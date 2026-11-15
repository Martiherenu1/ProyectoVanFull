"""Gestión administrativa de vehículos respaldada por CU-022/RF-026."""

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.models.viajes import Vehiculo as VehiculoModelo
from app.schemas.vehiculos import Vehiculo, VehiculoCreate, VehiculoUpdate


def _a_schema(vehiculo: VehiculoModelo) -> Vehiculo:
    return Vehiculo(
        id_vehiculo=vehiculo.id_vehiculo,
        patente=vehiculo.patente,
        marca=vehiculo.marca,
        modelo=vehiculo.modelo,
        capacidad=vehiculo.capacidad,
        disponibilidad=vehiculo.disponibilidad,
    )


async def _validar_patente(
    db: AsyncSession, patente: str, *, excluir_id: int | None = None
) -> None:
    consulta = select(VehiculoModelo.id_vehiculo).where(VehiculoModelo.patente == patente)
    if excluir_id is not None:
        consulta = consulta.where(VehiculoModelo.id_vehiculo != excluir_id)
    if await db.scalar(consulta) is not None:
        raise ApiError(409, "PATENTE_DUPLICADA", "Ya existe un vehículo con esa patente.")


async def listar_vehiculos(db: AsyncSession) -> list[Vehiculo]:
    vehiculos = (
        await db.scalars(select(VehiculoModelo).order_by(VehiculoModelo.id_vehiculo))
    ).all()
    return [_a_schema(vehiculo) for vehiculo in vehiculos]


async def consultar_vehiculo(db: AsyncSession, id_vehiculo: int) -> Vehiculo:
    vehiculo = await db.get(VehiculoModelo, id_vehiculo)
    if vehiculo is None:
        raise ApiError(404, "VEHICULO_NO_ENCONTRADO", "El vehículo no existe.")
    return _a_schema(vehiculo)


async def crear_vehiculo(db: AsyncSession, datos: VehiculoCreate) -> Vehiculo:
    await _validar_patente(db, datos.patente)
    vehiculo = VehiculoModelo(**datos.model_dump())
    db.add(vehiculo)
    try:
        await db.flush()
    except IntegrityError as error:
        await db.rollback()
        raise ApiError(
            409, "PATENTE_DUPLICADA", "Ya existe un vehículo con esa patente."
        ) from error
    resultado = _a_schema(vehiculo)
    await db.commit()
    return resultado


async def actualizar_vehiculo(
    db: AsyncSession, id_vehiculo: int, datos: VehiculoUpdate
) -> Vehiculo:
    vehiculo = await db.scalar(
        select(VehiculoModelo).where(VehiculoModelo.id_vehiculo == id_vehiculo).with_for_update()
    )
    if vehiculo is None:
        raise ApiError(404, "VEHICULO_NO_ENCONTRADO", "El vehículo no existe.")
    if "patente" in datos.model_fields_set:
        await _validar_patente(db, datos.patente, excluir_id=id_vehiculo)
    for campo in datos.model_fields_set:
        setattr(vehiculo, campo, getattr(datos, campo))
    try:
        await db.flush()
    except IntegrityError as error:
        await db.rollback()
        raise ApiError(
            409, "PATENTE_DUPLICADA", "Ya existe un vehículo con esa patente."
        ) from error
    resultado = _a_schema(vehiculo)
    await db.commit()
    return resultado
