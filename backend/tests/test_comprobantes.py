"""Comprobantes propios del pasajero (CU-035) contra un PostgreSQL real."""

import asyncio
from decimal import Decimal
from pathlib import Path

import pytest
import yaml

from app.core.security import crear_token
from tests._bd import base_migrada, cliente_api, consultar

RUTA = "/api/pasajeros/me/comprobantes"
CONTRATO = Path(__file__).resolve().parents[1] / "openapi" / "openapi.yaml"
NO_ENCONTRADO = "COMPROBANTE_NO_ENCONTRADO"


def _uno(base: str, sql: str, *args):
    return asyncio.run(consultar(base, sql, *args))[0][0]


def _pasajero(base: str, dni: str, roles: list[str], *, con_cliente: bool = True) -> dict:
    id_persona = _uno(
        base,
        "INSERT INTO persona (nombre, apellido, dni) VALUES ('Prueba', 'Comprobante', $1) "
        "RETURNING id_persona",
        dni,
    )
    _uno(base, "INSERT INTO pasajero (id_persona) VALUES ($1) RETURNING id_persona", id_persona)
    id_cliente = None
    if con_cliente:
        id_cliente = _uno(
            base,
            "INSERT INTO cliente (naturaleza_cliente) VALUES ('INDIVIDUAL') RETURNING id_cliente",
        )
        _uno(
            base,
            "INSERT INTO cliente_individual (id_cliente, id_persona) VALUES ($1, $2) "
            "RETURNING id_cliente",
            id_cliente,
            id_persona,
        )
        _uno(
            base,
            "INSERT INTO cuenta_corriente (id_cliente) VALUES ($1) RETURNING id_cliente",
            id_cliente,
        )
    return {
        "id_cliente": id_cliente,
        "token": crear_token(id_persona, id_persona, roles),
    }


def _recibo(base: str, id_cliente: int, importe: str, medio: str) -> dict:
    id_pago = _uno(
        base,
        "INSERT INTO pago (id_cliente, importe, medio_pago, estado) "
        "VALUES ($1, $2, $3, 'CONFIRMADO') RETURNING id_pago",
        id_cliente,
        Decimal(importe),
        medio,
    )
    id_comprobante = _uno(
        base,
        "INSERT INTO comprobante (tipo, id_pago) VALUES ('RECIBO', $1) RETURNING id_comprobante",
        id_pago,
    )
    return {"id_comprobante": id_comprobante, "id_pago": id_pago}


def _factura(base: str, id_cliente: int, id_servicio: int, importe: str | None) -> dict:
    id_contratacion = _uno(
        base,
        "INSERT INTO contratacion (id_cliente, id_servicio, importe_acordado) "
        "VALUES ($1, $2, $3) RETURNING id_contratacion",
        id_cliente,
        id_servicio,
        None if importe is None else Decimal(importe),
    )
    id_comprobante = _uno(
        base,
        "INSERT INTO comprobante (tipo, id_contratacion) VALUES ('FACTURA', $1) "
        "RETURNING id_comprobante",
        id_contratacion,
    )
    return {"id_comprobante": id_comprobante, "id_contratacion": id_contratacion}


def _nota(base: str, id_cliente: int, tipo: str, naturaleza: str, importe: str) -> dict:
    id_movimiento = _uno(
        base,
        "INSERT INTO movimiento_cuenta (id_cliente, naturaleza, importe) VALUES ($1, $2, $3) "
        "RETURNING id_movimiento_cuenta",
        id_cliente,
        naturaleza,
        Decimal(importe),
    )
    id_comprobante = _uno(
        base,
        "INSERT INTO comprobante (tipo, id_movimiento_cuenta) VALUES ($1, $2) "
        "RETURNING id_comprobante",
        tipo,
        id_movimiento,
    )
    return {"id_comprobante": id_comprobante, "id_movimiento_cuenta": id_movimiento}


