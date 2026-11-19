# Contexto vivo · Administración y Flutter (Facundo)

## CU-021 / #279 — retomada después del merge de #277 (19/11/2026)

- Referencias verificadas: main `55ee8b5f7e0127ab8d76bcd84d657367ab8556ae`, #277 mergeada (HEAD dc67e54), #279 abierta en `2cfe1ed5e0f5f9a1b508e94f553095059db7af1c`. El corte anterior que pedía esperar a #277 queda superado por este estado.
- Se retoma el checkout aislado _pr279_pc3_merge: preparación contra d169da5 resguardada en árbol 690c91c68ab4db8ccb7e337fa4ed7828feb14873 y patch fuera del repo; merge anterior abortado tras verificar el respaldo. Incorporación normal de main 55ee8b5 con --no-commit --no-ff, manteniendo HEAD 2cfe1ed, sin nuevos commits. Objeto existente 55ee8b5 recuperado por conector, SHA firmado verificado y conectividad de objetos comprobada. Origin del checkout, antes local, corregido a GitHub; upstream de la rama existente configurado, sin push.
- Se resolvieron seis archivos en conflicto: main.dart, YAML/JSON/README OpenAPI y ambos contextos. Contextos previos preservados como antecedentes. La composición se deriva de main íntegro y agrega Choferes: conserva Vehículos, Administradores, Tarifas, Recorridos, Historial y Abonos; no concatena fragmentos de métodos ni sustituye la entrada del dueño. main.dart solo suma 45 líneas frente a main, sin eliminaciones; RoleRouter/AppRole/SesionApp y demás core permanecen idénticos a main. No se amplían permisos.
- Contrato verificado como unión exacta: 87 operaciones de main más cuatro CU-021, sin alterar operaciones/schemas/tags existentes. 67 rutas, 91 operaciones, 89 schemas; YAML y JSON válidos/equivalentes, JSON regenerado. README 31 CU representados/6 pendientes. Archivos propios productivos CU-021 y todo Vehículos (incluidas sus pruebas) intactos respecto de sus HEAD de origen.
- Pruebas actuales: Flutter completo 1111 aprobadas (03:17); analyze sin incidencias. Tanda focalizada 45 aprobadas: CRUD de ambos módulos y roles, 200/401/403/500, recuperación, navegación y preservación de módulos, y seis respuestas tardías 200/401/403 cruzadas entre Choferes/Vehículos en sesiones diferentes. Se agregan ocho pruebas conjuntas y se conservan/adaptan las nueve de dueño CU-021 al menú vigente.
- Backend seleccionado sin BD: 66 aprobadas en 10.25 s (contrato/rutas/modelos, seguridad/health y 40 permisos HTTP con JWT y servicios simulados). Ruff completo y formato 171 archivos aprobados. Los mocks no acreditan transacciones/constraints PostgreSQL.
- PostgreSQL 16 local no ejecutado: docker info confirma motor/pipe docker_engine inexistente. Sin reparación de Docker ni acceso a Neon/Render. Las CI previas de #279 y #277 solo validan sus árboles históricos; pendiente CI del futuro HEAD publicado. Prueba manual navegador/Android no realizada. Logs no bloqueantes de fuentes y warnings de dependencias/clave JWT de prueba no se tratan como fallos de tests.
- Modelos, SQL, seed, migraciones, dependencias y despliegue idénticos a main; cadena 0001→0002 intacta y 0002 SHA256 dcd5220130be7dc7b7565f95eff4fd8a932d3e936d969fb36f799be9fc7b3e2d. Sin conflictos/whitespace en el índice final.
- Estado LISTA PARA REVISAR Y AUTORIZAR PUBLICACIÓN, no lista para merge a main hasta CI del nuevo HEAD. Responsable Facundo. Siguiente acción: revisión del diff, autorización de commit/push normal y CI PostgreSQL 16, migraciones/OpenAPI y Flutter. No se creó ningún commit ni se realizó push, force, merge a main, despliegue o cambio Neon/Render. CU-021 sigue parcial por documentación habilitante, cuentas/roles, bajas/estados y alertas pendientes; no se agregan reglas.

## Cierre local CU-022 / #276 / #277 sobre main d169da5 — pendiente de revisión

