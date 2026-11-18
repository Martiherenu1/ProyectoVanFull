"""Gestión de tarifas (CU-031). Router fino: el rol y la delegación, nada más.

Exclusivo del dueño (RN-027): un administrador recibe 403. Vive bajo `/administracion/tarifas` para no
chocar con `GET /tarifas?id_viaje`, que es la consulta de la tarifa aplicable a un viaje (pasajero).
"""

from fastapi import APIRouter, Depends, Path
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import UsuarioActual, requiere_rol
from app.schemas.gestion_tarifas import (
    TarifaGestion,
    TarifaGestionCreate,
    TarifaGestionLista,
    TarifaGestionUpdate,
)
from app.services import gestion_tarifas as servicio

router = APIRouter(prefix="/administracion/tarifas", tags=["administracion"])

_DUENO = Depends(requiere_rol("dueno"))


@router.get("", response_model=TarifaGestionLista, response_model_exclude_none=True)
async def listar_tarifas(_: UsuarioActual = _DUENO, db: AsyncSession = Depends(get_db)):
    return await servicio.listar_tarifas(db)


@router.post("", response_model=TarifaGestion, response_model_exclude_none=True, status_code=201)
async def crear_tarifa(
    datos: TarifaGestionCreate, _: UsuarioActual = _DUENO, db: AsyncSession = Depends(get_db)
):
    return await servicio.crear_tarifa(db, datos)


@router.get("/{id_tarifa}", response_model=TarifaGestion, response_model_exclude_none=True)
async def consultar_tarifa(
    id_tarifa: int = Path(gt=0), _: UsuarioActual = _DUENO, db: AsyncSession = Depends(get_db)
):
    return await servicio.obtener_tarifa(db, id_tarifa)


@router.patch("/{id_tarifa}", response_model=TarifaGestion, response_model_exclude_none=True)
async def modificar_tarifa(
    datos: TarifaGestionUpdate,
    id_tarifa: int = Path(gt=0),
    _: UsuarioActual = _DUENO,
    db: AsyncSession = Depends(get_db),
):
    return await servicio.modificar_tarifa(db, id_tarifa, datos)
