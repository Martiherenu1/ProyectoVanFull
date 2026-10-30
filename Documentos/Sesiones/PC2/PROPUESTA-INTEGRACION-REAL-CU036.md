# CU-036: preparación de integración sandbox — #238

> **Implementación candidata posterior en esta rama aislada:** autorización del usuario
> para preparar modelo/migración/contrato y pruebas locales, sin aprobar D1–D6 ni integrar
> a main. Ver [ensayo y matriz vigentes](ENSAYO-CU036-AISLADO.md). Los límites de solo
> documentación que siguen describen la fase anterior. Webhook desactivado por defecto;
> live_mode=true rechazado, sin excepción ni despliegue. Se requiere aprobación escrita
> de los tres antes de integrar cambios compartidos; no se realizó commit/push nuevo.
> Revisión precommit: #240 ya mergeado (propuesta), #238 cerrado; implementación
> actual para PR nuevo vinculado a #215. Base 440c578; migración optativa mp_0001
> separada del head habitual para impedir su aplicación automática en Render.
> Ese ajuste D6 permanece candidato y no reescribe las decisiones históricas siguientes.
> Ampliación Checkout Pro posterior: intención UUID, preferencia, contrato y Flutter
> preparados localmente sin activación. D1–D6 continúan PENDIENTES DE APROBACIÓN;
> también requieren decisión los endpoints, asociación opaca y cambios del área pasajero.
> Ver [candidato y decisiones adicionales](CHECKOUT-PRO-CU014-CU036-CANDIDATO.md).

Fecha: 2026-10-29. Base: main `2d03aca`. Relacionados: #215 y #216.
**PROPUESTA DE IA — PENDIENTE DE VALIDACIÓN.** No autoriza modelos, contrato HTTP,
migraciones, despliegues ni operaciones externas. CU-036 permanece **PARCIAL**;
webhook HTTP inactivo, sin integración real certificada. Se conserva la decisión
de Martiniano de no aprobar cambios de modelo/contrato antes de PC2 como antecedente.
Actualización comunicada por el usuario: autoriza avanzar en rama aislada, pero exige
aprobación escrita de Martiniano, Martín y Facundo antes de integrar modelo/contrato
a main. Plazo comunicado: **30/10/2026, 10:00, Argentina**. No se presume ninguna de
esas tres aprobaciones. El alcance de esta edición sigue siendo solo documental.

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
push o PR adicionales; no altera contratos ni configura despliegues. La preparación
anterior ya fue publicada en Draft PR #240; la edición siguiente queda local.

## Decisiones concretas para votar — revisión de #240

Cada D requiere respuesta escrita «apruebo» o «rechazo + alternativa» de los tres
en #238/#240, referida a esta revisión. Ninguna D está aprobada por este documento.
La condición de unanimidad comunicada por el usuario prevalece sobre el flujo
general de CONTRIBUTING.md. Sin unanimidad al plazo, conservar CU-036 PARCIAL,
webhook inactivo y preparación en Draft; no habilitar integración por vencimiento.
Estas decisiones concretan las alternativas anteriores, que se conservan como historia.

### D1 — una tabla exclusiva de vínculo sandbox, relación 1:1

Nombre propuesto: `pago_mercadopago`, sin añadir columnas ni estados a `pago`.

| Campo | Tipo / restricción propuesta |
|---|---|
| `id_operacion` | VARCHAR(64), PK, CHECK solo dígitos, longitud 1..64 |
| `id_pago` | BIGINT NOT NULL UNIQUE, FK pago.id_pago ON DELETE RESTRICT |
| `id_receptor` | BIGINT NOT NULL CHECK > 0 |
| `moneda` | VARCHAR(3) NOT NULL CHECK tres letras mayúsculas |
| `creado_en` | TIMESTAMPTZ NOT NULL DEFAULT now() |

Proveedor y entorno son invariantes de esta tabla: exclusivamente Mercado Pago y
sandbox; no se propone soporte productivo ni multientorno. Si se necesita eso,
reabrir clave compuesta proveedor/entorno/id_operacion antes de implementar.
Un Pago tiene 0..1 vínculo; cada vínculo tiene exactamente un Pago y cada operación
solo uno. El vínculo es inmutable, sin endpoint de edición/borrado. La FK y UNIQUE
garantizan identidad/cardinalidad; servicio valida MERCADO_PAGO, PENDIENTE, importe,
receptor autorizado, moneda configurada y live_mode=false bajo lock del Pago.
No duplicar saldo/importe ni introducir una nueva regla económica.

### D2 — asociación explícita mediante comando local, no por webhook