- Estado actual: HEAD #277 `8839deb40e2b683c58c4ca24acaa851e710abee5`, MERGE_HEAD y origin/main `d169da5cfc448fdc6ea8a575fe2889d501062ad6`. Merge normal sin commit. Git HTTPS sigue sin conectar; se recuperaron los 19 commits existentes de main, árboles y blobs por conector y se verificaron sus SHA exactos, sin crear commits nuevos.
- Contexto vigente leído: CLAUDE.md (incluida regla de no apilar PR), CONTRIBUTING.md, Issue #276 y corte de main con CU-032/031/019/026/028. Se preservan todos esos módulos, su contrato y pruebas. #279 permanece abierta/separada en 2cfe1ed; su integración posterior debe conservar esta composición vigente y agregar Choferes, sin reemplazar funcionalidades del dueño.
- Un archivo con conflicto explícito: frontend/lib/main.dart (tres bloques). Resolución aditiva desde main: sus cinco módulos y métodos completos permanecen; Vehículos se inyecta en _entradaAdministracion tanto para administrador como para dueño. Frente a main, main.dart solo agrega 45 líneas, sin eliminaciones. Se elimina el contenedor exclusivo _EntradaVehiculosDueno y el bypass antiguo que el merge automático conservaba en RoleRouter. RoleRouter, AppRole y SesionApp quedan idénticos a main; se mantiene AppRole.owner y las restricciones de módulos solo dueño. No se amplían permisos.
- Backend main y YAML/JSON se combinaron automáticamente y se contrastaron semánticamente: 83 operaciones de main más cuatro CU-022, todos los schemas y tags preservados. 65 rutas, 87 operaciones, 86 schemas; JSON regenerado. README recalculado: 30 CU representados / 7 pendientes. Los archivos propios productivos CU-022 siguen intactos respecto de 8839deb.
- Validación actual: Flutter completo 1079 aprobadas (03:17); analyze sin incidencias. Tanda focalizada 21 aprobadas: CRUD y 200/401/403/500, recuperación, módulos recientes del dueño/admin, respuestas tardías de Vehículos sin afectar historial de otra sesión y roles múltiples. Se adaptan las nueve pruebas de dueño a la navegación actual y se agregan cinco regresiones entre módulos.
- Backend sin BD: 29 aprobadas (contrato/rutas/modelos + 20 HTTP de permisos con JWT y servicios simulados) y 17 aprobadas de seguridad/health: total 46. Ruff completo y formato 166 archivos aprobados. Estas pruebas no acreditan persistencia/transacciones. Se mantienen logs no bloqueantes de fuentes/warnings de pruebas, sin cambiar dependencias.
- PostgreSQL 16 local NO EJECUTADO: docker info no conecta y no existen los pipes docker_engine ni dockerDesktopLinuxEngine; solo hay binarios nativos 18, que no se usaron como sustituto. No se intentó reparar Docker ni se conectó a Neon/Render. Se recopilaron 170 casos PostgreSQL/migraciones/regr. recientes sin ejecutar fixtures, incluidos los 21 de Vehículos. La CI previa de 8839deb (955/993) NO valida este árbol. Pendiente PostgreSQL 16/CI tras revisar y autorizar publicación.
- Modelos, SQL, seed, migraciones (0001→0002), core backend/Flutter, otras pantallas de roles, dependencias, instrucciones y despliegue idénticos a main. 0002 SHA256 dcd5220130be7dc7b7565f95eff4fd8a932d3e936d969fb36f799be9fc7b3e2d. Sin conflictos de índice ni whitespace.
- Estado PREPARADO LOCAL / NO PUBLICADO. Responsable Facundo. Siguiente acción: revisión del diff por el usuario; después autorización de publicación normal sin force y CI completa PostgreSQL 16. Merge a main requiere autorización separada. CU-022 sigue parcial por documentación operativa no definida; disponibilidad sigue como booleano existente, sin nuevas reglas/asignaciones. No se modificaron GitHub, Neon/Render ni se desplegó.

## Continuación CU-022 — diagnóstico PostgreSQL y acceso de dueño (17/11/2026)

