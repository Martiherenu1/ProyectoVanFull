"""Extensión local optativa: no alterar los fixtures/esquema base compartidos."""

import os
import subprocess
import sys

from tests._bd import BACKEND, url_sqlalchemy


def alembic_mp(base: str, *args: str, autorizar: bool = True):
    if not base.startswith("vf_test_"):
        raise ValueError("Este helper solo opera en bases temporales vf_test_.")
    comando = [sys.executable, "-m", "alembic", "-c", "sandbox/mercadopago/alembic.ini"]
    if autorizar:
        comando += ["-x", "autorizar_cu036=SI"]
    return subprocess.run(
        comando + list(args),
        cwd=BACKEND,
        env={**os.environ, "DATABASE_URL": url_sqlalchemy(base)},
        capture_output=True,
        text=True,
        timeout=120,
    )
