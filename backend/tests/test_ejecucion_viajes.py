"""CU-030: transiciones, permisos e idempotencia contra PostgreSQL real."""

import asyncio
from pathlib import Path

import pytest
import yaml
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.security import UsuarioActual, crear_token
from app.services.ejecucion_viajes import (
    TIPO_VIAJE_FINALIZADO,
    TIPO_VIAJE_INICIADO,
    finalizar_viaje,
    iniciar_viaje,
)
from tests._bd import base_migrada, cliente_api, consultar, ejecutar_sql, url_sqlalchemy

CONTRATO = Path(__file__).resolve().parents[1] / "openapi" / "openapi.yaml"
RUTA = "/api/viajes"


def _uno(base: str, sql: str, *args):
    return asyncio.run(consultar(base, sql, *args))[0][0]


def _ejecutar(base: str, sql: str, *args):
    asyncio.run(ejecutar_sql(base, sql, *args))


def _token(id_persona: int, roles: list[str]) -> dict[str, str]:
    return {"Authorization": f"Bearer {crear_token(1, id_persona, roles)}"}


@pytest.fixture(scope="module")
def entorno():
    with base_migrada() as base:
        id_servicio = _uno(
            base,
            "INSERT INTO servicio (tipo_servicio) VALUES ('UNIVERSITARIO') "
            "RETURNING id_servicio",
        )
        id_recorrido = _uno(base, "INSERT INTO recorrido DEFAULT VALUES RETURNING id_recorrido")
        id_vehiculo = _uno(
            base,
            "INSERT INTO vehiculo (patente, capacidad) VALUES ('VF030AA', 20) "
            "RETURNING id_vehiculo",
        )
        ids_chofer = []
        for n in (1, 2):
            persona = _uno(
                base,
                "INSERT INTO persona (nombre, apellido, dni) "
                "VALUES ($1, 'Prueba', $2) RETURNING id_persona",
                f"Chofer{n}",
                f"CU030-{n}",
            )
            _ejecutar(base, "INSERT INTO chofer (id_persona) VALUES ($1)", persona)
            ids_chofer.append(persona)
        with cliente_api(base) as http:
            yield {
                "base": base,
                "http": http,
                "id_servicio": id_servicio,
                "id_recorrido": id_recorrido,
                "id_vehiculo": id_vehiculo,
                "choferes": ids_chofer,
            }


@pytest.fixture(autouse=True)
def _limpiar(entorno):
    _ejecutar(entorno["base"], "DELETE FROM evento_operativo; DELETE FROM viaje")


def _crear_viaje(entorno, chofer=None, vehiculo=-1, estado="programado", horario=True):
    if chofer is None:
        chofer = entorno["choferes"][0]
    if vehiculo == -1:
        vehiculo = entorno["id_vehiculo"]
    return _uno(
        entorno["base"],
        "INSERT INTO viaje (id_servicio, id_recorrido, id_vehiculo, id_chofer, "
        "fecha, horario, sentido, estado) "
        "VALUES ($1, $2, $3, $4, DATE '2026-10-30', "
        "CASE WHEN $5::bool THEN TIME '07:30' ELSE NULL END, 'IDA', $6) "
        "RETURNING id_viaje",
        entorno["id_servicio"],
        entorno["id_recorrido"],
        vehiculo,
        chofer,
        horario,
        estado,
    )


def _estado(entorno, id_viaje):
    return _uno(
        entorno["base"],
        "SELECT estado FROM viaje WHERE id_viaje = $1",
        id_viaje,
    )


def _eventos(entorno, id_viaje):
    return asyncio.run(
        consultar(
            entorno["base"],
            "SELECT tipo_evento FROM evento_operativo WHERE id_viaje = $1 "
            "ORDER BY id_evento_operativo",
            id_viaje,
        )
    )


