"""Modelos ORM (SQLAlchemy 2.0) de las 35 tablas de `backend/db/schema.sql`.

Un archivo por bloque del modelo relacional. Importarlos acá es lo que registra las tablas en
`Base.metadata`, que es lo que usa Alembic para generar y comparar migraciones.

Quién escribe en cada tabla está en `Documentos/Sesiones/PC2/REPARTO-PC2.md`.
"""

from app.models import cuenta_corriente, personas, servicios, trazabilidad, viajes

__all__ = ["cuenta_corriente", "personas", "servicios", "trazabilidad", "viajes"]
