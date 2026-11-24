# Genera el ejecutable portátil del panel: un solo "Orbital.exe" con todo el panel y Node.js dentro, para
# compartirlo y probarlo en otros PC. Quien lo recibe solo le hace doble clic: no tiene que instalar Node.js ni nada más
# (cómo se prepara al abrirlo: lib\portatil.cs).
# Usa el Node.js de este PC (el de "node" en el PATH) y el compilador de C# que trae Windows. Nunca incluye tu .token,
# tu config.json ni la carpeta data.
# Uso:  .\herramientas\portatil.ps1                        → "Orbital.exe" en el Escritorio (junto a la carpeta del panel)
#       .\herramientas\portatil.ps1 -Salida C:\ruta\x.exe
param([string]$Salida)
$ErrorActionPreference = 'Stop'
$Raiz = Split-Path $PSScriptRoot -Parent
. (Join-Path $Raiz 'lib\requisitos.ps1')   # $PanelArchivos, $PanelMiniaturas, Invoke-Oculto
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
if (-not $Salida) { $Salida = Join-Path (Split-Path $Raiz -Parent) 'Orbital.exe' }
# Un .exe abierto no se puede reemplazar: se avisa antes de compilar.
if (Test-Path $Salida) {
    try { [IO.File]::Open($Salida, 'Open', 'ReadWrite', 'None').Dispose() }
    catch { throw "No se puede reemplazar «$Salida»: está abierto (por ejemplo, el panel en marcha desde ese archivo). Ciérralo con «Detener el panel» y vuelve a ejecutar esto, o usa -Salida con otra ruta." }
}

# 1. Node.js de este PC
$node = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $node -or $node -notmatch '\.exe$') { throw 'No se encontró Node.js (node.exe) en este PC: hace falta para generar el ejecutable.' }
$versionNode = "$(& $node --version)".Trim()
if ([version]($versionNode -replace '^v', '') -lt $PanelNodeMinimo) { throw "Node.js $versionNode es muy antiguo; se necesita $($PanelNodeMinimo.Major) o superior." }

# 2. Todo el panel en un .zip: los mismos archivos que el .zip para compartir (sin el instalador) y Node.js
$tmp = Join-Path ([IO.Path]::GetTempPath()) "panel-portatil-$PID"
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $tmp | Out-Null
try {
    $zipRuta = Join-Path $tmp 'panel.zip'
    $archivos = @($PanelArchivos) + @($PanelMiniaturas) + 'verificar.ps1', 'verificar.cmd', 'LEEME.md'
    $prohibidos = '\.token$|(^|\\)config\.json$|(^|\\)data\\|debug\.log$'
    $aviso = @"
Este programa incluye Node.js $versionNode (https://nodejs.org), en la carpeta node.
This program includes Node.js $versionNode (https://nodejs.org), in the node folder.

Node.js is licensed for use as follows:

"""
Copyright Node.js contributors. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to
deal in the Software without restriction, including without limitation the
rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
IN THE SOFTWARE.
"""

Node.js also includes third-party components under their own licenses. The full text of every license for this
version is in https://github.com/nodejs/node/blob/$versionNode/LICENSE
"@
    $zip = [IO.Compression.ZipFile]::Open($zipRuta, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($f in $archivos) {
            if ($f -match $prohibidos) { throw "Archivo personal en la lista: $f" }
            $ruta = Join-Path $Raiz $f
            if (-not (Test-Path $ruta)) { throw "Falta el archivo: $f" }
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $ruta, ($f -replace '\\', '/'), [IO.Compression.CompressionLevel]::Optimal)
        }
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $node, 'node/node.exe', [IO.Compression.CompressionLevel]::Optimal)
        $entrada = $zip.CreateEntry('node/AVISO-NODEJS.txt')
        $entrada.LastWriteTime = (Get-Item $node).LastWriteTime # fecha fija: si nada cambia, la versión tampoco
        $w = New-Object IO.StreamWriter($entrada.Open(), (New-Object Text.UTF8Encoding $true))
        $w.Write($aviso -replace "`r?`n", "`r`n"); $w.Dispose()
    } finally { $zip.Dispose() }

    # Comprobación: nada personal dentro
    $z = [IO.Compression.ZipFile]::OpenRead($zipRuta)
    try { $entradas = @($z.Entries | ForEach-Object { $_.FullName -replace '/', '\' }) } finally { $z.Dispose() }
    $malos = @($entradas | Where-Object { $_ -match $prohibidos })
    if ($malos.Count) { throw "El paquete contenía archivos personales: $($malos -join ', ')" }

    # 3. Versión: la huella del .zip (cambia si cambia cualquier archivo); con ella el .exe sabe si tiene que actualizar.
    $version = (Get-FileHash $zipRuta -Algorithm SHA256).Hash.Substring(0, 16).ToLower()
    $versionRuta = Join-Path $tmp 'panel.version'
    [IO.File]::WriteAllText($versionRuta, $version)

    # 4. Compilar: lib\lanzador.cs + lib\portatil.cs, con el .zip y la versión dentro
    $csc = Join-Path ([Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()) 'csc.exe'
    $sma = "$env:WINDIR\Microsoft.NET\assembly\GAC_MSIL\System.Management.Automation\v4.0_3.0.0.0__31bf3856ad364e35\System.Management.Automation.dll"
    if (-not (Test-Path $sma)) { $sma = [PSObject].Assembly.Location }
    if (-not (Test-Path $csc)) { throw 'No se encontró el compilador de C# de Windows (.NET Framework 4).' }
    $exeTmp = Join-Path $tmp 'Orbital.exe'
    $r = Invoke-Oculto $csc @('/nologo', '/target:winexe', '/optimize+', "/out:$exeTmp", "/win32icon:$(Join-Path $Raiz 'panel.ico')",
        "/r:$sma", '/r:System.Windows.Forms.dll', '/r:System.Drawing.dll', '/r:System.IO.Compression.dll', '/r:System.IO.Compression.FileSystem.dll',
        "/resource:$zipRuta,panel.zip", "/resource:$versionRuta,panel.version",
        (Join-Path $Raiz 'lib\lanzador.cs'), (Join-Path $Raiz 'lib\portatil.cs')) -EsperaMs 180000
    if ($r.Codigo -ne 0 -or -not (Test-Path $exeTmp)) { throw "No se pudo compilar el ejecutable:`n$($r.Salida)" }
    Move-Item $exeTmp $Salida -Force
} finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Listo: $Salida ($([math]::Round((Get-Item $Salida).Length / 1MB, 1)) MB; $($entradas.Count) archivos, con Node.js $versionNode; versión $version)" -ForegroundColor Green
Write-Host "Quien lo reciba: doble clic. La primera vez se prepara en %LOCALAPPDATA%\Panel del PC y deja el icono Orbital en el menú Inicio."
