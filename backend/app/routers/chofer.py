"""Consultas del chofer (CU-029): rutas contratadas, sin lógica de negocio."""

from datetime import date

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import UsuarioActual, requiere_rol
from app.schemas.chofer import OperacionAsignada
from app.schemas.viajes import Viaje
from app.services import chofer as servicio

router = APIRouter(prefix="/choferes/me/viajes", tags=["chofer"])


@router.get("", response_model=list[Viaje], response_model_exclude_none=True)
async def consultar_viajes_asignados(
    fecha: date | None = None,
    usuario: UsuarioActual = Depends(requiere_rol("chofer")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.listar_viajes_propios(db, usuario, fecha)


@router.get(
    "/{id_viaje}",
    response_model=OperacionAsignada,
    response_model_exclude_unset=True,
)
async def consultar_detalle_viaje(
    id_viaje: int,
    usuario: UsuarioActual = Depends(requiere_rol("chofer")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.detalle_viaje_propio(db, usuario, id_viaje)
