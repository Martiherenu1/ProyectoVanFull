"""Asistente AG-01 (CU-011): POST /api/chat, con un modelo falso que sigue un guion.

El LLM se reemplaza por `Guion`; la base, los servicios y la autenticación son los reales. Lo que
se prueba es lo que el backend le garantiza al pasajero sea cual sea el modelo: qué tools se le
ofrecen, que "solo lo propio" se cumple, que un fallo del modelo deriva a una persona y que las
conversaciones no se cruzan.
"""

import ast
import asyncio
import copy
import json
import time
from pathlib import Path

import pytest

from app.agent import openrouter_client
from app.core.security import UsuarioActual, crear_token
from app.services import agente
from tests._bd import base_migrada, cliente_api, consultar, ejecutar_sql

CHAT = "/api/chat"
HABILITADAS = {
    "consultar_disponibilidad",
    "consultar_reserva",
    "consultar_paradas",
    "crear_reserva",
    "cancelar_reserva",
    "derivar_humano",
}


def _uno(base: str, sql: str, *args):
    return asyncio.run(consultar(base, sql, *args))[0][0]


def _con(id_persona: int, roles: list[str]) -> dict[str, str]:
    return {"Authorization": f"Bearer {crear_token(id_persona, id_persona, roles)}"}


# --- El modelo falso -----------------------------------------------------------------------


def _texto(contenido: str | None) -> dict:
    return {"choices": [{"message": {"role": "assistant", "content": contenido}}]}


def _llamada(*tools: tuple[str, dict]) -> dict:
    """Una respuesta del modelo que pide una o varias tools, como la manda OpenRouter."""
    return {
        "choices": [
            {
                "message": {
                    "role": "assistant",
                    "content": None,
                    "tool_calls": [
                        {
                            "id": f"llamada_{i}",
                            "type": "function",
                            "function": {"name": nombre, "arguments": json.dumps(argumentos)},
                        }
                        for i, (nombre, argumentos) in enumerate(tools)
                    ],
                }
            }
        ]
    }


class Guion:
    """Reemplaza a `chat_completion`: devuelve los pasos en orden y guarda lo que recibió."""

    def __init__(self, *pasos):
        self.pasos = list(pasos)
        self.llamadas: list[dict] = []

    async def __call__(self, messages, tools=None, limite=None):
        # Copia profunda: el servicio sigue agregando mensajes a las mismas listas.
        self.llamadas.append(
            {"messages": copy.deepcopy(messages), "tools": tools, "limite": limite}
        )
        assert self.pasos, "el servicio llamó al modelo más veces de las previstas"
        paso = self.pasos.pop(0)
        if isinstance(paso, Exception):
            raise paso
        return paso

    def resultados_de_tools(self, llamada: int) -> list[dict]:
        """Lo que se le devolvió al modelo, ya decodificado, en la llamada número `llamada`."""
        mensajes = self.llamadas[llamada]["messages"]
        return [json.loads(m["content"]) for m in mensajes if m["role"] == "tool"]


@pytest.fixture
def hablar(monkeypatch):
    def _instalar(*pasos) -> Guion:
        guion = Guion(*pasos)
        monkeypatch.setattr(openrouter_client, "chat_completion", guion)
        return guion

    return _instalar


@pytest.fixture(autouse=True)
def conversaciones_limpias():
    agente._conversaciones.clear()
    yield
    agente._conversaciones.clear()


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

        def persona(dni: str, *, pasajero: bool = True) -> int:
            id_persona = _uno(
                base,
                "INSERT INTO persona (nombre, apellido, dni) VALUES ('N', 'A', $1) "
                "RETURNING id_persona",
                dni,
            )
            if pasajero:
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

        ana, beto, chofer = persona("1"), persona("2"), persona("3", pasajero=False)
        with cliente_api(base) as http:
            yield {
                "http": http,
                "base": base,
                "persona": persona,
                "viaje": viaje,
                "reserva": reserva,
                "recorrido": recorrido,
                "ana": ana,
                "beto": beto,
                "chofer": chofer,
                "reserva_ana": reserva(ana, viaje("IDA")),
                "reserva_beto": reserva(beto, viaje("VUELTA")),
            }


