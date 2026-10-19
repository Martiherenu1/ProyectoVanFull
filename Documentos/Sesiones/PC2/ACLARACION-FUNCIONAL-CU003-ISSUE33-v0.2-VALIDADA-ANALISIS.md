# VanFull — Aclaración funcional de consolidación de cupos y servicios

**Versión del documento:** 0.2 — VALIDADA FUNCIONALMENTE POR EL RESPONSABLE DE ANÁLISIS  
**Fecha de relevamiento de las aclaraciones:** 17/10/2026  
**Fecha de aprobación funcional por Martín:** 18/10/2026  
**Estado:** APROBADO POR MARTÍN (responsable de análisis, 18/10/2026) · PENDIENTE DE COMUNICACIÓN Y REVISIÓN POR MARTINIANO/FACUNDO Y DE INCORPORACIÓN FORMAL AL REPOSITORIO. No constituye, por sí solo, cambio aprobado de la línea base de RN/CU.  
**Tema:** Issue #33 — condiciones que distinguen reserva provisional de cupo consolidado  
**Responsable funcional:** Martín, Integrante 2 / análisis y relevamiento  
**Destinatarios:** Martiniano (área pasajero), Facundo (administración/pagos) y equipo VanFull  
**Ubicación propuesta en el repositorio:** `Documentos/Sesiones/PC2/ACLARACION-FUNCIONAL-CU003-ISSUE33-v0.2-VALIDADA-ANALISIS.md`

## 1. Objeto y alcance

Registrar las aclaraciones comerciales de VanFull necesarias para determinar **cuándo queda garantizado un lugar o servicio**, distinguiendo ese hecho de la **confirmación del pago**. Es una aclaración del funcionamiento comercial aplicable al diseño de CU-003, no una orden para cambiar código o para dar por cerrados otros Issues.

- **Dentro de este documento:** modalidad ocasional, estudiante, laboral, especial y corporativa; interpretación de RN-002, RN-008 y ADJ-02; trazabilidad e implicancias para CU-003.
- **Fuera de esta resolución:** sanciones por no presentación o falta de pago, restricción de reservas futuras en efectivo, cálculo de tarifas, creación de contrataciones, capacidad sin vehículo, diseño de endpoints, nuevos estados de reserva o políticas de aprobación automática.
- **Límite PC2:** el reparto del equipo deja abonos y administración corporativa fuera de la implementación completa del PC2. Las aclaraciones se documentan para consistencia del dominio, sin convertir por sí solas esos circuitos en funcionalidades PC2.

## 2. Fuentes y autoridad

| Fuente | Autoridad y uso |
|---|---|
| `01_Entrevista_VanFull_2026-08-25.docx` y `FC-01 — Aclaraciones posteriores de la entrevista VanFull.md` | Información primaria de la empresa; especialmente FC-01.05, .06, .07, .08, .10, .20, .21 y .22. |
| **Aclaraciones de VanFull transmitidas por Martín durante el análisis del Issue #33, el 17/10/2026** | **CONFIRMADO POR VANFULL**, según declaración expresa de Martín, entrevistador; las precisiones nuevas se documentan aquí para conservar evidencia y trazabilidad. No se atribuyen a un documento anterior. |
| `02_Reglas_de_Negocio_VanFull_v1.1_Aprobado_Equipo.docx` | **DEFINIDO POR EL EQUIPO**, revisión 29/09/2026; RN-001/002/003/004/008/013/014/015. La v1.1 solo modifica RN-015 respecto de la v1.0. |
| `03_Especificaciones_Casos_de_Uso_VanFull_v1.3_Aprobado_Equipo` | Línea base de CU-003 según citas del Issue #33 y copia del flujo en `07_Documento_MVC_VanFull_v1.1_completo.docx`. **PENDIENTE:** cotejar directamente el archivo v1.3 completo antes de aprobar cambios a ese documento. |
| `backend/db/schema.sql`, `backend/openapi/openapi.yaml`, `REPARTO-PC2.md`, `CONTRIBUTING.md` (`main`, consulta 17/10/2026) | Fuentes técnicas vigentes; verifican las representaciones existentes y el procedimiento de cambios. No establecen nuevas reglas comerciales. |

**Criterio de precedencia:** profesores > fuentes directas de VanFull > decisiones formalmente aprobadas por el equipo > propuestas de IA. Si la aclaración reciente necesita precisar documentos aprobados, se registra la interpretación y se tramita su aceptación; no se edita silenciosamente una RN.

