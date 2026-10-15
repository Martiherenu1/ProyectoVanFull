"""Perfil del pasajero (CU-001, RF-001, RF-003, RN-026).

Un pasajero solo accede al suyo: el id sale del token, nunca de la URL ni del cuerpo.
"""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.core.security import UsuarioActual
from app.models.personas import Pasajero, Persona
from app.schemas.perfil import PerfilPasajero, PerfilPasajeroUpdate

# PENDIENTE DE VALIDACIÓN con Martín (Issue #25): "campos editables del perfil" es un pendiente del
# cierre de la etapa 03. Esta es la lista del contrato v0.1 (`PerfilPasajeroUpdate`). El DNI queda
# afuera por RN-026. Cambiar la lista es cambiar esta constante y el schema.
CAMPOS_EDITABLES = ("email", "telefono", "direccion")


async def _cargar(db: AsyncSession, usuario: UsuarioActual) -> tuple[Persona, Pasajero]:
    fila = (
        await db.execute(
            select(Persona, Pasajero)
            .join(Pasajero, Pasajero.id_persona == Persona.id_persona)
            .where(Persona.id_persona == usuario.id_persona)
        )
    ).one_or_none()
    if fila is None:
        # La cuenta tiene el rol pero no hay un pasajero detrás: es un dato inconsistente.
        raise ApiError(
            404, "PASAJERO_NO_ENCONTRADO", "No hay un perfil de pasajero para esta cuenta."
        )
    return fila[0], fila[1]


def _armar(persona: Persona, pasajero: Pasajero) -> PerfilPasajero:
    return PerfilPasajero(
        id_persona=persona.id_persona,
        nombre=persona.nombre,
        apellido=persona.apellido,
        dni=persona.dni,
        email=persona.email,
        telefono=persona.telefono,
        direccion=persona.direccion,
        categoria=pasajero.categoria,
        estado_habilitacion=pasajero.estado_habilitacion,
        fotografia=pasajero.fotografia,
    )


async def obtener_perfil(db: AsyncSession, usuario: UsuarioActual) -> PerfilPasajero:
    persona, pasajero = await _cargar(db, usuario)
    return _armar(persona, pasajero)


async def modificar_perfil(
    db: AsyncSession, usuario: UsuarioActual, datos: PerfilPasajeroUpdate
) -> PerfilPasajero:
    """Aplica los cambios, todo o nada: si hay un dato no habilitado no se modifica ninguno."""
    persona, pasajero = await _cargar(db, usuario)

    no_habilitados = sorted((datos.model_extra or {}).keys())
    if no_habilitados:
        raise ApiError(
            403,
            "DATO_NO_MODIFICABLE",
            # CU-001 A1: el cambio "debe ser realizado por un administrador autorizado".
            "Ese dato no se puede modificar por autoservicio: el cambio debe ser realizado por un "
            "administrador autorizado (RN-026).",
            {"campos": no_habilitados, "campos_editables": list(CAMPOS_EDITABLES)},
        )

    for campo, valor in datos.model_dump(exclude_unset=True, include=set(CAMPOS_EDITABLES)).items():
        setattr(persona, campo, valor)
    await db.commit()
    return _armar(persona, pasajero)
