"""Carga los datos de prueba de `backend/db/seed/` en una base ya migrada.

    docker compose run --rm backend python -m db.seed.cargar
    docker compose run --rm backend python -m db.seed.cargar --reiniciar

Cada CSV tiene las columnas de su tabla en `schema.sql`, con los ids explícitos para que las FK
entre archivos sean legibles. La única columna que no está en un CSV es
`cuenta_acceso.hash_contrasena`: se calcula con bcrypt a partir de `contrasenas-de-prueba.csv`
(contraseñas de desarrollo, no reales). Ver README.md de esta carpeta.

Todo se carga en una sola transacción: si algo falla, no queda nada a medias.
"""

import argparse
import asyncio
import csv
import sys
from pathlib import Path
from urllib.parse import urlparse

import asyncpg
from sqlalchemy.engine import make_url

from app.core.config import get_settings
from app.core.security import hash_contrasena

CARPETA = Path(__file__).resolve().parent
CONTRASENAS = CARPETA / "contrasenas-de-prueba.csv"

# Orden de carga: cada tabla después de las que referencia por FK.
ORDEN = (
    "persona",
    "pasajero",
    "chofer",
    "cliente",
    "cliente_individual",
    "cuenta_corriente",
    "cuenta_acceso",
    "cuenta_rol",
    "servicio",
    "recorrido",
    "parada",
    "parada_recorrido",
    "vehiculo",
    "viaje",
)

# cuenta_rol.csv usa ids. Los fija la migración inicial, en este orden.
ROLES_ESPERADOS = ("pasajero", "chofer", "administrador", "dueno", "representante_corporativo")

HOSTS_LOCALES = {"localhost", "127.0.0.1", "::1", "db"}


class ErrorSeed(Exception):
    """Algo impide cargar los datos; el mensaje dice qué hacer."""


def _dsn_de_settings() -> str:
    url = make_url(get_settings().database_url).set(drivername="postgresql")
    return url.render_as_string(hide_password=False)


def es_base_local(dsn: str) -> bool:
    return (urlparse(dsn).hostname or "") in HOSTS_LOCALES


def leer_csv(tabla: str) -> list[dict[str, str]]:
    with (CARPETA / f"{tabla}.csv").open(encoding="utf-8", newline="") as archivo:
        return list(csv.DictReader(archivo))


def leer_contrasenas(ruta: Path) -> dict[str, str]:
    with ruta.open(encoding="utf-8", newline="") as archivo:
        return {f["identificador_acceso"]: f["contrasena"] for f in csv.DictReader(archivo)}


def _filas_a_cargar(archivo_contrasenas: Path) -> dict[str, list[dict[str, str]]]:
    contrasenas = leer_contrasenas(archivo_contrasenas)
    filas = {tabla: leer_csv(tabla) for tabla in ORDEN}
    for cuenta in filas["cuenta_acceso"]:
        identificador = cuenta["identificador_acceso"]
        if identificador not in contrasenas:
            raise ErrorSeed(
                f"Falta la contraseña de {identificador} en {archivo_contrasenas.name}."
            )
        cuenta["hash_contrasena"] = hash_contrasena(contrasenas[identificador])
    return filas


async def _verificar_roles(conn: asyncpg.Connection) -> None:
    try:
        filas = await conn.fetch("SELECT rol FROM rol_acceso ORDER BY id_rol_acceso")
    except asyncpg.UndefinedTableError as error:
        raise ErrorSeed(
            "La base no tiene las tablas: aplicar las migraciones primero "
            "(docker compose run --rm backend alembic upgrade head)."
        ) from error
    roles = [r["rol"] for r in filas]
    if roles != list(ROLES_ESPERADOS):
        raise ErrorSeed(
            f"rol_acceso tiene {roles} y cuenta_rol.csv espera {list(ROLES_ESPERADOS)}. "
            "¿La base está migrada? (alembic upgrade head)"
        )


