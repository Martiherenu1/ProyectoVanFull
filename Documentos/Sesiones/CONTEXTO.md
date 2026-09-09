# CONTEXTO VANFULL — Carga rápida de sesión

> **Propósito:** documento de arranque. Al empezar una sesión, este archivo me devuelve todo el
> contexto crítico del proyecto sin releer la documentación completa. Mantener actualizado al cerrar
> cada sesión (ver bloque "Estado actual" al final).
>
> Última actualización: **2026-08-31**

---

## 1. Qué es Vanfull

Empresa **real** de transporte de pasajeros (charters). Hoy opera con **WhatsApp + Excel + teléfono**.
El proyecto académico centraliza esa operatoria en una plataforma **Web + Mobile** con reservas, pagos,
notificaciones, seguimiento GPS, optimización de rutas y un agente conversacional de IA.

Servicios que presta: charter universitario, charter laboral, eventuales, ocasionales, empresas, turismo, especiales.

**Tres dolores priorizados por la empresa:** (1) control de reservas/cupos, (2) control de pagos
(el problema grave es *no detectar* un pago), (3) notificaciones a clientes.

## 2. Stack técnico (CERRADO por el equipo el 2026-08-27)

| Capa | Decisión | Nota |
|---|---|---|
| Frontend | **Flutter** (Web + Mobile) | misma base para ambas plataformas |
| Backend | **Python + FastAPI** | REST / JSON / OpenAPI |
| Base de datos | **PostgreSQL** | relacional, integridad transaccional |
| Mapas / rutas | **Google Maps Platform** (Routes API) | tránsito + waypoints + optimización de paradas |
| Pagos | **Mercado Pago** (entorno de PRUEBAS) | webhooks; sin cobros productivos |
| Gateway LLM | **OpenRouter** | permite rutear/fallback de modelos |
| LLM principal | **MiniMax M3 Free** (`minimax/minimax-m3:free`) | elegido por PoC |
| LLM fallback | **NVIDIA Nemotron 3 Super Free** (`nvidia/nemotron-3-super-120b-a12b:free`) | |
| Mensajería | **WhatsApp** (Cloud API probable) | config exacta pendiente |
| Control de versiones | **Git + GitHub** | flujo Issue→Branch→PR→Review→Merge |

## 3. Arquitectura en una frase

**Cliente-servidor por capas.** El frontend NO tiene reglas críticas de negocio. El agente de IA
**NO** accede a la base de datos: sólo llama *tools* de FastAPI. **FastAPI gobierna** auth, permisos,
cupos, pagos y validaciones. El LLM interpreta intención y elige herramienta; el backend decide.

```
Flutter (Web/Mobile)  →  REST/JSON/OpenAPI  →  FastAPI  →  Servicios de dominio  →  PostgreSQL / Integraciones
```

## 4. Alcance MVP

**Dentro:** pasajeros, clientes corporativos, reservas/cupos (con lista de espera), tipos de servicio,
tarifas/abonos, pagos y deuda, viajes, choferes y vehículos, abordaje por QR, GPS del servicio,
optimización de recorridos, WhatsApp + chatbot, notificaciones, reportes (export Excel/PDF).

**Fuera (límites explícitos):** integración con Uber, modificación libre del DNI por el pasajero,
acceso del chofer a contactos privados, confirmación manual de abordaje por el chofer, seguimiento
de toda la flota por pasajeros, cambio autónomo de rutas por la IA, validación 100% autónoma de pagos
por el LLM, integración fiscal (ARCA), Mercado Pago productivo.

**Extensión futura (NO MVP):** AG-02 (agente de asistencia operativa para admins), QR del chofer,
registro de combustible, gestión de mantenimiento de flota.

## 5. AG-01 — Agente conversacional (el corazón de la IA)

- **Usuarios:** pasajeros/clientes autorizados, desde la app y luego WhatsApp (mismo agente en ambos canales).
- **Acceso a datos:** indirecto, sólo vía tools de FastAPI. Nunca toca PostgreSQL directo.
- **11 tools previstas:** `consultar_disponibilidad`, `consultar_horarios`, `consultar_recorridos`/`consultar_paradas`,
  `consultar_tarifa`, `consultar_estado_pago`/`consultar_deuda`, `consultar_reserva`, `crear_reserva`,
  `cancelar_reserva`, `consultar_estado_viaje`, `consultar_ubicacion_vehiculo`, `derivar_humano`.
