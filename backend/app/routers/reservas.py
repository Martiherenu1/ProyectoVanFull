"""Endpoints de reservas. Hoy solo la consulta del pasajero (CU-010).

Las rutas se declaran completas porque este router mezcla dos prefijos del contrato
(`/pasajeros/me/reservas` y `/reservas/...`); al sumar CU-003, 004 y 005 siguen acá.

`GET /reservas/{id}` es hoy solo del pasajero y solo de lo propio. El contrato dice "propia/autorizada":
si administración necesita el detalle (CU-027), se extiende ahí, con su regla de autorización.
"""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import UsuarioActual, requiere_rol
from app.schemas.reservas import Reserva
from app.services import reservas as servicio

router = APIRouter(tags=["reservas"])


@router.get("/pasajeros/me/reservas", response_model=list[Reserva])
async def consultar_reservas_propias(
    usuario: UsuarioActual = Depends(requiere_rol("pasajero")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.listar_reservas_del_pasajero(db, usuario)


@router.get("/reservas/{id_reserva}", response_model=Reserva)
async def consultar_reserva(
    id_reserva: int,
    usuario: UsuarioActual = Depends(requiere_rol("pasajero")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.obtener_reserva_del_pasajero(db, usuario, id_reserva)
