"""D1–D4 candidatos, solo sandbox estricto; CU-016 conserva su unidad contable."""

import asyncio
import logging
import re

from sqlalchemy import or_, select, text
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.core.errors import ApiError
from app.integrations.mercadopago import (
    ClienteMercadoPagoPruebas,
    NotificacionNoValida,
    ProveedorNoDisponible,
    validar_firma,
)
from app.models.cuenta_corriente import Pago
from app.models.mercadopago import PagoMercadoPago
from app.schemas.mercadopago import NotificacionMP
from app.services.mercadopago import VinculoOperacionPrueba, procesar_notificacion_prueba

logger = logging.getLogger(__name__)
PRESUPUESTO_SEGUNDOS = 15


def exigir_habilitado(ajustes: Settings) -> None:
    # No aceptar model_construct ni un perfil de usuarios ficticios como bypass.
    Settings.model_validate(ajustes.model_dump())
    if not ajustes.mercadopago_sandbox_enabled:
        raise ApiError(503, "INTEGRACION_NO_DISPONIBLE", "Integración de pruebas deshabilitada.")


def conflicto() -> ApiError:
    return ApiError(409, "VINCULO_PAGO_INVALIDO", "La operación y el pago no admiten este vínculo.")


async def vincular_operacion(
    db: AsyncSession,
    *,
    id_operacion: str,
    id_pago: int,
    proveedor: ClienteMercadoPagoPruebas,
    ajustes: Settings,
) -> str:
    """Alta explícita local D2, no endpoint; nunca confirma ni infiere external_reference."""
    exigir_habilitado(ajustes)
    try:
        async with asyncio.timeout(PRESUPUESTO_SEGUNDOS):
            operacion = await proveedor.consultar(id_operacion)
            if (
                operacion.moneda != ajustes.mercadopago_currency
                or operacion.id_receptor != ajustes.mercadopago_collector_id
            ):
                raise conflicto()
            await db.execute(text("SET LOCAL lock_timeout = '2s'"))
            pago = await db.scalar(select(Pago).where(Pago.id_pago == id_pago).with_for_update())
            if (
                pago is None
                or pago.medio_pago != "MERCADO_PAGO"
                or pago.importe != operacion.importe
            ):
                raise conflicto()
            existentes = (
                await db.scalars(
                    select(PagoMercadoPago).where(
                        or_(
                            PagoMercadoPago.id_pago == id_pago,
                            PagoMercadoPago.id_operacion == id_operacion,
                        )
                    )
                )
            ).all()
            if existentes:
                if len(existentes) != 1 or (
                    existentes[0].id_pago,
                    existentes[0].id_operacion,
                    existentes[0].moneda,
                    existentes[0].id_receptor,
                ) != (id_pago, id_operacion, operacion.moneda, operacion.id_receptor):
                    raise conflicto()
                await db.commit()
                return "vinculo_existente"
            if pago.estado != "PENDIENTE":
                raise conflicto()
            db.add(
                PagoMercadoPago(
                    id_operacion=id_operacion,
                    id_pago=id_pago,
                    moneda=operacion.moneda,
                    id_receptor=operacion.id_receptor,
                )
            )
            await db.commit()
            return "vinculado"
    except IntegrityError:
        await db.rollback()
        raise conflicto() from None
    except (TimeoutError, SQLAlchemyError):
        await db.rollback()
        raise ApiError(
            503, "INTEGRACION_NO_DISPONIBLE", "No se pudo completar el vínculo."
        ) from None
    except BaseException:
        await db.rollback()
        raise


async def procesar_webhook(
    db: AsyncSession,
    *,
    datos: NotificacionMP,
    data_id: str,
    request_id: str,
    firma: str,
    ahora: float,
    proveedor: ClienteMercadoPagoPruebas,
    ajustes: Settings,
) -> str:
    exigir_habilitado(ajustes)
    try:
        # Autenticidad antes de leer vínculo/base o consultar el proveedor.
        if not re.fullmatch(r"[A-Za-z0-9_-]{1,128}", request_id):
            raise NotificacionNoValida("Request ID no válido.")
        validar_firma(
            secreto=ajustes.mercadopago_webhook_secret.get_secret_value(),
            firma=firma,
            request_id=request_id,
            data_id=data_id,
            ahora=ahora,
            tolerancia_segundos=ajustes.mercadopago_webhook_tolerance_seconds,
        )
    except NotificacionNoValida:
        raise ApiError(
            401, "FIRMA_WEBHOOK_INVALIDA", "No se pudo autenticar la notificación."
        ) from None
    if datos.type != "payment" or datos.live_mode is not False or str(datos.data.id) != data_id:
        raise ApiError(
            400, "WEBHOOK_INVALIDO", "La notificación no corresponde al escenario de pruebas."
        )

    async def resolver(id_operacion: str):
        vinculo = await db.get(PagoMercadoPago, id_operacion)
        if vinculo is None and ajustes.mercadopago_checkout_enabled:
            from app.services.checkout import resolver_checkout

            return await resolver_checkout(
                db, await consulta.consultar(id_operacion), proveedor, ajustes
            )
        if vinculo is None or (
            vinculo.moneda != ajustes.mercadopago_currency
            or vinculo.id_receptor != ajustes.mercadopago_collector_id
        ):
            return None
        return VinculoOperacionPrueba(
            id_operacion, vinculo.id_pago, vinculo.moneda, vinculo.id_receptor
        )

    class ConsultaUnica:
        # Cache solo de esta entrega; nunca cache global del estado del proveedor.
        recurso = None

        async def consultar(self, id_operacion):
            if self.recurso is None:
                self.recurso = await proveedor.consultar(id_operacion)
            return self.recurso

    consulta = ConsultaUnica()
    try:
        async with asyncio.timeout(PRESUPUESTO_SEGUNDOS):
            await db.execute(text("SET LOCAL lock_timeout = '2s'"))
            resultado = await procesar_notificacion_prueba(
                db,
                cuerpo=datos.model_dump(),
                data_id=data_id,
                request_id=request_id,
                firma=firma,
                secreto=ajustes.mercadopago_webhook_secret.get_secret_value(),
                ahora=ahora,
                tolerancia_segundos=ajustes.mercadopago_webhook_tolerance_seconds,
                proveedor=consulta,
                resolver=resolver,
            )
            # El no_acreditado no escribe; finalizar igualmente su transacción antes del ACK.
            if db.in_transaction():
                await db.commit()
            logger.info("mercadopago_http_resultado=%s", resultado)
            return resultado
    except ProveedorNoDisponible:
        await db.rollback()
        raise ApiError(
            503, "PROVEEDOR_NO_DISPONIBLE", "No se pudo consultar al proveedor."
        ) from None
    except NotificacionNoValida:
        await db.rollback()
        raise conflicto() from None
    except (TimeoutError, SQLAlchemyError):
        await db.rollback()
        raise ApiError(
            503, "INTEGRACION_NO_DISPONIBLE", "No se pudo completar la operación."
        ) from None
    except Exception:
        await db.rollback()
        logger.error("mercadopago_http_resultado=error_interno")
        raise ApiError(500, "ERROR_INTERNO", "No se pudo completar la operación.") from None
    except BaseException:
        await db.rollback()
        raise
