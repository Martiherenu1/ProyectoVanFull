# VanFull — Aclaración funcional del respaldo de reservas ocasionales

**Versión:** 0.2 — VALIDADA FUNCIONALMENTE POR MARTÍN, RESPONSABLE DE ANÁLISIS  
**Fecha de elaboración:** 18/10/2026  
**Fecha de aprobación funcional por Martín:** 18/10/2026  
**Revisión complementaria:** 18/10/2026 — se incorpora la respuesta expresa de VanFull a las observaciones de revisión de PR #58: ida y vuelta en fechas distintas requieren contrataciones independientes.  
**Estado:** APROBADO FUNCIONALMENTE POR MARTÍN (Integrante 2 / análisis, 18/10/2026); PENDIENTE DE REVISIÓN TÉCNICA POR MARTINIANO Y FACUNDO Y DE MERGE DE LA PR #58. No constituye un cambio aprobado de la línea base RN/CU/MR, ni una autorización de implementación.
**Tema:** Issue [#7 — CU-003: respaldo de la reserva creada por el pasajero](https://github.com/Martiherenu1/ProyectoVanFull/issues/7)  
**Interdependencias:** Issue #33; documento de aclaración CU-003 v0.2 (PR #56); Issues #9, #28 y #34  
**Ubicación propuesta tras aprobación:** `Documentos/Sesiones/PC2/ACLARACION-FUNCIONAL-CU003-ISSUE7-v0.2-VALIDADA-ANALISIS.md`

## 1. Objetivo y límites

Documentar las aclaraciones que VanFull comunicó a Martín sobre **cómo se solicita, agrupa y reemplaza una contratación ocasional que respalda reservas de viaje**, de manera que el equipo pueda decidir de dónde obtiene CU-003 el respaldo requerido por MR-R13 sin inventar reglas de negocio.

- **Dentro del alcance de esta aclaración:** solicitudes ocasionales sin contratación anterior; aceptación digital automática condicionada; contratación que comprende ida y vuelta; incorporación posterior de un segundo tramo cuando la ida está paga o impaga; conservación de la ida si no existe cupo de vuelta; trazabilidad y pendientes técnicos.
- **Fuera del alcance:** nuevas tarifas/descuentos; sanciones por ausencias o impagos; inventar estados de contratación; cancelación económica fuera de las condiciones ya aprobadas; rediseñar OpenAPI o el MR; incorporación automática de funciones de abonos, especiales o corporativos al PC2.
- **Alcance de PC2:** CU-003 es parte del PC2 de Martiniano. Los abonos y la gestión corporativa completos quedan fuera del PC2 según `REPARTO-PC2.md`; no ampliar dicho alcance mediante este documento.

## 2. Fuentes consultadas y clasificación

| Fuente | Autoridad | Uso / alcance del cotejo |
|---|---|---|
| Aclaraciones directas de VanFull transmitidas por Martín durante la conversación de análisis del Issue #7 (18/10/2026) | **CONFIRMADO POR VANFULL** según declaración expresa del entrevistador | Seis situaciones operativas de contratación ocasional, recogidas en la sección 3. No se atribuyen retroactivamente a la entrevista escrita del 25/08/2026. |
| `FC-01 — Aclaraciones posteriores de la entrevista VanFull.md` | Fuente primaria recordada por entrevistador | FC-01.03 (solo vuelta), FC-01.05–06 (verbal/provisional) y FC-01.20 (efectivo al abordar). No describe la agrupación ni el reemplazo posterior: esos datos son aclaraciones nuevas. |
| CU-003 v1.3 (citado en Issue #7 y #33) y documento de CU v1.1 accesible en Drive | **DEFINIDO POR EL EQUIPO** para la línea base | CU-003 permite seleccionar servicio/condiciones y diferencia provisional/consolidada; **pendiente cotejo integral directo del original v1.3** antes de modificar su texto. |
| MR-R13, MR-R15 y `backend/db/schema.sql` (`main`, revisión 18/10/2026) | **DEFINIDO POR EL EQUIPO** | Respaldo XOR, vínculos y unicidad. |
| `backend/openapi/openapi.yaml` (`main`, revisión 18/10/2026) | Contrato técnico vigente | `ReservaCreate` contiene `id_viaje` y `orden_parada`, sin declarar respaldo ni agrupación. |
| Aclaración CU-003 — Issue #33 v0.2, PR #56 | Aprobada funcionalmente por Martín; incorporación/revisión del equipo en trámite | Condiciones de garantía por modalidad. La aceptación automática de ocasionales aquí registrada es una **precisión posterior** que requiere coordinación documental con ese anexo. |
| `CONTRIBUTING.md` y `REPARTO-PC2.md` | **DEFINIDO POR EL EQUIPO** | Procedimiento de controles de cambios y límites entre áreas. |

**Precedencia aplicada:** consignas docentes > VanFull > decisiones formalmente aprobadas por el equipo > propuestas de IA. Ninguna sugerencia técnica de este documento se clasifica como regla aprobada.

## 3. Aclaraciones comerciales de VanFull

Todas las afirmaciones de esta sección están clasificadas **CONFIRMADO POR VANFULL**, comunicadas explícitamente por Martín durante el análisis del Issue #7.

| Ref. local* | Escenario comercial | Comportamiento confirmado |
|---|---|---|
| AC7-01 | Un pasajero ocasional quiere reservar sin contrato comercial previo. | VanFull **permite solicitar y obtener una reserva** sin contratación comercial preexistente. |
| AC7-02 | Solicitud ocasional desde aplicación/chatbot, con disponibilidad y condiciones comerciales cumplidas. | **El sistema acepta automáticamente** la solicitud y garantiza el asiento, sin exigir aceptación manual previa de administración. |
| AC7-03 | Pasajero ocasional solicita ida y vuelta conjuntamente. | **Solo si ida y vuelta son del mismo día** pueden abarcarse en **una misma contratación** y pagarse en conjunto. Si son de **días distintos**, corresponden **dos contrataciones independientes**, cada una con su tarifa individual; no se aplica tarifa conjunta (AC9-06, Issue #9). |
| AC7-04 | Tiene una ida reservada, **no pagada**, y solicita agregar la vuelta, con disponibilidad. | **Solo cuando ambos viajes son del mismo día**, debe **cancelarse la primera contratación** y **generarse una nueva** conjunta de ida y vuelta, sujeto a disponibilidad y condiciones comerciales. **Si la vuelta es de otro día, no se reemplaza la contratación de ida:** se conserva y se genera otra contratación independiente para la vuelta, con tarifa individual. |
| AC7-05 | Tiene la ida **pagada** y luego desea agregar la vuelta. | Puede **contratar la vuelta por separado**, conservando la contratación de ida. |
| AC7-06 | Tiene una ida no pagada y desea agregar la vuelta, pero **no existe cupo** en ese viaje. | VanFull **mantiene vigente la reserva original de ida**; no se la cancela por la solicitud frustrada. |

\* Los códigos **AC7-01 a AC7-06 son referencias internas de esta aclaración, no nuevas RN, RF, CU ni identificadores aprobados de línea base**.

**Contexto confirmado en el Issue #33:** cuando el ocasional paga en efectivo al abordar, una reserva **aceptada** garantiza el lugar aunque el pago siga pendiente. AC7-04/06 se refieren a un cambio **solicitado por el pasajero**; no autorizan a VanFull a cancelar por sí sola una reserva garantizada simplemente porque aún no esté paga.

**Relación expresa con AC9-06 (Issue #9):** la tarifa ocasional conjunta `IDA_VUELTA` solo aplica a **viajes del mismo día**. En **días distintos**, las contrataciones son **independientes** y utilizan las tarifas individuales de cada viaje; esto precisa AC7-03 y acota el reemplazo previsto en AC7-04. No confundir que dos reservas puedan compartir una contratación a nivel de MR con una autorización comercial para agrupar cualquier fecha.

**Restricción común:** todo nuevo tramo está sujeto a la disponibilidad y a las condiciones comerciales aplicables (RN-001 y CU-003). La aceptación automática no implica sobreventa ni soslaya otros requisitos del servicio.

## 4. Consistencia con el Modelo Relacional aprobado

### 4.1. Respaldo obligatorio y compatibilidad de varios viajes

- **MR-R13 (DEFINIDO POR EL EQUIPO):** cada fila de `reserva` debe tener **exactamente uno** de `id_periodo_abono` o `id_contratacion_directa`. El `CHECK` XOR de `schema.sql` impide ambos nulos o ambos informados.
- `reserva.id_contratacion_directa` tiene FK a `contratacion.id_contratacion` **sin unicidad**. Por ello, **varias reservas pueden compartir una misma contratación**: AC7-03 es compatible estructuralmente con el MR **solo cuando la agrupación comercial está permitida (ida y vuelta del mismo día)**.
- Para abonos, la FK compuesta `(id_periodo_abono, id_viaje)` debe existir en `periodo_abono_viaje`. Este respaldo y su validación **no se sustituyen** por el de contratación directa.
- **MR-R15 (DEFINIDO POR EL EQUIPO):** `UNIQUE (id_pasajero, id_viaje)`. No se deben crear dos filas para la misma combinación de pasajero y viaje; corresponde analizar cómo conservar/revincular el registro de ida durante AC7-04, conforme a las decisiones aprobadas de reutilización de la reserva.

### 4.2. Diferencias que NO están resueltas por el esquema

- **Restricción de fechas confirmada:** AC7-03/04 no permiten agrupar ida y vuelta en fechas diferentes; en ese caso son dos contrataciones y tarifas individuales (AC9-06). La compatibilidad estructural del MR no elimina esta restricción comercial.
- `contratacion` **no tiene campo `estado`**. «Cancelar una contratación» (AC7-04) es un comportamiento comercial, pero **el mecanismo de persistencia, historial y efectos contables están PENDIENTES DE DISEÑO**. No equiparar cancelación de contratación, cancelación de `reserva` y baja física de datos.
- `contratacion` tiene un solo `id_servicio`; `viaje` también indica `id_servicio`. La compatibilidad entre viajes agrupados y ese servicio debe comprobarse; **no inferir** agrupaciones de servicios distintos.
- `contratacion.id_cliente` y `reserva.id_pasajero` refieren entidades diferentes. El servicio backend debe validar la relación/autorización del titular de la contratación con el pasajero, sin confiar en un identificador arbitrario enviado por la aplicación.
- `servicio.tipo_servicio` admite `UNIVERSITARIO`, `LABORAL`, `CORPORATIVO`, `ESPECIAL`; **no** admite `OCASIONAL`. El encuadre de la modalidad ocasional sigue **PENDIENTE DE VALIDACIÓN**; no agregar una opción a ciegas ni confundir ocasional con especial.
- `pago` se relaciona con `cliente` y los movimientos contables pueden referirse a `contratacion`; no hay una FK simple `reserva → pago`. La factibilidad del pago conjunto no define aún cómo contabilizarlo o acreditarlo (área de Facundo).

## 5. Diferencia entre aclaración comercial y propuesta de implementación

**PROPUESTA DE IA — pendiente de revisión técnica de Martiniano y Facundo y de aprobación mediante el procedimiento del equipo:**

1. Para una reserva ocasional sin contratación previa, el backend **crearía el respaldo comercial válido como parte de la operación de reserva**; no exigiría que el pasajero haya creado previamente una `contratacion`.
2. En una solicitud conjunta de ida y vuelta **del mismo día**, **validaría ambos viajes y registraría una contratación directa compartida**, vinculando cada reserva individual a la misma. La creación de respaldo/reservas debería ser **atómica** para evitar registros huérfanos o cupos parcialmente ocupados; además debe verificarse concurrencia real del cupo (#28).
3. Para AC7-04, **únicamente si ida y vuelta son del mismo día**, antes de reemplazar la contratación impaga, **verificaría primero** cupo de vuelta, estado comercial y elegibilidad de la operación. Si no hay cupo, mantendría la ida **sin modificar**. Si sí hay, realizaría el reemplazo como una sola operación consistente, sin duplicar la reserva de ida ni perder su lugar.
4. Para viajes de días distintos, **mantendría** la contratación original de ida (aunque esté impaga) y tramitaría la vuelta mediante otra contratación individual, previa comprobación de cupo y condiciones comerciales; **no** aplicaría sustitución AC7-04.
5. Para AC7-05, **mantendría** el respaldo existente de ida y tramitaría la vuelta bajo otra contratación.
6. Centralizaría las validaciones de respaldo y vínculo cliente–pasajero en servicios backend de los dueños del tema, nunca en Flutter ni mediante escritura directa del chatbot a PostgreSQL.

**No se decide todavía:** si el sistema deduce el respaldo, si recibe un identificador, si se agrega una operación compuesta o se orquestan varias; cómo crear/anular una contratación; cómo manejar movimientos contables o reintegros; cómo marcar «pagada» una contratación; ni qué se comunica en una solicitud de vuelta rechazada.

### OpenAPI actual — discrepancia identificada

`ReservaCreate` declara únicamente `id_viaje` y `orden_parada`. No existe en el contrato revisado un campo que identifique `id_periodo_abono` / `id_contratacion_directa`, ni una operación definida para reservar **dos viajes conjuntamente**.

**PENDIENTE DE DECISIÓN TÉCNICA (#7):** definir de dónde obtiene el backend el respaldo, cómo registra la agrupación, cómo respeta CU-003 para app y chatbot, y qué cambio mínimo de OpenAPI —si alguno— se necesita. Cualquier modificación de una operación existente requiere el acuerdo del equipo según `CONTRIBUTING.md` / `REPARTO-PC2.md`.

## 6. Casos de aceptación y pruebas candidatos (NO ejecutados ni aprobados)

| Escenario | Resultado funcional a asegurar | Aspecto pendiente de implementación |
|---|---|---|
| Ocasional sin contratación previa y con cupo | Solicitud válida; aceptación automática si se cumplen las condiciones; respaldo comercial válido al registrar reserva. | Generación de contratación y verificación de cliente/tarifa. |
| Ocasional con pago en efectivo al abordar | Lugar garantizado aunque el pago aún no se haya acreditado. | Estado de reserva y evidencia de condiciones comerciales (#33). |
| Ida y vuelta **del mismo día** solicitadas juntas | Dos reservas por sus respectivos viajes, vinculables a **una** contratación; pago conjunto y tarifa conjunta posible (AC7-03, AC9-06). | Operación de varios viajes y contabilidad. |
| Ida impaga + vuelta disponible **del mismo día** | Se sustituye comercialmente la contratación de ida por una nueva de ida/vuelta, sin perder la reserva de ida (AC7-04). | Representación de anulación/reemplazo; unicidad MR-R15; transacción. |
| Ida y vuelta **de días distintos** | Dos reservas con **dos contrataciones independientes** y **tarifas individuales**; no corresponde precio conjunto, aunque la ida esté impaga (AC7-03/04; AC9-06). | Creación de contratación separada, cupo y selección de tarifa individual. |
| Ida impaga + vuelta sin cupo | Se informa falta de disponibilidad **sin modificar ni liberar** la reserva/contratación de ida. | Validación previa y control de concurrencia (#28). |
| Ida pagada + vuelta | La ida y su contratación se conservan; la vuelta puede tener contratación independiente. | Identificación fiable de pago y relación con movimientos contables. |
| Falla técnica durante reemplazo | Sin efecto parcial sobre la reserva garantizada de ida. | Atomicidad/rollback e idempotencia (recomendaciones técnicas). |
| Reserva por período de abono | FK `(id_periodo_abono, id_viaje)` apunta a combinación válida de `periodo_abono_viaje`. | Origen de identificación y validación de período correspondiente; fuera del circuito completo de abonos del PC2. |

## 7. Matriz de trazabilidad

| Necesidad confirmada / restricción | Fuente | CU / requisito | Modelo/API | Seguimiento |
|---|---|---|---|---|
| Reservar sin contratación previa | AC7-01; CU-003 | CU-003, RF-005 | `contratacion`, `reserva` | #7 |
| Aceptación digital automática si hay cupo | AC7-02, RN-001; aclaración #33 | CU-003, RF-005 | `reserva.estado`, servicio de reservas y API | #7, #33, #28 |
| Agrupar ida/vuelta y pago conjunto **del mismo día** | AC7-03; AC9-06; MR-R13 | CU-003 | Una `contratacion`, dos `reserva`, circuito de pagos | #7, #9; administración/pagos |
| Reemplazar contratación impaga al agregar vuelta **del mismo día** | AC7-04; AC9-06; MR-R15 | CU-003 y eventual operación de cambio | `contratacion`, `reserva`, `movimiento_cuenta` | #7, #28; diseño pendiente |
| Contratar ida/vuelta de **días distintos** | AC7-03/04; AC9-06 | CU-003 | Dos `contratacion`, dos `reserva`, tarifas individuales | #7, #9; coordinación de reservas y tarifas |
| Preservar ida si no hay cupo para vuelta | AC7-06; RN-001 | CU-003 | cupo, transacción, reservas | #7, #28 |
| Conservar ida paga y contratar vuelta independiente | AC7-05; RN-015 cuando corresponda | CU-003 | dos contrataciones; pagos | #7, administración/pagos |
| Respaldo por abono distinto de directo | MR-R13, MR-R15 y decisión aprobada de FK compuesta | CU-003; CU de abonos fuera del PC2 completo | `periodo_abono_viaje`, `reserva` | #7; alcance PC2 |

## 8. Contradicciones y pendientes de validación

### No se detecta una contradicción estructural necesaria con MR-R13/MR-R15

**Aclaración comercial transversal confirmada por VanFull (18/10/2026):** AC7-03 y AC7-04 se aplican a la ida y la vuelta **del mismo día**; si corresponden a días distintos, cada viaje tiene **su propia contratación y tarifa individual**. Coherente con AC9-06 de la aclaración de tarifas (PR #59). Esta decisión precisa el alcance comercial y no modifica MR-R13/MR-R15.

- **AC7-03 no contradice MR-R13:** cada reserva conserva un respaldo único, y las dos pueden referir la misma contratación.
- **AC7-04/06 son compatibles comercialmente** si se garantiza que la solicitud de cambio no libera la ida cuando falta cupo para vuelta. **La implementación no está resuelta** porque `contratacion` carece de estado y hay que respetar MR-R15.
- **AC7-02 amplía la aclaración del Issue #33**: la v0.2 aún lista como pendiente qué constituye aceptación desde app/AG-01. Ahora VanFull confirmó que, para ocasionales, puede ser automática si se cumplen condiciones y disponibilidad. **Debe informarse al equipo y registrarse como precisión posterior**, sin modificar silenciosamente el PR #56. La evidencia técnica de aceptación automática sigue pendiente.

### Pendientes concretos

1. **PENDIENTE DE VALIDACIÓN / DISEÑO:** correspondencia del ocasional con tipos `servicio.tipo_servicio` vigentes.
2. **PENDIENTE TÉCNICO (#7):** algoritmo para determinar respaldo (deducción, selección, generación), entrada de `ReservaCreate`, reservas conjuntas y preservación del vínculo cliente–pasajero.
3. **PENDIENTE TÉCNICO Y DE MODELO:** cómo reflejar cancelación/sustitución de `CONTRATACION` impaga y mantener trazabilidad histórica; no agregar `estado` sin control de cambio.
4. **PENDIENTE COMERCIAL/CONTABLE:** qué significa «contratación ya pagada» en presencia de pagos parciales, pendientes o confirmados; efectos de RN-015 y de las reglas de cancelación ocasional (RN-017). No establecer excepciones ni créditos automáticamente.
5. **PENDIENTE TÉCNICO (#9):** cálculo de la tarifa/importe al agrupar ida y vuelta.
6. **PENDIENTE TÉCNICO (#28):** disponibilidad con/sin vehículo y control concurrente en solicitudes compuestas.
7. **PENDIENTE DE VALIDACIÓN:** cómo opera este circuito si los tramos pertenecen a distintos servicios; no inferir soporte de múltiples `id_servicio` por contratación.
8. **PENDIENTE DOCUMENTAL:** cotejo directo final con CU-003 v1.3 completo y consigna docente vigente antes de modificar la línea base.

## 9. Aprobaciones y pasos posteriores

| Interviniente | Estado | Evidencia |
|---|---|---|
| VanFull (información comercial) | **CONFIRMADO POR VANFULL según entrevistador Martín** | Respuestas de Martín durante análisis de Issue #7, 18/10/2026. |
| Martín, responsable de análisis | **APROBADO (contenido funcional de este documento)** | 18/10/2026; aprobación expresa de Martín en conversación del proyecto. No equivale a aprobación técnica ni del equipo. |
| Martiniano, pasajero/backend | **PENDIENTE DE REVISIÓN TÉCNICA** | Impacto CU-003 y contrato. |
| Facundo, pagos/administración | **PENDIENTE DE REVISIÓN TÉCNICA** | Impacto contratación/pagos y alcance. |
| Equipo, incorporación de cambios a línea base | **PENDIENTE** | Control de cambio si fuera necesario, conforme a `CONTRIBUTING.md` §1.8. |

**Secuencia de seguimiento:** (1) **COMPLETADO** — aprobación funcional del documento por Martín el 18/10/2026; (2) revisión de Martiniano y Facundo; (3) decidir si alcanza aclaración documental o se requiere control de cambio de CU/MR/OpenAPI; (4) registrar seguimiento en Issue #7 y coordinar actualización/anexo del #33; (5) solo después diseñar implementación y pruebas en PR(s) según reparto del PC2. **No cerrar #7 por aprobar este borrador.**

---

**Nota de control:** revisión complementaria de AC7-03/04 y escenarios por fecha confirmada expresamente por VanFull el 18/10/2026, a pedido de Marti; el documento se preparó a partir de fuentes identificadas y aclaraciones comunicadas por Martín y fue aprobado funcionalmente por él el 18/10/2026. No se ejecutaron pruebas, no se cambió código ni contrato y no se obtuvo aprobación adicional de profesores o empresa por fuera de las aclaraciones expresamente relatadas. La validación funcional no implica conformidad de Martiniano y Facundo ni cierre del Issue #7.
