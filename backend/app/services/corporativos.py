"""Gestión de clientes corporativos (CU-023, RF-034, RN-014, RN-028).

Alcance recortado a lo que está definido:
- la empresa: `cliente` (naturaleza PERSONA_JURIDICA) + `cliente_persona_juridica` +
  `cliente_corporativo`, con alta, consulta y modificación de sus datos (flujo principal y A1);
- sus contactos (`contacto_corporativo`), con `cargo` y `es_representante`;
- sus pasajeros asociados (`pasajero_corporativo`, A2).

Queda afuera, por pendiente:
- las condiciones comerciales y modalidades de pago: RN-014 y la spec dicen que no hay un catálogo
  cerrado de acuerdos, y viven en `contratacion`;
- `cliente_corporativo.estado` y `pasajero_corporativo.estado_vinculo`, que solo tienen el valor por
  defecto `activo` y ningún catálogo; por eso desasociar borra la fila en vez de cambiar un estado;
- un corporativo que sea cliente individual: el modelo lo permite, pero la spec habla de empresas;
- la cuenta y los permisos del representante (ACT-03, RN-028): son de CU-033.

El rol ya lo exigió el router (administrador o dueño). Las seis tablas son de este dueño.
"""

from sqlalchemy import delete, func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ApiError
from app.models.personas import (
    Cliente,
    ClientePersonaJuridica,
    Pasajero,
    Persona,
)
from app.models.personas import (
    ClienteCorporativo as ClienteCorporativoModelo,
)
from app.models.personas import (
    ContactoCorporativo as ContactoModelo,
)
from app.models.personas import (
    PasajeroCorporativo as VinculoModelo,
)
from app.schemas.corporativos import (
    ClienteCorporativo,
    ClienteCorporativoCreate,
    ClienteCorporativoDetalle,
    ClienteCorporativoLista,
    ClienteCorporativoUpdate,
    ContactoCorporativo,
    ContactoCorporativoCreate,
    PasajeroCorporativo,
    PasajeroCorporativoCreate,
)
from app.services.pasajeros import dni_en_uso, error_dni_duplicado, patron_busqueda

_CAMPOS_PERSONA = ("nombre", "apellido", "dni", "email", "telefono")


def _cuit_duplicado(cuit: str) -> ApiError:
    return ApiError(
        409, "CUIT_DUPLICADO", "Ya existe una persona jurídica con ese CUIT.", {"cuit": cuit}
    )


def _armar(corporativo: ClienteCorporativoModelo, juridica: ClientePersonaJuridica):
    return ClienteCorporativo(
        id_cliente=corporativo.id_cliente,
        razon_social=juridica.razon_social,
        cuit=juridica.cuit,
        direccion=juridica.direccion,
        estado=corporativo.estado,
    )


def _armar_contacto(contacto: ContactoModelo, persona: Persona) -> ContactoCorporativo:
    return ContactoCorporativo(
        id_persona=persona.id_persona,
        nombre=persona.nombre,
        apellido=persona.apellido,
        dni=persona.dni,
        email=persona.email,
        telefono=persona.telefono,
        cargo=contacto.cargo,
        es_representante=contacto.es_representante,
    )


async def _cargar(
    db: AsyncSession, id_cliente: int, *, bloquear: bool = False
) -> tuple[ClienteCorporativoModelo, ClientePersonaJuridica]:
    """La empresa: corporativo y persona jurídica del mismo cliente. 404 si no es las dos cosas."""
    consulta = (
        select(ClienteCorporativoModelo, ClientePersonaJuridica)
        .join(
            ClientePersonaJuridica,
            ClientePersonaJuridica.id_cliente == ClienteCorporativoModelo.id_cliente,
        )
        .where(ClienteCorporativoModelo.id_cliente == id_cliente)
    )
    if bloquear:
        consulta = consulta.with_for_update()
    fila = (await db.execute(consulta)).one_or_none()
    if fila is None:
        raise ApiError(
            404,
            "CLIENTE_CORPORATIVO_NO_ENCONTRADO",
            "No existe un cliente corporativo con el identificador indicado.",
        )
    return fila[0], fila[1]


async def _cuit_en_uso(db: AsyncSession, cuit: str, *, salvo: int | None = None) -> bool:
    consulta = select(ClientePersonaJuridica.id_cliente).where(ClientePersonaJuridica.cuit == cuit)
    if salvo is not None:
        consulta = consulta.where(ClientePersonaJuridica.id_cliente != salvo)
    return (await db.execute(consulta)).first() is not None


# --- la empresa ----------------------------------------------------------------------------


