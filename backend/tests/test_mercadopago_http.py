"""CU-014 → vínculo SQL → webhook HMAC → Payments simulado → CU-016, PostgreSQL local."""

import asyncio
import os
import subprocess
import sys
from contextlib import contextmanager

import asyncpg
import httpx
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from pydantic import ValidationError
from sqlalchemy import text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.config import Settings, get_settings
from app.core.database import get_db
from app.core.errors import ApiError, registrar_manejadores
from app.core.security import crear_token
from app.integrations.mercadopago import ClienteMercadoPagoPruebas
from app.routers import deuda, pagos
from app.routers.mercadopago import proveedor_mp, registrar_si_habilitado, reloj_mp
from app.services import mercadopago_sandbox as servicio_mp
from app.services import pagos as servicio_pagos
from app.services.mercadopago_sandbox import vincular_operacion
from tests._bd import (
    BACKEND,
    alembic,
    base_migrada,
    conectar,
    consultar,
    ejecutar_sql,
    url_sqlalchemy,
)
from tests._bd_mercadopago import alembic_mp
from tests.test_mercadopago_validacion import AHORA, SECRETO, firma, recurso

RUTA = "/api/webhooks/mercadopago?data.id=987"
CUERPO = {"type": "payment", "live_mode": False, "data": {"id": "987"}}
CABECERAS = {"x-signature": firma(), "x-request-id": "peticion-falsa"}


@pytest.fixture(scope="module")
def base():
    with base_migrada() as nombre:
        resultado = alembic_mp(nombre, "upgrade", "head")
        assert resultado.returncode == 0, resultado.stderr
        yield nombre


@pytest.fixture
def entorno(base):
    assert base.startswith("vf_test_")
    asyncio.run(ejecutar_sql(base, "TRUNCATE cliente RESTART IDENTITY CASCADE"))
    id_cliente = asyncio.run(
        consultar(
            base,
            "INSERT INTO cliente(naturaleza_cliente) VALUES ('INDIVIDUAL') RETURNING id_cliente",
        )
    )[0][0]
    asyncio.run(ejecutar_sql(base, "INSERT INTO cuenta_corriente VALUES ($1)", id_cliente))
    ajustes = Settings(
        _env_file=None,
        env="development",
        database_url=url_sqlalchemy(base),
        mercadopago_sandbox_enabled=True,
        mercadopago_access_token="token-falso",
        mercadopago_webhook_secret=SECRETO,
        mercadopago_collector_id=44,
        mercadopago_currency="ARS",
    )
    return base, id_cliente, ajustes


@contextmanager
def api(entorno, responder=None):
    base, _, ajustes = entorno
    motor = create_async_engine(url_sqlalchemy(base), poolclass=NullPool)
    fabrica = async_sessionmaker(motor, expire_on_commit=False)
    llamadas = []

    def transporte(request):
        llamadas.append(request.method)
        assert str(request.url) == "https://api.mercadopago.com/v1/payments/987"
        return responder(request) if responder else httpx.Response(200, json=recurso())

    async def proveedor():
        async with httpx.AsyncClient(transport=httpx.MockTransport(transporte)) as cliente:
            yield ClienteMercadoPagoPruebas(cliente, "token-falso")

    async def db():
        async with fabrica() as sesion:
            yield sesion

    app = FastAPI()
    registrar_manejadores(app)
    app.include_router(pagos.router, prefix="/api")
    app.include_router(deuda.router, prefix="/api")
    registrar_si_habilitado(app, ajustes)
    app.dependency_overrides.update(
        {
            get_db: db,
            get_settings: lambda: ajustes,
            proveedor_mp: proveedor,
            reloj_mp: lambda: AHORA,
        }
    )
    with TestClient(app) as cliente:
        yield cliente, llamadas, app, fabrica
    asyncio.run(motor.dispose())


def registrar(cliente, entorno):
    r = cliente.post(
        "/api/pagos",
        json={"id_cliente": entorno[1], "importe": 1250.50, "medio_pago": "MERCADO_PAGO"},
        headers={"Authorization": f"Bearer {crear_token(1, 1, ['administrador'])}"},
    )
    assert r.status_code == 201, r.text
    return r.json()["id_pago"]


