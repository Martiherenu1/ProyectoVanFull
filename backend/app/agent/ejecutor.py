"""Ejecutor de las tools de AG-01 (CU-011, pasos 5 y 6).

El modelo elige una tool y arma los argumentos; acá se traducen y se llama al servicio que
corresponde. **No se importa ningún modelo ni se consulta la base**: la regla vive una sola vez, en
el servicio, y el agente recibe lo mismo que la app (CONVENCIONES.md §1).

"Solo lo propio" (RN-026 a RN-030): la identidad es `usuario`, que sale del token. Ninguna tool
recibe el id del pasajero, y cada función toma solo los argumentos que conoce: si el modelo inventa
otro, se descarta.

Un error del servicio (`ApiError`) o un argumento que no se puede traducir no se propaga: vuelve al
modelo como `{"error": {...}}`, para que le explique al pasajero qué pasó en vez de terminar en 500.
"""

import json
from collections.abc import Awaitable, Callable
from datetime import date
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.agent.tools import TOOLS
from app.core.errors import ApiError
from app.core.security import UsuarioActual
from app.schemas.reservas import Reserva
from app.services import disponibilidad, reservas, servicios

DERIVAR_HUMANO = "derivar_humano"

# El modelo manda el sentido en minúsculas (tools.py); el contrato y la base usan IDA/VUELTA.
_SENTIDOS = {"ida": "IDA", "vuelta": "VUELTA"}


class _ArgumentoInvalido(Exception):
    """El modelo mandó algo que no se puede traducir. Vuelve al modelo como error."""


def _error(codigo: str, mensaje: str) -> dict:
    return {"error": {"codigo": codigo, "mensaje": mensaje}}


def _leer_argumentos(argumentos: str | dict | None) -> dict:
    """OpenRouter manda los argumentos como un JSON en texto; algunos modelos, vacío."""
    if argumentos is None or argumentos == "":
        return {}
    if isinstance(argumentos, str):
        try:
            argumentos = json.loads(argumentos)
        except json.JSONDecodeError as exc:
            raise _ArgumentoInvalido("Los argumentos no son un JSON válido.") from exc
    if not isinstance(argumentos, dict):
        raise _ArgumentoInvalido("Los argumentos tienen que ser un objeto JSON.")
    return argumentos


def _fecha(valor: Any) -> date:
    try:
        return date.fromisoformat(str(valor))
    except ValueError as exc:
        raise _ArgumentoInvalido("La fecha tiene que tener el formato AAAA-MM-DD.") from exc


def _entero(valor: Any, nombre: str) -> int:
    try:
        return int(str(valor).strip())
    except ValueError as exc:
        raise _ArgumentoInvalido(f"`{nombre}` tiene que ser un número.") from exc


def _reserva_para_el_modelo(reserva: Reserva) -> dict:
    # 07-IA-y-Agentes §8: al modelo, lo mínimo. El id del pasajero es el del usuario: no aporta nada.
    return reserva.model_dump(mode="json", exclude={"id_pasajero"})


# --- Una función por tool habilitada -------------------------------------------------------


async def _consultar_disponibilidad(db: AsyncSession, usuario: UsuarioActual, args: dict) -> dict:
    sentido = _SENTIDOS.get(str(args.get("sentido", "")).strip().lower())
    if sentido is None:
        raise _ArgumentoInvalido("`sentido` tiene que ser ida o vuelta.")
    viajes = await disponibilidad.consultar_disponibilidad(
        db,
        fecha=_fecha(args.get("fecha")),
        sentido=sentido,
        # Issue #8: el servicio rechaza `destino` con FILTRO_NO_DISPONIBLE. No se descarta acá:
        # sería mostrar viajes a cualquier lado como si fueran al destino pedido.
        destino=args.get("destino") or None,
    )
    return {"viajes": [v.model_dump(mode="json", exclude_none=True) for v in viajes]}


async def _consultar_reserva(db: AsyncSession, usuario: UsuarioActual, args: dict) -> dict:
    """Sin `reserva_id`, las reservas propias; con `reserva_id`, el detalle de una (CU-010)."""
    reserva_id = args.get("reserva_id")
    if reserva_id is None or str(reserva_id).strip() == "":
        propias = await reservas.listar_reservas_del_pasajero(db, usuario)
        return {"reservas": [_reserva_para_el_modelo(r) for r in propias]}
    reserva = await reservas.obtener_reserva_del_pasajero(
        db, usuario, _entero(reserva_id, "reserva_id")
    )
    return {"reserva": _reserva_para_el_modelo(reserva)}


async def _consultar_paradas(db: AsyncSession, usuario: UsuarioActual, args: dict) -> dict:
    paradas = await servicios.paradas_de_recorrido(db, _entero(args.get("recorrido"), "recorrido"))
    return {"paradas": [p.model_dump(mode="json", exclude_none=True) for p in paradas]}


async def _derivar_humano(db: AsyncSession, usuario: UsuarioActual, args: dict) -> dict:
    # RF-032. Qué recibe la persona que atiende no está definido (Issue #42): por ahora la
    # derivación solo marca la respuesta de /chat.
    return {"derivado": True}


_FUNCIONES: dict[str, Callable[[AsyncSession, UsuarioActual, dict], Awaitable[dict]]] = {
    "consultar_disponibilidad": _consultar_disponibilidad,
    "consultar_reserva": _consultar_reserva,
    "consultar_paradas": _consultar_paradas,
    DERIVAR_HUMANO: _derivar_humano,
}

# A3 de CU-011: al modelo solo se le ofrecen estas. Las 13 definiciones siguen en tools.py.
TOOLS_HABILITADAS: list[dict] = [t for t in TOOLS if t["function"]["name"] in _FUNCIONES]


async def ejecutar(
    db: AsyncSession, usuario: UsuarioActual, nombre: str, argumentos: str | dict | None
) -> dict:
    """Ejecuta la tool `nombre` para `usuario` y devuelve lo que se le pasa al modelo."""
    funcion = _FUNCIONES.get(nombre)
    if funcion is None:
        # A3: no se inventa capacidad. Reservar es CU-003 y cancelar CU-004.
        return _error("TOOL_NO_HABILITADA", "Esa operación no está disponible en el asistente.")
    try:
        return await funcion(db, usuario, _leer_argumentos(argumentos))
    except _ArgumentoInvalido as exc:
        return _error("ARGUMENTO_INVALIDO", str(exc))
    except ApiError as exc:
        return _error(exc.codigo, exc.mensaje)