- **Reglas de oro:** no inventa cupos/horarios/tarifas/pagos; no modifica estados de pago; no revela
  datos de terceros; si faltan datos los pide; deriva a humano si no puede resolver seguro.
- **Hallazgo PoC clave:** las fechas relativas ("mañana") **NO** se dejan al modelo → FastAPI inyecta
  fecha/hora determinística en el contexto.

## 6. Decisiones cerradas en sesión (2026-08-31)

- **Repositorio:** **Monorepo** en GitHub (`/backend` FastAPI + `/frontend` Flutter).
- **Hosting:** **Railway / Render** (free/low-cost, PostgreSQL gestionado, deploy desde GitHub).
- **GPS tiempo real:** **Polling controlado para el MVP** (chofer publica por REST; consumidores hacen
  GET cada 5–10 s). SSE como plan B de optimización; WebSocket sólo si surge caso bidireccional real.
  El transporte es intercambiable sin tocar el modelo conceptual.

## 6b. Decisiones aún abiertas

- **Sincronización offline del QR de abordaje:** pendiente.
- **RNF completos:** rendimiento, concurrencia, disponibilidad, auth/sesiones/cifrado/auditoría.
- **Config WhatsApp:** cuenta, plantillas, costos.
- **¿Código ya iniciado?:** por confirmar.

## 6c. Cronograma (detalle en `Documentos/Documentacion/02-Cronograma.md`)

Hoy 2026-08-31 = **Semana 5** (Relevamiento y análisis funcional). Hitos clave:
- **28/09 → 1er Punto de Control.** Antes hay que producir: UML (sem 6, 07/09), DER + diccionario de
  datos (sem 7, 14/09), contratos OpenAPI (sem 8, 21/09). La parte de IA (LLM + AG-01) ya está mayormente hecha.
- **26/10 → 2do PC.** Desarrollo backend (sem 10, 05/10), frontend (sem 11, 12/10), integración (sem 12, 19/10).
- **09/11 → 3er PC.** Pruebas + documentación (sem 14, 02/11). **16/11 → Cierre.**
- **Estado:** el equipo va **adelantado** (el doc del PC1 ya cubre relevamiento y diseño de IA).

## 7. Mi rol (Martiniano)

Estudiante de 4º año de Ing. en Informática. Equipo de 3.

**Reparto de tareas (PC1)** — ver `Documentos/Documentacion/04-Reparto-Tareas-y-Plan-Int1-3.md`:
- **Integrante 2** = el de requerimientos: Modelo Conceptual, MVC, C4, **casos de uso**, secuencia, Mermaid,
  **wireframes**. → NO es nuestro foco (lo hace él). Lo usamos como entrada.
- **Martiniano + compañero** toman **juntos** todo **Integrante 1** (Datos+Backend/API: DER, PostgreSQL,
  diccionario de datos, OpenAPI/endpoints, pagos+GPS, servicios para agentes) **+ Integrante 3** (IA+Agentes:
  LLM, System Prompts, Function Calling, PoC agentes, **Git/GitHub+tablero**, cronograma/hitos). Sin subdividir 1 y 3.
- ⚠ Ojo: **casos de uso / UML / wireframes NO son nuestros** (son de Int2). Nuestro foco es backend + datos + IA.
- 📥 **Int2 también hace el DER y nos lo pasa**, junto con **todos los casos de uso con especificación**.
  → Son ENTRADAS. Nuestro DER v0.1 es borrador provisional a conciliar con el oficial. Nosotros IMPLEMENTAMOS
  (ORM, servicios, endpoints, OpenAPI). Mientras esperamos el DER, avanzamos con lo independiente: Git/GitHub,
  PoC de agentes (tools mockeadas), diseño pagos/GPS.

## 8. Cómo trabajamos juntos (contrato de colaboración)

- Soy socio técnico experto en ESTE proyecto: decisiones de arquitectura, revisión de código, mejoras.
- Documento logros en `HITOS.md` (para el CV de Martiniano).
- Mantengo este `CONTEXTO.md` actualizado para carga rápida entre sesiones.
- **Layout del repo (2026-08-31):** en la **raíz** sólo va código y config (`backend/`, `frontend/`,
  `docker-compose.yml`, `.gitignore`, `README.md`). **TODA la documentación que no es código vive en `Documentos/`**:
  `Documentos/Documentacion/` (análisis, requisitos, DER, casos de uso), `Documentos/Recursos/` (referencias
  técnicas), `Documentos/Sesiones/` (este CONTEXTO), `Documentos/HITOS.md`, y los `.docx` fuente. Todo doc nuevo va acá.

