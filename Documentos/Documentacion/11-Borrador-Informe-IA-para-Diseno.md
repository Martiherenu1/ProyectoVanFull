# Borrador — Informe sobre IA para diseño

> **Estado:** borrador para el documento v1.1. **No está en el Word.**
> **Martiniano (Integrante 1+3):** parte completa. Se redactó a partir del historial del repositorio y de las sesiones
> de trabajo con Claude Code; lo revisa y lo corrige antes de entregar.
> **Facundo (Integrante 1+3):** parte completa, con el texto que él mismo escribió (usó ChatGPT, no Claude Code).
> **Martín (Integrante 2):** parte completa, con el texto que él mismo escribió. Su comparación entre ChatGPT y Gemini
> fue práctica, no una evaluación formal.
> **Qué falta:** que los tres lean el borrador completo y corrijan lo que no refleje su experiencia. Las conclusiones
> del equipo se redactaron a partir de los tres bloques y las revisan los tres. No hay registro de una discusión
> formal entre ustedes sobre qué herramienta usar. Ya no quedan marcas `[completar]`.
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
| **Claude Code** | Programación y documentación sobre el repositorio: backend, API, datos y documento del MVC | Martiniano | Historial de git; notas de ingesta (§0) |
| **Claude Design** | Las 10 pantallas y el sistema de diseño | Martiniano | Brief de diseño UI |
| **Prompt Cowboy** | Generar el prompt inicial de las sesiones con Claude Code, donde se explicó cómo se iba a trabajar | Martiniano | Declarado por Martiniano |
| **Claude** (familia Opus), en chat | Razonamiento y diseño | Nadie del equipo lo usó durante el PC1 | Stack y referencias |
| **ChatGPT** (GPT-5.6) | Martín: relevamiento, análisis funcional, modelado, trazabilidad y revisión documental. Facundo: apoyo conversacional para entender el proyecto, revisar la entrega contra la consigna y hacer borradores | Martín y Facundo | Stack y referencias; informes de cada uno |
| **ChatGPT Work** | Agente de trabajo y documentación. Se usó en análisis extensos y revisión transversal; en el análisis de la entrevista se usó solo para detectar contradicciones y pendientes | Martín | AS-IS consolidado; trabajos de análisis y actualización de artefactos |
| **Codex** | Programación. Figura asignada al rol de Integrante 3 en los prompts maestros | Nadie lo usó hasta ahora. Facundo lo va a usar para implementar durante el desarrollo | Notas de ingesta (§0) |

### Propuestas y discusiones

No hay registro de una discusión formal del equipo sobre qué herramienta usar. Lo que sigue es lo que cada integrante
considera sobre su propia elección; la de Facundo está en su bloque, más abajo.

**Martín (Integrante 2).** Las alternativas consideradas de forma práctica fueron **ChatGPT** y **Gemini**. Ambas
herramientas estaban disponibles en planes pagos. No se realizó una matriz comparativa formal ni un benchmark
documentado: la elección se basó en la experiencia de uso durante las tareas de análisis y diseño del proyecto.

Martín eligió **ChatGPT** para el relevamiento y análisis porque, en su experiencia, ofrecía un lenguaje más natural y
respuestas más detalladas que Gemini. También le resultó más adecuado para el trabajo con artefactos visuales y de
modelado utilizados en VanFull, especialmente diagramas en **PlantUML**, archivos **draw.io** y generación/revisión de
imágenes **PNG**. Gemini quedó disponible como alternativa, pero no se adoptó como herramienta principal para esta etapa.

Para tareas extensas, Martín utilizó **ChatGPT Work** en tres casos: (1) análisis de la entrevista con VanFull,
(2) explicación del MVC aplicado a VanFull y (3) actualización de Casos de Uso y artefactos de la Etapa 04. El uso más
relevante fue el análisis de la entrevista. En todos los casos se mantuvo el mismo límite: la IA podía organizar, comparar,
detectar contradicciones o proponer, pero no reemplazar la entrevista, las correcciones docentes ni las decisiones del equipo.

