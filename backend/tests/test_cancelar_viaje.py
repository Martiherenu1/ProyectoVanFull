"""Recorte local #180, pendiente de confirmación final; PostgreSQL real."""

import asyncio

import pytest
from sqlalchemy import text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.errors import ApiError
from app.core.security import UsuarioActual
from app.schemas.reservas import ReservaCreate
from app.services import ejecucion_viajes, reservas, viajes
from tests._bd import consultar, ejecutar_sql, url_sqlalchemy
from tests.test_viajes import _con, _en_sesion, _uno, _viaje_para_listado
from tests.test_viajes import entorno as entorno  # Reutiliza la base temporal CU-018.


@pytest.fixture(autouse=True)
def limpiar(entorno):
    asyncio.run(
        ejecutar_sql(
            entorno["base"],
            "DELETE FROM evento_operativo; DELETE FROM registro_lista_espera; "
            "DELETE FROM reserva; DELETE FROM periodo_abono_viaje; DELETE FROM viaje",
        )
    )


def cancelar(entorno, id_viaje, roles=("administrador",)):
    return entorno["http"].post(f"/api/viajes/{id_viaje}/cancelacion", headers=_con(list(roles)))


@pytest.mark.parametrize("rol", ["administrador", "dueno"])
def test_cancelacion_logica_con_evento_y_sin_borrar(entorno, rol):
    id_viaje = _viaje_para_listado(entorno)
    respuesta = cancelar(entorno, id_viaje, (rol,))
    assert respuesta.status_code == 200
    assert respuesta.json()["estado"] == "cancelado"
    assert (
        _uno(entorno["base"], "SELECT estado FROM viaje WHERE id_viaje=$1", id_viaje) == "cancelado"
    )
    assert (
        _uno(
            entorno["base"], "SELECT tipo_evento FROM evento_operativo WHERE id_viaje=$1", id_viaje
        )
        == "viaje_cancelado"
    )
    assert cancelar(entorno, id_viaje).status_code == 409


@pytest.mark.parametrize("estado", ["en_curso", "finalizado", "cancelado"])
def test_rechaza_estado_incompatible(entorno, estado):
    respuesta = cancelar(entorno, _viaje_para_listado(entorno, estado=estado))
    assert respuesta.status_code == 409
    assert respuesta.json()["error"]["codigo"] == "ESTADO_VIAJE_INVALIDO"


@pytest.mark.parametrize("tipo", ["ESPECIAL", "CORPORATIVO"])
def test_excluye_servicios(entorno, tipo):
    id_viaje = _viaje_para_listado(entorno)
    servicio = _uno(
        entorno["base"],
        "INSERT INTO servicio (tipo_servicio) VALUES ($1) RETURNING id_servicio",
        tipo,
    )
    asyncio.run(
        ejecutar_sql(
            entorno["base"], "UPDATE viaje SET id_servicio=$1 WHERE id_viaje=$2", servicio, id_viaje
        )
    )
    respuesta = cancelar(entorno, id_viaje)
    assert respuesta.status_code == 409
    assert respuesta.json()["error"]["codigo"] == "ESTADO_VIAJE_INVALIDO"


@pytest.mark.parametrize(
    "estado,bloquea", [("provisional", True), ("consolidada", True), ("cancelada", False)]
)
def test_reservas_solo_vigentes_impiden_cancelacion(entorno, estado, bloquea):
    id_viaje = _viaje_para_listado(entorno)
    asyncio.run(
        ejecutar_sql(
            entorno["base"],
            "INSERT INTO reserva (id_pasajero,id_viaje,id_recorrido,orden_parada,id_contratacion_directa,estado) VALUES ($1,$2,$3,1,$4,$5)",
            entorno["pasajeros"][0],
            id_viaje,
            entorno["id_recorrido"],
            entorno["id_contratacion"],
            estado,
        )
    )
    respuesta = cancelar(entorno, id_viaje)
    assert respuesta.status_code == (409 if bloquea else 200)
    if bloquea:
        assert respuesta.json()["error"]["codigo"] == "VIAJE_CON_COMPROMISOS"
        assert (
            _uno(entorno["base"], "SELECT estado FROM viaje WHERE id_viaje=$1", id_viaje)
            == "programado"
        )
    assert _uno(entorno["base"], "SELECT count(*) FROM reserva") == 1


@pytest.mark.parametrize(
    "estado,bloquea", [("en_espera", True), ("cancelada", False), ("EN_ESPERA", False)]
)
def test_lista_espera_estado_exacto(entorno, estado, bloquea):
    id_viaje = _viaje_para_listado(entorno)
    asyncio.run(
        ejecutar_sql(
            entorno["base"],
            "INSERT INTO registro_lista_espera (id_pasajero,id_viaje,estado) VALUES ($1,$2,$3)",
            entorno["pasajeros"][0],
            id_viaje,
            estado,
        )
    )
    respuesta = cancelar(entorno, id_viaje)
    assert respuesta.status_code == (409 if bloquea else 200)
    if bloquea:
        assert respuesta.json()["error"]["codigo"] == "VIAJE_CON_COMPROMISOS"
    assert _uno(entorno["base"], "SELECT count(*) FROM registro_lista_espera") == 1


