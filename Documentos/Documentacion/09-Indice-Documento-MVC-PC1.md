# Índice propuesto — «Documento con el MVC»

> **Qué es esto:** la estructura del entregable del PC1, para que el equipo se reparta las secciones y
> escriba en paralelo. No es el documento: es su esqueleto, con qué va en cada parte, de dónde sale el
> material y quién lo tiene.
>
> **Autor:** Martiniano (Int1+3) · **Fecha:** 2026-09-26 · **Entrega:** 28/09/2026

---

## El criterio que ordena todo

La consigna pide **un solo documento**: *«Entrega: Documento con el MVC»*. Tiene que poder leerse solo, de
punta a punta, y alcanzar para entender y evaluar el proyecto entero.

De ahí salen dos reglas:

1. **Contenido adentro, archivos crudos afuera.** El DER va adentro; las 411 líneas del `schema.sql` van como
   anexo. La prueba: *si alguien lee solo el documento, ¿le falta algo para calificar?* Si sí, eso entra.
2. **Cada ítem obligatorio tiene su sección, titulada con las palabras de ellos.** El MVC es la columna
   vertebral del núcleo técnico (secciones 3, 4 y 5), pero **5 de los 7 ítems obligatorios viven fuera de esa
   columna**. Si el documento tuviera solo tres capítulos, esos cinco se perderían de vista.

---

## Trazabilidad con la consigna

Esta tabla va **dentro del documento**, justo después del índice. Le permite a quien corrige ir tachando, y
demuestra que se leyó la consigna.

| Lo que pide la consigna (textual) | Sección |
|---|---|
| «Presentación general del Proyecto (Objetivos, antecedentes, justificación, alcances y límites)» | 1 |
| «Arquitectura de la solución» | 2 |
| «Modelo de Datos y relaciones» / «Model de datos SQL» | 3 |
| «Modelo de Desarrollo utilizado con interfases gráficas» — interfaces | 4 |
| «Comunicación V-C: Open APi (Formato Json)» | 5 |
| «Modelos de IA utilizados y justificación» | 6.1 |
| «Agentes IA implementados» | 6.2 |
| «Modelo de Desarrollo utilizado con interfases gráficas» — modelo | 7 |
| «Modelo flujo -Graficos: UML, C4 Model» | 2 y 3 |
| «Modelo : marmaid.js» | 2 (ver nota de formato) |
| «Presentación de la documentación» | La exposición del 28/09 |

---

## Las ocho secciones

### 1 · Presentación general del Proyecto
**Cubre:** ítem obligatorio 1 · **Quién:** Integrante 2 · **Extensión:** 3–4 páginas

- **Objetivos** del sistema.
- **Antecedentes:** VanFull es una empresa real que hoy opera con **WhatsApp, Excel y teléfono**. Conviene
  que esto esté contado con detalle: es lo que hace que el proyecto no parezca un ejercicio.
- **Justificación:** qué problema concreto resuelve.
- **Alcances y límites:** resumen de los 45 RF, 14 RNF y 31 RN, y sobre todo **qué queda afuera** del MVP.

**De dónde sale:** Drive `00_Control_y_Decisiones`, `01_Relevamiento_y_AS-IS`, `02_Alcance_RF_RNF_Reglas`.

---

### 2 · Arquitectura de la solución
**Cubre:** ítem obligatorio 6, más «UML, C4 Model» y «marmaid.js» · **Quién:** Int2 (diagramas) + Int1/3 (decisiones) · **Extensión:** 4–5 páginas

- **C4 de Contexto y C4 de Contenedores** (ya hechos).
- **Arquitectura cliente-servidor por capas**, y el stack: Flutter · Python/FastAPI · PostgreSQL ·
  Google Maps Routes · Mercado Pago · OpenRouter · WhatsApp.
- ⭐ **El mapeo MVC**, que es lo que justifica el título del documento:

  | | En este sistema |
  |---|---|
  | **Modelo** | PostgreSQL + las reglas de negocio en la capa de servicios |
  | **Vista** | Flutter (Web y Mobile) — sin reglas críticas |
  | **Controlador** | FastAPI: routers finos que delegan en servicios |

- **El principio de arquitectura más importante:** la IA **no** accede a la base de datos. Llama herramientas
  de FastAPI, y **FastAPI es la autoridad** sobre permisos, cupos y pagos. Vale explicar *por qué*: aísla un
  componente no determinístico detrás de una capa de validación determinística.

