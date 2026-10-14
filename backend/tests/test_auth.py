"""/auth/login y /auth/logout (CU-012) contra un PostgreSQL real, con el esquema migrado.

Las cuentas y contraseñas de acá son inventadas para la prueba y viven en una base temporal.
"""

import asyncio

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.database import get_db
from app.core.security import decodificar_token, hash_contrasena
from app.main import app
from tests._bd import base_migrada, consultar, ejecutar_sql, url_sqlalchemy

CONTRASENA = "contrasena-de-prueba-123"
LOGIN = "/api/auth/login"
LOGOUT = "/api/auth/logout"


def _crear_cuenta(base: str, dni: str, identificador: str, roles: list[str], estado="activo"):
    """Inserta persona, cuenta y roles. Devuelve (id_persona, id_cuenta_acceso)."""
    id_persona = asyncio.run(
        consultar(
            base,
            "INSERT INTO persona (nombre, apellido, dni) VALUES ('Prueba', 'Prueba', $1) "
            "RETURNING id_persona",
            dni,
        )
    )[0][0]
    id_cuenta = asyncio.run(
        consultar(
            base,
            "INSERT INTO cuenta_acceso (id_persona, identificador_acceso, hash_contrasena, estado) "
            "VALUES ($1, $2, $3, $4) RETURNING id_cuenta_acceso",
            id_persona,
            identificador,
            hash_contrasena(CONTRASENA),
            estado,
        )
    )[0][0]
    for rol in roles:
        asyncio.run(
            ejecutar_sql(
                base,
                "INSERT INTO cuenta_rol (id_cuenta_acceso, id_rol_acceso) "
                "SELECT $1, id_rol_acceso FROM rol_acceso WHERE rol = $2",
                id_cuenta,
                rol,
            )
        )
    return id_persona, id_cuenta


@pytest.fixture(scope="module")
def sesion():
    """La app apuntando a una base temporal migrada y con tres cuentas de prueba."""
    with base_migrada() as base:
        cuentas = {
            "pasajero": _crear_cuenta(base, "1", "pasajero@prueba.test", ["pasajero"]),
            "doble_rol": _crear_cuenta(base, "2", "doble@prueba.test", ["chofer", "administrador"]),
            "inactiva": _crear_cuenta(
                base, "3", "inactiva@prueba.test", ["pasajero"], "suspendida"
            ),
        }
        # NullPool: cada pedido abre su conexión, así no queda atada al loop de TestClient.
        motor = create_async_engine(url_sqlalchemy(base), poolclass=NullPool)
        fabrica = async_sessionmaker(motor, expire_on_commit=False)

        async def _get_db():
            async with fabrica() as db:
                yield db

        app.dependency_overrides[get_db] = _get_db
        with TestClient(app) as cliente:
            yield cliente, cuentas
        app.dependency_overrides.pop(get_db, None)


def _login(cliente, identificador, password=CONTRASENA):
    return cliente.post(LOGIN, json={"identificador_acceso": identificador, "password": password})


def test_login_correcto_devuelve_token_y_roles(sesion):
    cliente, cuentas = sesion
    respuesta = _login(cliente, "pasajero@prueba.test")
    assert respuesta.status_code == 200
    cuerpo = respuesta.json()
    assert set(cuerpo) == {"access_token", "token_type", "roles"}
    assert cuerpo["token_type"] == "bearer"
    assert cuerpo["roles"] == ["pasajero"]

    id_persona, id_cuenta = cuentas["pasajero"]
    usuario = decodificar_token(cuerpo["access_token"])
    assert (usuario.id_persona, usuario.id_cuenta_acceso) == (id_persona, id_cuenta)


def test_una_cuenta_con_varios_roles_los_devuelve_todos(sesion):
    cliente, _ = sesion
    assert _login(cliente, "doble@prueba.test").json()["roles"] == ["chofer", "administrador"]


def test_contrasena_incorrecta_es_401(sesion):
    cliente, _ = sesion
    respuesta = _login(cliente, "pasajero@prueba.test", "no-es-la-contrasena")
    assert respuesta.status_code == 401
    assert respuesta.json()["error"]["codigo"] == "CREDENCIALES_INVALIDAS"


def test_no_se_distingue_cuenta_inexistente_de_contrasena_incorrecta(sesion):
    """Misma respuesta en los tres rechazos: el cliente no puede averiguar qué cuentas existen."""
    cliente, _ = sesion
    rechazos = [
        _login(cliente, "nadie@prueba.test"),
        _login(cliente, "pasajero@prueba.test", "no-es-la-contrasena"),
        _login(cliente, "inactiva@prueba.test"),
    ]
    assert {r.status_code for r in rechazos} == {401}
    assert len({r.text for r in rechazos}) == 1


def test_una_cuenta_que_no_esta_activa_no_entra(sesion):
    """Lectura conservadora del DEFAULT del schema. PENDIENTE DE VALIDACIÓN con la v1.3 (#4)."""
    cliente, _ = sesion
    assert _login(cliente, "inactiva@prueba.test").status_code == 401


def test_un_cuerpo_incompleto_es_400_y_no_repite_lo_enviado(sesion):
    cliente, _ = sesion
    respuesta = cliente.post(LOGIN, json={"identificador_acceso": "pasajero@prueba.test"})
    assert respuesta.status_code == 400
    error = respuesta.json()["error"]
    assert error["codigo"] == "VALIDACION"
    assert error["detalles"]["errores"][0]["campo"] == "password"


def test_la_contrasena_no_aparece_en_ninguna_respuesta(sesion):
    cliente, _ = sesion
    for respuesta in (
        _login(cliente, "pasajero@prueba.test"),
        _login(cliente, "pasajero@prueba.test", CONTRASENA + "x"),
        cliente.post(LOGIN, json={"password": CONTRASENA}),
    ):
        assert CONTRASENA not in respuesta.text


def test_logout_con_token_es_204_sin_cuerpo(sesion):
    cliente, _ = sesion
    token = _login(cliente, "pasajero@prueba.test").json()["access_token"]
    respuesta = cliente.post(LOGOUT, headers={"Authorization": f"Bearer {token}"})
    assert respuesta.status_code == 204
    assert respuesta.content == b""


def test_logout_sin_token_es_401(sesion):
    cliente, _ = sesion
    respuesta = cliente.post(LOGOUT)
    assert respuesta.status_code == 401
    assert respuesta.json()["error"]["codigo"] == "NO_AUTENTICADO"
