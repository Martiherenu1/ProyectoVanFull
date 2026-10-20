"""Consulta de deuda propia (CU-006) contra un PostgreSQL real."""

import asyncio
from decimal import Decimal
from pathlib import Path

import pytest
import yaml

from app.core.security import crear_token
from tests._bd import base_migrada, cliente_api, consultar, ejecutar_sql

RUTA = "/api/pasajeros/me/deuda"
CONTRATO = Path(__file__).resolve().parents[1] / "openapi" / "openapi.yaml"


def _crear_pasajero(
    base: str,
    dni: str,
    roles: list[str],
    *,
    con_cliente_individual: bool = True,
    con_cuenta_corriente: bool = True,
) -> dict:
    id_persona = asyncio.run(
        consultar(
            base,
            "INSERT INTO persona (nombre, apellido, dni) "
            "VALUES ('Prueba', 'Deuda', $1) RETURNING id_persona",
            dni,
        )
    )[0][0]
    asyncio.run(
        ejecutar_sql(
            base,
            "INSERT INTO pasajero (id_persona) VALUES ($1)",
            id_persona,
        )
    )

    id_cliente = None
    if con_cliente_individual:
        id_cliente = asyncio.run(
            consultar(
                base,
                "INSERT INTO cliente (naturaleza_cliente) "
                "VALUES ('INDIVIDUAL') RETURNING id_cliente",
            )
        )[0][0]
        asyncio.run(
            ejecutar_sql(
                base,
                "INSERT INTO cliente_individual (id_cliente, id_persona) VALUES ($1, $2)",
                id_cliente,
                id_persona,
            )
        )
    if con_cuenta_corriente and id_cliente is not None:
        asyncio.run(
            ejecutar_sql(
                base,
                "INSERT INTO cuenta_corriente (id_cliente) VALUES ($1)",
                id_cliente,
            )
        )

    return {
        "id_persona": id_persona,
        "id_cliente": id_cliente,
        "token": crear_token(id_persona, id_persona, roles),
    }


def _crear_movimiento(base: str, id_cliente: int, naturaleza: str, importe: str) -> None:
    asyncio.run(
        ejecutar_sql(
            base,
            "INSERT INTO movimiento_cuenta (id_cliente, naturaleza, importe) VALUES ($1, $2, $3)",
            id_cliente,
            naturaleza,
            Decimal(importe),
        )
    )


def _con(persona: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {persona['token']}"}


@pytest.fixture(scope="module")
def entorno():
    with base_migrada() as base:
        personas = {
            "ana": _crear_pasajero(base, "deuda-100", ["pasajero"]),
            "beto": _crear_pasajero(base, "deuda-200", ["pasajero"]),
            "sin_movimientos": _crear_pasajero(base, "deuda-300", ["pasajero"]),
            "chofer": _crear_pasajero(base, "deuda-400", ["chofer"]),
            "sin_cuenta": _crear_pasajero(
                base,
                "deuda-500",
                ["pasajero"],
                con_cuenta_corriente=False,
            ),
            "sin_cliente": _crear_pasajero(
                base,
                "deuda-600",
                ["pasajero"],
                con_cliente_individual=False,
                con_cuenta_corriente=False,
            ),
        }

        _crear_movimiento(base, personas["ana"]["id_cliente"], "DEUDOR", "150.00")
        _crear_movimiento(base, personas["ana"]["id_cliente"], "ACREEDOR", "30.00")
        _crear_movimiento(base, personas["beto"]["id_cliente"], "DEUDOR", "80.00")
        _crear_movimiento(base, personas["beto"]["id_cliente"], "ACREEDOR", "200.00")

        with cliente_api(base) as cliente:
            yield base, cliente, personas


def test_calcula_el_saldo_deudor_desde_los_movimientos(entorno):
    _, cliente, personas = entorno

    respuesta = cliente.get(RUTA, headers=_con(personas["ana"]))

    assert respuesta.status_code == 200
    assert respuesta.json() == {"saldo": 120.0, "estado": "con_deuda"}


def test_un_saldo_acreedor_se_informa_sin_deuda(entorno):
    _, cliente, personas = entorno

    respuesta = cliente.get(RUTA, headers=_con(personas["beto"]))

    assert respuesta.status_code == 200
    assert respuesta.json() == {"saldo": 0.0, "estado": "al_dia"}


def test_una_cuenta_sin_movimientos_esta_al_dia(entorno):
    _, cliente, personas = entorno

    respuesta = cliente.get(RUTA, headers=_con(personas["sin_movimientos"]))

    assert respuesta.status_code == 200
    assert respuesta.json() == {"saldo": 0.0, "estado": "al_dia"}


def test_cada_pasajero_consulta_solamente_su_cuenta(entorno):
    _, cliente, personas = entorno

    deuda_ana = cliente.get(RUTA, headers=_con(personas["ana"])).json()
    deuda_beto = cliente.get(RUTA, headers=_con(personas["beto"])).json()

    assert deuda_ana == {"saldo": 120.0, "estado": "con_deuda"}
    assert deuda_beto == {"saldo": 0.0, "estado": "al_dia"}


def test_la_consulta_no_modifica_los_movimientos(entorno):
    base, cliente, personas = entorno
    consulta = (
        "SELECT id_movimiento_cuenta, id_cliente, naturaleza, importe "
        "FROM movimiento_cuenta ORDER BY id_movimiento_cuenta"
    )
    antes = asyncio.run(consultar(base, consulta))

    respuesta = cliente.get(RUTA, headers=_con(personas["ana"]))

    assert respuesta.status_code == 200
    assert asyncio.run(consultar(base, consulta)) == antes


def test_la_respuesta_usa_solamente_los_campos_del_contrato(entorno):
    _, cliente, personas = entorno
    contrato = yaml.safe_load(CONTRATO.read_text(encoding="utf-8"))
    campos = set(contrato["components"]["schemas"]["Deuda"]["properties"])

    respuesta = cliente.get(RUTA, headers=_con(personas["ana"]))

    assert set(respuesta.json()) == campos


def test_sin_token_es_401_y_otro_rol_es_403(entorno):
    _, cliente, personas = entorno

    assert cliente.get(RUTA).status_code == 401
    respuesta = cliente.get(RUTA, headers=_con(personas["chofer"]))
    assert respuesta.status_code == 403
    assert respuesta.json()["error"]["codigo"] == "SIN_PERMISO"


def test_un_pasajero_sin_cuenta_corriente_esta_al_dia(entorno):
    _, cliente, personas = entorno

    respuesta = cliente.get(RUTA, headers=_con(personas["sin_cuenta"]))

    assert respuesta.status_code == 200
    assert respuesta.json() == {"saldo": 0.0, "estado": "al_dia"}


def test_un_pasajero_sin_cliente_individual_es_404(entorno):
    _, cliente, personas = entorno

    respuesta = cliente.get(RUTA, headers=_con(personas["sin_cliente"]))

    assert respuesta.status_code == 404
    assert respuesta.json()["error"]["codigo"] == "CLIENTE_NO_ENCONTRADO"
