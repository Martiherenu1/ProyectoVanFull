# CU-008: conexión, coordinación e históricos

## Publicación autorizada — Issue #256, 30/10/2026

- Martín informó revisión de Martiniano sin bloqueos sobre Mis reservas, PasajeroShell y main.dart, y su solicitud de publicar la PR completa para revisar también ausencias_api.dart y accion_informar_ausencia.dart. No se atribuye revisión integral del adaptador/componente ni aprobación final de toda la entrega. El usuario autorizó commit, push normal y PR con código, pruebas y documentación.
- Búsqueda remota repetida por CU-008/ausencia sin Issue/PR específico equivalente de interfaz. #146/#147 y #131/#133 son antecedentes de backend/helper ya integrados; no se reutilizan para cierre. Issue nuevo verificado: https://github.com/Martiherenu1/ProyectoVanFull/issues/256. La PR cerrará únicamente #256, sin cerrar seguimientos generales.
- Fetch previo a publicación: main sigue cbcbf1243370649add1b30fb2f1908bdb54962a5, misma base revisada y probada; no hay cambios entrantes ni nueva combinación. Código y dependencias conservados. No se repiten las 832 pruebas locales ni analyze por agregar solo este registro documental; no se atribuyen a otra base ni a CI remota.
- Alcance publicado previsto: 12 archivos (10 Dart de implementación/pruebas y dos documentos), sin artefactos .diff, logs, build, APK o archivos ajenos. Diff propio sin backend/OpenAPI/modelo/dependencias/flags; diff --check correcto. CI remota se verifica después del push y se registra con HEAD/enlace/resultados en Issue #256 y la PR vinculada, separada de los resultados locales. Al preparar este registro: CI propia pendiente de ejecución.
- Sin merge, despliegues ni reinicio de Neon autorizados. El horario de merge sigue pendiente de aclaración: mención posterior 11:40 y acuerdo general hasta 18:00 Argentina del 30/10; no se resuelve por inferencia ni se ejecuta merge por el reloj. Revisión, CI verde y ensayo de versión desplegada siguen como controles, con despliegue/ensayo sujetos a autorización posterior. Publicar Web no incluye reiniciar la base.


## Plazo vigente informado por Martín — 30/10/2026, 11:11 Argentina

Martín informó que Martiniano flexibilizó el corte anterior de las 12:00: podemos continuar y completar integración, despliegue y verificación antes de las 18:00 Argentina del 30/10/2026. No se descarta automáticamente la entrega al pasar el mediodía. El corte de las 12:00 y las decisiones vinculadas a él se conservan abajo como históricos; esta actualización los sustituye únicamente en cuanto al plazo.

Se mantienen revisión del diff antes de publicar, CI verde y ensayo de la versión desplegada, sin omitir verificaciones por el horario. La ampliación de plazo no autoriza por sí sola publicación, reinicio de Neon, modificación de flags ni despliegue: cada operación se coordina según lo necesario. Una publicación Web no incluye reiniciar la base.

Se continúa desde la entrega local sobre cbcbf12, con analyze y 832 pruebas ya aprobados; no se repiten por este cambio documental. Siguen pendientes revisión del diff por Martín y Martiniano y autorización de publicación. CI/merge, único relanzamiento Web desde main y ensayo completo de la versión desplegada continúan como pasos posteriores sujetos a las coordinaciones correspondientes. Código, pruebas, flags y servicios reales intactos en esta actualización.


## Estado vigente — conexión local autorizada, 30/10/2026

Martín comunicó la confirmación de Martiniano para conectar CU-008, con la conformidad conceptual previa de Facundo informada por Martín. Esto habilita la implementación local de los tres archivos compartidos, no su publicación ni sustituye la revisión del diff final por Martín y Martiniano.

Hora inicial verificada: 13:02:49 UTC = 10:02:49 Argentina (UTC−03), antes del corte de las 12:00 del 30/10. Main remoto verificado por fetch: cbcbf12; actualización local por git merge --ff-only origin/main, sin conflictos ni commits nuevos. #251 (bfad0307) y #253 (75896ce3) conservados como ancestros. Respaldo previo de todos los cambios locales en .worktrees/cu008-respaldo-20261030-1002, fuera del worktree de implementación; no se alteraron ETA/RNF-008 ni la APK ensayada.

