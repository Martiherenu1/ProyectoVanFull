# VanFull — Aclaración funcional CU-009 / Issue #39

**Archivo:** `ACLARACION-FUNCIONAL-CU009-ISSUE39-v0.2-VALIDADA-ANALISIS.md`  
**Versión:** v0.2 — VALIDADA POR ANÁLISIS FUNCIONAL  
**Fecha del relevamiento:** 18/10/2026  
**Responsable del relevamiento:** Martín — área Chofer y Viaje en curso  
**Estado:** **APROBADO FUNCIONALMENTE POR MARTÍN** el 18/10/2026 sobre la v0.1; contenido consolidado como v0.2. **Pendientes** la revisión de la línea base v1.3, la validación técnica, la aprobación de eventuales cambios al contrato y la definición de alcance PC2.  
**Issue:** [#39 — CU-009 A1: ubicación desactualizada cuando el celular tiene el reloj atrasado](https://github.com/Martiherenu1/ProyectoVanFull/issues/39)  
**Relacionado:** [Issue #37](https://github.com/Martiherenu1/ProyectoVanFull/issues/37) y [PR #40](https://github.com/Martiherenu1/ProyectoVanFull/pull/40) (contrato integrado en `main`).

> **Control de autoridad.** Las respuestas obtenidas de VanFull describen comportamiento funcional deseado. No sustituyen automáticamente CU, RNF, OpenAPI, Modelo Relacional ni decisiones técnicas del equipo. Este documento no autoriza implementación ni ampliaciones de alcance por sí solo.

## Registro de aprobación funcional

- **Fecha:** 18/10/2026.
- **Quién aprueba:** Martín, responsable de relevamiento y validación de las respuestas funcionales obtenidas de VanFull.
- **Evidencia:** respuesta expresa «APROBADO EL DOCUMENTO» a la `v0.1-PARA-REVISION` en la conversación de seguimiento del Issue #39.
- **Contenido aprobado:** las siete decisiones VF-39-01 a VF-39-07 y su consolidación como aclaración funcional del Issue #39.
- **Límite de la aprobación:** los 14 escenarios, 5 brechas, 12 pendientes y 16 pruebas se mantienen como **instrumentos de análisis y PROPUESTA DE IA**, sujetos a revisión técnica y del equipo. No se considera aprobado ningún algoritmo, proveedor, campo de API, cambio de modelo, modificación de CU/RNF ni alcance adicional para PC2.
- **Estado de integración:** **documento local para incorporar mediante PR**, sin que esta aprobación implique merge ni cierre del Issue #39.

## 1. Objetivo y alcance

Analizar el comportamiento del seguimiento GPS (CU-009) cuando la hora del teléfono del chofer está atrasada respecto del servidor, cuando hay interrupciones de conectividad y cuando al reconectarse llegan posiciones acumuladas. Distinguir ubicación *actual*, *desactualizada* y *de antigüedad no verificable*, y registrar el tratamiento funcional deseado para las estimaciones de llegada (ETA).

**Dentro del alcance de este Issue:** aclaración funcional, análisis de consistencia con la línea base y el contrato, escenarios de prueba propuestos, identificación de decisiones técnicas y de posibles controles de cambio.

**Fuera del alcance de este documento:** modificar endpoints, esquemas, código, migraciones, RF/RN/RNF, integrar proveedores externos o afirmar que estas funciones ya están implementadas.

## 2. Fuentes y jerarquía

| Fuente | Estado | Evidencia y alcance |
|---|---|---|
| Consignas del PC2 y reparto acordado por el equipo | DEFINIDO POR EL EQUIPO, sujeto a consignas docentes | `Documentos/Sesiones/PC2/REPARTO-PC2.md`. Martín es responsable de ejecución del viaje y GPS. |
| Entrevista inicial VanFull del 25/08/2026 | CONFIRMADO POR VANFULL | Se desea seguimiento en tiempo real, ETA para pasajeros, visibilidad para administración y pasajeros autorizados; ante pérdida de conexión el chofer contacta por WhatsApp o llamada a la empresa. No especifica desfase de reloj ni tratamiento del ETA. |
| CU-009 de `03_Especificaciones_Casos_de_Uso_VanFull_v1.1_Aprobado_Equipo.md` | DEFINIDO POR EL EQUIPO — versión anterior localizada | Flujo A1: más de 30 s → no presentar como tiempo real, identificar como desactualizada. A2: pérdida de señal → conservar última posición y marcar desactualizada, retomar seguimiento al recuperar conectividad. A3: si no hay ETA válido, no inventarlo. **Debe cotejarse con CU v1.3 vigente antes de formalizar cambios.** |
| RNF-008 (referenciado por Issue #39, CU-009 y OpenAPI) | LÍNEA BASE DEL EQUIPO | Ubicación desactualizada cuando supera 30 s de antigüedad. No se propone cambiar el umbral. Verificar redacción exacta vigente de RNF-008 antes del cierre documental. |
| OpenAPI en `main`, incorporado por PR #40 | DEFINIDO POR EL EQUIPO — contrato técnico vigente | `backend/openapi/openapi.yaml`, `POST/GET /viajes/{id_viaje}/ubicacion` y esquemas `PosicionGpsCreate`, `ResultadoPosicionGps`, `Ubicacion`. |
| Modelo relacional / `backend/db/schema.sql` en `main` | DEFINIDO POR EL EQUIPO — diseño vigente | `posicion_gps`: una última posición por viaje (`id_viaje` PK), coordenadas y `fecha_hora_posicion`; sin historial. |
| Respuestas del relevamiento del 18/10/2026 (esta conversación) | **CONFIRMADO POR VANFULL** | Siete precisiones funcionales VF-39-01 a VF-39-07 que se presentan a continuación. |

**Pendiente documental imprescindible:** obtener y revisar CU-009 **v1.3** y el texto literal vigente de RNF-008. La v1.1 encontrada en Drive es una referencia auxiliar y **no reemplaza** la v1.3.

## 3. Comportamiento del contrato vigente (sin cambios)

1. Solo el chofer asignado puede enviar posiciones del viaje `en_curso`, según el contrato de CU-030.
2. La marca temporal del dispositivo es opcional. Si está ausente o es futura, se utiliza la hora del servidor; si es anterior, se conserva la informada.
3. Una posición reemplaza la última almacenada únicamente si su marca temporal efectiva es **estrictamente posterior** a la ya guardada. Si es igual o anterior, se ignora; el servidor conserva las coordenadas y hora anteriores.
4. La respuesta `200` del POST informa `actualizada` y `fecha_hora_posicion` de la posición que realmente queda almacenada.
5. Se guarda solo la última posición por viaje. No hay historial de ubicaciones en `posicion_gps`.
6. El GET entrega `id_viaje`, coordenadas, `fecha_hora_posicion`, `desactualizada` (booleano) y `eta_minutos` cuando está disponible. El contrato indica el umbral de 30 s y el objetivo de actualización de seguimiento de aproximadamente 10 s.
7. No están definidas por este contrato banderas de «antigüedad no verificable», una fuente de fecha de captura validada, estado de conectividad ni campos específicos de confiabilidad / antigüedad del ETA.

**Riesgo detectado, no falla comprobada:** una posición capturada recientemente puede llegar con marca temporal vieja porque el reloj del teléfono está atrasado; se puede clasificar como desactualizada o ignorarse al compararla con una posición posterior, aunque el equipo tenga conectividad.

## 4. Aclaraciones funcionales obtenidas de VanFull

Las siguientes respuestas fueron elegidas expresamente por VanFull durante la entrevista del 18/10/2026. Se registran como intención funcional, **no como implementación aprobada**.

| ID | Situación | Definición funcional confirmada | Estado de traducción técnica |
|---|---|---|---|
| **VF-39-01** | Reloj del celular atrasado; ubicación realmente reciente | Priorizar la ubicación reciente **si es posible comprobar su antigüedad real**, sin tratarla como vieja solo por el reloj incorrecto del dispositivo. Nunca hacer pasar posiciones antiguas por nuevas. | PENDIENTE DE VALIDACIÓN TÉCNICA. |
| **VF-39-02** | Se recibe una ubicación, pero no puede verificarse cuándo fueron obtenidas las coordenadas | Mostrar la ubicación recibida acompañada de una advertencia clara: **«No se puede verificar si esta ubicación está actualizada»**; no presentarla como tiempo real confirmado. | PENDIENTE: aceptación, almacenamiento y representación de estado no verificable. |
| **VF-39-03** | ETA disponible con ubicación de antigüedad no verificable | Puede mostrarse el ETA disponible, **advirtiendo que podría ser incorrecto**; si no hay ETA válido, no inventarlo (CU-009 A3). | PENDIENTE: procedencia, antigüedad y presentación del ETA. |
| **VF-39-04** | Pérdida de conexión, sin nuevas posiciones durante más de 30 s | Conservar y mostrar la última ubicación **como desactualizada**. Mantener el último ETA, si existe, **como desactualizado y potencialmente incorrecto**. | PENDIENTE: contrato y comportamiento visual. |
| **VF-39-05** | ETA previo de 8 minutos; pasan 3 minutos sin conexión | Mostrar **5 minutos** con advertencia de desactualización: decrementar el último tiempo estimado según el tiempo transcurrido, **sin presentarlo como recálculo con GPS nuevo**. | PENDIENTE: referencia temporal fiable y sincronización entre consultas. |
| **VF-39-06** | El último ETA llega a cero sin novedades | Mantener **0 minutos** (nunca negativo) y advertir que la llegada **está demorada o no pudo confirmarse**. No inferir la llegada real del vehículo ni cambiar el estado del viaje. | PENDIENTE: tratamiento de ETA agotado y mensaje. |
| **VF-39-07** | Reconexión; el celular transmite múltiples posiciones capturadas durante la desconexión | Priorizar la **más reciente cuya antigüedad pueda verificarse** y evitar reproducir secuencialmente puntos antiguos como si fueran el movimiento actual. Para ubicación no verificable, aplicar VF-39-02. | PENDIENTE: orden, filtrado, procedencia y consistencia. |

**Interpretación limitada:** «reciente comprobable» es una condición exigida por VanFull, pero **no implica** que baste con utilizar la hora de recepción del servidor. Recibir *ahora* un punto no prueba que haya sido capturado *ahora*. No se fija tolerancia adicional ni se aprueba un algoritmo de detección de desfases.

## 5. Escenarios y contraste con el contrato actual

Los tiempos son **ejemplos de análisis**, no nuevos límites ni pruebas ejecutadas. «Resultado con contrato actual» es una lectura de sus reglas, suponiendo un GET/POST implementado que las respete; no afirma funcionamiento actual del backend.

| Escenario | Entrada / contexto | Resultado conforme al contrato vigente | Comportamiento deseado de VanFull | Brecha |
|---|---|---|---|---|
| E01 — Normal | Servidor 10:00, posición capturada 09:59:55 con timestamp correcto; último punto anterior | POST puede actualizar si el timestamp es posterior al almacenado; GET no la marca vieja a 10:00 | Mostrar ubicación actual | Sin brecha funcional aparente. |
| E02 — Reloj atrasado sin registro previo | Servidor 10:00; punto realmente reciente con timestamp 09:58 | Puede almacenar hora 09:58 y GET marcar `desactualizada=true` | Si se comprueba captura reciente, mostrar actual | **Contradicción potencial entre comportamiento deseado y reglas de timestamp**. |
| E03 — Reloj atrasado con punto posterior almacenado | Ya se guardó punto 09:59:50; llega captura realmente nueva con timestamp 09:58 | Se ignora por no superar 09:59:50 | Priorizar reciente verificable | Requiere redefinir criterio de orden sin violar integridad. |
| E04 — Timestamp futuro | Servidor 10:00; teléfono informa 10:02 | El contrato usa hora del servidor | No definido un cambio; conservar criterio base hasta revisión | No modificar silenciosamente. |
| E05 — Timestamp ausente | Llega punto sin fecha | El contrato usa hora del servidor (aunque la captura pudiera ser antigua) | Si su antigüedad no puede verificarse, mostrar advertencia | **Riesgo:** hora de recepción no certifica hora de captura. |
| E06 — Captura realmente antigua, recepción reciente | Se envía a las 10:00 una ubicación capturada 09:50 | Se evalúa timestamp y puede ignorarse frente a una más nueva; o guardarse si no la había | No mostrar como confirmadamente actual; advertir o mostrar como antigua según lo verificable | Requiere distinguir captura y recepción. |
| E07 — Edad no verificable | Se reciben coordenadas pero no hay prueba confiable de antigüedad | `Ubicacion` solo tiene `desactualizada` booleano | Mostrar ubicación y advertencia explícita de no verificación | Falta representación inequívoca. |
| E08 — ETA con edad no verificable | Existe ETA previo; antigüedad GPS incierta | `eta_minutos` es entero o null; sin estado de confiabilidad | Mostrar estimación disponible y advertir posible error; no inventarla | Falta metadato/mecanismo de advertencia. |
| E09 — Caída >30 s | Última ubicación conocida y ETA existente; sin nuevos puntos | GET indica ubicación desactualizada si supera 30 s; no especifica congelamiento/actualización del ETA | Mantener posición y ETA con advertencias de desactualización | Comportamiento ETA no documentado. |
| E10 — Contador sin conexión | ETA inicial 8 min; pasan 3 min | Contrato no define descontar ETA en ausencia de puntos | 5 min estimados, advertidos como no actualizados | Falta tiempo de referencia y criterio de cómputo. |
| E11 — Contador agotado | ETA inicial 8 min; pasan 10 min sin conexión | Contrato no define límite inferior ni leyenda | 0 min y mensaje de llegada no confirmada o demorada; no finalizar viaje | Falta criterio de presentación. |
| E12 — Reconexión con cola | Llegan varios puntos acumulados con distintas marcas | POST procesa cada envío individual según timestamp estrictamente posterior; sin distinción explícita de replay visual | Priorizar último punto capturado recientemente que pueda verificarse; no mostrar secuencia como actual | Requiere política de cola y pruebas de orden de llegada. |
| E13 — Sin ETA disponible | Falta información necesaria para estimar | `eta_minutos=null` es posible; CU-009 A3 no permite inventar | No inventar ETA; mostrar ubicación según su calidad | Compatible. |
| E14 — Pérdida y recuperación de conexión | Se cortan posiciones, luego llegan válidas | CU-009 A2 en fuente v1.1 prevé reanudación; contrato define recepción POST | Recuperar seguimiento cuando llegan posiciones válidas | Verificar UX y consistencia con v1.3. |

## 6. Brechas y contradicciones a elevar al equipo

| Código | Elemento vigente | Definición nueva | Acción requerida |
|---|---|---|---|
| BR-39-01 | Fecha vieja del teléfono se conserva; nueva posición solo se guarda si su timestamp supera el almacenado | Priorizar capturas recientes comprobadas pese al reloj atrasado | Diseñar y validar una noción fiable de momento de captura/orden; determinar si implica cambio de contrato y control de cambios. |
| BR-39-02 | `GET Ubicacion.desactualizada` es booleano, derivado de >30 s | Existe un tercer estado funcional: antigüedad **no verificable** | Evaluar diseño de representación sin confundir «confirmadamente viejo» con «no verificable». |
| BR-39-03 | `eta_minutos` es entero o null; no hay fecha de cálculo ni marca de confiabilidad | ETA visible con advertencia, descuento por tiempo sin GPS y mínimo cero | Acordar dónde se calcula, conserva, advierte y sincroniza; verificar impacto en API, móvil/web y tests. |
| BR-39-04 | Solo última posición GPS por viaje; no hay historial | Reconexión con varios puntos acumulados: mostrar el más reciente verificable | Evaluar selección/descartes en cola sin crear historial no aprobado. |
| BR-39-05 | CU-009 A1/A2 de la v1.1 exige avisar posiciones viejas y pérdidas de señal; RNF-008 fija 30 s | Nueva decisión conserva umbral pero distingue posición no verificable | Contrastar literalmente CU v1.3 y RNF-008 antes de resolver si basta con aclaración o requiere modificación de línea base. |

**Regla de prioridad:** no elegir silenciosamente la nueva semántica sobre el contrato aprobado. Hasta resolver BR-39-01 y BR-39-02, el contrato en `main` conserva su vigencia técnica.

## 7. Pendientes de validación y responsabilidades

| ID | Tipo | Pendiente / pregunta de decisión | Responsable propuesto para revisión |
|---|---|---|---|
| PV-39-01 | Documental | Obtener y cotejar especificación **CU-009 v1.3** y texto completo vigente de RNF-008. | Martín / documentación del equipo |
| PV-39-02 | Técnico-funcional | ¿Qué evidencia permite asegurar que la captura es reciente, aun con reloj desfasado? ¿Qué hacer si no existe esa evidencia? | Martín + Martiniano (contrato) |
| PV-39-03 | Técnico | ¿Cómo distinguir momento de captura, envío y recepción sin confiar ingenuamente en el reloj del móvil? | Martín (GPS/backend) |
| PV-39-04 | Arquitectura/contrato | ¿Cómo representar «antigüedad no verificable»? ¿Cambiar `Ubicacion`, mantener compatibilidad o adoptar otra opción acordada? | Martín + Martiniano (OpenAPI) |
| PV-39-05 | Técnico | Política segura para aceptar/rechazar puntos retrasados y los que llegan fuera de orden, manteniendo una única posición por viaje. | Martín |
| PV-39-06 | Funcional/técnico | ¿Cómo distinguir pérdida de conectividad del móvil de falta de cobertura GPS, y cómo mostrar la causa si no se puede determinar? | Martín + equipo |
| PV-39-07 | Técnico/UX | Cómo conservar ETA, conocer el instante de cálculo, decrementar correctamente sin conectividad y volver a calcular tras reconexión. | Martín + frontend / equipo |
| PV-39-08 | Técnico/UX | Leyendas exactas para GPS incierto, ubicación antigua, ETA incierto, ETA obsoleto y contador en 0. | Equipo / frontend |
| PV-39-09 | Alcance PC2 | Qué parte de estas definiciones entra efectivamente al PC2 y qué se difiere, sin que la aprobación de VanFull amplíe automáticamente el alcance. | Tres integrantes |
| PV-39-10 | Control de cambios | Si la solución contradice reglas del contrato o línea base, acordar y documentar cambio antes de implementarlo. | Equipo, responsable de OpenAPI |
| PV-39-11 | Pruebas | Confirmar estrategia de simulación de reloj incorrecto, GPS offline, posiciones en cola, reconexión y ETA; ejecutar pruebas después de implementar. | Martín + equipo |
| PV-39-12 | Coordinación | Verificar impacto en CU-030 (envío GPS), CU-009 (consulta), PR #40 y `CONTEXTO-chofer-y-viaje.md`; no modificar CU-007/008 ni asignaciones de Facundo. | Martín |

**No se aprueban aquí:** umbrales de tolerancia de desfase adicionales, biometría, nuevos proveedores, acceso sin autorización, historización de GPS, almacenamiento de colas, campos específicos de API ni algoritmos propuestos por IA.

## 8. Escenarios de prueba propuestos (sin ejecución)

- **TP-39-01:** reloj correcto, captura reciente → coordenadas y marca temporal esperadas.
- **TP-39-02:** reloj retrasado dos minutos, captura reciente verificable → no tratar como punto antiguo por ese solo motivo (tras decisión técnica y cambio aprobado si aplica).
- **TP-39-03:** reloj retrasado, última posición guardada cronológicamente posterior a la marca del dispositivo → probar rechazo vigente vs. política validada.
- **TP-39-04:** reloj adelantado → aplicación exacta de la regla vigente de sustitución por hora del servidor.
- **TP-39-05:** omisión de timestamp → verificar que no se equipare automáticamente recepción con captura real sin evaluar PV-39-02.
- **TP-39-06:** punto verdaderamente antiguo recibido con conexión → no mostrar como ubicación confirmadamente actual.
- **TP-39-07:** antigüedad no comprobable → punto visible con advertencia; ETA, si lo hay, advertido.
- **TP-39-08:** 31 s sin nueva ubicación → última posición desactualizada conforme a RNF-008.
- **TP-39-09:** ETA 8 min y 3 min sin conexión → 5 min con advertencia y sin recálculo GPS fingido.
- **TP-39-10:** ETA 8 min y 10 min sin conexión → 0 min, sin negativo, sin declarar llegada ni finalizar viaje.
- **TP-39-11:** reconexión con posiciones capturadas en distintos momentos y enviadas en ráfaga → priorización de la última verificable, sin replay como actual.
- **TP-39-12:** posiciones recibidas fuera de orden → resultado determinista que respete la política finalmente acordada.
- **TP-39-13:** recuperación con datos nuevos confiables → advertencias se actualizan en función de la validez, ETA recalculado solo si existen datos para ello.
- **TP-39-14:** ETA no disponible → se muestra ubicación sin inventar duración.
- **TP-39-15:** usuario no autorizado solicita ubicación → no accede a los datos (RN-030).
- **TP-39-16:** chofer no asignado o viaje no `en_curso` intenta enviar GPS → se respetan permisos y estados del contrato vigente.

Estos escenarios son **PROPUESTA DE IA para trazabilidad y pruebas**, pendientes de revisión del equipo. Los valores de minutos en los ejemplos no sustituyen el umbral aprobado de RNF-008.

## 9. Trazabilidad

| Necesidad del negocio | Referencia | Comportamiento / decisión | API de diseño existente | Datos | Pruebas propuestas |
|---|---|---|---|---|---|
| Seguimiento confiable y no engañoso | CU-009 A1/A2, RNF-008 | VF-39-01, 02, 04, 07 | `GET /viajes/{id_viaje}/ubicacion`; `POST /viajes/{id_viaje}/ubicacion` | `posicion_gps` (última posición) | TP-39-01 a 08, 11 a 13 |
| Informar ETA útil sin fingir exactitud | CU-009 A3, RF-022 | VF-39-03, 04, 05, 06 | `GET /viajes/{id_viaje}/ubicacion` (`eta_minutos`) | Datos/instante de cálculo pendiente | TP-39-07, 09, 10, 13, 14 |
| Respetar permisos y ciclo del viaje | RN-030, CU-030, RF-021/025 | Sin cambio solicitado | GET/POST ubicación del viaje | `viaje`, asignación del chofer | TP-39-15, 16 |

Los enlaces trazables de UI y clases de servicio/backend quedan **pendientes**, porque el flujo del chofer todavía no está implementado y la solución final no está aprobada. No se inventan rutas adicionales.

## 10. Proceso de formalización

1. **Relevamiento funcional:** completado el 18/10/2026 (VF-39-01 a 07).
2. **Aprobación funcional de la v0.1 por Martín:** **COMPLETADA el 18/10/2026**. Martín confirmó expresamente «APROBADO EL DOCUMENTO», aprobando el documento integral de aclaración funcional. La aprobación no alcanza implementaciones técnicas, ampliaciones de alcance, modificaciones de línea base o pruebas que todavía no se ejecutaron.
3. **Verificación documental faltante:** cotejar CU v1.3 y RNF-008 literalmente, corregir cualquier conflicto.
4. **Validación técnica de las brechas:** Martín (GPS y viaje), Martiniano (contrato compartido) y, cuando afecte a la interfaz o integración, Facundo.
5. **Control de cambios, si corresponde:** tramitar modificación de contrato/línea base expresamente autorizada; no modificar silenciosamente lo integrado en PR #40.
6. **Formalización documental:** v0.2-VALIDADA-ANALISIS generada a partir de la v0.1 aprobada. Su incorporación mediante PR **documental** queda para un paso posterior; la PR no autoriza merge automático ni cambios en OpenAPI, SQL, requisitos o código.
7. **Implementación y pruebas:** issues/PR técnicos separados, con alcance PC2 expresamente acordado por el equipo.

---

**Estado final de esta versión:** **v0.2 VALIDADA POR ANÁLISIS FUNCIONAL**, basada en la aprobación expresa de Martín del 18/10/2026. Las siete definiciones funcionales siguen clasificadas como **CONFIRMADO POR VANFULL**; la traducción técnica, el contraste con CU-009 v1.3 y RNF-008 literal, y los eventuales controles de cambio siguen **PENDIENTES DE VALIDACIÓN**. No hay pruebas ejecutadas ni modificaciones de código, SQL, OpenAPI, RF, RN, RNF o CU.

---

## Revisión PC3 de RNF-008 y decisión pendiente #39 — 2026-11-10

**Estado:** recomendación para decidir con Martiniano y Facundo; sin implementación
productiva ni cambio contractual aplicado. Rama test/chofer-rnf008-pc3-39,
worktree F:/dev/vf-rnf008-pc3, base exacta origin/main
fa59928ee1dc4ce838f818397181bc6a817c31c1. #39 revalidado abierto, sin comentarios.
La aclaración #63/v0.2 sigue siendo antecedente funcional, no aprobación del algoritmo.

### Fuentes y separación respecto del PC2

Literal releído de
F:/TIN/One Drive/OneDrive/Escritorio/UM/TC/02 Alcance, RF, RNF y Reglas/02_Requisitos_No_Funcionales_VanFull_v1.0_Aprobado_Equipo.docx,
v1.0 aprobada 31/08/2026, SHA-256
8f386f3789afdf02f9d886894fb4b02c83ef7695c8b6b5669f29dcf1137f8004:

> Cuando la última posición disponible de un vehículo tenga una antigüedad superior a 30 segundos, el sistema deberá identificarla como información desactualizada y no presentarla como una posición actual en tiempo real.

El worktree F:/dev/vf-eta-rnf008-doc queda intacto en su HEAD histórico fb6e422,
con seis archivos locales, variante aplicada y resultados **130 aprobadas / 2 fallidas**.
No están integrados en main ni se trasladó esa variante a esta revisión.
Inventario y hashes: F:/dev/vf-rnf008-pc3-inventario-original.json.
APK ensayada: fuente 8217c9c, no recompilada ni intervenida. Merge GitHub no prueba
despliegue: SHA exacto del backend en Render sigue SIN VERIFICAR.

| Concepto | Qué significa / qué no permite concluir |
|---|---|
| Antigüedad contractual | Diferencia entre referencia del servidor y fecha_hora_posicion efectiva almacenada. No se modifica ese timestamp: el POST conserva anterior, sustituye futuro/ausente por hora servidor y actualiza solo si estrictamente posterior. |
| Edad física de captura | Tiempo desde que se obtuvieron realmente las coordenadas. El contrato actual no aporta evidencia verificable de ello. Recepción reciente o timestamp normalizado no prueban captura reciente. |
| Demora de respuesta | Tiempo entre evaluar la respuesta y entregarla/aplicarla. Un false correcto al evaluar puede haber envejecido al llegar; no es pérdida de conexión ni prueba de edad de captura. |
| Conexión perdida confirmada | Exige evidencia identificada y alcance (observador, API, teléfono del chofer). Posición antigua, falta de puntos o error GET no acreditan desconexión del chofer. El contrato GPS no expone ese estado. |

### Resultados nuevos sobre main, sin variante productiva

Solo se trasladaron bloques de tests, conservando aserciones y tags sin excluirlos.
backend/tests/test_gps.py completo: **7 aprobadas**, 16 advertencias preexistentes,
11,60 s, incluidas 29 s=false, exactamente 30 s=false y 31 s=true con reloj controlado.
PostgreSQL 16 efímero, sin red externa/puertos/volúmenes persistentes, ya retirado.
frontend/test/screens/gps/ubicacion_screen_test.dart completo: **2 aprobadas / 2 fallidas /
0 omitidas**. Fallan GET 29→31 s y envejecimiento durante GET pendiente por falta de
identificación explícita como desactualizada. Precondiciones y aserciones intactas.
Advertencia de tag pendiente-contrato-39 no declarado en dart_test.yaml; no se cambió
configuración ni se omitió caso alguno. No es suite completa ni cumplimiento RNF-008.
Ruff y formato del test Python correctos; formato Dart correcto. Análisis estático
focalizado: sin problemas (40,9 s). diff --check: correcto.
ETA fuera de alcance; no se modificaron servicios ni datos reales.

### Comparación y recomendación concreta

| Alternativa | Ventaja | Límite |
|---|---|---|
| Solo booleano actual | Informa la decisión del servidor al evaluar. | No indica el instante de evaluación ni envejece mientras un GET queda pendiente. |
| Solo reloj de pared del cliente | Ninguna autoridad temporal nueva. | Restarlo a fecha_hora_posicion presupone sincronización no demostrada; se descarta. |
| Solo tiempo monotónico desde recepción | Mide intervalos locales sin usar fecha de pared. | No conoce la edad al evaluar ni la demora previa; no llamar edad GPS a segundos desde recepción. |
| Metadato del servidor sin monotónico | Permite calcular edad contractual al evaluar, sin sincronizar el cliente. | Congela esa edad y no corrige por sí solo demora ni paso posterior del tiempo. |
| Metadato servidor + RTT y transcurrido monotónicos | Permite acotar edad contractual en la presentación bajo condiciones explícitas. | No determina demora unidireccional exacta, no prueba captura física y conserva una franja incierta alrededor de 30 s. |

**Recomendación:** acordar una extensión aditiva mínima del GET: una propiedad opcional
fecha_hora_evaluacion (UTC/date-time), calculada en el mismo instante S y sobre el mismo
snapshot que desactualizada, sin cambiar fecha_hora_posicion T. Servidor nuevo la emitiría
en cada 200 fresco; cliente nuevo admite que falte y entonces mantiene incertidumbre.
Solicitar generación fresca y Cache-Control: no-store; no usar un GET cacheado como
ancla nueva. La propuesta externa YAML/JSON es orientativa, NO aplicada.

Medir en cliente m0 antes de la solicitud y m1 al disponer de la respuesta completa,
con reloj monotónico, nunca DateTime.now. Definir r=m1−m0 y d=m_actual−m1.
Si S ocurrió dentro de esa solicitud fresca, la escala servidor es coherente y el
contador es válido para ese intervalo, A=S−T permite estimar el intervalo contractual:

```
edad mínima = A + d
edad máxima = A + r + d
```

Es una derivación de diseño, no evidencia medida ni fórmula ya implementada.
No sumar r/2 ni suponer red simétrica; r también incluye procesamiento y entrega.
Precisar resolución/error/drift y validez de los relojes antes de afirmar límites
físicos exactos; no se aprueba aquí una tolerancia. Rechazar el ancla si edad es negativa,
los metadatos son incoherentes, falta S, hay caché no controlada o se pierde continuidad
del contador. Para la misma posición y contexto, conservar la desactualización
acreditada por true del servidor o cota mínima válida >30 s: una respuesta repetida
o la pérdida posterior del ancla no la rejuvenece. Limpiar ese estado al cambiar
posición/contexto o perder acceso.
No reinventar llegada, timestamp ni política de recepción.

Ejemplo solicitado: evaluación con A=29 s, RTT=2 s y recepción con d=0 produce
intervalo [29,31] s. El sistema **no sabe** que la edad exacta sea 31 s; podría ser
menor si parte del RTT fue anterior a la evaluación. No se marca cumplimiento porque
se muestre incertidumbre. Tras d>1 s, la cota mínima supera 30 s y ya puede identificarse
contractualmente como desactualizada; a d=1 exacto la comparación sigue siendo estricta.

Propuesta de clasificación para coordinar:
- true del servidor o cota mínima >30 s: desactualizada conocida, sin borrar esa marca.
- cota máxima ≤30 s: dentro de ventana contractual bajo las hipótesis verificadas;
  nunca equivalente a edad física de captura comprobada.
- intervalo que cruza 30 s o sin ancla válida: vigencia incierta; no presentar como actual
  ni mostrar segundos exactos. Sigue siendo una brecha de precisión respecto de una
  clasificación exacta al cruzar el umbral, no una aprobación de RNF-008.
- Si el equipo prefiere tratar toda posibilidad de >30 s como expirada por precaución,
  acordarlo explícitamente, diferenciando esa decisión de una edad conocida; habrá
  falsos positivos. No cambia el umbral ni se aplica aquí.

Sin caché y una evaluación coherente son condiciones de la propuesta, no hechos
verificados en Render. Date/Age HTTP genéricos no certifican que la fecha corresponda
al mismo cálculo; no los adoptar como ancla implícita. [RFC 9111, edad y no-store](https://www.rfc-editor.org/rfc/rfc9111.html).
Dart ofrece Stopwatch para tiempo transcurrido, pero debe validarse la continuidad
del contador en cada plataforma y suspensión. Android elapsedRealtime incluye sueño;
no extrapolarlo sin prueba al Stopwatch Flutter/Web. Al perder el ancla tras reinicio,
suspensión no cubierta, volver a incertidumbre y consultar fresco solo si no hay
desactualización ya acreditada para la misma posición y contexto; conservarla si
la hay. Un cambio de posición/contexto o pérdida de acceso limpia ese estado.
[Stopwatch](https://api.dart.dev/dart-core/Stopwatch-class.html),
[SystemClock](https://developer.android.com/reference/android/os/SystemClock).

### Compatibilidad, archivos futuros y aceptación

Clientes Flutter actuales ignoran propiedades adicionales al parsear UbicacionViaje;
conservarían comportamiento anterior y no obtendrían esta mejora por recibir S.
Revisar consumidores estrictos. Campo opcional permite cliente nuevo con backend
anterior: sin metadato no debe inventar un ancla. No cambiar required ni estructuras
anteriores. Actualizar YAML y JSON equivalentes solo después del acuerdo.

Archivos futuros (NO modificados en esta entrega):
- backend/openapi/openapi.yaml y openapi.json: propiedad aditiva y respuesta no-store.
- backend/app/schemas/gps.py: propiedad de respuesta, sin columna nueva.
- backend/app/services/gps.py: capturar una sola evaluación S para bool y metadato;
  no tocar enviar ni timestamps almacenados.
- backend/app/routers/gps.py: header de respuesta GET; revisar caché en despliegue
  separadamente, sin ejecutarlo ahora.
- frontend/lib/models/gps/ubicacion_viaje.dart y services/gps/ubicacion_api.dart:
  parseo compatible y medición monotónica ligada a la solicitud/contexto.
- frontend/lib/screens/gps/ubicacion_screen.dart: presentar estado con procedencia,
  reevaluar sin depender de completar otro GET y descartar callbacks antiguos.
- Los tests GPS existentes de servicio/API/pantalla/mapa/composición.

Aceptación propuesta, sin implementar:
1. Mismo S calcula flag y metadato; frontera 29/30/31 exacta, sin cambiar T ni POST.
2. Clientes viejos aceptan campo extra; nuevo con campo ausente/malformado retrocede
   a incertidumbre, conservando true recibido.
3. A=29, r=2: intervalo [29,31] incierto al recibir; no afirmar exactamente 31 ni verde.
   Con d=2, [31,33] desactualizado conocido; exactamente 30 no se fuerza por ≥.
4. GET posterior pendiente: contador continúa; conserva posición/fecha y cambia
   presentación cuando la cota fiable supera 30 s; cero GET/envíos solapados.
5. Latencia asimétrica y procesamiento: no usar mitad del RTT ni recepción como captura.
6. Reloj cliente muy adelantado/atrasado: no afecta el cálculo. Caché, salto de reloj
   servidor detectable, ancla incoherente o suspensión no cubierta invalidan referencia.
7. Cambio viaje/sesión/acceso y callbacks tardíos no restauran anclas/datos anteriores.
8. Edad contractual vieja por reloj del chofer atrasado sigue vieja con política actual:
   este metadato NO resuelve VF-39-01 (captura reciente verificable) ni justifica aceptar
   puntos hoy descartados. Esa parte de #39 requiere otra decisión, fuera de esta etapa.

**Para decidir:** Martiniano valida contrato/snapshot/compatibilidad; Facundo valida
estados visuales y límites de incertidumbre; Martín mantiene trazabilidad RNF-008/#39.
Recomendar la pareja metadato+monotónico con cotas, sin prometer exactitud inexistente.
Acordar la franja incierta y el alcance de verificación física antes de implementar.
#39 permanece abierto. La mejora de presentación con el contrato actual (true persistente,
incertidumbre y consulta pendiente) puede revisarse por separado, pero no acredita el umbral.

---

## Textos de pantalla y registro propuesto en #39 — 2026-11-11

### Procedencia y alcance de la conformidad informada

Martín informa conformidad de Martiniano con fecha_hora_evaluacion opcional,
**condicionada a PR contractual con aviso, registro en #39 y revisión del texto de
pantalla antes del merge**. No se atribuye aprobación de los tres integrantes ni
de toda la solución temporal, política de caché o algoritmo por esa conformidad.
No acredita cumplimiento completo de RNF-008. Esta adición prepara revisión;
no aplica contrato/código, no publica comentario ni autoriza merge.

### Propuesta breve de pantalla (pendiente de revisión)

| Condición y precedencia | Texto principal | Aclaración |
|---|---|---|
| true del servidor, o referencia válida con cota mínima >30 s | **Información desactualizada** | Conservar procedencia en el estado interno. Para la misma posición y contexto, conservar true o una cota mínima válida >30 s ya acreditados, incluso ante respuesta repetida o pérdida posterior del ancla. |
| Referencia válida con mínima ≤30 s y máxima >30 s | **Vigencia no confirmada** | Puede haber superado el umbral; no presentarla como actual. No afirmar edad exacta. |
| Sin referencia válida, sin desactualización previamente acreditada | **Antigüedad no verificable** | No se puede establecer su vigencia contractual; no sustituir por reloj del cliente. |
| Referencia válida, intervalo no negativo íntegramente ≤30 s | **Dentro de la ventana de vigencia contractual** | Solo describe vigencia contractual bajo las condiciones del cálculo, no captura física reciente. |

Aviso complementario común: **«No se pudo verificar cuándo se capturó esta ubicación»**.
La fecha, si se muestra, sigue identificada como informada de la posición: no se
convierte en hora de recepción o evaluación. Sin referencia temporal fiable no
mostrar «hace N segundos» ni otros segundos exactos. Tampoco presentar un intervalo
como una única edad exacta cuando exista incertidumbre.

Ejemplos internos para revisión, **no mediciones ni textos numéricos obligatorios
de la pantalla**:
- Servidor true, incluso sin metadato válido: «Información desactualizada».
- Intervalo [31,33] s: «Información desactualizada»; la cota mínima supera 30 s.
- Intervalo [29,31] s: «Vigencia no confirmada»; no afirmar «31 segundos».
- Referencia ausente/incoherente, sin desactualización previamente acreditada: «Antigüedad no verificable».
- Misma posición/contexto con true previo o cota mínima válida >30 s ya acreditada:
  «Información desactualizada», aunque se repita la respuesta o luego se pierda el ancla.
- Intervalo [28,30] s o [30,30] s: «Dentro de la ventana de vigencia contractual», con el
  aviso de captura no verificada. Se conserva **>30 s estricto**, no ≥30 s.

**Consulta, conectividad y ausencia de datos se separan del estado de posición:**
- GET pendiente: «Actualizando ubicación…» con indicador, sin renovar coordenadas,
  timestamp o vigencia por el solo hecho de consultar.
- Error de consulta: «No se pudo actualizar la ubicación». Mantener aparte el estado
  de la última posición; el error no acredita pérdida de conexión del chofer.
- No se propone «Chofer desconectado» sin una fuente confirmada y acordada que
  permita saberlo. Una posición antigua o falta de puntos no bastan.
- Sin posición disponible: «Todavía no hay una posición disponible». No inferir causa.
- Sin acceso, sesión inválida o viaje cerrado: retirar mapa, coordenadas y avisos
  de posición; no conservar estados de la posición anterior como datos accesibles.

La franja incierta sigue siendo incierta: estos textos no se presentan como prueba
de cumplimiento del umbral ni solución completa de RNF-008. Las dos regresiones
originales permanecen con sus aserciones y sus resultados en rojo; esta propuesta
no las sustituye ni las convierte en casos aprobados. No se ejecutan pruebas nuevas.

### Comentario propuesto para #39 (BORRADOR NO PUBLICADO)

### RNF-008 / #39 — conformidad condicionada y textos propuestos

Martín informa conformidad de Martiniano con `fecha_hora_evaluacion` opcional,
condicionada a PR contractual con aviso, registro en #39 y revisión del texto de
pantalla antes del merge. Es una conformidad informada y acotada: no constituye
aprobación de los tres, autorización de implementación/merge ni cumplimiento
completo de RNF-008.

Se propone distinguir:
- **Información desactualizada**: true del servidor o cota mínima contractual >30 s.
- **Vigencia no confirmada**: intervalo válido cuya cota mínima es ≤30 s y máxima >30 s.
- **Antigüedad no verificable**: falta referencia válida, salvo desactualización ya acreditada para la misma posición y contexto.
- **Dentro de la ventana de vigencia contractual**: intervalo válido íntegramente ≤30 s.
  Este texto no certifica captura física reciente; se acompaña de
  «No se pudo verificar cuándo se capturó esta ubicación».

Para la misma posición y contexto, se conserva la desactualización ya acreditada
por true del servidor o por una cota mínima válida >30 s. Una respuesta repetida
o la pérdida posterior del ancla no la rejuvenece. Ese estado se limpia al cambiar
de posición/contexto o perder acceso.

El umbral sigue siendo estrictamente >30 s: exactamente 30 s no fuerza
desactualización. [29,31] es un ejemplo de intervalo incierto, no una edad exacta
medida. No se mostrarán segundos exactos sin una referencia que los justifique.

Los errores de consulta se presentan aparte («No se pudo actualizar la ubicación»).
No se infiere desconexión del chofer por posición antigua, falta de puntos o fallo
del GET. Sin posición disponible se informa esa ausencia; pérdida de acceso/cierre
retira mapa, coordenadas y avisos de posición.

Las dos regresiones originales se conservan fallidas, sin cambiar sus aserciones
ni omitirlas. El histórico 130 aprobadas/2 fallidas de F:\dev\vf-eta-rnf008-doc
se conserva separado de los resultados nuevos de esta revisión aislada, cuya base
es fa59928ee1dc4ce838f818397181bc6a817c31c1: 7 pruebas backend aprobadas y
2 Flutter aprobadas/2 fallidas. Estos resultados nuevos no se atribuyen a main
sin los tests locales trasladados.
#39 sigue abierto; quedan por acordar la referencia temporal y los textos, y por
resolver la antigüedad física no verificable. No hay contrato/código aplicado en
esta revisión ni despliegue verificado. Un merge en GitHub no acredita Render.

---

## Identidad, regresiones y PR contractual propuesta — revisión 2026-11-11

### Fuentes, bases y conformidades informadas

Main verificado en GitHub y mediante ls-remote:
**c9ac094299a93a52cae6245ea0093aaf964196a2** (merge documental #268).
Es el SHA de referencia de esta revisión y del parche contractual candidato.
Respecto de fa59928ee1dc4ce838f818397181bc6a817c31c1, solo cambian cuatro documentos
de CU-007; contrato GPS, modelo, servicios, parser e instrucciones aplicables no cambian.
El worktree conserva HEAD fa59928ee1dc4ce838f818397181bc6a817c31c1 y sus cambios:
no hubo integración, fetch ni traslado de resultados a main.
#39 verificado abierto y con cero comentarios; sus criterios siguen sin cerrar.

Martín informa que Facundo está conforme con avanzar con la PR contractual,
la clasificación y conservar la desactualización acreditada para una misma posición.
Pide precisar identidad y regresiones, en especial [29,31]. No aprueba implementación,
merge ni cumplimiento completo. Se mantiene la conformidad informada de Martiniano
con fecha_hora_evaluacion opcional, condicionada a PR contractual con aviso, registro
en #39 y revisión de pantalla antes del merge. No se atribuye aprobación conjunta
de los tres ni se considera publicado este registro.

### Identidad local candidata: posición aceptada y contexto de acceso

Propuesta técnica, sin campo nuevo ni cambio del modelo:
- Contexto C: viaje solicitado + generación opaca de sesión/acceso + fuente de consulta
  e instancia/generación de seguimiento. Nunca token, coordenadas o identidad personal
  como key visible o log. Cambiar cuenta, viaje, fuente, contexto o perder acceso invalida
  solicitudes, anclas y marca; una nueva sesión no hereda datos del acceso anterior.
- Posición P dentro de C: (id_viaje, fecha_hora_posicion contractual, latitud, longitud).
  Timestamp comparado como instante UTC, sin truncarlo; coordenadas finitas comparadas
  como valores numéricos devueltos por el contrato, sin tolerancia espacial ni redondeo
  inventados. No usar el texto JSON como identidad (1 y 1.0 representan el mismo valor).
- El contrato Ubicacion devuelve esos cuatro datos; schema.sql y models/viajes.py
  conservan una fila por id_viaje, coordenadas NUMERIC(9,6) y TIMESTAMPTZ. No hay ID de
  muestra ni historial. El servicio solo acepta timestamps efectivos estrictamente
  posteriores. Por eso timestamp y coordenadas distinguen la representación almacenada,
  no una captura física única, un envío intentado ni movimiento verificado.
- No usar solo coordenadas: el vehículo detenido con timestamp posterior es P nueva.
  Repetir el mismo P es la misma posición aunque cambie S o desactualizada.
  Timestamps iguales con coordenadas distintas contradicen la actualización normal:
  tratar como incoherencia a revisar, sin limpiar la marca ni aceptar un reemplazo
  silencioso. La precisión del parser/serialización y posibles restauraciones de datos
  limitan esta identidad; no se promete reconocer capturas descartadas o una restauración.

Orden y conservación propuestos:
1. Descartar primero respuestas/callbacks de otra generación, fuente o acceso, viaje
   distinto y solicitudes superadas. Una respuesta descartada no altera P, ancla o avisos.
   Mantener consultas sin solapamiento y guardas existentes; no inferir orden de llegada.
2. Dentro de C, una respuesta con T anterior al P ya aceptado no lo reemplaza ni limpia
   su estado. Igual T y mismas coordenadas es respuesta repetida. T posterior válido
   acepta P nueva y limpia la marca/ancla de la anterior antes de clasificar la nueva.
3. Para el mismo P y C, conservar «Información desactualizada» acreditada por true
   del servidor o cota mínima válida >30 s. False repetido, S más reciente o pérdida
   posterior del ancla no rejuvenecen P. Guardar procedencia en memoria; sin persistencia
   nueva, historial ni transferencia entre contextos. La pérdida del ancla impide cálculos
   nuevos, pero no revoca una conclusión ya acreditada bajo condiciones válidas.
4. Limpiar al aceptar una posición nueva, cambiar contexto o perder acceso; cierre,
   sesión inválida y retiro de datos limpian mapa, coordenadas, marca y avisos.
   Un GET fallido no prueba pérdida de acceso ni desconexión del chofer: conserva
   la última P accesible y separa error de consulta y clasificación temporal.
5. Las hipótesis de reloj servidor coherente y continuidad monotónica deben validarse.
   Si se detecta incoherencia que cuestiona una cota previa, no declararla fiable:
   requiere decisión explícita de integridad/contexto, no rejuvenecimiento silencioso.

### Contrato mínimo propuesto, todavía no aplicado

Solo backend/openapi/openapi.yaml y su JSON equivalente en el parche externo:
fecha_hora_evaluacion opcional date-time UTC, no nullable y no agregada a required.
El servidor nuevo la emitiría en cada 200 fresco, con S tomado una sola vez sobre
el mismo snapshot de P/T usado para desactualizada: true si y solo si S-T >30 s.
Exactamente 30 s sigue false. No cambia T ni la política POST, permisos o modelo.
S no es captura ni llegada del GET al cliente; false solo describe la evaluación S.

Se propone Cache-Control: no-store y generación fresca por solicitud. El cliente
no trataría una respuesta cacheada/reutilizada como ancla nueva. Verificar intermediarios,
service worker, reloj servidor y transporte es pendiente; el header por sí solo
no prueba frescura ni sincronía. Medir RTT y transcurrido con monotónico válido:
[A+d,A+r+d], A=S-T. Sin r/2, reloj de pared cliente como autoridad ni demora exacta.
Si falta S, es inválido, negativo/incoherente o no hay garantías para el ancla:
«Antigüedad no verificable», excepto desactualización ya acreditada para P/C.
No convertir false sin referencia en vigencia acreditada.

Compatibilidad: clientes actuales toleran propiedades JSON extra (parser cotejado);
los nuevos deben funcionar sin S con incertidumbre, manteniendo true.
No se exige actualizar el modelo ni alterar required. Revisar consumidores estrictos.
La PR contractual definiría comportamiento objetivo, sin declarar que el backend
ya emite S/no-store: implementación, pruebas y despliegue separados y posteriores.
Los textos permanecen: «Información desactualizada», «Vigencia no confirmada»,
«Antigüedad no verificable» y «Dentro de la ventana de vigencia contractual».
El último texto no certifica captura física reciente.

### Regresiones originales: conservar sin reescribir para obtener verde

Histórico F:/dev/vf-eta-rnf008-doc: 130 aprobadas / 2 fallidas con variante local.
Revisión aislada sobre fa59928ee1dc4ce838f818397181bc6a817c31c1 más tests trasladados:
7 backend aprobadas; 2 Flutter aprobadas / 2 fallidas / 0 omitidas.
No son resultados nuevos de c9ac094 ni de esta propuesta. Hoy no se ejecutaron pruebas.

- GET calculado a 29 y recibido a 31: la regresión original conoce una sola línea
  temporal de prueba y exige «Información desactualizada». Se conserva íntegra y roja.
  El diseño con metadato+RTT observa [29,31]: no prueba edad conocida estrictamente >30.
  Su aceptación futura debe exigir «Vigencia no confirmada», en un test separado;
  eso no satisface ni sustituye la aserción original. La brecha sigue registrada en #39.
- Envejecimiento mientras otro GET queda pendiente: se conserva íntegra y roja.
  Futuro caso separado: con A=29 y ancla válida, al transcurrir d=2 la cota mínima
  es 31 y se exige «Información desactualizada» sin esperar al GET. Al d=1 la mínima
  es 30 y no basta para acreditar >30; debe considerarse también la cota máxima.
- Si se pretende cerrar las regresiones originales, hace falta decidir explícitamente
  la brecha y su trazabilidad, o aportar observabilidad suficiente; no cambiar expectativas,
  agregar skips, excluir tags o llamar cumplimiento a la incertidumbre.

### Matriz futura de aceptación (propuesta; no ejecutada)

| Caso | Resultado esperado del diseño | Relación con evidencia |
|---|---|---|
| Backend S-T =29/30/31 s | false / false / true, mismo S/P/T en bool y metadato | Frontera existente aprobada; metadato nuevo pendiente |
| S ausente, inválido o ancla no fiable, sin marca previa | Antigüedad no verificable; sin segundos exactos ni autoridad del reloj cliente | Caso nuevo, no arregla originales |
| A=29,r=2,d=0: [29,31] | Vigencia no confirmada; no afirmar >30 conocido | Aceptación separada; original GET 29→31 sigue roja |
| A=29,r=2,d=2: [31,33], GET siguiente pendiente | Información desactualizada por cota mínima válida; no congelar presentación | Aceptación futura; original pendiente sigue roja hoy |
| [28,30] o [30,30] | Dentro de la ventana de vigencia contractual; captura física no verificada | Exactamente 30 no fuerza desactualización |
| Mismo P/C: true o mínima válida >30 ya acreditados; luego false repetido/ancla perdida | Conservar Información desactualizada y procedencia | Prueba nueva de identidad y monotonía de la clasificación |
| Vehículo detenido, coordenadas iguales y T posterior | P nueva; limpiar estado anterior y clasificar esta P | No deduplicar solo por coordenadas |
| T anterior o callback de contexto anterior | Descartar antes de cualquier efecto; no reponer ni limpiar datos actuales | Probar respuesta fuera de orden y cambio de cuenta/viaje/fuente |
| Igual T y coordenadas diferentes | Incoherencia; no reemplazar silenciosamente ni limpiar marca acreditada | Política candidata para revisión |
| Pérdida acceso/cierre | Retirar P, mapa, ancla y advertencias; tardías no restauran | No equivale a error GET transitorio |
| Error GET/posición antigua/sin posición | Estados separados; no afirmar chofer desconectado | El contrato no observa esa conexión |
| Cliente viejo / backend viejo | Extra ignorado / ausencia tolerada con incertidumbre | Probar compatibilidad sin nueva autoridad temporal |

### Decisiones y siguiente paso de revisión

Acordar identidad P/C, orden/anomalías, garantías de S/no-store/monotónico, textos
y tratamiento explícito de las regresiones originales; revisar con Martiniano y Facundo
antes de implementar. La opcionalidad mantiene interoperabilidad, no elimina las brechas.
No hay aprobación de implementación/merge ni cumplimiento completo de RNF-008.
#39 permanece abierto; ETA fuera de alcance. SHA Render sin verificar: merge no acredita
despliegue. Conservados documentos, ensayos, APK 8217c9c y resultados originales.

### Artefactos y validación de esta revisión (sin pruebas funcionales)

- Parche externo: F:/dev/vf-rnf008-pc3-contrato-propuesto.diff. Solo YAML/JSON
  candidatos, no aplicados; incluye S opcional y no-store, no cambio de POST/modelo.
- Borrador vigente #39: F:/dev/vf-rnf008-pc3-comentario39-borrador.md; reemplaza
  únicamente para futura publicación al borrador anterior conservado en este documento.
- Descripción propuesta de PR, con plantilla del repositorio:
  F:/dev/vf-rnf008-pc3-pr-contractual-borrador.md. Referencia #39 sin cerrarlo.
- Parseo YAML con yaml 3.1.4 ya disponible en el entorno Flutter y JSON estándar:
  correctos; comparación recursiva semántica: equivalentes. Campo date-time opcional
  y no nullable comprobado. No instalación ni resolución de dependencias.
- git apply --check del candidato: correcto, sin aplicar. Los dos archivos base son
  idénticos byte a byte en fa59928 y c9ac094, por lo que la comprobación corresponde
  también al contenido de main revisado. git diff --check: correcto.
- No se ejecutó validador integral OpenAPI ni suites nuevas; parseo/equivalencia
  y aplicabilidad no acreditan implementación, cumplimiento ni comportamiento real.
- Pruebas, código, contrato versionado y modelo conservan sus bytes anteriores.
  Copia de artefactos previos y hashes externos preservados; sin publicaciones.

---

## Rama contractual limpia para revisión — 2026-11-11

**Estado vigente de esta rama:** docs/chofer-contrato-rnf008-39,
F:/dev/vf-rnf008-contrato, creada desde origin/main actualizado
c9ac094299a93a52cae6245ea0093aaf964196a2. Candidato revisado aplicado localmente
solo en openapi.yaml y JSON equivalente; sin backend productivo ni Flutter.
El contrato GPS de esta base coincide con el del candidato: no hubo adaptación
semántica. Los estados anteriores «no aplicado» describen la preparación externa
y se conservan como historial, no como estado actual de esta rama.

Se incorpora el análisis previo como documentación, sin sus archivos de pruebas
ni la variante productiva. Los worktrees de diagnóstico y la APK permanecen
intactos. Las dos regresiones no pasan a verde por separarlas de esta rama:
histórico 130/2 en F:/dev/vf-eta-rnf008-doc y revisión fa59928 más tests locales
(7 backend aprobadas; 2 Flutter aprobadas/2 fallidas/0 omitidas) conservan procedencia.
No son pruebas de esta rama ni del contrato nuevo.

Propuesta conservada: identidad P=(viaje,T contractual,coordenadas), dentro de
contexto opaco de acceso/sesión/fuente; posición repetida o pérdida de ancla no
rejuvenece una marca acreditada por true o mínima válida >30 s. P nueva/contexto
nuevo o pérdida de acceso limpia estado. No solo coordenadas; detenido con T nuevo
es nueva P. Descartar respuestas anteriores antes de efectos. Igual T/coordenadas
distintas y garantías de relojes siguen como propuestas técnicas para revisión.

fecha_hora_evaluacion es opcional y no nullable, del mismo snapshot e instante S
que calcula desactualizada=(S-T >30 s). Exactamente 30 no fuerza true.
Respuesta fresca/no-store; sin referencia válida, incertidumbre salvo marca ya
acreditada. No cambiar recepción GPS, T almacenado, permisos, modelo ni captura.
Servidor actual aún no emite S/no-store: este contrato no acredita implementación.

Se conservan los textos revisados y la franja [29,31] como Vigencia no confirmada.
Su futura aceptación es separada de la regresión original que exige desactualizada;
no se modifican aserciones ni se declara resuelta la brecha. Antigüedad contractual,
física, error GET y conexión confirmada permanecen separados.

Conformidades informadas por Martín: Martiniano condicionado a PR contractual con
aviso, registro en #39 y revisión de pantalla antes del merge; Facundo conforme con
avanzar PR/clasificación/conservación, pidiendo identidad y regresiones precisadas.
No aprobación de implementación, merge, cumplimiento completo ni conformidad
conjunta atribuida a los tres. #39 permanece abierto; ETA fuera de alcance.
Borradores locales de PR y comentario #39 externos; sin publicación ni despliegue.
Validaciones nuevas se registran debajo, separadas de las regresiones funcionales.

### Validación efectiva de la rama contractual — 2026-11-11

- pytest -q -p no:cacheprovider tests/test_contrato.py tests/test_rutas_contrato.py:
  **5 aprobadas en 4,82 s** sobre JSON regenerado final. Incluye validación integral
  OpenAPI YAML/JSON con openapi-spec-validator, equivalencia y rutas frente al contrato.
  Ejecución previa al regenerado: 5 aprobadas en 16,39 s; no son suites distintas.
- JSON regenerado desde YAML según README; semántica idéntica al candidato.
  Solo se normalizó el orden de miembros del objeto de respuesta JSON al orden YAML.
  Una comprobación inicial de igualdad byte a byte detectó ese orden, no una diferencia
  contractual. La equivalencia semántica y los controles sobre el resultado aprobaron.
- ruff check --no-cache .: aprobado; ruff format --check --no-cache .:
  119 archivos ya formateados. Intento inicial bloqueado por caché en montaje de
  solo lectura; repetido sin caché, sin cambiar archivos ni controles.
- git diff --check: limpio. Solo dos archivos OpenAPI y tres documentos.
- Imagen local existente proyectovanfull-backend:latest; contenedores efímeros
  con --network none, montaje de solo lectura y sin base. Sin instalaciones ni
  descarga de imágenes; no se arrancó servidor ni se ejecutaron operaciones reales.

Son resultados contractuales, no suite backend completa, pruebas GPS/Flutter,
CI remota o cumplimiento de RNF-008. Regresiones originales no reejecutadas,
no trasladadas y no resueltas. La documentación previa de preparativos y sus
resultados permanece histórica. SHA Render continúa sin verificar.
