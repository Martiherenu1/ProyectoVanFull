# Guía de contribución — VanFull

**El método de trabajo del equipo, para personas y para agentes de IA.** Este archivo es la única fuente del
"cómo se trabaja": si algo de acá contradice a otro documento, vale lo que dice acá. Quién es dueño de qué está
en `Documentos/Sesiones/PC2/REPARTO-PC2.md`.

Base de trabajo: la línea funcional aprobada (45 RF, 14 RNF, 31 RN, 37 CU, DER/MR). **No inventar.** Ante una
duda, marcar `PENDIENTE DE VALIDACIÓN` y consultar.

---

## 1. El ciclo de una tarea

```
Issue → verificar → rama → desarrollo en pasos chicos → checks → commit → PR → revisión → merge → cierre
```

### 1.1 Issue (antes de tocar nada)

- Toda tarea tiene un **Issue en GitHub** (plantilla "Tarea"): qué se hace, el CU/RF/RN que la justifica, el área
  (pasajero, chofer, admin o común) y el criterio de aceptación.
- Si no hay CU/RF/RN que la justifique y no es una tarea técnica (entorno, CI, refactor), **no es una tarea**: es
  una propuesta y se consulta al equipo.
- Con `gh`: `gh issue create --title "CU-003: crear reserva (backend)" --label pasajero`.

### 1.2 Verificar antes de hacer

Antes de escribir una línea:

1. `git switch main && git pull` — trabajar siempre sobre lo último.
2. **Buscar si ya existe** (`grep`, o leer la carpeta). No duplicar un modelo, un servicio ni una pantalla.
3. **Leer lo que se va a tocar** y lo que lo usa: el contrato (`openapi.yaml`), el modelo (`schema.sql` y
   `backend/app/models/`), la especificación del CU (v1.3, carpeta 03 del Drive) y el texto de la RN vigente
   (carpeta 02).
4. **Confirmar que es de tu área** (REPARTO). Si hay que tocar código de otro dueño, se abre un Issue para él o
   se le pide permiso. No se arregla "de paso".
5. Si las fuentes no coinciden entre sí (por ejemplo, el contrato pide un campo que el modelo no tiene), **se para
   y se avisa**. No se elige una versión en silencio.

### 1.3 Rama

`<tipo>/<área>-<descripción>-<CU o #issue>`, desde `main` actualizado. Una rama por Issue.

- `feat/pasajero-crear-reserva-cu003`
- `feat/chofer-iniciar-viaje-cu030`
- `fix/admin-confirmar-pago-rn015`
- `chore/comun-ci`

Áreas: `pasajero`, `chofer`, `admin`, `comun` (base compartida), `docs`.

### 1.4 Desarrollo en pasos chicos

- **Un concepto por commit.** Un modelo, un servicio, un endpoint, una pantalla. Si el mensaje necesita un "y",
  son dos commits.
- El código va **con sus pruebas** en la misma rama.
- Nunca: commitear `.env` o claves, commitear directo a `main`, `push --force` sobre una rama compartida, mover o
  borrar tags (`pc1`, `pc1.1`, `pc1.2`).

### 1.5 Checks (antes de cada commit)

| Si tocaste… | Correr | Debe dar |
|---|---|---|
| `backend/` | `ruff check .` · `ruff format --check .` · `pytest` (desde `backend/`) | sin errores |
| `openapi.yaml` | regenerar `openapi.json` (comando en `backend/openapi/README.md`) y validar ambos con `openapi-spec-validator` | válidos y equivalentes |
| modelos o migraciones | `alembic upgrade head` sobre una base limpia, y comparar las tablas con `schema.sql` | lo mismo |
| `frontend/` | `flutter analyze` · `flutter test` | sin errores |

Después, **leer el diff completo** (`git diff --staged`). Si un check no se pudo correr, se dice en el commit y en
el PR. **Nunca se da por bueno algo que no se ejecutó.**

