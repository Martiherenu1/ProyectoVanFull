"""Reservas del pasajero: consulta (CU-010, RF-043) y creación (CU-003, RF-005).

Cancelar (CU-004) y cambiar de parada (CU-005) se suman acá cuando sus reglas estén definidas.
`reserva` es una tabla de este módulo: lo que otras áreas necesiten de ella lo piden por estas
funciones.
"""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.core.security import UsuarioActual
from app.models.personas import Cliente, ClienteIndividual, Pasajero
from app.models.servicios import Contratacion
from app.models.viajes import ParadaRecorrido, Viaje
from app.models.viajes import Reserva as ReservaModelo
from app.schemas.reservas import Reserva, ReservaCreate
from app.services.disponibilidad import ESTADO_OFRECIDO, cupo_del_viaje
from app.services.eventos import registrar_evento

TIPO_RESERVA_CREADA = "reserva_creada"


def _a_schema(r: ReservaModelo, v: Viaje) -> Reserva:
    return Reserva(
        id_reserva=r.id_reserva,
        id_pasajero=r.id_pasajero,
        id_viaje=r.id_viaje,
        id_recorrido=r.id_recorrido,
        orden_parada=r.orden_parada,
        fecha=v.fecha,
        horario=v.horario.strftime("%H:%M") if v.horario else None,
        sentido=v.sentido,
        estado=r.estado,
    )


async def listar_reservas_del_pasajero(db: AsyncSession, usuario: UsuarioActual) -> list[Reserva]:
    """Todas las reservas del pasajero, de cualquier estado, la más reciente primero.

    CU-010 pide "las reservas que le corresponden" con su estado: las canceladas también son suyas.
    El orden no está definido en la especificación; es el de la fecha del viaje, descendente.
    """
    consulta = (
        select(ReservaModelo, Viaje)
        .join(Viaje, Viaje.id_viaje == ReservaModelo.id_viaje)
        .where(ReservaModelo.id_pasajero == usuario.id_persona)
        .order_by(
            Viaje.fecha.desc(), Viaje.horario.desc().nulls_last(), ReservaModelo.id_reserva.desc()
        )
    )
    return [_a_schema(r, v) for r, v in (await db.execute(consulta)).all()]


async def obtener_reserva_del_pasajero(
    db: AsyncSession, usuario: UsuarioActual, id_reserva: int
) -> Reserva:
    """El detalle de una reserva propia. Una ajena responde igual que una que no existe: 404.

    Así quien consulta no puede averiguar qué reservas existen (CONVENCIONES.md §3).
    """
    fila = (
        await db.execute(
            select(ReservaModelo, Viaje)
            .join(Viaje, Viaje.id_viaje == ReservaModelo.id_viaje)
            .where(
                ReservaModelo.id_reserva == id_reserva,
                ReservaModelo.id_pasajero == usuario.id_persona,
            )
        )
    ).one_or_none()
    if fila is None:
        raise ApiError(404, "RESERVA_NO_ENCONTRADA", "La reserva no existe.")
    return _a_schema(*fila)


async def _cliente_individual_del_pasajero(db: AsyncSession, id_persona: int) -> int:
    """El cliente que contrata en nombre del pasajero; si todavía no existe, se crea.

    Un ocasional no tiene contrato previo (AC7-01): al reservar por primera vez se convierte en
    cliente individual de sí mismo (`cliente` y `cliente_individual` son tablas de esta área).
    """
    id_cliente = await db.scalar(
        select(ClienteIndividual.id_cliente).where(ClienteIndividual.id_persona == id_persona)
    )
    if id_cliente is not None:
        return id_cliente
    cliente = Cliente(naturaleza_cliente="INDIVIDUAL")
    db.add(cliente)
    await db.flush()
    db.add(ClienteIndividual(id_cliente=cliente.id_cliente, id_persona=id_persona))
    await db.flush()
    return cliente.id_cliente


