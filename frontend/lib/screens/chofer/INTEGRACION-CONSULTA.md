# Integración de consulta Chofer — validación de #123

## Estado comprobado al 25/10/2026

- Base local actualizada mediante `git merge --ff-only origin/main` a
  `bd4ec6fc6b36a50f4e715ed8489ecf832359f414` (#161), sin rebase ni reescritura.
  Los tres archivos locales se conservaron y respaldaron antes del merge.
  #163 sigue abierta y no está incorporada en esta base.
- #159 integrada y #152 cerrado: la composición autenticada ya conecta sesión,
  listado HTTP por fecha, detalle por ID, retorno y salida de Chofer. No queda
  pendiente implementar esa conexión ni se duplica desde #123.
- #128 aporta ChoferShell; #113, DetalleViajeChoferApi; ViajesChoferApi ya consulta
  la fecha explícita. Componentes y adaptadores integrados se reutilizan.
- #153 aporta generación de sesión, invalidación condicionada de 401 y logout
  con token saliente. SesionController y HttpApiClient siguen siendo comunes.
- #161 integrada: la composición entrega métodos de instancia estables para
  cargar listado y detalle, conservando los mecanismos comunes de #153/#159.
- CI remota del main exacto: [ejecución 40252289955](https://github.com/Martiherenu1/ProyectoVanFull/actions/runs/40252289955),
  completada con éxito. Es evidencia remota de la base, no de nuestras pruebas nuevas.

## Composición existente e interfaz

VanFullBootstrap crea una sola sesión, un HttpApiClient y un transporte. Inyecta
ViajesChoferApi y DetalleViajeChoferApi en la entrada Chofer de SesionApp y
RoleRouter. No se agregan clientes, DTO ni políticas de sesión propios.

```dart
ChoferShell(
  cargarViajes: cargarViajes, // Future<List<ViajeResumen>> Function(DateTime)
  cargarDetalle: cargarDetalle, // Future<OperacionAsignada?> Function(int)
  onSalir: salir, // VoidCallback externo.
)
```

- SesionApp remonta el árbol autenticado mediante
  `ValueKey(controller.generacion)`. El shell anterior se desmonta al salir o
  invalidar la sesión; su fecha, rutas y datos no se heredan por otra cuenta.
- La fecha inicial del shell es el día local. El listado envía `fecha=YYYY-MM-DD`
  explícita, sin asumir el valor por defecto del servidor. Seleccionar entrega
  el ID al adaptador de detalle; volver conserva fecha/listado sin recarga propia.
- Fuentes iguales no recargan el shell; un reemplazo explícito invalida las
  respuestas anteriores en las pantallas. #161 corrigió las closures creadas
  en build: la prueba local original conserva ambos callbacks y no genera GET
  adicionales al reconstruir con detalle abierto y listado en la navegación.
- onSalir solo delega. Listado y detalle permiten salir incluso durante carga;
  no administran token, logout HTTP ni cierre del cliente.

## Sesión, errores y transporte ya integrados

- 401 contractual: HttpApiClient notifica onNoAutorizado con el token enviado,
  solo si el pedido llevó token. SesionController.invalidar actúa solo si sigue
  vigente ese token. Un 401 tardío con token distinto no invalida la cuenta nueva;
  el 401 sin token del login no activa ese callback.
- 403 contractual: la composición conserva sesión, retira el contenido protegido
  y muestra «Acceso denegado». Compara generación y token de la solicitud con los
  actuales antes de denegar; un 403 anterior no bloquea otra sesión.
- 404 contractual de detalle: el adaptador devuelve null y la pantalla muestra
  «Detalle no disponible». Otros fallos mantienen error/reintento explícito.
- Logout: salir retira inmediatamente la sesión local y pasa el token saliente
  a AuthApi.cerrarSesion. Su demora o fallo no revierte la salida local ni toma
  el token de una cuenta posterior.
- Respuestas tardías: la key por generación desmonta las pantallas anteriores;
  estas descartan respuestas si ya no están montadas. La protección de 401 por
  token y la de 403 por generación/token se reutilizan, sin otra política local.
- VanFullBootstrap es propietario del transporte: se crea en initState y se
  cierra en dispose, una sola vez. No se cierra al volver del detalle ni al salir
  de una sesión, porque el login y la cuenta siguiente lo reutilizan. Shell y
  adaptadores reciben dependencias prestadas.

## Reparto coordinado vigente

- Facundo: composición en main.dart, SesionApp y RoleRouter, integrada por #159;
  estabilidad de callbacks corregida por #161.
- Martiniano: autenticación, sesión, token y roles; SesionController y
  HttpApiClient a su cargo, con los mecanismos integrados por #153.
- Martín: componentes/adaptadores de Chofer y validación de #123 sobre esa base.

## Verificación y pendientes de #123

- Las pruebas nuevas montan VanFullBootstrap con transporte simulado y usan las
  pantallas/adaptadores existentes: fecha/ID/token, retorno, errores 401/403/404,
  reintento, cuenta nueva, respuestas tardías, generación, callbacks y cierre.
- Verificación local nueva sobre bd4ec6f, en este orden: primero la regresión
  original de estabilidad (1 aprobada, 6 s); después el archivo completo
  consulta_autenticada_chofer_test.dart (21 aprobadas, 0 fallidas/omitidas, 19 s)
  y `flutter analyze --no-pub` (sin observaciones, 36,9 s). La regresión forma
  parte de esas 21 pruebas; no se cuentan 22 casos distintos.
- El archivo de pruebas permanece idéntico al respaldo previo al merge; no se
  suavizaron expectativas ni se omitió la regresión. Ambos callbacks se conservan
  y reconstruir con la misma sesión no genera GET adicionales. Pendiente técnico
  de Facundo resuelto por #161, sin modificaciones compartidas locales.
- Formato del test correcto (0 cambios) y `git diff --check` correcto.
  Logs locales ignorados: frontend/cu123-161-{estabilidad,consulta,analyze}.log.
  Dependencias y lockfile intactos. No se repitió la suite completa ni el chequeo
  global de formato sobre esta base; no se les atribuye una aprobación local nueva.
- Evidencia histórica sobre e9a1030: archivo de consulta con 20 aprobadas/1 fallida;
  suite completa con 522 aprobadas/1 fallida, 0 omitidas (124 s). Fallaba únicamente
  la estabilidad de callbacks (dos GET adicionales), ahora corregida por #161.
  El chequeo global de formato en esa base señaló tres archivos de tema
  preexistentes e intactos (app_colors.dart, app_spacing.dart, app_typography.dart).
  Estos resultados no describen una ejecución completa sobre bd4ec6f.
- El usuario revisó el diff y autorizó publicar únicamente estas pruebas y su
  documentación, sin merge. La prueba real de consulta continúa pendiente,
  según el plan siguiente; la publicación no la acredita.
- Evidencia histórica: las 51 y 117 pruebas de entregas anteriores no son una
  ejecución sobre esta combinación. La suite antigua interrumpida después de
  233 aprobadas no acredita aprobación completa. Las 502 informadas en #159
  corresponden a esa entrega, separadas de los resultados locales nuevos.
- Prueba real propuesta, todavía SIN EJECUTAR: confirmar con Martiniano la versión
  desplegada, cuenta de Chofer y dataset/fecha/ID disponibles; usar una ejecución
  local identificada por SHA contra la API de Render, ingresar, consultar fecha,
  abrir el ID, volver conservando fecha/listado y cerrar sesión. No publicar la
  demo ni modificar viajes/datos. No registrar credenciales ni tokens en evidencia.
- Los escenarios de rechazo/cambio de cuenta se verifican con transporte simulado;
  no se fuerza una situación de permisos ni se altera el dataset real.
- Esta entrega no cierra #123 ni declara CU-029 completo. No se acredita HTTP
  real, dataset, cuentas o dispositivo. Inicio/finalización, ubicación, captura
  GPS y ausencias quedan fuera. CU-030, preview, demo y otros worktrees se preservan.
- Entrega publicada mediante commit y push normal en la
  [PR #164](https://github.com/Martiherenu1/ProyectoVanFull/pull/164), abierta hacia
  main, sin merge y con Refs #123. El resultado real de la CI del HEAD final se
  registra en su descripción, separado de las 21 pruebas locales sobre bd4ec6f.
  El documento previo a #159 quedó respaldado fuera del worktree; sus pendientes
  obsoletos no se trasladan.
