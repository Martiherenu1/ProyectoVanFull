# Control previo Android con operaciones simuladas — 2026-10-22

Continuación del procedimiento del ensayo. Esta sección corresponde a la nueva
entrada lib/technical/control_ubicacion_inicio_main.dart, en el worktree
F:\dev\vanfull-cu030-ubicacion, rama feat/chofer-control-ubicacion-cu030.
Base 16b0d3593803d72d48020b7daaab8b2d49d38fe9 de #103, abierta y sin merge;
main remoto verificado a86ce5a. No se modifica la rama publicada de #103.

## Separación de responsabilidades

- Real: solo lectura de permiso y servicio de ubicación del teléfono mediante
  ComprobadorUbicacionAndroid, reutilizando el control inyectable revisado.
- Simulado: viaje, detalle vacío y funciones de inicio/finalización en memoria.
  La pantalla indica «Operaciones simuladas: sin backend»; el contador registra
  invocaciones de inicio simulado, no posiciones. IDs y fecha son ficticios.
- Pendiente: captura/envío GPS e integración HTTP/autenticación. No se abren streams,
  obtienen posiciones, solicita precisión ni espera señal. Sin notificación de captura.
  No se registra información de ubicación, IDs de dispositivo ni datos personales.

El adaptador solo llama isLocationServiceEnabled y checkPermission. whileInUse y
always conceden permiso, incluido aproximado; denied, deniedForever y
unableToDetermine no lo conceden. Errores de consulta se propagan al bloqueo local
ya revisado. No llama requestPermission ni abre Ajustes automáticamente. La lógica
de incertidumbre, confirmaciones y finalización permanece intacta.

## Dependencias y permisos

geolocator 14.1.2 exacto, geolocator_android 5.2.1 y platform_interface 4.4.1,
resueltos desde caché. El lockfile solo añade paquetes: no cambia versiones existentes.
Manifest fuente: COARSE_LOCATION para aproximada y FINE_LOCATION para permitir la
opción precisa, sin exigirla; no se consulta precisión. Sin FOREGROUND_SERVICE,
FOREGROUND_SERVICE_LOCATION, POST_NOTIFICATIONS, WAKE_LOCK ni BACKGROUND_LOCATION.
El plugin declara su servicio auxiliar en el manifest fusionado; esta entrada no
solicita actualizaciones ni inicia su modo foreground. MainActivity permanece intacta.

## Verificación y APK

Formato de archivos del alcance correcto. Analyze: sin problemas (14,4 s).
Suite Flutter: 230 aprobadas, 0 fallidas/omitidas (~54 s): 212 anteriores + 13 del
adaptador + 5 de entrada técnica. Dobles de GeolocatorPlatform verifican solo
consultas, mapeo de todos los permisos, errores, contador, Ajustes explícitos y
finalización sin GPS. Avisos preexistentes de Google Fonts sin fallas.
Compilación debug final de la entrada técnica: correcta (80,2 s), sin cambios de
Gradle/JDK/MainActivity. Flutter 3.47.7, Dart 3.13.5, Java efectivo 21.0.6.
APK: F:\dev\vanfull-cu030-ubicacion\frontend\build\app\outputs\flutter-apk\app-debug.apk
Tamaño: 172570106 bytes.
SHA-256: 8a3c579eafe70ed40b0633654fe27c1ef2c93d69a6967ba7ec9567c06173d483
APK NO instalada ni abierta.

Manifiesto fusionado y empaquetado revisados con aapt2: minSdk 24, target/compile
36; COARSE_LOCATION, FINE_LOCATION, INTERNET (debug preexistente) y permiso
interno signature com.vanfull.frontend.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION
de AndroidX. Servicio del plugin no exportado, tipo location, declarado pero no
iniciado por esta entrada. Sin permisos foreground, background, notificaciones
ni wake lock. FINE permite elegir ubicación precisa, no la exige.

