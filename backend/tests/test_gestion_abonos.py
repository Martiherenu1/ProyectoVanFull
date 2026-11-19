"""Gestión de abonos mensuales (CU-028): /api/administracion/abonos contra un PostgreSQL real."""

import asyncio
import itertools

import pytest

from app.core.security import crear_token
from tests._bd import base_migrada, cliente_api, consultar

ABONOS = "/api/administracion/abonos"
_n = itertools.count(95000)


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


def _servicio(base, tipo="LABORAL"):
    return _sql(
        base,
        "INSERT INTO servicio (tipo_servicio) VALUES ($1) RETURNING id_servicio",
        tipo,
    )[0][0]


def _pasajero(base, estado="habilitado", con_cliente=False):
    n = next(_n)
    persona = _sql(
        base,
        "INSERT INTO persona (nombre, apellido, dni) VALUES ('Ana', 'Abono', $1) "
        "RETURNING id_persona",
        str(n),
    )[0][0]
    _sql(
        base,
        "INSERT INTO pasajero (id_persona, estado_habilitacion) VALUES ($1, $2) RETURNING 1",
        persona,
        estado,
    )
    if con_cliente:
        cli = _sql(
            base,
            "INSERT INTO cliente (naturaleza_cliente) VALUES ('INDIVIDUAL') RETURNING id_cliente",
        )[0][0]
        _sql(
            base,
            "INSERT INTO cliente_individual (id_cliente, id_persona) VALUES ($1, $2) RETURNING 1",
            cli,
            persona,
        )
        _sql(base, "INSERT INTO cuenta_corriente (id_cliente) VALUES ($1) RETURNING 1", cli)
    return persona


def _alta(cliente, pasajero, servicio, headers=ADMIN, **extra):
    cuerpo = {
        "id_pasajero": pasajero,
        "id_servicio": servicio,
        "modalidad": "IDA_VUELTA",
        "dias_semanales": "L,M,X,J,V",
    } | extra
    return cliente.post(ABONOS, json=cuerpo, headers=headers)


# --- Permisos -------------------------------------------------------------------------------


def test_sin_token_es_401(entorno):
    _, cliente = entorno
    assert cliente.get(ABONOS).status_code == 401
    assert cliente.post(ABONOS, json={}).status_code == 401


@pytest.mark.parametrize("rol", ["pasajero", "chofer", "representante_corporativo"])
def test_solo_administracion_y_dueno_operan(entorno, rol):
    _, cliente = entorno
    otro = _con(rol)
    assert cliente.get(ABONOS, headers=otro).status_code == 403
    assert cliente.post(ABONOS, json={}, headers=otro).status_code == 403
    assert cliente.get(f"{ABONOS}/1", headers=otro).status_code == 403
    assert cliente.patch(f"{ABONOS}/1", json={"modalidad": "IDA"}, headers=otro).status_code == 403
    assert cliente.post(f"{ABONOS}/1/periodos", json={}, headers=otro).status_code == 403


@pytest.mark.parametrize("headers", [ADMIN, DUENO])
def test_administrador_y_dueno_pueden(entorno, headers):
    base, cliente = entorno
    respuesta = _alta(cliente, _pasajero(base), _servicio(base), headers)
    assert respuesta.status_code == 201, respuesta.text


# --- Alta ------------------------------------------------------------------------------------


