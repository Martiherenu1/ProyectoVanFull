"""Candidato de ampliación CU-014: solo pasajero propio y feature flag explícito."""

from fastapi import APIRouter, Depends, FastAPI, Response
from fastapi.responses import HTMLResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.database import get_db
from app.core.security import UsuarioActual, requiere_rol
from app.integrations.checkout import ClienteCheckoutPruebas
from app.routers.mercadopago import proveedor_mp
from app.schemas.checkout import CheckoutOut, IniciarCheckout
from app.schemas.pagos import Pago
from app.services.checkout import consultar_pago_propio, exigir_checkout, iniciar_checkout

router = APIRouter(prefix="/pagos", tags=["pagos"])


@router.post("/mercadopago/checkout", response_model=CheckoutOut)
async def iniciar(
    datos: IniciarCheckout,
    respuesta: Response,
    usuario: UsuarioActual = Depends(requiere_rol("pasajero")),
    db: AsyncSession = Depends(get_db),
    proveedor: ClienteCheckoutPruebas = Depends(proveedor_mp),
    ajustes: Settings = Depends(get_settings),
):
    resultado = await iniciar_checkout(db, usuario, datos, proveedor, ajustes)
    if resultado.estado_checkout != "LISTO" and resultado.pago.estado == "PENDIENTE":
        respuesta.status_code = 202
    return resultado


@router.get("/mercadopago/retorno", response_class=HTMLResponse)
async def retorno():
    # No interpreta query params ni escribe: approved en la URL no es acreditación.
    return HTMLResponse(
        "<!doctype html><html lang='es'><meta charset='utf-8'>"
        "<title>Volver a VanFull</title><h1>Regresaste de Mercado Pago</h1>"
        "<p>Este retorno no confirma tu pago. Volvé a la ventana de VanFull y pulsá Consultar estado.</p></html>"
    )


@router.get("/{id_pago}", response_model=Pago)
async def consultar(
    id_pago: int,
    usuario: UsuarioActual = Depends(requiere_rol("pasajero")),
    db: AsyncSession = Depends(get_db),
):
    return await consultar_pago_propio(db, usuario, id_pago)


def registrar_checkout_si_habilitado(app: FastAPI, ajustes: Settings):
    if ajustes.mercadopago_checkout_enabled:
        exigir_checkout(ajustes)
        app.include_router(router, prefix=ajustes.api_prefix)
