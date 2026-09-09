# Roadmap detallado de tareas — Integrante 1 + 3 (Vanfull)

> **Para:** el compañero de Martiniano. **Scope:** todo lo que hacemos **juntos** = Integrante 1
> (Datos + Backend/API) + Integrante 3 (IA + Agentes + Modelo de Desarrollo). **NO incluye** lo de
> Integrante 2 (modelo conceptual, MVC, C4, casos de uso, secuencia, wireframes) — eso lo hace él y nos
> pasa el **DER** y los **casos de uso con especificación** como entradas.
>
> **Cómo leer:** las tareas van en **orden de ejecución** (T-001, T-002…). Cada una indica responsable
> sugerido, de qué depende y a qué RF/RN responde. Los ✅ ya están hechos de sesiones previas.
> Meta: **1er Punto de Control = 28/09/2026** · 2do PC = 26/10 · 3er PC = 09/11 · Cierre = 16/11.
>
> **Referencias:** [DER borrador](03-Modelo-de-Datos-DER-v0.1.md) · [Reparto de tareas](04-Reparto-Tareas-y-Plan-Int1-3.md)
> · [Stack y tools](../Recursos/Stack-y-Referencias.md)

**Leyenda de responsable:** `[1]` Datos/Backend · `[3]` IA/Dev · `[1+3]` compartida · `[←Int2]` depende de entrega de Int2.

---

## EPIC A — Fundaciones (ya establecidas)
*Estado base sobre el que construimos. La mayoría ✅.*

- ✅ **T-001** `[1+3]` Stack y arquitectura definidos (Flutter, FastAPI, PostgreSQL, OpenRouter, Google Maps, MP, WhatsApp).
- ✅ **T-002** `[1]` Scaffold del monorepo (`backend/` por capas, `frontend/`, `docker-compose`, `.gitignore`, READMEs).
- ✅ **T-003** `[3]` Selección y justificación del LLM (PoC MiniMax M3 / Nemotron con matriz ponderada).
- ✅ **T-004** `[3]` Definición de AG-01: 11 tools en formato function-calling + System Prompt base.
- ✅ **T-005** `[3]` Cliente OpenRouter con fallback (stub) + cronograma e hitos (`HITOS.md`).

---

## EPIC B — Trabajo independiente del DER (HACER AHORA · sem 6-7)
*No necesita el DER oficial de Int2. Nos deja algo ejecutable para el PC1.*

### B.1 — Convenciones y entorno
- ⬜ **T-006** `[1+3]` Fijar convenciones de código: `ruff` (lint+formato), estructura de imports, nombres en `snake_case`, idioma de comentarios (ES). Agregar `pyproject.toml` con config de ruff/pytest.
- ⬜ **T-007** `[1+3]` Definir convención de ramas y commits (Conventional Commits: `feat:`, `fix:`, `docs:`…) y plantilla de PR. Documentar en `CONTRIBUTING.md`.
- ⬜ **T-008** `[1]` Confirmar flujo de desarrollo local: `docker compose up` levanta Postgres + API; documentar troubleshooting de Python 3.14 vs 3.12.

### B.2 — PoC ejecutable del agente AG-01 (tarea estrella de Int3)
- ⬜ **T-009** `[3]` Completar el cliente OpenRouter: manejo de `tool_calls` en la respuesta, reintento con fallback, timeouts y logging de errores de proveedor.
- ⬜ **T-010** `[3]` Implementar el **loop de Function Calling**: mensaje usuario → LLM elige tool → ejecutar tool → devolver resultado al modelo → respuesta final en lenguaje natural.
- ⬜ **T-011** `[1+3]` **Tools mockeadas**: implementar las 11 tools devolviendo datos de prueba (sin BD), para validar el loop de punta a punta. (RF-029..032)
- ⬜ **T-012** `[3]` **Inyección de fecha/contexto determinístico**: el backend resuelve "hoy/mañana" antes de ejecutar tools (hallazgo de la PoC). Nunca delegar la fecha al modelo.
- ⬜ **T-013** `[3]` Endpoint `POST /api/chat`: recibe mensaje + contexto de usuario, corre el loop, responde. Con manejo de `derivar_humano()`.
- ⬜ **T-014** `[3]` **Modo mock sin API key**: simular la elección de tool para poder demostrar/testear offline. Flag por variable de entorno.
- ⬜ **T-015** `[3]` Tests automáticos del agente: reusar los 10 casos **TC-01..TC-10** (disponibilidad, horarios, tarifa, reserva, cancelación, pago, seguridad de pago, privacidad/prompt-injection, fuera de alcance, derivación).
- ⬜ **T-016** `[3]` Guardar la PoC como evidencia para el PC1 (resultados, capturas, breve informe).