def vincular(entorno, id_pago, *, id_operacion="987", datos=None):
    async def run():
        motor = create_async_engine(url_sqlalchemy(entorno[0]), poolclass=NullPool)
        try:
            async with (
                async_sessionmaker(motor, expire_on_commit=False)() as db,
                httpx.AsyncClient(
                    transport=httpx.MockTransport(
                        lambda _: httpx.Response(200, json=datos or recurso(id=int(id_operacion)))
                    )
                ) as http,
            ):
                return await vincular_operacion(
                    db,
                    id_operacion=id_operacion,
                    id_pago=id_pago,
                    proveedor=ClienteMercadoPagoPruebas(http, "token-falso"),
                    ajustes=entorno[2],
                )
        finally:
            await motor.dispose()

    return asyncio.run(run())


def estado(entorno, id_pago):
    return asyncio.run(consultar(entorno[0], "SELECT estado FROM pago WHERE id_pago=$1", id_pago))[
        0
    ][0]


def efectos(entorno):
    return asyncio.run(
        consultar(
            entorno[0],
            "SELECT (SELECT count(*) FROM comprobante), (SELECT count(*) FROM movimiento_cuenta), "
            "(SELECT count(*) FROM evento_operativo WHERE tipo_evento='pago_confirmado')",
        )
    )[0]


def test_circuito_http_completo_y_duplicado_tras_respuesta_perdida(entorno):
    with api(entorno) as (cliente, llamadas, _, _):
        id_pago = registrar(cliente, entorno)
        asyncio.run(
            ejecutar_sql(
                entorno[0],
                "INSERT INTO movimiento_cuenta(id_cliente,naturaleza,importe) VALUES ($1,'DEUDOR',2000)",
                entorno[1],
            )
        )
        assert vincular(entorno, id_pago) == "vinculado"
        assert estado(entorno, id_pago) == "PENDIENTE"
        assert vincular(entorno, id_pago) == "vinculo_existente"
        r = cliente.post(RUTA, headers=CABECERAS, json=CUERPO)
        assert r.status_code == 200 and r.content == b""
        # Simular que el emisor no recibió el primer ACK: entregar de nuevo.
        assert cliente.post(RUTA, headers=CABECERAS, json=CUERPO).status_code == 200
        assert estado(entorno, id_pago) == "CONFIRMADO"
        assert efectos(entorno) == (1, 2, 1)
        assert llamadas == ["GET", "GET"]
        r = cliente.get(
            f"/api/clientes/{entorno[1]}/deuda",
            headers={"Authorization": f"Bearer {crear_token(1, 1, ['administrador'])}"},
        )
        assert r.status_code == 200 and float(r.json()["saldo"]) == 749.5


@pytest.mark.parametrize(
    "cambios,codigo",
    [
        ({"headers": {"x-request-id": "peticion-falsa", "x-signature": "falsa"}}, 401),
        ({"headers": {}}, 401),
        ({"json": {**CUERPO, "live_mode": True}}, 400),
        ({"json": {**CUERPO, "type": "merchant_order"}}, 400),
        ({"json": {**CUERPO, "data": {"id": "988"}}}, 400),
        ({"json": {**CUERPO, "live_mode": "false"}}, 400),
        ({"json": {**CUERPO, "data": {"id": True}}}, 400),
        ({"json": {**CUERPO, "data": {"id": False}}}, 400),
        ({"json": {**CUERPO, "data": {"id": 987.0}}}, 400),
        ({"json": {**CUERPO, "data": {"id": -1}}}, 400),
        ({"json": {**CUERPO, "data": {"id": "../987"}}}, 400),
    ],
)
def test_http_invalido_no_consulta_proveedor_ni_muta(entorno, cambios, codigo):
    with api(entorno) as (cliente, llamadas, _, _):
        id_pago = registrar(cliente, entorno)
        r = cliente.post(RUTA, **({"headers": CABECERAS, "json": CUERPO} | cambios))
        assert r.status_code == codigo
        assert llamadas == [] and estado(entorno, id_pago) == "PENDIENTE"
        assert efectos(entorno) == (0, 0, 0)


