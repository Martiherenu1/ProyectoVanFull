# Despliegue de la demo

Demo del 30/10/2026 (freeze el 25/10). Issue #116.

```
Navegador ──► Render, sitio estático (Flutter Web) ──HTTPS──► Render (FastAPI) ──TLS──► Neon (PostgreSQL)
              vanfull.onrender.com                              vanfull-api.onrender.com/api

Respaldo: el mismo Flutter Web en GitHub Pages (martiherenu1.github.io/ProyectoVanFull/).
```

Nada secreto vive en el repositorio. Los secretos los carga a mano quien despliega, en cada servicio.
En la tabla, **secreto** quiere decir que no va al chat, ni a un commit, ni a un issue.

| Dónde | Qué | Valor |
|---|---|---|
| Render (panel) | `DATABASE_URL` | **secreto**: la cadena **directa** de Neon, tal cual la da el panel |
| Render (panel) | `OPENROUTER_API_KEY` | **secreto**, opcional: sin ella, el asistente deriva a una persona |
| Render (panel) | `OPENROUTER_MODEL_PRIMARY`, `OPENROUTER_MODEL_FALLBACK` | públicos. Opcionales: los valores por defecto del repo son los de la demo (`nvidia/nemotron-3-ultra-550b-a55b:free` y `nvidia/nemotron-3.5-lightning:free`, `CONTEXTO.md` §13) |
| Render (`render.yaml`) | `JWT_SECRET` | lo genera Render (`generateValue`); nadie lo ve ni lo copia |
| Render (`render.yaml`) | `ENV=production`, `API_PREFIX=/api`, `CORS_ORIGINS=https://vanfull.onrender.com,https://martiherenu1.github.io` | públicos |
| GitHub → Settings → Secrets and variables → Actions → **Variables** | `API_BASE_URL` | `https://<servicio>.onrender.com/api` (público: queda en el JS) |
| GitHub → Settings → Pages | Source | «GitHub Actions» |
| Tu computadora, **fuera del repo** | `contrasenas-demo.csv` | **secreto**: las contraseñas de las cuentas de la demo |

## 1. Base en Neon

1. Crear el proyecto en Neon, región **AWS us-east-2 (Ohio)**, la misma que Render.
2. En *Connect*, **desactivar «Connection pooling»** y copiar la cadena directa (el host **no** termina en
   `-pooler`). El pooler de Neon es PgBouncer en modo transacción y rompe las sentencias preparadas de
   asyncpg. La cadena trae `?sslmode=require&channel_binding=require`: se pega así, sin editarla. La
   configuración la adapta para asyncpg (`app/core/config.py`).

## 2. Datos de la demo

El seed **no carga las contraseñas del repositorio en una base remota**: el repositorio es público. Con
`--permitir-base-remota`, el cargador exige además un archivo de contraseñas que esté **fuera** del repo.

En PowerShell, desde la raíz del repo y con Docker abierto:

```powershell
# a) Contraseñas nuevas y aleatorias, fuera del repo. Solo usa la biblioteca estándar (no hace falta Docker).
cd backend
& "$env:LOCALAPPDATA\Programs\Python\Python313\python.exe" -m db.seed.generar_contrasenas "$HOME\VanFull-secretos\contrasenas-demo.csv"
cd ..

# b) Migrar y sembrar Neon. La cadena se escribe en la terminal, no se guarda en ningún archivo.
$env:DATABASE_URL = Read-Host "Cadena directa de Neon"
docker compose run --rm --no-deps -e DATABASE_URL -v "$HOME\VanFull-secretos:/secretos:ro" backend sh -c "alembic upgrade head && python -m db.seed.cargar --permitir-base-remota --contrasenas /secretos/contrasenas-demo.csv"
Remove-Item Env:DATABASE_URL
```

- El generador no imprime las contraseñas y no pisa un archivo existente. Guardá el CSV en tu gestor de
  contraseñas y pasáselo al equipo por un canal privado, nunca por el chat ni por el repo.
- Qué se carga: las 4 cuentas ficticias (`pasajero1`, `pasajero2`, `chofer1` y `admin1`, todas
  `@vanfull.test`), los 2 servicios y el recorrido con 3 paradas. **Los viajes del 30/10 llegan con el PR
  #101** (Facundo). Hasta que entre, no hay nada para reservar.
- Para volver al estado inicial, por ejemplo después del ensayo o cuando entre #101: el mismo comando con
  `--reiniciar`. Eso vacía las tablas del seed **y todo lo que dependa de ellas**, incluidas las reservas.

## 3. API en Render

