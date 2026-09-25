# HITOS PROFESIONALES — Proyecto Vanfull

> Registro de decisiones arquitectónicas, componentes técnicos significativos, desafíos resueltos e
> integraciones completadas. Pensado como insumo para el **CV profesional de Martiniano** (desarrollador
> backend Python/FastAPI + frontend Flutter). Cada hito está redactado para poder traducirse a un bullet
> de CV o a una respuesta de entrevista técnica.

**Formato de cada entrada:**
```
### [AAAA-MM-DD] Título del hito
- **Qué:** descripción técnica concreta.
- **Rol de Martiniano:** qué hizo/decidió personalmente.
- **Por qué importa (CV):** el valor técnico o de negocio, para venderlo.
- **Tecnologías:** stack involucrado.
```

---

## Hitos

### [2026-08-27] Definición de arquitectura y stack tecnológico del sistema
- **Qué:** Se cerró una arquitectura **cliente-servidor por capas** con separación explícita entre la
  IA y las reglas de negocio: el LLM interpreta intención y selecciona herramientas, pero **FastAPI**
  gobierna autenticación, permisos, cupos, pagos y validaciones. El frontend no contiene reglas críticas.
- **Rol de Martiniano:** integrante del equipo de 3 que aprobó las decisiones; responsable de backend
  (Python/FastAPI) y frontend (Flutter).
- **Por qué importa (CV):** demuestra criterio de **diseño de sistemas** — aislar un componente no
  determinístico (LLM) detrás de una capa de validación determinística es una decisión de arquitectura
  madura y defendible en entrevistas.
- **Tecnologías:** Flutter (Web+Mobile), Python/FastAPI, PostgreSQL, OpenRouter, Google Maps Platform, Mercado Pago, WhatsApp.

### [2026-08-27] Selección de modelos LLM basada en evidencia empírica (PoC con matriz ponderada)
- **Qué:** En vez de elegir el modelo por preferencia, el equipo construyó una **PoC sobre OpenRouter**
  con una batería de 10 casos (TC-01..TC-10) que midió *tool calling*, exactitud de argumentos, seguridad,
  no-alucinación, español, estructura, latencia y disponibilidad, con **matriz de criterios ponderada**.
  Resultado: **MiniMax M3 Free** (95,5/100) como principal y **Nemotron 3 Super Free** (94,5/100) como fallback.
- **Rol de Martiniano:** parte del equipo que definió criterios, ejecutó la evaluación y aprobó el resultado.
- **Por qué importa (CV):** muestra **evaluación rigurosa de LLMs** (benchmarking reproducible, métricas
  ponderadas, honestidad metodológica sobre el caso multi-paso TC-04). Muy vendible en el mercado actual de IA.
- **Tecnologías:** OpenRouter, MiniMax M3, NVIDIA Nemotron 3 Super, tool calling, evaluación de modelos.

### [2026-08-27] Diseño del agente conversacional AG-01 con tool calling seguro
- **Qué:** Especificación de AG-01: agente que atiende lenguaje natural en app y WhatsApp mediante **11
  herramientas** controladas del backend, sin acceso directo a la base de datos. Incluye prompt base con
  restricciones de seguridad y el hallazgo de que las fechas relativas ("mañana") deben resolverse de forma
  **determinística en el backend**, no delegarse al modelo.
- **Rol de Martiniano:** co-diseño; será quien implemente las tools en FastAPI (backend).
- **Por qué importa (CV):** experiencia en **agentes de IA con function/tool calling** y en mitigación de
  riesgos (prompt injection, alucinación, privacidad de datos) — competencia muy demandada.
- **Tecnologías:** FastAPI, tool/function calling, diseño de prompts, seguridad de LLMs.

### [2026-08-31] Scaffolding del monorepo (backend FastAPI + frontend Flutter + Docker)
- **Qué:** Estructura inicial del monorepo: backend **FastAPI por capas** (`core`/`models`/`schemas`/
  `routers`/`services`/`agent`) con SQLAlchemy 2.0 async, `config` por variables de entorno, endpoint de
  salud con chequeo de BD, módulo **AG-01** (las 11 tools en formato function-calling + cliente OpenRouter
  con fallback), tests de humo, `Dockerfile` y `docker-compose` (PostgreSQL + API con hot-reload).
