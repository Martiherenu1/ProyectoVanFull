"""Entrada y salida de pagos según el contrato OpenAPI (CU-014 y CU-016)."""

from datetime import datetime
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, Field


class PagoCreate(BaseModel):
    # Administración lo indica; el pasajero lo omite y se usa su cliente individual.
    id_cliente: int | None = None
    importe: Decimal = Field(ge=0)
    medio_pago: Literal[
        "EFECTIVO", "TRANSFERENCIA", "BILLETERA", "CUENTA_CORRIENTE", "MERCADO_PAGO"
    ]
    tipo: Literal["total", "parcial", "senia"] | None = None
    evidencia_pago: str | None = None


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
