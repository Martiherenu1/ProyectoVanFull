-- Verificación de MR-R28: COMPROBANTE debe tener un único origen, compatible con su tipo.
-- Se corre DESPUÉS de cargar schema.sql. Cada bloque debe dar el resultado que anuncia.

\set ON_ERROR_STOP off

-- Datos mínimos para poder insertar comprobantes
INSERT INTO cliente (naturaleza_cliente) VALUES ('INDIVIDUAL');
INSERT INTO cuenta_corriente (id_cliente) VALUES (1);
INSERT INTO pago (id_cliente, importe, medio_pago, estado)
     VALUES (1, 2900.00, 'TRANSFERENCIA', 'CONFIRMADO');
INSERT INTO servicio (tipo_servicio) VALUES ('UNIVERSITARIO');
INSERT INTO contratacion (id_cliente, id_servicio) VALUES (1, 1);
INSERT INTO movimiento_cuenta (id_cliente, naturaleza, importe)
     VALUES (1, 'ACREEDOR', 1500.00);

\echo ''
\echo '=== DEBEN ACEPTARSE (cada tipo con su origen correcto) ==='

\echo '-- RECIBO con id_pago'
INSERT INTO comprobante (tipo, id_pago) VALUES ('RECIBO', 1);

\echo '-- FACTURA con id_contratacion'
INSERT INTO comprobante (tipo, id_contratacion) VALUES ('FACTURA', 1);

\echo '-- NOTA_DE_CREDITO con id_movimiento_cuenta'
INSERT INTO comprobante (tipo, id_movimiento_cuenta) VALUES ('NOTA_DE_CREDITO', 1);

\echo ''
\echo '=== DEBEN RECHAZARSE (violan MR-R28) ==='

\echo '-- RECIBO apuntando a una contratacion (origen incompatible con el tipo)'
INSERT INTO comprobante (tipo, id_contratacion) VALUES ('RECIBO', 1);

\echo '-- FACTURA con dos origenes a la vez'
INSERT INTO comprobante (tipo, id_pago, id_contratacion) VALUES ('FACTURA', 1, 1);

\echo '-- NOTA_DE_DEBITO sin ningun origen'
INSERT INTO comprobante (tipo) VALUES ('NOTA_DE_DEBITO');

\echo ''
\echo '=== RESULTADO: tienen que haber quedado exactamente 3 comprobantes ==='
SELECT COUNT(*) AS comprobantes_guardados FROM comprobante;
SELECT id_comprobante, tipo, id_pago, id_contratacion, id_movimiento_cuenta FROM comprobante ORDER BY 1;
