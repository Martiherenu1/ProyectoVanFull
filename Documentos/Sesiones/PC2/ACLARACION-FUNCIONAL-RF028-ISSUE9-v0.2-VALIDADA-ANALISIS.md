# VanFull — Aclaración funcional de determinación de tarifas, descuentos y ajustes

**Versión:** 0.2 — VALIDADA POR ANÁLISIS (MARTÍN)  
**Fecha:** 18/10/2026  
**Estado:** **APROBADO FUNCIONALMENTE POR MARTÍN** el 18/10/2026. **PENDIENTE** la revisión técnica y aprobación por el equipo de cualquier cambio en RN, RF, CU, OpenAPI, SQL o código.  
**Origen:** [Issue #9 — RF-028: parámetros de `/tarifas` no corresponden a la tabla `tarifa`](https://github.com/Martiherenu1/ProyectoVanFull/issues/9).  
**Responsable de relevamiento:** Martín (Integrante 2).  
**Revisión posterior prevista:** Martiniano (servicios, tarifas, reservas y contrato API), Facundo (pagos, descuentos, deuda y cuenta corriente).  
**Ubicación documental prevista en el repositorio:** `Documentos/Sesiones/PC2/ACLARACION-FUNCIONAL-RF028-ISSUE9-v0.2-VALIDADA-ANALISIS.md`.

> **Control de cambios:** Este documento registra información comercial comunicada como **CONFIRMADO POR VANFULL** durante el relevamiento conversacional del 18/10/2026. Martín aprobó el contenido funcional de la v0.1 el 18/10/2026, sin aprobar diseños técnicos ni cambios a la línea base. No convierte automáticamente ninguna aclaración en una nueva RN, RF, CU o decisión tecnológica. No autoriza modificar `schema.sql`, OpenAPI, aplicaciones, contratos o documentos base sin el procedimiento y aprobación correspondientes.

## 1. Propósito, problema y alcance

El Issue #9 advierte que `GET /tarifas` recibe `tipo_cliente`, `modalidad`, `dias` y `medio_pago`, pero la tabla `tarifa` únicamente presenta `nombre`, `importe`, `tipo`, `fecha_creacion` y `fecha_vigencia`. Falta definir la correspondencia real entre combinaciones comerciales y registros de tarifas; además, el endpoint declara el descuento por efectivo como parte de la consulta, aunque **el beneficio se reconoce al confirmar el pago**.

**Objetivo:** preservar las aclaraciones de VanFull para que el equipo diseñe la selección de tarifas y coordine los cálculos asociados con pagos/contrataciones sin inventar reglas.

**Dentro de este relevamiento:** tarifarios fijos; ocasionales; abonos; cotizaciones; descuentos; prorrateo; variaciones FADEEAC; saldos, reajustes y redondeo; impacto en contrato API, datos, pruebas y trazabilidad.

**No implica implementar todo lo descripto en PC2:** según `REPARTO-PC2.md`, Martiniano tiene `/tarifas`, CU-003 y las tablas `tarifa`/`contratacion`; Facundo es responsable de pagos y cuenta corriente. La **gestión completa de abonos, dueño, corporativos, facturación y administración de tarifas está fuera del PC2**. Registrar un comportamiento en análisis no amplía el alcance ni crea endpoints nuevos.

## 2. Fuentes consultadas y jerarquía

| Fuente | Tipo / autoridad | Verificación / límites |
|---|---|---|
| Declaraciones directas de VanFull transmitidas expresamente por Martín durante las preguntas del 18/10/2026 | **CONFIRMADO POR VANFULL** (aclaraciones posteriores) | Sustentan las definiciones AC9 de la sección 3; no son citas de la entrevista original. |
| `01_Entrevista_VanFull_2026-08-25.docx` | Entrevista directa a VanFull | Relevó tipos de servicio, pago en efectivo, descuentos particulares, días/modalidades, frecuencia FADEEAC y actualización de contratos; algunas formulaciones quedaron precisadas posteriormente. |
| `02_Reglas_de_Negocio_VanFull_v1.1_Aprobado_Equipo.docx` (copia proporcionada) | **DEFINIDO POR EL EQUIPO** (RN-001 a RN-031, aprobado) | Cotejadas especialmente RN-010, RN-011, RN-012, RN-013, RN-014, RN-015 y RN-027; **su texto no se modifica con este borrador**. |
| [Issue #9](https://github.com/Martiherenu1/ProyectoVanFull/issues/9) | Registro de trabajo, abierto al 18/10/2026 | Confirma la inconsistencia entre selección de tarifa, OpenAPI y modelo. |
| [`backend/openapi/openapi.yaml`](https://github.com/Martiherenu1/ProyectoVanFull/blob/main/backend/openapi/openapi.yaml) | Contrato técnico en `main`, cotejado 18/10/2026 | `GET /tarifas` y respuesta `Tarifa`; parámetros actuales. |
| [`backend/db/schema.sql`](https://github.com/Martiherenu1/ProyectoVanFull/blob/main/backend/db/schema.sql) | Modelo físico implementado en `main`, cotejado 18/10/2026 | `servicio`, `tarifa`, `contratacion`, `abono_mensual`, `periodo_abono`, `viaje`, `pago`, `movimiento_cuenta`, `comprobante`. |
| [`Documentos/Sesiones/PC2/REPARTO-PC2.md`](https://github.com/Martiherenu1/ProyectoVanFull/blob/main/Documentos/Sesiones/PC2/REPARTO-PC2.md) | **DEFINIDO POR EL EQUIPO** | Dueños por área, alcance PC2, control de cambios de contratos. |
| Aclaración [Issue #7](https://github.com/Martiherenu1/ProyectoVanFull/issues/7), v0.2 validada por análisis | Aclaración funcional relacionada | Una contratación ocasional puede agrupar ida y vuelta; el pago conjunto no implica que las dos reservas sean una sola. |
| RF-028 y CU-003 vigentes, citados por Issue #9 | **DEFINIDO POR EL EQUIPO** | **PENDIENTE DE COTEJO DIRECTO DEL TEXTO INTEGRAL MÁS RECIENTE** de RF y CU antes de alterar sus especificaciones. |

**Precedencia ante contradicciones:** indicaciones docentes > afirmaciones directas de VanFull > línea base aprobada por el equipo > propuestas de IA. Las aclaraciones posteriores de VanFull precisan el negocio; su incorporación normativa requiere control de cambio.

## 3. Matriz de aclaraciones comerciales confirmadas

Todos los identificadores **AC9-xx** son referencias **locales a este documento**, **NO** nuevas reglas de negocio ni códigos oficiales.

### 3.1. Modalidades y selección de precios

| Ref. | Aclaración — **CONFIRMADO POR VANFULL** |
|---|---|
| AC9-01 | Los servicios habituales universitarios y laborales utilizan **tarifas mensuales fijas** diferenciadas por tipo de servicio, cantidad de días contratados por semana y modalidad `IDA`, `VUELTA` o `IDA_VUELTA`. |
| AC9-02 | «Ocasional» significa utilizar eventualmente un **charter universitario o laboral ya existente**. No se refiere a traslados particulares; estos corresponden a **servicios especiales**. |
| AC9-03 | El ocasional tiene **tarifas fijas propias por viaje**, independientes del abono mensual, generalmente más altas por trayecto que el costo equivalente de un abonado. «Generalmente» no es una restricción numérica obligatoria. |
| AC9-04 | Las tarifas ocasionales se diferencian por **servicio** (universitario/laboral) y **sentido** (ida/vuelta). La ida suele ser más cara que la vuelta, pero no siempre. |
| AC9-05 | La contratación ocasional conjunta de **ida y vuelta** tiene **tarifa fija especial propia**; **no** se calcula necesariamente sumando ambas tarifas individuales. |
| AC9-06 | La tarifa conjunta de ocasional `IDA_VUELTA` **solo corresponde cuando ambos viajes ocurren el mismo día**. La capacidad y las condiciones de reserva siguen sujetas a las reglas existentes. |
| AC9-07 | Los servicios **especiales** y **corporativos** se cotizan particularmente conforme a los parámetros de cada servicio; no se les aplica sin más la matriz fija de abonos u ocasionales. |
| AC9-08 | La **cantidad de días** usada para determinar el precio de un abono es la cantidad de **días contratados por semana**, no los días efectivos de viaje de ese mes. |

### 3.2. Incorporación a mitad de mes y feriados

| Ref. | Aclaración — **CONFIRMADO POR VANFULL** |
|---|---|
| AC9-09 | Si un universitario o laboral inicia un abono **a mitad de mes**, se cobra un importe proporcional a los días contratados que faltan hasta terminar dicho mes. |
| AC9-10 | El proporcional se calcula como **precio del abono mensual completo / total de días contratados que corresponden a ese mes × días contratados restantes desde la incorporación**. Se usan los días semanales concretamente contratados. |
| AC9-11 | Los **feriados sin servicio** que coincidan con días contratados **también se cuentan** en el total mensual y en los días restantes del cálculo proporcional. No se infiere aquí el tratamiento de suspensiones extraordinarias, reintegros ni recuperaciones de días. |

### 3.3. Descuentos y pagos

| Ref. | Aclaración — **CONFIRMADO POR VANFULL** |
|---|---|
| AC9-12 | El descuento del **15 % por efectivo** aplica a **todos los servicios**, incluidos universitarios, laborales, ocasionales, especiales y corporativos. |
| AC9-13 | Elegir `EFECTIVO` **no aplica** el descuento inmediatamente: solo se reconoce cuando VanFull **recibe y confirma efectivamente** el pago en efectivo. |
| AC9-14 | En un pago parcial en efectivo confirmado, el descuento inicialmente reconocido equivale al **15 % del importe efectivamente entregado en efectivo**; dicho descuento reduce el saldo pendiente además del dinero pagado. |
| AC9-15 | Si una contratación se **cancela íntegramente en efectivo**, se obtiene el **15 % del importe comercial aplicable**, aunque el cliente haya realizado varios pagos parciales en efectivo. El total entregado en efectivo termina siendo el 85 % de ese importe y el saldo queda en cero. |
| AC9-16 | Los descuentos comerciales particulares **pueden acumularse** con el de efectivo; se aplican **sucesivamente**, primero el descuento comercial y luego el de efectivo sobre el resultado, **no** sumando porcentajes. |

**Advertencia para el diseño:** AC9-14 y AC9-15 **no son equivalentes a aplicar incondicionalmente `pago × 15 %` en cada operación**, porque eso contradice la liquidación final confirmada. El ajuste de cancelación debe modelarse expresamente y quedar trazable (ver §4.2 y §6).

### 3.4. FADEEAC, vigencia y reajuste de deuda

| Ref. | Aclaración — **CONFIRMADO POR VANFULL** |
|---|---|
| AC9-17 | VanFull revisa sus tarifas **cada tres meses** según el índice **FADEEAC**; utiliza la **variación compuesta** de las tres variaciones mensuales, no su suma aritmética. |
| AC9-18 | **AS-IS:** una persona **consulta el índice publicado y carga manualmente** los valores/porcentajes. La integración automática a la fuente FADEEAC **no está confirmada ni aprobada**. |
| AC9-19 | El tarifario actualizado **entra en vigencia desde el mes siguiente**, sin cambios a mitad del mes en curso. |
| AC9-20 | La revisión trimestral alcanza **tarifas fijas** de universitarios/laborales/ocasionales y también **valores de referencia** para cotizaciones especiales y corporativas. Actualizar estos valores **no implica automáticamente** modificar toda cotización aceptada. |
| AC9-21 | Un **abono vigente del mes en curso** mantiene el precio originalmente contratado y su saldo pendiente original, pese a los cambios del tarifario general. |
| AC9-22 | Si un abono impago motivó la **suspensión del servicio** y el pasajero **solicita reactivarlo tras una actualización**, se ajusta **solamente el saldo pendiente del abono anterior** según la variación tarifaria; los pagos anteriores no se recalculan. |
| AC9-23 | Si transcurrieron **varias actualizaciones trimestrales** antes de la reactivación, se aplican **todas las variaciones compuestas sucesivas** al saldo original adeudado. |
| AC9-24 | En servicios especiales y corporativos **sin cláusula contractual expresa de ajuste**, una cotización aceptada **conserva su precio**, aun con saldo impago. |
| AC9-25 | En especiales/corporativos **con cláusula expresa de ajuste**, se utiliza la **variación trimestral compuesta FADEEAC**; se actualiza únicamente el **saldo pendiente** (no los pagos anteriores). |
| AC9-26 | Cuando esa cláusula existe y hay saldo pendiente, el saldo se actualiza **cada vez que entra en vigencia una revisión trimestral**, incluso si el servicio **ya se prestó**, y hasta cancelar la deuda. |
| AC9-27 | Los importes monetarios calculados **conservan centavos y se redondean a dos decimales**, no a pesos enteros ni a múltiplos comerciales. |

## 4. Procedimientos y ejemplos de cálculo

**Los valores numéricos de esta sección son exclusivamente ejemplos de prueba; NO constituyen tarifario real de VanFull.** Los casos calculados representan exclusivamente las condiciones expresamente confirmadas. El manejo de empates exactos al tercer decimal (p. ej. x,005) no ha sido definido y queda abierto (§7).

### 4.1. Prorrateo de un abono iniciado durante el mes

`Importe proporcional = redondear_2(Precio mensual × Días semanales contratados que quedan en ese mes / Total de esos días semanales en el mes)`.

Ejemplo: tarifa mensual $120.000,00; 12 días contratados computables en el mes; incorporación cuando quedan 6 → **$60.000,00**. Los feriados sin servicio **sí se computan** si coinciden con los días contratados.

El cálculo de un abono y el control de reservas no deben deducir automáticamente los días restantes de un mero número `dias=3`: el prorrateo también requiere **fechas y días concretos de la semana**.

### 4.2. Descuentos comerciales y efectivo; pagos parciales

**Caso 1 — pago total en efectivo:** servicio $100.000,00, descuento comercial 10 % ilustrativo → base ajustada $90.000,00. Se paga totalmente en efectivo → descuento efectivo $13.500,00; **cobro total $76.500,00; saldo $0,00**.

**Caso 2 — primer pago parcial:** base aplicable $100.000,00; pago efectivo confirmado $30.000,00 → descuento reconocido inicialmente $4.500,00; **saldo $65.500,00**.

**Caso 3 — segundo pago que cancela completamente en efectivo:** continúa el caso 2. VanFull cobra **otros $55.000,00**, reconoce un ajuste/descuento adicional de **$10.500,00** y declara **saldo $0,00**. En total cobró $85.000,00 y reconoció un descuento total de $15.000,00.

> **Inconsistencia aparente resuelta funcionalmente, pero con mecanismo contable pendiente:** 15 % del segundo pago ($55.000,00) serían $8.250,00, **no** $10.500,00. Por tanto, el último movimiento incluye un **ajuste de cierre** para cumplir el total final confirmado. **No implementar `importe_pago * 0,15` como regla universal para todas las operaciones y cierres.** El asiento/movimiento exacto y la conciliación de pagos mixtos deben ser acordados por Facundo.

### 4.3. Variación trimestral compuesta FADEEAC

Si las variaciones mensuales, expresadas en decimales, son `i1`, `i2` e `i3`:

`variacion_trimestral = (1 + i1) × (1 + i2) × (1 + i3) − 1`.

Ejemplo **ilustrativo** con +2 %, +3 % y +1 %: variación **6,1106 %** (aproximadamente **6,11 %**). Sobre una tarifa de $125.000,00, si se conserva la variación compuesta completa antes del redondeo monetario: `125.000 × 1,061106 = $132.638,25`.

**PENDIENTE TÉCNICO:** acordar si se almacenan/cuantizan variaciones intermedias; no inferir que VanFull redondea el porcentaje trimestral a dos decimales. Lo confirmado a dos decimales corresponde a **importes monetarios**.

### 4.4. Suspensión y reactivación de un abono

Ejemplo: importe abono $100.000,00; pagos previos $60.000,00; saldo adeudado $40.000,00. Suspensión, solicitud de reactivación tras incremento +20 % → **saldo ajustado $48.000,00**, no $60.000,00.

Si antes de solicitar reactivación hubo dos incrementos sucesivos +20 % y +10 %, la variación acumulada es +32 % y los $40.000,00 se convierten en **$52.800,00**. Es una deuda del abono anterior, **no** una recalculación completa del abono del mes nuevo.

### 4.5. Contrataciones especiales/corporativas con cláusula FADEEAC

Ejemplo: precio contratado $300.000,00; pagos recibidos $100.000,00; deuda $200.000,00; ajuste contractual FADEEAC +10 % → **saldo $220.000,00**, sin modificar los $100.000,00 pagados. Con cláusula, nuevos ajustes posteriores inciden sobre el saldo aún pendiente, incluso después de realizado el servicio; sin cláusula, no se ajusta por ese motivo.

## 5. Diagnóstico concreto del Issue #9 y fuentes técnicas verificadas

### 5.1. Contrato actual: `GET /tarifas`

El contrato vigente declara los parámetros: `tipo_cliente` (**obligatorio**, `string`), `modalidad` (**obligatoria**: `IDA`, `VUELTA`, `IDA_VUELTA`), `dias` (opcional, `integer`) y `medio_pago` (opcional: `EFECTIVO`, `TRANSFERENCIA`, `BILLETERA`, `CUENTA_CORRIENTE`, `MERCADO_PAGO`). Su descripción indica que **incluye el 15 % por efectivo**. La respuesta `Tarifa` expone `id_tarifa`, `nombre`, `importe` (número doble) y `tipo`.

### 5.2. Modelo físico actual

- `servicio.tipo_servicio`: `UNIVERSITARIO`, `LABORAL`, `CORPORATIVO`, `ESPECIAL`. **No existe `OCASIONAL` como quinto tipo de servicio**.
- `tarifa`: `id_tarifa`, `nombre`, `importe NUMERIC(12,2)`, `tipo`, `fecha_creacion`, `fecha_vigencia`. **No contiene relaciones explícitas con tipo de servicio, cantidad de días, sentido, condición ocasional/abono ni tramos de vigencia.**
- `contratacion`: `id_servicio`, `id_tarifa` opcional, `importe_acordado`, `condiciones_comerciales`; **no** contiene una columna estructurada de cláusula FADEEAC ni de porcentaje de descuento.
- `abono_mensual`: `modalidad`, `dias_semanales` (cadena), `id_contratacion`; `periodo_abono` almacena `YYYY-MM`.
- `viaje.sentido`: `IDA` o `VUELTA`; `viaje.fecha` permite comprobar la condición de **mismo día** en una tarifa conjunta ocasional.
- `pago`: importe `NUMERIC(12,2)`, medio y estado; **CONFIRMADO** es distinto de **PENDIENTE**. `movimiento_cuenta` permite vincular movimientos con contrataciones y pagos, pero **no existe en la fuente inspeccionada una decisión de cómo contabilizar cada tipo de descuento y ajuste**.

### 5.3. Diferencias a resolver; NO son instrucciones de implementación

| Hallazgo | Estado | Responsable propuesto para evaluar |
|---|---|---|
| `tipo_cliente` no distingue por sí mismo **servicio** universitario/laboral y **modalidad comercial** ocasional/abono. Falta un mapeo formal al dato. | **PENDIENTE DE DISEÑO** | Martiniano + Martín |
| `dias` no está documentado como **días por semana** y no aplica del mismo modo a ocasionales ni a cotizaciones particulares. | **PENDIENTE DE CONTRATO** | Martiniano + Martín |
| `medio_pago=EFECTIVO` en una **consulta** no demuestra pago confirmado. El contrato afirma «incluye descuento» sin distinguir precio base, simulación/beneficio potencial y descuento efectivamente aplicado. | **CONTRADICCIÓN DE SEMÁNTICA** | Martiniano + Facundo |
| Tabla `tarifa` no identifica combinaciones fijas ni versionado de cambios; `fecha_vigencia` carece de semántica de selección suficientemente expresada. | **PENDIENTE DE MODELO** | Martiniano + Martín |
| Cotizaciones especiales/corporativas tienen criterios distintos y eventuales cláusulas; no hay una fórmula confirmada para elaborar sus precios. | **PENDIENTE** | Facundo + Martín |
| Abonos, reajustes de deuda, descuentos y cierre en efectivo necesitan trazabilidad monetaria; el saldo es derivado según MR y no debe persistirse indiscriminadamente. | **PENDIENTE DE DISEÑO CONTABLE** | Facundo + Martiniano |
| Índice FADEEAC: carga humana confirmada AS-IS vs cálculo automático de tarifas y deudas propuesto TO-BE. | **PENDIENTE DE APROBACIÓN TÉCNICA** | Equipo; dueño de tarifas y pagos |

## 6. Propuestas de arquitectura y diseño — NO aprobadas

**PROPUESTA DE IA:** distinguir conceptualmente (1) **tarifa fija base y su vigencia**, (2) **cotización e importe contratado**, (3) **descuentos comerciales acordados**, (4) **pagos confirmados y descuentos reconocidos**, y (5) **ajustes tarifarios/de deuda y sus causas**. Esta distinción puede implementarse de varias maneras, sin declarar todavía nuevas tablas, columnas, RN ni endpoints.

1. **Selección de tarifa (Martiniano).** Establecer una correspondencia explícita entre tipo de servicio + clase comercial (abono/ocasional) + modalidad + días semanales cuando corresponda + vigencia y el registro tarifario. No calcular el ocasional por prorrateo del abono. Consultar dos reservas de ida y vuelta en la misma fecha antes de seleccionar el precio conjunto. Mantener la solución compatible con Issue #7.
2. **Consulta y respuesta API (Martiniano + Facundo).** Separar **importe base** de cualquier **beneficio eventual** por elegir efectivo. No presentar el 15 % como descuento ya devengado hasta que Facundo confirme el pago. Cambiar una operación OpenAPI existente requiere acuerdo de los tres según `REPARTO-PC2.md`.
3. **Movimientos de pagos y deuda (Facundo).** Definir asientos/movimientos para descuento comercial, descuento por pago parcial confirmado, ajuste de cierre íntegramente en efectivo, actualización FADEEAC, imputación a contrataciones y auditoría. Respetar saldos derivados y `NUMERIC(12,2)` del modelo.
4. **Actualización periódica (evaluación posterior).** Una persona autorizada carga variaciones consultadas en FADEEAC; el backend puede calcular factores compuestos con precisión decimal y registrar vigencia. La **consulta automática externa** no forma parte de los hechos confirmados ni del alcance del PC2.
5. **Permisos.** La entrevista AS-IS mencionó dueño/administrador, pero la **RN-027 aprobada para TO-BE reserva al dueño la creación/modificación estructural de tarifas y descuentos especiales**. Una carga delegada de índices o un proceso automático deberá diseñarse sin soslayar esta regla; cualquier cambio requiere aprobación del equipo.
6. **Registros con decimales.** Utilizar aritmética decimal exacta y cuantización a 2 decimales monetarios. Confirmar el criterio de desempate cuando la tercera cifra decimal sea exactamente 5 antes de codificar el redondeo como RN.

**Fuera del PC2 según reparto:** administración de precios por dueño, abonos completos, corporativos y cotizaciones especiales completos; las aclaraciones de esas modalidades quedan documentadas para trazabilidad y evolución posterior, no para incorporar funcionalidades nuevas en esta entrega.

## 7. Contradicciones, precisiones y pendientes explícitos

### 7.1. Aclaraciones posteriores frente a fuentes anteriores

| Fuente anterior / situación | Nueva evidencia | Tratamiento |
|---|---|---|
| Entrevista 25/08 menciona «ocasionales» incluyendo traslados a aeropuertos. | AC9-02 reserva «ocasional» para charters regulares y clasifica traslado particular como especial. | **PRECISIÓN POSTERIOR DE VANFULL**; no borrar la redacción histórica sin anotación de cambio. |
| Entrevista 25/08 indica que una tarifa nueva puede afectar servicios impagos; RN-012 dice que **podrá** afectar saldos. | AC9-21 a 26 acotan condiciones: abono vigente conserva importe; suspensión + reactivación actualiza deuda; especiales/corporativos solo con cláusula. | **CRITERIO MÁS ESPECÍFICO**; requiere cotejo y decisión de incorporación a línea base. |
| Entrevista 25/08 dice actualización trimestral según FADEEAC; respuestas iniciales hablaban de actualización «automática». | AC9-18 precisa que **hoy** hay consulta/carga humana; cálculo backend automático es una propuesta de sistema. | **DIFERENCIA AS-IS / TO-BE**; no declarar integración FADEEAC aprobada. |
| OpenAPI afirma que consultar `/tarifas` «incluye descuento 15 % efectivo». | AC9-13 confirma que solo se otorga después de **pago en efectivo confirmado**. | **INCONSISTENCIA DE CONTRATO**; propuesta de separar cotización de descuento devengado. |
| RN-011 aprobada: «Todo pago realizado en efectivo tendrá un descuento del 15 % sobre la tarifa aplicable…». | AC9-14 y 15 detallan pagos parciales, saldo y ajuste de cierre. | **COMPLEMENTO NECESARIO**; el cálculo por movimiento no puede simplificarse como 15 % de cada cuota en todos los casos. |
| Entrevista: dueño/administrador podía modificar tarifas AS-IS. | RN-027 TO-BE: dueño exclusivamente para modificaciones estructurales y descuentos especiales. | **ÁMBITOS DISTINTOS; aplicar RN-027** mientras el equipo no apruebe cambios. |

### 7.2. Pendientes comerciales puntuales (no bloquear automáticamente la aclaración)

- **PV9-01 — Tarifa real y catálogo:** importes, cantidad de días semanales disponibles, combinaciones efectivamente comercializadas, vigencias y matrices de especiales/corporativos. Ninguno fue proporcionado durante este relevamiento.
- **PV9-02 — Descuentos y pagos mixtos:** cálculo de cancelación final cuando una contratación reúne efectivo y otros medios, evitando beneficios sobre importes no pagados en efectivo; reglas de compensación si hay devoluciones o pagos rechazados. No inventar un algoritmo a partir de ejemplos únicamente en efectivo.
- **PV9-03 — Prorrateo:** convención de fecha de incorporación y cómo se manejan cambios de modalidad/días durante un mes, si existieran; no confundir con simple alta a mitad de mes.
- **PV9-04 — FADEEAC y vigencia:** calendario exacto de los trimestres, periodicidad y responsable de la carga, origen oficial verificable de datos, control de errores, y precisión intermedia de los porcentajes. La variación compuesta sí está confirmada.
- **PV9-05 — Condiciones contractuales:** representación estructurada y autorización de cláusulas FADEEAC; si existen excepciones por períodos de mora, renegociaciones o acuerdos no tratados, no suponerlas.
- **PV9-06 — Redondeo:** criterio en empates exactos al medio centavo (`x,005`); confirmado **dos decimales**, no el algoritmo de desempate.

### 7.3. Pendientes técnicos que bloquean cerrar el Issue #9

- **PT9-01:** acuerdo del equipo sobre identificación y búsqueda inequívoca de tarifas por combinación (incluida vigencia), sin permitir coincidencias ambiguas.
- **PT9-02:** contrato definitivo de `GET /tarifas`: nombres, obligatoriedad, tipos, respuesta y semántica del descuento en la **consulta**, con compatibilidad de las pantallas y CU-003.
- **PT9-03:** impacto del esquema físico/ORM, migración si hace falta y semillas de tarifas para la demo. **No agregar columnas sin control de cambio.**
- **PT9-04:** decisión de Facundo sobre contabilización y prueba de pagos parciales, descuento por cierre y ajustes FADEEAC; mecanismo para evitar doble aplicación de una variación.
- **PT9-05:** delimitación PC2 vs extensiones futuras y aprobación de los tres para modificar operaciones API existentes.
- **PT9-06:** revisión del RF-028 y CU-003 más recientes y ajuste controlado de trazabilidad/documentación si correspondiere.

## 8. Matriz de trazabilidad orientativa

| Necesidad / comportamiento | Fuente o requisito asociado | Interfaz / API / datos existentes | Test candidato | Estado |
|---|---|---|---|---|
| Consultar precio de universitario/laboral según días semanales y sentido | RN-010; RF-028 (según Issue #9); AC9-01/08 | `/tarifas`; `tarifa`, `servicio`, `abono_mensual` | TP9-01 | Relevamiento confirmado; mapeo técnico pendiente |
| Consultar ocasional IDA/VUELTA/combinado | AC9-02..06; CU-003; Issue #7 | `/tarifas`, `/reservas`; `viaje`, `contratacion` | TP9-02/03 | Comercial confirmado; API pendiente |
| Registrar descuentos después de pago efectivo confirmado | RN-011, RN-015; AC9-12..16 | `pago`, `movimiento_cuenta`; operaciones de pagos vigentes | TP9-04..07 | Comercial confirmado; cálculo/contabilidad pendiente |
| Prorratear un abono incorporado a mitad de mes | RN-010; AC9-09..11 | `abono_mensual`, `periodo_abono` | TP9-08/09 | Confirmado; gestión completa fuera PC2 |
| Actualizar referencias según FADEEAC | RN-012 (relación parcial); AC9-17..20 | `tarifa.fecha_vigencia` | TP9-10 | Confirmado AS-IS; mecanismo TO-BE pendiente/fuera PC2 |
| Mantener abono vigente; reactivar deuda suspendida | RN-012; AC9-21..23 | `periodo_abono`, `pago`, `movimiento_cuenta` | TP9-11/12 | Confirmado; gestión fuera PC2 |
| Respetar cláusula de cotización especial/corporativa | RN-012, RN-014; AC9-24..26 | `contratacion.importe_acordado`, `condiciones_comerciales`, movimientos | TP9-13/14 | Confirmado; gestión fuera PC2 |
| Redondear importes a centavos | AC9-27 | `NUMERIC(12,2)` | TP9-15 | Confirmado; desempate técnico pendiente |

Los identificadores `TP9-xx` son **escenarios candidatos, no pruebas ejecutadas ni nuevos CU/RF/RN**. Endpoints de pagos existentes no se renombraron aquí; la trazabilidad definitiva debe copiar las operaciones exactas del OpenAPI y quedar aprobada por cada dueño.

## 9. Escenarios de prueba candidatos (sin ejecución)

| ID local | Dado / cuando | Resultado funcional esperado |
|---|---|---|
| TP9-01 | Consultar abono universitario de 3 días semanales IDA frente al de 3 días IDA_VUELTA, con ambos registros de tarifario. | Selección de cada **tarifa fija específica**; no multiplicación diaria ni mezcla entre modalidades. |
| TP9-02 | Ocasional toma IDA de un charter laboral y consulta VUELTA. | Precio fijo de cada sentido; no forzar igualdad ni que ida sea siempre mayor. |
| TP9-03 | Ocasional contrata IDA y VUELTA el mismo día; otro intenta combinado con fechas distintas. | Primer caso utiliza tarifa fija conjunta; segundo **no tiene derecho a esa tarifa conjunta** (sin inferir aquí si otra contratación múltiple es admisible). |
| TP9-04 | Se selecciona EFECTIVO al consultar y existe pago PENDIENTE. | El descuento aún **no está otorgado**. |
| TP9-05 | Importe base $100.000, pago efectivo CONFIRMADO de $30.000. | Descuento $4.500; saldo $65.500. |
| TP9-06 | Tras TP9-05 se cancelan los restantes con $55.000 más en efectivo. | Descuento total $15.000; cobros totales $85.000; saldo $0. **No** solo 15 % del segundo importe. |
| TP9-07 | Contratación $100.000 con descuento comercial 10 % y pago total efectivo. | Cobro final $76.500; descuentos sucesivos, no sumados. |
| TP9-08 | Abono $120.000 con 12 días contratados computables y 6 restantes al incorporar. | Importe proporcional $60.000. |
| TP9-09 | Feriado sin viaje coincide con día semanal contratado. | Se cuenta para el denominador y, si corresponde, para los días restantes de TP9-08. |
| TP9-10 | Variaciones FADEEAC mensuales +2 %, +3 %, +1 %. | Factor 1,061106; variación compuesta 6,1106 %; no suma 6 %. |
| TP9-11 | Abono vigente del mes y posterior revisión trimestral. | Su saldo mantiene precio originalmente acordado. |
| TP9-12 | Abono suspendido por impago: deuda original $40.000, reactivación tras +20 % y +10 %. | Deuda reactivada $52.800; pagos previos no alterados. |
| TP9-13 | Servicio especial aceptado **sin** cláusula de ajuste, aún impago; entra nueva tarifa. | No se actualiza su importe acordado por FADEEAC. |
| TP9-14 | Servicio corporativo con cláusula: deuda $200.000 tras pago previo; actualización +10 %, servicio ya realizado. | Saldo $220.000; pago previo intacto; posteriores actualizaciones mientras exista deuda. |
| TP9-15 | Cálculo produce $132.637,506. | Importe monetario $132.637,51. |

**No ejecutados.** Los casos dentro del PC2 se seleccionarán según `REPARTO-PC2.md`; los demás sirven de criterios diferidos, no como obligación de desarrollo inmediato.

## 10. Plan de aprobación y entrega

1. **Martín — COMPLETADO (18/10/2026):** aprobó funcionalmente la v0.1 tras revisar las aclaraciones sobre efectivo, FADEEAC y tarifas. Esta v0.2 documenta esa aprobación; no representa aprobación técnica del equipo.
2. **Martiniano y Facundo:** analizar el mapeo de `/tarifas` y la imputación de pagos/saldos, respectivamente, preservando los dueños definidos en `REPARTO-PC2.md`.
3. **Tres integrantes:** acordar cambios a contrato existente/ORM/esquema y alcance PC2; cualquier ampliación queda pendiente de aprobación.
4. **Repositorio:** con la aprobación funcional de Martín registrada, incorporar **exclusivamente este anexo validado** mediante rama/PR/documentación y CI, sin modificar silenciosamente RN, RF, CU, OpenAPI ni SQL.
5. **Issue #9:** no marcarlo resuelto por documentar la aclaración. Se cierra cuando exista decisión aprobada y solución implementada/cotejada en la fuente correspondiente, con pruebas.

---

**Control de versión:** v0.2, aprobada funcionalmente por Martín el 18/10/2026 sobre el contenido de la v0.1, sin cambios sustantivos en aclaraciones AC9 ni en escenarios TP9. Ninguna decisión técnica aquí sugerida está aprobada; toda ambigüedad residual conserva el estado **PENDIENTE DE VALIDACIÓN**.
