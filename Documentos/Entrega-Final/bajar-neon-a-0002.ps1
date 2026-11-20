# Vuelta atras de #327: baja la base de Neon de la revision 0004 a la 0002 (Issue #304).
#
# Cuando usarlo: si el despliegue de #327 falla y hay que volver Render a la version anterior.
# ORDEN OBLIGATORIO: primero este script, despues volver Render (o integrar el revert).
# La imagen anterior no conoce la revision 0004: si se vuelve Render antes, la API no arranca.
#
# Que hace:
#   1. Pide la cadena DIRECTA de Neon (oculta; no se muestra ni se guarda).
#   2. Trae el codigo de -Ref (por defecto origin/main despues del merge) a una carpeta temporal
#      y aborta si no tiene la migracion 0004.
#   3. Muestra la revision actual de Neon y aborta si no es 0004.
#   4. Cuenta los datos que el downgrade de 0003 borra sin aviso (descensos y pasos confirmados).
#   5. Hace un volcado de seguridad de Neon ANTES de tocar nada.
#   6. Pide escribir BAJAR, corre "alembic downgrade 0002" y verifica que quedo en 0002.
#
# Requisitos: Docker encendido; imagen del backend construida (docker compose build backend).
# Ensayado sobre una copia restaurada de Neon (19/11): 0004 -> 0002 deja datos y esquema identicos.
#
# Uso (PowerShell, desde la raiz del repo):  .\Documentos\Entrega-Final\bajar-neon-a-0002.ps1
param(
    [string]$Ref = "origin/main",
    [string]$Imagen = "proyectovanfull-backend:latest",
    [string]$Carpeta = (Join-Path $env:USERPROFILE "neon-backups"),
    [string]$RedDocker = "",          # solo para pruebas locales (p. ej. container:vanfull-restore-test)
    [switch]$ConUrlYaCargada,         # solo para pruebas locales: toma $env:NEON_URL
    [switch]$Confirmado               # solo para pruebas locales: no pide escribir BAJAR
)

$ErrorActionPreference = "Stop"
$repo = (git -C $PSScriptRoot rev-parse --show-toplevel).Trim()
$sello = Get-Date -Format "yyyyMMdd-HHmm"
$codigo = Join-Path $env:TEMP "vanfull-bajada-$sello"
$red = @(); if ($RedDocker) { $red = @("--network", $RedDocker) }

docker info --format "{{.ServerVersion}}" | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Docker no responde: encender Docker Desktop." }
docker image inspect $Imagen | Out-Null
if ($LASTEXITCODE -ne 0) { throw "No existe la imagen $Imagen. Construirla con: docker compose build backend" }

if (-not $ConUrlYaCargada) {
    $seguro = Read-Host "Cadena de conexion DIRECTA de Neon (sin -pooler)" -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($seguro)
    $env:NEON_URL = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}
$limpia = $env:NEON_URL.Trim()
$limpia = $limpia -replace "^psql\s+", ""
$limpia = $limpia -replace "^[A-Za-z_][A-Za-z0-9_]*=", ""
$limpia = $limpia.Trim().Trim([char]34).Trim([char]39).Trim()
$env:NEON_URL = $limpia -replace "^postgresql\+asyncpg://", "postgresql://"
if ($env:NEON_URL -match "-pooler") { throw "Esa es la cadena con pooler: usar la DIRECTA." }
if ($env:NEON_URL -notmatch "^postgres(ql)?://") {
    $i = $env:NEON_URL.IndexOf("://")
    $pista = if ($i -ge 0 -and $i -le 40) { $env:NEON_URL.Substring(0, $i + 3) } else { "(no se encontro ://)" }
    throw "La cadena no empieza con postgresql://. Empieza con: $pista - largo: $($env:NEON_URL.Length) caracteres."
}
$env:DATABASE_URL = $env:NEON_URL

function Invoke-Alembic($argumentos) {
    $salida = docker run --rm @red -e DATABASE_URL -v "${codigo}\backend:/app" -w /app $Imagen sh -c "alembic $argumentos 2>&1"
    $script:salidaAlembic = $LASTEXITCODE
    $salida | Where-Object { $_ -notmatch "(Context impl|Will assume)" }
}
function Invoke-Sql($consulta) {
    $env:CONSULTA = $consulta
    docker run --rm @red -e NEON_URL -e CONSULTA postgres:16 sh -c 'psql \"$NEON_URL\" -At -c \"$CONSULTA\"'
}

