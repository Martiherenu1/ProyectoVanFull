# Análisis de CU-007 — Registrar abordaje mediante QR

## Estado vigente y aclaraciones operativas — 10/11/2026

**Alcance de esta actualización:** análisis documental para la coordinación de
CU-007 hacia PC3. No acredita implementación ni aprueba cambios de modelo, contrato,
QR, sincronización o dependencias. Las secciones fechadas 30/10 se conservan como
historial: sus pendientes se deben leer junto con las aclaraciones de esta sección.
Las referencias a main, PR, worktrees y congelamiento de la demo del 30/10 son
históricas; no se verificó aquí el main ni el despliegue vigente del 10/11. El horario
de aquella demo no se extiende automáticamente a esta nueva etapa.

### Procedencia y autoridad

- **S10 — Información de VanFull comunicada por Martín el 10/11/2026:** Martín
  respondió las preguntas funcionales recordando la entrevista. Se registra como
  **CONFIRMADO POR VANFULL — informado por Martín**, con atribución expresa a ese
  recuerdo. No constituye una entrevista nueva, una cita textual recuperada del
  25/08 ni una verificación independiente con la empresa. No se atribuye aprobación
  técnica conjunta a Martiniano y Facundo por el solo hecho de incorporarla aquí.
- **S11 — Coordinación del 10/11 informada por Martín:** Facundo y Martiniano
  propusieron validar descenso, habilitaciones y comportamiento offline con VanFull;
  decidir técnicamente QR, sesión e históricos entre los tres. Facundo ofreció
  revisar Flutter compartido, escaneo, offline y sesión, manteniendo como prioridad
  CU-036/Mercado Pago antes del 20/11. Martiniano propuso presentar CU-007 en PC3
  como diseño documentado y pidió leer este archivo. Son mensajes transmitidos por
  Martín, sin comprobación externa ni aprobación de las alternativas técnicas.
  Las respuestas S10 se agregan ahora para su revisión, sin afirmar que ya fueron
  leídas por ambos, enviadas al cliente o incorporadas al repositorio.
- **Contraste acotado con la entrevista original disponible:** se leyeron los
  pasajes de `01_Entrevista_VanFull_2026-08-25.docx` sobre servicios/destinos,
  recorridos/paradas, chofer y pérdida de conexión. Menciona UADE/UCA, paradas
  fijas, orden establecido por el dueño, que el chofer no confirma el abordaje y
  que los pasajeros escanean igualmente ante pérdida de conexión del chofer.
  No se encontró en esos pasajes el detalle completo de S10 sobre modalidades,
  descenso sin control, DNI o conservación de conflictos: su fuente sigue siendo
  el recuerdo comunicado por Martín, no una cita atribuida a ese archivo.

### Aclaraciones funcionales comunicadas por Martín

| Tema | Información aportada y alcance | Efecto sobre CU-007 |
|---|---|---|
| Universitario, recorrido hacia universidades | Debe seleccionar una parada de destino de UADE o UCA. Esos son los fines de recorrido actuales; puede pedir bajar antes y no se controla el descenso real. | Distinguir destino previsto de descenso físico. No extender automáticamente este criterio a VUELTA ni a otros servicios. |
| Laboral en la misma unidad | Elige una parada de descenso: puede ser UADE/UCA u otra parada habilitada anterior. Estudiantes y laborales pueden compartir vehículo. | La última parada no sustituye al destino individual del laboral. El filtro y la persistencia del destino requieren diseño. |
| Separación de paradas | Las paradas de ascenso no son de descenso. Nadie prohíbe bajar antes si el pasajero se arrepiente o lo pide al chofer. | Representar opciones de ascenso y descenso diferenciadas; no convertir una bajada informal en cambio de reserva o en registro de descenso. |
| Cambio durante el viaje | Laborales y casuales no pueden cambiar su parada en el sistema cuando el viaje está en curso; pueden pedir al chofer bajar antes. | No agregar edición en curso ni registro de descenso a CU-007. Esto no define todavía las opciones de destino del casual. |
| Ascenso alternativo | Se admite acercarse a otra parada donde el vehículo todavía no pasó, por ejemplo si el pasajero perdió el servicio en la reservada. | Mantener S5: mismo recorrido, opción habilitada y ascenso real anterior al descenso previsto; conservar el ascenso reservado. El ejemplo no exige seguimiento automático de paradas alcanzadas mediante GPS. |
| Autoridad operativa | Administración o el dueño decide las paradas habilitadas. | Autoridad funcional aclarada. No decide si se almacenan por recorrido, viaje o plantilla con excepciones. |
| Descenso real | Actualmente no se controla ni por QR ni por GPS. | No incorporar control de bajada, segundo escaneo, geocerca ni constatación del descenso efectivo. |
| Registro sin conexión | El pasajero debe poder registrar que subió y enviar el registro al recuperar conexión. | Confirma continuidad del alcance offline ya respaldado por S1/S4; un pendiente local sigue sin ser confirmación autoritativa del servidor. |
| Presentación al chofer sin conexión | Puede mostrar la pantalla de VanFull con foto y habilitación, o su DNI. | No convierte al chofer en registrador/confirmador del abordaje. Falta resolver cómo se comprueba habilitación/reserva cuando solo se muestra DNI y la vigencia de datos mostrados offline. |
| Envío que no valida al sincronizar | Martín indica que queda registrado como envío de una situación errónea. | Conservar el intento y su resultado/motivo; no descartarlo silenciosamente. No implica aceptarlo como abordaje válido, recuperar cupo, reescribir historia ni crear un circuito de aprobación manual todavía no definido. |

**Alcance del contraste y diferencias de fuentes:** la entrevista del 25/08 admite
cambiar parada después de reservar «solo si hay cupo», sin precisar el estado del
viaje. S10 agrega el límite durante `en_curso` para laborales/casuales; no se usa la
frase general anterior como autorización para editar en curso. El mismo archivo
original indica que el recorrido no cambia según los pasajeros del día; la
configuración de habilitaciones por viaje de S6 es otra dimensión y no autoriza
alterar el recorrido. Si se pretende equipararlas, corresponde validar la diferencia,
no elegir una interpretación silenciosamente.

### Qué se aclara y qué sigue pendiente

Las preguntas generales por destino universitario/laboral hacia UADE/UCA, separación
de ascenso/descenso, autoridad, necesidad de captura offline y conservación de
situaciones erróneas tienen ahora respuesta atribuida a S10. No volver a presentarlas
como totalmente desconocidas. Falta revisión del equipo y estas precisiones:

1. **Casual:** confirmar si comparte las opciones de destino del laboral; no deducirlo
   de que ambos tengan restringido el cambio en curso.
2. **VUELTA y otros servicios:** precisar selección y habilitación de ascenso/descenso.
   S10 describe el trayecto hacia UADE/UCA. S6 ya contiene antecedentes de elección
   por viaje en VUELTA; contrastarlos antes de volver a preguntar y no invertir el
   orden ni derivar la vuelta de la ida automáticamente.
3. **Conflictos offline:** definir quién puede consultar las situaciones erróneas,
   qué tratamiento operativo reciben y si requieren resolución. Conservar el envío
   no equivale a validarlo ni autoriza al chofer a confirmarlo. Una falla de red o
   una respuesta perdida tampoco demuestran una situación inválida de negocio.
4. **Control con DNI:** precisar cómo verifica el chofer habilitación y reserva si
   el pasajero no puede mostrar la pantalla. No afirmar que DNI acredita habilitación,
   ni asumir rechazo automático por no tener Internet.
5. **Configuración y horario:** acordar alcance de habilitaciones (recorrido/viaje/
   excepciones) y vigencia de sus datos; conservar pendiente la correspondencia
   horaria de RN-023, sin inventar ventanas ni comprobación física automática.

**Diseño técnico pendiente de los tres:** representación y migración del descenso
previsto; configuración de opciones; formato/ciclo del QR; identidad durable de
operación e idempotencia; almacenamiento por cuenta; sincronización, reautenticación,
retención y protección de datos; aislamiento de callbacks y conservación de unidad
histórica bajo las FK existentes. Las recomendaciones 1–5 inferiores siguen siendo
**PROPUESTA DE IA** y aportes para discusión, no decisiones aprobadas.

Las alternativas de pedir descenso por primera vez al escanear o derivarlo de la
última parada no deben adoptarse como solución implícita. El destino previsto debe
tener una fuente acordada; no se exige controlar el descenso real. Los estados
conceptuales pendiente/confirmado/no validado no fijan nombres de columnas ni códigos
HTTP. RNF-011 mantiene el intento de sincronización dentro del objetivo de 60 s al
recuperar conectividad; no garantiza éxito y no se modifica mediante S10.

### Ajustes a la matriz y aceptación propuesta

Estas filas actualizan la lectura de las matrices históricas, sin atribuir pruebas
ejecutadas ni resultados nuevos:

| Elemento previo | Actualización de fuente/brecha | Escenario de aceptación propuesto |
|---|---|---|
| Descenso individual / O4 | S10 aclara destinos de universitario y laboral hacia universidades; falta representación persistente y completar modalidades/sentidos. | Selección de destinos permitidos por modalidad; ascenso real antes del destino previsto; reserva original intacta y sin registrar descenso físico. |
| Paradas habilitadas / O4 | S10 diferencia ascenso/descenso y asigna autoridad a Administración/dueño; esquema y granularidad siguen pendientes. | Rechazar como ascenso una opción configurada solo para descenso y viceversa, según configuración aprobada; no inferir opciones al faltar datos. |
| Offline / F1–F4 | S10 confirma registro sin conexión y presentación al chofer; falta estrategia y regla del DNI. | Pendiente durable, información clara sin afirmar validación remota; reconexión y reautenticación con la cuenta propietaria. |
| Conflictos / F6–F9 | S10 exige conservar el envío erróneo; falta consulta/resolución y semántica contractual. | Intento no validado y motivo conservados; no aparece como abordaje válido ni duplica eventos; errores transitorios permanecen diferenciados. |
| Chofer / O8, F10 | Presentación de pantalla/DNI no modifica su papel consultante de S5. | Sin acción de confirmar abordaje por chofer; ninguna cuenta ve o sincroniza pendientes ajenos. |

