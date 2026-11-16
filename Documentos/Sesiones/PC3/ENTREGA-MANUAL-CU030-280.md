# CU-030 manual — aceptación única y entrega #280

Base: `71739f49b1427aa3523e46011e6085fa9cbe4c91`. Fecha: 15/11/2026.
Seguimiento único: https://github.com/Martiherenu1/ProyectoVanFull/issues/280.

## Procedencia y alcance

El pedido del 15/11 comunica por Martín acuerdos aprobados entre los tres: autoría/correlación explícitas con integridad, recuperación histórica por autor autenticado después de fin/reasignación, mensaje contextual para reserva propia consolidada y prioridad manual. Autoriza implementar, probar aisladamente, publicar PR y pedir revisión; no merge/despliegue. Es la fuente del acuerdo técnico, no una revisión de este diff por los compañeros. Los históricos S7/S8/S9 del análisis conservan sus fechas y estados originales.

Durante esta entrega, el usuario transmitió aclaraciones de Martín: «a todos» comprende pasajeros con reserva propia consolidada del viaje, incluidos quienes ya abordaron; también necesitan conocer demoras durante trayecto y llegada a destino. Espera push del teléfono con VanFull cerrada o pantalla bloqueada; una pantalla contextual no satisface esa expectativa. **Procedencia: recuerdo/aclaración comunicado por Martín, pendiente de validación con VanFull; no nueva aprobación conjunta.** El permiso de visualización de reserva consolidada sí estaba acordado. La definición funcional de destinatarios no configura un canal, proveedor, suscripción o garantía de entrega y no excluye WhatsApp del alcance previo.

El usuario confirma continuar registro, recuperación y mensaje contextual, mantener CU-037 pendiente y no simular envíos. Se implementa mensaje fechado de reporte, no estado activo de demora ni historial pasajero. No hay cambio del ciclo de viaje. La comunicación sigue siendo una brecha y CU-030 no se declara completo.

## Lista única de aceptación

O = fuente funcional aprobada (CU-030 v1.3, DA v1.2, RF-025/033; RN-029; MR-R29/R32). E = acuerdo técnico comunicado el 15/11. P = propuesta/ampliación pendiente.

| Requisito/origen | Soporte previo | Implementación/brecha | Verificación identificada |
|---|---|---|---|
| O/E Reporte manual propio en curso | Solo inicio/fin/GPS | POST avisos, rol chofer + asignación/estado bajo lock | `test_avisos`: permisos, estado, contenido |
| E Autoría/correlación explícita | Evento sin autor/clave | `id_cuenta_autora` FK cuenta real y UUID `clave_solicitud`; UNIQUE por autor/viaje/clave; CHECK pares/origen/clase | Integridad directa BD, tests modelos/migración |
| E Reintento seguro | Solo inicio/fin idempotentes | Misma clave y clase/texto normalizados por trim devuelve ID original; distinto contenido 409; clave distinta no fusiona | Duplicados/conflicto y concurrencia PostgreSQL |
| E Recuperación histórica propia | Ausente | GET resultado exige sesión y cuenta autora, sin exigir asignación o rol histórico actual | Recuperación tras cierre/reasignación; otra cuenta 404 |
| O/E Registro durable y error veraz | Helper hace flush | Commit antes de confirmar; rollback ante excepción; 5xx/red como incierto | Fallo tras flush; reconciliación por clave; tests widget |
| O/E Contenido interno protegido | No circuito | Solo autor al recuperar y administración/dueño al consultar avisos del viaje; sin contactos | Permisos, proyección pública, negativos HTTP |
| E Mensaje contextual consolidado | Ausente | GET dedicado revalida reserva/viaje; devuelve mensaje histórico fechado solo en curso. Sin precisión de minutos ni detalle interno | Reserva consolidada/provisional/cancelada, fin y privacidad |
| E Flutter reporte/recuperación | Ausente | Formulario, bloqueo de doble pulsación, misma clave ante incertidumbre, consulta propia histórica, descarte por viaje/sesión | Pruebas widget/API más regresiones sesión existentes |
| O MR-R32, históricos | 35 tablas, sin Notificacion | Se conserva número de tablas. Migración nullable no inventa autores históricos | SQL vs Alembic; downgrade protege avisos nuevos |
| O CU-037 intento/comunicación | No implementación/configuración en main | **Pendiente**: no_evaluada, sin envío, cola ni promesa. Mensaje contextual no reemplaza push | Inspección main y respuesta del usuario; no prueba real |
| P Automatismo S8 | Sin horarios por parada/configuración, coordenadas nullable | Separado: no se implementa detector ni tolerancia ni evidencia GPS paso | Análisis S8 conservado; sin inventar geocercas |
| O GPS/RNF-008; ramas DA | Implementaciones parciales e históricos | #39/#273 sin tocar. Tránsito/trayecto/ausencia/abordaje siguen dependencias independientes, sin ampliar facultades del chofer | Código/históricos; no nueva afirmación de cumplimiento |

## Decisiones internas de implementación

- Identidad de autor = cuenta autenticada, no chofer actualmente asignado ni nombre en texto libre. Eventos anteriores quedan autor/clave NULL. No hay autoría retroactiva.
- Comparación durable de contenido: `tipo_evento` explícito y `detalle_evento` normalizado por trim en Pydantic; no se utiliza texto/fecha para identificar dos hechos distintos ni se necesita un hash distinto del contenido canónico guardado.
- Lock de viaje serializa alta/reintento y finalización/reasignación. Restricción UNIQUE es segunda defensa. Repetición existente se reconoce antes de exigir asignación/estado actual; GET histórico solo requiere sesión y propiedad por cuenta.
- Acceso admin/dueño a avisos de cualquier viaje de esta empresa sigue el alcance administrativo actual (no hay modelo multiempresa/tenant); no habilita chofer/pasajero a consultar listas ni contactos.
- Proyección pasajero usa pasajero → viaje → lectura de reserva bajo lock del viaje, siguiendo orden global. Cancelación/finalización revalidadas; abordaje no se consulta para excluir destinatarios.
- Mensaje exacto implementado: «El chofer informó una demora durante este viaje. La situación actual no está confirmada.» más fecha de reporte. No equivale a `demora_activa`. Al finalizar no se proyecta mensaje; eventos quedan conservados.
- Notificación siempre `no_evaluada` porque CU-037 no está integrado. No se anuncia pendiente/fallo/envío/entrega. «Aviso registrado» confirma solo registro. La frase de fallo de Martín no se muestra sin ambos hechos acreditados.
- Migración 0002: compatible hacia adelante, preserva históricos. Downgrade se rehúsa si hay avisos nuevos para no perder autoría/correlación por accidente; exige respaldo/decisión humana, sin manipular datos automáticamente.

## Ensayo integrado preparado

En PostgreSQL desechable se ejecuta HTTP real in-process: alta autenticada → lectura por clave → reintento → consulta interna → mensaje consolidado → cierre/reasignación → recuperación propia histórica. Las pruebas automatizadas usan JWT sintéticos y datos temporales, sin autenticarse contra servicios externos. Flutter usa transporte/dobles controlados para fallos y respuesta tardía; no equivale a ensayo físico Android/HTTP productivo.

Para un ensayo físico posterior: identificar SHA de APK/API y dataset **nuevo** aislado; cuenta chofer asignada, pasajero consolidado y admin; registrar clave antes del POST; comprobar el mensaje sin detalle y la recuperación tras cierre. No usar viajes/APK/base originales ni reiniciar Neon. No se ejecuta un envío real en esta entrega. Resultados concretos de suites y CI se registran al cierre con su SHA y no se atribuyen a otro HEAD.

