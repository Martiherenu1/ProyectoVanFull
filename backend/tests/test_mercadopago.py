"""CU-036 interno: proveedor/vínculo simulados, PostgreSQL real temporal, sin cobros."""

import asyncio
import logging

import httpx
import pytest
from sqlalchemy import text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.integrations.mercadopago import ClienteMercadoPagoPruebas, NotificacionNoValida
from app.services import pagos as servicio_pagos
from app.services.mercadopago import VinculoOperacionPrueba, procesar_notificacion_prueba
from tests._bd import consultar, ejecutar_sql, url_sqlalchemy
from tests.test_mercadopago_validacion import AHORA, SECRETO, firma, recurso
from tests.test_pagos import entorno as entorno


@pytest.fixture(autouse=True)
def restaurar(entorno):
    base, _, _ = entorno
    asyncio.run(
        ejecutar_sql(
            base,
            "DELETE FROM evento_operativo; DELETE FROM movimiento_cuenta; "
            "DELETE FROM comprobante; UPDATE pago SET estado='PENDIENTE', medio_pago='MERCADO_PAGO'",
        )
    )


async def procesar(db, id_pago, *, datos=None, vinculo=True, cuerpo=None, firma_recibida=None):
    async def resolver(_):
        return VinculoOperacionPrueba("987", id_pago, "ARS", 44) if vinculo else None

    async with httpx.AsyncClient(
        transport=httpx.MockTransport(
            lambda _: httpx.Response(200, json=datos if datos is not None else recurso())
        )
    ) as cliente:
        return await procesar_notificacion_prueba(
            db,
            cuerpo=cuerpo
            if cuerpo is not None
            else {"type": "payment", "live_mode": False, "data": {"id": "987"}},
            data_id="987",
            request_id="peticion-falsa",
            firma=firma_recibida or firma(),
            secreto=SECRETO,
            ahora=AHORA,
            tolerancia_segundos=60,
            proveedor=ClienteMercadoPagoPruebas(cliente, "token-falso"),
            resolver=resolver,
        )


def correr(base, funcion):
    async def run():
        motor = create_async_engine(url_sqlalchemy(base), poolclass=NullPool)
        try:
            async with async_sessionmaker(motor, expire_on_commit=False)() as db:
                return await funcion(db)
        finally:
            await motor.dispose()

    return asyncio.run(run())


def contar(base):
    return asyncio.run(
        consultar(
            base,
            "SELECT (SELECT count(*) FROM comprobante), "
            "(SELECT count(*) FROM movimiento_cuenta), (SELECT count(*) FROM evento_operativo)",
        )
    )[0]


def test_aprobacion_automatica_reutiliza_contabilidad_y_duplicado_no_repite(entorno, caplog):
    base, _, pagos = entorno
    caplog.set_level(logging.INFO, logger="app.services.mercadopago")
    assert correr(base, lambda db: procesar(db, pagos["principal"])) == "confirmado"
    assert correr(base, lambda db: procesar(db, pagos["principal"])) == "duplicado"
    assert contar(base) == (1, 1, 1)
    assert asyncio.run(
        consultar(base, "SELECT estado FROM pago WHERE id_pago=$1", pagos["principal"])
    ) == [("CONFIRMADO",)]
    assert (
        asyncio.run(consultar(base, "SELECT naturaleza,importe FROM movimiento_cuenta"))[0][0]
        == "ACREEDOR"
    )
    assert asyncio.run(consultar(base, "SELECT tipo FROM comprobante")) == [("RECIBO",)]
    assert SECRETO not in caplog.text and "token-falso" not in caplog.text
    assert "mercadopago_resultado=duplicado" in caplog.text


@pytest.mark.parametrize(
    "estado", ["pending", "in_process", "rejected", "authorized", "refunded", "charged_back"]
)
def test_no_acreditados_no_confirman_ni_rechazan_localmente(entorno, estado):
    base, _, pagos = entorno
    assert (
        correr(base, lambda db: procesar(db, pagos["principal"], datos=recurso(status=estado)))
        == "no_acreditado"
    )
    assert contar(base) == (0, 0, 0)
    assert asyncio.run(
        consultar(base, "SELECT estado FROM pago WHERE id_pago=$1", pagos["principal"])
    ) == [("PENDIENTE",)]


