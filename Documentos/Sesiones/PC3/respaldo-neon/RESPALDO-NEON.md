# Respaldo de Neon y ensayo de la migración 0002 (#281) — paso a paso

> Lo ejecuta Martiniano (se ofreció a hacer el respaldo de Neon, 16/11/2026). Cumple la condición de
> Martín para mergear #281: «respaldo actual de Neon con restauración aislada probada y ventana acordada»
> (pasos 2 a 5 de su `PC3/ENTREGA-MANUAL-CU030-280.md`, en la rama de #281). Este documento **no autoriza
> el merge**: solo produce la evidencia.
>
> **Dónde vive:** `Documentos/Sesiones/PC3/respaldo-neon/`, a propósito **fuera de `backend/`**. Render
> redespliega cuando cambia algo bajo `backend/**` y cada arranque corre `alembic upgrade head`; un PR de
> documentación bajo `backend/` abriría un despliegue en plena ventana.

## Qué hace y qué no hace

| Hace | No hace |
|---|---|
| Lee Neon (solo lectura) y saca un `pg_dump` completo en formato custom | **No escribe nada en Neon**: ningún script usa `psql` para modificar, ni `alembic`, ni seed, ni `stamp` |
| Restaura ese archivo **completo** en una base local aislada y lo compara con Neon (filas, hash de cada tabla, secuencias, columnas, índices, PK/FK/UNIQUE) | No prueba el comportamiento de CU-030 en la API (altas, recuperación, permisos): es otra prueba |
| Ensaya `0001 → 0002` **solo sobre la copia** con el código exacto de #281, y verifica que los históricos de `evento_operativo` no cambian | No recrea roles ni privilegios de Neon (se restaura con `--no-owner --no-privileges`, como pide Martín); no cubre objetos globales |
| Deja un registro con hora, SHA-256, tamaño y SHA del código, sin la cadena de conexión | No decide si se mergea ni cuándo; no borra el respaldo |

## Orden

`A` preparar → `B` cerrar la ventana → `C` respaldar → `D` restaurar aislado → `E` ensayar 0002 → `F` cerrar.
Los pasos C, D y E van seguidos, **dentro de la ventana**. A y los chequeos de solo lectura se pueden hacer antes.

---

## A. Preparación (antes de la ventana, sin riesgo)

**A1. Requisitos de tu máquina**

- Docker Desktop **abierto** (el motor tiene que estar andando: `docker info`).
- **PowerShell** común (no Git Bash: Git Bash convierte las rutas que empiezan con `/`).
- La imagen del backend: `docker image ls proyectovanfull-backend`. Si no está:
  `docker compose build backend` desde la raíz del repo.
- Espacio: la imagen `postgres:<mayor>` pesa unos 650 MB la primera vez; la base de la demo es chica.
- Tu Postgres de desarrollo (el de `docker compose`, puerto 5432) **no se toca**: la copia usa otro
  contenedor, otra red y otro volumen.

**A2. La cadena de Neon (la DIRECTA)**

- Neon → *Connect* → **desactivar «Connection pooling»** → copiar la cadena. El host **no** termina en
  `-pooler` (DESPLIEGUE.md §1). Los scripts se niegan a correr con la del pooler.
- Los scripts te la piden **sin mostrarla** al pegarla y solo viven en esa ventana de PowerShell. No va al
  chat, ni a un archivo, ni a un `.env`.
- **Comprobá que es la base correcta:** en Render → `vanfull-api` → Environment, mirá **solo el host**
  de `DATABASE_URL` (lo que está entre `@` y `/`). Tiene que ser el mismo que figure como `Origen (host)` en
  el registro del paso C. Si el proyecto de Neon tiene más de una rama o base, este es el chequeo que evita
  respaldar la equivocada.

**A3. Paso 1: estado de Neon (solo lectura)**

```powershell
cd "C:\Users\marti\OneDrive\Escritorio\Facultad\2026\2DO CUATRI\Trabajo de campo\ProyectoVanFull\Documentos\Sesiones\PC3\respaldo-neon"
git fetch origin
powershell -NoProfile -ExecutionPolicy Bypass -File .\01-estado.ps1
```

`-ExecutionPolicy Bypass` vale solo para ese proceso: no cambia la configuración de tu Windows.

Tiene que terminar así:

```
OK  alembic_version = 0001 (una sola revision, la esperada).
Version mayor de PostgreSQL en Neon: NN  ->  usar  -Pg NN  en los pasos 2 y 3.
OK  Ninguna otra conexion a la base en este momento.
```

**Anotá el `NN`**: es el `-Pg` de los pasos siguientes. `pg_dump` no puede ser más viejo que el servidor, y la
copia tiene que ser de la misma versión mayor.

| Si ves… | Hacé |
|---|---|
| `NO  alembic_version = [...]` distinto de 0001 | **Detenerte.** No usar `stamp`. Avisar a Martín y a Facundo: Neon no está donde #281 supone |
| `ATENCION  Hay N conexion(es) mas` | La ventana todavía no está cerrada: ver B. Cada fila dice desde dónde y desde cuándo |
| No conecta | Primera conexión con Neon dormido: repetir. Si sigue, revisar que sea la cadena directa y la red |

---

## B. Cerrar la ventana

Los escritores posibles de Neon son: la API de Render (`vanfull-api`) y todo lo que le pegue (el sitio
`vanfull.onrender.com`, la APK de Martín, la PC de Martín o de Facundo apuntando a Render, los scripts de
verificación) y cualquier seed o migración que alguien corra con la cadena.

1. **Acordar y anotar** en el chat de los tres: hora de inicio y de fin. *Estimación mía, no medida:* con
   la base de la demo, C+D+E son pocos minutos más la descarga de la imagen de PostgreSQL la primera vez;
   pedí media hora y te sobra.
2. **Avisar a Martín y a Facundo:** durante la ventana nadie abre la app ni el sitio, ni corre scripts
   contra Render, ni mergea nada a `main`.
3. **Render → `vanfull-api` → Events:** que no haya un deploy en curso ni en cola.
4. **Opcional y más fuerte (no verificado):** suspender `vanfull-api` en el panel durante la ventana y
   reanudarla al final. No lo probé: antes de usarlo, confirmá en el panel qué hace con los deploys
   automáticos, y anotá la hora de suspensión y de reanudación. Reanudar arranca `arrancar.sh`, que corre
   `alembic upgrade head`: con `main` actual (solo 0001) no cambia nada.
5. **La prueba objetiva no es esta lista, es el paso C:** el script compara el manifiesto de Neon justo
   antes y justo después del `pg_dump`. Si alguien escribió, lo dice.

---

## C. Respaldo (paso 2)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\02-respaldar.ps1 -Pg NN
```

(Reemplazá `NN` por el número del paso A3.) Pide la cadena. Hace cinco cosas y las muestra numeradas:
manifiesto de Neon antes → `pg_dump` → manifiesto después → compara → hash y lectura del archivo.

Guarda en `%LOCALAPPDATA%\VanFullBackups` (carpeta **fuera de OneDrive y del repo**, solo con tu usuario;
el script se niega a usar una dentro de OneDrive):

- `neon-pre-0002-<fecha>.dump` — el respaldo
- `registro-<fecha>.txt` — hora, host (sin usuario ni contraseña), versión, **SHA-256**, tamaño, SHA del código
- `verificacion\origen-antes.txt` y `origen-despues.txt`

Tiene que terminar con `OK  Neon no cambio mientras se respaldaba.` y `Neon sin cambios durante el
respaldo: True`.

| Si ves… | Significa | Hacé |
|---|---|---|
| `El servidor es PostgreSQL X y se pidio -Pg Y` | Versión equivocada | Repetir con `-Pg X` |
| `pg_dump fallo` | El archivo está incompleto | No usarlo; pegame el mensaje |
| `NO  Neon CAMBIO durante el respaldo` | Hay un escritor activo | Cerrar la ventana de verdad y repetir. El archivo es consistente, pero no es un respaldo en ventana |
| `pg_restore --list no pudo leer` | Archivo ilegible | No usarlo |

**Guardá el SHA-256 y no borres el archivo** (la retención es decisión del equipo).

---

## D. Restauración aislada (paso 3)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\03-restaurar-aislado.ps1 -Pg NN
```

No usa la cadena de Neon. Toma el último `.dump`, **verifica que su SHA-256 siga siendo el del registro**,
y crea `vanfull-restore` en la red `vanfull-restore-net` (`--internal`, sin salida a internet), sin ningún
puerto publicado y con un volumen nuevo. **Antes de restaurar comprueba el aislamiento** y se niega si no se
cumple:

```
red interna (sin internet) : true   (se espera true)
puertos publicados al host : 0      (se espera 0)
redes del contenedor       : vanfull-restore-net
objetos en la base destino : 0      (se espera 0: base vacia)
```

Después corre `pg_restore --exit-on-error --single-transaction --no-owner --no-privileges` (completo, sin
`--clean` ni `--create`, como pide Martín) y compara la copia con Neon. Tiene que terminar con:

```
OK  La copia es identica a Neon en: version, alembic, extensiones, filas y hash de CADA tabla, ...
```

- **Si `pg_restore` falla** (por ejemplo, por una extensión que Neon tiene y la imagen de PostgreSQL no),
  el script se detiene en el primer error: **copiá el mensaje exacto**. No lo fuerces ni saques
  `--exit-on-error`. Es justo lo que este paso debe descubrir.
- **Límite de la comparación:** de los `CHECK` se comparan tabla, nombre y validación, **no el texto** de la
  expresión, porque PostgreSQL lo re-escribe al restaurar (`ANY (ARRAY[...])` pasa a
  `ANY ((ARRAY[...])::text[])`, mismo significado). Lo vimos en el ensayo y comparar el texto daba un falso
  «difiere». PK, FK y UNIQUE sí se comparan con su definición completa.

---

## E. Ensayo de 0002 sobre la copia (paso 4)

El `<SHA>` es el HEAD de #281. Si hoy no cambió, es `6656794b7cd1e1d4d1be9f8d707cbbbe63ea9827`; el script
compara contra el HEAD actual de #281 en GitHub y avisa si no coincide.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\04-ensayo-0002.ps1 -Commit <SHA>
```

Este paso **no usa Neon** y no te pide la cadena: si en esa ventana de PowerShell tuvieras definida
`NEON_URL`, el script se niega a correr (con `-File`, cada script es un proceso aparte y no pasa). Corre el código de ese commit en un checkout
aparte, dentro de la carpeta de respaldos, en un contenedor dentro de la red interna de la copia y **sin ningún
`.env`**: no puede llegar a Neon aunque quisiera. Ejecuta `alembic current → heads → history → upgrade 0002 →
current → check → upgrade 0002 (repetida) → current` y después compara la copia antes y después.

Veredicto esperado:

```
OK  Historicos de evento_operativo intactos y con metadatos NULL: ...
OK  Las N lineas que cambiaron del manifiesto son todas de evento_operativo y alembic_version.
OK  columna id_cuenta_autora (bigint, nullable)
OK  columna clave_solicitud (uuid, nullable)
OK  FK evento_operativo_id_cuenta_autora_fkey (validada)
OK  UNIQUE uq_aviso_solicitud (autora, viaje, clave)
OK  CHECK ck_aviso_metadatos (validada)
OK  alembic_version = 0002
ENSAYO DE 0002 SOBRE LA COPIA: APROBADO.
```

Leé también la definición del CHECK que imprime al final y cotejala con `schema.sql` y con `0002`.
Si algo dice `NO`, **#281 no se mergea**: guardá la salida completa.

---

## F. Cierre

1. **Limpiar la copia** (no toca Neon ni el respaldo):

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\05-limpiar.ps1
   ```

2. **Reanudar** `vanfull-api` si la suspendiste, y anotar la hora. Cerrar la ventana en el chat.
3. **Qué publicar en #281** (sin datos, sin la cadena, sin el `.dump`, sin los `.txt` de `verificacion\`,
   que tienen hashes de datos reales): fecha y hora de la ventana; versión de PostgreSQL de Neon;
   `alembic_version` = 0001; **SHA-256** y tamaño del respaldo; «restauración completa sin errores, copia
   idéntica (con el límite de los CHECK)»; SHA de #281 ensayado y el veredicto del paso E; que el respaldo
   queda custodiado fuera de OneDrive.
