"""Ejecutor de las tools de AG-01 (CU-011): traduce los argumentos del modelo y llama a los servicios."""

import ast
import asyncio
import json
from pathlib import Path

import pytest
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.agent import ejecutor
from app.agent.ejecutor import TOOLS_HABILITADAS, ejecutar
from app.agent.tools import TOOLS
from app.core.security import UsuarioActual
from tests._bd import base_migrada, consultar, ejecutar_sql, url_sqlalchemy

HABILITADAS = {
    "consultar_disponibilidad",
    "consultar_reserva",
    "consultar_paradas",
    "derivar_humano",
}


def _uno(base: str, sql: str, *args):
    return asyncio.run(consultar(base, sql, *args))[0][0]


def _pasajero(id_persona: int) -> UsuarioActual:
    return UsuarioActual(id_cuenta_acceso=id_persona, id_persona=id_persona, roles=("pasajero",))


def _correr(base: str, usuario: UsuarioActual, nombre: str, argumentos) -> dict:
    """`ejecutar` con una sesión nueva contra `base`, como la abre `/chat` en cada pedido."""

    async def _con_sesion():
        motor = create_async_engine(url_sqlalchemy(base), poolclass=NullPool)
        try:
            async with async_sessionmaker(motor, expire_on_commit=False)() as db:
                return await ejecutar(db, usuario, nombre, argumentos)
        finally:
            await motor.dispose()

    return asyncio.run(_con_sesion())


@pytest.fixture(scope="module")
def entorno():
    with base_migrada() as base:
        servicio = _uno(
            base,
            "INSERT INTO servicio (tipo_servicio) VALUES ('UNIVERSITARIO') RETURNING id_servicio",
        )
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
        cliente = _uno(
            base,
            "INSERT INTO cliente (naturaleza_cliente) VALUES ('INDIVIDUAL') RETURNING id_cliente",
        )
        contratacion = _uno(
            base,
            "INSERT INTO contratacion (id_cliente, id_servicio) VALUES ($1, $2) "
            "RETURNING id_contratacion",
            cliente,
            servicio,
        )

        def viaje(sentido: str) -> int:
            return _uno(
                base,
                "INSERT INTO viaje (id_servicio, id_recorrido, fecha, horario, sentido, "
                "capacidad_planificada) VALUES ($1, $2, DATE '2026-10-30', TIME '07:30', $3, 10) "
                "RETURNING id_viaje",
                servicio,
                recorrido,
                sentido,
            )

        def persona(dni: str) -> int:
            id_persona = _uno(
                base,
                "INSERT INTO persona (nombre, apellido, dni) VALUES ('N', 'A', $1) "
                "RETURNING id_persona",
                dni,
            )
            asyncio.run(
                ejecutar_sql(base, "INSERT INTO pasajero (id_persona) VALUES ($1)", id_persona)
            )
            return id_persona

        def reserva(pasajero: int, id_viaje: int) -> int:
            return _uno(
                base,
                "INSERT INTO reserva (id_pasajero, id_viaje, id_recorrido, orden_parada, "
                "id_contratacion_directa, estado) VALUES ($1, $2, $3, 1, $4, 'consolidada') "
                "RETURNING id_reserva",
                pasajero,
                id_viaje,
                recorrido,
                contratacion,
            )

        ida, vuelta = viaje("IDA"), viaje("VUELTA")
        ana, beto = persona("1"), persona("2")
        yield {
            "base": base,
            "recorrido": recorrido,
            "ida": ida,
            "vuelta": vuelta,
            "ana": _pasajero(ana),
            "beto": _pasajero(beto),
            "reserva_ana": reserva(ana, ida),
            "reserva_beto": reserva(beto, vuelta),
        }


# --- Qué se le ofrece al modelo y qué no se ejecuta (sin base) -----------------------------
# Estas pruebas pasan db=None: si el ejecutor intentara usar la base, fallarían.


def test_al_modelo_solo_se_le_ofrecen_las_tools_habilitadas():
    assert {t["function"]["name"] for t in TOOLS_HABILITADAS} == HABILITADAS
    # Las 13 definiciones no se tocan: el canario de test_health.py sigue valiendo.
    assert len(TOOLS) == 13


@pytest.mark.parametrize("nombre", ["crear_reserva", "cancelar_reserva", "consultar_deuda", "x"])
def test_una_tool_no_habilitada_no_se_ejecuta(nombre):
    """A3 de CU-011: no se inventa capacidad. Reservar y cancelar siguen en CU-003 y CU-004."""
    resultado = asyncio.run(ejecutar(None, _pasajero(1), nombre, {"reserva_id": "1"}))
    assert resultado["error"]["codigo"] == "TOOL_NO_HABILITADA"


@pytest.mark.parametrize(
    ("argumentos", "por_que"),
    [
        ("{no es json", "JSON roto"),
        ("[1, 2]", "no es un objeto"),
        ({"fecha": "2026-10-30", "sentido": "subida"}, "sentido desconocido"),
        ({"fecha": "mañana", "sentido": "ida"}, "fecha sin resolver"),
        ({"sentido": "ida"}, "falta la fecha"),
    ],
)
def test_un_argumento_que_no_se_puede_traducir_vuelve_como_error(argumentos, por_que):
    resultado = asyncio.run(ejecutar(None, _pasajero(1), "consultar_disponibilidad", argumentos))
    assert resultado["error"]["codigo"] == "ARGUMENTO_INVALIDO", por_que