def _hablar_como(entorno, quien: str, mensaje: str, **extra):
    return entorno["http"].post(
        CHAT, json={"mensaje": mensaje, **extra}, headers=_con(entorno[quien], ["pasajero"])
    )


# --- Una respuesta directa -----------------------------------------------------------------


def test_el_pasajero_recibe_la_respuesta_del_agente(entorno, hablar):
    hablar(_texto("Hola, ¿en qué te ayudo?"))
    respuesta = _hablar_como(entorno, "ana", "Hola")
    assert respuesta.status_code == 200
    cuerpo = respuesta.json()
    assert cuerpo["respuesta"] == "Hola, ¿en qué te ayudo?"
    assert cuerpo["conversacion_id"]
    assert cuerpo["derivar_humano"] is False
    # El contrato lo declara `nullable`: va como null, no se omite.
    assert cuerpo["tool_usada"] is None


def test_al_modelo_solo_se_le_ofrecen_las_tools_habilitadas(entorno, hablar):
    """A3 de CU-011: solo las tools habilitadas; las demás de las 13 no se ofrecen."""
    guion = hablar(_texto("ok"))
    _hablar_como(entorno, "ana", "Hola")
    ofrecidas = {t["function"]["name"] for t in guion.llamadas[0]["tools"]}
    assert ofrecidas == HABILITADAS


def test_el_modelo_recibe_la_fecha_y_el_mensaje_del_pasajero(entorno, hablar):
    guion = hablar(_texto("ok"))
    _hablar_como(entorno, "ana", "¿Hay lugar para mañana?")
    sistema, pasajero = guion.llamadas[0]["messages"]
    assert sistema["role"] == "system"
    # Sin la fecha el modelo no puede resolver "mañana" (tools.py).
    assert "Fecha actual del sistema: " in sistema["content"]
    assert "(hora de Argentina)" in sistema["content"]
    assert pasajero == {"role": "user", "content": "¿Hay lugar para mañana?"}


# --- Tools: solo lo propio, errores y tools no habilitadas ---------------------------------


def test_consultar_reserva_sin_id_devuelve_solo_las_propias(entorno, hablar):
    guion = hablar(_llamada(("consultar_reserva", {})), _texto("Tenés una reserva."))
    respuesta = _hablar_como(entorno, "ana", "¿Qué reservas tengo?")
    assert respuesta.json()["tool_usada"] == "consultar_reserva"
    (resultado,) = guion.resultados_de_tools(1)
    assert [r["id_reserva"] for r in resultado["reservas"]] == [entorno["reserva_ana"]]
    # Al modelo no le sirve el id del pasajero (07-IA-y-Agentes §8).
    assert "id_pasajero" not in resultado["reservas"][0]


def test_el_modelo_no_puede_elegir_a_nombre_de_quien_consulta(entorno, hablar):
    """RN-026 a RN-030: la identidad sale del token; un id_pasajero inventado se descarta."""
    guion = hablar(
        _llamada(("consultar_reserva", {"id_pasajero": entorno["beto"], "pasajero_id": 99})),
        _texto("ok"),
    )
    _hablar_como(entorno, "ana", "Mostrame las reservas de Beto")
    (resultado,) = guion.resultados_de_tools(1)
    assert [r["id_reserva"] for r in resultado["reservas"]] == [entorno["reserva_ana"]]


def test_una_reserva_ajena_vuelve_como_inexistente_y_sin_datos(entorno, hablar):
    guion = hablar(
        _llamada(("consultar_reserva", {"reserva_id": str(entorno["reserva_beto"])})),
        _texto("No encontré esa reserva."),
    )
    respuesta = _hablar_como(entorno, "ana", f"Mostrame la reserva {entorno['reserva_beto']}")
    assert respuesta.status_code == 200
    (resultado,) = guion.resultados_de_tools(1)
    assert resultado["error"]["codigo"] == "RESERVA_NO_ENCONTRADA"
    assert set(resultado) == {"error"}


