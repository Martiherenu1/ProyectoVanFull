"""Primera entrega de administración de choferes (CU-021) contra PostgreSQL real."""

import asyncio
from pathlib import Path

import pytest
import yaml

from app.core.security import crear_token
from tests._bd import base_migrada, cliente_api, consultar, ejecutar_sql

RUTA = "/api/choferes"
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
            "DELETE FROM viaje; DELETE FROM chofer; DELETE FROM cuenta_rol; "
            "DELETE FROM cuenta_acceso; DELETE FROM persona; DELETE FROM recorrido; "
            "DELETE FROM servicio",
        )
    )


def _crear(entorno, dni="21000001", **cambios):
    datos = {
        "nombre": "Ana",
        "apellido": "Pérez",
        "dni": dni,
        "direccion": "Calle 1",
        "telefono": "1122334455",
        "email": "ana.chofer@vanfull.test",
        "cuil": "27-21000001-1",
        "registro_conducir": "REG-CU021",
        "fecha_vencimiento_registro": "2028-06-30",
        **cambios,
    }
    return entorno["http"].post(RUTA, json=datos, headers=_con("administrador"))


def test_administrador_registra_y_dueno_consulta_un_chofer(entorno):
    creado = _crear(entorno)
    assert creado.status_code == 201
    assert creado.json() == {
        "id_persona": creado.json()["id_persona"],
        "nombre": "Ana",
        "apellido": "Pérez",
        "dni": "21000001",
        "direccion": "Calle 1",
        "telefono": "1122334455",
        "email": "ana.chofer@vanfull.test",
        "cuil": "27-21000001-1",
        "registro_conducir": "REG-CU021",
        "fecha_vencimiento_registro": "2028-06-30",
    }
    consultado = entorno["http"].get(f"{RUTA}/{creado.json()['id_persona']}", headers=_con("dueno"))
    assert consultado.status_code == 200
    assert consultado.json() == creado.json()


def test_listado_ordenado_y_vacio(entorno):
    assert entorno["http"].get(RUTA, headers=_con("administrador")).json() == []
    segundo = _crear(entorno, "21000002").json()
    primero = _crear(entorno, "21000001", email="otra@vanfull.test").json()
    listado = entorno["http"].get(RUTA, headers=_con("administrador"))
    assert listado.status_code == 200
    assert [chofer["id_persona"] for chofer in listado.json()] == [
        segundo["id_persona"],
        primero["id_persona"],
    ]


def test_modifica_persona_y_chofer_y_admite_opcionales_nulos(entorno):
    id_persona = _crear(entorno).json()["id_persona"]
    respuesta = entorno["http"].patch(
        f"{RUTA}/{id_persona}",
        json={
            "nombre": "Andrea",
            "apellido": "Gómez",
            "dni": "22000002",
            "direccion": None,
            "telefono": None,
            "email": None,
            "cuil": None,
            "registro_conducir": None,
            "fecha_vencimiento_registro": None,
        },
        headers=_con("administrador"),
    )
    assert respuesta.status_code == 200
    assert respuesta.json() == {
        "id_persona": id_persona,
        "nombre": "Andrea",
        "apellido": "Gómez",
        "dni": "22000002",
        "direccion": None,
        "telefono": None,
        "email": None,
        "cuil": None,
        "registro_conducir": None,
        "fecha_vencimiento_registro": None,
    }


@pytest.mark.parametrize("operacion", ["crear", "actualizar"])
def test_dni_duplicado_no_deja_escrituras_parciales(entorno, operacion):
    primero = _crear(entorno, "21000001").json()
    if operacion == "crear":
        respuesta = _crear(entorno, "21000001", email="duplicado@vanfull.test")
    else:
        segundo = _crear(entorno, "21000002", email="segundo@vanfull.test").json()
        respuesta = entorno["http"].patch(
            f"{RUTA}/{segundo['id_persona']}",
            json={"dni": "21000001"},
            headers=_con("administrador"),
        )
    assert respuesta.status_code == 409
    assert respuesta.json()["error"]["codigo"] == "DNI_DUPLICADO"
    assert asyncio.run(consultar(entorno["base"], "SELECT dni FROM persona ORDER BY id_persona"))[
        0
    ] == (primero["dni"],)
    cantidades = asyncio.run(
        consultar(
            entorno["base"],
            "SELECT (SELECT count(*) FROM persona), (SELECT count(*) FROM chofer)",
        )
    )[0]
    assert cantidades[0] == cantidades[1]