### 1.6 Commit — Conventional Commits

```
<tipo>(<área>): <qué hace, en imperativo>

<por qué: qué CU, RF o RN lo justifica y qué decisión se tomó>

Refs #<issue>
```

Tipos: `feat`, `fix`, `test`, `refactor`, `docs`, `chore`. Ejemplo:

```
feat(pasajero): rechazar la reserva cuando no hay cupo

RN-001: la reserva no puede superar la capacidad de la unidad. El cupo se calcula,
no se guarda (MR-R30). Devuelve 409 con el error uniforme del contrato.

Refs #12
```

Si el commit lo escribió un agente de IA, se agrega su línea `Co-Authored-By:`. Así queda registro de qué se hizo
con ayuda de IA.

### 1.7 Pull Request

- **Un PR por Issue**, chico, con la plantilla completa: qué y por qué, CU/RN, si cambia el contrato o el modelo,
  cómo se probó (comandos y resultado) y capturas si es una pantalla. El cuerpo lleva `Closes #<issue>`.
- **Revisión de otro integrante** antes del merge. Además:
  - si cambia `openapi.yaml` → revisa Martiniano (coherencia del contrato);
  - si cambia modelos, migraciones o `schema.sql` → revisa Martiniano y se le avisa a Martín (dueño del DER);
  - si cambia la base de Flutter (tema, navegación, cliente de API) → revisa Facundo.
  Esas revisiones se piden con `.github/CODEOWNERS`, que le avisa a Martiniano cuando se toca el contrato o el modelo.
- El que revisa **lee el código y corre los checks**, no solo mira el título.
- **El autor mergea su propio PR, después de la revisión.** Quien revisa comenta o aprueba, pero no mergea el PR
  de otro. Mientras no haya un revisor disponible, se pide la revisión igual y el PR queda abierto el tiempo que
  haga falta para que se pueda mirar; no se mergea sin que nadie lo haya visto.
- Se mergea con **"Create a merge commit"** (no squash): conserva cada commit y su CU en el historial.
- Después del merge: borrar la rama, `git switch main && git pull`, y marcar el avance en el tablero de Notion.

### 1.8 Quién decide qué

Para no depender de nadie en lo que es de tu área, y no decidir solo lo que afecta a otros:

| Si la decisión… | La toma | Cómo queda registrada |
|---|---|---|
| es interna de tu área: cómo se implementa algo, qué valida un servicio, cómo se arma una pantalla | **El dueño del área**, sin pedir permiso | En el PR, en una línea |
| cambia el contrato (`openapi.yaml`), el modelo (`schema.sql`, `models/`, migraciones) o toca a otra área | El dueño la **propone en un PR**; la revisa **Martiniano** (y avisa a Martín si toca el DER) | En la revisión del PR |
| afecta una regla de negocio (RN), un caso de uso (CU), un requisito o el DER, es decir, la línea base | **Martín**, como analista, con aviso al equipo | En un Issue de control de cambio |

Si no está claro en cuál de las tres cae, se trata como la segunda. Y si un agente de IA no sabe a quién le toca,
no decide: lo pregunta.

### 1.9 Cómo revisar una propuesta de contrato (checklist)

Cuando una tarea agrega o cambia operaciones de `openapi.yaml`, el revisor contrasta **cuatro fuentes** y no
confía en ninguna sola:

1. **La especificación del CU (v1.3).** ¿Cada operación y cada campo salen de un paso del flujo o de una regla? ¿Se
   inventó algo que la especificación no dice?
2. **`schema.sql`.** ¿Cada campo existe como columna o se calcula de columnas que existen (MR-R30)? ¿Los valores
   coinciden con los `CHECK` (estados, tipos)? ¿Hay columnas privadas que no deberían salir (RN-029: teléfono,
   email, dirección)?
