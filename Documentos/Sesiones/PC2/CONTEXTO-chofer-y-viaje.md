# Contexto vivo · Chofer y viaje en curso (Martín)

## Estado al 23/10/2026 — adaptador del listado CU-029 local

- Base `origin/main 4d8213a3112bc08c9794366b5d4c1a9a7314b5f1`; #87 integrada, interfaz compartida revisada. Rama `feat/chofer-adaptador-listado-cu029`, worktree `F:/dev/vanfull-cu029-adaptador`.
- `ViajesChoferApi.cargarViajes(DateTime)` recibe ApiClient externo: base con /api/, ruta /choferes/me/viajes y fecha por year/month/day sin conversión horaria. Reutiliza ViajeResumen y conserva orden, vacío y horario omitido; propaga errores HTTP/transporte sin reintentos ni cierre del cliente.
- Estructura/DTO inválidos: ListadoViajesInvalidoException con mensaje fijo y sin datos recibidos, sin listado parcial. Sin cambios de navegación, pantallas, sesión, dependencias, lockfile, backend, README, #103 ni GPS; sin llamadas reales. Sin commits/publicaciones por instrucción del usuario.
- Checks locales: pub get offline con lockfile exigido correcto; formato final de dos archivos correcto (cero cambios); analyze sin issues (17,7 s). Suite Flutter: 148 aprobadas, 0 fallidas, 0 omitidas (19 nuevas, 129 de base; 58 s). Avisos preexistentes de Google Fonts sin fallas; diff de dependencias/lockfile vacío.
- Pendiente: conectar el adaptador desde el contenedor externo en una tarea posterior; integración real y dispositivo SIN VERIFICAR. Los registros inferiores son históricos (detalle #89 ya integrado en esta base).

## Estado vigente al 21/10/2026 — detalle Flutter CU-029 local con mocks

- Entrega publicada en [PR #89](https://github.com/Martiherenu1/ProyectoVanFull/pull/89), abierta y sin merge a main; Issue #88 abierto con etiqueta `chofer`. Rama `feat/chofer-detalle-flutter-cu029`, worktree `F:\dev\vanfull-flutter-cu029-detalle`. Los seis archivos revisados se preservaron en `a6f234eb107214dd0380670f368a1e0110042efc`. Base inicial: `28cfe338fde8bdcd8eb25c56b17c8911dfdb8d7e`; se reutiliza `ViajeResumen`, sin copiarlo ni modificar la rama del listado.
- Primera base integrada el 21/10/2026: `origin/main 5bf3117daf8ce8ab943cf234ac19dbac3fb6196d`, mediante merge local `b81ca4c3967360fe94ed9dabc4bf7fa535adf6da` (padres `a6f234e` y `5bf3117`). #81 ya está mergeada y #80 cerrado; #79 también integrada y #48 cerrado. La dependencia de una PR abierta quedó resuelta. Merge automático, sin conflictos ni rebase/force; historial del contexto conservado, sin borradores ajenos. El detalle aún no está integrado a main ni conectado a navegación/listado.
- Reanudación del 21/10/2026: incorporado `origin/main 34d3855c1af3ddb9b5eab33f30e70b8323d94772` mediante merge local `a78dba2c46af501c534c298e78513b584402b496`, sin conflictos. Incluye #78 (AG-01) y #83 (CI Flutter). No cambian pantallas, DTO, contratos ni dependencias propios; el diff contra main conserva únicamente los seis archivos del detalle/contexto. La publicación anterior ya existía: se reutilizan #88/#89, sin duplicarlos. La nueva CI comprende backend y Flutter; su resultado se verifica en la PR para cada HEAD.

### Hecho

- Backend CU-029 integrado por #65; listado Flutter integrado por #81, todavía sin HTTP ni conexión a navegación. Inicio/finalización backend por #71/#67 y #66 cerrado. CU-030 sigue parcial por GPS y avisos de demora/problemas. #79 aporta entradas temporales por rol, no autorización ni integración HTTP.

### En curso

- Modelo de lectura `OperacionAsignada`, pantalla `DetalleViajeChoferScreen`, dos archivos de pruebas y un fixture sintético compartido. Información del viaje, capacidad planificada, paradas en orden recibido, reservas y nómina separadas y cantidades del servidor sin calcular disponibilidad u ocupación total.
- Carga, contenido, no disponible, error/reintento; invalidación al cambiar ID o fuente, protección tras desmontaje y rechazo de una respuesta con otro ID. Sin contactos privados ni inferencia de ausencia; nómina sin fotografía, reserva ni abordaje inventados.

### Decisiones de esta entrega

- Interfaz local `CargarDetalleViajeChofer = Future<OperacionAsignada?> Function(int idViaje)`: `null` representa detalle no disponible; el futuro adaptador común traducirá el 404 sin distinguir viaje ajeno de inexistente. Otros fallos muestran un error genérico. No cambia contrato ni permisos.
- Fotografía nullable requerida en el modelo; el contrato proporciona una referencia, no necesariamente una URL. Presentación alternativa accesible, sin descarga de imágenes; resolver la referencia real queda para la integración. Horario omitido muestra «Sin horario». Tema de chofer y mínimos compartidos de 64 px; sin navegación, HTTP ni autenticación propios.

### Pendientes

- Issue específico [#88](https://github.com/Martiherenu1/ProyectoVanFull/issues/88) creado el 21/10/2026 con el texto revisado y etiqueta `chofer`. Trazabilidad CU-029, RF-024, RN-029; referencias #64/#48/#81. La [PR #89](https://github.com/Martiherenu1/ProyectoVanFull/pull/89) cierra únicamente #88 al integrarse y mantiene esas referencias. #81 ya integrada: no hay dependencia de una PR abierta; no se declara CU-029 completo.
- Coordinar cliente común y conexión efectiva entre navegación, listado y detalle en otra tarea. Sin prueba HTTP ni en dispositivo; fotografías no visualizadas. La nómina se prueba solo con mocks: no acredita C12 ni modifica el guion/dataset. La CI y las revisiones del HEAD publicado se informan en la PR; no sustituyen la evidencia Flutter local.

### Entorno y comprobaciones

- Flutter 3.47.7 stable / Dart 3.13.5, SDK `F:\dev\flutter`; PATH/PUB_CACHE ajustados solo para el proceso como en la preparación del listado. `flutter pub get --enforce-lockfile` correcto; lockfile SHA-256 intacto `1016007f35a680bb417cafa59e6498ead13c0b6ed116b6d406d03d22c17eac15`.
- Registro histórico previo a integrar main (base `28cfe33`): formato de los cinco archivos nuevos correcto; `flutter analyze --no-pub` sin problemas (20,7 s); `flutter test --no-pub --reporter expanded`: **39 aprobadas, 0 fallidas, 0 omitidas** (24 nuevas: 7 modelo + 17 pantalla; 15 de la base #81: 13 del listado + 2 preexistentes). Pruebas con mocks, incluida pantalla pequeña, privacidad y resultados/errores/null atrasados; no equivalen a integración real.
- **Combinación previa local con main `5bf3117`:** formato de cinco archivos nuevos correcto (cero cambios); `flutter analyze --no-pub` sin problemas (25,0 s); `flutter test --no-pub --reporter expanded`: **45 aprobadas, 0 fallidas, 0 omitidas** (24 nuevas del detalle: 7 modelo + 17 pantalla; 21 de main: 13 listado + 8 navegación/tema). Suite de widgets en aproximadamente 10 s, sin HTTP/dispositivo; esta evidencia Flutter es local y se distingue de la CI remota. No se modificaron dependencias ni lockfile, y no fue necesario repetir pub get. `git diff --check` correcto; diff propio contra main limitado a los seis archivos del detalle/contexto.
- **Combinación vigente con main `34d3855`:** formato de los cinco archivos nuevos correcto (cero cambios), `flutter analyze --no-pub` sin problemas (25,6 s) y `flutter test --no-pub --reporter expanded`: **45 aprobadas, 0 fallidas, 0 omitidas** (24 detalle, 13 listado y 8 navegación/tema; aproximadamente 9 s). Avisos conocidos de Google Fonts en el test preexistente, sin fallas. SDK Flutter 3.47.7 / Dart 3.13.5; lockfile y dependencias intactos. No se ejecutó backend local ni se llamó a la demo; la CI del nuevo HEAD se informa separadamente en #89.
- Durante la preparación previa se corrigieron un aviso de estilo del test, el tipo nullable del fixture y la separación/limpieza de la semántica de fotografía. Sus ejecuciones con fallos no se presentan como aprobadas. Google Fonts emitió avisos desde el test preexistente en ejecuciones previas y en la combinación con main; no se modificó el tema.
- No se ejecutó backend ni se llamó a la demo. Un intento auxiliar de comparación YAML/JSON no pudo correr en Python local por falta de PyYAML; contrato y backend no tienen diferencias entre esta base y main, ni cambios propios en esta entrega.

### Para otras áreas

- Facundo: la pantalla recibe `idViaje` y `cargarDetalle`; no crea `MaterialApp` ni conecta el detalle con la navegación de #79 o el listado de #81. Martiniano: el futuro adaptador conserva sesión/permisos en backend y mapea el resultado a esta interfaz; no se incorporan reglas de reservas en Flutter. Textos de Issue/PR revisados; publicación autorizada y sin mensajes enviados.
- Preservados checkout original, ramas publicadas, borradores documentales, demás worktrees, `.env` y demo. No se copió el guion ni la matriz de otros worktrees.

## Registro histórico al 21/10/2026 — listado Flutter CU-029 verificado con mocks

- Base original: `80a85634a2ab40bf201bb78e8787e8c87d51f0f2`. Issue específico #80 creado con etiqueta `chofer`; entrega local registrada en `ccb5eea8cd5dece5996e9e54a18f1f92d686dcbf`. El 21/10 se integró `origin/main 742476b7c2181a184498f57489888834e1cf2fa7` mediante merge `f00c48aa64c4419ee659ff6277d4186144eb54f3`, sin conflictos, rebase ni force. Incorpora los 11 commits de #73/#76 sin cambios propios de reservas/contrato; Flutter, el listado CU-029 y el schema `Viaje` no cambiaron en ese avance. Backend CU-029 integrado por #65; inicio/finalización integrados por #71/#67 y #66 cerrado. CU-030 continúa parcial: GPS y avisos de demora/problemas pendientes. Los registros inferiores describen verificaciones históricas.
- Rama aislada `feat/chofer-listado-flutter-cu029`: modelo `ViajeResumen` y pantalla de listado por fecha con fuente asíncrona inyectable y callback de selección por ID. Estados de carga, listado, vacío y error/reintento; horario omitido se presenta como «Sin horario». Sin nombres deducidos de identificadores.
- La selección inicial usa el día local (o `fechaInicial` inyectada) y consulta esa fecha explícitamente; no equivale al valor por defecto de fecha del servidor. Se conserva el orden recibido. Respuestas o errores de consultas anteriores no sustituyen la selección actual. Tema `AppTheme.driver` y mínimos compartidos de 64 px para filas y controles propios.
- Revisión estática del 20/10/2026: corregida la fecha de los mocks del día 31 y ampliada la cobertura de fecha inicial UTC (sin conversión de día), rechazo de timestamps donde corresponde una fecha, error tras desmontaje y reemplazo de fuente. Las 13 pruebas entonces pendientes se ejecutaron el 21/10 según el resultado siguiente; no son llamadas HTTP.
- **Checks locales del 21/10/2026:** `flutter pub get --enforce-lockfile` correcto; SHA-256 del lockfile intacto `1016007f35a680bb417cafa59e6498ead13c0b6ed116b6d406d03d22c17eac15`. Formato aplicado solo a cuatro archivos nuevos (dos reformateados); comprobación final: cuatro archivos, cero cambios. Primer analyze detectó un aviso `use_null_aware_elements` en el mock de horario omitido, corregido con entrada null-aware. `flutter analyze --no-pub`: sin issues. `flutter test --no-pub --reporter expanded`: **15 aprobadas, 0 fallidas, 0 omitidas** = 13 nuevas (4 modelo + 9 pantalla) y 2 preexistentes. Sin integración real ni validación visual en dispositivo; CU-029 no está completo.
- **Verificación posterior a integrar main:** sobre el árbol combinado de `ccb5eea` con `742476b`, luego registrado sin cambios en `f00c48a`, se repitieron formato de los cuatro archivos nuevos (cero cambios), analyze (sin avisos, 53,5 s) y la suite completa (15 aprobadas: 13 nuevas + 2 preexistentes; cero fallidas/omitidas). Lockfile y dependencias intactos. No se repitió pub get porque el merge no cambió dependencias. Persisten los avisos de Google Fonts del test preexistente; sin cambios del tema ni prueba HTTP/dispositivo.
- **SDK local instalado el 21/10/2026:** `F:\dev\flutter`, Flutter 3.47.7 stable, revisión `abaf9c523780a608bd46686fd5e53740a07077f8`, Dart 3.13.5; versión ejecutada coincide con Facundo y el [manifiesto oficial](https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json). ZIP SHA-256 comprobado antes de extraer: `c2c875da25a1a1448d18ee4e8f398b2f6fce888b4775d8f9130538e16d826cb4`. El manifiesto vigente usa `/releases/releases_windows.json`; la ruta antigua `/flutter/releases/` devolvió 404. SDK invocado por ruta completa, sin cambiar PATH permanente ni instalar otros SDK/toolchains. El README antiguo no implica regenerar el proyecto: no se ejecutó `flutter create` ni se actualizó ninguna dependencia del proyecto.
- **Trampas y límites de entorno:** el `.bat` falló al expandir PATH con el `&` del perfil; se excluyeron esas entradas solo en cada proceso. El primer intento de test falló antes de ejecutar pruebas por rutas `M&M` en el hook `objective_c`. Resuelto con junctions `F:\dev\vanfull-cu029-worktree` al mismo worktree y `F:\dev\pub-cache` a la caché existente; ejecución desde el primer alias y `PUB_CACHE` del proceso apuntando al segundo, nuevo pub get con lockfile intacto. Doctor informa PATH no configurado, Android SDK y Visual Studio ausentes; no se instalaron. La suite aprobada emitió mensajes de descarga fallida de Archivo/IBM Plex Mono desde el test preexistente del tema: limitación para coordinar con Facundo, sin modificar el tema. Archivos locales de paquetes, build, configuración y registrantes Android/iOS generados están ignorados y fuera del índice; archivos versionados ajenos al alcance intactos.
- Contra el main integrado `742476b`, solo cambian modelo, pantalla, pruebas y contexto propio: sin cambios propios en `main.dart`, navegación, tema compartido, dependencias, backend o contrato; detalle y ejecución quedan fuera de esta tarea. PR #81 abierta para #80, sin merge de esta entrega a main. La CI de publicación del HEAD `28cfe338fde8bdcd8eb25c56b17c8911dfdb8d7e` fue aprobada ([ejecución 39609803814](https://github.com/Martiherenu1/ProyectoVanFull/actions/runs/39609803814)); solo ejecutó backend, no Flutter. La evidencia Flutter anterior sigue siendo local.
- Corrección documental del 21/10/2026: Facundo (`facubarrientos`) publicó [APPROVED](https://github.com/Martiherenu1/ProyectoVanFull/pull/81#pullrequestreview-5604187419) sobre `28cfe338fde8bdcd8eb25c56b17c8911dfdb8d7e`. No se repiten pruebas Flutter porque no cambia código ni dependencias. La CI y la vigencia de esa aprobación para el nuevo HEAD se informan en #81 después del push; no se presuponen por herencia.
- Estado comprobado el 21/10/2026: #79 de Facundo integrada en main mediante `da85c6bd6fdb77544856535faa2d1f3cfe3629cd`; #48 cerrado. Esa navegación conserva una entrada temporal de chofer y todavía no conecta este listado. La conexión efectiva entre navegación y listado será una tarea separada, junto con la integración del cliente HTTP y autenticación comunes; se mantiene el callback futuro al detalle. El adaptador deberá enviar la fecha como `YYYY-MM-DD` y gestionar la sesión y los errores HTTP. Preparación del dataset en el guion/worktree documental independiente; no requerida para estos mocks ni copiada a esta rama. #80 cubre solo este listado Flutter; #64 corresponde al backend, excluye Flutter y no se cierra por este trabajo. La PR cerrará únicamente #80 y referencia #64/#48. Sin mensajes enviados a Facundo o Martiniano.
- Este contexto parte de la versión de `main`; no incorpora ni reemplaza los borradores documentales pendientes de otros worktrees. Checkout original, guion, matriz, `.env` y demo preservados.

## Historial al 19/10/2026 — CU-029 integrado y CU-030 en revisión

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
