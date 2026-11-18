"""Entrada y salida de la gestión de recorridos y paradas (CU-019).

Nombres del contrato: `ParadaGestion`, `ParadaGestionLista`, `ParadaGestionCreate`,
`ParadaGestionUpdate`, `RecorridoGestion`, `RecorridoGestionLista`, `RecorridoParadas`.
Los largos y la precisión son los de las columnas de `parada`.
"""

from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class ParadaGestion(BaseModel):
    id_parada: int
    nombre_descripcion: str | None = None
    direccion: str | None = None
    # float y no Decimal: el contrato las declara `number`, y Decimal viajaría como texto.
    latitud: float | None = None
    longitud: float | None = None


class ParadaGestionLista(BaseModel):
    items: list[ParadaGestion]
    total: int


class ParadaGestionCreate(BaseModel):
    """Alta de una parada del catálogo. Latitud y longitud van juntas o ninguna."""

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    nombre_descripcion: str = Field(min_length=1, max_length=150)
    direccion: str | None = Field(default=None, min_length=1, max_length=200)
    latitud: Decimal | None = Field(default=None, ge=-90, le=90, max_digits=9, decimal_places=6)
    longitud: Decimal | None = Field(default=None, ge=-180, le=180, max_digits=9, decimal_places=6)

    @model_validator(mode="after")
    def _coordenadas_juntas(self):
        if (self.latitud is None) != (self.longitud is None):
            raise ValueError("latitud y longitud se informan juntas")
        return self


class ParadaGestionUpdate(BaseModel):
    """Modificación parcial. `direccion`, `latitud` y `longitud` admiten `null`."""

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    nombre_descripcion: str | None = Field(default=None, min_length=1, max_length=150)
    direccion: str | None = Field(default=None, min_length=1, max_length=200)
    latitud: Decimal | None = Field(default=None, ge=-90, le=90, max_digits=9, decimal_places=6)
    longitud: Decimal | None = Field(default=None, ge=-180, le=180, max_digits=9, decimal_places=6)

    @field_validator("nombre_descripcion", mode="after")
    @classmethod
    def _no_nulo(cls, valor):
        if valor is None:
            raise ValueError("no puede ser nulo")
        return valor


class ParadaEnRecorrido(BaseModel):
    orden: int
    id_parada: int
    nombre_descripcion: str | None = None
    direccion: str | None = None
    latitud: float | None = None
    longitud: float | None = None
    # Solo lectura: esta API la conserva, no la fija (cómo se compromete una parada es PENDIENTE).
    comprometida: bool


class RecorridoGestion(BaseModel):
    id_recorrido: int
    paradas: list[ParadaEnRecorrido]


class RecorridoGestionLista(BaseModel):
    items: list[RecorridoGestion]
    total: int


class RecorridoParadas(BaseModel):
    """Las paradas del recorrido, en orden: la primera es el orden 1."""

    model_config = ConfigDict(extra="forbid")

    id_paradas: list[int] = Field(min_length=1, max_length=100)

    @field_validator("id_paradas")
    @classmethod
    def _positivos(cls, valor: list[int]):
        if any(i <= 0 for i in valor):
            raise ValueError("los identificadores de parada son enteros positivos")
        return valor