Conexión aplicada localmente:

- main.dart reutiliza HttpApiClient y SesionController; AusenciasApi recibe token capturado, callback y guardia estables por generación. Respuestas/401 tardíos de A no afectan B. Checkout y su flag se conservan.
- PasajeroShell invalida un alcance propio de ausencia al cambiar pestaña, antes de abrir sus rutas y al regresar. La guardia comprueba actividad además de sesión; no se reactiva un diálogo viejo al volver. La confirmación de ausencia no cuenta como salida de ruta.
- Mis reservas ofrece la acción solo para reserva propia consolidada recibida del GET. No aplica reglas locales sobre fecha, estado del viaje o abordaje. Feedback transitorio; reintento exige nueva confirmación.
- Se conserva la instancia de Mis reservas: versionReservas solicita las recargas existentes en vez de reemplazar toda la pantalla por key. Salir de pestaña/ruta no recarga por sí mismo ni destruye lista/saldo/detalle. Volver a la pestaña y el retorno de Checkout mantienen la recarga que ya existía. La recarga descarta cancelaciones anteriores mediante su generación de solicitud, preservando la protección anterior por desmontaje, sin cambiar sus reglas ni enviar cancelaciones desde ausencia.
- El componente retira únicamente su DialogRoute obsoleto al invalidarse/desmontarse, sin hacer pop de una nueva pantalla; descarta resultados tardíos. Invalidar la interfaz no cancela ni revierte una escritura ya procesada.
- Al volver se consultan solo los datos disponibles: GET reservas no expone ausencia y no existe GET ausencias. No se reconstruye el aviso, no hay persistencia local y POST nunca se usa como consulta.

El resto de este documento conserva el análisis/propuesta y coordinaciones anteriores como históricos: sus indicaciones de no editar o conexión no aplicada describen etapas previas, sustituidas por este estado vigente. Pruebas y resultados finales se registran en el contexto. Sin ensayo real/en pantalla, publicación, CI propia ni integración de esta entrega en main. Si no llega a estar revisada, integrada, con CI verde y verificada en pantalla antes de las 12:00, queda para después de la demo; no se omiten checks. CI/merge y un único relanzamiento Web desde main, seguidos del ensayo completo, son pasos posteriores a revisión y autorización, no ejecutados aquí.


30/10/2026. Base origin/main fb6e422. Esta propuesta NO está aplicada.
Mis reservas, PasajeroShell y main.dart permanecen intactos hasta coordinar con Martiniano y Facundo.

## Composición propuesta

- Bootstrap: crear AusenciasApi con el HttpApiClient existente, sin cliente ni sesión nuevos.
- Entrada pasajero: retener por generación un alcance Object y callbacks estables; capturar identidad de Sesion y generación. Guardia: bootstrap montado, misma generación e identical(sesion actual, capturada).
- Capturar token de esa sesión para AusenciasApi.informar(idViaje, accessToken: tokenCapturado). Comprobar vigencia inmediatamente antes de enviar y al retornar. Nunca guardar token como key ni en este documento.
- Propagar operación, alcance y guardia por PasajeroShell a MisReservasScreen.
- Mis reservas: montar AccionInformarAusencia solo en el detalle de reserva propia consolidada obtenido de GET /pasajeros/me/reservas, con idViaje de esa reserva. No inferir fecha, viaje abierto o abordaje: backend decide.
- Prioridad: invalidar únicamente el alcance de la acción al salir de pestaña o ruta, conservando la instancia y el estado del resto de Mis reservas (lista, saldo y detalle abierto). IndexedStack conserva hijos: la guardia debe incluir actividad de pestaña/ruta y una generación de acción que cambie en cada salida, de modo que salir y volver no reactive una confirmación anterior. Retirar su feedback transitorio y, si corresponde, desmontar solo la acción o cerrar su diálogo sin confirmar. El diálogo propio no cuenta como salida de la ruta. Coordinar la señal de actividad y su tratamiento de navegación antes de conectar; no recrear toda Mis reservas para resolverlo.
- Mantener el aislamiento existente KeyedSubtree por generación. Guardia adicional impide enviar desde diálogo viejo incluso antes del desmontaje. 401 compartido ya asociado al token de la petición; 403 se muestra como rechazo sin logout.

