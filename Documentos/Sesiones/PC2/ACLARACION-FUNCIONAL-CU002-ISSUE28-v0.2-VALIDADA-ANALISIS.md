# VanFull — Aclaración funcional de capacidad, disponibilidad y liberación de cupos

**Versión:** 0.2 — VALIDADA POR ANÁLISIS (MARTÍN)  
**Fecha del relevamiento:** 18/10/2026  
**Estado:** **APROBADO FUNCIONALMENTE POR MARTÍN** el 18/10/2026. Las aclaraciones confirmadas por VanFull no constituyen por sí mismas modificaciones aprobadas de la línea base ni decisiones técnicas.  
**Origen:** [Issue #28 — CU-002: capacidad sin vehículo, viajes ofrecidos y ausencias](https://github.com/Martiherenu1/ProyectoVanFull/issues/28).  
**Responsable del relevamiento:** Martín — Integrante 2.  
**Revisión técnica posterior:** Martiniano (disponibilidad, reservas, contrato API), Martín (ejecución del viaje, ubicación y ausencias) y Facundo (creación y asignación de viajes/vehículos).  
**Ubicación prevista:** `Documentos/Sesiones/PC2/ACLARACION-FUNCIONAL-CU002-ISSUE28-v0.2-VALIDADA-ANALISIS.md`.

> **Alcance del documento.** Recopila aclaraciones funcionales transmitidas por Martín como respuestas directas de VanFull durante el 18/10/2026. Los identificadores `AC28-*`, `PT28-*` y `PV28-*` son internos de esta aclaración funcional validada, **no** nuevos RF, RN ni CU. Ninguna propuesta de implementación está aprobada por este documento. No modificar RN, CU, DER/MR, SQL, OpenAPI o código hasta completar la revisión y el control de cambios que corresponda.

## 1. Problema, objetivo y límites

El Issue #28 identifica tres criterios incompletos para consultar disponibilidad (**CU-002**) y reservar (**CU-003**):

1. Capacidad aplicable cuando el viaje aún no tiene vehículo asignado.
2. Estados y horarios en los que se pueden seguir ofreciendo viajes.
3. Efecto de las ausencias voluntarias sobre los lugares disponibles.

**Objetivo:** documentar el comportamiento comercial y operativo confirmado por VanFull para que la disponibilidad mostrada al pasajero coincida con la validación de la reserva y con la operación del chofer, sin exceder las capacidades de las unidades.

**Dentro del análisis:** selección de capacidad, estado del viaje, parada futura, ausencia voluntaria, reutilización del cupo, recuperación de lugar, trazabilidad y pruebas.

**Fuera de esta aprobación:** implementación de seguimiento de paradas alcanzadas; nuevos endpoints, columnas, estados o algoritmos; modificación de RN-025; cambios de interfaz; definición del filtro `destino` (Issue #8); implementación integral de lista de espera (cuestión vinculada a CU-003); ampliaciones funcionales no acordadas para PC2.

## 2. Fuentes contrastadas y precedencia

| Fuente | Clasificación | Alcance / observaciones |
|---|---|---|
| Aclaraciones de VanFull transmitidas explícitamente por Martín en este intercambio del 18/10/2026 | **CONFIRMADO POR VANFULL** | Fuente de las definiciones `AC28-01` a `AC28-09`. Son posteriores a la entrevista y precisan la operación prevista. |
| `01_Entrevista_VanFull_2026-08-25.docx` | Entrevista directa | Confirma control de lugares disponibles, unidades de 19/24 asientos, posibilidad de múltiples reservas con límites y ausencia sin penalización. No detalla las reglas nuevas de viaje `en_curso`. |
| `02_Reglas_de_Negocio_VanFull_v1.1_Aprobado_Equipo(1).docx` | **DEFINIDO POR EL EQUIPO** | RN-001 (capacidad), RN-002 (consolidación), RN-022 (no presentación en parada), RN-023 (abordaje), RN-024 (ausencia sin penalización), RN-025 (liberación voluntaria), RN-031 (restricciones por sentido/día). Línea base no modificada. |
| [Issue #28](https://github.com/Martiherenu1/ProyectoVanFull/issues/28) | Registro de pendiente en GitHub | Abierto al momento de la revisión; identifica los tres puntos y la implementación provisional. |
| [`backend/app/services/disponibilidad.py`](https://github.com/Martiherenu1/ProyectoVanFull/blob/main/backend/app/services/disponibilidad.py) | Implementación vigente consultada | Solo ofrece `programado`; prioridad vehículo → capacidad planificada → `None`; cuenta reservas `consolidada` sin excluir ausencias. |
| [`backend/db/schema.sql`](https://github.com/Martiherenu1/ProyectoVanFull/blob/main/backend/db/schema.sql) | Modelo físico vigente consultado | Columnas de `viaje`, `reserva`, `ausencia`, `abordaje`, `parada_recorrido` y `posicion_gps`. |
| [`backend/openapi/openapi.yaml`](https://github.com/Martiherenu1/ProyectoVanFull/blob/main/backend/openapi/openapi.yaml) | Contrato vigente consultado | `GET /servicios/disponibilidad` devuelve cupo por viaje; `ReservaCreate` contiene `orden_parada`. |
| [`Documentos/Sesiones/PC2/REPARTO-PC2.md`](https://github.com/Martiherenu1/ProyectoVanFull/blob/main/Documentos/Sesiones/PC2/REPARTO-PC2.md) | **DEFINIDO POR EL EQUIPO** | Responsables por tablas/servicios, coordinación de cambios y límites de PC2. |
| Ajuste **ADJ-03** del proyecto | **DEFINIDO POR EL EQUIPO**, citado en Issue #28 y reparto PC2 | Vehículo asignado determina la validación de capacidad; iniciar viaje exige chofer y vehículo asignados. Revisar el artefacto aprobado completo si se modifica el diseño. |
| Especificaciones completas CU-002, CU-003 y CU-008, versión v1.3 | **DEFINIDO POR EL EQUIPO** | **PENDIENTE DE COTEJO DIRECTO** de la última versión íntegra antes de modificar sus textos. Este documento no reproduce un texto no comprobado. |

**Orden de autoridad:** consignas docentes > comunicaciones directas de VanFull > decisiones del equipo > recomendaciones de IA. Si una aclaración reciente precisa o modifica el alcance de una RN aprobada, se registra expresamente y se tramita el ajuste; **no se sobrescribe silenciosamente**.

## 3. Matriz de aclaraciones funcionales

Todos los siguientes enunciados corresponden a **CONFIRMADO POR VANFULL — 18/10/2026**.

### 3.1. Capacidad aplicable

| ID | Aclaración confirmada |
|---|---|
| **AC28-01** | VanFull permite recibir y consolidar reservas para un viaje sin vehículo asignado, mientras exista capacidad aplicable. Si existe `capacidad_planificada`, esa es la referencia inicial; al asignar la unidad se comprueba que tenga capacidad suficiente para las reservas existentes. |
| **AC28-02** | Cuando no hay vehículo asignado **ni** capacidad planificada, se utiliza una **capacidad predeterminada de 19 pasajeros**, identificada por VanFull como la mínima habitual de sus unidades. |
| **AC28-03** | Si existe una unidad asignada, prevalece **la capacidad real de esa unidad** sobre la capacidad planificada/predeterminada. La asignación debe respetar las reservas existentes. |

**Jerarquía funcional para determinar la capacidad:**

1. Si hay vehículo asignado → capacidad de ese vehículo.
2. Si no hay vehículo, pero existe capacidad planificada → capacidad planificada.
3. Si no hay ninguna de las dos → 19 lugares predeterminados.

No se autoriza a superar la capacidad aplicable. El modo de gestionar una asignación que no alcanza para reservas previas **no fue definido** (véase `PV28-02`).

### 3.2. Viajes ofrecidos y parada de ascenso

| ID | Aclaración confirmada |
|---|---|
| **AC28-04** | VanFull permite aceptar reservas en un viaje `en_curso` **si hay cupo y la parada elegida para abordar todavía no fue alcanzada**. El viaje en curso no basta, por sí solo, para habilitar cualquier reserva. |
| **AC28-05** | Si el horario programado ya pasó, pero el viaje continúa `programado` porque todavía **no comenzó realmente**, VanFull permite seguir recibiendo reservas, con cupo y condiciones comerciales aplicables. El reloj no es por sí solo un cierre automático. |

**Distinción importante:** `viaje.estado = 'programado'` y el horario programado no prueban por sí mismos dónde está la unidad o si una parada fue alcanzada. La consulta por viaje y la autorización de una **parada concreta** deben ser coherentes, pero el mecanismo técnico para garantizarlo **está pendiente**.

**No convertir en regla confirmada sin nueva validación:** la política exacta de visibilidad de viajes `finalizado` o `cancelado` y de reservas que no puedan asociarse a una parada pendiente. Propuesta de diseño: no ofrecer estos estados como reservables; requiere revisión de la especificación de CU correspondiente.

### 3.3. Ausencias, disponibilidad y regreso a la reserva

| ID | Aclaración confirmada |
|---|---|
| **AC28-06** | Cuando un pasajero informa y confirma voluntariamente su ausencia mediante la aplicación, **el cupo que ocupaba se libera automáticamente**, sin requerir aprobación adicional de administrador o chofer. |
| **AC28-07** | El cupo liberado puede utilizarlo **cualquier pasajero que cumpla las condiciones comerciales pertinentes**, incluidos otros abonados y pasajeros ocasionales; no es exclusivo de eventuales. |
| **AC28-08** | Si quien informó la ausencia cambia de opinión, solo puede intentar recuperar un lugar **si existe cupo al momento de solicitarlo**. No conserva prioridad ni desplaza a quien ya consolidó una reserva sobre el cupo liberado. |
| **AC28-09** | El pasajero puede informar una ausencia incluso con el viaje `en_curso`, **mientras todavía no haya abordado**. El cupo liberado podrá aprovecharse para otra reserva cuando también se cumplan las condiciones de capacidad y parada futura. |

**Alcance y preservación:** informar una ausencia no se equipara automáticamente con `cancelar reserva`. Tampoco está definido si el registro de ausencia se revoca, reemplaza o cambia de estado ante un intento de reincorporación. Este punto requiere diseño y control de consistencia con el modelo vigente.

La **no obligatoriedad del aviso de ausencia** y la **ausencia de penalización para el abonado al día** provienen de RN-025 y RN-024 aprobadas. El aviso automático de liberación se activa **cuando se informa y confirma la ausencia**; una falta de presentación no reportada no debe inferirse como aviso voluntario sin otra regla.

## 4. Cotejo con la línea base: diferencias explícitas

| Referencia | Texto/base anterior | Aclaración posterior | Tratamiento documental |
|---|---|---|---|
| **RN-001 / ADJ-03** | Control frente a capacidad de la unidad y vehículo asignado; no fija capacidad sin unidad. | Jerarquía capacidad real → planificada → 19 predeterminada. | Complemento funcional a revisar; no altera RN-001 de forma automática. |
| **RN-025 — posibilidad** | El lugar del pasajero que avisa "**podrá quedar temporalmente disponible**". | La liberación es **automática** una vez confirmada la ausencia. | **Diferencia normativa**: requiere decisión del equipo sobre ajuste de RN-025 y CU-008. |
| **RN-025 — destinatario** | Menciona "**un pasajero eventual**". | El cupo puede ser reservado también por otro abonado u otro pasajero elegible. | **Ampliación/precisión de alcance**: RN-025 no deberá interpretarse como exclusividad sin atender a la aclaración; cambio documental sujeto a aprobación. |
| **RN-025 — aviso previo** | El pasajero puede "**avisar previamente**" que no usará un viaje. | Admite ausencia **durante** el viaje, si todavía no abordó. | **Ambigüedad temporal**: verificar la redacción de la RN (¿previo a su abordaje o al inicio del viaje?). No resolver silenciosamente. |
| **Implementación de CU-002** | Solo `programado`; sin ambas capacidades devuelve `None`; ausencias no modifican cupos. | Se permite `en_curso` con parada pendiente; predeterminado 19; ausencia confirmada libera lugar. | **Diferencia entre código y negocio confirmado**: requiere aprobación y cambios coordinados, no corrección inmediata aislada. |

El Issue #28 permanece **abierto** hasta acordar la solución en las fuentes pertinentes y verificarla mediante pruebas; una aprobación del texto de análisis no cierra por sí misma el problema técnico.

## 5. Estructuras y restricciones vigentes relevantes (sin proponer alterarlas)

- `viaje`: `id_vehiculo` opcional, `capacidad_planificada` opcional; `estado` admite `programado`, `en_curso`, `finalizado`, `cancelado`; `fecha` y `horario`.
- `vehiculo`: `capacidad` mayor que cero.
- `reserva`: pasajero, viaje, recorrido, `orden_parada`, estado `provisional` / `consolidada` / `cancelada`; **UNIQUE (`id_pasajero`, `id_viaje`)** (`MR-R15`).
- `ausencia`: pasajero y viaje, **UNIQUE (`id_pasajero`, `id_viaje`)** (`MR-R25`); el DDL actual no guarda un estado de revocación.
- `abordaje`: registra pasajero y viaje; requiere respetar las condiciones de abordaje (RN-023).
- `posicion_gps`: guarda la última posición asociada al viaje; **no existe allí un historial de paradas alcanzadas**.
- `GET /servicios/disponibilidad`: devuelve `cupo_disponible` a **nivel de viaje**, sin parámetro de parada concreta; `ReservaCreate` sí incluye `orden_parada`.
- `services/disponibilidad.py`: cuenta `Reserva.estado == 'consolidada'`, sin excluir ausencias. RN-002 y la aclaración del Issue #33 siguen distinguiendo consolidación comercial de pago realizado.

**PENDIENTE DE DISEÑO:** el modelo actual y la API no describen explícitamente el estado «parada pendiente/alcanzada», el mecanismo de recuperar una ausencia ni el vínculo preciso entre ausencia y reserva al consultar cupos. Tampoco se debe introducir uno de estos atributos o una API adicional sin revisión del equipo.

## 6. Escenarios funcionales para la revisión y futuras pruebas

Los importes y cantidades ilustrativas no fijan tarifas ni unidades reales; donde un comportamiento aún no está decidido se marca **PENDIENTE**. Los escenarios `PT28` son propuestas de prueba, no casos de uso ni reglas nuevas.

| Prueba | Escenario | Resultado funcional esperado | Base |
|---|---|---|---|
| **PT28-01** | Viaje sin unidad, capacidad planificada 19 y 12 reservas consolidadas sin ausencia. | Se identifican **7** cupos disponibles. | AC28-01 / RN-001 |
| **PT28-02** | Viaje sin unidad ni capacidad planificada y sin reservas consolidadas. | Se utiliza capacidad de referencia **19**. | AC28-02 |
| **PT28-03** | Viaje sin unidad ni capacidad planificada y 19 reservas consolidadas que ocupan cupo. | No admite una vigésima reserva que requiera un cupo adicional. | AC28-02 / RN-001 |
| **PT28-04** | Viaje con unidad asignada de 24 lugares y capacidad planificada 19, sin reservas previas. | Capacidad aplicable **24**. | AC28-03 |
| **PT28-05** | Se intenta asignar una unidad cuya capacidad es inferior a los lugares ya comprometidos. | No se debe permitir sobrecapacidad; **respuesta técnica exacta PENDIENTE**. | RN-001 / AC28-01 |
| **PT28-06** | Viaje `programado`, el horario de salida ya pasó, pero todavía no inició; existe cupo. | Puede aceptarse reserva, sujetándose a las demás condiciones. | AC28-05 |
| **PT28-07** | Viaje `en_curso`, cupo disponible, parada de ascenso aún no alcanzada. | Puede aceptarse reserva si cumple condiciones comerciales. | AC28-04 |
| **PT28-08** | Viaje `en_curso` con cupo, pero parada de ascenso ya alcanzada. | No debe aceptarse el abordaje/reserva para esa parada. | AC28-04 |
| **PT28-09** | Un pasajero con reserva consolidada informa y confirma ausencia antes de iniciar el viaje. | Su lugar se libera para nueva reserva sin aprobación de personal. | AC28-06 |
| **PT28-10** | Otro abonado cumple condiciones y solicita el cupo liberado. | Puede obtenerlo; no queda limitado a pasajeros ocasionales. | AC28-07 |
| **PT28-11** | Un pasajero ocasional cumple condiciones y solicita el cupo liberado. | También puede obtenerlo. | AC28-07 |
| **PT28-12** | Pasajero ausente cambia de opinión y aún hay cupo. | Puede volver a solicitar lugar; forma de recuperar la reserva **PENDIENTE**. | AC28-08 |
| **PT28-13** | Pasajero ausente cambia de opinión, pero el último cupo fue reservado por otro pasajero. | No desplaza al nuevo pasajero; no recupera el lugar automáticamente. | AC28-08 |
| **PT28-14** | Pasajero aún no abordó; viaje `en_curso`; comunica ausencia. | Su cupo se libera automáticamente al confirmar aviso. | AC28-09 |
| **PT28-15** | Pasajero ya abordó; intenta informar ausencia para ese mismo viaje. | No se satisface la condición de AC28-09; rechazo/mensaje preciso **PENDIENTE**. | AC28-09 / RN-023 |
| **PT28-16** | Reserva `provisional` sin condiciones de consolidación cumplidas. | No debe contarse como lugar ocupado por una reserva consolidada, según RN-002 y aclaración del Issue #33. | RN-002 / Issue #33 |
| **PT28-17** | Dos pasajeros intentan tomar simultáneamente el último cupo liberado. | Nunca asignar más cupos que los permitidos; mecanismo transaccional **PENDIENTE**. | RN-001 / AC28-06 |
| **PT28-18** | Pasajero no se presenta sin informar ausencia. | No se presume aviso voluntario confirmado; los efectos operativos siguen RN-022 y RN-025. | RN-022 / RN-025 |

## 7. Pendientes y decisiones que corresponden al equipo

| ID | Estado | Pendiente concreto | Responsables de análisis técnico |
|---|---|---|---|
| **PV28-01** | **PENDIENTE DE VALIDACIÓN TÉCNICA** | Determinar con evidencia operativa cuáles paradas no han sido alcanzadas, especialmente con viaje `en_curso`. No asumir que la última posición GPS alcanza para probarlo; aclarar pérdida de conexión y cambios de recorrido. | Martín + Martiniano |
| **PV28-02** | **PENDIENTE DE VALIDACIÓN TÉCNICA** | Evitar la asignación de vehículo con capacidad incompatible; comportamiento ante conflicto o reducción posterior de capacidad. | Facundo + Martiniano + Martín |
| **PV28-03** | **PENDIENTE DE VALIDACIÓN TÉCNICA** | Coordinar registro de ausencia y cálculo de cupo para evitar doble contabilización o liberaciones repetidas. | Martín + Martiniano |
| **PV28-04** | **PENDIENTE DE VALIDACIÓN TÉCNICA / MR** | Recuperación de lugar luego de ausencia, preservando unicidad `reserva(id_pasajero,id_viaje)` y `ausencia(id_pasajero,id_viaje)`, sin cancelar silenciosamente la reserva ni inventar estados. | Martín (análisis/MR) + Martiniano |
| **PV28-05** | **PENDIENTE DE CONTROL DE CAMBIO** | Adecuar, si el equipo lo aprueba, redacción de RN-025 y especificación de CU-008 respecto de liberación automática, quién puede tomar el cupo y aviso durante viaje. | Martín + equipo |
| **PV28-06** | **PENDIENTE DE DISEÑO CONTRACTUAL** | Determinar si `GET /servicios/disponibilidad` puede expresar reservabilidad según `orden_parada` o si la validación detallada corresponde solo a CU-003; no crear parámetro o endpoint sin acuerdo. | Martiniano + Martín |
| **PV28-07** | **PENDIENTE DE DISEÑO** | Política y visibilidad de estados `finalizado`/`cancelado` y posibles cambios al viaje ya iniciado, cotejando CU-002/CU-003/CU-018. | Martín + Martiniano + Facundo |
| **PV28-08** | **PENDIENTE DE PRUEBAS** | Evitar carreras de reservas simultáneas, verificar reglas cuando hay ausencias, unidad asignada, cambios de estado o capacidad. | Martiniano + Facundo + Martín |
| **PV28-09** | **PENDIENTE DE TRAZABILIDAD** | Cotejar última versión íntegra aprobada de CU-002, CU-003 y CU-008, y el artefacto de ADJ-03 antes de iniciar cambios a la línea base. | Martín |
| **PV28-10** | **PENDIENTE DE ALCANCE PC2** | Si la solución completa de paradas efectivamente alcanzadas o la revocación de ausencias excede el PC2, delimitar demostración y extensión futura sin declarar como implementada una regla que aún no se puede garantizar. | Equipo |

**No generar automáticamente un requisito por cada pendiente:** priorizar una decisión trazable y coordinada con la especificación vigente, según la consigna docente y el reparto PC2.

## 8. Trazabilidad funcional y responsables

| Necesidad / fuente | Reglas existentes | CU / RF relacionados | Dato o interfaz técnica actual | Pruebas |
|---|---|---|---|---|
| Evitar sobreocupación al reservar sin unidad asignada | RN-001; ADJ-03 | CU-002, CU-003, RF-004 | `viaje.capacidad_planificada`, `vehiculo.capacidad`, `cupo_disponible` | PT28-01 a 05, 17 |
| Permitir reservas tardías operativamente posibles | RN-001, RN-002, RN-023 | CU-002, CU-003, CU-030 | `viaje.estado`, `horario`, `orden_parada`, `parada_recorrido`, `posicion_gps` | PT28-06 a 08 |
| Liberar un lugar comunicado como no utilizado | RN-024, RN-025 | CU-008, CU-002, CU-003 | `ausencia`, `reserva`, `services/disponibilidad.py` | PT28-09 a 11, 14, 18 |
| Respetar que el ausente no desplace al reemplazante | RN-001, RN-002, RN-025 | CU-003, CU-008 | Restricciones `UNIQUE` en `reserva` y `ausencia` | PT28-12, 13, 17 |
| No confundir reserva provisional con cupo consolidado | RN-002; aclaración Issue #33 | CU-003, CU-002 | `reserva.estado` | PT28-16 |

### Responsabilidades según `REPARTO-PC2.md`

- **Martiniano:** módulo de disponibilidad y reservas (CU-002/CU-003), coherencia del contrato OpenAPI y pruebas del servicio propio. No debe escribir directamente sobre tablas operativas de otro responsable.
- **Martín:** ejecución del viaje y registro de ausencias/abordajes; análisis de requisitos, modelo, trazabilidad y validación funcional de la solución de paradas pendientes.
- **Facundo:** creación y asignación de vehículos/viajes, validación de capacidad al asignar. Los cambios de estado de ejecución del viaje pertenecen a Martín según el reparto.
- **Los tres:** acordar cambios al contrato compartido, modelo, reglas y condiciones de integración antes de abrir una PR de código.

## 9. Recomendaciones de IA (NO aprobadas)

1. **PROPUESTA DE IA:** centralizar la selección de capacidad en una única función compartida por consulta y reserva: unidad asignada, si no capacidad planificada, si no 19. Verificar también al asignar un vehículo. La **jerarquía comercial** está confirmada; el diseño específico no.
2. **PROPUESTA DE IA:** calcular cupos de forma derivada a partir de reservas consolidadas que aún ocupen lugar, teniendo en cuenta ausencias válidas y abordajes existentes, con una regla de consistencia que impida liberar dos veces el mismo cupo. No asumir que una mera resta SQL agota todas las condiciones operativas.
3. **PROPUESTA DE IA:** para viajes `en_curso`, condicionar la confirmación de la reserva a la comprobación efectiva de la parada de ascenso pendiente. Mantener un comportamiento conservador si no puede saberse con seguridad, pendiente de aprobación.
4. **PROPUESTA DE IA:** separar el hecho de **informar ausencia** de **cancelar la reserva** y diseñar una reversión trazable; no añadir automáticamente columnas, estados ni endpoints sin revisar el Modelo Relacional y CU-008.

Estas son opciones de diseño, no hechos atribuidos a VanFull ni cambios aprobados para PC2.

## 10. Control de calidad y estado de validación

- [x] Se separaron confirmaciones directas de VanFull y propuestas de IA.
- [x] Se contrastó la interpretación de RN-001, RN-002 y RN-025 con el texto de RN v1.1.
- [x] Se identificaron las diferencias entre negocio confirmado y el código actual de disponibilidad.
- [x] Se preservaron los identificadores de RF, RN, CU y MR; las referencias nuevas son locales.
- [x] Se documentaron escenarios de prueba y trazabilidad.
- [x] Se respetó el reparto PC2 y no se inventaron endpoints ni campos.
- [x] **Aprobación funcional de Martín** otorgada el 18/10/2026 para consolidar la v0.2.
- [ ] Cotejo directo de la última especificación integral CU v1.3 y ADJ-03 antes de editar línea base.
- [ ] Revisión/decisión técnica del equipo para cambios a SQL, OpenAPI, servicios o RN.
- [ ] Pruebas automáticas, PR y CI para la eventual implementación.

## 11. Próximos pasos (posteriores a la aprobación funcional)

1. Incorporar **solo este documento v0.2** mediante rama y PR documental, con revisión de Martiniano y Facundo.
2. Cotejar la última versión íntegra aprobada de los CU y ADJ-03 antes de proponer cambios en los artefactos de la línea base.
3. Acordar y documentar las decisiones técnicas pendientes entre los responsables indicados; si requieren modificar RN, CU, DER/MR, SQL u OpenAPI, seguir el control de cambios vigente.
4. Mantener abierto el Issue #28 hasta resolver las decisiones técnicas, implementar y verificar los cambios que correspondan y ejecutar las pruebas.

---

**Control de versión:** v0.2, validada funcionalmente por Martín el 18/10/2026 sobre el contenido de la v0.1, **sin cambios sustantivos** en aclaraciones AC28 ni escenarios PT28. Las propuestas técnicas no están aprobadas; las ambigüedades residuales permanecen **PENDIENTES DE VALIDACIÓN**. No genera por sí sola un cambio de la línea base vigente.
