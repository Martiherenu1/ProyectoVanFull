"""CU-029: consultas de viajes del chofer contra PostgreSQL migrado y contrato vigente."""

import asyncio
from datetime import date
from pathlib import Path

import pytest
import yaml

from app.core.security import crear_token
from tests._bd import base_migrada, cliente_api, consultar, ejecutar_sql

CONTRATO = Path(__file__).resolve().parents[1] / "openapi" / "openapi.yaml"
RUTA = "/api/choferes/me/viajes"


def _uno(base: str, sql: str, *args):
    return asyncio.run(consultar(base, sql, *args))[0][0]


def _ejecutar(base: str, sql: str, *args):
    asyncio.run(ejecutar_sql(base, sql, *args))


def _token(persona: int, roles: list[str]) -> dict[str, str]:
    return {"Authorization": f"Bearer {crear_token(1, persona, roles)}"}


@pytest.fixture(scope="module")
def entorno():
    with base_migrada() as base:
        servicio = _uno(
            base,
            "INSERT INTO servicio (tipo_servicio) VALUES ('UNIVERSITARIO') RETURNING id_servicio",
        )
        especial = _uno(
            base,
            "INSERT INTO servicio (tipo_servicio) VALUES ('ESPECIAL') RETURNING id_servicio",
        )
        recorrido = _uno(base, "INSERT INTO recorrido DEFAULT VALUES RETURNING id_recorrido")
        primera = _uno(
            base,
            "INSERT INTO parada (nombre_descripcion, direccion) "
            "VALUES ('Parada de inicio', 'Calle 1') RETURNING id_parada",
        )
        segunda = _uno(
            base,
            "INSERT INTO parada (nombre_descripcion) "
            "VALUES ('Parada final') RETURNING id_parada",
        )
        _ejecutar(
            base,
            "INSERT INTO parada_recorrido (id_recorrido, orden, id_parada) "
            "VALUES ($1, 2, $2), ($1, 1, $3)",
            recorrido,
            segunda,
            primera,
        )
        vehiculo = _uno(
            base,
            "INSERT INTO vehiculo (patente, capacidad) VALUES ('VF029AA', 20) "
            "RETURNING id_vehiculo",
        )
        choferes = []
        for n in (1, 2):
            id_persona = _uno(
                base,
                "INSERT INTO persona (nombre, apellido, dni) "
                "VALUES ($1, 'Prueba', $2) RETURNING id_persona",
                f"Chofer{n}",
                f"CU029-C{n}",
            )
            _ejecutar(base, "INSERT INTO chofer (id_persona) VALUES ($1)", id_persona)
            choferes.append(id_persona)
        pasajeros = []
        for n in (1, 2, 3):
            id_persona = _uno(
                base,
                "INSERT INTO persona (nombre, apellido, dni, email, telefono, direccion) "
                "VALUES ($1, 'Viaja', $2, 'privado@example.test', '112345', 'Privada 12') "
                "RETURNING id_persona",
                f"Pasajero{n}",
                f"CU029-P{n}",
            )
            _ejecutar(
                base,
                "INSERT INTO pasajero (id_persona, fotografia) VALUES ($1, $2)",
                id_persona,
                "foto-referenciada" if n == 1 else None,
            )
            pasajeros.append(id_persona)
        cliente = _uno(
            base,
            "INSERT INTO cliente (naturaleza_cliente) VALUES ('INDIVIDUAL') RETURNING id_cliente",
        )
        contrato = _uno(
            base,
            "INSERT INTO contratacion (id_cliente, id_servicio) VALUES ($1, $2) "
            "RETURNING id_contratacion",
            cliente,
            especial,
        )
        with cliente_api(base) as http:
            yield {
                "base": base,
                "http": http,
                "servicio": servicio,
                "especial": especial,
                "recorrido": recorrido,
                "vehiculo": vehiculo,
                "choferes": choferes,
                "pasajeros": pasajeros,
                "contrato": contrato,
            }


