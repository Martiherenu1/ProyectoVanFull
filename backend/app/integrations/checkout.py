"""Preferences API sandbox estricta. Sin retries POST ni URLs arbitrarias del webhook."""

import re
from dataclasses import dataclass
from decimal import Decimal
from urllib.parse import parse_qs, urlparse

import httpx

from app.integrations.mercadopago import (
    ClienteMercadoPagoPruebas,
    NotificacionNoValida,
    ProveedorNoDisponible,
)


@dataclass(frozen=True)
class PreferenciaCheckout:
    id: str
    url: str
    referencia: str
    receptor: int
    importe: Decimal
    moneda: str


class ClienteCheckoutPruebas(ClienteMercadoPagoPruebas):
    async def _solicitar(self, metodo: str, ruta: str, **opciones):
        try:
            respuesta = await self._cliente.request(
                metodo,
                "https://api.mercadopago.com" + ruta,
                headers={"Authorization": "Bearer " + self._token},
                timeout=10,
                follow_redirects=False,
                **opciones,
            )
            if respuesta.status_code not in {200, 201}:
                raise ProveedorNoDisponible("No se obtuvo respuesta válida del proveedor.")
            datos = respuesta.json()
            if not isinstance(datos, dict):
                raise ValueError
            return datos
        except (httpx.HTTPError, ValueError):
            raise ProveedorNoDisponible("No se pudo completar la consulta al proveedor.") from None

    def _preferencia(self, datos: dict, referencia: str, receptor: int) -> PreferenciaCheckout:
        id_pref = datos.get("id")
        url = datos.get("sandbox_init_point")
        if (
            not isinstance(id_pref, str)
            or not re.fullmatch(r"[A-Za-z0-9_-]{1,160}", id_pref)
            or not isinstance(url, str)
        ):
            raise NotificacionNoValida("Preferencia no válida.")
        try:
            uri = urlparse(url)
            puerto = uri.port
            items = datos["items"]
            if (
                len(items) != 1
                or type(items[0]["quantity"]) is not int
                or items[0]["quantity"] != 1
            ):
                raise ValueError
            importe = Decimal(str(items[0]["unit_price"]))
            moneda = items[0]["currency_id"]
            if not importe.is_finite() or importe <= 0 or not isinstance(moneda, str):
                raise ValueError
        except (ValueError, KeyError, TypeError, ArithmeticError):
            raise NotificacionNoValida("Detalle de preferencia no válido.") from None
        if (
            uri.scheme != "https"
            or uri.hostname not in {"sandbox.mercadopago.com", "sandbox.mercadopago.com.ar"}
            or uri.username
            or uri.password
            or puerto not in {None, 443}
            or uri.fragment
            or parse_qs(uri.query).get("pref_id") != [id_pref]
            or datos.get("external_reference") != referencia
            or type(datos.get("collector_id")) is not int
            or datos.get("collector_id") != receptor
        ):
            raise NotificacionNoValida("Preferencia ajena al escenario sandbox.")
        return PreferenciaCheckout(id_pref, url, referencia, receptor, importe, moneda)

    async def crear_preferencia(
        self,
        *,
        referencia: str,
        importe: Decimal,
        moneda: str,
        receptor: int,
        retorno: str,
        webhook: str,
    ) -> PreferenciaCheckout:
        datos = await self._solicitar(
            "POST",
            "/checkout/preferences",
            json={
                "items": [
                    {
                        "title": "VanFull - pago sandbox",
                        "quantity": 1,
                        "unit_price": float(importe),
                        "currency_id": moneda,
                    }
                ],
                "external_reference": referencia,
                "notification_url": webhook,
                "back_urls": {"success": retorno, "pending": retorno, "failure": retorno},
            },
        )
        return self._preferencia(datos, referencia, receptor)

    async def obtener_preferencia(self, id_pref: str, referencia: str, receptor: int):
        if not re.fullmatch(r"[A-Za-z0-9_-]{1,160}", id_pref):
            raise NotificacionNoValida("Preferencia no válida.")
        return self._preferencia(
            await self._solicitar("GET", "/checkout/preferences/" + id_pref), referencia, receptor
        )

    async def buscar_preferencia(self, referencia: str, receptor: int):
        datos = await self._solicitar(
            "GET",
            "/checkout/preferences/search",
            params={"external_reference": referencia, "limit": 2},
        )
        elementos = datos.get("elements")
        if not isinstance(elementos, list) or type(datos.get("total")) is not int:
            raise ProveedorNoDisponible("Búsqueda de preferencia incompleta.")
        if datos["total"] == 0 and not elementos:
            return None
        if datos["total"] != 1 or len(elementos) != 1 or not isinstance(elementos[0], dict):
            raise NotificacionNoValida("La correlación de preferencia es ambigua.")
        return await self.obtener_preferencia(str(elementos[0].get("id")), referencia, receptor)

    async def orden_de_pago(
        self, id_orden: str, id_operacion: str, referencia: str, receptor: int
    ) -> str:
        if not re.fullmatch(r"[0-9]{1,64}", id_orden):
            raise NotificacionNoValida("Orden no válida.")
        datos = await self._solicitar("GET", "/merchant_orders/" + id_orden)
        collector = datos.get("collector")
        pagos = datos.get("payments")
        if (
            str(datos.get("id")) != id_orden
            or not isinstance(collector, dict)
            or type(collector.get("id")) is not int
            or collector.get("id") != receptor
            or datos.get("external_reference") != referencia
            or not isinstance(pagos, list)
            or not any(isinstance(p, dict) and str(p.get("id")) == id_operacion for p in pagos)
        ):
            raise NotificacionNoValida("La orden no acredita la asociación del pago.")
        pref = await self.obtener_preferencia(str(datos.get("preference_id")), referencia, receptor)
        return pref.id
