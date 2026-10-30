"""Webhook candidato D3. Sin ruta registrada por defecto, ni creación de cobros."""

import time
from collections.abc import AsyncGenerator

import httpx
from fastapi import APIRouter, Depends, FastAPI, Header, Query, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.database import get_db
from app.integrations.mercadopago import ClienteMercadoPagoPruebas
from app.schemas.mercadopago import NotificacionMP
from app.services.mercadopago_sandbox import exigir_habilitado, procesar_webhook

router = APIRouter(prefix="/webhooks", tags=["integraciones"])


async def proveedor_mp(
    ajustes: Settings = Depends(get_settings),
) -> AsyncGenerator[ClienteMercadoPagoPruebas]:
    async with httpx.AsyncClient(follow_redirects=False) as cliente:
        yield ClienteMercadoPagoPruebas(cliente, ajustes.mercadopago_access_token)


def reloj_mp() -> float:
    return time.time()


@router.post("/mercadopago", response_class=Response, status_code=200)
async def recibir(
    datos: NotificacionMP,
    data_id: str = Query(default="", alias="data.id", max_length=64),
    request_id: str = Header(default="", alias="x-request-id", max_length=128),
    firma: str = Header(default="", alias="x-signature", max_length=256),
    db: AsyncSession = Depends(get_db),
    proveedor: ClienteMercadoPagoPruebas = Depends(proveedor_mp),
    ajustes: Settings = Depends(get_settings),
    ahora: float = Depends(reloj_mp),
):
    await procesar_webhook(
        db,
        datos=datos,
        data_id=data_id,
        request_id=request_id,
        firma=firma,
        ahora=ahora,
        proveedor=proveedor,
        ajustes=ajustes,
    )
    return Response(status_code=200)


def registrar_si_habilitado(app: FastAPI, ajustes: Settings) -> None:
    if ajustes.mercadopago_sandbox_enabled:
        exigir_habilitado(ajustes)
        app.include_router(router, prefix=ajustes.api_prefix)
