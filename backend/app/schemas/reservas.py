"""Entrada y salida de las reservas. Nombres del contrato: `ReservaCreate`, `Reserva`."""

from datetime import date
from typing import Literal

from pydantic import BaseModel, Field


class ReservaCreate(BaseModel):
    id_viaje: int
    # Parada de ascenso dentro del recorrido del viaje. Los órdenes empiezan en 1.
    orden_parada: int = Field(ge=1)


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


class ResultadoCancelacion(BaseModel):
    """Resultado de cancelar una reserva (CU-004): la reserva ya cancelada y su consecuencia."""

    reserva: Reserva
    # true si la cancelación devolvió un lugar al viaje (RN-001, RN-002).
    cupo_liberado: bool
    penalidad_aplicada: bool
    importe_penalidad: float
    # La regla que decidió: dice también cuando la consecuencia económica todavía no se aplica.
    motivo: str
