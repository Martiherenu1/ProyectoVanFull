"""Helpers para las pruebas que necesitan un PostgreSQL real (migración, login, servicios).

Crean una base temporal con nombre único dentro del PostgreSQL de `DATABASE_URL` (necesita permiso
para crear bases) y la borran al terminar. Sin base accesible, las pruebas se saltean en local pero
**fallan en la CI** (GitHub define `CI=true`), para que una base mal configurada no pase por verde.
"""

import asyncio
import os
import subprocess
import sys
import uuid
from contextlib import contextmanager
from pathlib import Path

import asyncpg
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.engine import URL, make_url
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.config import get_settings
from app.core.database import get_db

BACKEND = Path(__file__).resolve().parents[1]


def url_de(base: str) -> URL:
    return make_url(get_settings().database_url).set(database=base)


def url_sqlalchemy(base: str) -> str:
    """URL con el driver async, para `DATABASE_URL` y para `create_async_engine`."""
    return url_de(base).render_as_string(hide_password=False)


def _dsn(base: str) -> str:
    return url_de(base).set(drivername="postgresql").render_as_string(hide_password=False)


def alembic(base: str, *args: str) -> subprocess.CompletedProcess:
    """Corre Alembic en un proceso aparte: su env.py usa asyncio.run y no puede anidarse."""
    env = {**os.environ, "DATABASE_URL": url_sqlalchemy(base)}
    return subprocess.run(
        [sys.executable, "-m", "alembic", *args],
        cwd=BACKEND,
        env=env,
        capture_output=True,
        text=True,
        timeout=120,
    )


async def _admin(sentencia: str) -> None:
    conn = await asyncpg.connect(_dsn("postgres"))
    try:
        await conn.execute(sentencia)
    finally:
        await conn.close()


async def ejecutar_sql(base: str, sql: str, *parametros) -> None:
    conn = await asyncpg.connect(_dsn(base))
    try:
        # Sin parámetros usa el protocolo simple, que admite varias sentencias (schema.sql).
        await conn.execute(sql, *parametros)
    finally:
        await conn.close()


async def conectar(base: str) -> asyncpg.Connection:
    """Una conexión directa, para retener una transacción abierta (bloqueos) en una prueba."""
    return await asyncpg.connect(_dsn(base))


async def consultar(base: str, consulta: str, *parametros) -> list[tuple]:
    conn = await asyncpg.connect(_dsn(base))
    try:
        return [tuple(fila) for fila in await conn.fetch(consulta, *parametros)]
    finally:
        await conn.close()


@contextmanager
def base_temporal():
    """Una base vacía con nombre único, que se borra al salir."""
    nombre = f"vf_test_{uuid.uuid4().hex[:10]}"
    try:
        asyncio.run(_admin(f'CREATE DATABASE "{nombre}"'))
    except (OSError, asyncpg.PostgresError) as exc:
        if os.getenv("CI"):
            raise
        pytest.skip(f"No hay un PostgreSQL accesible para la prueba: {exc}")
    try:
        yield nombre
    finally:
        asyncio.run(_admin(f'DROP DATABASE IF EXISTS "{nombre}" WITH (FORCE)'))


@contextmanager
def base_migrada():
    """Una base temporal con `alembic upgrade head` aplicado."""
    with base_temporal() as nombre:
        resultado = alembic(nombre, "upgrade", "head")
        assert resultado.returncode == 0, resultado.stderr
        yield nombre


@contextmanager
def cliente_api(base: str):
    """La app real apuntando a `base`, con un TestClient. Para pruebas de punta a punta."""
    from app.main import app  # import tardío: no hace falta para las pruebas que no usan la API

    # NullPool: cada pedido abre su propia conexión, así no queda atada al loop de TestClient.
    motor = create_async_engine(url_sqlalchemy(base), poolclass=NullPool)
    fabrica = async_sessionmaker(motor, expire_on_commit=False)

    async def _get_db():
        async with fabrica() as db:
            yield db

    app.dependency_overrides[get_db] = _get_db
    try:
        with TestClient(app) as cliente:
            yield cliente
    finally:
        app.dependency_overrides.pop(get_db, None)
