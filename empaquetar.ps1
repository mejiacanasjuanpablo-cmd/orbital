# Genera Panel-USB.zip para compartir el panel.
# Solo incluye los archivos de esta lista: nunca tu .token, tu config.json ni tus tareas.
# Uso:  .\empaquetar.ps1                      (crea Panel-USB.zip junto a esta carpeta, en el Escritorio)
#       .\empaquetar.ps1 -Salida C:\ruta\x.zip
param([string]$Salida = (Join-Path (Split-Path $PSScriptRoot -Parent) 'Panel-USB.zip'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

# Los archivos del programa salen de lib\requisitos.ps1 (la misma lista que se verifica al instalar y al arrancar),
# más la guía, el instalador y el verificador.
. (Join-Path $PSScriptRoot 'lib\requisitos.ps1')
$incluir = @($PanelArchivos) + @('LEEME.md', 'instalar.ps1', 'instalar.cmd', 'verificar.ps1', 'verificar.cmd')
$prohibidos = '\.token$|(^|\\)config\.json$|(^|\\)data\\|debug\.log$'

foreach ($f in $incluir) {
    if ($f -match $prohibidos) { throw "Archivo personal en la lista: $f" }
    if (-not (Test-Path (Join-Path $PSScriptRoot $f))) { throw "Falta el archivo: $f" }
}
if (Test-Path $Salida) { Remove-Item $Salida -Force }

# Las rutas dentro del .zip usan "/" para que cualquier descompresor las entienda.
$zip = [IO.Compression.ZipFile]::Open($Salida, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($f in $incluir) {
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $PSScriptRoot $f), ('Panel-USB/' + ($f -replace '\\', '/')), [IO.Compression.CompressionLevel]::Optimal)
    }
} finally { $zip.Dispose() }

# Comprobación final: el .zip no contiene nada personal.
$zip = [IO.Compression.ZipFile]::OpenRead($Salida)
try {
    $entradas = $zip.Entries | ForEach-Object { $_.FullName -replace '/', '\' }
    $malos = $entradas | Where-Object { $_ -match $prohibidos }
} finally { $zip.Dispose() }
if ($malos) { Remove-Item $Salida -Force; throw "El .zip contenía archivos personales y se borró: $($malos -join ', ')" }

Write-Host "Listo: $Salida  ($([math]::Round((Get-Item $Salida).Length / 1KB)) KB, $(@($entradas).Count) archivos)" -ForegroundColor Green
Write-Host "Quien lo reciba: descomprime, doble clic en instalar.cmd y sigue LEEME.md."
