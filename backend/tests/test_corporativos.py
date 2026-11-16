"""Clientes corporativos (CU-023): /api/clientes-corporativos contra un PostgreSQL real."""

import asyncio
from pathlib import Path

import pytest
import yaml

from app.core.security import crear_token
from tests._bd import base_migrada, cliente_api, consultar, ejecutar_sql

RUTA = "/api/clientes-corporativos"
CONTRATO = Path(__file__).resolve().parents[1] / "openapi" / "openapi.yaml"


def _uno(base: str, sql: str, *args):
    return asyncio.run(consultar(base, sql, *args))[0][0]


def _persona(base: str, dni: str, *, pasajero: bool = False, **datos) -> int:
    id_persona = _uno(
        base,
        "INSERT INTO persona (nombre, apellido, dni, email) VALUES ($1, $2, $3, $4) "
        "RETURNING id_persona",
        datos.get("nombre", "Nombre"),
        datos.get("apellido", "Apellido"),
        dni,
        datos.get("email"),
    )
    if pasajero:
        asyncio.run(ejecutar_sql(base, "INSERT INTO pasajero (id_persona) VALUES ($1)", id_persona))
    return id_persona


def _empresa(base: str, razon_social: str, cuit: str) -> int:
    id_cliente = _uno(
        base,
        "INSERT INTO cliente (naturaleza_cliente) VALUES ('PERSONA_JURIDICA') RETURNING id_cliente",
    )
    asyncio.run(
        ejecutar_sql(
            base,
            "INSERT INTO cliente_persona_juridica (id_cliente, razon_social, cuit) "
            "VALUES ($1, $2, $3)",
            id_cliente,
            razon_social,
            cuit,
        )
    )
    asyncio.run(
        ejecutar_sql(base, "INSERT INTO cliente_corporativo (id_cliente) VALUES ($1)", id_cliente)
    )
    return id_cliente