## Comportamiento y límites

Confirmación: libera lugar, no cancela reserva, recuperar lugar fuera de acción. El componente bloquea desde apertura de diálogo hasta resolución. Cerrar/Volver no envía. No hay envío automático.

200 y 201 son éxito con el mismo cuerpo; HttpApiClient no expone el código de éxito. Se muestra «Tu aviso de ausencia está registrado», sin afirmar creación nueva.

Errores contractuales 400/401/403/404/409 muestran mensaje del servidor. Red, 5xx o respuesta inesperada dejan resultado incierto: no afirmar que falló el registro. Nuevo intento exige otra confirmación explícita; backend devuelve 200 si ya existía.

GET de reservas no incluye ausencia y no existe GET de ausencias. Feedback transitorio únicamente; al reabrir no se reconstruye una marca. No POST para consultar, caché de ausencia ni deshabilitación permanente. Reserva, saldo, disponibilidad, recuperación y ausencia inferida intactos.

## Verificación de integración pendiente

Probar composición real con transporte simulado: entrada solo consolidada; cuerpo único id_viaje; 200/201; confirmación abierta al cambiar cuenta; respuesta/error/401 tardíos A→B; salida de pestaña y ruta; recarga sin marca local. Las pruebas aisladas no acreditan esa conexión ni ensayo físico.

## Fuentes

Especificación local v1.3 verificada, SHA-256 fce1f29f7ca621497cad0fd950429044e6adbfa80aee0fb98f9c5d2e6ea53df8. CU-008 conserva redacción anterior de viaje futuro/liberación condicional; AC28-06/09 y alcance acordado de #147 precisan liberación automática y aviso en_curso sin abordaje. No se modifica línea base.

#147 integrada en main (merge 0ee54a0); notas anteriores de PR pendiente son históricas. Sin cambios backend/OpenAPI/modelo/dependencias ni publicación.

## Superposición con Checkout #251 / #253 — consulta de solo lectura, 30/10/2026

Facundo informó #253 dependiente de #251 y ambos Draft. La consulta posterior por GitHub devuelve otro estado: #253 closed/merged, draft=false, merge 75896ce3caed7a1e3a28d10f0e20725b40e55c01 el 30/10 a las 03:55:33 UTC, hacia feat/admin-integracion-cu036-247; #251 closed/merged, draft=false, merge bfad0307433f2cf9434c9bea4c033a884255fdab a las 03:59:26 UTC, hacia main. Los cuerpos conservan redacción de Draft/aprobaciones pendientes: es información histórica distinta de los metadatos actuales. No se infiere aprobación funcional, activación o despliegue ni se incorpora ninguna rama.

Fuentes leídas: https://github.com/Martiherenu1/ProyectoVanFull/pull/251 y https://github.com/Martiherenu1/ProyectoVanFull/pull/253 (metadatos y diffs completos, extracción de hunks compartidos). HEAD #253 af8d71f7adc0e5982eadf0f49e138d8f863a8c5b, base A 10dd5bf29d195fdbb49ae1da55c8d9d1d0c2dea9; HEAD #251 75896ce3caed7a1e3a28d10f0e20725b40e55c01, base main fb6e422fa3695e85b014e0e3dd1876327b5136ed. Los diffs de ambas incluyen los mismos hunks de main.dart y PasajeroShell por la integración B→A: no son dos implementaciones independientes que deban aplicarse dos veces.

### Comparación y conexión compatible propuesta, NO aplicada

