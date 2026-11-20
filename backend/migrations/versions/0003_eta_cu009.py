"""Descenso explícito por reserva y último paso confirmado del viaje (CU-009)."""

import sqlalchemy as sa
from alembic import op

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("viaje", sa.Column("orden_ultimo_paso", sa.Integer()))
    op.add_column("viaje", sa.Column("fecha_ultimo_paso", sa.DateTime(timezone=True)))
    op.create_foreign_key(
        "viaje_id_recorrido_orden_ultimo_paso_fkey",
        "viaje",
        "parada_recorrido",
        ["id_recorrido", "orden_ultimo_paso"],
        ["id_recorrido", "orden"],
    )
    op.create_table(
        "descenso_habilitado",
        sa.Column("id_viaje", sa.BigInteger(), primary_key=True),
        sa.Column("orden_parada", sa.Integer(), primary_key=True),
        sa.Column("id_recorrido", sa.BigInteger(), nullable=False),
        sa.ForeignKeyConstraint(
            ["id_viaje", "id_recorrido"], ["viaje.id_viaje", "viaje.id_recorrido"]
        ),
        sa.ForeignKeyConstraint(
            ["id_recorrido", "orden_parada"],
            ["parada_recorrido.id_recorrido", "parada_recorrido.orden"],
        ),
    )
    op.add_column("reserva", sa.Column("orden_descenso", sa.Integer()))
    op.create_foreign_key(
        "reserva_id_viaje_orden_descenso_fkey",
        "reserva",
        "descenso_habilitado",
        ["id_viaje", "orden_descenso"],
        ["id_viaje", "orden_parada"],
    )


def downgrade() -> None:
    op.drop_constraint("reserva_id_viaje_orden_descenso_fkey", "reserva", type_="foreignkey")
    op.drop_column("reserva", "orden_descenso")
    op.drop_table("descenso_habilitado")
    op.drop_constraint("viaje_id_recorrido_orden_ultimo_paso_fkey", "viaje", type_="foreignkey")
    op.drop_column("viaje", "fecha_ultimo_paso")
    op.drop_column("viaje", "orden_ultimo_paso")
