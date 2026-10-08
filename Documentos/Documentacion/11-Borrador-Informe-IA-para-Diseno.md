# Borrador — Informe sobre IA para diseño

> **Estado:** borrador para el documento v1.1. **No está en el Word.**
> **Martiniano y Facundo (Integrantes 1+3):** parte completa. Trabajaron juntos con las mismas herramientas, así que
> es un solo bloque. Se redactó a partir del historial del repositorio y de las sesiones de trabajo con la IA; lo
> revisan y lo corrigen antes de entregar.
> **Martín (Integrante 2):** parte vacía, para que la complete él.
> **Qué no está:** las **propuestas y discusiones** entre ustedes sobre qué herramienta usar. No hay registro en
> ningún archivo. Lo que falta está marcado con `[completar: ...]`.
> **Cuando esté completo:** se integra al documento como sección 6.5 y se borra este archivo.

---

## 6.5 Informe sobre la IA usada en el diseño y el desarrollo

La consigna pide un informe con las propuestas, discusiones y conclusiones sobre las herramientas de inteligencia
artificial que se usaron **en el diseño**. Este informe cubre las que el equipo usó para **analizar, diseñar y
programar** VanFull. La IA que forma parte del producto (el asistente AG-01 y sus modelos) está en las secciones
6.1 a 6.4.

### Herramientas usadas

| Herramienta | Para qué se usó | Quién | Dónde consta |
|---|---|---|---|
| **Claude Code** | Programación y documentación sobre el repositorio: backend, API, datos y documento del MVC | Martiniano y Facundo | Historial de git; notas de ingesta (§0) |
| **Claude Design** | Las 10 pantallas y el sistema de diseño | Martiniano y Facundo | Brief de diseño UI |
| **Claude** (familia Opus), en chat | Razonamiento y diseño | `[completar: Martín, si lo usó]` | Stack y referencias |
| **ChatGPT** (GPT-5.6) | Razonamiento y diseño | `[completar: Martín]` | Stack y referencias |
| **ChatGPT Work** | Agente de trabajo y documentación. En el análisis, un informe previo se usó solo para detectar contradicciones y pendientes | `[completar: Martín]` | AS-IS consolidado; Stack y referencias |
| **Codex** | Programación. Figura asignada al rol de Integrante 3 en los prompts maestros | `[completar: Martín, si alguien lo usó]` | Notas de ingesta (§0) |

### Propuestas y discusiones

`[completar: qué otras herramientas se consideraron (por ejemplo, otros asistentes o editores con IA)]`

`[completar: por qué se eligieron estas y no otras: costo, calidad en español, integración con el código, experiencia previa]`

`[completar: qué se discutió sobre usar IA en cada etapa (análisis, diseño, programación) y qué límites se pusieron]`

| Herramienta evaluada | Para qué se evaluó | Qué se discutió | Decisión |
|---|---|---|---|
| `[completar]` | `[completar]` | `[completar]` | `[completar]` |

### Cómo se usó en el diseño

- **Análisis.** La fuente primaria fue siempre la entrevista con el dueño. El informe previo que produjo la IA se usó
  solo como insumo para localizar contradicciones, no como fuente de información de VanFull.
- **Interfaces.** Antes de pedir una sola pantalla se escribió un brief de diseño con los contextos de uso de cada
  persona, la dirección visual, una lista de prohibiciones y una plantilla de prompt. Cada pantalla se pidió con su
  caso de uso, los datos reales del contrato (con la instrucción de no inventar campos) y datos de ejemplo reales.
- **Arquitectura, datos y API.** El contrato OpenAPI se escribió antes de programar, y el modelo SQL se ejecutó contra
  un PostgreSQL real y se comprobó que rechaza datos inválidos: no se dio por bueno solo lo que "se veía bien".
- **Programación.** La IA trabaja con reglas fijas escritas en el repositorio: explicar antes de hacer, pasos chicos,
  mostrar el cambio antes de incorporarlo, verificar en vez de suponer, y decir qué no se pudo verificar.

---

## Aportes por integrante

### Martiniano y Facundo (Integrantes 1+3)