def test_alta_crea_contratacion_abono_y_primer_periodo(entorno):
    base, cliente = entorno
    pasajero, servicio = _pasajero(base, con_cliente=True), _servicio(base, "UNIVERSITARIO")
    tarifa = _sql(
        base,
        "INSERT INTO tarifa (nombre, importe) VALUES ('Mensual', 50000) RETURNING id_tarifa",
    )[0][0]

    respuesta = _alta(
        cliente,
        pasajero,
        servicio,
        modalidad="IDA",
        id_tarifa=tarifa,
        importe_acordado=45000.5,
        periodo="2026-11",
    )
    assert respuesta.status_code == 201, respuesta.text
    abono = respuesta.json()
    assert abono["estado"] == "activo"
    assert abono["modalidad"] == "IDA"
    assert abono["dias_semanales"] == "L,M,X,J,V"
    assert abono["tipo_servicio"] == "UNIVERSITARIO"
    assert abono["id_tarifa"] == tarifa
    assert abono["importe_acordado"] == 45000.5
    assert (abono["nombre"], abono["apellido"]) == ("Ana", "Abono")
    assert [(p["periodo"], p["estado"]) for p in abono["periodos"]] == [("2026-11", "vigente")]

    # La contratación quedó a nombre del cliente individual del pasajero.
    fila = _sql(
        base,
        "SELECT c.id_servicio, ci.id_persona FROM contratacion c "
        "JOIN cliente_individual ci ON ci.id_cliente = c.id_cliente WHERE c.id_contratacion = $1",
        abono["id_contratacion"],
    )
    assert fila == [(servicio, pasajero)]


def test_alta_sin_periodo_ni_tarifa(entorno):
    base, cliente = entorno
    abono = _alta(cliente, _pasajero(base), _servicio(base)).json()
    assert abono["periodos"] == []
    assert "id_tarifa" not in abono
    assert "importe_acordado" not in abono


def test_alta_crea_cliente_y_cuenta_corriente_si_faltan(entorno):
    base, cliente = entorno
    pasajero = _pasajero(base)
    assert _sql(base, "SELECT 1 FROM cliente_individual WHERE id_persona = $1", pasajero) == []

    assert _alta(cliente, pasajero, _servicio(base)).status_code == 201

    ids = _sql(base, "SELECT id_cliente FROM cliente_individual WHERE id_persona = $1", pasajero)
    assert len(ids) == 1
    assert _sql(base, "SELECT 1 FROM cuenta_corriente WHERE id_cliente = $1", ids[0][0]) == [(1,)]
    # Un segundo abono reutiliza el cliente en vez de crear otro.
    assert _alta(cliente, pasajero, _servicio(base, "UNIVERSITARIO")).status_code == 201
    assert len(_sql(base, "SELECT 1 FROM cliente_individual WHERE id_persona = $1", pasajero)) == 1


def test_solo_servicios_universitarios_y_laborales_tienen_abono(entorno):
    base, cliente = entorno
    pasajero = _pasajero(base)
    for tipo in ("CORPORATIVO", "ESPECIAL"):
        respuesta = _alta(cliente, pasajero, _servicio(base, tipo))
        assert respuesta.status_code == 409
        assert respuesta.json()["error"]["codigo"] == "SERVICIO_SIN_ABONO"
        assert respuesta.json()["error"]["detalles"] == {"tipo_servicio": tipo}


def test_alta_con_referencias_inexistentes_es_404_y_no_deja_restos(entorno):
    base, cliente = entorno
    pasajero, servicio = _pasajero(base), _servicio(base)
    antes = _sql(base, "SELECT count(*) FROM contratacion")[0][0]

    casos = {
        "PASAJERO_NO_ENCONTRADO": _alta(cliente, 987654321, servicio),
        "SERVICIO_NO_ENCONTRADO": _alta(cliente, pasajero, 987654321),
        "TARIFA_NO_ENCONTRADA": _alta(cliente, pasajero, servicio, id_tarifa=987654321),
    }
    for codigo, respuesta in casos.items():
        assert respuesta.status_code == 404, codigo
        assert respuesta.json()["error"]["codigo"] == codigo
    assert _sql(base, "SELECT count(*) FROM contratacion")[0][0] == antes
    # Y el pasajero no quedó convertido en cliente por un alta que falló.
    assert _sql(base, "SELECT 1 FROM cliente_individual WHERE id_persona = $1", pasajero) == []


def test_pasajero_de_baja_no_puede_contratar(entorno):
    base, cliente = entorno
    respuesta = _alta(cliente, _pasajero(base, "baja"), _servicio(base))
    assert respuesta.status_code == 409
    assert respuesta.json()["error"]["codigo"] == "PASAJERO_DADO_DE_BAJA"


