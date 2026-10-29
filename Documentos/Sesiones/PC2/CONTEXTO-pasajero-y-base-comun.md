# Contexto vivo · Pasajero y base común del backend (Martiniano)

> Lo mantiene el agente de Martiniano, en el mismo PR que cambia algo. Convención en
> `PROMPT-CONTEXTO-VIVO.md`. Si algo de acá contradice al código, manda el código: corregir este archivo.
>
> **Última actualización: 2026-10-29**

## Estado

**La base común del backend está completa y en `main`.** Del circuito del pasajero están hechos el perfil
(CU-001), servicios, disponibilidad y paradas (CU-002), las reservas propias (CU-010), el asistente AG-01
(CU-011, `POST /api/chat`), la **creación de la reserva (CU-003, solo ocasional y sin tarifa)** y la
**cancelación (CU-004, sin crédito ni penalidad)**. El asistente puede reservar y cancelar (ver «En curso»).
El cambio de parada (CU-005) **no es del PC2** (REPARTO-PC2).

La CI corre en cada PR. En `main` la suite da 300 pruebas; la rama de las tools de AG-01 suma 15 (315), unos dos minutos.

## Hecho

| Qué | Issue | PR |
|---|---|---|
| Modelos SQLAlchemy 2.0 de las 35 tablas y `tests/test_modelos.py`, que los compara con `schema.sql` | #1 | #10 |
| Alembic async, migración `0001` (35 tablas y 5 roles) y `cuenta_acceso.hash_contrasena` | #2 | #11 |
| Contexto vivo: este archivo y `PROMPT-CONTEXTO-VIVO.md` | #12 | #13 |
| Inconsistencias de docs y CODEOWNERS | #14 | #15 |
| CI en GitHub Actions: `ruff`, `pytest` (incluye migración contra `schema.sql` y contrato) | #3 | #16 |
| Login y logout (CU-012), `core/security.py`, `core/errors.py`, `test_rutas_contrato.py` | #4 | #17 |
| `registrar_evento` (`services/eventos.py`) y `backend/CONVENCIONES.md` | #5 | #18 |
| Seed (`db/seed/`) y su cargador | #6 | #19 |
| Perfil del pasajero (CU-001): `GET` y `PATCH /api/pasajeros/me`, 23 pruebas | #24 | #26 |
| Servicios, disponibilidad y paradas (CU-002), 25 pruebas; `cupo_disponible` en `services/disponibilidad.py` | #27 | #29 |
| Reservas propias (CU-010): `GET /api/pasajeros/me/reservas` y `GET /api/reservas/{id}`, 13 pruebas | #30 | #32 |
| `Reserva` del contrato con `fecha`, `horario`, `sentido` e `id_recorrido` del viaje (cambio aditivo): `openapi.yaml`, JSON regenerado y los dos endpoints de CU-010 | #31 | el que cierra #31 |
| Hoja de pendientes de validación para Martín: `PENDIENTES-PARA-MARTIN-2026-10-15.html` (#33, #7, #9, #28, #8 y #25, cada uno con "mi opción"); superada por las aclaraciones validadas del 2026-10-18 | — | el que cierra #31 |
| Asistente AG-01 de lectura (CU-011): `POST /api/chat`, ejecutor de 4 tools y servicio con modelo + fallback; 30 + 24 pruebas | #42 | #69 |
| Cancelar una reserva propia, sin crédito ni penalidad (CU-004): `POST /api/reservas/{id}/cancelacion`, 23 pruebas | #74 | #76 |
| Cupo: capacidad del vehículo, si no la planificada, si no 19; la ausencia informada libera el lugar (#28 parcial) | #28 | #70 |
| Crear la reserva del ocasional, sin tarifa (CU-003): `POST /api/reservas`, 27 pruebas; `cupo_del_viaje` como definición única | #72 | #73 |
| Tools `crear_reserva` y `cancelar_reserva` de AG-01: `agent/ejecutor.py` las traduce a los servicios de reservas; `crear_reserva` recibe `viaje_id` y `orden_parada` | #77 | #78 |
| Integración del pasajero: login, Buscar, Confirmar, Mis reservas y Asistente conectados a la API (detalle abajo, en «En curso», hasta limpiar esa sección) | #107 | #108 |
| Deploy de la demo: Neon + Render (API y sitio estático) + Pages de respaldo, CORS por variable, seed sin contraseñas públicas, `DESPLIEGUE.md` | #116, #119, #122, #125 | #117, #120, #124, #126 |
| Orden de locks pasajero → viaje → reserva en `cancelar_reserva` y helper `reserva_propia_del_viaje` para el aviso de ausencia (CU-008, de Martín); `CONVENCIONES.md` §8 | #131 | #133 |

## En curso

**Demo desplegada y ensayada (2026-10-23; #116, #119, #122, #125).** App en **https://vanfull.onrender.com**
(sitio estático de Render), API en **https://vanfull-api.onrender.com/api** (Render, Docker free, Ohio) y base en
**Neon** (Postgres 16, us-east-2, endpoint directo); Pages de respaldo. Guía, variables y ensayo: `DESPLIEGUE.md`.
Neon se sembró con `generar_contrasenas` (las contraseñas viven solo en el CSV de Martiniano, fuera del repo) y
trae los 3 viajes del 30/10 de #101. Tropiezos resueltos: Render no parte un `sh -c "…"` en el `dockerCommand`
(→ `backend/arrancar.sh`, #119); la sync del Blueprint falla si la rama `sitio-web` todavía no existe (correr
**Web** antes y aprobar la sync manual); el sitio estático daba 404 en `/` (→ rewrite `/*` → `/index.html`, #125).
**Verificado de verdad:** contra los servicios reales, health `up`, CORS (200 desde el sitio y Pages, 400 desde
otro origen), 401 con la contraseña pública del repo, la disponibilidad del 30/10 desde Neon, y los assets y el
fallback del sitio; **Martiniano ensayó el flujo completo desde el celular** (login, buscar, reservar, Mis
reservas, cancelar, asistente, cerrar sesión) y anduvo. **Antes de la demo:** resembrar Neon con `--reiniciar`
(borra la reserva del ensayo) y despertar la API 5 min antes. **SIN VERIFICAR:** el asistente con un modelo
real (sin `OPENROUTER_API_KEY` deriva). **Cosmético:** el `<title>` de `index.html` y el `manifest.json` dicen
«frontend».

**Integración del pasajero (Issue #107, PR de la rama `feat/pasajero-integracion-107`).** Con #87 en `main`, las cuatro
pantallas del pasajero y el login (#106) quedan **conectadas a la API**: `core/api/auth_api.dart` y `pasajero_api.dart`
implementan los `typedef` de las pantallas sobre `ApiClient` (400/409 → `ReservaRechazada`, 401 → `CredencialesInvalidas`);
`screens/pasajero/pasajero_shell.dart` une Buscar → Confirmar, Mis reservas, Asistente y Cuenta (cerrar sesión), y Mis
reservas se recarga cada vez que se vuelve a ella; `main()` arma el cliente con `--dart-define=API_BASE_URL` y usa
`SesionApp`, que da la entrada real solo al pasajero (chofer y administración siguen en la portada temporal de
`RoleRouter`). Cómo correrla: `frontend/README.md`. **Verificado de verdad (2026-10-23):** `flutter analyze` y
`flutter test` (143), y el flujo en Chrome contra el backend en Docker con el seed: login con contraseña incorrecta
(mensaje) y correcta, disponibilidad y paradas reales, reserva creada en PostgreSQL (una sola fila `consolidada`),
Mis reservas con saldo «Al día», cancelación con el motivo del backend, el chat llegando a `/chat` y cerrar sesión.
**SIN VERIFICAR:** el asistente con un modelo real (`OPENROUTER_API_KEY` vacía: sin modelo `/chat` deriva a una
persona), en Android/iOS, y los rechazos 409 contra el backend real (solo con pruebas). **Pendiente:** el token no
se persiste; perfil (CU-001) y pago (CU-014) tienen su párrafo más abajo; el seed no trae viajes (se crean con `POST /viajes` o con el
seed de la demo, #101). Si la base local de Docker viene de una versión vieja y el login da 500, recrearla con
`docker compose down -v` y repetir migración y seed.

**Pantalla Pago (pantalla 5, CU-014, Issue #140, rama `feat/pasajero-registrar-pago-cu014-140`).** El PC1 la
asigna al pasajero, pero `POST /pagos` solo admitía administración y exigía un `id_cliente` que el pasajero no conoce.
Acordado con Martiniano el 2026-10-24 (backend de Facundo, que lo revisa en el PR): `POST /pagos` acepta el rol
`pasajero`, el cliente sale de su cliente individual (403 `SIN_PERMISO` si manda otro; 404 `CLIENTE_NO_ENCONTRADO`
o `CUENTA_CORRIENTE_NO_ENCONTRADA`, sin crear nada) e `id_cliente` pasa a ser opcional en `PagoCreate` (obligatorio
para administración, 400 si falta; y el que indica administración también debe existir y tener cuenta: mismos dos
404, a pedido de Facundo en la revisión del PR). Flutter: `screens/pasajero/pago_screen.dart` (importe sugerido con el saldo,
medio efectivo/transferencia/billetera; Mercado Pago y cuenta corriente no se ofrecen), `models/pasajero/pago.dart`,
`PasajeroApi.registrarPago` y `leerImporte`/`importeEditable` en `core/format/importe.dart`; se entra con «Registrar
un pago» bajo el saldo de Mis reservas. El pago queda `PENDIENTE` y el saldo no cambia hasta que administración lo
confirma (CU-016). `tipo` y `evidencia_pago` siguen rechazados con 400 (#84). **Verificado:** ruff, `pytest` (367)
y contrato; `flutter analyze` y `flutter test` (340, ya con el perfil); contra el backend en Docker con el seed: `pasajero1` sin
`id_cliente` → 201 `PENDIENTE` con su cliente, con cliente ajeno → 403, `admin1` sin cliente → 400, y `admin1` lo
confirma. **SIN VERIFICAR:** la pantalla en Chrome contra el backend (solo pruebas de widget). Los pasajeros 1 y 2
del seed tienen cuenta corriente; uno que se registra y reserva después, no (recibe el 404).

**Pantalla Flutter Perfil (CU-001, Issue #142), rama `feat/pasajero-perfil-cu001-142`; cubre el «falta perfil»
del párrafo anterior.** `screens/pasajero/perfil_screen.dart` y `models/pasajero/perfil.dart` reemplazan el
contenido de la pestaña Cuenta (conserva «Cerrar sesión»). Dos operaciones **inyectables** (`CargarPerfil`,
`ModificarPerfil`) sobre `GET` y `PATCH /pasajeros/me`; para eso `ApiClient` y `HttpApiClient` ganaron `patch`
(los dos fakes de las pruebas también). Nombre, apellido y DNI se muestran sin edición (RN-026); correo, teléfono y
dirección se editan y **solo se manda lo que cambió**; un dato que quedaría vacío no se guarda (el backend no
admite `null`: omitir deja el valor). 400 y 403 muestran el mensaje del backend; cualquier otra falla, un aviso
genérico. **No hay verificación del contacto ni foto:** #25 sigue abierto (SMS/WhatsApp, almacenamiento de fotos), así
que la pantalla edita sin código de verificación, como hoy el endpoint. Verificado: `flutter analyze` y
`flutter test` (326). **SIN VERIFICAR:** contra el backend real y en un dispositivo o navegador.

**Pantalla Flutter Buscar servicio (CU-002, Issue #90, PR #91), rama `feat/pasajero-buscar-servicio-cu002`.**
`screens/pasajero/buscar_servicio_screen.dart` y `models/pasajero/` (`DisponibilidadViaje`, `Parada`). Carga
**inyectable** (`CargarDisponibilidad`, `CargarParadas`), igual que el listado del chofer: no crea clientes HTTP.
Fecha y sentido explícitos; **no manda `destino`** (el backend lo rechaza con 400 `FILTRO_NO_DISPONIBLE` hasta
resolver #8). Estados: esqueleto, vacío, error con reintento, "Sin cupo". Verificado: `flutter analyze` y
`flutter test` (40/40). **SIN VERIFICAR:** contra el backend real y en un dispositivo o navegador. **No está
conectada** al `RoleRouter`: falta el cliente común (#87) y el login (pantalla 1).

Después: el login y la navegación entre las pantallas del pasajero (Pago quedó en #140). El tipo de servicio no se muestra
(la respuesta trae solo `id_servicio`; haría falta `GET /servicios`).

**Pantalla Flutter Confirmar reserva (CU-003, Issue #92), rama `feat/pasajero-confirmar-reserva-cu003`, apilada
sobre la de Buscar servicio (#91).** `screens/pasajero/confirmar_reserva_screen.dart` y `models/pasajero/reserva.dart`
(`Reserva`, `EstadoReserva`, `ReservaRechazada`). Recibe el `DisponibilidadViaje` que entrega Buscar servicio
(`onReservar`), pide las paradas del recorrido (`CargarParadas`), el pasajero marca dónde sube y confirma con
`CrearReserva(idViaje, ordenParada)` **inyectable**: el adaptador común debe lanzar `ReservaRechazada` ante los
400/409 con cuerpo de error. Muestra el motivo concreto de cada rechazo (`CUPO_NO_DISPONIBLE`,
`RESERVA_DUPLICADA_DEL_DIA`, `RESERVA_CANCELADA_PREVIA`, `VIAJE_NO_RESERVABLE`, `PARADA_NO_VALIDA`, red); los
cuatro primeros bloquean el botón porque reintentar no cambia el resultado. Sin doble envío. `consolidada` se
muestra como «Confirmada». **No muestra tarifa** (CU-003 no la calcula hasta #9) **ni lista de espera** (#34: el
409 la anuncia pero no hay operación). Verificado: `flutter analyze` y `flutter test` (60/60). **SIN VERIFICAR:**
contra el backend real y en un dispositivo o navegador; **no está conectada** (falta #87 y el login). Las
paradas se listan todas, incluida la última: ninguna regla dice cuáles admiten ascenso.

**Pantalla Flutter Mis reservas y deuda (CU-010 / CU-006 / CU-004, Issue #94), rama `feat/pasajero-mis-reservas-cu010`,
apilada sobre la de Confirmar reserva (#93).** `screens/pasajero/mis_reservas_screen.dart`, `models/pasajero/deuda.dart`,
`ResultadoCancelacion` en `models/pasajero/reserva.dart` y `core/format/importe.dart` (`$ 11.600,00`). Tres cargas
**inyectables** (`CargarReservas`, `CargarDeuda`, `CancelarReserva`). El saldo (dato dominante: «Al día» o el importe en
rojo) y la lista fallan y se reintentan por separado. Cancelar pide confirmación; los 409 `RESERVA_NO_CANCELABLE` y
`VIAJE_NO_CANCELABLE` se muestran con su motivo (el adaptador debe lanzar `ReservaRechazada`), y la cancelada
muestra el `motivo` que devuelve el backend. **No muestra la ventana de cancelación de RN-017** (“Podés cancelar hasta
…” del brief): hoy se puede cancelar mientras el viaje esté programado y el crédito no existe (#75), así que mostrar
una hora prometería algo que no se aplica; la `Reserva` tampoco informa el estado del viaje. **Resuelto el 2026-10-24
(Issue #137):** si el pasajero no tiene cliente individual todavía (no reservó nunca), `GET /pasajeros/me/deuda`
responde 404 `CLIENTE_NO_ENCONTRADO` y `PasajeroApi.cargarDeuda` lo traduce a «Al día» (sin cuenta corriente no
hay deuda); el backend de Facundo no cambia. Verificado: `flutter analyze` y `flutter test` (79/79). **SIN VERIFICAR:** contra el backend real y en
un dispositivo o navegador; no está conectada (#87 y el login).

**Pantalla Flutter Asistente (CU-011, Issue #96), rama `feat/pasajero-asistente-cu011`, apilada sobre la de Mis reservas
(#95).** `screens/pasajero/asistente_screen.dart` y `models/pasajero/respuesta_chat.dart`. Envío **inyectable**
(`EnviarMensaje(mensaje, conversacionId)` → `RespuestaChat`); la pantalla guarda el `conversacion_id` que devuelve el
backend y lo reenvía. No envía vacío ni más de 2000 caracteres (el tope del backend), un mensaje a la vez, avisa
«El asistente está respondiendo…» con texto y no con spinner, marca «Derivado a una persona de VanFull» cuando
`derivar_humano` es `true` y, si el envío falla, deja el mensaje con «No se pudo enviar» y «Reintentar» (reenvía con
el mismo `conversacion_id`). Cualquier excepción del adaptador es «no se pudo enviar»; el 400 `VALIDACION` no tiene
tratamiento propio porque el cliente ya valida. La presentación inicial solo promete lo que las tools habilitadas
hacen (viajes, cupos, reservas, derivar a una persona) y avisa que no confirma pagos. **No usa `tool_usada`**:
al reservar o cancelar por chat, Mis reservas no se entera; cuando se arme la navegación hay que recargarla al volver.
Las conversaciones viven en memoria del backend (#42): al reiniciar el servidor se abre una nueva sin avisar, y esta
pantalla tampoco guarda el historial. Verificado: `flutter analyze` y `flutter test` (72 sobre `main`, 91 con #95).
**SIN VERIFICAR:** contra `/chat` real ni contra un modelo de OpenRouter, y en un dispositivo o navegador; no está
conectada (#87 y el login).

## Decisiones

| Fecha | Decisión | Dónde queda |
|---|---|---|
| 2026-10-13 | Docker Compose para correr backend, base y pruebas, igual en las tres máquinas; el venv es solo para el editor | Este archivo |
| 2026-10-13 | `cuenta_acceso.hash_contrasena VARCHAR(255) NOT NULL` | PR #11, CONTEXTO §7 |
| 2026-10-13 | `POST /auth/logout` devuelve 204 y el cliente descarta el token, sin lista negra | CONTEXTO §7 |
| 2026-10-13 | Sin `relationship()` en los modelos; los servicios consultan explícito | PR #10 |
| 2026-10-14 | `bcrypt` y `PyJWT` directos (no `passlib` ni `python-jose`) | CONTEXTO §7, PR #17 |
| 2026-10-14 | El servicio hace el `commit`, una vez, al final; el helper de eventos solo hace `flush`. Un recurso ajeno responde 404 | `backend/CONVENCIONES.md` |
| 2026-10-14 | El seed se niega a correr contra una base no local: las contraseñas de prueba están en un repo público | `db/seed/README.md` |
| 2026-10-14 | **La revisión de otro integrante es opcional, para siempre**; el autor mergea con la CI en verde y deja asentado en el PR si hubo revisión. Los PR #10 a #21 se mergearon sin revisión registrada en GitHub | CONTRIBUTING §1.7 |
| 2026-10-15 | `Reserva` trae `fecha`, `horario` (`"HH:MM"`, `null` si el viaje no tiene), `sentido` e `id_recorrido`, **planos** y con los nombres de `Disponibilidad`: el schema `Viaje` expone chofer y vehículo, que el pasajero no necesita. `id_recorrido` es para resolver `orden_parada` con `GET /recorridos/{id}/paradas`. No se expone `estado_viaje`: ninguna RN dice qué pasa con las reservas de un viaje cancelado | Issue #31, `openapi.yaml` |
| 2026-10-15 | **GPS (#37):** un timestamp futuro se reemplaza por la hora del servidor; ante un empate de timestamp se conserva la primera posición, porque `posicion_gps` guarda una fila por viaje. Decisión de Martiniano, respondida a Martín | Este archivo: #37 todavía no tiene comentario en GitHub |
| 2026-10-19 | **`/chat` (Issue #42):** las conversaciones viven en memoria del proceso, atadas al `id_persona` que las abrió (ninguna de las 35 tablas las guarda). Topes: 40 mensajes por conversación (se descartan turnos enteros) y 500 conversaciones | `services/agente.py`, Issue #42 |
| 2026-10-19 | Un `conversacion_id` inexistente o de otra persona **abre una conversación nueva** y devuelve su id, en vez de 404: tras reiniciar el servidor el chat del pasajero sigue andando, y una ajena no revela que existe (RN-026 a 030). Decisión mía al implementar, a confirmar | `services/agente.py`, `test_agente.py` |
| 2026-10-19 | Cada mensaje admite hasta 5 vueltas modelo → tools y 2000 caracteres. Si el modelo no responde (principal ni fallback), responde algo ilegible o no cierra en las vueltas, sale `derivar_humano: true` y el turno no se guarda. `tool_usada` es la última tool habilitada que se ejecutó | `services/agente.py`, Issue #42 |
| 2026-10-20 | **CU-003 (Issue #72):** el ocasional queda `consolidada` al reservar (la aceptación es automática: AC7-02 y #33); su respaldo es **una contratación por reserva**, sin `id_tarifa` ni `importe_acordado`, y no genera deuda. Si el pasajero no tiene cliente individual se crea. Decisiones mías al implementar, a confirmar | `services/reservas.py`, Issue #72 |
| 2026-10-20 | **CU-004 (Issue #74):** cancelar no otorga crédito ni cobra penalidad, porque ninguna de las 35 tablas guarda el crédito de RN-017. Se puede cancelar mientras el viaje esté `programado`, también fuera de las 18:00 del día anterior: esa referencia solo decide el crédito y el caso fuera de término está sin definir (CU-004 en 06-Notas §6.3), así que solo cambia el `motivo`. Un viaje cancelado, en curso o finalizado responde 409. Decisiones mías al implementar, a confirmar | `services/reservas.py`, Issue #74 |
| 2026-10-20 | Una reserva cancelada del mismo viaje no se reactiva ni se pisa: responde 409 `RESERVA_CANCELADA_PREVIA`, porque MR-R15 deja una fila por pasajero y viaje y reactivarla no está definido (AC28-08) | `services/reservas.py` |
| 2026-10-23 | **Deploy (#116):** la migración corre en el arranque del servicio de Render (`backend/arrancar.sh`: `alembic upgrade head` y después uvicorn; va en un script porque Render no parte un `sh -c "…"` como un shell, #119), porque el plan free no tiene shell ni jobs; es idempotente. Pages se publica a mano (`workflow_dispatch`); la API, cuando la CI de `main` pasa. Fuera de desarrollo, sin `CORS_ORIGINS` la API no arranca. CORS sin `allow_credentials`: el token va en `Authorization` | `render.yaml`, `DESPLIEGUE.md` |
| 2026-10-23 | En una base remota, el seed exige `--permitir-base-remota` **y** un archivo de contraseñas fuera del repo (la bandera sola ya no alcanza); las contraseñas de la demo se generan al azar y no se imprimen | `db/seed/README.md`, `DESPLIEGUE.md` |
| 2026-10-23 | **La URL de la demo es `vanfull.onrender.com`** (sitio estático de Render), no la de Pages, que muestra el usuario de GitHub (#122). Flutter se compila en GitHub Actions (workflow **Web**) y se publica en la rama `sitio-web`, que Render sirve sin compilar; Pages queda de respaldo | `render.yaml`, `DESPLIEGUE.md` |
| 2026-10-24 | **Orden de locks: pasajero → viaje → reserva** en creación, cancelación, ausencia y abordaje; ejecución del viaje toma solo el viaje y no adquiere pasajero ni reserva después. Propuesta de Martín (CU-008), confirmada por Martiniano; Facundo pendiente. `cancelar_reserva` se adaptó (antes bloqueaba solo la reserva) | `services/reservas.py`, `CONVENCIONES.md` §8, #131 |
| 2026-10-28 | **Prueba contra Render con el código de `main` (`pasajero2`, solo lectura):** login, perfil, deuda, Buscar servicio (IDA con 3 viajes; VUELTA vacía), paradas, el filtro `id_parada_destino` y sus dos 400, y Mis reservas respondieron bien (0,3 a 0,6 s; login 2,4 s). **Asistente con el modelo real** (7 mensajes): disponibilidad, paradas, reservas propias, confirmación previa a reservar, rechazo de lo ajeno y `derivar_humano` correctos; `**` en 2 de 7 respuestas (#194 las limpia en el backend) y sin usar el filtro nuevo (#195). Latencia en frío: login 34,7 s y primer mensaje 27,3 s. **No probado:** escritura (crear y cancelar una reserva), pantalla Flutter, fallback con modelos reales. Antes de la demo hay que re-sembrar Neon con `--reiniciar` | Issue #156 (comentario), PR #194 y #195 |
| 2026-10-28 | **Modelos de AG-01:** principal `nvidia/nemotron-3-ultra-550b-a55b:free` y fallback `nvidia/nemotron-3.5-lightning:free` como valor por defecto del repo (los del PC1 dejaron de funcionar gratis el 24/10). No pasaron por la PoC de 07 §3.1 | PR #188, #154 cerrado |
| 2026-10-29 | **Asistente: bajada vs. subida (#197, #198).** Con el modelo real, ante «quiero bajar en la Parada 2» el asistente decía que había que reservar con la parada 2 como *subida* (la reserva guarda solo la subida). #197 sumó la regla al prompt y empeoró: el modelo le pedía al pasajero el nombre del recorrido e inventaba ejemplos, sin consultar la disponibilidad. #198 da la secuencia explícita (disponibilidad → paradas → disponibilidad con `id_parada_destino`) y prohíbe pedir ids o nombres de recorrido, viaje o parada. **Verificado contra Render tras #198 (3 mensajes):** consulta, aclara que el filtro solo indica que el recorrido pasa por la parada, pregunta dónde sube y pide confirmación con esa parada de subida; sin Markdown. El mensaje con la cadena de tools tardó 40 s (tope por mensaje: 60 s). **No verificado:** el argumento exacto que mandó a la tool, la ejecución de la reserva tras la confirmación y la PoC formal TC-01..10 | PR #197 y #198, Issue #156 |
| 2026-10-29 | **Asistente en la app y con mensajes informales (#199 a #202).** App web de Render con `pasajero2`: Buscar (30/10: 3 viajes de ida y sus paradas), Confirmar reserva (pide dónde subís), Mis reservas, Asistente y Cuenta funcionan; no se confirmó ninguna reserva ni pago. Hallazgos y arreglos: el asistente prometía «en la práctica sí se puede» bajar (#200), mostraba una cita `>` (#201) y un mensaje («y hoy?») no respondió en 120 s porque el tiempo de espera de httpx es por lectura y no por llamada (#202; **causa no confirmada**: falta mirar el log de Render por «no respondió (TimeoutError)»). **Con mensajes informales** («pa el viernes», «kiero bajar x la parada 2», «el de las 6 de la tarde», «cuanto sale?») entendió la fecha y la hora y no inventó una tarifa. **Casos difíciles** («mañana», «y hoy?», «dale» sin contexto, «hay lugar?» sin datos, cancelar sin reservas): pide el dato que falta y no crea nada. Tras #202: de 1,9 a 16,4 s por mensaje y el cuelgue no se repitió (no se pudo provocar). **Pendiente:** latencia en frío (51 s un «hola», 34,9 s el login con la API dormida: calentar antes de la demo), tope de espera en el cliente de Flutter (cliente compartido: acordar con Martín y Facundo), la fecha se sugiere como `2026-10-30`, reservar y cancelar por el chat, y la PoC TC-01..10 | Issue #156 (comentario), PR #197 a #202 |
| 2026-10-29 | **Seed: segundo chofer y segundo vehículo.** Para probar la reasignación de CU-018 (Facundo) hacían falta ids distintos de chofer 3 y vehículo 1, que eran los únicos. Se suman la persona 5 («Chofer Dos», sin cuenta de acceso: para asignar alcanza con que exista en `chofer`), el chofer 5 y el vehículo 2 (`VF030AA`, capacidad 20). Una prueba reasigna el viaje 1 al chofer 5 y al vehículo 2 por `PATCH /viajes/1`. **Neon no lo tiene hasta re-sembrar con `--reiniciar`**, que borra lo que cargaron Facundo y Martín | `db/seed/`, `test_seed.py` |
| 2026-10-29 | **CU-027: `GET /api/reservas` para administrador/dueño** (acordado por los tres: recorte propuesto por Martín, aceptado por Facundo). Todas las reservas, de cualquier estado, con el schema `Reserva` actual (con `id_pasajero`), por `id_reserva` ascendente, solo lectura; sin reservas, 200 con lista vacía. **Sin** filtros HTTP, nombres, contactos ni importes (quedan pendientes, `x-cobertura: parcial`); no se pagina ni se trunca (el volumen de la demo lo permite). `GET /reservas/{id}` sigue siendo solo del pasajero. Cambia el contrato (agrega una operación, no modifica ninguna existente) | `services/reservas.py`, `routers/reservas.py`, `openapi.yaml`/`.json`, `test_reservas.py` |
| 2026-10-29 | **Asistente: las fechas se muestran como DD/MM/AAAA (#231).** El modelo repetía al pasajero las fechas como las recibe de las tools (`2026-10-30`). Igual que con el Markdown (#194), se resuelve en el backend y no con el prompt: a un día de la demo no se toca, y #197 mostró que un cambio de prompt puede empeorar el comportamiento. `fechas_legibles()` convierte `AAAA-MM-DD` en `DD/MM/AAAA` solo en la respuesta que ve el pasajero; el historial del modelo conserva el ISO, para que no empiece a mandarle `DD/MM/AAAA` a las tools. No toca fechas inválidas ni fechas con hora (`…T18:00`). Con esto el punto «la fecha se sugiere como `2026-10-30`» de #156 queda resuelto; **#156 sigue abierto** por la PoC formal TC-01..10, cuyos casos originales no están en el repo ni en el Drive (solo sus resultados y los nombres de TC-04, 07, 08, 09 y 10) | `services/agente.py`, `test_agente.py`, Issue #231 |
| 2026-10-29 | **Asistente: límite diario de OpenRouter (#233).** Con el script de verificación contra Render (`pasajero2`), reservar por el chat se cortó en «sí, confirmo»: el log de Render mostró `429 Rate limit exceeded: free-models-per-day` en los **dos** modelos (`X-RateLimit-Limit: 50`, `Remaining: 0`, `limit_source: openrouter_free_tier_daily`; se renueva a las 21:00 de Argentina, 00:00 UTC). **La cuenta gratuita permite 50 pedidos por día** y cada mensaje del pasajero gasta de 2 a 4 (una vuelta por tool), o sea unos 15 a 25 mensajes por día entre pruebas y demo. Decisión del equipo: **no se cargan créditos** (10 créditos subirían el tope a 1000). El backend ya derivaba bien, pero decía «No pude resolver tu consulta…»: ahora el cliente distingue el cupo diario (`CupoDiarioAgotado`, solo si TODOS los intentos fallaron por eso) y el pasajero lee que el asistente alcanzó su límite de hoy y que puede seguir desde Buscar y Mis reservas (07 §8: «informa indisponibilidad»); `derivar_humano` sigue en `true`. Cualquier otra falla conserva el mensaje de siempre. **Confirmado también en ese log:** `nemotron-3-ultra … no respondió (TimeoutError)` (el tope de 30 s por llamada se dispara de verdad; el mensaje tardó 46 s porque respondió el fallback). **No verificado:** reservar y cancelar por el chat con el modelo real (el paso 1 pidió confirmación sin crear nada; el paso 2 no llegó a ejecutarse); y **no gastar cupo antes de la demo**: un solo mensaje de calentamiento | `agent/openrouter_client.py`, `services/agente.py`, tests, Issue #233 |
| 2026-10-29 | **Protección de `main` (cambio de configuración, no de código).** Se bajó a 0 la cantidad de approvals requeridos, de modo que cada integrante mergea sus propios PR (coincide con CONTRIBUTING §1.7: la revisión es opcional). El PR sigue siendo obligatorio, no se admite push directo ni force-push, y ahora las dos CI son requisito: `Backend (ruff, pytest, migración y contrato)` y `Flutter (analyze y test)`. Antes la CI **no** era requisito. El auto-merge del repositorio está activado. Para volver a exigir review basta subir ese 0 a 1 | Ajustes de GitHub (`gh api …/branches/main/protection`) |
| 2026-10-29 | **Verificado en Render por API: crear y cancelar una reserva; y el pendiente del timeout del cliente queda cerrado.** Script de verificación (viaje 3 de las 18:00, `pasajero2`, contraseña por `getpass`): `POST /reservas` responde 201 en 0,3 s y la reserva queda `consolidada`; el cupo baja de 18 a 17; aparece en Mis reservas y el detalle coincide; `GET /viajes/{id}/ubicacion` responde `404 VIAJE_NO_DISPONIBLE` con el viaje sin iniciar (RN-030); `POST /reservas/{id}/cancelacion` responde 200, devuelve el lugar (el cupo vuelve a 18) y no aplica penalidad (RN-017 fuera de término «no está definido», #75). **Deuda: `0.0 al_dia` antes, durante y después** — reservar no genera un movimiento `DEUDOR` (la tarifa, RF-028/#9, está fuera por decisiones pendientes) y ninguna pantalla lo crea, así que el pago confirmado no se ve bajando una deuda (se habló con Facundo: cargar un `DEUDOR` de demo a mano después del reinicio, o presentar solo el pago). **Timeout del cliente Flutter:** `http_api_client.dart` usa `http` sin tope y el servidor corta cada mensaje a los 60 s (`TIEMPO_MAXIMO`), así que la app espera la respuesta y no puede cortar antes de que el servidor ejecute una acción; si falla, la pantalla marca el mensaje para reintentar (un reintento de una reserva repetida lo frena RN-031). No hace falta acordar un tope con Martín y Facundo. **También:** `test_el_pasajero_cancela_por_el_chat` dependía de la hora (el plazo de RN-017 vencía el 29/10 a las 18:00) y tumbaba la CI de todo PR; ahora usa una fecha relativa a hoy (#237/#239) | `verificar_pasajero.py` (no versionado), `test_agente.py`, Issue #237 |
| 2026-10-29 | **CU-005: `POST /reservas/{id}/cambio-parada` implementado (backend, #242).** Estaba en el contrato desde la v0.1 sin ruta ni servicio. Fuentes leídas en el Drive (aprobadas): CU-005 v1.3 y RN-020 v1.1 — «solamente podrá cambiar su parada cuando exista disponibilidad compatible con el horario, recorrido y unidad»; si no la hay, no se modifica la parada. **Interpretación mínima, PENDIENTE DE VALIDACIÓN por el equipo:** la capacidad se calcula por viaje y la reserva ya ocupa su lugar en él, así que cambiar de parada dentro del mismo viaje mantiene horario, recorrido y unidad y no consume otro lugar; «compatible» = la parada nueva pertenece al recorrido del viaje. Por analogía con la cancelación: solo una reserva propia **no cancelada** de un viaje **programado**; mismo orden de bloqueos (pasajero → viaje → reserva) y evento `reserva_parada_cambiada`. Errores: 400 `PARADA_NO_VALIDA` (la misma validación que al crear), 409 `RESERVA_NO_MODIFICABLE`, `VIAJE_NO_MODIFICABLE` y `PARADA_SIN_CAMBIOS` (pedir la que ya tiene), 404 igual para ajena e inexistente, 403 para otros roles. El cupo no se mueve (probado). **Sin pantalla Flutter** (queda para después) y el chatbot no lo ofrece (CU-005 no lo asigna a ese canal). Cambia el contrato: documenta los errores y el `minimum: 1` de una operación que ya existía; no agrega ni quita operaciones | `services/reservas.py`, `routers/reservas.py`, `openapi.yaml`/`.json`, `test_cambiar_parada.py`, Issue #242 |
| 2026-10-29 | **Los 17 CU sin contrato quedan declarados PENDIENTES para el PC2 (decisión de Martiniano, noche del 29/10).** Se evaluó sumar uno para la demo leyendo sus objetivos en CU v1.3: 017, 024, 028, 031 y 035 dependen de reglas sin definir (tarifa #9, crédito de RN-017 #75, pagos); 037 necesita un proveedor de WhatsApp sin definir y 020 la clave de Google Maps; 023, 033, 034 y 025 son grandes (rol corporativo, cuentas, export a Excel/PDF); 032 crea cuentas y roles con contraseñas. Los únicos viables eran consultas de solo lectura (013, 019, 021, 022, 026); el mejor candidato era CU-013 como consulta (tablas `persona` y `pasajero` propias, sin regla pendiente en una lectura), pero se descartó: sin pantalla solo se vería en `/docs`, exige un PR de contrato con aviso y suma riesgo antes de la demo. **No se implementa ninguno ni se declara completo**; quedan en la lista del contrato (`openapi/README.md`, «CU pendientes de contrato») y en el guion de la demo (§4). Los datos que esos CU administran se cargan con el seed | `openapi/README.md`, `GUION-DEMO-PC2.md` |

## Pendientes

El 2026-10-18 Martín validó funcionalmente las aclaraciones de #7, #8, #9, #25, #28 y #33
(`ACLARACION-FUNCIONAL-*-VALIDADA-ANALISIS.md`, en esta carpeta). **Definen el negocio; no aprueban cambios
técnicos ni de la línea base** (lo dicen ellas mismas): contrato, modelo y código siguen sin decidir, y los
dos primeros se cambian por PR aparte (§1.8, §1.9). La hoja `PENDIENTES-PARA-MARTIN-2026-10-15.html` quedó
superada en esos seis puntos.

| Qué | Issue | Estado |
|---|---|---|
| Respaldo de la reserva que `POST /reservas` no informa. Aclarado (AC7-01 a 06): se puede reservar sin contratación previa y el sistema la acepta solo; ida y vuelta del **mismo día** van en una contratación, de días distintos en dos; con la ida impaga y el mismo día se cancela la contratación y se genera una conjunta; con la ida paga se contrata la vuelta aparte; sin cupo de vuelta se conserva la ida. `contratacion` no tiene `estado` y `servicio.tipo_servicio` no tiene `OCASIONAL` | #7 | Funcional VALIDADO. **Parcial en CU-003 (#72):** el ocasional ya reserva con una contratación por reserva. Falta: ida y vuelta del mismo día en una sola contratación (AC7-03/04/06), cómo se registra cancelar una contratación (no tiene `estado`) y el respaldo por abono |
| Filtro `destino` de `/servicios/disponibilidad` sin columna en el modelo; hoy 400 `FILTRO_NO_DISPONIBLE` (en `/chat` vuelve al modelo como resultado, no es un 500). Aclarado (AC08-01 a 05): el destino de IDA de un abonado se fija al contratar; el ocasional elige un destino habilitado y se listan los viajes que pasan por una parada de descenso habilitada; el filtro **no es la última parada**; en VUELTA el descenso se elige en cada viaje. Las paradas de ascenso y descenso pueden variar por viaje | #8 | Funcional VALIDADO. **Primera entrega de PC2 hecha (28/10):** `id_parada_destino` opcional en `GET /servicios/disponibilidad` filtra los viajes cuyo recorrido **pasa por** esa parada (contrato #190, servicio #193, aprobado por Martín y Facundo; la tool del asistente en #195). **No distingue ascenso/descenso ni habilitación por viaje** (AC08-06/07, PT08-03/04/20): sigue pendiente la parada de descenso por reserva (hoy solo se guarda la de ascenso) y la habilitación por viaje. Pide PR de modelo, después de PC2. `destino` en texto sigue en 400 `FILTRO_NO_DISPONIBLE` |
| `Reserva` también la devuelven `POST /reservas` y `ResultadoCancelacion` (CU-003 y 004, ya hechos) y `cambio-parada` (CU-005, fuera del PC2): `services/reservas.py::_a_schema(reserva, viaje)` arma los campos del viaje con el `JOIN` | #31 (cerrado) | Aviso a Martín y Facundo en el PR (CONTRIBUTING §1.8 fila 2) |
| Crédito de RN-017: la cancelación de un ocasional en término genera un crédito para otro viaje del mismo mes, que se pierde si no se usa. Las 35 tablas no lo guardan (el DER v0.1 tenía `CREDITO_REINTEGRO`). Tampoco hay devolución de RN-018 ni reintegro de RN-019 | #75 | PENDIENTE DE VALIDACIÓN con Martín: dónde se guarda (PR de modelo, §1.9) y la cancelación del ocasional fuera de término |
| Qué ve el pasajero de una reserva cuyo viaje se cancela: hoy `Reserva.estado` no cambia y no se informa el estado del viaje. CU-018 solo crea viajes en el contrato | — | PENDIENTE DE VALIDACIÓN con Martín; sin Issue todavía |
| Disponibilidad (#28). **En `main` (PR #70):** capacidad = vehículo asignado, si no `capacidad_planificada`, si no 19 (AC28-01 a 03); una fila de `ausencia` libera el lugar de esa reserva consolidada (AC28-06); un viaje `programado` se ofrece aunque haya pasado su hora (AC28-05). **Sigue pendiente:** reservar en viajes `en_curso` (AC28-04; el modelo no guarda qué paradas se alcanzaron y el GPS solo no alcanza, PV28-01), recuperar el lugar tras una ausencia (AC28-08, PV28-04), la sobrecapacidad al asignar un vehículo (PV28-02, Facundo) y las carreras al reservar (CU-003) | #28 | Parcial. **Confirmado por Martín el 2026-10-20 (opción a):** cada fila de `ausencia` es un aviso voluntario del pasajero (CU-008); `POST /ausencias` no registra inasistencias sin aviso (RN-022) ni se generan ausencias por falta de abordaje, así que el cálculo de #70 no necesita distinguir tipos (PT28-18 resuelto en ese sentido). Siguen pendientes la recuperación del lugar y las paradas pendientes. CU-003 valida con la misma función |
| Persistencia de las conversaciones de `/chat`: se pierden al reiniciar y no se comparten entre procesos. Dos mensajes simultáneos de una misma conversación se pisan (gana el último en guardar) | #42 | Pendiente de diseño: hace falta una tabla, y las 35 no incluyen una |
| Qué recibe la persona a la que se deriva (RF-032): hoy `derivar_humano` solo marca la respuesta de `/chat` | #42 | Sin definir en la línea base |
| `/chat` contra un modelo real: probado contra Render el 24/10 y el 28/10 (ver Decisiones). Falta la PoC formal (TC-01..10) con los modelos y tools actuales (07 §9), reservar y cancelar por el chat con confirmación (escribe datos y obliga a re-sembrar Neon) y el tope de espera del cliente de Flutter | #156 | PoC pendiente; necesita la clave en la terminal de Martiniano |
| Parámetros de `/tarifas` no corresponden a la tabla `tarifa`. Aclarado (AC9-01 a 27): tarifa mensual fija por servicio, días por semana y modalidad; el ocasional tiene tarifa fija por viaje (por servicio y sentido) y una conjunta ida+vuelta **solo del mismo día**; prorrateo a mitad de mes; 15 % por efectivo sobre la deuda que cada pago cancela (`efectivo / 0,85`); importes con 2 decimales; ajuste trimestral por FADEEAC | #9 | Funcional VALIDADO. Falta rehacer los parámetros de `/tarifas` contra la tabla `tarifa` (PR de contrato). **Hasta entonces CU-003 no calcula tarifa ni genera deuda (paso 5 de la v1.3)** |
| Campos editables del perfil. Aclarado (AC25-01 a 22): el pasajero edita correo, teléfono, dirección y **fotografía** (obligatoria: se reemplaza, no se elimina); nombre, apellido y DNI los corrige un administrador. Cambiar correo o teléfono pide un código al dato nuevo y el anterior sigue vigente hasta verificarlo. Perfil completo = esos datos verificados y la foto; incompleto **no reserva ni paga**, pero consulta. Hoy `PATCH /pasajeros/me` edita `email`, `telefono` y `direccion` (`CAMPOS_EDITABLES`) sin verificación, y la fotografía solo se muestra | #25 | Funcional VALIDADO; el código no se cambió. Falta: modelo de «perfil completo» y «contacto verificado», proveedor de SMS/WhatsApp, almacenamiento de fotos, detección de rostro y qué entra en el PC2 (PV25-18) |
| Lista de espera de CU-003 sin operación en el contrato. La v1.3 define el registro a pedido (A1) y la incorporación FIFO (A1.1); propuesta: `POST /viajes/{id}/lista-espera` | #34 | Propuesta mía, por PR de contrato (checklist §1.9). La incorporación FIFO crea una reserva: depende de #7, #9 y #33 |
| Qué determina que una reserva quede provisional o consolidada. Aclarado (§3 del documento): ocasional en efectivo al abordar, la **aceptación de VanFull**; estudiante con cupo anual, la acreditación del pago anticipado de enero; laboral, la acreditación del pago inicial; especial, la seña del 50 %; corporativo, la aceptación bajo un acuerdo vigente. No se define sanción por ausencia ni impago, ni que cualquier pago consolide | #33 | Funcional VALIDADO. El ocasional ya queda `consolidada` en CU-003 (#72). Falta la regla para abono, especial y corporativo, y el ocasional que paga por transferencia antes; el alcance de `ocasional` frente a `ESPECIAL` sigue abierto |
| Condiciones de rechazo del login. Hoy: credencial inválida y cuenta con `estado` distinto de `activo` (lectura conservadora del DEFAULT); no se mira `pasajero.estado_habilitacion` ni hay política de intentos | #4 (cerrado) | La v1.3 de CU-012 define solo autenticación válida o inválida (A1) y **no menciona el estado de la cuenta**: ese rechazo es decisión mía, a confirmar o sacar. Intentos máximos, bloqueo y expiración son pendiente técnico del propio CU |
| El contrato usa `password` (inglés) en `LoginRequest` y el resto es castellano | — | Cambiarlo pide el acuerdo de los tres (§1.3). No se cambió |
| Sin lista negra, un token vale hasta que vence (60 min) aunque se suspenda la cuenta | — | Política de sesiones: CONTEXTO §13 |
| Confirmación de Martín por `hash_contrasena` en el DER | — | Pendiente de su respuesta |

## Entorno y trampas

- **Docker Desktop tiene que estar abierto.** Sin el motor nada corre; `docker info` lo confirma. Desde
  PowerShell se abre con `Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"`.
- **Para reemplazar el modelo en una prueba** se hace `monkeypatch.setattr(openrouter_client,
  "chat_completion", ...)`: `services/agente.py` lo llama por el módulo. Con `from ... import chat_completion`
  el reemplazo no tendría efecto.
- **`backend/.env` hace falta** (`cp backend/.env.example backend/.env`): sin él ningún comando del backend
  arranca. No está en el repo; la clave de OpenRouter va solo ahí.
- **La API no migra sola.** Tras `docker compose up -d --build`, `/health` da 200 pero el login da 500 hasta
  correr `alembic upgrade head`. El orden está en el README raíz.
- Checks, desde la raíz y dentro de Docker: `docker compose run --rm --no-deps backend ruff check .` y
  `... ruff format --check .`; pruebas: `docker compose run --rm backend pytest -q`.
- **No correr `ruff format` sobre todo `app` o `tests`**: reformatea archivos de otros. Pasarle solo los de la
  tarea. `ruff format` también formatea los bloques de Python dentro de los `.md` bajo `backend/`.
- La CI cancela la corrida anterior de la misma rama (`concurrency`): en `main`, merges seguidos dejan
  corridas "canceladas" que no son fallas.
- Las pruebas que usan la base crean bases temporales `vf_test_*` en el PostgreSQL de Docker y las borran
  (`tests/_bd.py`). En la CI fallan en vez de saltearse si no hay base.
- **La v1.3 de los CU y las 31 RN están en el Drive** (`03_Especificaciones_Casos_de_Uso_VanFull_v1.3_...`
  y `02_Reglas_de_Negocio_VanFull_v1.1_...`). Buscar por **título**: por carpeta (`parentId`) o por texto
  (`fullText`) devuelve vacío o archivos de otras materias. Antes de implementar un CU, leerlo.
- Git Bash en Windows: `git show origin/main:ruta` falla por la conversión de rutas; usar `MSYS_NO_PATHCONV=1`.
  Una ruta de clon muy larga falla: `git clone -c core.longpaths=true`.
- Los números de Issue y de PR los asigna GitHub en orden de creación: verificar con `gh` antes de citarlos.
- **Regenerar `openapi.json` con el comando del README puede dejarlo vacío:** el comando abre el JSON para
  escribir antes de parsear el YAML, así que un YAML con error (por ejemplo `{id}` sin comillas dentro de un
  `{ ... }` de una línea) deja el JSON en 0 bytes. Si pasa, arreglar el YAML y volver a correr; `git diff --stat`
  tiene que mostrar solo las líneas agregadas.
- La regla de "quién decide un cambio de contrato" está en CONTRIBUTING **§1.8 fila 2** y en la tabla de §2.
  §1.3 es "Rama": el Issue #31 lo citaba mal.
- CODEOWNERS asigna `models/`, `migrations/`, `db/`, `openapi/` y `.github/` a `@Martiherenu1`, que es el
  autor de estos PR: GitHub no le pide la revisión a sí mismo, así que el revisor se asigna a mano.

## Para otras áreas

**Ya se puede usar (en `main`):**
- Modelos de las 35 tablas: `from app.models.<bloque> import ...`; quién escribe en cada tabla está en
  `REPARTO-PC2.md`.
- `from app.core.security import usuario_actual, requiere_rol` y `from app.core.errors import ApiError`.
  El "solo lo propio" (RN-026 a 030) lo decide cada servicio con `usuario.id_persona`.
- `from app.services.eventos import registrar_evento`: a lo sumo un origen (reserva, pago o viaje), hace
  `flush`, los `tipo_evento` los define cada dueño.
- `backend/CONVENCIONES.md`: capas, transacción, errores y pruebas.
- `from app.services.reservas import listar_reservas_del_pasajero, obtener_reserva_del_pasajero`: lectura de
  reservas del pasajero (y `listar_reservas_para_administracion`, CU-027). `reserva` es tabla de esta área; si necesitan otras lecturas (el chofer),
  se agregan ahí por PR. Desde #31 el schema `Reserva` trae también `fecha`, `horario`, `sentido` e
  `id_recorrido` del viaje: si arman un listado de reservas (CU-027, listado operativo del chofer), pueden
  reusar el schema o declarar el suyo, pero el contrato del pasajero ya lo tiene.
- `from app.services.disponibilidad import cupo_disponible`: **la definición única del cupo** (RN-001,
  RN-002). Desde #28 devuelve siempre un entero (sin unidad ni capacidad planificada rige 19) y no cuenta a quien informó su ausencia. Si necesitan el cupo de un viaje (por ejemplo, CU-018 al asignar un vehículo), úsenla; no la
  reescriban.
- `POST /api/chat` (PR #69): solo rol `pasajero`. Si suman un servicio de lectura que el
  asistente deba usar (estado del viaje, ubicación, deuda), la tool se habilita en `_FUNCIONES` de
  `agent/ejecutor.py` llamando a **su servicio**; las 13 definiciones ya están en `agent/tools.py`.
- El seed: cuentas `pasajero1@vanfull.test`, `pasajero2@vanfull.test`, `chofer1@vanfull.test` y
  `admin1@vanfull.test`; las contraseñas están en `db/seed/contrasenas-de-prueba.csv`. Cada dueño suma los
  CSV de sus tablas por PR (`db/seed/README.md`).

**Qué necesito de las demás áreas:**
- Martín: confirmar `hash_contrasena` en el DER y resolver #7, #8 y #9; el escenario de la demo cruzada y los
  CSV de sus tablas.
- Facundo: el servicio de deuda (`GET /pasajeros/me/deuda`) que usa la tool de AG-01 y la pantalla, y revisar
  el cambio de `POST /pagos` para el pasajero (#140). Sumar `chofer`, `vehiculo` y `viaje` al seed: la cuenta
  `chofer1` todavía no tiene fila en `chofer`.
