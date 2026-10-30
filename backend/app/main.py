"""Punto de entrada de la API Vanfull (FastAPI)."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.core.cors import opciones_cors
from app.core.errors import registrar_manejadores
from app.routers import (
    ausencias,
    auth,
    chat,
    chofer,
    deuda,
    ejecucion_viajes,
    gps,
    health,
    pagos,
    perfil,
    reservas,
    servicios,
    viajes,
)
from app.routers.checkout import registrar_checkout_si_habilitado
from app.routers.mercadopago import registrar_si_habilitado

settings = get_settings()

app = FastAPI(
    title="Vanfull API",
    version="0.1.0",
    description="Backend de gestión de viajes en micro para Vanfull. La IA (AG-01) opera vía tools; "
    "el backend gobierna reglas de negocio, cupos, permisos y pagos.",
)

# CORS: Flutter Web consume esta API desde otro origen (GitHub Pages en la demo). Sin credenciales
# del navegador: el token viaja en `Authorization`, no en cookies.
app.add_middleware(
    CORSMiddleware,
    **opciones_cors(settings),
    allow_methods=["*"],
    allow_headers=["*"],
)

# Todo error sale con la forma del contrato: {"error": {"codigo", "mensaje", "detalles"}}.
registrar_manejadores(app)

app.include_router(health.router, prefix=settings.api_prefix)
app.include_router(gps.router, prefix=settings.api_prefix)
app.include_router(auth.router, prefix=settings.api_prefix)
app.include_router(ausencias.router, prefix=settings.api_prefix)
app.include_router(perfil.router, prefix=settings.api_prefix)
app.include_router(deuda.router, prefix=settings.api_prefix)
app.include_router(servicios.router, prefix=settings.api_prefix)
app.include_router(reservas.router, prefix=settings.api_prefix)
app.include_router(pagos.router, prefix=settings.api_prefix)
app.include_router(viajes.router, prefix=settings.api_prefix)
app.include_router(chofer.router, prefix=settings.api_prefix)
app.include_router(chat.router, prefix=settings.api_prefix)
app.include_router(ejecucion_viajes.router, prefix=settings.api_prefix)
registrar_si_habilitado(app, settings)
registrar_checkout_si_habilitado(app, settings)


@app.get("/")
def root():
    return {"service": "vanfull-api", "status": "ok", "docs": "/docs"}
