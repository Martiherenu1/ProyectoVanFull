"""Aviso voluntario de ausencia (CU-008); identidad obtenida de la sesión."""

from pydantic import BaseModel


class AusenciaCreate(BaseModel):
    id_viaje: int


class Ausencia(BaseModel):
    id_ausencia: int
    id_pasajero: int
    id_viaje: int
