"""CU-030 manual: HTTP + PostgreSQL desechable, sin servicios externos."""

import asyncio
from concurrent.futures import ThreadPoolExecutor
from uuid import uuid4

import pytest

from app.core.security import crear_token
from tests._bd import ejecutar_sql
from tests.test_ejecucion_viajes import _crear_viaje, _ejecutar, _uno
from tests.test_ejecucion_viajes import entorno as entorno  # noqa: F401


@pytest.fixture(autouse=True)
def limpio(entorno):
    _ejecutar(
        entorno["base"],
        "DELETE FROM evento_operativo; DELETE FROM abordaje; DELETE FROM reserva; DELETE FROM viaje",
    )
    for p in entorno["choferes"]:
        _ejecutar(
            entorno["base"],
            "INSERT INTO cuenta_acceso (id_persona, identificador_acceso, hash_contrasena) VALUES ($1, $2, 'test') ON CONFLICT DO NOTHING",
            p,
            f"aviso-{p}",
        )


def cuenta(e, index=0):
    return _uno(
        e["base"],
        "SELECT id_cuenta_acceso FROM cuenta_acceso WHERE id_persona=$1",
        e["choferes"][index],
    )


def headers(e, index=0, roles=None):
    return {
        "Authorization": "Bearer "
        + crear_token(
            cuenta(e, index), e["choferes"][index], ["chofer"] if roles is None else roles
        )
    }


def payload(clase="demora", clave=None, texto="Tránsito"):
    return {"clase": clase, "clave_solicitud": str(clave or uuid4()), "descripcion_interna": texto}


def post(e, viaje, datos, index=0):
    return e["http"].post(f"/api/viajes/{viaje}/avisos", json=datos, headers=headers(e, index))


def test_registro_reintentos_conflicto_y_hechos_distintos(entorno):
    e = entorno
    v = _crear_viaje(e, estado="en_curso")
    d = payload()
    r = post(e, v, d)
    assert r.status_code == 201, r.text
    assert r.json()["notificacion"] == "no_evaluada"
    assert post(e, v, d).json() == r.json()
    assert post(e, v, d).status_code == 200
    assert post(e, v, {**d, "descripcion_interna": "Otro"}).status_code == 409
    assert post(e, v, payload()).status_code == 201
    assert _uno(e["base"], "SELECT count(*) FROM evento_operativo") == 2


def test_recuperacion_historica_por_cuenta_sin_rol_y_reasignado(entorno):
    e = entorno
    v = _crear_viaje(e, estado="en_curso")
    d = payload("problema")
    r = post(e, v, d)
    _ejecutar(
        e["base"],
        "UPDATE viaje SET estado='finalizado', id_chofer=$1 WHERE id_viaje=$2",
        e["choferes"][1],
        v,
    )
    url = f"/api/viajes/{v}/avisos/resultado"
    assert (
        e["http"]
        .get(url, params={"clave_solicitud": d["clave_solicitud"]}, headers=headers(e, roles=[]))
        .json()
        == r.json()
    )
    assert post(e, v, d).json() == r.json()
    assert post(e, v, payload()).status_code == 404
    assert (
        e["http"]
        .get(url, params={"clave_solicitud": d["clave_solicitud"]}, headers=headers(e, 1))
        .status_code
        == 404
    )


@pytest.mark.parametrize("estado", ["programado", "cancelado", "finalizado"])
def test_alta_solo_en_curso(entorno, estado):
    v = _crear_viaje(entorno, estado=estado)
    assert post(entorno, v, payload()).status_code == 409
    assert _uno(entorno["base"], "SELECT count(*) FROM evento_operativo") == 0


