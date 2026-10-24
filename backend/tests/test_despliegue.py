"""Configuración del despliegue (Issue #116): CORS por variable y la cadena de conexión de Neon.

No necesita base de datos.
"""

import pytest
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.testclient import TestClient

from app.core.config import Settings, normalizar_database_url
from app.core.cors import opciones_cors
from app.main import app

PAGES = "https://martiherenu1.github.io"


def _ajustes(**valores) -> Settings:
    # `_env_file=None`: la prueba no depende del `.env` de quien la corre.
    return Settings(_env_file=None, **valores)


def _cliente(ajustes: Settings) -> TestClient:
    prueba = FastAPI()
    prueba.add_middleware(
        CORSMiddleware, **opciones_cors(ajustes), allow_methods=["*"], allow_headers=["*"]
    )

    @prueba.get("/api/health")
    def _health():
        return {"status": "ok"}

    return TestClient(prueba)


def _preflight(cliente: TestClient, origen: str):
    return cliente.options(
        "/api/health",
        headers={
            "Origin": origen,
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "authorization,content-type",
        },
    )


# --- CORS ----------------------------------------------------------------------------------


def test_en_produccion_se_permite_el_origen_de_pages():
    cliente = _cliente(_ajustes(env="production", cors_origins=PAGES))
    respuesta = _preflight(cliente, PAGES)
    assert respuesta.status_code == 200
    assert respuesta.headers["access-control-allow-origin"] == PAGES


@pytest.mark.parametrize("origen", ["https://otro.github.io", "http://localhost:5000"])
def test_en_produccion_se_rechaza_cualquier_otro_origen(origen):
    cliente = _cliente(_ajustes(env="production", cors_origins=PAGES))
    respuesta = _preflight(cliente, origen)
    assert respuesta.status_code == 400
    assert "access-control-allow-origin" not in respuesta.headers


def test_la_barra_final_y_los_espacios_no_cambian_el_origen():
    ajustes = _ajustes(env="production", cors_origins=f" {PAGES}/ , http://localhost:5000")
    assert opciones_cors(ajustes) == {"allow_origins": [PAGES, "http://localhost:5000"]}


def test_en_produccion_sin_cors_origins_la_api_no_arranca():
    with pytest.raises(RuntimeError, match="CORS_ORIGINS"):
        opciones_cors(_ajustes(env="production"))


def test_no_se_acepta_el_comodin():
    with pytest.raises(RuntimeError, match=r"\*"):
        opciones_cors(_ajustes(env="production", cors_origins="*"))


@pytest.mark.parametrize("origen", ["http://localhost:53124", "http://127.0.0.1:8080"])
def test_en_desarrollo_sin_variable_se_permite_localhost(origen):
    respuesta = _preflight(_cliente(_ajustes(env="development")), origen)
    assert respuesta.headers["access-control-allow-origin"] == origen


def test_en_desarrollo_sin_variable_no_se_permite_un_sitio_externo():
    respuesta = _preflight(_cliente(_ajustes(env="development")), "http://localhost.evil.com")
    assert "access-control-allow-origin" not in respuesta.headers


def test_la_api_no_pide_credenciales_al_navegador():
    """El token va en `Authorization`; sin cookies no hace falta `allow_credentials`."""
    respuesta = TestClient(app).get("/", headers={"Origin": "http://localhost:53124"})
    assert "access-control-allow-credentials" not in respuesta.headers


# --- La cadena de conexión de Neon ---------------------------------------------------------


def test_la_cadena_de_neon_queda_lista_para_asyncpg():
    neon = "postgresql://usuario:clave@ep-algo-123.us-east-2.aws.neon.tech/vanfull?sslmode=require&channel_binding=require"
    assert normalizar_database_url(neon) == (
        "postgresql+asyncpg://usuario:clave@ep-algo-123.us-east-2.aws.neon.tech/vanfull?ssl=require"
    )


def test_el_esquema_postgres_corto_tambien_se_acepta():
    assert normalizar_database_url("postgres://u:p@host/db").startswith("postgresql+asyncpg://")


def test_la_url_local_no_cambia():
    local = "postgresql+asyncpg://vanfull:vanfull@db:5432/vanfull"
    assert normalizar_database_url(local) == local


def test_settings_normaliza_database_url_al_leerla():
    ajustes = _ajustes(database_url="postgresql://u:p@ep-x.neon.tech/db?sslmode=require")
    assert ajustes.database_url == "postgresql+asyncpg://u:p@ep-x.neon.tech/db?ssl=require"
