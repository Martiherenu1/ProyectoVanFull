"""Entrada y salida de la gestión de tarifas por el dueño (CU-031).

Nombres del contrato: `TarifaGestion`, `TarifaGestionLista`, `TarifaGestionCreate`,
`TarifaGestionUpdate`. Los largos y la precisión son los de las columnas de `tarifa`.
"""

from datetime import date
from decimal import Decimal
from typing import Annotated

from pydantic import BaseModel, BeforeValidator, ConfigDict, Field, field_validator


def _numero_json(valor: object) -> object:
    if isinstance(valor, bool) or not isinstance(valor, (int, float)):
        raise ValueError("el importe debe ser un número")
    return valor


def _fecha_iso(valor: object) -> date:
    if isinstance(valor, str):
        fecha = date.fromisoformat(valor)
        if fecha.isoformat() == valor:
            return fecha
    raise ValueError("la vigencia debe tener formato AAAA-MM-DD")


ImporteTarifa = Annotated[
    Decimal, Field(ge=0, max_digits=12, decimal_places=2), BeforeValidator(_numero_json)
]
FechaVigencia = Annotated[date, BeforeValidator(_fecha_iso)]


class TarifaGestion(BaseModel):
    id_tarifa: int
    nombre: str
    tipo: str | None = None
    # El contrato declara `number`; por eso la respuesta expone float y no Decimal como texto.
    importe: float
    fecha_creacion: date
    fecha_vigencia: date | None = None


class TarifaGestionLista(BaseModel):
    items: list[TarifaGestion]
    total: int


class TarifaGestionCreate(BaseModel):
    """Alta de una tarifa (CU-031, flujo principal).

    `tipo` y `fecha_vigencia` se guardan como llegan: la estructura de parámetros, las vigencias y
    el historial son PENDIENTE DE DISEÑO en la v1.3 del CU, así que no se les inventa semántica.
    """

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    nombre: str = Field(min_length=1, max_length=120)
    importe: ImporteTarifa
    tipo: str | None = Field(default=None, min_length=1, max_length=40)
    fecha_vigencia: FechaVigencia | None = None

    @field_validator("tipo", "fecha_vigencia")
    @classmethod
    def _opcional_no_nulo(cls, valor):
        if valor is None:
            raise ValueError("omití el campo si no tiene valor")
        return valor


class TarifaGestionUpdate(BaseModel):
    """Modificación parcial: solo los campos enviados. `tipo` y `fecha_vigencia` admiten `null`."""

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    nombre: str | None = Field(default=None, min_length=1, max_length=120)
    importe: ImporteTarifa | None = None
    tipo: str | None = Field(default=None, min_length=1, max_length=40)
    fecha_vigencia: FechaVigencia | None = None

    @field_validator("nombre", "importe", mode="after")
    @classmethod
    def _no_nulo(cls, valor):
        # Sin `exclude_unset` no se distingue «omitido» de «null»; acá `null` explícito es error.
        if valor is None:
            raise ValueError("no puede ser nulo")
        return valor
