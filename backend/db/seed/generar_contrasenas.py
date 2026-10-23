"""Genera contraseñas aleatorias para las cuentas del seed, en un archivo fuera del repositorio.

    python -m db.seed.generar_contrasenas C:/ruta/fuera/del/repo/contrasenas-demo.csv

Es el archivo que `cargar.py` pide con `--contrasenas` para sembrar una base remota (la de la demo):
las de `contrasenas-de-prueba.csv` son públicas. Solo usa la biblioteca estándar, así que corre con
cualquier Python 3.12+, sin Docker. No imprime las contraseñas: quedan solo en el archivo.
"""

import argparse
import csv
import secrets
import sys
from pathlib import Path

CARPETA = Path(__file__).resolve().parent
BACKEND = CARPETA.parents[1]
REPO = BACKEND.parent


def esta_en_el_repo(ruta: Path) -> bool:
    """`backend/` siempre es del repo (en Docker es `/app`); fuera de Docker, también el resto."""
    ruta = ruta.resolve()
    en_docker = not REPO.name  # `/app/..` es `/`, la raíz del contenedor
    return ruta.is_relative_to(BACKEND) or (not en_docker and ruta.is_relative_to(REPO))


def identificadores() -> list[str]:
    with (CARPETA / "cuenta_acceso.csv").open(encoding="utf-8", newline="") as archivo:
        return [fila["identificador_acceso"] for fila in csv.DictReader(archivo)]


def generar(destino: Path) -> int:
    """Escribe una contraseña nueva por cuenta. Devuelve cuántas escribió."""
    destino = destino.resolve()
    if esta_en_el_repo(destino):
        raise ValueError("El archivo tiene que quedar fuera del repositorio, que es público.")
    if destino.exists():
        raise ValueError(f"{destino} ya existe: no se pisa (las contraseñas viejas se perderían).")
    cuentas = identificadores()
    with destino.open("x", encoding="utf-8", newline="") as archivo:
        escritor = csv.writer(archivo)
        escritor.writerow(["identificador_acceso", "contrasena"])
        # 18 bytes → 24 caracteres: lejos del tope de 72 bytes de bcrypt.
        escritor.writerows([cuenta, secrets.token_urlsafe(18)] for cuenta in cuentas)
    return len(cuentas)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("destino", type=Path, help="CSV a crear, fuera del repositorio")
    args = parser.parse_args(argv)
    try:
        cantidad = generar(args.destino)
    except ValueError as error:
        print(f"No se generó nada: {error}", file=sys.stderr)
        return 1
    print(f"{cantidad} contraseñas en {args.destino.resolve()}. Guardalo y no lo subas.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
