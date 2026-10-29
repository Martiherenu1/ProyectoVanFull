# Contexto vivo · Administración y Flutter (Facundo)

## Estado

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

### CU-036

`app/integrations/mercadopago.py` y `app/services/mercadopago.py` están integrados por #216.
HMAC, consulta Payments, validación y confirmación contable reutilizada; no crea/captura cobros.
`app/main.py`/routers NO registran POST /webhooks/mercadopago: el contrato de diseño no lo activa.
Pruebas usan HTTP/proveedor y vínculo falsos, PostgreSQL temporal real. Idempotencia por pago local
con vínculo fijo; NO acredita asociación única global MP↔pagos ni ensayo sandbox real.

## En curso

#225, rama `docs/admin-cierre-pc2-225`: documentación y seguimiento, sin código funcional.
Antes de commit/push/PR se requiere autorización del usuario. Los Issues parciales permanecen abiertos;
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
- #215: vínculo persistente MP↔pago, contrato HTTP/ACK/reintentos, sandbox/moneda/receptor/escenario,
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
