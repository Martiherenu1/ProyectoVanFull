# Contexto vivo · Pasajero y base común del backend (Martiniano)

> Lo mantiene el agente de Martiniano, en el mismo PR que cambia algo. Convención en
> `PROMPT-CONTEXTO-VIVO.md`. Si algo de acá contradice al código, manda el código: corregir este archivo.
>
> **Última actualización: 2026-10-14**

## Estado

Base común del backend en construcción. Los modelos de las 35 tablas ya están en `main` (PR #10). La
migración inicial y la columna `hash_contrasena` están en revisión (PR #11). Todavía no hay CI, login, helper
de eventos ni seed. Del circuito del pasajero no hay código. El único endpoint real en `main` sigue siendo
`/health`.

## Hecho

| Qué | Issue | PR |
|---|---|---|
| Modelos SQLAlchemy 2.0 de las 35 tablas, un archivo por bloque en `app/models/`, y `tests/test_modelos.py`, que los compara con `schema.sql` (tablas, columnas y 54 FK) | #1 | #10 |
| `sqlalchemy[asyncio]` en `requirements.txt` (sin greenlet la app no arrancaba) | #1 | #10 |

## En curso

| Qué | Issue | PR | Estado |
|---|---|---|---|
| Alembic async, migración `0001` (35 tablas y 5 roles) y `cuenta_acceso.hash_contrasena` | #2 | #11 | Abierto, revisor Facundo. Aviso a Martín (DER) en el PR. Verificado a mano contra PostgreSQL 16 |

## Orden de la base común (acordado el 2026-10-13)

1. #1 modelos ✅ → 2. #2 migración inicial y `hash_contrasena` (en revisión) → 3. **#3 CI** → 4. #4 login
(CU-012) → 5. #5 helper de `evento_operativo` y convención → 6. #6 seed. La CI va antes del login para que
los PR de auth, helper y seed ya pasen por ella.

## Decisiones

| Fecha | Decisión | Quién | Dónde queda |
|---|---|---|---|
| 2026-10-13 | Docker Compose para correr backend, base y pruebas, igual en las tres máquinas. El venv es solo para el editor y opcional | Martiniano | Este archivo |
| 2026-10-13 | `cuenta_acceso.hash_contrasena VARCHAR(255) NOT NULL`, en castellano | Martiniano | PR #11 y CONTEXTO §7. Falta la confirmación de Martín por el DER |
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
| Condiciones de rechazo del login (cuenta con `estado` distinto de activo) y algoritmo de hash | #4 | Salen de la especificación v1.3 del CU-012, que pasa Martiniano. SIN VERIFICAR |
| `ruff check .` falla en `health.py` (B008, `Depends`) y `ruff format --check .` marca 7 archivos preexistentes | #3 | La CI fallaría sobre `main`. Decidir: configurar ruff o un commit de formato aparte |
| La CI tiene que correr `alembic upgrade head` sobre una base limpia, desde una imagen sin el volumen montado | #3 | SIN VERIFICAR: hasta ahora solo se probó con `./backend` montado en `/app` |

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
- `backend/.env` existe en la máquina de Martiniano y no está trackeado. La clave de OpenRouter va solo ahí.

## Para otras áreas

**Ya se puede usar (en `main`):** los modelos de las 35 tablas (`from app.models import ...`, o por bloque:
`personas`, `servicios`, `viajes`, `cuenta_corriente`, `trazabilidad`), con `Base` en `app.core.database`.
Quien escribe en cada tabla está en `REPARTO-PC2.md`.

**Todavía no:** crear la base con `alembic upgrade head` (espera el PR #11), autenticación y roles (#4),
`registrar_evento(...)` y la guía de convención (#5) y datos de prueba (#6).

**Qué necesito de las demás áreas:**
- Martín: confirmar `hash_contrasena` en el DER (PR #11) y resolver #7, #8 y #9.
- Facundo: el servicio de deuda (`GET /pasajeros/me/deuda`) que usa la tool de AG-01 y la pantalla, y el
  backend de pagos que usa la pantalla de pago del pasajero. Revisión del PR #11.
