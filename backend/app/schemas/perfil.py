"""Entrada y salida del perfil del pasajero. Nombres del contrato (`PerfilPasajero`, `PerfilPasajeroUpdate`)."""

from pydantic import BaseModel, ConfigDict, Field, field_validator


class PerfilPasajero(BaseModel):
    """Lo que ve el propio pasajero. Los datos que no tiene cargados no se incluyen en la respuesta."""

    id_persona: int
    nombre: str
    apellido: str
    dni: str
    email: str | None = None
    telefono: str | None = None
    direccion: str | None = None
    categoria: str | None = None
    estado_habilitacion: str
    fotografia: str | None = None


class PerfilPasajeroUpdate(BaseModel):
    """Datos que el pasajero puede modificar.

    `extra="allow"` es a propósito: un campo que no está acá (el DNI, por ejemplo) no es un cuerpo
    inválido sino un intento de modificar un dato no habilitado, que el contrato responde con 403.
    El servicio lee `model_extra` para decidirlo. Los largos son los de las columnas de `persona`.
    """

    model_config = ConfigDict(extra="allow")

    email: str | None = Field(default=None, min_length=1, max_length=120)
    telefono: str | None = Field(default=None, min_length=1, max_length=30)
    direccion: str | None = Field(default=None, min_length=1, max_length=200)

    @field_validator("email", "telefono", "direccion", mode="before")
    @classmethod
    def _no_nulo(cls, valor):
        # Omitir el campo lo deja como está; mandarlo en null sería borrarlo, y eso no está definido.
        if valor is None:
            raise ValueError("No puede ser nulo: omitir el campo lo deja sin cambios.")
        return valor