> ⚠️ **Nota de formato — mermaid.js.** La consigna pide *«Modelo : marmaid.js»*. Es un requisito de **formato**,
> no de contenido: al menos un diagrama del documento tiene que estar hecho en mermaid. El candidato natural
> es el diagrama de capas o el de flujo de una reserva, acá en la sección 2. **Hoy no existe ninguno.**

**De dónde sale:** Drive `05_Arquitectura_API_Datos` (C4 y Arquitectura General) + `Documentos/Sesiones/CONTEXTO.md`.

---

### 3 · Modelo — Datos y relaciones
**Cubre:** ítem obligatorio 4 y «Model de datos SQL» · **Quién:** Int2 (DER) + Int1/3 (modelo físico) · **Extensión:** 5–6 páginas

- **El DER / Modelo Relacional** de 35 tablas, como diagrama, organizado en sus 5 bloques.
- **Las decisiones de diseño que se defienden solas** — esto es lo que se evalúa, no la lista de tablas:
  - **Claves foráneas compuestas** para que la integridad entre viaje, recorrido y parada sea real y no
    dependa de la aplicación.
  - **Restricción XOR (MR-R13):** una reserva se respalda por un período de abono *o* por una contratación
    directa, nunca por las dos ni por ninguna.
  - **Una reserva por pasajero y viaje** (MR-R15) y **un abordaje por pasajero y viaje** (MR-R24).
  - **Lo que deliberadamente NO se persiste** por ser derivado (MR-R30): saldo, deuda y cupo disponible.
    Explicar por qué guardarlos sería un error.
  - **Roles resueltos con tablas de la aplicación** (`rol_acceso` + `cuenta_rol`), no con roles del motor:
    los usuarios no son usuarios de la base, y las reglas RN-027 a RN-030 son contextuales, cosa que un
    `GRANT` no puede expresar.
- **Las 31 reglas de negocio:** cuáles se expresan en el esquema y cuáles quedan en la capa de servicios.
- ⭐ **La verificación:** el DDL se **ejecutó contra un PostgreSQL 16 real** — 35 tablas, 54 claves foráneas,
  5 roles — y se comprobó que las restricciones rechazan datos inválidos. Vale contarlo: es la diferencia
  entre un modelo dibujado y un modelo probado.

**De dónde sale:** Drive `05` (DER/MR oficial) + `backend/db/schema.sql` y su `README.md`.

---

### 4 · Vista — Interfaces gráficas
**Cubre:** la mitad del ítem obligatorio 5 · **Quién:** Integrante 3 (Martiniano) · **Extensión:** 6–8 páginas

- ⭐ **Los tres contextos físicos de uso**, que es de donde sale todo lo demás: el pasajero caminando a la
  parada a las 6 AM; el chofer parado en la puerta de la combi, con una mano y posiblemente con guantes, y
  quizá **sin señal**; el administrador sentado, que necesita ver seis viajes a la vez. Poner la tabla
  comparativa: es lo que explica por qué las tres interfaces son distintas a propósito.
- **El sistema de diseño:** paleta **muestreada de los píxeles del logo real** de la empresa, y **contraste
  WCAG verificado** en cada par de colores — incluidos los tres casos que fallaron y cómo se resolvieron.
- **Las 10 pantallas como imágenes**, agrupadas por actor, cada una con su caso de uso.
- **La tabla de trazabilidad** pantalla → CU → endpoint → regla de negocio visible.
- **Los estados que no son el camino feliz**, que es lo que distingue este diseño: el `409` por falta de cupo,
  la posición de GPS desactualizada (>30 s, RNF-008), el modo sin señal con abordajes pendientes de
  sincronizar, y el intento de escanear el QR de alguien que ya abordó (que es la restricción MR-R24 hecha
  visible en pantalla).
- **El alcance, dicho explícitamente:** 10 pantallas diseñadas de 37 casos de uso, y por qué ese recorte.

**De dónde sale:** `Documentos/Documentacion/08-Brief-de-Diseno-UI.md` + los dos artefactos de diseño
(pantallas y sistema de diseño), cuyos enlaces están en `CONTEXTO.md` §10.

---

### 5 · Controlador — API y reglas de negocio
**Cubre:** «Comunicación V-C: Open APi (Formato Json)» · **Quién:** Integrante 1 · **Extensión:** 4–5 páginas

- **Las cuatro capas del backend** y qué hace cada una:
  `routers/` (finos, sin lógica) → `schemas/` (contrato de entrada y salida) → `services/` (las 31 reglas de
  negocio) → `models/` (la única capa que toca PostgreSQL).
