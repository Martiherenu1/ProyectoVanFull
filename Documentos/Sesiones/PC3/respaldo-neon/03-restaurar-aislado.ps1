<#
Paso 3 - Restauracion COMPLETA del respaldo en una base local aislada, y comparacion con Neon.
No toca Neon (no necesita la cadena). Tampoco toca tu Postgres de desarrollo (el de docker compose):
usa un contenedor propio, 'vanfull-restore', en una red 'vanfull-restore-net' creada con --internal
(sin salida a internet), sin ningun puerto publicado y con un volumen NUEVO.
La base queda con acceso 'trust' porque solo es alcanzable desde esa red interna: asi no hay ninguna
contrasena que guardar.
Uso:  .\03-restaurar-aislado.ps1 -Pg 17
      Respaldo posterior a 0002 (seccion G del runbook):
      .\03-restaurar-aislado.ps1 -Pg 16 -Archivo neon-post-0002-<fecha>.dump -Manifiesto post-antes-<fecha>.txt
#>
param(
    [Parameter(Mandatory)][ValidatePattern('^\d{2}$')][string]$Pg,
    [string]$Dir,
    [string]$Archivo,
    [string]$Manifiesto = 'origen-antes.txt'   # manifiesto de Neon tomado junto con ese respaldo
)
. "$PSScriptRoot\comun.ps1"

$Dir = Resolver-Dir $Dir
$v = Join-Path $Dir 'verificacion'
$imagen = "postgres:$Pg"
if (-not $Archivo) {
    $ultimo = Get-ChildItem -LiteralPath $Dir -Filter 'neon-pre-0002-*.dump' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $ultimo) { Fallar "No hay ningun neon-pre-0002-*.dump en $Dir (correr antes 02-respaldar.ps1)" }
    $Archivo = $ultimo.Name
}
if (-not (Test-Path -LiteralPath (Join-Path $Dir $Archivo))) { Fallar "No existe $Archivo en $Dir" }
$env:ARCHIVO = $Archivo
Write-Host "Archivo a restaurar: $Archivo"
$hashActual = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $Dir $Archivo)).Hash
Write-Host "SHA-256 actual     : $hashActual"
$registro = Join-Path $Dir ((($Archivo -replace '^neon-pre-0002-', 'registro-') -replace '^neon-post-0002-', 'registro-post-') -replace '\.dump$', '.txt')
if (-not (Test-Path -LiteralPath (Join-Path $v $Manifiesto))) { Fallar "No existe el manifiesto $Manifiesto en $v" }
if (Test-Path -LiteralPath $registro) {
    $hashRegistro = ((Get-Content -LiteralPath $registro | Where-Object { $_ -like 'SHA-256*' }) -split ':\s*')[1].Trim()
    if ($hashRegistro -ne $hashActual) { Fallar "El archivo cambio desde que se respaldo: su SHA-256 no coincide con el del registro ($hashRegistro)." }
    Write-Host 'OK  El SHA-256 coincide con el del registro: el archivo no se modifico.' -ForegroundColor Green
} else {
    Write-Host "ATENCION  No hay registro ($registro): no se puede comprobar que el archivo sea el original." -ForegroundColor Yellow
}

# --- Nada de reutilizar: contenedor, red y volumen tienen que ser nuevos -----------------------------
if (docker ps -aq -f 'name=^vanfull-restore$') { Fallar 'Ya existe el contenedor vanfull-restore. Correr 05-limpiar.ps1 antes: no se restaura sobre una base ya usada.' }
if (docker volume ls -q -f 'name=^vanfull-restore-data$') { Fallar 'Ya existe el volumen vanfull-restore-data. Correr 05-limpiar.ps1 antes.' }
if (-not (docker network ls -q -f 'name=^vanfull-restore-net$')) {
    docker network create --internal vanfull-restore-net | Out-Null
    Chequear 'No se pudo crear la red interna'
}

# La copia usa la MISMA intercalacion que Neon (la dice el propio respaldo). Con otra, el manifiesto
# ordena distinto las filas y los hashes no coinciden aunque los datos sean iguales (pasado el 16/11).
$crear = (docker run --rm -e ARCHIVO -v "${Dir}:/respaldos:ro" $imagen sh -c 'pg_restore --create --schema-only -f - /respaldos/$ARCHIVO' | Where-Object { $_ -like 'CREATE DATABASE*' })
if ($crear -notmatch "LOCALE = '([^']+)'") { Fallar "No se pudo leer la intercalacion del respaldo: $crear" }
$locale = $Matches[1]
Write-Host "Intercalacion de origen: $locale"

Write-Host '[1/5] Creando la base aislada...'
docker run -d --name vanfull-restore --network vanfull-restore-net `
    -e POSTGRES_USER=restore -e POSTGRES_DB=restaurada -e POSTGRES_HOST_AUTH_METHOD=trust `
    -e "POSTGRES_INITDB_ARGS=--locale=$locale" `
    -v vanfull-restore-data:/var/lib/postgresql/data `
    -v "${Dir}:/respaldos:ro" -v "${v}:/verif" -v "${PSScriptRoot}:/sql:ro" $imagen | Out-Null
