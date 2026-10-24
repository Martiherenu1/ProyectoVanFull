"""Configuración central de la app. Lee variables de entorno / .env (pydantic-settings)."""

from functools import lru_cache

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy.engine import make_url


def normalizar_database_url(url: str) -> str:
    """Acepta la cadena de Neon tal como la da el panel y la deja en la forma de SQLAlchemy.

    Neon entrega `postgresql://…?sslmode=require&channel_binding=require`. SQLAlchemy le pasa los
    parámetros de la URL a `asyncpg.connect()`, que no conoce `sslmode` ni `channel_binding`: el
    equivalente es `ssl`. El seed hace la traducción inversa (`db/seed/cargar.py`).
    """
    partes = make_url(url)
    if partes.drivername in ("postgres", "postgresql"):
        partes = partes.set(drivername="postgresql+asyncpg")
    if partes.drivername != "postgresql+asyncpg":
        return url
    parametros = dict(partes.query)
    if "sslmode" in parametros:
        parametros.setdefault("ssl", parametros.pop("sslmode"))
    parametros.pop("channel_binding", None)
    return partes.set(query=parametros).render_as_string(hide_password=False)


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # App
    env: str = "development"
    api_prefix: str = "/api"

    # Orígenes de Flutter Web que pueden llamar a la API, separados por comas
    # (en la demo, https://martiherenu1.github.io). Vacío en desarrollo: localhost en cualquier puerto.
    cors_origins: str = ""

    # Base de datos
    database_url: str = "postgresql+asyncpg://vanfull:vanfull@db:5432/vanfull"

    @field_validator("database_url")
    @classmethod
    def _database_url_para_asyncpg(cls, valor: str) -> str:
        return normalizar_database_url(valor)

    # Agente AG-01 (OpenRouter)
    openrouter_api_key: str = ""
    openrouter_model_primary: str = "minimax/minimax-m3:free"
    openrouter_model_fallback: str = "nvidia/nemotron-3-super-120b-a12b:free"

    # Integraciones (entorno de pruebas)
    mercadopago_access_token: str = ""
    google_maps_api_key: str = ""
    whatsapp_token: str = ""
    whatsapp_phone_number_id: str = ""

    # Auth (RF-045)
    jwt_secret: str = "cambiar-en-produccion"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60


@lru_cache
def get_settings() -> Settings:
    return Settings()
