"""Consultas operativas de los viajes asignados al chofer (CU-029, RF-024, RN-029).

Lecturas exclusivamente. La autorización "solo viajes propios" utiliza el id de persona
de la sesión y no un id de chofer elegido por el cliente.
"""

from datetime import date

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.core.security import UsuarioActual
from app.models.personas import Pasajero, Persona
from app.models.viajes import Abordaje, IntegranteNomina, Reserva
from app.models.viajes import Viaje as ViajeModelo
from app.schemas.chofer import (
    CantidadesOperacion,
    IntegranteNominaOperacion,
    OperacionAsignada,
    PasajeroOperacion,
)
from app.schemas.servicios import Parada
from app.schemas.viajes import Viaje
from app.services.servicios import paradas_de_recorrido


def _a_viaje(viaje: ViajeModelo) -> Viaje:
    """Construye el Viaje contratado omitiendo horario cuando es NULL."""
    campos = {
        "id_viaje": viaje.id_viaje,
        "id_servicio": viaje.id_servicio,
        "id_recorrido": viaje.id_recorrido,
        "id_vehiculo": viaje.id_vehiculo,
        "id_chofer": viaje.id_chofer,
        "fecha": viaje.fecha,
        "sentido": viaje.sentido,
        "estado": viaje.estado,
    }
    if viaje.horario is not None:
        campos["horario"] = viaje.horario.strftime("%H:%M")
    return Viaje(**campos)


async def listar_viajes_propios(
    db: AsyncSession, usuario: UsuarioActual, fecha: date | None = None
) -> list[Viaje]:
    """Solo asignaciones de la fecha elegida; sin asignaciones -> [] (RN-029)."""
    dia = fecha if fecha is not None else date.today()
    consulta = (
        select(ViajeModelo)
        .where(ViajeModelo.id_chofer == usuario.id_persona, ViajeModelo.fecha == dia)
        .order_by(
            ViajeModelo.horario.asc().nulls_last(),
            ViajeModelo.id_viaje.asc(),
        )
    )
    viajes = (await db.scalars(consulta)).all()
    return [_a_viaje(viaje) for viaje in viajes]


async def detalle_viaje_propio(
    db: AsyncSession, usuario: UsuarioActual, id_viaje: int
) -> OperacionAsignada:
    """Detalle solo del chofer asignado; viaje ajeno e inexistente devuelven el mismo 404."""
    viaje = await db.scalar(
        select(ViajeModelo).where(
            ViajeModelo.id_viaje == id_viaje,
            ViajeModelo.id_chofer == usuario.id_persona,
        )
    )
    if viaje is None:
        raise ApiError(404, "VIAJE_NO_ENCONTRADO", "El viaje no existe.")

    # Reutilizamos el servicio compartido de recorridos, sin duplicar su lógica.
    paradas = [
        Parada.model_validate(parada.model_dump(exclude_none=True))
        for parada in await paradas_de_recorrido(db, viaje.id_recorrido)
    ]

    filas = (
        await db.execute(
            select(Reserva, Persona, Pasajero, Abordaje.id_abordaje)
            .join(Persona, Persona.id_persona == Reserva.id_pasajero)
            .join(Pasajero, Pasajero.id_persona == Reserva.id_pasajero)
            .outerjoin(
                Abordaje,
                and_(
                    Abordaje.id_pasajero == Reserva.id_pasajero,
                    Abordaje.id_viaje == Reserva.id_viaje,
                ),
            )
            .where(
                Reserva.id_viaje == id_viaje,
                Reserva.estado.in_(("provisional", "consolidada")),
            )
            .order_by(Reserva.orden_parada, Reserva.id_reserva)
        )
    ).all()

    pasajeros = [
        PasajeroOperacion(
            id_reserva=reserva.id_reserva,
            id_pasajero=reserva.id_pasajero,
            id_viaje=reserva.id_viaje,
            orden_parada=reserva.orden_parada,
            estado=reserva.estado,
            nombre=persona.nombre,
            apellido=persona.apellido,
            dni=persona.dni,
            fotografia=pasajero.fotografia,
            abordaje_registrado=id_abordaje is not None,
        )
        for reserva, persona, pasajero, id_abordaje in filas
    ]

    nomina = (
        await db.scalars(
            select(IntegranteNomina)
            .where(IntegranteNomina.id_viaje == id_viaje)
            .order_by(IntegranteNomina.id_integrante_nomina)
        )
    ).all()
    integrantes = [
        IntegranteNominaOperacion(
            id_integrante_nomina=integrante.id_integrante_nomina,
            nombre=integrante.nombre,
            apellido=integrante.apellido,
            dni=integrante.dni,
        )
        for integrante in nomina
    ]

    consolidadas = sum(p.estado == "consolidada" for p in pasajeros)
    provisionales = sum(p.estado == "provisional" for p in pasajeros)

    return OperacionAsignada(
        viaje=_a_viaje(viaje),
        capacidad_planificada=viaje.capacidad_planificada,
        paradas=paradas,
        pasajeros_con_reserva=pasajeros,
        integrantes_nomina=integrantes,
        cantidades=CantidadesOperacion(
            consolidadas=consolidadas,
            provisionales=provisionales,
            total_reservas=len(pasajeros),
            total_nomina=len(integrantes),
            abordajes_registrados=sum(p.abordaje_registrado for p in pasajeros),
        ),
    )