def test_derivar_humano_marca_la_derivacion():
    assert asyncio.run(ejecutar(None, _pasajero(1), "derivar_humano", "")) == {"derivado": True}


def test_el_ejecutor_no_importa_modelos_ni_consulta_la_base():
    """CU-011 paso 5 y la regla de arquitectura: el agente llega a los datos solo por servicios."""
    arbol = ast.parse(Path(ejecutor.__file__).read_text(encoding="utf-8"))
    modulos = set()
    for nodo in ast.walk(arbol):
        if isinstance(nodo, ast.ImportFrom):
            modulos.add(nodo.module or "")
        elif isinstance(nodo, ast.Import):
            modulos.update(alias.name for alias in nodo.names)
    assert not {m for m in modulos if m.startswith("app.models")}
    # De SQLAlchemy, solo el tipo de la sesión que se le pasa al servicio.
    assert {m for m in modulos if m.startswith("sqlalchemy")} <= {"sqlalchemy.ext.asyncio"}


# --- Disponibilidad ------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("sentido", "viaje"), [("ida", "ida"), ("vuelta", "vuelta"), ("IDA", "ida")]
)
def test_disponibilidad_traduce_el_sentido_al_del_contrato(entorno, sentido, viaje):
    """La tool usa ida/vuelta y el contrato IDA/VUELTA (CONTEXTO del pasajero, pendientes)."""
    resultado = _correr(
        entorno["base"],
        entorno["ana"],
        "consultar_disponibilidad",
        json.dumps({"fecha": "2026-10-30", "sentido": sentido}),
    )
    assert [v["id_viaje"] for v in resultado["viajes"]] == [entorno[viaje]]
    assert resultado["viajes"][0]["sentido"] == sentido.upper()


def test_disponibilidad_con_destino_devuelve_el_error_del_servicio(entorno):
    """Issue #8: el destino no se descarta en silencio; el modelo recibe FILTRO_NO_DISPONIBLE."""
    resultado = _correr(
        entorno["base"],
        entorno["ana"],
        "consultar_disponibilidad",
        {"fecha": "2026-10-30", "sentido": "ida", "destino": "CABA"},
    )
    assert resultado["error"]["codigo"] == "FILTRO_NO_DISPONIBLE"


# --- Reservas: solo lo propio --------------------------------------------------------------


def test_sin_reserva_id_lista_solo_las_propias_y_sin_el_id_del_pasajero(entorno):
    resultado = _correr(entorno["base"], entorno["ana"], "consultar_reserva", "{}")
    assert [r["id_reserva"] for r in resultado["reservas"]] == [entorno["reserva_ana"]]
    assert all("id_pasajero" not in r for r in resultado["reservas"])


def test_un_id_de_pasajero_inventado_por_el_modelo_se_descarta(entorno):
    """RN-026 a 030: la identidad sale del token, no de los argumentos."""
    resultado = _correr(
        entorno["base"],
        entorno["ana"],
        "consultar_reserva",
        {"id_pasajero": entorno["beto"].id_persona},
    )
    assert [r["id_reserva"] for r in resultado["reservas"]] == [entorno["reserva_ana"]]


def test_el_detalle_de_una_reserva_propia(entorno):
    resultado = _correr(
        entorno["base"],
        entorno["ana"],
        "consultar_reserva",
        {"reserva_id": str(entorno["reserva_ana"])},
    )
    assert resultado["reserva"]["id_reserva"] == entorno["reserva_ana"]
    assert (resultado["reserva"]["fecha"], resultado["reserva"]["sentido"]) == ("2026-10-30", "IDA")
    assert "id_pasajero" not in resultado["reserva"]


def test_una_reserva_ajena_da_lo_mismo_que_una_inexistente(entorno):
    ajena = _correr(
        entorno["base"],
        entorno["ana"],
        "consultar_reserva",
        {"reserva_id": entorno["reserva_beto"]},
    )
    inexistente = _correr(
        entorno["base"], entorno["ana"], "consultar_reserva", {"reserva_id": 999999}
    )
    assert ajena == inexistente
    assert ajena["error"]["codigo"] == "RESERVA_NO_ENCONTRADA"


# --- Paradas -------------------------------------------------------------------------------


def test_las_paradas_de_un_recorrido(entorno):
    resultado = _correr(
        entorno["base"],
        entorno["ana"],
        "consultar_paradas",
        {"recorrido": str(entorno["recorrido"])},
    )
    assert [(p["orden"], p["nombre_descripcion"]) for p in resultado["paradas"]] == [(1, "Plaza")]


@pytest.mark.parametrize(
    ("recorrido", "codigo"), [("abc", "ARGUMENTO_INVALIDO"), ("999999", "RECORRIDO_NO_ENCONTRADO")]
)
def test_un_recorrido_invalido_o_inexistente_vuelve_como_error(entorno, recorrido, codigo):
    resultado = _correr(
        entorno["base"], entorno["ana"], "consultar_paradas", {"recorrido": recorrido}
    )
    assert resultado["error"]["codigo"] == codigo


def test_las_tools_no_modifican_ninguna_reserva(entorno):
    """Esta rebanada es solo de lectura."""
    base, sql = entorno["base"], "SELECT id_reserva, estado, id_viaje FROM reserva ORDER BY 1"
    antes = asyncio.run(consultar(base, sql))
    _correr(base, entorno["ana"], "consultar_reserva", {})
    _correr(base, entorno["ana"], "consultar_reserva", {"reserva_id": entorno["reserva_ana"]})
    assert asyncio.run(consultar(base, sql)) == antes
