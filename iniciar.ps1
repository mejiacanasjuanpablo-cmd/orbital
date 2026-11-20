# Panel USB: arranca el servidor local y lo abre en el celular Android por USB.
# Uso:  .\iniciar.ps1            (con el celular conectado y la depuración USB activada)
#       .\iniciar.ps1 -SoloPC    (sin celular: lo abre en el navegador del PC)
param(
    [int]$Puerto = 8787,
    [switch]$SoloPC
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Find-Adb {
    $cmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidates = @(
        "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
        "$env:LOCALAPPDATA\Microsoft\WinGet\Links\adb.exe"
    )
    $candidates += Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Google.PlatformTools*" -Recurse -Filter adb.exe -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName
    foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { return $c } }
    return $null
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "No se encontró Node.js. Instálalo desde https://nodejs.org" -ForegroundColor Red; exit 1
}

# Token fijo guardado en .token, para que el icono de la pantalla de inicio siga funcionando.
# Para invalidarlo (por ejemplo, si cambias de celular), borra el archivo .token.
$tokenFile = Join-Path $PSScriptRoot '.token'
$token = if (Test-Path $tokenFile) { (Get-Content $tokenFile -Raw).Trim() } else { '' }
if ($token -notmatch '^[0-9a-f]{32,}$') {
    $bytes = New-Object byte[] 24
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $token = -join ($bytes | ForEach-Object { $_.ToString('x2') })
    Set-Content -Path $tokenFile -Value $token -NoNewline -Encoding ascii
}
$url = "http://localhost:$Puerto/#t=$token"

$adb = $null
$serial = $null
if (-not $SoloPC) {
    $adb = Find-Adb
    if (-not $adb) {
        Write-Host "No se encontró adb (Android platform-tools)." -ForegroundColor Yellow
        Write-Host "Instálalo con:  winget install Google.PlatformTools   y vuelve a abrir la terminal."
        Write-Host "O ejecuta  .\iniciar.ps1 -SoloPC  para probar el panel en este PC." ; exit 1
    }
    & $adb start-server | Out-Null
    $devices = & $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '\S' }
    $ready = $devices | Where-Object { $_ -match '\tdevice$' }
    if (-not $ready) {
        if ($devices -match 'unauthorized') {
            Write-Host "El celular no ha autorizado este PC: desbloquéalo y acepta 'Permitir depuración USB'." -ForegroundColor Yellow
        } else {
            Write-Host "No hay ningún celular conectado con la depuración USB activada." -ForegroundColor Yellow
            Write-Host "Ajustes > Acerca del teléfono > toca 7 veces 'Número de compilación' > Opciones de desarrollador > Depuración USB."
        }
        exit 1
    }
    $serial = (@($ready)[0] -split "`t")[0]
    Write-Host "Celular detectado: $serial" -ForegroundColor Green
}

# Arranca el servidor.
$env:PANEL_TOKEN = $token
$env:PANEL_PORT = "$Puerto"
$server = Start-Process node -ArgumentList 'server.js' -NoNewWindow -PassThru

# Espera a que responda.
$ok = $false
for ($i = 0; $i -lt 40; $i++) {
    try { Invoke-WebRequest "http://127.0.0.1:$Puerto/" -UseBasicParsing -TimeoutSec 1 | Out-Null; $ok = $true; break } catch { Start-Sleep -Milliseconds 250 }
}
if (-not $ok) { Write-Host "El servidor no arrancó." -ForegroundColor Red; Stop-Process $server -ErrorAction SilentlyContinue; exit 1 }

try {
    if ($SoloPC) {
        Start-Process $url
    } else {
        # Túnel USB: el localhost del celular apunta al localhost del PC. Nada se expone a la red Wi-Fi.
        & $adb -s $serial reverse "tcp:$Puerto" "tcp:$Puerto" | Out-Null
        # application_id hace que Chrome reutilice la misma pestaña en lugar de abrir una nueva cada vez.
        & $adb -s $serial shell am start -a android.intent.action.VIEW -d "'$url'" --es com.android.browser.application_id panelusb | Out-Null
        Write-Host "Panel abierto en el celular. Si se desconecta el cable, vuelve a ejecutar este script." -ForegroundColor Green
    }
    Write-Host "Ctrl+C para detener."
    Wait-Process -Id $server.Id
}
finally {
    if (-not $server.HasExited) { Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue }
    if ($adb -and $serial) { & $adb -s $serial reverse --remove "tcp:$Puerto" 2>$null | Out-Null }
    Remove-Item Env:PANEL_TOKEN -ErrorAction SilentlyContinue
}
