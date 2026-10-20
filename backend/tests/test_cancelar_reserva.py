"""Cancelar una reserva (CU-004): POST /api/reservas/{id}/cancelacion.

Cubre el estado, el lugar que vuelve al viaje, el evento y el motivo de la consecuencia económica
(RN-007, RN-017, RN-018). El crédito de RN-017 no se otorga: no hay dónde guardarlo (Issue #74).
Todo contra un PostgreSQL real.
"""

import asyncio
from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, date, datetime
from itertools import count
from types import SimpleNamespace

import pytest

from app.core.security import crear_token
from app.services.reservas import ZONA_ARGENTINA, _en_termino, _motivo
from tests._bd import base_migrada, cliente_api, consultar, ejecutar_sql

RESERVAS = "/api/reservas"
MIS_RESERVAS = "/api/pasajeros/me/reservas"
DIA = "2026-11-10"

_dni = count(5000)


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
        servicios = {
            tipo: _uno(
                base,
                "INSERT INTO servicio (tipo_servicio) VALUES ($1) RETURNING id_servicio",
                tipo,
            )
            for tipo in ("UNIVERSITARIO", "ESPECIAL")
        }
        recorrido = _uno(base, "INSERT INTO recorrido DEFAULT VALUES RETURNING id_recorrido")
        parada = _uno(
            base, "INSERT INTO parada (nombre_descripcion) VALUES ('Plaza') RETURNING id_parada"
        )
        asyncio.run(
            ejecutar_sql(
                base,
                "INSERT INTO parada_recorrido (id_recorrido, orden, id_parada) VALUES ($1, 1, $2)",
                recorrido,
                parada,
            )
        )

        def viaje(fecha=DIA, estado="programado", planificada=10, tipo="UNIVERSITARIO") -> int:
            return _uno(
                base,
                "INSERT INTO viaje (id_servicio, id_recorrido, fecha, horario, sentido, estado, "
                "capacidad_planificada) "
                "VALUES ($1, $2, $3::text::date, TIME '07:30', 'IDA', $4, $5) RETURNING id_viaje",
                servicios[tipo],
                recorrido,
                fecha,
                estado,
                planificada,
            )

        with cliente_api(base) as http:
            yield {
                "base": base,
                "http": http,
                "recorrido": recorrido,
                "viaje": viaje,
                "servicios": servicios,
            }


def _reservar(entorno, id_persona: int, id_viaje: int):
    return entorno["http"].post(
        RESERVAS,
        json={"id_viaje": id_viaje, "orden_parada": 1},
        headers=_con(id_persona, ["pasajero"]),
    )


def _cancelar(entorno, id_persona: int, id_reserva: int, roles=("pasajero",)):
    return entorno["http"].post(
        f"{RESERVAS}/{id_reserva}/cancelacion", headers=_con(id_persona, list(roles))
    )


def _reserva_creada(entorno, viaje: int | None = None) -> tuple[int, int, int]:
    """Un pasajero con una reserva consolidada: (pasajero, viaje, reserva)."""
    ana = _persona(entorno["base"])
    viaje = viaje or entorno["viaje"]()
    return ana, viaje, _reservar(entorno, ana, viaje).json()["id_reserva"]


def _estado(entorno, id_reserva: int) -> str:
    return _uno(entorno["base"], "SELECT estado FROM reserva WHERE id_reserva = $1", id_reserva)


# --- El camino feliz ----------------------------------------------------------------------


def test_cancela_la_reserva_y_devuelve_el_resultado(entorno):
    ana, viaje, id_reserva = _reserva_creada(entorno)
    respuesta = _cancelar(entorno, ana, id_reserva)
    assert respuesta.status_code == 200, respuesta.text
    cuerpo = respuesta.json()
    assert set(cuerpo) == {
        "reserva",
        "cupo_liberado",
        "penalidad_aplicada",
        "importe_penalidad",
        "motivo",
    }
    assert cuerpo["reserva"]["id_reserva"] == id_reserva
    assert cuerpo["reserva"]["estado"] == "cancelada"
    assert (cuerpo["reserva"]["id_viaje"], cuerpo["reserva"]["fecha"]) == (viaje, DIA)
    assert cuerpo["cupo_liberado"] is True
    # Todavía no se aplica ninguna consecuencia económica (Issue #74).
    assert cuerpo["penalidad_aplicada"] is False
    assert cuerpo["importe_penalidad"] == 0
    assert _estado(entorno, id_reserva) == "cancelada"