## 3. Aclaraciones comerciales confirmadas por VanFull

| Modalidad comercial | Hecho que garantiza el cupo o servicio | Condición posterior / salvedad | Clasificación |
|---|---|---|---|
| **Ocasional, pago en efectivo al abordar** | **Aceptación de la reserva por VanFull**, aun sin pago previo. | Se reserva el lugar y no vuelve a ofrecerse; el pago queda pendiente hasta el abordaje. No se define aquí sanción ni deuda automática por ausencia o impago. | **CONFIRMADO POR VANFULL** (aclaración 17/10). |
| **Estudiante — cupo anual** | **Confirmación/acreditación del pago anticipado realizado en enero**, correspondiente al servicio de **julio en modalidad solo ida**. | Garantiza el lugar anual originalmente contratado mientras se cumplan las condiciones de pago mensual; la evaluación de disponibilidad en julio se destina a nuevas incorporaciones o cambios de turno/horario, **no** a poner nuevamente en disputa el cupo anual vigente. | **CONFIRMADO POR VANFULL** (aclaración 17/10; RN-008). |
| **Laboral — primera contratación** | **Acreditación/confirmación del pago inicial** al contratar el servicio. | En los meses posteriores mantiene el cupo y paga normalmente del 1 al 10; advertencia/suspensión y eventual pérdida siguen RN-004. | **CONFIRMADO POR VANFULL** (aclaración 17/10; RN-003/004/009). |
| **Especial** | **Acreditación/confirmación de la seña general del 50 %** garantiza la contratación del **servicio completo**. | Saldo mediante transferencia: cancelado **24 h antes**; saldo en efectivo: al inicio del viaje. Se respetan acuerdos empresariales particulares. No implica, sin análisis adicional, crear o consolidar reservas individuales cuando la operación se represente con nómina. | **CONFIRMADO POR VANFULL** (aclaración y rectificación 17/10; RN-013, FC-01.21). |
| **Corporativo** | **Aceptación de la solicitud por VanFull bajo un acuerdo comercial vigente**. | El cupo/servicio se garantiza aunque se facture y cobre posteriormente a cuenta corriente; no requiere universalmente pago anticipado. Debe comprobarse que el acuerdo aplica a la solicitud. | **CONFIRMADO POR VANFULL** (aclaración 17/10; RN-014, FC-01.22). |

**Condición transversal ya aprobada:** verificar disponibilidad y capacidad aplicables según RN-001. Garantizar un lugar no autoriza sobreventa ni omitir las demás restricciones vigentes.

## 4. Interpretación de reglas aprobadas y aparente contradicción

### RN-002 y ADJ-02

La RN-002 dice que una reserva verbal o provisional **no necesariamente** garantiza el cupo: depende de las condiciones comerciales aplicables. La aceptación de un ocasional **con compromiso de pago en efectivo al abordar** es uno de los casos en que VanFull **sí** garantiza el lugar. No debe confundirse una solicitud aún no aceptada con una reserva efectivamente aceptada.

ADJ-02 excluye la equivalencia universal entre *pago confirmado* y *reserva consolidada*. Las cinco modalidades descriptas respetan esa decisión; particularmente, ocasionales con pago al abordar y corporativos pueden tener lugar garantizado sin pago previo.

**Conclusión:** no se detecta contradicción necesaria que obligue a reemplazar RN-002. **Se requiere incorporar una aclaración trazable** para que CU-003 no siga siendo ambiguo.

### RN-008 — alcance de la evaluación en julio

La RN-008 se refiere a la reserva anual estudiantil mediante pago anticipado del servicio de julio solo ida e indica que en julio se vuelve a evaluar la disponibilidad para el segundo cuatrimestre.

VanFull aclaró que esa evaluación se aplica a **nuevos cupos y solicitudes de cambio de turno/horario**, sin quitar la garantía del cupo anual original a quienes continúan cumpliendo las condiciones comerciales. No se trata de reevaluar competitivamente a todos los estudiantes ya confirmados.

**Conclusión:** la nueva información precisa una frase potencialmente ambigua; recomendamos documentar expresamente su alcance. **No editar el texto aprobado de RN-008 sin el procedimiento del equipo**. Si al revisar CU-003 v1.3 o la consigna docente se requiere una modificación normativa, abrir/registrar el correspondiente control de cambio.

### RN-003 / RN-004 — mantenimiento del cupo