Martín no utilizó **Claude en chat** ni **Codex** durante el PC1 porque su trabajo estuvo concentrado en relevamiento,
análisis, requisitos, UML, datos conceptuales/lógicos y revisión, no en generación de código. Considera utilizarlos en
próximos puntos de control si sus tareas pasan a requerir programación. No se documentó una discusión formal del equipo
sobre estas herramientas desde su rol; por eso no se presentan como alternativas descartadas por una evaluación técnica.

| Herramienta evaluada | Para qué se evaluó | Qué se discutió | Decisión |
|---|---|---|---|
| **ChatGPT** | Relevamiento, análisis funcional, requisitos, UML, modelado, revisión y documentación | Calidad de redacción en español, nivel de detalle y capacidad para asistir con PUML/draw.io/PNG | **Seleccionada por Martín como herramienta principal** |
| **Gemini** | Alternativa para análisis y diseño | En la experiencia de Martín, respuestas menos naturales/detalladas y mayores limitaciones para el trabajo de diagramas e imágenes del proyecto | **No adoptada como herramienta principal** |
| **ChatGPT Work** | Análisis documental extenso y actualización transversal de artefactos | Conveniencia para tareas largas con múltiples fuentes; necesidad de verificar cada resultado contra la fuente primaria | **Utilizada en tres trabajos puntuales** |
| **Claude en chat / Codex** | Posible uso futuro en razonamiento/programación | No eran necesarios para las tareas de Martín en PC1 | **No utilizados por Martín en PC1** |

**Martiniano (Integrante 1+3).** No consideré otras herramientas para programar y diseñar: elegí **Claude Code** y
**Claude Design** porque ya había trabajado con ellas, para poder usar archivos de instrucciones reutilizables
(`skills.md`) y por su manejo del consumo de tokens. Además, las considero de las mejores valoradas para el desarrollo
de software. Fue una elección por experiencia previa, no el resultado de una comparación.

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

### Martiniano (Integrante 1+3)

> Redactado a partir del historial de git y de las sesiones de trabajo con Claude Code, y revisado por Martiniano.
> Facundo tiene el suyo más abajo porque usó otra herramienta.

**1. Qué herramientas usé.** Claude Code, como agente de programación y documentación sobre el repositorio, y
Claude Design, para las pantallas y el sistema de diseño. Los commits registran los modelos usados: Claude Opus 4.8,
Opus 5, Opus 5.5 y Sonnet 5.5. La única otra herramienta que usé fue **Prompt Cowboy**, para generar el prompt inicial
con el que le expliqué a Claude Code cómo íbamos a trabajar.

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

**3. Qué descarté y por qué.** Nada: como no evalué otras herramientas, no descarté ninguna.

**4. Errores de la IA que tuve que corregir.** Además de los registrados arriba, en las sesiones se detectaron estos
casos, todos al contrastar con el entregable real o con la fuente:

- Claude Code afirmó que una decisión (ADJ-03) ya estaba propagada al documento del MVC; solo lo estaba en el archivo
  `.md` y no en el Word entregado. Se había verificado contra el repositorio y no contra el entregable.
- Afirmó que el Word del Drive "no se había modificado" desde cierta fecha, cuando ya tenía las imágenes pegadas. Se
  vio por el tamaño del archivo.
- Dijo que la carátula del Word no tenía los nombres del equipo, porque leyó el `.md`; el Word sí los tenía.
- Dijo que los reportes quedaban fuera del alcance; el apartado 1.4 los incluye como parte del alcance.
- Al regenerar el Word desde la v1.0 iba a pisar dos ediciones manuales mías. Se detectó comparando con mi
  versión vigente antes de entregarla.
- En las pantallas, la fecha "jueves 25/09" era un viernes. Se vio al verificar el calendario.

**5. Qué decidí yo y no la IA.** Estas decisiones las tomé yo y constan en los documentos:

- El stack y la arquitectura base (Flutter, FastAPI, PostgreSQL, OpenRouter), el monorepo y que el contrato OpenAPI
  se escribe antes de programar.
- Las reglas de trabajo con la IA: explicar antes de hacer, pasos chicos, ver el cambio antes de incorporarlo, y que
  cada commit y cada fusión los apruebo yo.
