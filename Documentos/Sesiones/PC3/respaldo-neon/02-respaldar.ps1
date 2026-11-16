<#
Paso 2 - Respaldo actual de Neon (pg_dump, formato custom, completo). SOLO LEE de Neon.
Lo corres DENTRO de la ventana, con todos los escritores detenidos (ver RESPALDO-NEON.md, paso B).
Uso:  .\02-respaldar.ps1 -Pg 17        (el numero lo dice el paso 1)
Deja en la carpeta de respaldos (por defecto %LOCALAPPDATA%\VanFullBackups):
  neon-pre-0002-<fecha>.dump          el respaldo
  verificacion\origen-antes.txt       manifiesto de Neon justo ANTES del pg_dump
  verificacion\origen-despues.txt     manifiesto de Neon justo DESPUES (si difiere, alguien escribio)
  registro-<fecha>.txt                hora, version, hash SHA-256, tamano, SHA del codigo (sin la cadena)
#>
param(
    [Parameter(Mandatory)][ValidatePattern('^\d{2}$')][string]$Pg,
    [string]$Dir
)
. "$PSScriptRoot\comun.ps1"

$Dir = Resolver-Dir $Dir
$imagen = "postgres:$Pg"
$sello = Get-Date -Format 'yyyyMMdd-HHmmss'
$env:ARCHIVO = "neon-pre-0002-$sello.dump"
$v = Join-Path $Dir 'verificacion'

try {
    Leer-UrlNeon
    $hostNeon = Host-Saneado

    Write-Host "[1/5] Manifiesto de Neon ANTES del respaldo..."
    docker run --rm -e NEON_URL -v "${PSScriptRoot}:/sql:ro" -v "${Dir}:/out" $imagen sh -c 'set -f; psql $NEON_URL -X -A -t -q -v ON_ERROR_STOP=1 -f /sql/manifiesto.sql > /out/verificacion/origen-antes.txt'
    Chequear 'No se pudo generar el manifiesto de origen'
    $antes = Get-Content (Join-Path $v 'origen-antes.txt')
    $mayor = @(Seccion $antes '== version del servidor')[0]
    if ($mayor -ne $Pg) { Fallar "El servidor es PostgreSQL $mayor y se pidio -Pg $Pg. pg_dump no puede ser mas viejo que el servidor: repetir con -Pg $mayor." }
    $rev = (Seccion $antes '== alembic_version') -join ','
    if ($rev -ne '0001') { Fallar "alembic_version = [$rev] y se esperaba 0001. No seguir ni usar stamp: avisar al equipo." }

    Write-Host "[2/5] pg_dump (formato custom) ..."
    docker run --rm -e NEON_URL -e ARCHIVO -v "${Dir}:/out" $imagen sh -c 'set -f; pg_dump --dbname=$NEON_URL --format=custom --no-password --file=/out/$ARCHIVO'
    Chequear 'pg_dump fallo: el respaldo esta INCOMPLETO, no usarlo'

    Write-Host "[3/5] Manifiesto de Neon DESPUES del respaldo..."
    docker run --rm -e NEON_URL -v "${PSScriptRoot}:/sql:ro" -v "${Dir}:/out" $imagen sh -c 'set -f; psql $NEON_URL -X -A -t -q -v ON_ERROR_STOP=1 -f /sql/manifiesto.sql > /out/verificacion/origen-despues.txt'
    Chequear 'No se pudo generar el manifiesto posterior'
}
finally {
    Remove-Item Env:NEON_URL -ErrorAction SilentlyContinue
}

Write-Host "[4/5] Antes == despues ?"
$dif = Compare-Object (Get-Content (Join-Path $v 'origen-antes.txt')) (Get-Content (Join-Path $v 'origen-despues.txt'))
$sinEscrituras = -not $dif
if ($sinEscrituras) {
    Write-Host 'OK  Neon no cambio mientras se respaldaba.' -ForegroundColor Green
} else {
    Write-Host 'NO  Neon CAMBIO durante el respaldo: hay un escritor activo. El respaldo es consistente (pg_dump usa una instantanea) pero NO equivale a un respaldo en ventana. Cerrar la ventana de verdad y repetir.' -ForegroundColor Red
    $dif | Select-Object -First 10 | Format-Table -AutoSize | Out-String | Write-Host
}

Write-Host "[5/5] Hash y lectura del archivo..."
$ruta = Join-Path $Dir $env:ARCHIVO
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $ruta).Hash
$bytes = (Get-Item -LiteralPath $ruta).Length
if ($bytes -le 0) { Fallar 'El archivo de respaldo esta vacio' }
$lista = docker run --rm -e ARCHIVO -v "${Dir}:/out:ro" $imagen sh -c 'pg_restore --list /out/$ARCHIVO'
Chequear 'pg_restore --list no pudo leer el archivo: respaldo ilegible'
$tablasConDatos = @($lista | Where-Object { $_ -match ' TABLE DATA public ' }).Count

$git = (git -C $PSScriptRoot rev-parse HEAD)
$ramaGit = (git -C $PSScriptRoot branch --show-current)
$registro = @(
    "Respaldo de Neon - $sello",
    "Archivo        : $ruta",
    "SHA-256        : $hash",
    "Tamano (bytes) : $bytes",
    "Tablas con datos en el archivo: $tablasConDatos",
    "Origen (host)  : $hostNeon",
    "PostgreSQL mayor: $Pg",
    "alembic_version: $rev",
    "Neon sin cambios durante el respaldo: $sinEscrituras",
    "Codigo del repo (HEAD local): $git en la rama '$ramaGit'",
    "Cliente        : $(docker run --rm $imagen pg_dump --version)"
)
$registro | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $Dir "registro-$sello.txt")
Write-Host ''
$registro | ForEach-Object { Write-Host $_ }
Write-Host ''
Write-Host "Guarda el SHA-256 y NO borres el archivo. Siguiente: .\03-restaurar-aislado.ps1 -Pg $Pg"