El pago del 1 al 10 corresponde al **mantenimiento** del abono; no obliga a reabrir la competencia por el cupo cada día 1. Entre los días 11 y 13 puede haber advertencia/suspensión; después del día 13 **podrá** perderse el cupo si no se regulariza. No se establece pérdida automática el día 11 ni una transición de estados sin procedimiento aprobado.

### RN-013 / RN-014 — contratos especiales y corporativos

La seña de un especial asegura el **servicio contratado**; un acuerdo empresarial aceptado permite garantizarlo mediante cuenta corriente. La aplicación concreta a `reserva.estado` depende de cómo se represente cada modalidad en el DER/MR y del respaldo exigido por el Issue #7.

### RN-015 v1.1 — acreditación, separada de la garantía

Los pagos no acreditados automáticamente mediante proveedor integrado requieren confirmación/rechazo por persona autorizada. Cuando Mercado Pago comunica válidamente aprobación/acreditación en la integración definida, el sistema confirma el pago automáticamente. **Esto no crea una condición universal de consolidación de reservas**.

## 5. Implicancias de diseño — propuestas, no aprobaciones técnicas

**PROPUESTA DE IA (sujeta a revisión del equipo y compatibilidad con CU-003):** interpretar `reserva.estado = 'consolidada'` solo cuando una reserva individual tenga su lugar efectivamente garantizado. Un pago pendiente no obliga por sí mismo al estado `'provisional'`.

**Restricciones verificadas en el modelo actual:**

- `reserva.estado` admite `provisional`, `consolidada`, `cancelada`.
- Cada `reserva` exige respaldo por **exactamente uno** de `id_periodo_abono` e `id_contratacion_directa` (XOR): **Issue #7** aún pendiente.
- `servicio.tipo_servicio` incluye `UNIVERSITARIO`, `LABORAL`, `CORPORATIVO`, `ESPECIAL`; **no** incluye un valor `OCASIONAL`. La correspondencia del pasajero ocasional con esas categorías **no debe inventarse**.
- Servicios `ESPECIAL` disponen de `nomina_pasajeros` / `integrante_nomina`; garantizar la contratación no significa crear automáticamente una `reserva` por integrante de la nómina.
- `contratacion.condiciones_comerciales` es texto libre y no permite deducir por sí solo un criterio ejecutable, especialmente para acuerdos corporativos.
- `pago.estado` se administra independientemente de `reserva.estado`.
- En `ReservaCreate` del OpenAPI vigente solo aparecen `id_viaje` y `orden_parada`: **no** está resuelto cómo identificar respaldo y aceptación comercial. **No agregar campos ni endpoints sin tramitar los Issues correspondientes.**

**PENDIENTE DE VALIDACIÓN / DISEÑO:** qué constituye una *aceptación de VanFull* verificable al reservar desde app/AG-01 y con qué evidencia; tratamiento de ocasionales pagados anticipadamente por transferencia; cómo asociar pagos acreditados a períodos/contrataciones; cuándo se consolida el cupo de un nuevo período ya cubierto por un contrato anual; política exacta de suspensión/reactivación y estado en `reserva`; forma de comprobar acuerdo corporativo vigente. Ninguno de esos puntos se declara resuelto en este documento.

## 6. Criterios de prueba candidatos (no ejecutados ni aprobados)

| Escenario | Resultado funcional esperado tras aprobación | Alcance técnico |
|---|---|---|
| Ocasional: VanFull acepta pagar efectivo al abordar | El lugar queda garantizado, ocupa capacidad; pago puede seguir pendiente. | Requiere resolver representación de `ocasional`, respaldo #7 y aceptación. |
| Estudiante: pago de enero validado; en julio se solicitan nuevas altas | Se conserva el cupo anual del estudiante al día; se evalúan solo cupos disponibles para nuevas altas/cambios. | Lógica de abonos fuera del PC2 completo. |
| Laboral: primera contratación sin pago acreditado | No se considera todavía consolidado el cupo inicial bajo esta modalidad. | Requiere #7 y RN-015. |
| Laboral: primer pago acreditado | Cupo inicial garantizado, sujeto a RN-001. | Requiere #7 y RN-015. |
| Abono: llega el día 1 y pago mensual aún pendiente | No se declara automáticamente provisional el cupo anteriormente garantizado. | Evaluar RN-003/004 y estados administrativos. |
| Especial: seña general del 50 % acreditada | Contratación del servicio garantizada aun con saldo pendiente; no inferir reservas individuales. | Requiere representación contratación/nómina. |
| Corporativo: acuerdo aplicable y solicitud aceptada | Servicio garantizado sin pago anticipado. | Verificar acuerdo/aceptación; no deducir desde texto libre. |

