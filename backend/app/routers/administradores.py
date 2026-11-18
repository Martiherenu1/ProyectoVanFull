"""Gestión de administradores (CU-032). Router fino: el rol y la delegación, nada más.

Exclusivo del dueño (RN-027): un administrador recibe 403.
"""

from fastapi import APIRouter, Depends, Path
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import UsuarioActual, requiere_rol
from app.schemas.administradores import (
    Administrador,
    AdministradorCreate,
    AdministradorLista,
    AdministradorUpdate,
)
from app.services import administradores as servicio

router = APIRouter(prefix="/administradores", tags=["administracion"])

_DUENO = Depends(requiere_rol("dueno"))


@router.get("", response_model=AdministradorLista, response_model_exclude_none=True)
async def listar_administradores(
    _: UsuarioActual = _DUENO, db: AsyncSession = Depends(get_db)
):
    return await servicio.listar_administradores(db)


@router.post(
    "", response_model=Administrador, response_model_exclude_none=True, status_code=201
)
async def crear_administrador(
    datos: AdministradorCreate, _: UsuarioActual = _DUENO, db: AsyncSession = Depends(get_db)
):
    return await servicio.crear_administrador(db, datos)


@router.get(
    "/{id_cuenta_acceso}", response_model=Administrador, response_model_exclude_none=True
)
async def consultar_administrador(
    id_cuenta_acceso: int = Path(gt=0),
    _: UsuarioActual = _DUENO,
    db: AsyncSession = Depends(get_db),
):
    return await servicio.obtener_administrador(db, id_cuenta_acceso)


@router.patch(
    "/{id_cuenta_acceso}", response_model=Administrador, response_model_exclude_none=True
)
async def modificar_administrador(
    datos: AdministradorUpdate,
    id_cuenta_acceso: int = Path(gt=0),
    _: UsuarioActual = _DUENO,
    db: AsyncSession = Depends(get_db),
):
    return await servicio.modificar_administrador(db, id_cuenta_acceso, datos)


@router.post(
    "/{id_cuenta_acceso}/deshabilitacion",
    response_model=Administrador,
    response_model_exclude_none=True,
)
async def deshabilitar_administrador(
    id_cuenta_acceso: int = Path(gt=0),
    _: UsuarioActual = _DUENO,
    db: AsyncSession = Depends(get_db),
):
    return await servicio.deshabilitar_administrador(db, id_cuenta_acceso)
