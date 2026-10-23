# Contexto vivo · Administración y Flutter (Facundo)

## Estado

2026-10-23: #87 y #99 integrados en `main`. Issue #111 conecta la entrada del rol administrador con
`ViajesDiaAdminScreen` mediante fecha, consulta y selección inyectables, sin login, sesión, HTTP ni datos
simulados en producción. Sin rol, múltiples roles y rol desconocido conservan el comportamiento de #48.

2026-10-22: Issue #98 en desarrollo para la pantalla administrativa de Viajes del día (CU-018), con consulta
inyectable y sin HTTP, autenticación ni navegación. CU-014 permanece pausado en el Draft PR #85 por decisiones
pendientes sobre tipo/evidencia, descuento y respuestas para cliente o cuenta inexistentes.

2026-10-19: el PR #47 (tema visual compartido de Flutter) está en `main`. `POST /viajes` de CU-018 también.
CU-006 está en el PR #54 y CU-016 en el PR #52, ambos con CI aprobada. CU-018 y la base común Flutter siguen
siendo trabajos independientes.

## Hecho

- PR #50: `POST /viajes`, primera operación backend de administración, integrado en `main`.
- PR #87: cliente API HTTP compartido, integrado en `main`.
- PR #99 / Issue #98: pantalla Flutter administrativa de Viajes del día, integrada en `main`.
- CU-018 mantiene cobertura parcial en el contrato vigente.
- PR #47: temas oscuro para pasajero/chofer y claro para administración, tokens compartidos y vista temporal de
  verificación. La corrección A.0–A.8 deja esquemas de color explícitos, dorado accesible en el tema claro,
  tipografía Material completa y superficies sin sombras ni tintes.
- Issue #48 implementado en esta rama: enrutador inicial por rol y portadas temporales para CU-002, CU-029 y
  CU-018.
- Issue #53 implementado en el PR #54: consulta de deuda propia de CU-006.
- Issue #51 implementado en el PR #52: confirmación o rechazo manual de pagos de CU-016.

## En curso

- Issue #111: navegación hacia Viajes del día con dependencias inyectables; el endpoint administrativo todavía
  no está contratado.
- PR #54 (CU-006) y PR #52 (CU-016): integrar `main` y mergear.

## Decisiones

- 2026-10-16, Facundo: implementar primero solo la operación ya aprobada en OpenAPI,
  `POST /viajes`, sin cambiar contratos compartidos, modelos ni migraciones. Registrado en #49.
- 2026-10-16, línea base ADJ-03: un viaje puede planificarse sin vehículo ni chofer; se crea en
  estado `programado`. Implementación de #49.
- 2026-10-16, alcance de #49: no incluir modificación, cancelación, reasignación ni ejecución del
  viaje. La ejecución sigue siendo responsabilidad del área de Martín.
- 2026-10-19, #47: mantener Archivo para texto general e IBM Plex Mono solo para datos numéricos explícitos.
  Las etiquetas en mayúsculas se transforman en el widget, porque `TextStyle` no modifica el contenido.
- 2026-10-19, #47: aplicar las densidades 48/64/36 y la navegación real en #48; #47 sólo define los tokens y
  muestra los tres temas sin incorporar funcionalidad de navegación.
- 2026-10-20, #48: la navegación acepta un único rol conocido (`pasajero`, `chofer` o `administrador`). Sin rol,
  con varios roles o con un rol desconocido no selecciona una portada y muestra un estado pendiente explícito.
- 2026-10-20, #48: las entradas temporales son Buscar servicio (CU-002), Lista del viaje (CU-029) y Viajes del
  día (CU-018), con sus temas y alturas 48/64/36; no implementan todavía funcionalidad ni permisos.
- 2026-10-18, Facundo: CU-006 calcula el saldo sin persistirlo; los movimientos `DEUDOR` suman y los
  `ACREEDOR` restan según MR-R30. Un saldo neto acreedor se informa como cero.
