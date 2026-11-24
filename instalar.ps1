# Orbital: instalación en un PC nuevo (después de descomprimir el .zip).
# Revisa los requisitos (y ofrece instalar lo que falte), prepara config.json, crea "Orbital.exe" (la ventana del
# panel, sin consola) y el icono "Orbital" en el menú Inicio (y quita los "Panel del PC", "Panel USB" y "Panel Wi-Fi" de
# versiones anteriores, si apuntan a esta carpeta).
# Uso:  doble clic en instalar.cmd   (o .\instalar.ps1)
param(
    [string]$CarpetaAccesos = (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'),
    [switch]$SinPreguntas   # no ofrece instalar nada; solo informa (útil para pruebas)
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

# 1. Quitar la marca de "descargado de internet" de los archivos del panel, para que Windows no avise en cada uso.
Get-ChildItem $PSScriptRoot -Recurse -File | Unblock-File -ErrorAction SilentlyContinue

if (-not (Test-Path (Join-Path $PSScriptRoot 'lib\requisitos.ps1')) -or -not (Test-Path (Join-Path $PSScriptRoot 'lib\arranque.ps1'))) {
    Write-Host "Faltan archivos del panel. Vuelve a descomprimir el .zip del panel completo." -ForegroundColor Red; exit 1
}
. (Join-Path $PSScriptRoot 'lib\requisitos.ps1')
. (Join-Path $PSScriptRoot 'lib\arranque.ps1')

Write-Host ""
Write-Host "=== Instalación de Orbital ===" -ForegroundColor Cyan
Write-Host "Carpeta: $PSScriptRoot"

# 2. Requisitos: revisa todo y ofrece instalar lo que falte.
$listo = Invoke-Verificacion -Raiz $PSScriptRoot -Instalar -SinPreguntas:$SinPreguntas
Write-Host ""

# 3. Configuración propia
$cfg = Join-Path $PSScriptRoot 'config.json'
if (Test-Path $cfg) { Write-Host "[OK] config.json ya existe (no se toca)" -ForegroundColor Green }
else { Copy-Item (Join-Path $PSScriptRoot 'config.ejemplo.json') $cfg; Write-Host "[OK] config.json creado a partir del ejemplo" -ForegroundColor Green }

# 4. La ventana del panel: Orbital.exe se compila aquí con el compilador de C# que trae Windows.
$exe = Build-PanelVentana $PSScriptRoot
if ($exe) {
    Write-Host "[OK] Ventana del panel lista: Orbital.exe" -ForegroundColor Green
    # El de antes de llamarse Orbital sobra (si está abierto, se queda; iniciar.cmd ya abre el nuevo).
    Remove-Item (Join-Path $PSScriptRoot 'Panel del PC.exe') -ErrorAction SilentlyContinue
}
else { Write-Host "[AVISO] No se pudo crear Orbital.exe; el icono abrirá la ventana con PowerShell (funciona igual)." -ForegroundColor Yellow }

# 5. Icono en el menú Inicio: abre la ventana del panel, sin consola.
$shell = New-Object -ComObject WScript.Shell
# Los iconos de versiones anteriores se quitan si son de esta carpeta: «Panel del PC» (el nombre de antes) y, antes aún,
# uno para el cable y otro para el Wi-Fi.
foreach ($viejo in 'Panel del PC', 'Panel USB', 'Panel Wi-Fi') {
    $ruta = Join-Path $CarpetaAccesos "$viejo.lnk"
    if ((Test-Path $ruta) -and $shell.CreateShortcut($ruta).WorkingDirectory -eq $PSScriptRoot) { Remove-Item $ruta -ErrorAction SilentlyContinue }
}
$lnk = $shell.CreateShortcut((Join-Path $CarpetaAccesos 'Orbital.lnk'))
if ($exe) {
    $lnk.TargetPath = $exe
    $lnk.Arguments = ''
} else {
    $lnk.TargetPath = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $lnk.Arguments = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$(Join-Path $PSScriptRoot 'ventana.ps1')`""
    $lnk.WindowStyle = 7   # minimizada: así la consola de PowerShell no llega a verse
}
$lnk.WorkingDirectory = $PSScriptRoot
$lnk.IconLocation = "$(Join-Path $PSScriptRoot 'panel.ico'),0"
$lnk.Description = 'Orbital: tu PC en el celular, por Wi-Fi'
$lnk.Save()
Write-Host "[OK] Icono 'Orbital' creado en el menú Inicio" -ForegroundColor Green

Write-Host ""
if (-not $listo) {
    Write-Host "Atención: falta algo obligatorio (ver arriba). Cuando lo resuelvas, ejecuta verificar.cmd para comprobarlo." -ForegroundColor Red
    Write-Host ""
}
Write-Host "Siguientes pasos:" -ForegroundColor Cyan
Write-Host " No hay que instalar ni activar nada en el celular; solo tiene que estar en la misma red Wi-Fi que el PC."
Write-Host "   1. Abre 'Orbital' desde el menú Inicio y escanea con la cámara del celular el código QR de la ventana."
Write-Host "   2. En el PC aparecerá un aviso para aprobar el celular: pulsa Sí."
Write-Host "   3. En el celular, en Chrome: menú ⋮ > Agregar a pantalla principal."
Write-Host " Personaliza los botones en config.json. Todo está explicado en LEEME.md."
Write-Host ""
