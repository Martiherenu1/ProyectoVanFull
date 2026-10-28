"""Servicios, disponibilidad y paradas (CU-002) contra un PostgreSQL real."""

import asyncio
from pathlib import Path

import pytest
import yaml

from app.services.disponibilidad import CAPACIDAD_PREDETERMINADA, cupo_disponible
from tests._bd import base_migrada, cliente_api, consultar, ejecutar_sql

CONTRATO = Path(__file__).resolve().parents[1] / "openapi" / "openapi.yaml"
FECHA = "2026-10-30"
DISPONIBILIDAD = "/api/servicios/disponibilidad"


# --- La regla del cupo, sin base --------------------------------------------------------------


@pytest.mark.parametrize(
    ("vehiculo", "planificada", "ocupados", "esperado"),
    [
        (19, None, 0, 19),  # capacidad de la unidad (RN-001)
        (19, None, 5, 14),
        (19, 10, 5, 14),  # con vehículo manda el vehículo, no la planificada (ADJ-03)
        (None, 10, 4, 6),  # sin vehículo, la planificada
        (None, None, 0, 19),  # sin ninguna: la predeterminada de 19 (AC28-02)
        (None, None, 12, 7),  # PT28-01 con la predeterminada
        (None, None, 19, 0),  # PT28-03: la vigésima reserva no entra
        (24, 19, 0, 24),  # PT28-04: prevalece la capacidad real de la unidad (AC28-03)
        (3, None, 3, 0),  # lleno
        (3, None, 5, 0),  # sobrevendido: nunca negativo
        (0, 10, 0, 0),  # un vehículo de capacidad 0 es capacidad 0, no "sin vehículo"
    ],
)
def test_calculo_del_cupo(vehiculo, planificada, ocupados, esperado):
    assert cupo_disponible(vehiculo, planificada, ocupados) == esperado


# --- Con base ---------------------------------------------------------------------------------


def _uno(base: str, sql: str, *args):
    return asyncio.run(consultar(base, sql, *args))[0][0]


def _viaje(
    base,
    servicio,
    recorrido,
    *,
    vehiculo=None,
    horario=None,
    estado="programado",
    sentido="IDA",
    fecha=FECHA,
    planificada=None,
):
    return _uno(
        base,
        "INSERT INTO viaje (id_servicio, id_recorrido, id_vehiculo, fecha, horario, sentido, "
        "estado, capacidad_planificada) VALUES ($1, $2, $3, $4::text::date, $5::text::time, $6, $7, $8) "
        "RETURNING id_viaje",
        servicio,
        recorrido,
        vehiculo,
        fecha,
        horario,
        sentido,
        estado,
        planificada,
    )


def _reserva(base, pasajero, viaje, recorrido, contratacion, estado):
    asyncio.run(
        ejecutar_sql(
            base,
            "INSERT INTO reserva (id_pasajero, id_viaje, id_recorrido, orden_parada, "
            "id_contratacion_directa, estado) VALUES ($1, $2, $3, 1, $4, $5)",
            pasajero,
            viaje,
            recorrido,
            contratacion,
            estado,
        )
    )


