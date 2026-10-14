"""Utilidades compartidas por los modelos (no es un modelo)."""

from sqlalchemy import CheckConstraint


def check_en(columna: str, valores: tuple[str, ...], admite_nulo: bool = False) -> CheckConstraint:
    """CHECK de dominio enumerado: `columna IN (...)`, como en schema.sql.

    `admite_nulo` reproduce la forma `columna IS NULL OR columna IN (...)` que schema.sql
    usa en columnas opcionales.

    Sin nombre a propósito: PostgreSQL le asigna `<tabla>_<columna>_check`, el mismo
    nombre que recibe al cargar schema.sql, y así la migración se puede comparar.
    """
    lista = ", ".join(f"'{v}'" for v in valores)
    condicion = f"{columna} IN ({lista})"
    if admite_nulo:
        condicion = f"{columna} IS NULL OR {condicion}"
    return CheckConstraint(condicion)
