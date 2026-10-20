"""Operaciones de cambio de estado del viaje asignado al chofer (CU-030)."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import UsuarioActual, requiere_rol
from app.schemas.viajes import Viaje
from app.services import ejecucion_viajes as servicio

router = APIRouter(prefix="/viajes", tags=["chofer"])


@router.post("/{id_viaje}/inicio", response_model=Viaje, response_model_exclude_none=True)
async def iniciar_viaje(
    id_viaje: int,
    usuario: UsuarioActual = Depends(requiere_rol("chofer")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.iniciar_viaje(db, usuario, id_viaje)


@router.post("/{id_viaje}/finalizacion", response_model=Viaje, response_model_exclude_none=True)
async def finalizar_viaje(
    id_viaje: int,
    usuario: UsuarioActual = Depends(requiere_rol("chofer")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.finalizar_viaje(db, usuario, id_viaje)
