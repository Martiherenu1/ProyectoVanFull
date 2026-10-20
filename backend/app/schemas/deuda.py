"""Salida de la consulta de deuda propia (CU-006)."""

from pydantic import BaseModel


class Deuda(BaseModel):
    """Saldo deudor derivado y su estado vigente, según el contrato."""

    saldo: float
    estado: str
