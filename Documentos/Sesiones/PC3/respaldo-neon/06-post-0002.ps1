<#
Paso de contingencia - 0002 ya se aplico en Neon SIN el respaldo previo. SOLO LEE de Neon.
Comprueba la migracion (version, columnas, restricciones, filas con metadatos) y deja un respaldo del
estado actual, con manifiesto antes y despues, hash SHA-256 y lectura del archivo.
Uso:  .\06-post-0002.ps1 -Pg 16
Deja en la carpeta de respaldos (por defecto %LOCALAPPDATA%\VanFullBackups):
  neon-post-0002-<fecha>.dump, verificacion\post0002-<fecha>.txt, verificacion\post-antes-<fecha>.txt,
  verificacion\post-despues-<fecha>.txt y registro-post-<fecha>.txt
#>
param(
    [Parameter(Mandatory)][ValidatePattern('^\d{2}$')][string]$Pg,
    [string]$Dir
)
. "$PSScriptRoot\comun.ps1"

$Dir = Resolver-Dir $Dir
$imagen = "postgres:$Pg"
$sello = Get-Date -Format 'yyyyMMdd-HHmmss'
$env:ARCHIVO = "neon-post-0002-$sello.dump"
$env:SELLO = $sello
$v = Join-Path $Dir 'verificacion'
$ok = $true

try {
    Leer-UrlNeon
    $hostNeon = Host-Saneado

    Write-Host "[1/5] Estado de la migracion 0002 en Neon..."
    docker run --rm -e NEON_URL -e SELLO -v "${PSScriptRoot}:/sql:ro" -v "${Dir}:/out" $imagen sh -c 'set -f; psql $NEON_URL -X -A -t -q -v ON_ERROR_STOP=1 -f /sql/post0002.sql > /out/verificacion/post0002-$SELLO.txt'
    Chequear 'No se pudo leer el estado de la migracion'
    $post = Get-Content (Join-Path $v "post0002-$sello.txt")
    $post | ForEach-Object { Write-Host $_ }

    Write-Host "[2/5] Manifiesto ANTES del respaldo..."
    docker run --rm -e NEON_URL -e SELLO -v "${PSScriptRoot}:/sql:ro" -v "${Dir}:/out" $imagen sh -c 'set -f; psql $NEON_URL -X -A -t -q -v ON_ERROR_STOP=1 -f /sql/manifiesto.sql > /out/verificacion/post-antes-$SELLO.txt'
    Chequear 'No se pudo generar el manifiesto'
    $antes = Get-Content (Join-Path $v "post-antes-$sello.txt")
    $mayor = @(Seccion $antes '== version del servidor')[0]
    if ($mayor -ne $Pg) { Fallar "El servidor es PostgreSQL $mayor y se pidio -Pg ${Pg}: repetir con -Pg $mayor." }

    Write-Host "[3/5] pg_dump (formato custom) del estado actual..."
    docker run --rm -e NEON_URL -e ARCHIVO -v "${Dir}:/out" $imagen sh -c 'set -f; pg_dump --dbname=$NEON_URL --format=custom --no-password --file=/out/$ARCHIVO'
    Chequear 'pg_dump fallo: el respaldo esta INCOMPLETO, no usarlo'

    Write-Host "[4/5] Manifiesto DESPUES del respaldo..."
    docker run --rm -e NEON_URL -e SELLO -v "${PSScriptRoot}:/sql:ro" -v "${Dir}:/out" $imagen sh -c 'set -f; psql $NEON_URL -X -A -t -q -v ON_ERROR_STOP=1 -f /sql/manifiesto.sql > /out/verificacion/post-despues-$SELLO.txt'
    Chequear 'No se pudo generar el manifiesto posterior'
}
finally {
    Remove-Item Env:NEON_URL -ErrorAction SilentlyContinue
}

Write-Host "[5/5] Veredicto, hash y lectura del archivo..."
$rev = (Seccion $post '== alembic_version') -join ','
$cols = @(Seccion $post '== columnas nuevas')
$rest = @(Seccion $post '== restricciones nuevas')
$filas = @(Seccion $post '== evento_operativo')[0]
if ($rev -eq '0002') { Write-Host 'OK  alembic_version = 0002' -ForegroundColor Green } else { Write-Host "NO  alembic_version = [$rev]" -ForegroundColor Red; $ok = $false }
if ($cols.Count -eq 2 -and @($cols | Where-Object { $_ -like '*nullable=YES' }).Count -eq 2) { Write-Host 'OK  dos columnas nuevas, nullable' -ForegroundColor Green } else { Write-Host 'NO  columnas nuevas distintas de lo esperado' -ForegroundColor Red; $ok = $false }
if ($rest.Count -eq 3 -and @($rest | Where-Object { $_ -like '*validada=true' }).Count -eq 3) { Write-Host 'OK  tres restricciones nuevas, validadas' -ForegroundColor Green } else { Write-Host 'NO  restricciones nuevas distintas de lo esperado' -ForegroundColor Red; $ok = $false }
Write-Host "    evento_operativo (total | con metadatos nuevos): $filas"

$dif = Compare-Object (Get-Content (Join-Path $v "post-antes-$sello.txt")) (Get-Content (Join-Path $v "post-despues-$sello.txt"))
$sinEscrituras = -not $dif
if ($sinEscrituras) { Write-Host 'OK  Neon no cambio mientras se respaldaba.' -ForegroundColor Green } else { Write-Host 'ATENCION  Neon cambio durante el respaldo (la API esta en uso). El archivo es consistente igual: pg_dump usa una instantanea.' -ForegroundColor Yellow }

$ruta = Join-Path $Dir $env:ARCHIVO
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $ruta).Hash
$bytes = (Get-Item -LiteralPath $ruta).Length
if ($bytes -le 0) { Fallar 'El archivo de respaldo esta vacio' }
$lista = docker run --rm -e ARCHIVO -v "${Dir}:/out:ro" $imagen sh -c 'pg_restore --list /out/$ARCHIVO'
Chequear 'pg_restore --list no pudo leer el archivo: respaldo ilegible'
$tablasConDatos = @($lista | Where-Object { $_ -match ' TABLE DATA public ' }).Count

$registro = @(
    "Respaldo POSTERIOR a 0002 de Neon - $sello",
    "Archivo        : $ruta",
    "SHA-256        : $hash",
    "Tamano (bytes) : $bytes",
    "Tablas con datos en el archivo: $tablasConDatos",
    "Origen (host)  : $hostNeon",
    "PostgreSQL mayor: $Pg",
    "alembic_version: $rev",
    "Migracion 0002 como se esperaba: $ok",
    "evento_operativo (total | con metadatos nuevos): $filas",
    "Neon sin cambios durante el respaldo: $sinEscrituras",
    "Codigo del repo (HEAD local): $(git -C $PSScriptRoot rev-parse HEAD)"
)
$registro | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $Dir "registro-post-$sello.txt")
Write-Host ''
$registro | ForEach-Object { Write-Host $_ }
Write-Host ''
Write-Host '--- Conteo de filas por tabla (para comparar con lo conocido) ---'
Seccion (Get-Content (Join-Path $v "post-antes-$sello.txt")) '== tablas' | ForEach-Object { Write-Host $_ }
