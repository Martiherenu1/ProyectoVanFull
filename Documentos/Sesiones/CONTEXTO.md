# CONTEXTO VANFULL — Carga rápida de sesión

> **Para qué sirve:** documento de arranque. Leyendo esto se recupera todo el contexto crítico del proyecto sin
> releer la documentación completa. **Mantenerlo actualizado al cerrar cada sesión.**
>
> **Al abrir un chat nuevo:** `CLAUDE.md` (raíz del repo) se carga solo y tiene las reglas fijas y los
> datos de esta máquina. Los prompts de arranque por tipo de tarea, y el criterio de cuándo conviene
> abrir un chat nuevo, están en `Documentos/Sesiones/PROMPT-INICIAL.md`.
>
> **Última actualización: 2026-10-26** (§13 composición compartida de Flutter integrada y chofer1 verificado contra Render; antes, 24/10: backend en Render y asistente AG-01 con modelo real) · Reemplaza y consolida todas las versiones anteriores.

---

## 1. Qué es Vanfull

**VanFull** es una empresa **real** de transporte de pasajeros (charters) que hoy opera con **WhatsApp + Excel +
teléfono**. El proyecto académico (*Trabajo de Campo*, 4º año, 2º cuatrimestre 2026) centraliza esa operatoria en
una plataforma **Web + Mobile**.

Servicios que presta: charter universitario, charter laboral, eventuales/ocasionales, empresas, turismo y especiales.

**Los tres dolores que priorizó la empresa:** (1) control de reservas y cupos, (2) control de pagos — el problema
grave es *no detectar* un pago, (3) notificaciones a clientes.

## 2. Stack técnico (cerrado por el equipo el 2026-08-27)

| Capa | Decisión |
|---|---|
| Frontend | **Flutter** (Web + Mobile) |
| Backend | **Python + FastAPI** (REST / JSON / OpenAPI) |
| Base de datos | **PostgreSQL** |
| ORM + migraciones | **SQLAlchemy 2.0 async + Alembic** |
| Mapas / rutas | **Google Maps Platform** (Routes API) |
| Pagos | **Mercado Pago**, entorno de **pruebas** (webhooks) |
| Gateway LLM | **OpenRouter** |
| LLM principal / fallback | `minimax/minimax-m3:free` / `nvidia/nemotron-3-super-120b-a12b:free` |
| Mensajería | **WhatsApp** (configuración exacta pendiente) |
| Versionado | **Git + GitHub**, flujo rama → PR → merge |
| Hosting (costo 0) | **Neon** (BD) · **Render** (backend) · **GitHub Pages** (web). Ver §7 |

## 3. Arquitectura — el principio que gobierna todo

**Cliente-servidor por capas.** El frontend no tiene reglas críticas de negocio. **La IA no accede a la base de
datos**: sólo invoca *tools* de FastAPI. **FastAPI es la autoridad** de autenticación, permisos, cupos, pagos y
validaciones. El LLM interpreta la intención y elige la herramienta; **el backend decide**.

```
Flutter (Web/Mobile) ─┐
                      ├─→ REST/JSON (OpenAPI) → FastAPI → services/ (reglas RN) → PostgreSQL
Agente AG-01 (tools) ─┘                              └→ integraciones (MP · Maps · WhatsApp)
```

**Las 4 capas del backend** (clave para entender el código):

| Capa | Responsabilidad | Regla de oro |
|---|---|---|
| `routers/` | Recibe HTTP, valida permisos, delega | **Sin lógica de negocio.** Son finos |
| `schemas/` | Contrato de entrada/salida (Pydantic) | Separado de las tablas |
| `services/` | **Reglas de negocio (las 31 RN)** | El cerebro del sistema |
| `models/` | Tablas como clases (SQLAlchemy) | Lo único que habla con Postgres |

## 4. Alcance del MVP

**Dentro:** pasajeros, clientes corporativos, reservas/cupos con lista de espera, tipos de servicio, tarifas y
abonos, pagos y deuda, viajes, choferes y vehículos, abordaje por QR, GPS del servicio, optimización de recorridos,
WhatsApp + chatbot, notificaciones, reportes con export Excel/PDF.

