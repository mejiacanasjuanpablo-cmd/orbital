# Panel del PC: instalación en un PC nuevo (después de descomprimir el .zip).
# Revisa los requisitos (y ofrece instalar lo que falte), prepara config.json y crea los iconos en el menú Inicio:
#  - edición completa: "Panel USB" (cable) y "Panel Wi-Fi";
#  - edición solo Wi-Fi (con EDICION-WIFI.txt): solo "Panel Wi-Fi".
# Uso:  doble clic en instalar.cmd   (o .\instalar.ps1)
param(
    [string]$CarpetaAccesos = (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'),
    [switch]$SinPreguntas   # no ofrece instalar nada; solo informa (útil para pruebas)
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

# 1. Quitar la marca de "descargado de internet" de los archivos del panel, para que Windows no avise en cada uso.
Get-ChildItem $PSScriptRoot -Recurse -File | Unblock-File -ErrorAction SilentlyContinue

if (-not (Test-Path (Join-Path $PSScriptRoot 'lib\requisitos.ps1'))) {
    Write-Host "Falta lib\requisitos.ps1. Vuelve a descomprimir el .zip del panel completo." -ForegroundColor Red; exit 1
}
. (Join-Path $PSScriptRoot 'lib\requisitos.ps1')

Write-Host ""
Write-Host "=== Instalación del Panel del PC$(if ($PanelSoloWifi) { ' (edición Wi-Fi)' }) ===" -ForegroundColor Cyan
Write-Host "Carpeta: $PSScriptRoot"

# 2. Requisitos: revisa todo y ofrece instalar lo que falte.
$listo = Invoke-Verificacion -Raiz $PSScriptRoot -Instalar -SinPreguntas:$SinPreguntas
Write-Host ""

# 3. Configuración propia
$cfg = Join-Path $PSScriptRoot 'config.json'
if (Test-Path $cfg) { Write-Host "[OK] config.json ya existe (no se toca)" -ForegroundColor Green }
else { Copy-Item (Join-Path $PSScriptRoot 'config.ejemplo.json') $cfg; Write-Host "[OK] config.json creado a partir del ejemplo" -ForegroundColor Green }

# 4. Iconos en el menú Inicio
$iconos = if ($PanelSoloWifi) {
    @(@{ n = 'Panel Wi-Fi'; f = 'iniciar.cmd'; d = 'Panel del PC en el celular por Wi-Fi' })
} else {
    @(@{ n = 'Panel USB';   f = 'iniciar.cmd';      d = 'Panel del PC en el celular por cable USB' },
      @{ n = 'Panel Wi-Fi'; f = 'iniciar-wifi.cmd'; d = 'Panel del PC en el celular por Wi-Fi' })
}
$shell = New-Object -ComObject WScript.Shell
foreach ($a in $iconos) {
    $lnk = $shell.CreateShortcut((Join-Path $CarpetaAccesos "$($a.n).lnk"))
    $lnk.TargetPath = Join-Path $env:WINDIR 'System32\cmd.exe'
    $lnk.Arguments = "/c `"$(Join-Path $PSScriptRoot $a.f)`""
    $lnk.WorkingDirectory = $PSScriptRoot
    $lnk.IconLocation = "$(Join-Path $PSScriptRoot 'panel.ico'),0"
    $lnk.Description = $a.d
    $lnk.Save()
}
Write-Host "[OK] Icono(s) $(($iconos | ForEach-Object { "'$($_.n)'" }) -join ' y ') creado(s) en el menú Inicio" -ForegroundColor Green

Write-Host ""
if (-not $listo) {
    Write-Host "Atención: falta algo obligatorio (ver arriba). Cuando lo resuelvas, ejecuta verificar.cmd para comprobarlo." -ForegroundColor Red
    Write-Host ""
}
Write-Host "Siguientes pasos:" -ForegroundColor Cyan
if ($PanelSoloWifi) {
    Write-Host " No hay que instalar ni activar nada en el celular; solo tiene que estar en la misma red Wi-Fi que el PC."
    Write-Host "   1. Abre 'Panel Wi-Fi' desde el menú Inicio y escanea con la cámara del celular el código QR de la ventana."
    Write-Host "   2. En el PC aparecerá un aviso para aprobar el celular: pulsa Sí."
    Write-Host "   3. En el celular, en Chrome: menú ⋮ > Agregar a pantalla principal."
} else {
    Write-Host " Por Wi-Fi (no hay que tocar nada del celular):"
    Write-Host "   1. Abre 'Panel Wi-Fi' desde el menú Inicio y escanea con la cámara del celular el código QR de la ventana."
    Write-Host "   2. En el PC aparecerá un aviso para aprobar el celular: pulsa Sí."
    Write-Host " Por cable (USB):"
    Write-Host "   1. En el celular: Ajustes > Acerca del teléfono > toca 7 veces 'Número de compilación';"
    Write-Host "      luego Opciones de desarrollador > activa 'Depuración USB'."
    Write-Host "   2. Conecta el cable y abre 'Panel USB' desde el menú Inicio. Acepta el aviso en el celular."
}
Write-Host " Personaliza los botones en config.json. Todo está explicado en LEEME.md."
Write-Host ""
