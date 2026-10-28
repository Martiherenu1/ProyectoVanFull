"""Creación y planificación de viajes del área de administración (CU-018)."""

from datetime import date

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.models.personas import Chofer
from app.models.servicios import PeriodoAbonoViaje, Servicio
from app.models.viajes import Recorrido, RegistroListaEspera, Reserva, Vehiculo
from app.models.viajes import Viaje as ViajeModelo
from app.schemas.viajes import Viaje, ViajeCreate, ViajeUpdate
from app.services.disponibilidad import (
    CAPACIDAD_PREDETERMINADA,
    lugares_ocupados_del_viaje,
)
from app.services.eventos import registrar_evento

TIPO_VIAJE_CREADO = "viaje_creado"
TIPO_VIAJE_ACTUALIZADO = "viaje_actualizado"
TIPO_VIAJE_CANCELADO = "viaje_cancelado"


async def cancelar_viaje(db: AsyncSession, id_viaje: int) -> Viaje:
    """Propuesta PC2 #180; confirmación de Martín pendiente. No implementa RN-019/CU-017.

    CONVENCIONES §8: solo bloquea viaje; nunca adquiere pasajero o reserva después.
    Comparte el lock con crear_reserva e iniciar_viaje antes de validar y escribir.
    """
    viaje = await db.scalar(
        select(ViajeModelo).where(ViajeModelo.id_viaje == id_viaje).with_for_update()
    )
    if viaje is None:
        raise ApiError(404, "VIAJE_NO_ENCONTRADO", "El viaje no existe.")
    tipo = await db.scalar(
        select(Servicio.tipo_servicio).where(Servicio.id_servicio == viaje.id_servicio)
    )
    if viaje.estado != "programado" or tipo in {"ESPECIAL", "CORPORATIVO"}:
        raise ApiError(
            409, "ESTADO_VIAJE_INVALIDO", "El viaje no admite esta cancelación limitada."
        )
    compromisos = (
        select(Reserva.id_reserva).where(
            Reserva.id_viaje == id_viaje,
            Reserva.estado.in_(("provisional", "consolidada")),
        ),
        select(PeriodoAbonoViaje.id_periodo_abono).where(PeriodoAbonoViaje.id_viaje == id_viaje),
        select(RegistroListaEspera.id_registro_lista_espera).where(
            RegistroListaEspera.id_viaje == id_viaje,
            RegistroListaEspera.estado == "en_espera",
        ),
    )
    for consulta in compromisos:
        if await db.scalar(consulta.limit(1)) is not None:
            # Código propuesto: pendiente de confirmación final del equipo (#180).
            raise ApiError(409, "VIAJE_CON_COMPROMISOS", "El viaje tiene compromisos pendientes.")
    viaje.estado = "cancelado"
    await registrar_evento(db, tipo_evento=TIPO_VIAJE_CANCELADO, id_viaje=id_viaje)
    resultado = _a_schema(viaje)
    await db.commit()
    return resultado


async def listar_viajes(db: AsyncSession, fecha: date) -> list[Viaje]:
    """Devuelve todos los viajes del día en el orden operativo acordado para administración."""
    consulta = (
        select(ViajeModelo)
        .where(ViajeModelo.fecha == fecha)
        .order_by(ViajeModelo.horario.asc().nulls_last(), ViajeModelo.id_viaje.asc())
    )
    viajes = (await db.scalars(consulta)).all()
    return [_a_schema(viaje) for viaje in viajes]


async def _validar_referencias(db: AsyncSession, datos: ViajeCreate) -> None:
    """Rechaza referencias inexistentes antes de que lo haga una FK de la base."""
    servicio = await db.scalar(
        select(Servicio.id_servicio).where(Servicio.id_servicio == datos.id_servicio)
    )
    if servicio is None:
        raise ApiError(404, "SERVICIO_NO_ENCONTRADO", "El servicio no existe.")

    recorrido = await db.scalar(
        select(Recorrido.id_recorrido).where(Recorrido.id_recorrido == datos.id_recorrido)
    )
    if recorrido is None:
        raise ApiError(404, "RECORRIDO_NO_ENCONTRADO", "El recorrido no existe.")

    await _capacidad_vehiculo(db, datos.id_vehiculo)
    await _validar_chofer(db, datos.id_chofer)


async def _capacidad_vehiculo(db: AsyncSession, id_vehiculo: int | None) -> int | None:
    if id_vehiculo is None:
        return None
    capacidad = await db.scalar(
        select(Vehiculo.capacidad).where(Vehiculo.id_vehiculo == id_vehiculo)
    )
    if capacidad is None:
        raise ApiError(404, "VEHICULO_NO_ENCONTRADO", "El vehículo no existe.")
    return capacidad


