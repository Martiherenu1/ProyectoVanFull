# Contexto vivo · Pasajero y base común del backend (Martiniano)

> Lo mantiene el agente de Martiniano, en el mismo PR que cambia algo. Convención en
> `PROMPT-CONTEXTO-VIVO.md`. Si algo de acá contradice al código, manda el código: corregir este archivo.
>
> **Última actualización: 2026-10-14**

## Estado

Base común del backend en construcción. En `main` están los modelos de las 35 tablas (PR #10) y la migración
inicial con `hash_contrasena` (PR #11); la base se crea con `alembic upgrade head`. El login (CU-012) está
hecho, y el helper de eventos con la guía de convención también; ambos en ramas apiladas, a la espera de
merge, y el seed con sus cuentas de prueba. Con eso la base común queda completa. Del circuito del pasajero
no hay código. En `main` el único endpoint real sigue siendo `/health`.

## Hecho

| Qué | Issue | PR |
|---|---|---|
| Modelos SQLAlchemy 2.0 de las 35 tablas, un archivo por bloque en `app/models/`, y `tests/test_modelos.py`, que los compara con `schema.sql` (tablas, columnas y 54 FK) | #1 | #10 |
| `sqlalchemy[asyncio]` en `requirements.txt` (sin greenlet la app no arrancaba) | #1 | #10 |
| Alembic async, migración `0001` (35 tablas y 5 roles) y `cuenta_acceso.hash_contrasena`, en `schema.sql`, modelo y migración. Verificada contra PostgreSQL 16, también desde la imagen sola | #2 | #11 |
| Contexto vivo: este archivo y `PROMPT-CONTEXTO-VIVO.md` | #12 | #13 |

## En curso

| Qué | Issue | PR | Estado |
|---|---|---|---|
| Corregir inconsistencias de docs y CODEOWNERS tras la base común | #14 | #15 | Abierto, sin revisor: lo mergea el autor |
| Integración continua en GitHub Actions: `ruff`, `pytest` (incluye migración y contrato) | #3 | #16 | Abierto, Auto-fix activado. Falta ver la primera corrida en GitHub |
| Login y logout (CU-012): `core/security.py`, `core/errors.py`, `/auth/*`, 42 pruebas en total | #4 | #17 | Abierto, Auto-fix activado. Apilado sobre #16 |
| `registrar_evento` (`services/eventos.py`, 10 pruebas contra la base) y `backend/CONVENCIONES.md` | #5 | #18 | Abierto. El patrón de la guía se corrió de punta a punta. Apilado sobre #17 |
| Seed (`db/seed/`): 4 cuentas (2 pasajeros, chofer y administrador), un recorrido con 3 paradas; cargador con protección contra bases remotas. 17 pruebas | #6 | en esta rama | Probado en Docker, también el CLI documentado. Apilado sobre #18 |

## Orden de la base común (acordado el 2026-10-13)

1. #1 modelos ✅ → 2. #2 migración inicial y `hash_contrasena` ✅ → 3. **#3 CI** (PR #16) → 4. #4 login
(CU-012, PR #17) → 5. #5 helper de `evento_operativo` y convención (PR #18) → 6. #6 seed (hecho, en esta rama). La CI
va antes del login para que los PR de auth, helper y seed ya pasen por ella.

## Decisiones

| Fecha | Decisión | Quién | Dónde queda |
|---|---|---|---|
| 2026-10-13 | Docker Compose para correr backend, base y pruebas, igual en las tres máquinas. El venv es solo para el editor y opcional | Martiniano | Este archivo |
| 2026-10-13 | `cuenta_acceso.hash_contrasena VARCHAR(255) NOT NULL`, en castellano | Martiniano | PR #11 (en `main`) y CONTEXTO §7. **Falta la confirmación de Martín** por el DER |
| 2026-10-13 | `POST /auth/logout` devuelve 204 y el cliente descarta el token, sin lista negra. La política de sesiones sigue pendiente (CONTEXTO §13) | Martiniano | CONTEXTO §7, se implementa en #4 |
| 2026-10-13 | Sin `relationship()` en los modelos; los servicios consultan explícito. CHECK sin nombre para que PostgreSQL les ponga el mismo que al cargar `schema.sql` | Martiniano | PR #10 |
| 2026-10-14 | El autor mergea su propio PR después de la revisión; los revisores no mergean (CONTRIBUTING §1.7) | Equipo | CONTRIBUTING.md |

## Pendientes

| Qué | Issue | Estado |
|---|---|---|
| Respaldo de la reserva (XOR período de abono / contratación) que `POST /reservas` no informa | #7 | PENDIENTE DE VALIDACIÓN con Martín |
| Filtro `destino` de `/servicios/disponibilidad` sin columna en el modelo | #8 | PENDIENTE DE VALIDACIÓN con Martín |
| Parámetros de `/tarifas` no corresponden a la tabla `tarifa` | #9 | PENDIENTE DE VALIDACIÓN con Martín |
| Lista de espera de CU-003 sin operación en el contrato | sin Issue | Se completa en el circuito de reservas (paso 2). Pasa por el checklist de CONTRIBUTING §1.9 |
| Condiciones de rechazo del login. Hoy: credencial inválida y cuenta con `estado` distinto de `activo` (lectura conservadora del DEFAULT). No se mira `pasajero.estado_habilitacion` ni la política de intentos o bloqueo | #4 | PENDIENTE DE VALIDACIÓN: salen de la especificación v1.3 del CU-012. No la encontré en el Drive (la carpeta 03 no responde a la búsqueda): la pasa Martiniano |
| El contrato usa `password` (inglés) en `LoginRequest` mientras el resto es castellano | #4 | Cambiar una operación existente pide el acuerdo de los tres (§1.3). No se cambió |
| Sin lista negra, un token vale hasta que vence aunque se suspenda la cuenta o se quite un rol | — | Es la decisión del 2026-10-13; la política de sesiones sigue pendiente (CONTEXTO §13) |
| La CI corre por primera vez en GitHub | #3 | SIN VERIFICAR: el workflow se validó como YAML y la suite pasa en Docker, pero nadie vio todavía la corrida en Actions. La imagen no incluye `tests/` (`.dockerignore`): `pytest` corre sobre el checkout |

## Entorno y trampas

- **Docker Desktop tiene que estar abierto.** Si el motor está apagado nada corre. `docker info` lo confirma.
- Checks, desde la raíz del repo y dentro de Docker (Python 3.12, el del Dockerfile):
  `docker compose run --rm --no-deps backend ruff check app/models tests` ·
  `docker compose run --rm --no-deps backend pytest -q`.
- Migraciones (la base tiene que estar levantada: `docker compose up -d db`):
  `docker compose run --rm backend alembic upgrade head` · `... alembic check` · `... alembic downgrade base`.
  Para verificar contra `schema.sql`: dos bases temporales, `schema.sql` en una y `upgrade head` en la otra,
  `pg_dump --schema-only` de ambas y `diff`. Solo difieren el token `\restrict` y un `COMMENT ON SCHEMA`.
- **No correr `ruff format` sobre todo `app` o `tests`:** reformatea archivos de otros (pasó el 2026-10-14, se
  revirtió antes de commitear). Pasarle solo los archivos de la tarea. `migrations/` está excluida de ruff en
  `pyproject.toml`; un `ruff check migrations` explícito sí la revisa y marca estilo del código generado.
- El backend necesita `sqlalchemy[asyncio]` (greenlet); sin él no arranca.
- Git Bash en Windows: `git show origin/main:ruta` falla por la conversión de rutas; usar
  `MSYS_NO_PATHCONV=1`.
- Los números de Issue los asigna GitHub en el orden de creación; verificar con `gh issue list` antes de
  citarlos (el 2026-10-14 el PR #10 citó mal el de la CI y hubo que corregirlo).
- CODEOWNERS asigna `/backend/app/models/` y `/backend/db/` a `@Martiherenu1`, que es el autor de estos PR:
  GitHub no le pide la revisión a sí mismo, así que el revisor se asigna a mano.
- La suite completa son 16 pruebas, tarda unos 15 s e incluye `test_migracion.py`, que crea bases temporales
  (`vf_test_*`) en el PostgreSQL de Docker y las borra. En la CI falla en vez de saltearse si no hay base.
- `ruff` ya no marca `Depends` (B008): `pyproject.toml` lo declara inmutable. Los 7 archivos viejos se
  formatearon el 2026-10-14; el cambio es solo de formato (AST idéntico).
- `backend/.env` existe en la máquina de Martiniano y no está trackeado. La clave de OpenRouter va solo ahí.

## Para otras áreas

**Ya se puede usar (en `main`):** los modelos de las 35 tablas (`from app.models import ...`, o por bloque:
`personas`, `servicios`, `viajes`, `cuenta_corriente`, `trazabilidad`), con `Base` en `app.core.database`.
Quien escribe en cada tabla está en `REPARTO-PC2.md`.

**También ya en `main`:** la migración `0001`. `docker compose run --rm backend alembic upgrade head` crea
las 35 tablas y los 5 roles en una base limpia.

**En la rama del login (#4), cuando se mergee:** `from app.core.security import usuario_actual, requiere_rol`
y `from app.core.errors import ApiError`. `Depends(usuario_actual)` entrega un `UsuarioActual` con
`id_persona` y `roles`; `Depends(requiere_rol("chofer"))` agrega el 403. Los servicios levantan
`ApiError(estado, "CODIGO", "mensaje")` y el cliente recibe `{"error": {...}}` como pide el contrato.
`requiere_rol` solo dice qué clase de operación se puede intentar; **el "solo lo propio" (RN-026 a 030) lo
decide cada servicio** con `id_persona`.

**En la rama del helper (#5), cuando se mergee:** `from app.services.eventos import registrar_evento`
(a lo sumo un origen: reserva, pago o viaje; hace `flush`, el `commit` es tuyo; los `tipo_evento` los define
cada dueño) y la guía `backend/CONVENCIONES.md`, que explica capas, transacción, errores y pruebas.

**En la rama del seed (#6), cuando se mergee:** `docker compose run --rm backend python -m db.seed.cargar`
(con la base migrada). Deja 4 cuentas: `pasajero1@vanfull.test`, `pasajero2@vanfull.test`,
`chofer1@vanfull.test` y `admin1@vanfull.test`, con las contraseñas de `db/seed/contrasenas-de-prueba.csv`.
Cada dueño suma los CSV de sus tablas por PR (ver `db/seed/README.md`). Se niega a correr contra una base
no local: el repo es público y las contraseñas son de desarrollo.

**Qué necesito de las demás áreas:**
- Martín: confirmar `hash_contrasena` en el DER (PR #11, ya mergeado) y resolver #7, #8 y #9.
- Facundo: el servicio de deuda (`GET /pasajeros/me/deuda`) que usa la tool de AG-01 y la pantalla, y el
  backend de pagos que usa la pantalla de pago del pasajero. Sumar al seed `chofer`, `vehiculo` y `viaje`:
  la cuenta `chofer1` todavía no tiene fila en `chofer`.
- Martín: el escenario de la demo cruzada y los CSV de sus tablas.
