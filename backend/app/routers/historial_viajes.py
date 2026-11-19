"""Historial de viajes (CU-026). Router fino: el rol, los criterios y la delegación.

Administrador y dueño (ACT-05 y ACT-06). Solo GET: el historial no se modifica.
"""

from datetime import date
from typing import Literal

from fastapi import APIRouter, Depends, Path, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import UsuarioActual, requiere_rol
from app.schemas.historial_viajes import HistorialViajeDetalle, HistorialViajeLista
from app.services import historial_viajes as servicio

router = APIRouter(prefix="/administracion/historial-viajes", tags=["administracion"])

_ADMIN = Depends(requiere_rol("administrador", "dueno"))


@router.get("", response_model=HistorialViajeLista, response_model_exclude_none=True)
async def listar_historial(
    desde: date | None = None,
    hasta: date | None = None,
    estado: Literal["programado", "en_curso", "finalizado", "cancelado"] | None = None,
    id_servicio: int | None = Query(default=None, gt=0),
    id_chofer: int | None = Query(default=None, gt=0),
    id_vehiculo: int | None = Query(default=None, gt=0),
    sentido: Literal["IDA", "VUELTA"] | None = None,
    limite: int = Query(default=50, ge=1, le=200),
    desplazamiento: int = Query(default=0, ge=0),
    _: UsuarioActual = _ADMIN,
    db: AsyncSession = Depends(get_db),
):
    return await servicio.listar(
        db,
        desde=desde,
        hasta=hasta,
        estado=estado,
        id_servicio=id_servicio,
        id_chofer=id_chofer,
        id_vehiculo=id_vehiculo,
        sentido=sentido,
        limite=limite,
        desplazamiento=desplazamiento,
    )


@router.get("/{id_viaje}", response_model=HistorialViajeDetalle, response_model_exclude_none=True)
async def consultar_historial(
    id_viaje: int = Path(gt=0), _: UsuarioActual = _ADMIN, db: AsyncSession = Depends(get_db)
):
    return await servicio.detalle(db, id_viaje)
