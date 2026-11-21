# Panel USB: instalación en un PC nuevo (después de descomprimir el .zip).
# Revisa Node.js y adb, prepara config.json y crea los iconos "Panel USB" y "Panel Wi-Fi" en el menú Inicio.
# Uso:  doble clic en instalar.cmd   (o .\instalar.ps1)
param(
    [string]$CarpetaAccesos = (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'),
    [switch]$SinPreguntas   # no ofrece instalar nada; solo informa (útil para pruebas)
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Confirm-Paso([string]$pregunta) {
    if ($SinPreguntas) { return $false }
    $r = Read-Host "$pregunta (S/N)"
    return $r -match '^(s|si|sí|y|yes)$'
}
function Update-RutaSesion {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}
function Find-Adb {
    $cmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidates = @("$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe", "$env:LOCALAPPDATA\Microsoft\WinGet\Links\adb.exe")
    $candidates += Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Google.PlatformTools*" -Recurse -Filter adb.exe -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName
    foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { return $c } }
    return $null
}
$hayWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)

Write-Host ""
Write-Host "=== Instalación de Panel USB ===" -ForegroundColor Cyan
Write-Host "Carpeta: $PSScriptRoot"
Write-Host ""

# 1. Quitar la marca de "descargado de internet" de los archivos del panel, para que Windows no avise en cada uso.
Get-ChildItem $PSScriptRoot -Recurse -File | Unblock-File -ErrorAction SilentlyContinue

# 2. Node.js (obligatorio)
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    Write-Host "[OK] Node.js $(& node --version)" -ForegroundColor Green
} else {
    Write-Host "[FALTA] Node.js: es obligatorio para que funcione el panel." -ForegroundColor Yellow
    if ($hayWinget -and (Confirm-Paso "¿Instalar Node.js LTS ahora con winget?")) {
        winget install -e --id OpenJS.NodeJS.LTS --accept-package-agreements
        Update-RutaSesion
    }
    if (Get-Command node -ErrorAction SilentlyContinue) { Write-Host "[OK] Node.js instalado" -ForegroundColor Green }
    else { Write-Host "       Descárgalo de https://nodejs.org (versión LTS) y vuelve a ejecutar este instalador." }
}

# 3. adb (solo para el modo USB)
$adb = Find-Adb
if ($adb) {
    Write-Host "[OK] adb: $adb" -ForegroundColor Green
} else {
    Write-Host "[FALTA] adb (Android platform-tools): solo se necesita para el modo USB (con cable)." -ForegroundColor Yellow
    if ($hayWinget -and (Confirm-Paso "¿Instalar adb ahora con winget?")) {
        winget install -e --id Google.PlatformTools --accept-package-agreements
        Update-RutaSesion
    }
    if (Find-Adb) { Write-Host "[OK] adb instalado" -ForegroundColor Green }
    else { Write-Host "       Si lo necesitas: https://developer.android.com/tools/releases/platform-tools (descomprime y deja adb.exe en el PATH)." }
}

# 4. Configuración propia
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
Write-Host "Siguientes pasos:" -ForegroundColor Cyan
Write-Host " 1. En el celular Android: Ajustes > Acerca del teléfono > toca 7 veces 'Número de compilación'."
Write-Host "    Luego Opciones de desarrollador > activa 'Depuración USB'."
Write-Host " 2. Conecta el celular por cable y abre 'Panel USB' desde el menú Inicio. Acepta el aviso en el celular."
Write-Host " 3. Para usarlo sin cable: abre 'Panel Wi-Fi' una vez con el cable conectado (autoriza tu celular)."
Write-Host " 4. Personaliza los botones en config.json. Todo está explicado en LEEME.md."
Write-Host ""
