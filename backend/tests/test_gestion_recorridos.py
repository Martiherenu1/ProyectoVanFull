"""Gestión de recorridos y paradas (CU-019): /api/administracion contra un PostgreSQL real."""

import asyncio
import itertools

import pytest

from app.core.security import crear_token
from tests._bd import base_migrada, cliente_api, consultar

PARADAS = "/api/administracion/paradas"
RECORRIDOS = "/api/administracion/recorridos"
_dni = itertools.count(70000)


def _con(*roles: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {crear_token(1, 1, list(roles))}"}


ADMIN = _con("administrador")
DUENO = _con("dueno")


def _sql(base, sql, *args):
    return asyncio.run(consultar(base, sql, *args))


@pytest.fixture(scope="module")
def entorno():
    with base_migrada() as base, cliente_api(base) as cliente:
        yield base, cliente


def _parada(cliente, nombre="Plaza", **datos):
    respuesta = cliente.post(PARADAS, json={"nombre_descripcion": nombre} | datos, headers=ADMIN)
    assert respuesta.status_code == 201, respuesta.text
    return respuesta.json()["id_parada"]


def _recorrido(cliente, ids):
    respuesta = cliente.post(RECORRIDOS, json={"id_paradas": ids}, headers=ADMIN)
    assert respuesta.status_code == 201, respuesta.text
    return respuesta.json()["id_recorrido"]


def _reemplazar(cliente, id_recorrido, ids, headers=ADMIN):
    return cliente.put(
        f"{RECORRIDOS}/{id_recorrido}/paradas", json={"id_paradas": ids}, headers=headers
    )


def _ordenes(cliente, id_recorrido):
    detalle = cliente.get(f"{RECORRIDOS}/{id_recorrido}", headers=ADMIN).json()
    return [(p["orden"], p["id_parada"]) for p in detalle["paradas"]]


# --- Permisos -------------------------------------------------------------------------------


def test_sin_token_es_401(entorno):
    _, cliente = entorno
    assert cliente.get(PARADAS).status_code == 401
    assert cliente.get(RECORRIDOS).status_code == 401


@pytest.mark.parametrize("rol", ["pasajero", "chofer", "representante_corporativo"])
def test_solo_administracion_y_dueno_operan(entorno, rol):
    _, cliente = entorno
    otro = _con(rol)
    assert cliente.get(PARADAS, headers=otro).status_code == 403
    assert cliente.post(PARADAS, json={}, headers=otro).status_code == 403
    assert cliente.patch(f"{PARADAS}/1", json={"direccion": "x"}, headers=otro).status_code == 403
    assert cliente.get(RECORRIDOS, headers=otro).status_code == 403
    assert cliente.post(RECORRIDOS, json={}, headers=otro).status_code == 403
    assert _reemplazar(cliente, 1, [1], headers=otro).status_code == 403


def test_el_dueno_tambien_opera(entorno):
    _, cliente = entorno
    assert cliente.get(PARADAS, headers=DUENO).status_code == 200
    assert cliente.get(RECORRIDOS, headers=DUENO).status_code == 200


# --- Paradas --------------------------------------------------------------------------------


def test_alta_de_parada_con_coordenadas(entorno):
    base, cliente = entorno
    respuesta = cliente.post(
        PARADAS,
        json={
            "nombre_descripcion": "Terminal",
            "direccion": "Av. Siempre Viva 742",
            "latitud": -34.603722,
            "longitud": -58.381592,
        },
        headers=ADMIN,
    )
    assert respuesta.status_code == 201, respuesta.text
    parada = respuesta.json()
    assert parada["latitud"] == -34.603722
    assert parada["longitud"] == -58.381592
    fila = _sql(
        base, "SELECT nombre_descripcion FROM parada WHERE id_parada = $1", parada["id_parada"]
    )
    assert fila[0][0] == "Terminal"


def test_alta_de_parada_solo_con_nombre_omite_el_resto(entorno):
    _, cliente = entorno
    id_parada = _parada(cliente, "Solo nombre")
    parada = cliente.get(f"{PARADAS}/{id_parada}", headers=ADMIN).json()
    assert set(parada) == {"id_parada", "nombre_descripcion"}


@pytest.mark.parametrize(
    "datos",
    [
        {"nombre_descripcion": ""},
        {"nombre_descripcion": "x" * 151},
        {"nombre_descripcion": "A", "latitud": -34.6},
        {"nombre_descripcion": "A", "longitud": -58.3},
        {"nombre_descripcion": "A", "latitud": 91, "longitud": 0},
        {"nombre_descripcion": "A", "latitud": 0, "longitud": 181},
        {"nombre_descripcion": "A", "comprometida": True},
        {},
    ],
)
def test_alta_de_parada_invalida_es_400(entorno, datos):
    _, cliente = entorno
    respuesta = cliente.post(PARADAS, json=datos, headers=ADMIN)
    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "VALIDACION"


def test_lista_detalle_y_404_de_parada(entorno):
    _, cliente = entorno
    id_parada = _parada(cliente, "Listada")
    lista = cliente.get(PARADAS, headers=ADMIN).json()
    assert lista["total"] == len(lista["items"])
    assert id_parada in [p["id_parada"] for p in lista["items"]]
    inexistente = cliente.get(f"{PARADAS}/999999", headers=ADMIN)
    assert inexistente.status_code == 404
    assert inexistente.json()["error"]["codigo"] == "PARADA_NO_ENCONTRADA"


def test_modificar_parada(entorno):
    _, cliente = entorno
    id_parada = _parada(cliente, "Vieja", direccion="Calle 1")
    url = f"{PARADAS}/{id_parada}"
    cambiada = cliente.patch(url, json={"nombre_descripcion": "Nueva"}, headers=ADMIN)
    assert cambiada.status_code == 200, cambiada.text
    assert cambiada.json()["nombre_descripcion"] == "Nueva"
    assert cambiada.json()["direccion"] == "Calle 1"

    vaciada = cliente.patch(url, json={"direccion": None}, headers=ADMIN)
    assert "direccion" not in vaciada.json()

    assert cliente.patch(url, json={}, headers=ADMIN).status_code == 400
    assert cliente.patch(url, json={"nombre_descripcion": None}, headers=ADMIN).status_code == 400
    assert (
        cliente.patch(f"{PARADAS}/999999", json={"direccion": "x"}, headers=ADMIN).status_code
        == 404
    )


def test_modificar_una_sola_coordenada_deja_la_parada_sin_cambios(entorno):
    _, cliente = entorno
    id_parada = _parada(cliente, "Coord")
    url = f"{PARADAS}/{id_parada}"
    respuesta = cliente.patch(url, json={"latitud": -34.6}, headers=ADMIN)
    assert respuesta.status_code == 400
    assert "latitud" not in cliente.get(url, headers=ADMIN).json()
    completa = cliente.patch(url, json={"latitud": -34.6, "longitud": -58.4}, headers=ADMIN)
    assert completa.status_code == 200


# --- Recorridos -----------------------------------------------------------------------------


def test_alta_de_recorrido_numera_las_paradas_desde_uno(entorno):
    _, cliente = entorno
    a, b, c = (_parada(cliente, n) for n in "ABC")
    id_recorrido = _recorrido(cliente, [b, a, c])
    assert _ordenes(cliente, id_recorrido) == [(1, b), (2, a), (3, c)]
    detalle = cliente.get(f"{RECORRIDOS}/{id_recorrido}", headers=ADMIN).json()
    assert all(p["comprometida"] is False for p in detalle["paradas"])
    assert id_recorrido in [
        r["id_recorrido"] for r in cliente.get(RECORRIDOS, headers=ADMIN).json()["items"]
    ]


@pytest.mark.parametrize(
    "cuerpo", [{"id_paradas": []}, {"id_paradas": [0]}, {"id_paradas": [-1]}, {}, {"x": 1}]
)
def test_alta_de_recorrido_invalida_es_400(entorno, cuerpo):
    _, cliente = entorno
    assert cliente.post(RECORRIDOS, json=cuerpo, headers=ADMIN).status_code == 400


def test_recorrido_con_parada_inexistente_es_404_y_no_crea_nada(entorno):
    base, cliente = entorno
    antes = _sql(base, "SELECT count(*) FROM recorrido")[0][0]
    respuesta = cliente.post(
        RECORRIDOS, json={"id_paradas": [_parada(cliente), 999999]}, headers=ADMIN
    )
    assert respuesta.status_code == 404
    assert respuesta.json()["error"]["codigo"] == "PARADA_NO_ENCONTRADA"
    assert _sql(base, "SELECT count(*) FROM recorrido")[0][0] == antes


def test_recorrido_inexistente_es_404(entorno):
    _, cliente = entorno
    assert cliente.get(f"{RECORRIDOS}/999999", headers=ADMIN).status_code == 404
    respuesta = _reemplazar(cliente, 999999, [_parada(cliente)])
    assert respuesta.status_code == 404
    assert respuesta.json()["error"]["codigo"] == "RECORRIDO_NO_ENCONTRADO"


def test_reemplazar_reordena_agrega_y_quita(entorno):
    _, cliente = entorno
    a, b, c, d = (_parada(cliente, n) for n in "ABCD")
    id_recorrido = _recorrido(cliente, [a, b, c])

    assert _reemplazar(cliente, id_recorrido, [c, a, b, d]).status_code == 200
    assert _ordenes(cliente, id_recorrido) == [(1, c), (2, a), (3, b), (4, d)]

    assert _reemplazar(cliente, id_recorrido, [a]).status_code == 200
    assert _ordenes(cliente, id_recorrido) == [(1, a)]


def test_reemplazar_con_parada_inexistente_no_cambia_nada(entorno):
    _, cliente = entorno
    a, b = _parada(cliente, "A"), _parada(cliente, "B")
    id_recorrido = _recorrido(cliente, [a, b])
    assert _reemplazar(cliente, id_recorrido, [b, 999999]).status_code == 404
    assert _ordenes(cliente, id_recorrido) == [(1, a), (2, b)]


# --- RN-021: paradas comprometidas ----------------------------------------------------------


def _comprometer(base, id_recorrido, orden):
    _sql(
        base,
        "UPDATE parada_recorrido SET comprometida = TRUE WHERE id_recorrido = $1 AND orden = $2 "
        "RETURNING 1",
        id_recorrido,
        orden,
    )


def test_una_modificacion_que_conserva_las_comprometidas_es_valida(entorno):
    base, cliente = entorno
    a, b, c, d = (_parada(cliente, n) for n in "ABCD")
    id_recorrido = _recorrido(cliente, [a, b, c])
    _comprometer(base, id_recorrido, 2)

    # B sigue en el orden 2; A y C (no comprometidas) cambian y se suma D.
    assert _reemplazar(cliente, id_recorrido, [c, b, a, d]).status_code == 200
    detalle = cliente.get(f"{RECORRIDOS}/{id_recorrido}", headers=ADMIN).json()
    assert [(p["orden"], p["id_parada"], p["comprometida"]) for p in detalle["paradas"]] == [
        (1, c, False),
        (2, b, True),
        (3, a, False),
        (4, d, False),
    ]


@pytest.mark.parametrize(
    "nueva",
    [
        ("A", "C", "B"),  # la comprometida (B) cambia de orden
        ("A", "D", "C"),  # la comprometida (B) es reemplazada por otra parada
        ("A",),  # la comprometida queda fuera del recorrido
    ],
)
def test_una_modificacion_incompatible_con_una_comprometida_es_409(entorno, nueva):
    base, cliente = entorno
    ids = {n: _parada(cliente, n) for n in "ABCD"}
    id_recorrido = _recorrido(cliente, [ids["A"], ids["B"], ids["C"]])
    _comprometer(base, id_recorrido, 2)

    respuesta = _reemplazar(cliente, id_recorrido, [ids[n] for n in nueva])
    assert respuesta.status_code == 409
    error = respuesta.json()["error"]
    assert error["codigo"] == "PARADA_COMPROMETIDA"
    assert error["detalles"]["ordenes"] == [2]
    # A2: el recorrido quedó como estaba.
    assert _ordenes(cliente, id_recorrido) == [(1, ids["A"]), (2, ids["B"]), (3, ids["C"])]


def test_no_se_modifica_una_parada_comprometida_pero_si_las_demas(entorno):
    base, cliente = entorno
    a, b = _parada(cliente, "Libre"), _parada(cliente, "Comprometida")
    id_recorrido = _recorrido(cliente, [a, b])
    _comprometer(base, id_recorrido, 2)

    bloqueada = cliente.patch(f"{PARADAS}/{b}", json={"direccion": "Otra"}, headers=ADMIN)
    assert bloqueada.status_code == 409
    assert bloqueada.json()["error"]["codigo"] == "PARADA_COMPROMETIDA"
    assert (
        cliente.patch(f"{PARADAS}/{a}", json={"direccion": "Otra"}, headers=ADMIN).status_code
        == 200
    )


def test_la_api_no_permite_comprometer_una_parada(entorno):
    """Cómo se compromete una parada es PENDIENTE: la API solo conserva la marca."""
    _, cliente = entorno
    a = _parada(cliente, "A")
    id_recorrido = _recorrido(cliente, [a])
    detalle = cliente.get(f"{RECORRIDOS}/{id_recorrido}", headers=ADMIN).json()
    assert detalle["paradas"][0]["comprometida"] is False
    respuesta = cliente.put(
        f"{RECORRIDOS}/{id_recorrido}/paradas",
        json={"id_paradas": [a], "comprometida": True},
        headers=ADMIN,
    )
    assert respuesta.status_code == 400


# --- Reservas sobre las paradas -------------------------------------------------------------


def _reserva_en(base, id_recorrido, orden):
    """Una reserva real sobre (recorrido, orden), con el viaje y el contrato que exige el modelo."""
    n = next(_dni)
    servicio = _sql(
        base, "INSERT INTO servicio (tipo_servicio) VALUES ('UNIVERSITARIO') RETURNING id_servicio"
    )[0][0]
    vehiculo = _sql(
        base,
        "INSERT INTO vehiculo (patente, capacidad) VALUES ($1, 10) RETURNING id_vehiculo",
        f"CU{n}",
    )[0][0]
    chofer = _sql(
        base,
        "INSERT INTO persona (nombre, apellido, dni) VALUES ('C', 'H', $1) RETURNING id_persona",
        str(n),
    )[0][0]
    _sql(base, "INSERT INTO chofer (id_persona) VALUES ($1) RETURNING 1", chofer)
    pasajero = _sql(
        base,
        "INSERT INTO persona (nombre, apellido, dni) VALUES ('P', 'A', $1) RETURNING id_persona",
        str(n + 500000),
    )[0][0]
    _sql(base, "INSERT INTO pasajero (id_persona) VALUES ($1) RETURNING 1", pasajero)
    viaje = _sql(
        base,
        "INSERT INTO viaje (id_servicio, id_recorrido, id_vehiculo, id_chofer, fecha, sentido, estado) "
        "VALUES ($1, $2, $3, $4, DATE '2026-12-01', 'IDA', 'programado') RETURNING id_viaje",
        servicio,
        id_recorrido,
        vehiculo,
        chofer,
    )[0][0]
    cliente_id = _sql(
        base, "INSERT INTO cliente (naturaleza_cliente) VALUES ('INDIVIDUAL') RETURNING id_cliente"
    )[0][0]
    contrato = _sql(
        base,
        "INSERT INTO contratacion (id_cliente, id_servicio) VALUES ($1, $2) RETURNING id_contratacion",
        cliente_id,
        servicio,
    )[0][0]
    _sql(
        base,
        "INSERT INTO reserva (id_pasajero, id_viaje, id_recorrido, orden_parada, "
        "id_contratacion_directa, estado) VALUES ($1, $2, $3, $4, $5, 'consolidada') RETURNING 1",
        pasajero,
        viaje,
        id_recorrido,
        orden,
        contrato,
    )


def test_no_se_quita_ni_se_cambia_una_parada_con_reservas(entorno):
    base, cliente = entorno
    a, b, c, d = (_parada(cliente, n) for n in "ABCD")
    id_recorrido = _recorrido(cliente, [a, b, c])
    _reserva_en(base, id_recorrido, 2)

    quitar = _reemplazar(cliente, id_recorrido, [a, c])
    assert quitar.status_code == 409
    assert quitar.json()["error"]["codigo"] == "PARADA_CON_RESERVAS"
    assert quitar.json()["error"]["detalles"]["ordenes"] == [2]

    cambiar = _reemplazar(cliente, id_recorrido, [a, d, c])
    assert cambiar.status_code == 409
    assert cambiar.json()["error"]["codigo"] == "PARADA_CON_RESERVAS"
    assert _ordenes(cliente, id_recorrido) == [(1, a), (2, b), (3, c)]

    # Cambiar otras paradas y sumar una nueva sí se puede.
    assert _reemplazar(cliente, id_recorrido, [d, b, a, c]).status_code == 200
    assert _ordenes(cliente, id_recorrido) == [(1, d), (2, b), (3, a), (4, c)]
