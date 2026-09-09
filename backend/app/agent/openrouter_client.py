"""Cliente de OpenRouter para AG-01, con modelo principal + fallback.

Encapsula la llamada al gateway. Si el modelo principal falla (error de proveedor / indisponibilidad),
reintenta con el fallback; si tampoco responde, se informa indisponibilidad y se ofrece derivar a humano.
"""
import httpx

from app.core.config import get_settings

settings = get_settings()

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"


class OpenRouterError(RuntimeError):
    """No se obtuvo respuesta válida de ningún modelo (principal ni fallback)."""


async def chat_completion(messages: list[dict], tools: list[dict] | None = None) -> dict:
    """Llama a OpenRouter probando primero el modelo principal y luego el fallback.

    Devuelve el JSON crudo de la respuesta del modelo que haya respondido.
    Lanza OpenRouterError si ninguno responde.
    """
    headers = {"Authorization": f"Bearer {settings.openrouter_api_key}"}
    modelos = [settings.openrouter_model_primary, settings.openrouter_model_fallback]

    async with httpx.AsyncClient(timeout=30) as client:
        for modelo in modelos:
            payload: dict = {"model": modelo, "messages": messages}
            if tools:
                payload["tools"] = tools
            try:
                resp = await client.post(OPENROUTER_URL, headers=headers, json=payload)
                if resp.status_code == 200:
                    return resp.json()
            except httpx.HTTPError:
                continue  # probar el siguiente modelo

    raise OpenRouterError("Ningún modelo (principal ni fallback) respondió correctamente.")