- Base preservada: HEAD #277 `491e914`, MERGE_HEAD `d00c1ee`; #279 sigue en `fc761ef`, abierta. Sin commit/push/merge hacia main.
- Diagnóstico de los 5 failed + 31 errors anteriores: los 36 resúmenes tienen ConnectionDoesNotExistError. Los 31 errors ocurren en fixtures y los 5 failed en context managers dentro del cuerpo, durante asyncpg.connect antes de CREATE DATABASE. Reproducción sin importar app/servicios, exclusivamente contra 127.0.0.1:5432, con ssl=False/prefer y loops Proactor/Selector: misma desconexión en los cuatro intentos. Confirma un problema de conexión del entorno, no un fallo de aserciones CRUD; la causa subyacente del cierre no quedó resuelta y no prueba ausencia de defectos backend.
- PostgreSQL 16 aislado: NO EJECUTADO. Docker no expone dockerDesktopLinuxEngine ni motor predeterminado; lanzar Docker Desktop oculto no habilitó el motor y se cerró el proceso iniciado para la prueba, sin crear contenedores. Solo hay binarios nativos PostgreSQL 18; no se sustituyó la versión requerida ni se usó Neon. Script de repetición PG16 preparado fuera del repo, sintaxis PowerShell comprobada, sin ejecutar contra datos reales.
- Causa Flutter: AppRole no reconoce dueno y RoleRouter solo resolvía las tres entradas habituales. Corrección mínima acotada a CU-022: entradaDueno opcional en RoleRouter/SesionApp y contenedor explícito de vehículos en main.dart. No alias global a administrador, no menú de otras áreas, no cambio en AppRole, backend o permisos API. Conserva generación/token, _protegerAcceso, 401/403 y logout. Dueno sin entrada configurada y sesiones con múltiples roles mantienen su bloqueo anterior.
- Reproducción roja de dueño HTTP 200 antes del fix: falla porque no muestra vehículos. Después: 9 pruebas nuevas (consulta 200/401/403/500, CRUD por contrato/token existente, respuestas tardías 200/401/403 de dueño a administrador y múltiples roles) aprobadas; tanda focalizada 26 aprobadas. Suite completa actual: 993 aprobadas; flutter analyze sin incidencias (18.8 s). 9 backend sin BD aprobadas (9.52 s), Ruff/formato 5 archivos aprobados. Fonts generaron logs durante tests sin fallarlos.
- Contrato sigue 51 rutas/63 operaciones/57 schemas, ambas ramas preservadas; 0002 y modelos/schema.sql sin cambios frente a main. Compatibilidad #279 recalculada: rutas/schemas sin colisión, mismos conflictos aditivos en composición backend/Flutter. La entrada explícita de dueño a vehículos debe preservarse al integrar choferes; el acceso UI de dueño a CU-021 requiere tratamiento en #279, no se habilita aquí.
- Estado: corrección local disponible para revisión; bloquea integración la repetición real en PostgreSQL 16/CI. Responsable Facundo; reanudar con motor local disponible y aprobación del diff antes de commit/push. Documentación operativa CU-022 sigue parcial. Sin Neon/Render ni cambios de alcance.

## Antecedente — preparación anterior (antes de corregir dueño)

## CU-022 / #276 / PR #277 — integración PC3 preparada para revisión (17/11/2026)

- Referencias contrastadas: #277 `491e914dc717f8e0f80abe0b105db603067d79fa`; main `d00c1ee8bccfe2082caaacfa78bd234824cc938d`; #279 `fc761ef54e56e5f1a7a2c503ce565284338aa7ac` (ambas PR abiertas).
- Merge normal local preparado con `--no-commit --no-ff` contra main actual. El intento anterior contra `8fafa02` se resguardó antes de reemplazarlo. Ante fallo de git fetch se importaron los objetos remotos existentes de #309 por conector, comprobando sus SHA exactos; no se creó ningún commit nuevo. MERGE_HEAD es `d00c1ee`; contexto general nuevo conservado.
- Tres conflictos resueltos: YAML/JSON/README de OpenAPI. Conservados tags de vehículos y corporativo y todas las operaciones/schemas de main y aportaciones CU-022. JSON regenerado; 51 rutas, 63 operaciones, 57 schemas; 12 CU pendientes de contrato. Sin conflictos ni whitespace pendiente.
- Modelos, schema.sql, migraciones, cliente HTTP, tema, dependencias, pantallas de otros roles y configuración/arranque idénticos a main. Cadena normal 0001→0002; 0002 SHA-256 dcd5220130be7dc7b7565f95eff4fd8a932d3e936d969fb36f799be9fc7b3e2d. Los archivos propios productivos CU-022 siguen intactos respecto de #277.
- Pruebas locales actuales: 9 aprobadas de contrato/rutas/modelos; Ruff y formato aprobados en cinco archivos backend. Flutter 3.47.7: suite existente completa 977 aprobadas; 7 nuevas regresiones de composición/sesión en admin_vehiculos_session_test.dart aprobadas (200/401/403/500 y respuestas 200/401/403 tardías); analyze sin observaciones. Caché temporal escribible de herramientas, sin cambios al SDK ni dependencias del proyecto. Logs google_fonts durante la suite no causaron fallos.
- PostgreSQL: Docker sin motor. Intento de instancia nueva local con binarios 18 falló al inicializar por restricciones del entorno. Tanda contra servidor exclusivamente local 127.0.0.1:5432, CI=true para impedir skips: 4 passed, 5 failed, 31 errors por cierre de conexión (WinError 64 / ConnectionDoesNotExistError al conectar en helpers). No valida CRUD, constraints ni migración del árbol integrado; repetir en PostgreSQL 16 aislado/CI. No se accedió a Neon/Render ni se aplicó migración remota.
- Permisos: API exige administrador/dueno en las cuatro operaciones; Flutter conserva guardas de generación/token y 403. Limitación previa: AppRole solo reconoce pasajero/chofer/administrador, y la prueba existente de widget confirma dueno bloqueado. No declarar cumplido el acceso UI de dueño de #276; requiere decisión/seguimiento del equipo, sin ampliar roles en este merge.
- #279: rutas /choferes y /choferes/{id_persona} y tres schemas nuevos compatibles sin colisión. Simulación sin aplicar: un conflicto de imports en backend/app/main.py y nueve bloques en frontend/lib/main.dart; además ambos PR editan OpenAPI. Actualizar #279 después conservando ambos routers, imports, constructores, adaptadores, botones y métodos completos; regenerar JSON y repetir pruebas. No incorporar #279 dentro de #277.
- Estado: PREPARADO LOCAL / NO PUBLICADO. Responsable: Facundo. Pendientes: revisión del diff por el usuario, repetición PostgreSQL/CI del merge, contraste remoto final y revisión contractual solicitada a Martiniano. CU-022 sigue PARCIAL por documentación operativa sin definir y límite UI dueño. Sin commit, push, merge hacia main, despliegue ni operaciones Neon/Render.

