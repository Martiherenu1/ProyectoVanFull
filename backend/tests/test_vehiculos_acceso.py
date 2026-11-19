"""Permisos HTTP de CU-022 sin BD; el CRUD transaccional se prueba por separado."""

from unittest.mock import AsyncMock

import pytest
from fastapi.testclient import TestClient

from app.core.database import get_db
from app.core.security import crear_token
from app.main import app
from app.services import vehiculos


@pytest.fixture
def acceso(monkeypatch):
    vehiculo = {
        "id_vehiculo": 7,
        "patente": "VF022AA",
        "marca": None,
        "modelo": None,
        "capacidad": 19,
        "disponibilidad": True,
    }
    operaciones = {}
    for nombre in (
        "listar_vehiculos",
        "consultar_vehiculo",
        "crear_vehiculo",
        "actualizar_vehiculo",
    ):
        operacion = AsyncMock(return_value=[vehiculo] if nombre == "listar_vehiculos" else vehiculo)
        monkeypatch.setattr(vehiculos, nombre, operacion)
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
        ("GET", "/api/vehiculos", "listar_vehiculos", 200),
        ("GET", "/api/vehiculos/7", "consultar_vehiculo", 200),
        ("POST", "/api/vehiculos", "crear_vehiculo", 201),
        ("PATCH", "/api/vehiculos/7", "actualizar_vehiculo", 200),
    ],
)
def test_permisos_http_sin_acceder_a_persistencia(acceso, rol, metodo, ruta, operacion, estado):
    cliente, operaciones = acceso
    headers = {} if rol is None else {"Authorization": f"Bearer {crear_token(1, 1, [rol])}"}
    argumentos = {}
    if metodo == "POST":
        argumentos["json"] = {"patente": "VF022AA", "capacidad": 19}
    elif metodo == "PATCH":
        argumentos["json"] = {"capacidad": 20}
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