def test_vinculo_abono_sin_reserva_impide_cancelacion(entorno):
    id_viaje = _viaje_para_listado(entorno)
    abono = _uno(
        entorno["base"],
        "INSERT INTO abono_mensual (id_contratacion,id_pasajero) VALUES ($1,$2) RETURNING id_abono_mensual",
        entorno["id_contratacion"],
        entorno["pasajeros"][0],
    )
    periodo = _uno(
        entorno["base"],
        "INSERT INTO periodo_abono (id_abono_mensual,periodo) VALUES ($1,'2026-10') RETURNING id_periodo_abono",
        abono,
    )
    asyncio.run(
        ejecutar_sql(
            entorno["base"], "INSERT INTO periodo_abono_viaje VALUES ($1,$2)", periodo, id_viaje
        )
    )
    respuesta = cancelar(entorno, id_viaje)
    assert respuesta.status_code == 409
    assert respuesta.json()["error"]["codigo"] == "VIAJE_CON_COMPROMISOS"
    assert _uno(entorno["base"], "SELECT count(*) FROM periodo_abono_viaje") == 1


def test_autorizacion_y_no_encontrado(entorno):
    assert entorno["http"].post("/api/viajes/999999/cancelacion").status_code == 401
    for rol in ("pasajero", "chofer"):
        assert cancelar(entorno, 999999, (rol,)).status_code == 403
    assert cancelar(entorno, 999999).status_code == 404


def test_fallo_evento_revierte_cancelacion(entorno, monkeypatch):
    id_viaje = _viaje_para_listado(entorno)

    async def fallar(*args, **kwargs):
        raise RuntimeError("evento fallido")

    monkeypatch.setattr(viajes, "registrar_evento", fallar)
    with pytest.raises(RuntimeError, match="evento fallido"):
        _en_sesion(entorno["base"], lambda db: viajes.cancelar_viaje(db, id_viaje))
    assert (
        _uno(entorno["base"], "SELECT estado FROM viaje WHERE id_viaje=$1", id_viaje)
        == "programado"
    )
    assert asyncio.run(consultar(entorno["base"], "SELECT count(*) FROM evento_operativo")) == [
        (0,)
    ]


@pytest.mark.parametrize("rival", ["reserva", "inicio"])
@pytest.mark.parametrize("primero_cancela", [True, False])
def test_carrera_serializa_transicion_y_compromisos(entorno, monkeypatch, rival, primero_cancela):
    id_viaje = _viaje_para_listado(entorno, asignado=True)

    async def carrera():
        motor = create_async_engine(url_sqlalchemy(entorno["base"]), poolclass=NullPool)
        retenido, soltar = asyncio.Event(), asyncio.Event()
        modulo = viajes if primero_cancela else reservas if rival == "reserva" else ejecucion_viajes
        original = modulo.registrar_evento

        async def pausa(db, **datos):
            await original(db, **datos)
            retenido.set()
            await soltar.wait()

        monkeypatch.setattr(modulo, "registrar_evento", pausa)
        try:
            fabrica = async_sessionmaker(motor, expire_on_commit=False)
            async with fabrica() as db1, fabrica() as db2, fabrica() as observador:
                pid2 = await db2.scalar(text("SELECT pg_backend_pid()"))

                async def otra(db):
                    usuario = UsuarioActual(
                        id_cuenta_acceso=1,
                        id_persona=entorno["pasajeros"][0]
                        if rival == "reserva"
                        else entorno["id_chofer"],
                        roles=("pasajero",) if rival == "reserva" else ("chofer",),
                    )
                    if rival == "reserva":
                        return await reservas.crear_reserva(
                            db, usuario, ReservaCreate(id_viaje=id_viaje, orden_parada=1)
                        )
                    return await ejecucion_viajes.iniciar_viaje(db, usuario, id_viaje)

                async def cancelar_local(db):
                    return await viajes.cancelar_viaje(db, id_viaje)

                primera, segunda = (
                    (cancelar_local, otra) if primero_cancela else (otra, cancelar_local)
                )
                t1 = asyncio.create_task(primera(db1))
                t2 = None
                try:
                    await asyncio.wait_for(retenido.wait(), 10)
                    t2 = asyncio.create_task(segunda(db2))

                    async def esperar_lock():
                        while not await observador.scalar(
                            text("SELECT cardinality(pg_blocking_pids(:pid)) > 0"), {"pid": pid2}
                        ):
                            if t2.done():
                                raise AssertionError("La segunda operación no esperó el lock")
                            await asyncio.sleep(0.01)

                    await asyncio.wait_for(esperar_lock(), 10)
                finally:
                    soltar.set()
                    resultados = await asyncio.wait_for(
                        asyncio.gather(*([t1, t2] if t2 else [t1]), return_exceptions=True), 15
                    )
                assert not isinstance(resultados[0], Exception), resultados[0]
                assert isinstance(resultados[1], ApiError), resultados[1]
                esperado = (
                    ("VIAJE_NO_RESERVABLE" if rival == "reserva" else "VIAJE_CANCELADO")
                    if primero_cancela
                    else (
                        "VIAJE_CON_COMPROMISOS" if rival == "reserva" else "ESTADO_VIAJE_INVALIDO"
                    )
                )
                assert resultados[1].codigo == esperado
        finally:
            await motor.dispose()

    asyncio.run(carrera())
    estado = "cancelado" if primero_cancela else "programado" if rival == "reserva" else "en_curso"
    assert _uno(entorno["base"], "SELECT estado FROM viaje WHERE id_viaje=$1", id_viaje) == estado
    assert _uno(entorno["base"], "SELECT count(*) FROM reserva WHERE id_viaje=$1", id_viaje) == (
        int(not primero_cancela and rival == "reserva")
    )
