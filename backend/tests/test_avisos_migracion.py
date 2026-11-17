"""Extensión additive: no atribuir autor a eventos anteriores ni borrar evidencia."""

import asyncio

from tests._bd import alembic, base_temporal, consultar, ejecutar_sql


def test_upgrade_preserva_evento_historico_sin_autor():
    with base_temporal() as base:
        assert alembic(base, "upgrade", "0001").returncode == 0
        asyncio.run(
            ejecutar_sql(
                base,
                "INSERT INTO evento_operativo (tipo_evento,detalle_evento) VALUES ('historico','intacto')",
            )
        )
        assert alembic(base, "upgrade", "head").returncode == 0
        assert asyncio.run(
            consultar(
                base,
                "SELECT tipo_evento,detalle_evento,id_cuenta_autora,clave_solicitud FROM evento_operativo",
            )
        ) == [("historico", "intacto", None, None)]
        assert alembic(base, "check").returncode == 0


def test_downgrade_no_borra_autoria_de_avisos():
    with base_temporal() as base:
        assert alembic(base, "upgrade", "head").returncode == 0
        sql = """
        INSERT INTO persona (nombre,apellido,dni) VALUES ('A','B','MIG030');
        INSERT INTO cuenta_acceso (id_persona,identificador_acceso,hash_contrasena) VALUES (1,'migracion','x');
        INSERT INTO servicio (tipo_servicio) VALUES ('UNIVERSITARIO');
        INSERT INTO recorrido DEFAULT VALUES;
        INSERT INTO viaje (id_servicio,id_recorrido,fecha,sentido) VALUES (1,1,'2026-11-15','IDA');
        INSERT INTO evento_operativo (tipo_evento,id_viaje,id_cuenta_autora,clave_solicitud,detalle_evento)
        VALUES ('aviso_demora',1,1,'11111111-1111-4111-8111-111111111111','test');
        """
        asyncio.run(ejecutar_sql(base, sql))
        assert alembic(base, "downgrade", "0001").returncode != 0
        assert asyncio.run(
            consultar(base, "SELECT count(*) FROM evento_operativo WHERE id_cuenta_autora=1")
        ) == [(1,)]
