<#
Paso 5 - Limpieza de la copia aislada. NO toca Neon y NO borra el respaldo.
Quita: el contenedor vanfull-restore, su volumen vanfull-restore-data, la red vanfull-restore-net y el
checkout del codigo de #281 (git worktree) si existe.
Se conservan: el .dump, el registro y la carpeta verificacion\ (la retencion del respaldo es una decision
del equipo; no se borra solo).
Uso:  .\05-limpiar.ps1
#>
param([string]$Dir)
. "$PSScriptRoot\comun.ps1"
$Dir = Resolver-Dir $Dir

if (docker ps -aq -f 'name=^vanfull-restore$') { docker rm -f vanfull-restore | Out-Null; Write-Host 'Contenedor vanfull-restore: borrado' }
if (docker volume ls -q -f 'name=^vanfull-restore-data$') { docker volume rm vanfull-restore-data | Out-Null; Write-Host 'Volumen vanfull-restore-data: borrado' }
if (docker network ls -q -f 'name=^vanfull-restore-net$') { docker network rm vanfull-restore-net | Out-Null; Write-Host 'Red vanfull-restore-net: borrada' }
Get-ChildItem -LiteralPath $Dir -Directory -Filter 'codigo-*' -ErrorAction SilentlyContinue | ForEach-Object {
    git -C $PSScriptRoot worktree remove --force $_.FullName
    Write-Host "Checkout $($_.Name): quitado"
}
Write-Host ''
Write-Host "Se conserva el respaldo en: $Dir"
Get-ChildItem -LiteralPath $Dir -Filter 'neon-pre-0002-*.dump' | ForEach-Object { Write-Host ("  " + $_.Name + "  " + $_.Length + " bytes") }