- **La tabla de las 22 operaciones**, con su caso de uso, el rol que las puede invocar y sus códigos de error.
- **Autenticación JWT y autorización por rol** (RN-026 a RN-030).
- **Formato de error uniforme** y códigos HTTP coherentes con el negocio — por ejemplo `409` cuando no hay
  cupo o cuando la reserva está duplicada (RN-031). Conviene explicar por qué un conflicto de negocio no es
  un `400`.
- ⭐ **Por qué contract-first:** definir el contrato antes de programar permite que frontend, backend y agente
  avancen en paralelo sin romperse.

> ⚠️ La consigna pide **formato JSON** y nuestro contrato está en YAML. Hay que generar el `openapi.json`
> y entregar los dos.

**De dónde sale:** `backend/openapi/openapi.yaml` y su `README.md` (matriz CU → endpoint).

---

### 6 · Modelos de IA y agentes
**Cubre:** ítems obligatorios 2 y 3 · **Quién:** Integrante 3 (Martiniano) · **Extensión:** 4–5 páginas

**6.1 · Modelos de IA utilizados y justificación**
- OpenRouter como gateway. Principal **MiniMax M3 Free**, fallback **Nemotron 3 Super Free**.
- ⭐ **Cómo se eligieron:** una PoC con **10 casos de prueba (TC-01 a TC-10)** midiendo tool calling, exactitud
  de argumentos, seguridad, no-alucinación, español, estructura, latencia y disponibilidad, con **matriz de
  criterios ponderada**. Resultado 95,5 contra 94,5. Poner la matriz.
- Vale incluir la honestidad metodológica sobre el caso multi-paso TC-04: reconocer un límite suma.

**6.2 · Agentes IA implementados**
- **AG-01:** definición formal, las **11 herramientas** en formato function-calling, el prompt base.
- **La matriz de trazabilidad** herramienta → caso de uso → endpoint.
- **Seguridad del agente:** no accede a la base, no confirma pagos, y las **fechas relativas** («mañana») se
  resuelven de forma determinística en el backend en vez de delegarlas al modelo — que fue un hallazgo de la
  PoC y conviene contarlo como tal.
- AG-02 queda declarado como extensión futura, fuera del MVP.

**De dónde sale:** el Anexo 3 de la carpeta `07` (ya escrito) — se resume acá y se referencia completo.

---

### 7 · Modelo de desarrollo
**Cubre:** la otra mitad del ítem obligatorio 5 · **Quién:** Integrante 3 (Martiniano) · **Extensión:** 3 páginas

- Repositorio, monorepo y criterio de qué va en Git y qué en Drive.
- **El flujo** Issue → Branch → PR → Revisión → Merge, y las convenciones de ramas y commits.
- **La cadena de trazabilidad:** CU → operación → endpoint → servicio → datos → prueba.
- **Calidad:** ruff, pytest, Docker Compose, y el checklist de cierre de tarea.
- **Planificación:** el cronograma de las 16 semanas y en qué semana estamos.

**De dónde sale:** el Anexo 6 de la carpeta `07` (ya escrito) + `CONTRIBUTING.md`.

---

### 8 · Anexos

Lista con enlaces, no contenido pegado:

| Anexo | Qué es | Dónde |
|---|---|---|
| A · Modelo de datos SQL | El DDL completo de 35 tablas | GitHub, tag `pc1` |
| B · Contrato OpenAPI | YAML **y JSON** | GitHub, tag `pc1` |
| C · IA y agentes | El documento consolidado completo | Drive `07` |
| D · Modelo de desarrollo | El documento completo | Drive `07` |
| E · Prototipo navegable | Las 10 pantallas, recorribles | Enlace |
| F · Sistema de diseño | Tokens, componentes y marca | Enlace |
| G · Especificaciones de casos de uso | Los 37 CU | Drive `03` |

---

## Reparto sugerido

| Integrante | Secciones |
|---|---|
| **Integrante 2** | 1 · 2 (diagramas) · 3 (DER) |
| **Integrante 1** | 2 (decisiones) · 3 (modelo físico) · 5 |
| **Integrante 3** | 4 · 6 · 7 |
| **Juntos** | Portada, índice, tabla de trazabilidad, sección 8 y revisión final |

**Total estimado:** 30 a 36 páginas más anexos.

## Lo único que no existe todavía

1. **El diagrama en mermaid.js** (sección 2) — es el único requisito de la consigna sin nada hecho.
2. **El `openapi.json`** (sección 5) — el contenido existe, falta el formato.
3. **El documento en sí**, que es lo que este índice viene a destrabar.

Todo lo demás ya está escrito o diagramado: es trabajo de integración y redacción, no de producción.