- El alcance de las pantallas: diez de los 37 casos de uso, con los tres tipos de usuario.
- Las fechas válidas de los puntos de control: el cronograma preparado con IA traía las fechas de inicio de cada
  semana, y yo las corregí a los viernes de encuentro (02/10, 30/10 y 13/11).
- El alojamiento sin costo (Neon, Render y GitHub Pages) después de comparar las opciones.
- Qué se incorpora al documento y qué no: por ejemplo, saqué dos fragmentos que la IA había redactado en la tabla de la
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


### Facundo (Integrante 1+3)

> Texto escrito por Facundo, tal cual lo envió; solo se adaptaron los títulos al formato del documento.
**Cómo usé la IA.** Durante el diseño de VanFull utilicé ChatGPT como herramienta de apoyo para comprender el
proyecto, organizar la información y revisar la documentación. Me resultó especialmente útil para relacionar los
requisitos del negocio con las interfaces, los casos de uso y la arquitectura propuesta.

Mi intención fue utilizar la inteligencia artificial como un asistente con el que pudiera discutir ideas y hacer
preguntas. A medida que avanzaba el proyecto, necesitaba entender no solo qué tecnologías habíamos elegido, sino
también qué función cumplía cada una y cómo se conectaban entre sí.

**Propuestas y elección de herramientas.** Dentro de las herramientas contempladas en el proyecto se encontraban
ChatGPT y Claude para tareas de análisis, diseño y documentación, y Codex y Claude Code para actividades relacionadas
con el código.

En mi caso, elegí ChatGPT como apoyo principal porque podía trabajar de manera conversacional: presentar una duda,
pedir una explicación más sencilla y profundizar hasta comprender el tema. Esto me sirvió para revisar conceptos como
la comunicación entre frontend y backend, los endpoints de una API, el funcionamiento de FastAPI y el acceso a la base
de datos mediante un ORM.

También consideré importante que la herramienta pudiera trabajar sobre la documentación existente. Para mí, una
respuesta útil debía estar relacionada con VanFull y con las decisiones del equipo, además de explicar conceptos
generales.

Claude aparece en el proyecto asociado a propuestas de interfaces y prototipos. Ese uso complementa el trabajo de
análisis: permite visualizar una solución y discutir cómo se organizarían las pantallas y las acciones del usuario. No
considero necesario elegir una única herramienta para todas las tareas; la elección depende del tipo de trabajo y de
la posibilidad de revisar el resultado.

**Uso personal durante el diseño.** Utilicé ChatGPT para consultar dudas técnicas y comprender mejor las decisiones
del proyecto. Por ejemplo, trabajé sobre el papel de FastAPI y la diferencia entre una API, el backend y la base de
datos. A través de preguntas sucesivas pude aclarar cómo una acción realizada desde una pantalla llega al servidor y
cómo este consulta o modifica los datos.

También lo utilicé para revisar la entrega del primer punto de control. Comparé las indicaciones de la cátedra con el
contenido del documento y con el material disponible del proyecto. Esta revisión ayudó a identificar qué apartados ya
estaban cubiertos y cuáles requerían una explicación adicional o la incorporación de diagramas.

Otro uso fue la elaboración de borradores. La herramienta me permitió ordenar ideas y convertir información técnica en
textos más claros. Sin embargo, esos borradores necesitaban una lectura posterior para verificar que expresaran
correctamente el funcionamiento de VanFull.

**Discusiones y dificultades.** Una de las cuestiones que considero más importantes es que una respuesta bien
redactada puede parecer correcta aunque contenga supuestos equivocados. Por eso, no alcanza con que la IA explique algo
con seguridad: hay que contrastarlo con los requisitos y las reglas del proyecto.

En la revisión de las interfaces aparecieron condiciones que no estaban respaldadas por la documentación, como un
bloqueo después de cuatro intentos de acceso o una regla general de cancelación con ocho horas de anticipación.
También se detectó una restricción sobre recibir reservas sin tener un vehículo asignado, cuando el proyecto permite
planificar un viaje y completar posteriormente la asignación de vehículo y chofer.