| Archivo / punto | Cambio observado de Checkout | Preparación CU-008 |
|---|---|---|
| main.dart, imports/campos/initState | CheckoutApi sobre httpClient existente, abrirCheckout y flag CHECKOUT_MP_ENABLED false por defecto | Agregar AusenciasApi sobre ese mismo cliente conservando Checkout, su flag y dependencias. Ausencias no depende del flag de pagos. |
| main.dart, entradaPasajero | Pasa de expresión a bloque; captura generacion/sesion y pasa contextoPagoVigente | Añadir callback ligado al token capturado y guardia propia de ausencias en ese bloque; conservar contextoPagoVigente y pantallaUbicacion. Retener alcance/callback por sesión: no crear Object nuevo en cada build. No reutilizar un nombre específico de pagos para la vigencia de ausencias. |
| PasajeroShell, constructor/campos | checkout, abrirCheckout y contextoPagoVigente opcionales | Agregar dependencias de ausencia en forma aditiva sin reemplazar las de Checkout ni modificar su semántica. |
| PasajeroShell, _registrarPago | Pasa iniciar/consultar/abrir/guardia a PagoScreen; finalizo y .then recargan reservas al regresar de Checkout sin terminar | Conservar flujo y recarga existentes. Invalidar únicamente alcance de ausencia antes de abrir Pago y demás rutas; al retornar, usar alcance nuevo, nunca reactivar diálogo anterior. La invalidación de ausencia no debe incrementar _versionReservas ni recargar lista/saldo por sí misma. |
| MisReservasScreen | Sin hunk en los diffs consultados de #251/#253 | La entrada CU-008 sigue pendiente de coordinación con Martiniano; ausencia de hunk no equivale a permiso. Conservar estado de lista/saldo/detalle y montar solo la acción. |

La guardia de sesión de Checkout no resuelve actividad de pestaña/ruta: una sesión puede seguir vigente después de salir y volver. CU-008 requiere generación propia de actividad más señal de pestaña/ruta activa, con excepciones para su diálogo de confirmación. El regreso de Pago puede recrear Mis reservas por su recarga preexistente; no eliminar esa conducta ajena ni usarla como mecanismo general de invalidación de ausencias.

Antes de implementar la conexión, coordinar con Martiniano y Facundo y volver a verificar main/HEAD efectivos; esta revisión está anclada a los SHA anteriores y no demuestra compatibilidad compilada de una combinación. Pruebas futuras: flag Checkout apagado/encendido, pago manual/Checkout conservados, abrir Pago/Ubicación y cambiar pestaña con confirmación abierta, salir y volver sin reactivación del diálogo, aislamiento de cuentas y conservación de lista/saldo/detalle cuando no corresponda una recarga preexistente. Sin fetch de ramas, merge/rebase/cherry-pick, edición de compartidos ni pruebas sobre combinación incorporada.

## Coordinación informada por Martín — Facundo conforme, Martiniano pendiente

Martín informó en esta conversación la conformidad conceptual de Facundo para conservar Checkout Pro, su retorno y recarga, invalidando únicamente la interacción de ausencia fuera de contexto. Esta conformidad no constituye revisión del diff ni reemplaza la coordinación pendiente con Martiniano. La atribución es indirecta: informada por Martín, sin afirmar una revisión directa o comentario de Facundo consultado en GitHub.

Sigue pendiente la coordinación de Martiniano para PasajeroShell y main.dart. Por instrucción expresa de Martín se mantienen también Mis reservas y esos dos archivos sin editar hasta recibirla. La conformidad de Facundo no sustituye esa coordinación ni autoriza publicación.

Invalidar la interfaz impide nuevas acciones fuera de contexto y descarta resultados tardíos; no cancela una escritura ya procesada por el backend ni revierte sus efectos. Al regresar pueden recargarse los datos que el contrato permite consultar, conservando el retorno y la recarga de Checkout Pro. Actualmente GET /pasajeros/me/reservas no expone ausencia y no existe GET de ausencias: esa recarga no permite reconstruir el aviso. No prometer reconstrucción del aviso, persistencia local ni usar POST /ausencias como consulta; solo se envía por una nueva confirmación explícita del pasajero.

No se actualizó la base local en este paso: continúa fb6e422. Antes de la conexión autorizada corresponde verificar main efectivo y conservar Checkout Pro al actualizar la base; no aplicar automáticamente los parches históricos de #251/#253. Sin incorporar ramas, commit, push o PR.
