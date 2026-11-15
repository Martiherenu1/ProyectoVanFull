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

**Faltantes para prueba real, responsables de coordinación:** equipo/CU-037 debe elegir proveedor/canales y política; Martiniano coordina identidad, asociación de dispositivos y permisos backend; Facundo configuración/plataformas Flutter y despliegue de cliente; Martín validación funcional con VanFull y escenarios de viaje. Faltan proyecto/identificadores y acceso al servicio elegido, configuración de entrega por plataforma y dispositivos con consentimiento. No se han solicitado ni usado credenciales en el repo. Envío real requerirá autorización nueva: el pedido vigente lo prohíbe.

## Estado de publicación y pruebas

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
