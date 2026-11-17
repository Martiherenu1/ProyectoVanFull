-- Conservación de los históricos de evento_operativo alrededor de la migración 0002. SOLO LECTURA.
-- Se corre con: psql -X -A -t -q -v ON_ERROR_STOP=1 -f historicos.sql
--
-- El hash se calcula SIN las dos columnas que agrega 0002 (id_cuenta_autora y clave_solicitud), así que
-- sale igual antes y después si la migración no tocó ninguna fila. to_jsonb(t) - ARRAY[...] funciona
-- aunque las columnas todavía no existan (quitar una clave ausente no hace nada).
SET TimeZone = 'UTC';
SET default_transaction_read_only = on;

SELECT '== evento_operativo: filas | md5 de las columnas originales | filas con metadatos nuevos (0 esperado)';
SELECT count(*)
       || ' | ' || coalesce(md5(string_agg((to_jsonb(t) - ARRAY['id_cuenta_autora', 'clave_solicitud'])::text, '|'
                                          ORDER BY (to_jsonb(t) - ARRAY['id_cuenta_autora', 'clave_solicitud'])::text)), 'sin filas')
       || ' | ' || count(*) FILTER (WHERE to_jsonb(t) ->> 'id_cuenta_autora' IS NOT NULL
                                       OR to_jsonb(t) ->> 'clave_solicitud' IS NOT NULL)
FROM public.evento_operativo t;
