"""Pasajeros de la organización, para su representante corporativo (CU-033, RF-035, RN-026, RN-028).

Alcance recortado a lo definido: listar, registrar y modificar. Queda afuera la baja (A2), porque la
propia spec la deja como pendiente de precisión funcional (si termina solo la relación con la
organización o cambia además el estado general del usuario en VanFull).

El router solo exigió el rol `representante_corporativo`. El rol dice qué *clase* de operación puede
intentar; el alcance se decide acá, con la persona del token: la empresa tiene que figurar entre
aquellas de las que es contacto con `es_representante` (`contacto_corporativo`). Una empresa que no
representa responde igual que una inexistente (404), y lo mismo un pasajero que no es de ella: no se
presenta ni se modifica nada ajeno (A3, RN-028). `persona`, `pasajero`, `contacto_corporativo` y
`pasajero_corporativo` son tablas de este dueño.
"""

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.core.security import UsuarioActual
from app.models.personas import ClientePersonaJuridica, Pasajero, Persona
from app.models.personas import ContactoCorporativo as ContactoModelo
from app.models.personas import PasajeroCorporativo as VinculoModelo
from app.schemas.organizaciones import (
    CAMPOS_EDITABLES,
    OrganizacionLista,
    OrganizacionRepresentada,
    PasajeroOrganizacion,
    PasajeroOrganizacionCreate,
    PasajeroOrganizacionLista,
    PasajeroOrganizacionUpdate,
)
from app.schemas.pasajeros import PasajeroCreate
from app.services.pasajeros import cargar_pasajero, insertar_pasajero


def _armar(persona: Persona, pasajero: Pasajero) -> PasajeroOrganizacion:
    return PasajeroOrganizacion(
        id_persona=persona.id_persona,
        nombre=persona.nombre,
        apellido=persona.apellido,
        dni=persona.dni,
        email=persona.email,
        telefono=persona.telefono,
        direccion=persona.direccion,
        estado_habilitacion=pasajero.estado_habilitacion,
    )


async def _exigir_organizacion(db: AsyncSession, usuario: UsuarioActual, id_cliente: int) -> None:
    """404 si la persona del token no es representante de esa empresa (o la empresa no existe)."""
    fila = (
        await db.execute(
            select(ContactoModelo.id_persona).where(
                ContactoModelo.id_cliente_corporativo == id_cliente,
                ContactoModelo.id_persona == usuario.id_persona,
                ContactoModelo.es_representante.is_(True),
            )
        )
    ).first()
    if fila is None:
        raise ApiError(
            404,
            "ORGANIZACION_NO_ENCONTRADA",
            "No existe una organización con el identificador indicado entre las que representás.",
        )


async def listar_organizaciones(db: AsyncSession, usuario: UsuarioActual) -> OrganizacionLista:
    """Las empresas que el usuario representa: sirve para saber qué `id_cliente` usar."""
    filas = (
        await db.execute(
            select(
                ContactoModelo.id_cliente_corporativo,
                ClientePersonaJuridica.razon_social,
                ContactoModelo.cargo,
            )
            .join(
                ClientePersonaJuridica,
                ClientePersonaJuridica.id_cliente == ContactoModelo.id_cliente_corporativo,
            )
            .where(
                ContactoModelo.id_persona == usuario.id_persona,
                ContactoModelo.es_representante.is_(True),
            )
            .order_by(ClientePersonaJuridica.razon_social, ContactoModelo.id_cliente_corporativo)
        )
    ).all()
    items = [
        OrganizacionRepresentada(id_cliente=id_cliente, razon_social=razon_social, cargo=cargo)
        for id_cliente, razon_social, cargo in filas
    ]
    return OrganizacionLista(items=items, total=len(items))


async def listar_pasajeros(
    db: AsyncSession,
    usuario: UsuarioActual,
    id_cliente: int,
    *,
    limite: int,
    desplazamiento: int,
) -> PasajeroOrganizacionLista:
    await _exigir_organizacion(db, usuario, id_cliente)
    de_la_empresa = VinculoModelo.id_cliente_corporativo == id_cliente
    total = await db.scalar(select(func.count()).select_from(VinculoModelo).where(de_la_empresa))
    filas = (
        await db.execute(
            select(Persona, Pasajero)
            .join(Pasajero, Pasajero.id_persona == Persona.id_persona)
            .join(VinculoModelo, VinculoModelo.id_pasajero == Pasajero.id_persona)
            .where(de_la_empresa)
            .order_by(Persona.apellido, Persona.nombre, Persona.id_persona)
            .limit(limite)
            .offset(desplazamiento)
        )
    ).all()
    return PasajeroOrganizacionLista(
        items=[_armar(persona, pasajero) for persona, pasajero in filas], total=total or 0
    )


async def registrar_pasajero(
    db: AsyncSession,
    usuario: UsuarioActual,
    id_cliente: int,
    datos: PasajeroOrganizacionCreate,
) -> PasajeroOrganizacion:
    """Persona, pasajero y vínculo con la empresa, todo en una sola transacción.

    Si ya hay una persona con ese DNI responde 409 `DNI_DUPLICADO`: reutilizarla no está definido y
    no se infiere. Eso confirma al representante que el DNI ya está registrado, pero no de quién.
    """
    await _exigir_organizacion(db, usuario, id_cliente)
    persona, pasajero = await insertar_pasajero(db, PasajeroCreate(**datos.model_dump()))
    # El INSERT del pasajero se emite antes que el del vínculo: la FK está declarada en el modelo.
    db.add(VinculoModelo(id_cliente_corporativo=id_cliente, id_pasajero=persona.id_persona))
    await db.commit()
    await db.refresh(pasajero)
    return _armar(persona, pasajero)


async def modificar_pasajero(
    db: AsyncSession,
    usuario: UsuarioActual,
    id_cliente: int,
    id_pasajero: int,
    datos: PasajeroOrganizacionUpdate,
) -> PasajeroOrganizacion:
    """Aplica los cambios, todo o nada. Orden de las respuestas: primero el alcance (A3), después
    los datos no habilitados (A4) y por último el cuerpo vacío, para no confirmar nada ajeno."""
    await _exigir_organizacion(db, usuario, id_cliente)
    vinculo = (
        await db.execute(
            select(VinculoModelo.id_pasajero).where(
                VinculoModelo.id_cliente_corporativo == id_cliente,
                VinculoModelo.id_pasajero == id_pasajero,
            )
        )
    ).first()
    if vinculo is None:
        raise ApiError(
            404, "PASAJERO_NO_ENCONTRADO", "No existe ese pasajero en la organización indicada."
        )

    no_habilitados = sorted((datos.model_extra or {}).keys())
    if no_habilitados:
        raise ApiError(
            403,
            "DATO_NO_MODIFICABLE",
            # CU-033 A4: «el cambio debe gestionarse por un administrador autorizado» (RN-026).
            "Ese dato no se puede modificar desde la organización: el cambio debe ser realizado "
            "por un administrador autorizado (RN-026).",
            {"campos": no_habilitados, "campos_editables": list(CAMPOS_EDITABLES)},
        )

    cambios = datos.model_dump(exclude_unset=True, include=set(CAMPOS_EDITABLES))
    if not cambios:
        raise ApiError(400, "VALIDACION", "No se indicó ningún dato para modificar.")

    persona, pasajero = await cargar_pasajero(db, id_pasajero, bloquear=True)
    for campo, valor in cambios.items():
        setattr(persona, campo, valor)
    await db.commit()
    return _armar(persona, pasajero)
