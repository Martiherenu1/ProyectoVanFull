# Respaldo de la base de Neon y prueba de restauracion en una base local aparte (Issue #304).
#
# Que hace:
#   1. Pide la cadena de conexion DIRECTA de Neon (oculta: no se muestra, no se guarda en disco).
#   2. Hace un volcado con pg_dump (SOLO LEE de Neon) a una carpeta fuera de OneDrive.
#   3. Levanta un PostgreSQL 16 local y descartable (Docker) y restaura ahi el volcado.
#   4. Compara filas por tabla y la revision de Alembic entre Neon y la copia restaurada.
#   5. Deja un resumen sin secretos para anexar al Issue #304.
#
# Requisitos: Docker Desktop encendido (usa la imagen postgres:16).
# Si Neon corre una version mayor que 16, cambiar $imagen por esa version.
# El volcado contiene datos de personas y hashes: no subirlo a Git ni al Drive.
#
# Uso (PowerShell):  .\respaldo-neon.ps1
param(
    [string]$Carpeta = (Join-Path $env:USERPROFILE "neon-backups"),
    [switch]$ConUrlYaCargada   # solo para pruebas locales: toma $env:NEON_URL en vez de pedirla
)

$ErrorActionPreference = "Stop"
$imagen = "postgres:16"
$contenedor = "vanfull-restore-test"

New-Item -ItemType Directory -Force $Carpeta | Out-Null
docker info --format "{{.ServerVersion}}" | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Docker no responde: encender Docker Desktop." }

if (-not $ConUrlYaCargada) {
    $seguro = Read-Host "Cadena de conexion DIRECTA de Neon (sin -pooler)" -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($seguro)
    $env:NEON_URL = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}
# Tolera lo que suele venir al copiar de Render o Neon: espacios, comillas, "DATABASE_URL=" o "psql ".
$limpia = $env:NEON_URL.Trim()
$limpia = $limpia -replace "^psql\s+", ""
$limpia = $limpia -replace "^[A-Za-z_][A-Za-z0-9_]*=", ""
$limpia = $limpia.Trim().Trim([char]34).Trim([char]39).Trim()
$env:NEON_URL = $limpia -replace "^postgresql\+asyncpg://", "postgresql://"
if ($env:NEON_URL -match "-pooler") { throw "Esa es la cadena con pooler: usar la DIRECTA (pg_dump no funciona bien con el pooler)." }
if ($env:NEON_URL -notmatch "^postgres(ql)?://") {
    # Solo se muestra el comienzo hasta "://" y el largo; nunca lo que va despues (usuario, clave, host).
    $i = $env:NEON_URL.IndexOf("://")
    $pista = if ($i -ge 0 -and $i -le 40) { $env:NEON_URL.Substring(0, $i + 3) } else { "(no se encontro ://)" }
    throw "La cadena no empieza con postgresql://. Empieza con: $pista - largo: $($env:NEON_URL.Length) caracteres."
}

$sello = Get-Date -Format "yyyyMMdd-HHmm"
$archivo = "neon-$sello.dump"
$env:ARCHIVO = $archivo
$env:CONSULTA = "select table_name, (xpath('/row/c/text()', query_to_xml(format('select count(*) as c from public.%I', table_name), false, true, '')))[1]::text as filas from information_schema.tables where table_schema='public' and table_type='BASE TABLE' order by 1"