La entrada técnica deshabilita la descarga runtime de Google Fonts antes de crear
la app; usa fuentes disponibles o alternativa del sistema. No modifica el tema
compartido. Se añadió una comprobación de arranque sin descarga ni consultas al
teléfono. Un intento intermedio de ese test usaba runApp directamente y falló por
el reloj artificial del harness; se corrigió usando pumpWidget con la misma
factoría de arranque. Log intermedio preservado con sufijo -test-intermedio.log.
Logs externos F:\dev\vanfull-cu030-adaptador-{analyze,test,build}.log.

applicationId com.vanfull.frontend: coincide con el ensayo de captura instalado.
Instalar con reemplazo sustituiría ese ensayo; no pueden coexistir con ese ID.
No se propone ni realiza instalación sin autorización posterior específica.

## Observaciones físicas manuales de Martín — 2026-10-23

Dispositivo: Samsung Galaxy S20+ 5G, Android 13. Nueva APK técnica de control
previo, con condiciones del teléfono reales y viajes/operaciones simulados.
Actualización autorizada del ensayo anterior mediante install -r, sin desinstalar
ni borrar datos: ADB autorizado, APK anterior identificada por su hash y nueva APK
con SHA-256 documentado verificado; instalación correcta y entrada abierta.
Esto actualiza el estado histórico anterior de «APK no instalada ni abierta».

- Ubicación apagada: mensaje «Activá la ubicación del teléfono para iniciar el
  viaje», contador de inicios 0.
- Tras reactivarla, sin pulsar Iniciar: Programado y contador 0.
- Pulsación explícita: En curso, contador 1.
- Finalización con Ubicación apagada: Finalizado, contador 1.
- Permiso denegado: mensaje «Permití que VanFull acceda a tu ubicación para iniciar
  el viaje», Programado y contador observado 0. No se compara este contador con
  el de sesiones anteriores.
- Permiso mientras se usa y ubicación precisa desactivada: al volver de Ajustes
  sin iniciar permaneció Programado. El contador pasó de 1 a 0; causa no
  determinada. No se atribuye a un mecanismo interno ni se presupone continuidad
  entre sesiones.
- Después, pulsación explícita con permiso aproximado: Programado → En curso,
  contador 0 → 1.
- Finalización confirmada: Finalizado, contador 1.

La observación inicial que parecía un inicio automático quedó aclarada: Martín
había pulsado Iniciar. No se registra como defecto.

Son observaciones manuales comunicadas por Martín, no mediciones instrumentadas.
Se observó bloqueo local con servicio apagado o permiso denegado, retorno de Ajustes
sin inicio automático, inicio explícito con permiso aproximado y finalización con
Ubicación apagada en los escenarios indicados. Sin HTTP, captura ni envío GPS;
no validan el circuito completo ni seguimiento integrado. No se repitieron pruebas,
cambió código, compiló ni publicó nada para este registro. Los demás escenarios no
observados siguen pendientes; el procedimiento siguiente queda como referencia.
## Procedimiento físico pendiente, tras autorización

1. Comprobar ADB autorizado, hash documentado y colisión de applicationId antes de
   decidir instalación. No borrar datos ni desinstalar automáticamente.
2. Abrir esta entrada: comprobar banner y contador de invocaciones simuladas en 0.
3. Con servicio apagado o permiso denegado, pulsar Iniciar viaje: mensaje orientativo
   y contador sin incremento. Un fallo de consulta tampoco debe invocar inicio.
4. Abrir Ajustes mediante el botón explícito correspondiente y habilitar manualmente
   ubicación/permiso mientras se usa la app, aproximado o preciso. No hay solicitud
   automática de permisos. Volver no inicia: requiere nueva pulsación.
5. Pulsar Iniciar viaje habilitado: aumenta contador y cambia el viaje simulado a
   en curso, sin primera posición ni notificación de captura. Confirmar finalización
   simulada incluso con ubicación apagada o permiso retirado.
6. Nuevo viaje simulado restablece escenario programado e ID ficticio, conservando
   el contador acumulado de invocaciones durante la sesión. No carga datos reales.

