# Contexto vivo · Administración y Flutter (Facundo)

## Estado

2026-10-18: `POST /viajes` de CU-018 ya está integrado en `main`. CU-006 está en corrección en
el PR #54. CU-016 está implementado en el PR #52, con CI aprobada y pendiente de revisión.

## Hecho

- PR #50 integrado: primera operación backend de CU-018, `POST /viajes`.
- Issue #53 implementado en el PR #54: consulta de deuda propia de CU-006.

## En curso

- PR #54, rama `feat/admin-consultar-deuda-cu006-53`: integrar `main`, completar el seed y distinguir
  un cliente sin cuenta corriente de un pasajero sin cliente individual.

## Decisiones

- 2026-10-16, Facundo: implementar primero solo la operación ya aprobada en OpenAPI,
  `POST /viajes`, sin cambiar contratos compartidos, modelos ni migraciones. Registrado en #49.
- 2026-10-16, línea base ADJ-03: un viaje puede planificarse sin vehículo ni chofer; se crea en
  estado `programado`. Implementación de #49.
- 2026-10-16, alcance de #49: no incluir modificación, cancelación, reasignación ni ejecución del
  viaje. La ejecución sigue siendo responsabilidad del área de Martín.
- 2026-10-18, Facundo: CU-006 calcula el saldo sin persistirlo; los movimientos `DEUDOR` suman y los
  `ACREEDOR` restan según MR-R30. Un saldo neto acreedor se informa como cero.
- 2026-10-18, Facundo: si existe el cliente individual pero no su cuenta corriente, CU-006 responde
  `200`, saldo `0` y estado `al_dia`, porque sin cuenta no puede haber movimientos asociados.
- 2026-10-18, Facundo: CU-016 crea el movimiento `ACREEDOR` al confirmar el pago; CU-014 y el rechazo
  no crean movimientos. CU-006 conserva el cálculo por movimientos sin inventar estados.

## Pendientes

- #53: cerrar mediante la revisión e integración del PR #54.
- CU-006 devuelve `404 CLIENTE_NO_ENCONTRADO` si no existe el cliente individual. Esa respuesta no
  figura en OpenAPI y agregarla al contrato requiere el acuerdo de los tres integrantes.
- PR #52 debe integrarse para que las confirmaciones de pago creen los movimientos acreedores que
  CU-006 usa al calcular la deuda.
- El catálogo físico de estados de `movimiento_cuenta` continúa PENDIENTE DE VALIDACIÓN; CU-006 no
  filtra por un estado no aprobado.
- CU-015 contempla acciones administrativas sobre deuda, pero todavía no tiene operaciones en
  OpenAPI; no se inventan en este PR.
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