async def _insertar(conn: asyncpg.Connection, tabla: str, filas: list[dict[str, str]]) -> None:
    if not filas:
        return
    columnas = list(filas[0])
    definidas = {
        r["column_name"]: r
        for r in await conn.fetch(
            "SELECT column_name, udt_name, is_identity FROM information_schema.columns "
            "WHERE table_schema = 'public' AND table_name = $1",
            tabla,
        )
    }
    desconocidas = [c for c in columnas if c not in definidas]
    if desconocidas:
        raise ErrorSeed(f"{tabla}.csv tiene columnas que {tabla} no tiene: {desconocidas}.")

    # Los valores llegan como texto y se convierten al tipo de la columna; vacío es NULL.
    valores = ", ".join(
        f"CAST(NULLIF(${i}, '') AS {definidas[c]['udt_name']})" for i, c in enumerate(columnas, 1)
    )
    con_identidad = any(definidas[c]["is_identity"] == "YES" for c in columnas)
    # Las PK son GENERATED ALWAYS: para fijar el id hay que pedirlo explícitamente.
    pedido = " OVERRIDING SYSTEM VALUE" if con_identidad else ""
    sentencia = f'INSERT INTO "{tabla}" ({", ".join(columnas)}){pedido} VALUES ({valores})'
    await conn.executemany(sentencia, [[fila[c] for c in columnas] for fila in filas])


async def _reajustar_secuencias(conn: asyncpg.Connection) -> None:
    """Con ids explícitos la secuencia quedaría en 1 y el próximo INSERT chocaría."""
    for tabla in ORDEN:
        identidades = await conn.fetch(
            "SELECT column_name FROM information_schema.columns "
            "WHERE table_schema = 'public' AND table_name = $1 AND is_identity = 'YES'",
            tabla,
        )
        for fila in identidades:
            columna = fila["column_name"]
            maximo = await conn.fetchval(f'SELECT max("{columna}") FROM "{tabla}"')
            if maximo is not None:
                await conn.execute(
                    "SELECT setval(pg_get_serial_sequence($1, $2), $3)",
                    f"public.{tabla}",
                    columna,
                    maximo,
                )


async def cargar(
    dsn: str, *, reiniciar: bool = False, archivo_contrasenas: Path = CONTRASENAS
) -> dict[str, int]:
    """Carga los CSV. Devuelve cuántas filas entraron por tabla."""
    filas = _filas_a_cargar(archivo_contrasenas)
    conn = await asyncpg.connect(dsn)
    try:
        async with conn.transaction():
            await _verificar_roles(conn)
            ocupadas = [
                t for t in ORDEN if await conn.fetchval(f'SELECT EXISTS (SELECT 1 FROM "{t}")')
            ]
            if ocupadas and not reiniciar:
                raise ErrorSeed(
                    f"Ya hay datos en {ocupadas}. Con --reiniciar se vacían esas tablas "
                    "(y todo lo que dependa de ellas) antes de cargar."
                )
            if ocupadas:
                tablas = ", ".join(f'"{t}"' for t in ORDEN)
                await conn.execute(f"TRUNCATE {tablas} RESTART IDENTITY CASCADE")
            for tabla in ORDEN:
                await _insertar(conn, tabla, filas[tabla])
            await _reajustar_secuencias(conn)
    finally:
        await conn.close()
    return {tabla: len(filas[tabla]) for tabla in ORDEN}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Carga los datos de prueba en la base migrada.")
    parser.add_argument(
        "--reiniciar",
        action="store_true",
        help="vacía las tablas del seed (y lo que dependa de ellas) antes de cargar",
    )
    parser.add_argument(
        "--contrasenas",
        type=Path,
        default=CONTRASENAS,
        help="CSV identificador_acceso,contrasena (por defecto, el de esta carpeta)",
    )
    parser.add_argument(
        "--permitir-base-remota",
        action="store_true",
        help="permite cargar en una base que no es local (no usar con las contraseñas del repo)",
    )
    args = parser.parse_args(argv)

    dsn = _dsn_de_settings()
    if not es_base_local(dsn) and not args.permitir_base_remota:
        host = urlparse(dsn).hostname
        print(
            f"No se carga: la base es '{host}', no local. Las contraseñas del seed están en un "
            "repositorio público; para una base compartida usar --contrasenas con un archivo "
            "propio y --permitir-base-remota.",
            file=sys.stderr,
        )
        return 2

    try:
        resumen = asyncio.run(
            cargar(dsn, reiniciar=args.reiniciar, archivo_contrasenas=args.contrasenas)
        )
    except ErrorSeed as error:
        print(f"No se cargó nada: {error}", file=sys.stderr)
        return 1

    for tabla, cantidad in resumen.items():
        print(f"  {tabla}: {cantidad}")
    print("Listo.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
