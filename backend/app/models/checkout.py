"""Intención Checkout candidata, exclusivamente en la extensión optativa CU-036."""

from datetime import datetime

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    DateTime,
    ForeignKeyConstraint,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class CheckoutMercadoPago(Base):
    __tablename__ = "checkout_mercadopago"
    __table_args__ = (
        UniqueConstraint("id_cliente", "clave_solicitud"),
        ForeignKeyConstraint(
            ["id_pago", "id_cliente"], ["pago.id_pago", "pago.id_cliente"], ondelete="RESTRICT"
        ),
        CheckConstraint(
            "estado_tecnico IN ('CREANDO','LISTO','INCIERTO')", name="ck_checkout_estado"
        ),
    )

    id_intento: Mapped[str] = mapped_column(String(36), primary_key=True)
    id_cliente: Mapped[int] = mapped_column(BigInteger)
    clave_solicitud: Mapped[str] = mapped_column(String(36))
    id_pago: Mapped[int] = mapped_column(BigInteger, unique=True)
    id_preferencia: Mapped[str | None] = mapped_column(String(160), unique=True)
    url_checkout: Mapped[str | None] = mapped_column(Text)
    estado_tecnico: Mapped[str] = mapped_column(String(12), server_default="CREANDO")
    creado_en: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