async def crear_reserva(db: AsyncSession, usuario: UsuarioActual, datos: ReservaCreate) -> Reserva:
    """Reserva un lugar al pasajero ocasional en un viaje (CU-003, RF-005).

    Validaciones, en el orden del flujo: el viaje, la parada, RN-031 (paso 3) y RN-001 (paso 4).
    Cubre al **ocasional** (AC7-01/02): sin contratación previa, el sistema acepta la reserva solo
    y queda `consolidada` (#33). Quedan fuera, por decisiones pendientes: la tarifa (paso 5,
    RF-028 / #9), el respaldo por abono, la lista de espera y el perfil completo (Issue #72).

    Se bloquean la fila del pasajero y la del viaje: dos pedidos del mismo pasajero no pueden pasar
    juntos RN-031, y dos pasajeros no pueden quedarse con el último lugar (RN-001).
    """
    pasajero = await db.scalar(
        select(Pasajero).where(Pasajero.id_persona == usuario.id_persona).with_for_update()
    )
    if pasajero is None:
        raise ApiError(404, "PASAJERO_NO_ENCONTRADO", "No hay un pasajero para esta cuenta.")

    viaje = await db.scalar(select(Viaje).where(Viaje.id_viaje == datos.id_viaje).with_for_update())
    if viaje is None:
        raise ApiError(404, "VIAJE_NO_ENCONTRADO", "El viaje no existe.")
    if viaje.estado != ESTADO_OFRECIDO:
        raise ApiError(409, "VIAJE_NO_RESERVABLE", "El viaje ya no admite reservas.")

    parada = await db.scalar(
        select(ParadaRecorrido.orden).where(
            ParadaRecorrido.id_recorrido == viaje.id_recorrido,
            ParadaRecorrido.orden == datos.orden_parada,
        )
    )
    if parada is None:
        raise ApiError(
            400,
            "PARADA_NO_VALIDA",
            "La parada no pertenece al recorrido del viaje.",
            {"orden_parada": datos.orden_parada, "id_recorrido": viaje.id_recorrido},
        )

    # RN-031 / A2: una sola reserva de ida y una de vuelta por día. Una cancelada no cuenta.
    del_dia = await db.scalar(
        select(ReservaModelo.id_reserva)
        .join(Viaje, Viaje.id_viaje == ReservaModelo.id_viaje)
        .where(
            ReservaModelo.id_pasajero == usuario.id_persona,
            ReservaModelo.estado != "cancelada",
            Viaje.fecha == viaje.fecha,
            Viaje.sentido == viaje.sentido,
        )
    )
    if del_dia is not None:
        raise ApiError(
            409,
            "RESERVA_DUPLICADA_DEL_DIA",
            "Ya tenés una reserva de ese sentido para esa fecha.",
            {"fecha": viaje.fecha.isoformat(), "sentido": viaje.sentido},
        )
    # MR-R15: una fila por pasajero y viaje, aunque esté cancelada. Reactivarla no está definido
    # (AC28-08, PV28-04): se informa en vez de chocar contra la restricción de la base.
    ya_tuvo_reserva = await db.scalar(
        select(ReservaModelo.id_reserva).where(
            ReservaModelo.id_pasajero == usuario.id_persona,
            ReservaModelo.id_viaje == viaje.id_viaje,
        )
    )
    if ya_tuvo_reserva is not None:
        raise ApiError(
            409, "RESERVA_CANCELADA_PREVIA", "Ya existe una reserva cancelada tuya para este viaje."
        )

    # RN-001 / A1: sin lugar libre no hay reserva. La lista de espera no tiene operación (#34).
    if await cupo_del_viaje(db, viaje.id_viaje) <= 0:
        raise ApiError(
            409,
            "CUPO_NO_DISPONIBLE",
            "No hay lugares disponibles en este viaje.",
            {"lista_espera": True},
        )

    # Respaldo (MR-R13): contratación directa. Una por reserva, sin tarifa ni importe todavía (#9).
    id_cliente = await _cliente_individual_del_pasajero(db, usuario.id_persona)
    contratacion = Contratacion(id_cliente=id_cliente, id_servicio=viaje.id_servicio)
    db.add(contratacion)
    await db.flush()

    reserva = ReservaModelo(
        id_pasajero=usuario.id_persona,
        id_viaje=viaje.id_viaje,
        id_recorrido=viaje.id_recorrido,
        orden_parada=datos.orden_parada,
        id_contratacion_directa=contratacion.id_contratacion,
        estado="consolidada",
    )
    db.add(reserva)
    await db.flush()
    await registrar_evento(db, tipo_evento=TIPO_RESERVA_CREADA, id_reserva=reserva.id_reserva)
    resultado = _a_schema(reserva, viaje)
    await db.commit()
    return resultado
