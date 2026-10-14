"""Bloque 3 — Viajes, recorridos y operación (12 tablas de schema.sql).

Las FK compuestas (reserva y abordaje contra viaje y parada_recorrido) se declaran con
`ForeignKeyConstraint`, igual que en schema.sql: son las que hacen que una reserva no pueda
apuntar a una parada que no pertenece al recorrido del viaje.
"""

from datetime import date, datetime, time
from decimal import Decimal

from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    ForeignKeyConstraint,
    Identity,
    Integer,
    Numeric,
    String,
    Time,
    UniqueConstraint,
    false,
    func,
    true,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models._comun import check_en

SENTIDOS = ("IDA", "VUELTA")
ESTADOS_VIAJE = ("programado", "en_curso", "finalizado", "cancelado")
ESTADOS_RESERVA = ("provisional", "consolidada", "cancelada")


class Recorrido(Base):
    __tablename__ = "recorrido"

    id_recorrido: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)


class Parada(Base):
    __tablename__ = "parada"

    id_parada: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    nombre_descripcion: Mapped[str | None] = mapped_column(String(150))
    direccion: Mapped[str | None] = mapped_column(String(200))
    latitud: Mapped[Decimal | None] = mapped_column(Numeric(9, 6))
    longitud: Mapped[Decimal | None] = mapped_column(Numeric(9, 6))


class ParadaRecorrido(Base):
    __tablename__ = "parada_recorrido"

    id_recorrido: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("recorrido.id_recorrido"), primary_key=True
    )
    # Único por recorrido (forma parte de la PK).
    orden: Mapped[int] = mapped_column(Integer, primary_key=True)
    id_parada: Mapped[int] = mapped_column(BigInteger, ForeignKey("parada.id_parada"))
    comprometida: Mapped[bool] = mapped_column(Boolean, server_default=false())


class Vehiculo(Base):
    __tablename__ = "vehiculo"
    __table_args__ = (CheckConstraint("capacidad > 0"),)

    id_vehiculo: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    patente: Mapped[str] = mapped_column(String(10), unique=True)
    marca: Mapped[str | None] = mapped_column(String(50))
    modelo: Mapped[str | None] = mapped_column(String(50))
    capacidad: Mapped[int] = mapped_column(Integer)
    disponibilidad: Mapped[bool] = mapped_column(Boolean, server_default=true())


class Viaje(Base):
    """Única tabla con dos dueños: administración (alta y asignaciones) y chofer (ejecución)."""

    __tablename__ = "viaje"
    __table_args__ = (
        check_en("sentido", SENTIDOS),
        check_en("estado", ESTADOS_VIAJE),
        CheckConstraint("capacidad_planificada IS NULL OR capacidad_planificada >= 0"),
        # Soporte de las FK compuestas de reserva y abordaje.
        UniqueConstraint("id_viaje", "id_recorrido"),
        UniqueConstraint("id_viaje", "id_vehiculo"),
    )

    id_viaje: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    id_servicio: Mapped[int] = mapped_column(BigInteger, ForeignKey("servicio.id_servicio"))
    id_recorrido: Mapped[int] = mapped_column(BigInteger, ForeignKey("recorrido.id_recorrido"))
    # Vehículo y chofer pueden quedar pendientes durante la planificación (ADJ-03).
    id_vehiculo: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("vehiculo.id_vehiculo"))
    id_chofer: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("chofer.id_persona"))
    fecha: Mapped[date] = mapped_column(Date)
    horario: Mapped[time | None] = mapped_column(Time)
    sentido: Mapped[str] = mapped_column(String(10))
    estado: Mapped[str] = mapped_column(String(20), server_default="programado")
    capacidad_planificada: Mapped[int | None] = mapped_column(Integer)


