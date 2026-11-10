#!/bin/sh
# Servicio web compartido y aislado de CU-036. No usar con la base habitual.
set -e

alembic upgrade head
alembic -c sandbox/mercadopago/alembic.ini -x autorizar_cu036=SI upgrade head

exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8000}" --proxy-headers --forwarded-allow-ips='*'
