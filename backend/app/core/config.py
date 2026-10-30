"""Configuración central de la app. Lee variables de entorno / .env (pydantic-settings)."""

from functools import lru_cache
from urllib.parse import urlparse

from pydantic import Field, SecretStr, field_validator, model_validator
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


def exigir_destino_mp_local(env: str, database_url: str) -> None:
    """Barrera compartida de aplicación y migración optativa, antes de conectar."""
    url = make_url(database_url)
    if (
        env not in {"development", "test"}
        or url.host not in {"db", "localhost", "127.0.0.1", "::1"}
        or not (url.database or "").startswith(("vf_test_", "vf_sandbox_"))
    ):
        raise ValueError(
            "Mercado Pago solo admite entorno local y base aislada vf_test_/vf_sandbox_."
        )


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", extra="ignore", hide_input_in_errors=True
    )

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
    openrouter_model_primary: str = "nvidia/nemotron-3-ultra-550b-a55b:free"
    openrouter_model_fallback: str = "nvidia/nemotron-3.5-lightning:free"

    # Integraciones (entorno de pruebas)
    mercadopago_access_token: str = Field(default="", repr=False)
    # D3/D6 candidatos: nunca habilitar en producción. No existe excepción live_mode=true.
    mercadopago_sandbox_enabled: bool = False
    mercadopago_webhook_secret: SecretStr = SecretStr("")
    mercadopago_webhook_tolerance_seconds: int = Field(default=300, gt=0, le=3600)
    mercadopago_collector_id: int | None = Field(default=None, gt=0)
    mercadopago_currency: str = ""
    mercadopago_checkout_enabled: bool = False
    mercadopago_checkout_return_url: str = ""
    mercadopago_checkout_webhook_url: str = ""
    google_maps_api_key: str = ""
    whatsapp_token: str = ""
    whatsapp_phone_number_id: str = ""

    # Auth (RF-045)
    jwt_secret: str = "cambiar-en-produccion"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60

    @field_validator("mercadopago_collector_id", mode="before")
    @classmethod
    def receptor_vacio(cls, valor):
        return None if valor == "" else valor

    @model_validator(mode="after")
    def validar_mercadopago_sandbox(self):
        if self.mercadopago_checkout_enabled and not self.mercadopago_sandbox_enabled:
            raise ValueError("Checkout requiere la integración sandbox explícita.")
        if not self.mercadopago_sandbox_enabled:
            return self
        exigir_destino_mp_local(self.env, self.database_url)
        if (
            not self.mercadopago_access_token
            or not self.mercadopago_webhook_secret.get_secret_value()
            or self.mercadopago_collector_id is None
            or len(self.mercadopago_currency) != 3
            or not self.mercadopago_currency.isascii()
            or not self.mercadopago_currency.isalpha()
            or not self.mercadopago_currency.isupper()
        ):
            raise ValueError("Falta configuración de autenticidad/receptor/moneda de Mercado Pago.")
        if self.mercadopago_checkout_enabled:
            for valor in (
                self.mercadopago_checkout_return_url,
                self.mercadopago_checkout_webhook_url,
            ):
                url = urlparse(valor)
                if (
                    url.scheme != "https"
                    or not url.hostname
                    or url.username
                    or url.password
                    or url.fragment
                    or url.query
                    or url.hostname in {"localhost", "127.0.0.1", "::1"}
                ):
                    raise ValueError(
                        "Checkout requiere URLs HTTPS de retorno y webhook autorizadas, sin secretos."
                    )
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