def test_permisos_validacion_y_lectura_interna(entorno):
    e = entorno
    v = _crear_viaje(e, estado="en_curso")
    url = f"/api/viajes/{v}/avisos"
    assert e["http"].post(url, json=payload()).status_code == 401
    assert (
        e["http"].post(url, json=payload(), headers=headers(e, roles=["pasajero"])).status_code
        == 403
    )
    assert post(e, v, payload(), 1).status_code == 404
    assert post(e, v, {**payload(), "descripcion_interna": " "}).status_code == 400
    assert post(e, v, {**payload(), "clave_solicitud": "no"}).status_code == 400
    assert post(e, v, {**payload(), "id_cuenta_autora": 999}).status_code == 400
    post(e, v, payload("problema", texto="Detalle privado"))
    assert e["http"].get(url, headers=headers(e)).status_code == 403
    for rol in ("administrador", "dueno"):
        r = e["http"].get(url, headers=headers(e, roles=[rol]))
        assert r.status_code == 200 and r.json()[0]["descripcion_interna"] == "Detalle privado"


def test_concurrencia_misma_clave_y_contenido(entorno):
    e = entorno
    v = _crear_viaje(e, estado="en_curso")
    d = payload()
    with ThreadPoolExecutor(2) as pool:
        rs = list(pool.map(lambda _: post(e, v, d), range(2)))
    assert sorted(r.status_code for r in rs) == [200, 201]
    assert rs[0].json() == rs[1].json()
    assert _uno(e["base"], "SELECT count(*) FROM evento_operativo") == 1


def test_fallo_despues_flush_revierte_y_reintenta(entorno, monkeypatch):
    from app.services import avisos

    real = avisos.registrar_evento

    async def fallar(*args, **kwargs):
        await real(*args, **kwargs)
        raise RuntimeError("fallo controlado")

    monkeypatch.setattr(avisos, "registrar_evento", fallar)
    e = entorno
    v = _crear_viaje(e, estado="en_curso")
    d = payload()
    with pytest.raises(RuntimeError):
        post(e, v, d)
    assert _uno(e["base"], "SELECT count(*) FROM evento_operativo") == 0
    monkeypatch.setattr(avisos, "registrar_evento", real)
    assert post(e, v, d).status_code == 201


def test_integridad_bd_no_depende_del_helper(entorno):
    from asyncpg import CheckViolationError, UniqueViolationError

    e = entorno
    v = _crear_viaje(e, estado="en_curso")
    d = payload()
    post(e, v, d)
    sql = "INSERT INTO evento_operativo (tipo_evento,id_viaje,id_cuenta_autora,clave_solicitud,detalle_evento) VALUES ('aviso_demora',$1,$2,$3,'x')"
    with pytest.raises(UniqueViolationError):
        asyncio.run(ejecutar_sql(e["base"], sql, v, cuenta(e), d["clave_solicitud"]))
    with pytest.raises(CheckViolationError):
        asyncio.run(
            ejecutar_sql(
                e["base"],
                "INSERT INTO evento_operativo (tipo_evento,id_viaje,id_cuenta_autora) VALUES ('aviso_demora',$1,$2)",
                v,
                cuenta(e),
            )
        )


def test_mensaje_privacidad_reserva_y_fin(entorno):
    e = entorno
    v = _crear_viaje(e, estado="en_curso")
    # Reutiliza un chofer como persona pasajero de prueba, sin datos de producción.
    persona = e["choferes"][1]
    _ejecutar(
        e["base"], "INSERT INTO pasajero (id_persona) VALUES ($1) ON CONFLICT DO NOTHING", persona
    )
    post(e, v, payload())
    url = f"/api/pasajeros/me/viajes/{v}/demora"
    assert e["http"].get(url, headers=headers(e, 1, ["pasajero"])).status_code == 404

    assert e["http"].get(url, headers=headers(e)).status_code == 403


