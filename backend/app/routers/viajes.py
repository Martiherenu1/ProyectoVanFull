"""Operaciones de administración sobre viajes (CU-018, cobertura parcial)."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import UsuarioActual, requiere_rol
from app.schemas.viajes import Viaje, ViajeCreate
from app.services import viajes as servicio

router = APIRouter(prefix="/viajes", tags=["viajes"])


@router.post("", response_model=Viaje, response_model_exclude_none=True, status_code=201)
async def crear_viaje(
    datos: ViajeCreate,
    _: UsuarioActual = Depends(requiere_rol("administrador", "dueno")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.crear_viaje(db, datos)