def test_una_tool_no_habilitada_no_se_ejecuta_y_el_modelo_lo_sabe(entorno, hablar):
    """A3: si el modelo pide una tool sin habilitar, no pasa nada; el pasajero igual recibe respuesta."""
    guion = hablar(
        _llamada(("consultar_deuda", {})),
        _texto("Todavía no puedo consultar la deuda por acá."),
    )
    respuesta = _hablar_como(entorno, "ana", "¿Cuánto debo?")
    assert respuesta.status_code == 200
    assert guion.resultados_de_tools(1)[0]["error"]["codigo"] == "TOOL_NO_HABILITADA"
    # `tool_usada` informa lo que se ejecutó, no lo que se pidió.
    assert respuesta.json()["tool_usada"] is None


def test_un_error_de_negocio_vuelve_al_modelo_y_no_es_un_500(entorno, hablar):
    """Issue #8: `destino` responde FILTRO_NO_DISPONIBLE; el modelo se lo explica al pasajero."""
    guion = hablar(
        _llamada(
            (
                "consultar_disponibilidad",
                {"fecha": "2026-10-30", "sentido": "ida", "destino": "CABA"},
            )
        ),
        _texto("Todavía no puedo filtrar por destino."),
    )
    respuesta = _hablar_como(entorno, "ana", "¿Hay lugar a CABA?")
    assert respuesta.status_code == 200
    assert guion.resultados_de_tools(1)[0]["error"]["codigo"] == "FILTRO_NO_DISPONIBLE"
    assert respuesta.json()["tool_usada"] == "consultar_disponibilidad"


def test_el_pasajero_reserva_por_el_chat(entorno, hablar):
    """CU-003 por el chat (07-IA §6): el mismo servicio, a nombre de quien habla."""
    gus, id_viaje = entorno["persona"]("40"), entorno["viaje"]("IDA")
    guion = hablar(
        _llamada(("crear_reserva", {"viaje_id": str(id_viaje), "orden_parada": "1"})),
        _texto("Listo, quedó reservado."),
    )
    respuesta = entorno["http"].post(
        CHAT, json={"mensaje": "Sí, reservalo"}, headers=_con(gus, ["pasajero"])
    )
    assert respuesta.status_code == 200
    assert respuesta.json()["tool_usada"] == "crear_reserva"
    assert guion.resultados_de_tools(1)[0]["reserva"]["estado"] == "consolidada"
    dueño = _uno(
        entorno["base"],
        "SELECT id_pasajero FROM reserva WHERE id_viaje = $1",
        id_viaje,
    )
    assert dueño == gus


def test_el_pasajero_cancela_por_el_chat(entorno, hablar):
    """CU-004 por el chat: el modelo recibe el motivo y no se le oculta que no hay crédito."""
    hugo, id_viaje = entorno["persona"]("41"), entorno["viaje"]("VUELTA")
    id_reserva = entorno["reserva"](hugo, id_viaje)
    guion = hablar(
        _llamada(("cancelar_reserva", {"reserva_id": str(id_reserva)})),
        _texto("Cancelada."),
    )
    respuesta = entorno["http"].post(
        CHAT, json={"mensaje": "Sí, cancelala"}, headers=_con(hugo, ["pasajero"])
    )
    assert respuesta.json()["tool_usada"] == "cancelar_reserva"
    (resultado,) = guion.resultados_de_tools(1)
    assert resultado["reserva"]["estado"] == "cancelada"
    assert resultado["penalidad_aplicada"] is False
    assert "todavía no se otorga" in resultado["motivo"]


def test_varias_tools_en_un_mensaje_se_ejecutan_y_se_informa_la_ultima(entorno, hablar):
    guion = hablar(
        _llamada(
            ("consultar_paradas", {"recorrido": str(entorno["recorrido"])}),
            ("consultar_reserva", {}),
        ),
        _texto("Listo."),
    )
    respuesta = _hablar_como(entorno, "ana", "Paradas y reservas")
    paradas, reservas = guion.resultados_de_tools(1)
    assert paradas["paradas"][0]["nombre_descripcion"] == "Plaza"
    assert len(reservas["reservas"]) == 1
    assert respuesta.json()["tool_usada"] == "consultar_reserva"


