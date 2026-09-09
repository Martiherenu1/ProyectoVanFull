# Reparto de tareas y plan de trabajo — Martiniano + compañero (Integrante 1 + 3)

> Fuente: `VanFull_Comparacion_Tareas_Integrantes.pdf`. **Decisión del equipo:** Martiniano y su compañero
> toman **juntos** todo el scope de **Integrante 1 (Datos+Backend/API)** e **Integrante 3 (IA+Agentes+Modelo
> de Desarrollo)**, sin subdividir. El **Integrante 2** (requerimientos/arquitectura/UX) queda a cargo del
> tercer integrante y **fuera de nuestro foco**. Meta: **1er Punto de Control = 28/09/2026**.

## 1. Lo que NO hacemos nosotros (Integrante 2 — el de requerimientos)

Modelo Conceptual, MVC, C4 Nivel 1 y 2, **casos de uso UML**, diagramas de secuencia, Mermaid como
herramienta, **wireframes** (Pasajero Mobile, Conductor Mobile, Administrador Web).
→ *No invertir tiempo acá; es de Integrante 2. Sí lo usamos como entrada (sus casos de uso/flujos
alimentan nuestros endpoints y modelo de datos).*

## 2. Nuestro scope combinado (Integrante 1 + 3)

> **⚠ Entradas que provee Integrante 2 (análisis) — NO las producimos nosotros:**
> el **DER / modelo de datos** y **todos los casos de uso con su especificación** los hace Int2 y nos los
> pasa. Nuestro trabajo es **implementarlos** (modelos ORM, servicios, endpoints, OpenAPI) y **conciliar**
> nuestro borrador provisional con lo que llegue. Mientras tanto avanzamos con lo que NO depende del DER final.

### 2A · Datos + Backend/API (Integrante 1)
| # | Tarea | Estado |
|---|---|---|
| 1 | **DER y modelo relacional** | 📥 **lo provee Int2**. Tenemos borrador provisional (`03-Modelo-de-Datos-DER-v0.1.md`) para arrancar; se reemplaza/concilia al recibir el oficial |
| 2 | **Implementar** el modelo en PostgreSQL (ORM, claves, relaciones) a partir del DER de Int2 | ⬜ pendiente (espera DER oficial) |
| 3 | **OpenAPI/JSON y endpoints** | ⬜ pendiente (contratos de la API) |
| 4 | **Integración de pagos (Mercado Pago) y tracking (GPS)** en la API | ⬜ pendiente (diseño) |
| 5 | **Servicios del backend** utilizables por los agentes IA | 🟡 estructura lista (`app/services/`), falta implementar |

### 2B · IA + Agentes + Modelo de Desarrollo (Integrante 3)
| # | Tarea | Estado |
|---|---|---|
| 6 | **Selección y justificación del LLM** | ✅ hecho (PoC MiniMax/Nemotron, matriz ponderada) |
| 7 | **Arquitectura de agentes y System Prompts** | ✅ AG-01 definido (prompt base en `agent/tools.py`) |
| 8 | **Function Calling** integrado con backend | 🟡 11 tools codificadas; falta conectarlas a `services` |
| 9 | **PoC mínima de los agentes** | ⬜ pendiente (demo ejecutable end-to-end) |
| 10 | **Git/GitHub y tablero de trabajo** | ⬜ pendiente (`git init` + repo + board) |
| 11 | **Cronograma e hitos** | ✅ cronograma ingerido + `HITOS.md` en marcha |

### 2C · Zona compartida 1+3
- **Servicios del backend expuestos como Function Calling**: los `services/` (reglas de negocio, cupos,
  pagos, GPS) son consumidos por las tools de AG-01. Es el punto donde se cruzan Integrante 1 y 3 → nos
  toca a nosotros dos y lo resolvemos de una sola vez (ventaja de tomar ambos roles juntos).

## 3. Dependencia con Integrante 2

Flujo sugerido del equipo: **(1)** Int2 define casos de uso, arquitectura y flujos → **(2)** nosotros
ajustamos modelo de datos y endpoints a esos flujos → **(3)** conectamos agentes/Function Calling a los
servicios → **(4)** los tres revisan de punta a punta y consolidan.
→ Podemos **adelantar** DER, servicios y OpenAPI con un primer corte y **ajustar** cuando Int2 cierre casos de uso.

## 4. Orden de ataque propuesto (hacia el PC1)

**Fase A — ahora, sin depender del DER/casos de uso de Int2:**
1. **PoC de agentes ejecutable** (tarea 9): AG-01 llamando OpenRouter con las 11 tools y respuestas de
   servicios **mockeadas** (sin BD real todavía). Valida Function Calling end-to-end. *(Int1+3)*
2. **Diseño de integración de pagos (Mercado Pago sandbox) y GPS** (tarea 4): flujo de webhooks y endpoints,
   independiente del detalle del DER. *(Int1)*

**Fase B — al recibir el DER + casos de uso de Int2:**
3. **Conciliar** nuestro borrador con el DER oficial → **modelos ORM + migraciones**. *(Int1)*
4. **Servicios de dominio** (reglas RN) y **conexión real de las tools** de AG-01 a esos servicios. *(Int1+3)*
5. **Contratos OpenAPI + endpoints** derivados de los casos de uso de Int2. *(Int1)*
6. **`git init` + primer commit + GitHub + tablero** (tarea 10) — **decisión de Martiniano: se hace cuando
   el DER esté definido**, para que el primer commit incluya el scaffold completo con modelos ORM. *(Int3)*
