#!/bin/sh
# Arranque del servicio en Render (render.yaml, `dockerCommand: sh arrancar.sh`). Issue #119.
# Va en un script porque Render no parte el `dockerCommand` como un shell: un `sh -c "…"` le llega
# como un solo nombre de comando. Local y la CI no lo usan (docker-compose.yml tiene su `command`).
set -e

# Migra antes de servir: el plan free no tiene shell ni jobs. Si la base ya está en head no hace nada;
# si falla, `set -e` corta y la API no arranca con el esquema viejo.
alembic upgrade head

# Render define PORT (10000). Detrás de su proxy, el esquema y la IP reales vienen en X-Forwarded-*.
exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8000}" --proxy-headers --forwarded-allow-ips='*'
