"""Cliente de OpenRouter de AG-01: qué hace ante cada falla del gateway (Issue #154).

OpenRouter se reemplaza por un `httpx.MockTransport`, sin red. Lo que se prueba: que toda falla del
modelo principal pasa al fallback, que si fallan los dos se lanza `OpenRouterError` (que el servicio
convierte en derivación, `test_agente.py`), que ninguna termina en otra excepción y que el log dice
el motivo sin mostrar la clave.
"""

import asyncio
import json
import logging
import time

import httpx
import pytest

from app.agent import openrouter_client
from app.agent.openrouter_client import OpenRouterError, chat_completion

CLAVE = "sk-or-de-prueba"
PRINCIPAL = "principal/modelo:free"
FALLBACK = "fallback/modelo:free"
RESPUESTA = {"choices": [{"message": {"role": "assistant", "content": "Hola"}}]}
MENSAJES = [{"role": "user", "content": "Hola"}]


@pytest.fixture
def openrouter(monkeypatch):
    """Instala un OpenRouter falso: `responder(modelo, request)` decide qué contesta cada uno."""
    monkeypatch.setattr(openrouter_client.settings, "openrouter_api_key", CLAVE)
    monkeypatch.setattr(openrouter_client.settings, "openrouter_model_primary", PRINCIPAL)
    monkeypatch.setattr(openrouter_client.settings, "openrouter_model_fallback", FALLBACK)
    pedidos: list[httpx.Request] = []
    cliente_real = httpx.AsyncClient

    def _instalar(responder):
        def manejar(request: httpx.Request) -> httpx.Response:
            pedidos.append(request)
            return responder(json.loads(request.content)["model"], request)

        transporte = httpx.MockTransport(manejar)
        monkeypatch.setattr(
            openrouter_client.httpx,
            "AsyncClient",
            lambda **kwargs: cliente_real(transport=transporte, **kwargs),
        )
        return pedidos

    return _instalar


def _modelos(pedidos: list[httpx.Request]) -> list[str]:
    return [json.loads(p.content)["model"] for p in pedidos]


def _falla_de_red(excepcion):
    def responder(modelo, request):
        raise excepcion("falla simulada", request=request)

    return responder


FALLAS = {
    "clave_invalida_401": lambda m, r: httpx.Response(401, json={"error": {"code": 401}}),
    "limite_429": lambda m, r: httpx.Response(429, json={"error": {"code": 429}}),
    "modelo_inexistente_404": lambda m, r: httpx.Response(404, json={"error": {"code": 404}}),
    "proveedor_caido_502": lambda m, r: httpx.Response(502, text="Bad gateway"),
    "200_sin_json": lambda m, r: httpx.Response(200, text="<html>no es json</html>"),
    "200_con_error": lambda m, r: httpx.Response(200, json={"error": {"code": 502}}),
    "200_sin_choices": lambda m, r: httpx.Response(200, json={"choices": []}),
    "timeout": _falla_de_red(httpx.ReadTimeout),
    "sin_conexion": _falla_de_red(httpx.ConnectError),
}


@pytest.mark.parametrize("falla", FALLAS.values(), ids=FALLAS.keys())
def test_si_falla_el_principal_responde_el_fallback(openrouter, falla):
    pedidos = openrouter(
        lambda modelo, r: (
            falla(modelo, r) if modelo == PRINCIPAL else httpx.Response(200, json=RESPUESTA)
        )
    )
    assert asyncio.run(chat_completion(MENSAJES)) == RESPUESTA
    assert _modelos(pedidos) == [PRINCIPAL, FALLBACK]


@pytest.mark.parametrize("falla", FALLAS.values(), ids=FALLAS.keys())
def test_si_fallan_los_dos_se_lanza_openrouter_error_y_se_registra(openrouter, falla, caplog):
    pedidos = openrouter(falla)
    with (
        caplog.at_level(logging.WARNING, logger=openrouter_client.__name__),
        pytest.raises(OpenRouterError),
    ):
        asyncio.run(chat_completion(MENSAJES))
    assert _modelos(pedidos) == [PRINCIPAL, FALLBACK]
    assert PRINCIPAL in caplog.text and FALLBACK in caplog.text
    assert CLAVE not in caplog.text


