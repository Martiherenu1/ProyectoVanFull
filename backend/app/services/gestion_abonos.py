"""Gestión de abonos mensuales por administración y dueño (CU-028, RF-044).

Alcance: alta del abono (con su contratación y, si se indica, su primer período), listado y consulta,
modificación de modalidad y días, y alta de períodos. El rol ya lo exigió el router.

Solo hay abono para servicios UNIVERSITARIO y LABORAL (estudiante y laboral son categorías de
pasajero, no actores nuevos). El pasajero tiene que existir y no estar dado de baja.

Interpretación a validar con Martín: la contratación necesita un cliente (`contratacion.id_cliente`
es obligatorio). Si el pasajero todavía no es cliente individual, el alta lo crea junto con su cuenta
corriente (1:1), que es lo que el modelo exige para poder contratar.

PENDIENTES (v1.3 y RN, no se inventan):
- Estados: `abono_mensual.estado` y `periodo_abono.estado` son texto libre y no hay catálogo
  aprobado. El alta usa los valores por defecto del modelo (`activo` y `vigente`) y el estado no se
  edita a mano.
- RN-004 (A2): advertencia, suspensión y pérdida de cupo «podrán» aplicarse, no son automáticas, y
  el modelo no tiene dónde guardar la advertencia. Tampoco hay evaluación automática del período de
  pago (días 1 a 10, A1): los pagos no están asociados a un período.
- RN-005 (A3): la habilitación excepcional por 5 días no tiene tabla; igual que en CU-013 y CU-015.
- RN-008 (A6): la reserva anual del estudiante no tiene modelo propio.
- A7 y la precondición de cupo: el cupo se calcula al reservar cada viaje (CU-003); el alta del
  abono no reserva viajes ni asigna cupo.
- A4 y A5 viven en otros CU: el límite de deuda (CU-015, RN-006) y que los viajes de un abono no
  generan devolución (RN-007, ya aplicado en la cancelación de reservas).
- No hay baja del abono: el CU no la prevé y hay reservas que lo referencian.
- No se impide tener más de un abono para el mismo pasajero y servicio: la regla no está definida.
"""

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.models.cuenta_corriente import CuentaCorriente
from app.models.personas import Cliente, ClienteIndividual, Pasajero, Persona
from app.models.servicios import AbonoMensual, Contratacion, PeriodoAbono, Servicio, Tarifa
from app.schemas.gestion_abonos import (
    AbonoGestion,
    AbonoGestionCreate,
    AbonoGestionLista,
    AbonoGestionUpdate,
    PeriodoAbonoGestion,
)

SERVICIOS_CON_ABONO = ("UNIVERSITARIO", "LABORAL")


def _numero(valor) -> float | None:
    return float(valor) if valor is not None else None


def _consulta_base():
    return (
        select(AbonoMensual, Contratacion, Persona, Servicio.tipo_servicio)
        .join(Contratacion, Contratacion.id_contratacion == AbonoMensual.id_contratacion)
        .join(Persona, Persona.id_persona == AbonoMensual.id_pasajero)
        .join(Servicio, Servicio.id_servicio == Contratacion.id_servicio)
    )


async def _armar(db: AsyncSession, filas) -> list[AbonoGestion]:
    ids = [f[0].id_abono_mensual for f in filas]
    periodos: dict[int, list[PeriodoAbonoGestion]] = {i: [] for i in ids}
    if ids:
        consulta = (
            select(PeriodoAbono)
            .where(PeriodoAbono.id_abono_mensual.in_(ids))
            .order_by(PeriodoAbono.periodo.desc(), PeriodoAbono.id_periodo_abono.desc())
        )
        for p in (await db.scalars(consulta)).all():
            periodos[p.id_abono_mensual].append(
                PeriodoAbonoGestion(
                    id_periodo_abono=p.id_periodo_abono, periodo=p.periodo, estado=p.estado
                )
            )
    return [
        AbonoGestion(
            id_abono_mensual=a.id_abono_mensual,
            id_contratacion=a.id_contratacion,
            id_pasajero=a.id_pasajero,
            nombre=persona.nombre,
            apellido=persona.apellido,
            id_servicio=c.id_servicio,
            tipo_servicio=tipo,
            id_tarifa=c.id_tarifa,
            importe_acordado=_numero(c.importe_acordado),
            modalidad=a.modalidad,
            dias_semanales=a.dias_semanales,
            estado=a.estado,
            periodos=periodos[a.id_abono_mensual],
        )
        for a, c, persona, tipo in filas
    ]


async def listar(
    db: AsyncSession, *, id_pasajero: int | None, estado: str | None, tipo_servicio: str | None
) -> AbonoGestionLista:
    consulta = _consulta_base().order_by(AbonoMensual.id_abono_mensual.desc())
    for columna, valor in (
        (AbonoMensual.id_pasajero, id_pasajero),
        (AbonoMensual.estado, estado),
        (Servicio.tipo_servicio, tipo_servicio),
    ):
        if valor is not None:
            consulta = consulta.where(columna == valor)
    items = await _armar(db, (await db.execute(consulta)).all())
    return AbonoGestionLista(items=items, total=len(items))


