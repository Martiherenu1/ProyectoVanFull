"""Consulta de reservas propias (CU-010): GET /api/pasajeros/me/reservas y /api/reservas/{id}."""

import asyncio
from pathlib import Path

import pytest
import yaml

from app.core.security import crear_token
from tests._bd import base_migrada, cliente_api, consultar, ejecutar_sql

LISTA = "/api/pasajeros/me/reservas"
CONTRATO = Path(__file__).resolve().parents[1] / "openapi" / "openapi.yaml"


def _uno(base: str, sql: str, *args):
    return asyncio.run(consultar(base, sql, *args))[0][0]


def _persona(base: str, dni: str, *, pasajero: bool = True) -> int:
    id_persona = _uno(
        base,
        "INSERT INTO persona (nombre, apellido, dni) VALUES ('N', 'A', $1) RETURNING id_persona",
        dni,
    )
    if pasajero:
        asyncio.run(ejecutar_sql(base, "INSERT INTO pasajero (id_persona) VALUES ($1)", id_persona))
    return id_persona


def _con(id_persona: int, roles: list[str]) -> dict[str, str]:
    return {"Authorization": f"Bearer {crear_token(id_persona, id_persona, roles)}"}


@pytest.fixture(scope="module")
def entorno():
    with base_migrada() as base:
        servicio = _uno(
            base,
            "INSERT INTO servicio (tipo_servicio) VALUES ('UNIVERSITARIO') RETURNING id_servicio",
        )
        recorrido = _uno(base, "INSERT INTO recorrido DEFAULT VALUES RETURNING id_recorrido")
        parada = _uno(
            base, "INSERT INTO parada (nombre_descripcion) VALUES ('P') RETURNING id_parada"
        )
        asyncio.run(
            ejecutar_sql(
                base,
                "INSERT INTO parada_recorrido (id_recorrido, orden, id_parada) VALUES ($1, 1, $2)",
                recorrido,
                parada,
            )
        )
        cliente = _uno(
            base,
            "INSERT INTO cliente (naturaleza_cliente) VALUES ('INDIVIDUAL') RETURNING id_cliente",
        )
        contratacion = _uno(
            base,
            "INSERT INTO contratacion (id_cliente, id_servicio) VALUES ($1, $2) "
            "RETURNING id_contratacion",
            cliente,
            servicio,
        )

        def viaje(fecha: str, horario: str, sentido: str = "IDA") -> int:
            return _uno(
                base,
                "INSERT INTO viaje (id_servicio, id_recorrido, fecha, horario, sentido) "
                "VALUES ($1, $2, $3::text::date, $4::text::time, $5) RETURNING id_viaje",
                servicio,
                recorrido,
                fecha,
                horario,
                sentido,
            )

        def reserva(pasajero: int, id_viaje: int, estado: str) -> int:
            return _uno(
                base,
                "INSERT INTO reserva (id_pasajero, id_viaje, id_recorrido, orden_parada, "
                "id_contratacion_directa, estado) VALUES ($1, $2, $3, 1, $4, $5) "
                "RETURNING id_reserva",
                pasajero,
                id_viaje,
                recorrido,
                contratacion,
                estado,
            )

        ana, beto, sin_reservas, chofer = (
            _persona(base, "1"),
            _persona(base, "2"),
            _persona(base, "3"),
            _persona(base, "4", pasajero=False),
        )
        v_corto = viaje("2026-10-30", "07:30")
        v_futuro = viaje("2026-11-02", "09:00")
        v_tarde = viaje("2026-10-30", "18:00", "VUELTA")
        r = {
            "ana_consolidada": reserva(ana, v_corto, "consolidada"),
            "ana_provisional": reserva(ana, v_futuro, "provisional"),
            "ana_cancelada": reserva(ana, v_tarde, "cancelada"),
            "beto": reserva(beto, v_corto, "consolidada"),
        }
        with cliente_api(base) as http:
            yield {
                "base": base,
                "http": http,
                "ana": ana,
                "beto": beto,
                "sin_reservas": sin_reservas,
                "chofer": chofer,
                "reservas": r,
            }


# --- Lista ---------------------------------------------------------------------------------


def test_lista_todas_las_reservas_propias_con_su_estado(entorno):
    respuesta = entorno["http"].get(LISTA, headers=_con(entorno["ana"], ["pasajero"]))
    assert respuesta.status_code == 200
    por_id = {r["id_reserva"]: r for r in respuesta.json()}
    r = entorno["reservas"]
    assert set(por_id) == {r["ana_consolidada"], r["ana_provisional"], r["ana_cancelada"]}
    assert por_id[r["ana_consolidada"]]["estado"] == "consolidada"
    assert por_id[r["ana_provisional"]]["estado"] == "provisional"
    # Una cancelada sigue siendo suya: CU-010 pide el estado de cada reserva.
    assert por_id[r["ana_cancelada"]]["estado"] == "cancelada"


