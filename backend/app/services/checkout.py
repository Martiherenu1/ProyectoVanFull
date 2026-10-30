"""Saga local candidata: DB antes de POST remoto; repetir intención solo reconcilia GET."""

import asyncio
from uuid import UUID, uuid4

from sqlalchemy import or_, select, text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.core.errors import ApiError
from app.core.security import UsuarioActual
from app.integrations.checkout import ClienteCheckoutPruebas
from app.integrations.mercadopago import ErrorMercadoPago, NotificacionNoValida, PagoProveedor
from app.models.checkout import CheckoutMercadoPago
from app.models.cuenta_corriente import CuentaCorriente, Pago
from app.models.mercadopago import PagoMercadoPago
from app.schemas.checkout import CheckoutOut, IniciarCheckout
from app.services import pagos
from app.services.mercadopago import VinculoOperacionPrueba


def exigir_checkout(ajustes: Settings):
    Settings.model_validate(ajustes.model_dump())
    if not ajustes.mercadopago_checkout_enabled:
        raise ApiError(503, "CHECKOUT_NO_DISPONIBLE", "Checkout no está habilitado.")


def _salida(pago: Pago, intento: CheckoutMercadoPago) -> CheckoutOut:
    return CheckoutOut(
        pago=pagos._a_schema(pago),
        estado_checkout=intento.estado_tecnico,
        checkout_url=intento.url_checkout if pago.estado == "PENDIENTE" else None,
    )


async def _bloquear(db, id_pago: int, id_intento: str):
    await db.execute(text("SET LOCAL lock_timeout = '2s'"))
    pago = await db.scalar(
        select(Pago)
        .where(Pago.id_pago == id_pago)
        .with_for_update()
        .execution_options(populate_existing=True)
    )
    intento = await db.scalar(
        select(CheckoutMercadoPago)
        .where(CheckoutMercadoPago.id_intento == id_intento)
        .with_for_update()
        .execution_options(populate_existing=True)
    )
    if pago is None or intento is None or intento.id_pago != pago.id_pago:
        raise NotificacionNoValida("Intención no válida.")
    return pago, intento


async def iniciar_checkout(
    db: AsyncSession,
    usuario: UsuarioActual,
    datos: IniciarCheckout,
    proveedor: ClienteCheckoutPruebas,
    ajustes: Settings,
) -> CheckoutOut:
    exigir_checkout(ajustes)
    try:
        id_cliente = await pagos._cliente_del_pasajero(db, usuario, None)
        # Solo el alta toma cuenta corriente; libera antes de tocar red externa.
        await db.execute(text("SET LOCAL lock_timeout = '2s'"))
        await db.scalar(
            select(CuentaCorriente)
            .where(CuentaCorriente.id_cliente == id_cliente)
            .with_for_update()
        )
        intento = await db.scalar(
            select(CheckoutMercadoPago).where(
                CheckoutMercadoPago.id_cliente == id_cliente,
                CheckoutMercadoPago.clave_solicitud == str(datos.clave_solicitud),
            )
        )
        nuevo = intento is None
        if nuevo:
            pago = await pagos.preparar_pago_pendiente(
                db, id_cliente=id_cliente, importe=datos.importe, medio_pago="MERCADO_PAGO"
            )
            intento = CheckoutMercadoPago(
                id_intento=str(uuid4()),
                id_pago=pago.id_pago,
                id_cliente=id_cliente,
                clave_solicitud=str(datos.clave_solicitud),
                estado_tecnico="CREANDO",
            )
            db.add(intento)
            await db.flush()
        else:
            pago = await db.get(Pago, intento.id_pago)
            if pago is None or pago.importe != datos.importe or pago.medio_pago != "MERCADO_PAGO":
                raise ApiError(
                    409,
                    "CHECKOUT_CLAVE_REUTILIZADA",
                    "La clave ya corresponde a otro importe o método.",
                )
        id_pago, id_intento = pago.id_pago, intento.id_intento
        listo = intento.estado_tecnico == "LISTO" or pago.estado != "PENDIENTE"
        salida = _salida(pago, intento)
        await db.commit()
        if listo:
            return salida

        preferencia = None
        try:
            async with asyncio.timeout(15):
                if nuevo:
                    preferencia = await proveedor.crear_preferencia(
                        referencia=id_intento,
                        importe=datos.importe,
                        moneda=ajustes.mercadopago_currency,
                        receptor=ajustes.mercadopago_collector_id,
                        retorno=ajustes.mercadopago_checkout_return_url,
                        webhook=ajustes.mercadopago_checkout_webhook_url,
                    )
                else:
                    preferencia = await proveedor.buscar_preferencia(
                        id_intento, ajustes.mercadopago_collector_id
                    )
        except (ErrorMercadoPago, TimeoutError):
            # POST podría haber sido aceptado. No repetirlo ni borrar Pago/intención.
            preferencia = None
        pago, intento = await _bloquear(db, id_pago, id_intento)
        if preferencia is not None:
            if (
                preferencia.importe != pago.importe
                or preferencia.moneda != ajustes.mercadopago_currency
            ):
                raise ApiError(
                    409,
                    "CHECKOUT_ASOCIACION_INVALIDA",
                    "El importe o moneda de la preferencia no coincide.",
                )
            if intento.id_preferencia not in {None, preferencia.id}:
                raise ApiError(
                    409, "CHECKOUT_ASOCIACION_AMBIGUA", "La intención tiene otra preferencia."
                )
            intento.id_preferencia, intento.url_checkout = preferencia.id, preferencia.url
            intento.estado_tecnico = "LISTO"
        elif intento.estado_tecnico != "LISTO":
            intento.estado_tecnico = "INCIERTO"
        salida = _salida(pago, intento)
        await db.commit()
        return salida
    except ApiError:
        await db.rollback()
        raise
    except (SQLAlchemyError, TimeoutError):
        await db.rollback()
        raise ApiError(
            503,
            "CHECKOUT_NO_DISPONIBLE",
            "No se pudo completar el inicio. Conservá la misma solicitud para reintentar.",
        ) from None
    except BaseException:
        await db.rollback()
        raise