4. **Vigencia:** el respaldo vale para el estado de Neon de esa ventana. Si después se escribe en Neon, si
   cambia el HEAD de #281 o si pasa mucho tiempo, hay que repetir C, D y E antes del merge (Martín, paso 6).
5. **El merge de #281** sigue siendo decisión de Martín, dentro de la ventana, y migra Neon solo
   (`arrancar.sh`). Verificar después con él (pasos 7 y 8 de su procedimiento).

---

## Qué verifiqué y qué no

**Ensayado el 16/11/2026 en esta máquina con una base sintética** (PostgreSQL 16 descartable, migrada y
sembrada con `main`, más 3 eventos históricos en `evento_operativo`), con el código real de #281 (`6656794`):

- los cinco scripts corren de punta a punta con la misma invocación que está acá;
- el manifiesto detecta un solo carácter cambiado en una fila (2 líneas distintas) y vuelve a coincidir al
  revertirlo;
- el aislamiento se comprueba antes de restaurar; `05-limpiar.ps1` deja el Docker sin restos;
- el camino de fallo: con un commit sin 0002 el paso 4 se detiene y no dice «aprobado»;
- el ensayo encontró y corrigió cuatro problemas **míos** antes de tocar Neon: una consulta mal casteada, un
  `[0]` que tomaba un carácter en vez de un texto, comillas anidadas que el PowerShell 5.1 rompe sin avisar
  (la primera consulta devolvió salida vacía con código 0) y la diferencia de texto de los `CHECK`.