@pytest.mark.parametrize(
    "cambios",
    [
        {"live_mode": True},
        {"transaction_amount": 1},
        {"currency_id": "USD"},
        {"collector_id": 45},
        {"id": 988},
    ],
)
def test_http_rechaza_recurso_incompatible_y_live_mode_true(entorno, cambios):
    with api(entorno, lambda _: httpx.Response(200, json=recurso(**cambios))) as (cliente, _, _, _):
        id_pago = registrar(cliente, entorno)
        vincular(entorno, id_pago)
        assert cliente.post(RUTA, headers=CABECERAS, json=CUERPO).status_code == 409
        assert estado(entorno, id_pago) == "PENDIENTE" and efectos(entorno) == (0, 0, 0)


def test_sin_vinculo_no_consulta_payments(entorno):
    with api(entorno) as (cliente, llamadas, _, _):
        registrar(cliente, entorno)
        assert cliente.post(RUTA, headers=CABECERAS, json=CUERPO).status_code == 409
        assert llamadas == []


@pytest.mark.parametrize("fallo", ["timeout", 429, 500])
def test_http_transitorio_permite_nueva_entrega_segura(entorno, fallo):
    contador = 0

    def responder(request):
        nonlocal contador
        contador += 1
        if contador == 1:
            if fallo == "timeout":
                raise httpx.ReadTimeout("token-falso", request=request)
            return httpx.Response(fallo, text="token-falso")
        return httpx.Response(200, json=recurso())

    with api(entorno, responder) as (cliente, _, _, _):
        id_pago = registrar(cliente, entorno)
        vincular(entorno, id_pago)
        r = cliente.post(RUTA, headers=CABECERAS, json=CUERPO)
        assert r.status_code == 503 and "token-falso" not in r.text
        assert estado(entorno, id_pago) == "PENDIENTE" and efectos(entorno) == (0, 0, 0)
        assert cliente.post(RUTA, headers=CABECERAS, json=CUERPO).status_code == 200
        assert efectos(entorno) == (1, 1, 1)


def test_fallo_contable_http_rollback_y_reintento(entorno, monkeypatch):
    original = servicio_pagos.registrar_evento

    async def fallar(*args, **kwargs):
        raise RuntimeError("detalle secreto que no debe devolverse")

    with api(entorno) as (cliente, _, _, _):
        id_pago = registrar(cliente, entorno)
        vincular(entorno, id_pago)
        monkeypatch.setattr(servicio_pagos, "registrar_evento", fallar)
        r = cliente.post(RUTA, headers=CABECERAS, json=CUERPO)
        assert r.status_code == 500 and "secreto" not in r.text
        assert efectos(entorno) == (0, 0, 0) and estado(entorno, id_pago) == "PENDIENTE"
        monkeypatch.setattr(servicio_pagos, "registrar_evento", original)
        assert cliente.post(RUTA, headers=CABECERAS, json=CUERPO).status_code == 200


@pytest.mark.parametrize("campo", ["misma_operacion", "mismo_pago"])
def test_vinculo_persistente_no_se_reasigna(entorno, campo):
    with api(entorno) as (cliente, _, _, _):
        primero, segundo = registrar(cliente, entorno), registrar(cliente, entorno)
        vincular(entorno, primero)
        with pytest.raises(ApiError) as error:
            vincular(
                entorno,
                segundo if campo == "misma_operacion" else primero,
                id_operacion="987" if campo == "misma_operacion" else "988",
            )
        assert error.value.status_code == 409
        assert asyncio.run(consultar(entorno[0], "SELECT count(*) FROM pago_mercadopago")) == [(1,)]


