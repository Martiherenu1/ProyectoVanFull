"""Contrato administrativo de vehículos (CU-022, primera entrega)."""

from pydantic import BaseModel, ConfigDict, Field, model_validator


class VehiculoCreate(BaseModel):
    """Campos persistidos por el modelo vigente; no incluye documentación."""

    model_config = ConfigDict(extra="forbid")

    patente: str = Field(min_length=1, max_length=10)
    marca: str | None = Field(default=None, max_length=50)
    modelo: str | None = Field(default=None, max_length=50)
    capacidad: int = Field(ge=1)
    disponibilidad: bool = True


class VehiculoUpdate(BaseModel):
    """Modificación parcial sin inferir reglas sobre disponibilidad."""

    model_config = ConfigDict(extra="forbid")

    patente: str | None = Field(default=None, min_length=1, max_length=10)
    marca: str | None = Field(default=None, max_length=50)
    modelo: str | None = Field(default=None, max_length=50)
    capacidad: int | None = Field(default=None, ge=1)
    disponibilidad: bool | None = None

    @model_validator(mode="after")
    def validar_campos_presentes(self):
        if not self.model_fields_set:
            raise ValueError("Debe enviarse al menos un campo para actualizar.")
        for campo in ("patente", "capacidad", "disponibilidad"):
            if campo in self.model_fields_set and getattr(self, campo) is None:
                raise ValueError(f"{campo} no puede ser nulo.")
        return self


class Vehiculo(BaseModel):
    id_vehiculo: int
    patente: str
    marca: str | None
    modelo: str | None
    capacidad: int
    disponibilidad: bool
