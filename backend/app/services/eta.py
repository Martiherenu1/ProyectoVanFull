"""Estimaciones por reserva y progreso operativo del vehículo (CU-009/CU-030)."""

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from math import ceil, floor
from time import monotonic

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import ApiError
from app.core.security import UsuarioActual
from app.integrations.google_routes import Coordenada, calcular_tiempos
from app.models.viajes import (
    DescensoHabilitado,
    Parada,
    ParadaRecorrido,
    PosicionGps,
    Reserva,
    Viaje,
)
from app.schemas.eta import EtaReserva, OrdenesDescenso, PasoParada
from app.services.ejecucion_viajes import _bloquear_viaje_propio

_VIGENCIA_GPS = timedelta(seconds=30)
_INTERVALO_ROUTES = 60
_CAPACIDAD_CACHE = 1000


async def listar_descensos(db: AsyncSession, id_viaje: int) -> OrdenesDescenso:
    if await db.get(Viaje, id_viaje) is None:
        raise ApiError(404, "VIAJE_NO_ENCONTRADO", "El viaje no existe.")
    ordenes = await db.scalars(
        select(DescensoHabilitado.orden_parada)
        .where(DescensoHabilitado.id_viaje == id_viaje)
        .order_by(DescensoHabilitado.orden_parada)
    )
    return OrdenesDescenso(ordenes=list(ordenes))


async def configurar_descensos(
    db: AsyncSession, id_viaje: int, datos: OrdenesDescenso
) -> OrdenesDescenso:
    viaje = await db.scalar(select(Viaje).where(Viaje.id_viaje == id_viaje).with_for_update())
    if viaje is None:
        raise ApiError(404, "VIAJE_NO_ENCONTRADO", "El viaje no existe.")
    if viaje.estado != "programado":
        raise ApiError(409, "VIAJE_NO_MODIFICABLE", "El viaje debe estar programado.")
    nuevos = set(datos.ordenes)
    existentes = set(
        await db.scalars(
            select(ParadaRecorrido.orden)
            .where(
                ParadaRecorrido.id_recorrido == viaje.id_recorrido,
                ParadaRecorrido.orden.in_(nuevos),
            )
            .with_for_update(read=True, key_share=True)
        )
    )
    if existentes != nuevos:
        raise ApiError(400, "PARADA_NO_VALIDA", "Las paradas deben pertenecer al recorrido.")
    actuales = list(
        await db.scalars(select(DescensoHabilitado).where(DescensoHabilitado.id_viaje == id_viaje))
    )
    quitados = {parada.orden_parada for parada in actuales} - nuevos
    if quitados and await db.scalar(
        select(Reserva.id_reserva)
        .where(Reserva.id_viaje == id_viaje, Reserva.orden_descenso.in_(quitados))
        .limit(1)
    ):
        raise ApiError(409, "DESCENSO_CON_RESERVAS", "Hay reservas que referencian el descenso.")
    for parada in actuales:
        if parada.orden_parada in quitados:
            await db.delete(parada)
    for orden in nuevos - {parada.orden_parada for parada in actuales}:
        db.add(
            DescensoHabilitado(
                id_viaje=id_viaje, id_recorrido=viaje.id_recorrido, orden_parada=orden
            )
        )
    await db.commit()
    return OrdenesDescenso(ordenes=sorted(nuevos))


async def registrar_paso(
    db: AsyncSession, usuario: UsuarioActual, id_viaje: int, datos: PasoParada
) -> PasoParada:
    viaje = await _bloquear_viaje_propio(db, usuario, id_viaje)
    if viaje.estado != "en_curso":
        raise ApiError(409, "ESTADO_VIAJE_INVALIDO", "Solo se registra el paso durante el viaje.")
    orden = datos.orden_parada
    if await db.get(ParadaRecorrido, (viaje.id_recorrido, orden)) is None:
        raise ApiError(400, "PARADA_NO_VALIDA", "La parada no pertenece al recorrido del viaje.")
    # El chofer confirma el avance del vehículo. El reintento de una parada anterior es inocuo.
    ultimo = viaje.orden_ultimo_paso or 0
    if orden > ultimo:
        viaje.orden_ultimo_paso = ultimo = orden
        viaje.fecha_ultimo_paso = datetime.now(UTC)
    resultado = PasoParada(orden_parada=ultimo)
    await db.commit()
    return resultado


@dataclass(frozen=True)
class _ReservaEnCurso:
    id_viaje: int
    id_recorrido: int
    ultimo_paso: int
    ascenso: int
    destino: int | None
    origen: Coordenada | None
    fecha_gps: datetime | None


async def _contexto(db: AsyncSession, usuario: UsuarioActual, id_reserva: int) -> _ReservaEnCurso:
    fila = (
        await db.execute(
            select(
                Viaje.id_viaje,
                Viaje.id_recorrido,
                Viaje.estado,
                Viaje.orden_ultimo_paso,
                Viaje.fecha_ultimo_paso,
                Reserva.orden_parada,
                Reserva.orden_descenso,
                PosicionGps.latitud,
                PosicionGps.longitud,
                PosicionGps.fecha_hora_posicion,
            )
            .select_from(Reserva)
            .join(Viaje, Viaje.id_viaje == Reserva.id_viaje)
            .outerjoin(PosicionGps, PosicionGps.id_viaje == Viaje.id_viaje)
            .where(
                Reserva.id_reserva == id_reserva,
                Reserva.id_pasajero == usuario.id_persona,
                Reserva.estado == "consolidada",
            )
        )
    ).one_or_none()
    if fila is None or fila.estado != "en_curso":
        raise ApiError(404, "ETA_NO_DISPONIBLE", "No hay seguimiento disponible para esta reserva.")
    fecha_gps = fila.fecha_hora_posicion
    if (
        fila.fecha_ultimo_paso is not None
        and fecha_gps is not None
        and fecha_gps < fila.fecha_ultimo_paso
    ):
        fecha_gps = None
    return _ReservaEnCurso(
        fila.id_viaje,
        fila.id_recorrido,
        fila.orden_ultimo_paso or 0,
        fila.orden_parada,
        fila.orden_descenso,
        (float(fila.latitud), float(fila.longitud))
        if fila.latitud is not None and fila.longitud is not None
        else None,
        fecha_gps,
    )