Proponer comando restringido a entorno local de pruebas, con `id_pago` e
`id_operacion` explícitos, ambos identificados por el responsable del escenario.
Consultar Payments antes de insertar D1, comprobar D1 y mostrar confirmación sin
datos sensibles. Insertar en transacción con lock del Pago; repetir el mismo vínculo
es idempotente, otro vínculo para cualquiera de las dos identidades es conflicto.
No alterar el estado del Pago al vincular. No usar external_reference, coincidencia
de importe ni ID local como correlación implícita. No agregar endpoint de asociación.
La primera notificación puede llegar antes del alta: responder conflicto sin ACK de
éxito; tras alta, reenviar desde panel del proveedor o ejecutar reproceso controlado.
Esto es una preparación manual sandbox, no un circuito de cobro productivo CU-014.

### D3 — webhook síncrono mínimo y contrato explícito

Única ruta propuesta: `POST /api/webhooks/mercadopago` (OpenAPI relativo
`/webhooks/mercadopago` bajo servidor /api), sin JWT; autenticación exclusiva HMAC.
Headers obligatorios x-signature (`ts`, `v1`) y x-request-id; query obligatoria
`data.id`; JSON con type=payment, live_mode=false, data.id coincidente. Aceptar
metadatos adicionales sin usarlos para decisiones ni persistir datos del pagador.
HMAC-SHA256 sobre `id:{data.id};request-id:{x-request-id};ts:{ts};`, comparación
constante; proponer ventana de 300 segundos, reloj UTC sincronizado y límites
actuales de identificador. Es política propuesta, no una exigencia de RN-015.

| Respuesta propuesta | Condición / efecto |
|---|---|
| 200, cuerpo vacío | Confirmación comprometida, duplicado comprobado o estado no approved consultado válidamente; sin nueva transición para este último |
| 400 WEBHOOK_INVALIDO | JSON, IDs, tópico o entorno incompatibles; no confirmar |
| 401 FIRMA_WEBHOOK_INVALIDA | Firma ausente/inválida/fuera de ventana; no consultar Payments |
| 409 VINCULO_PAGO_INVALIDO | Sin vínculo o incompatibilidad de importe/moneda/receptor/estado local; no confirmar |
| 503 PROVEEDOR_NO_DISPONIBLE | Timeout, error/red, 429/5xx o respuesta Payments inválida; no confirmar |
| 503 INTEGRACION_NO_DISPONIBLE | Configuración incompleta, timeout de lock o DB indisponible; rollback |
| 500 ERROR_INTERNO | Fallo no previsto; rollback, mensaje sanitizado |

Los códigos son **propuestos**, no agregados al contrato actual. Errores con el
esquema uniforme existente. Token rechazado por proveedor se trata como incidente
de configuración y no se oculta como éxito; requiere intervención, no bucle interno.
Si está deshabilitado, no registrar router (404); no simular ACK.

GET Payments con máximo 10 s y un intento por entrega; presupuesto total propuesto
15 s, incluyendo lock/DB, con timeout de lock 2 s. Cancelar y rollback si vence antes
de commit; jamás responder 200 antes de commit. Una respuesta perdida después de
commit se recupera mediante duplicado idempotente. No incorporar worker/inbox en
este mínimo. Si las mediciones no cumplen el presupuesto, bloquear activación y
proponer inbox durable mediante nueva decisión de modelo, nunca background en memoria.

Solo status=approved del recurso real consultado habilita CU-016. Conservar las
validaciones y locks existentes, RECIBO/ACREEDOR/evento de CU-016 y sus UNIQUE.
No interpretar otro estado como aprobado, rechazo contable o reintegro.

### D4 — reintentos y registro mínimo sin tabla de eventos adicional

Registrar únicamente categoría, request-id acotado y validado, ID de operación y
resultado técnico; sin firmas, tokens, headers completos, cuerpos ni PII. Desactivar
logs HTTP detallados y proteger acceso/retención del log del entorno de prueba.
No crear historia durable en esta etapa: declarar expresamente esa limitación.
Ante error no emitir 200; permitir reentrega del proveedor. No suponer que solo
reintenta 503 ni fijar su calendario desde VanFull. Para firma de reentrega demasiado
antigua, no ampliar ventana automáticamente: reenviar una notificación nueva desde
panel o reprocesar por comando local autenticado por acceso al entorno, que consulta
Payments y reutiliza el servicio de liquidación con vínculo/lock sin falsificar HMAC.
Ese comando es administrativo local de sandbox, no un bypass HTTP público.
Sin confirmación de nuevo evento cuando cambie el estado, el responsable debe
reconciliar explícitamente operaciones no acreditadas. No hay garantía de recuperación
desatendida tras agotar entregas: si se exige, rechazar este mínimo y aprobar inbox.

