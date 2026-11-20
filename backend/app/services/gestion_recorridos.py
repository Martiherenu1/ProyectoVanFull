"""Gestión de recorridos y paradas por administración y dueño (CU-019, RF-019, RN-021).

Alcance: catálogo de paradas (listar, crear, consultar, modificar) y recorridos (listar, crear,
consultar, reemplazar sus paradas). El rol ya lo exigió el router.

RN-021 / A2: una modificación no puede impedir respetar una parada **comprometida**. Se aplica así:
- En un recorrido, cada parada comprometida debe seguir en el mismo orden y ser la misma parada.
- Una parada del catálogo que está comprometida en algún recorrido no se modifica (cambiaría el lugar
  al que ya se comprometió el servicio).
Además, una parada de un recorrido que tiene reservas o abordajes no se quita ni se cambia: las
reservas apuntan a (recorrido, orden) y quedarían apuntando a otro lugar o a ninguno.

PENDIENTE (v1.3 y RN): cómo una parada pasa a estar comprometida no está definido. Esta API **lee y
conserva** la marca (`comprometida`); las paradas nuevas entran sin comprometer. Tampoco hay baja de
paradas ni de recorridos: el CU no la prevé y hay FK de reservas, abordajes y viajes.
"""

from decimal import Decimal

from sqlalchemy import exists, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.models.viajes import (
    Abordaje,
    DescensoHabilitado,
    ParadaRecorrido,
    Recorrido,
    Reserva,
    Viaje,
)
from app.models.viajes import Parada as ParadaModelo
from app.schemas.gestion_recorridos import (
    ParadaEnRecorrido,
    ParadaGestion,
    ParadaGestionCreate,
    ParadaGestionLista,
    ParadaGestionUpdate,
    RecorridoGestion,
    RecorridoGestionLista,
)


def _numero(valor: Decimal | None) -> float | None:
    return float(valor) if valor is not None else None


def _parada(p: ParadaModelo) -> ParadaGestion:
    return ParadaGestion(
        id_parada=p.id_parada,
        nombre_descripcion=p.nombre_descripcion,
        direccion=p.direccion,
        latitud=_numero(p.latitud),
        longitud=_numero(p.longitud),
    )


# --- Paradas --------------------------------------------------------------------------------


async def _cargar_parada(
    db: AsyncSession, id_parada: int, *, bloquear: bool = False
) -> ParadaModelo:
    consulta = select(ParadaModelo).where(ParadaModelo.id_parada == id_parada)
    if bloquear:
        consulta = consulta.with_for_update()
    parada = (await db.execute(consulta)).scalar_one_or_none()
    if parada is None:
        raise ApiError(404, "PARADA_NO_ENCONTRADA", "No existe una parada con ese identificador.")
    return parada


async def listar_paradas(db: AsyncSession) -> ParadaGestionLista:
    paradas = (
        (
            await db.execute(
                select(ParadaModelo).order_by(
                    ParadaModelo.nombre_descripcion, ParadaModelo.id_parada
                )
            )
        )
        .scalars()
        .all()
    )
    return ParadaGestionLista(items=[_parada(p) for p in paradas], total=len(paradas))


async def obtener_parada(db: AsyncSession, id_parada: int) -> ParadaGestion:
    return _parada(await _cargar_parada(db, id_parada))


async def crear_parada(db: AsyncSession, datos: ParadaGestionCreate) -> ParadaGestion:
    parada = ParadaModelo(**datos.model_dump())
    db.add(parada)
    await db.commit()
    await db.refresh(parada)
    return _parada(parada)


async def modificar_parada(
    db: AsyncSession, id_parada: int, datos: ParadaGestionUpdate
) -> ParadaGestion:
    cambios = datos.model_dump(exclude_unset=True)
    if not cambios:
        raise ApiError(400, "VALIDACION", "No se indicó ningún dato para modificar.")
    parada = await _cargar_parada(db, id_parada, bloquear=True)

    comprometida = await db.scalar(
        select(
            exists().where(
                ParadaRecorrido.id_parada == id_parada, ParadaRecorrido.comprometida.is_(True)
            )
        )
    )
    if comprometida:
        raise ApiError(
            409,
            "PARADA_COMPROMETIDA",
            "La parada está comprometida en un recorrido (RN-021): no se puede modificar.",
            {"id_parada": id_parada},
        )

    for campo, valor in cambios.items():
        setattr(parada, campo, valor)
    if (parada.latitud is None) != (parada.longitud is None):
        await db.rollback()
        raise ApiError(400, "VALIDACION", "La latitud y la longitud se informan juntas.")
    await db.commit()
    await db.refresh(parada)
    return _parada(parada)


# --- Recorridos -----------------------------------------------------------------------------


async def _paradas_de(
    db: AsyncSession, ids_recorrido: list[int]
) -> dict[int, list[ParadaEnRecorrido]]:
    filas = await db.execute(
        select(ParadaRecorrido, ParadaModelo)
        .join(ParadaModelo, ParadaModelo.id_parada == ParadaRecorrido.id_parada)
        .where(ParadaRecorrido.id_recorrido.in_(ids_recorrido))
        .order_by(ParadaRecorrido.id_recorrido, ParadaRecorrido.orden)
    )
    por_recorrido: dict[int, list[ParadaEnRecorrido]] = {i: [] for i in ids_recorrido}
    for en_recorrido, parada in filas.all():
        por_recorrido[en_recorrido.id_recorrido].append(
            ParadaEnRecorrido(
                orden=en_recorrido.orden,
                id_parada=parada.id_parada,
                nombre_descripcion=parada.nombre_descripcion,
                direccion=parada.direccion,
                latitud=_numero(parada.latitud),
                longitud=_numero(parada.longitud),
                comprometida=en_recorrido.comprometida,
            )
        )
    return por_recorrido