- **Rol de Martiniano:** definió el stack y las decisiones (monorepo, hosting Railway/Render); dueño del backend y frontend.
- **Por qué importa (CV):** montar un proyecto **containerizado, por capas y multiplataforma** desde cero
  demuestra criterio de **estructura de proyecto, DevOps básico y separación de responsabilidades**.
- **Tecnologías:** FastAPI, SQLAlchemy 2.0 async, PostgreSQL, Docker Compose, pytest, Flutter (estructura), OpenRouter.

---

### [2026-09-08] Inicialización del repositorio y modelo de desarrollo
- **Qué:** `git init` + primer commit del monorepo (36 archivos) sobre `main`, con convenciones de equipo
  listas: **ruff** (lint/formato) y **pytest** vía `pyproject.toml`, `CONTRIBUTING.md` con el flujo
  **Issue → Branch → PR → Merge** y **Conventional Commits**, `.gitattributes` (normalización LF) y `.dockerignore`.
  Separación código (Git) / documentación oficial (Drive): los `.docx` quedan fuera del repo.
- **Rol de Martiniano:** definió y estableció el modelo de desarrollo del equipo (tarea de Integrante 3).
- **Por qué importa (CV):** montar el **modelo de desarrollo colaborativo** (control de versiones, convenciones,
  CI-ready) desde cero es una competencia de ingeniería de software concreta y demostrable.
- **Tecnologías:** Git, GitHub, ruff, pytest, Conventional Commits.

### [2026-09-21] Modelo de datos físico en PostgreSQL (DDL de 35 tablas, validado)
- **Qué:** Traducción del Modelo Relacional aprobado a un **DDL PostgreSQL ejecutable**: 35 tablas, 54 claves
  foráneas (incluidas **FKs compuestas** para integridad real entre viaje/recorrido/parada), restricciones `CHECK`
  para los dominios del negocio, una restricción **XOR** (una reserva se respalda por abono *o* por contratación,
  nunca ambas) y catálogo de roles. Decisiones del modelo físico documentadas (tipos, identidades, qué NO se
  persiste por ser derivado: saldo, deuda y cupo disponible).
- **Rol de Martiniano:** responsable del diseño físico y la persistencia (Integrante 1).
- **Por qué importa (CV):** pasar de un modelo lógico a un **esquema físico correcto y verificado** —con
  integridad referencial compuesta y reglas embebidas— es diseño de bases de datos real, no un CRUD genérico.
  Además se **validó contra un PostgreSQL real** (Docker), comprobando que las restricciones rechazan datos inválidos.
- **Tecnologías:** PostgreSQL 16, SQL DDL, Docker Compose.

### [2026-09-21] Contrato de API REST con OpenAPI 3.0 derivado de casos de uso
- **Qué:** Diseño del **contrato de la API antes de implementarla**: 22 operaciones y 22 schemas en OpenAPI 3.0.3,
  con autenticación JWT, autorización por rol, formato de error uniforme y códigos HTTP coherentes con las reglas
  de negocio (p. ej. `409` por falta de cupo o reserva duplicada). Cada endpoint es trazable a su caso de uso y a
  los requisitos/reglas que lo justifican.
- **Rol de Martiniano:** autor del contrato (Integrante 1), acordado como interfaz común para frontend y agente IA.
- **Por qué importa (CV):** **contract-first design** — definir el contrato antes de programar permite que
  frontend, backend e IA avancen en paralelo sin romperse. Es una práctica de ingeniería valorada en equipos reales.
- **Tecnologías:** OpenAPI 3.0, REST, JWT, JSON Schema.

### [2026-09-22] Trazabilidad end-to-end: caso de uso → endpoint → tool del agente
- **Qué:** Consolidación de la documentación de IA y agentes con una **matriz de trazabilidad** que conecta cada
  una de las 11 tools del agente AG-01 con su caso de uso y su endpoint de la API, más la justificación empírica
  de los modelos (PoC con matriz ponderada) y las restricciones de seguridad del agente.
- **Rol de Martiniano:** responsable de IA/agentes (Integrante 3).
- **Por qué importa (CV):** demuestra capacidad de **mantener trazabilidad entre negocio, API e IA** —que el
  agente no haga nada que no esté respaldado por un caso de uso y validado por el backend—, que es justamente
  el problema difícil de integrar LLMs en sistemas reales.
- **Tecnologías:** OpenRouter, function calling, OpenAPI, documentación técnica.

