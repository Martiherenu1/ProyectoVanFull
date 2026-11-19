"""Operaciones administrativas de choferes (CU-021)."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import UsuarioActual, requiere_rol
from app.schemas.choferes_admin import ChoferAdmin, ChoferAdminCreate, ChoferAdminUpdate
from app.services import choferes_admin as servicio

router = APIRouter(prefix="/choferes", tags=["choferes"])


@router.get("", response_model=list[ChoferAdmin])
async def listar_choferes(
    _: UsuarioActual = Depends(requiere_rol("administrador", "dueno")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.listar_choferes(db)


@router.post("", response_model=ChoferAdmin, status_code=201)
async def crear_chofer(
    datos: ChoferAdminCreate,
    _: UsuarioActual = Depends(requiere_rol("administrador", "dueno")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.crear_chofer(db, datos)


@router.get("/{id_persona}", response_model=ChoferAdmin)
async def consultar_chofer(
    id_persona: int,
    _: UsuarioActual = Depends(requiere_rol("administrador", "dueno")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.consultar_chofer(db, id_persona)


@router.patch("/{id_persona}", response_model=ChoferAdmin)
async def actualizar_chofer(
    id_persona: int,
    datos: ChoferAdminUpdate,
    _: UsuarioActual = Depends(requiere_rol("administrador", "dueno")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.actualizar_chofer(db, id_persona, datos)
