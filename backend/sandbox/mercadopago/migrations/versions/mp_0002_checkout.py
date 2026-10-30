"""Checkout optativo; no descubierto por el upgrade head normal de Render."""

import sqlalchemy as sa
from alembic import op

revision = "mp_0002"
down_revision = "mp_0001"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "checkout_mercadopago",
        sa.Column("id_intento", sa.String(36), primary_key=True),
        sa.Column("id_cliente", sa.BigInteger(), nullable=False),
        sa.Column("clave_solicitud", sa.String(36), nullable=False),
        sa.Column("id_pago", sa.BigInteger(), nullable=False, unique=True),
        sa.Column("id_preferencia", sa.String(160), unique=True),
        sa.Column("url_checkout", sa.Text()),
        sa.Column("estado_tecnico", sa.String(12), nullable=False, server_default="CREANDO"),
        sa.Column(
            "creado_en", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.UniqueConstraint("id_cliente", "clave_solicitud"),
        sa.ForeignKeyConstraint(
            ["id_pago", "id_cliente"], ["pago.id_pago", "pago.id_cliente"], ondelete="RESTRICT"
        ),
        sa.CheckConstraint(
            "estado_tecnico IN ('CREANDO','LISTO','INCIERTO')", name="ck_checkout_estado"
        ),
    )


def downgrade():
    op.drop_table("checkout_mercadopago")