class PosicionGps(Base):
    """Solo la última posición, sin historial (MR-R31)."""

    __tablename__ = "posicion_gps"

    id_viaje: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("viaje.id_viaje"), primary_key=True
    )
    latitud: Mapped[Decimal | None] = mapped_column(Numeric(9, 6))
    longitud: Mapped[Decimal | None] = mapped_column(Numeric(9, 6))
    fecha_hora_posicion: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class Reserva(Base):
    """El cupo disponible se calcula, no se guarda (MR-R30)."""

    __tablename__ = "reserva"
    __table_args__ = (
        ForeignKeyConstraint(
            ["id_viaje", "id_recorrido"], ["viaje.id_viaje", "viaje.id_recorrido"]
        ),
        ForeignKeyConstraint(
            ["id_recorrido", "orden_parada"],
            ["parada_recorrido.id_recorrido", "parada_recorrido.orden"],
        ),
        ForeignKeyConstraint(
            ["id_periodo_abono", "id_viaje"],
            ["periodo_abono_viaje.id_periodo_abono", "periodo_abono_viaje.id_viaje"],
        ),
        check_en("estado", ESTADOS_RESERVA),
        # Máximo una reserva por pasajero y viaje (MR-R15).
        UniqueConstraint("id_pasajero", "id_viaje"),
        # Respaldo exactamente uno: período de abono XOR contratación directa (MR-R13).
        CheckConstraint("(id_periodo_abono IS NOT NULL) <> (id_contratacion_directa IS NOT NULL)"),
    )

    id_reserva: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    id_pasajero: Mapped[int] = mapped_column(BigInteger, ForeignKey("pasajero.id_persona"))
    id_viaje: Mapped[int] = mapped_column(BigInteger)
    id_recorrido: Mapped[int] = mapped_column(BigInteger)
    orden_parada: Mapped[int] = mapped_column(Integer)
    id_periodo_abono: Mapped[int | None] = mapped_column(BigInteger)
    id_contratacion_directa: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("contratacion.id_contratacion")
    )
    estado: Mapped[str] = mapped_column(String(20), server_default="provisional")


class RegistroListaEspera(Base):
    __tablename__ = "registro_lista_espera"
    # Único por pasajero y viaje (MR-R19).
    __table_args__ = (UniqueConstraint("id_pasajero", "id_viaje"),)

    id_registro_lista_espera: Mapped[int] = mapped_column(
        BigInteger, Identity(always=True), primary_key=True
    )
    id_pasajero: Mapped[int] = mapped_column(BigInteger, ForeignKey("pasajero.id_persona"))
    id_viaje: Mapped[int] = mapped_column(BigInteger, ForeignKey("viaje.id_viaje"))
    # El orden FIFO sale de esta marca (MR-R20).
    fecha_hora_solicitud: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    estado: Mapped[str] = mapped_column(String(20), server_default="en_espera")


class NominaPasajeros(Base):
    """Solo para servicios ESPECIALES."""

    __tablename__ = "nomina_pasajeros"

    id_viaje: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("viaje.id_viaje"), primary_key=True
    )


class IntegranteNomina(Base):
    __tablename__ = "integrante_nomina"
    # Un DNI por nómina (MR-R23).
    __table_args__ = (UniqueConstraint("id_viaje", "dni"),)

    id_integrante_nomina: Mapped[int] = mapped_column(
        BigInteger, Identity(always=True), primary_key=True
    )
    id_viaje: Mapped[int] = mapped_column(BigInteger, ForeignKey("nomina_pasajeros.id_viaje"))
    nombre: Mapped[str] = mapped_column(String(80))
    apellido: Mapped[str] = mapped_column(String(80))
    dni: Mapped[str] = mapped_column(String(20))


class Abordaje(Base):
    __tablename__ = "abordaje"
    __table_args__ = (
        ForeignKeyConstraint(
            ["id_viaje", "id_recorrido"], ["viaje.id_viaje", "viaje.id_recorrido"]
        ),
        # El vehículo del abordaje tiene que ser el del viaje.
        ForeignKeyConstraint(["id_viaje", "id_vehiculo"], ["viaje.id_viaje", "viaje.id_vehiculo"]),
        ForeignKeyConstraint(
            ["id_recorrido", "orden_parada"],
            ["parada_recorrido.id_recorrido", "parada_recorrido.orden"],
        ),
        # Máximo un abordaje válido por pasajero y viaje (MR-R24).
        UniqueConstraint("id_pasajero", "id_viaje"),
    )

    id_abordaje: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    id_pasajero: Mapped[int] = mapped_column(BigInteger, ForeignKey("pasajero.id_persona"))
    id_viaje: Mapped[int] = mapped_column(BigInteger)
    id_vehiculo: Mapped[int] = mapped_column(BigInteger)
    id_recorrido: Mapped[int] = mapped_column(BigInteger)
    orden_parada: Mapped[int] = mapped_column(Integer)


class Ausencia(Base):
    __tablename__ = "ausencia"
    # Máximo una ausencia por pasajero y viaje (MR-R25).
    __table_args__ = (UniqueConstraint("id_pasajero", "id_viaje"),)

    id_ausencia: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    id_pasajero: Mapped[int] = mapped_column(BigInteger, ForeignKey("pasajero.id_persona"))
    id_viaje: Mapped[int] = mapped_column(BigInteger, ForeignKey("viaje.id_viaje"))