def _con(persona: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {persona['token']}"}


@pytest.fixture(scope="module")
def entorno():
    with base_migrada() as base:
        p = {
            "ana": _pasajero(base, "comp-100", ["pasajero"]),
            "beto": _pasajero(base, "comp-200", ["pasajero"]),
            "sin_comprobantes": _pasajero(base, "comp-300", ["pasajero"]),
            "sin_cliente": _pasajero(base, "comp-400", ["pasajero"], con_cliente=False),
            "chofer": _pasajero(base, "comp-500", ["chofer"]),
            "admin": _pasajero(base, "comp-600", ["administrador"]),
        }
        id_servicio = _uno(
            base,
            "INSERT INTO servicio (tipo_servicio) VALUES ('UNIVERSITARIO') RETURNING id_servicio",
        )
        ana = p["ana"]["id_cliente"]
        c = {
            # Intercalados con los de Beto: el orden y el filtro no pueden depender de la inserción.
            "recibo_ana": _recibo(base, ana, "1500.50", "TRANSFERENCIA"),
            "recibo_beto": _recibo(base, p["beto"]["id_cliente"], "700.00", "EFECTIVO"),
            "factura_ana": _factura(base, ana, id_servicio, "9000.00"),
            "factura_sin_importe": _factura(base, ana, id_servicio, None),
            "factura_beto": _factura(base, p["beto"]["id_cliente"], id_servicio, "100.00"),
            "nota_credito_ana": _nota(base, ana, "NOTA_DE_CREDITO", "ACREEDOR", "200.00"),
            "nota_debito_beto": _nota(
                base, p["beto"]["id_cliente"], "NOTA_DE_DEBITO", "DEUDOR", "50.00"
            ),
        }
        with cliente_api(base) as cliente:
            yield base, cliente, p, c


# --- Lista ------------------------------------------------------------------------------


def test_lista_solo_los_comprobantes_propios_en_orden(entorno):
    _, cliente, p, c = entorno

    respuesta = cliente.get(RUTA, headers=_con(p["ana"]))

    assert respuesta.status_code == 200
    ids = [fila["id_comprobante"] for fila in respuesta.json()]
    assert ids == [
        c["recibo_ana"]["id_comprobante"],
        c["factura_ana"]["id_comprobante"],
        c["factura_sin_importe"]["id_comprobante"],
        c["nota_credito_ana"]["id_comprobante"],
    ]


def test_otro_pasajero_ve_los_suyos_y_no_los_de_ana(entorno):
    _, cliente, p, c = entorno

    respuesta = cliente.get(RUTA, headers=_con(p["beto"]))

    assert respuesta.status_code == 200
    assert [(f["id_comprobante"], f["tipo"]) for f in respuesta.json()] == [
        (c["recibo_beto"]["id_comprobante"], "RECIBO"),
        (c["factura_beto"]["id_comprobante"], "FACTURA"),
        (c["nota_debito_beto"]["id_comprobante"], "NOTA_DE_DEBITO"),
    ]


@pytest.mark.parametrize("quien", ["sin_comprobantes", "sin_cliente"])
def test_sin_comprobantes_la_lista_esta_vacia(entorno, quien):
    _, cliente, p, _ = entorno

    respuesta = cliente.get(RUTA, headers=_con(p[quien]))

    assert respuesta.status_code == 200
    assert respuesta.json() == []


# --- Detalle: los datos salen del origen ---------------------------------------------------


def test_el_recibo_trae_fecha_importe_y_medio_del_pago(entorno):
    base, cliente, p, c = entorno
    recibo = c["recibo_ana"]

    respuesta = cliente.get(f"{RUTA}/{recibo['id_comprobante']}", headers=_con(p["ana"]))

    assert respuesta.status_code == 200
    cuerpo = respuesta.json()
    assert {k: v for k, v in cuerpo.items() if k != "fecha_hora"} == {
        "id_comprobante": recibo["id_comprobante"],
        "tipo": "RECIBO",
        "id_pago": recibo["id_pago"],
        "id_contratacion": None,
        "id_movimiento_cuenta": None,
        "importe": 1500.5,
        "medio_pago": "TRANSFERENCIA",
    }
    assert cuerpo["fecha_hora"] is not None


def test_la_factura_trae_el_importe_acordado_y_no_tiene_fecha(entorno):
    _, cliente, p, c = entorno
    factura = c["factura_ana"]

    cuerpo = cliente.get(f"{RUTA}/{factura['id_comprobante']}", headers=_con(p["ana"])).json()

    assert cuerpo["tipo"] == "FACTURA"
    assert cuerpo["id_contratacion"] == factura["id_contratacion"]
    assert (cuerpo["fecha_hora"], cuerpo["importe"], cuerpo["medio_pago"]) == (None, 9000.0, None)


def test_una_factura_sin_importe_acordado_lo_informa_nulo(entorno):
    _, cliente, p, c = entorno
    factura = c["factura_sin_importe"]

    cuerpo = cliente.get(f"{RUTA}/{factura['id_comprobante']}", headers=_con(p["ana"])).json()

    assert cuerpo["importe"] is None


def test_la_nota_trae_fecha_e_importe_del_movimiento(entorno):
    _, cliente, p, c = entorno
    nota = c["nota_credito_ana"]

    cuerpo = cliente.get(f"{RUTA}/{nota['id_comprobante']}", headers=_con(p["ana"])).json()

    assert cuerpo["tipo"] == "NOTA_DE_CREDITO"
    assert cuerpo["id_movimiento_cuenta"] == nota["id_movimiento_cuenta"]
    assert (cuerpo["importe"], cuerpo["medio_pago"]) == (200.0, None)
    assert cuerpo["fecha_hora"] is not None


# --- A2: lo ajeno no se muestra ni se confirma ----------------------------------------------


@pytest.mark.parametrize("ajeno", ["recibo_beto", "factura_beto", "nota_debito_beto"])
def test_un_comprobante_ajeno_responde_lo_mismo_que_uno_inexistente(entorno, ajeno):
    _, cliente, p, c = entorno

    ajena = cliente.get(f"{RUTA}/{c[ajeno]['id_comprobante']}", headers=_con(p["ana"]))
    inexistente = cliente.get(f"{RUTA}/999999", headers=_con(p["ana"]))

    assert ajena.status_code == inexistente.status_code == 404
    assert ajena.json() == inexistente.json()
    assert ajena.json()["error"]["codigo"] == NO_ENCONTRADO


def test_sin_cliente_individual_el_detalle_responde_404(entorno):
    _, cliente, p, c = entorno

    respuesta = cliente.get(
        f"{RUTA}/{c['recibo_ana']['id_comprobante']}", headers=_con(p["sin_cliente"])
    )

    assert respuesta.status_code == 404
    assert respuesta.json()["error"]["codigo"] == NO_ENCONTRADO


# --- Permisos y solo lectura -------------------------------------------------------------


@pytest.mark.parametrize("rol", ["chofer", "admin"])
def test_otros_roles_reciben_403(entorno, rol):
    _, cliente, p, c = entorno

    lista = cliente.get(RUTA, headers=_con(p[rol]))
    detalle = cliente.get(f"{RUTA}/{c['recibo_ana']['id_comprobante']}", headers=_con(p[rol]))

    assert lista.status_code == detalle.status_code == 403


def test_sin_token_responde_401(entorno):
    _, cliente, _, _ = entorno

    assert cliente.get(RUTA).status_code == 401
    assert cliente.get(f"{RUTA}/1").status_code == 401


def test_consultar_no_modifica_comprobantes_pagos_ni_movimientos(entorno):
    base, cliente, p, c = entorno
    consultas = [
        "SELECT * FROM comprobante ORDER BY id_comprobante",
        "SELECT * FROM pago ORDER BY id_pago",
        "SELECT * FROM movimiento_cuenta ORDER BY id_movimiento_cuenta",
    ]
    antes = [asyncio.run(consultar(base, q)) for q in consultas]

    cliente.get(RUTA, headers=_con(p["ana"]))
    cliente.get(f"{RUTA}/{c['recibo_ana']['id_comprobante']}", headers=_con(p["ana"]))

    assert [asyncio.run(consultar(base, q)) for q in consultas] == antes


def test_la_respuesta_tiene_los_campos_del_contrato(entorno):
    _, cliente, p, _ = entorno
    esquema = yaml.safe_load(CONTRATO.read_text(encoding="utf-8"))["components"]["schemas"][
        "ComprobantePropio"
    ]

    for fila in cliente.get(RUTA, headers=_con(p["ana"])).json():
        assert set(fila) == set(esquema["properties"]) == set(esquema["required"])
        assert fila["tipo"] in esquema["properties"]["tipo"]["enum"]