Ninguna prueba con dobles acredita el control Android en dispositivo. Las observaciones
de captura históricas siguientes no validan esta nueva entrada ni seguimiento integrado.

---

## Procedimiento e historial del ensayo de captura original (referencia preservada)

El texto siguiente procede de F:\dev\vanfull-gps-android\frontend\technical\gps-probe.md.
Ese worktree permanece intacto. Describe otra entrada/APK y su configuración de
captura; su código no se copia a esta rama y sus permisos no se aplican a esta nueva
entrada. Se conserva el historial documental sin repetir pruebas físicas.

# Ensayo tecnico GPS Android (2026-10-22)

Base: main remoto a86ce5a2f8d8c657d198108367c24500116a617b.
Rama local chore/chofer-ensayo-gps-android, worktree F:\dev\vanfull-gps-android.
Autorizacion de implementacion local y coordinacion con Facundo en la conversacion.
Sin Issue/PR nuevo, commits ni publicaciones por instruccion expresa. #103 y demo ajenos.

## Alcance

Entrada lib/technical/gps_probe_main.dart; no cambia main.dart, navegacion ni pantallas
productivas. Una captura manual; ultima posicion y contador solo en memoria. Sin
backend, viajes, almacenamiento ni logs de coordenadas. No se registra historial.
El timestamp mostrado es el del proveedor, sin afirmar antiguedad verificada.
Permiso aproximado no se rechaza. No hay umbral de precision, antiguedad ni timeout.

Flutter 3.47.7, Dart 3.13.5, JDK 21.0.6, SDK API 36, Build Tools 36.0.0,
NDK 28.2.13676358. Gradle 9.3.1, AGP 9.1.0 y Kotlin declarado 2.4.0 sin cambios.
geolocator 14.1.2 exacto; geolocator_android 5.2.1 y platform_interface 4.4.1
resueltos en lockfile. Las dependencias preexistentes mantienen sus versiones.
Se reviso el codigo Android de 5.2.1: servicio no exportado tipo location,
foregroundNotificationConfig, cancelacion de actualizaciones y foreground.

## Configuracion y permisos

Parametros del ensayo: high, intervalo solicitado 10 s, distanceFilter 0 m,
foreground con notificacion continua y wake lock; sin Wi-Fi lock. No validan
RNF-008 ni garantizan frecuencia/precision. Inicio exclusivamente visible.
Manifest: COARSE_LOCATION, FINE_LOCATION, FOREGROUND_SERVICE,
FOREGROUND_SERVICE_LOCATION, POST_NOTIFICATIONS y WAKE_LOCK.
Sin ACCESS_BACKGROUND_LOCATION. No se duplica el servicio aportado por el plugin.
No se modifico MainActivity: Android 13 requiere habilitar las notificaciones
manualmente en Ajustes de la app para observar la bandeja. El ensayo no comprueba
ese permiso por codigo; su denegacion no equivale a denegar ubicacion.
No se agrega INTERNET en main; debug ya lo incluye por Flutter.
La resolucion federada puede agregar componentes transitivos al manifest;
el resultado de la fusion se registra tras compilar, sin ocultar adiciones.

## Procedimiento y escenarios pendientes

PowerShell dedicado, variables solo de proceso:

```powershell
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-21'
$env:ANDROID_HOME = 'F:\dev\android-sdk'
$env:GRADLE_USER_HOME = 'F:\dev\gradle-cache'
$env:PUB_CACHE = 'F:\dev\pub-cache'
# Invocar Flutter de F:\dev\flutter; evitar el problema previo de PATH con &.
```

Compilacion autorizada: flutter build apk --debug --no-pub -t lib/technical/gps_probe_main.dart.
La instalacion y apertura de esta APK fueron autorizadas y realizadas despues de compilar, sin recompilacion, tras comprobar ADB autorizado, ausencia de colision y SHA-256 coincidente. La APK usa el applicationId
com.vanfull.frontend de la base: antes de instalar, comprobar si reemplazaria una
app existente y coordinarlo; no se cambia ahora applicationId/flavors/Gradle.

