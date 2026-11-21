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

function Test-Panel {
    try { Invoke-WebRequest "http://127.0.0.1:$Puerto/" -UseBasicParsing -TimeoutSec 1 | Out-Null; return $true } catch { return $false }
}

function Set-Tunel {
    # Túnel USB: el localhost del celular apunta al localhost del PC. Nada se expone a la red Wi-Fi.
    # Devuelve $true si el túnel está activo. Se pierde al desconectar el cable, por eso se revisa cada pocos segundos.
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $list = (& $adb -s $serial reverse --list 2>&1) -join "`n"
        if ($list -match "tcp:$Puerto") { return $true }
        & $adb -s $serial reverse "tcp:$Puerto" "tcp:$Puerto" 2>&1 | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch { return $false } finally { $ErrorActionPreference = $prev }
}

function Open-EnCelular {
    # application_id hace que Chrome reutilice la misma pestaña en lugar de abrir una nueva cada vez.
    # ?v= cambia en cada apertura para que Chrome recargue la página y muestre siempre la última versión.
    $abrir = "http://localhost:$Puerto/?v=$([DateTime]::Now.Ticks)#t=$token"
    & $adb -s $serial shell am start -a android.intent.action.VIEW -d "'$abrir'" --es com.android.browser.application_id panelusb | Out-Null
}

# Si el panel ya está en marcha (por ejemplo, se pulsó el icono dos veces), solo se vuelve a abrir en el celular.
if (Test-Panel) {
    if ($SoloPC) { Start-Process $url }
    else {
        if (-not (Set-Tunel)) { Write-Host "No se pudo crear el túnel USB." -ForegroundColor Red; exit 1 }
        Open-EnCelular
    }
    Write-Host "El panel ya estaba en marcha; se volvió a abrir." -ForegroundColor Green
    Start-Sleep -Seconds 2
    exit 0
}

# Arranca el servidor.
$env:PANEL_TOKEN = $token
$env:PANEL_PORT = "$Puerto"
$server = Start-Process node -ArgumentList 'server.js' -NoNewWindow -PassThru

# Espera a que responda.
$ok = $false
for ($i = 0; $i -lt 40; $i++) {
    if (Test-Panel) { $ok = $true; break }
    if ($server.HasExited) { break }
    Start-Sleep -Milliseconds 250
}
if (-not $ok) { Write-Host "El servidor no arrancó." -ForegroundColor Red; Stop-Process $server -ErrorAction SilentlyContinue; exit 1 }

try {
    if ($SoloPC) {
        Start-Process $url
    } else {
        if (-not (Set-Tunel)) { Write-Host "No se pudo crear el túnel USB." -ForegroundColor Red }
        Open-EnCelular
        Write-Host "Panel abierto en el celular. Si desconectas el cable, el túnel se restablece solo al reconectarlo." -ForegroundColor Green
    }
    Write-Host "Ctrl+C para detener."
    $conectado = $true
    while (-not $server.HasExited) {
        if (-not $SoloPC) {
            $ahora = Set-Tunel
            if ($ahora -and -not $conectado) { Write-Host "Celular reconectado: túnel USB restablecido." -ForegroundColor Green }
            elseif (-not $ahora -and $conectado) { Write-Host "Celular desconectado; esperando a que vuelva..." -ForegroundColor Yellow }
            $conectado = $ahora
        }
        Start-Sleep -Seconds 3
    }
}
finally {
    if (-not $server.HasExited) { Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue }
    if ($adb -and $serial) { try { & $adb -s $serial reverse --remove "tcp:$Puerto" 2>&1 | Out-Null } catch {} }
    Remove-Item Env:PANEL_TOKEN -ErrorAction SilentlyContinue
}
