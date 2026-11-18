"""Gestión de administradores por el dueño (CU-032, RF-041, RN-027).

Alcance: alta (flujo principal), consulta, modificación de datos (A1) y deshabilitación (A2), sin
eliminación física (RF-041). El rol `dueno` ya lo exigió el router.

Una cuenta administrativa es una `cuenta_acceso` con el rol `administrador`. Las cuentas que además
tienen `dueno` no se gestionan acá: el CU es del dueño sobre los administradores, no sobre sí mismo.

PENDIENTE (v1.3 del CU): permisos más finos que el rol, recuperación y cambio de contraseña,
sesiones. Deshabilitar impide iniciar sesión (el login solo admite `activo`), pero un token ya
emitido sigue valiendo hasta que vence: `core/security.py` no reconsulta la cuenta en cada pedido.
"""

from sqlalchemy import exists, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.core.security import hash_contrasena
from app.models.personas import CuentaAcceso, CuentaRol, Persona, RolAcceso
from app.schemas.administradores import (
    Administrador,
    AdministradorCreate,
    AdministradorLista,
    AdministradorUpdate,
)
from app.services.pasajeros import dni_en_uso, error_dni_duplicado

ROL_ADMINISTRADOR = "administrador"
ROL_DUENO = "dueno"
ESTADO_ACTIVO = "activo"
ESTADO_DESHABILITADO = "deshabilitado"

_CAMPOS_PERSONA = ("nombre", "apellido", "dni", "email", "telefono")


def _tiene_rol(rol: str):
    return exists().where(
        CuentaRol.id_cuenta_acceso == CuentaAcceso.id_cuenta_acceso,
        CuentaRol.id_rol_acceso == RolAcceso.id_rol_acceso,
        RolAcceso.rol == rol,
    )


# Administrador y no dueño.
_ES_ADMINISTRABLE = (_tiene_rol(ROL_ADMINISTRADOR), ~_tiene_rol(ROL_DUENO))


def _armar(persona: Persona, cuenta: CuentaAcceso) -> Administrador:
    return Administrador(
        id_cuenta_acceso=cuenta.id_cuenta_acceso,
        id_persona=persona.id_persona,
        nombre=persona.nombre,
        apellido=persona.apellido,
        dni=persona.dni,
        email=persona.email,
        telefono=persona.telefono,
        identificador_acceso=cuenta.identificador_acceso,
        estado=cuenta.estado,
    )


def _error_identificador(identificador: str) -> ApiError:
    return ApiError(
        409,
        "IDENTIFICADOR_EN_USO",
        "Ya existe una cuenta con ese identificador de acceso.",
        {"identificador_acceso": identificador},
    )


async def _identificador_en_uso(
    db: AsyncSession, identificador: str, *, salvo: int | None = None
) -> bool:
    consulta = select(CuentaAcceso.id_cuenta_acceso).where(
        CuentaAcceso.identificador_acceso == identificador
    )
    if salvo is not None:
        consulta = consulta.where(CuentaAcceso.id_cuenta_acceso != salvo)
    return (await db.execute(consulta)).first() is not None


async def _cargar(
    db: AsyncSession, id_cuenta_acceso: int, *, bloquear: bool = False
) -> tuple[Persona, CuentaAcceso]:
    consulta = select(CuentaAcceso).where(
        CuentaAcceso.id_cuenta_acceso == id_cuenta_acceso, *_ES_ADMINISTRABLE
    )
    if bloquear:
        consulta = consulta.with_for_update()
    cuenta = (await db.execute(consulta)).scalar_one_or_none()
    if cuenta is None:
        raise ApiError(
            404,
            "ADMINISTRADOR_NO_ENCONTRADO",
            "No existe una cuenta de administrador con el identificador indicado.",
        )
    consulta_persona = select(Persona).where(Persona.id_persona == cuenta.id_persona)
    if bloquear:
        consulta_persona = consulta_persona.with_for_update()
    persona = (await db.execute(consulta_persona)).scalar_one()
    return persona, cuenta


