"""Historial de viajes (CU-026): /api/administracion/historial-viajes contra un PostgreSQL real."""

import asyncio
import itertools
from datetime import date, time, timedelta

import pytest

from app.core.security import crear_token
from tests._bd import base_migrada, cliente_api, consultar

HISTORIAL = "/api/administracion/historial-viajes"
_n = itertools.count(91000)


def _con(*roles: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {crear_token(1, 1, list(roles))}"}


ADMIN = _con("administrador")
DUENO = _con("dueno")


def _sql(base, sql, *args):
    return asyncio.run(consultar(base, sql, *args))


@pytest.fixture(scope="module")
def entorno():
    with base_migrada() as base, cliente_api(base) as cliente:
        yield base, cliente


class Mundo:
    """Un servicio, un vehículo, un chofer y un recorrido propios: aíslan a cada prueba."""

    def __init__(self, base, cliente):
        self.base = base
        n = next(_n)
        self.servicio = _sql(
            base,
            "INSERT INTO servicio (tipo_servicio) VALUES ('LABORAL') RETURNING id_servicio",
        )[0][0]
        self.vehiculo = _sql(
            base,
            "INSERT INTO vehiculo (patente, capacidad) VALUES ($1, 10) RETURNING id_vehiculo",
            f"HI{n}",
        )[0][0]
        self.chofer = _sql(
            base,
            "INSERT INTO persona (nombre, apellido, dni) VALUES ('Carla', 'Ruta', $1) "
            "RETURNING id_persona",
            str(n),
        )[0][0]
        _sql(base, "INSERT INTO chofer (id_persona) VALUES ($1) RETURNING 1", self.chofer)
        paradas = []
        for nombre in ("Plaza", "Terminal"):
            r = cliente.post(
                "/api/administracion/paradas", json={"nombre_descripcion": nombre}, headers=ADMIN
            )
            paradas.append(r.json()["id_parada"])
        self.paradas = paradas
        r = cliente.post(
            "/api/administracion/recorridos", json={"id_paradas": paradas}, headers=ADMIN
        )
        self.recorrido = r.json()["id_recorrido"]

    def viaje(self, fecha, estado="finalizado", sentido="IDA", horario=None, con_recursos=True):
        return _sql(
            self.base,
            "INSERT INTO viaje (id_servicio, id_recorrido, id_vehiculo, id_chofer, fecha, horario,"
            " sentido, estado, capacidad_planificada) "
            "VALUES ($1, $2, $3::bigint, $4::bigint, $5, $6::time, $7, $8, 10) RETURNING id_viaje",
            self.servicio,
            self.recorrido,
            self.vehiculo if con_recursos else None,
            self.chofer if con_recursos else None,
            fecha,
            time.fromisoformat(horario) if horario else None,
            sentido,
            estado,
        )[0][0]

    def reserva(self, id_viaje, estado="consolidada"):
        n = next(_n)
        pasajero = _sql(
            self.base,
            "INSERT INTO persona (nombre, apellido, dni) VALUES ('Pablo', 'Secreto', $1) "
            "RETURNING id_persona",
            str(n),
        )[0][0]
        _sql(self.base, "INSERT INTO pasajero (id_persona) VALUES ($1) RETURNING 1", pasajero)
        cli = _sql(
            self.base,
            "INSERT INTO cliente (naturaleza_cliente) VALUES ('INDIVIDUAL') RETURNING id_cliente",
        )[0][0]
        contrato = _sql(
            self.base,
            "INSERT INTO contratacion (id_cliente, id_servicio) VALUES ($1, $2) "
            "RETURNING id_contratacion",
            cli,
            self.servicio,
        )[0][0]
        _sql(
            self.base,
            "INSERT INTO reserva (id_pasajero, id_viaje, id_recorrido, orden_parada, "
            "id_contratacion_directa, estado) VALUES ($1, $2, $3, 1, $4, $5) RETURNING 1",
            pasajero,
            id_viaje,
            self.recorrido,
            contrato,
            estado,
        )
        return pasajero

    def abordaje(self, id_viaje, id_pasajero):
        _sql(
            self.base,
            "INSERT INTO abordaje (id_pasajero, id_viaje, id_vehiculo, id_recorrido, orden_parada)"
            " VALUES ($1, $2, $3, $4, 1) RETURNING 1",
            id_pasajero,
            id_viaje,
            self.vehiculo,
            self.recorrido,
        )

    def ausencia(self, id_viaje, id_pasajero):
        _sql(
            self.base,
            "INSERT INTO ausencia (id_pasajero, id_viaje) VALUES ($1, $2) RETURNING 1",
            id_pasajero,
            id_viaje,
        )

    def listar(self, cliente, headers=ADMIN, **criterios):
        criterios.setdefault("id_chofer", self.chofer)
        return cliente.get(HISTORIAL, params=criterios, headers=headers)

    def ids(self, cliente, **criterios):
        respuesta = self.listar(cliente, **criterios)
        assert respuesta.status_code == 200, respuesta.text
        return [v["id_viaje"] for v in respuesta.json()["items"]]


HACE_RATO = date(2020, 3, 10)
HOY = date.today()
FUTURO = date(2099, 1, 1)


# --- Permisos -------------------------------------------------------------------------------


def test_sin_token_es_401(entorno):
    _, cliente = entorno
    assert cliente.get(HISTORIAL).status_code == 401
    assert cliente.get(f"{HISTORIAL}/1").status_code == 401


@pytest.mark.parametrize("rol", ["pasajero", "chofer", "representante_corporativo"])
def test_solo_administracion_y_dueno_consultan(entorno, rol):
    _, cliente = entorno
    assert cliente.get(HISTORIAL, headers=_con(rol)).status_code == 403
    assert cliente.get(f"{HISTORIAL}/1", headers=_con(rol)).status_code == 403


@pytest.mark.parametrize("headers", [ADMIN, DUENO])
def test_administrador_y_dueno_pueden(entorno, headers):
    _, cliente = entorno
    assert cliente.get(HISTORIAL, headers=headers).status_code == 200


# --- Qué es historia -------------------------------------------------------------------------


def test_son_historia_solo_los_finalizados_y_cancelados(entorno):
    base, cliente = entorno
    m = Mundo(base, cliente)
    pasado_finalizado = m.viaje(HACE_RATO, "finalizado")
    pasado_cancelado = m.viaje(HACE_RATO, "cancelado")
    terminado_hoy = m.viaje(HOY, "cancelado")
    # Programados y en curso quedan afuera, también con fecha pasada: la fecha sola no hace historia.
    m.viaje(HACE_RATO, "programado")
    m.viaje(HACE_RATO, "en_curso")
    m.viaje(HOY, "programado")
    m.viaje(HOY, "en_curso")
    m.viaje(FUTURO, "programado")

    assert sorted(m.ids(cliente)) == sorted([pasado_finalizado, pasado_cancelado, terminado_hoy])


def test_el_estado_se_muestra_y_programado_o_en_curso_dan_vacio(entorno):
    base, cliente = entorno
    m = Mundo(base, cliente)
    finalizado = m.viaje(HACE_RATO, "finalizado")
    cancelado = m.viaje(HACE_RATO, "cancelado")
    m.viaje(HACE_RATO, "programado")
    m.viaje(HACE_RATO, "en_curso")

    estados = {v["id_viaje"]: v["estado"] for v in m.listar(cliente).json()["items"]}
    assert estados == {finalizado: "finalizado", cancelado: "cancelado"}
    for estado in ("programado", "en_curso"):
        assert m.ids(cliente, estado=estado) == []


def test_sin_resultados_informa_vacio(entorno):
    base, cliente = entorno
    m = Mundo(base, cliente)
    m.viaje(FUTURO, "programado")
    respuesta = m.listar(cliente)
    assert respuesta.status_code == 200
    assert respuesta.json() == {"items": [], "total": 0}


# --- Criterios -------------------------------------------------------------------------------


def test_filtra_por_rango_de_fechas(entorno):
    base, cliente = entorno
    m = Mundo(base, cliente)
    enero = m.viaje(date(2020, 1, 15))
    febrero = m.viaje(date(2020, 2, 15))
    marzo = m.viaje(date(2020, 3, 15))

    assert m.ids(cliente, desde="2020-02-01") == [marzo, febrero]
    assert m.ids(cliente, hasta="2020-02-28") == [febrero, enero]
    assert m.ids(cliente, desde="2020-02-01", hasta="2020-02-28") == [febrero]
    # Los extremos entran.
    assert m.ids(cliente, desde="2020-02-15", hasta="2020-02-15") == [febrero]


def test_filtra_por_estado_sentido_y_recursos(entorno):
    base, cliente = entorno
    m = Mundo(base, cliente)
    ida = m.viaje(HACE_RATO, "finalizado", "IDA")
    vuelta = m.viaje(HACE_RATO, "cancelado", "VUELTA")

    assert m.ids(cliente, estado="cancelado") == [vuelta]
    assert m.ids(cliente, estado="finalizado") == [ida]
    assert m.ids(cliente, sentido="IDA") == [ida]
    assert sorted(m.ids(cliente, id_servicio=m.servicio)) == sorted([ida, vuelta])
    assert sorted(m.ids(cliente, id_vehiculo=m.vehiculo)) == sorted([ida, vuelta])
    # Un criterio que no coincide con nada da vacío, no error.
    assert m.ids(cliente, id_servicio=m.servicio + 10_000) == []


def test_criterios_se_combinan(entorno):
    base, cliente = entorno
    m = Mundo(base, cliente)
    buscado = m.viaje(date(2020, 5, 1), "cancelado", "VUELTA")
    m.viaje(date(2020, 5, 1), "finalizado", "VUELTA")
    m.viaje(date(2020, 6, 1), "cancelado", "VUELTA")
    m.viaje(date(2020, 5, 1), "cancelado", "IDA")

    assert m.ids(
        cliente, desde="2020-05-01", hasta="2020-05-31", estado="cancelado", sentido="VUELTA"
    ) == [buscado]


def test_orden_fecha_y_horario_descendentes(entorno):
    base, cliente = entorno
    m = Mundo(base, cliente)
    viejo = m.viaje(date(2020, 1, 1), horario="08:00")
    manana = m.viaje(date(2020, 2, 1), horario="08:00")
    tarde = m.viaje(date(2020, 2, 1), horario="18:00")
    sin_hora = m.viaje(date(2020, 2, 1))

    # El mismo día: horario descendente y los que no tienen horario al final.
    assert m.ids(cliente) == [tarde, manana, sin_hora, viejo]


def test_paginacion_y_total(entorno):
    base, cliente = entorno
    m = Mundo(base, cliente)
    ids = [m.viaje(date(2020, 1, d)) for d in range(1, 6)]  # 1..5 de enero, más nuevo primero
    nuevos_primero = list(reversed(ids))

    pagina = m.listar(cliente, limite=2, desplazamiento=1).json()
    assert pagina["total"] == 5
    assert [v["id_viaje"] for v in pagina["items"]] == nuevos_primero[1:3]


@pytest.mark.parametrize(
    "criterios",
    [
        {"desde": "2020-02-01", "hasta": "2020-01-01"},
        {"desde": "no-es-fecha"},
        {"estado": "inexistente"},
        {"sentido": "LATERAL"},
        {"limite": 0},
        {"limite": 201},
        {"desplazamiento": -1},
        {"id_chofer": 0},
    ],
)
def test_criterios_invalidos_son_400(entorno, criterios):
    _, cliente = entorno
    respuesta = cliente.get(HISTORIAL, params=criterios, headers=ADMIN)
    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "VALIDACION"


# --- Detalle ---------------------------------------------------------------------------------


def test_detalle_trae_la_informacion_operativa_sin_datos_de_pasajeros(entorno):
    base, cliente = entorno
    m = Mundo(base, cliente)
    viaje = m.viaje(HACE_RATO, "finalizado", "IDA", "07:30")
    a = m.reserva(viaje, "consolidada")
    b = m.reserva(viaje, "consolidada")
    m.reserva(viaje, "cancelada")
    m.reserva(viaje, "provisional")
    m.abordaje(viaje, a)
    m.ausencia(viaje, b)

    respuesta = cliente.get(f"{HISTORIAL}/{viaje}", headers=DUENO)
    assert respuesta.status_code == 200, respuesta.text
    d = respuesta.json()
    assert d["id_viaje"] == viaje
    assert d["estado"] == "finalizado"
    assert d["sentido"] == "IDA"
    assert d["horario"] == "07:30"
    assert d["tipo_servicio"] == "LABORAL"
    assert d["capacidad_planificada"] == 10
    assert d["chofer"] == {"id_persona": m.chofer, "nombre": "Carla", "apellido": "Ruta"}
    assert d["vehiculo"]["id_vehiculo"] == m.vehiculo
    assert [(p["orden"], p["id_parada"], p["nombre_descripcion"]) for p in d["paradas"]] == [
        (1, m.paradas[0], "Plaza"),
        (2, m.paradas[1], "Terminal"),
    ]
    assert d["conteos"] == {
        "reservas_provisionales": 1,
        "reservas_consolidadas": 2,
        "reservas_canceladas": 1,
        "abordajes": 1,
        "ausencias": 1,
    }
    # Privacidad: ningún dato de los pasajeros viaja en el historial.
    assert "Secreto" not in respuesta.text
    assert "Pablo" not in respuesta.text


def test_detalle_de_un_viaje_sin_chofer_ni_vehiculo(entorno):
    base, cliente = entorno
    m = Mundo(base, cliente)
    viaje = m.viaje(HACE_RATO, "cancelado", con_recursos=False)
    d = cliente.get(f"{HISTORIAL}/{viaje}", headers=ADMIN).json()
    assert "chofer" not in d
    assert "vehiculo" not in d
    assert d["conteos"]["abordajes"] == 0


def test_detalle_de_un_viaje_que_todavia_no_es_historia_es_404(entorno):
    base, cliente = entorno
    m = Mundo(base, cliente)
    for fecha, estado in (
        (FUTURO, "programado"),
        (HOY, "en_curso"),
        (HACE_RATO, "programado"),
        (HACE_RATO, "en_curso"),
    ):
        viaje = m.viaje(fecha, estado)
        respuesta = cliente.get(f"{HISTORIAL}/{viaje}", headers=ADMIN)
        assert respuesta.status_code == 404
        assert respuesta.json()["error"]["codigo"] == "VIAJE_NO_ENCONTRADO"


def test_detalle_inexistente_es_404_y_id_invalido_400(entorno):
    _, cliente = entorno
    assert cliente.get(f"{HISTORIAL}/999999999", headers=ADMIN).status_code == 404
    assert cliente.get(f"{HISTORIAL}/0", headers=ADMIN).status_code == 400


# --- Postcondición: no se modifica -----------------------------------------------------------


def test_el_historial_es_solo_lectura(entorno):
    base, cliente = entorno
    m = Mundo(base, cliente)
    viaje = m.viaje(HACE_RATO, "finalizado")
    antes = _sql(base, "SELECT estado, fecha, id_chofer FROM viaje WHERE id_viaje = $1", viaje)

    assert cliente.post(HISTORIAL, json={}, headers=ADMIN).status_code == 405
    assert cliente.patch(f"{HISTORIAL}/{viaje}", json={}, headers=ADMIN).status_code == 405
    assert cliente.delete(f"{HISTORIAL}/{viaje}", headers=ADMIN).status_code == 405
    cliente.get(f"{HISTORIAL}/{viaje}", headers=ADMIN)
    m.listar(cliente)

    despues = _sql(base, "SELECT estado, fecha, id_chofer FROM viaje WHERE id_viaje = $1", viaje)
    assert despues == antes


def test_lo_terminado_ayer_es_historia_y_lo_programado_de_ayer_no(entorno):
    base, cliente = entorno
    m = Mundo(base, cliente)
    ayer = HOY - timedelta(days=1)
    terminado = m.viaje(ayer, "finalizado")
    m.viaje(ayer, "programado")  # vencido sin resolver: se lo busca en CU-018, no acá
    assert m.ids(cliente) == [terminado]
