"""Rutas de descenso, progreso y ETA por reserva."""

from fastapi import APIRouter, Depends, Path, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import UsuarioActual, requiere_rol
from app.schemas.eta import EtaReserva, OrdenesDescenso, PasoParada
from app.services import eta

router = APIRouter()


@router.get("/viajes/{id_viaje}/descensos", response_model=OrdenesDescenso, tags=["reservas"])
async def listar_descensos(
    id_viaje: int = Path(gt=0),
    _: UsuarioActual = Depends(requiere_rol("pasajero", "administrador", "dueno")),
    db: AsyncSession = Depends(get_db),
):
    return await eta.listar_descensos(db, id_viaje)


@router.patch("/viajes/{id_viaje}/descensos", response_model=OrdenesDescenso, tags=["viajes"])
async def configurar_descensos(
    datos: OrdenesDescenso,
    id_viaje: int = Path(gt=0),
    _: UsuarioActual = Depends(requiere_rol("administrador", "dueno")),
    db: AsyncSession = Depends(get_db),
):
    return await eta.configurar_descensos(db, id_viaje, datos)


@router.post("/viajes/{id_viaje}/paso-parada", response_model=PasoParada, tags=["chofer"])
async def registrar_paso(
    datos: PasoParada,
    id_viaje: int = Path(gt=0),
    usuario: UsuarioActual = Depends(requiere_rol("chofer")),
    db: AsyncSession = Depends(get_db),
):
    return await eta.registrar_paso(db, usuario, id_viaje, datos)


@router.get("/reservas/{id_reserva}/eta", response_model=EtaReserva, tags=["gps"])
async def consultar(
    response: Response,
    id_reserva: int = Path(gt=0),
    usuario: UsuarioActual = Depends(requiere_rol("pasajero")),
    db: AsyncSession = Depends(get_db),
):
    resultado = await eta.consultar(db, usuario, id_reserva)
    response.headers["Cache-Control"] = "no-store"
    return resultado