- 2026-10-18, Facundo: si existe el cliente individual pero no su cuenta corriente, CU-006 responde
  `200`, saldo `0` y estado `al_dia`, porque sin cuenta no puede haber movimientos asociados.
- 2026-10-18, Facundo: CU-016 crea el movimiento `ACREEDOR` al confirmar el pago; CU-014 y el rechazo
  no crean movimientos. CU-006 conserva el cálculo por movimientos sin inventar estados.
- 2026-10-18, Facundo: CU-016 crea, al confirmar, exactamente un `MovimientoCuenta` de naturaleza
  `ACREEDOR`, asociado al cliente y al pago, por el importe pagado. El rechazo y CU-014 no crean
  movimientos. Motivo: MR-R30 calcula la deuda desde movimientos y esta alternativa evita inventar
  un catálogo de estados todavía pendiente. El movimiento se confirma en la misma transacción que
  el pago y el recibo.

## Pendientes

- CU-014: Draft PR #85 pausado; no declarar completo hasta resolver persistencia de tipo/evidencia, descuento y
  respuestas para clientes inexistentes o sin cuenta corriente.
- Issue #111: la consulta real queda pendiente del endpoint administrativo para listar viajes y de la
  autenticación; el cliente compartido ya está integrado, pero esta tarea no inventa un adaptador sin contrato.
- #53 y #51: cerrar mediante la revisión e integración de los PR #54 y #52.
- CU-006 devuelve `404 CLIENTE_NO_ENCONTRADO` si no existe el cliente individual. Esa respuesta no
  figura en OpenAPI y agregarla al contrato requiere el acuerdo de los tres integrantes.
- PR #52 debe integrarse para que las confirmaciones de pago creen los movimientos acreedores que
  CU-006 usa al calcular la deuda.
- El catálogo físico de estados de `movimiento_cuenta` continúa PENDIENTE DE VALIDACIÓN; CU-006 no
  filtra por un estado no aprobado.
- CU-015 contempla acciones administrativas sobre deuda, pero todavía no tiene operaciones en
  OpenAPI; no se inventan en este PR.
- CU-018: reglas detalladas de conflictos o solapamientos de asignaciones están PENDIENTES DE
  VALIDACIÓN y no fueron implementadas por #50 (#49).
- CU-018 continúa con cobertura parcial: modificación, cancelación y reasignaciones requieren una
  tarea y contrato posteriores; fuera del alcance de #49.
- #47: Martiniano debe confirmar Archivo + IBM Plex Mono antes de incorporar archivos de fuentes y desactivar
  la descarga en ejecución. No se descargaron ni agregaron fuentes en esta corrección.
- #47: completar la plantilla del cuerpo del PR requiere una autorización remota separada.
- #48: integrar los roles de la autenticación cuando esté disponible y reemplazar las portadas temporales por
  las definitivas; la resolución de cuentas con múltiples roles continúa PENDIENTE DE VALIDACIÓN.
- #48: `AppTheme.admin` es sólo el fallback visual temporal de los estados sin rol; no selecciona el rol de
  administración y debe revisarse al integrar autenticación.

## Entorno y trampas

- Docker Desktop debe estar iniciado para ejecutar PostgreSQL, Ruff y Pytest según el flujo del repo.
- `gh` no está instalado en este equipo; el Issue #49 se creó desde GitHub en el navegador.
- Ejecutar el formateador solamente sobre los archivos de esta tarea para no tocar otras áreas.
- La suite completa mantiene advertencias conocidas de JWT de desarrollo y TestClient en desuso.

## Para otras áreas

- `POST /viajes` está disponible en `main` desde el PR #50.
- Martín: esta tarea solo crea y planifica viajes; no cambia inicio, finalización, GPS ni abordajes.
- Martiniano: esta tarea no cambia reservas, disponibilidad ni contratos compartidos.
