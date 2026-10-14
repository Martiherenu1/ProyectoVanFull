"""esquema inicial

Crea las 35 tablas de backend/db/schema.sql (generada desde los modelos y revisada a mano) y
carga los 5 roles de rol_acceso. Incluye cuenta_acceso.hash_contrasena, decisión del modelo
físico del 2026-10-13: schema.sql, models/ y esta migración cambian juntos (CONTRIBUTING §2).

Revision ID: 0001
Revises:
Create Date: 2026-10-14

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '0001'
down_revision: Union[str, Sequence[str], None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Crea el esquema y el catálogo de roles."""
    op.create_table('cliente',
    sa.Column('id_cliente', sa.BigInteger(), sa.Identity(always=True), nullable=False),
    sa.Column('naturaleza_cliente', sa.String(length=20), nullable=False),
    sa.CheckConstraint("naturaleza_cliente IN ('INDIVIDUAL', 'PERSONA_JURIDICA')"),
    sa.PrimaryKeyConstraint('id_cliente')
    )
    op.create_table('parada',
    sa.Column('id_parada', sa.BigInteger(), sa.Identity(always=True), nullable=False),
    sa.Column('nombre_descripcion', sa.String(length=150), nullable=True),
    sa.Column('direccion', sa.String(length=200), nullable=True),
    sa.Column('latitud', sa.Numeric(precision=9, scale=6), nullable=True),
    sa.Column('longitud', sa.Numeric(precision=9, scale=6), nullable=True),
    sa.PrimaryKeyConstraint('id_parada')
    )
    op.create_table('persona',
    sa.Column('id_persona', sa.BigInteger(), sa.Identity(always=True), nullable=False),
    sa.Column('nombre', sa.String(length=80), nullable=False),
    sa.Column('apellido', sa.String(length=80), nullable=False),
    sa.Column('dni', sa.String(length=20), nullable=False),
    sa.Column('direccion', sa.String(length=200), nullable=True),
    sa.Column('telefono', sa.String(length=30), nullable=True),
    sa.Column('email', sa.String(length=120), nullable=True),
    sa.PrimaryKeyConstraint('id_persona'),
    sa.UniqueConstraint('dni')
    )
    op.create_table('recorrido',
    sa.Column('id_recorrido', sa.BigInteger(), sa.Identity(always=True), nullable=False),
    sa.PrimaryKeyConstraint('id_recorrido')
    )
    op.create_table('rol_acceso',
    sa.Column('id_rol_acceso', sa.BigInteger(), sa.Identity(always=True), nullable=False),
    sa.Column('rol', sa.String(length=50), nullable=False),
    sa.PrimaryKeyConstraint('id_rol_acceso'),
    sa.UniqueConstraint('rol')
    )
    op.create_table('servicio',
    sa.Column('id_servicio', sa.BigInteger(), sa.Identity(always=True), nullable=False),
    sa.Column('tipo_servicio', sa.String(length=20), nullable=False),
    sa.CheckConstraint("tipo_servicio IN ('UNIVERSITARIO', 'LABORAL', 'CORPORATIVO', 'ESPECIAL')"),
    sa.PrimaryKeyConstraint('id_servicio')
    )
    op.create_table('tarifa',
    sa.Column('id_tarifa', sa.BigInteger(), sa.Identity(always=True), nullable=False),
    sa.Column('nombre', sa.String(length=120), nullable=False),
    sa.Column('importe', sa.Numeric(precision=12, scale=2), nullable=False),
    sa.Column('tipo', sa.String(length=40), nullable=True),
    sa.Column('fecha_creacion', sa.Date(), server_default=sa.text('CURRENT_DATE'), nullable=False),
    sa.Column('fecha_vigencia', sa.Date(), nullable=True),
    sa.CheckConstraint('importe >= 0'),
    sa.PrimaryKeyConstraint('id_tarifa')
    )
    op.create_table('vehiculo',
    sa.Column('id_vehiculo', sa.BigInteger(), sa.Identity(always=True), nullable=False),
    sa.Column('patente', sa.String(length=10), nullable=False),
    sa.Column('marca', sa.String(length=50), nullable=True),
    sa.Column('modelo', sa.String(length=50), nullable=True),
    sa.Column('capacidad', sa.Integer(), nullable=False),
    sa.Column('disponibilidad', sa.Boolean(), server_default=sa.text('true'), nullable=False),
    sa.CheckConstraint('capacidad > 0'),
    sa.PrimaryKeyConstraint('id_vehiculo'),
    sa.UniqueConstraint('patente')
    )
    op.create_table('chofer',
    sa.Column('id_persona', sa.BigInteger(), nullable=False),
    sa.Column('cuil', sa.String(length=20), nullable=True),
    sa.Column('registro_conducir', sa.String(length=40), nullable=True),
    sa.Column('fecha_vencimiento_registro', sa.Date(), nullable=True),
    sa.ForeignKeyConstraint(['id_persona'], ['persona.id_persona'], ),
    sa.PrimaryKeyConstraint('id_persona')
    )
    op.create_table('cliente_corporativo',
    sa.Column('id_cliente', sa.BigInteger(), nullable=False),
    sa.Column('estado', sa.String(length=30), server_default='activo', nullable=False),
    sa.ForeignKeyConstraint(['id_cliente'], ['cliente.id_cliente'], ),
    sa.PrimaryKeyConstraint('id_cliente')
    )
    op.create_table('cliente_individual',
    sa.Column('id_cliente', sa.BigInteger(), nullable=False),
    sa.Column('id_persona', sa.BigInteger(), nullable=False),
    sa.ForeignKeyConstraint(['id_cliente'], ['cliente.id_cliente'], ),
    sa.ForeignKeyConstraint(['id_persona'], ['persona.id_persona'], ),
    sa.PrimaryKeyConstraint('id_cliente'),
    sa.UniqueConstraint('id_persona')
    )
    op.create_table('cliente_persona_juridica',
    sa.Column('id_cliente', sa.BigInteger(), nullable=False),
    sa.Column('razon_social', sa.String(length=150), nullable=False),
    sa.Column('cuit', sa.String(length=20), nullable=False),
    sa.Column('direccion', sa.String(length=200), nullable=True),
    sa.ForeignKeyConstraint(['id_cliente'], ['cliente.id_cliente'], ),
    sa.PrimaryKeyConstraint('id_cliente'),
    sa.UniqueConstraint('cuit')
    )
    op.create_table('contratacion',
    sa.Column('id_contratacion', sa.BigInteger(), sa.Identity(always=True), nullable=False),
    sa.Column('id_cliente', sa.BigInteger(), nullable=False),
    sa.Column('id_servicio', sa.BigInteger(), nullable=False),
    sa.Column('id_tarifa', sa.BigInteger(), nullable=True),
    sa.Column('importe_acordado', sa.Numeric(precision=12, scale=2), nullable=True),
    sa.Column('condiciones_comerciales', sa.Text(), nullable=True),
    sa.CheckConstraint('importe_acordado IS NULL OR importe_acordado >= 0'),
    sa.ForeignKeyConstraint(['id_cliente'], ['cliente.id_cliente'], ),
    sa.ForeignKeyConstraint(['id_servicio'], ['servicio.id_servicio'], ),
    sa.ForeignKeyConstraint(['id_tarifa'], ['tarifa.id_tarifa'], ),
    sa.PrimaryKeyConstraint('id_contratacion'),
    sa.UniqueConstraint('id_contratacion', 'id_cliente')
    )
    op.create_table('cuenta_acceso',
    sa.Column('id_cuenta_acceso', sa.BigInteger(), sa.Identity(always=True), nullable=False),
    sa.Column('id_persona', sa.BigInteger(), nullable=False),
    sa.Column('identificador_acceso', sa.String(length=120), nullable=False),
    sa.Column('hash_contrasena', sa.String(length=255), nullable=False),
    sa.Column('estado', sa.String(length=20), server_default='activo', nullable=False),
    sa.ForeignKeyConstraint(['id_persona'], ['persona.id_persona'], ),
    sa.PrimaryKeyConstraint('id_cuenta_acceso'),
    sa.UniqueConstraint('id_persona'),
    sa.UniqueConstraint('identificador_acceso')
    )
    op.create_table('cuenta_corriente',
    sa.Column('id_cliente', sa.BigInteger(), nullable=False),
    sa.ForeignKeyConstraint(['id_cliente'], ['cliente.id_cliente'], ),
    sa.PrimaryKeyConstraint('id_cliente')
    )
    op.create_table('parada_recorrido',
    sa.Column('id_recorrido', sa.BigInteger(), nullable=False),
    sa.Column('orden', sa.Integer(), nullable=False),
    sa.Column('id_parada', sa.BigInteger(), nullable=False),
    sa.Column('comprometida', sa.Boolean(), server_default=sa.text('false'), nullable=False),
    sa.ForeignKeyConstraint(['id_parada'], ['parada.id_parada'], ),
    sa.ForeignKeyConstraint(['id_recorrido'], ['recorrido.id_recorrido'], ),
    sa.PrimaryKeyConstraint('id_recorrido', 'orden')
    )
    op.create_table('pasajero',
    sa.Column('id_persona', sa.BigInteger(), nullable=False),
    sa.Column('categoria', sa.String(length=30), nullable=True),
    sa.Column('estado_habilitacion', sa.String(length=20), server_default='habilitado', nullable=False),
    sa.Column('fotografia', sa.String(length=500), nullable=True),
    sa.CheckConstraint("estado_habilitacion IN ('habilitado', 'suspendido', 'baja')"),
    sa.ForeignKeyConstraint(['id_persona'], ['persona.id_persona'], ),
    sa.PrimaryKeyConstraint('id_persona')
    )
    op.create_table('abono_mensual',
    sa.Column('id_abono_mensual', sa.BigInteger(), sa.Identity(always=True), nullable=False),
    sa.Column('id_contratacion', sa.BigInteger(), nullable=False),
    sa.Column('id_pasajero', sa.BigInteger(), nullable=False),
    sa.Column('modalidad', sa.String(length=20), nullable=True),
    sa.Column('dias_semanales', sa.String(length=30), nullable=True),
    sa.Column('estado', sa.String(length=30), server_default='activo', nullable=False),
    sa.CheckConstraint("modalidad IS NULL OR modalidad IN ('IDA', 'VUELTA', 'IDA_VUELTA')"),
    sa.ForeignKeyConstraint(['id_contratacion'], ['contratacion.id_contratacion'], ),
    sa.ForeignKeyConstraint(['id_pasajero'], ['pasajero.id_persona'], ),
    sa.PrimaryKeyConstraint('id_abono_mensual'),
    sa.UniqueConstraint('id_contratacion')
    )
    op.create_table('contacto_corporativo',
    sa.Column('id_cliente_corporativo', sa.BigInteger(), nullable=False),
    sa.Column('id_persona', sa.BigInteger(), nullable=False),
    sa.Column('cargo', sa.String(length=80), nullable=True),
    sa.Column('es_representante', sa.Boolean(), server_default=sa.text('false'), nullable=False),
    sa.ForeignKeyConstraint(['id_cliente_corporativo'], ['cliente_corporativo.id_cliente'], ),
    sa.ForeignKeyConstraint(['id_persona'], ['persona.id_persona'], ),
    sa.PrimaryKeyConstraint('id_cliente_corporativo', 'id_persona')
    )
    op.create_table('cuenta_rol',
    sa.Column('id_cuenta_acceso', sa.BigInteger(), nullable=False),
    sa.Column('id_rol_acceso', sa.BigInteger(), nullable=False),
    sa.ForeignKeyConstraint(['id_cuenta_acceso'], ['cuenta_acceso.id_cuenta_acceso'], ),
    sa.ForeignKeyConstraint(['id_rol_acceso'], ['rol_acceso.id_rol_acceso'], ),
    sa.PrimaryKeyConstraint('id_cuenta_acceso', 'id_rol_acceso')
    )
    op.create_table('pago',
    sa.Column('id_pago', sa.BigInteger(), sa.Identity(always=True), nullable=False),
    sa.Column('id_cliente', sa.BigInteger(), nullable=False),
    sa.Column('importe', sa.Numeric(precision=12, scale=2), nullable=False),
    sa.Column('fecha_hora', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.Column('medio_pago', sa.String(length=20), nullable=False),
    sa.Column('estado', sa.String(length=20), server_default='PENDIENTE', nullable=False),
    sa.CheckConstraint("estado IN ('PENDIENTE', 'CONFIRMADO', 'RECHAZADO')"),
    sa.CheckConstraint("medio_pago IN ('EFECTIVO', 'TRANSFERENCIA', 'BILLETERA', 'CUENTA_CORRIENTE', 'MERCADO_PAGO')"),
    sa.CheckConstraint('importe >= 0'),
    sa.ForeignKeyConstraint(['id_cliente'], ['cuenta_corriente.id_cliente'], ),
    sa.PrimaryKeyConstraint('id_pago'),
    sa.UniqueConstraint('id_pago', 'id_cliente')
    )
    op.create_table('pasajero_corporativo',
    sa.Column('id_cliente_corporativo', sa.BigInteger(), nullable=False),
    sa.Column('id_pasajero', sa.BigInteger(), nullable=False),
    sa.Column('estado_vinculo', sa.String(length=30), server_default='activo', nullable=False),
    sa.ForeignKeyConstraint(['id_cliente_corporativo'], ['cliente_corporativo.id_cliente'], ),
    sa.ForeignKeyConstraint(['id_pasajero'], ['pasajero.id_persona'], ),
    sa.PrimaryKeyConstraint('id_cliente_corporativo', 'id_pasajero')
    )
    op.create_table('viaje',
    sa.Column('id_viaje', sa.BigInteger(), sa.Identity(always=True), nullable=False),
    sa.Column('id_servicio', sa.BigInteger(), nullable=False),
    sa.Column('id_recorrido', sa.BigInteger(), nullable=False),
    sa.Column('id_vehiculo', sa.BigInteger(), nullable=True),
    sa.Column('id_chofer', sa.BigInteger(), nullable=True),
    sa.Column('fecha', sa.Date(), nullable=False),
    sa.Column('horario', sa.Time(), nullable=True),
    sa.Column('sentido', sa.String(length=10), nullable=False),
    sa.Column('estado', sa.String(length=20), server_default='programado', nullable=False),
    sa.Column('capacidad_planificada', sa.Integer(), nullable=True),
    sa.CheckConstraint("estado IN ('programado', 'en_curso', 'finalizado', 'cancelado')"),
    sa.CheckConstraint("sentido IN ('IDA', 'VUELTA')"),
    sa.CheckConstraint('capacidad_planificada IS NULL OR capacidad_planificada >= 0'),
    sa.ForeignKeyConstraint(['id_chofer'], ['chofer.id_persona'], ),
    sa.ForeignKeyConstraint(['id_recorrido'], ['recorrido.id_recorrido'], ),
    sa.ForeignKeyConstraint(['id_servicio'], ['servicio.id_servicio'], ),
    sa.ForeignKeyConstraint(['id_vehiculo'], ['vehiculo.id_vehiculo'], ),
    sa.PrimaryKeyConstraint('id_viaje'),
    sa.UniqueConstraint('id_viaje', 'id_recorrido'),
    sa.UniqueConstraint('id_viaje', 'id_vehiculo')
    )
    op.create_table('abordaje',
    sa.Column('id_abordaje', sa.BigInteger(), sa.Identity(always=True), nullable=False),
    sa.Column('id_pasajero', sa.BigInteger(), nullable=False),
    sa.Column('id_viaje', sa.BigInteger(), nullable=False),
    sa.Column('id_vehiculo', sa.BigInteger(), nullable=False),
    sa.Column('id_recorrido', sa.BigInteger(), nullable=False),
    sa.Column('orden_parada', sa.Integer(), nullable=False),
    sa.ForeignKeyConstraint(['id_pasajero'], ['pasajero.id_persona'], ),
    sa.ForeignKeyConstraint(['id_recorrido', 'orden_parada'], ['parada_recorrido.id_recorrido', 'parada_recorrido.orden'], ),
    sa.ForeignKeyConstraint(['id_viaje', 'id_recorrido'], ['viaje.id_viaje', 'viaje.id_recorrido'], ),
    sa.ForeignKeyConstraint(['id_viaje', 'id_vehiculo'], ['viaje.id_viaje', 'viaje.id_vehiculo'], ),
    sa.PrimaryKeyConstraint('id_abordaje'),
    sa.UniqueConstraint('id_pasajero', 'id_viaje')
    )
    op.create_table('ausencia',
    sa.Column('id_ausencia', sa.BigInteger(), sa.Identity(always=True), nullable=False),
    sa.Column('id_pasajero', sa.BigInteger(), nullable=False),
    sa.Column('id_viaje', sa.BigInteger(), nullable=False),
    sa.ForeignKeyConstraint(['id_pasajero'], ['pasajero.id_persona'], ),
    sa.ForeignKeyConstraint(['id_viaje'], ['viaje.id_viaje'], ),
    sa.PrimaryKeyConstraint('id_ausencia'),
    sa.UniqueConstraint('id_pasajero', 'id_viaje')
    )
    op.create_table('movimiento_cuenta',
    sa.Column('id_movimiento_cuenta', sa.BigInteger(), sa.Identity(always=True), nullable=False),
    sa.Column('id_cliente', sa.BigInteger(), nullable=False),
    sa.Column('id_contratacion', sa.BigInteger(), nullable=True),
    sa.Column('id_pago', sa.BigInteger(), nullable=True),
    sa.Column('naturaleza', sa.String(length=20), nullable=False),
    sa.Column('estado', sa.String(length=20), server_default='pendiente', nullable=False),
    sa.Column('importe', sa.Numeric(precision=12, scale=2), nullable=False),
    sa.Column('fecha_hora', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.CheckConstraint("naturaleza IN ('DEUDOR', 'ACREEDOR')"),
    sa.CheckConstraint('importe >= 0'),
    sa.ForeignKeyConstraint(['id_cliente'], ['cuenta_corriente.id_cliente'], ),
    sa.ForeignKeyConstraint(['id_contratacion', 'id_cliente'], ['contratacion.id_contratacion', 'contratacion.id_cliente'], ),
    sa.ForeignKeyConstraint(['id_pago', 'id_cliente'], ['pago.id_pago', 'pago.id_cliente'], ),
    sa.PrimaryKeyConstraint('id_movimiento_cuenta'),
    sa.UniqueConstraint('id_pago')
    )
    op.create_table('nomina_pasajeros',
    sa.Column('id_viaje', sa.BigInteger(), nullable=False),
    sa.ForeignKeyConstraint(['id_viaje'], ['viaje.id_viaje'], ),
    sa.PrimaryKeyConstraint('id_viaje')
    )
    op.create_table('periodo_abono',
    sa.Column('id_periodo_abono', sa.BigInteger(), sa.Identity(always=True), nullable=False),
    sa.Column('id_abono_mensual', sa.BigInteger(), nullable=False),
    sa.Column('periodo', sa.String(length=7), nullable=False),
    sa.Column('estado', sa.String(length=30), server_default='vigente', nullable=False),
    sa.ForeignKeyConstraint(['id_abono_mensual'], ['abono_mensual.id_abono_mensual'], ),
    sa.PrimaryKeyConstraint('id_periodo_abono'),
    sa.UniqueConstraint('id_abono_mensual', 'periodo')
    )
    op.create_table('posicion_gps',
    sa.Column('id_viaje', sa.BigInteger(), nullable=False),
    sa.Column('latitud', sa.Numeric(precision=9, scale=6), nullable=True),
    sa.Column('longitud', sa.Numeric(precision=9, scale=6), nullable=True),
    sa.Column('fecha_hora_posicion', sa.DateTime(timezone=True), nullable=True),
    sa.ForeignKeyConstraint(['id_viaje'], ['viaje.id_viaje'], ),
    sa.PrimaryKeyConstraint('id_viaje')
    )
    op.create_table('registro_lista_espera',
    sa.Column('id_registro_lista_espera', sa.BigInteger(), sa.Identity(always=True), nullable=False),
    sa.Column('id_pasajero', sa.BigInteger(), nullable=False),
    sa.Column('id_viaje', sa.BigInteger(), nullable=False),
    sa.Column('fecha_hora_solicitud', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.Column('estado', sa.String(length=20), server_default='en_espera', nullable=False),
    sa.ForeignKeyConstraint(['id_pasajero'], ['pasajero.id_persona'], ),
    sa.ForeignKeyConstraint(['id_viaje'], ['viaje.id_viaje'], ),
    sa.PrimaryKeyConstraint('id_registro_lista_espera'),
    sa.UniqueConstraint('id_pasajero', 'id_viaje')
    )
    op.create_table('comprobante',
    sa.Column('id_comprobante', sa.BigInteger(), sa.Identity(always=True), nullable=False),
    sa.Column('tipo', sa.String(length=20), nullable=False),
    sa.Column('id_pago', sa.BigInteger(), nullable=True),
    sa.Column('id_contratacion', sa.BigInteger(), nullable=True),
    sa.Column('id_movimiento_cuenta', sa.BigInteger(), nullable=True),
    sa.CheckConstraint("(tipo = 'RECIBO' AND id_pago IS NOT NULL AND id_contratacion IS NULL AND id_movimiento_cuenta IS NULL) OR (tipo = 'FACTURA' AND id_pago IS NULL AND id_contratacion IS NOT NULL AND id_movimiento_cuenta IS NULL) OR (tipo IN ('NOTA_DE_CREDITO', 'NOTA_DE_DEBITO') AND id_pago IS NULL AND id_contratacion IS NULL AND id_movimiento_cuenta IS NOT NULL)", name='ck_comprobante_origen_tipo'),
    sa.CheckConstraint("tipo IN ('RECIBO', 'FACTURA', 'NOTA_DE_CREDITO', 'NOTA_DE_DEBITO')"),
    sa.ForeignKeyConstraint(['id_contratacion'], ['contratacion.id_contratacion'], ),
    sa.ForeignKeyConstraint(['id_movimiento_cuenta'], ['movimiento_cuenta.id_movimiento_cuenta'], ),
    sa.ForeignKeyConstraint(['id_pago'], ['pago.id_pago'], ),
    sa.PrimaryKeyConstraint('id_comprobante'),
    sa.UniqueConstraint('id_movimiento_cuenta'),
    sa.UniqueConstraint('id_pago')
    )
    op.create_table('integrante_nomina',
    sa.Column('id_integrante_nomina', sa.BigInteger(), sa.Identity(always=True), nullable=False),
    sa.Column('id_viaje', sa.BigInteger(), nullable=False),
    sa.Column('nombre', sa.String(length=80), nullable=False),
    sa.Column('apellido', sa.String(length=80), nullable=False),
    sa.Column('dni', sa.String(length=20), nullable=False),
    sa.ForeignKeyConstraint(['id_viaje'], ['nomina_pasajeros.id_viaje'], ),
    sa.PrimaryKeyConstraint('id_integrante_nomina'),
    sa.UniqueConstraint('id_viaje', 'dni')
    )
    op.create_table('periodo_abono_viaje',
    sa.Column('id_periodo_abono', sa.BigInteger(), nullable=False),
    sa.Column('id_viaje', sa.BigInteger(), nullable=False),
    sa.ForeignKeyConstraint(['id_periodo_abono'], ['periodo_abono.id_periodo_abono'], ),
    sa.ForeignKeyConstraint(['id_viaje'], ['viaje.id_viaje'], ),
    sa.PrimaryKeyConstraint('id_periodo_abono', 'id_viaje')
    )
    op.create_table('reserva',
    sa.Column('id_reserva', sa.BigInteger(), sa.Identity(always=True), nullable=False),
    sa.Column('id_pasajero', sa.BigInteger(), nullable=False),
    sa.Column('id_viaje', sa.BigInteger(), nullable=False),
    sa.Column('id_recorrido', sa.BigInteger(), nullable=False),
    sa.Column('orden_parada', sa.Integer(), nullable=False),
    sa.Column('id_periodo_abono', sa.BigInteger(), nullable=True),
    sa.Column('id_contratacion_directa', sa.BigInteger(), nullable=True),
    sa.Column('estado', sa.String(length=20), server_default='provisional', nullable=False),
    sa.CheckConstraint("estado IN ('provisional', 'consolidada', 'cancelada')"),
    sa.CheckConstraint('(id_periodo_abono IS NOT NULL) <> (id_contratacion_directa IS NOT NULL)'),
    sa.ForeignKeyConstraint(['id_contratacion_directa'], ['contratacion.id_contratacion'], ),
    sa.ForeignKeyConstraint(['id_pasajero'], ['pasajero.id_persona'], ),
    sa.ForeignKeyConstraint(['id_periodo_abono', 'id_viaje'], ['periodo_abono_viaje.id_periodo_abono', 'periodo_abono_viaje.id_viaje'], ),
    sa.ForeignKeyConstraint(['id_recorrido', 'orden_parada'], ['parada_recorrido.id_recorrido', 'parada_recorrido.orden'], ),
    sa.ForeignKeyConstraint(['id_viaje', 'id_recorrido'], ['viaje.id_viaje', 'viaje.id_recorrido'], ),
    sa.PrimaryKeyConstraint('id_reserva'),
    sa.UniqueConstraint('id_pasajero', 'id_viaje')
    )
    op.create_table('evento_operativo',
    sa.Column('id_evento_operativo', sa.BigInteger(), sa.Identity(always=True), nullable=False),
    sa.Column('tipo_evento', sa.String(length=50), nullable=False),
    sa.Column('fecha_hora', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.Column('detalle_evento', sa.Text(), nullable=True),
    sa.Column('id_reserva', sa.BigInteger(), nullable=True),
    sa.Column('id_pago', sa.BigInteger(), nullable=True),
    sa.Column('id_viaje', sa.BigInteger(), nullable=True),
    sa.CheckConstraint('(CASE WHEN id_reserva IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN id_pago IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN id_viaje IS NOT NULL THEN 1 ELSE 0 END) <= 1'),
    sa.ForeignKeyConstraint(['id_pago'], ['pago.id_pago'], ),
    sa.ForeignKeyConstraint(['id_reserva'], ['reserva.id_reserva'], ),
    sa.ForeignKeyConstraint(['id_viaje'], ['viaje.id_viaje'], ),
    sa.PrimaryKeyConstraint('id_evento_operativo')
    )

    # Catálogo de roles: el mismo INSERT que cierra schema.sql. Los permisos por rol viven en
    # la app (rol_acceso + cuenta_rol), no en el motor (CONTEXTO §7).
    op.execute(
        "INSERT INTO rol_acceso (rol) VALUES "
        "('pasajero'), ('chofer'), ('administrador'), ('dueno'), ('representante_corporativo')"
    )


def downgrade() -> None:
    """Deja la base vacía. Al borrar las tablas se van también los roles cargados."""
    op.drop_table('evento_operativo')
    op.drop_table('reserva')
    op.drop_table('periodo_abono_viaje')
    op.drop_table('integrante_nomina')
    op.drop_table('comprobante')
    op.drop_table('registro_lista_espera')
    op.drop_table('posicion_gps')
    op.drop_table('periodo_abono')
    op.drop_table('nomina_pasajeros')
    op.drop_table('movimiento_cuenta')
    op.drop_table('ausencia')
    op.drop_table('abordaje')
    op.drop_table('viaje')
    op.drop_table('pasajero_corporativo')
    op.drop_table('pago')
    op.drop_table('cuenta_rol')
    op.drop_table('contacto_corporativo')
    op.drop_table('abono_mensual')
    op.drop_table('pasajero')
    op.drop_table('parada_recorrido')
    op.drop_table('cuenta_corriente')
    op.drop_table('cuenta_acceso')
    op.drop_table('contratacion')
    op.drop_table('cliente_persona_juridica')
    op.drop_table('cliente_individual')
    op.drop_table('cliente_corporativo')
    op.drop_table('chofer')
    op.drop_table('vehiculo')
    op.drop_table('tarifa')
    op.drop_table('servicio')
    op.drop_table('rol_acceso')
    op.drop_table('recorrido')
    op.drop_table('persona')
    op.drop_table('parada')
    op.drop_table('cliente')
