"""Cliente de Google Routes para el cálculo de tramos de CU-009."""

import asyncio
import re
from collections.abc import Sequence
from decimal import Decimal

import httpx

type Coordenada = tuple[float, float]

_URL = "https://routes.googleapis.com/directions/v2:computeRoutes"
_DURACION = re.compile(r"([0-9]{1,12}(?:\.[0-9]{1,9})?)s")
_TIMEOUT_SEGUNDOS = 3


def _punto(coordenada: Coordenada) -> dict:
    latitud, longitud = coordenada
    return {"location": {"latLng": {"latitude": latitud, "longitude": longitud}}}


async def calcular_tiempos(
    cliente: httpx.AsyncClient,
    clave: str,
    origen: Coordenada,
    paradas: Sequence[Coordenada],
) -> tuple[Decimal, ...] | None:
    """Devuelve segundos acumulados hasta cada parada, en el orden recibido."""
    clave = clave.strip()
    if not clave or not paradas:
        return None
    if any(not (-90 <= lat <= 90 and -180 <= lon <= 180) for lat, lon in (origen, *paradas)):
        return None

    puntos = [_punto(parada) for parada in paradas]
    cuerpo = {
        "origin": _punto(origen),
        "destination": puntos[-1],
        "intermediates": puntos[:-1],
        "travelMode": "DRIVE",
        "routingPreference": "TRAFFIC_AWARE",
    }
    try:
        async with asyncio.timeout(_TIMEOUT_SEGUNDOS):
            respuesta = await cliente.post(
                _URL,
                json=cuerpo,
                headers={"X-Goog-Api-Key": clave, "X-Goog-FieldMask": "routes.legs.duration"},
                follow_redirects=False,
            )
        respuesta.raise_for_status()
        tramos = respuesta.json()["routes"][0]["legs"]
        if not isinstance(tramos, list) or len(tramos) != len(puntos):
            return None
        acumulados = []
        total = Decimal(0)
        for tramo in tramos:
            duracion = _DURACION.fullmatch(tramo["duration"])
            if duracion is None:
                return None
            total += Decimal(duracion[1])
            acumulados.append(total)
        return tuple(acumulados)
    except (httpx.HTTPError, TimeoutError, ValueError, IndexError, KeyError, TypeError):
        return None