### B.3 — Diseño (sin implementar) de integraciones
- ⬜ **T-017** `[1]` Documentar el **flujo de Mercado Pago** (sandbox): creación de preferencia/checkout, recepción de webhook, actualización de estado, y el punto de confirmación humana (RN-015). (RF-012)
- ⬜ **T-018** `[1]` Documentar el **flujo de GPS**: el chofer publica posición por REST, el backend autoriza (RN-030), consumidores leen por **polling** (decisión ya tomada). ETA vía Google Maps. (RF-021/022)
- ⬜ **T-019** `[1]` Documentar el **flujo de WhatsApp** para AG-01: webhook entrante, plantillas, derivación a humano (pendiente INT-001).
- ⬜ **T-020** `[1]` Crear proyecto en **Google Cloud** + habilitar Routes API + API key con **cuotas/alertas** para no gastar (RF-020).

---

## EPIC C — Recepción y conciliación del DER (cuando Int2 lo entregue · sem 7)
- ⬜ **T-021** `[1] [←Int2]` Recibir el **DER oficial** y los **casos de uso con especificación** de Int2.
- ⬜ **T-022** `[1]` **Conciliar** el DER oficial con nuestro borrador v0.1: comparar entidades, atributos, relaciones y las 5 decisiones de modelado abiertas (recurrencia charter, tarifa snapshot, PK, deuda/cupo derivados, ida+vuelta).
- ⬜ **T-023** `[1]` Cerrar el **diccionario de datos** (tipos, nullabilidad, unicidad, defaults) si Int2 no lo entrega completo.
- ⬜ **T-024** `[1]` Validar cobertura: cada RF que toca datos tiene entidad/campos; marcar faltantes y devolver feedback a Int2.

---

## EPIC D — Capa de datos / persistencia (sem 7-8)
- ⬜ **T-025** `[1]` Configurar **Alembic** para migraciones (`alembic init`, `env.py` async apuntando a `DATABASE_URL`).
- ⬜ **T-026** `[1]` Modelos ORM SQLAlchemy — **núcleo**: `Usuario`, `Pasajero`, `ClienteCorporativo`, `ContactoEmpresa`, `Administrador`, `Chofer`, `Vehiculo`.
- ⬜ **T-027** `[1]` Modelos ORM — **servicios y viajes**: `TipoServicio`, `Recorrido`, `Parada`, `ServicioProgramado`, `Viaje`.
- ⬜ **T-028** `[1]` Modelos ORM — **reservas y abonos**: `Reserva`, `Abono`, `ListaEspera`, `Abordaje`, `Ausencia`.
- ⬜ **T-029** `[1]` Modelos ORM — **dinero**: `Tarifa`, `Pago`, `CreditoReintegro`, `Factura`.
- ⬜ **T-030** `[1]` Modelos ORM — **operación**: `UbicacionGPS`, `Notificacion`.
- ⬜ **T-031** `[1]` Primera **migración** y verificación de creación del esquema en Postgres.
- ⬜ **T-032** `[1]` **Seeds** de datos de prueba: tipos de servicio, tarifas del cuadro tarifario real (universitario ene-mar 2026), un recorrido con paradas, vehículos, un viaje.
- 🚩 **T-033 — HITO: `git init` + primer commit** `[3]` del scaffold **completo con modelos ORM** (decisión de Martiniano). Luego: crear repo en GitHub, subir, proteger `main`.

---

