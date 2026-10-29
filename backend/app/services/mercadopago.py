"""Procesamiento interno CU-036; no activado hasta resolver contrato/vínculo #215."""

import logging
from collections.abc import Awaitable, Callable
from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.integrations.mercadopago import (
    ClienteMercadoPagoPruebas,
    ErrorMercadoPago,
    NotificacionNoValida,
    validar_firma,
)
from app.models.cuenta_corriente import Pago
from app.services.pagos import decidir_pago_pendiente

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class VinculoOperacionPrueba:
    """Lo provee un resolvedor confiable, NO el payload ni external_reference.

    Pendiente: almacenamiento aprobado que garantice asociación única e inmutable
    de operación MP a pago local. No hay resolvedor de producción por defecto.
    Moneda/receptor se configuran explícitamente, nunca se asumen.
    """

    id_operacion: str
    id_pago: int
    moneda: str
    id_receptor: int


async def procesar_notificacion_prueba(
    db: AsyncSession,
    *,
    cuerpo: dict,
    data_id: str,
    request_id: str,
    firma: str,
    secreto: str,
    ahora: float,
    tolerancia_segundos: int,
    proveedor: ClienteMercadoPagoPruebas,
    resolver: Callable[[str], Awaitable[VinculoOperacionPrueba | None]],
) -> str:
    """Resultados técnicos internos; nunca son estados nuevos del pago o códigos HTTP."""
    try:
        validar_firma(
            secreto=secreto,
            firma=firma,
            request_id=request_id,
            data_id=data_id,
            ahora=ahora,
            tolerancia_segundos=tolerancia_segundos,
        )
        if cuerpo.get("type") != "payment" or cuerpo.get("live_mode") is not False:
            raise NotificacionNoValida("Notificación fuera del escenario de pruebas.")
        datos = cuerpo.get("data")
        if not isinstance(datos, dict) or str(datos.get("id")) != data_id:
            raise NotificacionNoValida("Identificadores de notificación inconsistentes.")
        vinculo = await resolver(data_id)
        if vinculo is None or vinculo.id_operacion != data_id:
            raise NotificacionNoValida("No hay una operación conocida vinculada.")
        operacion = await proveedor.consultar(data_id)
        if operacion.moneda != vinculo.moneda or operacion.id_receptor != vinculo.id_receptor:
            raise NotificacionNoValida("La operación no corresponde al vínculo configurado.")
        if operacion.estado != "approved":
            # No mapear pending/rejected/refunded a estados contables locales.
            logger.info("mercadopago_resultado=no_acreditado")
            return "no_acreditado"

        # Mismo lock que CU-016, sin adquirir locks de otras áreas después.
        pago = await db.scalar(
            select(Pago).where(Pago.id_pago == vinculo.id_pago).with_for_update()
        )
        if pago is None or pago.medio_pago != "MERCADO_PAGO" or pago.importe != operacion.importe:
            raise NotificacionNoValida("El pago no coincide con la operación vinculada.")
        if pago.estado == "CONFIRMADO":
            await db.commit()
            logger.info("mercadopago_resultado=duplicado")
            return "duplicado"
        if pago.estado != "PENDIENTE":
            raise NotificacionNoValida("El pago no admite confirmación automática.")
        # RN-015: acreditación válida confirma sin pedir segunda decisión humana.
        # Se reutilizan RECIBO, ACREEDOR y evento atómicos, sin duplicar reglas.
        await decidir_pago_pendiente(db, pago.id_pago, "CONFIRMADO")
        logger.info("mercadopago_resultado=confirmado")
        return "confirmado"
    except ErrorMercadoPago:
        logger.warning("mercadopago_resultado=incidente_validacion_o_proveedor")
        raise
