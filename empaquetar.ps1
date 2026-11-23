# Genera el .zip para compartir el panel. Nunca incluye tu .token, tu config.json ni tus tareas.
# Uso:  .\empaquetar.ps1                        edición solo Wi-Fi  → Panel-WiFi.zip en el Escritorio (junto a esta carpeta)
#       .\empaquetar.ps1 -Edicion Completa      USB y Wi-Fi         → Panel-USB.zip
#       .\empaquetar.ps1 -Salida C:\ruta\x.zip
param(
    [ValidateSet('Wifi', 'Completa')][string]$Edicion = 'Wifi',
    [string]$Salida
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

# La lista de archivos del programa sale de lib\requisitos.ps1 (la misma que se verifica al instalar y al arrancar).
. (Join-Path $PSScriptRoot 'lib\requisitos.ps1')
$soloWifi = $Edicion -eq 'Wifi'
if (-not $Salida) { $Salida = Join-Path (Split-Path $PSScriptRoot -Parent) $(if ($soloWifi) { 'Panel-WiFi.zip' } else { 'Panel-USB.zip' }) }
$carpeta = if ($soloWifi) { 'Panel-WiFi' } else { 'Panel-USB' }

# Origen → nombre dentro del .zip
$mapa = [ordered]@{}
$programa = if ($soloWifi) { $PanelArchivosComunes } else { $PanelArchivosComunes + 'iniciar-wifi.cmd' }
$programa += $PanelMiniaturas
foreach ($f in $programa) { $mapa[$f] = $f }
$mapa['instalar.ps1'] = 'instalar.ps1'; $mapa['instalar.cmd'] = 'instalar.cmd'
$mapa['verificar.ps1'] = 'verificar.ps1'; $mapa['verificar.cmd'] = 'verificar.cmd'
if ($soloWifi) {
    $mapa['LEEME-wifi.md'] = 'LEEME.md'
    # En la edición Wi-Fi, iniciar.cmd abre directamente el modo Wi-Fi (iniciar.ps1 lo detecta por esta marca).
    $marca = "Esta copia del Panel del PC funciona solo por Wi-Fi.`r`nNo borres este archivo: con él, iniciar.cmd abre siempre el modo Wi-Fi y no se usa adb ni el cable.`r`n"
} else {
    $mapa['LEEME.md'] = 'LEEME.md'
}

$prohibidos = '\.token$|(^|\\)config\.json$|(^|\\)data\\|debug\.log$|EDICION-WIFI\.txt$'
foreach ($f in $mapa.Keys) {
    if ($f -match $prohibidos) { throw "Archivo personal en la lista: $f" }
    if (-not (Test-Path (Join-Path $PSScriptRoot $f))) { throw "Falta el archivo: $f" }
}
if (Test-Path $Salida) { Remove-Item $Salida -Force }

# Las rutas dentro del .zip usan "/" para que cualquier descompresor las entienda.
$zip = [IO.Compression.ZipFile]::Open($Salida, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($f in $mapa.Keys) {
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $PSScriptRoot $f), "$carpeta/" + ($mapa[$f] -replace '\\', '/'), [IO.Compression.CompressionLevel]::Optimal)
    }
    if ($soloWifi) {
        $w = New-Object IO.StreamWriter(($zip.CreateEntry("$carpeta/$PanelMarcaWifi")).Open(), (New-Object Text.UTF8Encoding $true))
        $w.Write($marca); $w.Dispose()
    }
} finally { $zip.Dispose() }

# Comprobación final: el .zip no contiene nada personal.
$zip = [IO.Compression.ZipFile]::OpenRead($Salida)
try {
    $entradas = $zip.Entries | ForEach-Object { $_.FullName -replace '/', '\' }
    $malos = $entradas | Where-Object { $_ -match '\.token$|(^|\\)config\.json$|(^|\\)data\\|debug\.log$' }
} finally { $zip.Dispose() }
if ($malos) { Remove-Item $Salida -Force; throw "El .zip contenía archivos personales y se borró: $($malos -join ', ')" }

Write-Host "Listo ($(if ($soloWifi) { 'edición solo Wi-Fi' } else { 'edición completa: USB y Wi-Fi' })): $Salida  ($([math]::Round((Get-Item $Salida).Length / 1KB)) KB, $(@($entradas).Count) archivos)" -ForegroundColor Green
Write-Host "Quien lo reciba: descomprime, doble clic en instalar.cmd y sigue LEEME.md."
