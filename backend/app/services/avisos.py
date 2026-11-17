"""CU-030 manual: origen viaje, autor autenticado y correlación durable (#280)."""

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.core.security import UsuarioActual
from app.models.trazabilidad import EventoOperativo
from app.models.viajes import Viaje
from app.schemas.avisos import Aviso, AvisoCrear, MensajeDemora
from app.services import reservas
from app.services.eventos import registrar_evento

TIPOS = {"demora": "aviso_demora", "problema": "aviso_problema"}


def _salida(evento: EventoOperativo) -> Aviso:
    return Aviso(
        id_evento_operativo=evento.id_evento_operativo,
        id_viaje=evento.id_viaje,
        clase="demora" if evento.tipo_evento == TIPOS["demora"] else "problema",
        descripcion_interna=evento.detalle_evento,
        id_cuenta_autora=evento.id_cuenta_autora,
        clave_solicitud=evento.clave_solicitud,
        fecha_hora_registro=evento.fecha_hora,
    )


async def _propio(db: AsyncSession, usuario: UsuarioActual, viaje: int, clave: UUID):
    return await db.scalar(
        select(EventoOperativo).where(
            EventoOperativo.id_viaje == viaje,
            EventoOperativo.id_cuenta_autora == usuario.id_cuenta_acceso,
            EventoOperativo.clave_solicitud == clave,
        )
    )


async def crear(db: AsyncSession, usuario: UsuarioActual, id_viaje: int, datos: AvisoCrear):
    # Lock compartido por todos los escritores del viaje, incluido finalizar/reasignar.
    # Recuperar primero por autor permite repetir después del cierre o reasignación.
    viaje = await db.scalar(select(Viaje).where(Viaje.id_viaje == id_viaje).with_for_update())
    evento = await _propio(db, usuario, id_viaje, datos.clave_solicitud)
    if evento is not None:
        if (evento.tipo_evento, evento.detalle_evento) != (
            TIPOS[datos.clase],
            datos.descripcion_interna,
        ):
            raise ApiError(
                409, "CLAVE_SOLICITUD_EN_CONFLICTO", "La clave ya identifica otro contenido."
            )
        resultado = _salida(evento)
        await db.commit()
        return resultado, False
    if viaje is None or viaje.id_chofer != usuario.id_persona:
        raise ApiError(404, "VIAJE_NO_ENCONTRADO", "El viaje no existe.")
    if viaje.estado != "en_curso":
        raise ApiError(409, "ESTADO_VIAJE_INVALIDO", "Solo se informa durante el viaje.")
    evento = await registrar_evento(
        db,
        tipo_evento=TIPOS[datos.clase],
        detalle=datos.descripcion_interna,
        id_viaje=id_viaje,
        id_cuenta_autora=usuario.id_cuenta_acceso,
        clave_solicitud=datos.clave_solicitud,
    )
    resultado = _salida(evento)
    await db.commit()
    return resultado, True


async def resultado(db: AsyncSession, usuario: UsuarioActual, id_viaje: int, clave: UUID):
    evento = await _propio(db, usuario, id_viaje, clave)
    if evento is None:
        # No encontrado no demuestra que un POST aún en vuelo no vaya a confirmar.
        raise ApiError(404, "AVISO_NO_ENCONTRADO", "Resultado no disponible.")
    return _salida(evento)


async def internos(db: AsyncSession, id_viaje: int) -> list[Aviso]:
    # Administración/dueño gestionan viajes de la empresa. Solo avisos manuales,
    # no eventos generales ni datos de contacto. No hay aislamiento por empresa en este modelo.
    if await db.get(Viaje, id_viaje) is None:
        raise ApiError(404, "VIAJE_NO_ENCONTRADO", "El viaje no existe.")
    filas = (
        await db.scalars(
            select(EventoOperativo)
            .where(
                EventoOperativo.id_viaje == id_viaje,
                EventoOperativo.clave_solicitud.is_not(None),
            )
            .order_by(EventoOperativo.id_evento_operativo)
        )
    ).all()
    return [_salida(e) for e in filas]


async def mensaje(db: AsyncSession, usuario: UsuarioActual, id_viaje: int) -> MensajeDemora:
    # Orden global: pasajero -> viaje -> reserva. Revalidación bajo lock.
    from app.models.personas import Pasajero

    await db.scalar(
        select(Pasajero).where(Pasajero.id_persona == usuario.id_persona).with_for_update()
    )
    viaje = await db.scalar(
        select(Viaje).where(Viaje.id_viaje == id_viaje).with_for_update(read=True)
    )
    reserva = await reservas.reserva_propia_del_viaje(db, usuario, id_viaje)
    if viaje is None or reserva is None or reserva.estado != "consolidada":
        raise ApiError(404, "VIAJE_NO_ENCONTRADO", "El viaje no existe.")
    salida = MensajeDemora(id_viaje=id_viaje)
    if viaje.estado == "en_curso":
        evento = await db.scalar(
            select(EventoOperativo)
            .where(
                EventoOperativo.id_viaje == id_viaje,
                EventoOperativo.tipo_evento == TIPOS["demora"],
                EventoOperativo.clave_solicitud.is_not(None),
            )
            .order_by(EventoOperativo.id_evento_operativo.desc())
            .limit(1)
        )
        if evento is not None:
            # Hecho fechado: no afirma vigencia actual, ni ETA ni entrega CU-037.
            salida.mensaje = "El chofer informó una demora durante este viaje. La situación actual no está confirmada."
            salida.fecha_hora_reporte = evento.fecha_hora
    await db.commit()
    return salida