# --- Derivación a una persona (RF-032) -----------------------------------------------------


def test_si_el_pasajero_pide_una_persona_la_respuesta_sale_derivada(entorno, hablar):
    hablar(
        _llamada(("derivar_humano", {"motivo": "lo pidió el pasajero"})),
        _texto("Te paso con una persona."),
    )
    respuesta = _hablar_como(entorno, "ana", "Quiero hablar con alguien")
    cuerpo = respuesta.json()
    assert cuerpo["derivar_humano"] is True
    assert cuerpo["tool_usada"] == "derivar_humano"
    assert cuerpo["respuesta"] == "Te paso con una persona."


@pytest.mark.parametrize(
    "falla",
    [
        openrouter_client.OpenRouterError("ningún modelo respondió"),
        {},  # el gateway contestó algo sin `choices`
        {"choices": []},
        {"choices": [{"message": "texto suelto"}]},
        _texto(None),  # sin texto ni tools
        _texto("   "),
    ],
    ids=[
        "sin_modelo",
        "sin_choices",
        "choices_vacio",
        "mensaje_raro",
        "sin_contenido",
        "en_blanco",
    ],
)
def test_si_el_modelo_no_responde_bien_se_deriva_a_una_persona(entorno, hablar, falla):
    """A1: lo mismo si no responde ningún modelo (principal ni fallback)."""
    hablar(falla)
    respuesta = _hablar_como(entorno, "ana", "Hola")
    assert respuesta.status_code == 200
    cuerpo = respuesta.json()
    assert cuerpo["derivar_humano"] is True
    assert cuerpo["respuesta"] == agente.MENSAJE_DERIVACION
    # Un turno fallido no deja una conversación a medias.
    assert cuerpo["conversacion_id"] not in agente._conversaciones


def test_sin_clave_se_deriva_sin_llamar_a_openrouter(entorno, monkeypatch):
    """La demo sin OPENROUTER_API_KEY: el cliente real, sin red, termina en derivación y no en 500."""
    monkeypatch.setattr(openrouter_client.settings, "openrouter_api_key", "")

    def sin_red(*args, **kwargs):
        raise AssertionError("sin clave no se abre ninguna conexión")

    monkeypatch.setattr(openrouter_client.httpx, "AsyncClient", sin_red)
    respuesta = _hablar_como(entorno, "ana", "Hola")
    assert respuesta.status_code == 200
    assert respuesta.json()["derivar_humano"] is True


def test_todas_las_vueltas_de_un_mensaje_comparten_un_tope(entorno, hablar):
    """La app no corta la espera: el servicio le pone al mensaje entero un tope de tiempo."""
    guion = hablar(_llamada(("consultar_reserva", {})), _texto("Listo."))
    antes = time.monotonic()
    _hablar_como(entorno, "ana", "Mis reservas")
    limites = {llamada["limite"] for llamada in guion.llamadas}
    assert len(limites) == 1
    assert antes < limites.pop() <= time.monotonic() + agente.TIEMPO_MAXIMO


def test_si_el_modelo_no_cierra_en_las_vueltas_previstas_se_deriva(entorno, hablar):
    guion = hablar(*[_llamada(("consultar_reserva", {})) for _ in range(agente.MAX_VUELTAS)])
    respuesta = _hablar_como(entorno, "ana", "Hola")
    assert respuesta.json()["derivar_humano"] is True
    assert len(guion.llamadas) == agente.MAX_VUELTAS
    assert respuesta.json()["conversacion_id"] not in agente._conversaciones


# --- Conversaciones ------------------------------------------------------------------------


def test_la_conversacion_continua_con_su_id(entorno, hablar):
    guion = hablar(_texto("Hola Ana."), _texto("Son las 7:30."))
    primera = _hablar_como(entorno, "ana", "Hola").json()
    segunda = _hablar_como(
        entorno, "ana", "¿A qué hora?", conversacion_id=primera["conversacion_id"]
    )
    assert segunda.json()["conversacion_id"] == primera["conversacion_id"]
    # El modelo ve el historial: sistema, "Hola", "Hola Ana.", "¿A qué hora?".
    roles_y_textos = [(m["role"], m["content"]) for m in guion.llamadas[1]["messages"][1:]]
    assert roles_y_textos == [
        ("user", "Hola"),
        ("assistant", "Hola Ana."),
        ("user", "¿A qué hora?"),
    ]


