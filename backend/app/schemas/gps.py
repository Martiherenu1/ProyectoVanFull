"""Representaciones ya contratadas de GPS; sin columnas nuevas."""

from datetime import datetime

from pydantic import AwareDatetime, BaseModel, Field


class PosicionGpsCreate(BaseModel):
    latitud: float = Field(ge=-90, le=90, allow_inf_nan=False)
    longitud: float = Field(ge=-180, le=180, allow_inf_nan=False)
    fecha_hora_posicion: AwareDatetime | None = None


class ResultadoPosicionGps(BaseModel):
    actualizada: bool
    fecha_hora_posicion: datetime


class Ubicacion(BaseModel):
    id_viaje: int
    latitud: float
    longitud: float
    fecha_hora_posicion: datetime
    desactualizada: bool
    eta_minutos: int | None = None