Dispositivo del ensayo: Samsung Galaxy S20+ 5G / Android 13. ADB fue autorizado
antes de este desarrollo; no implica GPS validado. Habilitar notificaciones en
Ajustes; iniciar visible y pulsar Detener para terminar. Si se apaga ubicacion,
consultar estado y, tras reactivarla, iniciar explicitamente si se detuvo.
No hay reinicio automatico ni nueva captura por volver de segundo plano.

Registrar modelo/Android, estado de red y ubicacion por separado, bateria y
contador antes/despues, sin coordenadas, IDs personales ni capturas con posicion:

| Escenario fisico | Observacion requerida |
|---|---|
| Preciso/aproximado | Permiso real, precision autorizada/informada y recepciones |
| Denegado/permanente | Mensaje, sin captura y acceso a Ajustes |
| Ubicacion apagada/reactivada | Estado/error y recuperacion manual |
| Otra app y bloqueo, etapas de 5 min | Notificacion y recepciones; investigar entrega en rafaga |
| Modo avion | Red y ubicacion anotadas independientemente |
| Ahorro de bateria | Retrasos/interrupciones respecto de prueba normal |
| Retirada de recientes | Registrar resultado, sin promesa de continuidad |
| Cierre forzado | Escenario separado; sin promesa de recuperacion |
| Detener y reiniciar | Sin nuevos callbacks, notificacion/foreground terminados, nuevo inicio |

Cinco minutos es duracion tecnica, no requisito de negocio. Un contador mayor al
volver no demuestra que los eventos se entregaran durante el bloqueo: distinguir
captura del proveedor y entrega diferida mediante observacion fisica adicional.
El plugin mantiene un servicio bound a la actividad: comprobar fin del foreground
y de actualizaciones, diferenciandolo de la existencia residual del servicio bound.

## Verificacion

Pruebas del controlador con dobles adversos no demuestran continuidad Android.
- Formato de los tres archivos Dart correcto. flutter analyze --no-pub: sin problemas.
- flutter test --no-pub --reporter expanded: 98 aprobadas, 0 fallidas/omitidas;
  14 nuevas del controlador. Avisos de descarga de Google Fonts en tests del tema
  preexistente; sin modificarlos. Esta verificacion automatizada no ejecuto la APK en el telefono.
- Compilacion debug de la entrada tecnica: APROBADA, assembleDebug 1191,9 s
  (primera compilacion con descarga/preparacion de Gradle y dependencias).
  APK: build/app/outputs/flutter-apk/app-debug.apk, 159738461 bytes;
  SHA-256 0e0e0b7d78270795bef86f5a58eba1e2ba900e4e5c8590d5b8d52907fa7ffc52.
  aapt2 confirma compile/target SDK 36 y arquitecturas arm64-v8a, armeabi-v7a,
  x86_64; los permisos coinciden con el manifest revisado. La instalacion/apertura posterior se registra debajo. Formato final: tres archivos, cero cambios; git diff --check correcto.
- Manifest empaquetado revisado en build/app/intermediates/packaged_manifests/debug/
  processDebugManifestForPackage/AndroidManifest.xml. minSdk 24, targetSdk 36.
  Seis permisos del ensayo presentes; INTERNET procede de debug y AndroidX agrega
  com.vanfull.frontend.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION (firma).
  Unico servicio: com.baseflow.geolocator.GeolocatorLocationService, tipo location,
  enabled true y exported false. Sin ACCESS_BACKGROUND_LOCATION.
- Gradle 9.3.1 con daemon sobre Java 21 (JDK 21.0.6). Durante el primer build,
  Gradle instalo automaticamente API 35 revision 2: jni 1.1.0 / jni_flutter 1.0.4+1,
  ya presentes en el lockfile base, declaran compileSdk 35. API 36 se conserva.
  Advertencia de XML SDK 4 frente a lector hasta 3; avisos Java source/target 8 y
  API obsoleta en geolocator_android. Gradle tambien instalo CMake 3.22.1 para los componentes JNI de la base. No se cambiaron Gradle, JDK ni plugin.