> Redactado a partir del historial de git y de las sesiones de trabajo con Claude Code. Facundo trabajó junto a
> Martiniano, con las mismas herramientas y en las mismas sesiones, así que las herramientas, las tareas y las
> conclusiones valen para los dos. Los dos revisan este bloque.

**1. Qué herramientas usaron.** Claude Code, como agente de programación y documentación sobre el repositorio, y
Claude Design, para las pantallas y el sistema de diseño. Los commits registran los modelos usados: Claude Opus 4.8,
Opus 5, Opus 5.5 y Sonnet 5.5. `[completar: si usaron además otras herramientas]`

**2. Para qué tarea.** El historial del repositorio muestra el recorrido, con las fechas de los commits firmados:

- **Repositorio y modelo de desarrollo (08/09).** Estructura del monorepo, servidor FastAPI, Docker y convenciones.
- **Modelo de datos (21/09).** Las 35 tablas, ejecutadas y verificadas sobre PostgreSQL 16.
- **Contrato de la API (21/09).** OpenAPI en YAML y en JSON, validado con una herramienta.
- **Documentación de IA y agentes (21/09).** El agente AG-01 y sus herramientas.
- **Interfaces (24 y 25/09).** El brief de diseño, las 10 pantallas y el sistema de diseño.
- **Documento del MVC (26 al 30/09).** Redacción, consolidación y cierre del PC1.
- **Correcciones por la revisión de Integrante 2 (28/09 al 01/10).** Del contrato, del modelo y de las pantallas.
- **Decisión de alojamiento (02/10).** Comparación de Neon, Supabase, Render, Railway y Firebase con los límites de cada
  plan, tomados de su documentación oficial.
- **Documento v1.1 (08/10).** Propuestas, análisis, diagramas de actividad, de componentes y de despliegue.

**3. Qué descartaron y por qué.** `[completar: herramientas de IA que probaron y no siguieron usando, y el motivo]`

**4. Errores de la IA que tuvieron que corregir.** Además de los registrados arriba, en las sesiones se detectaron estos
casos, todos al contrastar con el entregable real o con la fuente:

- Claude Code afirmó que una decisión (ADJ-03) ya estaba propagada al documento del MVC; solo lo estaba en el archivo
  `.md` y no en el Word entregado. Se había verificado contra el repositorio y no contra el entregable.
- Afirmó que el Word del Drive "no se había modificado" desde cierta fecha, cuando ya tenía las imágenes pegadas. Se
  vio por el tamaño del archivo.
- Dijo que la carátula del Word no tenía los nombres del equipo, porque leyó el `.md`; el Word sí los tenía.
- Dijo que los reportes quedaban fuera del alcance; el apartado 1.4 los incluye como parte del alcance.
- Al regenerar el Word desde la v1.0 iba a pisar dos ediciones manuales de Martiniano. Se detectó comparando con su
  versión vigente antes de entregarla.
- En las pantallas, la fecha "jueves 25/09" era un viernes. Se vio al verificar el calendario.

**5. Qué decidieron ellos y no la IA.** Las decisiones que constan en los documentos son de Martiniano:

- El stack y la arquitectura base (Flutter, FastAPI, PostgreSQL, OpenRouter), el monorepo y que el contrato OpenAPI
  se escribe antes de programar.
- Las reglas de trabajo con la IA: explicar antes de hacer, pasos chicos, ver el cambio antes de incorporarlo, y que
  cada commit y cada fusión los aprueba Martiniano.
- El alcance de las pantallas: diez de los 37 casos de uso, con los tres tipos de usuario.
- Las fechas válidas de los puntos de control: el cronograma preparado con IA traía las fechas de inicio de cada
  semana, y Martiniano las corrigió a los viernes de encuentro (02/10, 30/10 y 13/11).
- El alojamiento sin costo (Neon, Render y GitHub Pages) después de comparar las opciones.
- Qué se incorpora al documento y qué no: por ejemplo, sacó dos fragmentos que la IA había redactado en la tabla de la
  propuesta seleccionada (la marca de pendiente del backend y la mención a PostGIS).

**Conclusiones sobre las herramientas.**