## Propuesta push para coordinar CU-037 (sin servicios externos configurados)

1. **Plataformas:** Android tiene captura/pruebas previas y proyecto nativo; iOS y Web tienen directorios pero no evidencia aquí de push funcional. Presencia del directorio no prueba soporte. Revisar alcance real con Facundo antes de introducir paquetes. Android requiere permisos según versión, canales/importancia y comportamiento background del proveedor elegido. iOS requiere permisos, capacidades y configuración APNs/aplicación; prueba real requiere equipo/identidad de firma/dispositivo adecuados. Web requiere permiso de navegador, contexto seguro y mecanismo/service worker compatible; no es push nativo de teléfono por defecto.
2. **Permisos/tokens:** solicitar consentimiento en contexto claro; registrar token/endpoint como dato de dispositivo, con plataforma y asociación a cuenta autorizada por servidor; renovar/invalidar al rotar, retirar inválidos según evidencia. No aceptar un ID de pasajero arbitrario elegido por cliente. Modelo/operaciones de registro de dispositivos son **propuesta fuera del acuerdo estructural actual**, requieren revisión; no agregar entidad Notificacion por inferencia.
3. **Sesión y privacidad:** cambio/cierre de sesión desvincula autorización del dispositivo y previene contenido de la cuenta anterior; definir efecto offline y revocación con sesión común. Payload mínimo sin descripción interna ni contactos. Al abrir la app, consultar información vigente bajo permisos, no confiar en el payload para autorizar.
4. **Selección funcional:** reserva propia consolidada del viaje, incluidos abordados, según aclaración de Martín pendiente VanFull. El servidor selecciona; definir momento de la selección y revalidación ante cancelación/concurrencia, sin extender automáticamente permiso de pantalla a suscripciones/envíos. Persistencia del incidente no implica aceptación por proveedor.
5. **Resultados:** separar registro confirmado, tarea/intento acreditado, aceptación del proveedor, entrega acreditada si el canal la soporta y lectura. Timeout deja incertidumbre, nunca fallo inferido. Reintentos, correlación del envío y fallback aún por acordar. Mantener WhatsApp como canal principal previsto, sin proveedor seleccionado. Un push aceptado no garantiza aparición en pantalla bloqueada.
6. **Estados del dispositivo:** distinguir app en foreground/background o proceso no abierto, pantalla bloqueada, cierre forzado por usuario y restricciones del sistema (batería, permisos, red, políticas). No prometer recepción tras cierre forzado o restricciones. La prueba física debe registrar versión de SO, configuración y estado real, por plataforma.

**Estado vigente de CU-037:** coordinación pendiente entre los tres, sin responsables asignados ni aceptación de la distribución anterior. Faltan proveedor/canales, plataformas efectivas, política, proyecto/identificadores, accesos al servicio elegido, configuración por plataforma y dispositivos con consentimiento. No se han solicitado ni usado credenciales en el repo. Envío real requerirá autorización nueva: el pedido vigente lo prohíbe.

**Histórico — propuesta de reparto no aceptada, sin vigencia como asignación:** «equipo/CU-037 debe elegir proveedor/canales y política; Martiniano coordina identidad, asociación de dispositivos y permisos backend; Facundo configuración/plataformas Flutter y despliegue de cliente; Martín validación funcional con VanFull y escenarios de viaje». Se conserva como antecedente, no como compromiso de sus integrantes. Las menciones anteriores a consultar aspectos de plataforma con Facundo tampoco designan un responsable de CU-037.

## Estado de publicación y pruebas

### Revisión de Facundo sobre 8b3466f — UUID de recuperación, 16/11/2026

**Procedencia:** el usuario comunica que Facundo revisó `8b3466f479a3735b2a4e0063d0bdde4b5f09848d` y confirmó resueltos los P1/P2 anteriores, pero informó otro P2: una recuperación exitosa con UUID mayúscula no retiraba su referencia incierta. No se atribuye aprobación formal/final de Flutter. HEAD local/remoto verificados en ese SHA; main remoto `6f111c10ce8126ee338e978a5070d6fafdc73260`. Sin necesidad de nuevo merge.