Fuentes: https://pub.dev/packages/geolocator (14.1.2); codigo descargado de
geolocator_android 5.2.1; https://developer.android.com/develop/background-work/services/fgs/service-types#location;
https://developer.android.com/develop/ui/views/notifications/notification-permission.
## Observaciones manuales de Martín — 2026-10-22

Samsung Galaxy S20+ 5G, Android 13. Notificaciones habilitadas manualmente.
Fuente: observaciones comunicadas por Martín en la conversación; no son mediciones
instrumentadas. No se registran coordenadas, identificadores ni capturas con ubicación.

| Escenario | Observación comunicada |
|---|---|
| Captura con app visible | Contador creciente. |
| Primera detención | Contador estable en 11; desapareció la notificación. |
| Reinicio | Primer valor observado 1, luego creciente; reapareció la notificación. |
| Cambio a otra aplicación, ensayo indicado de 2 minutos | Contador 6 antes, 15 al volver y 16 después; notificación activa. |
| Pantalla bloqueada, ensayo indicado de 2 minutos | Contador 26 antes, 35 al desbloquear y 36 unos 15 segundos después. Notificación confirmada activa posteriormente. |
| Detención final | Contador estable en 41; desapareció la notificación. |

Las duraciones indicadas son las de esta tanda manual (2 minutos), distintas de
las etapas de 5 minutos propuestas en la matriz; no se verificó su duración con
instrumentación. La notificación posterior al desbloqueo no prueba que permaneciera
visible durante todo el bloqueo. La estabilidad observada del contador y la retirada
de la notificación no verifican por sí solas la terminación del servicio nativo.

Estas observaciones no permiten distinguir entrega continua de posiciones acumuladas.
No acreditan frecuencia, precisión, RNF-008 ni envío al backend. No constituyen una
aprobación completa del GPS ni una validación instrumentada de continuidad en segundo
plano. Los demás escenarios de la matriz siguen pendientes; esta actualización solo
registra lo informado, sin repetir pruebas, recompilar, instalar ni modificar código.

### Ubicación apagada y reactivada — observaciones manuales de Martín

- Al apagar Ubicación, la pantalla informó servicio desactivado y el contador se detuvo.
- Al reactivarla y actualizar el estado, mostró servicio activado, pero el contador permaneció en 3: sin reinicio automático observado.
- Al pulsar Iniciar captura, el contador volvió a 0 y reapareció la notificación.
- Al detener nuevamente, la captura se detuvo y desapareció la notificación.

Precisión posterior comunicada por Martín: después de reiniciar desde 0, el contador
aumentó hasta 6. Al pulsar Detener captura quedó fijo en 6 y desapareció la notificación.
La recepción de posiciones posterior a ese reinicio queda CONFIRMADA POR OBSERVACIÓN
MANUAL DE MARTÍN. Esta precisión resuelve el pendiente anterior de recepción tras
reactivar Ubicación y reiniciar manualmente; no se infiere solo de la notificación.
Son observaciones manuales, no mediciones instrumentadas ni aprobación completa del
GPS. No acreditan frecuencia, precisión, RNF-008 ni envío al backend. Los restantes
pendientes y límites de la matriz se mantienen. No se repitieron pruebas para esta
actualización documental.

### Permiso de ubicación denegado y habilitado desde Ajustes

Observaciones manuales de Martín:

- Con ubicación denegada: 0 posiciones y sin notificación.
- La pantalla mostró «Permiso: denied» junto con «Permiso bloqueado. Habilitar ubicación desde Ajustes».
- Tras habilitar el permiso desde Ajustes: mostró whileInUse, aumentó el contador y apareció la notificación.
- Detención final: contador fijo en 6 y notificación desaparecida.