@pytest.fixture(autouse=True)
def _limpiar(entorno):
    _ejecutar(
        entorno["base"],
        "DELETE FROM abordaje; DELETE FROM ausencia; DELETE FROM integrante_nomina; "
        "DELETE FROM nomina_pasajeros; DELETE FROM reserva; "
        "DELETE FROM evento_operativo; DELETE FROM posicion_gps; DELETE FROM viaje;",
    )


def _viaje(entorno, chofer=None, fecha="2026-10-30", horario="07:30", especial=False):
    return _uno(
        entorno["base"],
        "INSERT INTO viaje (id_servicio, id_recorrido, id_vehiculo, id_chofer, "
        "fecha, horario, sentido, estado, capacidad_planificada) "
        "VALUES ($1, $2, $3, $4, $5::date, $6::time, 'IDA', 'programado', 18) "
        "RETURNING id_viaje",
        entorno["especial"] if especial else entorno["servicio"],
        entorno["recorrido"],
        entorno["vehiculo"],
        chofer,
        fecha,
        horario,
    )


def test_listado_rol_requerido(entorno):
    http = entorno["http"]
    assert http.get(RUTA).status_code == 401
    assert http.get(RUTA, headers=_token(entorno["choferes"][0], ["pasajero"])).status_code == 403


def test_sin_asignaciones_devuelve_lista_vacia(entorno):
    respuesta = entorno["http"].get(
        RUTA,
        params={"fecha": "2026-10-30"},
        headers=_token(entorno["choferes"][0], ["chofer"]),
    )
    assert respuesta.status_code == 200
    assert respuesta.json() == []


def test_filtro_por_chofer_fecha_y_horario_opcional(entorno):
    mio = entorno["choferes"][0]
    esperado = _viaje(entorno, chofer=mio)
    _viaje(entorno, chofer=entorno["choferes"][1])
    _viaje(entorno, chofer=mio, fecha="2026-10-31")
    sin_horario = _viaje(entorno, chofer=mio, horario=None)
    respuesta = entorno["http"].get(
        RUTA, params={"fecha": "2026-10-30"}, headers=_token(mio, ["chofer"])
    )
    assert respuesta.status_code == 200
    filas = respuesta.json()
    assert [fila["id_viaje"] for fila in filas] == [esperado, sin_horario]
    assert filas[0]["horario"] == "07:30"
    assert "horario" not in filas[1]
    assert all(fila["id_chofer"] == mio for fila in filas)


def test_fecha_omitida_usa_servidor_y_fecha_invalida_es_400(entorno):
    mio = entorno["choferes"][0]
    esperado = _viaje(entorno, chofer=mio, fecha=date.today().isoformat())
    resultado = entorno["http"].get(RUTA, headers=_token(mio, ["chofer"]))
    assert resultado.status_code == 200
    assert [fila["id_viaje"] for fila in resultado.json()] == [esperado]
    invalida = entorno["http"].get(
        RUTA, params={"fecha": "ayer"}, headers=_token(mio, ["chofer"])
    )
    assert invalida.status_code == 400
    assert invalida.json()["error"]["codigo"] == "VALIDACION"


def test_detalle_inexistente_o_ajeno_es_404(entorno):
    mio, otro = entorno["choferes"]
    id_viaje = _viaje(entorno, chofer=otro)
    http = entorno["http"]
    for ident in (id_viaje, 999999):
        respuesta = http.get(f"{RUTA}/{ident}", headers=_token(mio, ["chofer"]))
        assert respuesta.status_code == 404
        assert respuesta.json()["error"]["codigo"] == "VIAJE_NO_ENCONTRADO"
    assert http.get(f"{RUTA}/{id_viaje}").status_code == 401
    assert http.get(
        f"{RUTA}/{id_viaje}", headers=_token(mio, ["pasajero"])
    ).status_code == 403


