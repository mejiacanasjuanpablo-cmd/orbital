# Panel USB: arranca el servidor local y lo abre en el celular Android por USB.
# Uso:  .\iniciar.ps1            (con el celular conectado y la depuración USB activada)
#       .\iniciar.ps1 -Wifi      (sin cable: el celular entra por la red Wi-Fi de la casa)
#       .\iniciar.ps1 -SoloPC    (sin celular: lo abre en el navegador del PC)
param(
    [int]$Puerto = 8787,
    [switch]$Wifi,
    [switch]$SoloPC
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

# Comprobación rápida de lo imprescindible (la revisión completa está en verificar.cmd).
if (-not (Test-Path (Join-Path $PSScriptRoot 'lib\requisitos.ps1'))) {
    Write-Host "Faltan archivos del panel. Vuelve a descomprimir Panel-USB.zip completo." -ForegroundColor Red; exit 1
}
. (Join-Path $PSScriptRoot 'lib\requisitos.ps1')   # Find-Adb, Get-NodeVersion, Get-ArchivosFaltantes
$faltanArchivos = Get-ArchivosFaltantes $PSScriptRoot
if ($faltanArchivos.Count) {
    Write-Host "Faltan archivos del panel: $($faltanArchivos -join ', ')" -ForegroundColor Red
    Write-Host "Vuelve a descomprimir Panel-USB.zip completo."; exit 1
}
$nodeVer = Get-NodeVersion
if (-not $nodeVer -or $nodeVer -lt $PanelNodeMinimo) {
    $que = if ($nodeVer) { "Node.js $nodeVer es muy antiguo (se necesita $($PanelNodeMinimo.Major) o superior)" } else { 'No se encontró Node.js' }
    Write-Host "$que." -ForegroundColor Red
    Write-Host "Haz doble clic en verificar.cmd: revisa todo y ofrece instalarlo."; exit 1
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

# Modo Wi-Fi: busca la IP de este PC en la red local (la del adaptador con puerta de enlace).
$lanIp = $null
if ($Wifi) {
    $cfg = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } |
        Where-Object { $_.IPv4Address.IPAddress -match '^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)' } | Select-Object -First 1
    if (-not $cfg) { Write-Host "Este PC no está conectado a una red local." -ForegroundColor Red; exit 1 }
    $lanIp = @($cfg.IPv4Address.IPAddress)[0]
    $perfil = (Get-NetConnectionProfile -InterfaceIndex $cfg.InterfaceIndex -ErrorAction SilentlyContinue).NetworkCategory
    if ("$perfil" -eq 'Public') {
        Write-Host "La red '$($cfg.NetProfile.Name)' está marcada como Pública en Windows; el celular no podrá entrar." -ForegroundColor Yellow
        Write-Host "Cámbiala a Privada en Configuración > Red e Internet si es la red de tu casa."
    }
}
$hostCel = if ($Wifi) { $lanIp } else { 'localhost' }

$adb = $null
$serial = $null
if ($Wifi) {
    # En modo Wi-Fi el cable es opcional: si el celular está conectado se usa solo para abrirle el panel.
    $adb = Find-Adb
    if ($adb) {
        $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        & $adb start-server 2>&1 | Out-Null
        $ready = & $adb devices 2>$null | Select-Object -Skip 1 | Where-Object { $_ -match '\tdevice$' }
        $ErrorActionPreference = $prev
        if ($ready) { $serial = (@($ready)[0] -split "`t")[0] }
    }

    # Solo los dispositivos de config.json → wifi.dispositivos pueden entrar. Si la lista está vacía y el celular
    # está conectado por cable, se autoriza su IP de Wi-Fi automáticamente.
    $cfgPath = Join-Path $PSScriptRoot 'config.json'
    if (-not (Test-Path $cfgPath) -and (Test-Path (Join-Path $PSScriptRoot 'config.ejemplo.json'))) {
        Copy-Item (Join-Path $PSScriptRoot 'config.ejemplo.json') $cfgPath
    }
    $cfgTxt = [IO.File]::ReadAllText($cfgPath)
    $listaVacia = $cfgTxt -notmatch '"dispositivos"\s*:\s*\[\s*"'
    $ipCel = $null
    if ($serial) {
        $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        try { $wl = (& $adb -s $serial shell "ip -4 addr show wlan0" 2>&1) -join ' ' } catch { $wl = '' }
        $ErrorActionPreference = $prev
        if ($wl -match 'inet (\d+\.\d+\.\d+\.\d+)/') { $ipCel = $Matches[1] }
    }
    if ($ipCel -and $listaVacia -and $cfgTxt -match '"dispositivos"\s*:\s*\[\s*\]') {
        $cfgTxt = [regex]::Replace($cfgTxt, '"dispositivos"\s*:\s*\[\s*\]', "`"dispositivos`": [`"$ipCel`"]")
        [IO.File]::WriteAllText($cfgPath, $cfgTxt, (New-Object Text.UTF8Encoding $false))
        Write-Host "Celular autorizado para el modo Wi-Fi: $ipCel" -ForegroundColor Green
    } elseif ($ipCel -and $cfgTxt -notmatch [regex]::Escape("`"$ipCel`"")) {
        Write-Host "La IP Wi-Fi del celular ($ipCel) no está en config.json → wifi.dispositivos; agrégala para que pueda entrar." -ForegroundColor Yellow
    } elseif (-not $ipCel -and $listaVacia) {
        Write-Host "Todavía no hay ningún celular autorizado para el modo Wi-Fi: escanea el código QR y aprueba el aviso que aparecerá en el PC." -ForegroundColor Yellow
    }
} elseif (-not $SoloPC) {
    $adb = Find-Adb
    if (-not $adb) {
        Write-Host "No se encontró adb (Android platform-tools)." -ForegroundColor Yellow
        Write-Host "Instálalo con:  winget install Google.PlatformTools   y vuelve a abrir la terminal."
        Write-Host "O ejecuta  .\iniciar.ps1 -SoloPC  para probar el panel en este PC." ; exit 1
    }
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    & $adb start-server 2>&1 | Out-Null
    $ErrorActionPreference = $prev
    # Recién conectado (o con adb recién iniciado) el celular aparece unos segundos como "unauthorized" u "offline"
    # aunque ya haya dado permiso, o hasta que se desbloquee y se acepte el aviso. Se espera hasta 60 s.
    $ready = $null; $avisado = $false
    for ($i = 0; $i -lt 60; $i++) {
        $devices = & $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '\S' }
        $ready = $devices | Where-Object { $_ -match '\tdevice$' }
        if ($ready) { break }
        if (-not $avisado) { Write-Host "Esperando al celular (desbloquéalo si te pide permiso)..."; $avisado = $true }
        Start-Sleep -Seconds 1
    }
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

function Test-Panel([string]$Ip = '127.0.0.1') {
    try { Invoke-WebRequest "http://${Ip}:$Puerto/" -UseBasicParsing -TimeoutSec 1 | Out-Null; return $true } catch { return $false }
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
    $abrir = "http://${hostCel}:$Puerto/?v=$([DateTime]::Now.Ticks)#t=$token"
    & $adb -s $serial shell am start -a android.intent.action.VIEW -d "'$abrir'" --es com.android.browser.application_id panelusb | Out-Null
}

function Show-WifiInfo {
    $wifiUrl = "http://${lanIp}:$Puerto/#t=$token"
    Write-Host ""
    Write-Host "Modo Wi-Fi. Escanea este código con la cámara del celular (en la misma red Wi-Fi que el PC):" -ForegroundColor Green
    Write-Host ""
    # El QR se dibuja con Node (lib\qr.js, sin conexión a internet: el token nunca sale del PC).
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { & node (Join-Path $PSScriptRoot 'lib\qr.js') $wifiUrl } catch { }
    $ErrorActionPreference = $prev
    Write-Host ""
    Write-Host "O escribe esta dirección en el navegador del celular:" -ForegroundColor DarkGray
    Write-Host "  $wifiUrl" -ForegroundColor Cyan
    Write-Host "Si el celular es nuevo, aparecerá un aviso en el PC para aprobarlo. Después, en Chrome: ⋮ > Agregar a pantalla principal."
    Write-Host ""
}

# Si el panel ya está en marcha (por ejemplo, se pulsó el icono dos veces), solo se vuelve a abrir en el celular.
if ($Wifi -and (Test-Panel) -and -not (Test-Panel $lanIp)) {
    Write-Host "El panel ya está abierto en modo USB. Cierra esa ventana y vuelve a abrir el modo Wi-Fi." -ForegroundColor Yellow
    exit 1
}
if (Test-Panel) {
    if ($SoloPC) { Start-Process $url }
    elseif ($Wifi) { Show-WifiInfo; if ($serial) { Open-EnCelular } }
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
if ($Wifi) { $env:PANEL_LAN_IP = $lanIp } else { Remove-Item Env:PANEL_LAN_IP -ErrorAction SilentlyContinue }
$server = Start-Process node -ArgumentList 'server.js' -NoNewWindow -PassThru

# Espera a que responda.
$ok = $false
for ($i = 0; $i -lt 40; $i++) {
    if ((Test-Panel) -and (-not $Wifi -or (Test-Panel $lanIp))) { $ok = $true; break }
    if ($server.HasExited) { break }
    Start-Sleep -Milliseconds 250
}
if (-not $ok) { Write-Host "El servidor no arrancó." -ForegroundColor Red; Stop-Process $server -ErrorAction SilentlyContinue; exit 1 }

try {
    if ($SoloPC) {
        Start-Process $url
    } elseif ($Wifi) {
        Show-WifiInfo
        if ($serial) { Open-EnCelular; Write-Host "Como el celular está conectado por cable, ya se lo abrí. Puedes desconectarlo." -ForegroundColor Green }
    } else {
        if (-not (Set-Tunel)) { Write-Host "No se pudo crear el túnel USB." -ForegroundColor Red }
        Open-EnCelular
        Write-Host "Panel abierto en el celular. Si desconectas el cable, el túnel se restablece solo al reconectarlo." -ForegroundColor Green
    }
    Write-Host "Ctrl+C para detener."
    $conectado = $true
    while (-not $server.HasExited) {
        if (-not $SoloPC -and -not $Wifi) {
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
    if ($adb -and $serial -and -not $Wifi) { try { & $adb -s $serial reverse --remove "tcp:$Puerto" 2>&1 | Out-Null } catch {} }
    Remove-Item Env:PANEL_TOKEN, Env:PANEL_LAN_IP -ErrorAction SilentlyContinue
}
