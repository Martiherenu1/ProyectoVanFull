"""Respuestas de las consultas operativas del chofer (CU-029).

Usan los mismos nombres del contrato aprobado; las cantidades no representan disponibilidad.
"""

from pydantic import BaseModel, Field

from app.schemas.servicios import Parada
from app.schemas.viajes import Viaje


class PasajeroOperacion(BaseModel):
    id_reserva: int
    id_pasajero: int
    id_viaje: int
    orden_parada: int
    estado: str
    nombre: str
    apellido: str
    dni: str
    fotografia: str | None  # Requerida por el contrato, pero admite null.
    abordaje_registrado: bool


class IntegranteNominaOperacion(BaseModel):
    id_integrante_nomina: int
    nombre: str
    apellido: str
    dni: str


class CantidadesOperacion(BaseModel):
    consolidadas: int = Field(ge=0)
    provisionales: int = Field(ge=0)
    total_reservas: int = Field(ge=0)
    total_nomina: int = Field(ge=0)
    abordajes_registrados: int = Field(ge=0)


class OperacionAsignada(BaseModel):
    viaje: Viaje
    capacidad_planificada: int | None
    paradas: list[Parada]
    pasajeros_con_reserva: list[PasajeroOperacion]
    integrantes_nomina: list[IntegranteNominaOperacion]
    cantidades: CantidadesOperacion
