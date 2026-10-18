# VanFull — Aclaración funcional del filtro destino y de las paradas por modalidad

**Versión:** 0.2 — VALIDADA POR ANÁLISIS (MARTÍN)  
**Fecha del relevamiento:** 18/10/2026  
**Estado:** **APROBADO FUNCIONALMENTE POR MARTÍN** el 18/10/2026. Las aclaraciones confirmadas por VanFull no constituyen por sí mismas decisiones técnicas ni modificaciones aprobadas de la línea base.  
**Origen:** [Issue #8 — CU-002: filtro destino de `/servicios/disponibilidad` sin columna en el modelo](https://github.com/Martiherenu1/ProyectoVanFull/issues/8).  
**Responsable:** Martín — Integrante 2 (análisis, requisitos y trazabilidad).  
**Revisión técnica posterior:** Martiniano (pasajeros, CU-002/CU-003 y contrato API), Martín (recorrido en curso y abordaje), Facundo (planificación/administración de viajes).  
**Ubicación prevista:** `Documentos/Sesiones/PC2/ACLARACION-FUNCIONAL-CU002-ISSUE8-v0.2-VALIDADA-ANALISIS.md`.

> **Naturaleza del documento.** Las aclaraciones `AC08-*` surgen de respuestas explícitas de Martín en representación de VanFull en el relevamiento del 18/10/2026 y se clasifican **CONFIRMADO POR VANFULL**. Su redacción está **aprobada funcionalmente por Martín el 18/10/2026**. Los identificadores `AC08-*`, `PT08-*` y `PV08-*` son locales, no nuevos RF, RN o CU. Esta aprobación funcional **no autoriza por sí sola** nuevas estructuras, endpoints, optimización de rutas ni cambios silenciosos a los artefactos aprobados.

## 1. Problema, objetivo, alcance y límites

El contrato actual `GET /servicios/disponibilidad` acepta `destino` como cadena de texto, pero ni `SERVICIO`, ni `RECORRIDO`, ni `PARADA` poseen un atributo con ese nombre. La implementación devuelve `400 FILTRO_NO_DISPONIBLE` cuando se informa el parámetro. El Issue #8 solicita decidir qué significa *destino* y cómo resolverlo sin confundir el destino de **cada pasajero** con la última parada del vehículo.

**Objetivo funcional inmediato (Issue #8 / CU-002):** definir qué destinos puede buscar o seleccionar el pasajero según modalidad, qué viajes deben resultar elegibles y cómo respetar el sentido y las paradas de descenso habilitadas.

**Contexto operativo que debe documentarse sin ampliar automáticamente el alcance:** puntos de ascenso de abonados y ocasionales; flexibilidad de recorridos antes de la salida; comportamiento de reservas tardías; solicitudes de servicios especiales.

**Dentro de este documento:** aclaraciones funcionales, contraste con la línea base, observaciones sobre modelo/contrato existentes, casos para revisión y pruebas, trazabilidad, responsables, alcance PC2 y preguntas pendientes.

**Fuera del alcance de esta aprobación funcional:** decidir el nuevo contrato de API; crear columnas/tablas/estados; alterar DER/MR o RN/CU aprobados; implementar algoritmo de propuesta u optimización de recorridos; confirmar un nuevo módulo de solicitud de traslados especiales en PC2; realizar cambios en código o GitHub.

## 2. Fuentes contrastadas y jerarquía

| Fuente | Autoridad / clasificación | Aporte verificado y limitación |
|---|---|---|
| Respuestas directas de Martín como representante de VanFull, 18/10/2026 | **CONFIRMADO POR VANFULL** | Destinos según modalidad; parada final del pasajero; vuelta; ascenso de abonados y ocasionales; especiales; variaciones por viaje; propuesta, confirmación y excepción de ascenso. Fuente principal de `AC08-*`. |
| `01_Entrevista_VanFull_2026-08-25.docx` | Entrevista directa anterior | Se relevan servicio universitario/laboral, zona Bella Vista–CABA, destinos como UADE/UCA, origen/destino y punto de ascenso como datos, y adaptación del recorrido al domicilio. La entrevista no detallaba todas las opciones de UI aquí confirmadas. |
| `02_Reglas_de_Negocio_VanFull_v1.1_Aprobado_Equipo(1).docx` | **DEFINIDO POR EL EQUIPO** | RN-001 (cupo según servicio/recorrido/parada), RN-020 (cambio de parada sujeto a disponibilidad), RN-021 (cambio operativo por contingencias y respeto de paradas comprometidas), RN-023 (abordaje) y RN-031 (máximo una ida y una vuelta por día). **No se modifican.** |
| [Issue #8](https://github.com/Martiherenu1/ProyectoVanFull/issues/8) | Pendiente de GitHub | Problema preciso: parámetro `destino` sin atributo directo; decisión de filtro es de diseño; el Issue permanece abierto al momento del cotejo. Contiene un extracto de la especificación CU-002 v1.3. |
| [`backend/openapi/openapi.yaml`](https://github.com/Martiherenu1/ProyectoVanFull/blob/main/backend/openapi/openapi.yaml) | Contrato técnico vigente | `GET /servicios/disponibilidad`: parámetros `fecha`, `sentido`, `destino` (`string`, opcional), `id_recorrido`. `GET /recorridos/{id_recorrido}/paradas` lista paradas; `ReservaCreate` requiere `orden_parada` de ascenso. |
| [`backend/app/services/disponibilidad.py`](https://github.com/Martiherenu1/ProyectoVanFull/blob/main/backend/app/services/disponibilidad.py) | Implementación técnica vigente | Rechaza cualquier `destino` no nulo con `400 FILTRO_NO_DISPONIBLE`; no está resuelto el filtrado por parada de descenso. |
| [`backend/db/schema.sql`](https://github.com/Martiherenu1/ProyectoVanFull/blob/main/backend/db/schema.sql) | Estructura física vigente | `PARADA`, `PARADA_RECORRIDO` con orden y `comprometida`; `VIAJE` enlaza recorrido, `RESERVA` guarda **parada de ascenso**, pero no parada de descenso; `ABONO_MENSUAL` no identifica una parada final específica. |
| [`Documentos/Sesiones/PC2/REPARTO-PC2.md`](https://github.com/Martiherenu1/ProyectoVanFull/blob/main/Documentos/Sesiones/PC2/REPARTO-PC2.md) | **DEFINIDO POR EL EQUIPO** | CU-002, reservas y frontend pasajero: Martiniano; operación y abordajes: Martín; viajes y asignaciones: Facundo. Optimización de recorridos y varios procesos asociados están **fuera del PC2**. |
| [Issue #28 y aclaración funcional aprobada](https://github.com/Martiherenu1/ProyectoVanFull/pull/60) | Relevamiento funcional previo / PR documental | Nueva reserva con viaje en curso si existe cupo y parada de ascenso pendiente; coordinación necesaria con `AC08-12`. La PR de análisis no equivale a implementación. |

**Control de fuentes:** la jerarquía del proyecto es profesores > VanFull > equipo > IA. No se ha cotejado en forma íntegra la **última especificación CU-002 v1.3** ni los textos completos aprobados de CU-003, CU-005, CU-018, CU-019 y CU-030; antes de modificar línea base deberán leerse directamente. El extracto disponible de CU-002 indica que los criterios exactos de búsqueda/filtros se definirán en diseño sin convertirse automáticamente en RN.

## 3. Definiciones y vocabulario

- **Destino del pasajero:** punto o parada en que ese pasajero termina su traslado; puede ser intermedio respecto de la última parada del vehículo.
- **Última parada del recorrido:** punto final de la secuencia del vehículo; **no** representa necesariamente el destino de todos los pasajeros.
- **Parada habilitada para descenso:** parada utilizable como destino por un pasajero en un viaje/sentido concretos.
- **Punto habitual de ascenso del abonado:** punto cercano a su domicilio aceptado y confirmado para sus IDAS habituales, hasta que pida cambiarlo.
- **Pasajero ocasional/eventual de recorrido habitual:** pasajero sin abono que reserva un lugar en el servicio de charter existente; **no confundir automáticamente** con un cliente que solicita un traslado especial, aunque en la entrevista inicial aparezcan denominaciones cercanas.
- **Servicio especial:** solicitud de traslado con origen/destino y fecha/horario definidos por el cliente, sujeta a evaluación y presupuesto de VanFull; no es por definición una reserva inmediata de viaje ofrecido.

## 4. Matriz de aclaraciones funcionales

Todos los siguientes enunciados se clasifican **CONFIRMADO POR VANFULL — 18/10/2026** y la redacción de este documento `v0.2` cuenta con **aprobación funcional de Martín**. La implementación técnica aún requiere revisión y acuerdos del equipo.

### 4.1. Destinos, abonados y pasajeros eventuales

| ID | Aclaración confirmada |
|---|---|
| **AC08-01** | En los abonos, VanFull ofrece destinos/paradas predefinidos (por ejemplo, Obelisco, UCA, UADE). El **destino de IDA queda establecido al contratar el abono** y no debe preguntarse nuevamente en cada reserva de IDA. |
| **AC08-02** | El pasajero **ocasional/eventual en un recorrido habitual** elige el destino entre las paradas o destinos predefinidos habilitados; no ingresa arbitrariamente una dirección distinta para ese charter. |
| **AC08-03** | Un mismo recorrido puede llevar pasajeros a **distintos destinos de descenso**; una parada intermedia puede ser destino de un pasajero aunque la unidad continúe. Por tanto, el filtro no equivale a la última parada del recorrido. |
| **AC08-04** | En los viajes de **VUELTA** el pasajero puede escoger su parada de descenso entre las habilitadas para el recorrido. En un abono IDA/VUELTA, el destino de IDA permanece fijo y el descenso de cada VUELTA **se selecciona en cada viaje**. |
| **AC08-05** | Para buscar un viaje habitual como pasajero ocasional, primero se **selecciona el destino** y luego el sistema debe mostrar los viajes disponibles que pasan por una parada de descenso habilitada con ese destino. |

### 4.2. Paradas habilitadas y adaptación del recorrido

| ID | Aclaración confirmada |
|---|---|
| **AC08-06** | Existen paradas para **ascenso** y otras para **descenso**, según recorrido y sentido IDA/VUELTA. No toda parada que integra el recorrido es necesariamente un destino válido. |
| **AC08-07** | Las habilitaciones de ascenso y descenso **pueden variar de un viaje a otro**, aunque dos viajes utilicen el mismo recorrido de referencia. No se deben tratar automáticamente como propiedades invariables de `PARADA` o `PARADA_RECORRIDO`. |
| **AC08-08** | En la operación ordinaria se definen las paradas habilitadas **antes de iniciar el viaje** y no se agregan/modifican para nuevas incorporaciones una vez que el viaje está en curso. Esto **no deroga RN-021**, que permite ajustes operativos por tránsito, accidentes, cortes o fuerza mayor respetando las paradas comprometidas. |
| **AC08-09** | En IDA, VanFull opera como servicio **aproximadamente puerta a puerta** para abonados: procura puntos de ascenso cercanos al domicilio, sin garantizar recoger exactamente frente a cada vivienda. La incorporación o baja de pasajeros **antes de iniciar el viaje** puede requerir ajustar el recorrido, respetando las paradas comprometidas. |
| **AC08-10** | Los pasajeros ocasionales/eventuales de recorridos habituales se **adaptan a las paradas de ascenso ya establecidas**; no se modifica especialmente el recorrido para recogerlos. |
| **AC08-11** | Para un nuevo abonado, **el sistema propone uno o varios puntos de ascenso cercanos al domicilio**; el pasajero escoge uno. Solo deben ofrecerse opciones cuya viabilidad ya haya sido verificada. El punto elegido **queda confirmado automáticamente**, sin aprobación manual posterior. |
| **AC08-12** | Si no hay ningún punto de ascenso viable cerca del domicilio, el sistema lo informa y **deriva la solicitud a VanFull para evaluación manual**; no confirma un punto no verificado. |
| **AC08-13** | El punto de ascenso seleccionado por el abonado queda como **habitual para las IDAS** y no requiere nueva elección en cada reserva, salvo que el pasajero solicite cambiarlo. El cambio está sujeto a las condiciones pertinentes de RN-020. |
| **AC08-14** | Si una IDA ya está `en_curso`, se puede incorporar un nuevo pasajero **solo en una parada pendiente ya prevista**, si existe cupo y se cumplen las demás condiciones comerciales. **No se agrega un desvío o una nueva parada para esa reserva**. Relacionado con Issue #28. |

### 4.3. Solicitudes de traslados especiales

| ID | Aclaración confirmada |
|---|---|
| **AC08-15** | En servicios especiales el cliente puede elegir un destino frecuente (por ejemplo, Aeroparque o Ezeiza) o ingresar una **dirección/localidad de destino**. También puede indicar libremente **origen** (dirección/localidad); el traslado no tiene por qué salir de Bella Vista. |
| **AC08-16** | El cliente indica **origen, destino, fecha y horario** como solicitud de traslado especial. VanFull evalúa posteriormente disponibilidad y presupuesto y responde al cliente. **No es una reserva inmediata** sobre un viaje publicado con cupos y precio ya confirmados. |

### 4.4. Síntesis por modalidad (sin confundir etapas)

| Modalidad / momento | Destino | Ascenso | Resultado inmediato |
|---|---|---|---|
| Contratación de abono (IDA) | Selección de destino predefinido; queda fijo para las IDAS del abono | Punto propuesto cerca del domicilio, verificado y elegido; habitual | Definiciones comerciales/operativas del abono; no presupone pago ni habilitación automática de la reserva |
| Consulta/reserva de IDA de un abonado | Usa el destino ya contratado | Usa el punto habitual aceptado, salvo solicitud de cambio | Reserva sujeta a las reglas de CU-003 y cupo |
| Consulta/reserva de IDA ocasional | Elige primero un destino habilitado del recorrido | Elige entre puntos ya establecidos | Se listan viajes compatibles; reserva según CU-003 |
| VUELTA, incluido abonado | Elige parada de descenso habilitada **en cada viaje** | Ascenso en punto habilitado para la vuelta | Reserva según capacidad y demás reglas |
| Solicitud de servicio especial | Destino frecuente o dirección/localidad libre | Origen libre | Solicitud para evaluación/presupuesto posterior; no confirmación inmediata |

**No se infiere** del relevamiento si la contratación de abonos, la generación dinámica de propuestas o los especiales forman parte de la entrega PC2: esa definición sigue al reparto aprobado y al control de alcance.

## 5. Contraste con reglas, modelo y contrato vigentes

| Fuente / aspecto | Situación vigente | Relación con aclaraciones | Estado / tratamiento |
|---|---|---|---|
| **CU-002 / RF-004; Issue #8** | El criterio exacto del filtro `destino` no está fijado; el Issue admite una decisión de diseño. | `AC08-01` a `AC08-07` y `AC08-05` permiten diseñar un filtro por **destino de pasajero/parada habilitada**, no por última parada ni zona arbitraria. | **PENDIENTE DE DISEÑO Y APROBACIÓN TÉCNICA**. No crear RN nueva por el filtro en sí. |
| **OpenAPI** | `destino: string` opcional; no existe `id_parada_destino` definido en el contrato. | Una etiqueta como “UADE”/“CABA” no equivale necesariamente a una clave única de parada habilitada. | Evaluar semántica e identificación; modificación del contrato **pendiente**, sin inventar parámetro. |
| **Servicio de disponibilidad** | Un `destino` no nulo produce `400 FILTRO_NO_DISPONIBLE`. | No cumple el comportamiento deseado de `AC08-05`. | Código **pendiente** de diseño/implementación; no es un requisito nuevo que se dé por satisfecho. |
| **`PARADA` / `PARADA_RECORRIDO`** | Parada con nombre/dirección/coordenadas y relación con recorrido/orden; `comprometida` se registra por parada del recorrido. | Sirve como base de paradas y orden, pero **no** identifica por sí sola habilitación de ascenso/descenso **por viaje** (`AC08-06/07`). | Revisar DER/MR antes de proponer dato nuevo. `comprometida` no equivale a “habilitada para descenso”. |
| **`VIAJE`** | Incluye `id_recorrido`, sentido, fecha, horario y estado; no posee un destino libre ni una configuración explícita de habilitaciones por viaje. | Se requiere determinar qué destinos acepta **cada viaje** y cuándo se bloquean cambios ordinarios. | **PENDIENTE DE DISEÑO/MODELO**. |
| **`RESERVA`** | Registra `id_recorrido` y `orden_parada` de **ascenso**, pero no una parada de descenso explícita. | `AC08-03/04` requieren distinguir los descensos individuales, especialmente en VUELTA. | **PENDIENTE DE REVISIÓN DE DER/MR**; no reinterpretar `orden_parada` como descenso. |
| **`ABONO_MENSUAL` / `CONTRATACION`** | No hay una FK explícita a la parada de destino fija de IDA ni al punto habitual de ascenso; `CONTRATACION` posee `condiciones_comerciales` de texto libre. | `AC08-01/13` exigen conservar datos operativos habituales. | **PENDIENTE DE REVISIÓN DE MODELO**; no asumir que texto libre satisface integridad y trazabilidad. |
| **RN-020** | Cambio de parada sujeto a disponibilidad de horario, recorrido y unidad. | Aplica al pedido de modificar el punto habitual/operativo del abonado. | **COHERENTE**; falta procedimiento concreto de solicitud/aprobación. |
| **RN-021** | Dueño/administrador pueden modificar un recorrido por tránsito, accidentes, cortes o fuerza mayor; deben respetar las paradas comprometidas. | Excepción legítima a una lectura demasiado absoluta de “no modificar recorrido en curso”. | **ACLARACIÓN DE ALCANCE:** `AC08-08/14` impiden agregar paradas por nuevas reservas durante la marcha; **no prohíben ajustes excepcionales de RN-021**. |
| **Issue #28** | Reservas posibles con viaje en curso si hay cupo y ascenso pendiente. | `AC08-14` precisa que el ascenso debe ser en un punto **ya previsto**, sin nuevos desvíos ordinarios. | Complementario; implementación de detección de parada pendiente continúa **PENDIENTE**. |
| **Servicios especiales / PC2** | Existe tipo de servicio `ESPECIAL`, pero no se observa un circuito completo confirmado de solicitud libre de origen/destino y presupuesto en el contrato revisado; el reparto deja fuera del PC2 varios procesos especiales. | `AC08-15/16` reflejan necesidad de negocio más amplia que el filtro puntual de charter. | **FUERA DEL ALCANCE PC2 según reparto actual** para su desarrollo integral; eventual extensión requiere aprobación del equipo. |

**Posible contradicción a resolver antes de modificar artefactos:** la entrevista menciona “ocasional” tanto al describir traslados especiales como al hablar de pasajeros sin abono. En este relevamiento se distingue explícitamente **ocasional que usa un recorrido habitual** de **cliente que solicita un especial**. La nomenclatura uniforme para interfaz/datos queda **PENDIENTE DE VALIDACIÓN** con el equipo y, si afecta una condición comercial, con VanFull.

## 6. Escenarios de aceptación y prueba para revisión

Los `PT08-*` expresan criterios funcionales confirmados o escenarios derivados para **diseñar** las pruebas. No afirman que exista ya una API o automatización que los ejecute. Donde falta una decisión, se señala expresamente.

| ID | Escenario | Resultado funcional esperado / límite | Fuente |
|---|---|---|---|
| **PT08-01** | Ocasional elige “UADE” antes de buscar una IDA. | Se listan viajes compatibles que incluyen UADE como **descenso habilitado** (junto con las demás restricciones). | AC08-02/05/06 |
| **PT08-02** | Un recorrido termina en UADE, pero otro pasajero quiere bajar antes, en Obelisco. | La parada intermedia puede seleccionarse como destino si está habilitada en ese viaje. | AC08-03 |
| **PT08-03** | Una parada está en el recorrido pero está habilitada **solo para ascenso**. | No se ofrece como destino de descenso por esa sola presencia. | AC08-06 |
| **PT08-04** | La misma parada permite descenso en un viaje y no en otro con el mismo recorrido base. | Se respeta la configuración de **cada viaje**; no se muestra la misma habilitación indiscriminadamente. | AC08-07 |
| **PT08-05** | Abonado con destino de IDA fijado al contratar consulta su reserva. | Utiliza el destino contratado sin exigir nueva elección en cada IDA. | AC08-01 |
| **PT08-06** | Abonado IDA/VUELTA realiza dos VUELTAS en distintas fechas. | Puede elegir en cada vuelta una parada de descenso habilitada (no necesariamente la misma). | AC08-04 |
| **PT08-07** | Ocasional de charter consulta disponibilidad para una dirección no definida como parada. | No se confunde una dirección libre con un destino habilitado del recorrido habitual. El mensaje/UI concretos quedan **PENDIENTES**. | AC08-02 |
| **PT08-08** | Ocasional reserva IDA y pide desvío especial hacia su casa para subir. | No se adapta el recorrido por esa solicitud; se limita a paradas existentes. | AC08-10 |
| **PT08-09** | Nuevo abonado informa domicilio; existen dos puntos cercanos previamente verificados como viables. | El sistema los propone; selecciona uno y queda confirmado sin aprobación humana adicional. | AC08-09/11 |
| **PT08-10** | No existe punto de ascenso viable para un nuevo abonado. | Se informa y deriva para evaluación manual de VanFull; no se confirma uno no viable. | AC08-12 |
| **PT08-11** | Abonado ya dispone de punto habitual de ascenso para IDA. | No necesita seleccionarlo en cada reserva de IDA. | AC08-13 |
| **PT08-12** | Abonado solicita cambiar su punto habitual. | Se procesa sujeto a compatibilidad con horario, recorrido, unidad y paradas comprometidas; procedimiento exacto **PENDIENTE**. | AC08-13 / RN-020/021 |
| **PT08-13** | Antes de iniciar una IDA se incorpora o da de baja un pasajero. | Se puede ajustar el recorrido, preservando paradas comprometidas. | AC08-09 / RN-021 |
| **PT08-14** | IDA `en_curso`: ocasional reserva con cupo y ascenso en parada prevista **pendiente**. | Posible si satisface las condiciones comerciales; no se genera nuevo desvío. | AC08-14 / Issue #28 |
| **PT08-15** | IDA `en_curso`: se solicita subir en punto nuevo no previsto. | No se incorpora una parada nueva para esa reserva ordinaria. | AC08-08/14 |
| **PT08-16** | Viaje en curso: contingencia de tránsito/fuerza mayor obliga a modificar circulación. | No se bloquea la actuación permitida por RN-021; se respetan paradas comprometidas. El procedimiento técnico es **PENDIENTE**. | RN-021 |
| **PT08-17** | Cliente pide servicio especial desde un origen distinto de Bella Vista hasta Aeroparque. | Puede indicar origen libre y destino frecuente; VanFull evalúa disponibilidad y presupuesto posteriormente. | AC08-15/16 |
| **PT08-18** | Cliente pide especial a una dirección/localidad no predefinida. | Puede informar destino libre; se tramita una solicitud, no se confirma una plaza/tarifa automáticamente. | AC08-15/16 |
| **PT08-19** | Se intenta buscar por `destino` en la implementación **actual**. | Actualmente devuelve `400 FILTRO_NO_DISPONIBLE`; documentar como diferencia a resolver, **no** como aceptación del diseño futuro. | Issue #8 / código actual |
| **PT08-20** | Filtro por destino encuentra una parada del recorrido, pero no está habilitada para descenso en ese viaje. | Ese viaje no debe ofrecerse **como compatible con ese destino**. | AC08-05/06/07 |

**PENDIENTES de prueba transversal:** verificar que el filtro por destino no desvíe el cálculo de cupo de Issue #28; que el punto de **descenso** se encuentre después del de **ascenso** en la secuencia aplicable; y cómo se informa una búsqueda sin resultados. Estos comportamientos de detalle deberán acordarse en diseño/pruebas, sin asumir una implementación inexistente.

## 7. Pendientes y decisiones por responsable

| ID | Estado | Tema a resolver | Responsable principal |
|---|---|---|---|
| **PV08-01** | **PENDIENTE DE COTEJO DOCUMENTAL** | Leer la especificación completa aprobada CU-002 v1.3 y los CU afectados (CU-003, CU-005, CU-018, CU-019, CU-030), más diagramas y DER/MR vigentes, antes de actualizar línea base. | Martín |
| **PV08-02** | **PENDIENTE DE DISEÑO DE FILTRO** | Acordar el significado técnico de `destino` y si se identifica por parada/código u otra representación; no derivar destino de la última parada del vehículo ni tratar “CABA” como nombre exacto. | Martiniano + Martín |
| **PV08-03** | **PENDIENTE DE CONTRATO** | Definir qué parámetros, validaciones y esquema de respuesta requiere CU-002, considerando destino por pasajero, sentido y paradas habilitadas; actualizar OpenAPI solo por PR aprobada. | Martiniano |
| **PV08-04** | **PENDIENTE DE MODELO (DER/MR)** | Representar/parcialmente derivar parada de **descenso por reserva** y destino fijo de IDA del abono, evitando confundir con `reserva.orden_parada` (ascenso). | Martín + Martiniano |
| **PV08-05** | **PENDIENTE DE MODELO/OPERACIÓN** | Resolver habilitación ascenso/descenso **por viaje**, punto comprometido y variación previa al inicio sin alterar silenciosamente `PARADA_RECORRIDO`. | Martín + Facundo + Martiniano |
| **PV08-06** | **PENDIENTE DE PROCESO Y ALCANCE** | Propuesta de puntos cercanos al domicilio de abonados, garantía de viabilidad previa, confirmación automática y derivación manual si no hay alternativas. Precisar algoritmo, proveedor de mapas, validación y compatibilidad con PC2. | Equipo; Martín (análisis), Martiniano (pasajero), Facundo (operación) |
| **PV08-07** | **PENDIENTE DE OPERACIÓN** | Procedimiento del cambio de punto habitual solicitado por abonado y comunicación de la resolución, conforme RN-020. | Martín + Facundo + Martiniano |
| **PV08-08** | **PENDIENTE DE INTERACCIÓN CON ISSUE #28** | Identificación confiable de paradas aún pendientes en el viaje en curso; consistencia con disponibilidad y reservas de último momento. | Martín + Martiniano |
| **PV08-09** | **PENDIENTE DE DELIMITACIÓN OPERATIVA** | Distinguir ajustes ordinarios antes de iniciar del tratamiento de contingencias de RN-021 durante la ejecución, preservando compromisos. | Martín + Facundo |
| **PV08-10** | **PENDIENTE DE ALCANCE / EXTENSIÓN** | Solicitud especial con origen/destino libre, disponibilidad diferida y presupuesto; decidir tratamiento documental para futura etapa. **No incorporarlo automáticamente a PC2.** | Equipo (alcance) + Facundo (administración) |
| **PV08-11** | **PENDIENTE DE TERMINOLOGÍA** | Unificar uso de “ocasional/eventual” de charter versus “especial/ocasional” por pedido, sin confundir ambas lógicas de selección y reserva. | Martín + equipo; VanFull si se requiere |
| **PV08-12** | **PENDIENTE DE PRUEBAS** | Definir datos de prueba, configuración por viaje, secuencia ascenso/descenso, inexistencia de resultados, concurrencia y escenarios de cambios de itinerario, sin contradecir RN-001. | Martiniano + Martín + Facundo |
| **PV08-13** | **PENDIENTE DE CONTROL DE CAMBIOS** | Determinar si las nuevas condiciones de abono, habilitación de paradas y selección de descenso exigen actualizar RF/CU/MR o incorporar nuevas reglas; hacerlo solo con aprobación del equipo. | Martín + equipo |

**Prioridad sugerida — PROPUESTA DE IA:** resolver `PV08-01` a `PV08-05` para desbloquear el filtro de CU-002; tratar `PV08-06/07/10` como necesidades documentadas cuya implementación dependerá del alcance y cronograma. Esta priorización no equivale a decisión del equipo.

## 8. Trazabilidad de necesidades → artefactos → pruebas

| Necesidad de VanFull | Aclaraciones | Referencias existentes | Interfaz / datos actuales | Escenarios |
|---|---|---|---|---|
| Buscar viaje habitual por destino del pasajero, no por fin del recorrido | AC08-01/02/03/05 | CU-002, RF-004, RN-001 | `GET /servicios/disponibilidad`, `parada`, `parada_recorrido`, `viaje` | PT08-01, 02, 05, 19, 20 |
| Respetar destinos de vuelta y habilitaciones por viaje | AC08-04/06/07 | CU-002, CU-003, RN-001 | `parada_recorrido`, `reserva`, `viaje.sentido` | PT08-03, 04, 06, 20 |
| Tratar destino fijo y ascenso habitual de abono sin repetir selección | AC08-01/09/11/13 | CU-003, CU-028 (a cotejar), RN-020 | `abono_mensual`, `contratacion`, `reserva` | PT08-05, 09, 11, 12 |
| Ajustar ascensos al domicilio sin afectar compromisos | AC08-08/09/10/12/14 | RN-020, RN-021, CU-017/019 (a cotejar) | `parada_recorrido.comprometida`, `viaje`, `reserva` | PT08-08 a 16 |
| Solicitar especiales con direcciones abiertas y cotización posterior | AC08-15/16 | Servicios ESPECIALES; CU específicos **a cotejar** | `servicio.tipo_servicio`, `contratacion` (sin circuito confirmado en OpenAPI actual) | PT08-17/18 |

Los RF/CU adicionales señalados **no se consideran modificados**. No se inventan nuevos RF, RN, CU o integraciones. Cualquier cambio a DER/MR deberá mantener su historial de aprobación y la trazabilidad a la necesidad que lo originó.

## 9. Alcance PC2 y responsabilidades

Según `REPARTO-PC2.md` (acordado 13/10/2026):

- **Dentro del PC2 ya previsto:** CU-002 (consulta de servicios/disponibilidad) y CU-003 (reserva) para el módulo pasajero — **Martiniano**. Integración con viajes creados/asignados por **Facundo** y con su ejecución, paradas pendientes y abordajes gestionados por **Martín**.
- **Dependencia funcional directa del Issue #8:** resolver la semántica del destino en las búsquedas habituales; evaluar su representación en el contrato y en los datos. Ningún cambio al modelo o contrato está autorizado aún.
- **Fuera del PC2 según el reparto vigente:** optimización integral de recorridos y procesos de gestión de recorridos/paradas; contratación integral de abonos y desarrollo completo de servicios especiales sujetos a cotización. **No se convierten en entregables PC2 por aparecer en este relevamiento.**
- **Extensión futura / pendiente de aprobación:** algoritmo que propone puntos cercanos verificados y confirmación automática; derivación manual operacional; circuito de solicitud/cotización de especiales; eventuales estructuras por viaje/parada/abono.

**Dependencias entre integrantes:** un cambio de datos compartidos, API, alta de viajes, capacidad o configuración de paradas debe acordarse antes de implementación. No escribir directamente sobre tablas de otros módulos eludiendo la capa de servicios prevista.

## 10. Propuestas de IA (no aprobadas)

1. **PROPUESTA DE IA:** para el **filtro de viajes habituales** buscar por una referencia estable de parada y vincularla con los viajes cuya configuración permite **descenso** allí; preservar separación entre última parada del vehículo y destino de cada pasajero. Decidir en equipo si aprovechar `id_parada` existente o incorporar un mecanismo distinto, sin crear un endpoint/parámetro en esta etapa.
2. **PROPUESTA DE IA:** modelar conceptualmente, antes de elegir tablas, tres nociones distintas: (a) parada del recorrido, (b) habilitación de ascenso/descenso de un viaje y (c) ascenso y descenso comprometidos con el pasajero. Evaluar si se justifican cambios al DER/MR.
3. **PROPUESTA DE IA:** para la primera entrega, priorizar el caso de búsqueda por paradas predefinidas y documentar la **brecha** si la configuración variable por viaje no puede implementarse fielmente; no simular que está resuelta con un simple filtro por `parada_recorrido`.
4. **PROPUESTA DE IA:** documentar el comportamiento de especiales como **circuito distinto** de las reservas sobre viajes publicados, sin prometer cotización ni alta automática en PC2.

Ninguna propuesta es un requisito nuevo ni una regla de negocio aprobada.

## 11. Control de calidad / revisión requerida

- [x] Contraste de entrevista del 25/08/2026 con respuestas directas del 18/10/2026.
- [x] Contraste de RN-001, RN-020, RN-021, RN-023 y RN-031 con documento RN v1.1 aprobado.
- [x] Revisión de Issue #8, `schema.sql`, `openapi.yaml`, servicio `disponibilidad.py` y reparto PC2.
- [x] Separación de destino del pasajero, destino del recorrido, ascenso y descenso.
- [x] Excepción RN-021 explicitada: no crear una prohibición absoluta de cambios operativos en curso.
- [x] Identificados cambios potenciales del DER/MR y contrato sin implementarlos.
- [x] Identificados alcance PC2, dependencias, escenarios y responsables.
- [x] **Aprobación funcional de Martín otorgada el 18/10/2026 para consolidar la v0.2.**
- [ ] Cotejo integral de CU v1.3, diagramas y DER/MR oficiales antes de tocar la línea base.
- [ ] Validación técnica del diseño y cambios de alcance con el equipo.
- [ ] Pruebas y CI de la implementación que eventualmente se apruebe.

## 12. Próximos pasos (posteriores a la aprobación funcional)

1. Incorporar **solo este documento v0.2** mediante una rama y PR documental, con revisión de impacto de Martiniano y Facundo y coordinación operativa con Martín.
2. Cotejar íntegramente los CU y el DER/MR oficiales afectados antes de proponer modificaciones de la línea base.
3. Resolver los pendientes de diseño y, si corresponde, tramitar cambios controlados sobre DER/MR, RF/RN/CU, contrato, interfaz y pruebas en PR separadas con aprobación del equipo.
4. Mantener abierto el Issue #8 hasta que el filtro de destino comprometido esté implementado, sea coherente con reservas y quede verificado mediante pruebas.

---

**Control de versión:** v0.2, validada funcionalmente por Martín el 18/10/2026 sobre el contenido de la v0.1, **sin cambios sustantivos** en aclaraciones AC08 ni escenarios PT08. Continúan **PENDIENTES DE VALIDACIÓN** las decisiones técnicas, los ajustes al Modelo Relacional y el alcance de funcionalidades relacionadas. No genera por sí sola un cambio de la línea base vigente.