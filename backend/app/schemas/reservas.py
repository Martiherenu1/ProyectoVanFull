"""Salida de las reservas. Nombre del contrato: `Reserva`."""

from datetime import date
from typing import Literal

from pydantic import BaseModel


class Reserva(BaseModel):
    """Una reserva con los datos del viaje que el pasajero necesita para reconocerla.

    `id_recorrido`, `fecha`, `horario` y `sentido` son del viaje (Issue #31): salen del `JOIN` con
    `viaje`, no son columnas de `reserva` salvo `id_recorrido`.
    """

    id_reserva: int
    id_pasajero: int
    id_viaje: int
    id_recorrido: int
    orden_parada: int
    fecha: date
    # "HH:MM", como en `Disponibilidad`. Un viaje en planificación puede no tener horario.
    horario: str | None = None
    # Los dos valores del CHECK de `viaje.sentido` en schema.sql.
    sentido: Literal["IDA", "VUELTA"]
    # Los tres valores del CHECK de `reserva.estado` en schema.sql.
    estado: Literal["provisional", "consolidada", "cancelada"]
