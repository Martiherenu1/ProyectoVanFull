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
└── agent/             # AG-01: tools.py (11 tools) + openrouter_client.py (fallback)
```

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

```bash
cd backend
pytest
```

## Migraciones (próximo paso, al tener modelos)

```bash
alembic init migrations      # una sola vez
alembic revision --autogenerate -m "esquema inicial"
alembic upgrade head
```
