"""Checkout candidato: PostgreSQL efímero y proveedor HTTP íntegramente simulado."""

import asyncio
import json
from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
from uuid import uuid4

import httpx
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.config import Settings, get_settings
from app.core.database import get_db
from app.core.errors import registrar_manejadores
from app.core.security import crear_token
from app.integrations.checkout import ClienteCheckoutPruebas
from app.routers import pagos
from app.routers.checkout import registrar_checkout_si_habilitado
from app.routers.mercadopago import proveedor_mp, registrar_si_habilitado, reloj_mp
from tests._bd import base_migrada, consultar, ejecutar_sql, url_sqlalchemy
from tests._bd_mercadopago import alembic_mp
from tests.test_mercadopago_validacion import AHORA, SECRETO, firma, recurso
from tests.test_pagos import _crear_pasajero

RUTA = "/api/pagos/mercadopago/checkout"


@pytest.fixture(scope="module")
def base():
    with base_migrada() as nombre:
        r = alembic_mp(nombre, "upgrade", "head")
        assert r.returncode == 0, r.stderr
        yield nombre


@pytest.fixture
def escenario(base):
    asyncio.run(ejecutar_sql(base, "TRUNCATE persona, cliente RESTART IDENTITY CASCADE"))
    persona = _crear_pasajero(base, "91000001", cliente=True, cuenta=True)
    ajustes = Settings(
        _env_file=None,
        env="development",
        database_url=url_sqlalchemy(base),
        mercadopago_sandbox_enabled=True,
        mercadopago_checkout_enabled=True,
        mercadopago_access_token="token-falso",
        mercadopago_webhook_secret=SECRETO,
        mercadopago_collector_id=44,
        mercadopago_currency="ARS",
        mercadopago_checkout_return_url="https://vanfull.invalid/api/pagos/mercadopago/retorno",
        mercadopago_checkout_webhook_url="https://vanfull.invalid/api/webhooks/mercadopago",
    )
    return base, persona, ajustes


@contextmanager
def api(escenario, *, fallo=None, temprano=False):
    base, _, ajustes = escenario
    motor = create_async_engine(url_sqlalchemy(base), poolclass=NullPool)
    fabrica = async_sessionmaker(motor, expire_on_commit=False)
    estado = {
        "posts": 0,
        "referencia": None,
        "live_mode": False,
        "status": "approved",
        "importe": 10000,
        "moneda": "ARS",
        "receptor": 44,
        "orden": "77",
        "preferencia": "44-falsa",
    }
    app = FastAPI()
    registrar_manejadores(app)

    def preferencia():
        return {
            "id": estado["preferencia"],
            "collector_id": 44,
            "external_reference": estado["referencia"],
            "sandbox_init_point": "https://sandbox.mercadopago.com.ar/checkout/v1/redirect?pref_id=44-falsa",
            "items": [{"quantity": 1, "unit_price": 10000, "currency_id": "ARS"}],
        }

    async def transporte(request):
        ruta = request.url.path
        if request.method == "POST":
            assert ruta == "/checkout/preferences"
            estado["posts"] += 1
            cuerpo = json.loads(request.content)
            assert cuerpo["items"][0]["unit_price"] == 10000
            estado["referencia"] = cuerpo["external_reference"]
            if temprano:
                async with httpx.AsyncClient(
                    transport=httpx.ASGITransport(app=app), base_url="http://test"
                ) as cliente:
                    r = await cliente.post(
                        "/api/webhooks/mercadopago?data.id=987",
                        headers=cabeceras(),
                        json=notificacion(),
                    )
                    assert r.status_code == 200, r.text
            if fallo == "timeout":
                raise httpx.ReadTimeout("sintético")
            return httpx.Response(201, json=preferencia())
        if ruta == "/checkout/preferences/search":
            total = 2 if fallo == "ambiguo" else (0 if fallo == "ausente" else 1)
            return httpx.Response(
                200, json={"total": total, "elements": [{"id": "44-falsa"}] * total}
            )
        if ruta.startswith("/checkout/preferences/"):
            return httpx.Response(200, json=preferencia())
        if ruta.startswith("/v1/payments/"):
            return httpx.Response(
                200,
                json=recurso(
                    id=int(ruta.rsplit("/", 1)[1]),
                    live_mode=estado["live_mode"],
                    transaction_amount=estado["importe"],
                    currency_id=estado["moneda"],
                    collector_id=estado["receptor"],
                    status=estado["status"],
                    external_reference=estado["referencia"],
                    order={"id": estado["orden"], "type": "mercadopago"},
                ),
            )
        if ruta == "/merchant_orders/77":
            if estado.get("timeout_orden"):
                raise httpx.ReadTimeout("orden sintética")
            return httpx.Response(
                200,
                json={
                    "id": 77,
                    "collector": {"id": 44},
                    "external_reference": estado["referencia"],
                    "preference_id": "44-falsa",
                    "payments": [{"id": 987}, {"id": 988}],
                },
            )
        raise AssertionError(ruta)

    async def proveedor():
        async with httpx.AsyncClient(transport=httpx.MockTransport(transporte)) as cliente:
            yield ClienteCheckoutPruebas(cliente, "token-falso")

    async def db():
        async with fabrica() as sesion:
            yield sesion

    app.include_router(pagos.router, prefix="/api")
    registrar_si_habilitado(app, ajustes)
    registrar_checkout_si_habilitado(app, ajustes)
    app.dependency_overrides.update(
        {
            get_db: db,
            get_settings: lambda: ajustes,
            proveedor_mp: proveedor,
            reloj_mp: lambda: AHORA,
        }
    )
    with TestClient(app) as cliente:
        yield cliente, estado
    asyncio.run(motor.dispose())


