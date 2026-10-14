"""Bloque 1 — Personas, clientes y acceso (12 tablas de schema.sql).

Pasajero y chofer no usan herencia ORM: una misma persona puede ser las dos cosas y el
modelo no tiene discriminador, así que son tablas con PK = FK a persona.
"""

from datetime import date

from sqlalchemy import BigInteger, Boolean, ForeignKey, Identity, String, false
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models._comun import check_en

ESTADOS_HABILITACION = ("habilitado", "suspendido", "baja")
NATURALEZAS_CLIENTE = ("INDIVIDUAL", "PERSONA_JURIDICA")


class Persona(Base):
    __tablename__ = "persona"

    id_persona: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    nombre: Mapped[str] = mapped_column(String(80))
    apellido: Mapped[str] = mapped_column(String(80))
    dni: Mapped[str] = mapped_column(String(20), unique=True)
    direccion: Mapped[str | None] = mapped_column(String(200))
    telefono: Mapped[str | None] = mapped_column(String(30))
    email: Mapped[str | None] = mapped_column(String(120))


class Pasajero(Base):
    __tablename__ = "pasajero"
    __table_args__ = (check_en("estado_habilitacion", ESTADOS_HABILITACION),)

    id_persona: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("persona.id_persona"), primary_key=True
    )
    # Catálogo de categorías a confirmar (universitario/laboral/eventual/empresarial).
    categoria: Mapped[str | None] = mapped_column(String(30))
    estado_habilitacion: Mapped[str] = mapped_column(String(20), server_default="habilitado")
    # Referencia/URL; la estrategia de almacenamiento está por definir.
    fotografia: Mapped[str | None] = mapped_column(String(500))


class Chofer(Base):
    __tablename__ = "chofer"

    id_persona: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("persona.id_persona"), primary_key=True
    )
    cuil: Mapped[str | None] = mapped_column(String(20))
    registro_conducir: Mapped[str | None] = mapped_column(String(40))
    fecha_vencimiento_registro: Mapped[date | None]


class Cliente(Base):
    __tablename__ = "cliente"
    __table_args__ = (check_en("naturaleza_cliente", NATURALEZAS_CLIENTE),)

    id_cliente: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    naturaleza_cliente: Mapped[str] = mapped_column(String(20))


class ClienteIndividual(Base):
    __tablename__ = "cliente_individual"

    id_cliente: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("cliente.id_cliente"), primary_key=True
    )
    id_persona: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("persona.id_persona"), unique=True
    )


class ClientePersonaJuridica(Base):
    __tablename__ = "cliente_persona_juridica"

    id_cliente: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("cliente.id_cliente"), primary_key=True
    )
    razon_social: Mapped[str] = mapped_column(String(150))
    cuit: Mapped[str] = mapped_column(String(20), unique=True)
    direccion: Mapped[str | None] = mapped_column(String(200))


class ClienteCorporativo(Base):
    """Coexiste con cliente_individual o cliente_persona_juridica para el mismo cliente."""

    __tablename__ = "cliente_corporativo"

    id_cliente: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("cliente.id_cliente"), primary_key=True
    )
    estado: Mapped[str] = mapped_column(String(30), server_default="activo")


class ContactoCorporativo(Base):
    __tablename__ = "contacto_corporativo"

    id_cliente_corporativo: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("cliente_corporativo.id_cliente"), primary_key=True
    )
    id_persona: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("persona.id_persona"), primary_key=True
    )
    cargo: Mapped[str | None] = mapped_column(String(80))
    es_representante: Mapped[bool] = mapped_column(Boolean, server_default=false())


class PasajeroCorporativo(Base):
    __tablename__ = "pasajero_corporativo"

    id_cliente_corporativo: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("cliente_corporativo.id_cliente"), primary_key=True
    )
    id_pasajero: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("pasajero.id_persona"), primary_key=True
    )
    estado_vinculo: Mapped[str] = mapped_column(String(30), server_default="activo")


class CuentaAcceso(Base):
    __tablename__ = "cuenta_acceso"

    id_cuenta_acceso: Mapped[int] = mapped_column(
        BigInteger, Identity(always=True), primary_key=True
    )
    id_persona: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("persona.id_persona"), unique=True
    )
    # Email o usuario de login.
    identificador_acceso: Mapped[str] = mapped_column(String(120), unique=True)
    # Hash de la contraseña, nunca la contraseña en claro (decisión del modelo físico, 2026-10-13).
    hash_contrasena: Mapped[str] = mapped_column(String(255))
    estado: Mapped[str] = mapped_column(String(20), server_default="activo")


class RolAcceso(Base):
    """Catálogo de roles (pasajero, chofer, administrador, dueno, representante_corporativo)."""

    __tablename__ = "rol_acceso"

    id_rol_acceso: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    rol: Mapped[str] = mapped_column(String(50), unique=True)


class CuentaRol(Base):
    __tablename__ = "cuenta_rol"

    id_cuenta_acceso: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("cuenta_acceso.id_cuenta_acceso"), primary_key=True
    )
    id_rol_acceso: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("rol_acceso.id_rol_acceso"), primary_key=True
    )
