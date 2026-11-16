-- Manifiesto de comparación entre la base de Neon y su copia restaurada. SOLO LECTURA.
-- Se corre con: psql -X -A -t -q -v ON_ERROR_STOP=1 -f manifiesto.sql
-- Si los datos y el esquema son idénticos, la salida es idéntica byte a byte.
--
-- Fija la zona horaria y los formatos: sin esto, el texto de un timestamptz cambiaría según la
-- configuración de la sesión y el hash de una tabla igual saldría distinto.
SET TimeZone = 'UTC';
SET DateStyle = 'ISO, YMD';
SET extra_float_digits = 1;
SET bytea_output = 'hex';
SET default_transaction_read_only = on;

SELECT '== version del servidor (mayor)';
SELECT split_part(current_setting('server_version'), '.', 1);

SELECT '== alembic_version';
SELECT version_num FROM alembic_version ORDER BY version_num;

SELECT '== extensiones';
SELECT extname || ' ' || extversion FROM pg_extension ORDER BY extname;

-- Por tabla: cantidad exacta de filas y un hash de TODAS las filas (cada fila pasada a texto y
-- ordenada), así que detecta un valor cambiado, no solo una fila de más o de menos.
SELECT '== tablas: nombre | filas | md5 de todas las filas';
SELECT c.relname
       || ' | ' || (xpath('/row/n/text()',
            query_to_xml(format('SELECT count(*) AS n FROM public.%I', c.relname), false, true, '')))[1]::text
       || ' | ' || (xpath('/row/h/text()',
            query_to_xml(format('SELECT md5(coalesce(string_agg(t::text, ''|'' ORDER BY t::text), '''')) AS h FROM public.%I t', c.relname), false, true, '')))[1]::text
FROM pg_class c
WHERE c.relnamespace = 'public'::regnamespace AND c.relkind IN ('r', 'p')
ORDER BY c.relname;

SELECT '== secuencias: nombre | ultimo valor';
SELECT schemaname || '.' || sequencename || ' | ' || coalesce(last_value::text, 'NULL')
FROM pg_sequences
WHERE schemaname = 'public'
ORDER BY 1;

SELECT '== columnas';
SELECT table_name || '.' || ordinal_position || ' ' || column_name || ' ' || data_type || ' '
       || is_nullable || ' ' || coalesce(column_default, '')
FROM information_schema.columns
WHERE table_schema = 'public'
ORDER BY table_name, ordinal_position;

-- Los CHECK se comparan por tabla, nombre, tipo y si estan validados, SIN el texto de la expresion:
-- PostgreSQL re-escribe ese texto al restaurar (por ejemplo ANY (ARRAY[...]) pasa a
-- ANY ((ARRAY[...])::text[])) con el mismo significado, y compararlo daria un falso "difiere"
-- (visto en el ensayo). PK, FK y UNIQUE si se comparan con su definicion completa.
SELECT '== constraints (PK/FK/UNIQUE con definicion; CHECK solo nombre y validacion)';
SELECT conrelid::regclass::text || ' | ' || conname || ' | ' || contype::text || ' | validada=' || convalidated::text
       || CASE WHEN contype = 'c' THEN '' ELSE ' | ' || pg_get_constraintdef(oid) END
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace
ORDER BY 1;

SELECT '== indices';
SELECT indexdef FROM pg_indexes WHERE schemaname = 'public' ORDER BY indexdef;
