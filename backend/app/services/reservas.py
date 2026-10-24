"""Reservas del pasajero: consulta (CU-010, RF-043), creación (CU-003, RF-005) y cancelación (CU-004).

Cambiar de parada (CU-005) no es del PC2 (REPARTO-PC2.md).
`reserva` es una tabla de este módulo: lo que otras áreas necesiten de ella lo piden por estas
funciones.
"""

from datetime import date, datetime, time, timedelta, timezone

from sqlalchemy import exists, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.core.security import UsuarioActual
from app.models.personas import Cliente, ClienteIndividual, Pasajero
from app.models.servicios import Contratacion, Servicio
from app.models.viajes import Ausencia, ParadaRecorrido, Viaje
from app.models.viajes import Reserva as ReservaModelo
from app.schemas.reservas import Reserva, ReservaCreate, ResultadoCancelacion
from app.services.disponibilidad import ESTADO_OFRECIDO, cupo_del_viaje
from app.services.eventos import registrar_evento

TIPO_RESERVA_CREADA = "reserva_creada"
TIPO_RESERVA_CANCELADA = "reserva_cancelada"

# RN-017: la referencia operativa para cancelar un viaje ocasional es antes de las 18:00 del día
# anterior. Argentina no tiene horario de verano: UTC-3 todo el año.
ZONA_ARGENTINA = timezone(timedelta(hours=-3))
LIMITE_CANCELACION = time(18, 0)


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


async def reserva_propia_del_viaje(
    db: AsyncSession, usuario: UsuarioActual, id_viaje: int, *, bloquear: bool = False
) -> ReservaModelo | None:
    """La reserva del llamador en un viaje, sea cual sea su estado; `None` si no tiene.

    Es para otros servicios de esta área (el aviso de ausencia, CU-008): usa la sesión del llamador
    y no hace `commit`, así la lectura y lo que el llamador escriba después son una sola
    transacción. No decide nada sobre el estado: eso es de quien la llama.

    `bloquear=True` toma el lock de la fila, que es el **último** del orden pasajero → viaje →
    reserva (CONVENCIONES.md §8): el llamador ya tiene que haber bloqueado los dos primeros.
    """
    consulta = select(ReservaModelo).where(
        ReservaModelo.id_pasajero == usuario.id_persona, ReservaModelo.id_viaje == id_viaje
    )
    if bloquear:
        consulta = consulta.with_for_update()
    return await db.scalar(consulta)


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


def _en_termino(fecha_viaje: date, ahora: datetime) -> bool:
    """RN-017: ¿se cancela antes de las 18:00 del día anterior al viaje?"""
    limite = datetime.combine(fecha_viaje - timedelta(days=1), LIMITE_CANCELACION, ZONA_ARGENTINA)
    return ahora < limite


def _motivo(reserva: ReservaModelo, tipo_servicio: str, fecha_viaje: date, ahora: datetime) -> str:
    """Qué regla corresponde a esta cancelación. Ninguna consecuencia económica se aplica todavía.

    No hay dónde guardar el crédito de RN-017 (ninguna de las 35 tablas lo contempla) y la
    devolución de RN-018 depende de los pagos y la tarifa (#9): el motivo lo dice en vez de
    sugerir que se aplicó algo.
    """
    if reserva.id_periodo_abono is not None:
        return "RN-007: los viajes de un abono no generan devolución, crédito ni traslado."
    if tipo_servicio == "ESPECIAL":
        return "Servicio especial (RN-018): la devolución todavía no se calcula."
    if _en_termino(fecha_viaje, ahora):
        return (
            "Cancelación en término (antes de las 18:00 del día anterior). RN-017 prevé un "
            "crédito para otro viaje del mes, que todavía no se otorga."
        )
    return (
        "Cancelación fuera del término de referencia de RN-017 (18:00 del día anterior): "
        "el caso no está definido y no se aplica ninguna consecuencia."
    )


async def cancelar_reserva(
    db: AsyncSession, usuario: UsuarioActual, id_reserva: int
) -> ResultadoCancelacion:
    """Cancela una reserva propia y devuelve el lugar al viaje (CU-004, RF-006).

    La reserva queda `cancelada`; el cupo no se guarda, se calcula (MR-R30), así que el lugar vuelve
    solo. Se puede cancelar mientras el viaje está `programado`, fuera del término de RN-017 también:
    esa ventana solo decide el crédito, que todavía no se otorga (Issue #74).

    Se bloquean, en este orden, el pasajero, el viaje y la reserva (CONVENCIONES.md §8): dos
    cancelaciones simultáneas no pasan las dos, y una cancelación no se cruza con el inicio del
    viaje (que bloquea el viaje) ni con una reserva o un aviso de ausencia del mismo pasajero.
    """
    de_la_reserva = (
        ReservaModelo.id_reserva == id_reserva,
        ReservaModelo.id_pasajero == usuario.id_persona,
    )
    # El viaje se conoce por la reserva: se lee sin bloquear solo para saber cuál bloquear. Ajena e
    # inexistente responden igual (404), antes de tomar ningún lock.
    id_viaje = await db.scalar(select(ReservaModelo.id_viaje).where(*de_la_reserva))
    if id_viaje is None:
        raise ApiError(404, "RESERVA_NO_ENCONTRADA", "La reserva no existe.")

    await db.scalar(
        select(Pasajero.id_persona)
        .where(Pasajero.id_persona == usuario.id_persona)
        .with_for_update()
    )
    viaje = await db.scalar(select(Viaje).where(Viaje.id_viaje == id_viaje).with_for_update())
    # Se vuelve a leer con el lock: lo anterior pudo cambiar mientras se esperaba el turno.
    reserva = await db.scalar(select(ReservaModelo).where(*de_la_reserva).with_for_update())
    if reserva is None:
        raise ApiError(404, "RESERVA_NO_ENCONTRADA", "La reserva no existe.")

    if reserva.estado == "cancelada":
        raise ApiError(409, "RESERVA_NO_CANCELABLE", "La reserva ya estaba cancelada.")
    if viaje.estado != ESTADO_OFRECIDO:
        raise ApiError(409, "VIAJE_NO_CANCELABLE", "El viaje ya no está programado.")

    # El lugar vuelve solo si lo ocupaba: una provisional no lo ocupa (RN-002) y quien avisó su
    # ausencia ya lo había liberado (AC28-06).
    aviso_su_ausencia = await db.scalar(
        select(
            exists().where(
                Ausencia.id_pasajero == reserva.id_pasajero, Ausencia.id_viaje == reserva.id_viaje
            )
        )
    )
    cupo_liberado = reserva.estado == "consolidada" and not aviso_su_ausencia

    tipo_servicio = await db.scalar(
        select(Servicio.tipo_servicio).where(Servicio.id_servicio == viaje.id_servicio)
    )
    motivo = _motivo(reserva, tipo_servicio, viaje.fecha, datetime.now(ZONA_ARGENTINA))

    reserva.estado = "cancelada"
    await db.flush()
    await registrar_evento(db, tipo_evento=TIPO_RESERVA_CANCELADA, id_reserva=reserva.id_reserva)
    resultado = ResultadoCancelacion(
        reserva=_a_schema(reserva, viaje),
        cupo_liberado=cupo_liberado,
        penalidad_aplicada=False,
        importe_penalidad=0.0,
        motivo=motivo,
    )
    await db.commit()
    return resultado
