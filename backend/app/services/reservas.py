"""Reservas del pasajero. Por ahora, solo la consulta (CU-010, RF-043).

Crear (CU-003), cancelar (CU-004) y cambiar de parada (CU-005) se suman acá cuando sus reglas estén
definidas. `reserva` es una tabla de este módulo: lo que otras áreas necesiten de ella lo piden por
estas funciones.
"""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.core.security import UsuarioActual
from app.models.viajes import Reserva as ReservaModelo
from app.models.viajes import Viaje
from app.schemas.reservas import Reserva


def _a_schema(r: ReservaModelo) -> Reserva:
    return Reserva(
        id_reserva=r.id_reserva,
        id_pasajero=r.id_pasajero,
        id_viaje=r.id_viaje,
        orden_parada=r.orden_parada,
        estado=r.estado,
    )


async def listar_reservas_del_pasajero(db: AsyncSession, usuario: UsuarioActual) -> list[Reserva]:
    """Todas las reservas del pasajero, de cualquier estado, la más reciente primero.

    CU-010 pide "las reservas que le corresponden" con su estado: las canceladas también son suyas.
    El orden no está definido en la especificación; es el de la fecha del viaje, descendente.
    """
    consulta = (
        select(ReservaModelo)
        .join(Viaje, Viaje.id_viaje == ReservaModelo.id_viaje)
        .where(ReservaModelo.id_pasajero == usuario.id_persona)
        .order_by(
            Viaje.fecha.desc(), Viaje.horario.desc().nulls_last(), ReservaModelo.id_reserva.desc()
        )
    )
    return [_a_schema(r) for r in (await db.execute(consulta)).scalars()]


async def obtener_reserva_del_pasajero(
    db: AsyncSession, usuario: UsuarioActual, id_reserva: int
) -> Reserva:
    """El detalle de una reserva propia. Una ajena responde igual que una que no existe: 404.

    Así quien consulta no puede averiguar qué reservas existen (CONVENCIONES.md §3).
    """
    reserva = (
        await db.execute(
            select(ReservaModelo).where(
                ReservaModelo.id_reserva == id_reserva,
                ReservaModelo.id_pasajero == usuario.id_persona,
            )
        )
    ).scalar_one_or_none()
    if reserva is None:
        raise ApiError(404, "RESERVA_NO_ENCONTRADA", "La reserva no existe.")
    return _a_schema(reserva)
