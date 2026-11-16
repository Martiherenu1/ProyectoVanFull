-- Estado del origen antes de la ventana. SOLO LECTURA.
-- Se corre con: psql -X -A -t -q -v ON_ERROR_STOP=1 -f estado.sql
SET default_transaction_read_only = on;

SELECT '== base: ' || current_database() || ' | usuario: ' || current_user;
SELECT '== servidor: ' || version();
SELECT '== version mayor: ' || split_part(current_setting('server_version'), '.', 1);
SELECT '== tamano: ' || pg_size_pretty(pg_database_size(current_database()));
SELECT '== alembic_version (se espera 0001)';
SELECT version_num FROM alembic_version;
SELECT '== extensiones';
SELECT extname || ' ' || extversion FROM pg_extension ORDER BY extname;
SELECT '== tablas del esquema public: ' || count(*)
FROM pg_class WHERE relnamespace = 'public'::regnamespace AND relkind IN ('r', 'p');
SELECT '== otras conexiones a esta base (en la ventana tienen que ser 0 o solo Neon interno)';
SELECT coalesce(application_name, '') || ' | ' || coalesce(state, '') || ' | ' || coalesce(client_addr::text, 'local')
       || ' | desde ' || backend_start::timestamp(0)::text
FROM pg_stat_activity
WHERE datname = current_database() AND pid <> pg_backend_pid()
ORDER BY backend_start;
SELECT '== fin';