def test_registra_un_evento_operativo_de_la_reserva(entorno):
    ana, _, id_reserva = _reserva_creada(entorno)
    _cancelar(entorno, ana, id_reserva)
    tipos = asyncio.run(
        consultar(
            entorno["base"],
            "SELECT tipo_evento FROM evento_operativo WHERE id_reserva = $1 ORDER BY 1",
            id_reserva,
        )
    )
    assert [t[0] for t in tipos] == ["reserva_cancelada", "reserva_creada"]


def test_la_reserva_cancelada_sigue_en_mis_reservas_con_su_estado(entorno):
    ana, _, id_reserva = _reserva_creada(entorno)
    _cancelar(entorno, ana, id_reserva)
    mias = entorno["http"].get(MIS_RESERVAS, headers=_con(ana, ["pasajero"])).json()
    assert [(r["id_reserva"], r["estado"]) for r in mias] == [(id_reserva, "cancelada")]


# --- El lugar vuelve al viaje -------------------------------------------------------------


def test_el_lugar_cancelado_lo_puede_tomar_otro_pasajero(entorno):
    """RN-001: lo que libera la cancelación es lo mismo que cuenta la reserva (`cupo_del_viaje`)."""
    viaje = entorno["viaje"](fecha="2026-11-20", planificada=1)
    ana, bruno = _persona(entorno["base"]), _persona(entorno["base"])
    id_reserva = _reservar(entorno, ana, viaje).json()["id_reserva"]
    assert _reservar(entorno, bruno, viaje).status_code == 409
    assert _cancelar(entorno, ana, id_reserva).json()["cupo_liberado"] is True
    assert _reservar(entorno, bruno, viaje).status_code == 201


def _reserva_en_sql(entorno, pasajero: int, viaje: int, estado: str) -> int:
    base = entorno["base"]
    cliente = _uno(
        base, "INSERT INTO cliente (naturaleza_cliente) VALUES ('INDIVIDUAL') RETURNING id_cliente"
    )
    contratacion = _uno(
        base,
        "INSERT INTO contratacion (id_cliente, id_servicio) VALUES ($1, $2) RETURNING id_contratacion",
        cliente,
        entorno["servicios"]["UNIVERSITARIO"],
    )
    return _uno(
        base,
        "INSERT INTO reserva (id_pasajero, id_viaje, id_recorrido, orden_parada, "
        "id_contratacion_directa, estado) VALUES ($1, $2, $3, 1, $4, $5) RETURNING id_reserva",
        pasajero,
        viaje,
        entorno["recorrido"],
        contratacion,
        estado,
    )


def test_una_reserva_provisional_no_ocupaba_lugar_asi_que_no_lo_libera(entorno):
    """RN-002: solo la consolidada ocupa cupo."""
    ana, viaje = _persona(entorno["base"]), entorno["viaje"](fecha="2026-11-21")
    id_reserva = _reserva_en_sql(entorno, ana, viaje, "provisional")
    cuerpo = _cancelar(entorno, ana, id_reserva).json()
    assert cuerpo["reserva"]["estado"] == "cancelada"
    assert cuerpo["cupo_liberado"] is False


def test_quien_ya_aviso_su_ausencia_no_libera_otro_lugar(entorno):
    """AC28-06: la ausencia informada ya había liberado el lugar."""
    ana, viaje, id_reserva = _reserva_creada(entorno, entorno["viaje"](fecha="2026-11-22"))
    asyncio.run(
        ejecutar_sql(
            entorno["base"],
            "INSERT INTO ausencia (id_pasajero, id_viaje) VALUES ($1, $2)",
            ana,
            viaje,
        )
    )
    assert _cancelar(entorno, ana, id_reserva).json()["cupo_liberado"] is False


# --- Qué no se puede cancelar -------------------------------------------------------------


def test_una_reserva_ajena_es_404_y_no_se_toca(entorno):
    """Un recurso ajeno responde como uno inexistente (CONVENCIONES §3)."""
    _, _, id_reserva = _reserva_creada(entorno)
    intruso = _persona(entorno["base"])
    respuesta = _cancelar(entorno, intruso, id_reserva)
    assert respuesta.status_code == 404
    assert respuesta.json()["error"]["codigo"] == "RESERVA_NO_ENCONTRADA"
    assert _estado(entorno, id_reserva) == "consolidada"


def test_una_reserva_inexistente_es_404(entorno):
    respuesta = _cancelar(entorno, _persona(entorno["base"]), 999999)
    assert respuesta.status_code == 404
    assert respuesta.json()["error"]["codigo"] == "RESERVA_NO_ENCONTRADA"


