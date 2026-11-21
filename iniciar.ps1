# Panel del PC en modo consola: arranca el servidor y muestra sus mensajes en esta ventana (útil para diagnosticar).
# Lo normal es abrir la ventana del panel (iconos del menú Inicio, iniciar.cmd o ventana.ps1); esto hace lo mismo en una consola.
# Uso:  .\iniciar.ps1            (con el celular conectado y la depuración USB activada)
#       .\iniciar.ps1 -Wifi      (sin cable: el celular entra por la red Wi-Fi de la casa)
#       .\iniciar.ps1 -SoloPC    (sin celular: lo abre en el navegador del PC)
# En la edición solo Wi-Fi (con EDICION-WIFI.txt) siempre arranca en modo Wi-Fi y nunca usa adb.
param(
    [int]$Puerto = 8787,
    [switch]$Wifi,
    [switch]$SoloPC
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

# Comprobación rápida de lo imprescindible (la revisión completa está en verificar.cmd).
if (-not (Test-Path (Join-Path $PSScriptRoot 'lib\requisitos.ps1')) -or -not (Test-Path (Join-Path $PSScriptRoot 'lib\arranque.ps1'))) {
    Write-Host "Faltan archivos del panel. Vuelve a descomprimir el .zip del panel completo." -ForegroundColor Red; exit 1
}
. (Join-Path $PSScriptRoot 'lib\requisitos.ps1')   # Find-Adb, Get-NodeVersion, Get-ArchivosFaltantes, $PanelSoloWifi
. (Join-Path $PSScriptRoot 'lib\arranque.ps1')     # token, red, adb, túnel USB
if ($PanelSoloWifi) { $Wifi = $true }
$faltanArchivos = Get-ArchivosFaltantes $PSScriptRoot
if ($faltanArchivos.Count) {
    Write-Host "Faltan archivos del panel: $($faltanArchivos -join ', ')" -ForegroundColor Red
    Write-Host "Vuelve a descomprimir el .zip del panel completo."; exit 1
}
$nodeVer = Get-NodeVersion
if (-not $nodeVer -or $nodeVer -lt $PanelNodeMinimo) {
    $que = if ($nodeVer) { "Node.js $nodeVer es muy antiguo (se necesita $($PanelNodeMinimo.Major) o superior)" } else { 'No se encontró Node.js' }
    Write-Host "$que." -ForegroundColor Red
    Write-Host "Haz doble clic en verificar.cmd: revisa todo y ofrece instalarlo."; exit 1
}

$token = Get-PanelToken $PSScriptRoot
$url = "http://localhost:$Puerto/#t=$token"

# Modo Wi-Fi: la IP de este PC en la red local.
$lanIp = $null
if ($Wifi) {
    $red = Get-PanelRed
    if (-not $red) { Write-Host "Este PC no está conectado a una red local." -ForegroundColor Red; exit 1 }
    $lanIp = $red.Ip
    if ($red.Publica) {
        Write-Host "La red '$($red.Nombre)' está marcada como Pública en Windows; el celular no podrá entrar." -ForegroundColor Yellow
        Write-Host "Cámbiala a Privada en Configuración > Red e Internet si es la red de tu casa."
    }
}
$hostCel = if ($Wifi) { $lanIp } else { 'localhost' }

$adb = $null
$serial = $null
if ($Wifi) {
    # En modo Wi-Fi el cable es opcional: si el celular está conectado se usa solo para autorizarlo y abrirle el panel.
    # La edición solo Wi-Fi no usa adb nunca.
    $adb = if ($PanelSoloWifi) { $null } else { Find-Adb }
    if ($adb) {
        Start-Adb $adb
        $cel = Get-CelularAdb $adb
        if ($cel -and $cel.Estado -eq 'device') { $serial = $cel.Serial }
    }

    # Solo los dispositivos de config.json → wifi.dispositivos pueden entrar. Si la lista está vacía y el celular
    # está conectado por cable, se autoriza su IP de Wi-Fi automáticamente.
    Initialize-PanelConfig $PSScriptRoot
    $ipCel = if ($serial) { Get-IpWifiCelular $adb $serial } else { $null }
    if ($ipCel) {
        switch (Add-CelularPorCable $PSScriptRoot $ipCel) {
            'agregado' { Write-Host "Celular autorizado para el modo Wi-Fi: $ipCel" -ForegroundColor Green }
            'otros' { Write-Host "La IP Wi-Fi del celular ($ipCel) no está en config.json → wifi.dispositivos; agrégala para que pueda entrar." -ForegroundColor Yellow }
        }
    } elseif (Test-ListaWifiVacia $PSScriptRoot) {
        Write-Host "Todavía no hay ningún celular autorizado para el modo Wi-Fi: escanea el código QR y aprueba el aviso que aparecerá en el PC." -ForegroundColor Yellow
    }
} elseif (-not $SoloPC) {
    $adb = Find-Adb
    if (-not $adb) {
        Write-Host "No se encontró adb (Android platform-tools)." -ForegroundColor Yellow
        Write-Host "Instálalo con:  winget install Google.PlatformTools   y vuelve a abrir la terminal."
        Write-Host "O ejecuta  .\iniciar.ps1 -SoloPC  para probar el panel en este PC." ; exit 1
    }
    Start-Adb $adb
    # Recién conectado (o con adb recién iniciado) el celular aparece unos segundos como "unauthorized" u "offline"
    # aunque ya haya dado permiso, o hasta que se desbloquee y se acepte el aviso. Se espera hasta 60 s.
    $cel = $null; $avisado = $false
    for ($i = 0; $i -lt 60; $i++) {
        $cel = Get-CelularAdb $adb
        if ($cel -and $cel.Estado -eq 'device') { break }
        if (-not $avisado) { Write-Host "Esperando al celular (desbloquéalo si te pide permiso)..."; $avisado = $true }
        Start-Sleep -Seconds 1
    }
    if (-not $cel -or $cel.Estado -ne 'device') {
        if ($cel -and $cel.Estado -eq 'unauthorized') {
            Write-Host "El celular no ha autorizado este PC: desbloquéalo y acepta 'Permitir depuración USB'." -ForegroundColor Yellow
        } else {
            Write-Host "No hay ningún celular conectado con la depuración USB activada." -ForegroundColor Yellow
            Write-Host "Ajustes > Acerca del teléfono > toca 7 veces 'Número de compilación' > Opciones de desarrollador > Depuración USB."
        }
        exit 1
    }
    $serial = $cel.Serial
    Write-Host "Celular detectado: $serial" -ForegroundColor Green
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

# Si el panel ya está en marcha (por ejemplo, en la ventana del panel), solo se vuelve a abrir en el celular.
if ($Wifi -and (Test-Panel $Puerto) -and -not (Test-Panel $Puerto $lanIp)) {
    Write-Host "El panel ya está abierto en modo USB. Detenlo y vuelve a abrir el modo Wi-Fi." -ForegroundColor Yellow
    exit 1
}
if (Test-Panel $Puerto) {
    if ($SoloPC) { Start-Process $url }
    elseif ($Wifi) { Show-WifiInfo; if ($serial) { Open-PanelEnCelular $adb $serial $hostCel $Puerto $token } }
    else {
        if (-not (Set-TunelUsb $adb $serial $Puerto)) { Write-Host "No se pudo crear el túnel USB." -ForegroundColor Red; exit 1 }
        Open-PanelEnCelular $adb $serial $hostCel $Puerto $token
    }
    Write-Host "El panel ya estaba en marcha; se volvió a abrir." -ForegroundColor Green
    Start-Sleep -Seconds 2
    exit 0
}

# Arranca el servidor en esta consola, para ver sus mensajes. PANEL_PADRE: si se cierra la consola, se cierra también.
$env:PANEL_TOKEN = $token
$env:PANEL_PORT = "$Puerto"
$env:PANEL_PADRE = "$PID"
if ($Wifi) { $env:PANEL_LAN_IP = $lanIp } else { Remove-Item Env:PANEL_LAN_IP -ErrorAction SilentlyContinue }
$server = Start-Process node -ArgumentList 'server.js' -NoNewWindow -PassThru

# Espera a que responda.
$ok = $false
for ($i = 0; $i -lt 40; $i++) {
    if ((Test-Panel $Puerto) -and (-not $Wifi -or (Test-Panel $Puerto $lanIp))) { $ok = $true; break }
    if ($server.HasExited) { break }
    Start-Sleep -Milliseconds 250
}
if (-not $ok) { Write-Host "El servidor no arrancó." -ForegroundColor Red; Stop-Process $server -ErrorAction SilentlyContinue; exit 1 }

try {
    if ($SoloPC) {
        Start-Process $url
    } elseif ($Wifi) {
        Show-WifiInfo
        if ($serial) { Open-PanelEnCelular $adb $serial $hostCel $Puerto $token; Write-Host "Como el celular está conectado por cable, ya se lo abrí. Puedes desconectarlo." -ForegroundColor Green }
    } else {
        if (-not (Set-TunelUsb $adb $serial $Puerto)) { Write-Host "No se pudo crear el túnel USB." -ForegroundColor Red }
        Open-PanelEnCelular $adb $serial $hostCel $Puerto $token
        Write-Host "Panel abierto en el celular. Si desconectas el cable, el túnel se restablece solo al reconectarlo." -ForegroundColor Green
    }
    Write-Host "Ctrl+C para detener."
    $conectado = $true
    while (-not $server.HasExited) {
        if (-not $SoloPC -and -not $Wifi) {
            $ahora = Set-TunelUsb $adb $serial $Puerto
            if ($ahora -and -not $conectado) { Write-Host "Celular reconectado: túnel USB restablecido." -ForegroundColor Green }
            elseif (-not $ahora -and $conectado) { Write-Host "Celular desconectado; esperando a que vuelva..." -ForegroundColor Yellow }
            $conectado = $ahora
        }
        Start-Sleep -Seconds 3
    }
}
finally {
    if (-not $server.HasExited) { Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue }
    if ($adb -and $serial -and -not $Wifi) { Remove-TunelUsb $adb $serial $Puerto }
    Remove-Item Env:PANEL_TOKEN, Env:PANEL_LAN_IP, Env:PANEL_PADRE -ErrorAction SilentlyContinue
}