async def _validar_chofer(db: AsyncSession, id_chofer: int | None) -> None:
    if id_chofer is None:
        return
    chofer = await db.scalar(select(Chofer.id_persona).where(Chofer.id_persona == id_chofer))
    if chofer is None:
        raise ApiError(404, "CHOFER_NO_ENCONTRADO", "El chofer no existe.")


def _a_schema(viaje: ViajeModelo) -> Viaje:
    return Viaje(
        id_viaje=viaje.id_viaje,
        id_servicio=viaje.id_servicio,
        id_recorrido=viaje.id_recorrido,
        id_vehiculo=viaje.id_vehiculo,
        id_chofer=viaje.id_chofer,
        fecha=viaje.fecha,
        horario=viaje.horario.strftime("%H:%M") if viaje.horario else None,
        sentido=viaje.sentido,
        estado=viaje.estado,
        capacidad_planificada=viaje.capacidad_planificada,
    )


async def crear_viaje(db: AsyncSession, datos: ViajeCreate) -> Viaje:
    """Crea un viaje programado y registra su evento en la misma transacción.

    Vehículo y chofer son opcionales durante la planificación (ADJ-03). Las reglas para detectar
    solapamientos de asignaciones siguen pendientes de definición y no forman parte de esta operación.
    RN-001 no agrega una validación al alta: un viaje nuevo todavía no tiene pasajeros asignados.
    """
    await _validar_referencias(db, datos)

    viaje = ViajeModelo(
        id_servicio=datos.id_servicio,
        id_recorrido=datos.id_recorrido,
        id_vehiculo=datos.id_vehiculo,
        id_chofer=datos.id_chofer,
        fecha=datos.fecha,
        horario=datos.horario,
        sentido=datos.sentido,
        estado="programado",
        capacidad_planificada=datos.capacidad_planificada,
    )
    db.add(viaje)
    await db.flush()

    await registrar_evento(db, tipo_evento=TIPO_VIAJE_CREADO, id_viaje=viaje.id_viaje)
    await db.commit()
    return _a_schema(viaje)


async def actualizar_viaje(db: AsyncSession, id_viaje: int, datos: ViajeUpdate) -> Viaje:
    """Actualiza únicamente un viaje programado y preserva el cupo confirmado (CU-018/RN-001)."""
    viaje = await db.scalar(
        select(ViajeModelo).where(ViajeModelo.id_viaje == id_viaje).with_for_update()
    )
    if viaje is None:
        raise ApiError(404, "VIAJE_NO_ENCONTRADO", "El viaje no existe.")
    if viaje.estado != "programado":
        raise ApiError(
            409,
            "ESTADO_VIAJE_INVALIDO",
            "Solo se puede modificar un viaje programado.",
        )

    campos = datos.model_fields_set
    id_vehiculo = datos.id_vehiculo if "id_vehiculo" in campos else viaje.id_vehiculo
    id_chofer = datos.id_chofer if "id_chofer" in campos else viaje.id_chofer
    planificada = (
        datos.capacidad_planificada
        if "capacidad_planificada" in campos
        else viaje.capacidad_planificada
    )

    capacidad_vehiculo = await _capacidad_vehiculo(db, id_vehiculo)
    await _validar_chofer(db, id_chofer)
    if {"id_vehiculo", "capacidad_planificada"} & campos:
        ocupados = await lugares_ocupados_del_viaje(db, viaje.id_viaje)
        capacidad = (
            capacidad_vehiculo
            if capacidad_vehiculo is not None
            else planificada
            if planificada is not None
            else CAPACIDAD_PREDETERMINADA
        )
        if ocupados > capacidad:
            raise ApiError(
                409,
                "CAPACIDAD_INSUFICIENTE",
                "La capacidad no alcanza para las reservas existentes.",
                {"ocupados": ocupados, "capacidad": capacidad},
            )

    for campo in (
        "id_vehiculo",
        "id_chofer",
        "fecha",
        "horario",
        "sentido",
        "capacidad_planificada",
    ):
        if campo in campos:
            setattr(viaje, campo, getattr(datos, campo))

    await registrar_evento(
        db,
        tipo_evento=TIPO_VIAJE_ACTUALIZADO,
        id_viaje=viaje.id_viaje,
    )
    resultado = _a_schema(viaje)
    await db.commit()
    return resultado
