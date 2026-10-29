# CU-036: preparación de integración sandbox — #238

Fecha: 2026-10-29. Base: main `2d03aca`. Relacionados: #215 y #216.
**PROPUESTA DE IA — PENDIENTE DE VALIDACIÓN.** No autoriza modelos, contrato HTTP,
migraciones, despliegues ni operaciones externas. CU-036 permanece **PARCIAL**;
webhook HTTP inactivo, sin integración real certificada. Se conserva la decisión
de Martiniano de no aprobar cambios de modelo/contrato antes de PC2; esta tarea
prepara una alternativa, no revoca aquella decisión ni acredita su aprobación.

## Fuentes y alcance confirmado

- CU-036 v1.3, RF-012: integración académica de pruebas, operación asociada a CU-014,
  validación del resultado y confirmación automática únicamente ante acreditación válida.
  [Especificación](https://drive.google.com/file/d/1Kc4m4e2LH5xRc1J9HY-2hTQaiLNeRA7y/view).
- RN-015 vigente: proveedor integrado que informa válidamente aprobación/acreditación
  permite confirmar sin segunda decisión humana; los demás mecanismos conservan CU-016.
  [Reglas vigentes](https://docs.google.com/document/d/1aG6RTv1lTyY36PkyYyYl46NW4PKYvYMb/edit).
- [#215](https://github.com/Martiherenu1/ProyectoVanFull/issues/215),
  `INTEGRACION-MERCADOPAGO-PC2.md`, CLAUDE.md y CONTRIBUTING.md.

## Estado contrastado y preparación independiente

`Pago` carece de identificador externo persistente. POST /pagos registra PENDIENTE;
no crea operación remota ni vínculo. El adaptador existente hace GET Payments con
timeout y rechaza live_mode distinto de false. HMAC exige secreto y ventana inyectados.
El servicio interno recibe un resolver simulado; comprueba operación, receptor,
moneda e importe y reutiliza CU-016 bajo lock del pago. CU-016 genera recibo y
movimiento acreedor; sus restricciones únicas y pruebas existentes cubren duplicados,
concurrencia y rollback. Nada de esto demuestra todavía asociación durable ni
recepción HTTP real. No se duplican esos servicios ni sus pruebas.

OpenAPI contiene una descripción preliminar del webhook, sin contrato completo de
firma, parámetros, ACK o errores; no hay router conectado. Settings solo incluye
token MP vacío por defecto. La configuración versionada render.yaml no declara
secreto webhook ni política temporal, y arranca mediante un script con migraciones:
no se ejecuta ni modifica. No se consultaron servicios Render ni secretos.

Se agregan tres pruebas sin DB: fallo timeout/429/500 seguido de consulta explícita
exitosa usando el mismo adaptador. Verifican recuperación, ausencia de reintento
oculto y solicitudes exclusivamente GET. Son simulación, no integración certificada;
no cubren entrega/reintento del webhook ni persistencia. El código desacoplado de
#216 ya existe y se reutiliza sin modificarlo.

## Asociación mínima propuesta, aún no aprobada

Preferir una entidad de vínculo separada con FK al pago local y clave externa única
por proveedor, entorno e identificador de operación. Acordar si la relación será 1:1
y, solo entonces, imponer también unicidad del pago local. Martiniano debe validar
modelo, cardinalidad y origen del vínculo; avisar a Martín por el DER.

Para sandbox, proponer una asociación explícita y controlada entre un pago local
MERCADO_PAGO y una operación de pruebas previamente identificada: consultar Payments
y comprobar entorno, receptor, moneda e importe antes de persistir el vínculo.
El procedimiento autorizado de alta del vínculo también queda por definir; no se
ofrece un endpoint nuevo ni se empareja por importe, cliente o coincidencia de IDs.
No se presupone external_reference=id_pago. Si se decide iniciar operaciones desde
VanFull, definir aparte correlación opaca generada por servidor y su persistencia;
esa alternativa no está implementada ni aprobada.

## Circuito mínimo propuesto tras aprobación

1. Recibir POST /webhooks/mercadopago, validar firma y consistencia de identificadores;
   resolver exclusivamente el vínculo persistente previamente establecido.
2. Consultar Payments con el adaptador existente; nunca aceptar el estado del cuerpo
   como verdad ni seguir URLs de la notificación. Conservar validación sandbox.
3. Para approved válido, delegar en el servicio interno y CU-016 bajo lock: una sola
   confirmación/recibo/crédito; duplicados devuelven resultado sin nuevo asiento.
   Otros estados no generan nuevas transiciones contables. No agregar reintegros.
4. Acordar ACK y presupuesto temporal: no confirmar recepción como procesada antes
   del commit o de aceptación durable. Si se necesita ACK temprano, hace falta inbox
   persistente y worker; no basta una tarea en memoria. La elección síncrono/inbox,
   códigos HTTP, tolerancia HMAC y política de reintentos necesitan contrato aprobado.
5. Registrar categoría técnica e identificador de correlación mínimo, sin token,
   firma, datos del pagador ni payload completo. El log actual no sustituye historial
   durable de incidentes. Acordar almacenamiento y procedimiento de reproceso seguro;
   un fallo transitorio no debe convertir el pago en rechazado ni simular éxito.

La guía oficial recomienda validar, deduplicar y consultar el recurso para procesar
idempotentemente, considerando entregas repetidas o desordenadas:
[SDK Mercado Pago: webhooks](https://github.com/mercadopago/sdk-nodejs/blob/master/docs/webhooks.md).
Esto orienta la propuesta técnica; no define el contrato compartido de VanFull.

## Archivos futuros sujetos a autorización

- Modelo de vínculo, migración y schema.sql juntos; resolver SQL en servicio MP.
- Router webhook, registro en app/main.py y OpenAPI YAML/JSON sincronizados.
- Settings y ejemplo sin secretos para secreto HMAC, ventana, receptor/moneda y
  habilitación explícita de sandbox; valores y custodia pendientes.
- Pruebas PostgreSQL de unicidad del vínculo, HTTP→Payments→CU-016, duplicados,
  concurrencia, rollback y reproceso durable, reutilizando las existentes.
- No modificar CU-014/CU-016, importes, estados ni módulos ajenos para suplir decisiones.

## Estrategia sandbox y puerta de autorización

Ahora: solo MockTransport y pruebas sin conexión; no se crean pagos ni infraestructura.
Después: equipo proporciona aplicación/credenciales de prueba y secreto fuera del
repositorio, receptor/moneda y operación/escenario aprobados. Usar exclusivamente DB
local aislada y acceso HTTPS de pruebas expresamente autorizado, sin Neon/Render.
No aplicar siquiera migraciones locales hasta levantar la restricción actual.
Validar credenciales/entorno de prueba antes de cualquier operación; acordar quién
genera la operación simulada, sin cobros reales ni credenciales productivas.

Prueba real futura: operación aprobada, notificación válida, duplicado, entrega
concurrente y fallo/reintento; cotejar un solo recibo/crédito y resultado persistido,
con evidencia sanitizada. La autorización de preparación no habilita esta ejecución.
Sin modelo, contrato, configuración y escenario aprobados no hay prueba punta a punta.

## Próximos pasos

Validación local: `pytest -q tests/test_mercadopago_validacion.py
tests/test_mercadopago_reintentos.py`: **29 aprobadas**; Ruff y formato del archivo
nuevo correctos. HTTP íntegramente simulado; DATABASE_URL sobrescrita con dirección
local sin servicio. No se ejecutaron pruebas PostgreSQL ni migraciones, ni se repitió
la cobertura contable existente. No se realizó prueba sandbox externa.

Validar propuesta con Martiniano (modelo/HTTP/configuración) y Martín si afecta DER o
línea base. Recién después implementar vínculo/router, preparar pruebas de DB aislada
y solicitar autorización del escenario sandbox. Esta rama se detiene antes de commit,
push o PR; no altera contratos ni configura despliegues.
