# CONTEXTO VANFULL — Carga rápida de sesión

> **Para qué sirve:** documento de arranque. Leyendo esto se recupera todo el contexto crítico del proyecto sin
> releer la documentación completa. **Mantenerlo actualizado al cerrar cada sesión.**
>
> **Última actualización: 2026-09-23** · Reemplaza y consolida todas las versiones anteriores.

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
| Hosting previsto | **Railway / Render** |

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
- **11 tools**, todas trazadas a un CU y a un endpoint → `Documentos/Documentacion/07-IA-y-Agentes-Consolidado.md`.
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

## 8. Equipo y reparto

- **Integrante 2** → análisis: requisitos, casos de uso, UML/C4, modelo conceptual **y el DER/MR**. Llega como entrada.
- **Martiniano + su compañero** → **juntos, sin subdividir**: Integrante 1 (datos, backend, API, integraciones)
  **+** Integrante 3 (IA/agentes, frontend Flutter, modelo de desarrollo). Git y tablero los hacen igual.
- Los repartos formales de los documentos del equipo cambiaron varias veces → **no darles peso**; vale lo de arriba.

## 9. Cronograma (detalle en `02-Cronograma.md`)

**PC1 = 28/09/2026** · PC2 = 26/10 · PC3 = 09/11 · Cierre = 16/11.
El desarrollo del backend arranca el **05/10** (sem 10); frontend 12/10; integración 19/10; pruebas y documentación 02/11.

## 10. Estado del PC1 (al 2026-09-25)

**La consigna pide** (de `Presentacion.pdf`): definición del problema, alcance y límites, modelo conceptual
(Front/Back/BD), UML/C4, **Modelo de datos SQL**, **Comunicación V-C: OpenAPI (JSON)**, selección de modelos IA +
agentes + prompts, mermaid.js, y modelo de desarrollo + interfaces gráficas. **Entrega: "Documento con el MVC".**

### Nuestra parte: TERMINADA

| Entregable | Estado |
|---|---|
| **Modelo de datos SQL** | `backend/db/schema.sql` — 35 tablas, 54 FKs, **validado contra PostgreSQL real** |
| **Contrato OpenAPI** | `backend/openapi/openapi.yaml` — 22 operaciones, 22 schemas, validado |
| **Doc IA y Agentes** | `07-IA-y-Agentes-Consolidado.md` — también subida al Drive `06_` |
| **Modelo de desarrollo** | Repo + ramas/PR + ruff/pytest + `CONTRIBUTING.md` |
| **Interfaces gráficas** | **10 pantallas** con los 3 actores, recorribles en modo Play (ver abajo) |

### Los artefactos de diseño viven en claude.ai (⚠️ los links solo están acá)

| Qué | Link |
|---|---|
| **Pantallas VanFull** — las 10 pantallas del PC1, navegables | https://claude.ai/artifact/6M3yj4nmLnqaCoM6BqY4Ui |
| **Sistema de diseño VanFull** — tokens, 4 componentes, marca | https://claude.ai/artifact/6ptGhgioyJSHZeCBv1eRaG |

Las reglas y el porqué de todo eso están versionados en `Documentos/Documentacion/08-Brief-de-Diseno-UI.md`.
Las 10 pantallas: Login · Buscar servicio · Confirmar reserva · Mis reservas y deuda · Pago ·
Seguimiento en vivo · Asistente AG-01 · Chofer (lista) · Chofer (escaneo QR) · Admin (viajes del día).

### Falta — es del equipo, no nuestro

1. **Diagramas en mermaid.js** (hay PlantUML/drawio; confirmar si se acepta).
2. **"Documento con el MVC"** — *el* entregable: consolidar todo el diseño mostrando Modelo (BD + reglas) /
   Vista (Flutter) / Controlador (FastAPI). **Crítico.**
3. **Consolidar en la carpeta `07_PC1`** del Drive (está vacía).
4. **Revisión cruzada de Int2:** que valide que el SQL y el OpenAPI concuerdan con su DER y sus CU.
5. **Logística:** compartir el repo con la cátedra (hoy es privado), roles por escrito, y organizar la presentación.

## 11. Estado del código

**Existe:** `main.py` (app + CORS + routers), `core/config.py` (variables de entorno), `core/database.py` (motor
async + `get_db`), `routers/health.py` (**el único endpoint real**), `agent/tools.py` (11 tools + system prompt),
`agent/openrouter_client.py` (cliente con fallback), `tests/test_health.py`, Dockerfile y docker-compose.

**No existe todavía:** `models/`, `schemas/` y `services/` están **vacíos**, y falta todo endpoint que no sea
`/health`. También falta `core/security.py` (JWT/roles) y Alembic. **Esto es esperable:** el desarrollo arranca el 05/10.

**Plan cuando se programe:** `models/` (desde `schema.sql`, agrupados por dominio) → `services/` (reglas RN) →
`routers/` (endpoints del OpenAPI) → tests. Los 37 CU entran en ~10 routers, no uno por CU.

## 12. Cómo trabajamos (acordado el 2026-09-22)

Martiniano pidió **tener el control y entender el código**, no sólo aprobar lo que se hace. Por lo tanto:

1. **Explicar antes de hacer** — qué archivo, por qué, y qué hace cada parte.
2. **Pasos chicos y revisables**, un concepto por vez.
3. **Mostrar el contenido o el diff antes** de commitear o mergear.
4. **Explicar los comandos** que se corren, no sólo pegar el resultado.
5. Invitarlo a mirar y editar en VS Code, y a escribir partes él.

## 13. Pendientes abiertos (no inventar: requieren definición del equipo o externa)

Sincronización offline del QR · identificación/autenticación del chatbot para datos sensibles · política de sesiones,
cifrado y recuperación de cuenta · auditoría (es **propuesta**, no aprobada) · privacidad y retención de datos (legal) ·
detalle fiscal/ARCA · configuración de WhatsApp (cuenta, plantillas, costos) · campos editables del perfil ·
prioridad de la lista de espera · criterio de liberación de cupo por ausencia · fallback de la optimización de rutas.

## 14. Recursos

- **Repo:** https://github.com/Martiherenu1/ProyectoVanFull (privado)
- **Tablero de los 37 CU (Notion):** https://app.notion.com/p/a05f244f1ab4438982da04067e2fe018
- **Drive del equipo:** documentación oficial (ver memoria `drive-del-companero` para el mapa de carpetas e IDs)
- **En este repo:** `Documentos/Documentacion/01..07`, `Documentos/HITOS.md`,
  `Documentos/Recursos/Stack-y-Referencias.md`, `backend/db/README.md`, `backend/openapi/README.md`
