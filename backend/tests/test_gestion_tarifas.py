"""Gestión de tarifas por el dueño (CU-031): /api/administracion/tarifas contra un PostgreSQL real."""

import asyncio

import pytest

from app.core.security import crear_token
from tests._bd import base_migrada, cliente_api, consultar

RUTA = "/api/administracion/tarifas"


def _con(*roles: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {crear_token(1, 1, list(roles))}"}


DUENO = _con("dueno")


def _alta(cliente, **datos):
    cuerpo = {"nombre": "Universitario ida", "importe": 1500.5} | datos
    return cliente.post(RUTA, json=cuerpo, headers=DUENO)


@pytest.fixture(scope="module")
def entorno():
    with base_migrada() as base, cliente_api(base) as cliente:
        yield base, cliente


def test_sin_token_es_401(entorno):
    _, cliente = entorno
    assert cliente.get(RUTA).status_code == 401
    assert cliente.post(RUTA, json={}).status_code == 401


@pytest.mark.parametrize(
    "rol", ["administrador", "pasajero", "chofer", "representante_corporativo"]
)
def test_solo_el_dueno_opera(entorno, rol):
    _, cliente = entorno
    otro = _con(rol)
    assert cliente.get(RUTA, headers=otro).status_code == 403
    assert cliente.post(RUTA, json={}, headers=otro).status_code == 403
    assert cliente.get(f"{RUTA}/1", headers=otro).status_code == 403
    assert cliente.patch(f"{RUTA}/1", json={"nombre": "X"}, headers=otro).status_code == 403


def test_alta_devuelve_la_tarifa_con_su_fecha_de_creacion(entorno):
    base, cliente = entorno
    respuesta = _alta(cliente, tipo="OCASIONAL", fecha_vigencia="2026-12-01")
    assert respuesta.status_code == 201, respuesta.text
    tarifa = respuesta.json()
    assert tarifa["nombre"] == "Universitario ida"
    assert tarifa["importe"] == 1500.5
    assert tarifa["tipo"] == "OCASIONAL"
    assert tarifa["fecha_vigencia"] == "2026-12-01"
    assert tarifa["fecha_creacion"]

    fila = asyncio.run(
        consultar(
            base, "SELECT nombre, importe FROM tarifa WHERE id_tarifa = $1", tarifa["id_tarifa"]
        )
    )[0]
    assert fila[0] == "Universitario ida"
    assert float(fila[1]) == 1500.5


def test_alta_con_solo_lo_obligatorio_omite_tipo_y_vigencia(entorno):
    _, cliente = entorno
    tarifa = _alta(cliente).json()
    assert "tipo" not in tarifa
    assert "fecha_vigencia" not in tarifa


@pytest.mark.parametrize(
    "cambio",
    [
        {"nombre": ""},
        {"nombre": "x" * 121},
        {"importe": -1},
        {"importe": 10.123},
        {"importe": "mucho"},
        {"tipo": "t" * 41},
        {"fecha_vigencia": "no-es-fecha"},
        {"descuento": 15},
    ],
)
def test_alta_invalida_es_400(entorno, cambio):
    _, cliente = entorno
    respuesta = _alta(cliente, **cambio)
    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "VALIDACION"


def test_alta_sin_nombre_o_sin_importe_es_400(entorno):
    _, cliente = entorno
    assert cliente.post(RUTA, json={"importe": 10}, headers=DUENO).status_code == 400
    assert cliente.post(RUTA, json={"nombre": "A"}, headers=DUENO).status_code == 400


def test_importe_cero_es_valido(entorno):
    _, cliente = entorno
    assert _alta(cliente, importe=0).status_code == 201


def test_lista_y_detalle(entorno):
    _, cliente = entorno
    creada = _alta(cliente, nombre="Laboral vuelta").json()
    lista = cliente.get(RUTA, headers=DUENO).json()
    assert lista["total"] == len(lista["items"])
    assert creada["id_tarifa"] in [t["id_tarifa"] for t in lista["items"]]
    detalle = cliente.get(f"{RUTA}/{creada['id_tarifa']}", headers=DUENO)
    assert detalle.status_code == 200
    assert detalle.json() == creada


def test_tarifa_inexistente_es_404(entorno):
    _, cliente = entorno
    for respuesta in (
        cliente.get(f"{RUTA}/999999", headers=DUENO),
        cliente.patch(f"{RUTA}/999999", json={"nombre": "X"}, headers=DUENO),
    ):
        assert respuesta.status_code == 404
        assert respuesta.json()["error"]["codigo"] == "TARIFA_NO_ENCONTRADA"
    assert cliente.get(f"{RUTA}/0", headers=DUENO).status_code == 400


def test_modificar_aplica_solo_lo_enviado(entorno):
    _, cliente = entorno
    creada = _alta(cliente, tipo="OCASIONAL", fecha_vigencia="2026-12-01").json()
    url = f"{RUTA}/{creada['id_tarifa']}"

    respuesta = cliente.patch(url, json={"importe": 2000}, headers=DUENO)
    assert respuesta.status_code == 200, respuesta.text
    cambiada = respuesta.json()
    assert cambiada["importe"] == 2000
    assert cambiada["nombre"] == creada["nombre"]
    assert cambiada["tipo"] == "OCASIONAL"
    assert cambiada["fecha_creacion"] == creada["fecha_creacion"]


def test_modificar_permite_vaciar_tipo_y_vigencia_pero_no_nombre_ni_importe(entorno):
    _, cliente = entorno
    creada = _alta(cliente, tipo="OCASIONAL", fecha_vigencia="2026-12-01").json()
    url = f"{RUTA}/{creada['id_tarifa']}"

    vaciada = cliente.patch(url, json={"tipo": None, "fecha_vigencia": None}, headers=DUENO)
    assert vaciada.status_code == 200
    assert "tipo" not in vaciada.json() and "fecha_vigencia" not in vaciada.json()

    assert cliente.patch(url, json={"nombre": None}, headers=DUENO).status_code == 400
    assert cliente.patch(url, json={"importe": None}, headers=DUENO).status_code == 400
    assert cliente.patch(url, json={}, headers=DUENO).status_code == 400
    assert cliente.patch(url, json={"importe": -5}, headers=DUENO).status_code == 400
    assert cliente.patch(url, json={"id_tarifa": 1}, headers=DUENO).status_code == 400
    # Nada de lo rechazado cambió la tarifa.
    assert cliente.get(url, headers=DUENO).json()["nombre"] == creada["nombre"]


def test_modificar_una_tarifa_no_toca_las_contrataciones(entorno):
    """A2 / RN-012: la contratación conserva su importe acordado; no se recalcula nada."""
    base, cliente = entorno
    tarifa = _alta(cliente, importe=1000).json()
    id_servicio = asyncio.run(
        consultar(
            base,
            "INSERT INTO servicio (tipo_servicio) VALUES ('UNIVERSITARIO') RETURNING id_servicio",
        )
    )[0][0]
    id_cliente = asyncio.run(
        consultar(
            base,
            "INSERT INTO cliente (naturaleza_cliente) VALUES ('INDIVIDUAL') RETURNING id_cliente",
        )
    )[0][0]
    id_contratacion = asyncio.run(
        consultar(
            base,
            "INSERT INTO contratacion (id_cliente, id_servicio, id_tarifa, importe_acordado) "
            "VALUES ($1, $2, $3, 1000) RETURNING id_contratacion",
            id_cliente,
            id_servicio,
            tarifa["id_tarifa"],
        )
    )[0][0]

    respuesta = cliente.patch(
        f"{RUTA}/{tarifa['id_tarifa']}", json={"importe": 5000}, headers=DUENO
    )
    assert respuesta.status_code == 200

    acordado = asyncio.run(
        consultar(
            base,
            "SELECT importe_acordado FROM contratacion WHERE id_contratacion = $1",
            id_contratacion,
        )
    )[0][0]
    assert float(acordado) == 1000
