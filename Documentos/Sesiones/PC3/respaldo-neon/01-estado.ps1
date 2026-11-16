<#
Paso 1 - Estado del origen (Neon). SOLO LECTURA: no escribe nada en Neon.
Dice la version mayor de PostgreSQL (la necesitas como -Pg en los pasos 2 y 3), la revision de Alembic
(se espera 0001), el tamano, las extensiones y quien esta conectado.
Uso:  .\01-estado.ps1
#>
param([string]$Imagen = 'postgres:16')   # solo para consultar: psql 16 se conecta a servidores mas nuevos
. "$PSScriptRoot\comun.ps1"

try {
    Leer-UrlNeon
    $salida = docker run --rm -e NEON_URL -v "${PSScriptRoot}:/sql:ro" $Imagen sh -c 'set -f; psql $NEON_URL -X -A -t -q -v ON_ERROR_STOP=1 -f /sql/estado.sql'
    Chequear 'No se pudo leer el estado de Neon (revisar la cadena, que sea la directa y la red)'
    $salida | ForEach-Object { Write-Host $_ }

    Write-Host ''
    Write-Host '--- VEREDICTO ---'
    $revisiones = @(Seccion $salida '== alembic_version')
    if ($revisiones.Count -eq 1 -and $revisiones[0] -eq '0001') {
        Write-Host 'OK  alembic_version = 0001 (una sola revision, la esperada).' -ForegroundColor Green
    } else {
        Write-Host ('NO  alembic_version = [' + ($revisiones -join ', ') + '] y se esperaba 0001. NO seguir, NO usar stamp: avisar al equipo.') -ForegroundColor Red
    }
    $mayor = ($salida | Where-Object { $_ -like '== version mayor:*' }) -replace '.*: ', ''
    Write-Host "Version mayor de PostgreSQL en Neon: $mayor  ->  usar  -Pg $mayor  en los pasos 2 y 3."
    $otras = @(Seccion $salida '== otras conexiones')
    if ($otras.Count -eq 0) {
        Write-Host 'OK  Ninguna otra conexion a la base en este momento.' -ForegroundColor Green
    } else {
        Write-Host ("ATENCION  Hay " + $otras.Count + " conexion(es) mas. Si alguna es la API de Render, el sitio, un APK o la PC de Martin/Facundo, la ventana todavia no esta cerrada.") -ForegroundColor Yellow
    }
}
finally {
    Remove-Item Env:NEON_URL -ErrorAction SilentlyContinue
}
