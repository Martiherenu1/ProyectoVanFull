"""Representaciones de descenso y estimaciones por reserva."""

from typing import Annotated

from pydantic import BaseModel, Field

Orden = Annotated[int, Field(gt=0, le=2147483647)]


class OrdenesDescenso(BaseModel):
    ordenes: list[Orden] = Field(max_length=200)


class PasoParada(BaseModel):
    orden_parada: Orden


class EtaReserva(BaseModel):
    ascenso_minutos: int | None = None
    destino_minutos: int | None = None
    ascenso_pasado: bool = False
    destino_pasado: bool = False
    vigencia_segundos: int = Field(default=0, ge=0)