def test_concurrencia_http_con_cu016_confirma_una_vez(entorno, monkeypatch):
    async def carrera(app, fabrica, id_pago):
        retenido, continuar = asyncio.Event(), asyncio.Event()
        original = servicio_pagos.registrar_evento

        async def pausar(db, **datos):
            await original(db, **datos)
            retenido.set()
            await continuar.wait()

        monkeypatch.setattr(servicio_pagos, "registrar_evento", pausar)
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app), base_url="http://test"
        ) as http:
            t1 = asyncio.create_task(http.post(RUTA, headers=CABECERAS, json=CUERPO))
            tareas = [t1]
            try:
                await asyncio.wait_for(retenido.wait(), 5)
                tareas += [
                    asyncio.create_task(http.post(RUTA, headers=CABECERAS, json=CUERPO)),
                    asyncio.create_task(
                        http.post(
                            f"/api/pagos/{id_pago}/confirmacion",
                            json={"decision": "CONFIRMADO"},
                            headers={
                                "Authorization": f"Bearer {crear_token(1, 1, ['administrador'])}"
                            },
                        )
                    ),
                ]
                async with fabrica() as observador:

                    async def esperar_locks():
                        while True:
                            # pg_stat_activity cachea la lista de sesiones en la transacción;
                            # refrescar para observar conexiones creadas después del primer poll.
                            await observador.execute(text("SELECT pg_stat_clear_snapshot()"))
                            bloqueados = await observador.scalar(
                                text(
                                    "SELECT count(*) FROM pg_stat_activity "
                                    "WHERE datname=current_database() AND cardinality(pg_blocking_pids(pid))>0"
                                )
                            )
                            if bloqueados >= 2:
                                return
                            await asyncio.sleep(0.01)

                    await asyncio.wait_for(esperar_locks(), 1.5)
            finally:
                continuar.set()
                respuestas = await asyncio.wait_for(asyncio.gather(*tareas), 5)
        assert [r.status_code for r in respuestas] == [200, 200, 404]

    with api(entorno) as (cliente, _, app, fabrica):
        id_pago = registrar(cliente, entorno)
        vincular(entorno, id_pago)
        asyncio.run(carrera(app, fabrica, id_pago))
        assert efectos(entorno) == (1, 1, 1)


def test_router_desactivado_y_configuracion_cerrada():
    ajustes = Settings(_env_file=None)
    app = FastAPI()
    registrar_si_habilitado(app, ajustes)
    assert TestClient(app).post(RUTA, json=CUERPO).status_code == 404
    for cambios in (
        {"env": "production"},
        {"database_url": "postgresql+asyncpg://x:x@neon.example/x"},
        {"database_url": "postgresql+asyncpg://x:x@db/vanfull"},
    ):
        with pytest.raises(ValidationError):
            Settings(_env_file=None, mercadopago_sandbox_enabled=True, **cambios)


def test_migracion_candidata_reversible_y_metadata_coherente(base):
    assert alembic_mp(base, "check").returncode == 0
    assert alembic_mp(base, "downgrade", "base").returncode == 0
    assert asyncio.run(consultar(base, "SELECT to_regclass('pago_mercadopago')")) == [(None,)]
    assert alembic_mp(base, "upgrade", "head").returncode == 0
    # La cadena normal sigue en 0001 y no intenta borrar la extensión optativa.
    assert alembic(base, "upgrade", "head").returncode == 0
    assert alembic(base, "check").returncode == 0


@pytest.mark.parametrize(
    "sentencia",
    [
        "INSERT INTO pago_mercadopago SELECT '988',id_pago,id_receptor,moneda,now() FROM pago_mercadopago",
        "INSERT INTO pago_mercadopago SELECT id_operacion,id_pago+99999,id_receptor,moneda,now() FROM pago_mercadopago",
        "UPDATE pago_mercadopago SET id_pago=99999999",
        "UPDATE pago_mercadopago SET moneda='ars'",
        "UPDATE pago_mercadopago SET id_operacion='../../payments'",
        "DELETE FROM pago",
    ],
)
def test_restricciones_sql_del_vinculo(entorno, sentencia):
    with api(entorno) as (cliente, _, _, _):
        id_pago = registrar(cliente, entorno)
        vincular(entorno, id_pago)
        if sentencia == "DELETE FROM pago":
            # Aislar la FK RESTRICT del vínculo: el evento del registro también referencia Pago.
            asyncio.run(ejecutar_sql(entorno[0], "DELETE FROM evento_operativo"))
        with pytest.raises(asyncpg.IntegrityConstraintViolationError):
            asyncio.run(ejecutar_sql(entorno[0], sentencia))
        assert estado(entorno, id_pago) == "PENDIENTE"