def _con(id_persona: int, *roles: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {crear_token(id_persona, id_persona, list(roles))}"}


@pytest.fixture(scope="module")
def entorno():
    with base_migrada() as base:
        ids = {
            "admin": _persona(base, "1", nombre="Admin"),
            "ana": _persona(base, "100", pasajero=True, nombre="Ana", apellido="Gómez"),
            "beto": _persona(base, "200", pasajero=True, nombre="Beto", apellido="Pérez"),
            "rrhh": _persona(base, "300", nombre="Raquel", apellido="RRHH", email="r@acme.test"),
            "acme": _empresa(base, "Acme SA", "30-1"),
            "beta": _empresa(base, "Beta SRL", "30-2"),
        }
        # Un cliente jurídico que no es corporativo: no aparece en estas operaciones.
        ids["solo_juridica"] = _uno(
            base,
            "INSERT INTO cliente (naturaleza_cliente) VALUES ('PERSONA_JURIDICA') RETURNING id_cliente",
        )
        asyncio.run(
            ejecutar_sql(
                base,
                "INSERT INTO cliente_persona_juridica (id_cliente, razon_social, cuit) "
                "VALUES ($1, 'No Corporativa', '30-3')",
                ids["solo_juridica"],
            )
        )
        with cliente_api(base) as cliente:
            yield base, cliente, ids


@pytest.fixture
def admin(entorno):
    return _con(entorno[2]["admin"], "administrador")


@pytest.fixture(autouse=True)
def _restaurar(entorno):
    """Cada prueba parte de Acme y Beta sin contactos ni pasajeros, y sin empresas nuevas."""
    base, _, ids = entorno
    for sql in (
        "DELETE FROM contacto_corporativo",
        "DELETE FROM pasajero_corporativo",
        "DELETE FROM persona WHERE dni LIKE '9%'",
        "UPDATE cliente_persona_juridica SET razon_social = 'Acme SA', cuit = '30-1', "
        f"direccion = NULL WHERE id_cliente = {ids['acme']}",
    ):
        asyncio.run(ejecutar_sql(base, sql))
    nuevas = "SELECT id_cliente FROM cliente_persona_juridica WHERE cuit LIKE '99%'"
    for tabla in ("cliente_corporativo", "cliente_persona_juridica", "cliente"):
        asyncio.run(ejecutar_sql(base, f"DELETE FROM {tabla} WHERE id_cliente IN ({nuevas})"))


def _cuenta(base: str, sql: str, *args) -> int:
    return _uno(base, sql, *args)


# --- permisos ------------------------------------------------------------------------------


def test_sin_token_es_401(entorno):
    _, cliente, _ = entorno
    assert cliente.get(RUTA).status_code == 401


@pytest.mark.parametrize("rol", ["pasajero", "chofer", "representante_corporativo"])
def test_otros_roles_son_403_en_todas_las_operaciones(entorno, rol):
    """RN-028: el representante tampoco gestiona la empresa por acá (sus permisos son de CU-033)."""
    _, cliente, ids = entorno
    h = _con(ids["ana"], rol)
    acme = f"{RUTA}/{ids['acme']}"
    for respuesta in (
        cliente.get(RUTA, headers=h),
        cliente.post(RUTA, json={"razon_social": "X", "cuit": "991"}, headers=h),
        cliente.get(acme, headers=h),
        cliente.patch(acme, json={"razon_social": "Z"}, headers=h),
        cliente.post(f"{acme}/contactos", json={"id_persona": ids["rrhh"]}, headers=h),
        cliente.delete(f"{acme}/contactos/{ids['rrhh']}", headers=h),
        cliente.post(f"{acme}/pasajeros", json={"id_pasajero": ids["ana"]}, headers=h),
        cliente.delete(f"{acme}/pasajeros/{ids['ana']}", headers=h),
    ):
        assert respuesta.status_code == 403
        assert respuesta.json()["error"]["codigo"] == "SIN_PERMISO"


def test_el_dueno_tambien_puede(entorno):
    _, cliente, ids = entorno
    assert cliente.get(RUTA, headers=_con(ids["admin"], "dueno")).status_code == 200


# --- empresa -------------------------------------------------------------------------------


def test_lista_solo_corporativos_ordenados_por_razon_social(entorno, admin):
    _, cliente, ids = entorno
    cuerpo = cliente.get(RUTA, headers=admin).json()
    assert cuerpo["total"] == 2
    assert [e["id_cliente"] for e in cuerpo["items"]] == [ids["acme"], ids["beta"]]
    assert cuerpo["items"][0] == {
        "id_cliente": ids["acme"],
        "razon_social": "Acme SA",
        "cuit": "30-1",
        "estado": "activo",
    }


def test_busca_por_razon_social_o_cuit(entorno, admin):
    _, cliente, ids = entorno
    for q, esperado in (("beta", ids["beta"]), ("30-1", ids["acme"]), ("ACME", ids["acme"])):
        items = cliente.get(RUTA, params={"q": q}, headers=admin).json()["items"]
        assert [e["id_cliente"] for e in items] == [esperado]
    assert cliente.get(RUTA, params={"q": "%"}, headers=admin).json()["total"] == 0


def test_pagina(entorno, admin):
    _, cliente, ids = entorno
    cuerpo = cliente.get(RUTA, params={"limite": 1, "desplazamiento": 1}, headers=admin).json()
    assert (cuerpo["total"], [e["id_cliente"] for e in cuerpo["items"]]) == (2, [ids["beta"]])


def test_registra_una_empresa_en_las_tres_tablas(entorno, admin):
    base, cliente, _ = entorno
    respuesta = cliente.post(
        RUTA,
        json={"razon_social": " Nueva SA ", "cuit": "99-1", "direccion": "Av. 1"},
        headers=admin,
    )
    assert respuesta.status_code == 201
    cuerpo = respuesta.json()
    assert cuerpo["razon_social"] == "Nueva SA"
    assert cuerpo["estado"] == "activo"
    id_cliente = cuerpo["id_cliente"]
    assert (
        _uno(base, "SELECT naturaleza_cliente FROM cliente WHERE id_cliente = $1", id_cliente)
        == "PERSONA_JURIDICA"
    )
    assert (
        _cuenta(base, "SELECT count(*) FROM cliente_corporativo WHERE id_cliente = $1", id_cliente)
        == 1
    )


def test_cuit_repetido_es_409_y_no_deja_cliente_huerfano(entorno, admin):
    base, cliente, _ = entorno
    antes = _cuenta(base, "SELECT count(*) FROM cliente")
    for cuit in ("30-1", "30-3"):  # de un corporativo y de una jurídica que no lo es
        respuesta = cliente.post(RUTA, json={"razon_social": "Copia", "cuit": cuit}, headers=admin)
        assert respuesta.status_code == 409
        assert respuesta.json()["error"]["codigo"] == "CUIT_DUPLICADO"
    assert _cuenta(base, "SELECT count(*) FROM cliente") == antes


@pytest.mark.parametrize(
    "cuerpo",
    [
        {"cuit": "99-2"},
        {"razon_social": "X"},
        {"razon_social": "  ", "cuit": "99-2"},
        {"razon_social": "X", "cuit": "99-2", "condiciones_comerciales": "30 días"},
        {"razon_social": "X", "cuit": "99-2", "estado": "inactivo"},
    ],
)
def test_alta_invalida_es_400(entorno, admin, cuerpo):
    _, cliente, _ = entorno
    respuesta = cliente.post(RUTA, json=cuerpo, headers=admin)
    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "VALIDACION"


def test_detalle_de_una_empresa_sin_contactos_ni_pasajeros(entorno, admin):
    _, cliente, ids = entorno
    cuerpo = cliente.get(f"{RUTA}/{ids['beta']}", headers=admin).json()
    assert cuerpo["razon_social"] == "Beta SRL"
    assert (cuerpo["contactos"], cuerpo["pasajeros"]) == ([], [])


@pytest.mark.parametrize("clave", ["solo_juridica", None])
def test_lo_que_no_es_cliente_corporativo_es_404(entorno, admin, clave):
    """Una persona jurídica que no es corporativa, o un cliente que no existe."""
    _, cliente, ids = entorno
    id_cliente = ids[clave] if clave else 999999
    respuesta = cliente.get(f"{RUTA}/{id_cliente}", headers=admin)
    assert respuesta.status_code == 404
    assert respuesta.json()["error"]["codigo"] == "CLIENTE_CORPORATIVO_NO_ENCONTRADO"


def test_modifica_los_datos_de_la_empresa(entorno, admin):
    base, cliente, ids = entorno
    respuesta = cliente.patch(
        f"{RUTA}/{ids['acme']}",
        json={"razon_social": "Acme SAU", "direccion": "Calle 2"},
        headers=admin,
    )
    assert respuesta.status_code == 200
    assert (respuesta.json()["razon_social"], respuesta.json()["cuit"]) == ("Acme SAU", "30-1")
    assert (
        _uno(
            base,
            "SELECT direccion FROM cliente_persona_juridica WHERE id_cliente = $1",
            ids["acme"],
        )
        == "Calle 2"
    )


def test_cambiar_al_cuit_de_otra_es_409_y_no_modifica_nada(entorno, admin):
    base, cliente, ids = entorno
    respuesta = cliente.patch(
        f"{RUTA}/{ids['acme']}", json={"razon_social": "Otra", "cuit": "30-2"}, headers=admin
    )
    assert respuesta.status_code == 409
    assert respuesta.json()["error"]["codigo"] == "CUIT_DUPLICADO"
    assert (
        _uno(
            base,
            "SELECT razon_social FROM cliente_persona_juridica WHERE id_cliente = $1",
            ids["acme"],
        )
        == "Acme SA"
    )


@pytest.mark.parametrize("cuerpo", [{}, {"estado": "inactivo"}, {"cuit": None}])
def test_modificacion_invalida_es_400(entorno, admin, cuerpo):
    _, cliente, ids = entorno
    assert cliente.patch(f"{RUTA}/{ids['acme']}", json=cuerpo, headers=admin).status_code == 400


# --- contactos -----------------------------------------------------------------------------


def test_agrega_una_persona_existente_como_contacto(entorno, admin):
    _, cliente, ids = entorno
    respuesta = cliente.post(
        f"{RUTA}/{ids['acme']}/contactos",
        json={"id_persona": ids["rrhh"], "cargo": "RRHH", "es_representante": True},
        headers=admin,
    )
    assert respuesta.status_code == 201
    assert respuesta.json() == {
        "id_persona": ids["rrhh"],
        "nombre": "Raquel",
        "apellido": "RRHH",
        "dni": "300",
        "email": "r@acme.test",
        "cargo": "RRHH",
        "es_representante": True,
    }
    detalle = cliente.get(f"{RUTA}/{ids['acme']}", headers=admin).json()
    assert [c["id_persona"] for c in detalle["contactos"]] == [ids["rrhh"]]


def test_agrega_una_persona_nueva_como_contacto_sin_cuenta_ni_rol(entorno, admin):
    base, cliente, ids = entorno
    respuesta = cliente.post(
        f"{RUTA}/{ids['acme']}/contactos",
        json={"nombre": "Nuevo", "apellido": "Contacto", "dni": "900", "telefono": "555"},
        headers=admin,
    )
    assert respuesta.status_code == 201
    cuerpo = respuesta.json()
    assert (cuerpo["dni"], cuerpo["es_representante"]) == ("900", False)
    assert (
        _cuenta(
            base, "SELECT count(*) FROM cuenta_acceso WHERE id_persona = $1", cuerpo["id_persona"]
        )
        == 0
    )


def test_una_misma_persona_puede_ser_contacto_de_dos_empresas(entorno, admin):
    _, cliente, ids = entorno
    for empresa in ("acme", "beta"):
        respuesta = cliente.post(
            f"{RUTA}/{ids[empresa]}/contactos", json={"id_persona": ids["rrhh"]}, headers=admin
        )
        assert respuesta.status_code == 201


def test_contacto_repetido_es_409(entorno, admin):
    _, cliente, ids = entorno
    url = f"{RUTA}/{ids['acme']}/contactos"
    assert cliente.post(url, json={"id_persona": ids["rrhh"]}, headers=admin).status_code == 201
    segunda = cliente.post(url, json={"id_persona": ids["rrhh"]}, headers=admin)
    assert segunda.status_code == 409
    assert segunda.json()["error"]["codigo"] == "CONTACTO_YA_REGISTRADO"


def test_persona_nueva_con_dni_existente_es_409_y_no_registra_nada(entorno, admin):
    base, cliente, ids = entorno
    respuesta = cliente.post(
        f"{RUTA}/{ids['acme']}/contactos",
        json={"nombre": "Otra", "apellido": "Raquel", "dni": "300"},
        headers=admin,
    )
    assert respuesta.status_code == 409
    assert respuesta.json()["error"]["codigo"] == "DNI_DUPLICADO"
    assert _cuenta(base, "SELECT count(*) FROM contacto_corporativo") == 0


@pytest.mark.parametrize(
    "cuerpo",
    [
        {},
        {"nombre": "X", "apellido": "Y"},
        {"id_persona": 1, "nombre": "X"},
        {"nombre": "X", "apellido": "Y", "dni": "901", "categoria": "laboral"},
    ],
)
def test_contacto_invalido_es_400(entorno, admin, cuerpo):
    _, cliente, ids = entorno
    respuesta = cliente.post(f"{RUTA}/{ids['acme']}/contactos", json=cuerpo, headers=admin)
    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "VALIDACION"


def test_contacto_de_persona_inexistente_o_en_empresa_inexistente_es_404(entorno, admin):
    _, cliente, ids = entorno
    sin_persona = cliente.post(
        f"{RUTA}/{ids['acme']}/contactos", json={"id_persona": 999999}, headers=admin
    )
    assert sin_persona.json()["error"]["codigo"] == "PERSONA_NO_ENCONTRADA"
    sin_empresa = cliente.post(
        f"{RUTA}/999999/contactos", json={"id_persona": ids["rrhh"]}, headers=admin
    )
    assert sin_empresa.json()["error"]["codigo"] == "CLIENTE_CORPORATIVO_NO_ENCONTRADO"


def test_quitar_un_contacto_conserva_a_la_persona(entorno, admin):
    base, cliente, ids = entorno
    url = f"{RUTA}/{ids['acme']}/contactos"
    cliente.post(url, json={"id_persona": ids["rrhh"]}, headers=admin)
    assert cliente.delete(f"{url}/{ids['rrhh']}", headers=admin).status_code == 204
    assert _cuenta(base, "SELECT count(*) FROM persona WHERE id_persona = $1", ids["rrhh"]) == 1
    otra_vez = cliente.delete(f"{url}/{ids['rrhh']}", headers=admin)
    assert otra_vez.status_code == 404
    assert otra_vez.json()["error"]["codigo"] == "CONTACTO_NO_ENCONTRADO"


# --- pasajeros asociados (A2) --------------------------------------------------------------


def test_asocia_un_pasajero_y_aparece_en_el_detalle(entorno, admin):
    _, cliente, ids = entorno
    respuesta = cliente.post(
        f"{RUTA}/{ids['acme']}/pasajeros", json={"id_pasajero": ids["ana"]}, headers=admin
    )
    assert respuesta.status_code == 201
    assert respuesta.json() == {
        "id_persona": ids["ana"],
        "nombre": "Ana",
        "apellido": "Gómez",
        "dni": "100",
        "estado_habilitacion": "habilitado",
        "estado_vinculo": "activo",
    }
    detalle = cliente.get(f"{RUTA}/{ids['acme']}", headers=admin).json()
    assert [p["id_persona"] for p in detalle["pasajeros"]] == [ids["ana"]]


def test_asociar_dos_veces_es_409(entorno, admin):
    _, cliente, ids = entorno
    url = f"{RUTA}/{ids['acme']}/pasajeros"
    cliente.post(url, json={"id_pasajero": ids["ana"]}, headers=admin)
    segunda = cliente.post(url, json={"id_pasajero": ids["ana"]}, headers=admin)
    assert segunda.status_code == 409
    assert segunda.json()["error"]["codigo"] == "PASAJERO_YA_ASOCIADO"


def test_una_persona_que_no_es_pasajero_no_se_asocia(entorno, admin):
    _, cliente, ids = entorno
    respuesta = cliente.post(
        f"{RUTA}/{ids['acme']}/pasajeros", json={"id_pasajero": ids["rrhh"]}, headers=admin
    )
    assert respuesta.status_code == 404
    assert respuesta.json()["error"]["codigo"] == "PASAJERO_NO_ENCONTRADO"


def test_desasociar_conserva_al_pasajero(entorno, admin):
    base, cliente, ids = entorno
    url = f"{RUTA}/{ids['acme']}/pasajeros"
    cliente.post(url, json={"id_pasajero": ids["beto"]}, headers=admin)
    assert cliente.delete(f"{url}/{ids['beto']}", headers=admin).status_code == 204
    assert _cuenta(base, "SELECT count(*) FROM pasajero WHERE id_persona = $1", ids["beto"]) == 1
    otra_vez = cliente.delete(f"{url}/{ids['beto']}", headers=admin)
    assert otra_vez.status_code == 404
    assert otra_vez.json()["error"]["codigo"] == "VINCULO_NO_ENCONTRADO"


def test_las_respuestas_no_traen_campos_que_el_contrato_no_declara(entorno, admin):
    _, cliente, ids = entorno
    esquemas = yaml.safe_load(CONTRATO.read_text(encoding="utf-8"))["components"]["schemas"]
    cliente.post(f"{RUTA}/{ids['acme']}/contactos", json={"id_persona": ids["rrhh"]}, headers=admin)
    cliente.post(f"{RUTA}/{ids['acme']}/pasajeros", json={"id_pasajero": ids["ana"]}, headers=admin)
    detalle = cliente.get(f"{RUTA}/{ids['acme']}", headers=admin).json()
    base_props = set(esquemas["ClienteCorporativo"]["properties"])
    assert set(detalle) <= base_props | {"contactos", "pasajeros"}
    assert set(detalle["contactos"][0]) <= set(esquemas["ContactoCorporativo"]["properties"])
    assert set(detalle["pasajeros"][0]) <= set(esquemas["PasajeroCorporativo"]["properties"])
