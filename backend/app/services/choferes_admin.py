"""Gestión administrativa de choferes respaldada por CU-021/RF-023."""

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.models.personas import Chofer, Persona
from app.schemas.choferes_admin import ChoferAdmin, ChoferAdminCreate, ChoferAdminUpdate

_CAMPOS_PERSONA = {"nombre", "apellido", "dni", "direccion", "telefono", "email"}
_CAMPOS_CHOFER = {"cuil", "registro_conducir", "fecha_vencimiento_registro"}


def _a_schema(persona: Persona, chofer: Chofer) -> ChoferAdmin:
    return ChoferAdmin(
        id_persona=persona.id_persona,
        nombre=persona.nombre,
        apellido=persona.apellido,
        dni=persona.dni,
        direccion=persona.direccion,
        telefono=persona.telefono,
        email=persona.email,
        cuil=chofer.cuil,
        registro_conducir=chofer.registro_conducir,
        fecha_vencimiento_registro=chofer.fecha_vencimiento_registro,
    )


async def _validar_dni(db: AsyncSession, dni: str, *, excluir_id: int | None = None) -> None:
    consulta = select(Persona.id_persona).where(Persona.dni == dni)
    if excluir_id is not None:
        consulta = consulta.where(Persona.id_persona != excluir_id)
    if await db.scalar(consulta) is not None:
        raise ApiError(409, "DNI_DUPLICADO", "Ya existe una persona con ese DNI.")


async def _buscar(db: AsyncSession, id_persona: int, *, bloquear: bool = False):
    consulta = (
        select(Persona, Chofer)
        .join(Chofer, Chofer.id_persona == Persona.id_persona)
        .where(Persona.id_persona == id_persona)
    )
    if bloquear:
        consulta = consulta.with_for_update()
    return (await db.execute(consulta)).one_or_none()


async def listar_choferes(db: AsyncSession) -> list[ChoferAdmin]:
    filas = (
        await db.execute(
            select(Persona, Chofer)
            .join(Chofer, Chofer.id_persona == Persona.id_persona)
            .order_by(Persona.id_persona)
        )
    ).all()
    return [_a_schema(persona, chofer) for persona, chofer in filas]


async def consultar_chofer(db: AsyncSession, id_persona: int) -> ChoferAdmin:
    fila = await _buscar(db, id_persona)
    if fila is None:
        raise ApiError(404, "CHOFER_NO_ENCONTRADO", "El chofer no existe.")
    return _a_schema(*fila)


async def crear_chofer(db: AsyncSession, datos: ChoferAdminCreate) -> ChoferAdmin:
    await _validar_dni(db, datos.dni)
    persona = Persona(**datos.model_dump(include=_CAMPOS_PERSONA))
    db.add(persona)
    try:
        await db.flush()
        chofer = Chofer(id_persona=persona.id_persona, **datos.model_dump(include=_CAMPOS_CHOFER))
        db.add(chofer)
        await db.flush()
    except IntegrityError as error:
        await db.rollback()
        raise ApiError(409, "DNI_DUPLICADO", "Ya existe una persona con ese DNI.") from error
    resultado = _a_schema(persona, chofer)
    await db.commit()
    return resultado


async def actualizar_chofer(
    db: AsyncSession, id_persona: int, datos: ChoferAdminUpdate
) -> ChoferAdmin:
    fila = await _buscar(db, id_persona, bloquear=True)
    if fila is None:
        raise ApiError(404, "CHOFER_NO_ENCONTRADO", "El chofer no existe.")
    persona, chofer = fila
    if "dni" in datos.model_fields_set:
        await _validar_dni(db, datos.dni, excluir_id=id_persona)
    for campo in datos.model_fields_set & _CAMPOS_PERSONA:
        setattr(persona, campo, getattr(datos, campo))
    for campo in datos.model_fields_set & _CAMPOS_CHOFER:
        setattr(chofer, campo, getattr(datos, campo))
    try:
        await db.flush()
    except IntegrityError as error:
        await db.rollback()
        raise ApiError(409, "DNI_DUPLICADO", "Ya existe una persona con ese DNI.") from error
    resultado = _a_schema(persona, chofer)
    await db.commit()
    return resultado
