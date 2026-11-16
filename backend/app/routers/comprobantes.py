"""Endpoints de consulta de comprobantes propios (CU-035)."""

from fastapi import APIRouter, Depends, Path
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import UsuarioActual, requiere_rol
from app.schemas.comprobantes import ComprobantePropio
from app.services import comprobantes as servicio

router = APIRouter(tags=["pasajero"])


@router.get("/pasajeros/me/comprobantes", response_model=list[ComprobantePropio])
async def listar_comprobantes_propios(
    usuario: UsuarioActual = Depends(requiere_rol("pasajero")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.listar_propios(db, usuario)


@router.get("/pasajeros/me/comprobantes/{id_comprobante}", response_model=ComprobantePropio)
async def obtener_comprobante_propio(
    id_comprobante: int = Path(gt=0),
    usuario: UsuarioActual = Depends(requiere_rol("pasajero")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.obtener_propio(db, usuario, id_comprobante)
