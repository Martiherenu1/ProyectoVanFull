"""Bloque 5 — Trazabilidad operativa (1 tabla de schema.sql).

`evento_operativo` no se escribe directo desde los servicios: se usa el helper de la base común
(Issue de convenciones), que valida MR-R29 antes de llegar acá.
"""

from datetime import datetime

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Identity,
    String,
    Text,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class EventoOperativo(Base):
    __tablename__ = "evento_operativo"
    __table_args__ = (
        # A lo sumo un origen directo entre reserva, pago y viaje (MR-R29).
        CheckConstraint(
            "(CASE WHEN id_reserva IS NOT NULL THEN 1 ELSE 0 END"
            " + CASE WHEN id_pago IS NOT NULL THEN 1 ELSE 0 END"
            " + CASE WHEN id_viaje IS NOT NULL THEN 1 ELSE 0 END) <= 1"
        ),
    )

    id_evento_operativo: Mapped[int] = mapped_column(
        BigInteger, Identity(always=True), primary_key=True
    )
    tipo_evento: Mapped[str] = mapped_column(String(50))
    fecha_hora: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    detalle_evento: Mapped[str | None] = mapped_column(Text)
    id_reserva: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("reserva.id_reserva"))
    id_pago: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("pago.id_pago"))
    id_viaje: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("viaje.id_viaje"))