async def _existe_recorrido(db: AsyncSession, id_recorrido: int, *, bloquear: bool = False) -> None:
    consulta = select(Recorrido.id_recorrido).where(Recorrido.id_recorrido == id_recorrido)
    if bloquear:
        consulta = consulta.with_for_update()
    if (await db.execute(consulta)).first() is None:
        raise ApiError(404, "RECORRIDO_NO_ENCONTRADO", "El recorrido no existe.")


async def listar_recorridos(db: AsyncSession) -> RecorridoGestionLista:
    ids = list(
        (
            await db.execute(select(Recorrido.id_recorrido).order_by(Recorrido.id_recorrido))
        ).scalars()
    )
    paradas = await _paradas_de(db, ids) if ids else {}
    items = [RecorridoGestion(id_recorrido=i, paradas=paradas[i]) for i in ids]
    return RecorridoGestionLista(items=items, total=len(items))


async def obtener_recorrido(db: AsyncSession, id_recorrido: int) -> RecorridoGestion:
    await _existe_recorrido(db, id_recorrido)
    paradas = await _paradas_de(db, [id_recorrido])
    return RecorridoGestion(id_recorrido=id_recorrido, paradas=paradas[id_recorrido])


async def _verificar_paradas_existen(db: AsyncSession, id_paradas: list[int]) -> None:
    pedidas = set(id_paradas)
    halladas = set(
        (
            await db.execute(
                select(ParadaModelo.id_parada).where(ParadaModelo.id_parada.in_(pedidas))
            )
        ).scalars()
    )
    if pedidas - halladas:
        raise ApiError(
            404,
            "PARADA_NO_ENCONTRADA",
            "Alguna de las paradas indicadas no existe.",
            {"id_paradas": sorted(pedidas - halladas)},
        )


async def crear_recorrido(db: AsyncSession, id_paradas: list[int]) -> RecorridoGestion:
    await _verificar_paradas_existen(db, id_paradas)
    recorrido = Recorrido()
    db.add(recorrido)
    await db.flush()
    for orden, id_parada in enumerate(id_paradas, start=1):
        db.add(
            ParadaRecorrido(
                id_recorrido=recorrido.id_recorrido,
                orden=orden,
                id_parada=id_parada,
                comprometida=False,
            )
        )
    await db.commit()
    return await obtener_recorrido(db, recorrido.id_recorrido)


async def _ordenes_con_reservas(
    db: AsyncSession, id_recorrido: int, ordenes: list[int]
) -> list[int]:
    if not ordenes:
        return []
    usados: set[int] = set()
    for modelo, orden in (
        (Reserva, Reserva.orden_parada),
        (Abordaje, Abordaje.orden_parada),
        (DescensoHabilitado, DescensoHabilitado.orden_parada),
        (Viaje, Viaje.orden_ultimo_paso),
    ):
        usados |= set(
            (
                await db.execute(
                    select(orden).where(modelo.id_recorrido == id_recorrido, orden.in_(ordenes))
                )
            ).scalars()
        )
    return sorted(usados)


async def reemplazar_paradas(
    db: AsyncSession, id_recorrido: int, id_paradas: list[int]
) -> RecorridoGestion:
    """Flujo principal y A1: deja el recorrido con estas paradas, en este orden (todo o nada)."""
    await _existe_recorrido(db, id_recorrido, bloquear=True)
    await _verificar_paradas_existen(db, id_paradas)

    existentes = {
        pr.orden: pr
        for pr in (
            await db.execute(
                select(ParadaRecorrido)
                .where(ParadaRecorrido.id_recorrido == id_recorrido)
                .order_by(ParadaRecorrido.orden)
                .with_for_update()
            )
        ).scalars()
    }
    nuevas = dict(enumerate(id_paradas, start=1))

    # RN-021 / A2: toda parada comprometida sigue en su lugar.
    violadas = sorted(
        orden
        for orden, pr in existentes.items()
        if pr.comprometida and nuevas.get(orden) != pr.id_parada
    )
    if violadas:
        raise ApiError(
            409,
            "PARADA_COMPROMETIDA",
            "La modificación impide respetar paradas comprometidas (RN-021): elegir una "
            "alternativa que las conserve en su orden.",
            {"ordenes": violadas},
        )

    # Lo que se quita o se cambia no puede tener reservas ni abordajes.
    tocadas = [orden for orden, pr in existentes.items() if nuevas.get(orden) != pr.id_parada]
    con_reservas = await _ordenes_con_reservas(db, id_recorrido, tocadas)
    if con_reservas:
        raise ApiError(
            409,
            "PARADA_CON_RESERVAS",
            "Hay referencias operativas a paradas que la modificación quita o cambia.",
            {"ordenes": con_reservas},
        )

    for orden, pr in existentes.items():
        if orden not in nuevas:
            await db.delete(pr)
        elif pr.id_parada != nuevas[orden]:
            pr.id_parada = nuevas[orden]
    for orden, id_parada in nuevas.items():
        if orden not in existentes:
            db.add(
                ParadaRecorrido(
                    id_recorrido=id_recorrido, orden=orden, id_parada=id_parada, comprometida=False
                )
            )
    await db.commit()
    return await obtener_recorrido(db, id_recorrido)
