"""Protege el último paso del viaje y el orden de las paradas de la reserva."""

from alembic import op

revision = "0004"
down_revision = "0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_check_constraint(
        "ck_viaje_ultimo_paso_completo",
        "viaje",
        "(orden_ultimo_paso IS NULL) = (fecha_ultimo_paso IS NULL)",
    )
    op.create_check_constraint(
        "ck_reserva_orden_descenso_posterior",
        "reserva",
        "orden_descenso IS NULL OR orden_descenso > orden_parada",
    )


def downgrade() -> None:
    op.drop_constraint("ck_reserva_orden_descenso_posterior", "reserva", type_="check")
    op.drop_constraint("ck_viaje_ultimo_paso_completo", "viaje", type_="check")