- **Claude Code rinde cuando tiene reglas escritas y contexto en archivos.** Por eso se escribieron `CLAUDE.md`,
  `CONTEXTO.md` y los prompts de arranque por tipo de tarea: un chat nuevo no arranca de cero, y se definió cuándo
  conviene abrir uno.
- **El riesgo principal fue darlo por hecho sin verificar el entregable real.** Se corrigió exigiendo contrastar con el
  archivo final y decir explícitamente lo que no se pudo verificar (por ejemplo, que no se podían correr las pruebas
  ni renderizar el Word en esa máquina).
- **Claude Design necesita un brief.** Sin contexto de uso y sin prohibiciones explícitas produce el diseño promedio
  que genera cualquier IA; con el brief, las tres pantallas resultaron distintas a propósito.
- **Recomendación:** pedir siempre el cambio mostrado antes de incorporarlo, y no aceptar una afirmación de "ya está
  hecho" sin una verificación que se pueda repetir.

`[completar: agregar las decisiones propias de Facundo, y corregir lo que no refleje la experiencia de alguno de los dos]`

### Martín (Integrante 2)

**1. Qué herramientas usó.** `[completar: Martín]`

**2. Para qué tarea.** `[completar: Martín]`

**3. Qué descartó y por qué.** `[completar: Martín]`

**4. Errores de la IA que tuvo que corregir.** `[completar: Martín — un ejemplo concreto por herramienta]`

**5. Qué decidió él y no la IA.** `[completar: Martín]`

**Conclusiones sobre las herramientas.** `[completar: Martín — qué recomendaría y qué no]`

---

### Qué salió mal y se corrigió

En pantallas y documentos hechos con ayuda de IA aparecieron errores y contradicciones. Se detectaron en la revisión y
están registrados:

- **Reglas inventadas en las pantallas.** Tres pantallas afirmaban reglas que no existen en la línea funcional:
  un bloqueo tras cuatro intentos, una cancelación "ocho horas antes" y que un viaje sin vehículo no acepta reservas
  nuevas. Se quitaron.
- **El flujo del código QR, invertido.** Una pantalla mostraba al chofer escaneando, cuando quien escanea es el
  pasajero. Lo detectó Integrante 2 el 28/09 y se corrigió en las pantallas, el brief y el documento.
- **Una nota que contradecía al agente.** El documento de IA decía que AG-01 "solo consulta", pero tiene 13
  herramientas e incluye crear y cancelar reservas.
- **Cifras que se desalinearon entre documentos** (11 contra 13 herramientas, 22 contra 23 esquemas). De ahí salió la
  regla de que un dato vive en un solo lugar.
- **Un contrato desactualizado.** El archivo JSON conservaba una descripción vieja de `POST /viajes`; se regeneró
  desde el YAML y se verificó que los dos fueran equivalentes.

### Conclusiones del equipo

Lo que muestra el historial del proyecto:

- **La IA acelera, pero no decide.** Toda salida pasó por revisión humana antes de convertirse en requisito, regla o
  código. Una sugerencia de la IA no es una decisión del proyecto.
- **Un error que se repitió fue afirmar como hecho algo que nadie aprobó** (las tres reglas de las pantallas, por
  ejemplo). Por eso la regla de trabajo es que lo que no está aprobado es un pendiente, no una inferencia.
- **Verificar contra la fuente y ejecutar validaciones sirve.** Varios errores se encontraron contrastando contra el
  contrato, el modelo de datos o la línea funcional, y corriendo validaciones, no solo releyendo el texto.
- **Queda registro.** Al 08/10/2026, de los 30 commits propios del repositorio (sin contar las fusiones), 28 llevan la
  firma `Co-Authored-By` de Claude: se puede rastrear qué cambios se hicieron con ayuda de IA.

`[completar: conclusiones del equipo sobre cada herramienta, una vez que Martín complete la suya]`

### Gobernanza

Revisión humana obligatoria antes de incorporar cualquier salida de IA. Según el modelo de desarrollo (sección 7.2),
cada cambio entra por una rama y lo revisa un compañero antes de incorporarse. Se respeta una jerarquía de fuentes:
lo que exigen los profesores, lo que confirmó VanFull, lo que decidió el equipo, y recién después las propuestas de IA,
que solo valen una vez aprobadas.
