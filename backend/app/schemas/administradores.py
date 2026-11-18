"""Entrada y salida de la gestión de administradores por el dueño (CU-032).

Nombres del contrato: `Administrador`, `AdministradorLista`, `AdministradorCreate`, `AdministradorUpdate`.
Los largos son los de las columnas de `persona` y `cuenta_acceso`.
"""

from pydantic import BaseModel, ConfigDict, Field, field_validator


class Administrador(BaseModel):
    id_cuenta_acceso: int
    id_persona: int
    nombre: str
    apellido: str
    dni: str
    email: str | None = None
    telefono: str | None = None
    identificador_acceso: str
    # `activo` o `deshabilitado`. `cuenta_acceso.estado` no tiene CHECK; el login solo deja entrar
    # a `activo` (services/auth.py).
    estado: str


class AdministradorLista(BaseModel):
    items: list[Administrador]
    total: int


class AdministradorCreate(BaseModel):
    """Alta de una cuenta administrativa (CU-032, flujo principal).

    La contraseña inicial la define el dueño. Recuperación, cambio y política de contraseñas son un
    pendiente técnico del propio CU (v1.3): acá solo se exige un largo mínimo y se guarda el hash.
    """

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    nombre: str = Field(min_length=1, max_length=80)
    apellido: str = Field(min_length=1, max_length=80)
    dni: str = Field(min_length=1, max_length=20)
    email: str | None = Field(default=None, min_length=1, max_length=120)
    telefono: str | None = Field(default=None, min_length=1, max_length=30)
    identificador_acceso: str = Field(min_length=3, max_length=120)
    contrasena: str = Field(min_length=8, max_length=128)


class AdministradorUpdate(BaseModel):
    """Datos que el dueño puede cambiar (CU-032 A1). El estado se cambia con su propia operación.

    No hay permisos para elegir: hoy existe un único conjunto, el rol `administrador`. Un campo
    desconocido es un cuerpo inválido (400).
    """

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    nombre: str | None = Field(default=None, min_length=1, max_length=80)
    apellido: str | None = Field(default=None, min_length=1, max_length=80)
    dni: str | None = Field(default=None, min_length=1, max_length=20)
    email: str | None = Field(default=None, min_length=1, max_length=120)
    telefono: str | None = Field(default=None, min_length=1, max_length=30)
    identificador_acceso: str | None = Field(default=None, min_length=3, max_length=120)

    @field_validator("*", mode="before")
    @classmethod
    def _no_nulo(cls, valor):
        if valor is None:
            raise ValueError("No puede ser nulo: omitir el campo lo deja sin cambios.")
        return valor
