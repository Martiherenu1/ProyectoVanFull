"""Candidato técnico CU-036: HMAC y consulta de Payments; sin creación de cobros.

No conectado a HTTP público. Credenciales/secreto y política temporal los suministra
el futuro integrador, una vez definido el escenario académico (#215).
"""

import hashlib
import hmac
import re
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation

import httpx


class ErrorMercadoPago(Exception):
    """Error interno sanitizado; no define respuestas HTTP del contrato compartido."""


class NotificacionNoValida(ErrorMercadoPago):
    pass


class ProveedorNoDisponible(ErrorMercadoPago):
    pass


def validar_firma(
    *,
    secreto: str,
    firma: str,
    request_id: str,
    data_id: str,
    ahora: float,
    tolerancia_segundos: int,
) -> None:
    """Verifica el manifest oficial sin confiar en el cuerpo ni normalizar IDs.

    Política de tolerancia obligatoria e inyectable, sin elegirla por el equipo.
    Se admiten timestamps en segundos o milisegundos usados por el proveedor.
    """
    if not secreto or tolerancia_segundos <= 0:
        raise ValueError("Falta configuración de autenticidad de pruebas.")
    if not request_id or not re.fullmatch(r"[0-9]{1,64}", data_id):
        raise NotificacionNoValida("Notificación no válida.")
    partes = [parte.strip().split("=", 1) for parte in firma.split(",")]
    if any(len(parte) != 2 for parte in partes):
        raise NotificacionNoValida("Firma no válida.")
    valores = dict(partes)
    if len(valores) != len(partes) or set(valores) != {"ts", "v1"}:
        raise NotificacionNoValida("Firma no válida.")
    ts, v1 = valores["ts"], valores["v1"]
    if not re.fullmatch(r"[0-9]{1,16}", ts) or not re.fullmatch(r"[a-fA-F0-9]{64}", v1):
        raise NotificacionNoValida("Firma no válida.")
    timestamp = int(ts)
    segundos = timestamp / 1000 if timestamp >= 1_000_000_000_000 else timestamp
    if abs(ahora - segundos) > tolerancia_segundos:
        raise NotificacionNoValida("Notificación fuera de la ventana configurada.")
    manifest = f"id:{data_id};request-id:{request_id};ts:{ts};"
    esperado = hmac.new(secreto.encode(), manifest.encode(), hashlib.sha256).hexdigest()
    if not hmac.compare_digest(esperado, v1.lower()):
        raise NotificacionNoValida("Firma no válida.")


@dataclass(frozen=True)
class PagoProveedor:
    id_operacion: str
    estado: str
    importe: Decimal
    moneda: str
    id_receptor: int


class ClienteMercadoPagoPruebas:
    def __init__(self, cliente: httpx.AsyncClient, access_token: str):
        if not access_token:
            raise ValueError("Falta credencial de pruebas.")
        self._cliente = cliente
        self._token = access_token

    async def consultar(self, id_operacion: str) -> PagoProveedor:
        if not re.fullmatch(r"[0-9]{1,64}", id_operacion):
            raise NotificacionNoValida("Identificador no válido.")
        try:
            respuesta = await self._cliente.get(
                f"https://api.mercadopago.com/v1/payments/{id_operacion}",
                headers={"Authorization": f"Bearer {self._token}"},
                timeout=10,
                follow_redirects=False,
            )
            if respuesta.status_code != 200:
                raise ProveedorNoDisponible("No se obtuvo una respuesta válida del proveedor.")
            datos = respuesta.json()
            # Nunca confiar en live_mode ni status del webhook: se relee el recurso.
            if not isinstance(datos, dict) or datos.get("live_mode") is not False:
                raise NotificacionNoValida("La operación no corresponde al entorno de pruebas.")
            if str(datos.get("id")) != id_operacion:
                raise NotificacionNoValida("La operación consultada no coincide.")
            importe = Decimal(str(datos["transaction_amount"]))
            if not importe.is_finite() or importe < 0:
                raise ValueError
            estado, moneda, receptor = datos["status"], datos["currency_id"], datos["collector_id"]
            if (
                not isinstance(estado, str)
                or not estado
                or not isinstance(moneda, str)
                or not moneda
            ):
                raise ValueError
            if type(receptor) is not int or receptor <= 0:
                raise ValueError
            return PagoProveedor(id_operacion, estado, importe, moneda, receptor)
        except httpx.HTTPError:
            raise ProveedorNoDisponible("No se pudo consultar al proveedor.") from None
        except (KeyError, TypeError, ValueError, InvalidOperation):
            raise NotificacionNoValida("Respuesta del proveedor no válida.") from None
