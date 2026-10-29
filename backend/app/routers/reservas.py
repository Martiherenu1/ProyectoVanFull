"""Endpoints de reservas del pasajero: consulta (CU-010), creación (CU-003) y cancelación (CU-004).
Más el listado de solo lectura de administración (CU-027).

Las rutas se declaran completas porque este router mezcla dos prefijos del contrato
(`/pasajeros/me/reservas` y `/reservas/...`).

`GET /reservas/{id}` es hoy solo del pasajero y solo de lo propio. El contrato dice "propia/autorizada":
CU-027 se resolvió con el listado `GET /reservas` y no extiende este detalle, que sigue siendo del pasajero.
"""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import UsuarioActual, requiere_rol
from app.schemas.reservas import Reserva, ReservaCreate, ResultadoCancelacion
from app.services import reservas as servicio

router = APIRouter(tags=["reservas"])


@router.get("/pasajeros/me/reservas", response_model=list[Reserva])
async def consultar_reservas_propias(
    usuario: UsuarioActual = Depends(requiere_rol("pasajero")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.listar_reservas_del_pasajero(db, usuario)


@router.get("/reservas", response_model=list[Reserva])
async def listar_reservas(
    _: UsuarioActual = Depends(requiere_rol("administrador", "dueno")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.listar_reservas_para_administracion(db)


@router.get("/reservas/{id_reserva}", response_model=Reserva)
async def consultar_reserva(
    id_reserva: int,
    usuario: UsuarioActual = Depends(requiere_rol("pasajero")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.obtener_reserva_del_pasajero(db, usuario, id_reserva)


@router.post("/reservas", response_model=Reserva, status_code=201)
async def crear_reserva(
    datos: ReservaCreate,
    usuario: UsuarioActual = Depends(requiere_rol("pasajero")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.crear_reserva(db, usuario, datos)


@router.post("/reservas/{id_reserva}/cancelacion", response_model=ResultadoCancelacion)
async def cancelar_reserva(
    id_reserva: int,
    usuario: UsuarioActual = Depends(requiere_rol("pasajero")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.cancelar_reserva(db, usuario, id_reserva)