**Reproducción anterior al cambio:** transporte controlado devuelve registro confirmado y clave canónica; pantalla muestra «Aviso registrado (#51).», pero conserva tres referencias en vez de retirar solo viaje/clave confirmados. Regresión nueva `frontend/test/screens/chofer/referencias_aviso_test.dart`, log `cu030-uuid-rojo.log` fuera de Git en Temp. Fixtures preparan referencias inciertas por callbacks de detalle; no generan fallos sobre Neon ni simulan notificaciones.

**Corrección mínima:** recuperación normaliza `trim().toLowerCase()` antes de consultar/callback de confirmación; el adaptador aplica la misma normalización también al invocarlo directamente. `ReferenciaAviso.clave` expone la representación canónica, conservando constructor const e identidad de viaje; el shell usa esa representación al conservar, detectar duplicados, comparar y retirar. No cambia permisos ni generación de sesión. Validación UUID del servidor y controles de viaje, clave e identidad/confirmación de la respuesta intactos; no se modifica backend, contrato, modelo o migración.

**Aceptación de la corrección:** UUID con mayúsculas/espacios exteriores consulta canónicamente; confirmación retira solo su par viaje/clave; otra clave en el mismo viaje y misma clave en otro viaje permanecen. Errores 400/404/500, timeout, respuesta con otra clave/viaje o registro no confirmado no retiran referencias. UUID inválida rechazada no se transforma en válida; respuestas tardías de éxito/error no retiran referencias de otra sesión. Se mantienen las pruebas anteriores P1/P2, teclado/navegación y RNF-008. Resultados locales finales, SHA y CI del HEAD publicado se registran en #281 después de observarlos.

**Resultado local:** 189 pruebas pertinentes aprobadas (82 s), incluidas 12 nuevas; `flutter analyze --no-pub` sin observaciones (13,3 s), formato y diff check correctos. Tandas cubren normalización/retiro selectivo, errores, sesión, P1/P2, navegación, teclado, mapa/ausencias y RNF-008. Logs `cu030-uuid-regresiones.log` y `cu030-uuid-analyze.log` en Temp fuera de Git. No nueva suite backend local ni ensayo desplegado; la CI exacta del nuevo HEAD se registra en #281 al observarla.

El guion `Documentos/Sesiones/PC3/GUION-ENSAYO-CU030.md` sigue **local sin publicar**: T06 incorpora este escenario en transporte controlado, NO EJECUTADO como ensayo desplegado; conserva preparación de reserva antes de inicio y M09-A/M09-B con reasignación bloqueada. No se incluye el guion ni otros archivos locales en el commit de corrección.

**Pendientes conservados:** aprobación final Flutter por Facundo; revisión de modelo/migración por Martiniano; respaldo actual de Neon con restauración aislada probada y ventana sin uso/responsable confirmado antes del merge. CI verde o Docker local no acreditan esas condiciones. CU-037/notificaciones reales pendientes; CU-030 parcial. Sin merge hacia main, despliegue ni operaciones Neon/Render. Históricos siguientes conservados.

### Corrección de auditoría de Facundo — 16/11/2026

**Avance concurrente posterior:** después del push de corrección `482c49ddb37ead6b8fc685843409c12c5f261136`, GitHub informó `dirty` y no lanzó CI. `ls-remote`/fetch mostraron main nuevo `6f111c10ce8126ee338e978a5070d6fafdc73260`, que incorpora RNF-008/#272/#292/#294. Se reprodujeron conflictos solo en los dos contextos y se resolvieron conservando ambos bloques, sin sustituir CU-030 ni RNF-008. Merge normal `9edfebc88e9fe13898337544ce787fa99a44965c`, padres `482c49d` y `6f111c1`; sin rebase/force-push. Código incorporado RNF-008 idéntico a main; correcciones/pruebas CU-030 idénticas a `482c49d`; SQL/ORM/migración intactos respecto de `4c92b768`. YAML/JSON equivalentes; conserva todo el contrato de main y las operaciones CU-030: las únicas definiciones de `482c49d` actualizadas por main son GET ubicación y schema Ubicacion. Los resultados de 139 pruebas/6 s de analyze siguientes corresponden al corte anterior a este segundo merge, no a la nueva integración. Verificación posterior y CI exacta del HEAD final en #281.

**Verificación posterior a integrar RNF-008:** 177 pruebas locales aprobadas (86 s), incluyendo las regresiones anteriores y las tres nuevas suites GPS de main (modelo de vigencia, pantalla y referencia HTTP). `flutter analyze --no-pub` sin observaciones (11,3 s). Logs `cu030-integracion-rnf-pruebas.log` y `cu030-integracion-rnf-analyze.log` en Temp fuera de Git. Se conserva el diff específico de corrección `c75e368..482c49d` separado de la resolución documental `482c49d..9edfebc`; documentación posterior no cambia código. CI exacta del HEAD publicado en #281 tras observarla.

**Procedencia:** Martín informa auditoría de Facundo sobre `4c92b76867e65e56c5d8346b294161d26733d225`: P1 (`main.dart`, 770–789), protección común de 403; P2 (`chofer_shell.dart`, 244–263), acción global sobre rutas internas. Esa auditoría no constituye aprobación formal del código anterior ni del nuevo HEAD; Facundo debe volver a revisar el diff publicado.

**Base comprobada e integración:** HEAD remoto coincidía con `4c92b768`; main efectivo `4198022f7080d83b30715d5509d9f944e8ba1d7b`. Merge normal `c75e36801f1eec92117aadf06ac9b1dc5964b193`, sin rebase/force-push ni merge hacia main. Unión automática sin conflictos textuales; conserva CU-023/#288, CU-033/#290 y mensajes/documentación de #291. Comparación del JSON verifica cada operación/schema de ambos padres sin cambiar sus definiciones; YAML/JSON equivalentes (47 rutas), backend incorporado idéntico a main salvo composición aditiva de routers. No se incorporan ramas independientes RNF-008/ETA ni se altera su trabajo.

**Reproducción antes de corregir:** dos pruebas de integración nuevas fallan al exigir acceso denegado ante 403 de alta y recuperación; el alta absorbía 403 en `AvisoRechazado` y ninguno de los dos callbacks pasaba por `_protegerAcceso`. La prueba de navegación falla porque «Resultado propio» sigue visible sobre el detalle. Al ampliar la comprobación con POST pendiente y transición completa también se reproduce que retorno del sistema retira el formulario: delegación `pop()` ignoraba su `PopScope`. Logs locales saneados: `cu030-auditoria-p1-rojo.log`, `cu030-auditoria-p2-rojo.log`, `cu030-p2-pop-rojo.log`, fuera de Git en Temp. No se alteraron las protecciones para aprobar las pruebas.

**Diff específico de P1:** `main.dart` aplica `_protegerAcceso` a registrar/recuperar, manteniendo `_exigirSesion` antes y después; `AvisosApi` deja pasar el 403 original hasta esa protección. No cambia la política común, no cierra sesión por 403 ni convierte 401 tardío en cierre de otra cuenta. Rechazos 400/401/404/409 del adaptador y resultados inciertos conservan su tratamiento; prueba unitaria exige conservar el status 403.

**Diff específico de P2:** el FAB pasa del Scaffold global a la ruta raíz del listado del navegador interno; no se presenta en detalle, reporte ni recuperación. El retorno delegado usa `maybePop()` para respetar `PopScope` del formulario ocupado. La salida explícita incierta sigue disponible al finalizar la solicitud; conserva viaje/clave en la misma sesión y recuperación manual, sin envíos/consultas automáticos. No se elimina el bloqueo ni se vacían referencias al navegar.

**Verificación:** reproducciones con transporte HTTP controlado, sin red real. Pruebas nuevas: 403 vigente en ambas operaciones, 401 vigente, éxito/401/403 tardíos en alta y recuperación tras cambiar cuenta, ausencia de acción global en rutas internas y retorno bloqueado mientras el POST está en curso. Regresiones incluyen incertidumbre, recuperación de misma clave, teclado de teléfono, shell, permisos/sesión comunes, mapa y ausencias. `flutter analyze --no-pub`: sin observaciones (117,3 s). Conteo final de pruebas, SHA de corrección/documentación y CI exacta se registran en #281 después de observarlos; no se atribuye la CI de `4c92b768` al HEAD nuevo.

**Resultado local final:** 139 pruebas aprobadas (67 s), incluidas las once regresiones nuevas; formato correcto de los cinco Dart modificados y `flutter analyze --no-pub` final sin observaciones (6 s). Logs de regresión y analyze final en Temp fuera de Git. La CI completa backend/Flutter del HEAD publicado se registra en #281 al observarla; no se ejecutó una suite backend local en esta corrección de frontend.

**Pendientes intactos:** revisión de models/migrations por Martiniano, nueva revisión de Facundo, respaldo actual de Neon con restauración aislada probada y ventana acordada sin uso **antes del merge**. CU-037 sigue pendiente entre los tres sin responsables asignados; entrega parcial respecto de comunicación. Sin migraciones remotas, acceso a Neon/Render, despliegue, APK nueva ni merge hacia main; el efecto futuro automático de Render sigue vigente según la sección siguiente.

### Precisiones de Martiniano comunicadas por Martín — condiciones anteriores al merge

Procedencia: mensaje del usuario que transmite las precisiones de Martiniano; no aprobación formal del HEAD ni autorización para operar Neon/Render. **Antes del merge se requieren** revisión de models/migrations por Martiniano, revisión del diff publicado por Facundo, respaldo actual de Neon con restauración aislada probada y ventana acordada sin uso de la base. Ninguno de esos pendientes se acredita con CI o con el respaldo/ensayo previo de PostgreSQL local. No se verificó ni se produjo un respaldo de Neon durante este trabajo.

**Efecto futuro:** `render.yaml` vincula el backend a `main`, con filtro `backend/**`, `autoDeployTrigger: checksPass` y `dockerCommand: sh arrancar.sh`. `backend/arrancar.sh` ejecuta `alembic upgrade head` antes de Uvicorn. Un merge que active el despliegue puede aplicar 0002 automáticamente sobre la base configurada, incluida Neon; no debe esperarse una orden manual posterior. Reiniciar o volver a desplegar también pasa por ese arranque. La configuración efectiva del panel y la base destino no fueron inspeccionadas. «No se ejecutaron migraciones remotas durante este trabajo» describe acciones realizadas, **no garantiza que un merge futuro sea inocuo**. Las instrucciones históricas de despliegue siguientes quedan subordinadas a estas condiciones.

**Integración comprobada sin merge nuevo:** HEAD local/remoto `449ba07a2b96337262a45dfe6f42cba845b58557`; `git fetch`/`ls-remote` muestran main `d15a5d92f593dfc994a2acb236a6878d3b91be29` (CU-023/#288). Conector y REST de GitHub informan PR abierta, no fusionada, `mergeable=true` (REST `clean`), pero todavía base `df1ad20729b5a5c1eb1d1ac77ef2450ff004a929`. No se confunde ese metadato con la punta remota actual. `git merge-base` devuelve `df1ad20`; `git merge-tree --write-tree HEAD origin/main` termina con código 0 y árbol `597a26297f81986883e85fd69b4e1ad52abe64a9`, sin conflictos y sin cambiar rama, índice ni archivos. Esta simulación escribe objetos locales, no crea un commit/merge ni acredita CI del árbol combinado. No se incorpora main de nuevo solo para refrescar GitHub. Los merges históricos siguientes permanecen intactos.

### Procedimiento operativo concreto — preparado, NO ejecutado; bloquea el merge hasta acreditarlo

1. **Cerrar revisión y ventana.** Registrar SHA revisado, diff de `models`/SQL/0002 y conformidades de Martiniano y Facundo, sin extender la revisión de `bb1ceb5` al HEAD actual. Acordar inicio/fin de ventana sin uso de la base y quién ejecutará/verificará cada operación; no se asigna por este documento. Identificar todos los escritores (instancias API, clientes, tareas e integraciones), detener su uso y acreditar ausencia de actividad antes del respaldo. No hay un modo de mantenimiento implementado acreditado aquí: acordar el mecanismo y accesos antes de empezar. Revisar en Render rama, filtros, arranque, auto-deploy y despliegues en cola; si se decide desactivar temporalmente automatismo, hacerlo solo con autorización y registrar su restitución. No mergear mientras esas garantías falten.
2. **Identificar origen y destino sin exponer secretos.** El operador autorizado confirmará proyecto/rama/base de Neon, versión PostgreSQL, revisión de `alembic_version`, extensiones, roles/privilegios y tamaño. Esperado por esta PR: 0001 → 0002; si la revisión efectiva difiere, detener y revisar, no usar `stamp`. Elegir herramientas compatibles (pg_dump no más antiguo que el servidor) y restauración local aislada de la misma versión mayor, extensiones compatibles, volumen nuevo, sin acceso de aplicaciones productivas. Configurar fuera de Git/OneDrive perfiles libpq `vanfull_neon_source` (conexión directa sin pool, TLS requerido por Neon) y `vanfull_restore_isolated` (solo loopback/base nueva), con credenciales protegidas por ACL del usuario. No poner URLs/contraseñas en comandos, chat, logs o archivos versionados; no reutilizar el entorno de Render para la copia local.
3. **Respaldo actual de Neon, aún sin merge.** Con ventana sin uso vigente, obtener archivo custom completo de esa base en almacenamiento protegido fuera del repo/OneDrive. Ejemplo PowerShell **para ejecución humana futura**, perfiles ya preparados y carpeta protegida existente:

   ```powershell
   $archivoRespaldo = Join-Path $env:LOCALAPPDATA ('VanFullBackups\neon-pre-cu030-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.dump')
   pg_dump --dbname=service=vanfull_neon_source --format=custom --no-password --file=$archivoRespaldo
   if ($LASTEXITCODE -ne 0) { throw 'Respaldo incompleto: detener antes del merge' }
   Get-FileHash -Algorithm SHA256 -LiteralPath $archivoRespaldo
   pg_restore --list $archivoRespaldo
   if ($LASTEXITCODE -ne 0) { throw 'Archivo ilegible: detener' }
   ```

   Guardar hora, identificador saneado del origen, versiones, SHA del código, revisión Alembic, tamaño, hash y códigos de salida. El archivo y su listado pueden contener datos/identificadores: no publicarlos. `pg_dump` conserva una instantánea consistente pero no bloquea escritores; **no reemplaza** la ventana acordada. No cubre objetos globales del clúster; inventariar roles/privilegios/extensiones y su recreación autorizada por separado, sin exportar contraseñas. Definir retención y custodia del respaldo, no borrarlo al terminar el ensayo.
4. **Restaurar de verdad, exclusivamente en aislamiento.** Antes de conectar, comprobar que el perfil destino resuelve a loopback, a instancia/volumen nuevo y base vacía; registrar `current_database()`, `inet_server_addr()` y versión en ese destino. Si coincide con Neon, con la base original local o no puede acreditarse aislamiento, detener. No usar `--clean`, `--create` ni destino remoto. Sobre la base vacía preparada:

   ```powershell
   pg_restore --dbname=service=vanfull_restore_isolated --no-password --exit-on-error --single-transaction --no-owner --no-privileges $archivoRespaldo
   if ($LASTEXITCODE -ne 0) { throw 'Restauracion fallida: merge bloqueado' }
   ```

   No basta `--list`: exigir restauración completa sin errores. La copia omite propietarios/grants para aislarla bajo su rol local; no acredita restauración de privilegios productivos. Verificar todas las tablas, cantidades exactas, secuencias, PK/FK/CHECK/UNIQUE, extensiones y revisión Alembic contra la instantánea de origen durante la ventana. Comparar también valores históricos (exportaciones ordenadas por PK o hashes canónicos protegidos), no solo conteos. Mantener manifiesto anterior a 0002 para comprobar conservación posterior. Los datos reales restaurados siguen siendo sensibles: no volcarlos en CI/PR; no conectar esa copia a proveedores ni servicios reales.
5. **Ensayar 0002 en la copia restaurada.** Configurar el backend del SHA revisado para esa instancia local exclusivamente; revalidar destino antes de Alembic. Desde `backend`, ejecutar `alembic current`, `alembic heads`, `alembic history`, `alembic upgrade 0002`, `alembic current` y `alembic check`, deteniéndose ante cualquier error. Debe quedar 0002 como única revisión normal prevista. Verificar en `evento_operativo` columnas nullable `id_cuenta_autora`/`clave_solicitud`, FK `evento_operativo_id_cuenta_autora_fkey`, UNIQUE `uq_aviso_solicitud` y CHECK `ck_aviso_metadatos`; comparar definiciones con SQL/ORM/migración, no solo nombres. Todas las filas anteriores deben conservar columnas originales/valores y ambos metadatos NULL; mismas tablas/secuencias y cantidades antes de ensayos funcionales. Repetir `upgrade 0002` sin cambios. Ejecutar el ensayo funcional solo con cuentas/viaje/reservas nuevos acordados en la copia (alta, recuperación misma clave, conflicto y permisos, mensaje sin detalle interno), sin notificar y sin modificar filas históricas. Registrar evidencias saneadas y versiones/SHA. Un ensayo sobre base sintética previa no sustituye esta restauración de Neon.
6. **Decidir seguir o detener antes del merge.** Evidencia mínima: revisiones del HEAD, respaldo Neon vigente y hash, restauración y comparación satisfactorias, ensayo 0002, ventana todavía sin uso, plan de recuperación y configuración efectiva de despliegue confirmados. Si vuelve a usarse la base, avanza la revisión/datos o cambia el HEAD, evaluar vigencia y repetir lo que corresponda **antes** de autorizar merge; no asumir válido un respaldo antiguo. La autorización para preparar esto no autoriza merge ni operaciones remotas. No ejecutar el seed de demo, `--reiniciar`, `stamp` ni downgrade para resolver discrepancias.
7. **Despliegue futuro autorizado.** Solo después de esos requisitos y autorización expresa: registrar SHA final de main y observar el deployment que realmente inicia Render. No lanzar además otra migración concurrente. El arranque aplicará `upgrade head`; verificar logs saneados de revisión aplicada, estado Alembic y constraints con operador autorizado, conservación de datos y health antes de reabrir uso. Un health correcto no prueba preservación ni identifica SHA. Si falla, mantener la ventana, detener nuevos despliegues/escrituras y diagnosticar; no reintentar ni restaurar automáticamente. Rollback de aplicación y rollback de datos son decisiones distintas: el downgrade rehúsa avisos nuevos y la restauración puede perder escrituras posteriores; conservar evidencia y decidir recuperación con el equipo, sin borrar datos.
8. **SHA efectivos y ensayo final.** Backend: registrar ID/hora/SHA del deployment **Live** en Render y cotejar con main revisado. Web: registrar SHA fuente del workflow manual, run/input/API base usados, commit generado en `sitio-web` y deployment Live en Render/Pages; no suponer igualdad de esos SHA ni usar el commit de PR como prueba de publicación. Verificar cliente servido y API con dataset/roles/viaje acordados, sin reutilizar APK o datos previos; separar widget local de teléfono físico. Comprobar ausencia/error/reporte fechado, permisos, timeout y recuperación, sin envíos simulados. Reabrir uso solo tras registrar resultado y acuerdo. Aquí no se verificaron SHA Live ni se ejecutaron esos pasos.

**Fuentes del procedimiento:** código versionado `render.yaml`, `backend/arrancar.sh`, `backend/migrations/versions/0002_avisos_cu030.py`; [Neon: backup con conexión directa](https://neon.com/docs/manage/backup-pg-dump), [PostgreSQL: pg_dump](https://www.postgresql.org/docs/current/app-pgdump.html), [PostgreSQL: pg_restore](https://www.postgresql.org/docs/current/app-pgrestore.html) y [Render: despliegue automático y estado Live](https://render.com/docs/deploys), consultadas en esta revisión. Solo lectura de documentación pública; sin acceso a cuentas Neon/Render. Procedimiento preparado, respaldo/restauración/operaciones remotas **pendientes**.

### Integración del main efectivo para revisión — 15/11/2026

El usuario informó `mergeable=false` para #281 sobre `c9c977d` y pidió incorporar main por merge normal. Al verificar con `git fetch` y `git ls-remote`, main efectivo era **`df1ad20729b5a5c1eb1d1ac77ef2450ff004a929`**, que integra CU-013/#286; `7107233` ya era ancestro de la rama. El metadato del conector aún mostraba ese SHA anterior, por lo que no se usó como prueba de que main no hubiera avanzado. La simulación local y el merge efectivo no reprodujeron conflicto textual: Git unió automáticamente los archivos coincidentes y se revisó el resultado antes de registrarlo. No se inventa una resolución manual ni se considera que la observación de GitHub demuestre pérdida de código.

**Merge normal registrado:** `7792c645fbbb1db0a32ca8747adc00d8aebd3012`, primer padre `c9c977d0d6489c4ca0ecc0ea4548b2e8b089e0c9`, segundo padre `df1ad20729b5a5c1eb1d1ac77ef2450ff004a929`. Sin rebase, force-push ni modificación de commits publicados. Integra main hacia la rama de #281, no la PR hacia main.

**Diff para Martiniano y Facundo:** [comparación completa de la integración](https://github.com/Martiherenu1/ProyectoVanFull/compare/c9c977d0d6489c4ca0ecc0ea4548b2e8b089e0c9...7792c645fbbb1db0a32ca8747adc00d8aebd3012). Reproducible con `git diff c9c977d0d6489c4ca0ecc0ea4548b2e8b089e0c9 7792c645fbbb1db0a32ca8747adc00d8aebd3012`: nueve archivos, 1456 líneas agregadas y 3 retiradas. Incluye rutas/servicio/schemas/pruebas administrativos de pasajeros, registro del router, contrato YAML/JSON, README del contrato y contexto de pasajero. Los cuatro archivos nuevos de CU-013 son idénticos a main; el contrato conserva cada operación y schema de ambas referencias sin alterar sus definiciones (38 rutas, 38 schemas). YAML/JSON equivalentes y JSON regenerado en temporal idéntico al fusionado.

- `backend/app/main.py` conserva `avisos` y agrega importación/registro de `pasajeros`; las pruebas de rutas/contrato verifican ambos circuitos.
- El README y los dos formatos del contrato conservan CU-030 y añaden las operaciones/pendientes de CU-013 de main. No se vuelve a una versión anterior del contrato ni se amplía funcionalidad por inferencia.
- Frontend completo, CU-005/#275, mensaje fechado y sus estados, salida incierta/recuperación/aislamiento, SQL ordenado, ORM y migración 0002 permanecen sin cambios respecto de `c9c977d`. No se modifica la implementación de CU-007, RNF-008 ni APK.
- Verificación local sobre el árbol fusionado: Ruff correcto y formato de 128 archivos; **71 pruebas backend focalizadas aprobadas**, 106 warnings, 64,97 s (`test_pasajeros_admin`, `test_avisos`, `test_avisos_migracion`, `test_contrato`, `test_rutas_contrato`, `test_modelos`, `test_migracion`). PostgreSQL 16 exclusivo desechable, sin bases/volúmenes previos; contenedores retirados. **41 pruebas Flutter focalizadas aprobadas**, 19 s, con CU-005/mensaje contextual, navegación, teclado y sesión. No se atribuye una nueva suite local completa; la CI completa del HEAD final se registra en #281 tras observarla.

La conformidad de Martiniano sobre diseño en `bb1ceb5` continúa siendo la comunicada por Martín, sin aprobación formal del HEAD posterior. Facundo aún debe revisar el diff publicado. Los resultados/HEAD anteriores siguientes son históricos. CU-037 sigue separado; no se simulan envíos. Sin merge hacia main, despliegues ni operaciones remotas sobre bases.

### Observaciones de revisión comunicadas por Martín — 15/11/2026

Martín informa que **Martiniano revisó el corte `bb1ceb5` y está conforme con el diseño de idempotencia, permisos y locks, pero todavía no aprueba**. Revisará el HEAD final. El acuerdo estructural previo fue comunicado por Martín; no se convierte esa procedencia en aprobación formal del diff. **Facundo aún debe revisar el diff publicado.** Solicitudes de revisión, conformidad de diseño y aprobación formal son hechos diferentes.

- Main revalidado: `7107233b7097870ca5731cf9137209faf326608d`, ya integrado por merge normal `046173bce3bd7dc9dc34228f7ca16ee9344ee138`. Se conserva ese merge, CU-005/#275 y el mensaje contextual. Sin rebase, force-push ni merge de la PR hacia main.
- `schema.sql`: comentario «históricos» corregido; primero columnas, luego constraints de tabla; FK de autor junto a las FK de `evento_operativo`, antes del seed. Se mantienen orden/tipos de columnas, expresiones y nombres de constraints, ORM y migración 0002, así como históricos sin autor inventado. El cambio es de orden/presentación del DDL, no una migración nueva.
- Fecha del reporte: `DD/MM/AAAA a las HH:mm (hora local)` mediante `fechaLegible`, con conversión al horario local del dispositivo. Una fecha requerida ausente/inválida es error, no ausencia de aviso. No cambia el contrato ni se estima una demora activa.
- Mensaje contextual con cuatro resultados distinguibles: consultando; respuesta sin reporte («No hay reportes de demora para mostrar»); error de consulta con reintento manual; reporte fechado con actualización específica. La ausencia de reporte no afirma que no haya demora. Un error retira el contenido previo y no se presenta como ausencia; cargar no habilita consultas duplicadas. Se elimina el control genérico «Actualizar información del viaje»; sin reporte no se muestra un botón aislado sin contexto.
- La salida segura del fix anterior se conserva: salir no cancela/rechaza el aviso; referencias de viaje/clave solo en la sesión; consulta posterior explícita; sin reenvíos automáticos ni datos de otras cuentas. Nueva prueba del **formulario** a 360 × 640 con teclado de 300 px verifica entrada, timeout, consulta fallida y salida mediante desplazamiento, además de la prueba existente de recuperación con teclado. Son widgets controlados, no una prueba física ni APK nueva.
- Nueva regresión conjunta en MisReservas: una reserva propia consolidada muestra reporte fechado y mantiene el botón/callback de cambio de parada de CU-005. No se amplían permisos ni estados habilitantes.

#### Diff de compatibilidad para Martiniano

Comparación del archivo `mis_reservas_screen.dart` entre main `7107233` y el resultado de la rama: CU-005 permanece intacto; se añaden importación, parámetro/campo y mensaje contextual. El constructor mantiene **ambos** parámetros nombrados. Es el resultado del merge normal ya publicado, no una propuesta de rebase. Reproducible con `git diff --unified=8 7107233b7097870ca5731cf9137209faf326608d..HEAD -- frontend/lib/screens/pasajero/mis_reservas_screen.dart`.

```diff
diff --git a/frontend/lib/screens/pasajero/mis_reservas_screen.dart b/frontend/lib/screens/pasajero/mis_reservas_screen.dart
index 82f5549..043d623 100644
--- a/frontend/lib/screens/pasajero/mis_reservas_screen.dart
+++ b/frontend/lib/screens/pasajero/mis_reservas_screen.dart
@@ -1,8 +1,9 @@
+import 'mensaje_demora.dart';
 import 'accion_informar_ausencia.dart';

 import 'package:flutter/material.dart';

 import '../../core/format/fecha_legible.dart';
 import '../../core/format/importe.dart';
 import '../../core/theme/app_colors.dart';
 import '../../core/theme/app_spacing.dart';
@@ -24,29 +25,31 @@ typedef CancelarReserva = Future<ResultadoCancelacion> Function(int idReserva);

 /// CU-010 y CU-006, con la cancelación de CU-004. La pantalla no crea clientes
 /// HTTP ni calcula el saldo ni decide qué se puede cancelar: lo rechaza el
 /// backend y se muestra su motivo.
 class MisReservasScreen extends StatefulWidget {
   const MisReservasScreen({
     super.key,
     required this.cargarReservas,
+    this.cargarMensajeDemora,
     required this.cargarDeuda,
     required this.cancelarReserva,
     required this.onBuscarServicio,
     this.onRegistrarPago,
     this.onVerUbicacion,
     this.onCambiarParada,
     this.informarAusencia,
     this.alcanceAusencia,
     this.contextoAusenciaVigente,
     this.versionReservas = 0,
   });

   final CargarReservas cargarReservas;
+  final CargarMensajeDemora? cargarMensajeDemora;
   final CargarDeuda cargarDeuda;
   final CancelarReserva cancelarReserva;

   final InformarAusencia? informarAusencia;
   final Object? alcanceAusencia;
   final bool Function()? contextoAusenciaVigente;

   /// Solicita la recarga existente sin destruir el estado de la pantalla.
@@ -322,16 +325,24 @@ class _MisReservasScreenState extends State<MisReservasScreen> {
       separatorBuilder: (_, _) => const Divider(),
       itemBuilder: (context, index) {
         final reserva = _reservas[index];
         final id = reserva.idReserva;
         final abierta = _reservaAbierta == id;
         return Column(
           crossAxisAlignment: CrossAxisAlignment.stretch,
           children: [
+            if (abierta &&
+                reserva.estado == EstadoReserva.consolidada &&
+                widget.cargarMensajeDemora != null)
+              MensajeDemora(
+                key: ValueKey('demora-${reserva.idReserva}-${reserva.idViaje}'),
+                viaje: reserva.idViaje,
+                cargar: widget.cargarMensajeDemora!,
+              ),
             _FilaReserva(
               reserva: reserva,
               abierta: abierta,
               onTap: () =>
                   setState(() => _reservaAbierta = abierta ? null : id),
             ),
             if (_motivos[id] != null)
               Padding(
```

Resultados locales de esta revisión: **782 pruebas backend aprobadas**, 859 warnings, 682,48 s; Ruff check/formato correctos (124 archivos). Copia de código en contenedor exclusivo, PostgreSQL 16 desechable con datos en memoria, sin volúmenes originales ni configuración remota; contenedores retirados al terminar. Incluye comparación SQL/ORM/migración e históricos; no certifica supervivencia a corte de energía. Flutter: **884 aprobadas**, 8:42, `--no-pub --concurrency=1`; analyze final sin observaciones (19,4 s), formato/espacios correctos. Primer intento completo detenido sin progreso tras 21 pruebas, sin acreditarlo como aprobado; reejecución completa posterior sí aprobada. Tandas focalizadas previas: 33 aprobadas y 26 de MisReservas, sin sumar recuentos ni sustituir la suite final. HEAD/CI final se registra en #281 después de observarla. Los resultados de `0e179bd` y cortes anteriores conservados debajo no se atribuyen a los cambios posteriores. El procedimiento de despliegue sigue preparado y no ejecutado; CU-037 conserva proveedor, plataformas, accesos e integración pendientes, sin simular envíos ni atribuir responsables. No hubo operaciones remotas sobre bases.

### Revisión posterior: salida incierta y preparación de despliegue (15/11/2026)

**Actualización posterior autorizada:** después de publicar la corrección `a9546e4` y documentación `becab4555684f160758171e8cbbd383be473c7d4` (CI 43772146331 iniciada para ese corte), el usuario autorizó incorporar main en la rama de trabajo conservando ambos cambios de pasajero. Se integró `7107233b7097870ca5731cf9137209faf326608d` mediante merge **solo hacia la rama de PR #281**, commit `046173bce3bd7dc9dc34228f7ca16ee9344ee138`, sin conflictos ni reescritura de los commits publicados. Quedan presentes mensaje de demora y cambio de parada CU-005/#275. Los párrafos siguientes que dicen «sin incorporar main» describen el corte previo a esa autorización. La PR no se fusionó en main; no hubo despliegue. El nuevo HEAD y su CI se registran en #281; la CI del corte becab45 no se atribuye al HEAD posterior.

Corrección solicitada por Martín sobre PR #281, a partir de `bb1ceb53f89960420c6bda975354b6cbd261c3e0`. Main observado en modo lectura: `7107233b7097870ca5731cf9137209faf326608d`; sus cambios posteriores a la base son de pasajero/contextos y no se incorporan a esta corrección. Los resultados y HEAD anteriores de este documento son históricos.

- Tras timeout, consultas fallidas o repetición fallida, se permite **Volver al viaje sin confirmar** y volver a sus acciones. La pantalla explica que salir no cancela ni rechaza el aviso y que el resultado sigue incierto. Durante una solicitud en vuelo se mantiene el bloqueo de salida del formulario.
- El shell conserva únicamente viaje/clave de los resultados inciertos en memoria de la misma sesión. «Resultado propio» permite seleccionar esa referencia y consultar explícitamente con la misma clave. Seleccionar/abrir/salir no consulta ni reenvía automáticamente. No se conserva descripción interna en ese listado ni se genera una cola offline. Cerrar/cambiar sesión o cerrar el proceso elimina estas referencias locales; la recuperación histórica autenticada por clave sigue disponible según el contrato.
- Recuperación desplazable con teclado abierto. Pruebas cubren viewport de teléfono 360 × 640 e inset de teclado, no certifican teclado físico ni APK nueva. Éxitos y errores tardíos de la recuperación de la cuenta anterior se descartan al desmontar el navegador de su sesión.
- Compatibilidad con main: la PR ya tenía una colisión aditiva en el constructor de `MisReservasScreen` con CU-005/#275. Se reubica únicamente el parámetro nombrado `cargarMensajeDemora`, sin cambiar comportamiento ni incorporar main. Simulación textual de tres vías sobre archivos temporales confirma que quedan ambos parámetros (`cargarMensajeDemora` y `onCambiarParada`) sin conflicto. No se hizo merge de ramas ni se reescribió historia publicada.

Verificación local de la corrección: suite Flutter completa **858 aprobadas** (4:05, `--no-pub --concurrency=2`), analyze sin observaciones (15,9 s), formato y espacios correctos. La primera tanda focalizada dio 9 aprobadas/1 fallida: el ensayo anterior pulsaba Consultar sin desplazar la pantalla al agregar la advertencia; se corrigió el recorrido con `ensureVisible`. La suite completa posterior sí pasó. La comprobación focal final tras reubicar el parámetro dio **31 aprobadas** (14 s), incluido MisReservas; analyze final sin observaciones (12,1 s) y formato sin cambios. Backend/contrato/modelo/dependencias no modificados en esta corrección; backend será revalidado por CI, sin afirmar una suite local nueva. HEAD y CI exacta se publican en #281 después de observarlos.

| Aceptación de la corrección | Evidencia automatizada propuesta/ejecutada según registro de resultados |
|---|---|
| Timeout + dos consultas fallidas + repetición fallida permiten salir | Integración bootstrap con transporte controlado; vuelve a detalle y muestra Finalizar viaje |
| Viaje/clave recuperables después de salir, sin envío espontáneo | Referencia precargada; cero GET al seleccionarla; GET explícito con clave original; POST no aumenta |
| Cambio de cuenta mientras GET sigue en vuelo | Éxito y error tardíos no publican datos/mensajes; nueva cuenta sin referencias ni campos anteriores |
| Teclado abierto no bloquea consulta ni desborda | Widget 360 × 640, teclado 300 px, desplazamiento hasta botón y resultado |

### Procedimiento de despliegue preparado — NO ejecutado

Este procedimiento no autoriza merge, migración remota, reinicio ni workflow Web. Ejecutarlo exige una autorización posterior y una ventana/dataset acordados. No usar `seed --reiniciar`, recrear tablas ni `alembic stamp` para esconder divergencias. No copiar credenciales en comandos, evidencias ni este documento.

1. **Congelar artefactos y respaldo.** Registrar SHA completo aprobado de la PR y futuro merge, CI de ese SHA y cambios efectivos de backend/Web. Confirmar entorno/base objetivo con quien tenga acceso, tráfico/escrituras durante la ventana y respaldo consistente antes de migrar (snapshot/backup autorizado). Ensayar restauración y migración sobre una copia aislada del respaldo, con datos protegidos. Anotar versión PostgreSQL, revisión Alembic y conteos previos; conservar extracto ordenado o huella verificable de las columnas preexistentes de `evento_operativo`, más referencias a viajes/cuentas, sin publicarlos. Un conteo solo no prueba integridad. Nunca cargar aquí la cadena de Neon ni ejecutar contra remoto durante esta revisión.
2. **Precondición de esquema.** Desde el backend del SHA aprobado, en el entorno autorizado: `alembic current`, `alembic heads` y `alembic history`. Head normal esperado de esta rama: `0002`, con padre `0001`; `mp_0002` de sandbox CU-036 no se aplica. Si la base no está en `0001` (o ya en `0002` verificado), o hay columnas/constraints parciales/divergentes, detener y revisar. No forzar estampado ni alterar históricos.
3. **Ensayo de aplicación preservando datos.** En la copia aislada primero, `alembic upgrade 0002` agrega dos columnas nullable (`id_cuenta_autora`, `clave_solicitud`), FK, UNIQUE y CHECK; no crea tabla, no borra filas ni atribuye autores a eventos existentes. Luego repetir conteos y comparar los valores previos; para filas históricas ambas columnas nuevas deben ser NULL. Verificar en `information_schema.columns` tipos/nullability, y en `pg_constraint` las definiciones de `evento_operativo_id_cuenta_autora_fkey`, `uq_aviso_solicitud` y `ck_aviso_metadatos`. `alembic current` debe informar `0002`; `alembic check` con ese código no debe proponer diferencias. Verificar en copia que segunda aplicación no modifica datos y que autor/viaje/clave duplicados o metadatos incompletos se rechazan usando exclusivamente datos sintéticos acordados.
4. **Aplicación futura controlada.** `backend/arrancar.sh` ejecuta `alembic upgrade head` antes de iniciar uvicorn; por eso desplegar/reiniciar el backend también puede migrar. Revisar el head efectivo antes de autorizar ese arranque. Tras el ensayo y respaldo verificados, elegir una sola ejecución controlada (paso de migración o arranque previsto), observar logs saneados y repetir verificaciones del punto 3 sobre el entorno autorizado. Un fallo impide habilitar el ensayo; no reiniciar repetidamente como solución. No se ejecutó nada de esto en remoto.
5. **Recuperación ante fallo.** Mantener respaldo y código anterior identificados; la migración aditiva conserva columnas originales. No ejecutar downgrade por rutina: el downgrade de `0002` se rehúsa si hay avisos con clave, porque eliminaría autoría/correlación. Ante fallo, detener nuevas escrituras de avisos y acordar recuperación con evidencia; restaurar un respaldo puede perder escrituras posteriores y requiere decisión explícita. Probar ese procedimiento en copia, no improvisarlo en producción.
6. **SHA realmente servido, separados.** Backend: obtener SHA completo del deploy Live en Events de Render y enlazar deploy/log saneado; `/api/health` comprueba salud pero no identifica commit (la versión de aplicación no basta). Web: registrar run del workflow `Web`, su `head_sha`, entradas y API_BASE_URL efectiva; el commit generado en `sitio-web` es un SHA distinto del código fuente y se relaciona con el run/mensaje de compilación. Registrar además deploy Live del sitio estático de Render y deployment de Pages si se usan ambos. Confirmar caché/recarga en cliente y anotar URL y hora. Ni main, ni CI verde, ni último commit de `sitio-web` prueban por sí solos qué está sirviendo Render. **SHA efectivos actuales de backend/Web: no verificados en esta revisión; pendientes de acceso/observación, sin reciclar los SHA históricos de PC2.**
7. **Ensayo funcional con datos acordados.** Antes de escribir: acordar IDs de viaje exclusivamente de prueba, fecha, chofer asignado, vehículo y estado en curso; pasajero consolidado (incluido un caso ya abordado), cuenta ajena y admin/dueño, sin tocar viajes/reservas originales. Registrar SHA API y fuente Web/APK, dataset y hora sin credenciales. Comprobar reporte manual, ID confirmado, misma clave sin duplicado, contenido distinto con conflicto, privacidad interna/pública y recuperación por autor después de finalizar/reasignar el viaje de prueba. Para timeout/pérdida de respuesta usar transporte controlado en local, sin cortar producción ni repetir POST con clave nueva. Verificar salida al detalle y recuperación posterior; cerrar/cambiar sesión mientras consulta controlada sigue pendiente. En teléfono abrir teclado, desplazar y consultar; registrar plataforma/versión y evidencia saneada. No ensayar envíos CU-037 ni ETA. Registrar qué casos se ejecutaron y cuáles quedan pendientes; no declarar CU-030 completo.

### CU-037: faltantes concretos, sin asignación de responsables

La distribución de coordinación nombrada en la propuesta push anterior era una propuesta, **no una asignación confirmada**. No atribuye compromisos a Martiniano, Facundo ni Martín. Queda pendiente confirmar quién coordina cada parte.

- **Proveedor/canales:** elegir mecanismo operativo push y su relación con WhatsApp, credenciales de prueba, ambiente, correlación, política de reintentos/fallback y evidencia que ofrece de aceptación/entrega. No se eligió proveedor ni se simulan envíos.
- **Plataformas:** confirmar Android/iOS/Web incluidos en la primera prueba. Android necesita aplicación/paquete y configuración de mensajería, permiso según SO, canales y dispositivo; iOS necesita identidad/bundle, capacidades, firma/APNs y dispositivo/acceso de prueba; Web necesita origen seguro, permisos, service worker y suscripción compatibles con el proveedor. Directorios de proyecto no acreditan que push esté configurado. No confundir pantalla bloqueada/app en background con cierre forzado ni prometer recepción.
- **Accesos:** proyecto/tenant del proveedor autorizado, consolas y credenciales mediante canal seguro, capacidad de configurar aplicaciones/firma/orígenes y dispositivos con consentimiento. Confirmar las personas habilitadas sin publicar secretos. No se solicitaron ni usaron estos accesos.
- **Integración aún no aprobada:** contrato/modelo para asociar/renovar/revocar tokens o suscripciones por cuenta/dispositivo, cambio y cierre de sesión, selección/revalidación de destinatarios y separación registro/intento/aceptación/entrega. La referencia en memoria de esta corrección solo recupera el registro; no sirve como cola de notificaciones. La definición funcional de consolidados incluidos abordados conserva procedencia de Martín y validación VanFull pendiente. CU-030 continúa parcial respecto de comunicación.

Preparación en rama `feat/chofer-avisos-manual-cu030`, worktree aislado. CI y publicación se registrarán con HEAD real después de verificarlas; nunca se atribuyen por anticipado. Revisión solicitada a Martiniano/Facundo no significa revisión ni aprobación recibida. Sin merge, despliegue ni escrituras sobre Neon/Render.


Nota de entorno de pruebas: PostgreSQL 16 se cre? en contenedor exclusivo `vf-cu030-280-db`, sin vol?menes originales. Para reducir latencia de disco de ese contenedor desechable se desactivaron fsync y synchronous_commit; esto no altera la atomicidad l?gica comprobada, pero las pruebas no certifican supervivencia a p?rdida de energ?a. Ninguna configuraci?n/base original se modific?. Un primer intento completo sobre bind mount se interrumpi? por latencia de disco sin acreditarlo como suite pasada; la corrida final usa una copia del backend dentro de contenedor exclusivo. La construcci?n de una imagen nueva fall?; se us? imagen local existente con dependencias del proyecto, sin cambiar requirements. Captura/build/dispositivo y push real no ejecutados.


## Resultados locales observados antes de publicar

- PostgreSQL/HTTP focalizado inicial: 27 aprobadas; despu?s se agregaron pruebas de carreras e hist?ricos.
- Suite backend completa sobre copia en contenedor: **781 aprobadas y 1 fallida**, 859 warnings, 483,93 s. La falla era la expectativa hist?rica del head 0001 en test_migracion_mercadopago; se corrigi? a 0002 sin modificar CU-036. Archivo completo de esa migraci?n: **10 aprobadas**, 1 warning, 116,20 s; Ruff check/format correctos (124 archivos). No se afirma que la primera suite haya pasado ?ntegra.
- ?ltimas pruebas backend propias test_avisos y test_avisos_migracion, incluida reserva ya abordada: **15 aprobadas**, 28 warnings, 68,71 s. Prueban permisos, concurrencia, integridad SQL, rollback, fin/reasignaci?n, privacidad e hist?ricos. Los recuentos de tandas no se suman.
- Flutter analyze: sin observaciones. Regresi?n completa con concurrency=2: **852 aprobadas**, 4:25; las 14 pruebas propias de formulario/adaptador/mensaje tambi?n pasaron por separado. Ensayo integrado bootstrap/HTTP simulado con respuesta perdida: **1 aprobado**, 5 s, separado de la regresi?n que inici? antes de agregar ese archivo. Una corrida anterior completa pas? 842 y otra sin progreso se interrumpi?; no son resultados del conjunto final.
- YAML/JSON y rutas/ORM/esquema/migraci?n se verificaron con las pruebas del contrato y test_migracion/test_modelos; JSON regenerado desde YAML, sin cambios de operaciones anteriores. Diff y espacios revisados. Sin builds nuevos, dispositivo, prueba push o servicios externos.
- UI mantiene clave en memoria durante la sesi?n y la muestra para copiar; recuperaci?n hist?rica por clave disponible sin depender del listado/asignaci?n actual. No hay cola offline ni recuperaci?n autom?tica tras cerrar forzadamente el proceso. Ninguna prueba certifica ese comportamiento.

La CI del HEAD publicado se informar? despu?s de observarla; esta evidencia local no sustituye la CI ni se atribuye anticipadamente a ella.


## Publicaci?n observada y ajuste de aislamiento

PR [#281](https://github.com/Martiherenu1/ProyectoVanFull/pull/281) abierta con primer HEAD fe14da1f9b868fff23c0f891c84a67f969db9f44. Revisi?n solicitada efectivamente a Martiherenu1 y facubarrientos y aviso contractual en #280; sin revisi?n recibida atribuida. CI inicial [43767428954](https://github.com/Martiherenu1/ProyectoVanFull/actions/runs/43767428954) completada con success para ese HEAD; evidencia distinta de la CI del ajuste posterior.

Revisi?n propia final corrigi? recuperaci?n hist?rica dentro del navegador de la sesi?n para retirar la pantalla al cambiar de cuenta; la comparaci?n de UUID acepta su forma can?nica al pegar may?sculas. Pruebas integradas y de ChoferShell: 8 aprobadas (18 s), analyze sin observaciones (12,2 s). El adaptador se vuelve a comprobar tras normalizar UUID. La CI del HEAD final y su SHA se registran en PR/Issue despu?s de observarlos, sin atribuir por anticipado el success inicial.

Contenedores de pruebas propios retirados despu?s de terminar las tandas; las bases originales, Neon/Render y APK no se tocaron. Logs locales auxiliares sin seguimiento preservados para diagn?stico. Sin merge, despliegue, credenciales externas o env?o real.


Revisi?n de accesibilidad del brief: los controles nuevos del chofer usan m?nimos t?ctiles de 64 px, incluida entrada de reporte, recuperaci?n, selector y acciones de incertidumbre. Pruebas de reporte/integraci?n/shell posteriores: 12 aprobadas (38 s), con aserci?n de tama?o t?ctil; analyze sin observaciones (13,1 s). Se registra como ajuste posterior a cfbe04d, cuya CI no se atribuye al nuevo HEAD.