@pytest.mark.parametrize(
    "datos",
    [
        {"apellido": "Pérez", "dni": "21000001"},
        {"nombre": "Ana", "apellido": "Pérez", "dni": "21000001", "cuenta": "x"},
        {"nombre": "Ana", "apellido": "Pérez", "dni": "21000001", "estado": "activo"},
    ],
)
def test_alta_rechaza_ausentes_y_campos_fuera_del_modelo(entorno, datos):
    respuesta = entorno["http"].post(RUTA, json=datos, headers=_con("administrador"))
    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "VALIDACION"
    assert asyncio.run(consultar(entorno["base"], "SELECT count(*) FROM persona")) == [(0,)]


@pytest.mark.parametrize("datos", [{}, {"nombre": None}, {"apellido": None}, {"dni": None}])
def test_update_requiere_un_cambio_valido(entorno, datos):
    id_persona = _crear(entorno).json()["id_persona"]
    respuesta = entorno["http"].patch(
        f"{RUTA}/{id_persona}", json=datos, headers=_con("administrador")
    )
    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "VALIDACION"


@pytest.mark.parametrize("metodo,ruta", [("get", RUTA), ("post", RUTA), ("patch", f"{RUTA}/1")])
@pytest.mark.parametrize("headers,estado", [({}, 401), (_con("pasajero"), 403)])
def test_solo_administrador_o_dueno(entorno, metodo, ruta, headers, estado):
    datos = (
        {"nombre": "Ana", "apellido": "Pérez", "dni": "21000001"}
        if metodo == "post"
        else {"nombre": "Andrea"}
    )
    respuesta = getattr(entorno["http"], metodo)(
        ruta, headers=headers, **({"json": datos} if metodo != "get" else {})
    )
    assert respuesta.status_code == estado


@pytest.mark.parametrize("metodo", ["get", "patch"])
def test_chofer_inexistente_responde_404(entorno, metodo):
    argumentos = {"json": {"nombre": "X"}} if metodo == "patch" else {}
    respuesta = getattr(entorno["http"], metodo)(
        f"{RUTA}/999999", headers=_con("administrador"), **argumentos
    )
    assert respuesta.status_code == 404
    assert respuesta.json()["error"]["codigo"] == "CHOFER_NO_ENCONTRADO"


def test_alta_no_crea_cuenta_rol_ni_estado_administrativo(entorno):
    creado = _crear(entorno)
    assert creado.status_code == 201
    assert asyncio.run(consultar(entorno["base"], "SELECT count(*) FROM cuenta_acceso")) == [(0,)]
    assert "estado" not in creado.json()
    assert "documentacion" not in creado.json()


def test_modificar_chofer_no_altera_su_asignacion(entorno):
    id_persona = _crear(entorno).json()["id_persona"]
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
            "INSERT INTO viaje (id_servicio, id_recorrido, id_chofer, fecha, sentido) "
            "VALUES ($1, $2, $3, '2026-11-20', 'IDA')",
            id_servicio,
            id_recorrido,
            id_persona,
        )
    )
    respuesta = entorno["http"].patch(
        f"{RUTA}/{id_persona}",
        json={"telefono": "1199999999"},
        headers=_con("administrador"),
    )
    assert respuesta.status_code == 200
    assert asyncio.run(consultar(entorno["base"], "SELECT id_chofer FROM viaje")) == [(id_persona,)]


def test_respuestas_coinciden_con_el_contrato(entorno):
    declarados = set(
        yaml.safe_load(CONTRATO.read_text(encoding="utf-8"))["components"]["schemas"][
            "ChoferAdmin"
        ]["properties"]
    )
    respuesta = _crear(entorno)
    assert set(respuesta.json()) == declarados
