# Contexto vivo · Chofer y viaje en curso (Martín)

## Validación local de #123 sobre #161 — 25/10/2026

- #159/#161 integradas, #152 cerrado; origin/main y base local `bd4ec6fc6b36a50f4e715ed8489ecf832359f414`.
  CI remota [40252289955](https://github.com/Martiherenu1/ProyectoVanFull/actions/runs/40252289955)
  completada con éxito, verificada por SHA. Composición de sesión/listado/detalle reutilizada, sin duplicación.
- Rama `docs/chofer-integracion-consulta-123`, worktree `.worktrees/chofer-integracion-doc-123`, actualizada
  mediante merge fast-forward, sin commits nuevos ni rebase. Los tres archivos locales se conservaron y
  respaldaron en Temp antes del merge, con hashes iguales. #163 abierta y no incorporada; otros worktrees intactos.
- Nueva prueba de circuito con VanFullBootstrap y transporte simulado: fecha/ID/token, retorno, 401/403/404,
  reintento, cambio de cuenta, respuestas tardías, generación, logout lento y cierre del transporte.
  Primero pasó la regresión original (1 prueba, 6 s); después el archivo completo: 21 aprobadas, 0 fallidas
  y 0 omitidas (19 s), incluida esa regresión. Callbacks iguales y 0 GET adicionales al reconstruir con
  detalle abierto y listado en la navegación. Archivo de pruebas preservado sin cambios ni expectativas rebajadas.
- Analyze nuevo sin observaciones (36,9 s), formato del test correcto y diff --check correcto.
  Logs ignorados frontend/cu123-161-{estabilidad,consulta,analyze}.log. Dependencias/lockfile intactos.
  No se repite ni se acredita suite completa local sobre bd4ec6f.
- Evidencia histórica de e9a1030: 20/21 de consulta; suite completa 522 aprobadas/1 fallida por callbacks
  (124 s), y 3 archivos de tema preexistentes señalados por formato global. No son resultados de la base nueva.
- Pendiente de callbacks de Facundo resuelto por #161; código compartido local intacto.
  SesionController/HttpApiClient siguen a cargo de Martiniano (#153). El usuario revisó el diff y autorizó
  publicar solo test/interfaz/contexto, sin merge. Esta entrega no cierra #123 ni declara CU-029 completo.
- Render SIN EJECUTAR: confirmar versión, cuenta y dataset con Martiniano antes de una prueba local de
  consulta/retorno/salida. Sin inicio/finalización ni GPS ni cierres de Issues. Publicación autorizada,
  pendiente de commit/push y PR al preparar este registro; CI del HEAD publicado se registrará en su descripción.
  CU-030, CU-008, #163, preview, demo y otros worktrees preservados. Evidencia histórica no se cuenta como nueva.

## Estado de publicación — CU-008, 2026-10-24

- Publicación autorizada por el usuario después de revisar el diff: creado [Issue #146](https://github.com/Martiherenu1/ProyectoVanFull/issues/146) tras buscar Issues/PR equivalentes; [PR #147](https://github.com/Martiherenu1/ProyectoVanFull/pull/147) abierta hacia main. Único cierre automático: `Closes #146`; #28 y los demás seguimientos permanecen independientes. Sin merge autorizado.
- Código, contrato y pruebas publicados mediante commit normal `3c1f64342c2214b4d349e9a38ead94ec486e8ccf`; esta actualización documental completa los ocho archivos revisados. Base de desarrollo conservada `3f0b04587fd8dc4c1a93acb0336c3c45845e459d`; main remoto consultado `c3059171dbedaf9f88c06a43656a3edc451f39de` con pagos/perfil, sin incorporarlo ni reescribir historiales. Push normal, sin rebase ni force.
- Los siete archivos de backend/contrato/pruebas coinciden con la entrega probada: no se repiten pruebas locales. Evidencia local histórica: 394 aprobadas; Ruff/formato y contrato correctos. La CI del HEAD final se registra por separado con URL y resultado real en la descripción de #147; en este registro previo al push documental está PENDIENTE, no se presume aprobada.
- Backend CU-008 implementado y publicado para revisión, todavía no integrado en main; Flutter pendiente. Abordaje y recuperación fuera de alcance; el futuro escaneo no debe recuperar lugar automáticamente. Sin cambios en demo, Render, Flutter, GPS ni otros trabajos. No hubo revisión formal registrada de otro integrante sobre la implementación ni mensajes a terceros.

## Preparación local histórica — aviso voluntario CU-008, 2026-10-24

- Implementación local sin commits en `feat/chofer-ausencias-cu008`, worktree `.worktrees/cu008-ausencias`, desde `origin/main` `3f0b04587fd8dc4c1a93acb0336c3c45845e459d` (incluye #133). Búsqueda por CU-008/ausencia sin Issue específico equivalente; #131 es la preparación del helper/locks. No se creó Issue por instrucción del usuario.
- Acuerdo de Martín, Martiniano y Facundo comunicado por el usuario: pasajero autenticado y reserva propia; alta solo consolidada, viaje programado/en_curso y sin abordaje. 201 al crear; 200 con la misma fila si existe aviso, incluso tras cancelar reserva/viaje o finalizar. Pertenencia antes del reintento, condiciones de alta después.
- Servicio, router y schemas de ausencias; contrato YAML/JSON actualizado con 200/201 y errores uniformes. Códigos: `RESERVA_NO_ENCONTRADA` (404); `RESERVA_NO_CONSOLIDADA`, `VIAJE_NO_ADMITE_AUSENCIA`, `PASAJERO_YA_ABORDADO` (409, en ese orden cuando no hay aviso). Validación 400 y permisos 401/403 compartidos.
- Protocolo §8 conservado: pasajero → viaje → reserva, helper `reserva_propia_del_viaje(..., bloquear=True)` con la sesión del llamador y sin commit propio; lecturas refrescadas bajo locks. Un commit del servicio; evento `ausencia_informada` ligado a la reserva solo en el alta. Cancelación y ejecución no modificadas.
- Sin cambios de reserva, disponibilidad, modelo/migración ni efectos económicos. La existencia del aviso libera cupo derivado; nunca se deduce ausencia por falta de abordaje. Recuperación fuera de alcance; futuro abordaje debe respetar el protocolo y no recuperar lugar por escaneo. Abordaje no implementado en esta entrega.
- Verificación local: `ruff check --no-cache .` correcto y `ruff format --check` de los cinco Python cambiados correcto; `pytest -q -p no:cacheprovider` completo: **394 aprobadas, 0 fallidas/omitidas**, 1 advertencia TestClient/httpx, 191,27 s. Incluye 36 pruebas CU-008: permisos/privacidad, altas/reintentos, cambios posteriores, reserva/cupo/efectos, rollback, locks retenidos y carreras con duplicados, cancelación, inicio/finalización y reservas del lugar liberado. Código montado en solo lectura, PostgreSQL 16 descartable exclusivo y bases `vf_test_*`, sin usar la base de desarrollo/demo. YAML/JSON válidos, equivalentes y sin claves YAML duplicadas; `git diff --check` correcto.
- Límites: sin Flutter, GPS, demo/Render ni otros worktrees modificados; sin commits, publicaciones, mensajes ni merge. CI remota y uso desde cliente real: SIN VERIFICAR.

## Publicación independiente — densidad del detalle CU-029, 24/10/2026

- Publicación autorizada por el usuario: [PR #139](https://github.com/Martiherenu1/ProyectoVanFull/pull/139) abierta hacia main; commit `f2bd16df972d54e57a4042c2039b27d7a99bd144` y push normal de `fix/chofer-densidad-detalle-main-cu029`. Base `f1f78ffbd98fd9d7601a5a50a37af9d5868316b5`, sin cambios desde los checks. No se encontró PR equivalente. Este último commit documental actualiza el estado publicado; el resultado real de CI del HEAD final se registra en la descripción de #139, separado de las 117 pruebas pertinentes locales. No se repiten checks por cambios exclusivamente documentales.
- Solo tres archivos: pantalla, pruebas y contexto propio. Las 117 pruebas son una selección pertinente, no una suite completa; el intento completo anterior interrumpido no acredita aprobación. `Refs #123`, sin cierre de #123/#64. PR sin merge. Preview, #128, otros worktrees, demo, código compartido y dependencias intactos.

## Registro previo a publicación — preparación independiente, 24/10/2026

- Rama `fix/chofer-densidad-detalle-main-cu029`, worktree `.worktrees/chofer-densidad-main-cu029`, desde `origin/main f1f78ffbd98fd9d7601a5a50a37af9d5868316b5` actualizado. Cero commits propios; sin merge/cherry-pick de ramas de trabajo. Se conserva el contexto de main y solo se agrega este registro puntual. Sin commits, push, PR nueva ni publicaciones.
- Parche compatible: la pantalla actual ya incorpora `comprobarUbicacionInicio`; se conserva íntegro. Solo cambia `_titulo` (16 px arriba / 8 px abajo) y `_fila` (altura natural, padding vertical 4 px por lado). Pasajeros, controles interactivos de 64 px, tema, sesión, ubicación y dependencias intactos. Entrega independiente hacia main, sin dependencia de #128; no se traslada su shell, interfaz ni registro de publicación.
- Mejora de usabilidad, sin falla funcional: el usuario confirmó «los datos quedan más juntos y cómodos de leer» en la preview anterior. No acredita manualmente anchos, escalas, otros escenarios ni el circuito completo. No se atribuye una revisión visual nueva a esta combinación.
- Se trasladan únicamente el ajuste visual y sus pruebas: altura de texto + 8 px y crecimiento con nombres largos al 200 %, sin recorte y con desplazamiento hasta nómina. Verificaciones nuevas sobre esta combinación: pub get offline con lockfile exigido correcto; formato final de dos Dart sin cambios; analyze sin issues (119,6 s); 117 pruebas pertinentes aprobadas, 0 fallidas/omitidas (detalle, acciones y coordinador; 30 s). Log local: frontend/build-densidad-main-tests.log. Git diff --check correcto; dependencias/lockfile iguales a main. No se presenta la evidencia anterior de 51 como ejecución sobre main actual. La suite completa local anterior interrumpida no acredita aprobación completa.
- Propuesta con `Refs #123`, sin cerrar #123/#64; borrador local conforme a plantilla. Preview, trabajos previos y PR abiertas preservados. Sin backend/HTTP real, instalación en teléfono, demo ni mensajes a terceros.

## Actualización de PR #121 — 24/10/2026

- Worktree de #118 limpio y coincidente con HEAD remoto `0c98c1afbebdd55459894ca6be8696d3bd85434c`
  antes del merge. Se incorpora origin/main `f1f78ffbd98fd9d7601a5a50a37af9d5868316b5`
  mediante merge, sin rebase ni force. Único conflicto: contexto; ambos historiales conservados.
- #115 ya integrada en main, al igual que #87/#103/#109. Sus cambios de control previo y
  dependencias se incorporan sin modificaciones propias. Adaptador HTTP y sus pruebas intactos;
  el diff revisado de #121 contra main contiene solo servicio, pruebas y contexto de #118.
- Combinación actualizada: pub get offline con lockfile exigido correcto; formato de 14 Dart,
  cero cambios; analyze sin problemas (38,6 s); 403 pruebas aprobadas, 0 fallidas/omitidas
  (87 propias + 316 de base; 104 s). Avisos preexistentes de Google Fonts sin fallas.
  Primer intento de test falló al limpiar build/unit_test_assets, antes de ejecutar casos;
  directorio preservado en .dart_tool y suite repetida correctamente. Logs ignorados
  frontend/cu030-121-merge-{analyze,test,test-preparacion-fallida}.log.
- Las 349 pruebas y la CI de `0c98c1a` son evidencia histórica. La CI remota del nuevo HEAD
  y la conservación de la aprobación se registran tras el push en la descripción de PR #121.
- Aprobación de Facundo observada antes de actualizar: APPROVED sobre `0c98c1a`, 24/10/2026;
  se comprobará su conservación en GitHub después del push, sin atribuirla al nuevo código/base.
- PR #121 abierta con cierre exclusivo de #118, sin merge autorizado. Sin POST reales, demo,
  integración productiva ni dispositivo; CU-030 sigue parcial. Otros worktrees preservados.
- Los registros inferiores son históricos: referencias a PR abiertas, bases anteriores y
  publicaciones pendientes describen sus fechas y no sustituyen este resumen vigente.

## Registro histórico — adaptador HTTP CU-030 / #118, 23/10/2026

- Entrega revisada, con commits y publicación autorizados el 23/10/2026 por Martín.
  Rama `feat/chofer-http-ejecucion-cu030-118`, worktree `.worktrees/cu030-http-118`,
  desde main remoto `792792cdb35cf861b116e8907cdfe9d9ec1929ac`. #87/#103 ya integradas.
- `EjecucionViajeApi.iniciar/finalizar` compatibles con CambiarEstadoViajeChofer: ApiClient externo
  con base /api/, POST sin body, ViajeResumen e ID comprobado. Inicio admite en_curso/finalizado;
  finalizar admite finalizado. Conserva el estado recibido, sin inferir una transición nueva.
- ApiException contractual 400/401/403/404/409 se traduce a RechazoOperacionViaje con motivo/código;
  transporte, timeout, 5xx, protocolo o respuesta incompatible son ResultadoViajeIncierto.
  Sin reenvíos automáticos, sesión propia ni cierre de transporte; reconciliación de #103 intacta.
- Verificación: formato correcto (2 Dart, cero cambios finales); analyze sin problemas (30,4 s).
  Suite Flutter: 349 aprobadas, 0 fallidas/omitidas (87 nuevas + 262 de base; 89 s).
  Pub get offline con lockfile exigido y diff --check correctos; dependencias/lockfile intactos.
  Avisos preexistentes de Google Fonts sin fallas. Logs ignorados frontend/cu030-118-{analyze,test}.log.
- Main y código coinciden con la verificación local anterior; no se repitieron los checks al publicar.
  Estado de publicación y CI remota del HEAD publicado: consultar la PR vinculada en #118;
  sus resultados se registran separados de las 349 pruebas locales. Cierre exclusivo de #118, sin merge.
- Sin POST reales, demo, integración productiva ni dispositivo. Navegación y GPS fuera de alcance;
  sin modificaciones de #113/#115 ni otros trabajos. CU-030 sigue parcial.
  Los registros inferiores son históricos y conservan el estado de sus fechas.

## Registro histórico — control previo de ubicación, 2026-10-23
## Estado vigente al 23/10/2026 — adaptador HTTP del detalle CU-029

- Integración vigente del 23/10/2026: pendiente documental preservado en `a754fc890a61776eea977bb9b9d2b434749461f3`; main verificado `fa2264c4347655e20ab70a9c689c4e99fe06e15b` (#109 integrada) incorporado por merge `e5f6057536cca86fa668ec52be2092386eb0b42e`. Único conflicto documental resuelto conservando el registro local y el contexto de main completo; sin cambios de comportamiento, rebase ni force. Adaptador y sus 19 pruebas intactos; diff propio limitado a esos dos archivos y este contexto. Interfaz CargarDetalleViajeChofer compatible mediante exportación de la pantalla. Formato: dos archivos, cero cambios; analyze sin issues (14,8 s); suite secuencial: **265 aprobadas, 0 fallidas/omitidas** (19 propias + 246 de main; aproximadamente 98 s). Dependencias/lockfile iguales a main, sin pub get adicional; avisos preexistentes de Google Fonts sin fallas. Sin conexión de pantallas, HTTP real, dispositivo, demo, cambios GPS/control de ubicación u otros worktrees. Publicación autorizada por el usuario el 23/10/2026: se reutiliza #110 y se prepara PR con cierre exclusivo de #110, sin merge autorizado; #64 permanece independiente. CI del HEAD publicado pendiente de verificar y registrar en la PR. Los registros siguientes son históricos.
- Issue [#110](https://github.com/Martiherenu1/ProyectoVanFull/issues/110), rama `feat/chofer-http-detalle-cu029`, base inicial `4d8213a3112bc08c9794366b5d4c1a9a7314b5f1`. #110 ya existía al retomar; se reutiliza el worktree separado sin duplicar tarea ni publicar cambios. Cliente común #87 y detalle #89 presentes en esta base; los registros inferiores son históricos.
- `DetalleViajeChoferApi.cargarDetalle(int)` usa `ApiClient` externo con base `/api/`, devuelve `OperacionAsignada` y traduce exclusivamente `ApiException` 404 a null. Otros errores se propagan sin reintentos; DTO inválido o ID distinto produce `DetalleViajeInvalidoException` con mensaje fijo y sin datos recibidos.
- Pruebas con transporte simulado: ruta GET, token externo vigente, callback compatible, orden/listas/cantidades, horario omitido y nullable, 404 y demás errores, JSON/DTO inválidos, ID distinto y comprobación explícita de transporte externo abierto tras éxito/error.
- Sin cambios en backend, contrato, modelo, dependencias, sesión o navegación. Sin fotografías descargadas, HTTP real ni prueba en dispositivo; CU-029 no se declara completo. Conexión de pantallas sigue pendiente; listado HTTP #104 es una entrega independiente.
- Evidencia previa a la integración: formato correcto (dos archivos, cero cambios); `flutter pub get --enforce-lockfile` correcto y lockfile intacto; `flutter analyze --no-pub` sin issues; `flutter test --no-pub --concurrency=1 --reporter expanded`: 148 aprobadas (19 nuevas y 129 de base), sin fallidas/omitidas; 19 del adaptador también aprobadas aisladamente. Primer intento concurrente interrumpido tras demorarse sin progreso, sin resultado completo. Avisos preexistentes de Google Fonts sin fallas. Ese cierre previo no agregó commits ni publicaciones. Sin CI remota de esta entrega.

- Actualización local del 23/10/2026: tres archivos revisados preservados en `2c4acf1b801843052705b59b64032fc54392db11`; `origin/main 9d635a5f43431d5c7005050f1a2c22edf37d6e6c` incorporado por merge `13b1f6a26d0a6e4895b0e837e695661b03ca2cbf`, sin conflictos, rebase ni force. Ambos historiales conservados. #99 agrega únicamente pantalla/pruebas/contexto administrativos. Adaptador y pruebas propios intactos; dependencias y lockfile iguales a main. Verificación sobre la combinación: formato correcto y analyze sin issues; `flutter test --no-pub --concurrency=1 --reporter expanded`: 154 aprobadas (19 propias y 135 de main, incluidas 6 de #99), 0 fallidas/omitidas, en aproximadamente 100 s. Avisos preexistentes de Google Fonts sin fallas. Sin push, actualización de #110, PR, merge remoto ni intervención en #103, #109, GPS, otros worktrees o demo.
## Actualización con main — PR #128, 24/10/2026 (sin merge de la PR)

- Desde HEAD publicado `7ffca530eba2eae2505202a41d1d0d3946da190d`, se incorpora `origin/main f1f78ffbd98fd9d7601a5a50a37af9d5868316b5` mediante merge `7d8304c359144c1ea925afd671dac31582aca3f7`, sin rebase ni force push. Único conflicto: contexto documental; se conservaron ambos bloques e historiales, comprobando que todos sus renglones no vacíos permanecieran. Sin conflictos productivos ni adaptaciones propias de código.
- Sobre esta combinación: pub get offline con lockfile exigido correcto; formato de los dos Dart propios, cero cambios; analyze sin issues (22,8 s); **85 pruebas pertinentes aprobadas**, 0 fallidas/omitidas (41 s): pantallas Chofer y adaptador del listado, con fuentes/transporte simulados. Log `frontend/build/chofer-consulta-main-actualizado-tests-final.log`. Primer intento sin ejecución por carpeta generada unit_test_assets de solo lectura; preservada mediante renombrado dentro de este worktree y repetición correcta. No se acredita suite completa local; la evidencia histórica de 51 corresponde a bases anteriores.
- Diff propio contra main: shell, pruebas del shell, interfaz y contexto. Shell/pruebas/interfaz intactos respecto del HEAD previo; archivos compartidos, control de ubicación, dependencias y lockfile coinciden con main. Sin cambios de preview, #139, otros worktrees o demo. Sin login/solicitudes reales ni merge de #128. Actualización y push normal autorizados; CI del nuevo HEAD se registra en la descripción de la misma PR, separada de estos resultados locales. #123/#64 no se cierran.

## Registro histórico al 24/10/2026 — publicación inicial de ChoferShell en PR #128

- Publicación autorizada por el usuario: cuatro archivos revisados preservados en `918a213`; main remoto `51b1b4da8a1cbd35c2e07271cbf7c71f95faeb62` incorporado mediante merge `8bfa1bd763aa03656a225ed8c79ee779215d4868`, sin conflictos, rebase ni force. Push normal realizado y [PR #128](https://github.com/Martiherenu1/ProyectoVanFull/pull/128) abierta hacia main, con `Refs #123` y sin cierre automático. El último commit documental actualiza este estado; CI del HEAD final se registra en la PR, separada de las pruebas locales.
- Sobre la combinación con main: formato de dos Dart, cero cambios; analyze sin issues (28,4 s); 51 pruebas pertinentes aprobadas, 0 fallidas/omitidas (31 s), log `frontend/build/chofer-consulta-tests-main.log`. Se conserva debajo la evidencia de 51 sobre base `792792c`; la suite completa anterior interrumpida NO acredita aprobación completa. No se repiten pruebas por esta actualización exclusivamente documental.
- Diff propio limitado a shell, sus pruebas, interfaz y contexto. Código compartido/dependencias/lockfile iguales a main; sin llamadas reales, cambios de otras PR/worktrees o demo, ni mensajes a terceros. #113 sigue abierta al verificar: condiciona solo la futura conexión HTTP, no esta publicación. #123 y #64 continúan abiertos; integración común pendiente. No se mergea esta PR.

## Registro previo a publicación — componente de consulta Chofer #123 (parcial)

- Rama `feat/chofer-integracion-cu029-123`, base `792792c`, worktree `.worktrees/chofer-integracion-123`. Usuario autoriza únicamente componentes propios. Reparto confirmado: Facundo composición/inyección/transporte/router; Martiniano autenticación/sesión/token/roles; Martín pantallas y adaptadores Chofer. Sin commits, push ni publicaciones.
- ChoferShell reutiliza listado y detalle por ID con fuentes externas, conserva fecha/listado al volver (incluido botón del sistema), evita apilar selecciones duplicadas y delega salida mediante callback también durante carga. Sin acciones CU-030 ni GPS. Reconstruir con fuentes iguales no recarga; reemplazarlas explícitamente actualiza las rutas y descarta resultados anteriores.
- Interfaz y responsabilidades: `frontend/lib/screens/chofer/INTEGRACION-CONSULTA.md`. El contenedor común aporta fuentes estables, maneja/notifica 401/403, retira el shell al cambiar sesión y posee/cierra el transporte. No se implementa política de acceso propia. Archivos compartidos y dependencias intactos; otras ramas, demo y datos preservados.
- PR #113 verificada el 24/10/2026: abierta, sin merge, HEAD `e4ac0ac`. No se copió su adaptador; dependencia HTTP del detalle explícita. Pruebas con fuentes simuladas (adaptador listado: transporte simulado), sin solicitudes reales.
- Checks finales: formato de dos Dart, cero cambios; analyze sin issues (24,6 s); 51 pruebas pertinentes aprobadas, 0 fallidas/omitidas (6 shell + 9 listado + 17 detalle + 19 adaptador listado; 28 s), log `frontend/build/chofer-consulta-tests-final.log`. Primera ejecución de analyze detectó uso protegido del notificador y estilo de funciones, corregidos y checks repetidos sobre versión final. Dependencias/lockfile sin cambios. No se ejecutó la suite completa nueva.
- Evidencia histórica: suite completa anterior interrumpida con Ctrl+C después de 233 aprobadas, sin resultado final y causa SIN VERIFICAR; NO acredita aprobación completa. Las 2 pruebas aisladas previas no sustituyen los checks finales indicados arriba.
- Entrega parcial: no cierra #123 ni #64. Integración común, #113, HTTP real, dataset/cuentas/versionado de Render con Martiniano, dispositivo y demo siguen pendientes; sin login ni solicitudes operativas reales. Contexto general y de otras áreas no editados.
## Resumen vigente — control previo de ubicación, 2026-10-23

- Entrega de revisión vinculada a [Issue #114](https://github.com/Martiherenu1/ProyectoVanFull/issues/114), rama feat/chofer-control-ubicacion-cu030; PR hacia main con cierre exclusivo de #114. #64 permanece independiente; CU-030/GPS no completos. Publicación autorizada mediante push normal, sin merge. Vínculo de PR, HEAD publicado y resultado real de CI se registran en la descripción de la PR vinculada al Issue.
- Base fa2264c4347655e20ab70a9c689c4e99fe06e15b, #103/#109 integradas. Preservación 90b32ca y merge b44c6da; este commit documental completa el procedimiento y el contexto de la entrega. Ambos historiales anteriores se conservan debajo como registros de su momento.
- 17 archivos revisados; código/base/dependencias sin cambios desde la verificación: formato correcto, analyze sin problemas, 300 pruebas locales aprobadas y APK técnica compilada. Ajustes editoriales sin repetir suites/build. Permisos mínimos COARSE/FINE, sin MainActivity/tema/navegación común/backend modificados.
- Acuerdo: servicio activo y permiso concedido antes de iniciar/repetir; aproximado admitido, sin primera posición. Bloqueo local no resuelve POST incierto; finalizar no consulta GPS. Adaptador real y operaciones simuladas; sin HTTP, captura/envío ni seguimiento integrado.
- Observaciones de Martín son de la tanda anterior sobre base 16b0d35 y hash identificado en procedimiento, no nueva prueba física de esta compilación; contador 1 → 0 de causa desconocida y aclaración de pulsación explícita conservados.
- Ensayo original, otros worktrees y demo preservados. Sin instalación en teléfono, POST reales ni mensajes a terceros. CI remota se verifica en GitHub sobre el HEAD publicado; el resultado no se infiere de las verificaciones locales.



## Sincronización del control previo con main — 2026-10-23

- Main remoto verificado fa2264c4347655e20ab70a9c689c4e99fe06e15b: #103 y #109 integradas, sin dependencia de PR abierta. Trabajo preservado en 90b32ca15a30265cb8b38cbc2764bfd999bfe7ae; merge local b44c6dabf4b486be088c85dd443ab2f1e94edff5, sin rebase/push. Ambos historiales conservados debajo; conflictos de contexto/pubspec resueltos conservando ambas adiciones, http y geolocator 14.1.2. Las 59 dependencias previas de main mantienen versiones/contenido; solo paquetes necesarios del plugin añadidos.
- Control/adaptador/entrada técnica sin cambios funcionales: ubicación activa y permiso concedido (aproximado admitido), sin primera posición/requestPermission/inicio al volver de Ajustes; finalizar no consulta GPS y bloqueo local no resuelve incertidumbre previa. Teléfono real y operaciones simuladas; sin HTTP, captura/envío ni navegación productiva.
- Nueva combinación: formato de 12 Dart, 0 cambios; analyze sin problemas (20,0 s); 300 pruebas aprobadas, 0 fallidas/omitidas (~62 s); APK técnica debug compilada (131,6 s). Advertencia de metadatos SDK XML sin fallo; Gradle/JDK/MainActivity intactos. Manifiesto fusionado/empaquetado revisado, solo COARSE/FINE más INTERNET debug y permiso interno AndroidX, sin permisos de captura. Logs F:/dev/vanfull-cu030-merge-{pubget,analyze,test,build}.log.
- APK SHA-256 8a3c579eafe70ed40b0633654fe27c1ef2c93d69a6967ba7ec9567c06173d483, igual al anterior; sin instalación ni conexión al teléfono en esta tarea. Observaciones manuales siguientes corresponden a la tanda anterior sobre base 16b0d35 y ese hash, no a una nueva prueba física. Se conserva contador 1 → 0 de causa desconocida y aclaración de pulsación explícita; sin validación de circuito completo/seguimiento.
- Búsquedas por control previo/geolocator/permiso/ubicación sin Issue específico equivalente; #110/#113 corresponden al adaptador HTTP del detalle y excluyen el control GPS. Borradores actualizados y diff final contra fa2264c en F:/dev/vanfull-cu030-revision-main-fa2264c; único cierre futuro: Issue específico por asignar, no #64. Documentación de esta sincronización queda local sin commit; sin publicaciones, backend, demo u otros worktrees modificados.



## Cierre local para revisión — 2026-10-23

- Base conservada: 16b0d3593803d72d48020b7daaab8b2d49d38fe9; #103 sigue abierta y conserva ese HEAD, dependencia explícita. Main remoto ahora 4d8213a3112bc08c9794366b5d4c1a9a7314b5f1 (#95/#106/#97/#87), con cambios compartidos y pubspec/lockfile; no incorporado. Sincronización/verificación de la combinación posteriores; no se atribuyen las 230 pruebas a main nuevo.
- Código/configuración/pruebas coinciden con el diff previamente verificado; cuatro archivos productivos revisados y hash de la APK conservados. Solo documentación posterior; suites/build no repetidos. Ensayo original/historial y otros trabajos preservados.
- Búsquedas de Issues/PR por ubicación, geolocator, control previo y CU-030 sin tarea específica equivalente; #102/#103 cubren las acciones de base. Diff final y borradores conforme a plantillas en F:/dev/vanfull-cu030-revision-2026-10-23. Único cierre futuro: Issue específico aún sin número, no #64. Sin commits, publicación, teléfono ni cambios de código.
## Observaciones manuales del control previo Android — 2026-10-23

- Martín, Samsung Galaxy S20+ 5G / Android 13, nueva APK actualizada y abierta tras autorización y comprobación de hashes/ADB. Servicio apagado: mensaje orientativo, inicios 0; reactivarlo sin pulsar conserva Programado/0; pulsación explícita → En curso/1; finalizar con Ubicación apagada → Finalizado/1.
- Permiso denegado: mensaje orientativo, Programado y contador observado 0, sin comparación entre sesiones. Permiso mientras se usa con ubicación precisa desactivada: volver de Ajustes conserva Programado; contador 1 → 0, causa no determinada. Pulsación explícita con aproximado: Programado → En curso, 0 → 1; finalización confirmada: Finalizado/1.
- La aparente observación de inicio automático se aclaró: Martín había pulsado Iniciar; no se registra como defecto. Condiciones reales del teléfono, operaciones/viajes simulados; observaciones manuales detalladas en frontend/technical/gps-probe.md. Sin HTTP, captura/envío GPS ni validación del circuito completo. Demás escenarios pendientes. Registro documental únicamente, sin código, repetición de pruebas, compilaciones o publicaciones; evidencia histórica anterior preservada.
## Adaptador Android del control previo — 2026-10-22

- Base sigue en 16b0d35 (#103 abierta, sin merge), main remoto a86ce5a. Misma rama/worktree feat/chofer-control-ubicacion-cu030 / F:\dev\vanfull-cu030-ubicacion. Diff revisado previo preservado en F:\dev\vanfull-cu030-ubicacion-pre-adaptador.diff; hashes de sus cuatro archivos productivos sin cambios. #103 y ensayo GPS original intactos.
- Adaptador ComprobadorUbicacionAndroid: solo consulta permiso y servicio reales con geolocator 14.1.2 (Android 5.2.1); whileInUse/always permiten, incluido aproximado, demás estados no. Errores bloquean mediante el controlador revisado. Sin requestPermission, precisión, posiciones, streams ni captura/notificación; Manifest fuente solo COARSE/FINE. Sin MainActivity ni lógica de incertidumbre/finalización modificados. Dependencias existentes conservan versiones.
- Entrada técnica independiente con detalle/acciones existentes: «Operaciones simuladas: sin backend», contador acumulado de inicios simulados, Ajustes por acción explícita y nuevo escenario ficticio. Volver no inicia automáticamente. Control del teléfono real; viajes/operaciones en memoria; captura/envío y seguimiento GPS pendientes.
- Analyze sin problemas (14,4 s); suite: 230 aprobadas, 0 fallidas/omitidas (~54 s), 18 nuevas (13 adaptador + 5 entrada), sin repetir pruebas físicas. APK debug compilada (80,2 s); manifiesto fusionado/empaquetado revisado: COARSE/FINE, INTERNET debug e interno signature AndroidX, sin permisos foreground/background/notificación. Descarga runtime de fuentes deshabilitada solo en entrada técnica. APK no instalada ni abierta. applicationId com.vanfull.frontend coincide y reemplazaría el ensayo anterior si se autoriza instalar con reemplazo.
- Procedimiento actualizado en frontend/technical/gps-probe.md: nueva sección para este control e historial documental del ensayo original preservado, sin copiar su código de captura ni modificar su worktree. Hash y ubicación APK registrados en el procedimiento. Pendiente: prueba física posterior autorizada; sin backend, contrato/modelos, navegación, demo, commits o publicaciones.

## Control previo inyectable de ubicación — 2026-10-22 (etapa previa al adaptador)

- Estado: implementado localmente con dobles; sin adaptador Android, geolocator, captura/envío ni seguimiento GPS integrado. Rama feat/chofer-control-ubicacion-cu030, worktree F:\dev\vanfull-cu030-ubicacion. Sin commits, publicaciones, instalaciones de herramientas, compilación Android ni POST reales.
- Base verificada: main remoto a86ce5a2f8d8c657d198108367c24500116a617b; #103 abierta, sin merge, HEAD 16b0d3593803d72d48020b7daaab8b2d49d38fe9. El nuevo worktree parte de ese HEAD como dependencia explícita. #103, ensayo GPS y demás trabajos preservados.
- Fuente cotejada íntegramente: F:\TIN\One Drive\OneDrive\Escritorio\UM\TC\03 Actores y Casos de Uso\03_Especificaciones_Casos_de_Uso_VanFull_v1.3_Aprobado_Equipo.md, CU-030 (precondiciones, flujo principal, A1/A2/A3 y postcondiciones). No se sustituye por v1.1 ni se modifica la fuente aprobada. CU-030 contempla autenticación/asignación/vehículo y ejecución/GPS; el control previo local responde al acuerdo posterior del equipo.
- Acuerdo confirmado por los tres integrantes, comunicado por el usuario: servicio de ubicación activo y permiso concedido antes de solicitar inicio; bloquear y orientar si falta cualquiera. Incluye permiso aproximado; no primera posición, señal, precisión mínima, frecuencia ni espera. Sustituye la propuesta anterior de primera posición; no es nueva validación de VanFull ni del servidor.
- Inyección en DetalleViajeChoferScreen y EjecucionViajeController: consulta asíncrona antes de inicio y reintento explícito de inicio; bloqueo desde antes del primer await e invalidación por viaje/comprobador/fuente/acciones/desmontaje. Sin comprobador: «No se pudo comprobar la ubicación». Servicio apagado, permiso denegado y fallo de consulta tienen los mensajes acordados. Sin solicitudes de permisos ni apertura automática de Ajustes.
- Un fallo local no invoca inicio, no marca operación enviada ni genera un POST incierto. Una solicitud anterior incierta y las confirmaciones del servidor se conservan; consultar programado o recibir un rechazo posterior no resuelve esa solicitud. Finalizar y repetir finalización no consultan ni dependen de GPS. Cambiar condiciones/comprobador no inicia automáticamente.
- Verificación: formato de siete archivos Dart correcto; analyze final sin problemas (5,5 s); suite Flutter: 212 aprobadas, 0 fallidas/omitidas (~36 s): 176 de base + 29 nuevas del controlador + 7 nuevas de pantalla. Los casos previos de CU-030 inyectan explícitamente un comprobador habilitado; los POST en vuelo se distinguen de la nueva consulta previa. Se corrigieron tres avisos de estilo antes de ejecutar la suite; persisten avisos preexistentes Google Fonts sin fallas.
- Dependencias y lockfile intactos; configuración local del nuevo worktree generada con pub get --offline --enforce-lockfile usando caché existente, sin descargas de paquetes. Logs externos F:\dev\vanfull-cu030-ubicacion-analyze.log y F:\dev\vanfull-cu030-ubicacion-test.log. Sin contrato, modelos, backend, Manifest, MainActivity, navegación o demo modificados.
- Pendientes: coordinar integración posterior de #103 y este cambio; adaptador de condiciones reales del teléfono e integración HTTP/autenticación comunes, pruebas físicas y armonización documental de CU-030/GPS (#39/#63 y prompt). Estas pruebas con dobles no verifican GPS real ni seguimiento. No se atribuyen permisos Android ni resultados físicos al comprobador simulado.

## Registro histórico al 22/10/2026 — CU-030 actualizado sobre main

## Estado al 23/10/2026 — actualización de PR #109

- Rama `feat/chofer-adaptador-listado-cu029`, worktree `F:/dev/vanfull-cu029-adaptador`, limpia antes de actualizar y coincidente con HEAD remoto `6eef07436aa4defed0afa961a2b717331a38df8c`. Se incorpora `origin/main 6e39d5f129ac3c9cc999594d58749ab0d11691b4` mediante merge, sin rebase ni force. #103 ya integrada y #102 cerrado; #109 continúa abierta para #104; #64 permanece independiente.
- Único conflicto: encabezados del contexto propio. Resolución conserva los registros del adaptador y de CU-030 y el historial compartido, sin decisiones nuevas ni cambios productivos propios. Código de adaptador intacto; ejecución CU-030 y administración incorporadas desde main. No se modifica el adaptador HTTP local del detalle, control de ubicación, ensayo GPS, otros worktrees ni demo.
- Verificación local sobre la combinación: formato de nueve Dart afectados correcto (cero cambios), analyze sin problemas (15,2 s), suite completa **246 aprobadas, 0 fallidas, 0 omitidas** (19 del adaptador y 227 de base; aproximadamente 44 s). Logs externos `F:\dev\vanfull-pr109-main-analyze.log` y `F:\dev\vanfull-pr109-main-test.log`. Avisos preexistentes de Google Fonts sin fallas. Dependencias/lockfile intactos respecto de ambos padres (SHA-256 `e84e212075a243e36c6f16d23d34f7720a992fd82e3cdd76ecfb5502f8149b7e`); no se repitió pub get. La aprobación formal de Facundo sobre `6eef074` es evidencia histórica; su vigencia y la CI se consultan nuevamente sobre el HEAD actualizado. Sin merge de #109 autorizado en esta actualización. Integración real/HTTP/dispositivo siguen SIN VERIFICAR.

## Registro previo al merge — adaptador del listado CU-029 (23/10/2026)

- Base `origin/main 4d8213a3112bc08c9794366b5d4c1a9a7314b5f1`; #87 integrada, interfaz compartida revisada. Rama `feat/chofer-adaptador-listado-cu029`, worktree `F:/dev/vanfull-cu029-adaptador`.
- `ViajesChoferApi.cargarViajes(DateTime)` recibe ApiClient externo: base con /api/, ruta /choferes/me/viajes y fecha por year/month/day sin conversión horaria. Reutiliza ViajeResumen y conserva orden, vacío y horario omitido; propaga errores HTTP/transporte sin reintentos ni cierre del cliente.
- Estructura/DTO inválidos: ListadoViajesInvalidoException con mensaje fijo y sin datos recibidos, sin listado parcial. Sin cambios de navegación, pantallas, sesión, dependencias, lockfile, backend, README, #103 ni GPS; sin llamadas reales. Sin commits/publicaciones por instrucción del usuario.
- Checks locales: pub get offline con lockfile exigido correcto; formato final de dos archivos correcto (cero cambios); analyze sin issues (17,7 s). Suite Flutter: 148 aprobadas, 0 fallidas, 0 omitidas (19 nuevas, 129 de base; 58 s). Avisos preexistentes de Google Fonts sin fallas; diff de dependencias/lockfile vacío.
- Pendiente: conectar el adaptador desde el contenedor externo en una tarea posterior; integración real y dispositivo SIN VERIFICAR. Los registros inferiores son históricos (detalle #89 ya integrado en esta base).

## Registro histórico al 22/10/2026 — CU-030 actualizado sobre main

- Publicación autorizada el 22/10/2026: búsqueda sin Issue/PR Flutter CU-030 equivalente; creado [Issue #102](https://github.com/Martiherenu1/ProyectoVanFull/issues/102), etiqueta chofer. Ajuste guardado mediante commit normal `a172ea5401df468dddd118b8625e917762f23cf6`; código/base coinciden con la verificación local de 176 (92 propias y 84 base), por lo que no se repiten checks. `origin/main` sigue en `a86ce5a`; sin merge adicional. Se prepara PR hacia main con cierre exclusivo de #102 y referencias #66/#89/#88/#64/#81. CI del HEAD publicado por verificar en GitHub; la aprobación de #89 no se hereda. Sin revisión formal de otro integrante para CU-030 al preparar la publicación; la revisión manual Web fue anterior al ajuste. Entrada temporal excluida; sin merge remoto, demo ni otros worktrees.
- Ajuste acotado posterior sobre HEAD local `c38a07e`, guardado posteriormente en `a172ea5`: `actualizarContexto()` conserva el Viaje confirmado si no cambia el ID y lo limpia al cambiar de viaje; mantiene invalidación por generación. GET regresivos mantienen listas ocultas, acciones bloqueadas y «Actualizar detalle»; igualdad y avance en_curso → finalizado siguen aceptados. Sin reglas nuevas ni cambios en la entrada temporal.
- Verificación final del ajuste: formato de tres archivos correcto; analyze sin problemas (28,3 s); suite completa **176 aprobadas, 0 fallidas, 0 omitidas**, aproximadamente 31 s (92 propias CU-030 y 84 de base). Se agregaron 27 casos: 24 combinaciones de cambio de fuente/acciones con recarga pendiente/fallida y tres regresiones, igualdad o avance; uno de cambio de ID y dos de pantalla con recuperación mediante Actualizar detalle. Logs `F:\dev\vanfull-cu030-contexto-confirmado-analyze.log` y `F:\dev\vanfull-cu030-contexto-confirmado-test.log`. Primer intento: 174 aprobadas y 2 fallidas por aserción nueva sobre un encabezado fuera de la zona visible; corregido desplazando la lista en el test, sin otro cambio productivo. Log inicial conservado con sufijo `-test-inicial.log`. Avisos preexistentes de Google Fonts sin fallas finales; lockfile intacto. Revisión Web anterior no repetida tras el ajuste.
- Desglose de las 39 pruebas aportadas previamente por main (110 → 149), todas de Pasajero: `test/models/pasajero/disponibilidad_y_parada_test.dart` (6), `test/screens/pasajero/buscar_servicio_screen_test.dart` (13), `test/models/pasajero/reserva_test.dart` (6) y `test/screens/pasajero/confirmar_reserva_screen_test.dart` (14). No son pruebas nuevas de Chofer. Los resultados de 149 siguientes corresponden al merge previo al ajuste.
- Se preservaron los seis archivos en el commit local `84dd2c997d6c5a9e5d7077a10e36babbd8ef9ba9`. `origin/main` consultado e integrado en `feat/chofer-ejecucion-flutter-cu030`: `a86ce5a2f8d8c657d198108367c24500116a617b`, mediante merge local `2b52eaa099f476f832a4437ce250dc205d21167c`, sin conflictos. Ambos historiales del contexto se conservan debajo; el contexto de Pasajero incorporado desde main permanece intacto.
- #89 ya integrada en main por `a86ce5a`; #88 cerrado y #64 abierto. Se elimina la dependencia de una PR abierta. CU-030 sigue solo local, sin Issue/PR ni push; publicación pendiente de revisión posterior. Base original y evidencia histórica de 110 pruebas se conservan, sin atribuirlas a la nueva combinación.
- Sobre la combinación del merge: formato de los cinco archivos Dart del alcance correcto (0 cambios); `flutter analyze --no-pub` sin problemas (106,0 s); `flutter test --no-pub --reporter expanded`: **149 aprobadas, 0 fallidas, 0 omitidas**, aproximadamente 28 s (65 propias CU-030 y 84 de base). Logs: `F:\dev\vanfull-cu030-main-analyze.log` y `F:\dev\vanfull-cu030-main-test.log`. Avisos preexistentes de Google Fonts, sin fallas. Sin repetir pub get; dependencias y lockfile intactos (SHA-256 `1016007f35a680bb417cafa59e6498ead13c0b6ed116b6d406d03d22c17eac15`). Sin CI remota propia ni pruebas de backend.
- Se incorpora a los borradores de Issue/PR la revisión manual Web del usuario del 22/10 detallada debajo, realizada antes de este merge: ventanas amplia/angosta, estados y reconciliación informados; observaciones de separación vertical y claridad del procesamiento pendientes. No se repitió la revisión visual tras el merge; no se acreditan otros escenarios, Android/dispositivo, HTTP ni C12. CU-030 continúa parcial; navegación y cliente compartidos, GPS y avisos siguen pendientes según el alcance previo.
- `frontend/local_chofer_preview.dart` permanece sin seguimiento y fuera de los commits y del diff de entrega. Sin ampliación de alcance ni reglas nuevas, POST reales, demo u otros worktrees; ajuste productivo acotado descrito arriba. Borradores externos actualizados; marcador de Issue específico pendiente de sustituir solo al publicar con autorización.

## Registro histórico al 21/10/2026 — inicio/finalización Flutter CU-030 local con mocks

### Estado

- Rama local `feat/chofer-ejecucion-flutter-cu030`, worktree `F:\dev\vanfull-flutter-cu030-ejecucion`, sin commits propios ni publicación. Base exacta: HEAD de #89 `c2cf701a764ebb4f008800e7d11310cc87673acd`; #89 sigue abierta, no se modifica su rama ni se copia el detalle.
- Main remoto consultado al preparar: `5b730397cdabff18c0399cc8bc30327c1e935751` (#91). Al cerrar avanzó a `a867de9d77fd640c45cd32e7c91f5e51589b1f89` (#93). Ambos avances son del pasajero; sin cambios en ViajeResumen, detalle chofer, contrato o dependencias. No incorporados: la base elegida sigue siendo #89, no se atribuyen a main vigente los resultados siguientes.

### Hecho

- Backend de inicio/finalización integrado por #71/#67; #66 cerrado. Listado Flutter integrado por #81; detalle CU-029 publicado en #89, todavía no integrado. CU-030 continúa parcial por GPS y avisos de demora/problemas.

### En curso

- Acciones inyectables de inicio/finalización en el detalle existente, sin HTTP/sesión/navegación propios. Coordinador en `controllers/chofer/ejecucion_viaje_controller.dart`: una sola coordinación de lecturas, escrituras y reconciliación. Componente `acciones_viaje_chofer.dart`, pruebas y ajuste acotado de la pantalla; se reutilizan ViajeResumen y CargarDetalleViajeChofer (reexportada para compatibilidad). Sin acciones inyectadas, conserva el detalle de consulta.
- Trazabilidad CU-030 / RF-025 / ADJ-03; sin cambios de contrato, modelo, asignaciones o reglas. No se creó Issue ni PR para esta tarea: publicación y número específico pendientes de autorización.

### Decisiones

- Confirmación del usuario del 21/10/2026: programado permite iniciar; en_curso permite finalizar con «¿Finalizar este viaje?» / «El viaje quedará finalizado.» y «Volver» / «Finalizar viaje». Finalizado/cancelado sin transiciones nuevas; controles compartidos de 64 px y tema de chofer.
- El Viaje de una respuesta de operación válida confirma el estado, también inicio que devuelve finalizado; no se anuncia una transición nueva por recibir 200. Bloqueo durante operación/recarga y lectura completa posterior, retirando listas anteriores. Recarga fallida conserva estado confirmado y ofrece «Actualizar detalle».
- Resultado incierto conserva la operación pendiente: «Consultar estado» no reenvía escrituras. Si la consulta falla, sigue incierto; si devuelve el estado previo, solo habilita repetición explícita de esa misma operación. Un rechazo posterior no resuelve el envío anterior. Fallos tipados para rechazos conocidos y resultado incierto; errores no clasificados de operación se consideran inciertos.
- Cambio de ID/fuente o desmontaje invalida resultados tardíos, sin cancelar efectos del servidor. En el mismo viaje se conserva la incertidumbre de un envío pendiente al cambiar la fuente o retirar las acciones. IDs recibidos comprobados; sin validaciones locales nuevas de fecha, horario, capacidad o pasajeros.

### Pendientes

- Integrar/revisar la base cuando #89 se incorpore a main. Sin conexión de navegación, HTTP/autenticación reales ni prueba en dispositivo; CU-030 no completo. GPS/ETA, QR, ausencias y demoras fuera del alcance. Nómina con mocks no acredita C12.
- Conservados los borradores, guion, matriz, demo, .env y demás worktrees; sin carga de datos ni solicitudes operativas reales.

### Entorno y comprobaciones

- SDK ejecutado: Flutter 3.47.7 stable, framework `abaf9c5237`, Dart 3.13.5, `F:\dev\flutter`. PATH/PUB_CACHE solo del proceso. `flutter pub get --enforce-lockfile` correcto; lockfile intacto respecto de la base (SHA-256 `1016007f35a680bb417cafa59e6498ead13c0b6ed116b6d406d03d22c17eac15`), sin cambios de dependencias.
- Verificación anterior local: formato de cinco archivos Dart correcto (0 cambios); `flutter analyze --no-pub` sin problemas (15,2 s); `flutter test --no-pub --reporter expanded`: **104 aprobadas, 0 fallidas, 0 omitidas** (59 nuevas: 35 coordinador + 24 pantalla; 45 de la base: 24 detalle + 13 listado + 8 navegación/tema), aproximadamente 10 s. Registro externo `F:\dev\vanfull-cu030-flutter-test.log`.
- Ajuste de reconciliación posterior: un detalle incompatible no borra el Viaje confirmado ni habilita acciones o muestra sus listas; conserva «Actualizar detalle». Admite igualdad y el avance en_curso → finalizado respaldado por el backend. Verificado: formato de tres archivos sin cambios pendientes; analyze sin problemas (16,3 s); suite completa **110 aprobadas, 0 fallidas, 0 omitidas** (6 pruebas adicionales respecto de las 104 anteriores), aproximadamente 13 s. Registro local externo: `F:\dev\vanfull-cu030-reconciliacion-test.log`. Sin cambios de backend, #89 ni demo.
- Se preservan los avisos preexistentes de Google Fonts en el test del tema. El intento inicial de pruebas en la ruta temporal con `&` falló antes de ejecutar casos; worktree trasladado a F:\dev y referencia reparada. Avisos iniciales de estilo corregidos. Sin prueba backend/HTTP/dispositivo ni CI remota de esta entrega local.

### Revisión visual manual local — 22/10/2026

- Realizada por el usuario con mocks en Flutter Web, en ventana amplia y angosta: listado y detalle legibles; horario omitido como «Sin horario». Pasajeros, nómina y diálogo legibles en ventana angosta.
- Inicio muestra «En curso» y «Finalizar viaje». «Volver» cancela la confirmación y conserva En curso; confirmar la finalización muestra «Finalizado» y retira las acciones.
- Resultado incierto exige consultar el estado; permite reintentar inicio explícitamente y recupera el detalle. Recarga fallida conserva el estado confirmado, oculta las listas y permite recuperarlas con «Actualizar detalle».
- Bloqueo visual observado durante operación y recarga: se retiran las acciones y aparecen «Procesando solicitud» / «Actualizando detalle», con indicador de carga. Durante la recarga se conserva «Estado confirmado: En curso».
- Observaciones pendientes, sin correcciones de código: separación vertical amplia y pantalla de procesamiento poco clara.
- Alcance limitado a los recorridos informados: no se declaran revisados los demás escenarios del menú, Android/dispositivo ni integración HTTP/backend. No acredita C12 ni CU-030 completo; sin llamadas a la demo. No se repitió la suite ni se cambió código productivo.
- Entrada temporal `frontend/local_chofer_preview.dart` sin seguimiento, fuera de los seis archivos de la entrega y de los textos preparados de Issue/PR. Este registro no actualiza la consulta remota de #89/main: comprobarla al retomar antes de actualizar la base y publicar.

### Para otras áreas

- Futuro contenedor: inyectar `AccionesEjecucionViaje(iniciar, finalizar, onRechazo)` junto a `cargarDetalle`. El adaptador común deberá enviar los POST sin cuerpo, devolver ViajeResumen, distinguir rechazo conocido/resultado incierto y efectuar consultas nuevas después de la escritura. Permisos y transacciones siguen en backend; no se envió ningún mensaje.

## Registro histórico al 21/10/2026 — detalle Flutter CU-029 local con mocks

- Entrega publicada en [PR #89](https://github.com/Martiherenu1/ProyectoVanFull/pull/89), abierta y sin merge a main; Issue #88 abierto con etiqueta `chofer`. Rama `feat/chofer-detalle-flutter-cu029`, worktree `F:\dev\vanfull-flutter-cu029-detalle`. Los seis archivos revisados se preservaron en `a6f234eb107214dd0380670f368a1e0110042efc`. Base inicial: `28cfe338fde8bdcd8eb25c56b17c8911dfdb8d7e`; se reutiliza `ViajeResumen`, sin copiarlo ni modificar la rama del listado.
- Primera base integrada el 21/10/2026: `origin/main 5bf3117daf8ce8ab943cf234ac19dbac3fb6196d`, mediante merge local `b81ca4c3967360fe94ed9dabc4bf7fa535adf6da` (padres `a6f234e` y `5bf3117`). #81 ya está mergeada y #80 cerrado; #79 también integrada y #48 cerrado. La dependencia de una PR abierta quedó resuelta. Merge automático, sin conflictos ni rebase/force; historial del contexto conservado, sin borradores ajenos. El detalle aún no está integrado a main ni conectado a navegación/listado.
- Reanudación del 21/10/2026: incorporado `origin/main 34d3855c1af3ddb9b5eab33f30e70b8323d94772` mediante merge local `a78dba2c46af501c534c298e78513b584402b496`, sin conflictos. Incluye #78 (AG-01) y #83 (CI Flutter). No cambian pantallas, DTO, contratos ni dependencias propios; el diff contra main conserva únicamente los seis archivos del detalle/contexto. La publicación anterior ya existía: se reutilizan #88/#89, sin duplicarlos. La nueva CI comprende backend y Flutter; su resultado se verifica en la PR para cada HEAD.

### Hecho

- Backend CU-029 integrado por #65; listado Flutter integrado por #81, todavía sin HTTP ni conexión a navegación. Inicio/finalización backend por #71/#67 y #66 cerrado. CU-030 sigue parcial por GPS y avisos de demora/problemas. #79 aporta entradas temporales por rol, no autorización ni integración HTTP.

### En curso

- Modelo de lectura `OperacionAsignada`, pantalla `DetalleViajeChoferScreen`, dos archivos de pruebas y un fixture sintético compartido. Información del viaje, capacidad planificada, paradas en orden recibido, reservas y nómina separadas y cantidades del servidor sin calcular disponibilidad u ocupación total.
- Carga, contenido, no disponible, error/reintento; invalidación al cambiar ID o fuente, protección tras desmontaje y rechazo de una respuesta con otro ID. Sin contactos privados ni inferencia de ausencia; nómina sin fotografía, reserva ni abordaje inventados.

### Decisiones de esta entrega

- Interfaz local `CargarDetalleViajeChofer = Future<OperacionAsignada?> Function(int idViaje)`: `null` representa detalle no disponible; el futuro adaptador común traducirá el 404 sin distinguir viaje ajeno de inexistente. Otros fallos muestran un error genérico. No cambia contrato ni permisos.
- Fotografía nullable requerida en el modelo; el contrato proporciona una referencia, no necesariamente una URL. Presentación alternativa accesible, sin descarga de imágenes; resolver la referencia real queda para la integración. Horario omitido muestra «Sin horario». Tema de chofer y mínimos compartidos de 64 px; sin navegación, HTTP ni autenticación propios.

### Pendientes

- Issue específico [#88](https://github.com/Martiherenu1/ProyectoVanFull/issues/88) creado el 21/10/2026 con el texto revisado y etiqueta `chofer`. Trazabilidad CU-029, RF-024, RN-029; referencias #64/#48/#81. La [PR #89](https://github.com/Martiherenu1/ProyectoVanFull/pull/89) cierra únicamente #88 al integrarse y mantiene esas referencias. #81 ya integrada: no hay dependencia de una PR abierta; no se declara CU-029 completo.
- Coordinar cliente común y conexión efectiva entre navegación, listado y detalle en otra tarea. Sin prueba HTTP ni en dispositivo; fotografías no visualizadas. La nómina se prueba solo con mocks: no acredita C12 ni modifica el guion/dataset. La CI y las revisiones del HEAD publicado se informan en la PR; no sustituyen la evidencia Flutter local.

### Entorno y comprobaciones

- Flutter 3.47.7 stable / Dart 3.13.5, SDK `F:\dev\flutter`; PATH/PUB_CACHE ajustados solo para el proceso como en la preparación del listado. `flutter pub get --enforce-lockfile` correcto; lockfile SHA-256 intacto `1016007f35a680bb417cafa59e6498ead13c0b6ed116b6d406d03d22c17eac15`.
- Registro histórico previo a integrar main (base `28cfe33`): formato de los cinco archivos nuevos correcto; `flutter analyze --no-pub` sin problemas (20,7 s); `flutter test --no-pub --reporter expanded`: **39 aprobadas, 0 fallidas, 0 omitidas** (24 nuevas: 7 modelo + 17 pantalla; 15 de la base #81: 13 del listado + 2 preexistentes). Pruebas con mocks, incluida pantalla pequeña, privacidad y resultados/errores/null atrasados; no equivalen a integración real.
- **Combinación previa local con main `5bf3117`:** formato de cinco archivos nuevos correcto (cero cambios); `flutter analyze --no-pub` sin problemas (25,0 s); `flutter test --no-pub --reporter expanded`: **45 aprobadas, 0 fallidas, 0 omitidas** (24 nuevas del detalle: 7 modelo + 17 pantalla; 21 de main: 13 listado + 8 navegación/tema). Suite de widgets en aproximadamente 10 s, sin HTTP/dispositivo; esta evidencia Flutter es local y se distingue de la CI remota. No se modificaron dependencias ni lockfile, y no fue necesario repetir pub get. `git diff --check` correcto; diff propio contra main limitado a los seis archivos del detalle/contexto.
- **Combinación vigente con main `34d3855`:** formato de los cinco archivos nuevos correcto (cero cambios), `flutter analyze --no-pub` sin problemas (25,6 s) y `flutter test --no-pub --reporter expanded`: **45 aprobadas, 0 fallidas, 0 omitidas** (24 detalle, 13 listado y 8 navegación/tema; aproximadamente 9 s). Avisos conocidos de Google Fonts en el test preexistente, sin fallas. SDK Flutter 3.47.7 / Dart 3.13.5; lockfile y dependencias intactos. No se ejecutó backend local ni se llamó a la demo; la CI del nuevo HEAD se informa separadamente en #89.
- Durante la preparación previa se corrigieron un aviso de estilo del test, el tipo nullable del fixture y la separación/limpieza de la semántica de fotografía. Sus ejecuciones con fallos no se presentan como aprobadas. Google Fonts emitió avisos desde el test preexistente en ejecuciones previas y en la combinación con main; no se modificó el tema.
- No se ejecutó backend ni se llamó a la demo. Un intento auxiliar de comparación YAML/JSON no pudo correr en Python local por falta de PyYAML; contrato y backend no tienen diferencias entre esta base y main, ni cambios propios en esta entrega.

### Para otras áreas

- Facundo: la pantalla recibe `idViaje` y `cargarDetalle`; no crea `MaterialApp` ni conecta el detalle con la navegación de #79 o el listado de #81. Martiniano: el futuro adaptador conserva sesión/permisos en backend y mapea el resultado a esta interfaz; no se incorporan reglas de reservas en Flutter. Textos de Issue/PR revisados; publicación autorizada y sin mensajes enviados.
- Preservados checkout original, ramas publicadas, borradores documentales, demás worktrees, `.env` y demo. No se copió el guion ni la matriz de otros worktrees.

## Registro histórico al 21/10/2026 — listado Flutter CU-029 verificado con mocks

- Base original: `80a85634a2ab40bf201bb78e8787e8c87d51f0f2`. Issue específico #80 creado con etiqueta `chofer`; entrega local registrada en `ccb5eea8cd5dece5996e9e54a18f1f92d686dcbf`. El 21/10 se integró `origin/main 742476b7c2181a184498f57489888834e1cf2fa7` mediante merge `f00c48aa64c4419ee659ff6277d4186144eb54f3`, sin conflictos, rebase ni force. Incorpora los 11 commits de #73/#76 sin cambios propios de reservas/contrato; Flutter, el listado CU-029 y el schema `Viaje` no cambiaron en ese avance. Backend CU-029 integrado por #65; inicio/finalización integrados por #71/#67 y #66 cerrado. CU-030 continúa parcial: GPS y avisos de demora/problemas pendientes. Los registros inferiores describen verificaciones históricas.
- Rama aislada `feat/chofer-listado-flutter-cu029`: modelo `ViajeResumen` y pantalla de listado por fecha con fuente asíncrona inyectable y callback de selección por ID. Estados de carga, listado, vacío y error/reintento; horario omitido se presenta como «Sin horario». Sin nombres deducidos de identificadores.
- La selección inicial usa el día local (o `fechaInicial` inyectada) y consulta esa fecha explícitamente; no equivale al valor por defecto de fecha del servidor. Se conserva el orden recibido. Respuestas o errores de consultas anteriores no sustituyen la selección actual. Tema `AppTheme.driver` y mínimos compartidos de 64 px para filas y controles propios.
- Revisión estática del 20/10/2026: corregida la fecha de los mocks del día 31 y ampliada la cobertura de fecha inicial UTC (sin conversión de día), rechazo de timestamps donde corresponde una fecha, error tras desmontaje y reemplazo de fuente. Las 13 pruebas entonces pendientes se ejecutaron el 21/10 según el resultado siguiente; no son llamadas HTTP.
- **Checks locales del 21/10/2026:** `flutter pub get --enforce-lockfile` correcto; SHA-256 del lockfile intacto `1016007f35a680bb417cafa59e6498ead13c0b6ed116b6d406d03d22c17eac15`. Formato aplicado solo a cuatro archivos nuevos (dos reformateados); comprobación final: cuatro archivos, cero cambios. Primer analyze detectó un aviso `use_null_aware_elements` en el mock de horario omitido, corregido con entrada null-aware. `flutter analyze --no-pub`: sin issues. `flutter test --no-pub --reporter expanded`: **15 aprobadas, 0 fallidas, 0 omitidas** = 13 nuevas (4 modelo + 9 pantalla) y 2 preexistentes. Sin integración real ni validación visual en dispositivo; CU-029 no está completo.
- **Verificación posterior a integrar main:** sobre el árbol combinado de `ccb5eea` con `742476b`, luego registrado sin cambios en `f00c48a`, se repitieron formato de los cuatro archivos nuevos (cero cambios), analyze (sin avisos, 53,5 s) y la suite completa (15 aprobadas: 13 nuevas + 2 preexistentes; cero fallidas/omitidas). Lockfile y dependencias intactos. No se repitió pub get porque el merge no cambió dependencias. Persisten los avisos de Google Fonts del test preexistente; sin cambios del tema ni prueba HTTP/dispositivo.
- **SDK local instalado el 21/10/2026:** `F:\dev\flutter`, Flutter 3.47.7 stable, revisión `abaf9c523780a608bd46686fd5e53740a07077f8`, Dart 3.13.5; versión ejecutada coincide con Facundo y el [manifiesto oficial](https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json). ZIP SHA-256 comprobado antes de extraer: `c2c875da25a1a1448d18ee4e8f398b2f6fce888b4775d8f9130538e16d826cb4`. El manifiesto vigente usa `/releases/releases_windows.json`; la ruta antigua `/flutter/releases/` devolvió 404. SDK invocado por ruta completa, sin cambiar PATH permanente ni instalar otros SDK/toolchains. El README antiguo no implica regenerar el proyecto: no se ejecutó `flutter create` ni se actualizó ninguna dependencia del proyecto.
- **Trampas y límites de entorno:** el `.bat` falló al expandir PATH con el `&` del perfil; se excluyeron esas entradas solo en cada proceso. El primer intento de test falló antes de ejecutar pruebas por rutas `M&M` en el hook `objective_c`. Resuelto con junctions `F:\dev\vanfull-cu029-worktree` al mismo worktree y `F:\dev\pub-cache` a la caché existente; ejecución desde el primer alias y `PUB_CACHE` del proceso apuntando al segundo, nuevo pub get con lockfile intacto. Doctor informa PATH no configurado, Android SDK y Visual Studio ausentes; no se instalaron. La suite aprobada emitió mensajes de descarga fallida de Archivo/IBM Plex Mono desde el test preexistente del tema: limitación para coordinar con Facundo, sin modificar el tema. Archivos locales de paquetes, build, configuración y registrantes Android/iOS generados están ignorados y fuera del índice; archivos versionados ajenos al alcance intactos.
- Contra el main integrado `742476b`, solo cambian modelo, pantalla, pruebas y contexto propio: sin cambios propios en `main.dart`, navegación, tema compartido, dependencias, backend o contrato; detalle y ejecución quedan fuera de esta tarea. PR #81 abierta para #80, sin merge de esta entrega a main. La CI de publicación del HEAD `28cfe338fde8bdcd8eb25c56b17c8911dfdb8d7e` fue aprobada ([ejecución 39609803814](https://github.com/Martiherenu1/ProyectoVanFull/actions/runs/39609803814)); solo ejecutó backend, no Flutter. La evidencia Flutter anterior sigue siendo local.
- Corrección documental del 21/10/2026: Facundo (`facubarrientos`) publicó [APPROVED](https://github.com/Martiherenu1/ProyectoVanFull/pull/81#pullrequestreview-5604187419) sobre `28cfe338fde8bdcd8eb25c56b17c8911dfdb8d7e`. No se repiten pruebas Flutter porque no cambia código ni dependencias. La CI y la vigencia de esa aprobación para el nuevo HEAD se informan en #81 después del push; no se presuponen por herencia.
- Estado comprobado el 21/10/2026: #79 de Facundo integrada en main mediante `da85c6bd6fdb77544856535faa2d1f3cfe3629cd`; #48 cerrado. Esa navegación conserva una entrada temporal de chofer y todavía no conecta este listado. La conexión efectiva entre navegación y listado será una tarea separada, junto con la integración del cliente HTTP y autenticación comunes; se mantiene el callback futuro al detalle. El adaptador deberá enviar la fecha como `YYYY-MM-DD` y gestionar la sesión y los errores HTTP. Preparación del dataset en el guion/worktree documental independiente; no requerida para estos mocks ni copiada a esta rama. #80 cubre solo este listado Flutter; #64 corresponde al backend, excluye Flutter y no se cierra por este trabajo. La PR cerrará únicamente #80 y referencia #64/#48. Sin mensajes enviados a Facundo o Martiniano.
- Este contexto parte de la versión de `main`; no incorpora ni reemplaza los borradores documentales pendientes de otros worktrees. Checkout original, guion, matriz, `.env` y demo preservados.

## Historial al 19/10/2026 — CU-029 integrado y CU-030 en revisión

- **Issue #37 / PR #40:** contrato OpenAPI de las operaciones del chofer integrado a `main` y Issue cerrado.
- **Issue #64 / PR #65:** consultas CU-029 del chofer ya **mergeadas** en `main`, con CI aprobada (148 pruebas en su rama antes del merge).
- **Issue #66 / PR #67:** inicio/finalización CU-030 implementados y en revisión, **sin merge de la PR a `main`**. Integraciones de `main` y prueba de rollback publicadas en la rama de la PR, según el registro debajo. El resultado de CI debe comprobarse para el HEAD publicado antes de solicitar merge; #66 permanece abierto.
- **Issue #39 / PR #63:** aclaración de GPS/ETA aprobada funcionalmente; pendiente de evaluación técnica y sin modificación automática de OpenAPI.
- **PR #50 de Facundo:** alta administrativa de viaje integrada; asignaciones posteriores de chofer y vehículo no implementadas. ADJ-03 impide iniciar un viaje sin ambos asignados.
- **PR #45 de Facundo:** base Flutter Web/Mobile **mergeada** y presente en `frontend/`. **PR #47** de tema visual sigue **abierta**. Las pantallas específicas de chofer continúan **pendientes** y corresponden a Martín sobre la base compartida; Issue #48 navegación por roles continúa como dependencia.
- **Pendientes del área:** GPS (contrato Issue #39), pantallas del chofer, datos seed de posiciones/abordajes/nóminas, pruebas de integración y avisos de demora/problemas de CU-030 (cobertura parcial). El chofer **no escanea QR**; consulta abordajes existentes.

### Verificación local histórica, antes de commit y push — PR #67 (19/10/2026)

- En esta verificación previa: worktree aislado de `feat/chofer-ejecucion-cu030-66`, HEAD `868172bed36fc5ca93fdfdd845f03b7aa0f8ed1f`; integración de `origin/main` `cf6ea21f7ee40d59c668d2af7474964bf32fa7fd` mediante `merge --no-ff --no-commit`, entonces sin commit ni push. El registro de publicación posterior se encuentra debajo; no hubo merge de la PR a `main`.
- Único archivo con conflictos: `backend/app/main.py` (imports y registro de routers). Resolución conserva chat del PR #69, consultas CU-029, ejecución CU-030 y todos los demás routers, cada uno registrado una sola vez. Los archivos incorporados desde `main`, incluido el contexto de Pasajero, se conservan sin cambios propios.
- Prueba de atomicidad agregada para inicio desde `programado` y finalización desde `en_curso`: fallo simulado después del `flush` real del evento y antes del commit; otra conexión verifica el estado original y la ausencia de eventos. No se modificó la lógica productiva de las transiciones.
- Checks locales en Docker sobre el código del worktree montado en solo lectura: Ruff sin errores; formato correcto (72 archivos); suite completa con PostgreSQL y bases temporales: **220 aprobadas, 0 fallidas, 0 omitidas**, 185 advertencias, 419,29 s. Advertencias por deprecación de `TestClient`/`httpx` y longitud de la clave JWT de desarrollo; configuración y dependencias sin modificar. Sin migraciones ni seed sobre la base de desarrollo.
- YAML y JSON válidos y equivalentes, sin claves YAML duplicadas; contrato sin cambios (25 rutas, 27 operaciones, 28 schemas). Rutas de chat, consultas del chofer e inicio/finalización verificadas como registradas y contratadas; `git diff --check` y su variante del índice sin errores. **CI remota en esa verificación: SIN VERIFICAR**. Issue #66 continúa abierto; CU-030 sigue parcial, sin GPS, QR, ausencias ni avisos de demora/problemas en este bloque.

### Publicación posterior de la integración actualizada — PR #67 (19/10/2026)

- `main` avanzó a `2db047832b9d6254dd06e8b00566348e804b0f63` (PR #70: disponibilidad, sus pruebas y contexto de Pasajero). Se incorporó sin conflictos nuevos y sin cambios propios en esos archivos. Las 220 pruebas anteriores corresponden únicamente a la verificación histórica con `main` `cf6ea21`.
- Publicados mediante push normal a la rama existente: `8b3a0a6` (merge revisado con chat), `364ade7` (merge del avance de `main`) y `ab269a8` (dos casos de rollback). Se conserva el historial, sin rebase ni force; este registro documental es posterior a esa publicación.
- Verificación local repetida porque cambió código en `main`: Ruff sin errores, formato correcto (72 archivos), **228 aprobadas, 0 fallidas, 0 omitidas**, 185 advertencias, 164,50 s. PostgreSQL temporal; sin migraciones ni seed en desarrollo. YAML/JSON válidos y equivalentes, sin claves duplicadas; chat, CU-029 e inicio/finalización registrados y contratados. El backend publicado coincide con el probado.
- Al registrar esta actualización documental, **CI remota del HEAD final: SIN VERIFICAR**; comprobar su resultado posterior en [PR #67](https://github.com/Martiherenu1/ProyectoVanFull/pull/67). Merge a `main` y cierre de #66 no autorizados; se mantiene `Refs #66`, sin referencias de cierre automático. GPS (#39), QR, ausencias, avisos de demora/problemas y refactor CU-029 fuera del alcance propio de esta actualización.

---


## Historial de avance al 18/10/2026 — ejecución CU-030 (#66)

- **#66 / rama `feat/chofer-ejecucion-cu030-66`: en desarrollo.** Backend de las dos operaciones **existentes en OpenAPI**: `POST /viajes/{id_viaje}/inicio` y `POST /viajes/{id_viaje}/finalizacion`, trazadas a CU-030 / RF-025 / ADJ-03; sin nuevas operaciones ni cambios SQL/ORM.
- Las transiciones bloquean la fila del viaje durante el cambio para evitar eventos duplicados ante solicitudes concurrentes. El acceso exige rol `chofer` y `viaje.id_chofer == usuario.id_persona`.
- Inicio: `programado -> en_curso` solo con vehículo asignado; reintentos `en_curso` y `finalizado` responden 200 sin reinicio/evento; `cancelado` 409.
- Finalización: `en_curso -> finalizado`; reintento finalizado 200 sin duplicación; programado/cancelado 409. Cada transición real deja un evento `viaje_iniciado` o `viaje_finalizado` con el helper compartido en la misma transacción (tipos internos del servicio, **no RN nuevas**).
- **Calidad verificada — PR #67 (18/10/2026):** CI GitHub Actions aprobada, `ruff check` y `ruff format --check` correctos; suite completa contra PostgreSQL: **156 pruebas aprobadas**, 0 fallidas (113 advertencias). Pruebas de concurrencia e idempotencia incluidas. PR abierta para revisión, **sin merge**.
- Dependencia de Facundo: para iniciar, asignación previa de chofer y vehículo (ADJ-03). La implementación de reasignaciones posterior al alta sigue fuera de este bloque.
- No se incluye GPS, UI Flutter, abordajes, avisos de demora/problemas (CU-030 parcialmente cubierto) ni cambios de línea base. Issue #39 GPS continúa en revisión documental.
- **#64 / PR #65 (estado histórico del 18/10):** consulta CU-029 enviada para revisión con CI aprobada; posteriormente mergeada en `main`, según estado vigente al 19/10 descrito arriba.

---


## Historial técnico al 15/10/2026

2026-10-15: #37 tiene completo el diseño contractual de las cinco operaciones acordadas y su README.
Siete commits originales más el merge de integración; sin push, PR ni merge de nuestra rama a main.
Backend de estas operaciones y Flutter pendientes de implementación; CU-030 continúa parcial.

## Hecho

- Ninguna funcionalidad propia integrada a main ni PR del área.
- Base común del backend disponible en la base de esta rama; entorno local, migración 0001
  y seed sin reiniciar verificados durante la preparación de #37.

## En curso

- Issue: [#37](https://github.com/Martiherenu1/ProyectoVanFull/issues/37), abierto y con etiqueta chofer.
- Rama: feat/chofer-contrato-cu029-cu030-37.
- Cinco commits OpenAPI:
  - 64fdbdc: GET /choferes/me/viajes.
  - b71007b: POST /viajes/{id_viaje}/inicio.
  - af0933c: POST /viajes/{id_viaje}/finalizacion.
  - 1f5ac0c: GET /choferes/me/viajes/{id_viaje}.
  - fb3fd40: POST /viajes/{id_viaje}/ubicacion y sus schemas de entrada/resultado.
- ed7cc3f: README actualizado con indicadores, cobertura y trazabilidad.
- 71b0b75: contexto vivo original del contrato, séptimo commit propio conservado.
- Integración de origin/main (65fdd5b) mediante merge --no-ff sin conflictos:
  d350ba4d69362add065ff3f88ff11672a3ca4b06. Incorpora el PR #38 de CU-010,
  incluida la ampliación de Reserva con id_recorrido, fecha, horario y sentido.
- Tras integrar main quedaron ocho commits exclusivos respecto de origin/main.
  Con esta actualización documental, la rama contiene nueve commits exclusivos respecto de origin/main: siete originales, uno de integración y uno de actualización del contexto.
- Contrato 0.1.0: 25 rutas, 27 operaciones HTTP, 28 schemas, 18 CU representados de 37
  y 19 CU sin operaciones. YAML/JSON válidos, equivalentes y sin claves duplicadas.
- Últimos checks después del merge d350ba4: Ruff sin errores, formato correcto (55 archivos);
  pytest en Docker: 132 aprobadas, 0 fallidas, 0 omitidas, 72 advertencias conocidas (77,07 s).
  YAML y JSON válidos y equivalentes, sin claves duplicadas.
- Pendientes de cierre: push, publicación del PR, CI remota y merge de nuestra rama a main.
  CI remota SIN VERIFICAR.

## Decisiones

- 2026-10-15, Martín, revisión de #37: consultas de viajes propios con rol chofer y fecha opcional
  (por defecto fecha actual del servidor); sin asignaciones devuelve [].
  Horario NULL se omite sin modificar Viaje. Contrato: 64fdbdc y 1f5ac0c.
- 2026-10-15, Martín, revisión de #37: detalle con listas separadas de reservas
  provisionales/consolidadas e integrantes de nómina. Identificación permitida, incluido DNI;
  sin contactos privados. Fotografía nullable y abordaje solo en la lista de reservas.
  Campos explícitos; cantidades independientes, sin disponibilidad ni total único. Contrato: 1f5ac0c.
- 2026-10-15, Martín, revisión de #37: inicio/finalización con transiciones e idempotencia aprobadas;
  los reintentos también comprueban permisos. ADJ-03 exige chofer y vehículo antes del inicio;
  sus asignaciones se leen sin modificarlas. Contrato: b71007b y af0933c.
  Recurso inexistente/ajeno: 404; rol incorrecto: 403, según backend/CONVENCIONES.md.
- 2026-10-15, Marti, comunicado por Martín: GPS exclusivo del chofer asignado con viaje en_curso;
  coordenadas obligatorias con rangos geográficos y timestamp opcional con zona horaria.
  Timestamp omitido o futuro: hora actual del servidor; anterior al servidor: conservarlo.
  Actualizar solo si el timestamp efectivo es estrictamente posterior al almacenado.
  Si es igual o anterior, ignorar la nueva posición sin cambiar coordenadas ni hora.
  Conservar únicamente la última posición por viaje, sin columnas nuevas. Contrato: fb3fd40.
- 2026-10-15, Martín aprueba la respuesta solicitada por Marti: 200 con ResultadoPosicionGps;
  actualizada indica si se guardó y fecha_hora_posicion siempre informa la hora almacenada,
  también si actualizada es false. Precisión de 50 m como objetivo, sin rechazo automático.
- CU-029 tiene documentadas sus consultas; esto no implementa backend ni pantallas.
  CU-030 mantiene x-cobertura: parcial por avisos de demora y problemas.
  RN-022/RN-023 son referencias generales de CU-030; RN-030 regula consulta de ubicación.

## Pendientes

- #37: publicar la rama (push), abrir el PR con plantilla completa, comprobar la CI remota
  y realizar el merge de nuestra rama a main conforme a CONTRIBUTING.md.
- [#39](https://github.com/Martiherenu1/ProyectoVanFull/issues/39), abierto y con etiqueta chofer:
  CU-009 A1, PENDIENTE DE VALIDACIÓN del comportamiento ante un reloj del celular atrasado.
  Riesgo de diseño, no falla comprobada en una implementación. Distinguirlo de pérdida de
  conectividad y posiciones realmente antiguas. No modificar RNF-008 ni inventar tolerancias
  o correcciones; el Issue autoriza análisis y validación, no cambios funcionales.
- #37: coordinar el contrato con Martiniano y avisar a Facundo antes del merge de nuestra rama a main.
  Avisos pendientes; el agente no envió mensajes al equipo.
- RN-002/disponibilidad, seguimiento previo #28/#33: conservar la referencia del contrato
  a capacidad menos reservas consolidadas. No modificar disponibilidad desde #37.
- Demoras/problemas de CU-030: fuera del alcance de #37; crear o vincular Issue posterior.
- QR offline de CU-007: RNF-011/012 aprobados frente a postergación del prompt.
  PENDIENTE DE VALIDACIÓN; conservar línea base y crear o vincular seguimiento.
- Implementación del área, seed propio y escenario de demo: tareas posteriores, fuera de #37.

## Entorno y trampas

- Docker Desktop debe estar iniciado; checks del backend dentro de Docker.
  Versión verificada durante #37: Desktop 4.95.0.242831, motor 29.8.2.
- backend/.env es local, ignorado por Git y excluido del contexto de construcción; no publicar claves.
- Las 72 advertencias conocidas corresponden a JWT de desarrollo corto y TestClient en desuso.
- El conector GitHub permite lectura; las mutaciones intentadas fueron rechazadas con HTTP 403.
  Los Issues #37 y #39 ya tienen etiqueta chofer, verificada en GitHub.
- PowerShell puede alterar tildes al enviar scripts por stdin; usar UTF-8 y escapes Unicode.

## Para otras áreas

- Las cinco operaciones sirven como contrato de diseño para integración y mocks; no son endpoints
  implementados. No se modificaron modelos, migraciones ni el GET existente de ubicación.
- Martiniano: avisar el cambio de contrato en el PR; revisión de otro integrante opcional según CONTRIBUTING.
  Al implementar el detalle, obtener datos mediante los servicios de su área, sin duplicar sus reglas.
  Usar el helper común de eventos.
- Facundo: avisar antes del merge de nuestra rama a main por la relación entre asignaciones y ejecución del viaje.
  Leer sus asignaciones sin modificarlas; faltan sus datos seed de chofer, vehículo y viaje.
  Flutter Web/Mobile ya fue integrada en `main` por Facundo mediante PR #45; la PR #47 del tema visual continúa abierta. Las pantallas específicas del chofer siguen pendientes y corresponden a Martín sobre la base común.
- Martín: preparar seed de posiciones, abordajes, ausencias y nóminas, y la demo cruzada
  en tareas posteriores; implementar servicios, routers y pantallas del área por CU.
