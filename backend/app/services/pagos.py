"""Confirmación o rechazo manual de pagos (CU-016, RF-011, RN-015)."""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.models.cuenta_corriente import Comprobante, MovimientoCuenta
from app.models.cuenta_corriente import Pago as PagoModelo
from app.schemas.pagos import Pago
from app.services.eventos import registrar_evento

TIPO_PAGO_CONFIRMADO = "pago_confirmado"
TIPO_PAGO_RECHAZADO = "pago_rechazado"


def _a_schema(pago: PagoModelo) -> Pago:
    return Pago(
        id_pago=pago.id_pago,
        id_cliente=pago.id_cliente,
        importe=float(pago.importe),
        medio_pago=pago.medio_pago,
        estado=pago.estado,
        fecha_hora=pago.fecha_hora,
    )


async def decidir_pago_pendiente(db: AsyncSession, id_pago: int, decision: str) -> Pago:
    """Decide un pago pendiente y registra todo en una única transacción.

    El bloqueo de la fila evita que dos administradores decidan el mismo pago a la vez. El filtro
    por PENDIENTE también impide revalidar un pago que ya fue confirmado automáticamente.
    """
    pago = (
        await db.execute(
            select(PagoModelo)
            .where(PagoModelo.id_pago == id_pago, PagoModelo.estado == "PENDIENTE")
            .with_for_update()
        )
    ).scalar_one_or_none()
    if pago is None:
        raise ApiError(
            404,
            "PAGO_PENDIENTE_NO_ENCONTRADO",
            "No se encontró un pago pendiente con ese identificador.",
        )

    pago.estado = decision
    if decision == "CONFIRMADO":
        db.add(Comprobante(tipo="RECIBO", id_pago=pago.id_pago))
        db.add(
            MovimientoCuenta(
                id_cliente=pago.id_cliente,
                id_pago=pago.id_pago,
                naturaleza="ACREEDOR",
                importe=pago.importe,
            )
        )

    # Fuerza ahora los controles contables y del comprobante, antes de agregar el evento.
    await db.flush()
    await registrar_evento(
        db,
        tipo_evento=(TIPO_PAGO_CONFIRMADO if decision == "CONFIRMADO" else TIPO_PAGO_RECHAZADO),
        id_pago=pago.id_pago,
    )
    await db.commit()
    return _a_schema(pago)