@pytest.fixture(scope="module")
def entorno():
    with base_migrada() as base:
        servicio = _uno(
            base,
            "INSERT INTO servicio (tipo_servicio) VALUES ('UNIVERSITARIO') RETURNING id_servicio",
        )
        asyncio.run(ejecutar_sql(base, "INSERT INTO servicio (tipo_servicio) VALUES ('LABORAL')"))

        # R1 con tres paradas (la 3 comprometida) y R2 sin paradas.
        r1 = _uno(base, "INSERT INTO recorrido DEFAULT VALUES RETURNING id_recorrido")
        r2 = _uno(base, "INSERT INTO recorrido DEFAULT VALUES RETURNING id_recorrido")
        paradas = []
        for n in (1, 2, 3):
            paradas.append(
                _uno(
                    base,
                    "INSERT INTO parada (nombre_descripcion, latitud, longitud) "
                    "VALUES ($1, -34.60 - $2::numeric / 100, -58.38) RETURNING id_parada",
                    f"Parada {n}",
                    n,
                )
            )
        # Se cargan en desorden para comprobar que la respuesta sale ordenada por `orden`.
        for orden, parada, comprometida in (
            (3, paradas[2], True),
            (1, paradas[0], False),
            (2, paradas[1], False),
        ):
            asyncio.run(
                ejecutar_sql(
                    base,
                    "INSERT INTO parada_recorrido (id_recorrido, orden, id_parada, comprometida) "
                    "VALUES ($1, $2, $3, $4)",
                    r1,
                    orden,
                    parada,
                    comprometida,
                )
            )

        v3 = _uno(
            base,
            "INSERT INTO vehiculo (patente, capacidad) VALUES ('AAA111', 3) RETURNING id_vehiculo",
        )
        v1 = _uno(
            base,
            "INSERT INTO vehiculo (patente, capacidad) VALUES ('BBB222', 1) RETURNING id_vehiculo",
        )

        cliente = _uno(
            base,
            "INSERT INTO cliente (naturaleza_cliente) VALUES ('INDIVIDUAL') RETURNING id_cliente",
        )
        contratacion = _uno(
            base,
            "INSERT INTO contratacion (id_cliente, id_servicio) VALUES ($1, $2) RETURNING id_contratacion",
            cliente,
            servicio,
        )
        pasajeros = []
        for n in range(1, 5):
            persona = _uno(
                base,
                "INSERT INTO persona (nombre, apellido, dni) VALUES ('P', 'P', $1) RETURNING id_persona",
                str(n),
            )
            asyncio.run(
                ejecutar_sql(base, "INSERT INTO pasajero (id_persona) VALUES ($1)", persona)
            )
            pasajeros.append(persona)

        viajes = {
            # 3 lugares; 1 consolidada, 1 provisional y 1 cancelada: ocupa un solo lugar.
            "con_reservas": _viaje(base, servicio, r1, vehiculo=v3, horario="07:30"),
            "planificado": _viaje(base, servicio, r1, horario="08:30", planificada=10),
            "sin_capacidad": _viaje(base, servicio, r1),
            "sobrevendido": _viaje(base, servicio, r1, vehiculo=v1, horario="09:00"),
            "otro_recorrido": _viaje(base, servicio, r2, horario="10:00", planificada=5),
            # No se ofrecen:
            "cancelado": _viaje(
                base, servicio, r1, horario="11:00", estado="cancelado", planificada=9
            ),
            "en_curso": _viaje(
                base, servicio, r1, horario="11:30", estado="en_curso", planificada=9
            ),
            "vuelta": _viaje(base, servicio, r1, horario="12:00", sentido="VUELTA", planificada=9),
            "otro_dia": _viaje(
                base, servicio, r1, horario="12:30", fecha="2026-10-31", planificada=9
            ),
        }
        v = viajes["con_reservas"]
        _reserva(base, pasajeros[0], v, r1, contratacion, "consolidada")
        _reserva(base, pasajeros[1], v, r1, contratacion, "provisional")
        _reserva(base, pasajeros[2], v, r1, contratacion, "cancelada")
        s = viajes["sobrevendido"]
        _reserva(base, pasajeros[0], s, r1, contratacion, "consolidada")
        _reserva(base, pasajeros[1], s, r1, contratacion, "consolidada")

        with cliente_api(base) as cliente_http:
            yield {
                "base": base,
                "servicio": servicio,
                "vehiculo_de_3": v3,
                "cliente": cliente_http,
                "viajes": viajes,
                "r1": r1,
                "r2": r2,
                "paradas": paradas,
                "pasajeros": pasajeros,
                "contratacion": contratacion,
            }


def _consultar(entorno, **params):
    return entorno["cliente"].get(
        DISPONIBILIDAD, params={"fecha": FECHA, "sentido": "IDA", **params}
    )


