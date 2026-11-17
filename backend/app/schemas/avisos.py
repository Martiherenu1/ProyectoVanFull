"""Reporte manual CU-030; comunicación no evaluada hasta integrar CU-037."""

from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class AvisoCrear(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    clase: Literal["demora", "problema"]
    descripcion_interna: str = Field(min_length=1, max_length=2000)
    clave_solicitud: UUID


class Aviso(BaseModel):
    id_evento_operativo: int
    id_viaje: int
    clase: Literal["demora", "problema"]
    descripcion_interna: str
    id_cuenta_autora: int
    clave_solicitud: UUID
    fecha_hora_registro: datetime
    registro: Literal["confirmado"] = "confirmado"
    notificacion: Literal["no_evaluada"] = "no_evaluada"


class MensajeDemora(BaseModel):
    id_viaje: int
    mensaje: str | None = None
    fecha_hora_reporte: datetime | None = None
