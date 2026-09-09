# Vanfull — Plataforma de gestión de viajes en micro

Monorepo del proyecto académico **Vanfull** (Trabajo de Campo, Ing. en Informática, 2º cuatrimestre 2026).
Plataforma Web + Mobile para centralizar reservas, pagos, notificaciones, seguimiento GPS y un agente
conversacional de IA para una empresa real de charters.

## Stack

| Capa | Tecnología |
|---|---|
| Frontend | Flutter (Web + Mobile) |
| Backend | Python + FastAPI (REST / OpenAPI) |
| Base de datos | PostgreSQL |
| IA (AG-01) | OpenRouter → MiniMax M3 (principal) / Nemotron 3 Super (fallback) |
| Mapas | Google Maps Platform (Routes API) |
| Pagos | Mercado Pago (entorno de pruebas) |
| Mensajería | WhatsApp |
| Deploy | Railway / Render |

**Principio de arquitectura:** la IA no accede a la base de datos; sólo llama *tools* de FastAPI, que
gobierna auth, permisos, cupos, reglas de negocio y pagos.

## Estructura

```
ProyectoVanFull/
├── backend/          # API FastAPI (app/core, models, schemas, routers, services, agent)
├── frontend/         # App Flutter Web + Mobile
├── docker-compose.yml
└── Documentos/       # TODA la documentación que no es código
    ├── Documentacion/    # Análisis, requisitos, DER, cronograma
    ├── Recursos/         # Referencias técnicas
    ├── Sesiones/         # Contexto de trabajo (CONTEXTO.md)
    ├── HITOS.md          # Hitos profesionales
    └── *.docx            # Fuentes originales (entrevista, cronograma, PC1)
```

## Puesta en marcha (backend + base de datos)

```bash
cp backend/.env.example backend/.env
docker compose up --build
```

- API: http://localhost:8000  ·  Docs OpenAPI: http://localhost:8000/docs
- Salud: http://localhost:8000/api/health

## Documentación clave

- Contexto rápido del proyecto: [`Documentos/Sesiones/CONTEXTO.md`](Documentos/Sesiones/CONTEXTO.md)
- Modelo de datos (DER): [`Documentos/Documentacion/03-Modelo-de-Datos-DER-v0.1.md`](Documentos/Documentacion/03-Modelo-de-Datos-DER-v0.1.md)
- Cronograma: [`Documentos/Documentacion/02-Cronograma.md`](Documentos/Documentacion/02-Cronograma.md)

## Equipo

3 integrantes. Flujo de trabajo: Issue → Branch → PR → Revisión → Merge.