def test_sin_id_cada_mensaje_abre_una_conversacion_nueva(entorno, hablar):
    hablar(_texto("uno"), _texto("dos"))
    a = _hablar_como(entorno, "ana", "Hola").json()["conversacion_id"]
    b = _hablar_como(entorno, "ana", "Hola").json()["conversacion_id"]
    assert a != b


def test_la_conversacion_de_otro_pasajero_no_se_retoma_ni_se_revela(entorno, hablar):
    guion = hablar(_texto("Hola Ana."), _texto("Hola Beto."))
    de_ana = _hablar_como(entorno, "ana", "Mi secreto").json()["conversacion_id"]
    de_beto = _hablar_como(entorno, "beto", "Hola", conversacion_id=de_ana)
    assert de_beto.status_code == 200
    # Se abre una nueva: no se usa el id ajeno y el modelo no ve nada de Ana.
    assert de_beto.json()["conversacion_id"] != de_ana
    assert "Mi secreto" not in json.dumps(guion.llamadas[1]["messages"])
    # La de Ana sigue siendo de Ana.
    assert agente._conversaciones[de_ana].id_persona == entorno["ana"]


def test_un_id_que_no_existe_abre_una_conversacion_nueva(entorno, hablar):
    """Tras reiniciar el servidor las conversaciones se pierden: el cliente sigue andando."""
    hablar(_texto("Hola."))
    respuesta = _hablar_como(entorno, "ana", "Hola", conversacion_id="no-existe")
    assert respuesta.status_code == 200
    assert respuesta.json()["conversacion_id"] != "no-existe"


