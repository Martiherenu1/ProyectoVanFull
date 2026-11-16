"""Gestión de clientes corporativos (CU-023). Router fino: el rol y la delegación, nada más."""

from fastapi import APIRouter, Depends, Path, Query, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import UsuarioActual, requiere_rol
from app.schemas.corporativos import (
    ClienteCorporativo,
    ClienteCorporativoCreate,
    ClienteCorporativoDetalle,
    ClienteCorporativoLista,
    ClienteCorporativoUpdate,
    ContactoCorporativo,
    ContactoCorporativoCreate,
    PasajeroCorporativo,
    PasajeroCorporativoCreate,
)
from app.services import corporativos as servicio

router = APIRouter(prefix="/clientes-corporativos", tags=["administracion"])

# Administración y dueño (ACT-05 y ACT-06). El representante corporativo (ACT-03) no: es CU-033.
_ADMIN = Depends(requiere_rol("administrador", "dueno"))

# exclude_none: lo que no está cargado no aparece, en vez de ir como null, que el contrato
# (campos `type: string` sin `nullable`) no admite.


@router.get("", response_model=ClienteCorporativoLista, response_model_exclude_none=True)
async def listar_clientes_corporativos(
    q: str | None = Query(default=None, max_length=100),
    limite: int = Query(default=20, ge=1, le=100),
    desplazamiento: int = Query(default=0, ge=0),
    _: UsuarioActual = _ADMIN,
    db: AsyncSession = Depends(get_db),
):
    return await servicio.listar(db, q=q, limite=limite, desplazamiento=desplazamiento)


@router.post(
    "", response_model=ClienteCorporativo, response_model_exclude_none=True, status_code=201
)
async def crear_cliente_corporativo(
    datos: ClienteCorporativoCreate,
    _: UsuarioActual = _ADMIN,
    db: AsyncSession = Depends(get_db),
):
    return await servicio.crear(db, datos)


@router.get(
    "/{id_cliente}", response_model=ClienteCorporativoDetalle, response_model_exclude_none=True
)
async def consultar_cliente_corporativo(
    id_cliente: int = Path(gt=0),
    _: UsuarioActual = _ADMIN,
    db: AsyncSession = Depends(get_db),
):
    return await servicio.obtener(db, id_cliente)


@router.patch("/{id_cliente}", response_model=ClienteCorporativo, response_model_exclude_none=True)
async def modificar_cliente_corporativo(
    datos: ClienteCorporativoUpdate,
    id_cliente: int = Path(gt=0),
    _: UsuarioActual = _ADMIN,
    db: AsyncSession = Depends(get_db),
):
    return await servicio.modificar(db, id_cliente, datos)


@router.post(
    "/{id_cliente}/contactos",
    response_model=ContactoCorporativo,
    response_model_exclude_none=True,
    status_code=201,
)
async def agregar_contacto(
    datos: ContactoCorporativoCreate,
    id_cliente: int = Path(gt=0),
    _: UsuarioActual = _ADMIN,
    db: AsyncSession = Depends(get_db),
):
    return await servicio.agregar_contacto(db, id_cliente, datos)


@router.delete("/{id_cliente}/contactos/{id_persona}", status_code=204)
async def quitar_contacto(
    id_cliente: int = Path(gt=0),
    id_persona: int = Path(gt=0),
    _: UsuarioActual = _ADMIN,
    db: AsyncSession = Depends(get_db),
):
    await servicio.quitar_contacto(db, id_cliente, id_persona)
    return Response(status_code=204)


@router.post(
    "/{id_cliente}/pasajeros",
    response_model=PasajeroCorporativo,
    response_model_exclude_none=True,
    status_code=201,
)
async def asociar_pasajero(
    datos: PasajeroCorporativoCreate,
    id_cliente: int = Path(gt=0),
    _: UsuarioActual = _ADMIN,
    db: AsyncSession = Depends(get_db),
):
    return await servicio.asociar_pasajero(db, id_cliente, datos)


@router.delete("/{id_cliente}/pasajeros/{id_pasajero}", status_code=204)
async def desasociar_pasajero(
    id_cliente: int = Path(gt=0),
    id_pasajero: int = Path(gt=0),
    _: UsuarioActual = _ADMIN,
    db: AsyncSession = Depends(get_db),
):
    await servicio.desasociar_pasajero(db, id_cliente, id_pasajero)
    return Response(status_code=204)
