"""Salida de la consulta de servicios, disponibilidad y paradas (CU-002).

Nombres del contrato: `Servicio`, `Parada`, `Disponibilidad`. Son todos de lectura.
"""

from datetime import date

from pydantic import BaseModel


class Servicio(BaseModel):
    id_servicio: int
    tipo_servicio: str


class Parada(BaseModel):
    id_parada: int
    orden: int
    nombre_descripcion: str | None = None
    direccion: str | None = None
    # float y no Decimal: el contrato las declara `number`, y Decimal viajaría como texto.
    latitud: float | None = None
    longitud: float | None = None
    comprometida: bool


class Disponibilidad(BaseModel):
    id_viaje: int
    id_servicio: int
    id_recorrido: int
    fecha: date
    # "HH:MM", como el ejemplo del contrato. Un viaje en planificación puede no tener horario.
    horario: str | None = None
    sentido: str
    # Derivado, nunca persistido (MR-R30). Ausente cuando no se puede determinar: ver
    # services/disponibilidad.cupo_disponible.
    cupo_disponible: int | None = None