## Estado

**Trabajo local posterior #238/#240, seguimiento #215:** #240 ya mergeado solo con
la propuesta; #238 cerrado. Implementación sin publicar, preparada para PR nuevo.
Base actualizada a main remoto `440c578`, conservando CU-005 y contextos. Candidato de integración HTTP CU-036,
vínculo SQL 1:1, migración/DDL/contrato propuestos y tests reales contra PostgreSQL temporal
con Payments simulado. Ruta desactivada por defecto; live_mode=true NO aceptado.
D1–D6 siguen pendientes de aprobación escrita triple para main. Sin commit/push/merge
ni activación/despliegue. Migración optativa fuera del head habitual, con guardas;
DDL base sin cambios. [Ensayo, alcance y matriz](ENSAYO-CU036-AISLADO.md).
Validación posterior: 177 casos focalizados aprobados, Ruff/formato y OpenAPI correctos;
incluye regresión CU-005 preservada. No implica validación del proveedor auténtico.
La cobertura integrada que sigue conserva su corte anterior; CU-036 continúa PARCIAL.

**Ampliación Checkout Pro local:** conserva la preparación anterior y propone intención
UUID/preferencia única, inicio/consulta propios y retorno informativo. Flutter candidato
Web/Mobile, sesión/doble envío y registro manual conservados; todas las rutas nuevas
inactivas por defecto. `mp_0002` optativa, esquema base/Render intactos. Pendientes de
aprobación compartida y coordinación con Martiniano; live_mode=true sigue rechazado.
[Circuito, archivos compartidos, ensayo y riesgos](CHECKOUT-PRO-CU014-CU036-CANDIDATO.md).
No certifica operación real ni modifica los estados integrados de la tabla siguiente.

