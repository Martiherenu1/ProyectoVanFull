"""Entrada y salida de la gestión de clientes corporativos (CU-023).

Nombres del contrato: `ClienteCorporativo*`, `ContactoCorporativo*`, `PasajeroCorporativo*`.
Los largos son los de las columnas de `cliente_persona_juridica`, `persona` y `contacto_corporativo`.
"""

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


def _no_nulo(valor):
    # Omitir el campo lo deja como está; mandarlo en null sería borrarlo, y eso no está definido.
    if valor is None:
        raise ValueError("No puede ser nulo: omitir el campo lo deja sin cambios.")
    return valor


class ClienteCorporativo(BaseModel):
    id_cliente: int
    razon_social: str
    cuit: str
    direccion: str | None = None
    # Solo existe el valor por defecto `activo`: no hay catálogo aprobado.
    estado: str


class ClienteCorporativoLista(BaseModel):
    items: list[ClienteCorporativo]
    total: int


class ClienteCorporativoCreate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    razon_social: str = Field(min_length=1, max_length=150)
    # El formato del CUIT no está definido: se valida solo el largo de la columna.
    cuit: str = Field(min_length=1, max_length=20)
    direccion: str | None = Field(default=None, min_length=1, max_length=200)


class ClienteCorporativoUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    razon_social: str | None = Field(default=None, min_length=1, max_length=150)
    cuit: str | None = Field(default=None, min_length=1, max_length=20)
    direccion: str | None = Field(default=None, min_length=1, max_length=200)

    @field_validator("*", mode="before")
    @classmethod
    def _sin_nulos(cls, valor):
        return _no_nulo(valor)


class ContactoCorporativo(BaseModel):
    id_persona: int
    nombre: str
    apellido: str
    dni: str
    email: str | None = None
    telefono: str | None = None
    cargo: str | None = None
    es_representante: bool


class ContactoCorporativoCreate(BaseModel):
    """Un contacto es una persona: una que ya existe (`id_persona`) o una nueva (sus datos).

    Las dos formas se excluyen: con `id_persona` no se mandan datos de la persona, y sin él son
    obligatorios nombre, apellido y DNI. `es_representante` solo marca el dato: no da una cuenta ni
    el rol `representante_corporativo` (eso es de CU-033).
    """

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    id_persona: int | None = Field(default=None, gt=0)
    nombre: str | None = Field(default=None, min_length=1, max_length=80)
    apellido: str | None = Field(default=None, min_length=1, max_length=80)
    dni: str | None = Field(default=None, min_length=1, max_length=20)
    email: str | None = Field(default=None, min_length=1, max_length=120)
    telefono: str | None = Field(default=None, min_length=1, max_length=30)
    cargo: str | None = Field(default=None, min_length=1, max_length=80)
    es_representante: bool = False

    @model_validator(mode="after")
    def _una_sola_forma(self):
        datos_persona = [
            campo
            for campo in ("nombre", "apellido", "dni", "email", "telefono")
            if getattr(self, campo) is not None
        ]
        if self.id_persona is not None:
            if datos_persona:
                raise ValueError(
                    "Con id_persona no se envían datos de la persona: " + ", ".join(datos_persona)
                )
        elif not (self.nombre and self.apellido and self.dni):
            raise ValueError("Sin id_persona son obligatorios nombre, apellido y dni.")
        return self


class PasajeroCorporativo(BaseModel):
    id_persona: int
    nombre: str
    apellido: str
    dni: str
    estado_habilitacion: str
    # Solo existe el valor por defecto `activo`: no hay catálogo aprobado.
    estado_vinculo: str


class PasajeroCorporativoCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id_pasajero: int = Field(gt=0)


class ClienteCorporativoDetalle(ClienteCorporativo):
    contactos: list[ContactoCorporativo]
    pasajeros: list[PasajeroCorporativo]
