-- Estado de Neon DESPUES de la migracion 0002 (CU-030). SOLO LECTURA.
-- Se corre con: psql -X -A -t -q -v ON_ERROR_STOP=1 -f post0002.sql
-- Sirve para el caso en que 0002 se aplico sin el respaldo previo (merge de #281 el 16/11/2026).
SET TimeZone = 'UTC';
SET default_transaction_read_only = on;

SELECT '== alembic_version (se espera 0002)';
SELECT version_num FROM alembic_version;

SELECT '== columnas nuevas de evento_operativo (se esperan 2, ambas nullable)';
SELECT column_name || ' ' || data_type || ' nullable=' || is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'evento_operativo'
  AND column_name IN ('id_cuenta_autora', 'clave_solicitud')
ORDER BY column_name;

SELECT '== restricciones nuevas (se esperan 3, todas validadas)';
SELECT conname || ' tipo=' || contype::text || ' validada=' || convalidated::text
FROM pg_constraint
WHERE conrelid = 'public.evento_operativo'::regclass
  AND conname IN ('evento_operativo_id_cuenta_autora_fkey', 'uq_aviso_solicitud', 'ck_aviso_metadatos')
ORDER BY conname;

SELECT '== evento_operativo: total | con metadatos nuevos (avisos de CU-030 creados despues del deploy)';
SELECT count(*) || ' | ' || count(*) FILTER (WHERE id_cuenta_autora IS NOT NULL OR clave_solicitud IS NOT NULL)
FROM public.evento_operativo;

SELECT '== fin';
