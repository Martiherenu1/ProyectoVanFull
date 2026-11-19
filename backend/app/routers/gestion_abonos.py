"""Gestión de abonos mensuales (CU-028). Router fino: el rol y la delegación, nada más.

Administrador y dueño (ACT-05 y ACT-06). Los pagos, la confirmación y la deuda del abono se
gestionan en CU-014, CU-016 y CU-015.
"""

from typing import Literal

from fastapi import APIRouter, Depends, Path, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import UsuarioActual, requiere_rol
from app.schemas.gestion_abonos import (
    AbonoGestion,
    AbonoGestionCreate,
    AbonoGestionLista,
    AbonoGestionUpdate,
    PeriodoAbonoCreate,
)
from app.services import gestion_abonos as servicio

router = APIRouter(prefix="/administracion/abonos", tags=["administracion"])

_ADMIN = Depends(requiere_rol("administrador", "dueno"))
_SIN_NULOS = {"response_model_exclude_none": True}


@router.get("", response_model=AbonoGestionLista, **_SIN_NULOS)
async def listar_abonos(
    id_pasajero: int | None = Query(default=None, gt=0),
    estado: str | None = Query(default=None, min_length=1, max_length=30),
    tipo_servicio: Literal["UNIVERSITARIO", "LABORAL"] | None = None,
    _: UsuarioActual = _ADMIN,
    db: AsyncSession = Depends(get_db),
):
    return await servicio.listar(
        db, id_pasajero=id_pasajero, estado=estado, tipo_servicio=tipo_servicio
    )


@router.post("", response_model=AbonoGestion, status_code=201, **_SIN_NULOS)
async def crear_abono(
    datos: AbonoGestionCreate, _: UsuarioActual = _ADMIN, db: AsyncSession = Depends(get_db)
):
    return await servicio.crear(db, datos)


@router.get("/{id_abono}", response_model=AbonoGestion, **_SIN_NULOS)
async def consultar_abono(
    id_abono: int = Path(gt=0), _: UsuarioActual = _ADMIN, db: AsyncSession = Depends(get_db)
):
    return await servicio.obtener(db, id_abono)


@router.patch("/{id_abono}", response_model=AbonoGestion, **_SIN_NULOS)
async def modificar_abono(
    datos: AbonoGestionUpdate,
    id_abono: int = Path(gt=0),
    _: UsuarioActual = _ADMIN,
    db: AsyncSession = Depends(get_db),
):
    return await servicio.modificar(db, id_abono, datos)


@router.post("/{id_abono}/periodos", response_model=AbonoGestion, status_code=201, **_SIN_NULOS)
async def agregar_periodo(
    datos: PeriodoAbonoCreate,
    id_abono: int = Path(gt=0),
    _: UsuarioActual = _ADMIN,
    db: AsyncSession = Depends(get_db),
):
    return await servicio.agregar_periodo(db, id_abono, datos.periodo)