def _por_viaje(entorno, **params) -> dict[int, dict]:
    respuesta = _consultar(entorno, **params)
    assert respuesta.status_code == 200, respuesta.text
    return {d["id_viaje"]: d for d in respuesta.json()}


def test_ofrece_solo_los_viajes_programados_de_esa_fecha_y_sentido(entorno):
    v = entorno["viajes"]
    esperados = {
        v[k]
        for k in ("con_reservas", "planificado", "sin_capacidad", "sobrevendido", "otro_recorrido")
    }
    assert set(_por_viaje(entorno)) == esperados


def test_el_cupo_es_la_capacidad_de_la_unidad_menos_las_consolidadas(entorno):
    v = entorno["viajes"]
    por_viaje = _por_viaje(entorno)
    # 3 lugares - 1 consolidada. La provisional y la cancelada no ocupan (RN-002).
    assert por_viaje[v["con_reservas"]]["cupo_disponible"] == 2
    # Sin vehículo asignado: la capacidad planificada.
    assert por_viaje[v["planificado"]]["cupo_disponible"] == 10
    # Capacidad 1 y dos consolidadas: sobrevendido, no negativo.
    assert por_viaje[v["sobrevendido"]]["cupo_disponible"] == 0


def test_sin_unidad_ni_capacidad_planificada_rige_la_predeterminada(entorno):
    """AC28-02: VanFull identifica 19 como la capacidad mínima habitual de sus unidades."""
    sin_capacidad = _por_viaje(entorno)[entorno["viajes"]["sin_capacidad"]]
    assert sin_capacidad["cupo_disponible"] == CAPACIDAD_PREDETERMINADA == 19
    assert "horario" not in sin_capacidad  # el viaje no tiene horario: se omite, no va null


def test_el_cupo_es_derivado_cambia_solo_al_cambiar_las_reservas(entorno):
    """No hay ninguna columna de cupo: se recalcula en cada consulta (MR-R30)."""
    v = entorno["viajes"]["con_reservas"]
    antes = _por_viaje(entorno)[v]["cupo_disponible"]
    _reserva(
        entorno["base"],
        entorno["pasajeros"][3],
        v,
        entorno["r1"],
        entorno["contratacion"],
        "consolidada",
    )
    assert _por_viaje(entorno)[v]["cupo_disponible"] == antes - 1


def test_orden_por_horario_y_sin_horario_al_final(entorno):
    horarios = [d.get("horario") for d in _consultar(entorno).json()]
    assert horarios == ["07:30", "08:30", "09:00", "10:00", None]


def test_filtra_por_recorrido(entorno):
    ids = set(_por_viaje(entorno, id_recorrido=entorno["r2"]))
    assert ids == {entorno["viajes"]["otro_recorrido"]}


def test_el_destino_se_rechaza_de_forma_explicita(entorno):
    """Issue #8: no se simula un filtro que el modelo no soporta."""
    respuesta = _consultar(entorno, destino="CABA")
    assert respuesta.status_code == 400
    error = respuesta.json()["error"]
    assert error["codigo"] == "FILTRO_NO_DISPONIBLE"
    assert error["detalles"] == {"parametro": "destino"}


def test_filtra_por_parada_de_destino_los_viajes_cuyo_recorrido_pasa_por_ella(entorno):
    """#8, primera entrega: R1 pasa por las tres paradas (también por la intermedia, AC08-03)."""
    v = entorno["viajes"]
    en_r1 = {v[k] for k in ("con_reservas", "planificado", "sin_capacidad", "sobrevendido")}
    for parada in entorno["paradas"]:
        assert set(_por_viaje(entorno, id_parada_destino=parada)) == en_r1


def test_la_parada_de_destino_conserva_el_resto_de_las_reglas_de_la_oferta(entorno):
    """Sin cancelados, en curso, otro sentido ni otro día; el cupo se calcula igual."""
    v = entorno["viajes"]
    por_viaje = _por_viaje(entorno, id_parada_destino=entorno["paradas"][1])
    for excluido in ("cancelado", "en_curso", "vuelta", "otro_dia", "otro_recorrido"):
        assert v[excluido] not in por_viaje
    assert por_viaje[v["planificado"]]["cupo_disponible"] == 10


