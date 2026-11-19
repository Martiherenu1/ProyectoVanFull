"""Operaciones administrativas de vehículos (CU-022)."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import UsuarioActual, requiere_rol
from app.schemas.vehiculos import Vehiculo, VehiculoCreate, VehiculoUpdate
from app.services import vehiculos as servicio

router = APIRouter(prefix="/vehiculos", tags=["vehiculos"])


@router.get("", response_model=list[Vehiculo])
async def listar_vehiculos(
    _: UsuarioActual = Depends(requiere_rol("administrador", "dueno")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.listar_vehiculos(db)


@router.post("", response_model=Vehiculo, status_code=201)
async def crear_vehiculo(
    datos: VehiculoCreate,
    _: UsuarioActual = Depends(requiere_rol("administrador", "dueno")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.crear_vehiculo(db, datos)


@router.get("/{id_vehiculo}", response_model=Vehiculo)
async def consultar_vehiculo(
    id_vehiculo: int,
    _: UsuarioActual = Depends(requiere_rol("administrador", "dueno")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.consultar_vehiculo(db, id_vehiculo)


@router.patch("/{id_vehiculo}", response_model=Vehiculo)
async def actualizar_vehiculo(
    id_vehiculo: int,
    datos: VehiculoUpdate,
    _: UsuarioActual = Depends(requiere_rol("administrador", "dueno")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.actualizar_vehiculo(db, id_vehiculo, datos)
