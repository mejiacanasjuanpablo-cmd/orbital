# Panel USB: instalación en un PC nuevo (después de descomprimir el .zip).
# Revisa los requisitos (y ofrece instalar Node.js y adb), prepara config.json y crea los iconos
# "Panel USB" y "Panel Wi-Fi" en el menú Inicio.
# Uso:  doble clic en instalar.cmd   (o .\instalar.ps1)
param(
    [string]$CarpetaAccesos = (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'),
    [switch]$SinPreguntas   # no ofrece instalar nada; solo informa (útil para pruebas)
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

Write-Host ""
Write-Host "=== Instalación de Panel USB ===" -ForegroundColor Cyan
Write-Host "Carpeta: $PSScriptRoot"

# 1. Quitar la marca de "descargado de internet" de los archivos del panel, para que Windows no avise en cada uso.
Get-ChildItem $PSScriptRoot -Recurse -File | Unblock-File -ErrorAction SilentlyContinue

if (-not (Test-Path (Join-Path $PSScriptRoot 'lib\requisitos.ps1'))) {
    Write-Host "Falta lib\requisitos.ps1. Vuelve a descomprimir Panel-USB.zip completo." -ForegroundColor Red; exit 1
}
. (Join-Path $PSScriptRoot 'lib\requisitos.ps1')

# 2. Requisitos: revisa todo y ofrece instalar Node.js y adb si faltan.
$listo = Invoke-Verificacion -Raiz $PSScriptRoot -Instalar -SinPreguntas:$SinPreguntas
Write-Host ""

# 3. Configuración propia
$cfg = Join-Path $PSScriptRoot 'config.json'
if (Test-Path $cfg) { Write-Host "[OK] config.json ya existe (no se toca)" -ForegroundColor Green }
else { Copy-Item (Join-Path $PSScriptRoot 'config.ejemplo.json') $cfg; Write-Host "[OK] config.json creado a partir del ejemplo" -ForegroundColor Green }

# 5. Iconos en el menú Inicio
$shell = New-Object -ComObject WScript.Shell
foreach ($a in @(
    @{ n = 'Panel USB';   f = 'iniciar.cmd';      d = 'Panel del PC en el celular por cable USB' },
    @{ n = 'Panel Wi-Fi'; f = 'iniciar-wifi.cmd'; d = 'Panel del PC en el celular por Wi-Fi' })) {
    $lnk = $shell.CreateShortcut((Join-Path $CarpetaAccesos "$($a.n).lnk"))
    $lnk.TargetPath = Join-Path $env:WINDIR 'System32\cmd.exe'
    $lnk.Arguments = "/c `"$(Join-Path $PSScriptRoot $a.f)`""
    $lnk.WorkingDirectory = $PSScriptRoot
    $lnk.IconLocation = "$(Join-Path $PSScriptRoot 'panel.ico'),0"
    $lnk.Description = $a.d
    $lnk.Save()
}
Write-Host "[OK] Iconos 'Panel USB' y 'Panel Wi-Fi' creados en el menú Inicio" -ForegroundColor Green

Write-Host ""
if (-not $listo) {
    Write-Host "Atención: falta algo obligatorio (ver arriba). Cuando lo resuelvas, ejecuta verificar.cmd para comprobarlo." -ForegroundColor Red
    Write-Host ""
}
Write-Host "Siguientes pasos:" -ForegroundColor Cyan
Write-Host " 1. En el celular Android: Ajustes > Acerca del teléfono > toca 7 veces 'Número de compilación'."
Write-Host "    Luego Opciones de desarrollador > activa 'Depuración USB'."
Write-Host " 2. Conecta el celular por cable y abre 'Panel USB' desde el menú Inicio. Acepta el aviso en el celular."
Write-Host " 3. Para usarlo sin cable: abre 'Panel Wi-Fi' una vez con el cable conectado (autoriza tu celular)."
Write-Host " 4. Personaliza los botones en config.json. Todo está explicado en LEEME.md."
Write-Host ""