def test_la_parada_de_destino_se_combina_con_el_recorrido(entorno):
    parada = entorno["paradas"][0]
    assert _por_viaje(entorno, id_parada_destino=parada, id_recorrido=entorno["r2"]) == {}
    con_r1 = _por_viaje(entorno, id_parada_destino=parada, id_recorrido=entorno["r1"])
    assert entorno["viajes"]["con_reservas"] in con_r1


def test_una_parada_que_ningun_recorrido_usa_da_lista_vacia(entorno):
    suelta = _uno(
        entorno["base"],
        "INSERT INTO parada (nombre_descripcion) VALUES ('Suelta') RETURNING id_parada",
    )
    respuesta = _consultar(entorno, id_parada_destino=suelta)
    assert respuesta.status_code == 200
    assert respuesta.json() == []


def test_una_parada_inexistente_es_400(entorno):
    respuesta = _consultar(entorno, id_parada_destino=999999)
    assert respuesta.status_code == 400
    error = respuesta.json()["error"]
    assert error["codigo"] == "PARADA_NO_VALIDA"
    assert error["detalles"] == {"id_parada_destino": 999999}


def test_el_destino_en_texto_sigue_sin_soporte_aunque_venga_la_parada(entorno):
    respuesta = _consultar(entorno, destino="CABA", id_parada_destino=entorno["paradas"][0])
    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "FILTRO_NO_DISPONIBLE"


@pytest.mark.parametrize(
    "params",
    [
        {"fecha": "no-es-una-fecha"},
        {"sentido": "ida"},
        {"sentido": "OTRO"},
        {"id_parada_destino": "no-es-un-numero"},
    ],
)
def test_parametros_invalidos_son_400(entorno, params):
    respuesta = _consultar(entorno, **params)
    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "VALIDACION"


def test_faltan_parametros_obligatorios(entorno):
    respuesta = entorno["cliente"].get(DISPONIBILIDAD)
    assert respuesta.status_code == 400
    campos = {e["campo"] for e in respuesta.json()["error"]["detalles"]["errores"]}
    assert campos == {"fecha", "sentido"}


def test_es_publica_no_pide_token(entorno):
    assert _consultar(entorno).status_code == 200
    assert entorno["cliente"].get("/api/servicios").status_code == 200


def test_lista_los_servicios(entorno):
    respuesta = entorno["cliente"].get("/api/servicios")
    assert respuesta.status_code == 200
    assert [s["tipo_servicio"] for s in respuesta.json()] == ["UNIVERSITARIO", "LABORAL"]


def test_las_paradas_salen_en_orden_y_con_su_marca(entorno):
    respuesta = entorno["cliente"].get(f"/api/recorridos/{entorno['r1']}/paradas")
    assert respuesta.status_code == 200
    paradas = respuesta.json()
    assert [p["orden"] for p in paradas] == [1, 2, 3]
    assert [p["nombre_descripcion"] for p in paradas] == ["Parada 1", "Parada 2", "Parada 3"]
    assert [p["comprometida"] for p in paradas] == [False, False, True]
    assert isinstance(paradas[0]["latitud"], float)  # número, no texto


def test_un_recorrido_sin_paradas_devuelve_lista_vacia(entorno):
    respuesta = entorno["cliente"].get(f"/api/recorridos/{entorno['r2']}/paradas")
    assert respuesta.status_code == 200
    assert respuesta.json() == []


def test_un_recorrido_inexistente_es_404(entorno):
    respuesta = entorno["cliente"].get("/api/recorridos/999999/paradas")
    assert respuesta.status_code == 404
    assert respuesta.json()["error"]["codigo"] == "RECORRIDO_NO_ENCONTRADO"


