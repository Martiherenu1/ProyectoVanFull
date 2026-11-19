"""Gestión de administradores por el dueño (CU-032): /api/administradores contra un PostgreSQL real."""

import asyncio
import itertools

import pytest

from app.core.security import crear_token
from tests._bd import base_migrada, cliente_api, consultar

RUTA = "/api/administradores"
_dni = itertools.count(5000)


def _con(*roles: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {crear_token(1, 1, list(roles))}"}


DUENO = _con("dueno")


def _alta(cliente, **datos):
    numero = next(_dni)
    cuerpo = {
        "nombre": "Ada",
        "apellido": "Admin",
        "dni": str(numero),
        "identificador_acceso": f"admin{numero}@prueba.test",
        "contrasena": "clave-segura-1",
    } | datos
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
    assert cliente.post(f"{RUTA}/1/deshabilitacion", headers=otro).status_code == 403


def test_alta_crea_persona_cuenta_y_rol_y_permite_iniciar_sesion(entorno):
    base, cliente = entorno
    respuesta = _alta(cliente, email="ada@prueba.test")
    assert respuesta.status_code == 201, respuesta.text
    admin = respuesta.json()
    assert admin["estado"] == "activo"
    assert admin["email"] == "ada@prueba.test"
    assert "contrasena" not in admin and "hash_contrasena" not in admin

    roles = asyncio.run(
        consultar(
            base,
            "SELECT r.rol FROM cuenta_rol cr JOIN rol_acceso r USING (id_rol_acceso) "
            "WHERE cr.id_cuenta_acceso = $1",
            admin["id_cuenta_acceso"],
        )
    )
    assert [fila[0] for fila in roles] == ["administrador"]
    guardado = asyncio.run(
        consultar(
            base,
            "SELECT hash_contrasena FROM cuenta_acceso WHERE id_cuenta_acceso = $1",
            admin["id_cuenta_acceso"],
        )
    )[0][0]
    assert guardado != "clave-segura-1"

    login = cliente.post(
        "/api/auth/login",
        json={"identificador_acceso": admin["identificador_acceso"], "password": "clave-segura-1"},
    )
    assert login.status_code == 200, login.text
    assert login.json()["roles"] == ["administrador"]


def test_alta_con_dni_o_identificador_repetido_es_409(entorno):
    _, cliente = entorno
    primero = _alta(cliente).json()
    repetido_dni = _alta(cliente, dni=primero["dni"])
    assert repetido_dni.status_code == 409
    assert repetido_dni.json()["error"]["codigo"] == "DNI_DUPLICADO"
    repetido_id = _alta(cliente, identificador_acceso=primero["identificador_acceso"])
    assert repetido_id.status_code == 409
    assert repetido_id.json()["error"]["codigo"] == "IDENTIFICADOR_EN_USO"


@pytest.mark.parametrize(
    "cambio",
    [
        {"contrasena": "corta"},
        {"identificador_acceso": "ab"},
        {"nombre": ""},
        {"rol": "dueno"},
    ],
)
def test_alta_invalida_es_400(entorno, cambio):
    _, cliente = entorno
    assert _alta(cliente, **cambio).status_code == 400


def test_lista_y_detalle(entorno):
    _, cliente = entorno
    creado = _alta(cliente, apellido="Zeta").json()
    lista = cliente.get(RUTA, headers=DUENO).json()
    assert lista["total"] == len(lista["items"])
    assert creado["id_cuenta_acceso"] in [a["id_cuenta_acceso"] for a in lista["items"]]
    detalle = cliente.get(f"{RUTA}/{creado['id_cuenta_acceso']}", headers=DUENO)
    assert detalle.status_code == 200
    assert detalle.json() == creado


def test_no_gestiona_cuentas_que_no_son_de_administrador(entorno):
    base, cliente = entorno
    # Una cuenta de pasajero y una de dueño-administrador: ninguna es "administrable".
    filas = asyncio.run(
        consultar(
            base,
            "WITH p AS (INSERT INTO persona (nombre, apellido, dni) VALUES "
            "('Pasa', 'Jero', '9001'), ('Due', 'Ño', '9002') RETURNING id_persona, dni), "
            "c AS (INSERT INTO cuenta_acceso (id_persona, identificador_acceso, hash_contrasena) "
            "SELECT id_persona, 'cuenta' || dni, 'x' FROM p RETURNING id_cuenta_acceso, "
            "identificador_acceso) SELECT id_cuenta_acceso, identificador_acceso FROM c",
        )
    )
    ids = {identificador: id_cuenta for id_cuenta, identificador in filas}
    asyncio.run(
        consultar(
            base,
            "INSERT INTO cuenta_rol (id_cuenta_acceso, id_rol_acceso) "
            "SELECT $1::bigint, id_rol_acceso FROM rol_acceso WHERE rol = 'pasajero' "
            "UNION ALL SELECT $2::bigint, id_rol_acceso FROM rol_acceso "
            "WHERE rol IN ('administrador', 'dueno') RETURNING 1",
            ids["cuenta9001"],
            ids["cuenta9002"],
        )
    )
    listados = [a["id_cuenta_acceso"] for a in cliente.get(RUTA, headers=DUENO).json()["items"]]
    for id_cuenta in ids.values():
        assert id_cuenta not in listados
        respuesta = cliente.get(f"{RUTA}/{id_cuenta}", headers=DUENO)
        assert respuesta.status_code == 404
        assert respuesta.json()["error"]["codigo"] == "ADMINISTRADOR_NO_ENCONTRADO"
        assert cliente.post(f"{RUTA}/{id_cuenta}/deshabilitacion", headers=DUENO).status_code == 404


def test_modificar_datos_e_identificador(entorno):
    _, cliente = entorno
    creado = _alta(cliente).json()
    url = f"{RUTA}/{creado['id_cuenta_acceso']}"
    respuesta = cliente.patch(
        url,
        json={"apellido": "Nuevo", "identificador_acceso": "nuevo-id@prueba.test"},
        headers=DUENO,
    )
    assert respuesta.status_code == 200, respuesta.text
    assert respuesta.json()["apellido"] == "Nuevo"
    assert respuesta.json()["identificador_acceso"] == "nuevo-id@prueba.test"

    assert cliente.patch(url, json={}, headers=DUENO).status_code == 400
    assert cliente.patch(url, json={"nombre": None}, headers=DUENO).status_code == 400
    assert cliente.patch(url, json={"estado": "activo"}, headers=DUENO).status_code == 400

    otro = _alta(cliente).json()
    choque = cliente.patch(url, json={"dni": otro["dni"]}, headers=DUENO)
    assert choque.status_code == 409
    assert choque.json()["error"]["codigo"] == "DNI_DUPLICADO"
    # Todo o nada: el choque no dejó cambios a medias.
    assert cliente.get(url, headers=DUENO).json()["dni"] == creado["dni"]


def test_deshabilitar_impide_iniciar_sesion_y_no_se_repite(entorno):
    _, cliente = entorno
    creado = _alta(cliente).json()
    url = f"{RUTA}/{creado['id_cuenta_acceso']}/deshabilitacion"
    respuesta = cliente.post(url, headers=DUENO)
    assert respuesta.status_code == 200
    assert respuesta.json()["estado"] == "deshabilitado"

    login = cliente.post(
        "/api/auth/login",
        json={"identificador_acceso": creado["identificador_acceso"], "password": "clave-segura-1"},
    )
    assert login.status_code == 401

    otra_vez = cliente.post(url, headers=DUENO)
    assert otra_vez.status_code == 409
    assert otra_vez.json()["error"]["codigo"] == "ADMINISTRADOR_YA_DESHABILITADO"