**Próximo paso:** compartir este análisis y las respuestas S10 con Martiniano y
Facundo; revisar las cuatro precisiones operativas y la configuración/horario;
acordar QR, sesión e históricos y el diseño restante. Para PC3 puede presentarse
el análisis con decisiones y pendientes explícitos. No declarar «diseño cerrado»
ni CU-007 implementado mientras esas decisiones estén abiertas. No se afirma aquí
que las consultas restantes ya fueron enviadas a VanFull.

**Verificación de esta actualización:** revisión de coherencia documental y de los
pasajes de entrevista indicados; conservación literal del cuerpo previo desde
«Ratificación funcional de Martín — 30/10/2026». Sin inspección nueva del código,
pruebas, cambios productivos, operaciones sobre bases ni publicación en GitHub.

## Ratificación funcional de Martín — 30/10/2026

**Procedencia:** declaración directa de Martín en esta conversación el **30/10/2026**,
en su carácter de responsable de análisis del proyecto. Martín ratifica en esta fecha
el antecedente funcional que había comunicado el 20/10.

Este registro documenta la ratificación actual. **No constituye evidencia documental
recuperada del 20/10 ni aprobación técnica de Martiniano, Facundo y Martín.** Tampoco
autoriza por sí solo cambios de código, contrato, modelo o datos.

Martín ratifica los siguientes criterios funcionales:

1. El chofer debe iniciar el viaje antes del primer abordaje.
2. El pasajero autenticado, habilitado y con reserva propia consolidada escanea el QR
   de la unidad.
3. El pasajero selecciona la parada real de ascenso, perteneciente al recorrido del
   viaje. Puede ser anterior o posterior a la parada reservada, siempre que sea
   anterior a su descenso.
4. El ascenso real se registra sin sobrescribir la parada reservada.
5. En esta etapa no se exige comprobación física mediante GPS ni geocerca.
6. El chofer consulta los abordajes; no escanea ni confirma el abordaje del pasajero.

## Efecto sobre el análisis previo

El análisis previo de esta conversación no había encontrado un registro documental
del 20/10 que reuniera todos estos criterios. Esa observación histórica se conserva:
la fuente que ahora los respalda es la declaración directa de Martín del 30/10/2026.
Ya no queda pendiente ratificar funcionalmente esos seis criterios. Su representación
técnica y las decisiones enumeradas más abajo siguen pendientes.

| Aspecto | Criterio ratificado | Soporte y brecha identificados en el análisis previo |
|---|---|---|
| Inicio | El chofer inicia antes del primer abordaje. | Existe ejecución del viaje; falta concretar las condiciones del alta y los conflictos de sincronización tardía. |
| Identidad y reserva | Pasajero autenticado, habilitado y reserva propia consolidada. | Existen autenticación, habilitación y helper de reserva propia; no existe servicio de alta de CU-007. |
| Ascenso real | Elección dentro del recorrido; puede ser anterior o posterior al reservado y debe preceder al descenso individual. | El abordaje puede guardar recorrido y orden propios; falta una fuente verificable del descenso individual y resolver paradas habilitadas. |
| Preservación de reserva | Registrar ascenso real sin sobrescribir el reservado. | Reserva y abordaje tienen datos de parada separados; el futuro servicio debe conservar esa separación. |
| Comprobación física | Sin exigencia de GPS ni geocerca en esta etapa. | No agregar ventanas, tolerancias ni validación física no definidas. |
| Chofer | Consulta; no escanea ni confirma. | Existe consulta de abordajes; conservar el registro a cargo del pasajero. |

La revisión técnica inicial tomó como base la referencia local `origin/main` en
`fb6e422` (29/10/2026). Aquel registro de ratificación no revalidaba main remoto.
La ampliación documental siguiente registra la consulta posterior de GitHub del
30/10/2026; ninguna de estas revisiones constituye implementación ni prueba ejecutada.

## Pendientes conservados

- **Descenso individual:** definir su representación y fuente autoritativa. La reserva
  actual guarda ascenso, no descenso. No sustituirlo por la última parada del recorrido
  ni reinterpretar la parada reservada como descenso.
- **Paradas habilitadas:** precisar su representación y aplicación por viaje; pertenecer
  al recorrido no prueba por sí solo habilitación de ascenso o descenso.
- **Correspondencia horaria:** definir cómo se comprueba, incluido horario nulo, sin
  inventar ventanas temporales.
- **Formato del QR:** definir contenido y resolución de la unidad; la ratificación no
  fija un formato ni acredita presencia física mediante el QR.
- **Reintentos:** definir identificación de operación, duplicados, solicitudes con
  contenido distinto y respuestas tras cambios de estado.
- **Sincronización offline:** definir almacenamiento durable, autenticación y
  reautenticación, validaciones locales, disparo de sincronización y conflictos con
  finalización, cancelación, ausencia, habilitación y cambios de asignación. Acordar
  cómo se evalúan condiciones al escanear y al sincronizar, sin suponer historia que
  el modelo actual no permite comprobar.

**Offline conserva su alcance aprobado:** RF-015, CU-007 v1.3 (A3), RNF-011 y RNF-012
exigen registro temporal pendiente, intento de sincronización dentro del objetivo
máximo de 60 segundos desde recuperar conectividad e integridad sin duplicados ante
reintentos. La estrategia técnica pendiente no elimina ni posterga ese alcance.

Se mantiene el acuerdo de interacción con CU-008: **escanear no recupera automáticamente
un lugar liberado por ausencia**. La implementación futura debe respetar el protocolo
de locks pasajero → viaje → reserva y la atomicidad, sin copiar automáticamente a
CU-007 la política de reintentos de otro caso de uso.

La coordinación técnica con Martiniano y Facundo sigue pendiente para contrato,
modelo, reservas, asignaciones y composición compartida de Flutter. Los worktrees
de CU-008 y ETA/RNF-008 y la APK ensayada quedan fuera de esta actualización.

## Verificación de GitHub en lectura — 30/10/2026

