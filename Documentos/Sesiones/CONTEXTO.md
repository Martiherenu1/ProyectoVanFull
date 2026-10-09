# CONTEXTO VANFULL — Carga rápida de sesión

> **Para qué sirve:** documento de arranque. Leyendo esto se recupera todo el contexto crítico del proyecto sin
> releer la documentación completa. **Mantenerlo actualizado al cerrar cada sesión.**
>
> **Al abrir un chat nuevo:** `CLAUDE.md` (raíz del repo) se carga solo y tiene las reglas fijas y los
> datos de esta máquina. Los prompts de arranque por tipo de tarea, y el criterio de cuándo conviene
> abrir un chat nuevo, están en `Documentos/Sesiones/PROMPT-INICIAL.md`.
>
> **Última actualización: 2026-10-08** · Reemplaza y consolida todas las versiones anteriores.

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
| **Hosting de costo 0** (decidido el 2026-10-02): BD en **Neon**, backend en **Render** (servicio web gratis), web Flutter en **GitHub Pages**. Desarrollo diario con `docker-compose.yml` | Alcance académico: sirve para la entrega; si el producto se vende se paga algo mejor. Se descartó Firebase (NoSQL, no calza con `schema.sql`), Supabase (pausa el proyecto a los 7 días sin uso) y la BD gratis de Render (vence a los 30 días y la borra). Usar la BD **solo como Postgres estándar**, sin SDK ni funciones propias del proveedor, para que mudarse sea cambiar `DATABASE_URL` + `pg_dump` |

## 8. Equipo y reparto

- **Integrante 2** → análisis: requisitos, casos de uso, UML/C4, modelo conceptual **y el DER/MR**. Llega como entrada.
- **Martiniano + su compañero** → **juntos, sin subdividir**: Integrante 1 (datos, backend, API, integraciones)
  **+** Integrante 3 (IA/agentes, frontend Flutter, modelo de desarrollo). Git y tablero los hacen igual.
- Los repartos formales de los documentos del equipo cambiaron varias veces → **no darles peso**; vale lo de arriba.

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

**Falta:** que Martiniano abra el Word a ojo (no se pudo renderizar acá), lo suba a la carpeta `07_` del Drive junto a la v1.0
(sin pisarla) y reemplace `07_README_PC1.docx` por la versión unida. Decisión tomada: los diagramas de actividad 018, 030, 028, 017
y 007 quedan con texto chico en papel (26-34 %); los PNG son de alta resolución y los originales están en la carpeta 04. Si
Martiniano edita el Word a mano, comparar antes de regenerarlo.

## 11. Estado del código

**Existe:** `main.py` (app + CORS + routers), `core/config.py` (variables de entorno), `core/database.py` (motor
async + `get_db`), `routers/health.py` (**el único endpoint real**), `agent/tools.py` (13 tools + system prompt),
`agent/openrouter_client.py` (cliente con fallback), `tests/test_health.py`, Dockerfile y docker-compose.

**No existe todavía:** `models/`, `schemas/` y `services/` están **vacíos**, y falta todo endpoint que no sea
`/health`. También falta `core/security.py` (JWT/roles) y Alembic. **Esto es esperable:** el backend se dejó para después de cerrar el documento v1.1 (decisión del 08/10; el cronograma lo preveía desde el 05/10).

**Plan cuando se programe:** `models/` (desde `schema.sql`, agrupados por dominio) → `services/` (reglas RN) →
`routers/` (endpoints del OpenAPI) → tests. Los 37 CU entran en ~10 routers, no uno por CU.

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

## 14. Recursos

- **Repo:** https://github.com/Martiherenu1/ProyectoVanFull (**público**) · entrega congelada en el tag `pc1`
- **Tablero de los 37 CU (Notion):** https://app.notion.com/p/a05f244f1ab4438982da04067e2fe018
- **Drive del equipo:** documentación oficial (ver memoria `drive-del-companero` para el mapa de carpetas e IDs)
- **En este repo:** `Documentos/Documentacion/01..07`, `Documentos/HITOS.md`,
  `Documentos/Recursos/Stack-y-Referencias.md`, `backend/db/README.md`, `backend/openapi/README.md`