try {
    Write-Host "1/5 Volcando Neon (solo lectura)..."
    docker run --rm -e NEON_URL -e ARCHIVO -v "${Carpeta}:/out" $imagen sh -c 'pg_dump \"$NEON_URL\" --format=custom --no-owner --no-privileges --file=\"/out/$ARCHIVO\"'
    if ($LASTEXITCODE -ne 0) { throw "pg_dump fallo (ver mensaje arriba)." }
    $tamano = (Get-Item (Join-Path $Carpeta $archivo)).Length
    if ($tamano -lt 1000) { throw "El volcado es sospechosamente chico ($tamano bytes)." }
    Write-Host ("    Volcado: {0} ({1:N0} bytes)" -f (Join-Path $Carpeta $archivo), $tamano)

    Write-Host "2/5 Levantando PostgreSQL local descartable..."
    if (docker ps -aq -f "name=^$contenedor$") { docker rm -f $contenedor | Out-Null }
    $clave = [guid]::NewGuid().ToString("N")
    docker run -d --name $contenedor -e POSTGRES_PASSWORD=$clave -v "${Carpeta}:/out:ro" $imagen | Out-Null
    do { Start-Sleep -Seconds 2; docker exec $contenedor pg_isready -U postgres | Out-Null } until ($LASTEXITCODE -eq 0)
    Start-Sleep -Seconds 5
    docker exec $contenedor createdb -U postgres restauracion
    if ($LASTEXITCODE -ne 0) { throw "No se pudo crear la base de prueba." }

    Write-Host "3/5 Restaurando el volcado en la copia..."
    # Neon agrega a algunas columnas la opcion interna pg_attver, que el PostgreSQL estandar no reconoce.
    # Se restaura a SQL, se quitan SOLO esas sentencias (patron estricto) y se aplica el resto con ON_ERROR_STOP.
    docker exec -e ARCHIVO=$archivo $contenedor sh -c 'pg_restore --no-owner --no-privileges -f /tmp/r.sql \"/out/$ARCHIVO\"'
    if ($LASTEXITCODE -ne 0) { throw "pg_restore fallo: la restauracion NO esta verificada." }
    docker exec $contenedor sh -c 'grep -vE \"^ALTER TABLE ONLY .* ALTER COLUMN .* SET \(pg_attver=[0-9]+\);$\" /tmp/r.sql > /tmp/r2.sql; true'
    $quitadas = [int](docker exec $contenedor sh -c 'grep -cE \"^ALTER TABLE ONLY .* ALTER COLUMN .* SET \(pg_attver=[0-9]+\);$\" /tmp/r.sql; true')
    $restantes = [int](docker exec $contenedor sh -c 'grep -c pg_attver /tmp/r2.sql; true')
    if ($restantes -ne 0) { throw "Quedan $restantes menciones de pg_attver fuera del patron esperado: no se filtran a ciegas. Restauracion NO verificada." }
    if ($quitadas -gt 0) { Write-Host "    Se omitieron $quitadas sentencias SET (pg_attver=...) propias de Neon (no existen en PostgreSQL estandar)." }
    docker exec $contenedor psql -U postgres -d restauracion -v ON_ERROR_STOP=1 -q -f /tmp/r2.sql
    if ($LASTEXITCODE -ne 0) { throw "La carga del volcado fallo: la restauracion NO esta verificada." }

    Write-Host "4/5 Comparando filas por tabla y revision de Alembic..."
    $origen = docker run --rm -e NEON_URL -e CONSULTA $imagen sh -c 'psql \"$NEON_URL\" -At -F , -c \"$CONSULTA\"'
    $copia = docker exec $contenedor psql -U postgres -d restauracion -At -F "," -c $env:CONSULTA
    $revOrigen = docker run --rm -e NEON_URL $imagen sh -c 'psql \"$NEON_URL\" -At -c \"select version_num from alembic_version\"'
    $revCopia = docker exec $contenedor psql -U postgres -d restauracion -At -c "select version_num from alembic_version"
    $diferencias = Compare-Object $origen $copia
    $tablas = @($origen).Count
    $filas = ($origen | ForEach-Object { [int](($_ -split ",")[1]) } | Measure-Object -Sum).Sum

    Write-Host "5/5 Resumen"
    $resumen = @(
        "Respaldo de Neon y restauracion de prueba (Issue #304)",
        "Fecha: $sello",
        "Archivo: $archivo ($tamano bytes), carpeta fuera de OneDrive",
        "Sentencias pg_attver propias de Neon omitidas al restaurar: $quitadas",
        "Tablas en Neon: $tablas - filas totales: $filas",
        "Revision de Alembic: Neon=$revOrigen - copia=$revCopia",
        $(if (-not $diferencias -and $revOrigen -eq $revCopia) { "RESULTADO: la copia restaurada coincide con Neon (filas por tabla y revision)." } else { "RESULTADO: HAY DIFERENCIAS, la restauracion NO esta verificada." })
    )
    $resumen | ForEach-Object { Write-Host "    $_" }
    $rutaResumen = Join-Path $Carpeta "restauracion-$sello.txt"
    $resumen | Set-Content -Encoding utf8 $rutaResumen
    if ($diferencias) {
        Write-Host "Diferencias por tabla (<= Neon, => copia):"
        $diferencias | Format-Table -AutoSize | Out-String | Write-Host
        Write-Host "Si la app se uso entre el volcado y el conteo, es esperable alguna diferencia: repetir sin usar la app."
    }
    Write-Host "Resumen sin secretos: $rutaResumen"
    Write-Host "La copia sigue levantada ($contenedor) para ensayar migraciones. Borrarla con: docker rm -f $contenedor"
}
finally {
    Remove-Item Env:NEON_URL, Env:ARCHIVO, Env:CONSULTA -ErrorAction SilentlyContinue
}