def test_el_principal_que_responde_bien_no_pasa_al_fallback(openrouter):
    tools = [{"type": "function", "function": {"name": "derivar_humano"}}]
    pedidos = openrouter(lambda modelo, r: httpx.Response(200, json=RESPUESTA))
    assert asyncio.run(chat_completion(MENSAJES, tools=tools)) == RESPUESTA
    assert _modelos(pedidos) == [PRINCIPAL]
    assert pedidos[0].headers["Authorization"] == f"Bearer {CLAVE}"
    assert json.loads(pedidos[0].content)["tools"] == tools


def test_sin_clave_no_se_llama_a_openrouter(openrouter, monkeypatch, caplog):
    pedidos = openrouter(lambda modelo, r: httpx.Response(200, json=RESPUESTA))
    monkeypatch.setattr(openrouter_client.settings, "openrouter_api_key", "")
    with (
        caplog.at_level(logging.WARNING, logger=openrouter_client.__name__),
        pytest.raises(OpenRouterError),
    ):
        asyncio.run(chat_completion(MENSAJES))
    assert pedidos == []
    assert "OPENROUTER_API_KEY" in caplog.text


def test_cada_llamada_espera_como_mucho_lo_que_queda_del_mensaje(openrouter):
    pedidos = openrouter(lambda modelo, r: httpx.Response(200, json=RESPUESTA))
    asyncio.run(chat_completion(MENSAJES, limite=time.monotonic() + 5))
    espera = pedidos[0].extensions["timeout"]
    assert 0 < espera["read"] <= 5
    # Sin tope del mensaje, rige el de cada llamada.
    asyncio.run(chat_completion(MENSAJES))
    assert pedidos[1].extensions["timeout"]["read"] == openrouter_client.TIMEOUT_POR_LLAMADA


def test_pasado_el_tope_del_mensaje_no_se_prueba_ningun_modelo(openrouter):
    pedidos = openrouter(lambda modelo, r: httpx.Response(200, json=RESPUESTA))
    with pytest.raises(OpenRouterError):
        asyncio.run(chat_completion(MENSAJES, limite=time.monotonic() - 1))
    assert pedidos == []


def test_un_modelo_que_no_termina_de_responder_se_corta_al_llegar_al_tope(monkeypatch, caplog):
    """Prueba en Render del 29/10: un mensaje no respondió en 120 s.

    El tiempo de espera de httpx es por lectura: si el modelo sigue mandando datos, no vence. El
    tope tiene que cortar la llamada entera, no solo cada lectura.
    """
    monkeypatch.setattr(openrouter_client.settings, "openrouter_api_key", CLAVE)
    monkeypatch.setattr(openrouter_client.settings, "openrouter_model_primary", PRINCIPAL)
    monkeypatch.setattr(openrouter_client.settings, "openrouter_model_fallback", FALLBACK)
    cliente_real = httpx.AsyncClient
    pedidos: list[httpx.Request] = []

    async def colgado(request: httpx.Request) -> httpx.Response:
        pedidos.append(request)
        await asyncio.sleep(30)
        return httpx.Response(200, json=RESPUESTA)

    monkeypatch.setattr(
        openrouter_client.httpx,
        "AsyncClient",
        lambda **kwargs: cliente_real(transport=httpx.MockTransport(colgado), **kwargs),
    )
    inicio = time.monotonic()
    with (
        caplog.at_level(logging.WARNING, logger=openrouter_client.logger.name),
        pytest.raises(OpenRouterError),
    ):
        asyncio.run(chat_completion(MENSAJES, limite=time.monotonic() + 0.5))
    # Corta cerca del tope; con el principal colgado no queda tiempo para el fallback.
    assert time.monotonic() - inicio < 3
    assert len(pedidos) == 1
    assert PRINCIPAL in caplog.text
    assert "TimeoutError" in caplog.text
