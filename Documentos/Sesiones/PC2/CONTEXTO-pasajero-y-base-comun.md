# Contexto vivo · Pasajero y base común del backend (Martiniano)

> Lo mantiene el agente de Martiniano, en el mismo PR que cambia algo. Convención en
> `PROMPT-CONTEXTO-VIVO.md`. Si algo de acá contradice al código, manda el código: corregir este archivo.
>
> **Última actualización: 2026-10-19**

## Estado

**La base común del backend está completa y en `main`.** Del circuito del pasajero están hechos el perfil
(CU-001, PR #26), la consulta de servicios, disponibilidad y paradas (CU-002, PR #29) y la consulta de
reservas propias (CU-010, PR #32), que con el PR de #31 ya informa fecha, horario y sentido del viaje. La
reserva (CU-003) y la cancelación (CU-004) siguen frenadas por pendientes de validación con Martín (#7, #9,
#28 y #33). **El asistente AG-01 (CU-011) está en una rama aparte, sin PR todavía:** `POST /api/chat` con las
tools de lectura (ver «En curso»).

La CI corre en cada PR y pasó en las ramas de la base y en `main`. En la rama del #42 la suite da 186 pruebas
(30 son del chat), algo más de un minuto.

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
| Hoja de pendientes de validación para Martín: `PENDIENTES-PARA-MARTIN-2026-10-15.html` (#33, #7, #9, #28, #8 y #25, cada uno con "mi opción") | — | el que cierra #31 |

## En curso

**CU-011, rebanada de lectura de AG-01 (Issue #42), rama `feat/pasajero-chat-lectura-cu011`.** Hecho: schemas
(`schemas/chat.py`), ejecutor de tools (`agent/ejecutor.py`), servicio (`services/agente.py`), router
(`routers/chat.py`) y pruebas con un modelo falso (`test_ejecutor.py`, `test_agente.py`). Tools que se ejecutan:
`consultar_disponibilidad`, `consultar_reserva` (sin `reserva_id` lista las propias), `consultar_paradas` y
`derivar_humano`; las otras 9 de `tools.py` no se ofrecen al modelo y, si las pide, vuelven `TOOL_NO_HABILITADA`.
`crear_reserva` y `cancelar_reserva` se suman en `_FUNCIONES` cuando existan CU-003 y CU-004.
Falta: abrir el PR e integrar `main` (cambió `app/main.py`).

Después, el circuito de reservas (CU-003, 004); no se empieza sobre una regla indefinida: CU-003 necesita el
respaldo de la reserva (#7), la tarifa (#9) y la capacidad sin vehículo (#28).

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

## Pendientes

Para Martín, la hoja `PENDIENTES-PARA-MARTIN-2026-10-15.html` reúne #33, #7, #9, #28, #8 y #25 con la fuente
(v1.3, RN, `schema.sql`) y "mi opción" de cada uno. Es una propuesta mía, no una decisión: vale si él la aprueba.

| Qué | Issue | Estado |
|---|---|---|
| Respaldo de la reserva (XOR período de abono / contratación) que `POST /reservas` no informa | #7 | PENDIENTE DE VALIDACIÓN con Martín |
| Filtro `destino` de `/servicios/disponibilidad` sin columna en el modelo. Hoy responde 400 `FILTRO_NO_DISPONIBLE` en vez de ignorarlo: la tool `consultar_disponibilidad` de AG-01 manda `destino`; en `/chat` ese error vuelve al modelo como resultado (no es un 500) y el asistente avisa que no puede filtrar por destino | #8 | PENDIENTE DE VALIDACIÓN con Martín |
| `Reserva` también la devuelven `POST /reservas`, `cambio-parada` y `ResultadoCancelacion` (CU-003, 005, 004): al implementarlos, `services/reservas.py::_a_schema(reserva, viaje)` ya arma los campos del viaje; necesitan el `JOIN` con `viaje` | #31 (cerrado) | Aviso a Martín y Facundo en el PR (CONTRIBUTING §1.8 fila 2) |
| Qué ve el pasajero de una reserva cuyo viaje se cancela: hoy `Reserva.estado` no cambia y no se informa el estado del viaje. CU-018 solo crea viajes en el contrato | — | PENDIENTE DE VALIDACIÓN con Martín; sin Issue todavía |
| `Disponibilidad.horario` devuelve `null` si el viaje no tiene horario pero el contrato no lo declara `nullable` (`Reserva.horario` sí) | — | Corrección chica de contrato; no se tocó para no ampliar el PR de #31 |
| Disponibilidad: capacidad de un viaje sin vehículo (hoy `capacidad_planificada`, o sin cupo), viajes ofrecidos (hoy solo `programado`) y si una ausencia libera el cupo (hoy no) | #28 | PENDIENTE DE VALIDACIÓN con Martín. CU-003 valida con la misma función |
| Persistencia de las conversaciones de `/chat`: se pierden al reiniciar y no se comparten entre procesos. Dos mensajes simultáneos de una misma conversación se pisan (gana el último en guardar) | #42 | Pendiente de diseño: hace falta una tabla, y las 35 no incluyen una |
| Qué recibe la persona a la que se deriva (RF-032): hoy `derivar_humano` solo marca la respuesta de `/chat` | #42 | Sin definir en la línea base |
| `/chat` nunca se probó contra un modelo real de OpenRouter: las pruebas usan un modelo falso con guion. La calidad de las respuestas y el prompt (`SYSTEM_PROMPT`, «base de la PoC») | #42 | SIN VERIFICAR; hace falta la clave en `backend/.env` |
| Parámetros de `/tarifas` no corresponden a la tabla `tarifa` | #9 | PENDIENTE DE VALIDACIÓN con Martín |
| Campos editables del perfil: hoy son los del contrato (`email`, `telefono`, `direccion`), concentrados en `CAMPOS_EDITABLES` de `services/perfil.py`. Tampoco está definido si se puede vaciar un dato ni si el email lleva formato o verificación | #25 | PENDIENTE DE VALIDACIÓN con Martín. La v1.3 de CU-001 lo dice textual: "la línea base no enumera cuáles campos, además del DNI, son modificables" |
| Lista de espera de CU-003 sin operación en el contrato. La v1.3 define el registro a pedido (A1) y la incorporación FIFO (A1.1); propuesta: `POST /viajes/{id}/lista-espera` | #34 | Propuesta mía, por PR de contrato (checklist §1.9). La incorporación FIFO crea una reserva: depende de #7, #9 y #33 |
| Qué determina que una reserva quede provisional o consolidada: la v1.3 de CU-003 dice "según las condiciones comerciales aplicables" sin decir cuáles | #33 | PENDIENTE DE VALIDACIÓN con Martín. Bloquea CU-003 |
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
  reservas del pasajero. `reserva` es tabla de esta área; si necesitan otras lecturas (CU-027, el chofer),
  se agregan ahí por PR. Desde #31 el schema `Reserva` trae también `fecha`, `horario`, `sentido` e
  `id_recorrido` del viaje: si arman un listado de reservas (CU-027, listado operativo del chofer), pueden
  reusar el schema o declarar el suyo, pero el contrato del pasajero ya lo tiene.
- `from app.services.disponibilidad import cupo_disponible`: **la definición única del cupo** (RN-001,
  RN-002). Si necesitan el cupo de un viaje (por ejemplo, CU-018 al asignar un vehículo), úsenla; no la
  reescriban.
- `POST /api/chat` (cuando se mergee el PR del #42): solo rol `pasajero`. Si suman un servicio de lectura que el
  asistente deba usar (estado del viaje, ubicación, deuda), la tool se habilita en `_FUNCIONES` de
  `agent/ejecutor.py` llamando a **su servicio**; las 13 definiciones ya están en `agent/tools.py`.
- El seed: cuentas `pasajero1@vanfull.test`, `pasajero2@vanfull.test`, `chofer1@vanfull.test` y
  `admin1@vanfull.test`; las contraseñas están en `db/seed/contrasenas-de-prueba.csv`. Cada dueño suma los
  CSV de sus tablas por PR (`db/seed/README.md`).

**Qué necesito de las demás áreas:**
- Martín: confirmar `hash_contrasena` en el DER y resolver #7, #8 y #9; el escenario de la demo cruzada y los
  CSV de sus tablas.
- Facundo: el servicio de deuda (`GET /pasajeros/me/deuda`) que usa la tool de AG-01 y la pantalla, y el
  backend de pagos que usa la pantalla de pago. Sumar `chofer`, `vehiculo` y `viaje` al seed: la cuenta
  `chofer1` todavía no tiene fila en `chofer`.
