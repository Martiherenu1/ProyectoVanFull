"""Creación y planificación de viajes del área de administración (CU-018)."""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.models.personas import Chofer
from app.models.servicios import Servicio
from app.models.viajes import Recorrido, Vehiculo
from app.models.viajes import Viaje as ViajeModelo
from app.schemas.viajes import Viaje, ViajeCreate
from app.services.eventos import registrar_evento

TIPO_VIAJE_CREADO = "viaje_creado"


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

    if datos.id_vehiculo is not None:
        vehiculo = await db.scalar(
            select(Vehiculo.id_vehiculo).where(Vehiculo.id_vehiculo == datos.id_vehiculo)
        )
        if vehiculo is None:
            raise ApiError(404, "VEHICULO_NO_ENCONTRADO", "El vehículo no existe.")

    if datos.id_chofer is not None:
        chofer = await db.scalar(
            select(Chofer.id_persona).where(Chofer.id_persona == datos.id_chofer)
        )
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