Estos ejemplos me hicieron prestar más atención a los textos de las pantallas. Un mensaje o un botón también puede
introducir una regla de negocio, aunque parezca un detalle de presentación.

Además, comprendí que debía pedir explicaciones más concretas cuando una respuesta era demasiado técnica. Reformular
las preguntas y solicitar ejemplos relacionados con VanFull me ayudó a entender las propuestas y a evaluarlas con
mayor criterio.

**Conclusiones personales.** Mi experiencia con la inteligencia artificial fue positiva porque me permitió resolver
dudas, organizar información y participar en la revisión del diseño con una mejor comprensión del proyecto.

La decisión que mantuve bajo mi responsabilidad fue qué información aceptar e incorporar. Una propuesta de la IA debía
coincidir con la documentación y las decisiones del equipo antes de convertirse en parte del trabajo.

Como conclusión, considero que estas herramientas son útiles cuando se utilizan con un objetivo concreto y con revisión
humana. En VanFull, su aporte estuvo en facilitar el análisis y la elaboración de propuestas, mientras que la
validación del diseño y las decisiones finales permanecieron a cargo de los integrantes del proyecto.

### Martín (Integrante 2)

> Texto escrito por Martín, tal cual lo envió.

**1. Qué herramientas usó.** Utilicé principalmente **ChatGPT** para el relevamiento, análisis funcional, ingeniería de
requisitos, modelado, trazabilidad y revisión documental. También utilicé **ChatGPT Work** para tres trabajos concretos:
el análisis de la entrevista con VanFull, la explicación del MVC aplicado al proyecto y la actualización de Casos de Uso y
artefactos de la Etapa 04. El trabajo más importante realizado con Work fue el análisis de la entrevista. Durante el PC1 no
utilicé Claude en chat ni Codex.

**2. Para qué tarea.** ChatGPT se utilizó para organizar y revisar el relevamiento; consolidar el AS-IS; elaborar y revisar
alcance, RF, RNF y reglas de negocio; trabajar sobre actores y los 37 Casos de Uso; revisar el Modelo Conceptual y los
Diagramas de Actividad; asistir en DER y Modelo Relacional; mantener trazabilidad; preparar controles de cambio; y realizar
revisiones cruzadas entre requisitos, modelo, contrato API, interfaces y documentación. Work se reservó para trabajos más
extensos que requerían comparar varias fuentes o actualizar varios artefactos relacionados.

**3. Qué descartó y por qué.** Tengo disponibles en modalidad paga tanto **ChatGPT** como **Gemini**. Para esta etapa
decidí trabajar con ChatGPT porque, en mi experiencia, el lenguaje resultó más natural y las respuestas más detalladas para
el relevamiento y análisis. También me dio mejores resultados para el trabajo de diseño y modelado que necesitábamos en
VanFull, especialmente PlantUML, draw.io y PNG, donde encontré más limitaciones con Gemini. Esta elección fue práctica y
basada en mi experiencia de uso; no hicimos una evaluación formal ni una matriz comparativa entre ambas. No utilicé Claude
en chat ni Codex porque mi responsabilidad durante PC1 no estuvo orientada a generación de código.

**4. Errores de la IA que tuvo que corregir.** Con ChatGPT, uno de los riesgos que apareció varias veces fue que una
respuesta plausible podía conservar una regla o interpretación desactualizada si no se contrastaba con toda la línea base.
Un caso concreto fue la semántica de pagos: en documentación previa permanecía la idea de que la confirmación final era
siempre humana, pero el control de cambio aprobado establecía que Mercado Pago confirma automáticamente cuando informa
válidamente una operación aprobada o acreditada. La contradicción se detectó en la revisión y se corrigió en los artefactos
correspondientes. También detecté el 28/09 el flujo del QR invertido en una interfaz: mostraba al chofer escaneando, cuando
según los Casos de Uso aprobados quien escanea el QR del vehículo es el pasajero; se corrigieron la pantalla, el brief y la
documentación.

En **ChatGPT Work** no tengo documentado un error puntual atribuible exclusivamente a la herramienta que pueda separar
con certeza del resto de las revisiones. Su principal riesgo durante el análisis de la entrevista era que una inferencia útil
pudiera confundirse con información confirmada. Por eso el resultado de Work se utilizó como apoyo para detectar
contradicciones y pendientes, pero cada afirmación relevante se contrastó contra la entrevista y las decisiones aprobadas.

