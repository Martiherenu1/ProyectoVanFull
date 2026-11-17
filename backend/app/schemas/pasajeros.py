"""Entrada y salida de la gestión administrativa de pasajeros (CU-013).

Nombres del contrato: `PasajeroAdmin`, `PasajeroCreate`, `PasajeroUpdate`, `PasajeroLista`.
Los largos son los de las columnas de `persona` y `pasajero`.
"""

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.perfil import PerfilPasajero


class PasajeroAdmin(PerfilPasajero):
    """Un pasajero tal como lo ve administración. Mismos datos que el perfil propio."""


class PasajeroLista(BaseModel):
    items: list[PasajeroAdmin]
    total: int


class PasajeroCreate(BaseModel):
    """Alta de un pasajero. No crea cuenta de acceso (CU-012 y CU-032 definen las contraseñas)."""

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    nombre: str = Field(min_length=1, max_length=80)
    apellido: str = Field(min_length=1, max_length=80)
    dni: str = Field(min_length=1, max_length=20)
    email: str | None = Field(default=None, min_length=1, max_length=120)
    telefono: str | None = Field(default=None, min_length=1, max_length=30)
    direccion: str | None = Field(default=None, min_length=1, max_length=200)
    # El catálogo de categorías está a confirmar (schema.sql): texto libre hasta que se defina.
    categoria: str | None = Field(default=None, min_length=1, max_length=30)


class PasajeroUpdate(BaseModel):
    """Datos que administración puede cambiar, incluido el DNI (CU-013 A1, RN-026).

    El estado de habilitación no se cambia por acá: la baja tiene su operación y la suspensión y la
    habilitación excepcional (A2, A3) dependen de RN-004/005, que siguen pendientes. Un campo
    desconocido es un cuerpo inválido (400), no se ignora en silencio.
    """

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    nombre: str | None = Field(default=None, min_length=1, max_length=80)
    apellido: str | None = Field(default=None, min_length=1, max_length=80)
    dni: str | None = Field(default=None, min_length=1, max_length=20)
    email: str | None = Field(default=None, min_length=1, max_length=120)
    telefono: str | None = Field(default=None, min_length=1, max_length=30)
    direccion: str | None = Field(default=None, min_length=1, max_length=200)
    categoria: str | None = Field(default=None, min_length=1, max_length=30)

    @field_validator("*", mode="before")
    @classmethod
    def _no_nulo(cls, valor):
        # Omitir el campo lo deja como está; mandarlo en null sería borrarlo, y eso no está definido.
        if valor is None:
            raise ValueError("No puede ser nulo: omitir el campo lo deja sin cambios.")
        return valor
