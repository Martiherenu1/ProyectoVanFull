# VanFull — Instructivo de instalación, uso y despliegue

**Trabajo de Campo · Proyecto Integrador con IA y Agentes**

Licenciatura en Sistemas | Ingeniería en Informática

**Entrega individual: 20 de noviembre de 2026 · Versión 1.1 (corte del 20/11/2026)**

**Autor de esta entrega:** Martiniano Hereñú

**Equipo del proyecto:** Martín Defez - Martiniano Hereñú - Facundo Barrientos

Repositorio del proyecto: https://github.com/Martiherenu1/ProyectoVanFull

> **Para qué sirve este instructivo.** Explica cómo poner en marcha VanFull en una computadora, cómo se usa cada
> pantalla según el tipo de usuario y cómo está desplegada la demostración pública. Es un entregable aparte del
> documento final de diseño, que lo cita. Parte del `README.md` y de `DESPLIEGUE.md` del repositorio, corregidos con lo que se comprobó
> al redactarlo.

# 1. Qué es y qué se comprobó al escribir esto

VanFull es una plataforma web y móvil para una empresa real de charters, que hoy trabaja con WhatsApp, Excel y
teléfono. Tiene tres partes: una aplicación **Flutter** (la que ve el usuario), un servidor **FastAPI** que decide
las reglas, los permisos, los cupos y los pagos, y una base **PostgreSQL**. El asistente de inteligencia
artificial no toca la base: solo llama herramientas del servidor.

**Qué se comprobó el 19/11/2026 y cómo.** Para no copiar pasos que ya no funcionan:

| Comprobación | Resultado |
|---|---|
| Migraciones sobre una base **vacía**, con el código de `main` del 19/11 (commit `3af0173`, antes de #327) | `alembic upgrade head` terminó sin errores y dejó **35 tablas del modelo** en la revisión `0002` |
| Migraciones y seed con el código de `main` del 20/11 (commit `b95b76f`, con #327) | `alembic upgrade head` subió una base local de la revisión `0001` a la `0004` sin errores, el seed cargó y el servidor respondió `ok`. El modelo declara **36 tablas**; no se volvió a contarlas sobre una base vacía |
| Circuito completo contra la API local con ese código | Crear viaje, reservar, cambiar de parada, pagar y confirmar el pago, iniciar, enviar posición, ver la ubicación, informar una demora, finalizar, historial y tarifas respondieron como se describe más abajo. **El aviso de demora solo se acepta con el viaje en curso.** Se probó el servidor, no las pantallas |
| Carga de datos de prueba (seed) sobre esa base | Carga 6 personas, 5 cuentas, 2 servicios, 1 recorrido con 3 paradas, 2 vehículos y 3 viajes del 30/10/2026. Si se repite, avisa «No se cargó nada» y no duplica |
| Servidor de `main` sobre esa base | `GET /api/health` responde `{"status":"ok","database":"up"}` |
| Demostración pública | La API, el sitio de Render y el respaldo de GitHub Pages respondían con código 200 |

Las comprobaciones locales se hicieron en un PostgreSQL descartable de Docker, sin tocar la base de la demostración.

**Qué no se comprobó.** No se recorrió cada pantalla en un celular real, y la compilación de Flutter la comprueba
la integración continua del repositorio (versión 3.47.7), no este documento. Lo que la aplicación todavía no hace
está en la sección 7 y, caso por caso, en la sección 10 del documento final.

# 2. Requisitos

| Para | Se necesita |
|---|---|
| El servidor y la base | **Docker Desktop** encendido (incluye Docker Compose) y **Git**. El servidor corre en una imagen con Python 3.12 y la base en PostgreSQL 16: no hace falta instalar ninguno de los dos |
| La aplicación Flutter | **Flutter 3.47.7** (la versión que usa la integración continua) y Chrome. Para Android, un emulador o un celular |
| Ver la demostración pública | Solo un navegador |

# 3. Instalación local: servidor y base de datos

Con Docker abierto, desde la raíz del repositorio (en PowerShell o en Bash):

```
git clone https://github.com/Martiherenu1/ProyectoVanFull.git
cd ProyectoVanFull
cp backend/.env.example backend/.env
docker compose up -d --build
docker compose run --rm backend alembic upgrade head
docker compose run --rm backend python -m db.seed.cargar
```

Qué hace cada comando:

| Comando | Qué hace |
|---|---|
| `cp backend/.env.example backend/.env` | Crea el archivo de configuración. **Sin este archivo ningún comando del servidor arranca.** Los valores por defecto sirven para trabajar en local; las claves de integraciones (asistente, Mercado Pago, mapas, WhatsApp) quedan vacías y esas funciones se desactivan |
| `docker compose up -d --build` | Construye y levanta PostgreSQL y el servidor |
| `alembic upgrade head` | Crea las tablas. **El servidor local no migra solo**: hay que correr este comando una vez |
| `python -m db.seed.cargar` | Carga las cuentas y los datos de prueba. Con `--reiniciar` vacía las tablas del seed **y todo lo que dependa de ellas** (incluidas las reservas) y carga de nuevo |

Para comprobar que anda:

- Salud: http://localhost:8000/api/health debe responder `{"status":"ok","database":"up"}`.
- Documentación interactiva del contrato: http://localhost:8000/docs
- Pruebas automáticas del servidor: `docker compose run --rm backend pytest -q`.

El archivo `.env` **nunca se sube al repositorio**.

# 4. Instalación local: aplicación Flutter

Con el servidor levantado:

```
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/api
```

- `API_BASE_URL` incluye el prefijo `/api`. En el emulador de Android el servidor está en `10.0.2.2`:
  `--dart-define=API_BASE_URL=http://10.0.2.2:8000/api`.
- Control de calidad, los mismos que corre la integración continua: `flutter analyze` y `flutter test`.
- **Pagos con Mercado Pago:** la pantalla de pago con Checkout está **apagada por defecto**
  (`CHECKOUT_MP_ENABLED=false`). Los pagos por transferencia y billetera se confirman a mano desde Administración.
- **Mapa de la última posición:** necesita claves de Google Maps que no están en el repositorio. Sin ellas la
  pantalla muestra la última posición en texto.
- Ningún proceso automático compila la aplicación para Android (APK): se compila a mano.

# 5. Cuentas de prueba

Todas son ficticias (dominio `@vanfull.test`). Se inicia sesión con el correo y la contraseña.

| Cuenta | Rol | Qué ve |
|---|---|---|
| `pasajero1@vanfull.test`, `pasajero2@vanfull.test` | Pasajero | Buscar servicio, reservar, mis reservas, pagos, comprobantes, perfil, asistente |
| `chofer1@vanfull.test` | Chofer | Sus viajes asignados, detalle, avisos de demora, ubicación |
| `admin1@vanfull.test` | Administrador | Viajes, recorridos, choferes, vehículos, pagos, deuda, reservas, abonos |
| `dueno1@vanfull.test` | Dueño | Lo del administrador más tarifas y administradores |

Dónde están las contraseñas:

- **En local:** en `backend/db/seed/contrasenas-de-prueba.csv`. El repositorio es público, así que esas contraseñas
  **solo sirven para una base local**: el cargador se niega a usarlas contra una base remota.
- **En la demostración pública:** son otras, generadas al azar y guardadas fuera del repositorio. **No figuran en
  este documento**; se entregan por un canal privado.
- Hay un segundo chofer («Chofer Dos») **sin cuenta de acceso**: existe para probar la reasignación de choferes.
- La cuenta `dueno1` **no existe en la base de la demostración pública**; sin ella no se pueden mostrar tarifas ni
  administradores en la demo remota. Se crea desde la terminal del responsable y con acuerdo del equipo, nunca por chat.

# 6. Cómo se usa

La aplicación es una sola. **El rol lo define la cuenta con la que se inicia sesión** y cada rol entra a su
pantalla inicial.

## 6.1 Pasajero

| Pantalla | Para qué sirve |
|---|---|
| Buscar servicio | Elegir una fecha, ver los viajes con lugar y las paradas del recorrido |
| Confirmar reserva | Reservar el viaje elegido marcando la parada de ascenso y, si administración habilitó descensos para ese viaje, **«Elegí dónde bajás»** (una parada posterior al ascenso) |
| Mis reservas | Ver las reservas y el saldo, cancelar, cambiar de parada e informar una ausencia |
| Pago y comprobantes | Ver la deuda, pagar y consultar los comprobantes |
| Ubicación | Con el viaje en curso, ver la última posición del vehículo y el **tiempo estimado de llegada** a la parada de ascenso y al descenso elegido, o «No disponible» |
| Asistente | Preguntar en lenguaje natural, por ejemplo «¿Hay lugar para ir el viernes a la ida?» |
| Perfil | Ver y editar correo, teléfono y dirección |

## 6.2 Chofer

| Pantalla | Para qué sirve |
|---|---|
| Mis viajes | Elegir una fecha (por defecto, hoy) y ver los viajes que le asignaron |
| Detalle del viaje | Ver los pasajeros con reserva, **iniciar** el viaje (con permiso de ubicación, para publicar su posición), **confirmar el paso por cada parada**, **finalizarlo** e **informar una demora o un problema** (solo con el viaje en curso) |

## 6.3 Administrador y dueño

| Pantalla | Para qué sirve |
|---|---|
| Viajes del día | Elegir una fecha y ver sus viajes, con el vehículo y el chofer de cada uno. Al abrir un viaje se puede **editarlo** (incluye asignar o cambiar chofer y vehículo) o **cancelarlo** si está programado. También **«Configurar descensos»**: marcar las paradas de bajada habilitadas para ese viaje |
| Crear viaje | Dar de alta un viaje: servicio, recorrido, fecha, sentido y, si se quiere, vehículo, chofer, horario y capacidad |
| Recorridos | Crear recorridos y editar sus paradas |
| Choferes y Vehículos | Registrar, listar, consultar y modificar |
| Registrar pago, Pagos pendientes y Deuda | Registrar un pago, confirmar o rechazar los que esperan confirmación y consultar la deuda de un cliente |
| Reservas | Consultar las reservas de un viaje |
| Abonos | Gestionar abonos mensuales |
| Historial de viajes | Consultar los viajes finalizados y cancelados |
| Tarifas y Administradores | Solo el dueño |

## 6.4 Un recorrido de prueba de punta a punta

Los viajes que trae el seed son del **30/10/2026**, que ya pasó. Para probar hay que crear uno nuevo:

1. Entrar como `admin1@vanfull.test` → **Crear viaje**. Con los datos del seed: servicio `1`, recorrido `1`,
   vehículo `1` y chofer `3` (el chofer `chofer1` es la persona 3), una fecha futura y sentido de ida. Opcional: abrir
   el viaje en **Viajes del día** → **Configurar descensos** y marcar paradas de bajada; sin eso el pasajero no ve
   «Elegí dónde bajás».
2. Entrar como `pasajero1@vanfull.test` → **Buscar servicio**, elegir esa fecha, elegir el viaje y la parada, y
   **confirmar la reserva**.
3. En **Mis reservas** aparece la reserva. Se puede cambiar la parada o cancelarla.
4. Entrar como `chofer1@vanfull.test`, elegir en **Mis viajes** la fecha del viaje creado y abrir el detalle: el
   pasajero figura entre los pasajeros con reserva.
5. Volver como administrador: **Viajes del día** muestra el viaje, **Reservas** la reserva y **Registrar pago**
   permite cargar un pago.

# 7. Qué todavía no hace

Para que nadie espere más de lo que hay:

| Tema | Estado |
|---|---|
| **Abordaje por código QR** (CU-007) | No está implementado: la operación existe en el contrato pero no tiene ruta |
| **Tiempo estimado de llegada** (CU-009) | Integrado con #327. Lo calcula Google Routes y necesita la clave `GOOGLE_ROUTES_API_KEY` en el servidor y paradas con coordenadas: en una instalación local sin la clave, o con el seed (que no trae coordenadas), responde «sin dato». La aceptación integral de RNF-008 sigue pendiente |
| **Notificaciones** (WhatsApp o aviso en el teléfono) | No se envían. Un aviso del chofer queda registrado, sin notificar a nadie |
| **Tarifas y deuda** | La reserva no calcula la tarifa ni genera deuda, porque las reglas de cálculo no están cerradas |
| **Mercado Pago** | Solo en entorno de pruebas y apagado por defecto. «Confirmar» no está disponible para pagos de Mercado Pago: los confirma el proveedor |
| **Asistente** | Sin clave de OpenRouter deriva a una persona (probado). Con clave, no se verificó para esta entrega ni se midió con los modelos actuales |

Ninguna regla se inventó para completar estos casos: lo que no está aprobado figura como pendiente. El detalle de
los 37 casos de uso está en la sección 10 del documento final.

# 8. Despliegue de la demostración pública

```
Navegador ──► Render, sitio estático (Flutter Web) ──HTTPS──► Render (FastAPI) ──TLS──► Neon (PostgreSQL)
              vanfull.onrender.com                              vanfull-api.onrender.com/api

Respaldo: el mismo Flutter Web en GitHub Pages (martiherenu1.github.io/ProyectoVanFull/).
```

| Servicio | Dirección |
|---|---|
| Sitio (la URL de la demostración) | https://vanfull.onrender.com |
| API, estado de salud | https://vanfull-api.onrender.com/api/health |
| Respaldo del sitio | https://martiherenu1.github.io/ProyectoVanFull/ |

**Nada secreto vive en el repositorio.** Los secretos los carga a mano quien despliega, en cada servicio. En la
tabla, *secreto* significa que no va al chat, ni a un commit, ni a un Issue.

| Dónde | Qué | Valor |
|---|---|---|
| Render (panel) | `DATABASE_URL` | **Secreto.** La cadena **directa** de Neon, tal cual la da el panel |
| Render (panel) | `OPENROUTER_API_KEY` | **Secreto**, opcional. Sin ella el asistente deriva a una persona |
| Render (panel) | `GOOGLE_ROUTES_API_KEY` | **Secreto**, opcional. Clave de Google Cloud con Routes API habilitada. Sin ella el tiempo estimado queda «sin dato». **No figura en `render.yaml`: se carga a mano en el panel** |
| Render (`render.yaml`) | `JWT_SECRET` | Lo genera Render; nadie lo ve ni lo copia |
| Render (`render.yaml`) | `ENV`, `API_PREFIX`, `CORS_ORIGINS` | Públicos. `CORS_ORIGINS` lista los dos orígenes del sitio |
| GitHub → Settings → Secrets and variables → Actions → **Variables** | `API_BASE_URL` | `https://<servicio>.onrender.com/api` (público: queda en el JavaScript) |
| Ídem | `VANFULL_MAPS_WEB_KEY`, `VANFULL_MAPS_WEB_MAP_ID` | Opcionales, para el mapa. La clave web **queda en el JavaScript publicado**: la protege su restricción por origen en Google Cloud |
| Tu computadora, fuera del repositorio | `contrasenas-demo.csv` | **Secreto.** Las contraseñas de las cuentas de la demostración |

## 8.1 Base en Neon

1. Crear el proyecto en Neon, región **AWS us-east-2 (Ohio)**, la misma que Render.
2. En *Connect*, **desactivar «Connection pooling»** y copiar la cadena directa (el servidor **no** termina en
   `-pooler`). El pooler rompe las sentencias preparadas del controlador asíncrono. La cadena se pega tal cual, sin
   editarla.

## 8.2 Datos de la demostración

El repositorio es público, así que el cargador **no usa las contraseñas del repositorio contra una base remota**:
exige un archivo de contraseñas guardado **fuera** del repositorio. En PowerShell, desde la raíz y con Docker abierto:

```
cd backend
& "$env:LOCALAPPDATA\Programs\Python\Python313\python.exe" -m db.seed.generar_contrasenas "$HOME\VanFull-secretos\contrasenas-demo.csv"
cd ..
$env:DATABASE_URL = Read-Host "Cadena directa de Neon"
docker compose run --rm --no-deps -e DATABASE_URL -v "$HOME\VanFull-secretos:/secretos:ro" backend sh -c "alembic upgrade head && python -m db.seed.cargar --permitir-base-remota --contrasenas /secretos/contrasenas-demo.csv"
Remove-Item Env:DATABASE_URL
```

La cadena de Neon se escribe en la terminal y no se guarda en ningún archivo. El generador no imprime las
contraseñas y no pisa un archivo existente: guardar el CSV en un gestor de contraseñas y pasarlo al equipo por un
canal privado. **No usar este procedimiento para reinicializar la base de la demostración ya en uso**: con
`--reiniciar` se pierden las reservas.

## 8.3 API en Render

1. Render → *New* → *Blueprint* → este repositorio. Toma `render.yaml` de la raíz.
2. Pide `DATABASE_URL` y `OPENROUTER_API_KEY`: pegarlos ahí.
3. El servicio arranca con `backend/arrancar.sh`: corre `alembic upgrade head` y después el servidor. El plan
   gratuito no tiene consola ni tareas programadas, por eso **la migración corre en cada arranque**. Si una
   migración falla, la API no arranca.
4. Comprobar `https://<servicio>.onrender.com/api/health`.
5. Después, Render redespliega solo cuando la integración continua de `main` pasa y cambió algo bajo `backend/`.

Si falta `CORS_ORIGINS`, o `JWT_SECRET` es corto, la API **no arranca** y el registro de Render lo dice.

## 8.4 Aplicación web: Render y GitHub Pages

Flutter **no se compila en Render**: lo compila el workflow **Web** de GitHub Actions y lo publica en la rama
`sitio-web`, que Render sirve tal cual. GitHub Pages queda de respaldo.

1. Settings → Pages → Source: **GitHub Actions**.
2. Settings → Secrets and variables → Actions → *Variables* → `API_BASE_URL` con la URL de la API terminada en `/api`.
3. Actions → **Web** → *Run workflow* (rama `main`). Si la variable falta o no es `https://…/api`, el workflow corta
   antes de compilar.
4. Solo la primera vez: en Render, el Blueprint → *Manual sync* para crear el sitio estático.

**Para publicar cambios del frontend hay que volver a correr el workflow: no se publica solo.**

## 8.5 Antes de una demostración

Hacerlo con un celular con datos móviles, no con el wifi de casa, para que nada dependa de la red local.

1. **Despertar la API cinco minutos antes.** El plan gratuito se duerme a los 15 minutos de inactividad y tarda
   alrededor de un minuto en volver. Abrir `…/api/health` hasta que responda `"database":"up"`.
2. Abrir el sitio, entrar con una contraseña incorrecta (debe mostrar el mensaje) y después con una cuenta válida.
3. Cada mensaje al asistente gasta de 2 a 3 de los 50 pedidos diarios del plan gratuito del modelo.

| Síntoma | Causa probable |
|---|---|
| `…/api/health` no responde en más de 2 minutos | Revisar el registro de Render: la migración falló o falta una variable |
| `"database":"down"` | `DATABASE_URL` mal copiada, o es la cadena con pooler |
| La API anda pero la aplicación no se conecta | CORS: `CORS_ORIGINS` debe incluir exactamente el origen del sitio, sin barra ni ruta; o `API_BASE_URL` sin `/api` (volver a correr el workflow) |
| Página en blanco o 404 en los recursos | En Pages: Pages no está en «GitHub Actions». En Render: la rama `sitio-web` no existe o está vacía (correr **Web**) |
| El inicio de sesión da 401 con la contraseña correcta | La base no se sembró con ese archivo de contraseñas |
| El asistente siempre deriva a una persona | Falta la clave, o el modelo falló: buscar `AG-01:` en el registro de Render |

# 9. Cambiar la base de datos con cuidado

La base de la demostración tiene datos reales de prueba y **no se debe tocar sin acuerdo de los tres integrantes**.
Antes de integrar un cambio que lleve una migración:

1. **Respaldo verificado.** Volcar la base con `pg_dump` (solo lee), restaurarla en una base local descartable y
   comparar las filas por tabla y la revisión de Alembic. El volcado contiene datos de personas: se guarda fuera
   del repositorio y de las carpetas sincronizadas. El procedimiento está automatizado en
   `Documentos/Entrega-Final/respaldo-neon.ps1`.
2. **Ensayo sobre la copia.** Aplicar y deshacer las migraciones sobre la copia restaurada y comprobar que, al volver,
   el esquema y los datos quedan idénticos.
3. **Ventana acordada** entre los tres: nadie más integra a `main` ni toca la base durante ese rato.

**Cómo volver atrás.** El orden importa: una imagen anterior del servidor **no conoce** una revisión nueva y, si la
base ya la tiene, la API no arranca. Por eso hay que **bajar primero la base** (`alembic downgrade` a la revisión
anterior, con el código que tiene la migración) y **recién después** volver el servicio de Render. Bajar una
migración puede borrar datos registrados desde el despliegue. El script
`Documentos/Entrega-Final/bajar-neon-a-0002.ps1` hace este paso con un volcado de seguridad previo y una
confirmación escrita.

Estado de la base al 20/11/2026: **no se verificó**. #327 se integró a `main` el 19/11 a las 22:59 (revisiones 0003 y
0004 y una tabla más: 36 tablas del modelo) y el servidor migra al arrancar, así que Neon probablemente está en la
revisión **0004**. Para comprobarlo: `select version_num from alembic_version;`. Si está en `0004`, el script
`bajar-neon-a-0002.ps1` sigue siendo la vuelta atrás; si ya estuviera en `0002`, avisa que no hay nada que bajar.