def test_reserva_consolidada_mensaje_fechado_sin_detalle_y_fin(entorno):
    e = entorno
    v = _crear_viaje(e, estado="en_curso")
    p = e["choferes"][1]
    _ejecutar(e["base"], "INSERT INTO pasajero (id_persona) VALUES ($1) ON CONFLICT DO NOTHING", p)
    parada = _uno(e["base"], "INSERT INTO parada DEFAULT VALUES RETURNING id_parada")
    _ejecutar(
        e["base"],
        "INSERT INTO parada_recorrido (id_recorrido,orden,id_parada) VALUES ($1,1,$2) ON CONFLICT DO NOTHING",
        e["id_recorrido"],
        parada,
    )
    cliente = _uno(
        e["base"],
        "INSERT INTO cliente (naturaleza_cliente) VALUES ('INDIVIDUAL') RETURNING id_cliente",
    )
    con = _uno(
        e["base"],
        "INSERT INTO contratacion (id_cliente,id_servicio) VALUES ($1,$2) RETURNING id_contratacion",
        cliente,
        e["id_servicio"],
    )
    r = _uno(
        e["base"],
        "INSERT INTO reserva (id_pasajero,id_viaje,id_recorrido,orden_parada,id_contratacion_directa,estado) VALUES ($1,$2,$3,1,$4,'consolidada') RETURNING id_reserva",
        p,
        v,
        e["id_recorrido"],
        con,
    )
    post(e, v, payload(texto="Privado: conductor"))
    url = f"/api/pasajeros/me/viajes/{v}/demora"
    auth = headers(e, 1, ["pasajero"])
    respuesta = e["http"].get(url, headers=auth)
    assert respuesta.status_code == 200
    assert respuesta.json()["fecha_hora_reporte"] is not None
    assert "actual no" in respuesta.json()["mensaje"]
    assert "Privado" not in respuesta.text and "id_cuenta_autora" not in respuesta.text
    assert respuesta.headers["cache-control"] == "no-store"
    _ejecutar(
        e["base"],
        "INSERT INTO abordaje (id_pasajero,id_viaje,id_vehiculo,id_recorrido,orden_parada) VALUES ($1,$2,$3,$4,1)",
        p,
        v,
        e["id_vehiculo"],
        e["id_recorrido"],
    )
    assert e["http"].get(url, headers=auth).json() == respuesta.json()
    for estado in ("provisional", "cancelada"):
        _ejecutar(e["base"], "UPDATE reserva SET estado=$1 WHERE id_reserva=$2", estado, r)
        assert e["http"].get(url, headers=auth).status_code == 404
    _ejecutar(e["base"], "UPDATE reserva SET estado='consolidada' WHERE id_reserva=$1", r)
    _ejecutar(e["base"], "UPDATE viaje SET estado='finalizado' WHERE id_viaje=$1", v)
    assert e["http"].get(url, headers=auth).json()["mensaje"] is None


def test_carrera_finalizacion_no_deja_alta_fuera_de_curso(entorno):
    e = entorno
    v = _crear_viaje(e, estado="en_curso")
    d = payload()
    with ThreadPoolExecutor(2) as pool:
        a = pool.submit(post, e, v, d)
        f = pool.submit(e["http"].post, f"/api/viajes/{v}/finalizacion", headers=headers(e))
        respuesta = a.result()
        assert f.result().status_code == 200
    assert respuesta.status_code in (201, 409)
    assert _uno(e["base"], "SELECT estado FROM viaje WHERE id_viaje=$1", v) == "finalizado"
    if respuesta.status_code == 201:
        assert post(e, v, d).json() == respuesta.json()


def test_carrera_reasignacion_serializa_el_alta(entorno):
    e = entorno
    v = _crear_viaje(e, estado="en_curso")
    d = payload()
    with ThreadPoolExecutor(2) as pool:
        a = pool.submit(post, e, v, d)
        f = pool.submit(
            _ejecutar,
            e["base"],
            "UPDATE viaje SET id_chofer=$1 WHERE id_viaje=$2",
            e["choferes"][1],
            v,
        )
        respuesta = a.result()
        f.result()
    assert respuesta.status_code in (201, 404)
    assert post(e, v, payload()).status_code == 404
    if respuesta.status_code == 201:
        assert post(e, v, d).json() == respuesta.json()
