"""Salida de las reservas. Nombre del contrato: `Reserva`."""

from typing import Literal

from pydantic import BaseModel


class Reserva(BaseModel):
    """Una reserva tal como la declara el contrato v0.1.

    No trae la fecha ni el horario del viaje: el contrato no los incluye (Issue #31).
    """

    id_reserva: int
    id_pasajero: int
    id_viaje: int
    orden_parada: int
    # Los tres valores del CHECK de `reserva.estado` en schema.sql.
    estado: Literal["provisional", "consolidada", "cancelada"]
