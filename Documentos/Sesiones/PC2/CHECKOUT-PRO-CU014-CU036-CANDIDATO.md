# Checkout Pro + CU-036 — candidato local, seguimiento #215

## Estado y límites

**PROPUESTA DE IA / PENDIENTE DE VALIDACIÓN.** Implementación local autorizada por
el usuario en `feat/admin-preparar-mercadopago-cu036-238`, base `440c578`. No reemplaza
el CU-036 previo: conserva vínculo explícito por CLI, HMAC, validación Payments,
CU-016 y sus pruebas. Los 25 archivos previos tienen respaldo local no versionado.
Los 177 casos anteriores son evidencia del corte previo; los resultados de esta
ampliación se informan separadamente. #240 está mergeado; no se actualiza ese PR.
No hay commit/push, despliegue, cobro ni consulta externa a Payments en esta tarea.

CU-014/CU-036 siguen **PARCIALES**. No se presenta integración real certificada,
aprobación de D1–D6 ni equivalencia BILLETERA/MERCADO_PAGO.

## Circuito implementado y propuesta de asociación

1. Pasajero autenticado solicita iniciar checkout con importe, método exclusivamente
   MERCADO_PAGO y clave UUID por solicitud. El servidor obtiene cliente de su sesión
   y exige cuenta corriente existente; no acepta id_cliente ni otros campos.
2. Se guarda atómicamente Pago PENDIENTE + evento + intención `checkout_mercadopago`.
   UUID **opaco generado por servidor**, distinto de id_pago, se propone como
   external_reference. No se interpreta una referencia arbitraria como Pago.
   Identidad vinculada por FK compuesta Pago/cliente; preferencia y Pago únicos;
   UNIQUE(cliente, clave_solicitud). La nueva tabla NO se agrega al esquema base.
3. Con la transacción cerrada se hace un único POST Preferences. Respuesta segura:
   receptor/referencia/ítem/importe/moneda y sandbox_init_point HTTPS validado.
   No existe fallback init_point. El dominio sandbox no prueba por sí solo el
   entorno; la comprobación decisiva de Payments sigue exigiendo live_mode=false.
4. Reintento de la misma clave recupera la misma intención. Si el POST fue incierto,
   solo GET search por UUID + GET de la preferencia única. Nunca repite POST.
   CREANDO/LISTO/INCIERTO son estados técnicos de intención, no estados contables.
   Clave reutilizada con otro importe: 409. Ninguna/múltiples preferencias: incierto,
   sin enlace operativo. Abandono no borra Pago ni simula rechazo/acreditación.
5. Webhook HMAC válido relee Payments. Si no había vínculo explícito, comprueba
   UUID conocido y cadena Payment → merchant order → preferencia por GET oficial,
   pertenencia de operación a orden, receptor, moneda, importe y medio local.
   Bloquea Pago → intención; solo approved crea vínculo de operación y llama CU-016.
   Así admite webhook temprano antes de guardar la respuesta del POST Preferences.
6. RECIBO, ACREEDOR y evento siguen en la transacción de CU-016. Misma operación
   repetida: ACK sin asientos nuevos. Otra operación approved para el mismo Pago:
   409 para conciliación, sin segundo asiento ni devolución automática. Un recurso
   no aprobado no fija el vínculo, no cambia Pago y permite un intento aprobado posterior.
7. Flutter ofrece la opción solo con flag; usa sesión/HTTP/modelos existentes.
   Inicia una vez, abre por gesto explícito (pestaña Web/navegador Mobile), consulta
   estado propio al regresar/reanudar o pulsar Consultar. Retorno HTML fijo no lee
   estados de URL ni confirma. Protección de sesión/pantalla y doble envío.
   Timeout HTTP 25 s: no equivale a rechazo, conserva clave mientras vive el formulario.
   Efectivo/transferencia/billetera conservan el registro manual anterior.

## Contrato y esquema candidatos, inactivos

- POST `/api/pagos/mercadopago/checkout`: pasajero propio; 200 listo/decidido,
  202 incierto, 400/401/403/404/409/503 uniformes. Clave UUID por cliente.
- GET `/api/pagos/{id_pago}`: solo propio; ajeno/no existente 404. Sin escrituras.
- GET `/api/pagos/mercadopago/retorno`: público informativo fijo. Sin datos privados.
- Extensión de resolución del webhook existente, sin relajar HMAC ni live_mode.
- Migración optativa `mp_0002` después de `mp_0001`, DDL propio y modelo nuevo;
  ambas fuera del head normal de Render, con autorización/localidad antes de conectar.
  `backend/db/schema.sql`, 0001, arrancar.sh y render.yaml siguen intactos.
- `MERCADOPAGO_SANDBOX_ENABLED=false`, `MERCADOPAGO_CHECKOUT_ENABLED=false` y
  Flutter `CHECKOUT_MP_ENABLED=false` por defecto. URLs retorno/webhook vacías;
  al habilitar requieren HTTPS explícito. Token/secret solo variables externas.
- Dependencia Flutter `url_launcher` y lock; no SDK MP ni credenciales en Flutter.
  Las rutas y la opción nueva no se registran/ofrecen por defecto.

## Ensayo aislado reproducible

Automático: `tests/test_checkout.py` usa router real, PostgreSQL `vf_test_<uuid>`
con extensión optativa y MockTransport. Cubre inicio/consulta, CU-016, duplicados,
webhook temprano/concurrente, operaciones distintas, timeout de POST, reconciliación,
commit ambiguo y negativos. `test_migracion_mercadopago.py` compara DDL/modelo y
upgrade/downgrade; la cadena habitual sigue excluyendo ambas tablas optativas.
Flutter: `test/checkout_pago_test.dart`, adaptador HTTP y widget con mocks, sesión
tardía, apertura explícita, retorno móvil, ancho 320/1440 y regresión del pago manual.

