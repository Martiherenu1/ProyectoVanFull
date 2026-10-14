"""Inicio de sesión (CU-012). Es el servicio modelo: lógica sin HTTP, errores con `ApiError`."""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.core.security import crear_token, hash_contrasena, verificar_contrasena
from app.models.personas import CuentaAcceso, CuentaRol, RolAcceso

# `cuenta_acceso.estado` no tiene CHECK en schema.sql; 'activo' es su DEFAULT.
ESTADO_ACTIVO = "activo"

# Se verifica contra este hash cuando el identificador no existe, para que responder "no existe" no
# tarde menos que responder "contraseña incorrecta" y no revele qué cuentas hay.
_HASH_DE_RELLENO = hash_contrasena("relleno-para-igualar-tiempos")


def _credenciales_invalidas() -> ApiError:
    # Mismo código y mismo mensaje para todos los motivos de rechazo.
    return ApiError(
        401, "CREDENCIALES_INVALIDAS", "El identificador o la contraseña no son correctos."
    )


async def roles_de(db: AsyncSession, id_cuenta_acceso: int) -> list[str]:
    consulta = (
        select(RolAcceso.rol)
        .join(CuentaRol, CuentaRol.id_rol_acceso == RolAcceso.id_rol_acceso)
        .where(CuentaRol.id_cuenta_acceso == id_cuenta_acceso)
        .order_by(RolAcceso.id_rol_acceso)
    )
    return list((await db.execute(consulta)).scalars())


async def iniciar_sesion(
    db: AsyncSession, identificador_acceso: str, contrasena: str
) -> tuple[str, list[str]]:
    """Devuelve (token, roles) o levanta 401 CREDENCIALES_INVALIDAS."""
    cuenta = (
        await db.execute(
            select(CuentaAcceso).where(CuentaAcceso.identificador_acceso == identificador_acceso)
        )
    ).scalar_one_or_none()

    hash_guardado = cuenta.hash_contrasena if cuenta else _HASH_DE_RELLENO
    contrasena_ok = verificar_contrasena(contrasena, hash_guardado)

    # PENDIENTE DE VALIDACIÓN (Issue #4): rechazar cuentas con estado distinto de 'activo' es la
    # lectura conservadora del DEFAULT del schema; la regla real sale de la especificación v1.3
    # del CU-012. Tampoco se miran `pasajero.estado_habilitacion` ni otras condiciones.
    if cuenta is None or not contrasena_ok or cuenta.estado != ESTADO_ACTIVO:
        raise _credenciales_invalidas()

    roles = await roles_de(db, cuenta.id_cuenta_acceso)
    token = crear_token(cuenta.id_cuenta_acceso, cuenta.id_persona, roles)
    return token, roles
