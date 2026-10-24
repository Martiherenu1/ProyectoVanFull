"""CU-008: API, cupo derivado, atomicidad y locks contra PostgreSQL temporal."""

import asyncio
import json
from concurrent.futures import ThreadPoolExecutor
from itertools import count
from pathlib import Path

import asyncpg
import pytest
import yaml
from jsonschema import validate
from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.errors import ApiError
from app.core.security import UsuarioActual, crear_token
from app.models.viajes import Reserva, Viaje
from app.schemas.ausencias import AusenciaCreate
from app.services import ausencias as servicio
from app.services.disponibilidad import cupo_del_viaje
from tests._bd import base_migrada, cliente_api, conectar, consultar, ejecutar_sql, url_sqlalchemy

RUTA = "/api/ausencias"
_dni = count(80000)


def _uno(e, sql, *args):
    return asyncio.run(consultar(e["base"], sql, *args))[0][0]


def _sql(e, sql, *args):
    asyncio.run(ejecutar_sql(e["base"], sql, *args))


def _persona(e):
    persona = _uno(
        e,
        "INSERT INTO persona (nombre, apellido, dni) VALUES ('A', 'B', $1) RETURNING id_persona",
        str(next(_dni)),
    )
    _sql(e, "INSERT INTO pasajero (id_persona) VALUES ($1)", persona)
    return persona


def _token(persona, roles=("pasajero",)):
    return {"Authorization": f"Bearer {crear_token(persona, persona, list(roles))}"}


@pytest.fixture(scope="module")
def entorno():
    with base_migrada() as base:
        e = {"base": base}
        e["servicio"] = _uno(
            e, "INSERT INTO servicio (tipo_servicio) VALUES ('UNIVERSITARIO') RETURNING id_servicio"
        )
        e["recorrido"] = _uno(e, "INSERT INTO recorrido DEFAULT VALUES RETURNING id_recorrido")
        parada = _uno(e, "INSERT INTO parada (nombre_descripcion) VALUES ('P') RETURNING id_parada")
        _sql(e, "INSERT INTO parada_recorrido VALUES ($1, 1, $2)", e["recorrido"], parada)
        e["vehiculo"] = _uno(
            e, "INSERT INTO vehiculo (patente, capacidad) VALUES ('CU008', 1) RETURNING id_vehiculo"
        )
        e["chofer"] = _persona(e)
        _sql(e, "INSERT INTO chofer (id_persona) VALUES ($1)", e["chofer"])
        with cliente_api(base) as http:
            e["http"] = http
            yield e


def _caso(e, estado="consolidada", viaje_estado="programado"):
    persona = _persona(e)
    viaje = _uno(
        e,
        "INSERT INTO viaje (id_servicio, id_recorrido, id_vehiculo, id_chofer, fecha, sentido, estado) "
        "VALUES ($1, $2, $3, $4, DATE '2026-11-20', 'IDA', $5) RETURNING id_viaje",
        e["servicio"],
        e["recorrido"],
        e["vehiculo"],
        e["chofer"],
        viaje_estado,
    )
    cliente = _uno(
        e, "INSERT INTO cliente (naturaleza_cliente) VALUES ('INDIVIDUAL') RETURNING id_cliente"
    )
    contrato = _uno(
        e,
        "INSERT INTO contratacion (id_cliente, id_servicio) VALUES ($1, $2) RETURNING id_contratacion",
        cliente,
        e["servicio"],
    )
    reserva = _uno(
        e,
        "INSERT INTO reserva (id_pasajero, id_viaje, id_recorrido, orden_parada, "
        "id_contratacion_directa, estado) VALUES ($1, $2, $3, 1, $4, $5) RETURNING id_reserva",
        persona,
        viaje,
        e["recorrido"],
        contrato,
        estado,
    )
    return persona, viaje, reserva


def _post(e, persona, viaje, **extras):
    return e["http"].post(RUTA, json={"id_viaje": viaje, **extras}, headers=_token(persona))


def _eventos(e, reserva):
    return _uno(
        e,
        "SELECT count(*) FROM evento_operativo WHERE id_reserva = $1 "
        "AND tipo_evento = 'ausencia_informada'",
        reserva,
    )


