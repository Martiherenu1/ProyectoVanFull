"""Bloque 2 — Servicios y contratación (6 tablas de schema.sql)."""

from datetime import date
from decimal import Decimal

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    Date,
    ForeignKey,
    Identity,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models._comun import check_en

TIPOS_SERVICIO = ("UNIVERSITARIO", "LABORAL", "CORPORATIVO", "ESPECIAL")
MODALIDADES_ABONO = ("IDA", "VUELTA", "IDA_VUELTA")


class Servicio(Base):
    __tablename__ = "servicio"
    __table_args__ = (check_en("tipo_servicio", TIPOS_SERVICIO),)

    id_servicio: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    tipo_servicio: Mapped[str] = mapped_column(String(20))


class Tarifa(Base):
    __tablename__ = "tarifa"
    __table_args__ = (CheckConstraint("importe >= 0"),)

    id_tarifa: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    nombre: Mapped[str] = mapped_column(String(120))
    importe: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    tipo: Mapped[str | None] = mapped_column(String(40))
    fecha_creacion: Mapped[date] = mapped_column(Date, server_default=func.current_date())
    fecha_vigencia: Mapped[date | None] = mapped_column(Date)


class Contratacion(Base):
    __tablename__ = "contratacion"
    __table_args__ = (
        CheckConstraint("importe_acordado IS NULL OR importe_acordado >= 0"),
        # Soporte de la FK compuesta de movimiento_cuenta.
        UniqueConstraint("id_contratacion", "id_cliente"),
    )

    id_contratacion: Mapped[int] = mapped_column(
        BigInteger, Identity(always=True), primary_key=True
    )
    id_cliente: Mapped[int] = mapped_column(BigInteger, ForeignKey("cliente.id_cliente"))
    id_servicio: Mapped[int] = mapped_column(BigInteger, ForeignKey("servicio.id_servicio"))
    id_tarifa: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("tarifa.id_tarifa"))
    importe_acordado: Mapped[Decimal | None] = mapped_column(Numeric(12, 2))
    condiciones_comerciales: Mapped[str | None] = mapped_column(Text)


class AbonoMensual(Base):
    __tablename__ = "abono_mensual"
    __table_args__ = (check_en("modalidad", MODALIDADES_ABONO, admite_nulo=True),)

    id_abono_mensual: Mapped[int] = mapped_column(
        BigInteger, Identity(always=True), primary_key=True
    )
    # 1:0..1 con contratacion.
    id_contratacion: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("contratacion.id_contratacion"), unique=True
    )
    # Beneficiario del abono.
    id_pasajero: Mapped[int] = mapped_column(BigInteger, ForeignKey("pasajero.id_persona"))
    modalidad: Mapped[str | None] = mapped_column(String(20))
    # Días contratados, por ejemplo "L,M,X,J,V".
    dias_semanales: Mapped[str | None] = mapped_column(String(30))
    estado: Mapped[str] = mapped_column(String(30), server_default="activo")


class PeriodoAbono(Base):
    __tablename__ = "periodo_abono"
    __table_args__ = (UniqueConstraint("id_abono_mensual", "periodo"),)

    id_periodo_abono: Mapped[int] = mapped_column(
        BigInteger, Identity(always=True), primary_key=True
    )
    id_abono_mensual: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("abono_mensual.id_abono_mensual")
    )
    # 'YYYY-MM'
    periodo: Mapped[str] = mapped_column(String(7))
    estado: Mapped[str] = mapped_column(String(30), server_default="vigente")


class PeriodoAbonoViaje(Base):
    __tablename__ = "periodo_abono_viaje"

    id_periodo_abono: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("periodo_abono.id_periodo_abono"), primary_key=True
    )
    id_viaje: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("viaje.id_viaje"), primary_key=True
    )
