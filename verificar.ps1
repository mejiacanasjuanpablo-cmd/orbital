# Panel USB: revisa todo lo que necesita el panel y ofrece instalar lo que falte (Node.js, adb).
# Uso:  doble clic en verificar.cmd   (o .\verificar.ps1)
param(
    [int]$Puerto = 8787,
    [switch]$SinPreguntas   # solo revisa; no ofrece instalar nada
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (-not (Test-Path (Join-Path $PSScriptRoot 'lib\requisitos.ps1'))) {
    Write-Host "Falta lib\requisitos.ps1. Vuelve a descomprimir Panel-USB.zip completo." -ForegroundColor Red; exit 1
}
. (Join-Path $PSScriptRoot 'lib\requisitos.ps1')

Write-Host "=== Verificación de requisitos de Panel USB ===" -ForegroundColor Cyan
$ok = Invoke-Verificacion -Raiz $PSScriptRoot -Puerto $Puerto -Instalar -SinPreguntas:$SinPreguntas
exit $(if ($ok) { 0 } else { 1 })