La diferencia entre el estado mostrado denied y el mensaje de bloqueo queda
PENDIENTE DE REVISIÓN. No se afirma que se haya verificado deniedForever ni se
atribuye una causa a esa diferencia. La recuperación tras habilitar el permiso y
la detención se registran como observaciones manuales, sin medición instrumentada.
Se mantienen los límites anteriores y los demás escenarios pendientes; esta tanda
no acredita frecuencia, precisión, RNF-008, backend ni aprobación completa del GPS.
No se modificó código ni se repitieron pruebas para esta actualización documental.

### Ubicación aproximada — observaciones manuales de Martín

- Permiso whileInUse y precisión autorizada reduced.
- Apareció la notificación.
- Se observó una posición recibida: contador 1.
- No se observó incremento adicional durante la espera; la duración exacta no fue medida. No se afirman actualizaciones periódicas.
- Al detener, el contador quedó fijo en 1 y desapareció la notificación.

Esta tanda confirma por observación manual una recepción con ubicación aproximada,
no una cadencia de actualizaciones. No se registran coordenadas. Se mantienen los
límites anteriores, la diferencia denied/mensaje de bloqueo pendiente de revisión
y los demás escenarios pendientes; no acredita frecuencia, precisión, RNF-008,
envío al backend ni aprobación completa del GPS. No se modificó código ni se
repitieron pruebas para esta actualización documental.

### Modo avión — observaciones manuales de Martín

- Wi-Fi apagado y servicio de Ubicación activo.
- Precisión autorizada: precise.
- El contador siguió aumentando y la notificación permaneció activa.
- Al detener: contador fijo en 9 y notificación desaparecida.

No se midieron duración exacta ni frecuencia. El resultado acredita recepción local
de posiciones en esa configuración observada; no acredita envío, sincronización
offline ni continuidad garantizada. Se registran por separado la configuración de
conectividad observada (modo avión, Wi-Fi apagado) y el servicio de Ubicación activo.
Se mantienen los límites anteriores y los demás escenarios pendientes. No se
registran coordenadas ni identificadores. No se modificó código ni se repitieron
pruebas para esta actualización documental.

### Ahorro de energía activado — observaciones manuales de Martín

- Contador 2 antes de bloquear el teléfono.
- Contador 11 al desbloquear, tras la espera indicada de 2 minutos.
- Contador 12 unos 15 segundos después.
- Notificación activa y sin errores observados.
- Detención final: contador fijo en 14; notificación desaparecida.

Resultado favorable preliminar por observación manual. No distingue entrega continua
de posiciones acumuladas, no mide consumo ni garantiza continuidad. Los tiempos
indicados no constituyen una medición instrumentada de frecuencia o duración.
Se mantienen los límites anteriores y los demás escenarios pendientes; no acredita
RNF-008, envío al backend ni aprobación completa del GPS. No se registran coordenadas
ni identificadores. No se modificó código ni se repitieron pruebas para esta
actualización documental.

### Retirada de recientes — observaciones manuales de Martín

- Martín quitó la tarjeta del ensayo de aplicaciones recientes.
- La notificación desapareció.
- Al reabrir: «Captura detenida», contador 0 sin aumentar.
- No se observó reinicio automático.
- Contador previo a retirar: no informado.

No se afirma continuidad tras retirar de recientes ni se equipara esta acción a
cierre forzado. No se inspeccionaron proceso ni servicio mediante ADB; la desaparición
de la notificación y la pantalla al reabrir no permiten afirmar por sí solas qué
ocurrió con el proceso o el servicio nativo. Se mantienen los demás límites y
escenarios pendientes. El cierre forzado se documenta por separado a continuación. No se
registran coordenadas ni identificadores. No se modificó código, recompiló ni
repitieron pruebas para esta actualización documental.

### Cierre forzado desde Ajustes — observaciones manuales de Martín

- Contador previo: 2.
- Tras Forzar detención desde Ajustes, desapareció la notificación.
- Al reabrir: «Captura detenida», contador 0.
- Sin reinicio automático observado.

Este escenario se registra por separado de retirar la app de recientes. No se
infieren estados internos del proceso ni se garantiza recuperación. Son observaciones
manuales de la interfaz y la notificación, no una inspección instrumentada del proceso
o servicio. Se mantienen los demás límites del ensayo y las verificaciones pendientes.
No se registran coordenadas ni identificadores. No se modificó código, recompiló ni
repitieron pruebas para esta actualización documental.

