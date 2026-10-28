"""Servicio del asistente AG-01 (CU-011): el ciclo mensaje → modelo → tools → respuesta.

El modelo no decide reglas ni toca la base: elige una tool y arma los argumentos, y
`agent/ejecutor.py` llama al servicio que corresponde (CONVENCIONES.md §1). Este servicio solo
orquesta: arma el contexto, itera con el modelo y decide cuándo derivar a una persona (RF-032).

Acá no se hace `commit`: las tools que escriben (crear y cancelar una reserva) confirman dentro de
su servicio, igual que desde la app.

**Las conversaciones se guardan en memoria del proceso** (Issue #42): ninguna de las 35 tablas las
guarda. Se pierden al reiniciar y no se comparten entre procesos. PENDIENTE: persistencia.
"""

import json
import re
import time
from collections import OrderedDict
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from uuid import uuid4

from sqlalchemy.ext.asyncio import AsyncSession

from app.agent import openrouter_client
from app.agent.ejecutor import DERIVAR_HUMANO, TOOLS_HABILITADAS, ejecutar
from app.agent.tools import SYSTEM_PROMPT
from app.core.errors import ApiError
from app.core.security import UsuarioActual
from app.schemas.chat import ChatRequest, ChatResponse

# Cada mensaje cuesta una llamada a un modelo: se acota lo que entra.
MAX_CARACTERES = 2000
# Vueltas modelo → tools → modelo dentro de un mismo mensaje. Si el modelo no cierra en este
# número de vueltas, no está resolviendo: se deriva en vez de seguir gastando.
MAX_VUELTAS = 5
# Tope de un mensaje entero, con todas sus vueltas y el fallback: la app no corta la espera sola.
# Pasado este tiempo se deriva en vez de dejar al pasajero mirando la pantalla.
TIEMPO_MAXIMO = 60.0
# Del historial de una conversación se descartan los turnos más viejos (nunca uno a medias).
MAX_MENSAJES = 40
MAX_CONVERSACIONES = 500

MENSAJE_DERIVACION = (
    "No pude resolver tu consulta por este medio. Te derivo con una persona de VanFull "
    "para que te ayude."
)

# Argentina no tiene horario de verano: un desfase fijo evita depender de la base de zonas horarias.
_HORA_ARGENTINA = timezone(timedelta(hours=-3))
_DIAS = ("lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo")
_NOMBRES_HABILITADOS = {t["function"]["name"] for t in TOOLS_HABILITADAS}

# La pantalla del asistente muestra el texto tal cual (Issue #156). El prompt pide texto plano, pero
# el modelo a veces responde con Markdown igual: acá se limpia, que no depende de que obedezca.
_VINETA = re.compile(r"^(\s*)[*+]\s+", re.MULTILINE)
_TITULO = re.compile(r"^\s{0,3}#{1,6}\s+", re.MULTILINE)
_NEGRITA = re.compile(r"(\*\*|__)(.+?)\1", re.DOTALL)
# Un asterisco solo, pegado al texto de ambos lados: cursiva. "2 * 3" no entra (hay espacios).
_CURSIVA = re.compile(r"(?<![*\w])\*(?=\S)([^*\n]+?)(?<=\S)\*(?![*\w])")


def a_texto_plano(texto: str) -> str:
    """Quita el formato Markdown (negritas, cursivas, títulos, viñetas con *, código)."""
    texto = _VINETA.sub(r"\1- ", texto)
    texto = _TITULO.sub("", texto)
    texto = _NEGRITA.sub(r"\2", texto)
    texto = _CURSIVA.sub(r"\1", texto)
    return texto.replace("**", "").replace("`", "")


@dataclass
class _Conversacion:
    id_persona: int
    mensajes: list[dict]


# Más vieja primero: al llegar al tope se descarta la que hace más que no se usa.
_conversaciones: OrderedDict[str, _Conversacion] = OrderedDict()


def _abrir(usuario: UsuarioActual, conversacion_id: str | None) -> tuple[str, list[dict]]:
    """Retoma la conversación si es de este usuario; si no existe o es ajena, abre una nueva.

    Ajena e inexistente se tratan igual para no revelar que el id existe (RN-026 a 030).
    """
    conversacion = _conversaciones.get(conversacion_id) if conversacion_id else None
    if conversacion is None or conversacion.id_persona != usuario.id_persona:
        return uuid4().hex, []
    _conversaciones.move_to_end(conversacion_id)
    return conversacion_id, list(conversacion.mensajes)


