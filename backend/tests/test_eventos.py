"""`registrar_evento` contra un PostgreSQL real con el esquema migrado."""

import asyncio

import pytest
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.models.trazabilidad import EventoOperativo
from app.services.eventos import MAX_TIPO_EVENTO, registrar_evento
from tests._bd import base_migrada, consultar, ejecutar_sql, url_sqlalchemy


@pytest.fixture(scope="module")
def datos():
    """Una base migrada con un viaje y un pago existentes. Devuelve (base, id_viaje, id_pago)."""
    with base_migrada() as base:
        id_servicio = asyncio.run(
            consultar(
                base,
                "INSERT INTO servicio (tipo_servicio) VALUES ('UNIVERSITARIO') RETURNING id_servicio",
            )
        )[0][0]
        id_recorrido = asyncio.run(
            consultar(base, "INSERT INTO recorrido DEFAULT VALUES RETURNING id_recorrido")
        )[0][0]
        id_viaje = asyncio.run(
            consultar(
                base,
                "INSERT INTO viaje (id_servicio, id_recorrido, fecha, sentido) "
                "VALUES ($1, $2, DATE '2026-10-30', 'IDA') RETURNING id_viaje",
                id_servicio,
                id_recorrido,
            )
        )[0][0]
        id_cliente = asyncio.run(
            consultar(
                base,
                "INSERT INTO cliente (naturaleza_cliente) VALUES ('INDIVIDUAL') RETURNING id_cliente",
            )
        )[0][0]
        asyncio.run(
            ejecutar_sql(base, "INSERT INTO cuenta_corriente (id_cliente) VALUES ($1)", id_cliente)
        )
        id_pago = asyncio.run(
            consultar(
                base,
                "INSERT INTO pago (id_cliente, importe, medio_pago) "
                "VALUES ($1, 100, 'EFECTIVO') RETURNING id_pago",
                id_cliente,
            )
        )[0][0]
        yield base, id_viaje, id_pago


@pytest.fixture(autouse=True)
def _sin_eventos(datos):
    base, _, _ = datos
    asyncio.run(ejecutar_sql(base, "DELETE FROM evento_operativo"))


def _en_sesion(base: str, funcion):
    """Corre `funcion(db)` con una sesión nueva y devuelve su resultado."""

    async def _correr():
        motor = create_async_engine(url_sqlalchemy(base), poolclass=NullPool)
        try:
            async with async_sessionmaker(motor, expire_on_commit=False)() as db:
                return await funcion(db)
        finally:
            await motor.dispose()

    return asyncio.run(_correr())


def _cantidad(base: str) -> int:
    return asyncio.run(consultar(base, "SELECT count(*) FROM evento_operativo"))[0][0]


def test_registra_un_evento_de_viaje(datos):
    base, id_viaje, _ = datos

    async def operacion(db):
        evento = await registrar_evento(
            db, tipo_evento="viaje_iniciado", detalle="Salió de la cochera", id_viaje=id_viaje
        )
        await db.commit()
        return evento.id_evento_operativo

    id_evento = _en_sesion(base, operacion)
    fila = asyncio.run(
        consultar(
            base,
            "SELECT tipo_evento, detalle_evento, id_viaje, id_pago, id_reserva, fecha_hora "
            "FROM evento_operativo WHERE id_evento_operativo = $1",
            id_evento,
        )
    )[0]
    assert fila[:5] == ("viaje_iniciado", "Salió de la cochera", id_viaje, None, None)
    assert fila[5] is not None  # fecha_hora la pone la base


def test_registra_un_evento_de_pago(datos):
    base, _, id_pago = datos

    async def operacion(db):
        await registrar_evento(db, tipo_evento="pago_registrado", id_pago=id_pago)
        await db.commit()

    _en_sesion(base, operacion)
    assert asyncio.run(consultar(base, "SELECT id_pago FROM evento_operativo")) == [(id_pago,)]


def test_un_evento_sin_origen_es_valido(datos):
    base, _, _ = datos

    async def operacion(db):
        await registrar_evento(db, tipo_evento="mantenimiento_programado")
        await db.commit()

    _en_sesion(base, operacion)
    assert _cantidad(base) == 1


def test_dos_origenes_se_rechazan_antes_de_llegar_a_la_base(datos):
    base, id_viaje, id_pago = datos

    async def operacion(db):
        with pytest.raises(ValueError, match="MR-R29"):
            await registrar_evento(db, tipo_evento="x", id_viaje=id_viaje, id_pago=id_pago)

    _en_sesion(base, operacion)
    assert _cantidad(base) == 0


@pytest.mark.parametrize("tipo", ["", "   ", "a" * (MAX_TIPO_EVENTO + 1)])
def test_un_tipo_vacio_o_demasiado_largo_se_rechaza(datos, tipo):
    base, _, _ = datos

    async def operacion(db):
        with pytest.raises(ValueError):
            await registrar_evento(db, tipo_evento=tipo)

    _en_sesion(base, operacion)
    assert _cantidad(base) == 0


def test_el_helper_no_confirma_la_transaccion(datos):
    """El evento va en la transacción del llamador: si ésta se revierte, el evento también."""
    base, id_viaje, _ = datos

    async def operacion(db):
        await registrar_evento(db, tipo_evento="viaje_iniciado", id_viaje=id_viaje)
        await db.rollback()

    _en_sesion(base, operacion)
    assert _cantidad(base) == 0


def test_un_id_que_no_existe_lo_rechaza_la_base(datos):
    base, _, _ = datos

    async def operacion(db):
        with pytest.raises(IntegrityError):
            await registrar_evento(db, tipo_evento="reserva_creada", id_reserva=999_999)

    _en_sesion(base, operacion)
    assert _cantidad(base) == 0


def test_la_base_tambien_controla_los_dos_origenes(datos):
    """Segunda línea de defensa: aunque alguien se salte el helper, el CHECK lo frena."""
    base, id_viaje, id_pago = datos

    async def operacion(db):
        db.add(EventoOperativo(tipo_evento="x", id_viaje=id_viaje, id_pago=id_pago))
        with pytest.raises(IntegrityError, match="evento_operativo_check"):
            await db.flush()

    _en_sesion(base, operacion)
    assert _cantidad(base) == 0