async def listar(
    db: AsyncSession, *, q: str | None, limite: int, desplazamiento: int
) -> ClienteCorporativoLista:
    filtros = []
    if q and q.strip():
        patron = patron_busqueda(q.strip())
        filtros.append(
            or_(
                ClientePersonaJuridica.razon_social.ilike(patron, escape="\\"),
                ClientePersonaJuridica.cuit.ilike(patron, escape="\\"),
            )
        )
    union = (ClientePersonaJuridica.id_cliente == ClienteCorporativoModelo.id_cliente,)
    total = await db.scalar(
        select(func.count())
        .select_from(ClienteCorporativoModelo)
        .join(ClientePersonaJuridica, *union)
        .where(*filtros)
    )
    filas = (
        await db.execute(
            select(ClienteCorporativoModelo, ClientePersonaJuridica)
            .join(ClientePersonaJuridica, *union)
            .where(*filtros)
            .order_by(ClientePersonaJuridica.razon_social, ClienteCorporativoModelo.id_cliente)
            .limit(limite)
            .offset(desplazamiento)
        )
    ).all()
    return ClienteCorporativoLista(items=[_armar(c, j) for c, j in filas], total=total or 0)


async def obtener(db: AsyncSession, id_cliente: int) -> ClienteCorporativoDetalle:
    corporativo, juridica = await _cargar(db, id_cliente)
    contactos = (
        await db.execute(
            select(ContactoModelo, Persona)
            .join(Persona, Persona.id_persona == ContactoModelo.id_persona)
            .where(ContactoModelo.id_cliente_corporativo == id_cliente)
            .order_by(Persona.apellido, Persona.nombre, Persona.id_persona)
        )
    ).all()
    pasajeros = (
        await db.execute(
            select(VinculoModelo, Pasajero, Persona)
            .join(Pasajero, Pasajero.id_persona == VinculoModelo.id_pasajero)
            .join(Persona, Persona.id_persona == Pasajero.id_persona)
            .where(VinculoModelo.id_cliente_corporativo == id_cliente)
            .order_by(Persona.apellido, Persona.nombre, Persona.id_persona)
        )
    ).all()
    return ClienteCorporativoDetalle(
        **_armar(corporativo, juridica).model_dump(),
        contactos=[_armar_contacto(c, p) for c, p in contactos],
        pasajeros=[
            PasajeroCorporativo(
                id_persona=persona.id_persona,
                nombre=persona.nombre,
                apellido=persona.apellido,
                dni=persona.dni,
                estado_habilitacion=pasajero.estado_habilitacion,
                estado_vinculo=vinculo.estado_vinculo,
            )
            for vinculo, pasajero, persona in pasajeros
        ],
    )


async def crear(db: AsyncSession, datos: ClienteCorporativoCreate) -> ClienteCorporativo:
    """Registra la empresa en una transacción: cliente, persona jurídica y corporativo."""
    if await _cuit_en_uso(db, datos.cuit):
        raise _cuit_duplicado(datos.cuit)

    cliente = Cliente(naturaleza_cliente="PERSONA_JURIDICA")
    db.add(cliente)
    await db.flush()
    juridica = ClientePersonaJuridica(
        id_cliente=cliente.id_cliente,
        razon_social=datos.razon_social,
        cuit=datos.cuit,
        direccion=datos.direccion,
    )
    corporativo = ClienteCorporativoModelo(id_cliente=cliente.id_cliente)
    db.add_all([juridica, corporativo])
    try:
        await db.flush()
    except IntegrityError:
        # Otro alta con el mismo CUIT ganó la carrera entre la consulta y el INSERT.
        await db.rollback()
        raise _cuit_duplicado(datos.cuit) from None
    await db.commit()
    await db.refresh(corporativo)
    return _armar(corporativo, juridica)


async def modificar(
    db: AsyncSession, id_cliente: int, datos: ClienteCorporativoUpdate
) -> ClienteCorporativo:
    """Modifica los datos de la empresa (A1), todo o nada. El estado no se cambia: no hay catálogo."""
    cambios = datos.model_dump(exclude_unset=True)
    if not cambios:
        raise ApiError(400, "VALIDACION", "No se indicó ningún dato para modificar.")

    corporativo, juridica = await _cargar(db, id_cliente, bloquear=True)
    nuevo_cuit = cambios.get("cuit")
    if (
        nuevo_cuit is not None
        and nuevo_cuit != juridica.cuit
        and await _cuit_en_uso(db, nuevo_cuit, salvo=id_cliente)
    ):
        raise _cuit_duplicado(nuevo_cuit)

    for campo, valor in cambios.items():
        setattr(juridica, campo, valor)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        # Solo el CUIT es único entre los datos que se pueden cambiar.
        raise _cuit_duplicado(nuevo_cuit or "") from None
    return _armar(corporativo, juridica)


# --- contactos -----------------------------------------------------------------------------


