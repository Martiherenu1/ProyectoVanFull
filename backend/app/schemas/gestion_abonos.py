"""Entrada y salida de la gestión de abonos mensuales (CU-028).

Nombres del contrato: `AbonoGestion`, `AbonoGestionLista`, `AbonoGestionCreate`,
`AbonoGestionUpdate`, `PeriodoAbonoGestion`, `PeriodoAbonoCreate`.
Los largos son los de las columnas de `abono_mensual` y `periodo_abono`.
"""

from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

Modalidad = Literal["IDA", "VUELTA", "IDA_VUELTA"]


def _periodo_valido(valor: str) -> str:
    """`YYYY-MM` con mes entre 01 y 12 (la columna es VARCHAR(7): no se valida sola)."""
    anio, _, mes = valor.partition("-")
    if len(valor) != 7 or not (anio.isdigit() and mes.isdigit() and 1 <= int(mes) <= 12):
        raise ValueError("el período debe tener el formato YYYY-MM")
    return valor


class PeriodoAbonoGestion(BaseModel):
    id_periodo_abono: int
    periodo: str
    estado: str


class AbonoGestion(BaseModel):
    id_abono_mensual: int
    id_contratacion: int
    id_pasajero: int
    nombre: str
    apellido: str
    id_servicio: int
    tipo_servicio: str
    id_tarifa: int | None = None
    # float y no Decimal: el contrato lo declara `number`, y Decimal viajaría como texto.
    importe_acordado: float | None = None
    modalidad: Modalidad | None = None
    dias_semanales: str | None = None
    estado: str
    periodos: list[PeriodoAbonoGestion]


class AbonoGestionLista(BaseModel):
    items: list[AbonoGestion]
    total: int


class AbonoGestionCreate(BaseModel):
    """Alta de un abono: crea la contratación y el abono, y opcionalmente el primer período."""

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    id_pasajero: int = Field(gt=0)
    id_servicio: int = Field(gt=0)
    modalidad: Modalidad
    dias_semanales: str = Field(min_length=1, max_length=30)
    id_tarifa: int | None = Field(default=None, gt=0)
    importe_acordado: Decimal | None = Field(default=None, ge=0, max_digits=12, decimal_places=2)
    periodo: str | None = None

    @field_validator("periodo")
    @classmethod
    def _periodo(cls, valor: str | None) -> str | None:
        return None if valor is None else _periodo_valido(valor)


class AbonoGestionUpdate(BaseModel):
    """Modalidad y días contratados. El estado no se edita a mano: ver PENDIENTES del servicio."""

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    modalidad: Modalidad | None = None
    dias_semanales: str | None = Field(default=None, min_length=1, max_length=30)

    @model_validator(mode="after")
    def _algo_para_cambiar(self):
        if not self.model_fields_set:
            raise ValueError("Debe enviarse al menos un campo para modificar.")
        for campo in ("modalidad", "dias_semanales"):
            if campo in self.model_fields_set and getattr(self, campo) is None:
                raise ValueError(f"{campo} no puede ser nulo.")
        return self


class PeriodoAbonoCreate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    periodo: str

    @field_validator("periodo")
    @classmethod
    def _periodo(cls, valor: str) -> str:
        return _periodo_valido(valor)
