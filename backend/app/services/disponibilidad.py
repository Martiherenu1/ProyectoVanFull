"""Disponibilidad de cupos (CU-002, RF-004, RN-001, RN-002).

El cupo **se calcula, no se guarda** (MR-R30). La función `cupo_disponible` es la definición única:
CU-003 (crear reserva) la usa para rechazar lo que supere la capacidad, así que lo que ve el
pasajero al consultar y lo que el backend valida al reservar no pueden diverger.
"""

from datetime import date

from sqlalchemy import exists, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.models.servicios import Servicio
from app.models.viajes import Ausencia, Reserva, Vehiculo, Viaje
from app.schemas.servicios import Disponibilidad

# RN-002: una reserva provisional no garantiza el cupo; solo la consolidada lo ocupa.
ESTADO_QUE_OCUPA_CUPO = "consolidada"

# Capacidad de referencia cuando el viaje no tiene unidad ni capacidad planificada: la mínima habitual
# de las unidades de VanFull (AC28-02, aclaración funcional validada de #28).
CAPACIDAD_PREDETERMINADA = 19

# Se ofrecen los viajes 'programado', sin mirar la hora: uno cuyo horario ya pasó pero todavía no
# comenzó sigue recibiendo reservas (AC28-05).
# PENDIENTE (#28): VanFull también acepta reservas en un viaje 'en_curso' si la parada de ascenso aún no
# fue alcanzada (AC28-04). No se implementa: el modelo no guarda qué paradas se alcanzaron y la última
# posición GPS no alcanza para probarlo (PV28-01).
ESTADO_OFRECIDO = "programado"


def cupo_disponible(
    capacidad_vehiculo: int | None,
    capacidad_planificada: int | None,
    ocupados: int,
) -> int:
    """Lugares libres de un viaje.

    La capacidad que rige, en este orden (AC28-01 a AC28-03):

    1. La del vehículo asignado (RN-001, ADJ-03): prevalece sobre las demás.
    2. Sin vehículo, `capacidad_planificada`.
    3. Sin ninguna de las dos, `CAPACIDAD_PREDETERMINADA` (19).

    `ocupados` son las reservas consolidadas que siguen ocupando lugar: quien informó su ausencia
    ya no cuenta (AC28-06). Nunca es negativo: un viaje sobrevendido muestra 0.
    """
    if capacidad_vehiculo is not None:
        capacidad = capacidad_vehiculo
    elif capacidad_planificada is not None:
        capacidad = capacidad_planificada
    else:
        capacidad = CAPACIDAD_PREDETERMINADA
    return max(capacidad - ocupados, 0)


def _lugares_ocupados():
    """Subconsulta correlacionada con `Viaje`: cuántas reservas ocupan lugar en cada viaje.

    Es la única definición de "ocupado" (RN-002, AC28-06): la consulta de disponibilidad y la
    creación de una reserva (CU-003) tienen que contar lo mismo, o el pasajero vería un cupo que
    el backend después rechaza.
    """
    # AC28-06: el pasajero que informó su ausencia (CU-008) libera su lugar de inmediato, sin que lo
    # apruebe nadie. La tabla `ausencia` es de Martín; acá solo se lee. Se asume que cada fila es un
    # aviso voluntario: una inasistencia sin aviso no libera cupo (PT28-18, RN-022).
    aviso_su_ausencia = exists().where(
        Ausencia.id_pasajero == Reserva.id_pasajero, Ausencia.id_viaje == Reserva.id_viaje
    )
    return (
        select(func.count())
        .select_from(Reserva)
        .where(
            Reserva.id_viaje == Viaje.id_viaje,
            Reserva.estado == ESTADO_QUE_OCUPA_CUPO,
            ~aviso_su_ausencia,
        )
        .correlate(Viaje)
        .scalar_subquery()
    )


async def lugares_ocupados_del_viaje(db: AsyncSession, id_viaje: int) -> int:
    """Cuenta lugares ocupados con la misma definición usada por consulta y reserva."""
    cantidad = await db.scalar(
        select(_lugares_ocupados()).select_from(Viaje).where(Viaje.id_viaje == id_viaje)
    )
    return int(cantidad or 0)


async def cupo_del_viaje(db: AsyncSession, id_viaje: int) -> int:
    """Lugares libres de un viaje concreto, con la misma regla que `consultar_disponibilidad`."""
    capacidad_vehiculo, planificada, ocupados = (
        await db.execute(
            select(Vehiculo.capacidad, Viaje.capacidad_planificada, _lugares_ocupados())
            .select_from(Viaje)
            .outerjoin(Vehiculo, Vehiculo.id_vehiculo == Viaje.id_vehiculo)
            .where(Viaje.id_viaje == id_viaje)
        )
    ).one()
    return cupo_disponible(capacidad_vehiculo, planificada, ocupados)


async def consultar_disponibilidad(
    db: AsyncSession,
    *,
    fecha: date,
    sentido: str,
    id_recorrido: int | None = None,
    destino: str | None = None,
) -> list[Disponibilidad]:
    if destino is not None:
        # Issue #8: el modelo no tiene un "destino" (ni en servicio, ni en recorrido, ni en parada).
        # Ignorarlo devolvería viajes a cualquier lado como si fueran al destino pedido; por eso se
        # rechaza de forma explícita en vez de simularlo.
        raise ApiError(
            400,
            "FILTRO_NO_DISPONIBLE",
            "Todavía no se puede filtrar por destino. Consultá por fecha y sentido, o por recorrido.",
            {"parametro": "destino"},
        )

    ocupados = _lugares_ocupados()
    consulta = (
        select(Viaje, Vehiculo.capacidad, ocupados.label("ocupados"))
        .outerjoin(Vehiculo, Vehiculo.id_vehiculo == Viaje.id_vehiculo)
        .join(Servicio, Servicio.id_servicio == Viaje.id_servicio)
        .where(
            Viaje.fecha == fecha,
            Viaje.sentido == sentido,
            Viaje.estado == ESTADO_OFRECIDO,
        )
        .order_by(Viaje.horario.nulls_last(), Viaje.id_viaje)
    )
    if id_recorrido is not None:
        consulta = consulta.where(Viaje.id_recorrido == id_recorrido)

    resultado = []
    for viaje, capacidad_vehiculo, cantidad in (await db.execute(consulta)).all():
        resultado.append(
            Disponibilidad(
                id_viaje=viaje.id_viaje,
                id_servicio=viaje.id_servicio,
                id_recorrido=viaje.id_recorrido,
                fecha=viaje.fecha,
                horario=viaje.horario.strftime("%H:%M") if viaje.horario else None,
                sentido=viaje.sentido,
                cupo_disponible=cupo_disponible(
                    capacidad_vehiculo, viaje.capacidad_planificada, cantidad
                ),
            )
        )
    return resultado
