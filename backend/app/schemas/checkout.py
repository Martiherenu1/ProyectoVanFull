"""Contrato candidato de inicio/consulta propia. No contiene credenciales MP."""

from decimal import Decimal
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.pagos import Pago


class IniciarCheckout(BaseModel):
    model_config = ConfigDict(extra="forbid")
    importe: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    medio_pago: Literal["MERCADO_PAGO"]
    clave_solicitud: UUID


class CheckoutOut(BaseModel):
    pago: Pago
    estado_checkout: Literal["CREANDO", "LISTO", "INCIERTO"]
    checkout_url: str | None = None
