<#
Paso 3 - Restauracion COMPLETA del respaldo en una base local aislada, y comparacion con Neon.
No toca Neon (no necesita la cadena). Tampoco toca tu Postgres de desarrollo (el de docker compose):
usa un contenedor propio, 'vanfull-restore', en una red 'vanfull-restore-net' creada con --internal
(sin salida a internet), sin ningun puerto publicado y con un volumen NUEVO.
La base queda con acceso 'trust' porque solo es alcanzable desde esa red interna: asi no hay ninguna
contrasena que guardar.
Uso:  .\03-restaurar-aislado.ps1 -Pg 17
#>
param(
    [Parameter(Mandatory)][ValidatePattern('^\d{2}$')][string]$Pg,
    [string]$Dir,
    [string]$Archivo
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
$registro = Join-Path $Dir (($Archivo -replace '^neon-pre-0002-', 'registro-') -replace '\.dump$', '.txt')
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

Write-Host '[1/5] Creando la base aislada...'
docker run -d --name vanfull-restore --network vanfull-restore-net `
    -e POSTGRES_USER=restore -e POSTGRES_DB=restaurada -e POSTGRES_HOST_AUTH_METHOD=trust `
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

Write-Host '[3/5] pg_restore completo (una transaccion, corta ante el primer error)...'
docker exec -e ARCHIVO vanfull-restore sh -c 'pg_restore --dbname=restaurada --username=restore --no-password --exit-on-error --single-transaction --no-owner --no-privileges /respaldos/$ARCHIVO'
Chequear 'La restauracion FALLO: el respaldo no se puede dar por bueno. Guardar el mensaje de arriba y avisar al equipo'

Write-Host '[4/5] Manifiesto de la copia restaurada...'
docker exec vanfull-restore sh -c 'psql -U restore -d restaurada -X -A -t -q -v ON_ERROR_STOP=1 -f /sql/manifiesto.sql > /verif/copia-pre0002.txt'
Chequear 'No se pudo generar el manifiesto de la copia'

Write-Host '[5/5] Copia == Neon ?'
$dif = Compare-Object (Get-Content (Join-Path $v 'origen-antes.txt')) (Get-Content (Join-Path $v 'copia-pre0002.txt'))
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