async def consultar_pago_propio(
    db: AsyncSession, usuario: UsuarioActual, id_pago: int
) -> pagos.Pago:
    id_cliente = await pagos._cliente_del_pasajero(db, usuario, None)
    pago = await db.scalar(
        select(Pago).where(Pago.id_pago == id_pago, Pago.id_cliente == id_cliente)
    )
    if pago is None:
        raise ApiError(404, "PAGO_NO_ENCONTRADO", "No se encontró el pago propio.")
    return pagos._a_schema(pago)


async def resolver_checkout(
    db: AsyncSession, operacion: PagoProveedor, proveedor: ClienteCheckoutPruebas, ajustes: Settings
) -> VinculoOperacionPrueba:
    """Solo después de HMAC y Payments estricto. Conservar vínculo histórico ya conocido."""
    exigir_checkout(ajustes)
    try:
        referencia = str(UUID(operacion.referencia or ""))
    except ValueError:
        raise NotificacionNoValida("Sin correlación de Checkout conocida.") from None
    intento = await db.get(CheckoutMercadoPago, referencia)
    if (
        intento is None
        or operacion.id_orden is None
        or operacion.moneda != ajustes.mercadopago_currency
        or operacion.id_receptor != ajustes.mercadopago_collector_id
    ):
        raise NotificacionNoValida("Operación ajena a una intención conocida.")
    id_pref = await proveedor.orden_de_pago(
        operacion.id_orden, operacion.id_operacion, referencia, ajustes.mercadopago_collector_id
    )
    pago, intento = await _bloquear(db, intento.id_pago, referencia)
    if (
        pago.medio_pago != "MERCADO_PAGO"
        or pago.importe != operacion.importe
        or intento.id_preferencia not in {None, id_pref}
    ):
        raise NotificacionNoValida("La preferencia o el importe no coincide.")
    if operacion.estado == "approved":
        existentes = (
            await db.scalars(
                select(PagoMercadoPago).where(
                    or_(
                        PagoMercadoPago.id_pago == pago.id_pago,
                        PagoMercadoPago.id_operacion == operacion.id_operacion,
                    )
                )
            )
        ).all()
        if existentes and (
            len(existentes) != 1
            or existentes[0].id_operacion != operacion.id_operacion
            or existentes[0].id_pago != pago.id_pago
        ):
            raise NotificacionNoValida(
                "Segunda operación distinta para el mismo pago; requiere conciliación."
            )
        if not existentes:
            if pago.estado != "PENDIENTE":
                raise NotificacionNoValida("El pago ya fue decidido por otro circuito.")
            db.add(
                PagoMercadoPago(
                    id_operacion=operacion.id_operacion,
                    id_pago=pago.id_pago,
                    moneda=operacion.moneda,
                    id_receptor=operacion.id_receptor,
                )
            )
        intento.id_preferencia = id_pref
        await db.flush()
    # No approved no fija operación: otro intento aprobado puede llegar luego.
    return VinculoOperacionPrueba(
        operacion.id_operacion, pago.id_pago, operacion.moneda, operacion.id_receptor
    )