def cabeceras(id_op="987"):
    return {"x-signature": firma(id_operacion=id_op), "x-request-id": "peticion-falsa"}


def notificacion(id_op="987"):
    return {"type": "payment", "live_mode": False, "data": {"id": id_op}}


def iniciar(cliente, escenario, clave=None, **cambios):
    return cliente.post(
        RUTA,
        headers=escenario[1]["headers"],
        json={
            "importe": 10000,
            "medio_pago": "MERCADO_PAGO",
            "clave_solicitud": clave or str(uuid4()),
            **cambios,
        },
    )


def webhook(cliente, id_op="987"):
    return cliente.post(
        "/api/webhooks/mercadopago?data.id=" + id_op,
        headers=cabeceras(id_op),
        json=notificacion(id_op),
    )


def efectos(escenario):
    return asyncio.run(
        consultar(
            escenario[0],
            "SELECT (SELECT count(*) FROM pago), "
            "(SELECT count(*) FROM comprobante), (SELECT count(*) FROM movimiento_cuenta), "
            "(SELECT count(*) FROM pago_mercadopago)",
        )
    )[0]


def test_circuito_completo_consulta_idempotente_y_retorno_no_autoriza(escenario):
    with api(escenario) as (cliente, estado):
        clave = str(uuid4())
        r = iniciar(cliente, escenario, clave)
        assert r.status_code == 200, r.text
        id_pago = r.json()["pago"]["id_pago"]
        assert iniciar(cliente, escenario, clave).json() == r.json()
        assert estado["posts"] == 1
        assert efectos(escenario) == (1, 0, 0, 0)
        assert cliente.get("/api/pagos/mercadopago/retorno?status=approved").status_code == 200
        assert efectos(escenario) == (1, 0, 0, 0)
        assert webhook(cliente).status_code == 200
        assert webhook(cliente).status_code == 200
        assert efectos(escenario) == (1, 1, 1, 1)
        pago = cliente.get(f"/api/pagos/{id_pago}", headers=escenario[1]["headers"])
        assert pago.json()["estado"] == "CONFIRMADO"
        assert iniciar(cliente, escenario, clave).json()["checkout_url"] is None


def test_webhook_temprano_antes_de_guardar_respuesta_preferencia(escenario):
    with api(escenario, temprano=True) as (cliente, estado):
        r = iniciar(cliente, escenario)
        assert r.status_code == 200, r.text
        assert r.json()["pago"]["estado"] == "CONFIRMADO"
        assert r.json()["checkout_url"] is None
        assert efectos(escenario) == (1, 1, 1, 1)
        assert estado["posts"] == 1


