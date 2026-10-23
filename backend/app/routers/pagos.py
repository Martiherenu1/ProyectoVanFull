"""Endpoints de administración de pagos (CU-014 y CU-016)."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import UsuarioActual, requiere_rol
from app.schemas.pagos import DecisionPago, Pago, PagoCreate
from app.services import pagos as servicio

router = APIRouter(prefix="/pagos", tags=["pagos"])


@router.post("", response_model=Pago, status_code=201)
async def registrar_pago(
    datos: PagoCreate,
    _: UsuarioActual = Depends(requiere_rol("administrador", "dueno")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.registrar_pago(db, datos)


@router.post("/{id_pago}/confirmacion", response_model=Pago)
async def confirmar_o_rechazar_pago(
    id_pago: int,
    datos: DecisionPago,
    _: UsuarioActual = Depends(requiere_rol("administrador", "dueno")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.decidir_pago_pendiente(db, id_pago, datos.decision)
