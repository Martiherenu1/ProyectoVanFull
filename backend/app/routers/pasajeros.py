"""Gestión administrativa de pasajeros (CU-013). Router fino: el rol y la delegación, nada más.

Se registra después de `perfil` en `main.py`: `/pasajeros/me` es del pasajero y tiene que resolverse
antes que `/pasajeros/{id_persona}`.
"""

from fastapi import APIRouter, Depends, Path, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import UsuarioActual, requiere_rol
from app.schemas.pasajeros import PasajeroAdmin, PasajeroCreate, PasajeroLista, PasajeroUpdate
from app.services import pasajeros as servicio

router = APIRouter(prefix="/pasajeros", tags=["administracion"])

# Administración y dueño (ACT-05 y ACT-06 por especialización).
_ADMIN = Depends(requiere_rol("administrador", "dueno"))

# exclude_none: lo que el pasajero no tiene cargado no aparece, en vez de ir como null, que el
# contrato (campos `type: string` sin `nullable`) no admite.


@router.get("", response_model=PasajeroLista, response_model_exclude_none=True)
async def listar_pasajeros(
    q: str | None = Query(default=None, max_length=100),
    limite: int = Query(default=20, ge=1, le=100),
    desplazamiento: int = Query(default=0, ge=0),
    _: UsuarioActual = _ADMIN,
    db: AsyncSession = Depends(get_db),
):
    return await servicio.listar_pasajeros(db, q=q, limite=limite, desplazamiento=desplazamiento)


@router.post("", response_model=PasajeroAdmin, response_model_exclude_none=True, status_code=201)
async def crear_pasajero(
    datos: PasajeroCreate,
    _: UsuarioActual = _ADMIN,
    db: AsyncSession = Depends(get_db),
):
    return await servicio.crear_pasajero(db, datos)


@router.get("/{id_persona}", response_model=PasajeroAdmin, response_model_exclude_none=True)
async def consultar_pasajero(
    id_persona: int = Path(gt=0),
    _: UsuarioActual = _ADMIN,
    db: AsyncSession = Depends(get_db),
):
    return await servicio.obtener_pasajero(db, id_persona)


@router.patch("/{id_persona}", response_model=PasajeroAdmin, response_model_exclude_none=True)
async def modificar_pasajero(
    datos: PasajeroUpdate,
    id_persona: int = Path(gt=0),
    _: UsuarioActual = _ADMIN,
    db: AsyncSession = Depends(get_db),
):
    return await servicio.modificar_pasajero(db, id_persona, datos)


@router.post("/{id_persona}/baja", response_model=PasajeroAdmin, response_model_exclude_none=True)
async def dar_de_baja_pasajero(
    id_persona: int = Path(gt=0),
    _: UsuarioActual = _ADMIN,
    db: AsyncSession = Depends(get_db),
):
    return await servicio.dar_de_baja(db, id_persona)
