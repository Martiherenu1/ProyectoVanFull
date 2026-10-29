"""CU-015: consulta administrativa de solo lectura; conserva CU-006."""

import asyncio
from pathlib import Path

import pytest
import yaml

from app.core.security import crear_token
from tests._bd import base_migrada, cliente_api, consultar
from tests.test_deuda import _con, _crear_movimiento, _crear_pasajero


@pytest.fixture(scope="module")
def entorno():
    with base_migrada() as base:
        clientes = {
            "deuda": _crear_pasajero(base, "admin-deuda-1", ["pasajero"]),
            "acreedor": _crear_pasajero(base, "admin-deuda-2", ["pasajero"]),
            "vacio": _crear_pasajero(base, "admin-deuda-3", ["pasajero"]),
            "sin_cuenta": _crear_pasajero(
                base, "admin-deuda-4", ["pasajero"], con_cuenta_corriente=False
            ),
        }
        _crear_movimiento(base, clientes["deuda"]["id_cliente"], "DEUDOR", "150.25")
        _crear_movimiento(base, clientes["deuda"]["id_cliente"], "ACREEDOR", "30.00")
        _crear_movimiento(base, clientes["acreedor"]["id_cliente"], "ACREEDOR", "50.00")
        with cliente_api(base) as api:
            yield base, api, clientes


def cabecera(clientes, rol):
    persona = clientes["deuda"]["id_persona"]
    return {"Authorization": f"Bearer {crear_token(persona, persona, [rol])}"}


@pytest.mark.parametrize("rol", ["administrador", "dueno"])
@pytest.mark.parametrize(
    ("nombre", "saldo", "estado"),
    [
        ("deuda", 120.25, "con_deuda"),
        ("acreedor", 0, "al_dia"),
        ("vacio", 0, "al_dia"),
        ("sin_cuenta", 0, "al_dia"),
    ],
)
def test_consulta_por_cliente_y_rol(entorno, rol, nombre, saldo, estado):
    _, api, clientes = entorno
    id_cliente = clientes[nombre]["id_cliente"]
    respuesta = api.get(f"/api/clientes/{id_cliente}/deuda", headers=cabecera(clientes, rol))
    assert respuesta.status_code == 200
    assert respuesta.json() == {"saldo": saldo, "estado": estado}


@pytest.mark.parametrize("rol", ["pasajero", "chofer", "corporativo"])
def test_otros_roles_no_consultan_ni_revelan_existencia(entorno, rol):
    _, api, clientes = entorno
    respuesta = api.get("/api/clientes/999999/deuda", headers=cabecera(clientes, rol))
    assert respuesta.status_code == 403
    assert respuesta.json()["error"]["codigo"] == "SIN_PERMISO"


def test_autenticacion_inexistente_y_validacion(entorno):
    _, api, clientes = entorno
    assert api.get("/api/clientes/1/deuda").status_code == 401
    respuesta = api.get("/api/clientes/999999/deuda", headers=cabecera(clientes, "administrador"))
    assert respuesta.status_code == 404
    assert respuesta.json()["error"]["codigo"] == "CLIENTE_NO_ENCONTRADO"
    assert api.get("/api/clientes/0/deuda", headers=cabecera(clientes, "dueno")).status_code == 400


def test_no_escribe_y_cu006_conserva_solo_lo_propio(entorno):
    base, api, clientes = entorno
    sql = "SELECT id_movimiento_cuenta, id_cliente, naturaleza, importe FROM movimiento_cuenta ORDER BY id_movimiento_cuenta"
    antes = asyncio.run(consultar(base, sql))
    id_cliente = clientes["deuda"]["id_cliente"]
    admin = api.get(
        f"/api/clientes/{id_cliente}/deuda", headers=cabecera(clientes, "administrador")
    )
    propia = api.get("/api/pasajeros/me/deuda", headers=_con(clientes["deuda"]))
    ajena = api.get("/api/pasajeros/me/deuda", headers=_con(clientes["acreedor"]))
    assert propia.json() == admin.json() == {"saldo": 120.25, "estado": "con_deuda"}
    assert ajena.json() == {"saldo": 0, "estado": "al_dia"}
    assert asyncio.run(consultar(base, sql)) == antes


def test_contrato_reutiliza_deuda_y_marca_cobertura_parcial():
    ruta = Path(__file__).resolve().parents[1] / "openapi" / "openapi.yaml"
    contrato = yaml.safe_load(ruta.read_text(encoding="utf-8"))
    operacion = contrato["paths"]["/clientes/{id_cliente}/deuda"]["get"]
    assert operacion["x-cobertura"] == "parcial"
    assert operacion["responses"]["200"]["content"]["application/json"]["schema"] == {
        "$ref": "#/components/schemas/Deuda"
    }
