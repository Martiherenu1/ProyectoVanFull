"""Registro y decisión administrativa de pagos (CU-014 y CU-016)."""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.models.cuenta_corriente import Comprobante, MovimientoCuenta
from app.models.cuenta_corriente import Pago as PagoModelo
from app.schemas.pagos import Pago, PagoCreate
from app.services.eventos import registrar_evento

TIPO_PAGO_REGISTRADO = "pago_registrado"
TIPO_PAGO_CONFIRMADO = "pago_confirmado"
TIPO_PAGO_RECHAZADO = "pago_rechazado"


def _a_schema(pago: PagoModelo) -> Pago:
    return Pago(
        id_pago=pago.id_pago,
        id_cliente=pago.id_cliente,
        importe=float(pago.importe),
        medio_pago=pago.medio_pago,
        estado=pago.estado,
        fecha_hora=pago.fecha_hora,
    )


async def registrar_pago(db: AsyncSession, datos: PagoCreate) -> Pago:
    """Registra la parte persistible de CU-014 en una única transacción.

    `tipo` y `evidencia_pago` están en OpenAPI pero no tienen columnas en el modelo aprobado. Mientras
    esa contradicción siga pendiente, se rechazan explícitamente para no perder datos en silencio.
    """
    campos_sin_persistencia = [
        campo
        for campo, valor in (("tipo", datos.tipo), ("evidencia_pago", datos.evidencia_pago))
        if valor is not None
    ]
    if campos_sin_persistencia:
        raise ApiError(
            400,
            "VALIDACION",
            "Los campos enviados todavía no pueden conservarse con el modelo vigente.",
            {"campos_pendientes": campos_sin_persistencia},
        )

    pago = PagoModelo(
        id_cliente=datos.id_cliente,
        importe=datos.importe,
        medio_pago=datos.medio_pago,
        estado="PENDIENTE",
    )
    db.add(pago)
    await db.flush()
    await registrar_evento(db, tipo_evento=TIPO_PAGO_REGISTRADO, id_pago=pago.id_pago)
    await db.commit()
    return _a_schema(pago)


async def decidir_pago_pendiente(db: AsyncSession, id_pago: int, decision: str) -> Pago:
    """Decide un pago pendiente y registra todo en una única transacción.

    El bloqueo de la fila evita que dos administradores decidan el mismo pago a la vez. El filtro
    por PENDIENTE también impide revalidar un pago que ya fue confirmado automáticamente.
    """
    pago = (
        await db.execute(
            select(PagoModelo)
            .where(PagoModelo.id_pago == id_pago, PagoModelo.estado == "PENDIENTE")
            .with_for_update()
        )
    ).scalar_one_or_none()
    if pago is None:
        raise ApiError(
            404,
            "PAGO_PENDIENTE_NO_ENCONTRADO",
            "No se encontró un pago pendiente con ese identificador.",
        )

    pago.estado = decision
    if decision == "CONFIRMADO":
        db.add(Comprobante(tipo="RECIBO", id_pago=pago.id_pago))
        db.add(
            MovimientoCuenta(
                id_cliente=pago.id_cliente,
                id_pago=pago.id_pago,
                naturaleza="ACREEDOR",
                importe=pago.importe,
            )
        )

    # Fuerza ahora los controles contables y del comprobante, antes de agregar el evento.
    await db.flush()
    await registrar_evento(
        db,
        tipo_evento=(TIPO_PAGO_CONFIRMADO if decision == "CONFIRMADO" else TIPO_PAGO_RECHAZADO),
        id_pago=pago.id_pago,
    )
    await db.commit()
    return _a_schema(pago)
