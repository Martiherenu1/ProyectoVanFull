"""Toda ruta que implementa el backend tiene que existir en el contrato.

`backend/openapi/README.md`: el contrato es el de diseño y la API generada por FastAPI "deberá
coincidir con este contrato". Esta prueba lo hace cumplir en el sentido que evita el error caro:
una ruta o un método inventados que ningún otro integrante ni el frontend conocen.

La inversa (que todo el contrato esté implementado) no se exige: el contrato cubre más de lo que
entra en el PC2.
"""

from pathlib import Path
from urllib.parse import urlparse

import yaml

from app.main import app

CONTRATO = Path(__file__).resolve().parents[1] / "openapi" / "openapi.yaml"
METODOS = {"get", "post", "put", "patch", "delete"}
# No son del contrato: la raíz y el chequeo de salud.
FUERA_DEL_CONTRATO = {"/", "/api/health"}


def test_las_rutas_implementadas_estan_en_el_contrato():
    contrato = yaml.safe_load(CONTRATO.read_text(encoding="utf-8"))
    prefijo = urlparse(contrato["servers"][0]["url"]).path.rstrip("/")
    del_contrato = {
        (prefijo + ruta, metodo.upper())
        for ruta, operaciones in contrato["paths"].items()
        for metodo in operaciones
        if metodo in METODOS
    }
    # Se lee del esquema que FastAPI genera, no de app.routes: no depende de cómo FastAPI
    # guarde internamente los routers incluidos.
    implementadas = {
        (ruta, metodo.upper())
        for ruta, operaciones in app.openapi()["paths"].items()
        for metodo in operaciones
        if metodo in METODOS
    }
    assert implementadas, "FastAPI no declara ninguna ruta: la comparación no estaría viendo nada"
    desconocidas = sorted(
        (ruta, metodo)
        for ruta, metodo in implementadas
        if ruta not in FUERA_DEL_CONTRATO and (ruta, metodo) not in del_contrato
    )
    assert not desconocidas, (
        f"Rutas que el backend implementa y el contrato no declara: {desconocidas}. "
        "Agregarlas a openapi.yaml (PR de contrato, §1.9) o sacarlas."
    )


def test_el_login_y_el_logout_estan_implementados():
    """Sanidad de la prueba anterior: que la comparación vea las rutas con su prefijo."""
    assert {"/api/auth/login", "/api/auth/logout"} <= set(app.openapi()["paths"])