@pytest.mark.parametrize("status", ["pending", "rejected"])
def test_http_no_aprobado_no_genera_contabilidad(entorno, status):
    with api(entorno, lambda _: httpx.Response(200, json=recurso(status=status))) as (
        cliente,
        _,
        _,
        _,
    ):
        id_pago = registrar(cliente, entorno)
        vincular(entorno, id_pago)
        assert cliente.post(RUTA, headers=CABECERAS, json=CUERPO).status_code == 200
        assert estado(entorno, id_pago) == "PENDIENTE" and efectos(entorno) == (0, 0, 0)


def test_http_timeout_del_lock_no_confirma_y_permite_reintento(entorno):
    with api(entorno) as (cliente, _, app, _):
        id_pago = registrar(cliente, entorno)
        vincular(entorno, id_pago)

        async def run():
            conn = await conectar(entorno[0])
            transaccion = conn.transaction()
            await transaccion.start()
            try:
                await conn.fetchrow("SELECT id_pago FROM pago WHERE id_pago=$1 FOR UPDATE", id_pago)
                async with httpx.AsyncClient(
                    transport=httpx.ASGITransport(app=app), base_url="http://test"
                ) as http:
                    r = await http.post(RUTA, headers=CABECERAS, json=CUERPO)
                    assert r.status_code == 503
                    assert r.json()["error"]["codigo"] == "INTEGRACION_NO_DISPONIBLE"
            finally:
                await transaccion.rollback()
                await conn.close()

        asyncio.run(run())
        assert efectos(entorno) == (0, 0, 0) and estado(entorno, id_pago) == "PENDIENTE"
        assert cliente.post(RUTA, headers=CABECERAS, json=CUERPO).status_code == 200


def test_vincular_concurrentemente_misma_operacion_a_pagos_distintos(entorno):
    with api(entorno) as (cliente, _, _, _):
        ids = [registrar(cliente, entorno), registrar(cliente, entorno)]

        async def run():
            motor = create_async_engine(url_sqlalchemy(entorno[0]), poolclass=NullPool)
            llegaron = 0
            liberar = asyncio.Event()

            async def responder(_):
                nonlocal llegaron
                llegaron += 1
                if llegaron == 2:
                    liberar.set()
                await asyncio.wait_for(liberar.wait(), 5)
                return httpx.Response(200, json=recurso())

            async def alta(id_pago):
                async with (
                    async_sessionmaker(motor, expire_on_commit=False)() as db,
                    httpx.AsyncClient(transport=httpx.MockTransport(responder)) as http,
                ):
                    try:
                        return await vincular_operacion(
                            db,
                            id_operacion="987",
                            id_pago=id_pago,
                            proveedor=ClienteMercadoPagoPruebas(http, "token-falso"),
                            ajustes=entorno[2],
                        )
                    except ApiError as error:
                        return error.status_code

            try:
                resultados = await asyncio.wait_for(
                    asyncio.gather(*(alta(id_pago) for id_pago in ids)), 8
                )
                assert resultados.count("vinculado") == 1 and resultados.count(409) == 1
            finally:
                await motor.dispose()

        asyncio.run(run())
        assert asyncio.run(consultar(entorno[0], "SELECT count(*) FROM pago_mercadopago")) == [(1,)]
        assert efectos(entorno) == (0, 0, 0)


