"""Crear una reserva (CU-003): POST /api/reservas, para el pasajero ocasional.

Cubre el flujo de CU-003 v1.3 menos la tarifa (paso 5, #9): RN-031 (paso 3 y A2), RN-001 (paso 4 y
A1), el respaldo, el estado y el evento. Todo contra un PostgreSQL real.
"""

import asyncio
from concurrent.futures import ThreadPoolExecutor
from itertools import count

import pytest

from app.core.security import crear_token
from tests._bd import base_migrada, cliente_api, consultar, ejecutar_sql

RESERVAS = "/api/reservas"
MIS_RESERVAS = "/api/pasajeros/me/reservas"
DISPONIBILIDAD = "/api/servicios/disponibilidad"
DIA = "2026-11-10"

_dni = count(100)


def _uno(base: str, sql: str, *args):
    return asyncio.run(consultar(base, sql, *args))[0][0]


def _cuantos(base: str, sql: str, *args) -> int:
    return _uno(base, sql, *args)


def _con(id_persona: int, roles: list[str]) -> dict[str, str]:
    return {"Authorization": f"Bearer {crear_token(id_persona, id_persona, roles)}"}


def _persona(base: str, *, pasajero: bool = True) -> int:
    id_persona = _uno(
        base,
        "INSERT INTO persona (nombre, apellido, dni) VALUES ('N', 'A', $1) RETURNING id_persona",
        str(next(_dni)),
    )
    if pasajero:
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
        for orden, nombre in ((1, "Plaza"), (2, "Obelisco")):
            parada = _uno(
                base,
                "INSERT INTO parada (nombre_descripcion) VALUES ($1) RETURNING id_parada",
                nombre,
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

        def vehiculo(patente: str, capacidad: int) -> int:
            return _uno(
                base,
                "INSERT INTO vehiculo (patente, capacidad) VALUES ($1, $2) RETURNING id_vehiculo",
                patente,
                capacidad,
            )

        def viaje(
            sentido="IDA", fecha=DIA, estado="programado", vehiculo_id=None, planificada=10
        ) -> int:
            return _uno(
                base,
                "INSERT INTO viaje (id_servicio, id_recorrido, id_vehiculo, fecha, horario, "
                "sentido, estado, capacidad_planificada) "
                "VALUES ($1, $2, $3, $4::text::date, TIME '07:30', $5, $6, $7) RETURNING id_viaje",
                servicio,
                recorrido,
                vehiculo_id,
                fecha,
                sentido,
                estado,
                planificada,
            )

        with cliente_api(base) as http:
            yield {
                "base": base,
                "http": http,
                "servicio": servicio,
                "recorrido": recorrido,
                "viaje": viaje,
                "vehiculo": vehiculo,
            }


def _reservar(entorno, id_persona: int, id_viaje: int, orden_parada: int = 1, roles=("pasajero",)):
    return entorno["http"].post(
        RESERVAS,
        json={"id_viaje": id_viaje, "orden_parada": orden_parada},
        headers=_con(id_persona, list(roles)),
    )


def _nuevo_pasajero(entorno) -> int:
    return _persona(entorno["base"])


# --- El camino feliz ----------------------------------------------------------------------


def test_crea_la_reserva_consolidada_con_los_datos_del_viaje(entorno):
    ana, viaje = _nuevo_pasajero(entorno), entorno["viaje"]()
    respuesta = _reservar(entorno, ana, viaje, orden_parada=2)
    assert respuesta.status_code == 201, respuesta.text
    cuerpo = respuesta.json()
    # El ocasional no necesita aprobación (AC7-02) y su lugar queda garantizado (#33).
    assert cuerpo["estado"] == "consolidada"
    assert cuerpo["id_pasajero"] == ana
    assert (cuerpo["id_viaje"], cuerpo["orden_parada"]) == (viaje, 2)
    assert (cuerpo["fecha"], cuerpo["horario"], cuerpo["sentido"]) == (DIA, "07:30", "IDA")
    assert cuerpo["id_recorrido"] == entorno["recorrido"]
    # Solo los campos del schema `Reserva` del contrato.
    assert set(cuerpo) == {
        "id_reserva",
        "id_pasajero",
        "id_viaje",
        "id_recorrido",
        "orden_parada",
        "fecha",
        "horario",
        "sentido",
        "estado",
    }


def test_el_respaldo_es_una_contratacion_directa_del_cliente_individual(entorno):
    """MR-R13: contratación directa XOR período de abono. Un ocasional no tiene abono."""
    base = entorno["base"]
    ana, viaje = _nuevo_pasajero(entorno), entorno["viaje"]()
    id_reserva = _reservar(entorno, ana, viaje).json()["id_reserva"]
    periodo, contratacion = asyncio.run(
        consultar(
            base,
            "SELECT id_periodo_abono, id_contratacion_directa FROM reserva WHERE id_reserva = $1",
            id_reserva,
        )
    )[0]
    assert periodo is None and contratacion is not None
    # La contratación es del cliente individual de Ana y del servicio del viaje; sin tarifa (#9).
    cliente, servicio, tarifa, importe = asyncio.run(
        consultar(
            base,
            "SELECT c.id_cliente, c.id_servicio, c.id_tarifa, c.importe_acordado "
            "FROM contratacion c WHERE c.id_contratacion = $1",
            contratacion,
        )
    )[0]
    assert servicio == entorno["servicio"] and tarifa is None and importe is None
    assert (
        _uno(base, "SELECT id_persona FROM cliente_individual WHERE id_cliente = $1", cliente)
        == ana
    )


def test_registra_un_evento_operativo_de_la_reserva(entorno):
    ana, viaje = _nuevo_pasajero(entorno), entorno["viaje"]()
    id_reserva = _reservar(entorno, ana, viaje).json()["id_reserva"]
    tipo = _uno(
        entorno["base"],
        "SELECT tipo_evento FROM evento_operativo WHERE id_reserva = $1",
        id_reserva,
    )
    assert tipo == "reserva_creada"


def test_el_cliente_individual_se_crea_una_sola_vez(entorno):
    base = entorno["base"]
    ana = _nuevo_pasajero(entorno)
    assert _reservar(entorno, ana, entorno["viaje"](fecha="2026-11-11")).status_code == 201
    assert _reservar(entorno, ana, entorno["viaje"](fecha="2026-11-12")).status_code == 201
    assert _cuantos(base, "SELECT count(*) FROM cliente_individual WHERE id_persona = $1", ana) == 1


def test_la_reserva_aparece_en_mis_reservas_y_baja_el_cupo_que_se_consulta(entorno):
    """Lo que ve el pasajero al consultar y lo que el backend valida al reservar es lo mismo."""
    ana, viaje = _nuevo_pasajero(entorno), entorno["viaje"](fecha="2026-11-13", planificada=4)
    http = entorno["http"]

    def cupo():
        r = http.get(DISPONIBILIDAD, params={"fecha": "2026-11-13", "sentido": "IDA"})
        return {d["id_viaje"]: d["cupo_disponible"] for d in r.json()}[viaje]

    assert cupo() == 4
    id_reserva = _reservar(entorno, ana, viaje).json()["id_reserva"]
    assert cupo() == 3
    propias = http.get(MIS_RESERVAS, headers=_con(ana, ["pasajero"])).json()
    assert [r["id_reserva"] for r in propias] == [id_reserva]


# --- RN-031: una ida y una vuelta por día -------------------------------------------------


def test_una_ida_y_una_vuelta_el_mismo_dia_son_compatibles(entorno):
    """A2 de CU-003."""
    ana = _nuevo_pasajero(entorno)
    ida, vuelta = entorno["viaje"]("IDA", "2026-11-14"), entorno["viaje"]("VUELTA", "2026-11-14")
    assert _reservar(entorno, ana, ida).status_code == 201
    assert _reservar(entorno, ana, vuelta).status_code == 201


@pytest.mark.parametrize("mismo_viaje", [True, False], ids=["mismo_viaje", "otro_viaje_del_dia"])
def test_una_segunda_reserva_del_mismo_sentido_y_dia_se_rechaza(entorno, mismo_viaje):
    base = entorno["base"]
    ana, primera = _nuevo_pasajero(entorno), entorno["viaje"](fecha="2026-11-15")
    segunda = primera if mismo_viaje else entorno["viaje"](fecha="2026-11-15")
    assert _reservar(entorno, ana, primera).status_code == 201

    respuesta = _reservar(entorno, ana, segunda)
    assert respuesta.status_code == 409
    error = respuesta.json()["error"]
    assert error["codigo"] == "RESERVA_DUPLICADA_DEL_DIA"
    assert error["detalles"] == {"fecha": "2026-11-15", "sentido": "IDA"}
    assert _cuantos(base, "SELECT count(*) FROM reserva WHERE id_pasajero = $1", ana) == 1


def test_una_reserva_cancelada_no_cuenta_para_el_limite_del_dia(entorno):
    base = entorno["base"]
    ana, vieja = _nuevo_pasajero(entorno), entorno["viaje"](fecha="2026-11-16")
    assert _reservar(entorno, ana, vieja).status_code == 201
    asyncio.run(
        ejecutar_sql(base, "UPDATE reserva SET estado = 'cancelada' WHERE id_pasajero = $1", ana)
    )
    assert _reservar(entorno, ana, entorno["viaje"](fecha="2026-11-16")).status_code == 201


def test_una_reserva_cancelada_del_mismo_viaje_no_se_pisa_en_silencio(entorno):
    """MR-R15 deja una fila por pasajero y viaje; reactivarla no está definido (AC28-08)."""
    base = entorno["base"]
    ana, viaje = _nuevo_pasajero(entorno), entorno["viaje"](fecha="2026-11-17")
    assert _reservar(entorno, ana, viaje).status_code == 201
    asyncio.run(
        ejecutar_sql(base, "UPDATE reserva SET estado = 'cancelada' WHERE id_pasajero = $1", ana)
    )
    respuesta = _reservar(entorno, ana, viaje)
    assert respuesta.status_code == 409
    assert respuesta.json()["error"]["codigo"] == "RESERVA_CANCELADA_PREVIA"


# --- RN-001 / RN-002: el cupo -------------------------------------------------------------


def _viaje_de_un_lugar(entorno, fecha: str) -> int:
    return entorno["viaje"](fecha=fecha, vehiculo_id=entorno["vehiculo"](f"T{next(_dni)}", 1))


def test_sin_cupo_no_hay_reserva_y_se_informa_la_lista_de_espera(entorno):
    """A1 de CU-003. Nada queda a medias: ni contratación ni cliente."""
    base = entorno["base"]
    viaje = _viaje_de_un_lugar(entorno, "2026-11-18")
    ana, beto = _nuevo_pasajero(entorno), _nuevo_pasajero(entorno)
    assert _reservar(entorno, ana, viaje).status_code == 201

    respuesta = _reservar(entorno, beto, viaje)
    assert respuesta.status_code == 409
    error = respuesta.json()["error"]
    assert error["codigo"] == "CUPO_NO_DISPONIBLE"
    assert error["detalles"] == {"lista_espera": True}
    assert _cuantos(base, "SELECT count(*) FROM reserva WHERE id_pasajero = $1", beto) == 0
    assert (
        _cuantos(base, "SELECT count(*) FROM cliente_individual WHERE id_persona = $1", beto) == 0
    )


def test_una_reserva_provisional_no_ocupa_el_lugar(entorno):
    """RN-002: solo la consolidada ocupa cupo."""
    base = entorno["base"]
    viaje = _viaje_de_un_lugar(entorno, "2026-11-19")
    otro, beto = _nuevo_pasajero(entorno), _nuevo_pasajero(entorno)
    cliente = _uno(
        base, "INSERT INTO cliente (naturaleza_cliente) VALUES ('INDIVIDUAL') RETURNING id_cliente"
    )
    contratacion = _uno(
        base,
        "INSERT INTO contratacion (id_cliente, id_servicio) VALUES ($1, $2) "
        "RETURNING id_contratacion",
        cliente,
        entorno["servicio"],
    )
    asyncio.run(
        ejecutar_sql(
            base,
            "INSERT INTO reserva (id_pasajero, id_viaje, id_recorrido, orden_parada, "
            "id_contratacion_directa, estado) VALUES ($1, $2, $3, 1, $4, 'provisional')",
            otro,
            viaje,
            entorno["recorrido"],
            contratacion,
        )
    )
    assert _reservar(entorno, beto, viaje).status_code == 201


def test_la_ausencia_informada_libera_el_lugar_para_otro_pasajero(entorno):
    """AC28-06 / PT28-10: el lugar liberado lo puede tomar cualquier pasajero habilitado."""
    base = entorno["base"]
    viaje = _viaje_de_un_lugar(entorno, "2026-11-20")
    ana, beto = _nuevo_pasajero(entorno), _nuevo_pasajero(entorno)
    assert _reservar(entorno, ana, viaje).status_code == 201
    assert _reservar(entorno, beto, viaje).status_code == 409

    asyncio.run(
        ejecutar_sql(
            base, "INSERT INTO ausencia (id_pasajero, id_viaje) VALUES ($1, $2)", ana, viaje
        )
    )
    assert _reservar(entorno, beto, viaje).status_code == 201


def test_dos_pasajeros_por_el_ultimo_lugar_solo_uno_lo_obtiene(entorno):
    """PV28-08: el bloqueo del viaje evita vender dos veces el mismo lugar."""
    base = entorno["base"]
    viaje = _viaje_de_un_lugar(entorno, "2026-11-21")
    pasajeros = [_nuevo_pasajero(entorno) for _ in range(4)]
    with ThreadPoolExecutor(max_workers=4) as pool:
        codigos = list(pool.map(lambda p: _reservar(entorno, p, viaje).status_code, pasajeros))
    assert sorted(codigos) == [201, 409, 409, 409]
    consolidadas = _cuantos(
        base, "SELECT count(*) FROM reserva WHERE id_viaje = $1 AND estado = 'consolidada'", viaje
    )
    assert consolidadas == 1


# --- Viaje y parada -----------------------------------------------------------------------


def test_un_viaje_inexistente_es_404(entorno):
    respuesta = _reservar(entorno, _nuevo_pasajero(entorno), 999999)
    assert respuesta.status_code == 404
    assert respuesta.json()["error"]["codigo"] == "VIAJE_NO_ENCONTRADO"


@pytest.mark.parametrize("estado", ["cancelado", "en_curso", "finalizado"])
def test_un_viaje_que_no_esta_programado_no_admite_reservas(entorno, estado):
    """Reservar en `en_curso` (AC28-04) necesita saber qué paradas se alcanzaron: no se implementa."""
    viaje = entorno["viaje"](fecha="2026-11-22", estado=estado)
    respuesta = _reservar(entorno, _nuevo_pasajero(entorno), viaje)
    assert respuesta.status_code == 409
    assert respuesta.json()["error"]["codigo"] == "VIAJE_NO_RESERVABLE"


def test_un_viaje_programado_cuya_hora_ya_paso_admite_reservas(entorno):
    """AC28-05: el reloj no cierra el viaje."""
    viaje = entorno["viaje"](fecha="2020-01-02")
    assert _reservar(entorno, _nuevo_pasajero(entorno), viaje).status_code == 201


def test_una_parada_que_no_es_del_recorrido_se_rechaza(entorno):
    base = entorno["base"]
    ana, viaje = _nuevo_pasajero(entorno), entorno["viaje"](fecha="2026-11-23")
    respuesta = _reservar(entorno, ana, viaje, orden_parada=7)
    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "PARADA_NO_VALIDA"
    assert _cuantos(base, "SELECT count(*) FROM reserva WHERE id_pasajero = $1", ana) == 0


@pytest.mark.parametrize(
    "cuerpo",
    [{}, {"id_viaje": 1}, {"orden_parada": 1}, {"id_viaje": 1, "orden_parada": 0}],
    ids=["vacio", "sin_parada", "sin_viaje", "parada_cero"],
)
def test_un_cuerpo_invalido_es_400(entorno, cuerpo):
    ana = _nuevo_pasajero(entorno)
    respuesta = entorno["http"].post(RESERVAS, json=cuerpo, headers=_con(ana, ["pasajero"]))
    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "VALIDACION"


# --- Acceso -------------------------------------------------------------------------------


def test_sin_token_es_401(entorno):
    respuesta = entorno["http"].post(RESERVAS, json={"id_viaje": 1, "orden_parada": 1})
    assert respuesta.status_code == 401


def test_un_rol_que_no_es_pasajero_es_403(entorno):
    chofer = _persona(entorno["base"], pasajero=False)
    respuesta = _reservar(entorno, chofer, entorno["viaje"](), roles=("chofer",))
    assert respuesta.status_code == 403


def test_una_cuenta_con_rol_pasajero_sin_fila_de_pasajero_es_404(entorno):
    sin_fila = _persona(entorno["base"], pasajero=False)
    respuesta = _reservar(entorno, sin_fila, entorno["viaje"]())
    assert respuesta.status_code == 404
    assert respuesta.json()["error"]["codigo"] == "PASAJERO_NO_ENCONTRADO"