async def listar_administradores(db: AsyncSession) -> AdministradorLista:
    filas = (
        await db.execute(
            select(Persona, CuentaAcceso)
            .join(CuentaAcceso, CuentaAcceso.id_persona == Persona.id_persona)
            .where(*_ES_ADMINISTRABLE)
            .order_by(Persona.apellido, Persona.nombre, CuentaAcceso.id_cuenta_acceso)
        )
    ).all()
    return AdministradorLista(items=[_armar(p, c) for p, c in filas], total=len(filas))


async def obtener_administrador(db: AsyncSession, id_cuenta_acceso: int) -> Administrador:
    persona, cuenta = await _cargar(db, id_cuenta_acceso)
    return _armar(persona, cuenta)


async def crear_administrador(db: AsyncSession, datos: AdministradorCreate) -> Administrador:
    """Persona, cuenta y rol `administrador` en una sola transacción.

    Si el DNI ya es de otra persona (un pasajero, un chofer) responde 409: reutilizar a la persona
    no está definido y no se infiere, igual que en CU-013.
    """
    if await dni_en_uso(db, datos.dni):
        raise error_dni_duplicado(datos.dni)
    if await _identificador_en_uso(db, datos.identificador_acceso):
        raise _error_identificador(datos.identificador_acceso)

    id_rol = await db.scalar(
        select(RolAcceso.id_rol_acceso).where(RolAcceso.rol == ROL_ADMINISTRADOR)
    )
    persona = Persona(**datos.model_dump(include=set(_CAMPOS_PERSONA)))
    db.add(persona)
    try:
        await db.flush()
        cuenta = CuentaAcceso(
            id_persona=persona.id_persona,
            identificador_acceso=datos.identificador_acceso,
            hash_contrasena=hash_contrasena(datos.contrasena),
            estado=ESTADO_ACTIVO,
        )
        db.add(cuenta)
        await db.flush()
        db.add(CuentaRol(id_cuenta_acceso=cuenta.id_cuenta_acceso, id_rol_acceso=id_rol))
        await db.commit()
    except IntegrityError:
        # Otra alta ganó la carrera entre la consulta y el INSERT: DNI o identificador.
        await db.rollback()
        if await dni_en_uso(db, datos.dni):
            raise error_dni_duplicado(datos.dni) from None
        raise _error_identificador(datos.identificador_acceso) from None
    return _armar(persona, cuenta)


async def modificar_administrador(
    db: AsyncSession, id_cuenta_acceso: int, datos: AdministradorUpdate
) -> Administrador:
    """CU-032 A1: aplica los cambios, todo o nada."""
    cambios = datos.model_dump(exclude_unset=True)
    if not cambios:
        raise ApiError(400, "VALIDACION", "No se indicó ningún dato para modificar.")

    persona, cuenta = await _cargar(db, id_cuenta_acceso, bloquear=True)

    nuevo_dni = cambios.get("dni")
    if (
        nuevo_dni is not None
        and nuevo_dni != persona.dni
        and await dni_en_uso(db, nuevo_dni, salvo=persona.id_persona)
    ):
        raise error_dni_duplicado(nuevo_dni)
    nuevo_id = cambios.get("identificador_acceso")
    if (
        nuevo_id is not None
        and nuevo_id != cuenta.identificador_acceso
        and await _identificador_en_uso(db, nuevo_id, salvo=id_cuenta_acceso)
    ):
        raise _error_identificador(nuevo_id)

    for campo, valor in cambios.items():
        setattr(cuenta if campo == "identificador_acceso" else persona, campo, valor)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        if nuevo_dni is not None and await dni_en_uso(db, nuevo_dni, salvo=persona.id_persona):
            raise error_dni_duplicado(nuevo_dni) from None
        raise _error_identificador(nuevo_id or "") from None
    return _armar(persona, cuenta)


async def deshabilitar_administrador(db: AsyncSession, id_cuenta_acceso: int) -> Administrador:
    """CU-032 A2: la cuenta deja de poder iniciar sesión. No se borra nada (RF-041)."""
    persona, cuenta = await _cargar(db, id_cuenta_acceso, bloquear=True)
    if cuenta.estado == ESTADO_DESHABILITADO:
        raise ApiError(
            409,
            "ADMINISTRADOR_YA_DESHABILITADO",
            "La cuenta de administrador ya estaba deshabilitada.",
        )
    cuenta.estado = ESTADO_DESHABILITADO
    await db.commit()
    return _armar(persona, cuenta)
