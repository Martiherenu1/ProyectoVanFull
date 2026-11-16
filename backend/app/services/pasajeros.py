"""Gestión administrativa de pasajeros (CU-013, RF-002, RF-042, RN-026).

Alcance recortado a lo que está definido: alta, consulta, modificación (con el DNI, A1) y baja (A4).
Quedan afuera, por pendientes de validación, la suspensión por falta de pago (A2) y la habilitación
excepcional de 5 días (A3), que dependen de RN-004/005/006 (Issue #212), y el motivo de la baja.

El rol ya fue exigido por el router (administrador o dueño). Acá no hay "solo lo propio": un
administrador ve a todos los pasajeros. `persona` y `pasajero` son tablas de este dueño.
"""

from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.models.personas import Pasajero, Persona
from app.schemas.pasajeros import PasajeroAdmin, PasajeroCreate, PasajeroLista, PasajeroUpdate

_CAMPOS_PERSONA = ("nombre", "apellido", "dni", "email", "telefono", "direccion")


def armar_pasajero(persona: Persona, pasajero: Pasajero) -> PasajeroAdmin:
    return PasajeroAdmin(
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


def error_dni_duplicado(dni: str) -> ApiError:
    return ApiError(
        409,
        "DNI_DUPLICADO",
        "Ya existe una persona registrada con ese DNI.",
        {"dni": dni},
    )


async def cargar_pasajero(
    db: AsyncSession, id_persona: int, *, bloquear: bool = False
) -> tuple[Persona, Pasajero]:
    """El pasajero y su persona. Con `bloquear`, toma el lock del pasajero primero (CONVENCIONES §8)."""
    consulta = (
        select(Pasajero).where(Pasajero.id_persona == id_persona).with_for_update()
        if bloquear
        else select(Pasajero).where(Pasajero.id_persona == id_persona)
    )
    pasajero = (await db.execute(consulta)).scalar_one_or_none()
    if pasajero is None:
        raise ApiError(
            404, "PASAJERO_NO_ENCONTRADO", "No existe un pasajero con el identificador indicado."
        )
    persona = (
        await db.execute(
            select(Persona).where(Persona.id_persona == id_persona).with_for_update()
            if bloquear
            else select(Persona).where(Persona.id_persona == id_persona)
        )
    ).scalar_one()
    return persona, pasajero


async def dni_en_uso(db: AsyncSession, dni: str, *, salvo: int | None = None) -> bool:
    consulta = select(Persona.id_persona).where(Persona.dni == dni)
    if salvo is not None:
        consulta = consulta.where(Persona.id_persona != salvo)
    return (await db.execute(consulta)).first() is not None


def patron_busqueda(texto: str) -> str:
    """Texto de búsqueda como patrón ILIKE, sin que `%` ni `_` del usuario funcionen de comodín."""
    escapado = texto.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    return f"%{escapado}%"


async def listar_pasajeros(
    db: AsyncSession, *, q: str | None, limite: int, desplazamiento: int
) -> PasajeroLista:
    """Localiza pasajeros por DNI, nombre o apellido (flujo principal, paso 2)."""
    filtros = []
    if q and q.strip():
        patron = patron_busqueda(q.strip())
        filtros.append(
            or_(
                Persona.dni.ilike(patron, escape="\\"),
                Persona.nombre.ilike(patron, escape="\\"),
                Persona.apellido.ilike(patron, escape="\\"),
            )
        )
    base = select(Persona, Pasajero).join(Pasajero, Pasajero.id_persona == Persona.id_persona)
    total = await db.scalar(
        select(func.count())
        .select_from(Persona)
        .join(Pasajero, Pasajero.id_persona == Persona.id_persona)
        .where(*filtros)
    )
    filas = (
        await db.execute(
            base.where(*filtros)
            .order_by(Persona.apellido, Persona.nombre, Persona.id_persona)
            .limit(limite)
            .offset(desplazamiento)
        )
    ).all()
    return PasajeroLista(
        items=[armar_pasajero(persona, pasajero) for persona, pasajero in filas], total=total or 0
    )


async def obtener_pasajero(db: AsyncSession, id_persona: int) -> PasajeroAdmin:
    persona, pasajero = await cargar_pasajero(db, id_persona)
    return armar_pasajero(persona, pasajero)


async def insertar_pasajero(db: AsyncSession, datos: PasajeroCreate) -> tuple[Persona, Pasajero]:
    """Agrega la persona y el pasajero a la transacción, sin confirmarla (la confirma quien llama).

    Si ya hay una persona con ese DNI (por ejemplo, un chofer) responde 409: reutilizar a la persona
    no está definido y no se infiere. El estado inicial es el de la base: `habilitado`.
    """
    if await dni_en_uso(db, datos.dni):
        raise error_dni_duplicado(datos.dni)

    persona = Persona(**datos.model_dump(include=set(_CAMPOS_PERSONA)))
    db.add(persona)
    try:
        await db.flush()
    except IntegrityError:
        # Otro alta con el mismo DNI ganó la carrera entre la consulta y el INSERT.
        await db.rollback()
        raise error_dni_duplicado(datos.dni) from None
    pasajero = Pasajero(id_persona=persona.id_persona, categoria=datos.categoria)
    db.add(pasajero)
    return persona, pasajero


async def crear_pasajero(db: AsyncSession, datos: PasajeroCreate) -> PasajeroAdmin:
    """Registra la persona y el pasajero en una sola transacción (CU-013, flujo principal)."""
    persona, pasajero = await insertar_pasajero(db, datos)
    await db.commit()
    await db.refresh(pasajero)
    return armar_pasajero(persona, pasajero)


async def modificar_pasajero(
    db: AsyncSession, id_persona: int, datos: PasajeroUpdate
) -> PasajeroAdmin:
    """Aplica los cambios, todo o nada. Administración puede cambiar el DNI (CU-013 A1, RN-026)."""
    cambios = datos.model_dump(exclude_unset=True)
    if not cambios:
        raise ApiError(400, "VALIDACION", "No se indicó ningún dato para modificar.")

    persona, pasajero = await cargar_pasajero(db, id_persona, bloquear=True)

    nuevo_dni = cambios.get("dni")
    if (
        nuevo_dni is not None
        and nuevo_dni != persona.dni
        and await dni_en_uso(db, nuevo_dni, salvo=id_persona)
    ):
        raise error_dni_duplicado(nuevo_dni)

    for campo, valor in cambios.items():
        setattr(pasajero if campo == "categoria" else persona, campo, valor)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        # Solo el DNI es único entre los datos que se pueden cambiar.
        raise error_dni_duplicado(nuevo_dni or "") from None
    return armar_pasajero(persona, pasajero)


async def dar_de_baja(db: AsyncSession, id_persona: int) -> PasajeroAdmin:
    """Baja lógica (CU-013 A4): no se borra nada, las reservas y los pagos siguen apuntando al pasajero.

    PENDIENTE: no hay catálogo de motivos de baja, así que no se guarda ninguno; y tampoco está
    definido qué pasa con las reservas futuras de quien se da de baja.
    """
    persona, pasajero = await cargar_pasajero(db, id_persona, bloquear=True)
    if pasajero.estado_habilitacion == "baja":
        raise ApiError(
            409, "PASAJERO_YA_DADO_DE_BAJA", "El pasajero ya fue dado de baja anteriormente."
        )
    pasajero.estado_habilitacion = "baja"
    await db.commit()
    return armar_pasajero(persona, pasajero)