def test_las_respuestas_no_traen_campos_que_el_contrato_no_declara(entorno):
    esquemas = yaml.safe_load(CONTRATO.read_text(encoding="utf-8"))["components"]["schemas"]
    cliente = entorno["cliente"]
    muestras = {
        "Disponibilidad": _consultar(entorno).json()[0],
        "Servicio": cliente.get("/api/servicios").json()[0],
        "Parada": cliente.get(f"/api/recorridos/{entorno['r1']}/paradas").json()[0],
    }
    for esquema, cuerpo in muestras.items():
        assert set(cuerpo) <= set(esquemas[esquema]["properties"]), esquema


# --- #28: ausencia informada y viajes cuya hora ya pasó ---------------------------------------


def _ausencia(base, pasajero, viaje):
    asyncio.run(
        ejecutar_sql(
            base, "INSERT INTO ausencia (id_pasajero, id_viaje) VALUES ($1, $2)", pasajero, viaje
        )
    )


def _viaje_lleno(entorno, fecha):
    """Un viaje de 3 lugares con tres consolidadas (los pasajeros 0, 1 y 2): cupo 0."""
    e = entorno
    viaje = _viaje(
        e["base"], e["servicio"], e["r1"], vehiculo=e["vehiculo_de_3"], horario="06:00", fecha=fecha
    )
    for pasajero in e["pasajeros"][:3]:
        _reserva(e["base"], pasajero, viaje, e["r1"], e["contratacion"], "consolidada")
    return viaje


def test_la_ausencia_informada_libera_el_lugar(entorno):
    """AC28-06 / PT28-09: al informar su ausencia, el lugar queda libre sin aprobación de nadie."""
    fecha = "2026-11-02"
    viaje = _viaje_lleno(entorno, fecha)
    assert _por_viaje(entorno, fecha=fecha)[viaje]["cupo_disponible"] == 0

    _ausencia(entorno["base"], entorno["pasajeros"][0], viaje)
    assert _por_viaje(entorno, fecha=fecha)[viaje]["cupo_disponible"] == 1


def test_cada_ausencia_libera_un_solo_lugar(entorno):
    """Dos ausencias liberan dos lugares, no más: ni se cuenta doble ni se libera de más."""
    fecha = "2026-11-03"
    viaje = _viaje_lleno(entorno, fecha)
    _ausencia(entorno["base"], entorno["pasajeros"][0], viaje)
    _ausencia(entorno["base"], entorno["pasajeros"][1], viaje)
    assert _por_viaje(entorno, fecha=fecha)[viaje]["cupo_disponible"] == 2


def test_la_ausencia_en_otro_viaje_no_libera_este_lugar(entorno):
    """La ausencia es de un pasajero en un viaje (MR-R25): no vale para otro viaje del mismo día."""
    fecha = "2026-11-04"
    este, otro = _viaje_lleno(entorno, fecha), _viaje_lleno(entorno, fecha)
    _ausencia(entorno["base"], entorno["pasajeros"][0], otro)
    por_viaje = _por_viaje(entorno, fecha=fecha)
    assert por_viaje[este]["cupo_disponible"] == 0
    assert por_viaje[otro]["cupo_disponible"] == 1


def test_la_ausencia_de_quien_no_tiene_reserva_consolidada_no_cambia_el_cupo(entorno):
    fecha = "2026-11-05"
    viaje = _viaje_lleno(entorno, fecha)
    # El pasajero 3 no tiene reserva en este viaje: su ausencia no puede liberar un lugar ajeno.
    _ausencia(entorno["base"], entorno["pasajeros"][3], viaje)
    assert _por_viaje(entorno, fecha=fecha)[viaje]["cupo_disponible"] == 0


def test_un_viaje_programado_cuya_hora_ya_paso_sigue_ofreciendose(entorno):
    """AC28-05 / PT28-06: el reloj no cierra el viaje; lo cierra que comience realmente."""
    e = entorno
    viaje = _viaje(e["base"], e["servicio"], e["r1"], horario="00:01", fecha="2020-01-02")
    assert viaje in _por_viaje(entorno, fecha="2020-01-02")