**Fuera (límites explícitos):** integración con Uber, cambio libre del DNI por el pasajero, acceso del chofer a
contactos privados, confirmación manual de abordaje por el chofer, seguimiento de toda la flota por pasajeros,
cambio autónomo de rutas por la IA, validación 100% autónoma de pagos por el LLM, integración fiscal (ARCA),
Mercado Pago productivo.

**Extensión futura (no MVP):** AG-02 (agente operativo para admins), QR del chofer, combustible, mantenimiento de flota.

## 5. Línea base funcional aprobada (producida por Integrante 2)

Todo esto **ya existe, está aprobado y fue ingerido**. Son **entradas**: no las escribimos nosotros.

- **45 Requisitos Funcionales** (RF-001..045) · **14 RNF + métricas** (RNF-001..014) · **31 Reglas de Negocio** (RN-001..031)
- **9 actores** (ACT-01..09) y **37 Casos de Uso** (CU-001..037) con especificaciones completas
- **Modelo conceptual, UML, C4** (Contexto + Contenedores) y **Arquitectura General**
- **DER / Modelo Relacional oficial: 35 tablas** en 5 bloques, con 32 restricciones (MR-R01..R32)

Resumen de lectura: `Documentos/Documentacion/06-Notas-Ingesta-Drive-2026-09-08.md`.
Fuente oficial: Drive del equipo (ver memoria `drive-del-companero` para el mapa de carpetas).

### Métricas RNF que condicionan la implementación

Disponibilidad 99 % mensual · 95 % de operaciones ≤ 2 s · operaciones pesadas ≤ 5 s · 100 usuarios concurrentes
(pico de prueba 150) · escalar ≥ 2× · **GPS: update 10 s, precisión ≤ 50 m, más de 30 s = "desactualizada"** ·
**QR offline: sincronizar ≤ 60 s sin duplicados** · **RTO ≤ 1 h · RPO ≤ 15 min**.

## 6. AG-01 — el agente conversacional

- **Usuarios:** pasajeros y clientes autorizados, desde la app y (luego) WhatsApp — **el mismo agente** en ambos canales.
- **Acceso a datos:** indirecto, sólo por tools de FastAPI. Nunca toca PostgreSQL.
- **13 tools**, todas trazadas a un CU y a un endpoint → `Documentos/Documentacion/07-IA-y-Agentes-Consolidado.md`.
- **Reglas de oro:** no inventa cupos/horarios/tarifas/pagos; no modifica estados de pago; no revela datos de
  terceros; si faltan datos los pide; deriva a humano si no puede resolver con seguridad.
- **Hallazgo de la PoC:** las fechas relativas ("mañana") **no** se delegan al modelo — el backend inyecta
  fecha/hora determinística antes de ejecutar cualquier tool.
- **Elección de modelos justificada por PoC:** matriz ponderada de 8 criterios sobre 10 casos (TC-01..10) →
  MiniMax 95,5/100 (principal), Nemotron 94,5/100 (fallback).

## 7. Decisiones técnicas tomadas (y por qué)

