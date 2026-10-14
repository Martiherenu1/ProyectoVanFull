"""La migración de Alembic tiene que producir lo mismo que `backend/db/schema.sql`.

CONTRIBUTING §1.5: "alembic upgrade head sobre una base limpia, y comparar las tablas con
schema.sql". Acá se hace en dos bases temporales, comparando los catálogos de PostgreSQL
(columnas, constraints, índices y roles). Si alguien cambia schema.sql, los modelos o la migración y
no los otros, falla.

Necesita un PostgreSQL accesible con la URL de `DATABASE_URL` y permiso para crear bases. Sin base,
la prueba se saltea en local, pero **falla en la CI** (GitHub define `CI=true`), para que una base mal
configurada no pase por verde.
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
from sqlalchemy.engine import URL, make_url

from app.core.config import get_settings

BACKEND = Path(__file__).resolve().parents[1]
SCHEMA = BACKEND / "db" / "schema.sql"

# `alembic_version` es de Alembic, no del modelo: se excluye de las comparaciones.
CONSULTAS = {
    "columnas": """
        SELECT table_name, ordinal_position, column_name, data_type, character_maximum_length,
               numeric_precision, numeric_scale, is_nullable, column_default, is_identity,
               identity_generation
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name <> 'alembic_version'
        ORDER BY table_name, ordinal_position""",
    "constraints": """
        SELECT conrelid::regclass::text AS tabla, conname, contype::text AS contype,
               pg_get_constraintdef(oid) AS definicion
        FROM pg_constraint
        WHERE connamespace = 'public'::regnamespace AND conrelid::regclass::text <> 'alembic_version'
        ORDER BY 1, 2""",
    "indices": """
        SELECT tablename, indexname, indexdef FROM pg_indexes
        WHERE schemaname = 'public' AND tablename <> 'alembic_version'
        ORDER BY 1, 2""",
    "roles": "SELECT rol FROM rol_acceso ORDER BY id_rol_acceso",
}


def _url(base: str) -> URL:
    return make_url(get_settings().database_url).set(database=base)


def _dsn(base: str) -> str:
    return _url(base).set(drivername="postgresql").render_as_string(hide_password=False)


def _alembic(base: str, *args: str) -> subprocess.CompletedProcess:
    """Corre Alembic en un proceso aparte: su env.py usa asyncio.run y no puede anidarse."""
    env = {**os.environ, "DATABASE_URL": _url(base).render_as_string(hide_password=False)}
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


async def _ejecutar_sql(base: str, sql: str) -> None:
    conn = await asyncpg.connect(_dsn(base))
    try:
        await conn.execute(sql)  # sin parámetros: protocolo simple, admite varias sentencias
    finally:
        await conn.close()


async def _consultar(base: str, consulta: str) -> list[tuple]:
    conn = await asyncpg.connect(_dsn(base))
    try:
        return [tuple(fila) for fila in await conn.fetch(consulta)]
    finally:
        await conn.close()


def _foto(base: str) -> dict[str, list[tuple]]:
    return {nombre: asyncio.run(_consultar(base, q)) for nombre, q in CONSULTAS.items()}


@contextmanager
def base_temporal():
    """Crea una base vacía con nombre único y la borra al terminar."""
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


@pytest.fixture(scope="module")
def bases():
    """Una base cargada con schema.sql y otra con `alembic upgrade head`."""
    with base_temporal() as con_schema, base_temporal() as migrada:
        asyncio.run(_ejecutar_sql(con_schema, SCHEMA.read_text(encoding="utf-8")))
        resultado = _alembic(migrada, "upgrade", "head")
        assert resultado.returncode == 0, resultado.stderr
        yield con_schema, migrada


@pytest.mark.parametrize("que", ["columnas", "constraints", "indices", "roles"])
def test_la_migracion_crea_lo_mismo_que_schema_sql(bases, que):
    con_schema, migrada = bases
    esperado = asyncio.run(_consultar(con_schema, CONSULTAS[que]))
    obtenido = asyncio.run(_consultar(migrada, CONSULTAS[que]))
    assert esperado, f"schema.sql no devolvió {que}: la consulta no está viendo nada"
    solo_schema = sorted(set(esperado) - set(obtenido))
    solo_migracion = sorted(set(obtenido) - set(esperado))
    assert not solo_schema and not solo_migracion, (
        f"{que}: solo en schema.sql={solo_schema[:5]} · solo en la migración={solo_migracion[:5]}"
    )


def test_la_migracion_tiene_35_tablas_y_54_fk(bases):
    _, migrada = bases
    foto = _foto(migrada)
    tablas = {fila[0] for fila in foto["columnas"]}
    claves_foraneas = [fila for fila in foto["constraints"] if fila[2] == "f"]
    assert len(tablas) == 35
    assert len(claves_foraneas) == 54


def test_los_modelos_y_la_base_migrada_coinciden(bases):
    """`alembic check`: si el modelo cambió y falta la migración, devuelve error."""
    _, migrada = bases
    resultado = _alembic(migrada, "check")
    assert resultado.returncode == 0, resultado.stdout + resultado.stderr


def test_downgrade_deja_la_base_vacia():
    with base_temporal() as base:
        assert _alembic(base, "upgrade", "head").returncode == 0
        assert _alembic(base, "downgrade", "base").returncode == 0
        tablas = asyncio.run(
            _consultar(
                base,
                "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'",
            )
        )
        assert tablas == [("alembic_version",)]