def test_detalle_sin_reservas_ni_nomina_y_paradas_ordenadas(entorno):
    mio = entorno["choferes"][0]
    id_viaje = _viaje(entorno, chofer=mio, horario=None)
    respuesta = entorno["http"].get(f"{RUTA}/{id_viaje}", headers=_token(mio, ["chofer"]))
    assert respuesta.status_code == 200
    cuerpo = respuesta.json()
    assert cuerpo["viaje"]["id_viaje"] == id_viaje
    assert "horario" not in cuerpo["viaje"]
    assert cuerpo["capacidad_planificada"] == 18
    assert [x["orden"] for x in cuerpo["paradas"]] == [1, 2]
    assert "direccion" not in cuerpo["paradas"][1]
    assert cuerpo["pasajeros_con_reserva"] == []
    assert cuerpo["integrantes_nomina"] == []
    assert cuerpo["cantidades"] == {
        "consolidadas": 0,
        "provisionales": 0,
        "total_reservas": 0,
        "total_nomina": 0,
        "abordajes_registrados": 0,
    }


def test_detalle_reservas_nomina_abordaje_privacidad_y_totales(entorno):
    mio = entorno["choferes"][0]
    id_viaje = _viaje(entorno, chofer=mio, especial=True)
    estados = ("consolidada", "provisional", "cancelada")
    for pasajero, estado in zip(entorno["pasajeros"], estados, strict=True):
        _ejecutar(
            entorno["base"],
            "INSERT INTO reserva (id_pasajero, id_viaje, id_recorrido, orden_parada, "
            "id_contratacion_directa, estado) VALUES ($1, $2, $3, 1, $4, $5)",
            pasajero,
            id_viaje,
            entorno["recorrido"],
            entorno["contrato"],
            estado,
        )
    _ejecutar(
        entorno["base"],
        "INSERT INTO abordaje (id_pasajero, id_viaje, id_vehiculo, id_recorrido, orden_parada) "
        "VALUES ($1, $2, $3, $4, 1)",
        entorno["pasajeros"][0],
        id_viaje,
        entorno["vehiculo"],
        entorno["recorrido"],
    )
    _ejecutar(entorno["base"], "INSERT INTO nomina_pasajeros (id_viaje) VALUES ($1)", id_viaje)
    _ejecutar(
        entorno["base"],
        "INSERT INTO integrante_nomina (id_viaje, nombre, apellido, dni) "
        "VALUES ($1, 'Invitado', 'Especial', 'CU029-N1')",
        id_viaje,
    )

    respuesta = entorno["http"].get(f"{RUTA}/{id_viaje}", headers=_token(mio, ["chofer"]))
    assert respuesta.status_code == 200
    datos = respuesta.json()
    reservas = datos["pasajeros_con_reserva"]
    assert len(reservas) == 2
    assert {x["estado"] for x in reservas} == {"consolidada", "provisional"}
    assert [x["abordaje_registrado"] for x in reservas] == [True, False]
    assert reservas[0]["fotografia"] == "foto-referenciada"
    assert reservas[1]["fotografia"] is None
    for x in reservas:
        assert not {"telefono", "email", "direccion"} & set(x)
        assert {"id_reserva", "id_pasajero", "id_viaje", "orden_parada", "dni"} <= set(x)
    assert datos["integrantes_nomina"][0]["dni"] == "CU029-N1"
    assert "fotografia" not in datos["integrantes_nomina"][0]
    assert datos["cantidades"] == {
        "consolidadas": 1,
        "provisionales": 1,
        "total_reservas": 2,
        "total_nomina": 1,
        "abordajes_registrados": 1,
    }


def test_nuevas_respuestas_solo_contienen_campos_contratados(entorno):
    contrato = yaml.safe_load(CONTRATO.read_text(encoding="utf-8"))
    esquemas = contrato["components"]["schemas"]
    mio = entorno["choferes"][0]
    id_viaje = _viaje(entorno, chofer=mio)
    http = entorno["http"]
    cabecera = _token(mio, ["chofer"])
    listado = http.get(RUTA, params={"fecha": "2026-10-30"}, headers=cabecera)
    detalle = http.get(f"{RUTA}/{id_viaje}", headers=cabecera)
    assert listado.status_code == 200
    assert detalle.status_code == 200
    assert set(listado.json()[0]) <= set(esquemas["Viaje"]["properties"])
    assert set(detalle.json()) == set(esquemas["OperacionAsignada"]["properties"])
    assert set(detalle.json()["cantidades"]) == set(
        esquemas["OperacionAsignada"]["properties"]["cantidades"]["properties"]
    )
