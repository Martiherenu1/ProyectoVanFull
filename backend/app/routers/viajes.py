"""Operaciones de administración sobre viajes (CU-018, cobertura parcial)."""

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends
from pydantic import BeforeValidator
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import UsuarioActual, requiere_rol
from app.schemas.viajes import Viaje, ViajeCreate, ViajeUpdate
from app.services import viajes as servicio

router = APIRouter(prefix="/viajes", tags=["viajes"])


def _fecha_iso(valor: object) -> date:
    """Acepta exclusivamente YYYY-MM-DD; Pydantic también aceptaría medianoche como datetime."""
    if not isinstance(valor, str):
        raise ValueError("La fecha debe usar el formato YYYY-MM-DD.")
    try:
        fecha = date.fromisoformat(valor)
    except ValueError as error:
        raise ValueError("La fecha debe usar el formato YYYY-MM-DD.") from error
    if fecha.isoformat() != valor:
        raise ValueError("La fecha debe usar el formato YYYY-MM-DD.")
    return fecha


FechaConsulta = Annotated[date, BeforeValidator(_fecha_iso)]


@router.post("/{id_viaje}/cancelacion", response_model=Viaje, response_model_exclude_none=True)
async def cancelar_viaje(
    id_viaje: int,
    _: UsuarioActual = Depends(requiere_rol("administrador", "dueno")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.cancelar_viaje(db, id_viaje)


@router.get("", response_model=list[Viaje], response_model_exclude_none=True)
async def listar_viajes(
    fecha: FechaConsulta,
    _: UsuarioActual = Depends(requiere_rol("administrador", "dueno")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.listar_viajes(db, fecha)


@router.post("", response_model=Viaje, response_model_exclude_none=True, status_code=201)
async def crear_viaje(
    datos: ViajeCreate,
    _: UsuarioActual = Depends(requiere_rol("administrador", "dueno")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.crear_viaje(db, datos)


@router.patch("/{id_viaje}", response_model=Viaje, response_model_exclude_none=True)
async def actualizar_viaje(
    id_viaje: int,
    datos: ViajeUpdate,
    _: UsuarioActual = Depends(requiere_rol("administrador", "dueno")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.actualizar_viaje(db, id_viaje, datos)
