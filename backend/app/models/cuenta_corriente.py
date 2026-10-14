"""Bloque 4 — Cuenta corriente, pagos y comprobantes (4 tablas de schema.sql).

El saldo y la deuda **no se persisten**: se calculan a partir de `movimiento_cuenta` (MR-R30).
"""

from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    DateTime,
    ForeignKey,
    ForeignKeyConstraint,
    Identity,
    Numeric,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models._comun import check_en

MEDIOS_PAGO = ("EFECTIVO", "TRANSFERENCIA", "BILLETERA", "CUENTA_CORRIENTE", "MERCADO_PAGO")
ESTADOS_PAGO = ("PENDIENTE", "CONFIRMADO", "RECHAZADO")
NATURALEZAS_MOVIMIENTO = ("DEUDOR", "ACREEDOR")
TIPOS_COMPROBANTE = ("RECIBO", "FACTURA", "NOTA_DE_CREDITO", "NOTA_DE_DEBITO")


class CuentaCorriente(Base):
    """1:1 con cliente."""

    __tablename__ = "cuenta_corriente"

    id_cliente: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("cliente.id_cliente"), primary_key=True
    )


class Pago(Base):
    __tablename__ = "pago"
    __table_args__ = (
        CheckConstraint("importe >= 0"),
        check_en("medio_pago", MEDIOS_PAGO),
        check_en("estado", ESTADOS_PAGO),
        # Soporte de la FK compuesta de movimiento_cuenta.
        UniqueConstraint("id_pago", "id_cliente"),
    )

    id_pago: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    id_cliente: Mapped[int] = mapped_column(BigInteger, ForeignKey("cuenta_corriente.id_cliente"))
    importe: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    fecha_hora: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    medio_pago: Mapped[str] = mapped_column(String(20))
    estado: Mapped[str] = mapped_column(String(20), server_default="PENDIENTE")


class MovimientoCuenta(Base):
    __tablename__ = "movimiento_cuenta"
    __table_args__ = (
        # El pago y la contratación tienen que ser del mismo cliente que el movimiento.
        ForeignKeyConstraint(["id_pago", "id_cliente"], ["pago.id_pago", "pago.id_cliente"]),
        ForeignKeyConstraint(
            ["id_contratacion", "id_cliente"],
            ["contratacion.id_contratacion", "contratacion.id_cliente"],
        ),
        check_en("naturaleza", NATURALEZAS_MOVIMIENTO),
        CheckConstraint("importe >= 0"),
    )

    id_movimiento_cuenta: Mapped[int] = mapped_column(
        BigInteger, Identity(always=True), primary_key=True
    )
    id_cliente: Mapped[int] = mapped_column(BigInteger, ForeignKey("cuenta_corriente.id_cliente"))
    id_contratacion: Mapped[int | None] = mapped_column(BigInteger)
    # 0..1 movimiento por pago.
    id_pago: Mapped[int | None] = mapped_column(BigInteger, unique=True)
    naturaleza: Mapped[str] = mapped_column(String(20))
    estado: Mapped[str] = mapped_column(String(20), server_default="pendiente")
    importe: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    fecha_hora: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Comprobante(Base):
    """Documento que emite la empresa. No es la evidencia que sube el pasajero (ver `PagoCreate`)."""

    __tablename__ = "comprobante"
    __table_args__ = (
        check_en("tipo", TIPOS_COMPROBANTE),
        # Cada tipo admite exactamente un origen, compatible con el tipo (MR-R28).
        CheckConstraint(
            "(tipo = 'RECIBO' AND id_pago IS NOT NULL AND id_contratacion IS NULL"
            " AND id_movimiento_cuenta IS NULL)"
            " OR (tipo = 'FACTURA' AND id_pago IS NULL AND id_contratacion IS NOT NULL"
            " AND id_movimiento_cuenta IS NULL)"
            " OR (tipo IN ('NOTA_DE_CREDITO', 'NOTA_DE_DEBITO') AND id_pago IS NULL"
            " AND id_contratacion IS NULL AND id_movimiento_cuenta IS NOT NULL)",
            name="ck_comprobante_origen_tipo",
        ),
    )

    id_comprobante: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    tipo: Mapped[str] = mapped_column(String(20))
    id_pago: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("pago.id_pago"), unique=True)
    id_contratacion: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("contratacion.id_contratacion")
    )
    id_movimiento_cuenta: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("movimiento_cuenta.id_movimiento_cuenta"), unique=True
    )
