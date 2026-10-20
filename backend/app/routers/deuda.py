"""Endpoint de consulta de deuda propia (CU-006)."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import UsuarioActual, requiere_rol
from app.schemas.deuda import Deuda
from app.services import deuda as servicio

router = APIRouter(tags=["pasajero"])


@router.get("/pasajeros/me/deuda", response_model=Deuda)
async def consultar_deuda_propia(
    usuario: UsuarioActual = Depends(requiere_rol("pasajero")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.consultar_deuda_propia(db, usuario)