## Acuerdo del equipo sobre control previo al inicio del viaje — 2026-10-22

**Autoridad:** decisión confirmada por los tres integrantes del equipo, comunicada
expresamente por el usuario en esta conversación. No se atribuye a una nueva
validación de VanFull. **Estado: ACUERDO CONFIRMADO; IMPLEMENTACIÓN PENDIENTE.**

Antes de solicitar el inicio del viaje, la app debe comprobar:

1. Servicio de ubicación del teléfono activado.
2. Permiso de ubicación concedido a VanFull.

Si falta cualquiera de las dos condiciones, debe bloquear la solicitud de inicio
y orientar al chofer para habilitarla. No se exige una primera posición: con
ubicación y permiso habilitados, la ausencia de posición por falta de señal no
bloquea por sí sola la solicitud. El acuerdo no define precisión mínima, frecuencia
ni tiempo de espera; tampoco equipara falta de internet con falta de ubicación.

### Historial y sustitución de la propuesta

La propuesta anterior de Martín planteaba exigir permisos, servicio activado y una
primera posición de la captura preparatoria antes de solicitar el inicio. Era una
propuesta para coordinar, no un acuerdo del equipo ni una validación de VanFull.
El acuerdo actual la sustituye: conserva las comprobaciones de servicio y permiso,
y elimina la exigencia de primera posición. Se conserva este antecedente como
historial, no como condición vigente.

Este control es previo y local en la app. No agrega por sí solo una validación del
servidor ni cambia la autoridad del backend sobre estado, permisos y asignaciones
del viaje. No modifica el contrato ni introduce campos o endpoints. Tampoco convierte
el ensayo técnico independiente en una integración con CU-030: aquí no se implementa
el bloqueo, no se envían solicitudes de inicio y no se acredita su funcionamiento.

### Referencias a armonizar en una tarea posterior

| Referencia | Armonización pendiente, sin cambios en esta actualización |
|---|---|
| CU-030 v1.3 íntegro, RF-025 y referencias ADJ-03 | Cotejar y formalizar el control previo de la app y la orientación al chofer; conservar las condiciones del viaje ya vigentes. La v1.3 íntegra no fue cotejada en esta sesión. |
| CU-030 Flutter y su reconciliación de inicio | Incorporar el control antes de solicitar inicio sin exigir una posición; revisar mensajes y pruebas. Respetar las operaciones inciertas existentes, sin interpretar el estado GPS como resolución de un POST previo. Coordinar sin intervenir en #103. |
| GPS CU-009/CU-030, aclaración #39/PR #63, archivo ACLARACION-FUNCIONAL-CU009-ISSUE39-v0.2-VALIDADA-ANALISIS.md | Distinguir habilitación para solicitar inicio de captura, recepción y tratamiento temporal de posiciones. No convertir primera posición ni antigüedad/precisión en condiciones nuevas de inicio. Las demás brechas de #39 conservan su estado. |
| backend/openapi/openapi.yaml y su JSON, POST /viajes/{id_viaje}/inicio y POST /viajes/{id_viaje}/ubicacion | Revisar coherencia con la frontera app/servidor; el acuerdo no autoriza añadir validación de servidor, campos ni cambios contractuales. No modificados. |
| PROMPT-PC2-Martin-Chofer-y-Viaje.md, contexto del área y procedimiento GPS | Mantener distinguido el acuerdo vigente de la propuesta histórica y de la implementación pendiente; alinear futuras tareas y sus criterios de prueba, sin declarar aprobación completa del GPS. |

Se conservan las observaciones manuales y sus límites, la diferencia denied/mensaje
de bloqueo pendiente de revisión y los demás escenarios pendientes. Esta actualización
solo documenta el acuerdo: no modifica código, #103, contrato, modelos, backend ni
reglas adicionales, y no ejecuta pruebas, commits, push o publicaciones.