def _cantidad(e, persona, viaje):
    return _uno(
        e, "SELECT count(*) FROM ausencia WHERE id_pasajero = $1 AND id_viaje = $2", persona, viaje
    )


def _cupo(e, viaje):
    async def correr():
        motor = create_async_engine(url_sqlalchemy(e["base"]), poolclass=NullPool)
        try:
            async with async_sessionmaker(motor)() as db:
                return await cupo_del_viaje(db, viaje)
        finally:
            await motor.dispose()

    return asyncio.run(correr())


@pytest.mark.parametrize("estado", ["programado", "en_curso"])
def test_creacion_reintento_reserva_conservada_y_cupo_derivado(entorno, estado):
    e = entorno
    persona, viaje, reserva = _caso(e, viaje_estado=estado)
    anterior = asyncio.run(
        consultar(e["base"], "SELECT * FROM reserva WHERE id_reserva = $1", reserva)
    )
    economicos = [
        _uno(e, f"SELECT count(*) FROM {tabla}") for tabla in ("pago", "movimiento_cuenta")
    ]
    assert _cupo(e, viaje) == 0  # La falta de abordaje sola no libera el lugar.
    primera, segunda = _post(e, persona, viaje), _post(e, persona, viaje)
    assert (primera.status_code, segunda.status_code) == (201, 200)
    assert primera.json() == segunda.json()
    assert primera.json() == {
        "id_ausencia": primera.json()["id_ausencia"],
        "id_pasajero": persona,
        "id_viaje": viaje,
    }
    assert _cantidad(e, persona, viaje) == _eventos(e, reserva) == 1
    assert _cupo(e, viaje) == 1
    assert (
        asyncio.run(consultar(e["base"], "SELECT * FROM reserva WHERE id_reserva = $1", reserva))
        == anterior
    )
    assert [
        _uno(e, f"SELECT count(*) FROM {tabla}") for tabla in ("pago", "movimiento_cuenta")
    ] == economicos


@pytest.mark.parametrize("cambio", ["reserva", "finalizado", "cancelado"])
def test_aviso_existente_prevalece_despues_de_cambios(entorno, cambio):
    e = entorno
    persona, viaje, reserva = _caso(e)
    primera = _post(e, persona, viaje)
    assert primera.status_code == 201
    if cambio == "reserva":
        cancelacion = e["http"].post(
            f"/api/reservas/{reserva}/cancelacion", headers=_token(persona)
        )
        assert cancelacion.status_code == 200
        assert cancelacion.json()["cupo_liberado"] is False
    else:
        _sql(e, "UPDATE viaje SET estado = $1 WHERE id_viaje = $2", cambio, viaje)
    repetida = _post(e, persona, viaje)
    assert repetida.status_code == 200
    assert repetida.json() == primera.json()
    assert _eventos(e, reserva) == _cantidad(e, persona, viaje) == 1
    assert _cupo(e, viaje) == 1


@pytest.mark.parametrize("estado", ["provisional", "cancelada"])
def test_rechaza_reserva_no_consolidada(entorno, estado):
    persona, viaje, reserva = _caso(entorno, estado=estado)
    respuesta = _post(entorno, persona, viaje)
    assert respuesta.status_code == 409
    assert respuesta.json()["error"]["codigo"] == "RESERVA_NO_CONSOLIDADA"
    assert _cantidad(entorno, persona, viaje) == _eventos(entorno, reserva) == 0


@pytest.mark.parametrize("estado", ["finalizado", "cancelado"])
def test_rechaza_viaje_cerrado_sin_aviso(entorno, estado):
    persona, viaje, reserva = _caso(entorno, viaje_estado=estado)
    respuesta = _post(entorno, persona, viaje)
    assert respuesta.status_code == 409
    assert respuesta.json()["error"]["codigo"] == "VIAJE_NO_ADMITE_AUSENCIA"
    assert _cantidad(entorno, persona, viaje) == _eventos(entorno, reserva) == 0