@pytest.mark.parametrize(
    "extra",
    [
        {"modalidad": "DIARIA"},
        {"dias_semanales": ""},
        {"dias_semanales": "x" * 31},
        {"periodo": "2026-13"},
        {"periodo": "2026-1"},
        {"periodo": "26-11-01"},
        {"importe_acordado": -1},
        {"id_tarifa": 0},
        {"estado": "suspendido"},
    ],
)
def test_alta_con_cuerpo_invalido_es_400(entorno, extra):
    base, cliente = entorno
    respuesta = _alta(cliente, _pasajero(base), _servicio(base), **extra)
    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "VALIDACION"


# --- Consulta --------------------------------------------------------------------------------


def test_consultar_y_listar_con_filtros(entorno):
    base, cliente = entorno
    laboral, universitario = _servicio(base, "LABORAL"), _servicio(base, "UNIVERSITARIO")
    p1, p2 = _pasajero(base), _pasajero(base)
    a = _alta(cliente, p1, laboral, periodo="2026-10").json()["id_abono_mensual"]
    b = _alta(cliente, p2, universitario).json()["id_abono_mensual"]
    c = _alta(cliente, p1, universitario).json()["id_abono_mensual"]

    detalle = cliente.get(f"{ABONOS}/{a}", headers=ADMIN)
    assert detalle.status_code == 200
    assert detalle.json()["periodos"][0]["periodo"] == "2026-10"

    def ids(**params):
        r = cliente.get(ABONOS, params=params, headers=ADMIN)
        assert r.status_code == 200, r.text
        assert r.json()["total"] == len(r.json()["items"])
        return [x["id_abono_mensual"] for x in r.json()["items"]]

    assert ids(id_pasajero=p1) == [c, a]  # el más reciente primero
    assert ids(id_pasajero=p2) == [b]
    assert ids(id_pasajero=p1, tipo_servicio="UNIVERSITARIO") == [c]
    assert ids(id_pasajero=p1, estado="activo") == [c, a]
    assert ids(id_pasajero=p1, estado="inexistente") == []
    assert ids(id_pasajero=987654321) == []


def test_consulta_inexistente_o_invalida(entorno):
    _, cliente = entorno
    assert cliente.get(f"{ABONOS}/987654321", headers=ADMIN).status_code == 404
    assert cliente.get(f"{ABONOS}/0", headers=ADMIN).status_code == 400
    assert (
        cliente.get(ABONOS, params={"tipo_servicio": "ESPECIAL"}, headers=ADMIN).status_code == 400
    )
    assert cliente.get(ABONOS, params={"id_pasajero": 0}, headers=ADMIN).status_code == 400


# --- Modificación ----------------------------------------------------------------------------


def test_modificar_modalidad_y_dias(entorno):
    base, cliente = entorno
    abono = _alta(cliente, _pasajero(base), _servicio(base)).json()["id_abono_mensual"]

    respuesta = cliente.patch(
        f"{ABONOS}/{abono}", json={"modalidad": "VUELTA", "dias_semanales": "M,J"}, headers=ADMIN
    )
    assert respuesta.status_code == 200, respuesta.text
    assert respuesta.json()["modalidad"] == "VUELTA"
    assert respuesta.json()["dias_semanales"] == "M,J"
    assert respuesta.json()["estado"] == "activo"

    parcial = cliente.patch(f"{ABONOS}/{abono}", json={"modalidad": "IDA"}, headers=ADMIN).json()
    assert parcial["modalidad"] == "IDA"
    assert parcial["dias_semanales"] == "M,J"  # lo no enviado no cambia


