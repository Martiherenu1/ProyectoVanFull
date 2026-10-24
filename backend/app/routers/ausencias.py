"""CU-008: aviso de ausencia del pasajero autenticado."""

from fastapi import APIRouter, Depends, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import UsuarioActual, requiere_rol
from app.schemas.ausencias import Ausencia, AusenciaCreate
from app.services import ausencias as servicio

router = APIRouter(tags=["abordaje"])


@router.post(
    "/ausencias", response_model=Ausencia, status_code=201, responses={200: {"model": Ausencia}}
)
async def informar_ausencia(
    datos: AusenciaCreate,
    respuesta: Response,
    usuario: UsuarioActual = Depends(requiere_rol("pasajero")),
    db: AsyncSession = Depends(get_db),
):
    aviso, creado = await servicio.informar_ausencia(db, usuario, datos)
    respuesta.status_code = 201 if creado else 200
    return aviso