def test_rechaza_pasajero_abordado(entorno):
    e = entorno
    persona, viaje, reserva = _caso(e, viaje_estado="en_curso")
    _sql(
        e,
        "INSERT INTO abordaje (id_pasajero, id_viaje, id_vehiculo, id_recorrido, orden_parada) "
        "VALUES ($1, $2, $3, $4, 1)",
        persona,
        viaje,
        e["vehiculo"],
        e["recorrido"],
    )
    respuesta = _post(e, persona, viaje)
    assert respuesta.status_code == 409
    assert respuesta.json()["error"]["codigo"] == "PASAJERO_YA_ABORDADO"
    assert _cantidad(e, persona, viaje) == _eventos(e, reserva) == 0


def test_privacidad_y_pertenencia_antes_del_aviso_existente(entorno):
    e = entorno
    persona, viaje, _ = _caso(e)
    assert _post(e, persona, viaje).status_code == 201
    otro = _persona(e)
    ajena, inexistente = _post(e, otro, viaje), _post(e, otro, 999999)
    assert ajena.status_code == inexistente.status_code == 404
    assert (
        ajena.json()
        == inexistente.json()
        == {"error": {"codigo": "RESERVA_NO_ENCONTRADA", "mensaje": "La reserva no existe."}}
    )
    assert _post(e, otro, viaje, id_pasajero=persona).status_code == 404
    assert _post(e, 999999, viaje).status_code == 404


@pytest.mark.parametrize("roles", [("chofer",), ("administrador",), ()])
def test_rol_incorrecto_es_403_incluso_al_reintentar(entorno, roles):
    persona, viaje, _ = _caso(entorno)
    assert _post(entorno, persona, viaje).status_code == 201
    respuesta = entorno["http"].post(RUTA, json={"id_viaje": viaje}, headers=_token(persona, roles))
    assert respuesta.status_code == 403
    assert respuesta.json()["error"]["codigo"] == "SIN_PERMISO"


@pytest.mark.parametrize("headers", [{}, {"Authorization": "Bearer invalido"}])
def test_sin_autenticacion_es_401(entorno, headers):
    respuesta = entorno["http"].post(RUTA, json={"id_viaje": 1}, headers=headers)
    assert respuesta.status_code == 401
    assert respuesta.json()["error"]["codigo"] == "NO_AUTENTICADO"


@pytest.mark.parametrize(
    "datos", [{}, {"id_viaje": "secreto"}, {"id_viaje": None}, {"id_viaje": []}]
)
def test_validacion_uniforme_sin_repetir_valores(entorno, datos):
    respuesta = entorno["http"].post(RUTA, json=datos, headers=_token(_persona(entorno)))
    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "VALIDACION"
    assert "secreto" not in respuesta.text


def test_identidad_del_cuerpo_no_suplanta_la_sesion(entorno):
    persona, viaje, _ = _caso(entorno)
    respuesta = _post(entorno, persona, viaje, id_pasajero=_persona(entorno))
    assert respuesta.status_code == 201
    assert respuesta.json()["id_pasajero"] == persona


def test_dos_solicitudes_concurrentes_201_y_200(entorno):
    persona, viaje, reserva = _caso(entorno)
    with ThreadPoolExecutor(max_workers=2) as pool:
        pedidos = [pool.submit(_post, entorno, persona, viaje) for _ in range(2)]
        respuestas = [p.result(timeout=20) for p in pedidos]
    assert sorted(r.status_code for r in respuestas) == [200, 201]
    assert respuestas[0].json() == respuestas[1].json()
    assert _cantidad(entorno, persona, viaje) == _eventos(entorno, reserva) == 1


def test_rollback_tras_insertar_aviso_y_evento(entorno, monkeypatch):
    e = entorno
    persona, viaje, reserva = _caso(e)
    original = servicio.registrar_evento

    async def fallar(db, **datos):
        await original(db, **datos)
        raise RuntimeError("fallo tras flush")

    with monkeypatch.context() as m:
        m.setattr(servicio, "registrar_evento", fallar)
        with pytest.raises(RuntimeError, match="fallo tras flush"):
            _post(e, persona, viaje)
    assert _cantidad(e, persona, viaje) == _eventos(e, reserva) == 0
    assert _cupo(e, viaje) == 0
    assert _uno(e, "SELECT estado FROM reserva WHERE id_reserva = $1", reserva) == "consolidada"
    assert _post(e, persona, viaje).status_code == 201


