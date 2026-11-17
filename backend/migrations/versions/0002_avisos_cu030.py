"""CU-030: autor y correlación explícitos, históricos sin autor inferido (#280)."""

from alembic import op
import sqlalchemy as sa

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("evento_operativo", sa.Column("id_cuenta_autora", sa.BigInteger(), nullable=True))
    op.add_column("evento_operativo", sa.Column("clave_solicitud", sa.Uuid(), nullable=True))
    op.create_foreign_key(
        "evento_operativo_id_cuenta_autora_fkey",
        "evento_operativo",
        "cuenta_acceso",
        ["id_cuenta_autora"],
        ["id_cuenta_acceso"],
    )
    op.create_unique_constraint(
        "uq_aviso_solicitud",
        "evento_operativo",
        ["id_cuenta_autora", "id_viaje", "clave_solicitud"],
    )
    op.create_check_constraint(
        "ck_aviso_metadatos",
        "evento_operativo",
        "(id_cuenta_autora IS NULL AND clave_solicitud IS NULL) OR "
        "(id_cuenta_autora IS NOT NULL AND clave_solicitud IS NOT NULL "
        "AND id_viaje IS NOT NULL AND detalle_evento IS NOT NULL "
        "AND tipo_evento IN ('aviso_demora', 'aviso_problema'))",
    )


def downgrade():
    # No destruir autoría de avisos nuevos por un downgrade accidental.
    op.execute(
        "DO $$ BEGIN IF EXISTS (SELECT 1 FROM evento_operativo WHERE clave_solicitud IS NOT NULL) THEN RAISE EXCEPTION 'CU030: existen avisos; conservar evidencia antes del downgrade'; END IF; END $$"
    )
    op.drop_constraint("ck_aviso_metadatos", "evento_operativo", type_="check")
    op.drop_constraint("uq_aviso_solicitud", "evento_operativo", type_="unique")
    op.drop_constraint("evento_operativo_id_cuenta_autora_fkey", "evento_operativo", type_="foreignkey")
    op.drop_column("evento_operativo", "clave_solicitud")
    op.drop_column("evento_operativo", "id_cuenta_autora")
