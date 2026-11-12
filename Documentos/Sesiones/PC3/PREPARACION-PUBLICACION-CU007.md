# Preparación de publicación documental de CU-007 para PC3

## Corrección documental publicada — 11/11/2026

Martín autorizó commit/push normales y nueva [PR #271](https://github.com/Martiherenu1/ProyectoVanFull/pull/271),
abierta sin merge. #268/#267 son antecedentes, sin cierre automático. Base main
revalidada sin avance `c9ac094299a93a52cae6245ea0093aaf964196a2`; primer HEAD
publicado `117af4f6d03628b1c1db855ab10cad758d85afdb`. Este registro completa
publicación efectiva en los mismos cuatro documentos; preparación e históricos
se conservan. Revisiones solicitadas a `Martiherenu1` y `facubarrientos`, sin
aprobación técnica atribuida. HEAD final y CI se registran en #271 después de
verificarlos; pendientes de comprobación al preparar esta nota. Sin implementación,
fecha de cierre confirmada, despliegues ni operaciones sobre bases.

## Integración efectiva verificada — 11/11/2026

PR #268 mergeada en main mediante `c9ac094299a93a52cae6245ea0093aaf964196a2`.
Se conservan base `fa59928ee1dc4ce838f818397181bc6a817c31c1`, primer HEAD
`8755c8b972c1ef98c73e072bd41ef3c73224e67a` y HEAD final publicado
`d5153fa2b2b09803a612eca8c69dea83409de1f0`. La aprobación de Martiniano fue
únicamente documental: no aprueba implementación ni descenso por reserva.
Las precisiones transmitidas por Martín el 11/11 dejan S10 pendiente de validación
con VanFull, los cambios de DER sujetos al acuerdo de los tres y una primera
entrega solo online como propuesta parcial de Martiniano, pendiente de alcance.
RF-015 y RNF-011/012 se conservan. No hay fecha de cierre confirmada.
Los registros siguientes describen publicación y preparación históricas; sus
afirmaciones de PR abierta/sin merge no son el estado efectivo actual.

## Publicación efectiva — 10/11/2026 (antecedente)

- Creados [Issue #267](https://github.com/Martiherenu1/ProyectoVanFull/issues/267)
  y [PR #268](https://github.com/Martiherenu1/ProyectoVanFull/pull/268), abierta
  para revisión, sin merge. Único cierre automático: #267, de documentación.
- Primer commit/push normal `8755c8b972c1ef98c73e072bd41ef3c73224e67a` sobre
  `fa59928ee1dc4ce838f818397181bc6a817c31c1`, main sin avance al revalidar.
  Este registro posterior se publica en la misma rama, sin ampliar los cuatro archivos.
- Revisión solicitada efectivamente a `Martiherenu1` y `facubarrientos`; ninguna
  aprobación técnica ni revisión concluida atribuida. Análisis fuente intacto.
- HEAD final y resultado/enlace de CI se registran en la descripción de #268 tras
  observarlos; al preparar este registro siguen pendientes de comprobación. No
  se trasladan resultados de otro HEAD ni se afirma CI aprobada por anticipado.
- No hubo merge, cambios productivos, despliegues ni operaciones sobre bases.
  Los borradores y estados «sin publicar» inferiores se conservan como antecedentes.

## Autorización de publicación — 10/11/2026 (antecedente)

Martín revisó el diff y autorizó Issue específico, commit/push normales y PR para
revisión, sin merge ni cambios productivos. Main revalidado sin avance en
`fa59928ee1dc4ce838f818397181bc6a817c31c1`; no fue necesario incorporarlo otra vez.
Creado [Issue documental #267](https://github.com/Martiherenu1/ProyectoVanFull/issues/267)
tras repetir búsqueda sin equivalente. Único cierre automático previsto: #267;
no cierra CU-007 ni sus pendientes funcionales. Al registrar esta autorización,
PR y CI final todavía pendientes. Las notas de preparación siguientes se conservan
como antecedentes, no como estado de publicación posterior.

**Fecha:** 10/11/2026. **Estado histórico de preparación:** preparado localmente para revisión; sin commit,
push, Issue, PR, comentarios, merge o despliegue realizados en esta tarea.

## Base y alcance

- Rama propia: `docs/chofer-analisis-cu007-pc3`.
- Worktree independiente: `.worktrees/docs-cu007-pc3`.
- Base main verificada en GitHub y obtenida por fetch:
  `fa59928ee1dc4ce838f818397181bc6a817c31c1`, commit del 10/11/2026
  16:39:12 Argentina (`19:39:12Z`), merge de #266.
- Fuente local: `Documentos/Sesiones/PC2/ANALISIS-CU007.md`, con sección
  «Estado vigente y aclaraciones operativas — 10/11/2026» y fuentes S10/S11.
  Se incorpora completa, sin editar: SHA-256
  `58b44ece93723360dacc5e73ad73f42ff901c481c02959e61291f76afe82d0e4`.
- Main no contenía ese archivo; no hay versión remota que sobrescribir. El análisis
  permanece en PC2 para conservar su ruta vigente; esta preparación se ubica en PC3.
- Cuatro archivos documentales previstos: análisis, este resumen y referencias
  puntuales en CONTEXTO general y de Chofer. Resto de main conservado, incluidos
  CU-008, Checkout Pro y cambios compartidos posteriores al 30/10.

La sección vigente proviene del **recuerdo de entrevista comunicado por Martín**,
sin entrevista nueva ni cita textual original recuperada. S11 recoge coordinación
de Marti y Facu informada por Martín; no demuestra aprobación técnica, revisión del
diff ni que ya hayan leído S10. No declara diseño cerrado ni CU-007 implementado.
Las fechas/restricciones de la demo del 30/10 son antecedentes, no restricciones
automáticamente vigentes para PC3.

## Resumen breve para revisión

**Reglas funcionales aclaradas, con esa procedencia:** hacia universidades, el
universitario elige destino UADE/UCA; el laboral puede elegir otra parada de descenso
habilitada anterior. Se distinguen destino previsto y descenso físico, que no se
controla por QR/GPS. Ascenso y descenso tienen opciones diferenciadas; Administración
o dueño decide habilitaciones. Se conserva el ascenso reservado y se admite otro
ascenso habilitado antes del destino previsto, sin comprobación física automática.
Laborales/casuales no editan su parada en el sistema durante el viaje; pedir bajar
antes no crea registro de descenso ni edición de reserva. Debe existir captura
offline y conservarse el envío que no valida como situación errónea, sin confundirlo
con abordaje válido. Mostrar pantalla con foto/habilitación o DNI no convierte al
chofer en confirmador manual.

**Preguntas operativas restantes:** opciones del casual; alcance de VUELTA y otros
servicios contrastando S6; quién consulta/trata/resuelve los conflictos offline;
cómo se verifica habilitación y reserva mostrando solo DNI. Sigue pendiente
correspondencia horaria, sin inventar ventanas. DNI por sí solo no prueba habilitación.

**Decisiones técnicas de equipo pendientes:** formato y ciclo del QR; sesión,
reautenticación, retención e históricos; configuración de paradas; persistencia de
destino previsto e intentos; identidad de operación e idempotencia. El momento de
validación y tratamiento técnico de conflictos necesitan acuerdo, conservando el
envío y motivo sin aceptarlo automáticamente ni recuperar cupo por ausencia.
RNF-011 exige intentar sincronizar dentro del objetivo de 60 segundos tras recuperar
conectividad, no garantizar éxito; RNF-012 conserva integridad sin duplicados.

**Dependencias propuestas, no aprobadas:** descenso previsto por reserva y su fuente
según modalidad; habilitaciones estructuradas; posibles credenciales QR y registro
de operaciones/resultados; contrato de reserva/opciones/abordaje, reintentos,
privacidad y consulta de conflictos. Los candidatos a tablas, rutas, columnas,
UUID, SQLite/IndexedDB y códigos de las recomendaciones históricas no son decisiones
del equipo. No se cambia schema, ORM, migraciones, OpenAPI ni dependencias aquí.

## Coherencia con el historial

| Pendiente o afirmación histórica | Lectura vigente para revisión |
|---|---|
| Destino individual y autoridad totalmente desconocidos | S10 aclara universitario/laboral hacia universidades y autoridad Administración/dueño; falta representación y completar modalidades. No reabrir lo aclarado como desconocido. |
| Descenso entendido como control físico | Es destino previsto; no exige constatar bajada, segundo escaneo ni GPS. No sustituirlo por última parada ni invertirlo por sentido. |
| Conflicto offline sin conservación definida | S10 pide conservar envío erróneo; falta consulta/tratamiento/resolución, y distinguir rechazo de red/respuesta perdida. |
| «Solo validar al sincronizar» en recomendación 4 | Propuesta histórica de IA, no política aprobada ni sustituto de la decisión pendiente de los tres. |
| QR permanente, estados conceptuales o estructuras candidatas | Propuestas; no formato, estados de base ni soporte de revocación aprobados. |
| Publicación/PR «abierta» en notas viejas | Metadatos actuales: #257, #260 y #266 mergeadas; no inferir estado desde el cuerpo histórico. |
| Congelamiento y demo 30/10 | Antecedentes; no se extienden automáticamente a PC3. No habilitan ni impiden por sí solos una entrega nueva. |

La ratificación del 30/10 y el resto del análisis se conservan íntegros; la sección
del 10/11 encabeza su lectura actual. La revisión no reconcilia fuentes inventando
reglas, no exige descenso físico ni atribuye a DNI una comprobación no definida.

## Búsqueda de equivalentes y estado remoto

Consulta del 10/11/2026 mediante GitHub, solo lectura. Búsquedas de repositorio sin
filtro de estado, con `is:issue`/`is:pull-request`, hasta 100 resultados; todas completas
(`incomplete_results=false`) y sin necesitar páginas adicionales:

- `CU-007`: un Issue (#259) y tres PR (#260/#76/#40), de cierre CU-029/CU-030,
  cancelación y contrato de ejecución; ninguno específico para publicar este análisis.
- `CU007`: cero Issues y cero PR.
- `registrar abordaje`: cero Issues y cero PR.
- `abordaje`: diez Issues y trece PR de antecedentes; ninguno equivalente específico.

Metadatos verificados: #257 merged el 30/10 a las 14:47:05Z; #260 merged el 30/10
a las 15:01:55Z; #266 merged el 10/11 a las 19:39:13Z. La hora de merge puede diferir
un segundo de la del commit. No se certifican aquí CI ni despliegue.
La comparación de main desde `58d272b` mantiene los servicios/modelo de CU-007
relevados; cambia pagos/Checkout, presentación y archivos compartidos. No resuelve
descenso por reserva, alta QR ni sincronización offline. No reutilizar #259 como
Issue de CU-007 ni cerrarlo como efecto de esta preparación.

## Issue propuesto, no creado

**Título:** CU-007: publicar análisis vigente y aclaraciones funcionales para PC3

**Cuerpo propuesto:**

### Qué hay que hacer

Incorporar `Documentos/Sesiones/PC2/ANALISIS-CU007.md` vigente al 10/11, conservar
ratificación e históricos y presentar aclaraciones, preguntas y propuestas para
revisión de Martiniano y Facundo. Alcance exclusivamente documental; no implementar.

### Justificación

- Área: chofer, con coordinación pasajero/administración.
- CU-007, RF-014/015, RN-023, RNF-011/012; relación con CU-008 y RN-025.
- Las aclaraciones proceden del recuerdo de entrevista comunicado por Martín;
  no equivalen a aprobación técnica conjunta ni cierre del diseño.

### Criterio de aceptación

- [ ] Conservar completo el análisis vigente y su sección del 10/11.
- [ ] Separar reglas aclaradas, preguntas operativas y decisiones técnicas pendientes.
- [ ] Mantener casuales, VUELTA, conflictos offline y control con DNI como precisiones pendientes.
- [ ] Identificar cambios de modelo/contrato exclusivamente como propuestas.
- [ ] Conservar offline, RNF-011 intento ≤60 s y RNF-012 sin duplicados.
- [ ] No declarar CU-007 implementado ni extender restricciones de demo PC2 a PC3.
- [ ] Solo documentación, con diff y conservación comprobados.

### Qué toca y dependencias

Solo los cuatro documentos enumerados en esta preparación. Sin código, modelo,
OpenAPI, datos ni dependencias. La revisión de Marti/Facu y las precisiones operativas
son pendientes para implementar, no evidencia ya obtenida. Este Issue cerraría
únicamente la publicación documental, nunca la implementación de CU-007.

## PR propuesta, no creada

**Título:** docs(chofer): análisis vigente de CU-007 y aclaraciones para PC3

### Qué y por qué

Publica el análisis vigente de CU-007 para revisar antes de implementar: incorpora
S10/S11 del 10/11, conserva la ratificación del 30/10 y todos los históricos. Agrega
resumen de reglas aclaradas, preguntas restantes y propuestas técnicas/de datos.
No declara diseño cerrado ni implementación. Base `fa59928ee1dc4ce838f818397181bc6a817c31c1`.

Al crear el Issue autorizado, reemplazar esta nota por `Closes #<número real>`;
sin número asignado ni cierre automático ficticio en esta preparación.

### Trazabilidad

- Área: chofer; revisión coordinada con pasajero/administración.
- CU-007; RF-014/015; RN-023; RNF-011/012; interacción CU-008/RN-025.
- Procedencia funcional: recuerdo de entrevista informado por Martín, no aprobación
  técnica de Marti y Facu. Revisión de esta entrega por ambos: pendiente, no atribuida.

### ¿Toca algo compartido?

Solo referencias documentales en CONTEXTO general y de Chofer; no contrato, modelo,
migraciones, base Flutter, dependencias ni datos. Conserva Checkout Pro y CU-008.

### Cómo se verificó

Presencia de sección vigente; copia byte a byte con SHA-256; revisión de coherencia
de preguntas/procedencia; búsquedas remotas y base; diff limitado a documentación
y control de whitespace. Suites/ruff/Flutter/migraciones no ejecutados: documentación
solamente. Sin ensayo físico ni acceso a Render/Neon/Maps, ni CI propia acreditada.

### Capturas y pendientes

No aplica captura. Preguntas operativas y decisiones técnicas siguen enumeradas
arriba y en el análisis. FC-01 exacto `(1)` sigue sin equivalencia verificada.
Publicación, commit/push/PR, CI y eventual merge requieren autorización posterior;
no se realizaron con esta preparación. No cerrar CU-007, #8 ni #28 como implementados.
