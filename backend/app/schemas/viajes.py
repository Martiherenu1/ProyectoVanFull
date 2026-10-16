"""Entrada y salida de la creación de viajes (CU-018, cobertura parcial)."""

from datetime import date, time
from typing import Literal

from pydantic import BaseModel, Field


class ViajeCreate(BaseModel):
    """Datos aceptados por POST /viajes según el contrato OpenAPI vigente."""

    id_servicio: int
    id_recorrido: int
    id_vehiculo: int | None = None
    id_chofer: int | None = None
    fecha: date
    horario: time | None = None
    sentido: Literal["IDA", "VUELTA"]
    capacidad_planificada: int | None = Field(default=None, ge=0)


class Viaje(BaseModel):
    """Representación pública de un viaje declarada en OpenAPI."""

    id_viaje: int
    id_servicio: int
    id_recorrido: int
    id_vehiculo: int | None = None
    id_chofer: int | None = None
    fecha: date
    horario: str | None = None
    sentido: Literal["IDA", "VUELTA"]
    estado: Literal["programado", "en_curso", "finalizado", "cancelado"]
