"""CU-030 manual y proyección contextual; CU-037 aún sin circuito."""

from uuid import UUID

from fastapi import APIRouter, Depends, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import UsuarioActual, requiere_rol, usuario_actual
from app.schemas.avisos import Aviso, AvisoCrear, MensajeDemora
from app.services import avisos

router = APIRouter(tags=["chofer"])


@router.post("/viajes/{id_viaje}/avisos", response_model=Aviso, status_code=201)
async def crear(
    id_viaje: int,
    datos: AvisoCrear,
    response: Response,
    usuario: UsuarioActual = Depends(requiere_rol("chofer")),
    db: AsyncSession = Depends(get_db),
):
    salida, nuevo = await avisos.crear(db, usuario, id_viaje, datos)
    response.status_code = 201 if nuevo else 200
    response.headers["Cache-Control"] = "no-store"
    return salida


@router.get("/viajes/{id_viaje}/avisos/resultado", response_model=Aviso)
async def resultado(
    id_viaje: int,
    clave_solicitud: UUID,
    response: Response,
    usuario: UsuarioActual = Depends(usuario_actual),
    db: AsyncSession = Depends(get_db),
):
    response.headers["Cache-Control"] = "no-store"
    return await avisos.resultado(db, usuario, id_viaje, clave_solicitud)


@router.get("/viajes/{id_viaje}/avisos", response_model=list[Aviso])
async def internos(
    id_viaje: int,
    response: Response,
    usuario: UsuarioActual = Depends(requiere_rol("administrador", "dueno")),
    db: AsyncSession = Depends(get_db),
):
    response.headers["Cache-Control"] = "no-store"
    return await avisos.internos(db, id_viaje)


@router.get("/pasajeros/me/viajes/{id_viaje}/demora", response_model=MensajeDemora)
async def mensaje(
    id_viaje: int,
    response: Response,
    usuario: UsuarioActual = Depends(requiere_rol("pasajero")),
    db: AsyncSession = Depends(get_db),
):
    response.headers["Cache-Control"] = "no-store"
    return await avisos.mensaje(db, usuario, id_viaje)