async def obtener(db: AsyncSession, id_abono: int) -> AbonoGestion:
    filas = (
        await db.execute(_consulta_base().where(AbonoMensual.id_abono_mensual == id_abono))
    ).all()
    if not filas:
        raise ApiError(404, "ABONO_NO_ENCONTRADO", "No existe un abono con ese identificador.")
    return (await _armar(db, filas))[0]


async def _cliente_del_pasajero(db: AsyncSession, id_persona: int) -> int:
    """El cliente individual del pasajero; si todavía no lo es, lo crea con su cuenta corriente."""
    id_cliente = await db.scalar(
        select(ClienteIndividual.id_cliente).where(ClienteIndividual.id_persona == id_persona)
    )
    if id_cliente is not None:
        return id_cliente
    cliente = Cliente(naturaleza_cliente="INDIVIDUAL")
    db.add(cliente)
    await db.flush()
    db.add(ClienteIndividual(id_cliente=cliente.id_cliente, id_persona=id_persona))
    db.add(CuentaCorriente(id_cliente=cliente.id_cliente))
    await db.flush()
    return cliente.id_cliente


async def crear(db: AsyncSession, datos: AbonoGestionCreate) -> AbonoGestion:
    estado_habilitacion = await db.scalar(
        select(Pasajero.estado_habilitacion).where(Pasajero.id_persona == datos.id_pasajero)
    )
    if estado_habilitacion is None:
        raise ApiError(
            404, "PASAJERO_NO_ENCONTRADO", "No existe un pasajero con ese identificador."
        )
    if estado_habilitacion == "baja":
        raise ApiError(409, "PASAJERO_DADO_DE_BAJA", "El pasajero está dado de baja.")

    tipo = await db.scalar(
        select(Servicio.tipo_servicio).where(Servicio.id_servicio == datos.id_servicio)
    )
    if tipo is None:
        raise ApiError(
            404, "SERVICIO_NO_ENCONTRADO", "No existe un servicio con ese identificador."
        )
    if tipo not in SERVICIOS_CON_ABONO:
        raise ApiError(
            409,
            "SERVICIO_SIN_ABONO",
            "Solo los servicios universitarios y laborales tienen abono mensual.",
            {"tipo_servicio": tipo},
        )

    if datos.id_tarifa is not None:
        existe = await db.scalar(
            select(Tarifa.id_tarifa).where(Tarifa.id_tarifa == datos.id_tarifa)
        )
        if existe is None:
            raise ApiError(
                404, "TARIFA_NO_ENCONTRADA", "No existe una tarifa con ese identificador."
            )

    id_cliente = await _cliente_del_pasajero(db, datos.id_pasajero)
    contratacion = Contratacion(
        id_cliente=id_cliente,
        id_servicio=datos.id_servicio,
        id_tarifa=datos.id_tarifa,
        importe_acordado=datos.importe_acordado,
    )
    db.add(contratacion)
    await db.flush()
    abono = AbonoMensual(
        id_contratacion=contratacion.id_contratacion,
        id_pasajero=datos.id_pasajero,
        modalidad=datos.modalidad,
        dias_semanales=datos.dias_semanales,
        estado="activo",
    )
    db.add(abono)
    await db.flush()
    if datos.periodo is not None:
        db.add(
            PeriodoAbono(
                id_abono_mensual=abono.id_abono_mensual, periodo=datos.periodo, estado="vigente"
            )
        )
        await db.flush()
    id_abono = abono.id_abono_mensual
    resultado = await obtener(db, id_abono)
    await db.commit()
    return resultado


async def _bloquear(db: AsyncSession, id_abono: int) -> AbonoMensual:
    abono = (
        await db.execute(
            select(AbonoMensual).where(AbonoMensual.id_abono_mensual == id_abono).with_for_update()
        )
    ).scalar_one_or_none()
    if abono is None:
        raise ApiError(404, "ABONO_NO_ENCONTRADO", "No existe un abono con ese identificador.")
    return abono


async def modificar(db: AsyncSession, id_abono: int, datos: AbonoGestionUpdate) -> AbonoGestion:
    abono = await _bloquear(db, id_abono)
    for campo in datos.model_fields_set:
        setattr(abono, campo, getattr(datos, campo))
    await db.flush()
    resultado = await obtener(db, id_abono)
    await db.commit()
    return resultado


async def agregar_periodo(db: AsyncSession, id_abono: int, periodo: str) -> AbonoGestion:
    await _bloquear(db, id_abono)
    repetido = await db.scalar(
        select(func.count())
        .select_from(PeriodoAbono)
        .where(PeriodoAbono.id_abono_mensual == id_abono, PeriodoAbono.periodo == periodo)
    )
    if repetido:
        raise ApiError(
            409, "PERIODO_DUPLICADO", "El abono ya tiene ese período.", {"periodo": periodo}
        )
    db.add(PeriodoAbono(id_abono_mensual=id_abono, periodo=periodo, estado="vigente"))
    await db.flush()
    resultado = await obtener(db, id_abono)
    await db.commit()
    return resultado