@pytest.mark.parametrize("fallo", ["timeout", "ausente", "ambiguo"])
def test_respuesta_incierta_no_repite_post_remoto(escenario, fallo):
    with api(escenario, fallo=fallo) as (cliente, estado):
        clave = str(uuid4())
        if fallo != "timeout":
            # Simular que solo la respuesta POST se perdió, conservando la intención.
            primero = iniciar(cliente, escenario, clave)
            assert primero.status_code == 200
            asyncio.run(
                ejecutar_sql(
                    escenario[0],
                    "UPDATE checkout_mercadopago SET estado_tecnico='INCIERTO', id_preferencia=NULL, url_checkout=NULL",
                )
            )
        else:
            assert iniciar(cliente, escenario, clave).status_code == 202
        r = iniciar(cliente, escenario, clave)
        assert r.status_code == (200 if fallo == "timeout" else 202), r.text
        assert estado["posts"] == 1
        assert efectos(escenario) == (1, 0, 0, 0)


def test_concurrencia_inicio_misma_clave_y_webhooks(escenario):
    with api(escenario) as (cliente, estado):
        clave = str(uuid4())
        with ThreadPoolExecutor(max_workers=2) as pool:
            respuestas = list(pool.map(lambda _: iniciar(cliente, escenario, clave), range(2)))
        assert all(r.status_code in {200, 202} for r in respuestas), [r.text for r in respuestas]
        assert estado["posts"] == 1
        with ThreadPoolExecutor(max_workers=2) as pool:
            respuestas = list(pool.map(lambda _: webhook(cliente), range(2)))
        assert all(r.status_code == 200 for r in respuestas), [r.text for r in respuestas]
        assert efectos(escenario) == (1, 1, 1, 1)


def test_segunda_operacion_distinta_no_duplica_acreditacion(escenario):
    with api(escenario) as (cliente, _):
        assert iniciar(cliente, escenario).status_code == 200
        assert webhook(cliente).status_code == 200
        assert webhook(cliente, "988").status_code == 409
        assert efectos(escenario) == (1, 1, 1, 1)


def test_timeout_orden_no_fija_vinculo_y_reentrega_segura(escenario):
    with api(escenario) as (cliente, estado):
        assert iniciar(cliente, escenario).status_code == 200
        estado["timeout_orden"] = True
        assert webhook(cliente).status_code == 503
        assert efectos(escenario) == (1, 0, 0, 0)
        estado["timeout_orden"] = False
        assert webhook(cliente).status_code == 200
        assert efectos(escenario) == (1, 1, 1, 1)


def test_fallo_cu016_revierte_tambien_vinculo_temprano(escenario, monkeypatch):
    from app.services import pagos as servicio

    original = servicio.registrar_evento

    async def fallar(db, **datos):
        if datos["tipo_evento"] == servicio.TIPO_PAGO_CONFIRMADO:
            raise RuntimeError("fallo contable sintético")
        return await original(db, **datos)

    with api(escenario) as (cliente, _):
        assert iniciar(cliente, escenario).status_code == 200
        monkeypatch.setattr(servicio, "registrar_evento", fallar)
        assert webhook(cliente).status_code == 500
        assert efectos(escenario) == (1, 0, 0, 0)
        monkeypatch.setattr(servicio, "registrar_evento", original)
        assert webhook(cliente).status_code == 200
        assert efectos(escenario) == (1, 1, 1, 1)


def test_no_aprobado_no_fija_operacion_y_puede_aprobar_otro_intento(escenario):
    with api(escenario) as (cliente, estado):
        assert iniciar(cliente, escenario).status_code == 200
        estado["status"] = "rejected"
        assert webhook(cliente).status_code == 200
        assert efectos(escenario) == (1, 0, 0, 0)
        estado["status"] = "approved"
        assert webhook(cliente, "988").status_code == 200
        assert efectos(escenario) == (1, 1, 1, 1)


@pytest.mark.parametrize(
    "campo,valor",
    [
        ("live_mode", True),
        ("importe", 1),
        ("moneda", "USD"),
        ("receptor", 99),
        ("referencia", str(uuid4())),
        ("orden", None),
    ],
)
def test_webhook_no_acredita_operacion_invalida(escenario, campo, valor):
    with api(escenario) as (cliente, estado):
        assert iniciar(cliente, escenario).status_code == 200
        estado[campo] = valor
        assert webhook(cliente).status_code in {400, 409}
        assert efectos(escenario) == (1, 0, 0, 0)


