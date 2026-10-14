"""Contraseñas, tokens y permisos por rol (`app/core/security.py`). No necesita base de datos."""

from datetime import UTC, datetime, timedelta

import jwt
import pytest
from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient

from app.core.config import get_settings
from app.core.errors import ApiError, registrar_manejadores
from app.core.security import (
    UsuarioActual,
    crear_token,
    decodificar_token,
    hash_contrasena,
    requiere_rol,
    usuario_actual,
    verificar_contrasena,
)

# Contraseña inventada para las pruebas; no es de ninguna cuenta real.
CONTRASENA = "contrasena-de-prueba-123"


# --- Contraseñas ---------------------------------------------------------------------------


def test_el_hash_no_es_la_contrasena_y_se_verifica():
    hash_ = hash_contrasena(CONTRASENA)
    assert hash_ != CONTRASENA
    assert CONTRASENA not in hash_
    assert verificar_contrasena(CONTRASENA, hash_)


def test_una_contrasena_incorrecta_no_verifica():
    assert not verificar_contrasena("otra", hash_contrasena(CONTRASENA))


def test_dos_hashes_de_la_misma_contrasena_son_distintos():
    """Cada hash lleva su sal."""
    assert hash_contrasena(CONTRASENA) != hash_contrasena(CONTRASENA)


def test_bcrypt_no_trunca_en_silencio_las_contrasenas_largas():
    larga = "a" * 73
    with pytest.raises(ValueError):
        hash_contrasena(larga)
    assert not verificar_contrasena(larga, hash_contrasena(CONTRASENA))


def test_un_hash_mal_formado_no_verifica_ni_rompe():
    assert not verificar_contrasena(CONTRASENA, "esto-no-es-un-hash")


# --- Tokens --------------------------------------------------------------------------------


def test_el_token_lleva_cuenta_persona_y_roles():
    token = crear_token(7, 42, ["chofer", "administrador"])
    usuario = decodificar_token(token)
    assert usuario == UsuarioActual(
        id_cuenta_acceso=7, id_persona=42, roles=("chofer", "administrador")
    )


def test_un_token_adulterado_se_rechaza():
    token = crear_token(1, 1, ["pasajero"])
    with pytest.raises(ApiError) as error:
        decodificar_token(token[:-3] + "abc")
    assert error.value.status_code == 401


def test_un_token_firmado_con_otro_secreto_se_rechaza():
    falso = jwt.encode(
        {"sub": "1", "pid": 1, "roles": ["administrador"], "exp": datetime.now(UTC) + timedelta(1)},
        "otro-secreto-que-no-es-el-de-la-app-0123456789",
        algorithm="HS256",
    )
    with pytest.raises(ApiError):
        decodificar_token(falso)


def test_un_token_vencido_se_rechaza():
    ajustes = get_settings()
    vencido = jwt.encode(
        {"sub": "1", "pid": 1, "roles": [], "exp": datetime.now(UTC) - timedelta(minutes=1)},
        ajustes.jwt_secret,
        algorithm=ajustes.jwt_algorithm,
    )
    with pytest.raises(ApiError):
        decodificar_token(vencido)


def test_un_token_sin_exp_se_rechaza():
    """Un token que no vence nunca no es válido."""
    ajustes = get_settings()
    eterno = jwt.encode(
        {"sub": "1", "pid": 1, "roles": []}, ajustes.jwt_secret, algorithm=ajustes.jwt_algorithm
    )
    with pytest.raises(ApiError):
        decodificar_token(eterno)


# --- Dependencias de FastAPI ---------------------------------------------------------------


@pytest.fixture(scope="module")
def cliente():
    app = FastAPI()
    registrar_manejadores(app)

    @app.get("/privado")
    async def privado(usuario: UsuarioActual = Depends(usuario_actual)):
        return {"id_persona": usuario.id_persona}

    @app.get("/solo-administracion")
    async def solo_administracion(
        usuario: UsuarioActual = Depends(requiere_rol("administrador", "dueno")),
    ):
        return {"roles": list(usuario.roles)}

    return TestClient(app)


def _con(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_sin_token_es_401_con_el_error_del_contrato(cliente):
    respuesta = cliente.get("/privado")
    assert respuesta.status_code == 401
    assert respuesta.json()["error"]["codigo"] == "NO_AUTENTICADO"
    assert respuesta.headers["www-authenticate"] == "Bearer"


def test_con_token_valido_pasa(cliente):
    respuesta = cliente.get("/privado", headers=_con(crear_token(1, 99, ["pasajero"])))
    assert respuesta.status_code == 200
    assert respuesta.json() == {"id_persona": 99}


def test_un_rol_que_no_corresponde_es_403(cliente):
    respuesta = cliente.get("/solo-administracion", headers=_con(crear_token(1, 1, ["pasajero"])))
    assert respuesta.status_code == 403
    assert respuesta.json()["error"]["codigo"] == "SIN_PERMISO"


def test_alcanza_con_tener_uno_de_los_roles_pedidos(cliente):
    token = crear_token(1, 1, ["pasajero", "dueno"])
    respuesta = cliente.get("/solo-administracion", headers=_con(token))
    assert respuesta.status_code == 200


def test_una_ruta_inexistente_tambien_responde_con_el_error_del_contrato(cliente):
    respuesta = cliente.get("/no-existe")
    assert respuesta.status_code == 404
    assert respuesta.json()["error"]["codigo"] == "NO_ENCONTRADO"