Estos ejemplos sirven para derivar pruebas **después** de validar la traducción al sistema; no se presentan como pruebas realizadas.

## 7. Trazabilidad y dependencias

| Necesidad | RN / decisión base | CU / RF | Artefactos y dependencias |
|---|---|---|---|
| Diferenciar solicitud, provisional y cupo garantizado | RN-001, RN-002, ADJ-02 | CU-003, RF-005 | `reserva.estado`; contrato `ReservaCreate`; **#7** (respaldo), **#28** (disponibilidad). |
| Mantener cupo de estudiantes y laborales | RN-003, RN-004, RN-008, RN-009 | CU-003 y CU de gestión de abonos | `abono_mensual`, `periodo_abono`, `periodo_abono_viaje`; alcance de PC2 limitado. |
| Reconocer la seña de especial | RN-013, RN-015 | CU-003 cuando aplica; pagos / contratación | `contratacion`, `pago`, `nomina_pasajeros`; no confundir servicio con reserva individual. |
| Reconocer acuerdo empresarial aceptado | RN-014, RN-015 cuando hay pagos | CU-003 cuando aplica; contratación corporativa | `contratacion`, `cuenta_corriente`; verificar acuerdo y aceptación. |
| Mantener pagos independientes del estado de cupo | RN-015 v1.1, ADJ-02 | CU-003; CU-014/016/036 según canal | `pago.estado`, `reserva.estado`, servicios responsables. |

**Dependencias externas al #33:** #7 (respaldo de reserva), #9 (tarifa), #28 (cupo) y #34 (lista de espera), además de la decisión sobre digitalización de aceptación. No se resuelven por este documento.

## 8. Procedimiento de formalización y aprobación

1. **COMPLETADO — Martín** revisó y aprobó el contenido funcional el 18/10/2026, ratificando las aclaraciones directas de VanFull transmitidas como entrevistador. Esta aprobación no equivale a la de los demás integrantes.
2. Revisar el archivo **CU-003 v1.3 completo** y la consigna docente vigente; si sus textos contradicen alguna aclaración, registrar ambas versiones y resolver por el procedimiento correspondiente.
3. Compartir con **Martiniano y Facundo** (afecta reservas y pagos) para evaluación de impacto. Por `CONTRIBUTING.md` §1.8, las precisiones de línea base se canalizan con el responsable del análisis, aviso al equipo y Issue de control de cambio cuando corresponda.
4. Aprobar la **aclaración funcional como anexo interpretativo** de RN-002, RN-008 y CU-003, o tramitar un control de cambio explícito si hay que modificar enunciados aprobados. **No** renumerar RN ni modificar automáticamente DER/OpenAPI.
5. Una vez aprobada y versionada, incorporar el enlace en **Issue #33** con alcance exacto y pendientes técnicos separados; recién entonces verificar su criterio de cierre con Martiniano y comenzar implementación conforme a #7/#28/#9.
6. Seguir el circuito del repositorio: Issue → rama de documentación → diff y aprobación → PR → CI → merge. No editar `main` directamente.

### Aprobaciones (a completar; no presumidas)

| Rol | Estado | Fecha / evidencia |
|---|---|---|
| Martín — responsable de análisis y entrevistador | **APROBADO (contenido funcional)** | 18/10/2026; aprobación expresa en conversación del proyecto. |
| Martiniano — área pasajero | **PENDIENTE DE REVISIÓN/CONFORMIDAD** | — |
| Facundo — área administración/pagos | **PENDIENTE DE REVISIÓN/CONFORMIDAD** | — |
| Equipo (incorporación a la línea base) | **PENDIENTE DE APROBACIÓN/REGISTRO FORMAL** | — |

## 9. Pendientes que NO deben incorporarse silenciosamente

- La propuesta de bloquear futuras reservas ocasionales en efectivo por deuda o ausencia **no está aprobada**; requiere análisis aparte y revisión de RN-004/005/006/024. No definir deuda automática por una mera inasistencia.
- El alcance de `ocasional` frente a `ESPECIAL`/charter eventual y su traducción al modelo sigue **PENDIENTE DE VALIDACIÓN**.
- No se establece prioridad automática entre solicitudes provisionales ni un mecanismo de aceptación en la app por defecto.
- No se establece que confirmar un pago baste siempre para consolidar cualquier reserva.
- Este archivo **no autoriza** migraciones, cambios de `openapi.yaml`, nueva API, ni ampliaciones del PC2.
