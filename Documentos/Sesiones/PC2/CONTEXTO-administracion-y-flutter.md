# Contexto vivo · Administración y Flutter (Facundo)

## Estado

2026-10-19: el PR #47 corrige el tema visual compartido de Flutter sobre `main`.
CU-018 y la base común Flutter siguen siendo trabajos independientes.

## Hecho

- PR #50: `POST /viajes`, primera operación backend de administración, integrado en `main`.
- CU-018 mantiene cobertura parcial en el contrato vigente.
- PR #47: temas oscuro para pasajero/chofer y claro para administración, tokens compartidos y vista temporal de
  verificación. La corrección A.0–A.8 deja esquemas de color explícitos, dorado accesible en el tema claro,
  tipografía Material completa y superficies sin sombras ni tintes.

## En curso

- Issue #46 / PR #47: correcciones del tema visual compartido y sus pruebas.

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

## Pendientes

- CU-018: reglas detalladas de conflictos o solapamientos de asignaciones están PENDIENTES DE
  VALIDACIÓN y no fueron implementadas por #50.
- CU-018 continúa con cobertura parcial: modificación, cancelación y reasignaciones requieren una
  tarea y contrato posteriores; fuera del alcance de #49.
- #47: Martiniano debe confirmar Archivo + IBM Plex Mono antes de incorporar archivos de fuentes y desactivar
  la descarga en ejecución. No se descargaron ni agregaron fuentes en esta corrección.
- #47: completar la plantilla del cuerpo del PR requiere una autorización remota separada.
- #48: aplicar tamaños táctiles y alturas 48 px pasajero, 64 px chofer y 36 px administración en los widgets de
  navegación y pantallas reales; reemplazar `ThemePreview`.

## Entorno y trampas

- Docker Desktop debe estar iniciado para ejecutar PostgreSQL, Ruff y Pytest según el flujo del repo.
- `gh` no está instalado en este equipo; el Issue #49 se creó desde GitHub en el navegador.
- Ejecutar el formateador solamente sobre los archivos de esta tarea para no tocar otras áreas.
- La suite completa mantiene 84 advertencias conocidas de JWT de desarrollo y TestClient en desuso.

## Para otras áreas

- `POST /viajes` está disponible en `main` desde el PR #50.
- Martín: esta tarea solo crea y planifica viajes; no cambia inicio, finalización, GPS ni abordajes.
- Martiniano: esta tarea no cambia reservas, disponibilidad ni contratos compartidos.
