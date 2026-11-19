"""Contrato administrativo de choferes (CU-021, primera entrega)."""

from datetime import date

from pydantic import BaseModel, ConfigDict, Field, model_validator


class ChoferAdminCreate(BaseModel):
    """Campos existentes de Persona y Chofer; no crea una cuenta de acceso."""

    model_config = ConfigDict(extra="forbid")

    nombre: str = Field(min_length=1, max_length=80)
    apellido: str = Field(min_length=1, max_length=80)
    dni: str = Field(min_length=1, max_length=20)
    direccion: str | None = Field(default=None, max_length=200)
    telefono: str | None = Field(default=None, max_length=30)
    email: str | None = Field(default=None, max_length=120)
    cuil: str | None = Field(default=None, max_length=20)
    registro_conducir: str | None = Field(default=None, max_length=40)
    fecha_vencimiento_registro: date | None = None


class ChoferAdminUpdate(BaseModel):
    """Modificación parcial limitada a las columnas vigentes."""

    model_config = ConfigDict(extra="forbid")

    nombre: str | None = Field(default=None, min_length=1, max_length=80)
    apellido: str | None = Field(default=None, min_length=1, max_length=80)
    dni: str | None = Field(default=None, min_length=1, max_length=20)
    direccion: str | None = Field(default=None, max_length=200)
    telefono: str | None = Field(default=None, max_length=30)
    email: str | None = Field(default=None, max_length=120)
    cuil: str | None = Field(default=None, max_length=20)
    registro_conducir: str | None = Field(default=None, max_length=40)
    fecha_vencimiento_registro: date | None = None

    @model_validator(mode="after")
    def validar_campos_presentes(self):
        if not self.model_fields_set:
            raise ValueError("Debe enviarse al menos un campo para actualizar.")
        for campo in ("nombre", "apellido", "dni"):
            if campo in self.model_fields_set and getattr(self, campo) is None:
                raise ValueError(f"{campo} no puede ser nulo.")
        return self


class ChoferAdmin(BaseModel):
    id_persona: int
    nombre: str
    apellido: str
    dni: str
    direccion: str | None
    telefono: str | None
    email: str | None
    cuil: str | None
    registro_conducir: str | None
    fecha_vencimiento_registro: date | None
