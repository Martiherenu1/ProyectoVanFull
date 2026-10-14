"""Endpoints del perfil del pasajero (CU-001). Router fino: el rol y la delegación, nada más."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import UsuarioActual, requiere_rol
from app.schemas.perfil import PerfilPasajero, PerfilPasajeroUpdate
from app.services import perfil as servicio

router = APIRouter(prefix="/pasajeros", tags=["pasajero"])

# exclude_none: lo que el pasajero no tiene cargado no aparece, en vez de ir como null, que el
# contrato (campos `type: string` sin `nullable`) no admite.


@router.get("/me", response_model=PerfilPasajero, response_model_exclude_none=True)
async def consultar_perfil(
    usuario: UsuarioActual = Depends(requiere_rol("pasajero")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.obtener_perfil(db, usuario)


@router.patch("/me", response_model=PerfilPasajero, response_model_exclude_none=True)
async def modificar_perfil(
    datos: PerfilPasajeroUpdate,
    usuario: UsuarioActual = Depends(requiere_rol("pasajero")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.modificar_perfil(db, usuario, datos)
