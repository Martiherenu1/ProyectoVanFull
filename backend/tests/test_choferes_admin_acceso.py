"""Permisos HTTP de CU-021 sin BD; el CRUD transaccional se prueba por separado."""

from unittest.mock import AsyncMock

import pytest
from fastapi.testclient import TestClient

from app.core.database import get_db
from app.core.security import crear_token
from app.main import app
from app.services import choferes_admin


@pytest.fixture
def acceso(monkeypatch):
    chofer = {
        "id_persona": 7,
        "nombre": "Ana",
        "apellido": "Perez",
        "dni": "21000001",
        "direccion": None,
        "telefono": None,
        "email": None,
        "cuil": None,
        "registro_conducir": None,
        "fecha_vencimiento_registro": None,
    }
    operaciones = {}
    for nombre in ("listar_choferes", "consultar_chofer", "crear_chofer", "actualizar_chofer"):
        operacion = AsyncMock(return_value=[chofer] if nombre == "listar_choferes" else chofer)
        monkeypatch.setattr(choferes_admin, nombre, operacion)
        operaciones[nombre] = operacion

    async def sin_base():
        yield object()

    anterior = app.dependency_overrides.copy()
    app.dependency_overrides[get_db] = sin_base
    try:
        with TestClient(app) as cliente:
            yield cliente, operaciones
    finally:
        app.dependency_overrides.clear()
        app.dependency_overrides.update(anterior)


@pytest.mark.parametrize("rol", ["administrador", "dueno", "pasajero", "chofer", None])
@pytest.mark.parametrize(
    "metodo,ruta,operacion,estado",
    [
        ("GET", "/api/choferes", "listar_choferes", 200),
        ("GET", "/api/choferes/7", "consultar_chofer", 200),
        ("POST", "/api/choferes", "crear_chofer", 201),
        ("PATCH", "/api/choferes/7", "actualizar_chofer", 200),
    ],
)
def test_permisos_http_sin_acceder_a_persistencia(acceso, rol, metodo, ruta, operacion, estado):
    cliente, operaciones = acceso
    headers = {} if rol is None else {"Authorization": f"Bearer {crear_token(1, 1, [rol])}"}
    argumentos = {}
    if metodo == "POST":
        argumentos["json"] = {"nombre": "Ana", "apellido": "Perez", "dni": "21000001"}
    elif metodo == "PATCH":
        argumentos["json"] = {"nombre": "Andrea"}
    respuesta = cliente.request(metodo, ruta, headers=headers, **argumentos)
    permitido = rol in {"administrador", "dueno"}
    assert respuesta.status_code == (estado if permitido else 401 if rol is None else 403)
    if permitido:
        operaciones[operacion].assert_awaited_once()
    else:
        assert respuesta.json()["error"]["codigo"] == (
            "NO_AUTENTICADO" if rol is None else "SIN_PERMISO"
        )
    for nombre, llamada in operaciones.items():
        if not permitido or nombre != operacion:
            llamada.assert_not_awaited()
