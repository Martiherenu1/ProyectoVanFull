"""La migración de Alembic tiene que producir lo mismo que `backend/db/schema.sql`.

CONTRIBUTING §1.5: "alembic upgrade head sobre una base limpia, y comparar las tablas con
schema.sql". Acá se hace en dos bases temporales, comparando los catálogos de PostgreSQL
(columnas, constraints, índices y roles). Si alguien cambia schema.sql, los modelos o la migración y
no los otros, falla.

Necesita un PostgreSQL accesible; ver `tests/_bd.py` para el criterio de saltear o fallar.
"""

import asyncio

import pytest

from tests._bd import BACKEND, alembic, base_migrada, base_temporal, consultar, ejecutar_sql

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
    # contype llega de PostgreSQL como "char" (bytes en asyncpg): se pasa a texto.
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


@pytest.fixture(scope="module")
def bases():
    """Una base cargada con schema.sql y otra con `alembic upgrade head`."""
    with base_temporal() as con_schema, base_migrada() as migrada:
        asyncio.run(ejecutar_sql(con_schema, SCHEMA.read_text(encoding="utf-8")))
        yield con_schema, migrada


@pytest.mark.parametrize("que", ["columnas", "constraints", "indices", "roles"])
def test_la_migracion_crea_lo_mismo_que_schema_sql(bases, que):
    con_schema, migrada = bases
    esperado = asyncio.run(consultar(con_schema, CONSULTAS[que]))
    obtenido = asyncio.run(consultar(migrada, CONSULTAS[que]))
    assert esperado, f"schema.sql no devolvió {que}: la consulta no está viendo nada"
    solo_schema = sorted(set(esperado) - set(obtenido))
    solo_migracion = sorted(set(obtenido) - set(esperado))
    assert not solo_schema and not solo_migracion, (
        f"{que}: solo en schema.sql={solo_schema[:5]} · solo en la migración={solo_migracion[:5]}"
    )


def test_la_migracion_tiene_35_tablas_y_54_fk(bases):
    _, migrada = bases
    columnas = asyncio.run(consultar(migrada, CONSULTAS["columnas"]))
    constraints = asyncio.run(consultar(migrada, CONSULTAS["constraints"]))
    assert len({fila[0] for fila in columnas}) == 35
    assert len([fila for fila in constraints if fila[2] == "f"]) == 54


def test_los_modelos_y_la_base_migrada_coinciden(bases):
    """`alembic check`: si el modelo cambió y falta la migración, devuelve error."""
    _, migrada = bases
    resultado = alembic(migrada, "check")
    assert resultado.returncode == 0, resultado.stdout + resultado.stderr


def test_downgrade_deja_la_base_vacia():
    with base_temporal() as base:
        assert alembic(base, "upgrade", "head").returncode == 0
        assert alembic(base, "downgrade", "base").returncode == 0
        tablas = asyncio.run(
            consultar(
                base,
                "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'",
            )
        )
        assert tablas == [("alembic_version",)]