### [2026-09-25] Sistema de diseño derivado de la marca real, con accesibilidad verificada
- **Qué:** Construcción de un **design system** para la plataforma en vez de elegir estilos pantalla por pantalla.
  La paleta no se eligió por gusto: se **muestrearon los píxeles** del logo y de la foto de la combi de la empresa
  para obtener los valores exactos (dorado `#D9A521`, grafito `#5F5F61`, franja `#414143`, chapa `#EAEBED`), y
  después **cada par de colores se validó con contraste WCAG**. Esa validación encontró tres límites reales que
  quedaron escritos como reglas: blanco sobre dorado falla (2.24:1), el dorado de marca **no sirve como texto en
  tema claro** (2.07:1) y hace falta una variante oscurecida, y los cuatro colores de estado necesitan **dos valores
  cada uno** —uno por tema— para llegar a 4.6:1. El sistema incluye tokens (color en 2 temas, tipografía,
  espaciado, radios y una familia propia de **densidad**), 4 componentes con preview vivo y guía de uso, y los
  activos de marca con sus reglas.
- **Rol de Martiniano:** responsable de la capa de Vista (Integrante 3). Aportó los activos de marca, definió el
  alcance y tomó las decisiones de diseño, incluida la de **descartar una vectorización del logo** que empeoraba
  el original y la de **no duplicar las pantallas en tema claro** por contradecir el criterio de contexto de uso.
- **Por qué importa (CV):** demuestra **accesibilidad tratada como ingeniería y no como opinión** —contraste
  medido, casos que fallan documentados en vez de escondidos— y criterio para construir un **sistema reutilizable**
  antes que pantallas sueltas. Además, derivar la identidad de la marca existente del cliente en lugar de inventar
  una paleta es exactamente lo que se espera en un proyecto real.
- **Tecnologías:** design tokens, WCAG 2.1 (ratios de contraste), sistemas de diseño multi-tema, Pillow (muestreo
  de color), Google Fonts, Material Symbols.

### [2026-09-25] Diseño de 10 interfaces trazables a casos de uso, contrato y reglas de negocio
- **Qué:** Diseño de las **10 pantallas** del PC1 para los **3 actores** (pasajero, chofer, administrador), navegables
  como prototipo. La decisión estructural fue derivar la interfaz del **contexto físico de uso** y no de una plantilla:
  el chofer opera parado en la puerta de la combi, con una mano y posiblemente con guantes, por eso sus objetivos
  táctiles son de 64 px y su pantalla funciona **sin conexión**; el administrador está sentado y necesita ver seis
  viajes a la vez, por eso su fila es de 36 px y su tema es claro. Cada pantalla es **trazable a su caso de uso, a su
  endpoint del contrato OpenAPI y a la regla de negocio que debe mostrar**, y usa los campos y enums reales del
  esquema SQL. Las pantallas exponen los estados que normalmente se omiten en un mockup: el `409` por falta de cupo
  al confirmar, la posición de GPS desactualizada (>30 s, RNF-008), el modo sin señal con abordajes pendientes de
  sincronizar, y el intento de escanear un QR de alguien **que ya abordó** —que es la restricción de unicidad
  `(id_pasajero, id_viaje)` del modelo relacional hecha visible en pantalla.
- **Rol de Martiniano:** responsable de la Vista (Integrante 3) y autor del brief de diseño que fija los criterios;
  definió el alcance (10 pantallas y no las 37) y el recorte de lo que queda fuera.
- **Por qué importa (CV):** la mayoría de los mockups muestran el camino feliz. Diseñar **los estados de error y de
  degradación**, y poder señalar qué regla de negocio o qué restricción de la base sostiene cada uno, es lo que
  separa un diseño decorativo de un diseño de producto. La trazabilidad pantalla → CU → endpoint → regla también
  demuestra que las tres capas del MVC fueron pensadas como un sistema y no por separado.
- **Tecnologías:** diseño de interfaces multiplataforma, prototipado navegable, OpenAPI, PostgreSQL (enums y
  restricciones del esquema), accesibilidad (objetivos táctiles, estado como texto además de color).

<!-- Próximos hitos a documentar a medida que se implementen:
     - Esquema de datos PostgreSQL y migraciones
     - Contrato OpenAPI de las tools de AG-01
     - Integración Mercado Pago (webhooks) en sandbox
     - Integración Google Maps Routes API con optimización de paradas
     - Seguimiento GPS en tiempo real (mecanismo elegido)
     - Integración WhatsApp Cloud API
     - Setup CI/CD y despliegue
     - Estrategia de testing (unit/integration/e2e)
-->
