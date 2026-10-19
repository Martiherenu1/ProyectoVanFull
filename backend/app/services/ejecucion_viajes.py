"""Inicio y finalización del viaje por su chofer asignado (CU-030, RF-025).

La planificación/asignación corresponde a administración. El chofer solo cambia el
estado de sus propios viajes, conforme al contrato #37 y ADJ-03.
"""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.core.security import UsuarioActual
from app.models.viajes import Viaje as ViajeModelo
from app.schemas.viajes import Viaje
from app.services.eventos import registrar_evento
from app.services.viajes import _a_schema

TIPO_VIAJE_INICIADO = "viaje_iniciado"
TIPO_VIAJE_FINALIZADO = "viaje_finalizado"


async def _bloquear_viaje_propio(
    db: AsyncSession, usuario: UsuarioActual, id_viaje: int
) -> ViajeModelo:
    """Bloquea el viaje durante la transición para que dos reintentos no dupliquen eventos.

    RN-029: pertenencia del recurso comprobada en base de datos, además del rol en router.
    Ajeno e inexistente devuelven el mismo 404, incluso al reintentar.
    """
    viaje = await db.scalar(
        select(ViajeModelo)
        .where(
            ViajeModelo.id_viaje == id_viaje,
            ViajeModelo.id_chofer == usuario.id_persona,
        )
        .with_for_update()
    )
    if viaje is None:
        raise ApiError(404, "VIAJE_NO_ENCONTRADO", "El viaje no existe.")
    return viaje


async def iniciar_viaje(
    db: AsyncSession, usuario: UsuarioActual, id_viaje: int
) -> Viaje:
    """programado -> en_curso; reintentos en_curso/finalizado no generan eventos."""
    viaje = await _bloquear_viaje_propio(db, usuario, id_viaje)

    if viaje.estado == "cancelado":
        raise ApiError(409, "VIAJE_CANCELADO", "No se puede iniciar un viaje cancelado.")

    # Reintentos: son idempotentes incluso si el viaje ya terminó.
    if viaje.estado in ("en_curso", "finalizado"):
        resultado = _a_schema(viaje)
        await db.commit()  # Libera el bloqueo sin modificar registros.
        return resultado

    # ADJ-03: la asignación del chofer ya se comprobó con el filtro de pertenencia.
    if viaje.id_vehiculo is None:
        raise ApiError(
            409,
            "VEHICULO_NO_ASIGNADO",
            "El viaje necesita un vehículo asignado para iniciarse.",
        )

    viaje.estado = "en_curso"
    await registrar_evento(db, tipo_evento=TIPO_VIAJE_INICIADO, id_viaje=viaje.id_viaje)
    resultado = _a_schema(viaje)
    await db.commit()
    return resultado


async def finalizar_viaje(
    db: AsyncSession, usuario: UsuarioActual, id_viaje: int
) -> Viaje:
    """en_curso -> finalizado; reintentos finalizado no generan eventos."""
    viaje = await _bloquear_viaje_propio(db, usuario, id_viaje)

    if viaje.estado == "finalizado":
        resultado = _a_schema(viaje)
        await db.commit()
        return resultado

    if viaje.estado != "en_curso":
        raise ApiError(
            409,
            "ESTADO_VIAJE_INVALIDO",
            "Solo se puede finalizar un viaje en curso.",
        )

    viaje.estado = "finalizado"
    await registrar_evento(db, tipo_evento=TIPO_VIAJE_FINALIZADO, id_viaje=viaje.id_viaje)
    resultado = _a_schema(viaje)
    await db.commit()
    return resultado