Corte documental **2026-10-29**, main `bceb929` (Issue #225). PR #210/#214/#216/#217/#218
mergeados, contrastados con código y contratos; no equivalen a CU completos ni a despliegue real.
IMPLEMENTADO = circuito descrito existente; PARCIAL = obligaciones faltantes; PENDIENTE = parte ausente.
No se ejecutan suites generales ni operaciones reales en este cierre. Notion: SIN VERIFICAR, no modificado.

## Hecho — cobertura y trazabilidad

| CU / RF | Estado | Código y alcance integrado | RN / límites | Issue → PR |
|---|---|---|---|---|
| CU-018 / RF-017/018 | PARCIAL | Viajes: alta, listado por fecha y selector, update de programado, cancelación lógica limitada en backend y Flutter | ADJ-03; capacidad/asignaciones; RN-019 NO implementada | #180/#207 → #189/#208; #186 update y #177 fecha; #75 reintegros |
| CU-027 / RF-043 | PARCIAL | GET /api/reservas, listado/selección/detalle local con id_pasajero, solo lectura | Todos los estados, orden id_reserva; criterios adicionales pendientes; CU-010 intacto | #211/#223 → #224/#217 |
| CU-014 / RF-009 (RF-028 secundario) | PARCIAL | Registro PENDIENTE y evento; formulario transferencia/billetera para cliente con cuenta | RN-015/016; RN-011/013/014 incompletas; no emitir recibo al registrar | #84/#213 → #85/#141/#214 |
| CU-015 / RF-010 | PARCIAL | GET /api/clientes/{id_cliente}/deuda y Flutter por ID; cálculo común, CU-006 conservado | MR-R30; RN-004/005/006 pendientes; no editar saldo ni inferir suspensión | #212 → #218 |
| CU-016 / RF-011 | IMPLEMENTADO (circuito documentado) | Pendientes, confirmar/rechazar y actualizar listado, backend y Flutter | RN-015: solo confirmar genera RECIBO/ACREEDOR/evento atómicos; no se acredita contraste integral v1.3 | #209 → #210; #52 backend original |
| CU-036 / RF-012, RNF-003 | PARCIAL; circuito HTTP PENDIENTE | Adaptador HMAC/GET Payments y servicio interno con proveedor/vínculo simulados en tests | RN-015 reutilizada; sin webhook activo ni validación real | #215 → #216 |

### CU-018

`backend/app/services/viajes.py`, routers/viajes.py y pantallas/adaptadores administrativos:
POST /viajes, GET /viajes?fecha, PATCH /viajes/{id_viaje}, POST /viajes/{id_viaje}/cancelacion.
Cancelación solo programado, sin ESPECIAL/CORPORATIVO, reservas provisional/consolidada,
periodo_abono_viaje ni lista de espera en_espera. FOR UPDATE del viaje; estado cancelado y
registro de evento atómicos, sin DELETE. Errores ESTADO_VIAJE_INVALIDO/VIAJE_CON_COMPROMISOS.
Flutter pide confirmación; refresca listado tras éxito aunque se cierre detalle, y aísla sesión.
No modifica servicio/recorrido ni aplica reintegro RN-019; solapamientos detallados siguen sin definir.

### CU-027

`backend/app/services/reservas.py` (Martiniano), `ReservasAdminApi`, `ReservaAdmin` y
`ConsultarReservasAdminScreen`. GET /reservas para administrador/dueno, todas las reservas por
id_reserva ascendente, [] si vacío. Modelo administrativo conserva id_pasajero sin alterar Reserva
del pasajero. Detalle usa el resultado seleccionado; GET /reservas/{id} mantiene propiedad CU-010.
Sin filtros/paginación inventados, nombres/contactos ni escrituras. Carga/error/reintento y sesión protegida.

### CU-014

`backend/app/services/pagos.py`, `RegistroPagosAdminApi` y `RegistrarPagoAdminScreen`.
POST /pagos admite administrador/dueno y pasajero propio; valida cliente/cuenta y crea PENDIENTE
con pago_registrado, sin comprobante/movimiento. Flutter administrativo ofrece transferencia/billetera.
`BorradorImputacionPago` y su formulario NO están montados ni persisten: preparación aislada.
Tipo/evidencia se rechazan con 400 VALIDACION; sin cuenta responde 404, sin alta automática.
El schema backend admite otros medios, pero eso NO implementa descuento 15 %, señas ni Mercado Pago.
En #225 solo se añade x-cobertura: parcial a POST /pagos y se regenera JSON; contrato funcional intacto.

### CU-015

`services/deuda.py`, routers/deuda.py, `DeudaAdminApi`, `ConsultarDeudaAdminScreen`.
Consulta administrativa por ID con esquema Deuda: sin cuenta 0.00/al_dia; inexistente
404 CLIENTE_NO_ENCONTRADO; otros roles 403 SIN_PERMISO. Saldo derivado MR-R30, no editable.
El cálculo compartido no cambia identificación propia ni comportamiento CU-006.
RN-004/005/006 no implementadas: situación de deuda no equivale a suspensión/habilitación/límite.

### CU-016

GET /pagos/pendientes y POST /pagos/{id_pago}/confirmacion, administrador/dueno.
`PagosPendientesScreen`/`PagosAdminApi`: confirmación explícita, recarga, errores, doble envío y sesión.
Solo PENDIENTE; lock del pago y efectos atómicos. Rechazo sin recibo/movimiento; decidido no se reprocesa.
La fuente detallada CU-016 v1.3 no se localizó según #210; se usaron MVC aprobado y contrato.
Por eso se informa IMPLEMENTADO el circuito documentado, sin certificar toda la especificación v1.3.

### CU-036 — PARCIAL en PC2

**DEFINIDO POR EL EQUIPO — Martiniano, 2026-10-29:** confirma expresamente la entrega PARCIAL
de CU-036 en PC2 (decisión comunicada por el usuario). No aprueba cambios de modelo ni de
contrato HTTP antes del PC2; los pendientes de integración pasan a post-demo en #215.

`app/integrations/mercadopago.py` y `app/services/mercadopago.py` están integrados por #216.
HMAC, consulta Payments, validación y confirmación contable reutilizada; no crea/captura cobros.
`app/main.py`/routers NO registran POST /webhooks/mercadopago: el contrato de diseño no lo activa.
Pruebas usan HTTP/proveedor y vínculo falsos, PostgreSQL temporal real. Idempotencia por pago local
con vínculo fijo; NO acredita asociación única global MP↔pagos ni ensayo sandbox real.
Webhook HTTP inactivo; sin integración real certificada. El alcance entregado es HMAC,
consulta Payments y servicio contable interno con simulaciones, no la recepción HTTP completa.

## En curso

#229, rama `test/admin-flutter-integracion-pc2-229`, desde main 8e16205 (#228 integrado).
Solo `frontend/test/admin_circuitos_ui_integration_test.dart` y contextos: tres casos UI con
MockClient y helpers existentes. Registro→pendientes→confirmar/rechazar→deuda (2 variantes),
y edición de viaje→PATCH autenticado→GET/refresco de detalle/listado. No recalcula deuda en UI.
CU-015 tardío y CU-027 listado/selección/detalle ya cubiertos: no se duplican sus casos.
32 focalizadas aprobadas (3 nuevas + 29 existentes), analyze/diff check correctos.
Sin defectos funcionales detectados, código productivo ni acceso Neon/Render. Sin commit/push/PR.
#227/#228 ya integrados: 3 backend nuevos + 11 existentes CU-027 aprobados, sin cambios funcionales.
Los Issues parciales permanecen abiertos;
#209/#213 cerrados corresponden a entregas acotadas, no completan otros pendientes de los CU.

## Decisiones y contradicciones

- **DEFINIDO POR EL EQUIPO:** reparto 13/10 en REPARTO-PC2.md, ADJ-03, MR-R30 y pagos:
  registro no acredita; confirmar produce ACREEDOR/RECIBO; rechazo no los produce.
- CU-027: recorte acordado en #224; CU-015: contrato de consulta acordado con Martiniano en #218.
- CU-018: [revisión #189](https://github.com/Martiherenu1/ProyectoVanFull/pull/189#pullrequestreview-5689483311)
  consigna confirmación de Martín/Facundo del 28/10 y de VIAJE_CON_COMPROMISOS. Issue #180,
  docstring y x-estado-aprobacion/descripcion aún contienen el estado anterior pendiente. Prima
  esa revisión posterior como evidencia documental; el merge por sí solo no constituye aprobación.
  Se registra contradicción en #180/#225 sin cambiar servicios ni ese metadato contractual aquí.
- El selector de fecha está integrado (#177), no es una propuesta pendiente de implementación.
- REPARTO conserva decisiones de alcance; la tabla de contratos faltantes del 13/10 es histórica.
  Los recortes no se convierten en exclusión formal de obligaciones restantes por estar mergeados.

## Pendientes

- #180/#75: reintegro 100 % RN-019, CU-017 y almacenamiento/operación de créditos; servicio/recorrido
  y solapamientos de asignaciones pendientes. Cancelación limitada no satisface estas obligaciones.
- #84: tipo/evidencia y persistencia; efectivo RN-011/15 % sin cálculo/imputación; señas RN-013/014,
  contratación/acuerdos; semántica CUENTA_CORRIENTE y cliente sin cuenta. No inventar reglas económicas.
- #212: RN-004 advertencia/suspensión/cupo; RN-005 habilitación excepcional cinco días y expiración;
  RN-006 límite mensual/referencia de abono. Sin acciones operativas ni inferencias desde el saldo.
- #211: criterios de búsqueda adicionales de CU-027; identificación personal adicional solo si se acuerda.
- #215, post-demo por decisión de Martiniano: vínculo único operación↔pago, contrato webhook
  HTTP/ACK/reintentos, sandbox real/moneda/receptor/escenario,
  handler/DI, conciliación durable y validación real autorizada. Webhook inactivo.
- #225: contraste documental CU-016 v1.3, contradicción de aprobación CU-018 y coordinación de prueba real.
- Notion: PENDIENTE DE COMPROBAR/ACTUALIZAR por Facundo; no se consultó ni modificó, sin asumir acceso.

## Entorno, evidencia y despliegue

Este cierre verifica estáticamente código/contratos y metadatos de Issues/PR, sin suites generales.
Evidencia histórica, NO nueva ejecución: #189 20 PostgreSQL; #210 558 backend/680 Flutter;
#214 682 Flutter (publicación inicial); #216 599 backend con 82 focalizadas de preparación;
#218 25 backend/733 Flutter; #217 724 Flutter y resolución final 42 focalizadas/analyze.
Los resultados corresponden a esos HEAD, no certifican nuevamente el main del corte.
Prueba manual Render 27/10 conservada: login, listado, formulario sin envío, logout/recarga; éxito
visual de una creación sin confirmación de persistencia. Nuevos circuitos/despliegue actual SIN VERIFICAR.
No se accedió a Neon/producción ni se hicieron pagos, cobros, migraciones o pruebas reales en este cierre.

## Para otras áreas

Usar los endpoints de lectura integrados para deuda/reservas/pagos; respetar las consultas propias
CU-006/CU-010. Administración mantiene alta/update/cancelación limitada; ejecución y GPS pertenecen a Martín.
Roles múltiples/desconocidos/dueno siguen sin portada Flutter específica, según reparto; el backend
conserva administrador/dueno donde está contratado. No confundir permisos HTTP con interfaz implementada.

Preparación PR A CU-036: Issue #247, rama feat/admin-integracion-cu036-247 desde 440c578.
Corte exclusivo sin Checkout/Flutter/mp_0002; D1–D6 pendientes de aprobación escrita triple.
Detalle y límites: Documentos/Sesiones/PC2/PREPARACION-PR-A-CU036.md. Sin commit/publicación/activación.

30/10/2026: PR A #247 actualizado a fb6e422; suite backend completa 731/731, Ruff/formato y OpenAPI correctos.
Publicación autorizada solo en Draft; D1–D6 pendientes. B se prepara apilado sobre A, sin commit/push.
Sin merge, activación, migraciones remotas ni despliegue; desarrollo original preservado.

30/10/2026: A publicado en Draft #251, CI backend/Flutter verde. B preparado local en #252 sobre 10dd5bf.
B: 763 backend, 780 Flutter, analyze y build Web correctos; Android/iOS nativos pendientes por herramientas.
Sin commit/push de B. D1–D6 y Checkout siguen pendientes de aprobación escrita del equipo.

30/10/2026: publicación B autorizada únicamente en Draft con base en A #251 (10dd5bf), Issue #252.
Ruff/formato, contrato y revalidación de Checkout correctos; revisión técnica por solicitar al equipo.
D1–D6 y ampliación siguen pendientes de aprobación escrita de Martín, Martiniano y Facundo.
Sin merge, despliegue, migraciones remotas ni activación. Flags false y live_mode=true rechazado.

30/10/2026 — CU-027 / #255, rama fix/admin-atras-reservas-cu027-255, base cbcbf12.
Reproducido: Atrás del sistema desde detalle abandona consulta; flecha sí vuelve al listado.
Corrección local: LocalHistoryEntry reutiliza pop de la ruta y flecha automática AppBar;
PageStorageKey conserva desplazamiento del listado por alcance de sesión. Carga/cambio de
sesión/desmontaje eliminan historial local. No se agregan filtros ni rutas/API/modelos.
Pruebas: reproducción inicial falla solo para sistema; después 784 Flutter aprobadas,
analyze sin incidencias y diff check correcto. Incluye cuatro regresiones nuevas:
flecha/sistema, segunda pulsación sale, desplazamiento/reapertura y cambio de sesión.
Límite: handlePopRoute prueba el evento recibido por Flutter; NO certifica el botón físico
Atrás de Chrome ni su historial externo. Esa comprobación real sigue pendiente.
Usuario autoriza commit/push y PR Draft contra main, con revisión solicitada; no merge ni despliegue.
Checkout/CU-008 intactos. Intento visual detenido: la herramienta no pudo identificar con certeza
la URL de Chrome. No se acredita aprobación de esa prueba; registrar resultado antes del merge.

30/10/2026 — CU-018 / #262: mejora exclusivamente visual de Viajes del día y su detalle.
Título/fecha, márgenes, cabecera de tabla, ancho adaptable, números IBM Plex Mono,
estados con texto/colores existentes y acciones diferenciadas. Filas 36 px, bordes y radio 2 px,
sin sombras. Solo viajes_dia_admin_screen.dart cambia código productivo; tres tests adaptan
expectativas de etiquetas/valores separados. Carga, selección, callbacks, condiciones,
formulario de edición y confirmación de cancelación conservan su código original.
Verificación local: analyze/formato/diff correctos y 23 pruebas relevantes aprobadas.
Cuatro capturas reales del motor Flutter, con datos ficticios, revisadas a 1440 y 360 px:
evidencias/admin-visual-262/. No son una prueba manual de Chrome ni evidencia productiva.
Sin cambios de API/modelo/tema compartido/Pasajero/Chofer/CU-008/Mercado Pago.
Publicación y merge commit autorizados por Facundo solo con CI completa verde, sin conflictos
y antes del corte 17:15; sin despliegues manuales ni cambios en Render/Neon/sitio-web.

## Antecedente de preparación CU-021 del 17/11 (no describe el estado actual)


## CU-021 / #278 / #279 — integración local PC3 para revisión (17/11/2026)

- Referencias verificadas por GitHub: #279 `fc761ef54e56e5f1a7a2c503ce565284338aa7ac`, main `d00c1ee8bccfe2082caaacfa78bd234824cc938d`; #277 abierta en `8839deb40e2b683c58c4ca24acaa851e710abee5`. Sin revisiones ni comentarios en #279 al contrastar. El alcance del acceso de dueño deriva del criterio explícito del Issue #278; no amplía roles ni reglas de negocio.
- Merge normal local `--no-commit --no-ff origin/main`; HEAD permanece fc761ef y MERGE_HEAD d00c1ee. Dos conflictos explícitos resueltos conservando ambos lados: imports en backend/app/main.py y pendientes en backend/openapi/README.md. main.dart y YAML/JSON se combinaron automáticamente y se auditaron; JSON regenerado, README recalculado: 51 rutas, 63 operaciones, 57 schemas, 25 CU representados/12 pendientes. Se preservan las 59 operaciones de main y las cuatro de CU-021, sus schemas y tags.
- Corrección Flutter mínima: entradaDueno opcional idéntica a #277 en RoleRouter/SesionApp y contenedor explícito limitado a Choferes en main.dart. No alias global a administrador ni otros accesos de Administración. Conserva AppRole, generación/token, cliente HTTP, 401/logout, 403 y descarte de respuestas tardías; múltiples roles y dueño sin entrada configurada siguen bloqueados. Los archivos propios productivos de CU-021 permanecen intactos frente a fc761ef.
- Pruebas actuales: 993 Flutter aprobadas en 3:05; analyze sin incidencias en 44.8 s. Incluye 16 regresiones nuevas de composición/sesión (7 administrador, 9 dueño): 200/401/403/500 y recuperación, CRUD de dueño con token existente, respuestas tardías entre sesiones y roles múltiples. Backend sin BD: 29 aprobadas en 4.36 s (9 contrato/rutas/modelos + 20 permisos HTTP con servicios simulados, no prueba transaccional). Ruff completo aprobado y 146 archivos con formato aprobado. Logs no bloqueantes de google_fonts y warnings de dependencias/clave de prueba; sin cambiar fuentes ni dependencias.
- PostgreSQL 16 local NO EJECUTADO: comprobación de Docker confirma ausencia del motor/pipe docker_engine. No se intentó repararlo ni conectar a Neon/Render. Las 23 pruebas PostgreSQL propias de CU-021 y migración sobre BD limpia deben repetirse para este árbol en PostgreSQL 16/CI; las 23 históricas de la PR original y la CI de #277 no validan este merge. Sin commit/push, no hay CI de este árbol pendiente.
- Modelos, schema.sql, migraciones, controlador de sesión, HTTP compartido, tema, dependencias, pantallas pasajero/chofer y arranque/despliegue idénticos a main. Cadena 0001 → 0002 intacta; 0002 SHA256 dcd5220130be7dc7b7565f95eff4fd8a932d3e936d969fb36f799be9fc7b3e2d.
- Compatibilidad #277: rutas y schemas nuevos sin colisiones; los dos hooks compartidos de dueño son idénticos. Simulación git merge-tree con base d00c1ee, sin aplicar #277 ni crear commits: conflictos futuros en README/YAML/JSON OpenAPI y main.dart (12 bloques). Backend main se combina automáticamente. Deben conservarse ambos imports, APIs, campos, constructores, botones y métodos completos; la entrada única de dueño requiere composición explícita para Choferes y Vehículos. No elegir una entrada ni concatenar fragmentos de métodos. Integración conjunta y sus regresiones NO ejecutadas; esta simulación no acredita compatibilidad automática.
- Estado PREPARADO LOCAL / NO PUBLICADO, responsable Facundo. Siguiente acción: revisión del diff por el usuario; después autorización de commit/push y CI PostgreSQL 16, más contraste/revisión de OpenAPI y Flutter compartido. CU-021 sigue PARCIAL: documentación habilitante/obligatoriedad, cuentas/roles, baja/estados y alertas pendientes. Sin funcionalidades nuevas, commit, push, merge hacia main, despliegue ni cambios Neon/Render.
