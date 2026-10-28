"""Última posición (MR-R31), timestamps del contrato #37 y acceso RN-030."""

from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.core.security import UsuarioActual
from app.models.viajes import PosicionGps, Viaje
from app.schemas.gps import PosicionGpsCreate, ResultadoPosicionGps, Ubicacion
from app.services.ejecucion_viajes import _bloquear_viaje_propio


async def enviar(
    db: AsyncSession, usuario: UsuarioActual, id_viaje: int, datos: PosicionGpsCreate
) -> ResultadoPosicionGps:
    # Mismo lock de viaje que finalizar: ningún POST aceptado tras el cierre.
    viaje = await _bloquear_viaje_propio(db, usuario, id_viaje)
    if viaje.estado != "en_curso":
        raise ApiError(409, "ESTADO_VIAJE_INVALIDO", "Solo se comparte ubicación durante el viaje.")
    ahora = datetime.now(UTC)
    efectiva = datos.fecha_hora_posicion
    if efectiva is None or efectiva > ahora:
        efectiva = ahora
    posicion = await db.get(PosicionGps, id_viaje)
    actualizada = (
        posicion is None
        or posicion.fecha_hora_posicion is None
        or efectiva > posicion.fecha_hora_posicion
    )
    if actualizada:
        if posicion is None:
            posicion = PosicionGps(id_viaje=id_viaje)
            db.add(posicion)
        posicion.latitud = datos.latitud
        posicion.longitud = datos.longitud
        posicion.fecha_hora_posicion = efectiva
    resultado = ResultadoPosicionGps(
        actualizada=actualizada, fecha_hora_posicion=posicion.fecha_hora_posicion
    )
    await db.commit()
    return resultado


async def consultar(db: AsyncSession, usuario: UsuarioActual, id_viaje: int) -> Ubicacion:
    # Compartido con finalización; no mostrar un cierre confirmado como seguimiento activo.
    viaje = await db.scalar(
        select(Viaje).where(Viaje.id_viaje == id_viaje).with_for_update(read=True)
    )
    if viaje is None or viaje.estado != "en_curso":
        raise ApiError(404, "VIAJE_NO_DISPONIBLE", "Ubicación no disponible.")
    if not set(usuario.roles).intersection({"administrador", "dueno"}):
        # Pendiente precisión contractual de reserva consolidada; no ampliar acceso.
        raise ApiError(403, "SIN_PERMISO", "No tenés permiso para consultar esta ubicación.")
    posicion = await db.get(PosicionGps, id_viaje)
    if (
        posicion is None
        or posicion.latitud is None
        or posicion.longitud is None
        or posicion.fecha_hora_posicion is None
    ):
        raise ApiError(404, "UBICACION_NO_DISPONIBLE", "Ubicación no disponible.")
    resultado = Ubicacion(
        id_viaje=id_viaje,
        latitud=posicion.latitud,
        longitud=posicion.longitud,
        fecha_hora_posicion=posicion.fecha_hora_posicion,
        desactualizada=datetime.now(UTC) - posicion.fecha_hora_posicion > timedelta(seconds=30),
        eta_minutos=None,
    )
    await db.commit()
    return resultado
