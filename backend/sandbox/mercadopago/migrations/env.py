"""Alembic CU-036 optativo: valida destino y permiso ANTES de abrir conexión."""

import asyncio

from alembic import context
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy.pool import NullPool

import app.models  # noqa: F401
from app.core.config import exigir_destino_mp_local, get_settings
from app.core.database import Base

ajustes = get_settings()
exigir_destino_mp_local(ajustes.env, ajustes.database_url)
if context.get_x_argument(as_dictionary=True).get("autorizar_cu036") != "SI":
    raise RuntimeError("Falta autorización explícita -x autorizar_cu036=SI; sin conexión a DB.")


def solo_candidato_mp(objeto, nombre, tipo, reflejado, comparado):
    return tipo != "table" or nombre in {"pago_mercadopago", "checkout_mercadopago"}


def ejecutar(conexion=None):
    opciones = {
        "target_metadata": Base.metadata,
        "version_table": "alembic_version_mercadopago",
        "include_object": solo_candidato_mp,
        "compare_type": True,
    }
    if conexion is None:
        context.configure(url=ajustes.database_url, literal_binds=True, **opciones)
    else:
        context.configure(connection=conexion, **opciones)
    with context.begin_transaction():
        context.run_migrations()


async def online():
    motor = create_async_engine(ajustes.database_url, poolclass=NullPool, echo=False)
    try:
        async with motor.connect() as conexion:
            await conexion.run_sync(ejecutar)
    finally:
        await motor.dispose()


if context.is_offline_mode():
    ejecutar()
else:
    asyncio.run(online())
