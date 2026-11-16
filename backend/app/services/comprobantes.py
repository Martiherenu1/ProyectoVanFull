"""Consulta de comprobantes propios del pasajero (CU-035, RF-037, RN-028).

Solo lectura: no crea, modifica ni descarga comprobantes, y no toca la lógica contable de
`services/pagos.py` (los RECIBO los genera CU-016 al confirmar un pago).

Qué es «propio». La tabla `comprobante` guarda el tipo y exactamente un origen (MR-R28): un
pago (RECIBO), una contratación (FACTURA) o un movimiento de cuenta (nota de crédito o de débito).
Los tres orígenes tienen `id_cliente`, así que un comprobante es del pasajero si su origen es de
su cliente individual. Los demás no se listan y, pedidos por id, responden el mismo 404 que uno
inexistente (A2: no se confirma que existan).
"""

from sqlalchemy import Select, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.core.security import UsuarioActual
from app.models.cuenta_corriente import Comprobante, MovimientoCuenta, Pago
from app.models.personas import ClienteIndividual
from app.models.servicios import Contratacion
from app.schemas.comprobantes import ComprobantePropio


async def _cliente_individual(db: AsyncSession, usuario: UsuarioActual) -> int | None:
    """El cliente individual del pasajero; no existe hasta que reserva o paga por primera vez."""
    return await db.scalar(
        select(ClienteIndividual.id_cliente).where(
            ClienteIndividual.id_persona == usuario.id_persona
        )
    )


def _consulta_propios(id_cliente: int) -> Select:
    """Comprobantes cuyo único origen pertenece a `id_cliente`, con los datos de ese origen."""
    return (
        select(Comprobante, Pago, Contratacion, MovimientoCuenta)
        .outerjoin(Pago, Pago.id_pago == Comprobante.id_pago)
        .outerjoin(Contratacion, Contratacion.id_contratacion == Comprobante.id_contratacion)
        .outerjoin(
            MovimientoCuenta,
            MovimientoCuenta.id_movimiento_cuenta == Comprobante.id_movimiento_cuenta,
        )
        # Un solo origen por comprobante (MR-R28): basta con que el presente sea del cliente.
        .where(
            or_(
                Pago.id_cliente == id_cliente,
                Contratacion.id_cliente == id_cliente,
                MovimientoCuenta.id_cliente == id_cliente,
            )
        )
    )


def _a_schema(
    comprobante: Comprobante,
    pago: Pago | None,
    contratacion: Contratacion | None,
    movimiento: MovimientoCuenta | None,
) -> ComprobantePropio:
    if pago is not None:
        fecha_hora, importe, medio_pago = pago.fecha_hora, pago.importe, pago.medio_pago
    elif movimiento is not None:
        fecha_hora, importe, medio_pago = movimiento.fecha_hora, movimiento.importe, None
    else:
        # FACTURA: la contratación no guarda fecha y el importe acordado es opcional.
        fecha_hora, importe, medio_pago = None, contratacion.importe_acordado, None
    return ComprobantePropio(
        id_comprobante=comprobante.id_comprobante,
        tipo=comprobante.tipo,
        id_pago=comprobante.id_pago,
        id_contratacion=comprobante.id_contratacion,
        id_movimiento_cuenta=comprobante.id_movimiento_cuenta,
        fecha_hora=fecha_hora,
        importe=None if importe is None else float(importe),
        medio_pago=medio_pago,
    )


async def listar_propios(db: AsyncSession, usuario: UsuarioActual) -> list[ComprobantePropio]:
    """Comprobantes del pasajero por `id_comprobante` ascendente; sin cliente, lista vacía (A1)."""
    id_cliente = await _cliente_individual(db, usuario)
    if id_cliente is None:
        return []
    filas = await db.execute(_consulta_propios(id_cliente).order_by(Comprobante.id_comprobante))
    return [_a_schema(*fila) for fila in filas.all()]


async def obtener_propio(
    db: AsyncSession, usuario: UsuarioActual, id_comprobante: int
) -> ComprobantePropio:
    """Un comprobante propio; uno ajeno o inexistente responde el mismo 404 (A2)."""
    id_cliente = await _cliente_individual(db, usuario)
    fila = None
    if id_cliente is not None:
        fila = (
            await db.execute(
                _consulta_propios(id_cliente).where(Comprobante.id_comprobante == id_comprobante)
            )
        ).one_or_none()
    if fila is None:
        raise ApiError(404, "COMPROBANTE_NO_ENCONTRADO", "No se encontró el comprobante.")
    return _a_schema(*fila)