---

## Novedades del Drive — 2026-09-08

**Int2 ya subió el DER y los casos de uso (lo que esperábamos). Se puede arrancar la Fase B.**

- **DER oficial** → `05_Arquitectura_API_Datos/`: `VanFull_MR_Entidades_y_Relaciones_Revision_Equipo.md`
  (modelo relacional, id `1yG3-pO8mx7FL_WQ1tuUV080rx6a4kj7f`), `DER_VanFull_General.drawio` (+ "Sin Paquetes"),
  `MR_VanFull_General.png`, `DER General.puml`. → **conciliar con nuestro DER v0.1**.
- **Casos de uso** → `03_Actores_y_Casos_de_Uso/`: `03_Especificaciones_Casos_de_Uso...md` (82 KB,
  id `1zuiWtzw_obUKFX-x8AcGBJJe1OyPR4Yh`) + DCU por actor (Pasajero/Corporativo/Chofer/Admin/Dueño/Integraciones)
  `.puml`+`.png` + `03_Cierre_Etapa_03`.
- **Modelo/UML** → `04_Modelo_y_UML/`: Modelo Conceptual, `Cardinalidades.xlsx`, Diagramas de Actividad, PUML etapa 04.
- **Guías/prompts por integrante** (raíz): `Guia_Integrante_1_Backend_API_Datos`, `Guia_Integrante_3_Frontend_IA`
  (`.docx`), `PROMPT_Integrante_1_...`, `PROMPT_Integrante_3_...` (`.md`), `README_VanFull.md`.
  → **leer las de Int1 e Int3 para alinear expectativas del compañero**. (Aún NO ingeridas en detalle.)
- Carpetas 00, 06, 07 siguen vacías. 01 y 02 sin cambios.
- **Pendiente inmediato:** ingerir DER oficial + casos de uso → conciliar DER v0.1 → arrancar EPIC C/D del roadmap.

## Ingesta 2026-09-08 — LEÍDO y anotado (detalle en `Documentos/Documentacion/06-Notas-Ingesta-Drive-2026-09-08.md`)

- **DER/MR oficial (35 tablas, 5 bloques)** ya leído. **Nuestro `03-Modelo-de-Datos-DER-v0.1.md` queda OBSOLETO.**
  Confirma nuestras 2 decisiones clave: reservas materializadas por viaje (MR-R15/16) y deuda/cupo/saldo derivados (MR-R30).
  Nuevos conceptos: SERVICIO(4 tipos), CONTRATACION, NOMINA/INTEGRANTE_NOMINA (especiales), MOVIMIENTO_CUENTA+COMPROBANTE, EVENTO_OPERATIVO.
- **Casos de uso oficiales:** 9 actores (ACT-01..09) + 37 CU (CU-001..037), Etapa 03 CERRADA. Fuente para endpoints/OpenAPI y tools.
- **Roles — RESUELTO (Martiniano, 08/09):** no dar peso a la distribución formal de los prompts. **Int1 e Int3 se juntan
  y hacen todo junto** (backend + API + integraciones + **Frontend Flutter** + IA/agentes). **GitHub/tablero se hace igual.**
  Los prompts nuevos ponen Frontend en Int3 y no asignan Git, pero eso no aplica a cómo trabajamos nosotros.
- Ambas guías/prompts insisten: **definir OpenAPI ANTES de implementar** (Int1 define, Int3 consume, mocks mientras tanto).
- **No se implementó nada** — solo lectura y anotación, por pedido de Martiniano.
- **Lectura profunda 2026-09-08:** leídos al 100% los **37 CU** (flujos + pendientes + matriz RF→CU), el **MR de 35
  tablas** (MR-R01..R32), las **51 cardinalidades** y las notas del modelo conceptual. Detalle en `06-Notas-Ingesta...`
  §6 (mapa CU por actor, mapa tools AG-01→CU, RNF, pendientes abiertos). Los `.puml/.drawio/.png` no se decodificaron
  (versión visual del mismo contenido).
- **14 RNF + métricas leídos completos** (§6.4): disp 99% mensual, 95% ops ≤2s, ops pesadas ≤5s, 100 concurrentes
  (pico 150), escalabilidad ≥2×, GPS 10s/50m/>30s desactualizada, QR sync ≤60s sin duplicados, RTO ≤1h, RPO ≤15min.
  Pendientes (no inventar): seguridad/auth detallada, privacidad, retención, auditoría (propuesta).
