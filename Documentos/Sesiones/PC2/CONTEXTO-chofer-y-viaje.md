# Contexto vivo · Chofer y viaje en curso (Martín)

## Estado vigente al 19/10/2026 — CU-029 integrado y CU-030 en revisión

- **Issue #37 / PR #40:** contrato OpenAPI de las operaciones del chofer integrado a `main` y Issue cerrado.
- **Issue #64 / PR #65:** consultas CU-029 del chofer ya **mergeadas** en `main`, con CI aprobada (148 pruebas en su rama antes del merge).
- **Issue #66 / PR #67:** inicio/finalización CU-030 implementados y en revisión, **sin merge de la PR a `main`**. Integraciones de `main` y prueba de rollback publicadas en la rama de la PR, según el registro debajo. El resultado de CI debe comprobarse para el HEAD publicado antes de solicitar merge; #66 permanece abierto.
- **Issue #39 / PR #63:** aclaración de GPS/ETA aprobada funcionalmente; pendiente de evaluación técnica y sin modificación automática de OpenAPI.
- **PR #50 de Facundo:** alta administrativa de viaje integrada; asignaciones posteriores de chofer y vehículo no implementadas. ADJ-03 impide iniciar un viaje sin ambos asignados.
- **PR #45 de Facundo:** base Flutter Web/Mobile **mergeada** y presente en `frontend/`. **PR #47** de tema visual sigue **abierta**. Las pantallas específicas de chofer continúan **pendientes** y corresponden a Martín sobre la base compartida; Issue #48 navegación por roles continúa como dependencia.
- **Pendientes del área:** GPS (contrato Issue #39), pantallas del chofer, datos seed de posiciones/abordajes/nóminas, pruebas de integración y avisos de demora/problemas de CU-030 (cobertura parcial). El chofer **no escanea QR**; consulta abordajes existentes.

### Verificación local histórica, antes de commit y push — PR #67 (19/10/2026)

- En esta verificación previa: worktree aislado de `feat/chofer-ejecucion-cu030-66`, HEAD `868172bed36fc5ca93fdfdd845f03b7aa0f8ed1f`; integración de `origin/main` `cf6ea21f7ee40d59c668d2af7474964bf32fa7fd` mediante `merge --no-ff --no-commit`, entonces sin commit ni push. El registro de publicación posterior se encuentra debajo; no hubo merge de la PR a `main`.
- Único archivo con conflictos: `backend/app/main.py` (imports y registro de routers). Resolución conserva chat del PR #69, consultas CU-029, ejecución CU-030 y todos los demás routers, cada uno registrado una sola vez. Los archivos incorporados desde `main`, incluido el contexto de Pasajero, se conservan sin cambios propios.
- Prueba de atomicidad agregada para inicio desde `programado` y finalización desde `en_curso`: fallo simulado después del `flush` real del evento y antes del commit; otra conexión verifica el estado original y la ausencia de eventos. No se modificó la lógica productiva de las transiciones.
- Checks locales en Docker sobre el código del worktree montado en solo lectura: Ruff sin errores; formato correcto (72 archivos); suite completa con PostgreSQL y bases temporales: **220 aprobadas, 0 fallidas, 0 omitidas**, 185 advertencias, 419,29 s. Advertencias por deprecación de `TestClient`/`httpx` y longitud de la clave JWT de desarrollo; configuración y dependencias sin modificar. Sin migraciones ni seed sobre la base de desarrollo.
- YAML y JSON válidos y equivalentes, sin claves YAML duplicadas; contrato sin cambios (25 rutas, 27 operaciones, 28 schemas). Rutas de chat, consultas del chofer e inicio/finalización verificadas como registradas y contratadas; `git diff --check` y su variante del índice sin errores. **CI remota en esa verificación: SIN VERIFICAR**. Issue #66 continúa abierto; CU-030 sigue parcial, sin GPS, QR, ausencias ni avisos de demora/problemas en este bloque.

### Publicación posterior de la integración actualizada — PR #67 (19/10/2026)

- `main` avanzó a `2db047832b9d6254dd06e8b00566348e804b0f63` (PR #70: disponibilidad, sus pruebas y contexto de Pasajero). Se incorporó sin conflictos nuevos y sin cambios propios en esos archivos. Las 220 pruebas anteriores corresponden únicamente a la verificación histórica con `main` `cf6ea21`.
- Publicados mediante push normal a la rama existente: `8b3a0a6` (merge revisado con chat), `364ade7` (merge del avance de `main`) y `ab269a8` (dos casos de rollback). Se conserva el historial, sin rebase ni force; este registro documental es posterior a esa publicación.
- Verificación local repetida porque cambió código en `main`: Ruff sin errores, formato correcto (72 archivos), **228 aprobadas, 0 fallidas, 0 omitidas**, 185 advertencias, 164,50 s. PostgreSQL temporal; sin migraciones ni seed en desarrollo. YAML/JSON válidos y equivalentes, sin claves duplicadas; chat, CU-029 e inicio/finalización registrados y contratados. El backend publicado coincide con el probado.
- Al registrar esta actualización documental, **CI remota del HEAD final: SIN VERIFICAR**; comprobar su resultado posterior en [PR #67](https://github.com/Martiherenu1/ProyectoVanFull/pull/67). Merge a `main` y cierre de #66 no autorizados; se mantiene `Refs #66`, sin referencias de cierre automático. GPS (#39), QR, ausencias, avisos de demora/problemas y refactor CU-029 fuera del alcance propio de esta actualización.

---


## Historial de avance al 18/10/2026 — ejecución CU-030 (#66)

- **#66 / rama `feat/chofer-ejecucion-cu030-66`: en desarrollo.** Backend de las dos operaciones **existentes en OpenAPI**: `POST /viajes/{id_viaje}/inicio` y `POST /viajes/{id_viaje}/finalizacion`, trazadas a CU-030 / RF-025 / ADJ-03; sin nuevas operaciones ni cambios SQL/ORM.
- Las transiciones bloquean la fila del viaje durante el cambio para evitar eventos duplicados ante solicitudes concurrentes. El acceso exige rol `chofer` y `viaje.id_chofer == usuario.id_persona`.
- Inicio: `programado -> en_curso` solo con vehículo asignado; reintentos `en_curso` y `finalizado` responden 200 sin reinicio/evento; `cancelado` 409.
- Finalización: `en_curso -> finalizado`; reintento finalizado 200 sin duplicación; programado/cancelado 409. Cada transición real deja un evento `viaje_iniciado` o `viaje_finalizado` con el helper compartido en la misma transacción (tipos internos del servicio, **no RN nuevas**).
- **Calidad verificada — PR #67 (18/10/2026):** CI GitHub Actions aprobada, `ruff check` y `ruff format --check` correctos; suite completa contra PostgreSQL: **156 pruebas aprobadas**, 0 fallidas (113 advertencias). Pruebas de concurrencia e idempotencia incluidas. PR abierta para revisión, **sin merge**.
- Dependencia de Facundo: para iniciar, asignación previa de chofer y vehículo (ADJ-03). La implementación de reasignaciones posterior al alta sigue fuera de este bloque.
- No se incluye GPS, UI Flutter, abordajes, avisos de demora/problemas (CU-030 parcialmente cubierto) ni cambios de línea base. Issue #39 GPS continúa en revisión documental.
- **#64 / PR #65 (estado histórico del 18/10):** consulta CU-029 enviada para revisión con CI aprobada; posteriormente mergeada en `main`, según estado vigente al 19/10 descrito arriba.

---


## Historial técnico al 15/10/2026

2026-10-15: #37 tiene completo el diseño contractual de las cinco operaciones acordadas y su README.
Siete commits originales más el merge de integración; sin push, PR ni merge de nuestra rama a main.
Backend de estas operaciones y Flutter pendientes de implementación; CU-030 continúa parcial.

## Hecho

- Ninguna funcionalidad propia integrada a main ni PR del área.
- Base común del backend disponible en la base de esta rama; entorno local, migración 0001
  y seed sin reiniciar verificados durante la preparación de #37.

## En curso

- Issue: [#37](https://github.com/Martiherenu1/ProyectoVanFull/issues/37), abierto y con etiqueta chofer.
- Rama: feat/chofer-contrato-cu029-cu030-37.
- Cinco commits OpenAPI:
  - 64fdbdc: GET /choferes/me/viajes.
  - b71007b: POST /viajes/{id_viaje}/inicio.
  - af0933c: POST /viajes/{id_viaje}/finalizacion.
  - 1f5ac0c: GET /choferes/me/viajes/{id_viaje}.
  - fb3fd40: POST /viajes/{id_viaje}/ubicacion y sus schemas de entrada/resultado.
- ed7cc3f: README actualizado con indicadores, cobertura y trazabilidad.
- 71b0b75: contexto vivo original del contrato, séptimo commit propio conservado.
- Integración de origin/main (65fdd5b) mediante merge --no-ff sin conflictos:
  d350ba4d69362add065ff3f88ff11672a3ca4b06. Incorpora el PR #38 de CU-010,
  incluida la ampliación de Reserva con id_recorrido, fecha, horario y sentido.
- Tras integrar main quedaron ocho commits exclusivos respecto de origin/main.
  Con esta actualización documental, la rama contiene nueve commits exclusivos respecto de origin/main: siete originales, uno de integración y uno de actualización del contexto.
- Contrato 0.1.0: 25 rutas, 27 operaciones HTTP, 28 schemas, 18 CU representados de 37
  y 19 CU sin operaciones. YAML/JSON válidos, equivalentes y sin claves duplicadas.
- Últimos checks después del merge d350ba4: Ruff sin errores, formato correcto (55 archivos);
  pytest en Docker: 132 aprobadas, 0 fallidas, 0 omitidas, 72 advertencias conocidas (77,07 s).
  YAML y JSON válidos y equivalentes, sin claves duplicadas.
- Pendientes de cierre: push, publicación del PR, CI remota y merge de nuestra rama a main.
  CI remota SIN VERIFICAR.

## Decisiones

- 2026-10-15, Martín, revisión de #37: consultas de viajes propios con rol chofer y fecha opcional
  (por defecto fecha actual del servidor); sin asignaciones devuelve [].
  Horario NULL se omite sin modificar Viaje. Contrato: 64fdbdc y 1f5ac0c.
- 2026-10-15, Martín, revisión de #37: detalle con listas separadas de reservas
  provisionales/consolidadas e integrantes de nómina. Identificación permitida, incluido DNI;
  sin contactos privados. Fotografía nullable y abordaje solo en la lista de reservas.
  Campos explícitos; cantidades independientes, sin disponibilidad ni total único. Contrato: 1f5ac0c.
- 2026-10-15, Martín, revisión de #37: inicio/finalización con transiciones e idempotencia aprobadas;
  los reintentos también comprueban permisos. ADJ-03 exige chofer y vehículo antes del inicio;
  sus asignaciones se leen sin modificarlas. Contrato: b71007b y af0933c.
  Recurso inexistente/ajeno: 404; rol incorrecto: 403, según backend/CONVENCIONES.md.
- 2026-10-15, Marti, comunicado por Martín: GPS exclusivo del chofer asignado con viaje en_curso;
  coordenadas obligatorias con rangos geográficos y timestamp opcional con zona horaria.
  Timestamp omitido o futuro: hora actual del servidor; anterior al servidor: conservarlo.
  Actualizar solo si el timestamp efectivo es estrictamente posterior al almacenado.
  Si es igual o anterior, ignorar la nueva posición sin cambiar coordenadas ni hora.
  Conservar únicamente la última posición por viaje, sin columnas nuevas. Contrato: fb3fd40.
- 2026-10-15, Martín aprueba la respuesta solicitada por Marti: 200 con ResultadoPosicionGps;
  actualizada indica si se guardó y fecha_hora_posicion siempre informa la hora almacenada,
  también si actualizada es false. Precisión de 50 m como objetivo, sin rechazo automático.
- CU-029 tiene documentadas sus consultas; esto no implementa backend ni pantallas.
  CU-030 mantiene x-cobertura: parcial por avisos de demora y problemas.
  RN-022/RN-023 son referencias generales de CU-030; RN-030 regula consulta de ubicación.

## Pendientes

- #37: publicar la rama (push), abrir el PR con plantilla completa, comprobar la CI remota
  y realizar el merge de nuestra rama a main conforme a CONTRIBUTING.md.
- [#39](https://github.com/Martiherenu1/ProyectoVanFull/issues/39), abierto y con etiqueta chofer:
  CU-009 A1, PENDIENTE DE VALIDACIÓN del comportamiento ante un reloj del celular atrasado.
  Riesgo de diseño, no falla comprobada en una implementación. Distinguirlo de pérdida de
  conectividad y posiciones realmente antiguas. No modificar RNF-008 ni inventar tolerancias
  o correcciones; el Issue autoriza análisis y validación, no cambios funcionales.
- #37: coordinar el contrato con Martiniano y avisar a Facundo antes del merge de nuestra rama a main.
  Avisos pendientes; el agente no envió mensajes al equipo.
- RN-002/disponibilidad, seguimiento previo #28/#33: conservar la referencia del contrato
  a capacidad menos reservas consolidadas. No modificar disponibilidad desde #37.
- Demoras/problemas de CU-030: fuera del alcance de #37; crear o vincular Issue posterior.
- QR offline de CU-007: RNF-011/012 aprobados frente a postergación del prompt.
  PENDIENTE DE VALIDACIÓN; conservar línea base y crear o vincular seguimiento.
- Implementación del área, seed propio y escenario de demo: tareas posteriores, fuera de #37.

## Entorno y trampas

- Docker Desktop debe estar iniciado; checks del backend dentro de Docker.
  Versión verificada durante #37: Desktop 4.95.0.242831, motor 29.8.2.
- backend/.env es local, ignorado por Git y excluido del contexto de construcción; no publicar claves.
- Las 72 advertencias conocidas corresponden a JWT de desarrollo corto y TestClient en desuso.
- El conector GitHub permite lectura; las mutaciones intentadas fueron rechazadas con HTTP 403.
  Los Issues #37 y #39 ya tienen etiqueta chofer, verificada en GitHub.
- PowerShell puede alterar tildes al enviar scripts por stdin; usar UTF-8 y escapes Unicode.

## Para otras áreas

- Las cinco operaciones sirven como contrato de diseño para integración y mocks; no son endpoints
  implementados. No se modificaron modelos, migraciones ni el GET existente de ubicación.
- Martiniano: avisar el cambio de contrato en el PR; revisión de otro integrante opcional según CONTRIBUTING.
  Al implementar el detalle, obtener datos mediante los servicios de su área, sin duplicar sus reglas.
  Usar el helper común de eventos.
- Facundo: avisar antes del merge de nuestra rama a main por la relación entre asignaciones y ejecución del viaje.
  Leer sus asignaciones sin modificarlas; faltan sus datos seed de chofer, vehículo y viaje.
  Flutter Web/Mobile ya fue integrada en `main` por Facundo mediante PR #45; la PR #47 del tema visual continúa abierta. Las pantallas específicas del chofer siguen pendientes y corresponden a Martín sobre la base común.
- Martín: preparar seed de posiciones, abordajes, ausencias y nóminas, y la demo cruzada
  en tareas posteriores; implementar servicios, routers y pantallas del área por CU.