Validación ejecutada localmente:

- Backend: **209 casos focalizados verificados por lotes** (31 Checkout y 178 de
  regresión CU-036/pagos/CU-005, migración y contrato), sin omisiones. Primera pasada
  detectó JSON anterior al último YAML; se regeneró y pasaron validez/equivalencia
  y rutas. No se presenta esa primera pasada como completamente aprobada.
- PostgreSQL local efímero: comparación DDL/migración/modelo y upgrade/downgrade/
  reupgrade optativos; prueba de exclusión del head habitual. Ninguna migración remota.
- Flutter: **779 tests en suite completa**. Después se agregó el caso de reapertura
  con misma clave/popup fallido y se ajustó el refresco para no duplicar el manual:
  **45 focalizados finales aprobados**, incluido ese caso, shell y sesión de main.
  Analyze sin incidencias. Build Web debug con flag Checkout: correcto.
- Ruff check y formato: correctos. Diff check e inventario sin archivos locales o
  patrones de credenciales incorporados. Advertencias preexistentes: clave JWT de
  desarrollo corta y deprecación TestClient; no se modificó configuración compartida.
- Sin compra real, firma recibida desde MP ni ejecución en dispositivo Android/iOS.

Prueba real futura, **NO autorizada/ejecutada aquí**: aprobar cambios y perfil de
prueba, preparar PostgreSQL local vacío dedicado, aplicar esquema base y extensión
optativa explícitamente; iniciar backend local con flags y secretos externos,
autorizar HTTPS temporal y configurar notificaciones de la aplicación. Ejecutar
Flutter local con `--dart-define=CHECKOUT_MP_ENABLED=true` y API local; crear solo
una preferencia desde el nuevo circuito y comprar únicamente con cuentas ficticias
después de autorización separada. Verificar recurso Payments y firma auténtica,
estado propio, recibo/movimiento/deuda e idempotencia. No usar la operación conocida
live_mode=true ni cambiar el criterio para hacer pasar el ensayo.

## Riesgos y decisiones para el equipo (ninguna aprobada)

- **Martiniano + Martín + Facundo:** ratificar D1–D6 y su ajuste de migración optativa;
  aprobar intención/UUID, cardinalidades y contrato adicional. Saga DB→POST→DB es
  excepción técnica propuesta a la unidad transaccional de CONVENCIONES §3: no existe
  atomicidad distribuida con MP. Pago+intención son atómicos; acreditación CU-016 también.
- **Martiniano:** revisar `pago_screen.dart`, `pasajero_shell.dart`, enum Pago y
  conexión mínima de `main.dart`, nueva pantalla/adaptador y dependencia de apertura.
  No se enviaron mensajes ni se presume conformidad por esta implementación local.
- **Martín/equipo:** importe libre positivo sigue el registro actual, sin inventar
  tipo de pago, señas, descuentos, reintegros ni reglas de deuda. Confirmar que el
  recorte CU-014 autoriza este inicio y los tres endpoints propuestos.
- **Perfil de prueba:** live_mode=true sigue rechazado, sin flag alternativo.
  Cuentas ficticias/prefijo de token/dominio no habilitan excepción. Exige decisión
  escrita y evidencia verificable para otro perfil; no está desarrollado ni activo aquí.
- **Notificaciones:** la documentación Preferences advierte que pagos creados con
  credenciales de prueba no envían notificaciones. El simulador prueba recepción,
  no garantiza Payment consultable/vínculo. Resolver con proveedor/equipo cómo
  certificar el circuito real sin relajar controles; no confundir mocks con certificación.
- **Incierto:** caída tras guardar intención y antes de POST puede quedar sin preferencia;
  se conserva para conciliación, sin rePOST ciego. Múltiples resultados también requieren
  revisión. No hay reconciliador autónomo, listado de pendientes propios ni recuperación
  de clave tras destruir formulario/recargar Web: decidir ese alcance antes de activación.
- **Dos operaciones o decisión manual:** otro approved para el mismo Pago o CU-016 manual
  antes del vínculo requieren conciliación. No generan otro recibo ni reintegro automático.
- **Mobile/Web:** pruebas con lanzador simulado y compilación Web no certifican navegador
  real, permisos nativos ni retorno en dispositivo. No se configura deep link: el usuario
  vuelve a VanFull y consulta, o la reanudación móvil consulta estado.

## Fuentes oficiales consultadas (29/10/2026)

- [Crear preferencia](https://www.mercadopago.com.ar/developers/en/reference/online-payments/checkout-pro-preferences/create-preference/post).
- [Buscar preferencias por external_reference](https://www.mercadopago.com.ar/developers/en/reference/online-payments/checkout-pro-preferences/search-preferences/get).
- [Notificaciones de Preferences](https://www.mercadopago.com.ar/developers/en/docs/checkout-pro-preferences/payment-notifications): HMAC, ACK y límite de notificación de pagos de prueba.
- [url_launcher](https://pub.dev/packages/url_launcher): apertura por plataforma; sin garantía de retorno automático a la app.

La línea funcional y decisiones originales siguen en CU-014/CU-036, RN-015,
`PROPUESTA-INTEGRACION-REAL-CU036.md` y `ENSAYO-CU036-AISLADO.md`. No se altera la
cobertura integrada ni se presentan estas propuestas como requisitos de VanFull.
