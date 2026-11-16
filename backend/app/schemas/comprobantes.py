"""Salida de la consulta de comprobantes propios (CU-035)."""

from datetime import datetime

from pydantic import BaseModel


class ComprobantePropio(BaseModel):
    """Un comprobante y los datos de su único origen (MR-R28).

    La tabla `comprobante` no guarda fecha, importe ni medio: salen del pago, la contratación o el
    movimiento que lo origina. Una FACTURA no tiene fecha porque `contratacion` no la guarda.
    """

    id_comprobante: int
    tipo: str
    id_pago: int | None
    id_contratacion: int | None
    id_movimiento_cuenta: int | None
    fecha_hora: datetime | None
    # El contrato declara `number`, igual que en `Pago`: se expone float y no Decimal como texto.
    importe: float | None
    medio_pago: str | None