3. **El contrato existente.** ¿Los nombres siguen el estilo (`/pasajeros/me/...`, `/reservas/{id}/cancelacion`)? ¿Se
   reusan los schemas y los errores uniformes? ¿Choca la ruta con la de otra área?
4. **Las reglas que no se reabren** (`REPARTO-PC2.md` §5): QR, pagos, ADJ-03, FIFO.

Y después: ¿el JSON se regeneró y es equivalente al YAML? ¿Quedó marcado `x-cobertura: parcial` lo que no se cubre
entero? ¿Quién puede llamar a cada operación (rol y "solo lo propio")? Lo que no se pueda responder con las fuentes
es un `PENDIENTE DE VALIDACIÓN` en un Issue, no una decisión del PR.

---

## 2. Una sola fuente por dato

La mayoría de los errores del PC1 fueron datos que se desalinearon entre documentos. Regla: **cada dato vive en un
solo lugar, y el resto se deriva de ahí.**

| Dato | Fuente única | Se propaga a | Si hay que cambiarlo |
|---|---|---|---|
| Tablas, columnas, FK, CHECK | `backend/db/schema.sql` = migraciones de Alembic | `backend/app/models/` | PR que cambie `schema.sql`, el modelo y una migración nueva **juntos**, con aviso a Martín (DER) |
| Rutas, campos, códigos de error | `backend/openapi/openapi.yaml` | `openapi.json` (regenerado), routers y schemas Pydantic, DTOs de Flutter | PR al YAML. Agregar se puede; cambiar lo existente requiere acuerdo de los tres |
| Reglas de negocio | Texto de la RN vigente (Drive, carpeta 02) | **Un** servicio en `backend/app/services/` | Control de cambio con Martín |
| Comportamiento de cada CU | Especificación v1.3 (Drive, carpeta 03) | Servicios, pantallas, pruebas | Control de cambio con Martín |
| Identificadores (CU, RF, RN, ACT, MR-R) | La línea base | Commits, Issues, código, pruebas | No se crean ni se renumeran |
| Datos de prueba | `backend/db/seed/` (un solo conjunto) | Base local, pruebas, mocks de Flutter | PR al seed |
| Valores derivados (saldo, deuda, cupo) | Se **calculan** (MR-R30) | — | No se guardan nunca |

Las reglas de negocio se validan en el backend (`services/`), nunca en el frontend ni en el agente. El agente
AG-01 no accede a PostgreSQL: usa los servicios del backend.

---

## 3. Cuándo una tarea está terminada

- [ ] Tiene CU/RF/RN que la justifica (o es técnica y lo dice).
- [ ] Respeta actores y permisos (RN-026 a 030).
- [ ] Las reglas se validan en el backend, en el servicio del dueño del tema.
- [ ] Si cambió la API, el contrato está actualizado y el JSON regenerado.
- [ ] No rompe nada que consuma Flutter o el agente.
- [ ] Tiene pruebas, y los checks del punto 1.5 pasan (o se explica cuál no se pudo correr).
- [ ] Los pendientes quedaron registrados en un Issue.
- [ ] El PR está mergeado y el tablero actualizado.

---

## 4. Si sos un agente de IA

1. **Explicá antes de hacer:** qué archivo vas a tocar, por qué, y qué hace cada parte. Pasos chicos.
2. **Mostrá el diff y esperá el visto bueno** antes de commitear, abrir un PR o mergear.
3. **Explicá cada comando** que corrés. No ejecutes nada destructivo sin confirmación.
4. **Verificá en vez de suponer.** Si no pudiste correr las pruebas, la migración o la app, decilo explícitamente.
5. **No inventes:** ni reglas, ni campos, ni rutas, ni identificadores. Lo que falta es un pendiente.
6. **Quedate en tu área.** Si necesitás algo de otro dueño, proponé un Issue para él.
7. Al cerrar cada tarea, informá: qué quedó hecho, qué se probó y cómo, qué no se pudo verificar y qué sigue.