try {
    Write-Host "1/6 Trayendo el codigo de $Ref..."
    git -C $repo fetch -q origin
    git -C $repo worktree add -q --detach $codigo $Ref
    if ($LASTEXITCODE -ne 0) { throw "No se pudo preparar el codigo de $Ref." }
    if (-not (Test-Path (Join-Path $codigo "backend\migrations\versions\0004_integridad_eta_cu009.py"))) {
        throw "$Ref no tiene la migracion 0004: no sirve para bajar. Usar el SHA mergeado de #327 con -Ref."
    }
    Write-Host ("    Codigo: {0}" -f (git -C $codigo log -1 --format="%h %s"))

    Write-Host "2/6 Revision actual de Neon..."
    $revision = (Invoke-Sql "select version_num from alembic_version").Trim()
    Write-Host "    Neon esta en: $revision"
    if ($revision -eq "0002") { Write-Host "    Ya esta en 0002: no hay nada que bajar. Se puede volver Render."; return }
    if ($revision -ne "0004") { throw "Neon esta en '$revision', no en 0004: no se baja nada. Revisar a mano." }

    Write-Host "3/6 Datos que el downgrade borra sin aviso..."
    $descensos = (Invoke-Sql "select count(*) from reserva where orden_descenso is not null").Trim()
    $habilitados = (Invoke-Sql "select count(*) from descenso_habilitado").Trim()
    $pasos = (Invoke-Sql "select count(*) from viaje where orden_ultimo_paso is not null").Trim()
    Write-Host "    reservas con descenso elegido: $descensos - descensos habilitados: $habilitados - viajes con paso confirmado: $pasos"

    Write-Host "4/6 Volcado de seguridad antes de bajar..."
    New-Item -ItemType Directory -Force $Carpeta | Out-Null
    $env:ARCHIVO = "neon-pre-bajada-$sello.dump"
    docker run --rm @red -e NEON_URL -e ARCHIVO -v "${Carpeta}:/out" postgres:16 sh -c 'pg_dump \"$NEON_URL\" --format=custom --no-owner --no-privileges --file=\"/out/$ARCHIVO\"'
    if ($LASTEXITCODE -ne 0) { throw "El volcado de seguridad fallo: NO se baja nada." }
    $tamano = (Get-Item (Join-Path $Carpeta $env:ARCHIVO)).Length
    if ($tamano -lt 1000) { throw "El volcado de seguridad es sospechosamente chico ($tamano bytes): NO se baja nada." }
    Write-Host ("    {0} ({1:N0} bytes)" -f (Join-Path $Carpeta $env:ARCHIVO), $tamano)

    Write-Host "5/6 Confirmacion"
    if (-not $Confirmado) {
        $respuesta = Read-Host "Escribir BAJAR para correr 'alembic downgrade 0002' contra Neon"
        if ($respuesta -cne "BAJAR") { Write-Host "    Cancelado: Neon sigue en 0004."; return }
    }
    Invoke-Alembic "downgrade 0002" | ForEach-Object { Write-Host "    $_" }
    if ($script:salidaAlembic -ne 0) { throw "alembic downgrade fallo (ver arriba). Neon puede haber quedado en 0003: revisar antes de volver Render." }

    Write-Host "6/6 Verificacion"
    $final = (Invoke-Sql "select version_num from alembic_version").Trim()
    Write-Host "    Neon quedo en: $final"
    if ($final -ne "0002") { throw "Neon no quedo en 0002 ('$final'): NO volver Render todavia." }
    Write-Host "    LISTO: ya se puede volver Render a la version anterior (o integrar el revert)."
}
finally {
    Remove-Item Env:NEON_URL, Env:DATABASE_URL, Env:ARCHIVO, Env:CONSULTA -ErrorAction SilentlyContinue
    if (Test-Path $codigo) { git -C $repo worktree remove --force $codigo 2>$null }
}