def _post(entorno, id_viaje, operacion="inicio", chofer=None, roles=None):
    return entorno["http"].post(
        f"{RUTA}/{id_viaje}/{operacion}",
        headers=_token(
            entorno["choferes"][0] if chofer is None else chofer,
            ["chofer"] if roles is None else roles,
        ),
    )


def test_inicio_y_finalizacion_guardan_estados_y_eventos(entorno):
    id_viaje = _crear_viaje(entorno)
    inicio = _post(entorno, id_viaje)
    assert inicio.status_code == 200
    assert inicio.json()["estado"] == "en_curso"
    assert _estado(entorno, id_viaje) == "en_curso"
    assert _eventos(entorno, id_viaje) == [(TIPO_VIAJE_INICIADO,)]

    fin = _post(entorno, id_viaje, "finalizacion")
    assert fin.status_code == 200
    assert fin.json()["estado"] == "finalizado"
    assert _estado(entorno, id_viaje) == "finalizado"
    assert _eventos(entorno, id_viaje) == [
        (TIPO_VIAJE_INICIADO,),
        (TIPO_VIAJE_FINALIZADO,),
    ]


def test_reintento_inicio_en_curso_es_idempotente(entorno):
    id_viaje = _crear_viaje(entorno)
    assert _post(entorno, id_viaje).status_code == 200
    segundo = _post(entorno, id_viaje)
    assert segundo.status_code == 200
    assert segundo.json()["estado"] == "en_curso"
    assert _eventos(entorno, id_viaje) == [(TIPO_VIAJE_INICIADO,)]


def test_reintento_inicio_con_viaje_finalizado_no_reinicia(entorno):
    id_viaje = _crear_viaje(entorno)
    assert _post(entorno, id_viaje).status_code == 200
    assert _post(entorno, id_viaje, "finalizacion").status_code == 200
    respuesta = _post(entorno, id_viaje)
    assert respuesta.status_code == 200
    assert respuesta.json()["estado"] == "finalizado"
    assert _eventos(entorno, id_viaje) == [
        (TIPO_VIAJE_INICIADO,),
        (TIPO_VIAJE_FINALIZADO,),
    ]


def test_reintento_finalizacion_no_duplica_evento(entorno):
    id_viaje = _crear_viaje(entorno, estado="en_curso")
    assert _post(entorno, id_viaje, "finalizacion").status_code == 200
    segundo = _post(entorno, id_viaje, "finalizacion")
    assert segundo.status_code == 200
    assert segundo.json()["estado"] == "finalizado"
    assert _eventos(entorno, id_viaje) == [(TIPO_VIAJE_FINALIZADO,)]


@pytest.mark.parametrize("estado", ["programado", "cancelado"])
def test_no_se_finaliza_si_no_esta_en_curso(entorno, estado):
    id_viaje = _crear_viaje(entorno, estado=estado)
    respuesta = _post(entorno, id_viaje, "finalizacion")
    assert respuesta.status_code == 409
    assert respuesta.json()["error"]["codigo"] == "ESTADO_VIAJE_INVALIDO"
    assert _estado(entorno, id_viaje) == estado
    assert _eventos(entorno, id_viaje) == []


def test_no_se_inicia_un_viaje_cancelado(entorno):
    id_viaje = _crear_viaje(entorno, estado="cancelado")
    respuesta = _post(entorno, id_viaje)
    assert respuesta.status_code == 409
    assert respuesta.json()["error"]["codigo"] == "VIAJE_CANCELADO"
    assert _estado(entorno, id_viaje) == "cancelado"
    assert _eventos(entorno, id_viaje) == []


def test_no_se_inicia_sin_vehiculo_asignado(entorno):
    id_viaje = _crear_viaje(entorno, vehiculo=None)
    respuesta = _post(entorno, id_viaje)
    assert respuesta.status_code == 409
    assert respuesta.json()["error"]["codigo"] == "VEHICULO_NO_ASIGNADO"
    assert _estado(entorno, id_viaje) == "programado"
    assert _eventos(entorno, id_viaje) == []


