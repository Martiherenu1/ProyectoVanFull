# Borrador — Propuestas y Propuesta seleccionada

> **Estado:** borrador para el documento v1.1. **No está en el Word entregado (v1.0).**
> **Fuente:** `Propuestas Trabajo de Campo.pdf` (9 páginas, armado por el equipo antes de comenzar).
> **Pendiente de completar:** todo lo marcado con `[completar]`. Se busca cada marca antes de entregar.
> Las secciones van entre §1.3 y §1.4 del documento, o como una sección propia antes de la Presentación.

---

# Propuestas

Antes de empezar, el equipo armó **tres propuestas de proyecto**. Las tres cumplen lo que pide la consigna
(aplicación Web y Mobile, servidor, base de datos e inteligencia artificial con agentes) y se compararon con los
mismos criterios: **factibilidad técnica, alcance, disponibilidad de datos, valor para el negocio, uso real de la
IA y facilidad de demostrarlo**.

## Las tres propuestas

| | Propuesta 1 · Transporte | Propuesta 2 · Canchas de fútbol | Propuesta 3 · Carne envasada |
|---|---|---|---|
| **Qué es** | Gestión y reserva de viajes de pasajeros, tomando como caso a VanFull | Gestión de complejos deportivos y reserva de canchas | Venta y gestión de carne envasada al vacío |
| **Quién la usa** | Pasajeros, conductores y administradores | Clientes y administradores | Clientes y administradores |
| **Qué resuelve** | Consultar horarios y cupos, reservar ida y vuelta, cancelar y recibir avisos; administrar vehículos, recorridos, reservas y pagos | Buscar sedes cercanas, ver disponibilidad y reservar; administrar sedes, horarios, precios y mantenimientos | Ver catálogo y stock, armar un pedido y seguir su entrega; administrar productos, precios y pedidos |
| **Papel de la IA** | Chatbot y agente de planificación: consulta disponibilidad real, sugiere horarios alternativos, detecta sobrecupos y analiza la demanda; puede preparar una reserva que el pasajero confirma | Chatbot que consulta sedes, horarios y precios, y prepara una reserva que el usuario confirma | Asistente que recomienda cortes y cantidades según las personas, y prepara un carrito que el cliente confirma |
| **Pagos** | Pago simulado | Pago simulado | Pago simulado |

## Comparación

La comparación se hizo en dos instancias. Primero, una **factibilidad de desarrollo** sobre 5:

| Propuesta | Factibilidad | Lectura |
|---|---|---|
| Complejo deportivo | **4,5 / 5** | La más factible. Riesgo: reglas de cancelación, pagos y superposición de turnos |
| Carne envasada | 4,1 / 5 | Alcance controlable. Riesgo: que la IA quede como un agregado |
| Transporte (VanFull) | 3,8 / 5 | Mayor potencial de impacto e innovación. Riesgo: geolocalización, recorridos y asignación pueden ampliar mucho el alcance |

Después, una **comparación general** por aspecto, con estrellas (de 1 a 5):

| Aspecto | Transporte | Canchas | Carne |
|---|---|---|---|
| Problema real | 3 | 3 | 3 |
| Web y Mobile justificadas | 3 | 3 | 3 |
| Base de datos interesante | 4 | 4 | 3 |
| Complejidad funcional | Alta | Media / Alta | Media |
| IA fácil de justificar | **4** | 3 | 2 |
| Agentes de IA | **4** | 4 | 3 |
| Innovación posible | **4** | 3 | 3 |
| Facilidad de desarrollo | 2 | 4 | 4 |
| Facilidad para probar | 3 | 5 | 4 |
| Potencial para la demostración final | 5 | 5 | 4 |
| **Riesgo del proyecto** | **Alto** | Bajo / Medio | Bajo / Medio |

**Conclusión del análisis, tal como quedó escrita entonces:** la opción más factible y controlada era el complejo
deportivo; la de mayor diferencial de IA y de impacto real era VanFull, **a condición de acotar el MVP** a
reservas, cupos, panel operativo y un agente de planificación simple.

---

# Propuesta seleccionada

**El equipo eligió la Propuesta 1: el sistema de gestión y reserva de transporte, con VanFull como caso real.**

## Por qué VanFull

