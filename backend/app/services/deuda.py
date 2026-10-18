"""Consulta de deuda (CU-006, RF-010, RN-004 a RN-006 y MR-R30).

El saldo deudor no se persiste: se deriva de los movimientos de la cuenta corriente.
"""

from decimal import Decimal

from sqlalchemy import case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.core.security import UsuarioActual
from app.models.cuenta_corriente import CuentaCorriente, MovimientoCuenta
from app.models.personas import ClienteIndividual
from app.schemas.deuda import Deuda

ESTADO_AL_DIA = "al_dia"
ESTADO_CON_DEUDA = "con_deuda"


async def consultar_deuda_propia(db: AsyncSession, usuario: UsuarioActual) -> Deuda:
    """Devuelve la deuda del cliente individual asociado al pasajero autenticado."""
    id_cliente = (
        await db.execute(
            select(ClienteIndividual.id_cliente).where(
                ClienteIndividual.id_persona == usuario.id_persona
            )
        )
    ).scalar_one_or_none()
    if id_cliente is None:
        raise ApiError(
            404,
            "CLIENTE_NO_ENCONTRADO",
            "No hay un cliente individual asociado al pasajero autenticado.",
        )

    tiene_cuenta = (
        await db.execute(
            select(CuentaCorriente.id_cliente).where(CuentaCorriente.id_cliente == id_cliente)
        )
    ).scalar_one_or_none()
    if tiene_cuenta is None:
        return Deuda(saldo=Decimal("0.00"), estado=ESTADO_AL_DIA)

    # MR-R30: DEUDOR aumenta el saldo y ACREEDOR lo reduce. El resultado no se guarda.
    # El MR define cada MOVIMIENTO_CUENTA como un impacto económico y deja pendiente el catálogo
    # físico de estados; por eso el campo `estado` no agrega un filtro no aprobado al cálculo.
    importe_con_signo = case(
        (MovimientoCuenta.naturaleza == "DEUDOR", MovimientoCuenta.importe),
        else_=-MovimientoCuenta.importe,
    )
    saldo_neto = (
        await db.execute(
            select(func.coalesce(func.sum(importe_con_signo), 0)).where(
                MovimientoCuenta.id_cliente == id_cliente
            )
        )
    ).scalar_one()
    saldo_deudor = max(Decimal(saldo_neto), Decimal("0.00"))

    return Deuda(
        saldo=saldo_deudor,
        estado=ESTADO_CON_DEUDA if saldo_deudor > 0 else ESTADO_AL_DIA,
    )
