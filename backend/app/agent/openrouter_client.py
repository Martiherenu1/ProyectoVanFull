"""Cliente de OpenRouter para AG-01, con modelo principal + fallback.

Encapsula la llamada al gateway. Si el modelo principal falla (error de proveedor / indisponibilidad),
reintenta con el fallback; si tampoco responde, se informa indisponibilidad y se ofrece derivar a humano.

Toda falla se registra en el log con el modelo y el motivo (07-IA-y-Agentes §8), nunca con la clave:
es lo único que permite saber en Render por qué el asistente derivó.
"""

import logging
import time

import httpx

from app.core.config import get_settings

settings = get_settings()
logger = logging.getLogger(__name__)

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
# Tope de cada llamada a un modelo. El tope del mensaje entero lo pone quien llama (`limite`).
TIMEOUT_POR_LLAMADA = 30.0
# Del cuerpo de un error se guarda el principio: alcanza para el motivo y no llena el log.
_MAX_LOG = 300


class OpenRouterError(RuntimeError):
    """No se obtuvo respuesta válida de ningún modelo (principal ni fallback)."""


def _tiene_mensaje(cuerpo: object) -> bool:
    # OpenRouter puede contestar 200 con un `error` en vez de `choices` (falla del proveedor).
    try:
        return isinstance(cuerpo["choices"][0]["message"], dict)  # type: ignore[index]
    except (KeyError, IndexError, TypeError):
        return False


async def chat_completion(
    messages: list[dict], tools: list[dict] | None = None, limite: float | None = None
) -> dict:
    """Llama a OpenRouter probando primero el modelo principal y luego el fallback.

    `limite` es un instante de `time.monotonic()`: pasado ese momento no se prueba ningún modelo
    más. Devuelve el JSON crudo de la respuesta del modelo que haya respondido.
    Lanza OpenRouterError si ninguno responde.
    """
    if not settings.openrouter_api_key:
        logger.warning("AG-01: falta OPENROUTER_API_KEY, no se llama a ningún modelo")
        raise OpenRouterError("Falta OPENROUTER_API_KEY.")

    headers = {"Authorization": f"Bearer {settings.openrouter_api_key}"}
    modelos = [settings.openrouter_model_primary, settings.openrouter_model_fallback]

    async with httpx.AsyncClient() as client:
        for modelo in modelos:
            espera = TIMEOUT_POR_LLAMADA
            if limite is not None:
                espera = min(espera, limite - time.monotonic())
            if espera <= 0:
                logger.warning("AG-01: se agotó el tiempo del mensaje antes de probar %s", modelo)
                break

            payload: dict = {"model": modelo, "messages": messages}
            if tools:
                payload["tools"] = tools
            try:
                resp = await client.post(
                    OPENROUTER_URL, headers=headers, json=payload, timeout=espera
                )
            except httpx.HTTPError as exc:
                logger.warning("AG-01: %s no respondió (%s)", modelo, type(exc).__name__)
                continue  # probar el siguiente modelo
            if resp.status_code != 200:
                logger.warning(
                    "AG-01: %s respondió %s: %s", modelo, resp.status_code, resp.text[:_MAX_LOG]
                )
                continue
            try:
                cuerpo = resp.json()
            except ValueError:
                logger.warning("AG-01: %s respondió 200 sin JSON: %s", modelo, resp.text[:_MAX_LOG])
                continue
            if not _tiene_mensaje(cuerpo):
                logger.warning(
                    "AG-01: %s respondió 200 sin mensaje: %s", modelo, str(cuerpo)[:_MAX_LOG]
                )
                continue
            return cuerpo

    raise OpenRouterError("Ningún modelo (principal ni fallback) respondió correctamente.")
