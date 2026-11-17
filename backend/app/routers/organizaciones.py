"""Pasajeros de la organización (CU-033). Router fino: el rol y la delegación, nada más."""

from fastapi import APIRouter, Depends, Path, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import UsuarioActual, requiere_rol
from app.schemas.organizaciones import (
    OrganizacionLista,
    PasajeroOrganizacion,
    PasajeroOrganizacionCreate,
    PasajeroOrganizacionLista,
    PasajeroOrganizacionUpdate,
)
from app.services import organizaciones as servicio

router = APIRouter(prefix="/organizaciones", tags=["corporativo"])

# Solo el representante (ACT-03). Administración y dueño gestionan estos mismos datos por CU-013 y
# CU-023. A qué empresa pertenece el representante lo decide el servicio, no el rol.
_REPRESENTANTE = Depends(requiere_rol("representante_corporativo"))

# exclude_none: lo que no está cargado no aparece, en vez de ir como null, que el contrato
# (campos `type: string` sin `nullable`) no admite.


@router.get("", response_model=OrganizacionLista, response_model_exclude_none=True)
async def listar_organizaciones(
    usuario: UsuarioActual = _REPRESENTANTE,
    db: AsyncSession = Depends(get_db),
):
    return await servicio.listar_organizaciones(db, usuario)


@router.get(
    "/{id_cliente}/pasajeros",
    response_model=PasajeroOrganizacionLista,
    response_model_exclude_none=True,
)
async def listar_pasajeros(
    id_cliente: int = Path(gt=0),
    limite: int = Query(default=20, ge=1, le=100),
    desplazamiento: int = Query(default=0, ge=0),
    usuario: UsuarioActual = _REPRESENTANTE,
    db: AsyncSession = Depends(get_db),
):
    return await servicio.listar_pasajeros(
        db, usuario, id_cliente, limite=limite, desplazamiento=desplazamiento
    )


@router.post(
    "/{id_cliente}/pasajeros",
    response_model=PasajeroOrganizacion,
    response_model_exclude_none=True,
    status_code=201,
)
async def registrar_pasajero(
    datos: PasajeroOrganizacionCreate,
    id_cliente: int = Path(gt=0),
    usuario: UsuarioActual = _REPRESENTANTE,
    db: AsyncSession = Depends(get_db),
):
    return await servicio.registrar_pasajero(db, usuario, id_cliente, datos)


@router.patch(
    "/{id_cliente}/pasajeros/{id_pasajero}",
    response_model=PasajeroOrganizacion,
    response_model_exclude_none=True,
)
async def modificar_pasajero(
    datos: PasajeroOrganizacionUpdate,
    id_cliente: int = Path(gt=0),
    id_pasajero: int = Path(gt=0),
    usuario: UsuarioActual = _REPRESENTANTE,
    db: AsyncSession = Depends(get_db),
):
    return await servicio.modificar_pasajero(db, usuario, id_cliente, id_pasajero, datos)
