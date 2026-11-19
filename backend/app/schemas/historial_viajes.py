"""Salida del historial de viajes (CU-026). Solo lectura: no hay esquemas de entrada.

Nombres del contrato: `HistorialViaje`, `HistorialViajeLista`, `HistorialViajeDetalle`,
`HistorialPersona`, `HistorialVehiculo`, `HistorialParada`, `HistorialConteos`.
"""

from datetime import date
from typing import Literal

from pydantic import BaseModel


class HistorialPersona(BaseModel):
    id_persona: int
    nombre: str
    apellido: str


class HistorialVehiculo(BaseModel):
    id_vehiculo: int
    patente: str


class HistorialViaje(BaseModel):
    id_viaje: int
    fecha: date
    horario: str | None = None
    sentido: Literal["IDA", "VUELTA"]
    estado: Literal["programado", "en_curso", "finalizado", "cancelado"]
    id_servicio: int
    tipo_servicio: str
    id_recorrido: int
    chofer: HistorialPersona | None = None
    vehiculo: HistorialVehiculo | None = None


class HistorialViajeLista(BaseModel):
    items: list[HistorialViaje]
    # Total que cumple los criterios, sin contar la paginación.
    total: int


class HistorialParada(BaseModel):
    orden: int
    id_parada: int
    nombre_descripcion: str | None = None


class HistorialConteos(BaseModel):
    """Solo cantidades: el historial no expone datos personales de los pasajeros."""

    reservas_provisionales: int
    reservas_consolidadas: int
    reservas_canceladas: int
    abordajes: int
    ausencias: int


class HistorialViajeDetalle(HistorialViaje):
    capacidad_planificada: int | None = None
    paradas: list[HistorialParada]
    conteos: HistorialConteos
