# Contexto vivo · Pasajero y base común del backend (Martiniano)

> Lo mantiene el agente de Martiniano, en el mismo PR que cambia algo. Convención en
> `PROMPT-CONTEXTO-VIVO.md`. Si algo de acá contradice al código, manda el código: corregir este archivo.
>
> **Última actualización: 2026-10-14**

## Estado

**La base común del backend está completa y en `main`.** Del circuito del pasajero todavía no hay código:
está frenado por tres pendientes de validación con Martín (#7, #8 y #9), salvo el perfil (CU-001), que
está hecho. En `main` hay `/health`, `/auth/*` y, con el PR #26, `/pasajeros/me`.

La CI corre en cada PR y pasó en las ramas de la base y en `main`. La suite son 69 pruebas, unos 50 a 60 s.

## Hecho

| Qué | Issue | PR |
|---|---|---|
| Modelos SQLAlchemy 2.0 de las 35 tablas y `tests/test_modelos.py`, que los compara con `schema.sql` | #1 | #10 |
| Alembic async, migración `0001` (35 tablas y 5 roles) y `cuenta_acceso.hash_contrasena` | #2 | #11 |
| Contexto vivo: este archivo y `PROMPT-CONTEXTO-VIVO.md` | #12 | #13 |
| Inconsistencias de docs y CODEOWNERS | #14 | #15 |
| CI en GitHub Actions: `ruff`, `pytest` (incluye migración contra `schema.sql` y contrato) | #3 | #16 |
| Login y logout (CU-012), `core/security.py`, `core/errors.py`, `test_rutas_contrato.py` | #4 | #17 |
| `registrar_evento` (`services/eventos.py`) y `backend/CONVENCIONES.md` | #5 | #18 |
| Seed (`db/seed/`) y su cargador | #6 | #19 |
| Perfil del pasajero (CU-001): `GET` y `PATCH /api/pasajeros/me`, 23 pruebas | #24 | #26 |

## En curso

Lo que sigue es el circuito de reservas (CU-002, 003, 004, 010); no se empieza sobre una regla indefinida.
Lo que se puede hacer sin esos pendientes: servicios y disponibilidad sin el filtro `destino` (CU-002).

## Decisiones

| Fecha | Decisión | Dónde queda |
|---|---|---|
| 2026-10-13 | Docker Compose para correr backend, base y pruebas, igual en las tres máquinas; el venv es solo para el editor | Este archivo |
| 2026-10-13 | `cuenta_acceso.hash_contrasena VARCHAR(255) NOT NULL` | PR #11, CONTEXTO §7 |
| 2026-10-13 | `POST /auth/logout` devuelve 204 y el cliente descarta el token, sin lista negra | CONTEXTO §7 |
| 2026-10-13 | Sin `relationship()` en los modelos; los servicios consultan explícito | PR #10 |
| 2026-10-14 | `bcrypt` y `PyJWT` directos (no `passlib` ni `python-jose`) | CONTEXTO §7, PR #17 |
| 2026-10-14 | El servicio hace el `commit`, una vez, al final; el helper de eventos solo hace `flush`. Un recurso ajeno responde 404 | `backend/CONVENCIONES.md` |
| 2026-10-14 | El seed se niega a correr contra una base no local: las contraseñas de prueba están en un repo público | `db/seed/README.md` |
| 2026-10-14 | **La revisión de otro integrante es opcional, para siempre**; el autor mergea con la CI en verde y deja asentado en el PR si hubo revisión. Los PR #10 a #21 se mergearon sin revisión registrada en GitHub | CONTRIBUTING §1.7 |

## Pendientes

| Qué | Issue | Estado |
|---|---|---|
| Respaldo de la reserva (XOR período de abono / contratación) que `POST /reservas` no informa | #7 | PENDIENTE DE VALIDACIÓN con Martín |
| Filtro `destino` de `/servicios/disponibilidad` sin columna en el modelo | #8 | PENDIENTE DE VALIDACIÓN con Martín |
| Parámetros de `/tarifas` no corresponden a la tabla `tarifa` | #9 | PENDIENTE DE VALIDACIÓN con Martín |
| Campos editables del perfil: hoy son los del contrato (`email`, `telefono`, `direccion`), concentrados en `CAMPOS_EDITABLES` de `services/perfil.py`. Tampoco está definido si se puede vaciar un dato ni si el email lleva formato o verificación | #25 | PENDIENTE DE VALIDACIÓN con Martín (es pendiente del cierre de la etapa 03) |
| Lista de espera de CU-003 sin operación en el contrato | sin Issue | Se completa en el circuito de reservas; pasa por el checklist de CONTRIBUTING §1.9 |
| Condiciones de rechazo del login. Hoy: credencial inválida y cuenta con `estado` distinto de `activo` (lectura conservadora del DEFAULT); no se mira `pasajero.estado_habilitacion` ni hay política de intentos | #4 (cerrado) | PENDIENTE DE VALIDACIÓN con la especificación v1.3 del CU-012, que no estaba accesible |
| El contrato usa `password` (inglés) en `LoginRequest` y el resto es castellano | — | Cambiarlo pide el acuerdo de los tres (§1.3). No se cambió |
| Sin lista negra, un token vale hasta que vence (60 min) aunque se suspenda la cuenta | — | Política de sesiones: CONTEXTO §13 |
| Confirmación de Martín por `hash_contrasena` en el DER | — | Pendiente de su respuesta |

## Entorno y trampas

- **Docker Desktop tiene que estar abierto.** Sin el motor nada corre; `docker info` lo confirma.
- **`backend/.env` hace falta** (`cp backend/.env.example backend/.env`): sin él ningún comando del backend
  arranca. No está en el repo; la clave de OpenRouter va solo ahí.
- **La API no migra sola.** Tras `docker compose up -d --build`, `/health` da 200 pero el login da 500 hasta
  correr `alembic upgrade head`. El orden está en el README raíz.
- Checks, desde la raíz y dentro de Docker: `docker compose run --rm --no-deps backend ruff check .` y
  `... ruff format --check .`; pruebas: `docker compose run --rm backend pytest -q`.
- **No correr `ruff format` sobre todo `app` o `tests`**: reformatea archivos de otros. Pasarle solo los de la
  tarea. `ruff format` también formatea los bloques de Python dentro de los `.md` bajo `backend/`.
- La CI cancela la corrida anterior de la misma rama (`concurrency`): en `main`, merges seguidos dejan
  corridas "canceladas" que no son fallas.
- Las pruebas que usan la base crean bases temporales `vf_test_*` en el PostgreSQL de Docker y las borran
  (`tests/_bd.py`). En la CI fallan en vez de saltearse si no hay base.
- Git Bash en Windows: `git show origin/main:ruta` falla por la conversión de rutas; usar `MSYS_NO_PATHCONV=1`.
  Una ruta de clon muy larga falla: `git clone -c core.longpaths=true`.
- Los números de Issue y de PR los asigna GitHub en orden de creación: verificar con `gh` antes de citarlos.
- CODEOWNERS asigna `models/`, `migrations/`, `db/`, `openapi/` y `.github/` a `@Martiherenu1`, que es el
  autor de estos PR: GitHub no le pide la revisión a sí mismo, así que el revisor se asigna a mano.

## Para otras áreas

**Ya se puede usar (en `main`):**
- Modelos de las 35 tablas: `from app.models.<bloque> import ...`; quién escribe en cada tabla está en
  `REPARTO-PC2.md`.
- `from app.core.security import usuario_actual, requiere_rol` y `from app.core.errors import ApiError`.
  El "solo lo propio" (RN-026 a 030) lo decide cada servicio con `usuario.id_persona`.
- `from app.services.eventos import registrar_evento`: a lo sumo un origen (reserva, pago o viaje), hace
  `flush`, los `tipo_evento` los define cada dueño.
- `backend/CONVENCIONES.md`: capas, transacción, errores y pruebas.
- El seed: cuentas `pasajero1@vanfull.test`, `pasajero2@vanfull.test`, `chofer1@vanfull.test` y
  `admin1@vanfull.test`; las contraseñas están en `db/seed/contrasenas-de-prueba.csv`. Cada dueño suma los
  CSV de sus tablas por PR (`db/seed/README.md`).

**Qué necesito de las demás áreas:**
- Martín: confirmar `hash_contrasena` en el DER y resolver #7, #8 y #9; el escenario de la demo cruzada y los
  CSV de sus tablas.
- Facundo: el servicio de deuda (`GET /pasajeros/me/deuda`) que usa la tool de AG-01 y la pantalla, y el
  backend de pagos que usa la pantalla de pago. Sumar `chofer`, `vehiculo` y `viaje` al seed: la cuenta
  `chofer1` todavía no tiene fila en `chofer`.