1. Render → *New* → *Blueprint* → este repositorio. Toma `render.yaml` de la raíz.
2. Pide `DATABASE_URL` y `OPENROUTER_API_KEY` (`sync: false`): pegarlos ahí. El primer deploy tarda
   varios minutos.
3. El servicio arranca con `backend/arrancar.sh`: `alembic upgrade head` y después uvicorn. El plan free no tiene shell ni jobs, por
   eso la migración corre en cada arranque. Si la base ya está en head no hace nada; si una migración
   falla, la API no arranca.
4. Comprobar `https://<servicio>.onrender.com/api/health` → `{"status":"ok","database":"up"}`.
5. Después, Render redespliega solo cuando la CI de `main` pasa y cambió algo bajo `backend/`.

Si falta `CORS_ORIGINS`, o `JWT_SECRET` es corto, la API **no arranca**, y el log de Render lo dice.

## 4. Flutter Web: Render (la URL de la demo) y Pages (respaldo)

La URL de la demo es la de Render, que no muestra el usuario de GitHub. Flutter **no se compila en
Render**: lo compila el workflow **Web** de GitHub Actions, con la misma versión que la CI. El sitio de
Render sale de la rama `sitio-web`, que escribe solo ese workflow (un commit, reemplazado en cada
corrida); Render la sirve tal cual. Pages queda de respaldo.

1. Settings → Pages → Source: **GitHub Actions**.
2. Settings → Secrets and variables → Actions → *Variables* → `API_BASE_URL` = la URL del paso 3 con `/api`.
3. Actions → **Web** → *Run workflow* (rama `main`). Si la variable falta o no es `https://…/api`,
   el workflow corta antes de compilar. Publica las dos cosas: la rama `sitio-web` y Pages
   (`https://martiherenu1.github.io/ProyectoVanFull/`).
4. **Solo la primera vez:** en Render, Blueprint `vanfull-demo` → **Manual sync**. Crea el sitio
   estático `vanfull` (necesita que la rama `sitio-web` ya exista, por eso va después del paso 3). Si
   Render le agrega un sufijo a la URL porque el nombre estaba tomado, corregir `CORS_ORIGINS` en
   `render.yaml`.
5. Después, cada corrida de **Web** redespliega el sitio de Render sola (`autoDeployTrigger: commit`).

Para publicar cambios del frontend, volver a correr el workflow: no se publica solo.

## Ensayo desde otro dispositivo

Hacerlo con un celular **con datos móviles, no con el wifi de casa**, para que nada dependa de la red local.

1. Despertar la API: el plan free se duerme a los 15 minutos y tarda alrededor de un minuto en volver.
   Abrir `…/api/health` hasta que responda `"database":"up"`. **Hacerlo 5 minutos antes de la demo.**
2. Abrir `https://vanfull.onrender.com` (o el respaldo, `https://martiherenu1.github.io/ProyectoVanFull/`).
3. Entrar con una contraseña incorrecta: tiene que mostrar el mensaje. Después, con `pasajero1` y su
   contraseña del CSV.
4. Buscar el 30/10 → elegir el viaje → marcar la parada → confirmar (necesita #101).
5. Mis reservas: aparece la reserva y el saldo. Cancelar: aparece cancelada, con su motivo.
6. Asistente: «¿Hay lugar para ir el viernes 30/10 a la ida?». Tiene que listar los viajes. Si responde que te
   deriva a una persona, ver la tabla de abajo. Cada mensaje gasta 2 o 3 de los 50 pedidos diarios del plan gratis.
7. Cerrar sesión. Recargar la página: vuelve al login (el token no se persiste).
8. Al terminar, resembrar con `--reiniciar` (paso 2) para que la demo arranque limpia.

| Síntoma | Causa probable |
|---|---|
| `…/api/health` no responde en más de 2 minutos | Revisar el log de Render: la migración falló o falta una variable |
| `"database":"down"` | `DATABASE_URL` mal copiada, o es la cadena `-pooler` |
| Health anda, pero la app dice que no pudo conectarse | CORS: `CORS_ORIGINS` tiene que incluir exactamente el origen del sitio (`https://vanfull.onrender.com`), sin barra ni ruta; o `API_BASE_URL` sin `/api` (correr de nuevo el workflow) |
| Página en blanco o 404 en los recursos | En Pages: el workflow no usó `--base-href /ProyectoVanFull/`, o Pages no está en «GitHub Actions». En Render: la rama `sitio-web` no existe o está vacía (correr **Web**) |
| Login correcto con el CSV da 401 | La base no se sembró con ese CSV: repetir el paso 2 con `--reiniciar` |
| El asistente siempre deriva a una persona | Buscar `AG-01:` en el log de Render: dice qué modelo falló y por qué (falta la clave, 401, 404 del modelo, 429 por el límite diario) |
