"""Endpoint del asistente AG-01 (CU-011). Router fino: el rol y la delegación, nada más."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import UsuarioActual, requiere_rol
from app.schemas.chat import ChatRequest, ChatResponse
from app.services import agente as servicio

router = APIRouter(tags=["chatbot"])


# Sin exclude_none: `tool_usada` es `nullable` en el contrato y va como null si no se usó ninguna.
@router.post("/chat", response_model=ChatResponse)
async def conversar(
    datos: ChatRequest,
    usuario: UsuarioActual = Depends(requiere_rol("pasajero")),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.responder(db, usuario, datos)