def _gps_vigente(fecha_gps: datetime | None) -> bool:
    return fecha_gps is not None and timedelta(0) <= datetime.now(UTC) - fecha_gps <= _VIGENCIA_GPS


async def _itinerario(
    db: AsyncSession, reserva: _ReservaEnCurso
) -> tuple[tuple[int, Coordenada], ...] | None:
    filas = (
        await db.execute(
            select(ParadaRecorrido.orden, Parada.latitud, Parada.longitud)
            .join(Parada, Parada.id_parada == ParadaRecorrido.id_parada)
            .where(
                ParadaRecorrido.id_recorrido == reserva.id_recorrido,
                ParadaRecorrido.orden > reserva.ultimo_paso,
            )
            .order_by(ParadaRecorrido.orden)
        )
    ).all()
    # Google admite hasta 25 puntos intermedios. Saltar una parada sin coordenadas
    # alteraría el itinerario, por lo que en este caso se retira la estimación.
    if not 1 <= len(filas) <= 26 or any(lat is None or lon is None for _, lat, lon in filas):
        return None
    return tuple((orden, (float(lat), float(lon))) for orden, lat, lon in filas)


@dataclass
class _Calculo:
    inicio: float
    fecha_gps: datetime
    itinerario: tuple[tuple[int, Coordenada], ...]
    tiempos: tuple[Decimal, ...] | None = None


_cache: dict[int, _Calculo] = {}


async def _estimar(
    reserva: _ReservaEnCurso, itinerario: tuple[tuple[int, Coordenada], ...]
) -> _Calculo | None:
    clave = get_settings().google_routes_api_key.get_secret_value()
    if not clave or reserva.origen is None or reserva.fecha_gps is None:
        return None
    ahora = monotonic()
    for id_viaje in tuple(_cache):
        if ahora - _cache[id_viaje].inicio >= _INTERVALO_ROUTES:
            del _cache[id_viaje]
    previo = _cache.get(reserva.id_viaje)
    if previo is not None:
        return (
            previo if previo.itinerario == itinerario and _gps_vigente(previo.fecha_gps) else None
        )
    if len(_cache) >= _CAPACIDAD_CACHE:
        return None
    # Se registra antes del primer await: un segundo pedido en este proceso reutiliza el cálculo.
    calculo = _Calculo(ahora, reserva.fecha_gps, itinerario)
    _cache[reserva.id_viaje] = calculo
    async with httpx.AsyncClient(trust_env=False) as cliente:
        calculo.tiempos = await calcular_tiempos(
            cliente, clave, reserva.origen, [punto for _, punto in itinerario]
        )
    return calculo


def _sin_eta(reserva: _ReservaEnCurso) -> EtaReserva:
    return EtaReserva(
        ascenso_pasado=reserva.ascenso <= reserva.ultimo_paso,
        destino_pasado=reserva.destino is not None and reserva.destino <= reserva.ultimo_paso,
    )


async def consultar(db: AsyncSession, usuario: UsuarioActual, id_reserva: int) -> EtaReserva:
    reserva = await _contexto(db, usuario, id_reserva)
    salida = _sin_eta(reserva)
    if not _gps_vigente(reserva.fecha_gps) or (
        salida.ascenso_pasado and (reserva.destino is None or salida.destino_pasado)
    ):
        return salida
    itinerario = await _itinerario(db, reserva)
    if itinerario is None:
        return salida
    await db.commit()  # La consulta externa no retiene la transacción.
    calculo = await _estimar(reserva, itinerario)
    vigente = await _contexto(db, usuario, id_reserva)
    salida = _sin_eta(vigente)
    if (
        calculo is None
        or calculo.tiempos is None
        or not _gps_vigente(calculo.fecha_gps)
        or not _gps_vigente(vigente.fecha_gps)
        or monotonic() - calculo.inicio >= _INTERVALO_ROUTES
        or vigente.ultimo_paso != reserva.ultimo_paso
        or vigente.id_recorrido != reserva.id_recorrido
        or await _itinerario(db, vigente) != itinerario
    ):
        return salida
    minutos = {
        orden: max(0, ceil((segundos - Decimal(monotonic() - calculo.inicio)) / 60))
        for (orden, _), segundos in zip(itinerario, calculo.tiempos, strict=True)
    }
    salida.vigencia_segundos = max(
        0,
        floor(
            min(
                (_VIGENCIA_GPS - (datetime.now(UTC) - calculo.fecha_gps)).total_seconds(),
                _INTERVALO_ROUTES - (monotonic() - calculo.inicio),
            )
        ),
    )
    if salida.vigencia_segundos == 0:
        return salida
    salida.ascenso_minutos = minutos.get(vigente.ascenso)
    if vigente.destino is not None:
        salida.destino_minutos = minutos.get(vigente.destino)
    return salida