**NO verificado, depende de Neon real:**

- la versión mayor de PostgreSQL de Neon y que la imagen `postgres:NN` exista y baje bien;
- que `pg_restore` corra sin error con lo que Neon realmente guarda (extensiones propias de Neon, por ejemplo);
- que la cadena con `channel_binding=require` conecte desde el contenedor (la imagen oficial trae un libpq
  que lo soporta, pero no lo probé contra Neon);
- cuánto tarda el `pg_dump` por internet y que Neon despierte a tiempo;
- qué conexiones internas de Neon aparecen en `pg_stat_activity` (pueden figurar sin ser tuyas: la salida
  del paso 1 dice desde dónde y desde cuándo);
- suspender `vanfull-api` y su efecto sobre los deploys (opcional en B.4);
- roles, privilegios y objetos globales del clúster: **no están cubiertos** (se restaura sin dueños ni
  grants; la recuperación de privilegios de Neon es un tema aparte).

## Por qué está hecho así

- **Scripts y no bloques para pegar:** PowerShell 5.1 rompe las comillas dobles anidadas en `docker ... sh -c`
  y el comando corre distinto, a veces sin error ni salida. Cada script lo evita y chequea el código de salida
  de cada paso.
- **`trust` en la copia:** solo se alcanza desde una red `--internal` sin puertos publicados; no hay
  contraseña que guardar ni filtrar.
- **Manifiesto con hash de todas las filas, no solo conteos:** un valor cambiado no cambia el conteo
  (Martín lo pide expresamente: «comparar también valores históricos»).
- **El hash de los históricos excluye las dos columnas nuevas** (`historicos.sql`): así es comparable antes y
  después de 0002.
