"""Disponibilidad de cupos (CU-002, RF-004, RN-001, RN-002).

El cupo **se calcula, no se guarda** (MR-R30). La función `cupo_disponible` es la definición única:
CU-003 (crear reserva) la usa para rechazar lo que supere la capacidad, así que lo que ve el
pasajero al consultar y lo que el backend valida al reservar no pueden diverger.
"""

from datetime import date

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.models.servicios import Servicio
from app.models.viajes import Reserva, Vehiculo, Viaje
from app.schemas.servicios import Disponibilidad

# RN-002: una reserva provisional no garantiza el cupo; solo la consolidada lo ocupa.
ESTADO_QUE_OCUPA_CUPO = "consolidada"

# PENDIENTE DE VALIDACIÓN (#27): qué viajes se ofrecen. Se ofrecen los 'programado'; no hay una regla
# aprobada sobre un viaje 'en_curso' (¿se puede subir alguien a último momento?).
ESTADO_OFRECIDO = "programado"


def cupo_disponible(
    capacidad_vehiculo: int | None,
    capacidad_planificada: int | None,
    ocupados: int,
) -> int | None:
    """Lugares libres de un viaje, o None si no se puede determinar.

    - RN-001: la capacidad es la de la unidad. ADJ-03: se valida contra el vehículo cuando hay uno
      asignado.
    - Sin vehículo asignado, se usa `capacidad_planificada` (lo que la planificación del viaje
      declara). ADJ-03 no define qué capacidad rige antes de asignar la unidad: es una asunción.
    - Sin ninguna de las dos no hay forma de saberlo, y no se inventa un número.
    - Nunca negativo: un viaje sobrevendido muestra 0.
    """
    capacidad = capacidad_vehiculo if capacidad_vehiculo is not None else capacidad_planificada
    if capacidad is None:
        return None
    return max(capacidad - ocupados, 0)


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

    ocupados = (
        select(func.count())
        .select_from(Reserva)
        .where(Reserva.id_viaje == Viaje.id_viaje, Reserva.estado == ESTADO_QUE_OCUPA_CUPO)
        .correlate(Viaje)
        .scalar_subquery()
    )
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