def test_identidad_propiedad_roles_clave_y_validaciones(escenario):
    with api(escenario) as (cliente, _):
        assert cliente.post(RUTA, json={}).status_code == 401
        for rol in ("administrador", "dueno", "chofer"):
            assert (
                cliente.post(
                    RUTA, json={}, headers={"Authorization": f"Bearer {crear_token(1, 1, [rol])}"}
                ).status_code
                == 403
            )
        for cambios in (
            {"importe": 0},
            {"importe": -1},
            {"importe": 0.001},
            {"medio_pago": "BILLETERA"},
            {"id_cliente": 99},
        ):
            assert iniciar(cliente, escenario, **cambios).status_code == 400
        clave = str(uuid4())
        r = iniciar(cliente, escenario, clave)
        assert r.status_code == 200
        assert iniciar(cliente, escenario, clave, importe=5).status_code == 409
        otro = _crear_pasajero(escenario[0], "91000002", cliente=True, cuenta=True)
        assert (
            cliente.get(
                "/api/pagos/" + str(r.json()["pago"]["id_pago"]), headers=otro["headers"]
            ).status_code
            == 404
        )
        assert efectos(escenario) == (1, 0, 0, 0)


def test_rutas_checkout_ausentes_por_defecto():
    app = FastAPI()
    registrar_checkout_si_habilitado(app, Settings(_env_file=None))
    assert not any("mercadopago/checkout" in r.path for r in app.routes)


@pytest.mark.parametrize("despues", [False, True])
def test_commit_respuesta_preferencia_ambiguo_recupera_sin_otro_post(
    escenario, monkeypatch, despues
):
    original = AsyncSession.commit
    veces = 0

    async def commit(db):
        nonlocal veces
        veces += 1
        if veces == 2:
            if despues:
                await original(db)
            raise TimeoutError("commit sintético ambiguo")
        await original(db)

    monkeypatch.setattr(AsyncSession, "commit", commit)
    with api(escenario) as (cliente, estado):
        clave = str(uuid4())
        assert iniciar(cliente, escenario, clave).status_code == 503
        r = iniciar(cliente, escenario, clave)
        assert r.status_code == 200, r.text
        assert r.json()["estado_checkout"] == "LISTO"
        assert estado["posts"] == 1
        assert efectos(escenario) == (1, 0, 0, 0)


@pytest.mark.parametrize(
    "cambio",
    [
        {"sandbox_init_point": None},
        {"sandbox_init_point": ""},
        {"sandbox_init_point": "https://www.mercadopago.com.ar/?pref_id=44-falsa"},
        {"sandbox_init_point": "https://sandbox.mercadopago.com.ar:invalido/?pref_id=44-falsa"},
        {"sandbox_init_point": "https://usuario@sandbox.mercadopago.com.ar/?pref_id=44-falsa"},
        {"sandbox_init_point": "https://sandbox.mercadopago.com.ar/?pref_id=otro"},
        {"external_reference": "otra"},
        {"collector_id": 99},
        {"items": []},
        {"items": [{"quantity": True, "unit_price": 1, "currency_id": "ARS"}]},
        {"items": [{"quantity": 1, "unit_price": "NaN", "currency_id": "ARS"}]},
    ],
)
def test_preferencia_no_admite_fallback_init_point_ni_datos_inseguros(cambio):
    from app.integrations.mercadopago import NotificacionNoValida

    async def run():
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(lambda _: httpx.Response(200))
        ) as http:
            proveedor = ClienteCheckoutPruebas(http, "falso")
            datos = {
                "id": "44-falsa",
                "collector_id": 44,
                "external_reference": "ref",
                "sandbox_init_point": "https://sandbox.mercadopago.com.ar/?pref_id=44-falsa",
                "init_point": "https://www.mercadopago.com.ar/?pref_id=44-falsa",
                "items": [{"quantity": 1, "unit_price": 10000, "currency_id": "ARS"}],
                **cambio,
            }
            with pytest.raises(NotificacionNoValida):
                proveedor._preferencia(datos, "ref", 44)

    asyncio.run(run())
