"""Gestión de tarifas por el dueño (CU-031, RF-027, RN-027).

Alcance: listar, crear, consultar y modificar tarifas. El rol `dueno` ya lo exigió el router.

Qué NO hace, y por qué (v1.3 del CU y de las RN, sin inventar):
- Modificar una tarifa no toca contrataciones, reservas ni saldos (A2, RN-012): la contratación
  conserva su `importe_acordado`. Si un cambio puede o no afectar un saldo pendiente es una decisión
  de negocio sin cerrar, y no se recalcula nada en silencio.
- PENDIENTE DE DISEÑO (v1.3): estructura de parámetros, vigencias e historial tarifario. Por eso una
  modificación pisa la fila (no hay historial) y `tipo`/`fecha_vigencia` se guardan sin interpretarlos.
- Descuentos especiales (A1): sin tabla ni regla aprobada en el modelo; fuera de alcance.
- El 15 % por pago en efectivo (RN-011) es una regla aprobada, no una tarifa editable.
- No se elimina: el CU no lo prevé y la fila puede estar referenciada por una contratación.
"""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.models.servicios import Tarifa
from app.schemas.gestion_tarifas import (
    TarifaGestion,
    TarifaGestionCreate,
    TarifaGestionLista,
    TarifaGestionUpdate,
)


def _armar(tarifa: Tarifa) -> TarifaGestion:
    return TarifaGestion(
        id_tarifa=tarifa.id_tarifa,
        nombre=tarifa.nombre,
        tipo=tarifa.tipo,
        importe=float(tarifa.importe),
        fecha_creacion=tarifa.fecha_creacion,
        fecha_vigencia=tarifa.fecha_vigencia,
    )


async def _cargar(db: AsyncSession, id_tarifa: int, *, bloquear: bool = False) -> Tarifa:
    consulta = select(Tarifa).where(Tarifa.id_tarifa == id_tarifa)
    if bloquear:
        consulta = consulta.with_for_update()
    tarifa = (await db.execute(consulta)).scalar_one_or_none()
    if tarifa is None:
        raise ApiError(
            404, "TARIFA_NO_ENCONTRADA", "No existe una tarifa con el identificador indicado."
        )
    return tarifa


async def listar_tarifas(db: AsyncSession) -> TarifaGestionLista:
    tarifas = (
        (await db.execute(select(Tarifa).order_by(Tarifa.tipo, Tarifa.nombre, Tarifa.id_tarifa)))
        .scalars()
        .all()
    )
    return TarifaGestionLista(items=[_armar(t) for t in tarifas], total=len(tarifas))


async def obtener_tarifa(db: AsyncSession, id_tarifa: int) -> TarifaGestion:
    return _armar(await _cargar(db, id_tarifa))


async def crear_tarifa(db: AsyncSession, datos: TarifaGestionCreate) -> TarifaGestion:
    tarifa = Tarifa(**datos.model_dump())
    db.add(tarifa)
    await db.commit()
    # `fecha_creacion` la pone la base (CURRENT_DATE): se relee para devolverla.
    await db.refresh(tarifa)
    return _armar(tarifa)


async def modificar_tarifa(
    db: AsyncSession, id_tarifa: int, datos: TarifaGestionUpdate
) -> TarifaGestion:
    cambios = datos.model_dump(exclude_unset=True)
    if not cambios:
        raise ApiError(400, "VALIDACION", "No se indicó ningún dato para modificar.")
    tarifa = await _cargar(db, id_tarifa, bloquear=True)
    for campo, valor in cambios.items():
        setattr(tarifa, campo, valor)
    await db.commit()
    await db.refresh(tarifa)
    return _armar(tarifa)
