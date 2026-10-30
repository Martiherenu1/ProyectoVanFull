"""Modelos ORM: 35 tablas de línea base + vínculo CU-036 candidato D1 (#238).

Un archivo por bloque del modelo relacional. Importarlos acá es lo que registra las tablas en
`Base.metadata`, que es lo que usa Alembic para generar y comparar migraciones.

Quién escribe en cada tabla está en `Documentos/Sesiones/PC2/REPARTO-PC2.md`.
"""

from app.models import cuenta_corriente, mercadopago, personas, servicios, trazabilidad, viajes

__all__ = ["cuenta_corriente", "mercadopago", "personas", "servicios", "trazabilidad", "viajes"]
