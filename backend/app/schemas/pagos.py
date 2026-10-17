"""Entrada y salida de pagos según el contrato OpenAPI (CU-016)."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel


class DecisionPago(BaseModel):
    decision: Literal["CONFIRMADO", "RECHAZADO"]


class Pago(BaseModel):
    id_pago: int
    id_cliente: int
    # El contrato declara `number`; por eso la respuesta expone float y no Decimal como texto.
    importe: float
    medio_pago: str
    estado: Literal["PENDIENTE", "CONFIRMADO", "RECHAZADO"]
    fecha_hora: datetime
