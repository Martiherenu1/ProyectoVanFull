# Funciones comunes de los scripts de respaldo de Neon. Se cargan con:  . "$PSScriptRoot\comun.ps1"
#
# Windows PowerShell 5.1: con 'Stop' convierte cualquier línea que docker escriba en stderr en una
# excepción, aunque el comando haya andado. Por eso se deja 'Continue' y se mira $LASTEXITCODE a mano.
# Y no se pueden anidar comillas dobles dentro de un `sh -c '...'`: PowerShell 5.1 las rompe y el
# comando corre distinto, a veces sin error ni salida. Los scripts usan comillas simples en el interior.
$ErrorActionPreference = 'Continue'

function Fallar([string]$mensaje) {
    Write-Host "DETENER: $mensaje" -ForegroundColor Red
    throw $mensaje
}

function Chequear([string]$mensaje) {
    if ($LASTEXITCODE -ne 0) { Fallar "$mensaje (codigo de salida $LASTEXITCODE)" }
}

# Carpeta de respaldos: FUERA del repositorio y FUERA de OneDrive (el repo está en el Escritorio, que
# OneDrive sincroniza: un respaldo con datos reales no puede subirse a la nube por accidente).
function Resolver-Dir([string]$d) {
    if (-not $d) { $d = Join-Path $env:LOCALAPPDATA 'VanFullBackups' }
    $completa = [IO.Path]::GetFullPath($d)
    foreach ($onedrive in @($env:OneDrive, $env:OneDriveConsumer, $env:OneDriveCommercial)) {
        if ($onedrive -and $completa.StartsWith($onedrive, [StringComparison]::OrdinalIgnoreCase)) {
            Fallar "La carpeta '$completa' esta dentro de OneDrive. Usar otra (por defecto: LOCALAPPDATA\VanFullBackups)."
        }
    }
    $repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
    if ($completa.StartsWith($repo, [StringComparison]::OrdinalIgnoreCase)) {
        Fallar "La carpeta '$completa' esta dentro del repositorio."
    }
    if (-not (Test-Path -LiteralPath $completa)) {
        New-Item -ItemType Directory -Path $completa | Out-Null
        # Solo tu usuario: sin herencia y con control total para vos.
        icacls $completa /inheritance:r /grant:r "${env:USERNAME}:(OI)(CI)F" | Out-Null
        Chequear 'No se pudo proteger la carpeta de respaldos con icacls'
    }
    New-Item -ItemType Directory -Force -Path (Join-Path $completa 'verificacion') | Out-Null
    return $completa
}

# La cadena se pide sin mostrarla y vive solo en la variable de entorno NEON_URL de este proceso:
# nunca se escribe en un archivo, en el chat ni en la línea de comandos de docker (`-e NEON_URL` pasa
# el valor por nombre, como en DESPLIEGUE.md §2).
function Leer-UrlNeon {
    if (-not $env:NEON_URL) {
        $segura = Read-Host 'Cadena DIRECTA de Neon (no se ve al pegar)' -AsSecureString
        $env:NEON_URL = [Net.NetworkCredential]::new('', $segura).Password
    }
    if ($env:NEON_URL -notmatch '^postgres(ql)?://') { Fallar 'No parece una cadena postgresql://' }
    if ($env:NEON_URL -match '-pooler') {
        Fallar 'Es la cadena con pooler (-pooler). pg_dump necesita la DIRECTA (Connect, sin Connection pooling).'
    }
}

# Solo el host, sin usuario ni contraseña: es lo unico del origen que se anota en el registro.
function Host-Saneado {
    try { return ([Uri]($env:NEON_URL -replace '^postgres(ql)?://', 'http://')).Host } catch { return '(no se pudo leer)' }
}

# Lineas de una seccion "== titulo" hasta la siguiente "== ".
function Seccion([string[]]$lineas, [string]$prefijo) {
    $i = 0
    while ($i -lt $lineas.Count -and -not $lineas[$i].StartsWith($prefijo)) { $i++ }
    $r = @()
    $i++
    while ($i -lt $lineas.Count -and -not $lineas[$i].StartsWith('== ')) { $r += $lineas[$i]; $i++ }
    return $r
}
