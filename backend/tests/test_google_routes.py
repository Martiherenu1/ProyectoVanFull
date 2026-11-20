import json
from decimal import Decimal

import httpx
import pytest

from app.integrations.google_routes import calcular_tiempos

VANFULL = (-34.569991, -58.696060)
YPF = (-34.572994, -58.692181)
UADE = (-34.617882, -58.381599)


async def test_calcula_tiempos_acumulados_sin_reordenar_paradas():
    def responder(request: httpx.Request) -> httpx.Response:
        assert request.method == "POST"
        assert str(request.url) == "https://routes.googleapis.com/directions/v2:computeRoutes"
        assert request.headers["X-Goog-Api-Key"] == "clave-de-prueba"
        assert request.headers["X-Goog-FieldMask"] == "routes.legs.duration"
        cuerpo = json.loads(request.content)
        assert cuerpo["origin"]["location"]["latLng"] == {
            "latitude": VANFULL[0],
            "longitude": VANFULL[1],
        }
        assert cuerpo["intermediates"] == [
            {"location": {"latLng": {"latitude": YPF[0], "longitude": YPF[1]}}}
        ]
        assert cuerpo["destination"]["location"]["latLng"] == {
            "latitude": UADE[0],
            "longitude": UADE[1],
        }
        assert cuerpo["travelMode"] == "DRIVE"
        assert cuerpo["routingPreference"] == "TRAFFIC_AWARE"
        assert not cuerpo.get("optimizeWaypointOrder", False)
        return httpx.Response(
            200, json={"routes": [{"legs": [{"duration": "315.5s"}, {"duration": "2680s"}]}]}
        )

    async with httpx.AsyncClient(transport=httpx.MockTransport(responder)) as cliente:
        assert await calcular_tiempos(cliente, "clave-de-prueba", VANFULL, [YPF, UADE]) == (
            Decimal("315.5"),
            Decimal("2995.5"),
        )


@pytest.mark.parametrize(
    ("codigo", "cuerpo"),
    [
        (403, {}),
        (429, {}),
        (503, {}),
        (200, {"routes": []}),
        (200, {"routes": [{"legs": []}]}),
        (200, {"routes": [{"legs": [{"duration": "-5s"}]}]}),
        (200, {"routes": [{"legs": [{"duration": "NaNs"}]}]}),
        (200, {"routes": [{"legs": [{"duration": None}]}]}),
    ],
)
async def test_no_inventa_eta_ante_errores_o_respuestas_incompletas(codigo, cuerpo):
    transporte = httpx.MockTransport(lambda _: httpx.Response(codigo, json=cuerpo))
    async with httpx.AsyncClient(transport=transporte) as cliente:
        assert await calcular_tiempos(cliente, "clave-de-prueba", YPF, [UADE]) is None


async def test_conserva_cero_si_google_entrega_un_tramo_de_cero_segundos():
    cuerpo = {"routes": [{"legs": [{"duration": "0s"}]}]}
    transporte = httpx.MockTransport(lambda _: httpx.Response(200, json=cuerpo))
    async with httpx.AsyncClient(transport=transporte) as cliente:
        assert await calcular_tiempos(cliente, "clave-de-prueba", YPF, [UADE]) == (Decimal(0),)


async def test_devuelve_no_disponible_cuando_vence_el_timeout():
    def vencer(request: httpx.Request) -> httpx.Response:
        raise httpx.ReadTimeout("Sin respuesta", request=request)

    async with httpx.AsyncClient(transport=httpx.MockTransport(vencer)) as cliente:
        assert await calcular_tiempos(cliente, "clave-de-prueba", VANFULL, [YPF]) is None


async def test_no_llama_al_proveedor_sin_clave_o_sin_coordenadas_validas():
    def inesperado(_: httpx.Request) -> httpx.Response:
        pytest.fail("Google Routes no debía recibir una solicitud")

    async with httpx.AsyncClient(transport=httpx.MockTransport(inesperado)) as cliente:
        assert await calcular_tiempos(cliente, "", VANFULL, [YPF]) is None
        assert await calcular_tiempos(cliente, "clave-de-prueba", VANFULL, []) is None
        assert await calcular_tiempos(cliente, "clave-de-prueba", VANFULL, [(91, 0)]) is None