## EPIC E — Servicios de dominio / reglas de negocio (sem 8-10)
*Aquí viven las RN-001..031. El agente y la API los consumen; no se duplican en routers.*
- ⬜ **T-034** `[1]` Servicio de **disponibilidad/cupos**: capacidad − reservas consolidadas; bloquear sobreventa; lista de espera. (RN-001, RN-002)
- ⬜ **T-035** `[1]` Servicio de **reservas**: crear/cancelar; estados provisional/consolidada; restricción 1 ida + 1 vuelta por día. (RF-005/006, RN-031)
- ⬜ **T-036** `[1]` Servicio de **abonos**: alta, período de pago (días 1-10), advertencia/suspensión (11-13), pérdida de cupo (>13), habilitación excepcional 5 días, reserva anual estudiantil. (RN-003..009, RF-044)
- ⬜ **T-037** `[1]` Servicio de **tarifas**: determinar tarifa por tipo/modalidad/días; descuento 15% efectivo; snapshot al reservar; actualización no afecta lo pagado. (RN-010..014, RF-028)
- ⬜ **T-038** `[1]` Servicio de **pagos**: registrar total/parcial/seña; pago por terceros asociado a cuenta; confirmación humana. (RF-009/011, RN-015/016)
- ⬜ **T-039** `[1]` Servicio de **deuda**: cálculo derivado; límite = 1 mes de abono, no ampliable; suspensión/habilitación. (RN-004/005/006, RF-010)
- ⬜ **T-040** `[1]` Servicio de **cancelaciones y créditos**: ocasional (crédito del mes), especial (50%/devolución según 7 días), cancelación por VanFull (100%). (RN-017/018/019, RF-013)
- ⬜ **T-041** `[1]` Servicio de **abordaje QR**: validar servicio/parada/horario/habilitación; registro offline + sincronización (cola, duplicados). (RF-014/015, RN-023, TEC-003)
- ⬜ **T-042** `[1]` Servicio de **ausencias**: registrar, aviso previo libera cupo temporal, sin penalización con abono al día. (RF-016, RN-024/025)
- ⬜ **T-043** `[1]` Servicio de **viajes/recorridos/paradas**: crear/modificar; cambio de parada sujeto a disponibilidad; modificación operativa respetando paradas comprometidas. (RF-017/018/019, RN-020/021/022)
- ⬜ **T-044** `[1]` Servicio de **permisos/roles**: dueño/admin/chofer/pasajero/corporativo; operaciones exclusivas del dueño; chofer sin datos de contacto; corporativo sólo su empresa. (RN-026..030)

---

## EPIC F — API REST / endpoints / OpenAPI (sem 8-10)
*Derivados de los casos de uso de Int2. Routers finos: delegan en servicios.*
- ⬜ **T-045** `[1] [←Int2]` Mapear casos de uso → endpoints (matriz CU ↔ endpoint).
- ⬜ **T-046** `[1]` **Auth**: `POST /auth/login`, `/auth/logout`, refresh; JWT; dependencia de usuario actual. (RF-045)
- ⬜ **T-047** `[1]` **Pasajeros**: CRUD + autoservicio (sin editar DNI) + gestión administrativa. (RF-001/002/042, RN-026)
- ⬜ **T-048** `[1]` **Reservas y cupos**: consultar disponibilidad, crear, cancelar, lista de espera, cambio de parada. (RF-004..008/043)
- ⬜ **T-049** `[1]` **Pagos y deuda**: registrar pago, confirmar, consultar deuda, créditos/reintegros. (RF-009..013)
- ⬜ **T-050** `[1]` **Viajes/recorridos/paradas/asignaciones**. (RF-017..019)
- ⬜ **T-051** `[1]` **Choferes y vehículos**. (RF-023..026)
- ⬜ **T-052** `[1]` **Tarifas** (gestión + cálculo). (RF-027/028)
- ⬜ **T-053** `[1]` **Empresas**: clientes corporativos + ABM de sus pasajeros + vista pasajero empresarial. (RF-034..036)
- ⬜ **T-054** `[1]` **Abordaje QR** (registro + sync offline). (RF-014..016)
- ⬜ **T-055** `[1]` **Reportes**: reservas pendientes, pasajeros por viaje, ingresos, ocupación, cancelaciones + export Excel/PDF. (RF-038..040)
- ⬜ **T-056** `[1]` Revisar/documentar el **OpenAPI** generado (tags, ejemplos, versionado `/api`).

---

## EPIC G — Integración Mercado Pago (sandbox) (sem 10-12)
- ⬜ **T-057** `[1]` Crear cuentas/credenciales de **prueba** de Mercado Pago; cargar en `.env`.
- ⬜ **T-058** `[1]` Crear preferencia / iniciar checkout desde el backend. (RF-012)
- ⬜ **T-059** `[1]` **Webhook receiver** `POST /webhooks/mercadopago` + verificación de autenticidad.
- ⬜ **T-060** `[1]` Actualizar estado de pago según el evento; enganchar con confirmación humana (el LLM no aprueba pagos). (RN-015)
- ⬜ **T-061** `[1]` Tests del flujo de pago en sandbox (aprobado/rechazado/pendiente).

---

## EPIC H — GPS + Google Maps (sem 10-12)
- ⬜ **T-062** `[1]` Endpoint para que el **chofer publique ubicación** durante el servicio. (RF-021)
- ⬜ **T-063** `[1]` Endpoint de **consulta de ubicación** por polling, autorizado sólo a usuarios del viaje. (RF-022, RN-030)
- ⬜ **T-064** `[1]` **ETA / tiempo restante** vía Google Maps. (RF-022)
- ⬜ **T-065** `[1]` **Optimización de recorridos** con Routes API respetando paradas obligatorias + intervención manual del admin. (RF-020)
- ⬜ **T-066** `[1]` Manejo de pérdida de conectividad del GPS (tolerancia, última posición conocida). (TEC-002)

