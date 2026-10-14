"""Servicios ofrecidos y paradas de un recorrido (CU-002, RF-019). Solo lectura."""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.models.servicios import Servicio as ServicioModelo
from app.models.viajes import Parada as ParadaModelo
from app.models.viajes import ParadaRecorrido, Recorrido
from app.schemas.servicios import Parada, Servicio


async def listar_servicios(db: AsyncSession) -> list[Servicio]:
    filas = (
        await db.execute(select(ServicioModelo).order_by(ServicioModelo.id_servicio))
    ).scalars()
    return [Servicio(id_servicio=s.id_servicio, tipo_servicio=s.tipo_servicio) for s in filas]


async def paradas_de_recorrido(db: AsyncSession, id_recorrido: int) -> list[Parada]:
    """Las paradas en el orden en que el recorrido las visita. 404 si el recorrido no existe."""
    existe = await db.scalar(
        select(Recorrido.id_recorrido).where(Recorrido.id_recorrido == id_recorrido)
    )
    if existe is None:
        raise ApiError(404, "RECORRIDO_NO_ENCONTRADO", "El recorrido no existe.")

    filas = await db.execute(
        select(ParadaRecorrido, ParadaModelo)
        .join(ParadaModelo, ParadaModelo.id_parada == ParadaRecorrido.id_parada)
        .where(ParadaRecorrido.id_recorrido == id_recorrido)
        .order_by(ParadaRecorrido.orden)
    )
    return [
        Parada(
            id_parada=parada.id_parada,
            orden=en_recorrido.orden,
            nombre_descripcion=parada.nombre_descripcion,
            direccion=parada.direccion,
            latitud=float(parada.latitud) if parada.latitud is not None else None,
            longitud=float(parada.longitud) if parada.longitud is not None else None,
            comprometida=en_recorrido.comprometida,
        )
        for en_recorrido, parada in filas.all()
    ]
