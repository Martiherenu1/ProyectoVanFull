# Contexto vivo · Administración y Flutter (Facundo)

## Estado

2026-10-16: CU-018 está en implementación con su primera operación backend, `POST /viajes`.
Los PR #45 y #47 pertenecen a la base común Flutter y siguen independientes de este trabajo.

## Hecho

- En `main` todavía no hay una operación backend propia del área de administración.
- El contrato vigente ya declara `POST /viajes` con cobertura parcial de CU-018.

## En curso

- Issue: [#49](https://github.com/Martiherenu1/ProyectoVanFull/issues/49), abierto y con etiqueta
  `admin`.
- Rama: `feat/admin-crear-viaje-cu018-49`.
- Alcance: schemas, servicio, router y pruebas de creación de viajes; revisión local completa.
- Checks locales: Ruff aprobado; 13 pruebas específicas y 140 pruebas totales aprobadas.

## Decisiones

- 2026-10-16, Facundo: implementar primero solo la operación ya aprobada en OpenAPI,
  `POST /viajes`, sin cambiar contratos compartidos, modelos ni migraciones. Registrado en #49.
- 2026-10-16, línea base ADJ-03: un viaje puede planificarse sin vehículo ni chofer; se crea en
  estado `programado`. Implementación de #49.
- 2026-10-16, alcance de #49: no incluir modificación, cancelación, reasignación ni ejecución del
  viaje. La ejecución sigue siendo responsabilidad del área de Martín.

## Pendientes

- #49: publicar el PR, verificar su CI y hacer el merge.
- #49: reglas detalladas de conflictos o solapamientos de asignaciones están PENDIENTES DE
  VALIDACIÓN en CU-018 v1.3 y no se implementan en esta operación.
- CU-018 continúa con cobertura parcial: modificación, cancelación y reasignaciones requieren una
  tarea y contrato posteriores; fuera del alcance de #49.

## Entorno y trampas

- Docker Desktop debe estar iniciado para ejecutar PostgreSQL, Ruff y Pytest según el flujo del repo.
- `gh` no está instalado en este equipo; el Issue #49 se creó desde GitHub en el navegador.
- Ejecutar el formateador solamente sobre los archivos de esta tarea para no tocar otras áreas.
- La suite completa mantiene 84 advertencias conocidas de JWT de desarrollo y TestClient en desuso.

## Para otras áreas

- `POST /viajes` todavía no está disponible en `main`; no consumirlo hasta que se integre el PR de #49.
- Martín: esta tarea solo crea y planifica viajes; no cambia inicio, finalización, GPS ni abordajes.
- Martiniano: esta tarea no cambia reservas, disponibilidad ni contratos compartidos.
