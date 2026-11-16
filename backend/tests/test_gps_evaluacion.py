"""Candidato #273: S/T coherentes, sin cambiar recepcion ni estados del GPS."""

import asyncio
from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.security import UsuarioActual
from app.services import gps
from tests._bd import consultar, ejecutar_sql, url_sqlalchemy
from tests.test_ejecucion_viajes import _crear_viaje, _token
from tests.test_gps import entorno as entorno
from tests.test_gps import limpiar as limpiar
from tests.test_gps import post


def _fecha(texto):
    return datetime.fromisoformat(texto.replace("Z", "+00:00"))


@pytest.mark.parametrize("edad,esperada", [(29, False), (30, False), (31, True)])
@pytest.mark.parametrize("rol", ["administrador", "dueno"])
def test_evaluacion_unica_coherente_y_no_store(entorno, monkeypatch, edad, esperada, rol):
    viaje = _crear_viaje(entorno, estado="en_curso")
    t = datetime(2026, 10, 29, 12, tzinfo=UTC)
    assert (
        post(
            entorno, viaje, {"latitud": 1, "longitud": 2, "fecha_hora_posicion": t.isoformat()}
        ).status_code
        == 200
    )
    llamadas = []
    s = t + timedelta(seconds=edad)

    class Reloj(datetime):
        @classmethod
        def now(cls, tz=None):
            assert tz is UTC
            llamadas.append(tz)
            # Un segundo uso rompe coherencia y se detecta además por el contador.
            return s + timedelta(seconds=100 * (len(llamadas) - 1))

    monkeypatch.setattr(gps, "datetime", Reloj)
    r = entorno["http"].get(f"/api/viajes/{viaje}/ubicacion", headers=_token(1, [rol]))
    assert r.status_code == 200
    assert llamadas == [UTC]
    assert r.headers["Cache-Control"] == "no-store"
    datos = r.json()
    assert _fecha(datos["fecha_hora_evaluacion"]) == s
    assert _fecha(datos["fecha_hora_evaluacion"]).utcoffset() == timedelta(0)
    assert _fecha(datos["fecha_hora_posicion"]) == t
    assert datos["desactualizada"] is esperada
    assert datos["desactualizada"] == (
        _fecha(datos["fecha_hora_evaluacion"]) - _fecha(datos["fecha_hora_posicion"])
        > timedelta(seconds=30)
    )
    assert (datos["latitud"], datos["longitud"], datos["eta_minutos"]) == (1, 2, None)
    guardado = asyncio.run(
        consultar(
            entorno["base"],
            "SELECT latitud, longitud, fecha_hora_posicion FROM posicion_gps WHERE id_viaje=$1",
            viaje,
        )
    )
    assert tuple(guardado[0]) == (1, 2, t)
    # Una segunda consulta obtiene S nuevo, sin rejuvenecer T ni reutilizar el booleano.
    llamadas.clear()
    s = t + timedelta(seconds=31)
    segunda = entorno["http"].get(f"/api/viajes/{viaje}/ubicacion", headers=_token(1, [rol]))
    assert segunda.status_code == 200
    assert llamadas == [UTC]
    assert _fecha(segunda.json()["fecha_hora_evaluacion"]) == s
    assert _fecha(segunda.json()["fecha_hora_posicion"]) == t
    assert segunda.json()["desactualizada"] is True
    assert segunda.headers["Cache-Control"] == "no-store"


@pytest.mark.parametrize(
    "caso,estado,codigo",
    [
        ("anonimo", 401, "NO_AUTENTICADO"),
        ("chofer", 403, "SIN_PERMISO"),
        ("pasajero", 403, "SIN_PERMISO"),
        ("sin_posicion", 404, "UBICACION_NO_DISPONIBLE"),
        ("finalizado", 404, "VIAJE_NO_DISPONIBLE"),
    ],
)
def test_error_no_evalua_ni_revela_posicion(entorno, monkeypatch, caso, estado, codigo):
    viaje = _crear_viaje(entorno, estado="en_curso")
    if caso == "finalizado":
        assert post(entorno, viaje, {"latitud": 1, "longitud": 2}).status_code == 200
        cierre = entorno["http"].post(
            f"/api/viajes/{viaje}/finalizacion", headers=_token(entorno["choferes"][0], ["chofer"])
        )
        assert cierre.status_code == 200

    class RelojProhibido(datetime):
        @classmethod
        def now(cls, tz=None):
            pytest.fail("Un error no debe generar S ni consultar el reloj GPS")

    monkeypatch.setattr(gps, "datetime", RelojProhibido)
    headers = (
        {}
        if caso == "anonimo"
        else _token(1, [caso if caso in ("chofer", "pasajero") else "administrador"])
    )
    r = entorno["http"].get(f"/api/viajes/{viaje}/ubicacion", headers=headers)
    assert r.status_code == estado
    assert r.json()["error"]["codigo"] == codigo
    assert "fecha_hora_evaluacion" not in r.json()
    assert "latitud" not in r.text


def test_snapshot_devuelto_no_mezcla_actualizacion_posterior(entorno, monkeypatch):
    viaje = _crear_viaje(entorno, estado="en_curso")
    t = datetime(2026, 10, 29, 12, tzinfo=UTC)
    s = t + timedelta(seconds=31)
    assert (
        post(
            entorno, viaje, {"latitud": 1, "longitud": 2, "fecha_hora_posicion": t.isoformat()}
        ).status_code
        == 200
    )

    class Reloj(datetime):
        @classmethod
        def now(cls, tz=None):
            assert tz is UTC
            return s

    monkeypatch.setattr(gps, "datetime", Reloj)

    async def escenario():
        motor = create_async_engine(url_sqlalchemy(entorno["base"]), poolclass=NullPool)
        fabrica = async_sessionmaker(motor, expire_on_commit=False)
        try:
            async with fabrica() as db:
                commit = db.commit

                async def actualizar_antes_de_liberar():
                    # SQL real desde otra conexion, despues de construir la respuesta.
                    await ejecutar_sql(
                        entorno["base"],
                        "UPDATE posicion_gps SET latitud=3, longitud=4, "
                        "fecha_hora_posicion=$1 WHERE id_viaje=$2",
                        s,
                        viaje,
                    )
                    await commit()

                monkeypatch.setattr(db, "commit", actualizar_antes_de_liberar)
                resultado = await gps.consultar(db, UsuarioActual(1, 1, ("administrador",)), viaje)
                assert resultado.fecha_hora_evaluacion == s
                assert resultado.fecha_hora_posicion == t
                assert resultado.desactualizada is True
                assert (resultado.latitud, resultado.longitud) == (1, 2)
        finally:
            await motor.dispose()

    asyncio.run(escenario())
    fila = asyncio.run(
        consultar(
            entorno["base"],
            "SELECT latitud, longitud, fecha_hora_posicion FROM posicion_gps WHERE id_viaje=$1",
            viaje,
        )
    )
    assert tuple(fila[0]) == (3, 4, s)
