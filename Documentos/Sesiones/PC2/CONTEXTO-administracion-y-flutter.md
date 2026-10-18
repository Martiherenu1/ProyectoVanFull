# Contexto vivo · Administración y Flutter (Facundo)

## Estado

2026-10-18: `POST /viajes` de CU-018 ya está integrado en `main`. CU-016 está en corrección en
el PR #52 para que la confirmación de un pago también impacte en la deuda.

## Hecho

- PR #50 integrado: primera operación backend de CU-018, `POST /viajes`.
- Issue #51 implementado en el PR #52: confirmación o rechazo manual de pagos de CU-016.

## En curso

- PR #52, rama `feat/admin-confirmar-pago-cu016-51`: integrar `main`, registrar el impacto
  contable al confirmar y completar sus pruebas de atomicidad.

## Decisiones

- 2026-10-16, Facundo: implementar primero solo la operación ya aprobada en OpenAPI,
  `POST /viajes`, sin cambiar contratos compartidos, modelos ni migraciones. Registrado en #49.
- 2026-10-16, línea base ADJ-03: un viaje puede planificarse sin vehículo ni chofer; se crea en
  estado `programado`. Implementación de #49.
- 2026-10-16, alcance de #49: no incluir modificación, cancelación, reasignación ni ejecución del
  viaje. La ejecución sigue siendo responsabilidad del área de Martín.
- 2026-10-18, Facundo: CU-016 crea, al confirmar, exactamente un `MovimientoCuenta` de naturaleza
  `ACREEDOR`, asociado al cliente y al pago, por el importe pagado. El rechazo y CU-014 no crean
  movimientos. Motivo: MR-R30 calcula la deuda desde movimientos y esta alternativa evita inventar
  un catálogo de estados todavía pendiente. El movimiento se confirma en la misma transacción que
  el pago y el recibo.

## Pendientes

- #51: cerrar mediante la revisión e integración del PR #52.
- #49: reglas detalladas de conflictos o solapamientos de asignaciones están PENDIENTES DE
  VALIDACIÓN en CU-018 v1.3 y no se implementan en esta operación.
- CU-018 continúa con cobertura parcial: modificación, cancelación y reasignaciones requieren una
  tarea y contrato posteriores; fuera del alcance de #49.

## Entorno y trampas

- Docker Desktop debe estar iniciado para ejecutar PostgreSQL, Ruff y Pytest según el flujo del repo.
- `gh` no está instalado en este equipo; el Issue #49 se creó desde GitHub en el navegador.
- Ejecutar el formateador solamente sobre los archivos de esta tarea para no tocar otras áreas.
- La suite completa mantiene advertencias conocidas de JWT de desarrollo y TestClient en desuso.

## Para otras áreas

- `POST /viajes` está disponible en `main` desde el PR #50.
- Martín: esta tarea solo crea y planifica viajes; no cambia inicio, finalización, GPS ni abordajes.
- Martiniano: esta tarea no cambia reservas, disponibilidad ni contratos compartidos.