---

## EPIC I — Agente AG-01 completo (sem 10-12)
- ⬜ **T-067** `[1+3]` **Conectar las 11 tools a los servicios reales** (reemplazar los mocks de la PoC).
- ⬜ **T-068** `[3]` System Prompt final + inyección de contexto de usuario autenticado (permisos, identidad).
- ⬜ **T-069** `[3]` Refuerzos de seguridad: no exceder cupo, no revelar datos de terceros, no modificar pagos, validar todo en backend.
- ⬜ **T-070** `[1+3]` **Canal WhatsApp**: webhook entrante, envío de respuestas, plantillas, mismo AG-01 que la app. (RF-029..032, INT-001)
- ⬜ **T-071** `[3]` Re-correr los casos TC-01..10 contra los servicios reales; documentar resultados.

---

## EPIC J — Notificaciones (sem 11-12)
- ⬜ **T-072** `[1]` Motor de notificaciones (app + WhatsApp), con registro de estado. (RF-033)
- ⬜ **T-073** `[1]` Disparadores por evento: confirmación de reserva, confirmación de pago, recordatorio, proximidad, demora, cambio de horario/vehículo, cancelación. (RF-033)

---

## EPIC K — Seguridad, permisos y auditoría (transversal · sem 9-12)
- ⬜ **T-074** `[1]` Hashing de contraseñas (passlib/bcrypt) + emisión/validación JWT. (RF-045, TEC-005)
- ⬜ **T-075** `[1]` Autorización por rol en cada endpoint (dependencias FastAPI). (RN-026..030)
- ⬜ **T-076** `[1+3]` Protección de datos sensibles: no enviar DNI/fotos/contactos de terceros al LLM; identificadores internos. (EXT-002/003)
- ⬜ **T-077** `[1]` Auditoría de cambios sobre tarifas, pagos, reservas, deuda, permisos (tablas de log). (TEC-006)

---

## EPIC L — Testing (transversal, continuo)
- ⬜ **T-078** `[1]` Tests unitarios de los servicios de dominio (cada RN con casos límite).
- ⬜ **T-079** `[1]` Tests de integración de endpoints (con BD de prueba).
- ⬜ **T-080** `[3]` Tests del agente (loop mock + casos TC).
- ⬜ **T-081** `[1+3]` Objetivo de cobertura y ejecución en CI.

---

## EPIC M — Modelo de desarrollo: GitHub + tablero + CI (Int3)
*El `git init` es T-033 (al tener el DER). Esto lo completa.*
- ⬜ **T-082** `[3]` Crear **tablero** (GitHub Projects) con columnas To do / In progress / Review / Done y cargar estas tareas como **issues**.
- ⬜ **T-083** `[3]` Configurar **CI** (GitHub Actions): lint (ruff) + tests (pytest) en cada PR.
- ⬜ **T-084** `[3]` Reglas de protección de `main` + revisión obligatoria antes de merge.

---

## EPIC N — Despliegue (Railway/Render) (sem 12-14)
- ⬜ **T-085** `[1]` Provisionar **PostgreSQL gestionado** (Railway/Render).
- ⬜ **T-086** `[1]` Deploy del **backend** desde GitHub; cargar variables/secrets; correr migraciones.
- ⬜ **T-087** `[1]` Deploy del **frontend web** (Flutter web build).
- ⬜ **T-088** `[1+3]` Smoke test end-to-end en el entorno desplegado.

---

## EPIC O — Documentación de cierre y Puntos de Control (sem 14-16)
- ⬜ **T-089** `[1+3]` **Manual de instalación** (cómo levantar el proyecto).
- ⬜ **T-090** `[1+3]` **Manual de usuario**.
- ⬜ **T-091** `[1+3]` Consolidar evidencia y entregables para **PC1 (28/09)**, **PC2 (26/10)** y **PC3 (09/11)**.
- ⬜ **T-092** `[1+3]` Actualizar `HITOS.md` a medida que se completan integraciones (para el CV).

---

## Resumen de dependencias clave

1. **EPIC B** se hace **ya** (no depende de nadie).
2. **EPIC C/D** arrancan cuando **Int2 entrega el DER + casos de uso** → ahí también el `git init` (T-033).
3. **EPIC E → F** es el grueso del backend (servicios primero, luego endpoints).
4. **EPIC G/H/I/J** (integraciones + agente real + notificaciones) van después del núcleo.
5. **EPIC K/L** son transversales (seguridad y tests, todo el tiempo).
6. **EPIC N/O** (deploy + docs) cierran hacia el final.