def test_viaje_sin_chofer_asignado_no_es_visible_como_propio(entorno):
    id_viaje = _crear_viaje(entorno)
    _ejecutar(entorno["base"], "UPDATE viaje SET id_chofer = NULL WHERE id_viaje = $1", id_viaje)
    respuesta = _post(entorno, id_viaje)
    assert respuesta.status_code == 404
    assert _estado(entorno, id_viaje) == "programado"
    assert _eventos(entorno, id_viaje) == []


@pytest.mark.parametrize("operacion", ["inicio", "finalizacion"])
def test_permisos_y_no_revelar_viajes_ajenos(entorno, operacion):
    id_viaje = _crear_viaje(entorno, estado="en_curso")
    otro = entorno["choferes"][1]
    http = entorno["http"]
    ruta = f"{RUTA}/{id_viaje}/{operacion}"
    assert http.post(ruta).status_code == 401
    assert _post(entorno, id_viaje, operacion, roles=["pasajero"]).status_code == 403
    ajeno = _post(entorno, id_viaje, operacion, chofer=otro)
    inexistente = _post(entorno, 999999, operacion)
    assert ajeno.status_code == inexistente.status_code == 404
    assert ajeno.json()["error"]["codigo"] == inexistente.json()["error"]["codigo"]
    assert _estado(entorno, id_viaje) == "en_curso"
    assert _eventos(entorno, id_viaje) == []


@pytest.mark.parametrize("operacion", ["inicio", "finalizacion"])
def test_parametro_id_invalido_no_modifica_datos(entorno, operacion):
    resultado = entorno["http"].post(
        f"{RUTA}/sin-numero/{operacion}",
        headers=_token(entorno["choferes"][0], ["chofer"]),
    )
    assert resultado.status_code == 400
    assert resultado.json()["error"]["codigo"] == "VALIDACION"


def test_horario_nulo_se_omite_y_no_se_agregan_campos_al_contrato(entorno):
    id_viaje = _crear_viaje(entorno, horario=False)
    respuesta = _post(entorno, id_viaje)
    assert respuesta.status_code == 200
    cuerpo = respuesta.json()
    assert "horario" not in cuerpo
    contrato = yaml.safe_load(CONTRATO.read_text(encoding="utf-8"))
    propiedades = set(contrato["components"]["schemas"]["Viaje"]["properties"])
    assert set(cuerpo) <= propiedades


@pytest.mark.parametrize("operacion", ["inicio", "finalizacion"])
def test_dos_solicitudes_concurrentes_generan_un_evento(entorno, operacion):
    id_viaje = _crear_viaje(
        entorno, estado="en_curso" if operacion == "finalizacion" else "programado"
    )
    chofer = entorno["choferes"][0]

    async def ejecutar_dos():
        motor = create_async_engine(url_sqlalchemy(entorno["base"]), poolclass=NullPool)
        try:
            fabrica = async_sessionmaker(motor, expire_on_commit=False)

            async def ejecutar_una():
                async with fabrica() as db:
                    usuario = UsuarioActual(
                        id_cuenta_acceso=1, id_persona=chofer, roles=("chofer",)
                    )
                    if operacion == "inicio":
                        return await iniciar_viaje(db, usuario, id_viaje)
                    return await finalizar_viaje(db, usuario, id_viaje)

            return await asyncio.gather(ejecutar_una(), ejecutar_una())
        finally:
            await motor.dispose()

    respuestas = asyncio.run(ejecutar_dos())
    esperado = "en_curso" if operacion == "inicio" else "finalizado"
    tipo = TIPO_VIAJE_INICIADO if operacion == "inicio" else TIPO_VIAJE_FINALIZADO
    assert all(r.estado == esperado for r in respuestas)
    assert _eventos(entorno, id_viaje) == [(tipo,)]
