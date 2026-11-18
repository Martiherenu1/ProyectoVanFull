"""Gestión de recorridos y paradas (CU-019). Router fino: el rol y la delegación, nada más.

Administrador y dueño (ACT-05 y ACT-06). Vive bajo `/administracion` para no chocar con
`GET /recorridos/{id}/paradas`, la consulta de paradas del lado pasajero (CU-002).
"""

from fastapi import APIRouter, Depends, Path
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import UsuarioActual, requiere_rol
from app.schemas.gestion_recorridos import (
    ParadaGestion,
    ParadaGestionCreate,
    ParadaGestionLista,
    ParadaGestionUpdate,
    RecorridoGestion,
    RecorridoGestionLista,
    RecorridoParadas,
)
from app.services import gestion_recorridos as servicio

router = APIRouter(prefix="/administracion", tags=["administracion"])

_ADMIN = Depends(requiere_rol("administrador", "dueno"))
_SIN_NULOS = {"response_model_exclude_none": True}


@router.get("/paradas", response_model=ParadaGestionLista, **_SIN_NULOS)
async def listar_paradas(_: UsuarioActual = _ADMIN, db: AsyncSession = Depends(get_db)):
    return await servicio.listar_paradas(db)


@router.post("/paradas", response_model=ParadaGestion, status_code=201, **_SIN_NULOS)
async def crear_parada(
    datos: ParadaGestionCreate, _: UsuarioActual = _ADMIN, db: AsyncSession = Depends(get_db)
):
    return await servicio.crear_parada(db, datos)


@router.get("/paradas/{id_parada}", response_model=ParadaGestion, **_SIN_NULOS)
async def consultar_parada(
    id_parada: int = Path(gt=0), _: UsuarioActual = _ADMIN, db: AsyncSession = Depends(get_db)
):
    return await servicio.obtener_parada(db, id_parada)


@router.patch("/paradas/{id_parada}", response_model=ParadaGestion, **_SIN_NULOS)
async def modificar_parada(
    datos: ParadaGestionUpdate,
    id_parada: int = Path(gt=0),
    _: UsuarioActual = _ADMIN,
    db: AsyncSession = Depends(get_db),
):
    return await servicio.modificar_parada(db, id_parada, datos)


@router.get("/recorridos", response_model=RecorridoGestionLista, **_SIN_NULOS)
async def listar_recorridos(_: UsuarioActual = _ADMIN, db: AsyncSession = Depends(get_db)):
    return await servicio.listar_recorridos(db)


@router.post("/recorridos", response_model=RecorridoGestion, status_code=201, **_SIN_NULOS)
async def crear_recorrido(
    datos: RecorridoParadas, _: UsuarioActual = _ADMIN, db: AsyncSession = Depends(get_db)
):
    return await servicio.crear_recorrido(db, datos.id_paradas)


@router.get("/recorridos/{id_recorrido}", response_model=RecorridoGestion, **_SIN_NULOS)
async def consultar_recorrido(
    id_recorrido: int = Path(gt=0), _: UsuarioActual = _ADMIN, db: AsyncSession = Depends(get_db)
):
    return await servicio.obtener_recorrido(db, id_recorrido)


@router.patch("/recorridos/{id_recorrido}", response_model=RecorridoGestion, **_SIN_NULOS)
async def reemplazar_paradas(
    datos: RecorridoParadas,
    id_recorrido: int = Path(gt=0),
    _: UsuarioActual = _ADMIN,
    db: AsyncSession = Depends(get_db),
):
    return await servicio.reemplazar_paradas(db, id_recorrido, datos.id_paradas)
