"""La extensión CU-036 nunca forma parte del upgrade head usado por Render."""

import asyncio
import os
import subprocess
import sys

import pytest
from alembic.config import Config
from alembic.script import ScriptDirectory

from tests._bd import BACKEND, alembic, base_migrada, base_temporal, consultar, ejecutar_sql
from tests._bd_mercadopago import alembic_mp
from tests.test_migracion import CONSULTAS, SCHEMA


def test_head_habitual_no_descubre_migracion_mp():
    cadena = ScriptDirectory.from_config(Config(str(BACKEND / "alembic.ini")))
    assert cadena.get_current_head() == "0001"
    assert all(not revision.revision.startswith("mp_") for revision in cadena.walk_revisions())


def test_arranque_habitual_no_crea_tabla_aun_si_modelo_importado():
    with base_migrada() as base:
        assert alembic(base, "upgrade", "head").returncode == 0
        assert asyncio.run(consultar(base, "SELECT to_regclass('pago_mercadopago')")) == [(None,)]
        assert alembic(base, "check").returncode == 0
        denegado = alembic_mp(base, "upgrade", "head", autorizar=False)
        assert denegado.returncode != 0 and "Falta autorización explícita" in denegado.stderr
        assert asyncio.run(consultar(base, "SELECT to_regclass('pago_mercadopago')")) == [(None,)]


@pytest.mark.parametrize(
    "env,url",
    [
        ("production", "postgresql+asyncpg://fake:fake@127.0.0.1:1/vf_sandbox_negativo"),
        ("development", "postgresql+asyncpg://fake:fake@no-conectar.invalid/vf_sandbox_negativo"),
        ("development", "postgresql+asyncpg://fake:fake@127.0.0.1:1/vanfull"),
    ],
)
def test_migracion_optativa_rechaza_destino_antes_de_conectar(env, url):
    resultado = subprocess.run(
        [
            sys.executable,
            "-m",
            "alembic",
            "-c",
            "sandbox/mercadopago/alembic.ini",
            "-x",
            "autorizar_cu036=SI",
            "upgrade",
            "head",
        ],
        cwd=BACKEND,
        env={**os.environ, "ENV": env, "DATABASE_URL": url, "MERCADOPAGO_SANDBOX_ENABLED": "false"},
        capture_output=True,
        text=True,
        timeout=20,
    )
    assert resultado.returncode != 0
    assert "solo admite entorno local" in resultado.stderr
    assert "ConnectionRefused" not in resultado.stderr and "getaddrinfo" not in resultado.stderr


@pytest.fixture(scope="module")
def bases():
    with base_temporal() as con_schema, base_migrada() as migrada:
        asyncio.run(ejecutar_sql(con_schema, SCHEMA.read_text(encoding="utf-8")))
        asyncio.run(
            ejecutar_sql(
                con_schema, (BACKEND / "sandbox/mercadopago/schema.sql").read_text(encoding="utf-8")
            )
        )
        resultado = alembic_mp(migrada, "upgrade", "head")
        assert resultado.returncode == 0, resultado.stderr
        yield con_schema, migrada


@pytest.mark.parametrize("que", ["columnas", "constraints", "indices", "roles"])
def test_extension_migrada_coincide_con_ddl_optativo(bases, que):
    esperado, obtenido = [asyncio.run(consultar(base, CONSULTAS[que])) for base in bases]
    # La segunda tabla de versión es infraestructura del circuito optativo.
    obtenido = [fila for fila in obtenido if fila[0] != "alembic_version_mercadopago"]
    assert esperado == obtenido
