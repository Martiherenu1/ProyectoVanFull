"""Entrada y salida de la creación de viajes (CU-018, cobertura parcial)."""

from datetime import date, time
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


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


class ViajeUpdate(BaseModel):
    """Campos modificables de un viaje programado respaldados por CU-018 y el modelo vigente."""

    model_config = ConfigDict(extra="forbid")

    id_vehiculo: int | None = None
    id_chofer: int | None = None
    fecha: date | None = None
    horario: time | None = None
    sentido: Literal["IDA", "VUELTA"] | None = None
    capacidad_planificada: int | None = Field(default=None, ge=0)

    @model_validator(mode="after")
    def validar_campos_presentes(self):
        if not self.model_fields_set:
            raise ValueError("Debe enviarse al menos un campo para actualizar.")
        for campo in ("fecha", "sentido"):
            if campo in self.model_fields_set and getattr(self, campo) is None:
                raise ValueError(f"{campo} no puede ser nulo.")
        return self


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
    capacidad_planificada: int | None = None
