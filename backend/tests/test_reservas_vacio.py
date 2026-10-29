"""CU-027 sin reservas: el listado de administración responde 200 con una lista vacía.

Va en su propio archivo porque `cliente_api` reemplaza `app.dependency_overrides[get_db]` y lo borra al
salir: si convivía con el fixture de módulo de `test_reservas.py`, dejaba a sus pruebas sin base.
"""

import asyncio

from app.core.security import crear_token
from tests._bd import base_migrada, cliente_api, consultar


def test_sin_reservas_el_listado_de_administracion_es_una_lista_vacia():
    with base_migrada() as base, cliente_api(base) as http:
        id_persona = asyncio.run(
            consultar(
                base,
                "INSERT INTO persona (nombre, apellido, dni) VALUES ('N', 'A', '9') "
                "RETURNING id_persona",
            )
        )[0][0]
        token = crear_token(id_persona, id_persona, ["administrador"])
        respuesta = http.get("/api/reservas", headers={"Authorization": f"Bearer {token}"})
    assert respuesta.status_code == 200
    assert respuesta.json() == []
