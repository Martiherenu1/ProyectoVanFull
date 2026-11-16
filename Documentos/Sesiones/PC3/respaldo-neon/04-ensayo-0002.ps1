<#
Paso 4 - Ensayo de la migracion 0002 de #281 SOLO sobre la copia restaurada (nunca sobre Neon).
Usa el codigo del commit que le pases (el HEAD de #281), en un checkout aparte (git worktree) dentro de
la carpeta de respaldos, y la imagen del backend de docker compose. El contenedor corre en la red
interna de la copia: no puede llegar a Neon ni a ningun servicio externo, y no recibe ningun .env.
Hace: alembic current / heads / history / upgrade 0002 / current / check / upgrade 0002 (repetida: no
debe cambiar nada) / current. Despues compara la copia ANTES y DESPUES de 0002.
NO ensaya el comportamiento de CU-030 en la API (altas, recuperacion, permisos): eso es otra prueba.
Uso:  .\04-ensayo-0002.ps1 -Commit <SHA del HEAD de #281>   (ver RESPALDO-NEON.md, seccion E)
#>
param(
    [Parameter(Mandatory)][string]$Commit,
    [string]$Dir,
    [string]$Revision = '0002',
    [string]$ImagenBackend = 'proyectovanfull-backend',
    [int]$Pr = 281
)
. "$PSScriptRoot\comun.ps1"

if ($env:NEON_URL) { Fallar 'NEON_URL esta definida en esta sesion. Este paso no usa Neon: cerrar la ventana de PowerShell y abrir otra.' }
$Dir = Resolver-Dir $Dir
$v = Join-Path $Dir 'verificacion'

# --- Precondiciones ----------------------------------------------------------------------------------
if (-not (docker ps -q -f 'name=^vanfull-restore$')) { Fallar 'No esta corriendo vanfull-restore: correr antes 03-restaurar-aislado.ps1.' }
if (-not (Test-Path (Join-Path $v 'copia-pre0002.txt'))) { Fallar 'Falta verificacion\copia-pre0002.txt (lo genera el paso 3).' }
if (Compare-Object (Get-Content (Join-Path $v 'origen-antes.txt')) (Get-Content (Join-Path $v 'copia-pre0002.txt'))) {
    Fallar 'La copia no coincide con el origen (paso 3 no aprobado). No se ensaya sobre una copia dudosa.'
}
docker image inspect $ImagenBackend | Out-Null
if ($LASTEXITCODE -ne 0) { Fallar "No existe la imagen '$ImagenBackend'. Construirla con:  docker compose build backend  (desde la raiz del repo)." }

# --- Codigo exacto a ensayar -------------------------------------------------------------------------
git -C $PSScriptRoot fetch origin --quiet
$completo = (git -C $PSScriptRoot rev-parse --verify "$Commit^{commit}")
Chequear "No se encontro el commit $Commit (git fetch origin y revisar el SHA)"
Write-Host "Commit a ensayar : $completo"
Write-Host ("  " + (git -C $PSScriptRoot log -1 --format='%s' $completo))
$headPr = (gh pr view $Pr --json headRefOid --jq .headRefOid 2>$null)
if ($LASTEXITCODE -eq 0 -and $headPr) {
    if ($headPr.Trim() -eq $completo) { Write-Host "OK  Es el HEAD actual de #$Pr." -ForegroundColor Green }
    else { Write-Host "ATENCION  El HEAD actual de #$Pr es $headPr, distinto del que se ensaya. Si #$Pr cambio, repetir con el nuevo." -ForegroundColor Yellow }
}
$cod = Join-Path $Dir ("codigo-" + $completo.Substring(0, 7))
if (Test-Path -LiteralPath $cod) { Fallar "Ya existe $cod. Correr 05-limpiar.ps1 antes." }
git -C $PSScriptRoot worktree add --detach $cod $completo | Out-Null
Chequear 'No se pudo crear el checkout del codigo'
if (-not (Test-Path (Join-Path $cod 'backend\alembic.ini'))) { Fallar "El commit no tiene backend\alembic.ini" }
if (Test-Path (Join-Path $cod 'backend\.env')) { Fallar 'El checkout trae un backend\.env: no deberia (esta ignorado por git). Avisar.' }

# --- Estado ANTES de 0002 ---------------------------------------------------------------------------
docker exec vanfull-restore sh -c 'psql -U restore -d restaurada -X -A -t -q -v ON_ERROR_STOP=1 -f /sql/historicos.sql > /verif/historicos-pre.txt'
Chequear 'No se pudo calcular el hash de los historicos'

# --- Alembic sobre la copia -------------------------------------------------------------------------
Write-Host ''
Write-Host "Ejecutando alembic en el checkout de $($completo.Substring(0,7)) contra la COPIA (red interna, sin .env)..."
$cadena = "alembic current && alembic heads && alembic history && alembic upgrade $Revision && alembic current && alembic check && alembic upgrade $Revision && alembic current"
docker run --rm --network vanfull-restore-net -v "$cod\backend:/app" -e DATABASE_URL='postgresql://restore@vanfull-restore:5432/restaurada' $ImagenBackend sh -c $cadena
Chequear 'Alembic fallo sobre la copia. Es justamente lo que el ensayo debia detectar: guardar la salida y NO mergear #281'

# --- Estado DESPUES de 0002 -------------------------------------------------------------------------
docker exec vanfull-restore sh -c 'psql -U restore -d restaurada -X -A -t -q -v ON_ERROR_STOP=1 -f /sql/manifiesto.sql > /verif/copia-post0002.txt'
Chequear 'No se pudo generar el manifiesto posterior'
docker exec vanfull-restore sh -c 'psql -U restore -d restaurada -X -A -t -q -v ON_ERROR_STOP=1 -f /sql/historicos.sql > /verif/historicos-post.txt'
Chequear 'No se pudo calcular el hash posterior de los historicos'

Write-Host ''
Write-Host '--- VEREDICTO ---'
$fallos = 0
$pre = Get-Content (Join-Path $v 'copia-pre0002.txt')
$post = Get-Content (Join-Path $v 'copia-post0002.txt')

# 1) Los historicos de evento_operativo no cambiaron y siguen sin autor ni clave.
$hPre = Get-Content (Join-Path $v 'historicos-pre.txt')
$hPost = Get-Content (Join-Path $v 'historicos-post.txt')
if (-not (Compare-Object $hPre $hPost)) {
    Write-Host ("OK  Historicos de evento_operativo intactos y con metadatos NULL: " + $hPost[1]) -ForegroundColor Green
} else { Write-Host 'NO  Los historicos de evento_operativo CAMBIARON.' -ForegroundColor Red; $hPre; $hPost; $fallos++ }

# 2) Las unicas diferencias entre antes y despues son las esperadas (evento_operativo y alembic_version).
$permitido = @(
    '^evento_operativo( \||\.)',
    '^alembic_version \|',
    '^000[12]$',
    '^CREATE UNIQUE INDEX uq_aviso_solicitud ON public\.evento_operativo '
)
$dif = @(Compare-Object $pre $post)
$inesperadas = @($dif | Where-Object { $linea = $_.InputObject; -not ($permitido | Where-Object { $linea -match $_ }) })
if ($inesperadas.Count -eq 0) {
    Write-Host ("OK  Las " + $dif.Count + " lineas que cambiaron del manifiesto son todas de evento_operativo y alembic_version.") -ForegroundColor Green
} else {
    Write-Host 'NO  Cambiaron cosas que 0002 no deberia tocar:' -ForegroundColor Red
    $inesperadas | ForEach-Object { Write-Host ("   " + $_.InputObject) }
    $fallos++
}

# 3) Lo nuevo esta, con el tipo y la validacion esperados.
$esperado = @(
    @{ Que = 'columna id_cuenta_autora (bigint, nullable)'; Patron = '^evento_operativo\.\d+ id_cuenta_autora bigint YES' },
    @{ Que = 'columna clave_solicitud (uuid, nullable)'; Patron = '^evento_operativo\.\d+ clave_solicitud uuid YES' },
    @{ Que = 'FK evento_operativo_id_cuenta_autora_fkey (validada)'; Patron = '^evento_operativo \| evento_operativo_id_cuenta_autora_fkey \| f \| validada=true \| FOREIGN KEY \(id_cuenta_autora\) REFERENCES cuenta_acceso\(id_cuenta_acceso\)' },
    @{ Que = 'UNIQUE uq_aviso_solicitud (autora, viaje, clave)'; Patron = '^evento_operativo \| uq_aviso_solicitud \| u \| validada=true \| UNIQUE \(id_cuenta_autora, id_viaje, clave_solicitud\)' },
    @{ Que = 'CHECK ck_aviso_metadatos (validada)'; Patron = '^evento_operativo \| ck_aviso_metadatos \| c \| validada=true' },
    @{ Que = 'alembic_version = 0002'; Patron = '^0002$' }
)
foreach ($e in $esperado) {
    if ($post | Where-Object { $_ -match $e.Patron }) { Write-Host ("OK  " + $e.Que) -ForegroundColor Green }
    else { Write-Host ("NO  falta: " + $e.Que) -ForegroundColor Red; $fallos++ }
}

# 4) Definicion real del CHECK nuevo (para leerla y cotejarla con schema.sql / 0002).
Write-Host ''
Write-Host 'Definicion del CHECK en la copia (para cotejar con schema.sql y la migracion):'
docker exec vanfull-restore psql -U restore -d restaurada -X -A -t -q -c "select pg_get_constraintdef(oid) from pg_constraint where conname = 'ck_aviso_metadatos'"

Write-Host ''
if ($fallos -eq 0) {
    Write-Host 'ENSAYO DE 0002 SOBRE LA COPIA: APROBADO.' -ForegroundColor Green
    Write-Host 'Evidencia (sin datos) para #281: SHA ensayado, salida de alembic de arriba, los OK de este veredicto.'
} else {
    Write-Host "ENSAYO DE 0002 SOBRE LA COPIA: $fallos problema(s). NO mergear #281." -ForegroundColor Red
    throw 'Ensayo de 0002 no aprobado'
}