def test_cancelar_dos_veces_es_409(entorno):
    ana, _, id_reserva = _reserva_creada(entorno)
    assert _cancelar(entorno, ana, id_reserva).status_code == 200
    segunda = _cancelar(entorno, ana, id_reserva)
    assert segunda.status_code == 409
    assert segunda.json()["error"]["codigo"] == "RESERVA_NO_CANCELABLE"


@pytest.mark.parametrize("estado", ["en_curso", "finalizado", "cancelado"])
def test_si_el_viaje_ya_no_esta_programado_no_se_cancela(entorno, estado):
    ana, viaje, id_reserva = _reserva_creada(entorno)
    asyncio.run(
        ejecutar_sql(
            entorno["base"], "UPDATE viaje SET estado = $1 WHERE id_viaje = $2", estado, viaje
        )
    )
    respuesta = _cancelar(entorno, ana, id_reserva)
    assert respuesta.status_code == 409
    assert respuesta.json()["error"]["codigo"] == "VIAJE_NO_CANCELABLE"
    assert _estado(entorno, id_reserva) == "consolidada"


def test_dos_cancelaciones_simultaneas_solo_una_prospera(entorno):
    ana, _, id_reserva = _reserva_creada(entorno)
    with ThreadPoolExecutor(max_workers=4) as pool:
        codigos = list(
            pool.map(lambda _: _cancelar(entorno, ana, id_reserva).status_code, range(4))
        )
    assert sorted(codigos) == [200, 409, 409, 409]
    eventos = _uno(
        entorno["base"],
        "SELECT count(*) FROM evento_operativo WHERE id_reserva = $1 AND tipo_evento = 'reserva_cancelada'",
        id_reserva,
    )
    assert eventos == 1


# --- Autenticación ------------------------------------------------------------------------


def test_sin_token_es_401(entorno):
    assert entorno["http"].post(f"{RESERVAS}/1/cancelacion").status_code == 401


def test_un_rol_que_no_es_pasajero_es_403(entorno):
    ana, _, id_reserva = _reserva_creada(entorno)
    assert _cancelar(entorno, ana, id_reserva, roles=("chofer",)).status_code == 403
    assert _estado(entorno, id_reserva) == "consolidada"


# --- El motivo ----------------------------------------------------------------------------


def test_un_ocasional_en_termino_dice_que_corresponderia_el_credito(entorno):
    ana, _, id_reserva = _reserva_creada(entorno)
    motivo = _cancelar(entorno, ana, id_reserva).json()["motivo"]
    assert "RN-017" in motivo and "en término" in motivo and "todavía no se otorga" in motivo


def test_un_ocasional_fuera_de_termino_no_se_bloquea_pero_lo_dice(entorno):
    """La ventana de RN-017 solo decide el crédito: cancelar el mismo día se puede."""
    hoy = datetime.now(ZONA_ARGENTINA).date().isoformat()
    ana, _, id_reserva = _reserva_creada(entorno, entorno["viaje"](fecha=hoy))
    respuesta = _cancelar(entorno, ana, id_reserva)
    assert respuesta.status_code == 200
    assert "fuera del término" in respuesta.json()["motivo"]


def test_un_servicio_especial_remite_a_rn_018(entorno):
    ana, _, id_reserva = _reserva_creada(
        entorno, entorno["viaje"](fecha="2026-11-23", tipo="ESPECIAL")
    )
    motivo = _cancelar(entorno, ana, id_reserva).json()["motivo"]
    assert "RN-018" in motivo


def test_un_abono_no_genera_credito_ni_devolucion():
    """RN-007. Sin base: el respaldo por abono no se crea todavía, se prueba la regla sola."""
    reserva = SimpleNamespace(id_periodo_abono=7)
    motivo = _motivo(reserva, "UNIVERSITARIO", date(2026, 11, 10), datetime.now(ZONA_ARGENTINA))
    assert "RN-007" in motivo


@pytest.mark.parametrize(
    ("hora", "minuto", "esperado"),
    [(17, 59, True), (18, 0, False), (18, 1, False)],
)
def test_el_limite_es_las_18_del_dia_anterior(hora, minuto, esperado):
    ahora = datetime(2026, 11, 9, hora, minuto, tzinfo=ZONA_ARGENTINA)
    assert _en_termino(date(2026, 11, 10), ahora) is esperado


def test_el_limite_se_mide_en_hora_argentina_no_en_utc():
    # 20:30 UTC del 9 son las 17:30 en Argentina: todavía en término.
    ahora = datetime(2026, 11, 9, 20, 30, tzinfo=UTC)
    assert _en_termino(date(2026, 11, 10), ahora) is True