@pytest.mark.parametrize(
    "cuerpo",
    [
        {},
        {"modalidad": None},
        {"dias_semanales": None},
        {"modalidad": "DIARIA"},
        {"estado": "suspendido"},
        {"importe_acordado": 1},
    ],
)
def test_modificar_con_cuerpo_invalido_es_400(entorno, cuerpo):
    base, cliente = entorno
    abono = _alta(cliente, _pasajero(base), _servicio(base)).json()["id_abono_mensual"]
    respuesta = cliente.patch(f"{ABONOS}/{abono}", json=cuerpo, headers=ADMIN)
    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "VALIDACION"
    assert _sql(base, "SELECT estado FROM abono_mensual WHERE id_abono_mensual = $1", abono) == [
        ("activo",)
    ]


def test_modificar_inexistente_es_404(entorno):
    _, cliente = entorno
    respuesta = cliente.patch(f"{ABONOS}/987654321", json={"modalidad": "IDA"}, headers=ADMIN)
    assert respuesta.status_code == 404
    assert respuesta.json()["error"]["codigo"] == "ABONO_NO_ENCONTRADO"


# --- Períodos --------------------------------------------------------------------------------


def test_agregar_periodos_y_no_repetirlos(entorno):
    base, cliente = entorno
    abono = _alta(cliente, _pasajero(base), _servicio(base), periodo="2026-10").json()
    id_abono = abono["id_abono_mensual"]

    nuevo = cliente.post(
        f"{ABONOS}/{id_abono}/periodos", json={"periodo": "2026-11"}, headers=ADMIN
    )
    assert nuevo.status_code == 201, nuevo.text
    # El más reciente primero, y nace vigente.
    assert [(p["periodo"], p["estado"]) for p in nuevo.json()["periodos"]] == [
        ("2026-11", "vigente"),
        ("2026-10", "vigente"),
    ]

    repetido = cliente.post(
        f"{ABONOS}/{id_abono}/periodos", json={"periodo": "2026-10"}, headers=ADMIN
    )
    assert repetido.status_code == 409
    assert repetido.json()["error"]["codigo"] == "PERIODO_DUPLICADO"
    assert repetido.json()["error"]["detalles"] == {"periodo": "2026-10"}
    assert len(cliente.get(f"{ABONOS}/{id_abono}", headers=ADMIN).json()["periodos"]) == 2


def test_el_mismo_periodo_puede_estar_en_abonos_distintos(entorno):
    base, cliente = entorno
    a = _alta(cliente, _pasajero(base), _servicio(base), periodo="2026-12").status_code
    b = _alta(cliente, _pasajero(base), _servicio(base), periodo="2026-12").status_code
    assert a == b == 201


@pytest.mark.parametrize("periodo", ["", "2026-00", "2026-13", "202611", "2026-1", "abcd-ef"])
def test_periodo_invalido_es_400(entorno, periodo):
    base, cliente = entorno
    abono = _alta(cliente, _pasajero(base), _servicio(base)).json()["id_abono_mensual"]
    respuesta = cliente.post(f"{ABONOS}/{abono}/periodos", json={"periodo": periodo}, headers=ADMIN)
    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "VALIDACION"


def test_periodo_en_abono_inexistente_es_404(entorno):
    _, cliente = entorno
    respuesta = cliente.post(
        f"{ABONOS}/987654321/periodos", json={"periodo": "2026-11"}, headers=ADMIN
    )
    assert respuesta.status_code == 404
    assert respuesta.json()["error"]["codigo"] == "ABONO_NO_ENCONTRADO"


# --- Lo que este CU no hace ------------------------------------------------------------------


def test_no_hay_baja_ni_se_tocan_reservas_ni_cupo(entorno):
    base, cliente = entorno
    abono = _alta(cliente, _pasajero(base), _servicio(base), periodo="2026-11").json()
    id_abono = abono["id_abono_mensual"]
    reservas = _sql(base, "SELECT count(*) FROM reserva")[0][0]

    assert cliente.delete(f"{ABONOS}/{id_abono}", headers=ADMIN).status_code == 405
    assert cliente.put(f"{ABONOS}/{id_abono}", json={}, headers=ADMIN).status_code == 405
    assert _sql(base, "SELECT count(*) FROM reserva")[0][0] == reservas
    assert _sql(base, "SELECT count(*) FROM periodo_abono_viaje")[0][0] == 0
