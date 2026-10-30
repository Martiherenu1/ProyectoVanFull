"""Registro y decisión administrativa de pagos (CU-014 y CU-016)."""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.core.security import UsuarioActual
from app.models.cuenta_corriente import Comprobante, CuentaCorriente, MovimientoCuenta
from app.models.cuenta_corriente import Pago as PagoModelo
from app.models.personas import Cliente, ClienteIndividual
from app.schemas.pagos import Pago, PagoCreate
from app.services.eventos import registrar_evento

TIPO_PAGO_REGISTRADO = "pago_registrado"
TIPO_PAGO_CONFIRMADO = "pago_confirmado"
TIPO_PAGO_RECHAZADO = "pago_rechazado"


async def listar_pagos_pendientes(db: AsyncSession) -> list[Pago]:
    """Consulta CU-016/RN-015, sin efectos contables ni revalidación de confirmados."""
    pagos = await db.scalars(
        select(PagoModelo)
        .where(PagoModelo.estado == "PENDIENTE")
        .order_by(PagoModelo.fecha_hora, PagoModelo.id_pago)
    )
    return [_a_schema(pago) for pago in pagos]


def _a_schema(pago: PagoModelo) -> Pago:
    return Pago(
        id_pago=pago.id_pago,
        id_cliente=pago.id_cliente,
        importe=float(pago.importe),
        medio_pago=pago.medio_pago,
        estado=pago.estado,
        fecha_hora=pago.fecha_hora,
    )


async def _cliente_del_pasajero(
    db: AsyncSession, usuario: UsuarioActual, pedido: int | None
) -> int:
    """La cuenta propia del pasajero: el cliente individual de su persona, con cuenta corriente.

    No se crea ninguna de las dos: qué hacer con un cliente sin cuenta sigue pendiente en #84, así
    que se responde 404 en vez de dejar que falle la clave foránea de `pago`.
    """
    fila = (
        await db.execute(
            select(ClienteIndividual.id_cliente, CuentaCorriente.id_cliente)
            .outerjoin(CuentaCorriente, CuentaCorriente.id_cliente == ClienteIndividual.id_cliente)
            .where(ClienteIndividual.id_persona == usuario.id_persona)
        )
    ).one_or_none()
    if fila is None:
        raise ApiError(
            404,
            "CLIENTE_NO_ENCONTRADO",
            "No hay un cliente individual asociado al pasajero autenticado.",
        )
    id_cliente, id_cuenta = fila
    if pedido is not None and pedido != id_cliente:
        raise ApiError(403, "SIN_PERMISO", "Solo podés registrar pagos de tu propia cuenta.")
    if id_cuenta is None:
        raise ApiError(
            404,
            "CUENTA_CORRIENTE_NO_ENCONTRADA",
            "Tu cliente todavía no tiene cuenta corriente donde registrar el pago.",
        )
    return id_cliente


async def _exigir_cuenta_corriente(db: AsyncSession, id_cliente: int) -> None:
    """El cliente que indica administración existe y tiene cuenta corriente donde registrar el pago.

    Sin esto el INSERT fallaría por la clave foránea de `pago` y la API respondería 500.
    """
    fila = (
        await db.execute(
            select(Cliente.id_cliente, CuentaCorriente.id_cliente)
            .outerjoin(CuentaCorriente, CuentaCorriente.id_cliente == Cliente.id_cliente)
            .where(Cliente.id_cliente == id_cliente)
        )
    ).one_or_none()
    if fila is None:
        raise ApiError(
            404, "CLIENTE_NO_ENCONTRADO", "No existe un cliente con el identificador indicado."
        )
    if fila[1] is None:
        raise ApiError(
            404,
            "CUENTA_CORRIENTE_NO_ENCONTRADA",
            "El cliente indicado todavía no tiene cuenta corriente donde registrar el pago.",
        )


async def registrar_pago(db: AsyncSession, usuario: UsuarioActual, datos: PagoCreate) -> Pago:
    """Registra la parte persistible de CU-014 en una única transacción.

    `tipo` y `evidencia_pago` están en OpenAPI pero no tienen columnas en el modelo aprobado. Mientras
    esa contradicción siga pendiente, se rechazan explícitamente para no perder datos en silencio.

    Administración indica el cliente, que debe existir y tener cuenta corriente (404 si no); el
    pasajero solo puede registrar pagos de su propia cuenta (pantalla 5 del PC1). Con ambos roles,
    manda el de administración.
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

    if set(usuario.roles) & {"administrador", "dueno"}:
        if datos.id_cliente is None:
            raise ApiError(
                400,
                "VALIDACION",
                "Falta el cliente del pago.",
                {"campos_faltantes": ["id_cliente"]},
            )
        id_cliente = datos.id_cliente
        await _exigir_cuenta_corriente(db, id_cliente)
    else:
        id_cliente = await _cliente_del_pasajero(db, usuario, datos.id_cliente)

    pago = await preparar_pago_pendiente(
        db, id_cliente=id_cliente, importe=datos.importe, medio_pago=datos.medio_pago
    )
    await db.commit()
    return _a_schema(pago)


async def preparar_pago_pendiente(
    db: AsyncSession, *, id_cliente: int, importe, medio_pago: str
) -> PagoModelo:
    """Preparación común sin commit: el llamador ya validó identidad/cuenta/contrato.

    Permite guardar intención+Pago atómicamente sin duplicar evento ni reglas contables.
    El registro manual conserva su commit y comportamiento anteriores.
    """
    pago = PagoModelo(
        id_cliente=id_cliente,
        importe=importe,
        medio_pago=medio_pago,
        estado="PENDIENTE",
    )
    db.add(pago)
    await db.flush()
    await registrar_evento(db, tipo_evento=TIPO_PAGO_REGISTRADO, id_pago=pago.id_pago)
    return pago


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
