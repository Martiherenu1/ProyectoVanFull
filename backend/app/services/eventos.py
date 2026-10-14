"""Helper de EVENTO_OPERATIVO (trazabilidad operativa, bloque 5 del modelo).

Es la única vía para escribir en `evento_operativo` (REPARTO-PC2.md): cualquier servicio lo llama,
nadie hace `db.add(EventoOperativo(...))` por su cuenta. Así la regla MR-R29 vive en un solo lugar.

Qué es y qué no es:
- Es una traza de lo que pasó en una reserva, un pago o un viaje.
- No es una auditoría: la auditoría figura como PROPUESTA, no aprobada (CONTEXTO §13).
- No hay un catálogo aprobado de `tipo_evento`. Cada dueño define los suyos como constantes en su
  servicio (por ejemplo `TIPO_RESERVA_CREADA = "reserva_creada"`) y no inventa tipos de otra área.

Transacción: el helper hace `flush`, no `commit`. El evento queda en la misma transacción que el
cambio que lo origina, así que o se guardan los dos o ninguno. El `commit` lo hace el servicio que
llama, al final de la operación.
"""

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.trazabilidad import EventoOperativo

# Largo de evento_operativo.tipo_evento (VARCHAR(50)).
MAX_TIPO_EVENTO = 50


async def registrar_evento(
    db: AsyncSession,
    *,
    tipo_evento: str,
    detalle: str | None = None,
    id_reserva: int | None = None,
    id_pago: int | None = None,
    id_viaje: int | None = None,
) -> EventoOperativo:
    """Agrega un evento a la sesión y lo envía a la base (sin confirmar la transacción).

    A lo sumo uno de `id_reserva`, `id_pago` o `id_viaje` (MR-R29); ninguno es válido para un evento
    que no se origina en esas tres entidades.

    Levanta `ValueError` si se rompe esa regla o si `tipo_evento` es vacío o demasiado largo: es un
    error de quien llama, no del usuario, y no tiene un código HTTP propio. La base lo vuelve a
    controlar con un CHECK, y con FK si el id no existe.
    """
    tipo = tipo_evento.strip()
    if not tipo:
        raise ValueError("tipo_evento no puede estar vacío.")
    if len(tipo) > MAX_TIPO_EVENTO:
        raise ValueError(f"tipo_evento supera los {MAX_TIPO_EVENTO} caracteres.")

    origenes = [x for x in (id_reserva, id_pago, id_viaje) if x is not None]
    if len(origenes) > 1:
        raise ValueError(
            "Un evento operativo tiene a lo sumo un origen: reserva, pago o viaje (MR-R29)."
        )

    evento = EventoOperativo(
        tipo_evento=tipo,
        detalle_evento=detalle,
        id_reserva=id_reserva,
        id_pago=id_pago,
        id_viaje=id_viaje,
    )
    db.add(evento)
    await db.flush()
    return evento