async def agregar_contacto(
    db: AsyncSession, id_cliente: int, datos: ContactoCorporativoCreate
) -> ContactoCorporativo:
    """Registra un contacto: una persona que ya existe o una nueva (flujo principal, paso 3)."""
    await _cargar(db, id_cliente)

    if datos.id_persona is not None:
        persona = await db.get(Persona, datos.id_persona)
        if persona is None:
            raise ApiError(
                404, "PERSONA_NO_ENCONTRADA", "No existe una persona con el identificador indicado."
            )
    else:
        if await dni_en_uso(db, datos.dni):
            # Si la persona ya existe, se la indica por su id_persona: no se duplica ni se pisa.
            raise error_dni_duplicado(datos.dni)
        persona = Persona(**datos.model_dump(include=set(_CAMPOS_PERSONA)))
        db.add(persona)
        try:
            await db.flush()
        except IntegrityError:
            await db.rollback()
            raise error_dni_duplicado(datos.dni) from None

    ya_registrado = await db.get(ContactoModelo, (id_cliente, persona.id_persona))
    if ya_registrado is not None:
        raise ApiError(
            409,
            "CONTACTO_YA_REGISTRADO",
            "Esa persona ya es contacto de la empresa.",
            {"id_persona": persona.id_persona},
        )
    contacto = ContactoModelo(
        id_cliente_corporativo=id_cliente,
        id_persona=persona.id_persona,
        cargo=datos.cargo,
        es_representante=datos.es_representante,
    )
    db.add(contacto)
    try:
        await db.commit()
    except IntegrityError:
        # Otro pedido registró el mismo contacto entre la consulta y el INSERT.
        await db.rollback()
        raise ApiError(
            409, "CONTACTO_YA_REGISTRADO", "Esa persona ya es contacto de la empresa."
        ) from None
    return _armar_contacto(contacto, persona)


async def quitar_contacto(db: AsyncSession, id_cliente: int, id_persona: int) -> None:
    """Quita el contacto. La persona sigue existiendo."""
    await _cargar(db, id_cliente)
    resultado = await db.execute(
        delete(ContactoModelo).where(
            ContactoModelo.id_cliente_corporativo == id_cliente,
            ContactoModelo.id_persona == id_persona,
        )
    )
    if resultado.rowcount == 0:
        raise ApiError(404, "CONTACTO_NO_ENCONTRADO", "Esa persona no es contacto de la empresa.")
    await db.commit()


# --- pasajeros asociados (A2) --------------------------------------------------------------


async def asociar_pasajero(
    db: AsyncSession, id_cliente: int, datos: PasajeroCorporativoCreate
) -> PasajeroCorporativo:
    """Asocia un pasajero existente a la empresa (A2).

    Un pasajero puede pertenecer a más de una empresa: el modelo lo permite y la spec no lo
    restringe. Tampoco se restringe por su estado de habilitación: no hay regla que lo diga.
    """
    await _cargar(db, id_cliente)
    fila = (
        await db.execute(
            select(Pasajero, Persona)
            .join(Persona, Persona.id_persona == Pasajero.id_persona)
            .where(Pasajero.id_persona == datos.id_pasajero)
        )
    ).one_or_none()
    if fila is None:
        raise ApiError(
            404, "PASAJERO_NO_ENCONTRADO", "No existe un pasajero con el identificador indicado."
        )
    pasajero, persona = fila

    def _ya_asociado() -> ApiError:
        return ApiError(
            409,
            "PASAJERO_YA_ASOCIADO",
            "El pasajero ya está asociado a la empresa.",
            {"id_pasajero": datos.id_pasajero},
        )

    if await db.get(VinculoModelo, (id_cliente, datos.id_pasajero)) is not None:
        raise _ya_asociado()
    vinculo = VinculoModelo(id_cliente_corporativo=id_cliente, id_pasajero=datos.id_pasajero)
    db.add(vinculo)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise _ya_asociado() from None
    await db.refresh(vinculo)
    return PasajeroCorporativo(
        id_persona=persona.id_persona,
        nombre=persona.nombre,
        apellido=persona.apellido,
        dni=persona.dni,
        estado_habilitacion=pasajero.estado_habilitacion,
        estado_vinculo=vinculo.estado_vinculo,
    )


async def desasociar_pasajero(db: AsyncSession, id_cliente: int, id_pasajero: int) -> None:
    """Quita la asociación (A2). El pasajero sigue existiendo, con sus reservas y pagos.

    Se borra la fila porque `estado_vinculo` no tiene un catálogo de estados aprobado.
    """
    await _cargar(db, id_cliente)
    resultado = await db.execute(
        delete(VinculoModelo).where(
            VinculoModelo.id_cliente_corporativo == id_cliente,
            VinculoModelo.id_pasajero == id_pasajero,
        )
    )
    if resultado.rowcount == 0:
        raise ApiError(404, "VINCULO_NO_ENCONTRADO", "El pasajero no está asociado a la empresa.")
    await db.commit()