Chequear 'No se pudo crear el contenedor'
# Se espera por TCP (127.0.0.1): durante la inicializacion la imagen levanta un servidor temporal que
# solo escucha por socket; si se restaurara en ese momento, se perderia al reiniciarse.
$listo = $false
for ($i = 0; $i -lt 60; $i++) {
    docker exec vanfull-restore pg_isready -h 127.0.0.1 -U restore -d restaurada | Out-Null
    if ($LASTEXITCODE -eq 0) { $listo = $true; break }
    Start-Sleep 1
}
if (-not $listo) { Fallar 'La base aislada no arranco en 60 s (docker logs vanfull-restore)' }

Write-Host '[2/5] Comprobando el aislamiento ANTES de restaurar...'
$interna = (docker network inspect vanfull-restore-net --format '{{.Internal}}')
$puertos = (docker inspect vanfull-restore --format '{{len .HostConfig.PortBindings}}')
$redes = (docker inspect vanfull-restore --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}').Trim()
$tablas = (docker exec vanfull-restore psql -U restore -d restaurada -X -A -t -q -c "select count(*) from pg_class where relnamespace = 'public'::regnamespace").Trim()
$destino = (docker exec vanfull-restore psql -U restore -d restaurada -X -A -t -q -c "select current_database() || ' | ' || version()").Trim()
Write-Host "  red interna (sin internet) : $interna   (se espera true)"
Write-Host "  puertos publicados al host : $puertos   (se espera 0)"
Write-Host "  redes del contenedor       : $redes   (se espera solo vanfull-restore-net)"
Write-Host "  objetos en la base destino : $tablas   (se espera 0: base vacia)"
Write-Host "  destino                    : $destino"
if ($interna -ne 'true' -or $puertos -ne '0' -or $redes -ne 'vanfull-restore-net' -or $tablas -ne '0') {
    Fallar 'El destino NO esta aislado o no esta vacio. No se restaura.'
}

Write-Host '[3/5] Restauracion completa (una transaccion, corta ante el primer error)...'
# Neon marca las columnas agregadas con ALTER TABLE con un parametro interno (pg_attver) que un
# PostgreSQL comun rechaza. Es metadato de Neon, no datos: se quitan SOLO esas lineas y se informa cuantas.
# Sin comillas dobles dentro del comando: PowerShell 5.1 las rompe al pasarlas a docker.
docker exec -e ARCHIVO vanfull-restore sh -c 'pg_restore --no-owner --no-privileges -f /tmp/r.sql /respaldos/$ARCHIVO && { grep -c ''^ALTER TABLE ONLY .* SET (pg_attver='' /tmp/r.sql > /tmp/n.txt; grep -v ''^ALTER TABLE ONLY .* SET (pg_attver='' /tmp/r.sql > /tmp/r2.sql; true; }'
Chequear 'No se pudo leer el respaldo con pg_restore'
$quitadas = (docker exec vanfull-restore cat /tmp/n.txt).Trim()
Write-Host "    lineas pg_attver de Neon quitadas: $quitadas"
docker exec vanfull-restore psql -U restore -d restaurada -X -q -1 -v ON_ERROR_STOP=1 -o /dev/null -f /tmp/r2.sql
Chequear 'La restauracion FALLO: el respaldo no se puede dar por bueno. Guardar el mensaje de arriba y avisar al equipo'

Write-Host '[4/5] Manifiesto de la copia restaurada...'
docker exec vanfull-restore sh -c 'psql -U restore -d restaurada -X -A -t -q -v ON_ERROR_STOP=1 -f /sql/manifiesto.sql > /verif/copia-pre0002.txt'
Chequear 'No se pudo generar el manifiesto de la copia'

Write-Host '[5/5] Copia == Neon ?'
Write-Host "    contra el manifiesto: $Manifiesto"
$dif = Compare-Object (Get-Content (Join-Path $v $Manifiesto)) (Get-Content (Join-Path $v 'copia-pre0002.txt'))
if (-not $dif) {
    $lineas = (Get-Content (Join-Path $v 'copia-pre0002.txt')).Count
    Write-Host "OK  La copia es identica a Neon en: version, alembic, extensiones, filas y hash de CADA tabla, secuencias, columnas, indices y PK/FK/UNIQUE ($lineas lineas comparadas)." -ForegroundColor Green
    Write-Host '    Limite: de los CHECK se comparan nombre, tabla y validacion, no el texto de la expresion (PostgreSQL lo re-escribe al restaurar).'
} else {
    Write-Host 'NO  La copia DIFIERE de Neon:' -ForegroundColor Red
    $dif | Select-Object -First 20 | Format-Table -AutoSize | Out-String | Write-Host
    Fallar 'La copia restaurada no coincide con el origen. No avanzar al paso 4.'
}
Write-Host ''
Write-Host 'Siguiente: .\04-ensayo-0002.ps1 -Commit <SHA del HEAD de #281>'
