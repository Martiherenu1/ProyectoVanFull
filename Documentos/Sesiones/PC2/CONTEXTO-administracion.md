# Contexto PC2 — Administración

Estado vivo del área de Facundo. Las fuentes funcionales y el reparto siguen siendo las indicadas en
`CLAUDE.md`, `CONTRIBUTING.md` y `REPARTO-PC2.md`.

## Consulta de deuda propia — Issue #53

- **Responsable:** Facundo, porque es dueño del backend de cuenta corriente y deuda. La pantalla de
  pasajero que consume esta operación continúa fuera de esta rama y pertenece a Martiniano.
- **Trazabilidad:** CU-006, RF-010, RN-004, RN-005, RN-006 y MR-R30.
- **Contrato existente:** `GET /pasajeros/me/deuda`, respuesta `Deuda {saldo, estado}`.
- **Alcance de la rama:** schema de salida, servicio de cálculo derivado, router y pruebas. No cambia
  `openapi.yaml`, modelos, migraciones, seed ni frontend.
- **Cálculo:** suma de movimientos `DEUDOR` menos movimientos `ACREEDOR`; como la respuesta es saldo
  deudor, un saldo neto acreedor se informa como cero. Nunca se persiste el resultado.
- **Permiso:** se identifica la cuenta desde `usuario.id_persona`; no se acepta un id de cliente en la
  URL ni en el cuerpo.
- **Estados de respuesta:** `al_dia` cuando el saldo deudor es cero y `con_deuda` cuando es mayor que
  cero. Es una decisión técnica del área registrada en el Issue #53; el contrato solo tipa el campo
  como string y ejemplifica `al_dia`.

## Verificación local del Issue #53

- `ruff check .`: correcto.
- `ruff format --check .`: 59 archivos ya formateados.
- `pytest -q tests/test_deuda.py`: 8 pruebas correctas.
- `pytest -q`: 140 pruebas correctas. Las advertencias existentes de TestClient y de la clave JWT de
  desarrollo no provocan fallos.

## Límites y pendientes relacionados

- **PENDIENTE DE VALIDACIÓN / contrato:** CU-015 contempla acciones administrativas sobre deuda, pero
  todavía no existen operaciones para ellas en `openapi.yaml`; no se inventan en esta rama.
- El modelo relacional define `MOVIMIENTO_CUENTA` como impacto económico y deja pendiente el catálogo
  físico de estados. La consulta suma los movimientos existentes sin inventar un filtro por `estado`.
- La consulta queda implementada de manera independiente. La creación de movimientos deudores y
  acreedores corresponde a los flujos de contratación/pagos y se integra cuando esos CU estén
  implementados.