@pytest.mark.parametrize(
    "tabla,campo,cambio,codigo",
    [
        ("pasajero", "id_persona", None, None),
        ("viaje", "id_viaje", "finalizado", "VIAJE_NO_ADMITE_AUSENCIA"),
        ("viaje", "id_viaje", "cancelado", "VIAJE_NO_ADMITE_AUSENCIA"),
        ("reserva", "id_reserva", "cancelada", "RESERVA_NO_CONSOLIDADA"),
    ],
)
def test_espera_locks_y_relee_los_cambios(entorno, tabla, campo, cambio, codigo):
    e = entorno
    persona, viaje, reserva = _caso(e)
    identificador = {"pasajero": persona, "viaje": viaje, "reserva": reserva}[tabla]

    async def correr():
        conn = await conectar(e["base"])
        try:
            async with conn.transaction():
                await conn.execute(
                    f"SELECT 1 FROM {tabla} WHERE {campo} = $1 FOR UPDATE", identificador
                )
                pedido = asyncio.get_running_loop().run_in_executor(None, _post, e, persona, viaje)
                terminadas, _ = await asyncio.wait({pedido}, timeout=0.5)
                if cambio:
                    await conn.execute(
                        f"UPDATE {tabla} SET estado = $1 WHERE {campo} = $2", cambio, identificador
                    )
            return not terminadas, await asyncio.wait_for(pedido, timeout=10)
        finally:
            await conn.close()

    espero, respuesta = asyncio.run(correr())
    assert espero
    assert respuesta.status_code == (409 if cambio else 201)
    if cambio:
        assert respuesta.json()["error"]["codigo"] == codigo
        assert _cantidad(e, persona, viaje) == 0


@pytest.mark.parametrize("operacion", ["cancelacion", "inicio", "finalizacion"])
def test_carrera_con_cancelacion_y_ejecucion(entorno, operacion):
    e = entorno
    persona, viaje, reserva = _caso(
        e, viaje_estado="en_curso" if operacion == "finalizacion" else "programado"
    )
    ruta = (
        f"/api/reservas/{reserva}/cancelacion"
        if operacion == "cancelacion"
        else f"/api/viajes/{viaje}/{operacion}"
    )
    headers = _token(persona) if operacion == "cancelacion" else _token(e["chofer"], ("chofer",))
    with ThreadPoolExecutor(max_workers=2) as pool:
        aviso = pool.submit(_post, e, persona, viaje)
        otro = pool.submit(e["http"].post, ruta, headers=headers)
        respuesta, cambio = aviso.result(timeout=20), otro.result(timeout=20)
    assert cambio.status_code == 200, cambio.text
    assert respuesta.status_code in ([201] if operacion == "inicio" else [201, 409])
    assert _cantidad(e, persona, viaje) == _eventos(e, reserva) == (respuesta.status_code == 201)
    if respuesta.status_code == 201:
        assert _post(e, persona, viaje).json() == respuesta.json()


def test_cupo_liberado_lo_reserva_otro_sin_recuperacion_automatica(entorno):
    e = entorno
    persona, viaje, _ = _caso(e)
    otro = _persona(e)

    def reservar():
        return e["http"].post(
            "/api/reservas", json={"id_viaje": viaje, "orden_parada": 1}, headers=_token(otro)
        )

    assert reservar().status_code == 409
    assert _post(e, persona, viaje).status_code == 201
    assert reservar().status_code == 201
    assert _cupo(e, viaje) == 0
    assert _post(e, persona, viaje).status_code == 200
    assert _cupo(e, viaje) == 0
    assert _cantidad(e, persona, viaje) == 1