def test_app_real_registra_ruta_solo_con_habilitacion_local(entorno):
    env = {
        **os.environ,
        "ENV": "development",
        "DATABASE_URL": url_sqlalchemy(entorno[0]),
        "MERCADOPAGO_SANDBOX_ENABLED": "true",
        "MERCADOPAGO_ACCESS_TOKEN": "token-falso",
        "MERCADOPAGO_WEBHOOK_SECRET": SECRETO,
        "MERCADOPAGO_COLLECTOR_ID": "44",
        "MERCADOPAGO_CURRENCY": "ARS",
    }
    resultado = subprocess.run(
        [
            sys.executable,
            "-c",
            "from app.main import app; assert '/api/webhooks/mercadopago' in app.openapi()['paths']",
        ],
        cwd=BACKEND,
        env=env,
        capture_output=True,
        text=True,
        timeout=20,
    )
    assert resultado.returncode == 0


@pytest.mark.parametrize(
    "decision,codigo,asientos", [("CONFIRMADO", 200, 1), ("RECHAZADO", 409, 0)]
)
def test_cu016_gana_carrera_antes_del_webhook(entorno, monkeypatch, decision, codigo, asientos):
    async def carrera(app, fabrica, id_pago):
        retenido, continuar = asyncio.Event(), asyncio.Event()
        original = servicio_pagos.registrar_evento

        async def pausar(db, **datos):
            await original(db, **datos)
            retenido.set()
            await continuar.wait()

        monkeypatch.setattr(servicio_pagos, "registrar_evento", pausar)
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app), base_url="http://test"
        ) as http:
            admin = asyncio.create_task(
                http.post(
                    f"/api/pagos/{id_pago}/confirmacion",
                    json={"decision": decision},
                    headers={"Authorization": f"Bearer {crear_token(1, 1, ['administrador'])}"},
                )
            )
            webhook = None
            try:
                await asyncio.wait_for(retenido.wait(), 5)
                webhook = asyncio.create_task(http.post(RUTA, headers=CABECERAS, json=CUERPO))
                async with fabrica() as observador:

                    async def esperar():
                        while True:
                            await observador.execute(text("SELECT pg_stat_clear_snapshot()"))
                            if (
                                await observador.scalar(
                                    text(
                                        "SELECT count(*) FROM pg_stat_activity "
                                        "WHERE datname=current_database() AND cardinality(pg_blocking_pids(pid))>0"
                                    )
                                )
                                > 0
                            ):
                                return
                            if webhook.done():
                                raise AssertionError("Webhook no espero el lock de CU-016")
                            await asyncio.sleep(0.01)

                    await asyncio.wait_for(esperar(), 1.5)
            finally:
                continuar.set()
                respuestas = await asyncio.wait_for(
                    asyncio.gather(*([admin, webhook] if webhook else [admin])), 5
                )
        assert [r.status_code for r in respuestas] == [200, codigo]

    with api(entorno) as (cliente, _, app, fabrica):
        id_pago = registrar(cliente, entorno)
        vincular(entorno, id_pago)
        asyncio.run(carrera(app, fabrica, id_pago))
        assert estado(entorno, id_pago) == decision
        assert efectos(entorno) == (asientos, asientos, asientos)


def test_timeout_global_revierte_antes_de_commit_y_reentrega_confirma(entorno, monkeypatch):
    assert servicio_mp.PRESUPUESTO_SEGUNDOS == 15
    original = servicio_pagos.registrar_evento

    async def esperar(db, **datos):
        await original(db, **datos)
        await asyncio.Event().wait()

    with api(entorno) as (cliente, _, _, _):
        id_pago = registrar(cliente, entorno)
        vincular(entorno, id_pago)
        monkeypatch.setattr(servicio_pagos, "registrar_evento", esperar)
        monkeypatch.setattr(servicio_mp, "PRESUPUESTO_SEGUNDOS", 0.3)
        r = cliente.post(RUTA, headers=CABECERAS, json=CUERPO)
        assert r.status_code == 503 and r.json()["error"]["codigo"] == "INTEGRACION_NO_DISPONIBLE"
        assert estado(entorno, id_pago) == "PENDIENTE" and efectos(entorno) == (0, 0, 0)
        monkeypatch.setattr(servicio_pagos, "registrar_evento", original)
        monkeypatch.setattr(servicio_mp, "PRESUPUESTO_SEGUNDOS", 15)
        assert cliente.post(RUTA, headers=CABECERAS, json=CUERPO).status_code == 200
        assert efectos(entorno) == (1, 1, 1)


