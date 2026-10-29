"""GPS contratado: PostgreSQL real, última posición y cierre serializado."""

import asyncio
from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.errors import ApiError
from app.core.security import UsuarioActual
from app.schemas.gps import PosicionGpsCreate
from app.services import ejecucion_viajes, gps
from tests._bd import consultar, ejecutar_sql, url_sqlalchemy
from tests.test_ejecucion_viajes import _crear_viaje, _token
from tests.test_ejecucion_viajes import entorno as entorno


@pytest.fixture(autouse=True)
def limpiar(entorno):
    asyncio.run(
        ejecutar_sql(
            entorno["base"],
            "DELETE FROM posicion_gps; DELETE FROM evento_operativo; DELETE FROM viaje",
        )
    )


def post(e, id, datos, chofer=None):
    return e["http"].post(
        f"/api/viajes/{id}/ubicacion",
        json=datos,
        headers=_token(chofer or e["choferes"][0], ["chofer"]),
    )


def test_ultima_posicion_orden_timestamp_y_sin_historial(entorno):
    id = _crear_viaje(entorno, estado="en_curso")
    antigua = (datetime.now(UTC) - timedelta(minutes=2)).isoformat()
    r = post(entorno, id, {"latitud": 1, "longitud": 2, "fecha_hora_posicion": antigua})
    assert r.status_code == 200 and r.json()["actualizada"]
    r = post(entorno, id, {"latitud": 3, "longitud": 4, "fecha_hora_posicion": antigua})
    assert r.status_code == 200 and not r.json()["actualizada"]
    guardado = asyncio.run(
        consultar(
            entorno["base"], "SELECT latitud, longitud FROM posicion_gps WHERE id_viaje=$1", id
        )
    )
    assert tuple(map(float, guardado[0])) == (1, 2)
    futura = (datetime.now(UTC) + timedelta(days=2)).isoformat()
    antes = datetime.now(UTC)
    r = post(entorno, id, {"latitud": 5, "longitud": 6, "fecha_hora_posicion": futura})
    fecha = datetime.fromisoformat(r.json()["fecha_hora_posicion"].replace("Z", "+00:00"))
    assert antes <= fecha <= datetime.now(UTC)
    assert post(entorno, id, {"latitud": 7, "longitud": 8}).json()["actualizada"]
    assert asyncio.run(consultar(entorno["base"], "SELECT count(*) FROM posicion_gps"))[0][0] == 1


def test_permisos_propiedad_estado_y_validacion(entorno):
    id = _crear_viaje(entorno)
    assert post(entorno, id, {"latitud": 0, "longitud": 0}).status_code == 409
    assert (
        post(entorno, id, {"latitud": 0, "longitud": 0}, entorno["choferes"][1]).status_code == 404
    )
    assert (
        entorno["http"]
        .post(
            f"/api/viajes/{id}/ubicacion",
            json={"latitud": 0, "longitud": 0},
            headers=_token(1, ["pasajero"]),
        )
        .status_code
        == 403
    )
    for datos in [
        {"latitud": 91, "longitud": 0},
        {"latitud": 0, "longitud": 0, "fecha_hora_posicion": "2026-01-01T00:00:00"},
    ]:
        assert post(entorno, id, datos).status_code == 400
    assert entorno["http"].get(f"/api/viajes/{id}/ubicacion").status_code == 401


def test_consulta_admin_vigencia_y_cierre_sin_acceso_inferido(entorno):
    id = _crear_viaje(entorno, estado="en_curso")
    url = f"/api/viajes/{id}/ubicacion"
    for rol in ["administrador", "dueno"]:
        assert entorno["http"].get(url, headers=_token(1, [rol])).status_code == 404
    antigua = (datetime.now(UTC) - timedelta(minutes=1)).isoformat()
    post(entorno, id, {"latitud": 1, "longitud": 2, "fecha_hora_posicion": antigua})
    for rol in ["administrador", "dueno"]:
        r = entorno["http"].get(url, headers=_token(1, [rol]))
        assert r.status_code == 200 and r.json()["desactualizada"]
        assert r.json()["eta_minutos"] is None
    # Pasajero sin reserva propia consolidada no habilitado.
    for rol in ["pasajero", "chofer"]:
        assert (
            entorno["http"].get(url, headers=_token(entorno["choferes"][0], [rol])).status_code
            == 403
        )
    entorno["http"].post(
        f"/api/viajes/{id}/finalizacion", headers=_token(entorno["choferes"][0], ["chofer"])
    )
    assert entorno["http"].get(url, headers=_token(1, ["administrador"])).status_code == 404
    assert post(entorno, id, {"latitud": 3, "longitud": 4}).status_code == 409


def test_finalizacion_bloquea_posicion_concurrente(entorno, monkeypatch):
    id = _crear_viaje(entorno, estado="en_curso")

    async def escenario():
        engine = create_async_engine(url_sqlalchemy(entorno["base"]), poolclass=NullPool)
        fabrica = async_sessionmaker(engine, expire_on_commit=False)
        finalizando = asyncio.Event()
        continuar = asyncio.Event()
        gps_intentando = asyncio.Event()
        original_evento = ejecucion_viajes.registrar_evento
        original_lock = gps._bloquear_viaje_propio

        async def evento(*args, **kwargs):
            await original_evento(*args, **kwargs)
            finalizando.set()
            await continuar.wait()

        async def lock(*args):
            gps_intentando.set()
            return await original_lock(*args)

        monkeypatch.setattr(ejecucion_viajes, "registrar_evento", evento)
        monkeypatch.setattr(gps, "_bloquear_viaje_propio", lock)
        usuario = UsuarioActual(1, entorno["choferes"][0], ("chofer",))
        try:
            async with fabrica() as a, fabrica() as b:
                cierre = asyncio.create_task(ejecucion_viajes.finalizar_viaje(a, usuario, id))
                await asyncio.wait_for(finalizando.wait(), 5)
                posicion = asyncio.create_task(
                    gps.enviar(b, usuario, id, PosicionGpsCreate(latitud=1, longitud=2))
                )
                await asyncio.wait_for(gps_intentando.wait(), 5)
                continuar.set()
                await asyncio.wait_for(cierre, 5)
                with pytest.raises(ApiError) as error:
                    await asyncio.wait_for(posicion, 5)
                assert error.value.status_code == 409
        finally:
            continuar.set()
            await engine.dispose()

    asyncio.run(escenario())
    assert asyncio.run(consultar(entorno["base"], "SELECT count(*) FROM posicion_gps"))[0][0] == 0
