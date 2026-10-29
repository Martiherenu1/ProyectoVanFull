"""Cambiar la parada de una reserva (CU-005): POST /api/reservas/{id}/cambio-parada.

RN-020, con el modelo actual: «disponibilidad compatible» es que la parada nueva pertenezca al
recorrido del viaje; el lugar ya está ocupado en ese viaje y no se consume otro (Issue #242,
interpretación PENDIENTE DE VALIDACIÓN). Todo contra un PostgreSQL real.
"""

import asyncio
from itertools import count

import pytest

from app.core.security import crear_token
from tests._bd import base_migrada, cliente_api, consultar, ejecutar_sql

RESERVAS = "/api/reservas"
DISPONIBILIDAD = "/api/servicios/disponibilidad"
DIA = "2026-11-10"

_dni = count(7000)


def _uno(base: str, sql: str, *args):
    return asyncio.run(consultar(base, sql, *args))[0][0]


def _con(id_persona: int, roles: list[str]) -> dict[str, str]:
    return {"Authorization": f"Bearer {crear_token(id_persona, id_persona, roles)}"}


def _persona(base: str) -> int:
    id_persona = _uno(
        base,
        "INSERT INTO persona (nombre, apellido, dni) VALUES ('N', 'A', $1) RETURNING id_persona",
        str(next(_dni)),
    )
    asyncio.run(ejecutar_sql(base, "INSERT INTO pasajero (id_persona) VALUES ($1)", id_persona))
    return id_persona


@pytest.fixture(scope="module")
def entorno():
    with base_migrada() as base:
        servicio = _uno(
            base,
            "INSERT INTO servicio (tipo_servicio) VALUES ('UNIVERSITARIO') RETURNING id_servicio",
        )
        recorrido = _uno(base, "INSERT INTO recorrido DEFAULT VALUES RETURNING id_recorrido")
        # Tres paradas: órdenes 1, 2 y 3.
        for orden in (1, 2, 3):
            parada = _uno(
                base,
                "INSERT INTO parada (nombre_descripcion) VALUES ($1) RETURNING id_parada",
                f"Parada {orden}",
            )
            asyncio.run(
                ejecutar_sql(
                    base,
                    "INSERT INTO parada_recorrido (id_recorrido, orden, id_parada) "
                    "VALUES ($1, $2, $3)",
                    recorrido,
                    orden,
                    parada,
                )
            )

        def viaje(estado="programado", planificada=10) -> int:
            return _uno(
                base,
                "INSERT INTO viaje (id_servicio, id_recorrido, fecha, horario, sentido, estado, "
                "capacidad_planificada) "
                "VALUES ($1, $2, $3::text::date, TIME '07:30', 'IDA', $4, $5) RETURNING id_viaje",
                servicio,
                recorrido,
                DIA,
                estado,
                planificada,
            )

        with cliente_api(base) as http:
            yield {"base": base, "http": http, "viaje": viaje}


def _reserva(entorno, orden: int = 1, viaje: int | None = None) -> tuple[int, int, int]:
    """Un pasajero con una reserva consolidada en `orden`: (pasajero, viaje, reserva)."""
    ana = _persona(entorno["base"])
    viaje = viaje or entorno["viaje"]()
    creada = entorno["http"].post(
        RESERVAS,
        json={"id_viaje": viaje, "orden_parada": orden},
        headers=_con(ana, ["pasajero"]),
    )
    assert creada.status_code == 201, creada.text
    return ana, viaje, creada.json()["id_reserva"]


def _cambiar(entorno, id_persona: int, id_reserva: int, orden, roles=("pasajero",)):
    return entorno["http"].post(
        f"{RESERVAS}/{id_reserva}/cambio-parada",
        json={"orden_parada": orden},
        headers=_con(id_persona, list(roles)),
    )


def _orden_guardado(entorno, id_reserva: int) -> int:
    return _uno(
        entorno["base"], "SELECT orden_parada FROM reserva WHERE id_reserva = $1", id_reserva
    )


def _eventos(entorno, id_reserva: int) -> int:
    return _uno(
        entorno["base"],
        "SELECT count(*) FROM evento_operativo "
        "WHERE id_reserva = $1 AND tipo_evento = 'reserva_parada_cambiada'",
        id_reserva,
    )


# --- El camino feliz ----------------------------------------------------------------------


def test_cambia_la_parada_y_devuelve_la_reserva(entorno):
    ana, viaje, id_reserva = _reserva(entorno, orden=1)
    respuesta = _cambiar(entorno, ana, id_reserva, 3)
    assert respuesta.status_code == 200, respuesta.text
    cuerpo = respuesta.json()
    assert cuerpo["id_reserva"] == id_reserva
    assert cuerpo["orden_parada"] == 3
    # Lo demás de la reserva no cambia.
    assert cuerpo["id_viaje"] == viaje
    assert cuerpo["estado"] == "consolidada"
    assert cuerpo["id_pasajero"] == ana
    assert _orden_guardado(entorno, id_reserva) == 3


def test_el_cambio_se_ve_en_mis_reservas(entorno):
    ana, _, id_reserva = _reserva(entorno, orden=1)
    assert _cambiar(entorno, ana, id_reserva, 2).status_code == 200
    mias = entorno["http"].get("/api/pasajeros/me/reservas", headers=_con(ana, ["pasajero"]))
    assert [r["orden_parada"] for r in mias.json()] == [2]


def test_se_puede_cambiar_mas_de_una_vez(entorno):
    ana, _, id_reserva = _reserva(entorno, orden=1)
    assert _cambiar(entorno, ana, id_reserva, 2).status_code == 200
    assert _cambiar(entorno, ana, id_reserva, 3).status_code == 200
    assert _cambiar(entorno, ana, id_reserva, 1).status_code == 200
    assert _orden_guardado(entorno, id_reserva) == 1
    assert _eventos(entorno, id_reserva) == 3


