"""Entrada y salida de los pasajeros de la organización (CU-033).

Nombres del contrato: `Organizacion*` y `PasajeroOrganizacion*`. Los largos son los de las columnas
de `persona`.
"""

from pydantic import BaseModel, ConfigDict, Field, field_validator

# Los datos que el representante puede cargar y cambiar. La spec no los enumera («datos permitidos»):
# se toman los de la persona y se deja afuera `categoria`, ligada a condiciones comerciales, que el
# representante no puede tocar (CU-033, observaciones).
CAMPOS_EDITABLES = ("nombre", "apellido", "email", "telefono", "direccion")


class OrganizacionRepresentada(BaseModel):
    id_cliente: int
    razon_social: str
    cargo: str | None = None


class OrganizacionLista(BaseModel):
    items: list[OrganizacionRepresentada]
    total: int


class PasajeroOrganizacion(BaseModel):
    id_persona: int
    nombre: str
    apellido: str
    dni: str
    email: str | None = None
    telefono: str | None = None
    direccion: str | None = None
    estado_habilitacion: str


class PasajeroOrganizacionLista(BaseModel):
    items: list[PasajeroOrganizacion]
    total: int


class PasajeroOrganizacionCreate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    nombre: str = Field(min_length=1, max_length=80)
    apellido: str = Field(min_length=1, max_length=80)
    dni: str = Field(min_length=1, max_length=20)
    email: str | None = Field(default=None, min_length=1, max_length=120)
    telefono: str | None = Field(default=None, min_length=1, max_length=30)
    direccion: str | None = Field(default=None, min_length=1, max_length=200)


class PasajeroOrganizacionUpdate(BaseModel):
    """Datos que el representante puede modificar.

    Igual que el perfil (CU-001), `extra="allow"` es a propósito: un campo que no está acá (el DNI,
    por ejemplo) no es un cuerpo inválido sino un intento de modificar un dato no habilitado, que el
    contrato responde con 403 (CU-033 A4, RN-026). El servicio lee `model_extra` para decidirlo.
    """

    model_config = ConfigDict(extra="allow", str_strip_whitespace=True)

    nombre: str | None = Field(default=None, min_length=1, max_length=80)
    apellido: str | None = Field(default=None, min_length=1, max_length=80)
    email: str | None = Field(default=None, min_length=1, max_length=120)
    telefono: str | None = Field(default=None, min_length=1, max_length=30)
    direccion: str | None = Field(default=None, min_length=1, max_length=200)

    @field_validator(*CAMPOS_EDITABLES, mode="before")
    @classmethod
    def _no_nulo(cls, valor):
        # Omitir el campo lo deja como está; mandarlo en null sería borrarlo, y eso no está definido.
        if valor is None:
            raise ValueError("No puede ser nulo: omitir el campo lo deja sin cambios.")
        return valor