@pytest.mark.parametrize(
    "cambios",
    [
        {"vinculo": False},
        {"firma_recibida": "ts=1,v1=falsa"},
        {"cuerpo": {"type": "payment", "live_mode": True, "data": {"id": "987"}}},
        {"cuerpo": {"type": "payment", "live_mode": False, "data": {"id": "988"}}},
        {"datos": recurso(currency_id="USD")},
        {"datos": recurso(collector_id=45)},
        {"datos": recurso(transaction_amount=1)},
        {"datos": recurso(live_mode=True)},
    ],
)
def test_invalido_no_muta_pago(entorno, cambios):
    base, _, pagos = entorno
    with pytest.raises(NotificacionNoValida):
        correr(base, lambda db: procesar(db, pagos["principal"], **cambios))
    assert contar(base) == (0, 0, 0)


@pytest.mark.parametrize("campo,valor", [("estado", "RECHAZADO"), ("medio_pago", "TRANSFERENCIA")])
def test_no_revierte_rechazo_ni_confirma_medio_ajeno(entorno, campo, valor):
    base, _, pagos = entorno
    # Los campos son constantes de la parametrización, nunca entrada HTTP.
    asyncio.run(
        ejecutar_sql(
            base, f"UPDATE pago SET {campo}=$1 WHERE id_pago=$2", valor, pagos["principal"]
        )
    )
    with pytest.raises(NotificacionNoValida):
        correr(base, lambda db: procesar(db, pagos["principal"]))
    assert contar(base) == (0, 0, 0)


def test_fallo_evento_revierte_pago_recibo_y_movimiento(entorno, monkeypatch):
    base, _, pagos = entorno

    async def fallar(*args, **kwargs):
        raise RuntimeError("fallo simulado")

    monkeypatch.setattr(servicio_pagos, "registrar_evento", fallar)
    with pytest.raises(RuntimeError, match="fallo simulado"):
        correr(base, lambda db: procesar(db, pagos["principal"]))
    assert contar(base) == (0, 0, 0)
    assert asyncio.run(
        consultar(base, "SELECT estado FROM pago WHERE id_pago=$1", pagos["principal"])
    ) == [("PENDIENTE",)]


def test_notificaciones_concurrentes_esperan_lock_y_confirman_una_vez(entorno, monkeypatch):
    base, _, pagos = entorno

    async def carrera():
        retenido, continuar = asyncio.Event(), asyncio.Event()
        original = servicio_pagos.registrar_evento

        async def pausar(db, **datos):
            await original(db, **datos)
            retenido.set()
            await continuar.wait()

        monkeypatch.setattr(servicio_pagos, "registrar_evento", pausar)
        motor = create_async_engine(url_sqlalchemy(base), poolclass=NullPool)
        try:
            fabrica = async_sessionmaker(motor, expire_on_commit=False)
            async with fabrica() as db1, fabrica() as db2, fabrica() as observador:
                pid = await db2.scalar(text("SELECT pg_backend_pid()"))
                t1 = asyncio.create_task(procesar(db1, pagos["principal"]))
                t2 = None
                try:
                    await asyncio.wait_for(retenido.wait(), 10)
                    t2 = asyncio.create_task(procesar(db2, pagos["principal"]))

                    async def esperar():
                        while not await observador.scalar(
                            text("SELECT cardinality(pg_blocking_pids(:pid))>0"), {"pid": pid}
                        ):
                            if t2.done():
                                raise AssertionError("No esperó el lock")
                            await asyncio.sleep(0.01)

                    await asyncio.wait_for(esperar(), 10)
                finally:
                    continuar.set()
                    resultados = await asyncio.wait_for(
                        asyncio.gather(*([t1, t2] if t2 else [t1])), 15
                    )
                assert resultados == ["confirmado", "duplicado"]
        finally:
            await motor.dispose()

    asyncio.run(carrera())
    assert contar(base) == (1, 1, 1)
