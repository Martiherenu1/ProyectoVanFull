"""Operaciones GET/POST ubicación ya aprobadas en OpenAPI."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import UsuarioActual, requiere_rol
from app.schemas.gps import PosicionGpsCreate, ResultadoPosicionGps, Ubicacion
from app.services import gps

router = APIRouter(prefix="/viajes", tags=["gps"])


@router.post("/{id_viaje}/ubicacion", response_model=ResultadoPosicionGps)
async def enviar(
    id_viaje: int,
    datos: PosicionGpsCreate,
    usuario: UsuarioActual = Depends(requiere_rol("chofer")),
    db: AsyncSession = Depends(get_db),
):
    return await gps.enviar(db, usuario, id_viaje, datos)


@router.get("/{id_viaje}/ubicacion", response_model=Ubicacion)
async def consultar(
    id_viaje: int,
    usuario: UsuarioActual = Depends(requiere_rol("pasajero", "administrador", "dueno")),
    db: AsyncSession = Depends(get_db),
):
    return await gps.consultar(db, usuario, id_viaje)
