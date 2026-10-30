"""Vínculo CU-036 candidato D1: solo rama aislada, pendiente de aprobación triple."""

from datetime import datetime

from sqlalchemy import BigInteger, CheckConstraint, DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class PagoMercadoPago(Base):
    __tablename__ = "pago_mercadopago"
    __table_args__ = (
        CheckConstraint("id_operacion ~ '^[0-9]{1,64}$'", name="ck_mp_operacion"),
        CheckConstraint("id_receptor > 0", name="ck_mp_receptor"),
        CheckConstraint("moneda ~ '^[A-Z]{3}$'", name="ck_mp_moneda"),
    )

    id_operacion: Mapped[str] = mapped_column(String(64), primary_key=True)
    id_pago: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("pago.id_pago", ondelete="RESTRICT"), unique=True
    )
    id_receptor: Mapped[int] = mapped_column(BigInteger)
    moneda: Mapped[str] = mapped_column(String(3))
    creado_en: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
