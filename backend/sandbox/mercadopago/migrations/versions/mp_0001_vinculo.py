"""CU-036 optativa: fuera del head normal, solo local y autorización explícita."""

import sqlalchemy as sa
from alembic import op

revision = "mp_0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "pago_mercadopago",
        sa.Column("id_operacion", sa.String(64), primary_key=True),
        sa.Column("id_pago", sa.BigInteger(), nullable=False, unique=True),
        sa.Column("id_receptor", sa.BigInteger(), nullable=False),
        sa.Column("moneda", sa.String(3), nullable=False),
        sa.Column(
            "creado_en", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint("id_operacion ~ '^[0-9]{1,64}$'", name="ck_mp_operacion"),
        sa.CheckConstraint("id_receptor > 0", name="ck_mp_receptor"),
        sa.CheckConstraint("moneda ~ '^[A-Z]{3}$'", name="ck_mp_moneda"),
        sa.ForeignKeyConstraint(["id_pago"], ["pago.id_pago"], ondelete="RESTRICT"),
    )


def downgrade() -> None:
    op.drop_table("pago_mercadopago")