def test_el_historial_descarta_turnos_enteros_mas_viejos():
    turno = [{"role": "user", "content": "p"}, {"role": "assistant", "content": "r"}]
    mensajes = turno * (agente.MAX_MENSAJES // 2 + 5)
    recortado = agente._recortar(mensajes)
    assert len(recortado) <= agente.MAX_MENSAJES
    # Nunca arranca con una respuesta o un resultado de tool sin su pregunta.
    assert recortado[0]["role"] == "user"


def test_al_llegar_al_tope_se_descarta_la_conversacion_mas_vieja(monkeypatch):
    monkeypatch.setattr(agente, "MAX_CONVERSACIONES", 2)
    usuario = UsuarioActual(id_cuenta_acceso=1, id_persona=1, roles=("pasajero",))
    for id_conversacion in ("a", "b", "c"):
        agente._guardar(id_conversacion, usuario, [{"role": "user", "content": "x"}])
    assert list(agente._conversaciones) == ["b", "c"]


# --- Entrada y acceso ----------------------------------------------------------------------


@pytest.mark.parametrize("mensaje", ["", "   ", "x" * (agente.MAX_CARACTERES + 1)])
def test_un_mensaje_vacio_o_demasiado_largo_se_rechaza_sin_llamar_al_modelo(
    entorno, hablar, mensaje
):
    guion = hablar()
    respuesta = _hablar_como(entorno, "ana", mensaje)
    assert respuesta.status_code == 400
    assert respuesta.json()["error"]["codigo"] == "VALIDACION"
    assert guion.llamadas == []


def test_sin_mensaje_es_400(entorno, hablar):
    hablar()
    respuesta = entorno["http"].post(CHAT, json={}, headers=_con(entorno["ana"], ["pasajero"]))
    assert respuesta.status_code == 400


def test_sin_token_es_401(entorno, hablar):
    guion = hablar()
    respuesta = entorno["http"].post(CHAT, json={"mensaje": "Hola"})
    assert respuesta.status_code == 401
    assert guion.llamadas == []


def test_un_rol_que_no_es_pasajero_es_403(entorno, hablar):
    guion = hablar()
    respuesta = entorno["http"].post(
        CHAT, json={"mensaje": "Hola"}, headers=_con(entorno["chofer"], ["chofer"])
    )
    assert respuesta.status_code == 403
    assert guion.llamadas == []


def test_el_servicio_no_importa_modelos():
    """CU-011 pasos 5 y 6: el agente llega a los datos solo por servicios (el ejecutor)."""
    arbol = ast.parse(Path(agente.__file__).read_text(encoding="utf-8"))
    modulos = set()
    for nodo in ast.walk(arbol):
        if isinstance(nodo, ast.ImportFrom):
            modulos.add(nodo.module or "")
        elif isinstance(nodo, ast.Import):
            modulos.update(alias.name for alias in nodo.names)
    assert not {m for m in modulos if m.startswith("app.models")}
    assert {m for m in modulos if m.startswith("sqlalchemy")} <= {"sqlalchemy.ext.asyncio"}


def test_al_modelo_no_se_le_pide_un_destino_que_no_se_puede_filtrar(entorno, hablar):
    """Issue #156: si la tool sugiere el destino, el modelo lo pide en vez de consultar (#8)."""
    guion = hablar(_texto("Hola"))
    _hablar_como(entorno, "ana", "Hola")
    (disponibilidad,) = [
        t["function"]
        for t in guion.llamadas[0]["tools"]
        if t["function"]["name"] == "consultar_disponibilidad"
    ]
    assert "destino" not in disponibilidad["description"]
    assert "destino" not in disponibilidad["parameters"]["required"]
    assert "no lo pidas" in disponibilidad["parameters"]["properties"]["destino"]["description"]


@pytest.mark.parametrize(
    ("con_formato", "plano"),
    [
        ("Es **Parada de prueba 2** (orden 2)", "Es Parada de prueba 2 (orden 2)"),
        ("Tu __reserva__ está lista", "Tu reserva está lista"),
        ("# Viajes\n## Hoy\nSí hay", "Viajes\nHoy\nSí hay"),
        ("* Uno\n* Dos\n  + Tres", "- Uno\n- Dos\n  - Tres"),
        ("Subís en *Parada 1* y bajás en `Parada 3`", "Subís en Parada 1 y bajás en Parada 3"),
        ("**Viaje:** ID 3\n**Hora:** 18:00", "Viaje: ID 3\nHora: 18:00"),
        ("Un ** suelto", "Un  suelto"),
        # Lo que no es formato se respeta.
        ("2 * 3 = 6 y id_viaje 3", "2 * 3 = 6 y id_viaje 3"),
        ("- Uno\n- Dos", "- Uno\n- Dos"),
        ("Hola, ¿en qué te ayudo?", "Hola, ¿en qué te ayudo?"),
    ],
)
def test_la_respuesta_se_limpia_de_formato_markdown(con_formato, plano):
    assert agente.a_texto_plano(con_formato) == plano


def test_el_pasajero_no_recibe_markdown_aunque_el_modelo_lo_mande(entorno, hablar):
    """Issue #156: observado en Render; la limpieza es del backend, no depende del prompt."""
    hablar(_texto("Los viajes son:\n* **Viaje 3** – 18:00"))
    cuerpo = _hablar_como(entorno, "ana", "Hola").json()
    assert cuerpo["respuesta"] == "Los viajes son:\n- Viaje 3 – 18:00"


def test_el_historial_guarda_la_respuesta_ya_limpia(entorno, hablar):
    """El modelo ve sus respuestas sin formato y no copia ese estilo en el turno siguiente."""
    hablar(_texto("Es **Viaje 3**"))
    primera = _hablar_como(entorno, "ana", "Hola").json()
    guion = hablar(_texto("Listo"))
    _hablar_como(entorno, "ana", "Gracias", conversacion_id=primera["conversacion_id"])
    previos = [m["content"] for m in guion.llamadas[0]["messages"] if m["role"] == "assistant"]
    assert previos == ["Es Viaje 3"]


def test_el_modelo_recibe_que_responda_sin_markdown(entorno, hablar):
    """Issue #156: la pantalla del asistente muestra el texto tal cual, sin formato."""
    guion = hablar(_texto("Hola"))
    _hablar_como(entorno, "ana", "Hola")
    assert "sin Markdown" in guion.llamadas[0]["messages"][0]["content"]
