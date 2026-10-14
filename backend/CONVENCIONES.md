# Convenciones del backend

Cómo se escribe una operación nueva (un servicio y su endpoint) para que las tres áreas queden
parecidas. **El ejemplo a copiar es el login**: `app/services/auth.py`, `app/routers/auth.py`,
`app/schemas/auth.py` y `tests/test_auth.py`. Esta guía explica el porqué de cada decisión.

Las reglas del proyecto están en `CLAUDE.md` y el método de trabajo en `CONTRIBUTING.md`; acá solo
lo que es propio del código del backend.

## 1. Las cuatro capas

| Capa | Archivo | Qué hace | Qué NO hace |
|---|---|---|---|
| Router | `app/routers/<tema>.py` | Recibe HTTP, declara el rol, delega | Reglas de negocio, consultas, `commit` |
| Schema | `app/schemas/<tema>.py` | Forma de entrada y salida (Pydantic) | Devolver objetos de SQLAlchemy |
| Servicio | `app/services/<tema>.py` | **Las reglas (RN)** y la transacción | Conocer HTTP o `Request` |
| Modelo | `app/models/<bloque>.py` | Las tablas | Lógica |

Una regla de negocio vive **una sola vez**, en un servicio. El router, el frontend y el agente AG-01
no la repiten: el agente llama al mismo servicio por una tool.

## 2. Receta para una operación nueva

1. **El contrato primero.** Si la ruta no está en `backend/openapi/openapi.yaml`, se agrega ahí
   (PR de contrato, checklist de CONTRIBUTING §1.9). `tests/test_rutas_contrato.py` falla si el
   backend implementa una ruta que el contrato no declara.
2. **Schema** con los nombres del contrato.
3. **Servicio** con la regla, citando la RN en un comentario (`# RN-001`).
4. **Router** fino, registrado en `app/main.py` con `prefix=settings.api_prefix`.
5. **Pruebas**: el servicio contra la base real, y el endpoint con `TestClient`.
6. **Contexto**: actualizar `Documentos/Sesiones/PC2/CONTEXTO-<tu-área>.md` en el mismo PR.

## 3. Servicios

```python
async def hacer_algo(db: AsyncSession, usuario: UsuarioActual, datos: AlgoCrear) -> Algo:
    # 1. Existe y es del usuario (si no, 404: el contrato de /reservas/{id} solo declara 404).
    # 2. Se cumplen las reglas (cada una con su RN y su ApiError 409).
    # 3. Se escribe, y el evento va en la misma transacción.
    await registrar_evento(db, tipo_evento=TIPO_ALGO_HECHO, id_reserva=algo.id_reserva)
    # 4. Se confirma una sola vez, al final.
    await db.commit()
    return algo
```

- **El servicio decide la transacción.** Una llamada al servicio es una unidad de trabajo: o se
  guarda todo o nada. El router no hace `commit`, y las tools del agente reciben la misma atomicidad
  porque llaman al mismo servicio. Si algo levanta una excepción antes del `commit`, la sesión se
  cierra y la base revierte.
- **Los errores de negocio se levantan con `ApiError`**, no con `HTTPException`:
  `ApiError(409, "CUPO_NO_DISPONIBLE", "No hay cupo para el viaje.")`. El `codigo` es estable y en
  `MAYUSCULAS_CON_GUIONES`: es lo que usa el cliente para decidir qué mostrar. El mensaje es para
  una persona.
- **"Solo lo propio"** (RN-026 a RN-030) lo decide el servicio con `usuario.id_persona`. El rol
  (`requiere_rol`) solo dice qué clase de operación puede intentar. Un recurso ajeno responde **404**,
  no 403, para no revelar que existe.
- **No se escribe en tablas de otra área.** Si hace falta un dato de otro dueño, se llama a su
  servicio. La tabla de dueños está en `REPARTO-PC2.md`.
- **Un `ValueError` es un error del programador**, no del usuario: sale como 500. Se usa en helpers
  internos (como `registrar_evento`) y nunca para una regla de negocio.

## 4. Códigos de estado

| Estado | Cuándo | Código |
|---|---|---|
| 400 | Cuerpo o parámetros inválidos (lo genera FastAPI solo) | `VALIDACION` |
| 401 | Sin token o inválido; credenciales incorrectas | `NO_AUTENTICADO`, `CREDENCIALES_INVALIDAS` |
| 403 | El rol no corresponde | `SIN_PERMISO` |
| 404 | No existe o no es tuyo | `NO_ENCONTRADO` o uno propio |
| 409 | Choca con una regla de negocio (cupo, duplicado, estado) | uno propio |

Todo error sale como `{"error": {"codigo", "mensaje", "detalles"}}` (schema `Error` del contrato).
La validación responde **400** y no el 422 de FastAPI, porque así lo fija el contrato, y nunca repite
el valor recibido (podría ser una contraseña).

## 5. Routers

```python
router = APIRouter(prefix="/reservas", tags=["reservas"])


@router.post(
    "", response_model=ReservaOut, status_code=201, dependencies=[Depends(requiere_rol("pasajero"))]
)
async def crear(
    datos: ReservaCrear,
    usuario: UsuarioActual = Depends(usuario_actual),
    db: AsyncSession = Depends(get_db),
):
    return await servicio.crear_reserva(db, usuario, datos)
```

- El estado y el cuerpo salen del contrato, no se eligen.
- `Depends(...)` y `requiere_rol(...)` en argumentos por defecto son el patrón de FastAPI: `ruff` los
  tiene declarados como inmutables en `pyproject.toml`.

## 6. Eventos operativos

`registrar_evento(db, tipo_evento=..., id_reserva=... | id_pago=... | id_viaje=...)`
(`app/services/eventos.py`) es la única forma de escribir en `evento_operativo`.

- A lo sumo un origen por evento (MR-R29); el helper lo controla y la base también.
- **No hay un catálogo aprobado de `tipo_evento`.** Cada dueño define los suyos como constantes en su
  servicio y no inventa tipos de otra área.
- Hace `flush` y no `commit`: el evento queda en tu transacción.
- Es una traza operativa, no una auditoría (la auditoría es una propuesta no aprobada).

## 7. Pruebas

- Archivos `tests/test_<tema>.py`, nombres de prueba en castellano que dicen qué se espera.
- Lo que toca la base usa `tests/_bd.py`: `base_migrada()` crea una base temporal con `alembic upgrade
  head` y la borra al terminar. Ver `tests/test_auth.py` y `tests/test_eventos.py`.
- **No se hacen mocks de la base.** Lo que se prueba son restricciones, FK y transacciones reales.
- Correr (desde la raíz del repo, con Docker abierto y la base arriba):
  `docker compose run --rm backend pytest -q`.
- Antes de commitear: `ruff check` y `ruff format --check` **solo sobre tus archivos**.

## 8. Lo que no se hace

- Reglas de negocio en un router, en el frontend o en el prompt del agente.
- `relationship()` en los modelos: los servicios consultan explícito.
- Agregar una ruta sin contrato, o cambiar una operación existente sin el acuerdo de los tres.
- Guardar saldo, deuda o cupo: se calculan (MR-R30).
- Meter claves o contraseñas en el repositorio.