Fuente técnica consultada: Mercado Pago documenta ACK 200/201 dentro de 22 s y
reentregas cuando no se recibe ACK; distingue notificación de consulta del recurso.
[Webhooks oficiales](https://www.mercadopago.com.pe/developers/es/docs/links-and-debts/additional-content/your-integrations/notifications/webhooks).
Los presupuestos, códigos y operación local anteriores son propuestas VanFull.

### D5 — escenario sandbox acotado, con autorización de ejecución separada

Responsable designado por el equipo aporta token de prueba de la aplicación,
secreto webhook, receptor, moneda e ID de operación de prueba, fuera del repo y
sin pegarlos en Issue/PR/log. No usar token productivo; prefijo del token no es
prueba suficiente: verificar cuenta/aplicación y live_mode=false del recurso.
Si no existe operación de prueba, acordar su generación mediante herramientas
oficiales y tarjetas/usuarios de prueba, exclusivamente en modo test. El simulador
de notificaciones por sí solo no certifica un pago consultable en Payments.

Proponer: backend y PostgreSQL local aislados, futuro esquema aprobado y HTTPS
temporal autorizado hacia ese backend; sin Neon/Render. Usar CU-014 para crear Pago
PENDIENTE del cliente de prueba por importe explícitamente acordado con la operación,
sin elegir un monto ni una moneda por inferencia; asociar con D2. Activar router solo
para ese entorno después de aprobación separada; registrar URL de pruebas en panel.
Probar evento aprobado real de sandbox, duplicados/concurrencia, fallo transitorio y
reproceso. Antes/después: Pago CONFIRMADO, exactamente un RECIBO y un ACREEDOR y sin
asientos adicionales tras repetición. Incluir negativo de firma, receptor/importe,
operación desconocida y live_mode=true exclusivamente simulado; nunca consultar un
pago real para ese negativo. Guardar evidencia sanitizada y cerrar acceso temporal.
Sin credenciales/operación/URL autorizadas, ejecutar mocks y declarar prueba real bloqueada.

### D6 — lista exacta de cambios futuros, sin ejecutarlos ahora

- Una nueva revisión Alembic hija del head vigente al implementar, creando solo
  `pago_mercadopago` y restricciones D1; downgrade elimina esa tabla, sin CASCADE.
  No editar 0001. Actualizar juntos schema.sql, modelo específico e import de modelos.
- Resolver SQL y comandos locales `vincular` / `reprocesar` en módulo sandbox dedicado;
  extraer de ser necesario la liquidación común sin alterar CU-016 ni saltar HMAC HTTP.
- Router/schema webhook y registro condicional en app/main.py; una sola operación
  HTTP nueva/activada, sin endpoint de creación de cobro, vínculo ni nuevos permisos.
- OpenAPI YAML/JSON y README coherentes con D3 y x-cobertura parcial vigente.
- Settings/.env.example: MERCADOPAGO_SANDBOX_ENABLED=false,
  MERCADOPAGO_WEBHOOK_SECRET vacío, MERCADOPAGO_WEBHOOK_TOLERANCE_SECONDS=300,
  MERCADOPAGO_COLLECTOR_ID y MERCADOPAGO_CURRENCY obligatorios al habilitar;
  reutilizar MERCADOPAGO_ACCESS_TOKEN. Exigir entorno local/test; error de arranque
  si se intenta habilitar con ENV=production. Timeouts D3 constantes documentadas.
- Sin cambios de render.yaml, despliegues ni secretos versionados. La URL pública
  temporal y configuración del panel son acciones externas separadas, no de este diff.
- Pruebas futuras: restricciones y carreras de asociación, contrato HTTP, atomicidad,
  presupuesto/rollback, sesión de DB tras error, reentrega con firma nueva y reproceso.

## Trabajo independiente y bloqueo de integración

Independiente: propuesta, matriz de casos y pruebas existentes con MockTransport;
se pueden preparar fakes de vínculo y reloj sin modificar contrato/modelos.
Dependiente de aprobación: D1–D6 y pruebas que fijan su comportamiento, migración,
resolver persistente, router/contrato/configuración y conexión externa. La autorización
de rama aislada no autoriza en esta tarea esos cambios, migraciones o activación.
Solo se edita este documento; sin commit/push. No se repiten pruebas de código ante
una edición documental. Validación: diff check y coherencia entre D1–D6.
