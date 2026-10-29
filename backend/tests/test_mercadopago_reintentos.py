"""Recuperación explícita del adaptador: HTTP simulado, sin DB ni cobros."""

import asyncio

import httpx
import pytest

from app.integrations.mercadopago import ClienteMercadoPagoPruebas, ProveedorNoDisponible
from tests.test_mercadopago_validacion import recurso


@pytest.mark.parametrize("fallo", ["timeout", 429, 500])
def test_consulta_puede_reintentarse_explicitamente_tras_fallo_transitorio(fallo):
    async def correr():
        llamadas = []

        def responder(request):
            llamadas.append(request)
            if len(llamadas) == 1:
                if fallo == "timeout":
                    raise httpx.ReadTimeout("token-sintetico", request=request)
                return httpx.Response(fallo, text="token-sintetico")
            return httpx.Response(200, json=recurso())

        async with httpx.AsyncClient(transport=httpx.MockTransport(responder)) as http:
            proveedor = ClienteMercadoPagoPruebas(http, "token-sintetico")
            with pytest.raises(ProveedorNoDisponible) as error:
                await proveedor.consultar("987")
            assert "token-sintetico" not in str(error.value)
            assert len(llamadas) == 1

            resultado = await proveedor.consultar("987")
            assert resultado.id_operacion == "987"
            assert resultado.estado == "approved"
            assert len(llamadas) == 2
            assert all(request.method == "GET" for request in llamadas)
            assert all(
                str(request.url) == "https://api.mercadopago.com/v1/payments/987"
                and request.content == b""
                for request in llamadas
            )

    asyncio.run(correr())
