"""CU-008 / RF-016: aviso voluntario, sin cancelar ni recuperar la reserva."""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.core.security import UsuarioActual
from app.models.personas import Pasajero
from app.models.viajes import Abordaje, Viaje
from app.models.viajes import Ausencia as AusenciaModelo
from app.schemas.ausencias import Ausencia, AusenciaCreate
from app.services.eventos import registrar_evento
from app.services.reservas import reserva_propia_del_viaje

TIPO_AUSENCIA_INFORMADA = "ausencia_informada"


def _a_schema(aviso: AusenciaModelo) -> Ausencia:
    return Ausencia(
        id_ausencia=aviso.id_ausencia,
        id_pasajero=aviso.id_pasajero,
        id_viaje=aviso.id_viaje,
    )


async def informar_ausencia(
    db: AsyncSession, usuario: UsuarioActual, datos: AusenciaCreate
) -> tuple[Ausencia, bool]:
    """Devuelve (aviso, creado). El servicio confirma una única transacción.

    CONVENCIONES §8 / #133: pasajero → viaje → reserva. Las lecturas se refrescan
    bajo los locks, incluso si la sesión ya tenía instancias cargadas. Ejecución
    solo bloquea viaje; cancelación y futuro abordaje respetan el mismo orden.
    """
    pasajero = await db.scalar(
        select(Pasajero).where(Pasajero.id_persona == usuario.id_persona).with_for_update()
    )
    viaje = await db.scalar(
        select(Viaje)
        .where(Viaje.id_viaje == datos.id_viaje)
        .with_for_update()
        .execution_options(populate_existing=True)
    )
    if pasajero is None or viaje is None:
        raise ApiError(404, "RESERVA_NO_ENCONTRADA", "La reserva no existe.")

    reserva = await reserva_propia_del_viaje(db, usuario, datos.id_viaje, bloquear=True)
    if reserva is None:
        raise ApiError(404, "RESERVA_NO_ENCONTRADA", "La reserva no existe.")
    await db.refresh(reserva)

    # Pertenencia antes del reintento; las condiciones de alta no invalidan un aviso previo.
    existente = await db.scalar(
        select(AusenciaModelo).where(
            AusenciaModelo.id_pasajero == usuario.id_persona,
            AusenciaModelo.id_viaje == datos.id_viaje,
        )
    )
    if existente is not None:
        resultado = _a_schema(existente)
        await db.commit()  # Libera locks; no duplica filas ni eventos.
        return resultado, False

    if reserva.estado != "consolidada":
        raise ApiError(409, "RESERVA_NO_CONSOLIDADA", "La reserva no está consolidada.")
    if viaje.estado not in ("programado", "en_curso"):
        raise ApiError(409, "VIAJE_NO_ADMITE_AUSENCIA", "El viaje ya no admite avisos nuevos.")
    abordaje = await db.scalar(
        select(Abordaje.id_abordaje).where(
            Abordaje.id_pasajero == usuario.id_persona, Abordaje.id_viaje == datos.id_viaje
        )
    )
    if abordaje is not None:
        raise ApiError(409, "PASAJERO_YA_ABORDADO", "Ya registraste tu abordaje en este viaje.")

    # RN-024/025 y AC28-06/09: solo aviso voluntario. El cupo se deriva de su existencia;
    # no se modifica la reserva, no hay efectos económicos ni recuperación por escaneo.
    aviso = AusenciaModelo(id_pasajero=usuario.id_persona, id_viaje=datos.id_viaje)
    db.add(aviso)
    await db.flush()
    await registrar_evento(db, tipo_evento=TIPO_AUSENCIA_INFORMADA, id_reserva=reserva.id_reserva)
    resultado = _a_schema(aviso)
    await db.commit()
    return resultado, True
