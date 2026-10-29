"""Brechas de integración #227: pagos→deuda y ciclo completo de viaje por HTTP.

Restricciones individuales, permisos y lectura CU-027 ya tienen cobertura específica.
Solo PostgreSQL temporal mediante los helpers existentes; no se modifica código funcional.
"""

import asyncio
from decimal import Decimal

import pytest

from tests._bd import base_migrada, cliente_api, consultar, ejecutar_sql
from tests.test_deuda import _crear_movimiento, _crear_pasajero
from tests.test_viajes import _con, _datos_validos, _uno
from tests.test_viajes import entorno as entorno


@pytest.fixture
def cuenta():
    with base_migrada() as base:
        persona = _crear_pasajero(base, "INT-ADMIN-227", ["pasajero"])
        _crear_movimiento(base, persona["id_cliente"], "DEUDOR", "1000.50")
        with cliente_api(base) as api:
            yield base, api, persona["id_cliente"]


def _efectos_pago(base, id_pago):
    consultas = [
        "SELECT tipo FROM comprobante WHERE id_pago=$1 ORDER BY id_comprobante",
        "SELECT naturaleza, importe FROM movimiento_cuenta WHERE id_pago=$1 "
        "ORDER BY id_movimiento_cuenta",
        "SELECT tipo_evento FROM evento_operativo WHERE id_pago=$1 ORDER BY id_evento_operativo",
    ]
    return [asyncio.run(consultar(base, sql, id_pago)) for sql in consultas]


@pytest.mark.parametrize("decision", ["CONFIRMADO", "RECHAZADO"])
def test_registro_decision_deuda_y_reintentos_sin_duplicar_efectos(cuenta, decision):
    """El saldo sale del movimiento real de CU-016, no de una precarga del resultado."""
    base, api, id_cliente = cuenta
    headers = _con(["administrador"])
    ruta_deuda = f"/api/clientes/{id_cliente}/deuda"
    inicial = {"saldo": 1000.50, "estado": "con_deuda"}
    deuda = api.get(ruta_deuda, headers=headers)
    assert deuda.status_code == 200
    assert deuda.json() == inicial

    registro = api.post(
        "/api/pagos",
        headers=headers,
        json={"id_cliente": id_cliente, "importe": 250.25, "medio_pago": "TRANSFERENCIA"},
    )
    assert registro.status_code == 201
    id_pago = registro.json()["id_pago"]
    assert registro.json()["estado"] == "PENDIENTE"
    assert api.get(ruta_deuda, headers=headers).json() == inicial

    ruta_decision = f"/api/pagos/{id_pago}/confirmacion"
    decidido = api.post(ruta_decision, json={"decision": decision}, headers=headers)
    assert decidido.status_code == 200
    assert decidido.json()["estado"] == decision
    saldo = 750.25 if decision == "CONFIRMADO" else 1000.50
    assert api.get(ruta_deuda, headers=headers).json() == {"saldo": saldo, "estado": "con_deuda"}
    efectos = _efectos_pago(base, id_pago)
    assert efectos == [
        [("RECIBO",)] if decision == "CONFIRMADO" else [],
        [("ACREEDOR", Decimal("250.25"))] if decision == "CONFIRMADO" else [],
        [
            ("pago_registrado",),
            ("pago_confirmado" if decision == "CONFIRMADO" else "pago_rechazado",),
        ],
    ]

    # El contrato rechaza redecidir; idempotencia de efectos no significa devolver 200.
    opuesta = "RECHAZADO" if decision == "CONFIRMADO" else "CONFIRMADO"
    for repetida in (decision, opuesta):
        respuesta = api.post(ruta_decision, json={"decision": repetida}, headers=headers)
        assert respuesta.status_code == 404
        assert respuesta.json()["error"]["codigo"] == "PAGO_PENDIENTE_NO_ENCONTRADO"
        assert _efectos_pago(base, id_pago) == efectos
        assert api.get(ruta_deuda, headers=headers).json() == {
            "saldo": saldo,
            "estado": "con_deuda",
        }
    assert _uno(base, "SELECT estado FROM pago WHERE id_pago=$1", id_pago) == decision


def test_crear_asignar_reasignar_actualizar_y_cancelar_mismo_viaje(entorno):
    e = entorno
    api, base = e["http"], e["base"]
    headers = _con(["administrador"])
    segundo_chofer = _uno(
        base,
        "INSERT INTO persona (nombre, apellido, dni) "
        "VALUES ('Segundo', 'Chofer', 'INT227') RETURNING id_persona",
    )
    asyncio.run(
        ejecutar_sql(
            base,
            "INSERT INTO chofer (id_persona, registro_conducir) VALUES ($1, 'REG-INT227')",
            segundo_chofer,
        )
    )
    segundo_vehiculo = _uno(
        base,
        "INSERT INTO vehiculo (patente, capacidad) VALUES ('INT227', 24) RETURNING id_vehiculo",
    )
    creado = api.post("/api/viajes", headers=headers, json=_datos_validos(e))
    assert creado.status_code == 201
    id_viaje = creado.json()["id_viaje"]
    ruta = f"/api/viajes/{id_viaje}"
    assert creado.json()["estado"] == "programado"
    for chofer, vehiculo in [
        (e["id_chofer"], e["id_vehiculo"]),
        (segundo_chofer, segundo_vehiculo),
    ]:
        asignado = api.patch(
            ruta, headers=headers, json={"id_chofer": chofer, "id_vehiculo": vehiculo}
        )
        assert asignado.status_code == 200
        assert (asignado.json()["id_chofer"], asignado.json()["id_vehiculo"]) == (chofer, vehiculo)
        assert asyncio.run(
            consultar(base, "SELECT id_chofer, id_vehiculo FROM viaje WHERE id_viaje=$1", id_viaje)
        ) == [(chofer, vehiculo)]

    actualizado = api.patch(
        ruta, headers=headers, json={"horario": "09:15", "capacidad_planificada": 16}
    )
    assert actualizado.status_code == 200
    assert actualizado.json()["id_chofer"] == segundo_chofer
    assert actualizado.json()["id_vehiculo"] == segundo_vehiculo
    assert actualizado.json()["horario"] == "09:15"
    assert actualizado.json()["capacidad_planificada"] == 16
    cancelado = api.post(ruta + "/cancelacion", headers=headers)
    assert cancelado.status_code == 200
    assert cancelado.json() == {**actualizado.json(), "estado": "cancelado"}
    listado = api.get("/api/viajes", params={"fecha": "2026-10-30"}, headers=headers)
    assert listado.status_code == 200
    assert next(v for v in listado.json() if v["id_viaje"] == id_viaje) == cancelado.json()

    antes = asyncio.run(consultar(base, "SELECT * FROM viaje WHERE id_viaje=$1", id_viaje))
    bloqueado = api.patch(ruta, headers=headers, json={"id_chofer": e["id_chofer"]})
    assert bloqueado.status_code == 409
    assert bloqueado.json()["error"]["codigo"] == "ESTADO_VIAJE_INVALIDO"
    assert asyncio.run(consultar(base, "SELECT * FROM viaje WHERE id_viaje=$1", id_viaje)) == antes
    assert asyncio.run(
        consultar(
            base,
            "SELECT tipo_evento FROM evento_operativo WHERE id_viaje=$1 ORDER BY id_evento_operativo",
            id_viaje,
        )
    ) == [
        ("viaje_creado",),
        ("viaje_actualizado",),
        ("viaje_actualizado",),
        ("viaje_actualizado",),
        ("viaje_cancelado",),
    ]
