"""Configuración central de la app. Lee variables de entorno / .env (pydantic-settings)."""
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # App
    env: str = "development"
    api_prefix: str = "/api"

    # Base de datos
    database_url: str = "postgresql+asyncpg://vanfull:vanfull@db:5432/vanfull"

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
