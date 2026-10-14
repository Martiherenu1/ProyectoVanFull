# Vanfull — Backend (FastAPI)

## Arquitectura por capas

```
app/
├── main.py            # Entry point FastAPI + CORS + routers
├── core/
│   ├── config.py      # Settings (env vars / .env)
│   └── database.py    # Engine async SQLAlchemy 2.0 + get_db()
├── models/            # Modelos ORM (a partir del DER)
├── schemas/           # Pydantic (I/O de la API)
├── routers/           # Endpoints HTTP
├── services/          # Reglas de negocio (RN-001..031): cupos, deuda, pagos
└── agent/             # AG-01: tools.py (13 tools) + openrouter_client.py (fallback)
```

Fuera de `app/`: `migrations/` y `alembic.ini` (Alembic), `db/` (`schema.sql` de referencia y su README),
`openapi/` (el contrato) y `tests/`.

**Regla de oro:** los `routers` no contienen reglas de negocio; delegan en `services`. El agente AG-01
llama a esos mismos `services` vía tools — nunca toca la BD directamente.

## Correr con Docker (recomendado)

Desde la raíz del repo:

```bash
cp backend/.env.example backend/.env
docker compose up --build
```

## Correr en local (sin Docker)

> Tenés Python 3.14 instalado; algunos paquetes aún no publican wheels para 3.14.
> Si tenés problemas, usá Python 3.12 en el venv o corré por Docker.

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate      # Windows PowerShell
pip install -r requirements.txt
# Necesitás un PostgreSQL corriendo y DATABASE_URL apuntando a él
uvicorn app.main:app --reload
```

## Tests

Corren dentro de Docker, con la base levantada (`docker compose up -d db`), desde la raíz del repo:

```bash
docker compose run --rm backend pytest -q
docker compose run --rm --no-deps backend ruff check .
docker compose run --rm --no-deps backend ruff format --check .
```

`tests/test_migracion.py` crea bases temporales en ese PostgreSQL, así que necesita la base arriba.
La misma secuencia corre en GitHub Actions (`.github/workflows/ci.yml`) en cada PR y en cada push a `main`.

## Cómo se escribe una operación

La convención de capas, transacciones, errores y pruebas está en [`CONVENCIONES.md`](CONVENCIONES.md). El
ejemplo a copiar es el login (`services/auth.py`, `routers/auth.py`).

## Autenticación y errores

`POST /api/auth/login` entrega un JWT con la cuenta, la persona y los roles. En un router:

```python
from app.core.security import UsuarioActual, requiere_rol, usuario_actual

@router.get("/algo")
async def algo(usuario: UsuarioActual = Depends(usuario_actual)): ...           # cualquier rol

@router.post("/otra", dependencies=[Depends(requiere_rol("administrador"))]): ...  # solo ese rol
```

`requiere_rol` solo filtra por rol. El permiso "solo lo propio" (RN-026 a 030) lo decide el servicio con
`usuario.id_persona`. Los servicios no devuelven HTTP: levantan `ApiError(409, "CUPO_NO_DISPONIBLE", "...")`
(`app/core/errors.py`) y el cliente recibe siempre `{"error": {"codigo", "mensaje", "detalles"}}`.
`tests/test_rutas_contrato.py` falla si el backend implementa una ruta que `openapi.yaml` no declara.

## Migraciones (Alembic)

La base se crea con migraciones, no a mano. La migración inicial (`0001`) crea las 35 tablas de
`db/schema.sql` y carga los 5 roles. Desde la raíz del repo, con la base levantada (`docker compose up -d db`):

```bash
docker compose run --rm backend alembic upgrade head     # crea o actualiza la base
docker compose run --rm backend alembic check            # los modelos y la base coinciden
docker compose run --rm backend alembic downgrade base   # la deja vacía
```

Para un cambio de modelo: tocar `db/schema.sql`, `app/models/` y generar la migración **en el mismo PR**
(`alembic revision --autogenerate -m "..."`), y **leerla antes de commitear**: el autogenerate no detecta
datos (como los roles) ni renombres. Un cambio de modelo se avisa a Martín, dueño del DER.