def test_la_lista_no_incluye_reservas_de_otros(entorno):
    respuesta = entorno["http"].get(LISTA, headers=_con(entorno["ana"], ["pasajero"]))
    assert {r["id_pasajero"] for r in respuesta.json()} == {entorno["ana"]}
    assert entorno["reservas"]["beto"] not in {r["id_reserva"] for r in respuesta.json()}


def test_la_lista_va_de_la_mas_reciente_a_la_mas_antigua(entorno):
    r = entorno["reservas"]
    respuesta = entorno["http"].get(LISTA, headers=_con(entorno["ana"], ["pasajero"]))
    # 2026-11-02 09:00, luego 2026-10-30 18:00, luego 2026-10-30 07:30.
    assert [x["id_reserva"] for x in respuesta.json()] == [
        r["ana_provisional"],
        r["ana_cancelada"],
        r["ana_consolidada"],
    ]


def test_sin_reservas_la_lista_es_vacia(entorno):
    """A1 de CU-010: el sistema informa que no hay reservas; el cliente lo traduce de una lista vacía."""
    respuesta = entorno["http"].get(LISTA, headers=_con(entorno["sin_reservas"], ["pasajero"]))
    assert respuesta.status_code == 200
    assert respuesta.json() == []


# --- Detalle -------------------------------------------------------------------------------


def test_el_detalle_de_una_reserva_propia(entorno):
    id_reserva = entorno["reservas"]["ana_provisional"]
    respuesta = entorno["http"].get(
        f"/api/reservas/{id_reserva}", headers=_con(entorno["ana"], ["pasajero"])
    )
    assert respuesta.status_code == 200
    cuerpo = respuesta.json()
    assert cuerpo["id_reserva"] == id_reserva
    assert cuerpo["id_pasajero"] == entorno["ana"]
    assert cuerpo["orden_parada"] == 1
    assert cuerpo["estado"] == "provisional"


def test_una_reserva_ajena_responde_igual_que_una_que_no_existe(entorno):
    """404 en los dos casos y con el mismo cuerpo: no se puede averiguar qué reservas existen."""
    http, ana = entorno["http"], _con(entorno["ana"], ["pasajero"])
    ajena = http.get(f"/api/reservas/{entorno['reservas']['beto']}", headers=ana)
    inexistente = http.get("/api/reservas/999999", headers=ana)
    assert ajena.status_code == inexistente.status_code == 404
    assert ajena.json() == inexistente.json()
    assert ajena.json()["error"]["codigo"] == "RESERVA_NO_ENCONTRADA"


def test_un_id_que_no_es_numero_es_400(entorno):
    respuesta = entorno["http"].get("/api/reservas/abc", headers=_con(entorno["ana"], ["pasajero"]))
    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "VALIDACION"


# --- Acceso y contrato ---------------------------------------------------------------------


@pytest.mark.parametrize("ruta", [LISTA, "/api/reservas/1"])
def test_sin_token_es_401(entorno, ruta):
    assert entorno["http"].get(ruta).status_code == 401


@pytest.mark.parametrize("ruta", [LISTA, "/api/reservas/1"])
def test_un_rol_que_no_es_pasajero_es_403(entorno, ruta):
    respuesta = entorno["http"].get(ruta, headers=_con(entorno["chofer"], ["chofer"]))
    assert respuesta.status_code == 403
    assert respuesta.json()["error"]["codigo"] == "SIN_PERMISO"


def test_la_consulta_no_modifica_ninguna_reserva(entorno):
    """Postcondición de CU-010: solo lectura."""
    base = entorno["base"]
    sql = "SELECT id_reserva, estado, orden_parada, id_viaje FROM reserva ORDER BY id_reserva"
    antes = asyncio.run(consultar(base, sql))
    http, ana = entorno["http"], _con(entorno["ana"], ["pasajero"])
    http.get(LISTA, headers=ana)
    for id_reserva in entorno["reservas"].values():
        http.get(f"/api/reservas/{id_reserva}", headers=ana)
    assert asyncio.run(consultar(base, sql)) == antes


def test_la_respuesta_no_trae_campos_que_el_contrato_no_declara(entorno):
    declarados = set(
        yaml.safe_load(CONTRATO.read_text(encoding="utf-8"))["components"]["schemas"]["Reserva"][
            "properties"
        ]
    )
    respuesta = entorno["http"].get(LISTA, headers=_con(entorno["ana"], ["pasajero"]))
    for reserva in respuesta.json():
        assert set(reserva) == declarados
