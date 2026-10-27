# Contexto vivo · Administración y Flutter (Facundo)

## Corte de estado

Última verificación: **2026-10-27**.

- `main`: `db62e5e017ad5061ff37ad60cafdedf2151dfaa0`.
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

- Login con una cuenta administrativa de rol único.
- Acceso al módulo administrativo y al formulario Crear viaje.
- El 2026-10-27 se envió una única creación para 2026-10-31 09:15, servicio 1, recorrido 1, sentido IDA,
  capacidad planificada 18, sin chofer ni vehículo. La interfaz mostró éxito.

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
- En navegador real se comprobaron login administrativo, entrada al módulo, apertura del formulario y respuesta
  visual exitosa de una creación.
- No se verificaron todavía en el entorno publicado: persistencia del viaje, listado autenticado con ese viaje,
  pagos, confirmación/rechazo, reservas administrativas, deuda administrativa ni Mercado Pago.
- El selector de fecha para el listado es una propuesta de mejora, no un requisito confirmado; no se incorpora
  durante el freeze por inferencia.
- Antes de la entrega corresponde coordinar un despliegue final desde el `main` definitivo, sin interferir con
  los cambios compartidos de Martín y Martiniano.

## Decisiones vigentes

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
2. Probar en Render el listado administrativo y logout sin efectuar nuevas escrituras.
3. Validar con el equipo el recorte de CU-018, CU-027, CU-014, CU-015 y CU-036.
4. Mantener abierto #84 hasta resolver o aceptar formalmente los límites de CU-014.
5. Coordinar el despliegue final solo cuando el `main` compartido quede estable.

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