- **Toda la documentación funcional del PC1 está ahora ingerida** (RF, RNF, RN, alcance, AS-IS, 37 CU, DER/MR, cardinalidades, RNF).
- **Pre-commit (2026-09-08):** revisada la estructura del repo contra los docs definidos. Agregados: `backend/pyproject.toml`
  (ruff+pytest), `CONTRIBUTING.md` (flujo Issue→Branch→PR + Conventional Commits), `backend/.dockerignore`, `ruff` en requirements.
  `.gitignore` ahora ignora `.docx/.doc/.xlsx` (viven en Drive). **ORM decidido: SQLAlchemy 2.0 async + Alembic** (no Prisma/SQLModel).
- **Diferido al 1er PR de modelos:** Alembic env, los 35 modelos ORM/schemas/servicios (por dominio: personas/servicios/viajes/economia/operacion),
  integraciones y auth.
- **✅ `git init` + primer commit HECHO (2026-09-08):** rama `main`, 36 archivos, commit `chore: scaffold inicial...`.
  Falta: crear repo en GitHub y `git push` (lo hace Martiniano con su cuenta; `gh` CLI no está instalado → vía web + remote).
  Luego arranca el 1er PR: modelos ORM del DER oficial (35 tablas).

## Estado actual (actualizar al cerrar cada sesión)

- **Sesión 2026-08-31:** Ingesté el documento consolidado del PC1 (`Documentacion Grupo 5 (1).docx`).
  Creé la estructura de carpetas, `HITOS.md`, este `CONTEXTO.md`, el análisis consolidado y las referencias técnicas.
- **Decisiones cerradas hoy:** monorepo, hosting Railway/Render, GPS por polling controlado en MVP.
- **Próximos pasos sugeridos:** (a) esqueleto del monorepo (`/backend` FastAPI + `/frontend` Flutter + README + .gitignore);
  (b) modelo de datos PostgreSQL (entidades se infieren del alcance); (c) contrato OpenAPI de las 11 tools de AG-01.
- **Cronograma ingerido** (`Cronograma_VanFull.docx` → `Documentos/Documentacion/02-Cronograma.md`). PC1 = 28/09.
- **Drive del compañero ingerido** (martindefez@gmail.com). Carpeta raíz `1wdCXRe6cWQaNdE1oQfnpU0cJGzholtWp`.
  Leídos: 45 RF, 31 RN, AS-IS consolidado, cuadro tarifario, pendientes, Instrucciones.txt (guía de gobernanza).
  Subcarpetas 03–07 (Casos de Uso, UML, Arquitectura/API/Datos, IA, PC1) están **vacías** → es lo que falta producir.
- **Nomenclatura estándar del proyecto** (del Instrucciones.txt): RF / RNF / RN / CU / ACT / INT, con trazabilidad
  Necesidad → Requisito → RN → CU → Interfaz → API → Datos → Prueba.
- **Esperando de Martiniano:** si ya hay código iniciado.
- **DER v0.1 (borrador)** creado en `Documentos/Documentacion/03-Modelo-de-Datos-DER-v0.1.md` — ~24 entidades con
  Mermaid + diccionario + trazabilidad RF/RN + 5 decisiones de modelado abiertas. **Pendiente de revisión del equipo.**
- **Monorepo scaffolded** (no había repo/código): `backend/` (FastAPI por capas + AG-01 stub + Docker) y
  `frontend/` (README con estructura Flutter; Flutter/Dart NO instalados). `docker-compose.yml`, `.gitignore`, READMEs.
  Sintaxis Python verificada. **Git NO se inicializa todavía — decisión de Martiniano: `git init` + primer
  commit + GitHub se hacen cuando el DER esté definido**, para que el primer commit lleve el scaffold completo con modelos ORM.
- **Entorno:** Python 3.14 local (backend corre en Docker con 3.12), Docker+Compose OK, Git OK, Flutter/Dart faltan.
- **Próximo trabajo hacia PC1:** validar DER → casos de uso (CU) + UML → contratos OpenAPI. Setup Git/GitHub.
- **Decisión de modelado #1 a resolver:** recurrencia del charter (materializar reservas por viaje vs abono ocupa cupo).
- **Roadmap completo Int1+3** en `Documentos/Documentacion/05-Roadmap-Tareas-Int1-3.md` — 92 tareas (T-001..T-092)
  en orden de ejecución, agrupadas en Epics A-O, con responsable/dependencias/RF-RN. Es el backlog para pasarle
  al compañero y cargar como issues. EPIC B (PoC agente + convenciones + diseño integraciones) es lo que se hace YA.
