# Contexto vivo · Administración y Flutter (Facundo)

## Corte de estado

Última verificación: **2026-10-27**.

- `main`: `63da29ee1153256366b5380f0d953a55df97728e`.
- CI de `main`: verde; **438 pruebas backend** y **548 pruebas Flutter** aprobadas.
- PR abiertos de Facundo: ninguno.
- Issue abierto de Facundo: **#84**, porque CU-014 continúa parcial.
- Frontend administrativo publicado en Render y GitHub Pages: build `d19c22ae70887eb98a4ac905bbebec107d4ac68b`.
  Contiene la composición administrativa integrada; no coincide con el HEAD actual de `main`, que avanzó después
  por cambios de Chofer y documentación.

La línea funcional vigente es la especificación de Casos de Uso v1.3. Según ella:

- CU-014: Registrar pagos y comprobantes.
- CU-015: Gestionar deuda.
- CU-016: Confirmar o rechazar pago.
- CU-018: Gestionar viajes y asignaciones.
- CU-027: Consultar reservas por administración.
- CU-036: Procesar operación mediante Mercado Pago en pruebas (`<<extend>>` de CU-014).

## Estado por responsabilidad

### CU-018 · Gestionar viajes y asignaciones — PARCIAL

**Implementado**

- Backend: `POST /viajes` (#50), `GET /viajes?fecha=YYYY-MM-DD` (#145) y actualización segura de
  viajes programados mediante `PATCH /viajes/{id_viaje}` (#178).
- Flutter: pantalla Viajes del día (#99), adaptador de consulta (#150), adaptador de creación (#130), formulario
  de creación (#134), navegación y composición autenticada (#159).
- Dataset sintético de demostración para 2026-10-30 (#101).
- ADJ-03: se permite planificar sin chofer y/o vehículo; ambos son necesarios antes de iniciar el viaje.

**Probado automáticamente**

- Backend: permisos, validación de fecha, lista vacía, estados, orden, asignaciones nulas, creación y
  actualización programada con protección de capacidad y concurrencia con CU-030.
- Flutter: carga, vacío, error/reintento, selección, serialización, formulario, navegación, sesión y 401/403.

**Probado realmente en Render**

- Prueba manual realizada por Facundo el 2026-10-27 en `https://vanfull.onrender.com`:
  - inicio de sesión administrativo: APROBADO;
  - acceso a «Viajes del día»: APROBADO;
  - carga del listado sin errores, incluso con resultado vacío: APROBADO;
  - navegación a «Crear viaje» y regreso sin enviar datos: APROBADO;
  - logout con regreso al login: APROBADO;
  - recarga posterior sin exponer contenido protegido: APROBADO.
- En una comprobación separada se envió una única creación para 2026-10-31 09:15, servicio 1, recorrido 1,
  sentido IDA, capacidad planificada 18, sin chofer ni vehículo. La interfaz mostró un mensaje de éxito, pero
  ese resultado visual no demuestra por sí solo la persistencia.

**Pendiente**

- La persistencia de esa creación en Neon está **NO VERIFICADA**: no hubo una conexión autorizada de solo lectura
  disponible. Tampoco quedó confirmada mediante un GET autenticado.
- No están implementadas la cancelación ni la modificación de servicio/recorrido. Estos dos últimos campos se
  excluyen del update porque no está definido cómo migrar contrataciones, paradas y reservas vinculadas.
- El contrato marca GET, POST y PATCH como cobertura parcial de CU-018.
- Las reglas detalladas de conflictos o solapamientos de asignaciones siguen PENDIENTES DE VALIDACIÓN.
- OpenAPI `Viaje` no declara propiedades obligatorias, mientras el backend y `ViajeResumen` esperan los campos
  públicos base. El adaptador rechaza respuestas incompletas y no inventa valores.

### CU-027 · Consultar reservas por administración — NO IMPLEMENTADO

No hay endpoint, servicio, pantalla administrativa ni pruebas específicas. El contrato y el alcance de la
interfaz continúan pendientes. No debe confundirse con las reservas propias del pasajero.

### CU-014 · Registrar pagos y comprobantes — PARCIAL

**Avance local #213, 29/10/2026:** rama `feat/admin-registrar-pago-cu014-213` desde main
`a8696de`, sin cambios de #210/CU-015/CU-027. Los trabajos locales #212 y #211 se preservaron
en stashes separados con sus nombres de rama; no aplicarlos sobre esta rama.

Leídos CU-014 v1.3 aprobado, RN-011/013/014/015/016 y contrato/servicio POST /pagos.
Formulario administrativo integrado al endpoint existente: ID cliente destinatario con cuenta
existente, importe recibido, transferencia o billetera. Confirma destinatario/importe antes
de enviar y muestra el estado real devuelto; no confirma pagos ni genera recibos/movimientos.
Reutiliza HTTP/sesión, Pago, MedioPago y formato de importes; main.dart solo conecta el registro.
Muestra errores de cliente/cuenta/permiso/validación; evita doble envío y efectos de sesión vieja.

Preparación aislada: BorradorImputacionPago y formulario local para tipo/referencia de respaldo,
sin serialización, persistencia, subida de archivos ni conexión al registro real. El adaptador
rechaza borradores con datos antes de HTTP: no los descarta silenciosamente. No determina tipo,
seña mínima o condiciones empresariales; estos campos son candidatos a integración, no decisiones.

**Para integrar lo restante (#84):** acordar almacenamiento y validación de tipo/evidencia con
Martiniano/Martín; definir tarifa aplicable e imputación del 15 % antes de habilitar efectivo;
vinculación con contratación/acuerdos y validación backend de seña general 50 %/excepciones
empresariales; definir semántica CUENTA_CORRIENTE y conectar CU-036 para Mercado Pago cuando
corresponda. Cliente sin cuenta conserva 404: no hay alta automática. No cambiar permisos.
La UI identifica este registro como parcial y no habilita efectivo, señas/acuerdos especiales
ni adjuntos. Sin cambios backend/OpenAPI/BD ni módulos Pasajero/Chofer/GPS. CU-014 sigue parcial.

Validación local: 26 pruebas Flutter focalizadas aprobadas (adaptador, formulario/borrador,
sesión y composición existente), flutter analyze sin problemas y diff check correcto.
No se registraron pagos reales; sin commit/push/PR.

Fuente CU: https://drive.google.com/file/d/1Kc4m4e2LH5xRc1J9HY-2hTQaiLNeRA7y/view

**Implementado**

- `POST /pagos`, integrado por #85 y ampliado por #141.
- Administrador/dueño registran indicando cliente; el pasajero solo registra un pago propio.
- El pago queda `PENDIENTE`, se valida cliente/cuenta y se registra `pago_registrado` atómicamente.
- Registrar no crea comprobante ni `MovimientoCuenta`; esos efectos pertenecen a la confirmación de CU-016.

**Probado automáticamente**

- Creación, roles, pasajero propio, cliente ajeno, cliente/cuenta inexistentes, validaciones, atomicidad e
  interacción con CU-016.

**Probado realmente en Render**

- No probado con operaciones reales de pago.

**Pendiente / bloqueado**

- `tipo` y `evidencia_pago` existen en OpenAPI, pero no tienen columnas aprobadas. Actualmente se rechazan con
  `400 VALIDACION`; no deben ignorarse ni persistirse inventando un modelo.
- No está acordada la imputación contable del descuento del 15 % para efectivo.
- Los clientes/pasajeros nuevos no reciben automáticamente una `cuenta_corriente`; sin ella se responde 404.
- Issue #84 permanece abierto. OpenAPI documenta estas limitaciones, pero la operación no está marcada con
  `x-cobertura: parcial`, a diferencia de la convención vigente.

### CU-015 · Gestionar deuda — NO IMPLEMENTADO

No existen operaciones administrativas aprobadas en OpenAPI ni una pantalla de administración. La consulta
`GET /pasajeros/me/deuda` implementada en #54 es **CU-006**, para el pasajero autenticado, y no completa CU-015.
Gestionar deuda no autoriza a modificar manualmente un saldo derivado. Las acciones administrativas exactas
requieren contrato y validación del equipo.

### CU-016 · Confirmar o rechazar pago — IMPLEMENTADO EN BACKEND

**Implementado y probado automáticamente**

- `POST /pagos/{id_pago}/confirmacion` (#52), para administrador/dueño.
- Confirmar un pago pendiente crea atómicamente el `RECIBO`, el evento y exactamente un `MovimientoCuenta`
  `ACREEDOR` por el importe del pago.
- Rechazar no crea recibo ni movimiento. Un pago ya decidido no se vuelve a procesar.
- Hay pruebas de permisos, estados, confirmación, rechazo y rollback.

**Pendiente**

- No existe pantalla administrativa de pagos pendientes/confirmación.
- No fue probado realmente en Render.
- El descuento del 15 % en efectivo no está resuelto por esta implementación.

### CU-036 · Mercado Pago en pruebas — NO IMPLEMENTADO

OpenAPI declara `POST /webhooks/mercadopago`, pero la aplicación no tiene router, servicio ni pruebas que lo
implementen. Siguen pendientes la validación de notificaciones, seguridad, idempotencia, credenciales de prueba
y confirmación automática de operaciones aprobadas/acreditadas. CU-036 no equivale a movimientos o estado de
cuenta: es la integración de Mercado Pago que extiende CU-014.

## Flutter compartido — INTEGRADO Y PROBADO

- Base Flutter (#45), tema visual (#47), navegación por roles (#79), CI Flutter (#83), `ApiClient` HTTP
  inyectable (#87), composición de sesión (#159) y estabilización de callbacks (#161) están en `main`.
- Se reutiliza un único `HttpApiClient`; 401 invalida solo la sesión correspondiente, 403 conserva la sesión y
  retira contenido protegido, y las respuestas tardías no contaminan una sesión nueva.
- Pasajero conserva su entrada; administrador abre Viajes del día y Crear viaje; Chofer recibe su `ChoferShell`.
- Roles múltiples, desconocidos y `dueno` permanecen bloqueados por decisión del equipo.
- La suite Flutter completa está verde. La integración productiva de inicio/finalización/GPS pertenece a Martín.

## Frontend administrativo y despliegue — PARCIALMENTE VALIDADO

- Render y GitHub Pages sirven el frontend que contiene administración.
- La evidencia manual de Render está separada de las pruebas automatizadas: cubre login, entrada a Viajes del
  día, carga correcta de una lista incluso vacía, navegación al formulario y regreso, logout y protección tras
  recargar. También hubo un resultado visual exitoso al crear un viaje, sin verificación de persistencia.
- No se probaron desde Flutter consultas de otras fechas, ni se confirmó la creación mediante GET autenticado o
  SELECT en Neon. Tampoco se probaron un CRUD completo, pagos, confirmación/rechazo, reservas administrativas,
  deuda administrativa ni Mercado Pago.
- El selector de fecha para el listado es una propuesta de mejora, no un requisito confirmado; no se incorpora
  durante el freeze por inferencia.
- Antes de la entrega corresponde coordinar un despliegue final desde el `main` definitivo, sin interferir con
  los cambios compartidos de Martín y Martiniano.

## Decisiones vigentes

- **Preparación local #209, CU-016 (29/10/2026):** main `a8696de`, rama
  `feat/admin-pagos-pendientes-cu016-209`. Pantalla de pagos pendientes, confirmación/rechazo,
  errores, recarga y protección frente a doble envío/sesión anterior. Reutiliza POST de decisión
  sin cambiar efectos contables; propone GET `/pagos/pendientes` solo administrador/dueño,
  filtro PENDIENTE y orden de presentación fecha/id. No es una regla económica nueva.
  Sin cambios Pasajero/Chofer/GPS ni modelos de BD. Fuente consultada: CU-016/RN-015 del MVC
  aprobado y contrato vigente; especificación detallada v1.3 no localizada mediante el conector
  Drive: contraste documental pendiente antes de declarar cobertura integral.
  44 pruebas backend/contrato y 15 específicas Flutter de pagos aprobadas; otras 9 pruebas de
  composición/sesión existentes aprobadas. Sin commit/push/PR; nueva operación de contrato
  pendiente de revisión al publicar, según CONTRIBUTING §1.9.

- **Preparación local #215/CU-036 (29/10/2026):** rama `feat/admin-mercadopago-cu036-215`
  desde main a8696de, sin #210/#214 ni stashes CU-015/CU-027. Adaptador GET Payments/HMAC
  y servicio interno de validación/confirmación reutilizando pagos; 82 pruebas focalizadas
  aprobadas (HTTP/vínculo falsos, PostgreSQL temporal real), Ruff/formato correctos.
  No hay webhook HTTP activo ni integración real certificada. Bloqueados vínculo único
  persistente, moneda/receptor/escenario, credenciales y contrato de notificaciones/errores.
  Ver `INTEGRACION-MERCADOPAGO-PC2.md`; no se inventan estados contables ni se hacen cobros.

- **Preparación local #207 (29/10/2026):** interfaz Flutter de cancelación CU-018 desde main
  `4d5c4ff` (#186/#189/#192 integrados). Botón en programado, confirmación, errores backend,
  actualización detalle/listado, protección contra doble envío y respuestas tras cierre/cambio
  de sesión. main.dart solo inyecta el callback administrativo con control de generación/token.
  Sin cambios backend/OpenAPI/BD ni ampliación de RN-019. 30 pruebas focalizadas aprobadas y
  flutter analyze sin problemas; dependencias restauradas con lockfile exigido, sin cambiarlo.
  Rama `feat/admin-cancelar-viaje-flutter-cu018-207`, sin commit/push/PR; pendiente autorización.

- **Propuesta local #180 (28/10/2026):** Facundo indica recorte acordado con Martiniano y autoriza
  preparar backend/OpenAPI y pruebas locales; confirmación final de Martín pendiente. Cancelación
  lógica solo de viajes programados no ESPECIAL/CORPORATIVO y sin reservas provisional/consolidada,
  vínculos periodo_abono_viaje ni lista de espera en_espera. `VIAJE_CON_COMPROMISOS` es propuesto.
  RN-019 no implementada; CU-017/#75 pendiente; CU-018 mantiene cobertura parcial. No publicado.
  Verificación local: 5 pruebas contrato/rutas aprobadas; 20 casos PostgreSQL (incluidas cuatro
  carreras reservas/CU-030) omitidos porque la conexión local se cierra. Concurrencia sin acreditar.

- **DEFINIDO POR EL EQUIPO — ADJ-03:** un viaje puede planificarse sin vehículo y/o chofer, pero no iniciarse
  hasta tener ambos asignados.
- **DEFINIDO POR EL EQUIPO — pagos:** CU-014 registra el pago pendiente sin movimiento. CU-016, al confirmar,
  crea el movimiento `ACREEDOR`; el rechazo no lo crea.
- **DEFINIDO POR EL EQUIPO — MR-R30:** saldo, deuda y cupo se calculan; no se persisten como valores derivados.
- **DEFINIDO POR EL EQUIPO — sesión Flutter:** un cliente HTTP, 401 contextual, 403 sin logout y aislamiento por
  generación/token.
- **PENDIENTE DE VALIDACIÓN:** persistencia de tipo/evidencia, imputación del 15 %, alta de cuenta corriente,
  conflictos de asignación y operaciones exactas de CU-015.

## Alcance PC2 y pendientes para el 30/10

El reparto acordado para PC2 asignó a Facundo CU-018, CU-027, CU-014, CU-015, CU-016 y CU-036, además de la base
común Flutter. Que una operación esté parcial o no implementada **no significa que haya sido formalmente
excluida**. El recorte respecto de ese reparto original está **PENDIENTE DE APROBACIÓN** por el equipo.

No se encontró una exigencia docente específica que use las expresiones “CRUD completo de viajes” o “pantallas
administrativas de pagos”. Sin embargo, el reparto del equipo sí prevé asignaciones, reservas y pagos a
confirmar; no se los declara fuera del PC2 sin una decisión explícita.

Prioridades documentales y de validación antes del viernes:

1. Verificar por SELECT autorizado o GET autenticado la persistencia del viaje de prueba y registrar su ID/estado.
2. Validar con el equipo el recorte de CU-018, CU-027, CU-014, CU-015 y CU-036.
3. Mantener abierto #84 hasta resolver o aceptar formalmente los límites de CU-014.
4. Coordinar el despliegue final solo cuando el `main` compartido quede estable.

## Fuera del alcance confirmado del PC2

Según `REPARTO-PC2.md`: interfaces de dueño, clientes corporativos, reportes, facturación, abonos, recorridos y
paradas, optimización de recorridos, y alta de choferes o vehículos (CU-005, CU-013, CU-017, CU-019 a CU-026,
CU-028 y CU-031 a CU-035, CU-037). Los datos necesarios se proveen mediante el seed compartido.

## Coordinación con otras áreas

- Martín es responsable de Chofer, viaje en curso, CU-030 y GPS. No modificar simultáneamente `main.dart` ni
  sus componentes durante esa integración.
- Martiniano es responsable de autenticación, pasajero, servicios, tarifas y reservas del pasajero.
- Los cambios de contrato, modelo o reglas se coordinan según `CONTRIBUTING.md`; no se resuelven desde este
  contexto.