def _recortar(mensajes: list[dict]) -> list[dict]:
    """Descarta turnos enteros (de un mensaje del pasajero al siguiente) hasta entrar en el tope."""
    while len(mensajes) > MAX_MENSAJES:
        turnos = (i for i in range(1, len(mensajes)) if mensajes[i]["role"] == "user")
        siguiente = next(turnos, None)
        if siguiente is None:
            break
        del mensajes[:siguiente]
    return mensajes


def _guardar(conversacion_id: str, usuario: UsuarioActual, mensajes: list[dict]) -> None:
    _conversaciones[conversacion_id] = _Conversacion(usuario.id_persona, _recortar(mensajes))
    _conversaciones.move_to_end(conversacion_id)
    while len(_conversaciones) > MAX_CONVERSACIONES:
        _conversaciones.popitem(last=False)


def _system_prompt() -> str:
    # Las fechas relativas ("mañana") no las resuelve el modelo sin saber qué día es (tools.py).
    ahora = datetime.now(_HORA_ARGENTINA)
    return SYSTEM_PROMPT.format(
        fecha_actual=f"{_DIAS[ahora.weekday()]} {ahora:%Y-%m-%d}, {ahora:%H:%M} (hora de Argentina)"
    )


def _derivacion(conversacion_id: str, tool_usada: str | None) -> ChatResponse:
    return ChatResponse(
        respuesta=MENSAJE_DERIVACION,
        conversacion_id=conversacion_id,
        derivar_humano=True,
        tool_usada=tool_usada,
    )


async def responder(db: AsyncSession, usuario: UsuarioActual, datos: ChatRequest) -> ChatResponse:
    """Atiende un mensaje del pasajero. `usuario` sale del token: ninguna tool recibe su id."""
    texto = datos.mensaje.strip()
    if not texto:
        raise ApiError(400, "VALIDACION", "El mensaje no puede estar vacío.")
    if len(texto) > MAX_CARACTERES:
        raise ApiError(
            400, "VALIDACION", f"El mensaje no puede superar los {MAX_CARACTERES} caracteres."
        )

    conversacion_id, historial = _abrir(usuario, datos.conversacion_id)
    # Se trabaja sobre una copia: si el turno falla, la conversación guardada queda como estaba.
    mensajes = [*historial, {"role": "user", "content": texto}]
    derivar = False
    tool_usada: str | None = None
    limite = time.monotonic() + TIEMPO_MAXIMO

    for _ in range(MAX_VUELTAS):
        try:
            salida = await openrouter_client.chat_completion(
                [{"role": "system", "content": _system_prompt()}, *mensajes],
                tools=TOOLS_HABILITADAS,
                limite=limite,
            )
            del_modelo = salida["choices"][0]["message"]
            llamadas = del_modelo.get("tool_calls") or []
            contenido = del_modelo.get("content")
        except (openrouter_client.OpenRouterError, KeyError, IndexError, TypeError, AttributeError):
            # A1: ningún modelo respondió bien (o la respuesta no tiene la forma esperada).
            return _derivacion(conversacion_id, tool_usada)

        if not llamadas:
            respuesta = a_texto_plano((contenido or "").strip())
            if not respuesta:
                return _derivacion(conversacion_id, tool_usada)
            mensajes.append({"role": "assistant", "content": respuesta})
            _guardar(conversacion_id, usuario, mensajes)
            return ChatResponse(
                respuesta=respuesta,
                conversacion_id=conversacion_id,
                derivar_humano=derivar,
                tool_usada=tool_usada,
            )

        mensajes.append({"role": "assistant", "content": contenido, "tool_calls": llamadas})
        # Una por una: comparten la sesión de la base, que no admite uso concurrente.
        for posicion, llamada in enumerate(llamadas):
            funcion = llamada.get("function") or {}
            nombre = funcion.get("name")
            resultado = await ejecutar(db, usuario, nombre, funcion.get("arguments"))
            if nombre in _NOMBRES_HABILITADOS:
                tool_usada = nombre
            if nombre == DERIVAR_HUMANO:
                derivar = True
            mensajes.append(
                {
                    "role": "tool",
                    "tool_call_id": llamada.get("id") or f"llamada_{posicion}",
                    "content": json.dumps(resultado, ensure_ascii=False),
                }
            )

    # Se agotaron las vueltas sin una respuesta: el modelo no está resolviendo (A1).
    return _derivacion(conversacion_id, tool_usada)