- **Es el proyecto con más diferencial de IA y más impacto real.** La IA se justifica de forma natural en cupos,
  horarios, demanda y comunicación con los pasajeros: era el aspecto en que la propuesta puntuaba más alto.
- **Tiene un caso real.** VanFull es una empresa existente, con una operación que hoy se apoya en WhatsApp, planillas
  y llamadas, y con un dueño al que se pudo entrevistar. El relevamiento está en la carpeta 01 del Drive.
- **Tiene una demostración final fuerte** (5 de 5, empatada con la mejor).
- **Reúne muchas de las capas que pide el trabajo:** una base de datos con relaciones complejas, agentes con
  herramientas, seguimiento de la combi y pagos.

## Qué costó esa elección

Se eligió sabiendo que **no era la opción más fácil**: tenía la menor factibilidad de desarrollo (3,8 sobre 5) y el
único riesgo clasificado como **alto**. La comparación ya advertía que la geolocalización, los recorridos y la
asignación podían ampliar mucho el alcance, y el proyecto final incluye seguimiento GPS y optimización de recorridos.

**Cómo se controló.** Se cerró la **línea funcional** (45 requisitos funcionales, 14 no funcionales, 31 reglas de
negocio, 37 casos de uso) y se dejaron **por escrito los límites** (§1.4). El alcance final terminó siendo más
amplio que el mínimo que recomendaba la comparación inicial —incluye seguimiento GPS, optimización de recorridos y
WhatsApp—, pero acotado y con cada decisión registrada.

## Qué cambió entre la propuesta y el proyecto

La propuesta era una idea inicial; algunas decisiones se precisaron al avanzar. Para que el documento sea
transparente, se deja el cambio a la vista:

| Aspecto | En la propuesta | En el proyecto |
|---|---|---|
| **Backend** | Java + Spring Boot | **Python + FastAPI** — motivo: `[completar: por qué se cambió]` |
| **Base de datos** | PostgreSQL + PostGIS | **PostgreSQL 16**, sin PostGIS. El modelo (35 tablas) no usa tipos geográficos; el recorrido y el tiempo estimado los calcula Google Maps (Routes API) |
| **Acceso a datos** | No se definía | SQLAlchemy 2.0 asíncrono y Alembic para las migraciones |
| **Pagos** | Pago simulado | **Mercado Pago en modo de prueba** (sandbox), con confirmación automática solo cuando el proveedor informa un pago aprobado o acreditado |
| **Contrato entre capas** | OpenAPI / JSON | Igual, entregado en YAML y en JSON (22 operaciones, 23 esquemas) |
| **IA** | Chatbot y agente de planificación, sin modelo definido | Agente AG-01 de 13 herramientas, sobre OpenRouter: MiniMax M3 (principal) y Nemotron 3 Super (respaldo), elegidos con una prueba medida |
| **Mensajería** | No figuraba | WhatsApp como canal alternativo de atención |
| **Diagramas** | Mermaid.js | Se mantiene (§2.4), junto con C4 y UML |

## Tecnologías adoptadas

**Flutter** (Web y Mobile) · **Python + FastAPI** (servidor) · **PostgreSQL 16** · **SQLAlchemy 2.0 + Alembic** ·
**OpenAPI** (YAML y JSON) · **OpenRouter** (MiniMax M3 y Nemotron 3 Super) · **Google Maps Platform** (Routes API) ·
**Mercado Pago** (modo de prueba) · **WhatsApp** · **Git y GitHub** · **Docker** (entorno de desarrollo).
Alojamiento previsto, sin costo: Neon (base), Render (servidor) y GitHub Pages (versión web).

---

## Notas para quien lo incorpore al Word

1. Las tres propuestas y la comparación son **tal como las presentó el equipo**; solo se resumieron. El PDF original
   puede adjuntarse como anexo si se quiere dar prueba.
2. La fila «Backend» deja a la vista que la propuesta decía Java + Spring Boot. Si el PDF original llegó a la cátedra
   con ese stack, **conviene dejarla**: un profesor puede notarlo, y es mejor que lo explique el documento.
3. Cifras verificadas contra el repo: 45 · 14 · 31 · 37 · 35 tablas, 22 operaciones, 23 esquemas, 13 herramientas.
   El detalle de las estrellas se leyó de la imagen de la página 9 del PDF.