**Main observado:** `bfad0307433f2cf9434c9bea4c033a884255fdab`, commit del
30/10/2026 a las **00:59:26 de Argentina** (`2026-10-30T03:59:26Z`).
Fuente: GET de la rama main y metadatos de PR; es una observación de esta consulta,
no una garantía sobre avances posteriores. [Commit observado](https://github.com/Martiherenu1/ProyectoVanFull/commit/bfad0307433f2cf9434c9bea4c033a884255fdab).

La comparación remota desde `fb6e422fa3695e85b014e0e3dd1876327b5136ed` confirma
que el avance incorpora #251 y, mediante su rama, #253 (CU-036/Checkout). No cambia
los servicios de reservas, ausencias, ejecución, disponibilidad o chofer, ni el
schema base y modelo de viajes inspeccionados. Sí modifica OpenAPI YAML/JSON,
`backend/app/main.py`, `frontend/lib/main.dart`, `PasajeroShell`, dependencias y
otros archivos de pagos. Se leyó el contrato del SHA remoto: CU-007 conserva su
operación y schemas anteriores. Las ampliaciones optativas de pagos no equivalen
a cambios de CU-007 ni a una aprobación técnica de este caso.

No se hizo fetch, checkout, pull ni actualización de referencias locales. El objeto
del nuevo main no está disponible localmente; los archivos relevantes sin cambios
se inspeccionaron desde `origin/main` local y su continuidad se verificó mediante
la comparación de GitHub. El árbol remoto recursivo se obtuvo completo, sin truncar:
no contiene módulo de alta de abordajes ni pantalla/cola QR. La comparación y los
patches de los archivos compartidos se consultaron sin aplicarlos.

Búsquedas reproducibles en GitHub: `repo:Martiherenu1/ProyectoVanFull is:issue`
o `is:pr`, término entre comillas e `in:title,body`, sin filtro de estado,
`per_page=100`. Todas las respuestas indicaron `incomplete_results=false` y menos
de 100 resultados; no hubo páginas adicionales. También se usó el buscador del
conector como contraste; las búsquedas no garantizan encontrar trabajo sin esas
palabras ni trabajo privado/local ajeno.

| Término | Issues | PR | Resultado relevante |
|---|---:|---:|---|
| `CU-007` | 0 | 2 | #40 y #76: contrato de ejecución y cancelación; no alta QR. |
| `abordaje` | 9 | 12 | Ausencias, locks, consulta, GPS y documentación; ninguna entrega específica de CU-007. |
| `QR` | 2 | 6 | Listado/detalle, ejecución e informes; no lector ni sincronizador CU-007. |

El buscador del conector tampoco encontró Issues por `CU007` o `RNF-011`.
No se creó un Issue ni se publicó comentario alguno.

| Referencia relevante | Estado efectivo verificado | Uso y límite |
|---|---|---|
| [#147](https://github.com/Martiherenu1/ProyectoVanFull/pull/147), Issue [#146](https://github.com/Martiherenu1/ProyectoVanFull/issues/146) | PR closed, merged=true, 24/10/2026 18:17:00Z; merge `0ee54a0d1e911c0dcd60ae4ffb3f05bbffc73b14`. Issue cerrado. | Backend de ausencia integrado. El cuerpo dice todavía «sin merge» y tiene casillas inconsistentes: son registros históricos, no estado actual ni evidencia de Flutter implementado. |
| [#133](https://github.com/Martiherenu1/ProyectoVanFull/pull/133), Issue [#131](https://github.com/Martiherenu1/ProyectoVanFull/issues/131) | PR merged, 24/10/2026 16:10:01Z; merge `29bb8b62bc1fe9f01ef97100bccc06c86b88420e`. Issue cerrado. | Helper y orden de locks integrados; no implementa abordajes. |
| [#61](https://github.com/Martiherenu1/ProyectoVanFull/pull/61) / [#8](https://github.com/Martiherenu1/ProyectoVanFull/issues/8) | PR merged, 18/10/2026 21:58:55Z; Issue abierto. | Aclaración funcional de destinos/paradas. El texto inicial del Issue propone última parada, pero la aclaración posterior la descarta como sustituto del destino individual. |
| [#60](https://github.com/Martiherenu1/ProyectoVanFull/pull/60) / [#28](https://github.com/Martiherenu1/ProyectoVanFull/issues/28) | PR merged, 18/10/2026 21:58:37Z; Issue abierto. | Aclaración de cupo/ausencia; no tratar el texto inicial «ausencias no liberan» como comportamiento actual. |
| [#65](https://github.com/Martiherenu1/ProyectoVanFull/pull/65), [#67](https://github.com/Martiherenu1/ProyectoVanFull/pull/67), [#76](https://github.com/Martiherenu1/ProyectoVanFull/pull/76) | Las tres merged; fechas UTC 19/10 02:51:57, 20/10 01:16:03 y 20/10 23:20:52 de 2026, respectivamente. | Consulta del chofer, ejecución y cancelación integradas. Sus reintentos no deciden los de CU-007. |
| [#251](https://github.com/Martiherenu1/ProyectoVanFull/pull/251) | PR merged, 30/10/2026 03:59:26Z; merge igual al main observado. | Avance de base y archivos compartidos; no entrega QR. |

## Fuentes y alcance de la evidencia

Las etiquetas S1–S9 de este documento son referencias locales de lectura, no nuevos
identificadores de requisitos. Fuentes funcionales leídas durante esta conversación;
existencia y SHA-256 de los cinco archivos externos rechecados el 30/10/2026:

| Fuente | Ubicación y aporte |
|---|---|
| S1 | `F:/TIN/One Drive/OneDrive/Escritorio/UM/TC/03 Actores y Casos de Uso/03_Especificaciones_Casos_de_Uso_VanFull_v1.3_Aprobado_Equipo.md`, CU-007 completo, líneas 383–448: principal, A1/A2/A3, postcondiciones y pendiente técnico offline. SHA-256 `fce1f29f7ca621497cad0fd950429044e6adbfa80aee0fb98f9c5d2e6ea53df8`. |
| S2 | `F:/TIN/One Drive/OneDrive/Escritorio/UM/TC/04 Modelo y UML/Diagramas de Actividad/DA-CU007 – Registrar abordaje mediante QR.png`, inspección visual previa: identificación, compatibilidad, habilitación, duplicado, pendiente y sincronización válida/no válida. SHA-256 `b2cee364b28e670db3a7a039fd60f3471338ec78723298624e6d0621266937e9`. |
| S3 | En `F:/TIN/One Drive/OneDrive/Escritorio/UM/TC/Desarrollo Front y BAck/`: `02_Requisitos_Funcionales_VanFull_v1.1_Aprobado_Equipo.docx`, RF-014/015/016 (hash `11edb6bf3aaf9c74732d8c2d3cdcd831ca76589dc4551feb8fe297a95bae5f5a`); `02_Reglas_de_Negocio_VanFull_v1.1_Aprobado_Equipo.docx`, RN-023/024/025 (hash `c30167a205e2a1c21e2bbff23736cdf99adc2df0a5c79ce35c8826f7d552aa11`). Lectura de contenido OOXML, sin edición. |
| S4 | `F:/TIN/One Drive/OneDrive/Escritorio/UM/TC/02 Alcance, RF, RNF y Reglas/02_Requisitos_No_Funcionales_VanFull_v1.0_Aprobado_Equipo.docx`: RNF-011 intento ≤60 s; RNF-012 integridad sin duplicados. Hash `8f386f3789afdf02f9d886894fb4b02c83ef7695c8b6b5669f29dcf1137f8004`. |
| S5 | Ratificación directa de Martín del 30/10/2026, conservada íntegra al inicio. No es evidencia recuperada del 20/10 ni aprobación técnica triple. |
| S6 | `Documentos/Sesiones/PC2/ACLARACION-FUNCIONAL-CU002-ISSUE8-v0.2-VALIDADA-ANALISIS.md` (AC08-01 a 08); aclaración de #28; contextos de pasajero y chofer; acuerdo CU-008 documentado en #146/#147. Distinguen descenso individual, habilitaciones por viaje y ausencia voluntaria. |
| S7 | `backend/CONVENCIONES.md` §§3/6/8; `CONTRIBUTING.md` §§1.8/1.9; `REPARTO-PC2.md`. Transacción, eventos, locks y coordinación. La fila «ausencia: por escribir» de convenciones quedó histórica frente al servicio integrado. |
| S8 | Código/contrato del main identificado: `backend/db/schema.sql`, `app/models/viajes.py`, servicios `reservas.py`, `ausencias.py`, `disponibilidad.py`, `ejecucion_viajes.py`, `viajes.py`, `chofer.py`, seguridad, contrato, Flutter y archivos de pruebas. Lectura estática y comparación GitHub; ninguna prueba ejecutada. |
| S9 | Referencia `FC-01 — Aclaraciones posteriores de la entrevista VanFull(1).docx`, aportada por Facundo e informada por Martín el 30/10/2026. El archivo exacto con `(1)` no se encontró en la búsqueda local bajo `F:/TIN/One Drive/OneDrive/Escritorio/UM`. Sí se localizaron y cotejaron las versiones sin ese sufijo en `TC/01 Relevamiento y AS-IS/`: `.docx`, SHA-256 `0568cfe7eb0ab1df64b43d6e534680ea546331fabe56c472f66de47850a73d76`, y `.md`, SHA-256 `b6ec2e63edbd3a96669d682af3f1c2ecdbbacd541edade08e24ba79e8eec12b8`. Sus pasajes pertinentes coinciden; no se certifica identidad con el archivo citado por Facundo. |

No falta la especificación v1.3 ni se reemplazó por una versión anterior. Sigue sin
recuperarse un documento histórico específico del 20/10 con los seis criterios;
su ratificación actual ya está disponible en S5. Faltan acuerdos técnicos de
Martiniano y Facundo y definiciones operativas indicadas al final. No se consultó
Drive, Render, Neon, Maps ni estado de despliegue. No se certifica CI ni ejecución
de las pruebas descritas en cuerpos históricos de PR.

## Separación de estados y brechas del contrato

- **Ratificado/aprobado funcionalmente:** los seis criterios de S5; RF-014/015,
  RN-023 y A3 offline con RNF-011/012. El chofer no confirma y no se agrega GPS.
- **Implementado, según inspección:** autenticación; reserva propia y estados;
  tabla/modelo de abordaje; consulta del chofer; inicio/finalización; aviso de
  ausencia y liberación derivada de cupo. No hay alta QR, lector ni cola offline.
- **Pendiente de acuerdo técnico:** representación/fuente autoritativa del descenso,
  habilitaciones por viaje, contrato, formato QR, identificación de operación,
  almacenamiento/autenticación/sincronización, errores y conflictos. Los cambios
  a la operación existente requieren acuerdo de los tres según el reparto.
- **Requiere precisión de VanFull, canalizada por Martín:** significado operativo
  de horario aplicable y excepciones; quién fija/confirma el descenso y las paradas
  habilitadas si las aclaraciones previas no alcanzan; tratamiento de un escaneo
  offline genuino que llega después de un cambio incompatible. Elegir columnas,
  transporte o motor de almacenamiento corresponde al equipo técnico.

`POST /api/abordajes` está declarado pero no registrado en la aplicación. Hereda
bearer del contrato, pero no precisa rol pasajero ni respuestas de privacidad.
`AbordajeCreate` exige solo `id_viaje` e `id_vehiculo`; parada, marca offline y
timestamp local son opcionales. Declara 201 y 409; faltan precisiones de errores y
reintentos. La descripción de 201 mezcla registrado con encolado: sin conexión el
servidor no puede responder, y la cola local debe distinguirse de la confirmación.

La tabla `abordaje` guarda pasajero/viaje/vehículo/recorrido/orden y UNIQUE de
pasajero+viaje, con FK compuestas de viaje–vehículo y recorrido–orden. No exige
reserva, habilitación o ausencia mediante restricciones. No guarda estado de sync,
hora local/servidor ni identificador de operación; los estados `registrado`,
`pendiente_sync`, `validado` solo están declarados en la respuesta OpenAPI.
Pueden requerir persistencia o una semántica derivada explícita: no se elige aquí.

La reserva guarda ascenso, no descenso. El filtro `id_parada_destino` de
disponibilidad no conserva una elección por reserva; pertenencia al recorrido y
`comprometida` tampoco acreditan habilitación por viaje. Abono/contratación no
aportan una FK suficiente al descenso individual. El dato no puede deducirse de
la última parada ni del texto comercial libre. Falta asimismo historial suficiente
para comprobar todas las condiciones al instante de un escaneo offline pasado.

## Matriz de trazabilidad y pruebas propuestas

Todas las pruebas de esta matriz son propuestas, no resultados ejecutados.

| Regla | Fuente | Soporte actual | Brecha | Decisión pendiente | Prueba propuesta |
|---|---|---|---|---|---|
| Identidad de sesión y rol pasajero | S1/S5/S7 | JWT, `usuario_actual`, `requiere_rol` | Sin alta CU-007 ni rol explícito en operación | Precisar permisos/errores | Sin token, vencido, rol incorrecto, identidad inyectada en cuerpo |
| Reserva propia consolidada | S5; estados S8 | Helper por pasajero/viaje con sesión del llamador y sin commit | No decide consolidación ni equivale a permiso completo | Precedencia y privacidad | Ajena/inexistente/provisional/cancelada/consolidada; misma respuesta sin filtración |
| Habilitación | S1 A1, RN-023, S5 | Estado habilitado/suspendido/baja | JWT no acredita estado vigente; falta validación CU-007 | Momento y conflictos offline | Token válido con suspensión/baja y estado precargado obsoleto |
| Inicio previo | S5; CU-030/ADJ-03 | Transiciones y lock viaje | Falta alta CU-007 | Precisar alta nueva y reintento tras cierre | Programado/en_curso/finalizado/cancelado; no iniciar desde escaneo |
| Unidad del QR corresponde al viaje | S1/S2/S5; FK S8 | FK viaje–vehículo | Sin formato/resolución QR; ID declarado no prueba escaneo | Formato y vínculo verificable | Unidad ajena, QR ilegible/desconocido, reasignación |
| Conservar la unidad original registrada | S8; revisión estática de FK y reasignación | Abordaje guarda unidad, ligada por FK compuesta a la asignación actual del viaje | No hay historial de asignaciones; reasignar en curso no está permitido por el servicio actual | Definir si hace falta un circuito excepcional y su representación, sin reescribir historia | Reasignación con/sin abordajes, cambio a otra unidad o null; rollback y unidad original intacta |
| Correspondencia servicio/horario | S1 A2; RN-023 | Reserva→viaje→servicio, fecha y horario nullable | Sin criterio temporal operacional | Definir sin inventar ventana | Misma unidad en viajes distintos, horario nulo y cambio de día |
| Ascenso real del recorrido | S5; S8 | FK recorrido–orden | API lo deja opcional; sin selector | Entrada obligatoria/semántica | Parada igual, anterior y posterior a reservada; orden ajeno/inexistente |
| Ascenso precede descenso individual | S5/S6 | Orden de recorrido | No existe descenso individual verificable | Fuente y representación | Antes/igual/después del descenso, destino intermedio, IDA/VUELTA |
| No sobrescribir ascenso reservado | S5 | Reserva y abordaje separados | Sin alta | Conservar ambos y su presentación | Registrar parada distinta y comprobar reserva idéntica |
| Paradas habilitadas por viaje | S6 AC08-06/07 | Paradas del recorrido | Sin habilitación por viaje/sentido | Representación y autoridad | Parada del recorrido que no admite ascenso/descenso en ese viaje |
| Ausencia no recupera lugar | S6 CU-008, RN-025 | Cupo excluye reserva con aviso; CU-008 rechaza abordado | UNIQUE no impide ausencia+abordaje | Respuesta ante escaneo y conflicto offline | Ausencia, cupo tomado por otro y escaneo: sin recuperar ni desplazar |
| Máximo un abordaje válido | S2; MR-R24; RNF-012 | UNIQUE pasajero+viaje | No reconoce la operación ni su payload | Reintento frente a nuevo escaneo | Dos dispositivos y payloads iguales/distintos: una fila, sin sobrescritura |
| Atomicidad y serialización | S7 | Patrón de locks/evento/commit; helper | Servicio CU-007 inexistente | Evento y resultado transaccional | Carreras y fallo después de flush: ni abordaje ni evento parcial |
| Chofer consulta; sin GPS físico | S1/S3/S5 | Consulta del chofer | Sin captura pasajero | Composición/permisos de cámara | Sin permisos GPS puede abordar; chofer no puede registrar |
| Registro temporal offline | S1 A3/S2/S3 | Campos declarados | Sin cola durable ni datos locales suficientes | Persistencia, cache y autenticación | Reinicio sin red, reingreso misma/otra cuenta, pendiente preservado |
| Intento ≤60 s al reconectar | S1/S4 | Ningún sincronizador | Sin disparador, planificación ni medición | Plataformas y ejecución de fondo | Red recuperada, app activa/cerrada: medir primer intento, no prometer éxito |
| Integridad ante reintentos offline | S2/S4 | UNIQUE como última defensa | Sin identificación/deduplicación de eventos | Clave, retención y política de conflictos | Respuesta perdida, reenvío/reinicio y sincronización tardía sin duplicados |

## Escenarios online para preparar las pruebas

Los rótulos O/F siguientes son locales al análisis, no identificadores nuevos de
la línea base. Cada escenario necesita datos sintéticos aislados en una futura
implementación; aquí no se crean datos ni se ejecutan pruebas.

| Escenario | Preparación y acción | Resultado exigido o pendiente |
|---|---|---|
| O1 Identidad | Sin token, token inválido/vencido, rol chofer/admin y cuerpo con pasajero distinto | Rechazar acceso/suplantación; identidad desde sesión. Documentar códigos y precedencia antes de implementar. |
| O2 Reserva/habilitación | Pasajero autenticado con las combinaciones de reserva y habilitación | Solo habilitado con propia consolidada puede producir alta válida; no filtrar recursos ajenos. |
| O3 Viaje/unidad | Variar estado y vehículo; misma unidad asociada a distintos viajes | Inicio previo y correspondencia del viaje; no inferir que hay un único viaje en curso ni elegir por unidad solamente. |
| O4 Ascenso/descenso | Ascenso igual/anterior/posterior al reservado, siempre dentro del recorrido; descenso intermedio | Admitir los tres si preceden al descenso y cumplen condiciones restantes. Igual/posterior al descenso no cumple. Bloqueado por fuente del descenso y habilitaciones. Reserva sin cambios. |
| O5 Horario | Horario nulo, fecha distinta o salida demorada | Resultado pendiente de definición; `en_curso` no sustituye silenciosamente toda RN-023. Sin ventana inventada. |
| O6 Ausencia previa | Aviso existente con reserva aún consolidada; otro pasajero ya tomó el cupo | Escaneo no recupera cupo, no borra ausencia ni desplaza a otro. Precisar respuesta; no usar consolidada sola como prueba de lugar ocupado. |
| O7 Duplicado/respuesta perdida | Registrar; perder respuesta después del commit; repetir, incluso desde otro dispositivo | Una fila y un evento. Respuesta, reconocimiento de operación y tratamiento de payload distinto pendientes; no reemplazar parada real anterior. |
| O8 Sesión | Abrir lector/selector con A, salir e ingresar B; completar callback/respuesta/401 de A | No enviar una acción de A con token de B ni mostrar su resultado en B; efecto ya confirmado en servidor no se deshace por desmontar. |
| O9 Concurrencia | Sesiones de BD distintas y barreras explícitas: alta/alta, alta/ausencia, alta/inicio, alta/finalización, alta/cancelación | Serializar y releer bajo locks; invariantes y límites detallados abajo. Sin resultado ganador elegido por tiempos de sleep. |
| O10 Rollback | Provocar fallo tras flush del abordaje o evento y antes de commit | Otra conexión no observa alta/evento parcial; reintento posterior no queda falsamente consumido. Incluir deduplicación persistente si se acuerda. |
| O11 Unidad histórica | Intentar reasignación en curso/finalizado; en un fixture excepcional programado con abordaje, cambiar unidad o quitarla; comparar con programado sin abordajes | Servicio actual rechaza estados no programados. La FK impide dejar un abordaje con par viaje/unidad inexistente. No actualizar abordajes para hacer pasar el cambio; verificar atomicidad y conservación. Son pruebas futuras, no ejecutadas. |

Protocolo a conservar: pasajero → viaje → reserva, usando el helper con la misma
sesión y lecturas frescas (incluido estado de habilitación precargado). Un lock no
refresca por sí solo una instancia ORM antigua. Inicio/finalización y cancelación
administrativa toman solo viaje, sin adquirir después pasajero/reserva.

- Si inicio se confirma primero, el alta evalúa viaje iniciado; si alta observa
  programado primero, no puede registrar válidamente ni iniciar el viaje por su cuenta.
- Si finalización gana, un alta online nueva no debe tratarse como un abordaje
  ocurrido antes del cierre; su rechazo concreto y el reintento reconocido se
  precisarán. Si alta gana, finalizar no elimina el abordaje confirmado.
- Si abordaje gana frente a ausencia nueva, CU-008 ya rechaza por abordaje. Si
  ausencia gana, CU-007 no recupera lugar; no basta una restricción UNIQUE separada.
- Cancelar reserva hoy exige programado y toma pasajero → viaje → reserva. Hay
  que cubrir también cancelación → inicio → alta y evitar lecturas antiguas.
- Cancelación administrativa actual solo admite programado, excluye especial y
  corporativo y rechaza compromisos vigentes; no inventar cancelación en curso.
  Comparte lock de viaje y no debe adquirir locks inversos. Cambiar parada reservada
  también se limita a programado y debe respetarse al releer para CU-007.
- La ausencia ya libera cupo derivado; registrar abordaje no crea reserva ni
  consume otra vez el lugar consolidado. No persistir contadores nuevos.

## Escenarios offline y decisiones necesarias

**Exigido:** pendiente temporal, intento de sync ≤60 s desde recuperar conexión,
integridad sin duplicados y resultado de validación comunicado (S1/S2/S4).
El diagrama conserva resultado no válido cuando la sincronización no valida.
No corresponde presentar «pendiente» como abordaje aceptado ni descartar en silencio
el alcance offline por falta de diseño.

| Escenario | Preparación y acción | Invariante y definición pendiente |
|---|---|---|
| F1 Escaneo sin red | Cuenta identificada con datos locales disponibles; escanear y seleccionar ascenso | Crear pendiente recuperable, sin afirmar validación del servidor. Definir datos mínimos/locales y qué ocurre si no estaban precargados. |
| F2 Persistencia | Cerrar/reabrir app o reiniciar dispositivo con pendientes | Preservar identidad y contenido del intento; almacenamiento, protección y retención pendientes. Distinguir proceso activo de cierre forzado. |
| F3 Reconexión | Recuperar conexión con pendientes y autenticación utilizable | Medir primer intento dentro del objetivo de 60 s; no confundir conectividad del dispositivo con API accesible ni intento con éxito. |
| F4 Autenticación | JWT vence sin red; reconectar; usuario reingresa con misma cuenta u otra | No usar credenciales de otra cuenta ni guardar contraseñas en cola. Definir pausa/reautenticación y cómo conciliar el objetivo de 60 s con credenciales vencidas. |
| F5 Commit sin respuesta | Servidor confirma, respuesta se pierde; app reinicia y reenvía | Misma operación no duplica fila/evento ni se cambia a otro payload. Requiere semántica de identificación/confirmación aún no acordada. |
| F6 Finalización tardía | Escaneo supuestamente en curso, sync después de finalizar/cancelar | No hay decisión aprobada de aceptar retroactivamente. Elegir estado al escaneo o recepción exige política y evidencia; reloj local no prueba el momento. |
| F7 Cambio de condiciones | Entre escaneo y sync: ausencia, cancelación de reserva, suspensión/baja, reasignación o cambio operativo | Nunca recuperar lugar liberado por ausencia. Resolver otros conflictos explícitamente; no validar con una cache como si fuera estado autoritativo. |
| F8 Conflicto de dispositivos | Dos colas para pasajero/viaje; paradas iguales o distintas | Máximo un abordaje válido y sin sobrescritura silenciosa; decidir cómo informar equivalencia/conflicto. |
| F9 Fallos transitorios/definitivos | Red intermitente, 5xx, 401, 409 o respuesta inesperada | Resultado incierto no equivale a rechazo. Definir reintento, pausa, resolución definitiva y feedback sin bucles infinitos de conflictos. |
| F10 Cambio de sesión | Pendiente A; login B; respuesta tardía A; regreso posterior a A | Aislamiento de almacenamiento, envío y presentación. Decidir conservación al logout y reanudación; B no hereda la operación ni su 401. |

Hoy Flutter conserva sesión solo en memoria; JWT es sin estado y logout no lo
revoca. La habilitación del pasajero debe distinguirse del estado de cuenta y de
los roles contenidos en un token emitido. No hay refresh ni cola QR implementados.
`registrado_offline` y `timestamp_local` no autentican el evento, no son por sí solos
su identificación y no reconstruyen el estado histórico de reserva/viaje/unidad.

## Alternativas técnicas para discusión, sin selección aprobada

Cada fila es una propuesta de diseño. No fija campos, rutas, formatos, ventanas o
políticas. Ventajas y límites se contrastan con el contrato/modelo actuales.

| Tema y alternativas | Ventajas | Limitaciones | Impacto potencial en contrato/modelo |
|---|---|---|---|
| Descenso estructurado por reserva, capturado/confirmado antes de abordar | Permite comprobar orden y conservar elección por viaje | Requiere definir quién lo autoriza y completar reservas existentes | Nuevo dato/FK y validaciones; schema, ORM, migración, creación/lectura de reserva y Flutter coordinados con Martiniano |
| Descenso derivado de contratación/abono, con resolución por viaje | Reutiliza destino habitual de IDA | Hoy no hay FK suficiente; VUELTA y ocasionales necesitan elección individual; texto libre no garantiza integridad | Nuevas relaciones y resolución explícita; no es derivación disponible hoy ni evita necesariamente cambiar reserva |
| Pedir descenso al abordar y persistir elección validada | Permite capturar un dato faltante en el flujo | Exige aprobación funcional: no asumir que el pasajero puede redefinir su destino al subir | Entrada adicional, validación contra destinos autorizados y persistencia; no adoptar como parche silencioso |
| Habilitaciones por recorrido, por viaje o por recorrido con excepciones por viaje | Recorrido reutiliza configuración; viaje expresa particularidades; combinación reutiliza base con excepciones | Recorrido solo necesita resolver AC08-07, que admite variaciones entre viajes; viaje repite configuración; combinación requiere precedencia/versionado. Las tres siguen sin seleccionar | Modelo y lectura de opciones; coordinación con Facundo y Martiniano. No equiparar pertenencia al recorrido con habilitación |
| QR permanente por vehículo (propuesta de Facundo), con identificador, referencia opaca o contenido firmado/versionado por definir | Reutiliza el QR de la unidad entre viajes; firma podría verificar integridad local | Reimpresión no revoca copias. Opacidad o firma por sí solas tampoco garantizan revocación; faltan resolución/cache, vigencia y política. No demuestra presencia ni viaje vigente | Documentar payload y errores; revocación/reemplazo exigirían diseño y soporte adicional. El modelo actual no los implementa. No se elige formato |
| Identidad natural pasajero+viaje frente a identificador estable generado por cliente para el intento | Natural aprovecha UNIQUE; identificador permite reconocer respuesta perdida y payload original | Natural no distingue intentos distintos; identificador exige alcance, retención y manejo de colisiones/reuso | Posible campo/header y almacenamiento de operación/resultado; conservar UNIQUE de negocio, sin fijar nombre ni algoritmo |
| Deduplicación en abordaje frente a registro separado de operaciones | Primera concentra éxito; segundo puede conservar resultado y conflictos | La tabla actual no contiene metadatos; registro separado requiere atomicidad y retención; proteger privacidad | Cambios de columnas o tabla/migración y respuestas. No usar `evento_operativo` como almacén arbitrario de idempotencia |
| Cola durable por cuenta con motor local adaptado a Android/Web | Sobrevive reinicio y permite reenviar la misma operación | Elección de motor, cifrado, limpieza/logout, backup y soporte por plataforma pendientes; no persistir tokens como identidad de operación | Dependencias y capa local; contrato de sincronización/resultado. Pendientes locales no son filas válidas de abordaje |
| Sync con condiciones actuales frente a validación del momento de escaneo acreditado o resolución explícita del conflicto | Actual simplifica autoridad; histórico refleja evento físico; resolución evita decidir sin evidencia | Actual puede rechazar un abordaje genuino tardío; histórico necesita evidencia/historial que hoy falta; resolución requiere proceso y responsable aprobado, sin convertir al chofer en confirmador | Estados/tiempos/evidencias/resultados o proceso nuevo según acuerdo. Ausencia nunca se revoca automáticamente |
| Reusar POST para sync frente a operación separada de sincronización | Un POST comparte servicio; separación puede representar lotes/resultados individuales | Reuso debe definir reintento y campos; separación no debe duplicar reglas ni inventar una ruta ahora | Precisión o ampliación OpenAPI, servicio único y atomicidad por operación explícita |
| Primera entrega solo online | Acota lector/validación y facilita revisión inicial | **Parcial:** no satisface RF-015/RNF-011/012 ni completa CU-007 | Debe declarar cobertura parcial y conservar trabajo offline concreto; no habilita eliminarlo del contrato o alcance |

Correspondencia horaria: usar viaje/reserva como contexto evita elegir por reloj
del cliente, pero no resuelve por sí solo qué significa «horario aplicable». Si
VanFull requiere controles temporales adicionales deben definirse antes de proponer
su representación. Aquí no se seleccionan ventanas ni excepciones automáticas.

## Propuestas de Facundo informadas por Martín — 30/10/2026

**Procedencia:** Martín comunicó estas propuestas de Facundo en esta conversación.
Se incorporan como aportes técnicos para discusión, no como declaraciones directas
verificadas de Facundo, aprobación de los tres ni autorización para implementar.
No incorporan la conformidad de otro mensaje que Martín retiró por haber sido
enviado por error; la ratificación funcional inicial y los históricos se conservan.

- **Habilitaciones:** mantener abiertas las tres alternativas: por recorrido, por
  viaje y por recorrido con excepciones. La fila de alternativas compara impactos;
  ninguna está seleccionada. Debe resolverse la variación por viaje de AC08-07.
- **QR permanente por vehículo:** propuesta técnica compatible con identificar la
  unidad, pero no fija payload ni un mecanismo de seguridad o revocación aprobado.
  **Reimprimir** reproduce el mismo código y deja utilizables sus copias según la
  misma semántica. **Revocar/reemplazar** supone invalidar una referencia anterior
  o cambiar su vínculo/vigencia: el modelo actual no tiene un registro de QR,
  versión, vigencia o revocación. No se promete que pegar otro QR invalide el previo;
  tampoco se cambia el ID del vehículo para simular una revocación.
- **Pendiente, confirmado y no validado:** distinciones conceptuales propuestas
  para explicar, respectivamente, registro temporal sin confirmación autoritativa,
  validación aceptada por el servidor y validación que no pudo aceptarse. No son
  nombres de estados de base aprobados ni un mapeo decidido a los valores de
  OpenAPI. Una respuesta perdida es resultado incierto, no prueba de «no validado».
- **Momento de validación offline:** validar al escanear o al sincronizar sigue
  pendiente de acuerdo entre Martín, Martiniano y Facundo. Debe distinguirse una
  comprobación local provisional de la confirmación autoritativa y definirse qué
  evidencia permitiría evaluar condiciones pasadas. En cualquier alternativa,
  escanear no recupera automáticamente un lugar liberado por ausencia.

### Cotejo literal de RNF-011 y FC-01

Se releyó el contenido OOXML de S4 antes de actualizar este análisis. RNF-011 dice:

> Cuando se recupere la conectividad, el sistema deberá intentar sincronizar los registros de abordaje pendientes en un plazo máximo objetivo de 60 segundos.

Se conserva **intentar dentro del objetivo máximo de 60 segundos**, no garantizar
éxito en ese plazo. Ni las distinciones conceptuales ni FC-01 sustituyen ese literal
o eliminan RNF-012. Autenticación vencida, ejecución en segundo plano y API inaccesible
siguen necesitando diseño y medición; no se declaran excepciones aprobadas al RNF.

S9 se presenta a sí misma como aclaración oral del dueño, recordada posteriormente
por el entrevistador y clasificada «CONFIRMADO POR VANFULL». Se verificó esa
declaración en los archivos locales, no de manera independiente con el dueño.
DOCX leído sin editar y MD cotejado en los pasajes pertinentes:

- **FC-01.17:** el pasajero escanea el QR de la puerta, identifica el vehículo y
  confirma abordaje; no reserva ni consulta cupo. No define permanencia, formato,
  reimpresión, revocación o reemplazo. «Confirma» se lee junto con RN-023 y A3,
  sin equiparar cualquier escaneo offline con un abordaje válido.
- **FC-01.19:** sin conexión queda pendiente hasta sincronizar al recuperar
  conectividad. No fija 60 segundos ni resuelve cuándo evaluar las condiciones.
- **FC-01.12 y FC-01.15:** describen transbordo y cambios de parada que pueden
  implicar otra unidad, horario o recorrido. No autorizan por sí solos reasignar
  un viaje con abordajes bajo las reglas técnicas actuales.
- **FC-01.34:** ausencia voluntaria y liberación temporal para otro pasajero;
  no define recuperación automática por escaneo.

Queda pendiente localizar el archivo exacto `(1)` aportado por Facundo o confirmar
su equivalencia con estas copias. No se lo presenta como fuente exacta verificada
ni como modificación aprobada de CU/RN/modelo. La búsqueda no incluyó Drive.

### Unidad original, FK y reasignación actual

Relectura estática en GitHub del main `bfad0307433f2cf9434c9bea4c033a884255fdab`,
reconfirmado el 30/10/2026: `backend/db/schema.sql`,
`backend/app/models/viajes.py`, `backend/app/services/viajes.py` y
`backend/app/schemas/viajes.py`. No se ejecutó SQL ni prueba alguna.

1. `abordaje.id_vehiculo` es obligatorio. La FK compuesta
   `(id_viaje, id_vehiculo)` referencia `viaje(id_viaje, id_vehiculo)`, cuyo par
   es UNIQUE. No hay `ON UPDATE CASCADE` ni mecanismo de historia de asignaciones.
   Por tanto, conservar el abordaje con unidad A y cambiar ese viaje a B o null
   dejaría sin referencia al par original y sería rechazado por la FK, según
   inspección del esquema. No se acredita aquí su ejecución ni un error HTTP concreto.
2. Las otras FK ligan abordaje a viaje/recorrido y a recorrido/orden de parada.
   Conservan correspondencia con esos datos actuales; no prueban por sí solas la
   asignación que existía en un instante histórico de escaneo.
3. `actualizar_viaje` toma lock del viaje y **solo admite estado programado**.
   `ViajeUpdate` permite cambiar/quitar vehículo y valida referencias/capacidad,
   pero no contiene un circuito excepcional de reasignación con abordajes ni
   un chequeo específico de ellos. Que exista el campo no habilita reasignar en
   curso/finalizado. Con el inicio previo ratificado, una alta válida nueva no
   debería dejar abordajes en un viaje todavía programado.
4. Una combinación excepcional de programado con abordajes cargados por otro
   mecanismo tampoco autoriza ignorar la FK: habría que conservar la unidad y
   resolver el caso expresamente. No se propone actualizar registros históricos,
   agregar cascadas, borrar abordajes ni alterar estados para facilitar la reasignación.
5. Si un pendiente fue escaneado con A y llega cuando el viaje tiene B, no se
   sustituye A por B automáticamente ni se afirma que es el vehículo original.
   Es un conflicto de F7, pendiente de política y de soporte histórico. Admitir
   excepcionalmente reasignación conservando unidad original exigiría revisar
   contrato/modelo/reglas, con acuerdo explícito; no está implementado ni aprobado.

O11 amplía los escenarios propuestos para esta conservación y los rechazos actuales.
FC-01 describe operatoria real de transbordo, pero no resuelve esa brecha del modelo.

## Coordinación, preservación y límites de esta revisión

Martín conserva el servicio de abordajes y la conducción del análisis. Martiniano:
reserva/descenso, identidad/sesión, helper y contrato. Facundo: viaje/asignaciones,
configuración operativa y base Flutter. Acuerdos sobre la operación existente y
cambios de modelo deben quedar explícitos; merge previo de otra PR no los concede.

Archivos compartidos previsibles: `backend/openapi/openapi.yaml` y JSON derivado,
`backend/app/main.py`; si se aprueba ampliar datos, schema/ORM/migración nueva;
`frontend/lib/main.dart`, `screens/pasajero/pasajero_shell.dart`,
`mis_reservas_screen.dart`, cliente/sesión si fuera necesario, dependencias y
permisos de cámara. El main nuevo ya modifica bootstrap, shell y dependencias por
Checkout: revalidar esa composición al comenzar, sin transportar una versión vieja.

CU-008 tiene una propuesta local de conexión sobre Mis reservas/shell/bootstrap;
coordinar puntos de entrada e invalidación por sesión/ruta sin copiar ni pisar su
trabajo. ETA/RNF-008 mantiene su trabajo independiente. Worktrees observados:
CU-008 backend `612f42f`, interfaz `fb6e422`, ETA `fb6e422`, APK CU-030 `14b83dd`
y ensayo GPS `8217c9c`. No se modificaron ni se resolvieron sus cambios/conflictos.
El registro del ensayo GPS conserva hash de APK
`a59d6d308658a8dfe8e645acb8575c0d2e0786cf86abe450f8ca2981512c705f`;
es evidencia histórica, no hash recalculado ni prueba física nueva.

`tests/test_ausencias.py`, `test_ejecucion_viajes.py`, `test_cancelar_reserva.py`,
`test_cancelar_viaje.py`, pruebas de chofer y de sesión ofrecen antecedentes
inspeccionables; no acreditan alta/sync CU-007. `test_rutas_contrato.py` exige que
lo implementado esté declarado, no que todo OpenAPI esté implementado.
No se ejecutó ninguna prueba, validador de contrato, migración ni servicio en esta
tarea; tampoco compilación, instalación, commit, push, PR o mensaje a terceros.
Único archivo editado: este análisis documental.

## Preparación concreta para implementación — revisión del 30/10/2026

Esta sección recomienda un diseño para decidir. **No aprueba ni implementa** sus
campos, tablas, rutas, dependencias, estados o políticas. Conserva las alternativas,
fuentes, ratificación de Martín y registros históricos anteriores; las frases sobre
CU-008 pendiente de conexión describen la situación de aquellas revisiones.

### Main y entregas recientes contrastados en lectura

Main observado ahora: **`58d272bab5954bdfa47048cb47b58101f94a69cd`**, commit del
30/10/2026 **16:25:13 Argentina** (`19:25:13Z`), merge de #261.
[Referencia verificable](https://github.com/Martiherenu1/ProyectoVanFull/commit/58d272bab5954bdfa47048cb47b58101f94a69cd).
Se consultaron rama, comparación desde `bfad030`, PR y archivos fijados a este SHA,
sin fetch, checkout ni actualización del árbol local.

- **#257 efectivamente mergeada** el 30/10 a las `14:47:05Z`, merge `f55ecf271aba9645582fcf1910b6a7da0084c6f7`:
  CU-008 ya tiene adaptador HTTP y acción desde Mis reservas, con token capturado,
  guardas por generación/sesión y alcance de pestaña/ruta; conserva State, Checkout
  y recargas. El texto de PR todavía dice «sin merge»: prevalecen los metadatos.
  Reutilizar ese patrón, no reconstruir la composición desde la base anterior.
- **#260 mergeada** (`67b5fa4`, `15:01:55Z`): cierre documental CU-029/CU-030;
  no implementa CU-007. **#261 mergeada**: actualiza guion y evidencia declarada
  de CU-008; no modifica backend ni resuelve descenso/QR/offline. Sus observaciones
  de Neon y Web son evidencia atribuida al documento, no consultas ni ensayos nuestros.
- La comparación remota no introduce cambios de backend desde `bfad030`; conserva
  Checkout Pro y sus flags, y modifica composición Flutter mediante #257. No añade
  descenso por reserva, habilitaciones por viaje, alta de abordajes ni cola QR.
- Búsquedas GitHub `repo:Martiherenu1/ProyectoVanFull`, sin filtro de estado:
  `is:issue "CU-007"` → #259 (cierre documental); `is:pr "CU-007"` → #260/#76/#40;
  `is:issue descenso` → #8; `is:pr descenso` → #200/#195/#193/#190/#61. Ninguna
  resuelve las brechas de datos. Resultados completos, `incomplete_results=false`,
  menos de 100 por consulta. Las PR #263 (turnos de demo) y #264 (presentación de
  viajes) estaban **abiertas, no mergeadas**: no se incorporan como main efectivo.

Se releyó CU-007 completo de S1 y se contrastó con AC08-01 a 08 de S6 y el literal
de RNF-011 ya cotejado. Ninguna entrega encontrada elimina los pendientes técnicos.
FC-01 exacto con `(1)` continúa sin verificarse; no se sustituye su identidad por
las copias locales. No se ejecutaron pruebas ni se certifica CI de esta revisión.

**Congelamiento:** el reparto conserva freeze desde el 25/10 salvo acuerdo; el
guion de #261 fija para el 30/10 último merge de backend/frontend a las 17:15,
ensayo 17:15–17:30 y silencio desde las 18:00. No se encontró excepción para CU-007
ni levantamiento general del freeze. Mantener esta preparación fuera de la versión
de demo aunque cambie la hora; no usar el guion como autorización para despliegues,
reinicios, ensayos o merge. Una futura implementación requerirá alcance acordado
y trabajo aislado sobre main revalidado, preservando las APK y los worktrees.

### Recomendación 1 — Descenso explícito de cada reserva

**Regla aprobada:** el ascenso real debe preceder al descenso individual, puede
diferir del reservado y no lo sobrescribe (S5). AC08-01/04 distinguen IDA del abono
y descenso elegido en cada VUELTA; no autorizan deducirlo de la última parada.

**Diseño recomendado, pendiente:** agregar a `reserva` un
`orden_parada_descenso` explícito, con FK compuesta
`(id_recorrido, orden_parada_descenso)` a `parada_recorrido`. Conservar
`orden_parada` como ascenso reservado. El orden se interpreta en el recorrido
efectivamente asociado al viaje: **no invertirlo por `sentido`**. Si hoy el orden
de un recorrido de VUELTA no representa su secuencia real, corregir/definir esa
configuración antes de habilitar la comparación; no resolverlo con aritmética.

Para ocasionales, transportar la selección estructurada de destino desde búsqueda
a creación de reserva y validarla en servidor. Para abonos de IDA, resolverla desde
un destino contractual estructurado y copiar la elección al viaje/reserva; esa
fuente aún no existe y requiere diseño adicional. Para VUELTA, conservar la
elección de ese viaje, sin derivarla de la IDA. Pedirla por primera vez al escanear
no es el camino recomendado: permitiría cambiar condiciones sin autorización.

Migración propuesta por etapas: columna inicialmente nullable para preservar
reservas antiguas, sin completar con última parada ni otros valores inventados;
exigir dato validado en nuevas reservas del alcance habilitado. Las antiguas sin
descenso deberán completarse mediante un procedimiento autorizado **antes de poder
validar CU-007**. Exponer explícitamente su falta en consulta; no fingir compatibilidad.
Solo hacer NOT NULL cuando todas las modalidades y datos existentes tengan fuente
resuelta. No agregar ahora un CHECK sobre ascenso reservado/descenso que no haya
sido acordado; la validación CU-007 compara ascenso real y descenso conocido.

**Contrato y archivos previstos:** extender `ReservaCreate`/`Reserva` y sus DTO
Flutter; lecturas propias, detalle y consulta administrativa; validación de
crear/cambiar parada y herramientas de reserva del asistente para no perder el
destino seleccionado. Revisar `backend/app/{schemas,services,routers}/reservas.py`,
`app/models/viajes.py`, `db/schema.sql`, migración nueva, `openapi.yaml/json`,
`frontend/lib/models/pasajero/reserva.dart`, `disponibilidad_viaje.dart`,
`core/api/pasajero_api.dart`, búsqueda/confirmación/Mis reservas y llamadas de AG-01.
Reutilizar `id_parada_destino` de disponibilidad, sin confundir filtrado con persistencia.

**Alternativas:** relación aparte para destino de reserva evita columna nullable
pero añade joins y gestión de integridad; derivación exclusiva de abono no cubre
ocasionales/VUELTA ni preserva elección histórica. **Decisión:** Martiniano propone
contrato/migración con Martín y Facundo; VanFull, por Martín, debe precisar fuente
contractual de IDA y autoridad/procedimiento para completar destinos faltantes.

### Recomendación 2 — Opciones de ascenso explícitas por viaje

**Base aprobada:** pertenencia al recorrido y ascenso real anterior al descenso;
AC08-06/07 permite habilitaciones diferentes por viaje. «Comprometida» no es
«habilitada». No se infiere presencia física, GPS, parada alcanzada ni ventana horaria.

**Diseño recomendado, pendiente:** una configuración efectiva por viaje, candidata
`parada_viaje`, con viaje, recorrido, orden y permisos separados de ascenso/descenso.
FK a viaje/recorrido y recorrido/orden; una fila por viaje/orden. Puede inicializarse
desde una plantilla de recorrido, pero la configuración efectiva debe ser explícita
y verificable; **no tomar toda parada como habilitada cuando faltan datos**.
No se crean estos registros ni se actualiza seed en esta tarea.

Proponer una lectura de opciones de abordaje para una reserva propia que devuelva
recorrido, descenso conocido y ascensos habilitados cuyo orden sea menor al descenso.
Puede presentar primero el ascenso reservado, pero mostrar también los anteriores
y posteriores que cumplan condiciones. Guardar elección real solo en `abordaje`.
El servidor repite las comprobaciones al escribir; una lista cacheada no autoriza
el alta. Cache local por cuenta/reserva/viaje con versión de configuración para
captura provisional offline; si no existe, no inventar opciones.

**Contrato/modelo/archivos:** tabla/migración nuevas y lectura candidata
`GET /reservas/{id_reserva}/opciones-abordaje` (nombre para discusión); servicio
dueño de reservas/configuración reutilizado por CU-007, no consultas duplicadas
de reglas ajenas. Afectaría schema/ORM, `services/reservas.py` y configuración de
viajes, schemas/routers, OpenAPI y DTO/selector Flutter. Configurar ordinariamente
antes de iniciar según AC08-08; contingencias RN-021 requieren definición propia,
sin habilitar edición arbitraria en curso desde esta propuesta.

**Alternativas:** permisos por recorrido/sentido son más simples pero insuficientes
sin resolver excepciones de AC08-07; plantilla con excepciones reduce repetición,
con mayor complejidad de precedencia. Recomiendo materializar la configuración
efectiva por viaje para evitar esa ambigüedad. **Decisión técnica de los tres**;
VanFull define quién autoriza opciones/excepciones si S6 no alcanza. Esta recomendación
no convierte en elegida la alternativa histórica aportada por Facundo.

### Recomendación 3 — QR de unidad con credencial versionada

**Aprobado:** identifica vehículo y lo escanea el pasajero; no reserva ni prueba
ubicación física. **Recomendación técnica pendiente:** QR reutilizable por vehículo,
con payload mínimo candidato `{version, id_vehiculo, credencial_opaca}`. Sin viaje,
pasajero, parada ni token de sesión en el código. El pasajero elige una reserva
propia; el backend deriva su viaje y contrasta la unidad. No suponer que la unidad
solo tiene un viaje posible ni navegar a URLs arbitrarias recibidas del lector.

La credencial aleatoria distingue una impresión autorizada de un ID simplemente
declarado; sigue siendo copiable y no demuestra abordaje físico. Recomiendo registro
candidato de credenciales por vehículo con hash, versión y vigencia/revocación;
el servicio resuelve y valida el valor recibido, sin persistirlo en logs/eventos.
Conservar referencia a la credencial utilizada para trazabilidad del resultado si
se acuerda. La forma exacta del payload y administración de credenciales debe aprobarse.

Reimprimir el mismo QR no altera nada. Revocar/reemplazar crearía nueva credencial
e invalidaría explícitamente la anterior, sin cambiar `id_vehiculo` ni abordajes.
Es **capacidad nueva propuesta**, no disponible hoy. Offline conserva el payload
como dato no confiable hasta sincronizar; una revocación posterior es conflicto
según la política acordada, no una razón para reescribir intentos confirmados.

**Alternativas:** solo ID de vehículo evita registro/rotación, pero no permite
revocar una copia individual; contenido firmado facilita verificar integridad offline
y exige gestión de claves y revocación igualmente. **Archivos/contrato/modelo:**
registro/migración de credenciales, servicio CU-007, schemas de entrada/errores,
OpenAPI, parser/lector Flutter; no reutilizar autenticación del pasajero como QR.
Equipo decide formato/ciclo de credenciales; VanFull define quién puede emitir,
reimprimir o revocar y qué comunicar ante reemplazo. No se promete administración
de QR en una pantalla que todavía no existe.

### Recomendación 4 — Una operación durable compartida por online y offline

**Exigido por S1/S4:** pendiente temporal, intento de sincronización dentro del
objetivo de 60 segundos de recuperar conectividad y ausencia de duplicados.
**Diseño recomendado, no aprobado:** crear un identificador UUIDv4 por intento
confirmado por el pasajero y persistir antes de enviar. Conservarlo al reiniciar,
perder respuesta o reintentar; nunca regenerarlo solo por timeout. Un nuevo intento
con contenido corregido necesita identificación nueva y acción explícita.

Entrada candidata del mismo `POST /abordajes`: `id_operacion`, `id_reserva`, payload
QR, `orden_parada` real, `timestamp_local` orientativo y marca offline existente.
Viaje/pasajero/recorrido se derivan de la reserva y sesión; la eliminación o
compatibilidad de `id_viaje`/`id_vehiculo` actuales requiere acuerdo contractual.
`timestamp_local` se conserva como declaración del cliente, sin certificar historia.

Proponer registro persistente de operación vinculado a cuenta/pasajero, clave única
por cuenta e identificador, huella de payload y resultado canónico. Ese registro
no es un abordaje válido ni un nuevo uso de `evento_operativo`. El servicio usaría
una transacción para operación, abordaje y evento; conservar UNIQUE pasajero/viaje
como invariante de negocio. Resultado previo autorizado se consulta/repite antes
de exigir condiciones de alta nuevas; la pertenencia y autenticación siguen siendo
obligatorias. Resultado ya confirmado no se pierde porque viaje terminó o QR fue
revocado después. Esto es una propuesta de reintentos para CU-007, no una copia
automática de CU-008 ni una semántica aprobada por el diagrama.

Semántica candidata para acordar:

| Situación | Resultado recomendado |
|---|---|
| Primera alta válida | 201, abordaje canónico; evento solo una vez. |
| Misma operación y mismo payload | 200 con resultado canónico previo; no revalidar como alta ni crear evento nuevo. |
| Misma operación con payload diferente | Conflicto 409, sin sobrescribir intención ni abordaje. |
| Nueva operación y abordaje previo con misma unidad/ascenso | Informar ya registrado, devolver el existente sin nuevo evento; registrar vínculo idempotente del nuevo intento si se acuerda. |
| Nueva operación que contradice unidad/ascenso ya registrado | Conflicto 409; no modificar historia. |
| Rechazo definitivo de negocio sin abordaje previo | Conservar resultado no validado con motivo; reenvío idéntico devuelve ese resultado. Corregir datos requiere nueva acción. |
| Sin autorización, red, 5xx o rollback | No afirmar alta ni rechazo definitivo; no consumir una clave con éxito falso. Resolver identidad antes de revelar operación; reintentar la misma intención cuando corresponda. |

Recomiendo **validación autoritativa de altas nuevas al sincronizar/recibir** y
comprobaciones locales solo provisionales. Una llegada después de cierre, ausencia,
reserva cancelada, suspensión, QR revocado o cambio de unidad no se acepta como
abordaje histórico basándose en reloj local. Se conserva resultado/conflicto visible,
sin recuperar el cupo por ausencia. **VanFull y el equipo deben aprobar este efecto
operativo**, porque puede rechazar un escaneo genuino tardío. Alternativa: validar
al escanear con evidencia autorizada e historia suficiente, que el modelo actual no
ofrece; o proceso excepcional de resolución definido por VanFull, nunca confirmación
manual del chofer. Sin acuerdo, este punto sigue bloqueando CU-007 completo.

Cola local candidata: almacenamiento transaccional durable por cuenta, adaptador
Android sobre SQLite y Web sobre IndexedDB, bajo una misma interfaz. Es una
recomendación de arquitectura, sin librería/version elegida ni dependencia instalada.
Guardar intención, identidad propietaria, contenido estable, resultado y control
de reintentos; no contraseña ni JWT en la fila de operación. Proteger datos en
reposo con el mecanismo que el equipo apruebe; no prometer cifrado por usar esos motores.

Planificador propuesto: disparo inmediato al recuperar conectividad, al volver a
foreground y al reingresar con la misma cuenta; temporizador mientras está activo,
un envío por operación y exclusión de sincronizadores concurrentes. Reintentos
transitorios con espera creciente y máximo propuesto de 30 s mientras la app puede
ejecutar; no es una ventana de negocio ni modifica RNF-011. Medir tiempo hasta
**primer intento**, no hasta éxito. Tras respuesta perdida reenviar misma operación;
tras 401 pausar hasta reautenticación de su propietario; conflictos de negocio no
entran en bucle automático. Una lectura candidata de resultado propio por
`id_operacion` permitiría reconciliar sin POST como consulta, pero el reenvío
idempotente debe funcionar incluso si esa lectura no llegó a hacerse.

Android requiere resolver ejecución en background y Web no garantiza ejecución
con pestaña cerrada; tampoco se puede enviar con sesión vencida sin política de
credenciales. Estas limitaciones **no son excepciones aprobadas a RNF-011**:
acordar plataformas/ciclo de vida y estrategia antes de declarar cumplimiento.
La cola al reabrir resuelve durabilidad, no por sí sola el objetivo de 60 segundos.

**Archivos/modelo/contrato:** registro de operaciones + migración, schemas/router/
servicio `abordajes`, helper de eventos, OpenAPI (201/200, conflictos, privacidad y
consulta propia candidata); DTO, repositorio local, sincronizador y adaptador HTTP
Flutter nuevos. Reutilizar servicio único tanto online como offline y `ApiClient.post`
con token explícito; no duplicar reglas en el dispositivo. Equipo decide identidad,
retención/resultados y transporte; VanFull define resolución operativa de conflictos.

### Recomendación 5 — Unidad histórica y aislamiento de sesión

Reutilizar el protocolo pasajero → viaje → reserva y refrescar instancias bajo
locks. El helper de reservas no hace commit ni decide consolidación. Habilitación,
ausencia, unidad, descenso y opciones se revalidan en el servicio del dueño o por
su interfaz acordada. Si se implementa revocación, acordar un lock de lectura de
credencial después de esos locks; la operación administrativa de revocar no deberá
adquirirlos en orden inverso. No cambiar el protocolo silenciosamente por tablas nuevas.

**Reasignación recomendada para el alcance inicial:** conservar la regla actual de
editar solo programado; no implementar transbordos/reasignaciones en curso como
parte implícita de CU-007. Si unidad del QR difiere de la actual al registrar,
rechazar alta nueva y conservar ambas referencias en el resultado del conflicto
según privacidad, sin cambiar unidad declarada por la asignada. La FK compuesta
actual impide una asignación distinta dejando un abordaje con el par anterior.
No agregar cascadas ni reescribir abordajes para acomodarla. Un circuito futuro
de múltiples asignaciones históricas necesitaría modelo y alcance propios.

**Sesión recomendada:** cada pendiente pertenece a cuenta/pasajero estables; generación
de UI no es identidad durable. Antes de enviar verificar propietario contra sesión
actual y capturar su token; cambio de cuenta bloquea esa cola y descarta callbacks
visuales viejos. Al regresar A con token nuevo se puede sincronizar A; B nunca
hereda su intención ni sus resultados. Mantener guardas de #257 para pestaña/ruta,
respuesta tardía y 401 asociado al token; cerrar pantalla no revierte un commit.
Logout pausa envíos y oculta pendientes de A, sin borrarlos automáticamente ni
exponerlos a B; retención/borrado y datos en dispositivos compartidos requieren acuerdo.

**Archivos y decisiones:** `services/viajes.py`/FK actuales se preservan; cualquier
interfaz para obtener asignación debe acordarse con Facundo. Integración futura
en `main.dart`, `PasajeroShell`, Mis reservas y sesión/HTTP de Martiniano, conservando
Checkout y ausencia. Reutilizar mecanismos existentes, sin copiar código de un
worktree viejo. Equipo acuerda aislamiento/retención y si hace falta información
adicional de consulta; VanFull define si requiere transbordo dentro de CU-007.

### Implementación propuesta y aceptación, sin ejecución en esta tarea

Los nombres de tablas, campos, rutas y códigos anteriores son candidatos revisables.
Antes de programar, resolver descenso/habilitaciones, horario aplicable y aceptación
de conflictos tardíos; documentar aprobación de cambios existentes y alcance fuera
de demo. Ninguna preferencia técnica anterior inventa ventanas GPS/horarias.

| Entrega separable | Trabajo propuesto y coordinación | Aceptación propuesta |
|---|---|---|
| Base de datos/contrato | Martiniano + Martín + Facundo: descenso, opciones efectivas, QR y operaciones; una migración nueva por cambio acordado, sin reescribir inicial | Migración limpia y desde datos previos; faltantes conservados sin defaults inventados; FK de descenso/configuración; contrato YAML/JSON equivalente; reserva y clientes antiguos tratados explícitamente. |
| Backend CU-007 | Martín: servicio transaccional, router fino, schemas; reutilizar autenticación, helper, eventos y locks; lecturas de reservas/configuración coordinadas | Propia consolidada/habilitado, viaje iniciado, QR correcto, ascenso permitido anterior al descenso; reserva intacta; ausencia no recupera; mismos intentos y respuesta perdida sin duplicación; payload distinto en conflicto; carreras y rollback reales con O1–O11/F5–F9. |
| Interfaz de escaneo | Lector/parser y selector por opciones del servidor/cache; permisos de cámara separados de GPS; integración acordada en Mis reservas con #257 y Checkout | Cámara denegada/QR inválido/cancelación sin envío; opciones antes y después de reservada; sin elegir última parada; estados conceptuales diferenciados e incertidumbre; A→B y callbacks antiguos sin envío ajeno. Puede revisarse con transporte simulado antes de habilitar red. |
| Consulta del chofer | Reutilizar CU-029 y su indicador; proponer exposición del ascenso real y, si se acuerda, descenso en detalle, sin convertir consulta en alta | Un éxito se ve tras recarga; reservado y real claramente separados; pendientes/no validados no cuentan como abordajes; sin datos privados adicionales ni botón de confirmar; estado vacío y errores. Revisar contrato/DTO y `services/chofer.py`, `schemas/chofer.py`, modelo/pantalla de detalle y pruebas. |
| Sincronización offline | Repositorio durable y sincronizador con mismo servicio backend; acordar background, almacenamiento y autenticación por plataforma | F1–F10: reinicio, reconexión, primer intento ≤60 s en condiciones de ejecución acordadas sin prometer éxito; duplicados entre dispositivos, 401, cambio de cuenta, QR revocado, unidad cambiada y viaje cerrado; no pérdida del pendiente ni recuperación automática por ausencia. |
| Integración final fuera de PC2 demo | Componer las cuatro capas y ensayar sobre entorno/dataset aislados autorizados, con APK nueva identificada; conservar APK y ensayos previos | Checks pertinentes y aceptación online/offline por plataforma; consulta del chofer coherente; ningún flujo rompe ausencia, pago/Checkout, navegación, inicio/finalización o privacidad. No declarar completo CU-007 si solo está online. |

Secuencia recomendada: decisiones y contrato/datos → backend idempotente → lector
y consulta del chofer con dobles → persistencia/sync completa → composición y ensayo
aislado. Diseñar operación y persistencia desde la primera entrega, aunque la UI
offline se desarrolle después. Toda entrega solo online permanece **parcial** y no
elimina RF-015/RNF-011/012. No se autoriza con este análisis abrir PR, hacer merge,
publicar, tocar la demo o ejecutar las pruebas propuestas.

## Preguntas priorizadas para destrabar

1. **Descenso y paradas:** ¿qué fuente autoritativa conservará el descenso individual
   y quién confirma las habilitaciones por viaje? Martiniano/Facundo proponen la
   representación; Martín consulta a VanFull si falta precisión operativa.
2. **Horario y conflictos:** ¿qué significa horario aplicable y qué tratamiento
   tendrá un pendiente offline que llega después de cierre/suspensión/cancelación?
   Resolver el criterio funcional con Martín/VanFull y luego el acuerdo técnico
   de los tres, manteniendo la prohibición de recuperar cupo por ausencia.
3. **Operación y duplicados:** ¿cómo se reconoce un mismo intento, qué cambia si el
   payload difiere y qué se devuelve tras respuesta perdida o cambios posteriores?
4. **QR y offline:** ¿qué payload/resolución se acuerda y qué datos, almacenamiento,
   reautenticación y ejecución Android/Web sostendrán A3 y el intento dentro del
   objetivo de 60 s? QR permanente sigue siendo propuesta; separar reimpresión de
   cualquier política futura de revocación/reemplazo.
5. **Unidad histórica:** ¿se necesita un circuito excepcional de transbordo o
   reasignación con abordajes? Si se necesita, ¿cómo conservar unidad original sin
   reescribir historia y con qué soporte de modelo? Hoy no está permitido en curso.
6. **Fuente aportada:** localizar FC-01 con sufijo `(1)` o confirmar su equivalencia
   con las copias locales cotejadas, antes de atribuirle verificación exacta.

## Secuencia propuesta de trabajo, pendiente de autorización para implementar

1. Recibir las definiciones y separar acuerdos funcionales de técnicos; documentar
   decisiones, errores y conflictos. No reabrir los seis puntos ratificados.
2. Reconsultar main/equivalentes y acordar Issue/alcance; preparar trabajo aislado
   sin reutilizar los worktrees protegidos ni regenerar las APK ensayadas.
3. Proponer primero contrato y datos necesarios para descenso, habilitaciones y
   operación/sync; coordinar cambios compartidos y pruebas de migración si aplican.
4. Implementar servicio transaccional único y endpoint(s) acordados, con pruebas
   propuestas O1–O10 y F5–F9 en PostgreSQL aislado; sin cambiar reglas ajenas.
5. Implementar captura/selector y almacenamiento/sincronización offline, con
   aislamiento por cuenta, reautenticación y escenarios F1–F10. Si se separa una
   entrega online inicial, marcarla parcial y mantener el seguimiento offline.
6. Integrar navegación con Martiniano/Facundo y CU-008; ejecutar checks pertinentes
   solo cuando exista autorización de implementación. Planificar después ensayo
   físico nuevo con fuente/hash propios, sin atribuirle resultados de APK anteriores.