@pytest.mark.parametrize("frontera", ["antes", "despues"])
def test_resultado_ambiguo_del_commit_reintento_no_duplica(entorno, monkeypatch, frontera):
    with api(entorno) as (cliente, _, _, _):
        id_pago = registrar(cliente, entorno)
        vincular(entorno, id_pago)
        original = servicio_mp.AsyncSession.commit
        primera = True

        async def commit(db):
            nonlocal primera
            if primera:
                primera = False
                if frontera == "despues":
                    await original(db)
                raise TimeoutError("detalle que no debe exponerse")
            return await original(db)

        monkeypatch.setattr(servicio_mp.AsyncSession, "commit", commit)
        r = cliente.post(RUTA, headers=CABECERAS, json=CUERPO)
        assert r.status_code == 503 and "detalle" not in r.text
        assert estado(entorno, id_pago) == ("CONFIRMADO" if frontera == "despues" else "PENDIENTE")
        assert efectos(entorno) == ((1, 1, 1) if frontera == "despues" else (0, 0, 0))
        assert cliente.post(RUTA, headers=CABECERAS, json=CUERPO).status_code == 200
        assert estado(entorno, id_pago) == "CONFIRMADO" and efectos(entorno) == (1, 1, 1)


def test_perdida_de_respuesta_http_despues_de_commit_no_duplica(entorno):
    with api(entorno) as (cliente, _, app, _):
        id_pago = registrar(cliente, entorno)
        vincular(entorno, id_pago)

        async def run():
            class PerderACK(httpx.AsyncBaseTransport):
                async def handle_async_request(self, request):
                    respuesta = await httpx.ASGITransport(app=app).handle_async_request(request)
                    assert respuesta.status_code == 200
                    await respuesta.aclose()
                    raise httpx.ReadError("ACK simulado perdido", request=request)

            async with httpx.AsyncClient(transport=PerderACK(), base_url="http://test") as http:
                with pytest.raises(httpx.ReadError):
                    await http.post(RUTA, headers=CABECERAS, json=CUERPO)

        asyncio.run(run())
        assert estado(entorno, id_pago) == "CONFIRMADO" and efectos(entorno) == (1, 1, 1)
        assert cliente.post(RUTA, headers=CABECERAS, json=CUERPO).status_code == 200
        assert efectos(entorno) == (1, 1, 1)


@pytest.mark.parametrize("valor,id_operacion", [(True, "1"), (False, "0"), (987.0, "987")])
def test_id_no_entero_estricto_se_rechaza_incluso_con_query_y_firma_coincidentes(
    entorno, valor, id_operacion
):
    # Reproduce exactamente el bug true -> 1: no depender de un mismatch 1 != 987.
    with api(entorno) as (cliente, llamadas, _, _):
        id_pago = registrar(cliente, entorno)
        r = cliente.post(
            f"/api/webhooks/mercadopago?data.id={id_operacion}",
            json={**CUERPO, "data": {"id": valor}},
            headers={
                "x-request-id": "peticion-falsa",
                "x-signature": firma(id_operacion=id_operacion),
            },
        )
        assert r.status_code == 400 and r.json()["error"]["codigo"] == "VALIDACION"
        assert llamadas == [] and efectos(entorno) == (0, 0, 0)
        assert estado(entorno, id_pago) == "PENDIENTE"


def test_id_entero_json_valido_sigue_admitido(entorno):
    with api(entorno) as (cliente, _, _, _):
        id_pago = registrar(cliente, entorno)
        vincular(entorno, id_pago)
        assert (
            cliente.post(RUTA, headers=CABECERAS, json={**CUERPO, "data": {"id": 987}}).status_code
            == 200
        )
        assert estado(entorno, id_pago) == "CONFIRMADO" and efectos(entorno) == (1, 1, 1)