@pytest.mark.parametrize(
    "tabla,identificador,cambio,codigo",
    [
        ("reserva", "id_reserva", "cancelada", "RESERVA_NO_CONSOLIDADA"),
        ("viaje", "id_viaje", "finalizado", "VIAJE_NO_ADMITE_AUSENCIA"),
    ],
)
def test_sesion_precargada_se_refresca_bajo_locks(entorno, tabla, identificador, cambio, codigo):
    e = entorno
    persona, viaje, reserva = _caso(e)

    async def correr():
        motor = create_async_engine(url_sqlalchemy(e["base"]), poolclass=NullPool)
        try:
            async with async_sessionmaker(motor, expire_on_commit=False)() as db:
                previa = await db.scalar(select(Reserva).where(Reserva.id_reserva == reserva))
                previo = await db.scalar(select(Viaje).where(Viaje.id_viaje == viaje))
                await ejecutar_sql(
                    e["base"],
                    f"UPDATE {tabla} SET estado = $1 WHERE {identificador} = $2",
                    cambio,
                    reserva if tabla == "reserva" else viaje,
                )
                assert previa.estado == "consolidada" and previo.estado == "programado"

                with pytest.raises(ApiError) as error:
                    await servicio.informar_ausencia(
                        db,
                        UsuarioActual(
                            id_cuenta_acceso=persona, id_persona=persona, roles=("pasajero",)
                        ),
                        AusenciaCreate(id_viaje=viaje),
                    )
                assert error.value.codigo == codigo
        finally:
            await motor.dispose()

    asyncio.run(correr())


def test_retiene_los_tres_locks_hasta_despues_del_evento(entorno, monkeypatch):
    e = entorno
    persona, viaje, reserva = _caso(e)
    original = servicio.registrar_evento

    async def comprobar(db, **datos):
        await original(db, **datos)
        conn = await conectar(e["base"])
        try:
            for tabla, campo, valor in (
                ("pasajero", "id_persona", persona),
                ("viaje", "id_viaje", viaje),
                ("reserva", "id_reserva", reserva),
            ):
                with pytest.raises(asyncpg.LockNotAvailableError):
                    await conn.fetch(
                        f"SELECT 1 FROM {tabla} WHERE {campo} = $1 FOR UPDATE NOWAIT", valor
                    )
        finally:
            await conn.close()

    monkeypatch.setattr(servicio, "registrar_evento", comprobar)
    assert _post(e, persona, viaje).status_code == 201


def test_dos_reservas_compiten_por_el_unico_lugar_liberado(entorno):
    e = entorno
    persona, viaje, reserva = _caso(e)
    assert _post(e, persona, viaje).status_code == 201
    otros = [_persona(e), _persona(e)]

    def reservar(pasajero):
        return e["http"].post(
            "/api/reservas", json={"id_viaje": viaje, "orden_parada": 1}, headers=_token(pasajero)
        )

    with ThreadPoolExecutor(max_workers=2) as pool:
        respuestas = list(pool.map(reservar, otros))
    assert sorted(r.status_code for r in respuestas) == [201, 409]
    assert _cupo(e, viaje) == 0
    assert _cantidad(e, persona, viaje) == _eventos(e, reserva) == 1


def test_respuestas_y_schemas_coinciden_con_contrato(entorno):
    carpeta = Path(__file__).resolve().parents[1] / "openapi"
    contrato = yaml.safe_load((carpeta / "openapi.yaml").read_text(encoding="utf-8"))
    assert contrato == json.loads((carpeta / "openapi.json").read_text(encoding="utf-8"))
    respuestas = contrato["paths"]["/ausencias"]["post"]["responses"]
    assert set(respuestas) == {"200", "201", "400", "401", "403", "404", "409"}
    assert respuestas["200"]["content"] == respuestas["201"]["content"]
    persona, viaje, _ = _caso(entorno)
    for esperado in (201, 200):
        respuesta = _post(entorno, persona, viaje)
        assert respuesta.status_code == esperado
        validate(respuesta.json(), contrato["components"]["schemas"]["Ausencia"])
    from app.main import app

    operacion = app.openapi()["paths"][RUTA]["post"]
    assert {"200", "201"} <= operacion["responses"].keys()