**5. Qué decidió él y no la IA.** Yo decidí qué herramienta utilizar para mi área, qué propuestas de la IA aceptar como
insumo, cuáles rechazar y cuáles mantener como pendientes. La IA no tuvo autoridad para crear requisitos, reglas de negocio
o decisiones de modelado. Cuando una cuestión requería decisión del equipo, mi tarea fue detectar el punto, documentar el
impacto y llevarlo a validación. Los RF, RNF, RN, Casos de Uso y ajustes transversales aprobados son decisiones del equipo,
no decisiones de la IA ni mías en forma individual. En mi rol también decidí exigir trazabilidad entre artefactos y revisar
los cambios contra la fuente de mayor autoridad antes de considerarlos cerrados.

**Conclusiones sobre las herramientas.** Recomendaría **ChatGPT** para análisis, modelado, revisión y generación de
propuestas cuando se le proporciona una base documental clara y se conserva revisión humana. **ChatGPT Work** resultó
especialmente útil para tareas largas que combinan varias fuentes, como el análisis de la entrevista y la actualización
transversal de artefactos. No recomendaría usar ninguna IA como fuente primaria ni aceptar automáticamente un requisito,
una regla, una relación de datos o un comportamiento solo porque la respuesta sea razonable. La mayor utilidad aparece
cuando la IA acelera la comparación y la elaboración, mientras una persona mantiene la trazabilidad, verifica contra las
fuentes y conserva la decisión final. Para próximas etapas, si mi responsabilidad incorpora programación, evaluaría el uso
de Codex u otras herramientas orientadas a código en función de la tarea concreta.

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

**Qué conclusión deja cada herramienta**, según lo que cuenta quien la usó:

- **ChatGPT** (Martín y Facundo). Sirvió para analizar, ordenar y explicar. Martín lo recomienda para análisis,
  modelado y revisión cuando se le da una base documental clara; Facundo lo usó para entender cómo se conectan las
  partes del proyecto y para revisar la entrega contra la consigna. Los dos coinciden en que una respuesta convincente
  puede traer una regla desactualizada o un supuesto equivocado, y en que hay que contrastarla con la documentación.
- **ChatGPT Work** (Martín). Rindió en tareas largas que combinan varias fuentes, como el análisis de la entrevista.
  Su resultado se usó para detectar contradicciones y pendientes, y cada afirmación relevante se contrastó con la fuente.
- **Claude Code y Claude Design** (Martiniano). Rinden cuando tienen reglas escritas, contexto en archivos y, para las
  pantallas, un brief con prohibiciones explícitas. El riesgo principal fue darlo por hecho sin verificar contra el
  entregable real.
- **Codex.** Nadie lo usó hasta ahora; Facundo lo va a usar para implementar. Todavía no hay experiencia que evaluar.

**Qué coincide entre los tres.** Ninguno usó la IA como fuente primaria ni aceptó una propuesta solo porque estuviera
bien redactada. Los tres dejan la decisión final en las personas y la validación contra los requisitos, las reglas del
proyecto y las fuentes aprobadas. Las herramientas se repartieron por tipo de trabajo: ChatGPT para el análisis y para
entender, Claude para el repositorio y las pantallas.

**Qué no se hizo y conviene decirlo.** No hubo una comparación formal de herramientas: cada integrante eligió la suya
por experiencia previa y por cómo le resultó en la práctica. Estas conclusiones valen para el PC1. Cuando Codex entre
en el desarrollo habrá que sumar qué se aprende con él.

### Gobernanza

Revisión humana obligatoria antes de incorporar cualquier salida de IA. Según el modelo de desarrollo (sección 7.2),
cada cambio entra por una rama y lo revisa un compañero antes de incorporarse. Se respeta una jerarquía de fuentes:
lo que exigen los profesores, lo que confirmó VanFull, lo que decidió el equipo, y recién después las propuestas de IA,
que solo valen una vez aprobadas.
