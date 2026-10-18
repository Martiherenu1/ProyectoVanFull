"""Creación de viajes por administración (CU-018) contra PostgreSQL real."""

import asyncio
from datetime import date, time
from pathlib import Path

import pytest
import yaml
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.security import crear_token
from app.schemas.viajes import ViajeCreate
from app.services.viajes import TIPO_VIAJE_CREADO, crear_viaje
from tests._bd import base_migrada, cliente_api, consultar, ejecutar_sql, url_sqlalchemy

RUTA = "/api/viajes"
CONTRATO = Path(__file__).resolve().parents[1] / "openapi" / "openapi.yaml"


def _uno(base: str, sql: str, *args):
    return asyncio.run(consultar(base, sql, *args))[0][0]


def _con(roles: list[str]) -> dict[str, str]:
    return {"Authorization": f"Bearer {crear_token(1, 1, roles)}"}


def _en_sesion(base: str, funcion):
    async def _correr():
        motor = create_async_engine(url_sqlalchemy(base), poolclass=NullPool)
        try:
            async with async_sessionmaker(motor, expire_on_commit=False)() as db:
                return await funcion(db)
        finally:
            await motor.dispose()

    return asyncio.run(_correr())


@pytest.fixture(scope="module")
def entorno():
    with base_migrada() as base:
        id_servicio = _uno(
            base,
            "INSERT INTO servicio (tipo_servicio) VALUES ('UNIVERSITARIO') RETURNING id_servicio",
        )
        id_recorrido = _uno(base, "INSERT INTO recorrido DEFAULT VALUES RETURNING id_recorrido")
        id_vehiculo = _uno(
            base,
            "INSERT INTO vehiculo (patente, capacidad) VALUES ('VF018AA', 20) "
            "RETURNING id_vehiculo",
        )
        id_chofer = _uno(
            base,
            "INSERT INTO persona (nombre, apellido, dni) "
            "VALUES ('Chofer', 'Prueba', 'CU018') RETURNING id_persona",
        )
        asyncio.run(
            ejecutar_sql(
                base,
                "INSERT INTO chofer (id_persona, registro_conducir) VALUES ($1, 'REG-CU018')",
                id_chofer,
            )
        )
        with cliente_api(base) as http:
            yield {
                "base": base,
                "http": http,
                "id_servicio": id_servicio,
                "id_recorrido": id_recorrido,
                "id_vehiculo": id_vehiculo,
                "id_chofer": id_chofer,
            }


@pytest.fixture(autouse=True)
def _sin_viajes(entorno):
    asyncio.run(ejecutar_sql(entorno["base"], "DELETE FROM evento_operativo; DELETE FROM viaje"))


def _datos_validos(entorno) -> dict:
    return {
        "id_servicio": entorno["id_servicio"],
        "id_recorrido": entorno["id_recorrido"],
        "fecha": "2026-10-30",
        "sentido": "IDA",
    }


def test_el_servicio_crea_el_viaje_programado_y_su_evento(entorno):
    async def operacion(db):
        return await crear_viaje(
            db,
            ViajeCreate(
                id_servicio=entorno["id_servicio"],
                id_recorrido=entorno["id_recorrido"],
                fecha=date(2026, 10, 30),
                horario=time(7, 30),
                sentido="IDA",
                capacidad_planificada=18,
            ),
        )

    creado = _en_sesion(entorno["base"], operacion)
    fila = asyncio.run(
        consultar(
            entorno["base"],
            "SELECT estado, capacidad_planificada FROM viaje WHERE id_viaje = $1",
            creado.id_viaje,
        )
    )[0]
    evento = asyncio.run(
        consultar(
            entorno["base"],
            "SELECT tipo_evento, id_viaje FROM evento_operativo WHERE id_viaje = $1",
            creado.id_viaje,
        )
    )
    assert fila == ("programado", 18)
    assert evento == [(TIPO_VIAJE_CREADO, creado.id_viaje)]


def test_administrador_crea_un_viaje_con_vehiculo_y_chofer(entorno):
    datos = {
        **_datos_validos(entorno),
        "id_vehiculo": entorno["id_vehiculo"],
        "id_chofer": entorno["id_chofer"],
        "horario": "07:30",
        "capacidad_planificada": 18,
    }
    respuesta = entorno["http"].post(RUTA, json=datos, headers=_con(["administrador"]))

    assert respuesta.status_code == 201
    cuerpo = respuesta.json()
    assert cuerpo == {
        "id_viaje": cuerpo["id_viaje"],
        "id_servicio": entorno["id_servicio"],
        "id_recorrido": entorno["id_recorrido"],
        "id_vehiculo": entorno["id_vehiculo"],
        "id_chofer": entorno["id_chofer"],
        "fecha": "2026-10-30",
        "horario": "07:30",
        "sentido": "IDA",
        "estado": "programado",
    }


def test_dueno_puede_crearlo_con_asignaciones_pendientes(entorno):
    respuesta = entorno["http"].post(RUTA, json=_datos_validos(entorno), headers=_con(["dueno"]))

    assert respuesta.status_code == 201
    cuerpo = respuesta.json()
    assert cuerpo["estado"] == "programado"
    assert "id_vehiculo" not in cuerpo
    assert "id_chofer" not in cuerpo
    assert "horario" not in cuerpo
    assert asyncio.run(
        consultar(
            entorno["base"],
            "SELECT id_vehiculo, id_chofer, horario FROM viaje WHERE id_viaje = $1",
            cuerpo["id_viaje"],
        )
    ) == [(None, None, None)]


@pytest.mark.parametrize(
    ("headers", "estado"),
    [({}, 401), (_con(["pasajero"]), 403)],
)
def test_solo_administrador_o_dueno_pueden_crear(entorno, headers, estado):
    respuesta = entorno["http"].post(RUTA, json=_datos_validos(entorno), headers=headers)
    assert respuesta.status_code == estado
    assert asyncio.run(consultar(entorno["base"], "SELECT count(*) FROM viaje")) == [(0,)]
    assert asyncio.run(consultar(entorno["base"], "SELECT count(*) FROM evento_operativo")) == [
        (0,)
    ]


def test_una_referencia_inexistente_responde_404_sin_escribir(entorno):
    datos = {**_datos_validos(entorno), "id_servicio": 999_999}
    respuesta = entorno["http"].post(RUTA, json=datos, headers=_con(["administrador"]))

    assert respuesta.status_code == 404
    assert respuesta.json()["error"]["codigo"] == "SERVICIO_NO_ENCONTRADO"
    assert asyncio.run(consultar(entorno["base"], "SELECT count(*) FROM viaje")) == [(0,)]
    assert asyncio.run(consultar(entorno["base"], "SELECT count(*) FROM evento_operativo")) == [
        (0,)
    ]


def test_capacidad_planificada_negativa_es_400(entorno):
    datos = {**_datos_validos(entorno), "capacidad_planificada": -1}
    respuesta = entorno["http"].post(RUTA, json=datos, headers=_con(["administrador"]))
    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "VALIDACION"


def test_la_respuesta_no_agrega_campos_fuera_del_contrato(entorno):
    declarados = set(
        yaml.safe_load(CONTRATO.read_text(encoding="utf-8"))["components"]["schemas"]["Viaje"][
            "properties"
        ]
    )
    respuesta = entorno["http"].post(
        RUTA, json=_datos_validos(entorno), headers=_con(["administrador"])
    )
    assert respuesta.status_code == 201
    assert set(respuesta.json()) <= declarados
