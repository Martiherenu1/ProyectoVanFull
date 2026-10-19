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