| Decisión | Motivo |
|---|---|
| **Monorepo** (`backend/` + `frontend/`) | Equipo de 3; evita duplicar issues/CI y facilita cambios que cruzan capas |
| **GPS por polling (~10 s)**, no WebSocket | No hay caso bidireccional; robusto en free tier; calza con RNF-007. SSE es plan B |
| **SQLAlchemy 2.0 async**, no Prisma ni SQLModel | Prisma es Node-first; SQLModel se complica con PK compuestas y herencia, y el DER tiene ambas |
| **Roles en tablas de la app** (`rol_acceso` + `cuenta_rol`), no roles del motor | Los usuarios finales no son usuarios de la BD; las reglas RN-027..030 son contextuales y un `GRANT` no las expresa |
| **PK BIGINT identity · CHECK para enums · NUMERIC para importes** | Decisiones del modelo físico que el MR dejó diferidas |
| **Derivados NO persistidos** (saldo, deuda, cupo) | MR-R30: se calculan; evita datos inconsistentes |
| **Una reserva por viaje** para los abonos | Resuelto así en el MR oficial (MR-R15/16); simplifica cupo, QR y reportes |
| **`.docx` fuera del repo** | Drive = documentación oficial · GitHub = código y artefactos versionables |
| **Contrato OpenAPI antes de implementar** | Permite que frontend, backend e IA avancen en paralelo sin romperse |
| **`cuenta_acceso.hash_contrasena VARCHAR(255) NOT NULL`** (decidido el 2026-10-13) | El MR dejó diferida la autenticación al modelo físico y la tabla no tenía dónde guardar la contraseña, necesaria para el login (CU-012, RF-045). Entra en `schema.sql`, `models/` y la migración inicial en el mismo PR. El algoritmo de hash lo fija la tarea del login. Aviso a Martín por ser el DER |
| **Autenticación: bcrypt y PyJWT directos** (decidido el 2026-10-14, Issue #4) | `passlib` no se mantiene y falla con `bcrypt` >= 5; `python-jose` tampoco, y la documentación de FastAPI usa PyJWT. Token HS256 con la cuenta, la persona y los roles; vence a los 60 min (`ACCESS_TOKEN_EXPIRE_MINUTES`). Fuera de desarrollo el secreto debe tener 32 bytes o más |
| **Logout sin lista negra** (decidido el 2026-10-13) | `POST /auth/logout` devuelve 204 y el cliente descarta el token. La política de sesiones sigue siendo un pendiente (§13) |
| **Hosting de costo 0** (decidido el 2026-10-02): BD en **Neon**, backend en **Render** (servicio web gratis), web Flutter en **GitHub Pages**. Desarrollo diario con `docker-compose.yml` | Alcance académico: sirve para la entrega; si el producto se vende se paga algo mejor. Se descartó Firebase (NoSQL, no calza con `schema.sql`), Supabase (pausa el proyecto a los 7 días sin uso) y la BD gratis de Render (vence a los 30 días y la borra). Usar la BD **solo como Postgres estándar**, sin SDK ni funciones propias del proveedor, para que mudarse sea cambiar `DATABASE_URL` + `pg_dump` |

## 8. Equipo y reparto

- **Hasta el PC1:** Martín (Integrante 2) produjo análisis, CU, UML/C4 y el DER, que siguen siendo la fuente de
  verdad; Martiniano y Facundo cubrieron backend, API, IA y Flutter.
- **Desde el 13/10/2026 (hacia el PC2), los tres desarrollan, por tipo de usuario**, cada uno frontend y backend
  de su parte: **Martiniano** pasajero (y la base común del backend), **Martín** chofer y viaje en curso,
  **Facundo** administración (y la base común de Flutter). Un dueño por tema en el backend; el contrato se amplía
  por PR. Todo en `Documentos/Sesiones/PC2/REPARTO-PC2.md`, con un prompt por integrante en esa carpeta.
- Herramientas: Martiniano usa Claude Code; Facundo, Codex (lee `AGENTS.md`, que remite a `CLAUDE.md`).

## 9. Cronograma (detalle en `02-Cronograma.md`)

**PC1 = entrega 28/09, presentado y aprobado el viernes 02/10/2026** · PC2 = viernes 30/10 · PC3 = viernes 13/11 ·
Cierre = viernes 20/11 (los encuentros son los viernes; ver `02-Cronograma.md`).
El desarrollo del backend arranca el **05/10** (sem 10); frontend 12/10; integración 19/10; pruebas y documentación 02/11.

## 10. Estado del PC1 y del documento v1.1

> **Tag `pc1` (`278b0d4`) = entrega aprobada el 02/10/2026, congelado.** Todo cambio posterior lleva tag nuevo: `pc1.1` y
> `pc1.2` ya existen (documento v1.1); el próximo sería `pc1.3`.

**Nuestra parte del PC1 quedó terminada:** `backend/db/schema.sql` (35 tablas, 54 FKs, validado contra PostgreSQL real) ·
`backend/openapi/openapi.yaml` + `.json` (21 rutas, 22 operaciones, 23 schemas, validado) · `07-IA-y-Agentes-Consolidado.md` ·
modelo de desarrollo (`CONTRIBUTING.md`, ruff/pytest) · 10 pantallas · `10-Documento-MVC-PC1.md` → `.docx` en la carpeta `07_` del Drive.

### Los artefactos de diseño viven en claude.ai (⚠️ los links solo están acá)

| Qué | Link |
|---|---|
| **Pantallas VanFull** — las 10 pantallas del PC1, navegables | https://claude.ai/artifact/6M3yj4nmLnqaCoM6BqY4Ui |
| **Sistema de diseño VanFull** — tokens, 4 componentes, marca | https://claude.ai/artifact/6ptGhgioyJSHZeCBv1eRaG |

Las reglas, el porqué y la lista de las 10 pantallas están en `Documentos/Documentacion/08-Brief-de-Diseno-UI.md`.

⚠️ **El QR lo escanea el pasajero, no el chofer** (CU-007): el código identifica a la unidad. El chofer solo consulta (CU-029) y
**no registra abordajes**. Int2 lo detectó el 28/09; está corregido en las pantallas, el brief y el documento.

⚠️ **Hubo dos documentos MVC** el 30/09 (Int2 trabajó sobre una copia `_Integracion_Int2`); se resolvió a favor de la suya. La
vieja quedó como `..._HISTORICO_no_usar.docx`: **no borrarla ni confundirla**.

⚠️ **El cronograma correcto es el de `02-Cronograma.md`** (puntos de control los viernes 02/10, 30/10 y 13/11; cierre 20/11).
Circulaban otras dos versiones con fechas distintas.

### Documento MVC v1.1 (08/10/2026)

La cátedra publicó la lista de contenidos del documento. La v1.1 suma, sin renumerar nada de lo ya citado: §1.5 Propuestas,
§1.6 Propuesta seleccionada, §1.7 Análisis, **§2.5.1 Trazo fino** (tabla de los 8 CU con diagrama de actividad), §2.7 Diagramas
de actividad, §2.8 Componentes y despliegue, **§6.5 Informe sobre la IA** (uno solo para el equipo, en tercera persona, sin
nombres) y el **Anexo G**: las 37 especificaciones copiadas sin modificar de `03_Especificaciones_Casos_de_Uso_VanFull_v1.3_Aprobado_Equipo`
(fuente de verdad: Int2; no copiarlas al repo).

**Vigente:** `07_Documento_MVC_VanFull_v1.1.docx` (en `Escritorio/VanFull-PC1-v1.1-para-Drive/`, con el README unido
`07_README_PC1.docx`), espejado en `10-Documento-MVC-PC1.md`. Los tres revisaron (Martín: 1.7, 2.5.1 y Anexo G sin correcciones).

**Sin confirmar con la cátedra:** *Trazo fino* = especificación detallada de los CU (lo planteó Martín); y si la lista es
re-entrega del PC1 o va para el PC2.

**Subido al Drive el 08/10** (carpeta `07_`, junto a la v1.0, que quedó intacta); Martiniano revisó el Word a ojo: OK.
**Falta:** reemplazar `07_README_PC1.docx` por la versión unida (`Escritorio/VanFull-PC1-v1.1-para-Drive/`). Hay además un
`07_README_PC1.md` de Martín en esa carpeta (12 KB, del 01/10): no reemplazarlo sin compararlo antes. Decisión tomada: los
diagramas de actividad 018, 030, 028, 017 y 007 quedan con texto chico en papel (26-34 %); los PNG son de alta resolución y los
originales están en la carpeta 04. Si Martiniano edita el Word a mano, comparar antes de regenerarlo.

## 11. Estado del código

**Existe:** `main.py` (app + CORS + routers), `core/config.py` (variables de entorno), `core/database.py` (motor
async + `get_db`), `routers/health.py` (**el único endpoint real**), `agent/tools.py` (13 tools + system prompt),
`agent/openrouter_client.py` (cliente con fallback), Dockerfile y docker-compose, y desde el PC2:

- `models/`: las 35 tablas, un archivo por bloque (PR #10). `tests/test_modelos.py` los compara con `schema.sql`.
- `migrations/` (Alembic async): migración `0001`, que crea las 35 tablas y carga los 5 roles. Se corre con
  `docker compose run --rm backend alembic upgrade head`.

- `core/security.py` (bcrypt, JWT, `usuario_actual` y `requiere_rol`) y `core/errors.py` (error uniforme del
  contrato), con `POST /api/auth/login` y `/api/auth/logout` (CU-012, Issue #4), que son los primeros
  `routers/`, `schemas/` y `services/` reales.

- `services/eventos.py` (helper de `evento_operativo`) y la guía `backend/CONVENCIONES.md` (Issue #5).
- `db/seed/` con los datos de prueba y su cargador, `python -m db.seed.cargar` (Issue #6).
- La integración continua, `.github/workflows/ci.yml`: `ruff`, `pytest`, migración y contrato, en cada PR
  (Issue #3).

- `routers/perfil.py`, `services/perfil.py` y `schemas/perfil.py`: `GET` y `PATCH /api/pasajeros/me` (CU-001,
  Issue #24).

- `routers/servicios.py`, `services/servicios.py` y `services/disponibilidad.py`: `GET /api/servicios`,
  `/api/servicios/disponibilidad` y `/api/recorridos/{id}/paradas` (CU-002, Issue #27). El cupo se deriva en
  `cupo_disponible`: la definición única, que CU-003 va a reutilizar.
- `routers/reservas.py`, `services/reservas.py` y `schemas/reservas.py`: `GET /api/pasajeros/me/reservas` y
  `GET /api/reservas/{id}` (CU-010, Issue #30). Solo lectura; crear, cancelar y cambiar parada se suman ahí.
  Desde el PR #38 (Issue #31) la `Reserva` informa también `fecha`, `horario`, `sentido` e `id_recorrido`
  del viaje: cambio aditivo del contrato.

**Endpoints desplegados el 2026-10-24** (OpenAPI de la API en Render; el detalle por área está en
`Documentos/Sesiones/PC2/CONTEXTO-<área>.md`): `/auth/login` y `/auth/logout` · `/pasajeros/me`,
`/pasajeros/me/reservas` y `/pasajeros/me/deuda` · `/servicios`, `/servicios/disponibilidad` y
`/recorridos/{id}/paradas` · `/reservas`, `/reservas/{id}` y `/reservas/{id}/cancelacion` · `/pagos` y
`/pagos/{id}/confirmacion` · `/viajes` (`POST` y, desde #145, `GET ?fecha=`), `/viajes/{id}/inicio` y
`/viajes/{id}/finalizacion` · `/choferes/me/viajes` y `/choferes/me/viajes/{id}` · `/ausencias` (CU-008, #147) ·
`/chat` · `/health`. El backend en Render está en `f511d3c` (deploy 20:32 UTC, incluye #155 y #157; GitHub lo
registra en Deployments). Todavía sin endpoint: los abordajes (Martín).

**`/chat` (AG-01) responde con un modelo real en Render desde el 24/10** (#155, #157): qué se verificó, con qué
modelos y qué falta, en §13.

**Plan:** `services/` (reglas RN) → `routers/` (endpoints del OpenAPI) → tests. Los 37 CU entran en ~10 routers,
no uno por CU.

## 12. Cómo trabajamos (acordado el 2026-09-22)

Martiniano pidió **tener el control y entender el código**, no sólo aprobar lo que se hace: explicar antes de hacer,
pasos chicos, mostrar el diff antes de commitear o mergear, explicar los comandos, e invitarlo a mirar y editar en
VS Code. Las reglas completas están en `CLAUDE.md`.

## 13. Pendientes abiertos (no inventar: requieren definición del equipo o externa)

Sincronización offline del QR · identificación/autenticación del chatbot para datos sensibles · política de sesiones,
cifrado y recuperación de cuenta · auditoría (es **propuesta**, no aprobada) · privacidad y retención de datos (legal) ·
detalle fiscal/ARCA · configuración de WhatsApp (cuenta, plantillas, costos) · campos editables del perfil ·
criterio de liberación de cupo por ausencia · fallback de la optimización de rutas.

**Ya decidido, no reabrir:** la **lista de espera es FIFO** y los ajustes ADJ-01, ADJ-02 y ADJ-03 están cerrados.

**Por verificar al provisionar el hosting (no están en la documentación oficial leída el 02/10):** si Render o
Neon piden tarjeta al registrarse · qué pasa cuando se agotan las 100 CU-horas mensuales de Neon · tiempo de
arranque en frío de Neon · cómo reintenta Mercado Pago un webhook que cae mientras el backend despierta.

**Límites del plan gratis, ya confirmados:** Neon, 1 GB por proyecto y 100 CU-horas por mes, se duerme a los 5 min
sin uso. Render, se duerme a los 15 min sin tráfico y despertar tarda cerca de 1 minuto; 750 horas gratis por mes
(un servicio 24/7 gasta 744, sin margen). **No usar un pinger** para mantenerlo despierto: agota las horas y, si
toca la BD, la mantiene despierta. En su lugar, **calentar con `/health` y una consulta real unos 5 minutos
antes de cada demo**, y sacar un `pg_dump` local antes de cada punto de control.

**Demo desplegada (2026-10-23):** app en https://vanfull.onrender.com, API en https://vanfull-api.onrender.com/api,
base en Neon (us-east-2). Ensayada desde un celular con el flujo completo del pasajero. Cómo se despliega, qué
variable va dónde y el ensayo: `DESPLIEGUE.md`.

**Estado al cierre del 2026-10-24.** Plazo real: **viernes 30/10/2026**; el equipo trabaja hasta ahí (el «freeze desde
el 25/10, salvo acuerdo» de REPARTO-PC2 no rige, por decisión de Martiniano):

- **Concurrencia (#131, PR #133, mergeado):** orden de locks **pasajero → viaje → reserva** en creación,
  cancelación, ausencia y abordaje; ejecución del viaje toma solo el viaje. Escrito en
  `backend/CONVENCIONES.md` §8. `cancelar_reserva` se adaptó y existe `reserva_propia_del_viaje` para el aviso de
  ausencia (CU-008). El servicio de ausencias y el abordaje son de Martín; falta que agregue sus pruebas de
  concurrencia e idempotencia (sin avisos duplicados).
- **CU-008 cerrado entre los tres:** 201 aviso nuevo; 404 sin reserva propia; 409 reserva provisional o cancelada,
  pasajero abordado o viaje finalizado/cancelado; 200 con la misma fila si el aviso propio ya existía, aunque
  después cambie la reserva o el viaje. El aviso no cancela la reserva ni recupera el lugar.
- **`GET /viajes` (CU-018): hecho (#145, Facundo, revisado por Martiniano).** Fecha obligatoria y estricta
  (`YYYY-MM-DD`), roles `administrador` y `dueno`, orden por horario (nulos al final, después `id_viaje`), todos los
  estados, errores 400/401/403. El adaptador Flutter es #150 (mergeado); falta la pantalla.
- **CU-008 (#147, Martín): mergeado.** `POST /ausencias` en producción.
- **Flutter (actualizado 26/10):** la composición compartida **ya está en `main`**. #153 (Martiniano: generación de
  sesión, 401 asociado al token de la petición, logout con el token saliente y salida local si falla la red) y
  **#159 (Facundo, Issue #152; revisado por Martiniano sobre `9cd69a5`)**: `main.dart` pasa a `VanFullBootstrap`
  (un solo `http.Client`, un solo `HttpApiClient` y una sola `SesionController` para las tres áreas),
  `SesionApp`/`RoleRouter` reciben `entradaPasajero`, `entradaChofer` y `entradaAdministrador`, un
  `KeyedSubtree(ValueKey(generacion))` aísla las pantallas entre cuentas y el 403 muestra «Acceso denegado» solo si
  la generación y el token siguen siendo los de la petición. #159 no tocó `SesionController` ni `HttpApiClient`.
  Luego **#161** (Issue #160) estabilizó los callbacks de chofer. Administración queda conectada con Viajes del día
  y Crear viaje; el detalle del viaje del admin no (`onViajeSeleccionado` vacío; CU-014 parcial en #84).
  **Abierto: #123** (Martín): actualizar sobre `main` y conectar la entrada del chofer a `ChoferShell`.
  Mergeados el 24/10: #113, #121, #128, #130, #134, #139 y #150 (los conflictos de #113, #121, #139 y #147
  eran solo del documento de contexto de Martín y los resolvió Martiniano con Claude, con las ramas encadenadas).
- **Pasajero (Martiniano):** Pago (CU-014, #141) y Perfil (CU-001, #144) mergeados. Con #141 administración y dueño
  reciben 404 `CLIENTE_NO_ENCONTRADO` o `CUENTA_CORRIENTE_NO_ENCONTRADA`; **sigue pendiente #84 de Facundo: nadie
  crea la `cuenta_corriente` de un pasajero nuevo**, que recibe 404 al pagar (los pasajeros 1 y 2 del seed andan).
- **CU-014 (#85):** queda con alcance limitado para PC2. El 15 % por efectivo no es del registro: RN-011 y AC9-13/14
  lo aplican tras un pago en efectivo confirmado (CU-016). Faltan tipo/evidencia y algunos errores; Facundo abre el
  Issue y marca `POST /pagos` con `x-cobertura: parcial`.
- **Demo en Render:** el sitio publicado es el build `8380d19` (24/10 18:24 UTC, workflow **Web** corrido a mano), que
  trae Pasajero con Pago y Perfil (comprobado en el bundle compilado; **no** se abrió la app ni se probó el flujo
  con sesión). El sitio **no tiene entrada de chofer** hasta que entre #123 y se vuelva a correr **Web**: no se
  publica solo. Un navegador con la versión vieja abierta puede mostrarla por su caché: recarga forzada o ventana
  privada. La API sí expone las rutas del chofer. `chofer1@vanfull.test` (persona 3) tiene los
  viajes 1 y 3 del 30/10/2026; el 3 no tiene vehículo. **Verificado el 26/10 contra Render** (ver el bloque
  «Prueba de chofer contra Render» más abajo).
- **Asistente AG-01 en Render con un modelo real (24/10, Martiniano).** `OPENROUTER_API_KEY` cargada en el panel
  (clave de cuenta free tier, límite de crédito 1 USD, vence el 22/01/2027). **Los dos modelos aprobados (07 §3) hoy
  no funcionan gratis:** `minimax/minimax-m3:free` ya no existe (OpenRouter: «unavailable for free»; queda
  `minimax/minimax-m3`, pago) y `nvidia/nemotron-3-super-120b-a12b:free` figura en el listado pero NVIDIA responde
  404. **Configuración provisoria de la demo, solo en el panel de Render:**
  `OPENROUTER_MODEL_PRIMARY=nvidia/nemotron-3-ultra-550b-a55b:free` y
  `OPENROUTER_MODEL_FALLBACK=nvidia/nemotron-3.5-lightning:free` (Martiniano eligió seguir gratis; los dos
  devolvieron una tool call correcta en un diagnóstico directo). El repo (`config.py`, `.env.example`) sigue con los
  aprobados.
  - **Verificado contra Render con `pasajero1`:** consultar disponibilidad (los 3 viajes de ida del 30/10), paradas,
    crear reserva previa confirmación (reserva 3, viaje 3), el rechazo `RESERVA_CANCELADA_PREVIA` explicado sin
    inventar, consultar reservas y cancelar previa confirmación (en término, sin penalidad). Respuestas de 1,8 a
    24 s; la conversación sigue con su id.
  - **Código:** #155 (ninguna falla de OpenRouter termina en 500 ni tarda más de 60 s por mensaje; cada falla deja
    `AG-01: <modelo> …` en el log de Render, sin la clave) y #157 (la tool de disponibilidad ya no pide destino, que
    el servicio no filtra, #8; el prompt pide texto plano).
  - **No verificado:** `derivar_humano` con el modelo real; el paso al fallback con modelos reales (solo con
    pruebas); los 10 casos de la PoC con estos modelos; la pantalla de Flutter con respuestas reales (se probó la
    API); si los 404 cuentan para la cuota. **El modelo a veces sigue usando negritas (`**`)** pese al prompt, y en
    la app se ven.
  - **Límites de OpenRouter (plan gratis):** 20 pedidos por minuto y **50 por día** (1000 si la cuenta compró al
    menos 10 USD de créditos). Cada mensaje usa 2 o 3 pedidos: unos 20 mensajes por día entre ensayo y demo. Los dos
    modelos son del mismo proveedor (NVIDIA): si se cae, el asistente deriva.
  - **Antes de la demo, obligatorio:** re-sembrar Neon con `--reiniciar`. `pasajero1` tiene canceladas reservas en
    los tres viajes de ida del 30/10 y, por MR-R15, no puede volver a reservar en ninguno. Y despertar la API 5
    minutos antes (`/api/health`).
  - **Pendientes del equipo (no se resolvieron acá):** cambiar el modelo aprobado en 07 §3 y los valores por
    defecto del repo (#154); actualizar 07 §5 (system prompt) y re-ejecutar la PoC, como pide 07 §9 (#156); qué
    recibe la persona cuando el agente deriva (#42).
- **Prueba de chofer contra Render (26/10, Martiniano; para la prueba real de Martín sobre #123).** Martín pidió
  confirmar backend, usuario y dataset antes de probar con su Flutter local: login → listado por fecha → detalle por
  ID → volver → cerrar sesión, **solo lectura** (sin iniciar/finalizar viajes, ausencias, abordajes, GPS ni cambios
  al dataset; sin guardar credenciales ni tokens en la evidencia).
  - **Panel de Render:** `vanfull-api` desplegado en **`f511d3c`** (merge del PR #157), Live; el SHA no se ve desde
    la API (solo `version: 0.1.0`), hay que mirarlo en Events. El sitio `vanfull` sigue en `c3d72aa` (rama
    `sitio-web`, compilado de `8380d19`): **sin entrada de chofer**, por eso la prueba va con Flutter local.
  - **Verificado con `chofer1@vanfull.test`** (contraseña por `getpass` en la terminal, fuera del chat): login 200 con
    `roles: ['chofer']`. `GET /choferes/me/viajes?fecha=2026-10-30` → 200 con los viajes **1** (07:30, IDA,
    programado, vehículo 1) y **3** (18:00, IDA, programado, sin vehículo), ambos `id_chofer` 3. Los detalles de 1 y
    3 → 200: capacidad 18, 3 paradas de prueba sin comprometer y **todas las cantidades en 0** (sin reservas,
    nómina ni abordajes). El detalle del viaje **2** (existe, sin chofer) → **404 `VIAJE_NO_ENCONTRADO`**, no 403:
    un viaje ajeno se trata como inexistente.
  - **No verificado:** el flujo en la app de Flutter (solo se probó la API); `GET /choferes/me/viajes` sin
    autenticación o con otro rol; que el SHA desplegado siga siendo `f511d3c` el día de la demo (hay que
    re-mirarlo); y, antes del 30/10, sigue obligatorio re-sembrar Neon con `--reiniciar` (ver arriba).
  - ⚠️ **Origen CORS temporal en Render (26/10, retirar).** Al probar #123, Martín recibió `400 Disallowed CORS
    origin` en el preflight del login desde `http://127.0.0.1:8140` (Flutter Web local). Martiniano agregó **solo ese
    origen exacto** a `CORS_ORIGINS` **en el panel de Render** (no en `render.yaml`), conservando los anteriores:
    `https://vanfull.onrender.com,https://martiherenu1.github.io,http://127.0.0.1:8140`. Verificado después del
    redeploy: preflight 200 con `access-control-allow-origin` desde ese origen y desde el de Render; un origen no
    listado (`:9999`) sigue en 400. **Al terminar la prueba de Martín, volver a dejar solo los dos primeros en el
    panel** (un cambio de `render.yaml` o una sincronización del Blueprint también lo revierte). No se verificó el
    login real desde el navegador de Martín.

## 14. Recursos

- **Repo:** https://github.com/Martiherenu1/ProyectoVanFull (**público**) · entrega congelada en el tag `pc1`
- **Tablero de los 37 CU (Notion):** https://app.notion.com/p/a05f244f1ab4438982da04067e2fe018
- **Drive del equipo:** documentación oficial. Los dos documentos que más se consultan para implementar:
  `03_Especificaciones_Casos_de_Uso_VanFull_v1.3_Aprobado_Equipo` (los 37 CU, con flujos alternativos y
  pendientes) y `02_Reglas_de_Negocio_VanFull_v1.1_Aprobado_Equipo` (las 31 RN). **Buscarlos por título**:
  la búsqueda por carpeta o por texto no los encuentra. Los `.md` equivalentes de la v1.3 están en la misma carpeta.
- **En este repo:** `Documentos/Documentacion/01..07`, `Documentos/HITOS.md`,
  `Documentos/Recursos/Stack-y-Referencias.md`, `backend/db/README.md`, `backend/openapi/README.md`
