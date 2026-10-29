"""Todo HTTP es simulado: no usa credenciales ni se comunica con Mercado Pago."""

import asyncio
import hashlib
import hmac

import httpx
import pytest

from app.integrations.mercadopago import (
    ClienteMercadoPagoPruebas,
    NotificacionNoValida,
    ProveedorNoDisponible,
    validar_firma,
)

SECRETO = "secreto-sintetico-no-real"
AHORA = 1_800_000_000


def firma(id_operacion="987", request_id="peticion-falsa", ts=str(AHORA)):
    manifest = f"id:{id_operacion};request-id:{request_id};ts:{ts};"
    digest = hmac.new(SECRETO.encode(), manifest.encode(), hashlib.sha256).hexdigest()
    return f"ts={ts},v1={digest}"


def recurso(**cambios):
    return {
        "id": 987,
        "live_mode": False,
        "status": "approved",
        "transaction_amount": 1250.50,
        "currency_id": "ARS",
        "collector_id": 44,
        **cambios,
    }


def test_firma_valida_segundos_y_milisegundos():
    for ts in (str(AHORA), str(AHORA * 1000)):
        validar_firma(
            secreto=SECRETO,
            firma=firma(ts=ts),
            request_id="peticion-falsa",
            data_id="987",
            ahora=AHORA,
            tolerancia_segundos=60,
        )


@pytest.mark.parametrize(
    "cambios",
    [
        {"firma": ""},
        {"firma": "ts=1,v1=error"},
        {"request_id": "otra"},
        {"data_id": "988"},
        {"data_id": "../../payments"},
        {"ahora": AHORA + 61},
        {"ahora": AHORA - 61},
        {"firma": firma() + ",ts=1"},
        {"request_id": ""},
    ],
)
def test_firma_invalida_o_replay_se_rechaza(cambios):
    args = {
        "secreto": SECRETO,
        "firma": firma(),
        "request_id": "peticion-falsa",
        "data_id": "987",
        "ahora": AHORA,
        "tolerancia_segundos": 60,
    }
    with pytest.raises(NotificacionNoValida):
        validar_firma(**(args | cambios))


def test_falta_configuracion_no_se_disfraza_como_exito():
    with pytest.raises(ValueError):
        validar_firma(
            secreto="",
            firma=firma(),
            request_id="peticion-falsa",
            data_id="987",
            ahora=AHORA,
            tolerancia_segundos=60,
        )


def test_cliente_solo_consulta_recurso_y_no_expone_payload():
    async def correr():
        def responder(request):
            assert request.method == "GET"
            assert str(request.url) == "https://api.mercadopago.com/v1/payments/987"
            assert request.headers["Authorization"] == "Bearer token-falso"
            return httpx.Response(200, json=recurso(payer={"email": "privado"}))

        async with httpx.AsyncClient(transport=httpx.MockTransport(responder)) as cliente:
            resultado = await ClienteMercadoPagoPruebas(cliente, "token-falso").consultar("987")
            assert resultado.estado == "approved"
            assert "privado" not in repr(resultado)

    asyncio.run(correr())


@pytest.mark.parametrize(
    "datos",
    [
        recurso(live_mode=True),
        recurso(id=988),
        recurso(transaction_amount="NaN"),
        recurso(transaction_amount=-1),
        recurso(collector_id=True),
        recurso(status=None),
        {},
        [],
    ],
)
def test_respuesta_no_valida_no_se_acepta(datos):
    async def correr():
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(lambda _: httpx.Response(200, json=datos))
        ) as cliente:
            with pytest.raises(NotificacionNoValida):
                await ClienteMercadoPagoPruebas(cliente, "token-falso").consultar("987")

    asyncio.run(correr())


@pytest.mark.parametrize("codigo", [302, 401, 404, 429, 500])
def test_error_proveedor_sanitizado_sin_confirmar(codigo):
    async def correr():
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(
                lambda _: httpx.Response(codigo, text="token-falso y datos privados")
            )
        ) as cliente:
            with pytest.raises(ProveedorNoDisponible) as error:
                await ClienteMercadoPagoPruebas(cliente, "token-falso").consultar("987")
            assert "token-falso" not in str(error.value)

    asyncio.run(correr())


def test_timeout_no_filtra_datos_ni_reintenta_ocultamente():
    async def correr():
        llamadas = 0

        def responder(_):
            nonlocal llamadas
            llamadas += 1
            raise httpx.ReadTimeout("token-falso")

        async with httpx.AsyncClient(transport=httpx.MockTransport(responder)) as cliente:
            with pytest.raises(ProveedorNoDisponible) as error:
                await ClienteMercadoPagoPruebas(cliente, "token-falso").consultar("987")
            assert "token-falso" not in str(error.value)
            assert llamadas == 1

    asyncio.run(correr())
