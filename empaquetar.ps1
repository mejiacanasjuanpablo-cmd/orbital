# Genera el .zip para compartir el panel. Nunca incluye tu .token, tu config.json ni tus datos (carpeta data).
# Uso:  .\empaquetar.ps1                      → Orbital.zip en el Escritorio (junto a esta carpeta)
#       .\empaquetar.ps1 -Salida C:\ruta\x.zip
param([string]$Salida)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

# La lista de archivos del programa sale de lib\requisitos.ps1 (la misma que se verifica al instalar y al arrancar).
. (Join-Path $PSScriptRoot 'lib\requisitos.ps1')
if (-not $Salida) { $Salida = Join-Path (Split-Path $PSScriptRoot -Parent) 'Orbital.zip' }
$carpeta = 'Orbital'

# Origen → nombre dentro del .zip
$mapa = [ordered]@{}
foreach ($f in $PanelArchivos + $PanelMiniaturas) { $mapa[$f] = $f }
$mapa['instalar.ps1'] = 'instalar.ps1'; $mapa['instalar.cmd'] = 'instalar.cmd'
$mapa['verificar.ps1'] = 'verificar.ps1'; $mapa['verificar.cmd'] = 'verificar.cmd'
$mapa['LEEME.md'] = 'LEEME.md'

$prohibidos = '\.token$|(^|\\)config\.json$|(^|\\)data\\|debug\.log$'
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
} finally { $zip.Dispose() }

# Comprobación final: el .zip no contiene nada personal.
$zip = [IO.Compression.ZipFile]::OpenRead($Salida)
try {
    $entradas = $zip.Entries | ForEach-Object { $_.FullName -replace '/', '\' }
    $malos = $entradas | Where-Object { $_ -match '\.token$|(^|\\)config\.json$|(^|\\)data\\|debug\.log$' }
} finally { $zip.Dispose() }
if ($malos) { Remove-Item $Salida -Force; throw "El .zip contenía archivos personales y se borró: $($malos -join ', ')" }

Write-Host "Listo: $Salida  ($([math]::Round((Get-Item $Salida).Length / 1KB)) KB, $(@($entradas).Count) archivos)" -ForegroundColor Green
Write-Host "Quien lo reciba: descomprime, doble clic en instalar.cmd y sigue LEEME.md."
