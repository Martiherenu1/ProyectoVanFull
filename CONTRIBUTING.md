# Guía de contribución — Vanfull

Convenciones de trabajo del equipo para mantener el repo ordenado y trazable.
Base de trabajo: la línea funcional aprobada (RF, RNF, RN, CU, DER/MR). No inventar; ante dudas, marcar
`PENDIENTE DE VALIDACIÓN` y coordinar.

## Flujo de trabajo

```
Issue → Branch → Desarrollo → Commit → Pull Request → Revisión → Merge
```

- **Issue** por cada funcionalidad, defecto o tarea técnica (idealmente atado a un CU/RF/RN).
- **Branch por tarea**, nunca commitear directo a `main`.
- **Pull Request** como unidad de revisión. Revisión de un compañero antes del merge.
- `main` siempre en estado desplegable.

## Nombres de ramas

`<tipo>/<descripcion-corta>` — ejemplos:

- `feat/modelos-orm-personas`
- `feat/endpoint-crear-reserva-cu003`
- `fix/validacion-cupo-rn001`
- `docs/actualizar-readme`
- `chore/config-ci`

## Commits — Conventional Commits

`<tipo>: <descripción en imperativo>` — tipos: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`.

```
feat: agregar modelo ORM y migración de RESERVA (CU-003, RN-001/031)
fix: corregir cálculo de cupo disponible
test: cubrir período de pago de abonos (RN-003/004)
```

Cuando aplique, referenciar el **CU/RF/RN** en el cuerpo para mantener trazabilidad.

## Trazabilidad esperada (backend)

```
CU → operación → endpoint → servicio → datos → prueba
```

Las reglas de negocio (RN) se validan en **FastAPI/servicios**, nunca en el frontend ni en el agente.
El agente de IA no accede directo a PostgreSQL: usa los servicios/API.

## Checklist antes de marcar una tarea como terminada

- [ ] ¿Existe RF/CU/RN que justifique el cambio?
- [ ] ¿Respeta actores y permisos?
- [ ] ¿Las RN se validan en backend?
- [ ] ¿OpenAPI/contratos actualizados si cambió la API?
- [ ] ¿No rompe contratos que consume Flutter/el agente?
- [ ] ¿Tiene pruebas?
- [ ] ¿`ruff check` y `pytest` pasan?
- [ ] ¿Los pendientes quedaron documentados?

## Calidad de código

```bash
cd backend
ruff check .      # lint
ruff format .     # formato
pytest            # tests
```