def test_no_consume_ni_libera_ningun_lugar_del_viaje(entorno):
    """La reserva ya ocupa su lugar: cambiar de parada no mueve el cupo del viaje."""
    viaje = entorno["viaje"](planificada=5)
    ana, _, id_reserva = _reserva(entorno, viaje=viaje)

    def cupo() -> int:
        respuesta = entorno["http"].get(DISPONIBILIDAD, params={"fecha": DIA, "sentido": "IDA"})
        return next(v["cupo_disponible"] for v in respuesta.json() if v["id_viaje"] == viaje)

    antes = cupo()
    assert _cambiar(entorno, ana, id_reserva, 2).status_code == 200
    assert cupo() == antes == 4


def test_registra_un_evento_operativo_de_la_reserva(entorno):
    ana, _, id_reserva = _reserva(entorno)
    assert _eventos(entorno, id_reserva) == 0
    assert _cambiar(entorno, ana, id_reserva, 2).status_code == 200
    assert _eventos(entorno, id_reserva) == 1


# --- A1: sin disponibilidad compatible, la parada original se conserva ---------------------


@pytest.mark.parametrize("orden", [4, 99])
def test_una_parada_que_no_es_del_recorrido_se_rechaza_y_conserva_la_original(entorno, orden):
    ana, _, id_reserva = _reserva(entorno, orden=2)
    respuesta = _cambiar(entorno, ana, id_reserva, orden)
    assert respuesta.status_code == 400
    error = respuesta.json()["error"]
    assert error["codigo"] == "PARADA_NO_VALIDA"
    assert error["detalles"]["orden_parada"] == orden
    assert _orden_guardado(entorno, id_reserva) == 2
    assert _eventos(entorno, id_reserva) == 0


def test_pedir_la_parada_que_ya_tiene_es_un_conflicto(entorno):
    ana, _, id_reserva = _reserva(entorno, orden=2)
    respuesta = _cambiar(entorno, ana, id_reserva, 2)
    assert respuesta.status_code == 409
    assert respuesta.json()["error"]["codigo"] == "PARADA_SIN_CAMBIOS"
    assert _eventos(entorno, id_reserva) == 0


def test_una_reserva_cancelada_no_cambia_de_parada(entorno):
    ana, _, id_reserva = _reserva(entorno, orden=1)
    cancelada = entorno["http"].post(
        f"{RESERVAS}/{id_reserva}/cancelacion", headers=_con(ana, ["pasajero"])
    )
    assert cancelada.status_code == 200
    respuesta = _cambiar(entorno, ana, id_reserva, 2)
    assert respuesta.status_code == 409
    assert respuesta.json()["error"]["codigo"] == "RESERVA_NO_MODIFICABLE"
    assert _orden_guardado(entorno, id_reserva) == 1


@pytest.mark.parametrize("estado", ["en_curso", "finalizado", "cancelado"])
def test_un_viaje_que_ya_no_esta_programado_no_admite_el_cambio(entorno, estado):
    ana, viaje, id_reserva = _reserva(entorno, orden=1)
    asyncio.run(
        ejecutar_sql(
            entorno["base"], "UPDATE viaje SET estado = $1 WHERE id_viaje = $2", estado, viaje
        )
    )
    respuesta = _cambiar(entorno, ana, id_reserva, 2)
    assert respuesta.status_code == 409
    assert respuesta.json()["error"]["codigo"] == "VIAJE_NO_MODIFICABLE"
    assert _orden_guardado(entorno, id_reserva) == 1


# --- Quién puede ----------------------------------------------------------------------------


def test_la_reserva_de_otro_pasajero_o_inexistente_responde_igual(entorno):
    ana, _, id_reserva = _reserva(entorno, orden=1)
    beto = _persona(entorno["base"])
    ajena = _cambiar(entorno, beto, id_reserva, 2)
    inexistente = _cambiar(entorno, beto, 999999, 2)
    assert ajena.status_code == inexistente.status_code == 404
    assert ajena.json()["error"]["codigo"] == "RESERVA_NO_ENCONTRADA"
    assert ajena.json()["error"]["codigo"] == inexistente.json()["error"]["codigo"]
    assert _orden_guardado(entorno, id_reserva) == 1


def test_sin_token_es_401(entorno):
    respuesta = entorno["http"].post(f"{RESERVAS}/1/cambio-parada", json={"orden_parada": 2})
    assert respuesta.status_code == 401


@pytest.mark.parametrize("rol", ["chofer", "administrador", "dueno"])
def test_solo_el_pasajero_cambia_la_parada(entorno, rol):
    ana, _, id_reserva = _reserva(entorno, orden=1)
    respuesta = _cambiar(entorno, ana, id_reserva, 2, roles=(rol,))
    assert respuesta.status_code == 403
    assert _orden_guardado(entorno, id_reserva) == 1


@pytest.mark.parametrize(
    "cuerpo",
    [{}, {"orden_parada": 0}, {"orden_parada": -1}, {"orden_parada": "dos"}],
    ids=["vacio", "cero", "negativo", "texto"],
)
def test_un_cuerpo_invalido_es_400(entorno, cuerpo):
    ana, _, id_reserva = _reserva(entorno, orden=1)
    respuesta = entorno["http"].post(
        f"{RESERVAS}/{id_reserva}/cambio-parada", json=cuerpo, headers=_con(ana, ["pasajero"])
    )
    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "VALIDACION"
    assert _orden_guardado(entorno, id_reserva) == 1
