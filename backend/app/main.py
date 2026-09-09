"""Punto de entrada de la API Vanfull (FastAPI)."""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.routers import health

settings = get_settings()

app = FastAPI(
    title="Vanfull API",
    version="0.1.0",
    description="Backend de gestión de viajes en micro para Vanfull. La IA (AG-01) opera vía tools; "
    "el backend gobierna reglas de negocio, cupos, permisos y pagos.",
)

# CORS: Flutter Web consume esta API. Ajustar orígenes al desplegar.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router, prefix=settings.api_prefix)


@app.get("/")
def root():
    return {"service": "vanfull-api", "status": "ok", "docs": "/docs"}
