"""Circuito VanFull → YPF → UADE con PostgreSQL real y Google Routes simulado."""

from decimal import Decimal

import asyncpg
import pytest

from app.core.config import get_settings
from app.services import eta
from tests.test_ausencias import _caso, _persona, _sql, _token, _uno
from tests.test_ausencias import entorno as entorno


@pytest.fixture(scope="module")
def recorrido(entorno):
    _sql(entorno, "UPDATE parada SET latitud=-34.57, longitud=-58.69")
    _sql(entorno, "UPDATE vehiculo SET capacidad=2 WHERE id_vehiculo=$1", entorno["vehiculo"])
    for orden, lat, lon, nombre in [
        (2, -34.572994, -58.692181, "YPF"),
        (3, -34.617882, -58.381599, "UADE"),
    ]:
        id_parada = _uno(
            entorno,
            "INSERT INTO parada (latitud, longitud, nombre_descripcion) VALUES ($1,$2,$3) "
            "RETURNING id_parada",
            Decimal(str(lat)),
            Decimal(str(lon)),
            nombre,
        )
        _sql(
            entorno,
            "INSERT INTO parada_recorrido (id_recorrido, orden, id_parada) VALUES ($1,$2,$3)",
            entorno["recorrido"],
            orden,
            id_parada,
        )
    return entorno


def test_base_rechaza_paso_incompleto_y_descenso_no_posterior(recorrido):
    e = recorrido
    _, viaje, reserva = _caso(e)
    for cambio in ("orden_ultimo_paso=1", "fecha_ultimo_paso=now()"):
        with pytest.raises(asyncpg.CheckViolationError) as error:
            _sql(e, f"UPDATE viaje SET {cambio} WHERE id_viaje=$1", viaje)
        assert error.value.constraint_name == "ck_viaje_ultimo_paso_completo"

    _sql(
        e,
        "INSERT INTO descenso_habilitado (id_viaje, id_recorrido, orden_parada) VALUES ($1, $2, 1)",
        viaje,
        e["recorrido"],
    )
    with pytest.raises(asyncpg.CheckViolationError) as error:
        _sql(e, "UPDATE reserva SET orden_descenso=1 WHERE id_reserva=$1", reserva)
    assert error.value.constraint_name == "ck_reserva_orden_descenso_posterior"


def test_descenso_explicito_paso_y_fin(recorrido, monkeypatch):
    e = recorrido
    persona, viaje, existente = _caso(e)
    _sql(e, "DELETE FROM reserva WHERE id_reserva=$1", existente)
    http = e["http"]
    pasajero = _token(persona)
    admin = _token(persona, ("administrador",))
    chofer = _token(e["chofer"], ("chofer",))
    descensos = f"/api/viajes/{viaje}/descensos"
    assert http.patch(descensos, headers=pasajero, json={"ordenes": [3]}).status_code == 403
    assert http.patch(descensos, headers=admin, json={"ordenes": [3]}).json() == {"ordenes": [3]}
    assert http.get(descensos, headers=pasajero).json() == {"ordenes": [3]}

    datos = {"id_viaje": viaje, "orden_parada": 2, "orden_descenso": 2}
    assert http.post("/api/reservas", headers=pasajero, json=datos).status_code == 400
    reserva = http.post("/api/reservas", headers=pasajero, json={**datos, "orden_descenso": 3})
    assert reserva.status_code == 201, reserva.text
    assert reserva.json()["orden_descenso"] == 3
    conflicto = http.patch(descensos, headers=admin, json={"ordenes": [1]})
    assert conflicto.status_code == 409
    assert conflicto.json()["error"]["codigo"] == "DESCENSO_CON_RESERVAS"
    assert http.get(descensos, headers=pasajero).json() == {"ordenes": [3]}
    otro_pasajero = _token(_persona(e))
    sin_descenso = http.post(
        "/api/reservas", headers=otro_pasajero, json={"id_viaje": viaje, "orden_parada": 2}
    )
    assert sin_descenso.status_code == 201, sin_descenso.text
    assert (
        http.post(
            f"/api/reservas/{reserva.json()['id_reserva']}/cambio-parada",
            headers=pasajero,
            json={"orden_parada": 3},
        ).status_code
        == 400
    )
    assert http.post(f"/api/viajes/{viaje}/inicio", headers=chofer).status_code == 200
    ubicacion = f"/api/viajes/{viaje}/ubicacion"
    assert (
        http.post(
            ubicacion, headers=chofer, json={"latitud": -34.569991, "longitud": -58.696060}
        ).status_code
        == 200
    )

    reloj = [100.0]
    pedidos = []

    async def simular(cliente, clave, origen, paradas):
        pedidos.append((origen, paradas))
        return (Decimal(0), Decimal(360), Decimal(3060)) if len(paradas) == 3 else (Decimal(2940),)

    monkeypatch.setenv("GOOGLE_ROUTES_API_KEY", "solo-prueba")
    get_settings.cache_clear()
    monkeypatch.setattr(eta, "_cache", {})
    monkeypatch.setattr(eta, "monotonic", lambda: reloj[0])
    monkeypatch.setattr(eta, "calcular_tiempos", simular)
    try:
        ruta = f"/api/reservas/{reserva.json()['id_reserva']}/eta"
        antes = http.get(ruta, headers=pasajero)
        assert antes.headers["Cache-Control"] == "no-store"
        assert (antes.json()["ascenso_minutos"], antes.json()["destino_minutos"]) == (6, 51)
        eta_sin_descenso = http.get(
            f"/api/reservas/{sin_descenso.json()['id_reserva']}/eta", headers=otro_pasajero
        )
        assert eta_sin_descenso.status_code == 200
        assert eta_sin_descenso.json()["destino_minutos"] is None
        assert eta_sin_descenso.json()["destino_pasado"] is False
        assert http.get(ruta, headers=_token(_persona(e))).status_code == 404
        assert http.get(ruta, headers=pasajero).status_code == 200 and len(pedidos) == 1
        assert http.get(ubicacion, headers=pasajero).json()["eta_minutos"] is None

        paso = f"/api/viajes/{viaje}/paso-parada"
        assert (
            http.post(
                paso, headers=_token(_persona(e), ("chofer",)), json={"orden_parada": 2}
            ).status_code
            == 404
        )
        assert http.post(paso, headers=chofer, json={"orden_parada": 2}).json() == {
            "orden_parada": 2
        }
        assert http.post(paso, headers=chofer, json={"orden_parada": 1}).json() == {
            "orden_parada": 2
        }

        sin_posicion_nueva = http.get(ruta, headers=pasajero).json()
        assert sin_posicion_nueva["ascenso_pasado"]
        assert sin_posicion_nueva["destino_minutos"] is None

        reloj[0] += 60
        assert (
            http.post(
                ubicacion, headers=chofer, json={"latitud": -34.572994, "longitud": -58.692181}
            ).status_code
            == 200
        )
        despues = http.get(ruta, headers=pasajero).json()
        assert despues["ascenso_pasado"] and despues["ascenso_minutos"] is None
        assert despues["destino_minutos"] == 49 and len(pedidos) == 2
        assert len(pedidos[-1][1]) == 1

        _sql(
            e,
            "UPDATE posicion_gps SET fecha_hora_posicion=now()-interval '31 seconds' "
            "WHERE id_viaje=$1",
            viaje,
        )
        assert http.get(ruta, headers=pasajero).json()["destino_minutos"] is None
        assert http.post(f"/api/viajes/{viaje}/finalizacion", headers=chofer).status_code == 200
        assert http.get(ruta, headers=pasajero).status_code == 404
    finally:
        get_settings.cache_clear()
