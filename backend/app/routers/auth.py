"""Endpoints /auth (CU-012). El router es fino: valida la forma y delega en el servicio."""

from fastapi import APIRouter, Depends, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import UsuarioActual, usuario_actual
from app.schemas.auth import LoginRequest, TokenResponse
from app.services import auth as servicio

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=TokenResponse)
async def login(datos: LoginRequest, db: AsyncSession = Depends(get_db)):
    token, roles = await servicio.iniciar_sesion(db, datos.identificador_acceso, datos.password)
    return TokenResponse(access_token=token, roles=roles)


@router.post("/logout", status_code=204)
async def logout(_: UsuarioActual = Depends(usuario_actual)):
    """No hay lista negra (decisión del 2026-10-13): el cliente descarta el token."""
    return Response(status_code=204)
