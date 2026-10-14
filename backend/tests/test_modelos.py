"""Los modelos ORM tienen que cubrir lo mismo que `backend/db/schema.sql`.

El schema es la fuente (CONTRIBUTING §2): estas pruebas lo leen a él y comparan, así que si
alguien agrega una tabla o una FK en un lado y no en el otro, fallan. La comparación columna por
columna contra PostgreSQL la hace la migración inicial.
"""

import re
from pathlib import Path

import pytest
from sqlalchemy import ForeignKeyConstraint

import app.models  # noqa: F401  (registra las tablas en Base.metadata)
from app.core.database import Base

SCHEMA = Path(__file__).resolve().parents[1] / "db" / "schema.sql"


@pytest.fixture(scope="module")
def sql() -> str:
    return SCHEMA.read_text(encoding="utf-8")


def test_hay_35_tablas():
    assert len(Base.metadata.tables) == 35


def test_las_tablas_son_las_del_schema(sql):
    en_sql = set(re.findall(r"^CREATE TABLE (\w+)", sql, flags=re.MULTILINE))
    assert set(Base.metadata.tables) == en_sql


def test_las_claves_foraneas_son_las_del_schema(sql):
    en_sql = len(re.findall(r"ADD FOREIGN KEY", sql))
    en_modelos = sum(
        1
        for tabla in Base.metadata.tables.values()
        for c in tabla.constraints
        if isinstance(c, ForeignKeyConstraint)
    )
    assert en_modelos == en_sql == 54


def test_cada_tabla_tiene_las_columnas_del_schema(sql):
    """Compara nombres de columna: atrapa una columna olvidada o con otro nombre."""
    for nombre, tabla in Base.metadata.tables.items():
        cuerpo = re.search(rf"^CREATE TABLE {nombre} \((.*?)^\);", sql, re.MULTILINE | re.DOTALL)
        assert cuerpo, nombre
        columnas_sql = set()
        for linea in cuerpo.group(1).splitlines():
            m = re.match(r"\s{4}([a-z_]+)\s+[A-Z]", linea)
            if m and m.group(1) not in {"PRIMARY", "UNIQUE", "CHECK", "CONSTRAINT"}:
                columnas_sql.add(m.group(1))
        assert {c.name for c in tabla.columns} == columnas_sql, nombre
