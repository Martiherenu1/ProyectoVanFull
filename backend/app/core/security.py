"""Contraseñas, tokens y permisos por rol (CU-012, RF-045, RN-026 a RN-030).

- Las contraseñas se guardan con bcrypt en `cuenta_acceso.hash_contrasena`; nunca en claro.
- El token es un JWT firmado (HS256) con el id de la cuenta, el de la persona y los roles.
- `usuario_actual` y `requiere_rol(...)` son las dependencias que usa cualquier router.

Lo que este módulo NO resuelve es el permiso "solo lo propio" (un pasajero ve sus reservas, no las
de otro; el chofer ve su viaje): eso depende del dato y lo decide cada servicio (RN-026 a 030),
usando `id_persona` del usuario actual. El rol dice qué *clase* de operación puede intentar.

Límite conocido: el token es sin estado. Si se quita un rol o se suspende una cuenta, el token ya
emitido vale hasta que vence (`ACCESS_TOKEN_EXPIRE_MINUTES`). El logout no lo invalida: queda como
pendiente la política de sesiones (CONTEXTO §13).
"""

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

import bcrypt
import jwt
from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.config import get_settings
from app.core.errors import ApiError

# bcrypt solo mira los primeros 72 bytes; una contraseña más larga se rechaza en vez de truncarse.
_MAX_BYTES_BCRYPT = 72
_SECRETO_POR_DEFECTO = "cambiar-en-produccion"
# RFC 7518 §3.2: la clave de HS256 tiene que medir al menos 32 bytes.
_MIN_BYTES_SECRETO = 32

# auto_error=False: si falta el token respondemos nosotros, con el error uniforme y el 401 del contrato.
_esquema_bearer = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class UsuarioActual:
    id_cuenta_acceso: int
    id_persona: int
    roles: tuple[str, ...]


# --- Contraseñas ---------------------------------------------------------------------------


def hash_contrasena(contrasena: str) -> str:
    datos = contrasena.encode("utf-8")
    if len(datos) > _MAX_BYTES_BCRYPT:
        raise ValueError("La contraseña supera los 72 bytes que admite bcrypt.")
    return bcrypt.hashpw(datos, bcrypt.gensalt()).decode("ascii")


def verificar_contrasena(contrasena: str, hash_guardado: str) -> bool:
    datos = contrasena.encode("utf-8")
    if len(datos) > _MAX_BYTES_BCRYPT:
        return False
    try:
        return bcrypt.checkpw(datos, hash_guardado.encode("ascii"))
    except ValueError:  # hash mal formado
        return False


# --- Tokens --------------------------------------------------------------------------------


def _secreto() -> str:
    ajustes = get_settings()
    if ajustes.env != "development":
        if ajustes.jwt_secret == _SECRETO_POR_DEFECTO:
            raise RuntimeError("JWT_SECRET tiene el valor de ejemplo: definir uno propio en .env.")
        if len(ajustes.jwt_secret.encode("utf-8")) < _MIN_BYTES_SECRETO:
            raise RuntimeError(f"JWT_SECRET debe tener al menos {_MIN_BYTES_SECRETO} bytes.")
    return ajustes.jwt_secret


def crear_token(id_cuenta_acceso: int, id_persona: int, roles: list[str]) -> str:
    ajustes = get_settings()
    ahora = datetime.now(UTC)
    claims = {
        "sub": str(id_cuenta_acceso),
        "pid": id_persona,
        "roles": roles,
        "iat": ahora,
        "exp": ahora + timedelta(minutes=ajustes.access_token_expire_minutes),
    }
    return jwt.encode(claims, _secreto(), algorithm=ajustes.jwt_algorithm)


def decodificar_token(token: str) -> UsuarioActual:
    ajustes = get_settings()
    try:
        claims = jwt.decode(
            token,
            _secreto(),
            algorithms=[ajustes.jwt_algorithm],
            options={"require": ["sub", "pid", "roles", "exp"]},
        )
        return UsuarioActual(
            id_cuenta_acceso=int(claims["sub"]),
            id_persona=int(claims["pid"]),
            roles=tuple(claims["roles"]),
        )
    except (jwt.PyJWTError, ValueError, TypeError) as exc:
        raise ApiError(
            401,
            "NO_AUTENTICADO",
            "La sesión no es válida o venció. Iniciá sesión de nuevo.",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc


# --- Dependencias de FastAPI ---------------------------------------------------------------


async def usuario_actual(
    credenciales: HTTPAuthorizationCredentials | None = Depends(_esquema_bearer),
) -> UsuarioActual:
    """El usuario del token. 401 si falta o no es válido."""
    if credenciales is None:
        raise ApiError(
            401,
            "NO_AUTENTICADO",
            "Falta iniciar sesión.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return decodificar_token(credenciales.credentials)


def requiere_rol(*roles_permitidos: str):
    """Dependencia que exige que el usuario tenga alguno de los roles. 403 si no."""

    async def _verificar(usuario: UsuarioActual = Depends(usuario_actual)) -> UsuarioActual:
        if not set(usuario.roles) & set(roles_permitidos):
            raise ApiError(
                403,
                "SIN_PERMISO",
                "No tenés permiso para esta operación.",
                {"roles_requeridos": list(roles_permitidos)},
            )
        return usuario

    return _verificar
