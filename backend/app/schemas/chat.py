"""Entrada y salida del asistente AG-01 (CU-011). Nombres del contrato: `ChatRequest`, `ChatResponse`."""

from pydantic import BaseModel


class ChatRequest(BaseModel):
    mensaje: str
    # Sin valor, el backend abre una conversación nueva y devuelve su id en la respuesta.
    conversacion_id: str | None = None


class ChatResponse(BaseModel):
    respuesta: str
    conversacion_id: str
    # RF-032: true si el agente escaló la conversación a una persona.
    derivar_humano: bool = False
    # El contrato admite una sola: si en un mensaje se usaron varias, es la última (Issue #42).
    tool_usada: str | None = None
