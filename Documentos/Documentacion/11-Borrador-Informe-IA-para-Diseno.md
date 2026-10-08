# Borrador — Informe sobre IA para diseño

> **Estado:** borrador para el documento v1.1. **No está en el Word.** Lo necesita completar el equipo.
> **Qué está escrito:** solo lo que consta en documentos del proyecto (`Stack-y-Referencias.md`, `07-IA-y-Agentes`,
> `06-Notas-Ingesta`, el brief de diseño, `CLAUDE.md`, el historial de git y el README de la carpeta 07 del Drive).
> **Qué no está:** las **propuestas y discusiones** entre ustedes sobre qué herramienta usar. No hay registro en
> ningún archivo. Todo eso está marcado con `[completar: ...]` y lo tienen que escribir ustedes.
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
| **ChatGPT** (GPT-5.6) | Razonamiento y diseño | `[completar: quiénes y en qué momentos]` | Stack y referencias |
| **Claude** (familia Opus) | Razonamiento y diseño | `[completar: quiénes]` | Stack y referencias |
| **ChatGPT Work** | Agente de trabajo y documentación. En el análisis, un informe previo se usó solo para detectar contradicciones y pendientes | `[completar: confirmar quién]` | AS-IS consolidado; Stack y referencias |
| **Codex** | Programación (Flutter y agentes) | Integrante 3, según los prompts maestros. `[completar: confirmar]` | Notas de ingesta (§0) |
| **Claude Code** | Programación: backend, API y datos | Integrante 1, según los prompts maestros | Notas de ingesta (§0); historial de git |
| **Claude Design** | Las 10 pantallas y el sistema de diseño | Integrantes 1 y 3 | Brief de diseño UI |

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

`[completar: ejemplos de errores de ChatGPT o Codex que hayan tenido que corregir]`

### Conclusiones

Lo que muestra el historial del proyecto:

- **La IA acelera, pero no decide.** Toda salida pasó por revisión humana antes de convertirse en requisito, regla o
  código. Una sugerencia de la IA no es una decisión del proyecto.
- **Un error que se repitió fue afirmar como hecho algo que nadie aprobó** (las tres reglas de las pantallas, por
  ejemplo). Por eso la regla de trabajo es que lo que no está aprobado es un pendiente, no una inferencia.
- **Verificar contra la fuente y ejecutar validaciones sirve.** Varios errores se encontraron contrastando contra el
  contrato, el modelo de datos o la línea funcional, y corriendo validaciones, no solo releyendo el texto.
- **Queda registro.** Al 08/10/2026, de los 30 commits propios del repositorio (sin contar las fusiones), 28 llevan la
  firma `Co-Authored-By` de Claude: se puede rastrear qué cambios se hicieron con ayuda de IA.

`[completar: conclusiones de cada integrante sobre cada herramienta: qué recomendarían y qué no]`

### Gobernanza

Revisión humana obligatoria antes de incorporar cualquier salida de IA. Según el modelo de desarrollo (sección 7.2),
cada cambio entra por una rama y lo revisa un compañero antes de incorporarse. Se respeta una jerarquía de fuentes: lo que exigen los profesores, lo que confirmó VanFull, lo que
decidió el equipo, y recién después las propuestas de IA, que solo valen una vez aprobadas.

---

## Preguntas para completar (una respuesta por integrante)

1. ¿Qué herramientas de IA usaste en el proyecto?
2. ¿Para qué tarea usaste cada una?
3. ¿Cuáles descartaste y por qué?
4. ¿Qué errores de la IA tuviste que corregir? Un ejemplo concreto por herramienta.
5. ¿Qué decisión tomaste vos y no la IA?
