"""Historial de viajes para administración y dueño (CU-026, RF-040). Solo lectura.

Qué es un viaje «anterior» (respuesta funcional de Martín del 18/11, el CU no lo define): uno que
ya terminó, `finalizado` o `cancelado`, mostrando su estado. Un viaje programado o en curso no es
historia aunque su fecha ya haya pasado: se lo encuentra en la consulta operativa de viajes
(CU-018). La fecha por sí sola no hace histórico a un viaje.

«Información operativa asociada»: servicio, recorrido y paradas, chofer, vehículo y cantidades de
reservas, abordajes y ausencias. No se exponen datos de los pasajeros: el CU pide solo lo
«disponible y autorizado» y no autoriza ningún dato personal.

PENDIENTE DE VALIDACIÓN LEGAL/TÉCNICA (v1.3): plazo de retención y eliminación de datos. Este CU no
borra nada ni aplica plazos: lo que existe en la base se puede consultar.
"""

from datetime import date

from sqlalchemy import Select, and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.models.personas import Persona
from app.models.servicios import Servicio
from app.models.viajes import (
    Abordaje,
    Ausencia,
    Parada,
    ParadaRecorrido,
    Reserva,
    Vehiculo,
    Viaje,
)
from app.schemas.historial_viajes import (
    HistorialConteos,
    HistorialParada,
    HistorialPersona,
    HistorialVehiculo,
    HistorialViaje,
    HistorialViajeDetalle,
    HistorialViajeLista,
)

_TERMINADOS = ("finalizado", "cancelado")


def _es_historico():
    return Viaje.estado.in_(_TERMINADOS)


def _base() -> Select:
    return (
        select(Viaje, Servicio.tipo_servicio, Persona, Vehiculo)
        .join(Servicio, Servicio.id_servicio == Viaje.id_servicio)
        .outerjoin(Persona, Persona.id_persona == Viaje.id_chofer)
        .outerjoin(Vehiculo, Vehiculo.id_vehiculo == Viaje.id_vehiculo)
    )


def _resumen(viaje: Viaje, tipo_servicio: str, chofer: Persona | None, vehiculo: Vehiculo | None):
    return {
        "id_viaje": viaje.id_viaje,
        "fecha": viaje.fecha,
        "horario": viaje.horario.isoformat(timespec="minutes") if viaje.horario else None,
        "sentido": viaje.sentido,
        "estado": viaje.estado,
        "id_servicio": viaje.id_servicio,
        "tipo_servicio": tipo_servicio,
        "id_recorrido": viaje.id_recorrido,
        "chofer": (
            HistorialPersona(
                id_persona=chofer.id_persona, nombre=chofer.nombre, apellido=chofer.apellido
            )
            if chofer
            else None
        ),
        "vehiculo": (
            HistorialVehiculo(id_vehiculo=vehiculo.id_vehiculo, patente=vehiculo.patente)
            if vehiculo
            else None
        ),
    }


async def listar(
    db: AsyncSession,
    *,
    desde: date | None,
    hasta: date | None,
    estado: str | None,
    id_servicio: int | None,
    id_chofer: int | None,
    id_vehiculo: int | None,
    sentido: str | None,
    limite: int,
    desplazamiento: int,
) -> HistorialViajeLista:
    if desde and hasta and desde > hasta:
        raise ApiError(400, "VALIDACION", "`desde` no puede ser posterior a `hasta`.")

    criterios = [_es_historico()]
    if desde:
        criterios.append(Viaje.fecha >= desde)
    if hasta:
        criterios.append(Viaje.fecha <= hasta)
    for columna, valor in (
        (Viaje.estado, estado),
        (Viaje.id_servicio, id_servicio),
        (Viaje.id_chofer, id_chofer),
        (Viaje.id_vehiculo, id_vehiculo),
        (Viaje.sentido, sentido),
    ):
        if valor is not None:
            criterios.append(columna == valor)
    donde = and_(*criterios)

    total = await db.scalar(select(func.count()).select_from(Viaje).where(donde))
    consulta = (
        _base()
        .where(donde)
        .order_by(
            Viaje.fecha.desc(),
            Viaje.horario.desc().nulls_last(),
            Viaje.id_viaje.desc(),
        )
        .limit(limite)
        .offset(desplazamiento)
    )
    filas = (await db.execute(consulta)).all()
    return HistorialViajeLista(items=[HistorialViaje(**_resumen(*f)) for f in filas], total=total)


async def detalle(db: AsyncSession, id_viaje: int) -> HistorialViajeDetalle:
    fila = (
        await db.execute(_base().where(Viaje.id_viaje == id_viaje, _es_historico()))
    ).one_or_none()
    # Un viaje que todavía no es historia se ve en la operación del día, no acá.
    if fila is None:
        raise ApiError(
            404, "VIAJE_NO_ENCONTRADO", "No existe un viaje anterior con ese identificador."
        )
    viaje = fila[0]

    paradas = (
        await db.execute(
            select(ParadaRecorrido.orden, ParadaRecorrido.id_parada, Parada.nombre_descripcion)
            .join(Parada, Parada.id_parada == ParadaRecorrido.id_parada)
            .where(ParadaRecorrido.id_recorrido == viaje.id_recorrido)
            .order_by(ParadaRecorrido.orden)
        )
    ).all()

    por_estado = dict(
        (
            await db.execute(
                select(Reserva.estado, func.count())
                .where(Reserva.id_viaje == id_viaje)
                .group_by(Reserva.estado)
            )
        ).all()
    )
    abordajes = await db.scalar(
        select(func.count()).select_from(Abordaje).where(Abordaje.id_viaje == id_viaje)
    )
    ausencias = await db.scalar(
        select(func.count()).select_from(Ausencia).where(Ausencia.id_viaje == id_viaje)
    )

    return HistorialViajeDetalle(
        **_resumen(*fila),
        capacidad_planificada=viaje.capacidad_planificada,
        paradas=[
            HistorialParada(orden=o, id_parada=p, nombre_descripcion=n) for o, p, n in paradas
        ],
        conteos=HistorialConteos(
            reservas_provisionales=por_estado.get("provisional", 0),
            reservas_consolidadas=por_estado.get("consolidada", 0),
            reservas_canceladas=por_estado.get("cancelada", 0),
            abordajes=abordajes,
            ausencias=ausencias,
        ),
    )
