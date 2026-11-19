"""Primera entrega de administración de vehículos (CU-022) contra PostgreSQL real."""

import asyncio
from pathlib import Path

import pytest
import yaml

from app.core.security import crear_token
from tests._bd import base_migrada, cliente_api, consultar, ejecutar_sql

RUTA = "/api/vehiculos"
CONTRATO = Path(__file__).resolve().parents[1] / "openapi" / "openapi.yaml"


def _con(*roles: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {crear_token(1, 1, list(roles))}"}


@pytest.fixture(scope="module")
def entorno():
    with base_migrada() as base, cliente_api(base) as http:
        yield {"base": base, "http": http}


@pytest.fixture(autouse=True)
def _sin_datos(entorno):
    asyncio.run(
        ejecutar_sql(
            entorno["base"],
            "DELETE FROM viaje; DELETE FROM vehiculo; DELETE FROM recorrido; DELETE FROM servicio",
        )
    )


def _crear(entorno, patente="VF022AA", **cambios):
    datos = {
        "patente": patente,
        "marca": "Mercedes-Benz",
        "modelo": "Sprinter",
        "capacidad": 19,
        "disponibilidad": True,
        **cambios,
    }
    return entorno["http"].post(RUTA, json=datos, headers=_con("administrador"))


def test_administrador_registra_y_dueno_consulta_un_vehiculo(entorno):
    creado = _crear(entorno)
    assert creado.status_code == 201
    assert creado.json() == {
        "id_vehiculo": creado.json()["id_vehiculo"],
        "patente": "VF022AA",
        "marca": "Mercedes-Benz",
        "modelo": "Sprinter",
        "capacidad": 19,
        "disponibilidad": True,
    }

    consultado = entorno["http"].get(
        f"{RUTA}/{creado.json()['id_vehiculo']}", headers=_con("dueno")
    )
    assert consultado.status_code == 200
    assert consultado.json() == creado.json()


def test_listado_ordenado_y_vacio(entorno):
    vacio = entorno["http"].get(RUTA, headers=_con("administrador"))
    assert vacio.status_code == 200
    assert vacio.json() == []
    segundo = _crear(entorno, "VF022BB").json()
    primero = _crear(entorno, "VF022AA").json()
    listado = entorno["http"].get(RUTA, headers=_con("administrador"))
    assert [vehiculo["id_vehiculo"] for vehiculo in listado.json()] == [
        segundo["id_vehiculo"],
        primero["id_vehiculo"],
    ]


def test_modifica_solo_campos_respaldados_y_admite_opcionales_nulos(entorno):
    id_vehiculo = _crear(entorno).json()["id_vehiculo"]
    respuesta = entorno["http"].patch(
        f"{RUTA}/{id_vehiculo}",
        json={
            "patente": "VF022ZZ",
            "marca": None,
            "modelo": None,
            "capacidad": 24,
            "disponibilidad": False,
        },
        headers=_con("administrador"),
    )
    assert respuesta.status_code == 200
    assert respuesta.json() == {
        "id_vehiculo": id_vehiculo,
        "patente": "VF022ZZ",
        "marca": None,
        "modelo": None,
        "capacidad": 24,
        "disponibilidad": False,
    }


@pytest.mark.parametrize("operacion", ["crear", "actualizar"])
def test_patente_duplicada_no_escribe(entorno, operacion):
    primero = _crear(entorno, "VF022AA").json()
    if operacion == "crear":
        respuesta = _crear(entorno, "VF022AA")
    else:
        segundo = _crear(entorno, "VF022BB").json()
        respuesta = entorno["http"].patch(
            f"{RUTA}/{segundo['id_vehiculo']}",
            json={"patente": "VF022AA"},
            headers=_con("administrador"),
        )
    assert respuesta.status_code == 409
    assert respuesta.json()["error"]["codigo"] == "PATENTE_DUPLICADA"
    assert asyncio.run(
        consultar(entorno["base"], "SELECT patente FROM vehiculo ORDER BY id_vehiculo")
    )[0] == (primero["patente"],)


@pytest.mark.parametrize(
    "datos",
    [
        {"patente": "VF022AA", "capacidad": 0},
        {"patente": "VF022AA", "capacidad": 19, "documentacion": "inventada"},
    ],
)
def test_alta_rechaza_valores_o_campos_fuera_del_modelo(entorno, datos):
    respuesta = entorno["http"].post(RUTA, json=datos, headers=_con("administrador"))
    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "VALIDACION"
    assert asyncio.run(consultar(entorno["base"], "SELECT count(*) FROM vehiculo")) == [(0,)]


@pytest.mark.parametrize(
    "datos",
    [{}, {"capacidad": 0}, {"patente": None}, {"disponibilidad": None}],
)
def test_update_requiere_un_cambio_valido(entorno, datos):
    id_vehiculo = _crear(entorno).json()["id_vehiculo"]
    respuesta = entorno["http"].patch(
        f"{RUTA}/{id_vehiculo}", json=datos, headers=_con("administrador")
    )
    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "VALIDACION"


@pytest.mark.parametrize("metodo,ruta", [("get", RUTA), ("post", RUTA), ("patch", f"{RUTA}/1")])
@pytest.mark.parametrize("headers,estado", [({}, 401), (_con("pasajero"), 403)])
def test_solo_administrador_o_dueno(entorno, metodo, ruta, headers, estado):
    datos = {"patente": "VF022AA", "capacidad": 19} if metodo == "post" else {"marca": "X"}
    respuesta = getattr(entorno["http"], metodo)(
        ruta, headers=headers, **({"json": datos} if metodo != "get" else {})
    )
    assert respuesta.status_code == estado


@pytest.mark.parametrize("metodo", ["get", "patch"])
def test_vehiculo_inexistente_responde_404(entorno, metodo):
    argumentos = {"json": {"marca": "X"}} if metodo == "patch" else {}
    respuesta = getattr(entorno["http"], metodo)(
        f"{RUTA}/999999", headers=_con("administrador"), **argumentos
    )
    assert respuesta.status_code == 404
    assert respuesta.json()["error"]["codigo"] == "VEHICULO_NO_ENCONTRADO"


def test_modificar_vehiculo_no_altera_su_asignacion(entorno):
    id_vehiculo = _crear(entorno).json()["id_vehiculo"]
    asyncio.run(
        ejecutar_sql(
            entorno["base"],
            "INSERT INTO servicio (tipo_servicio) VALUES ('UNIVERSITARIO'); "
            "INSERT INTO recorrido DEFAULT VALUES",
        )
    )
    id_servicio = asyncio.run(consultar(entorno["base"], "SELECT id_servicio FROM servicio"))[0][0]
    id_recorrido = asyncio.run(consultar(entorno["base"], "SELECT id_recorrido FROM recorrido"))[0][
        0
    ]
    asyncio.run(
        ejecutar_sql(
            entorno["base"],
            "INSERT INTO viaje (id_servicio, id_recorrido, id_vehiculo, fecha, sentido) "
            "VALUES ($1, $2, $3, '2026-11-20', 'IDA')",
            id_servicio,
            id_recorrido,
            id_vehiculo,
        )
    )
    respuesta = entorno["http"].patch(
        f"{RUTA}/{id_vehiculo}",
        json={"marca": "Iveco", "disponibilidad": False},
        headers=_con("administrador"),
    )
    assert respuesta.status_code == 200
    assert asyncio.run(consultar(entorno["base"], "SELECT id_vehiculo FROM viaje")) == [
        (id_vehiculo,)
    ]


def test_respuestas_no_agregan_documentacion_ni_campos_fuera_del_contrato(entorno):
    declarados = set(
        yaml.safe_load(CONTRATO.read_text(encoding="utf-8"))["components"]["schemas"]["Vehiculo"][
            "properties"
        ]
    )
    respuesta = _crear(entorno)
    assert set(respuesta.json()) == declarados
    assert "documentacion" not in respuesta.json()
