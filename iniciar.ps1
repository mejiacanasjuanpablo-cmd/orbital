# Orbital en modo consola: arranca el servidor y muestra sus mensajes en esta ventana (útil para diagnosticar).
# Lo normal es abrir la ventana del panel (icono del menú Inicio, iniciar.cmd o ventana.ps1); esto hace lo mismo en una consola.
# Uso:  .\iniciar.ps1            (el celular entra por la red Wi-Fi de la casa, con el código QR)
#       .\iniciar.ps1 -SoloPC    (sin celular: lo abre en el navegador de este PC)
# -Wifi se acepta y no hace nada: el panel siempre funciona por Wi-Fi.
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
. (Join-Path $PSScriptRoot 'lib\requisitos.ps1')   # Get-NodeVersion, Get-ArchivosFaltantes, $PanelNode
. (Join-Path $PSScriptRoot 'lib\arranque.ps1')     # token, red y servidor
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
Initialize-PanelConfig $PSScriptRoot

# La IP de este PC en la red local (no hace falta con -SoloPC).
$lanIp = $null
if (-not $SoloPC) {
    $red = Get-PanelRed
    if (-not $red) { Write-Host "Este PC no está conectado a una red local. Conéctalo al router, en la misma red que el celular." -ForegroundColor Red; exit 1 }
    $lanIp = $red.Ip
    if ($red.Categoria -eq 'Public') {
        Write-Host "La red '$($red.Nombre)' está marcada como Pública en Windows; el celular no podrá entrar." -ForegroundColor Yellow
        Write-Host "Cámbiala a Privada en Configuración > Red e Internet si es la red de tu casa."
    }
    if (Test-ListaWifiVacia $PSScriptRoot) {
        Write-Host "Todavía no hay ningún celular autorizado: escanea el código QR y aprueba el aviso que aparecerá en el PC." -ForegroundColor Yellow
    }
}

function Show-WifiInfo {
    $wifiUrl = "http://${lanIp}:$Puerto/#t=$token"
    Write-Host ""
    Write-Host "Escanea este código con la cámara del celular (en la misma red Wi-Fi que el PC):" -ForegroundColor Green
    Write-Host ""
    # El QR se dibuja con Node (lib\qr.js, sin conexión a internet: el token nunca sale del PC).
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { & $PanelNode (Join-Path $PSScriptRoot 'lib\qr.js') $wifiUrl } catch { }
    $ErrorActionPreference = $prev
    Write-Host ""
    Write-Host "O escribe esta dirección en el navegador del celular:" -ForegroundColor DarkGray
    Write-Host "  $wifiUrl" -ForegroundColor Cyan
    Write-Host "Si el celular es nuevo, aparecerá un aviso en el PC para aprobarlo. Después, en Chrome: ⋮ > Agregar a pantalla principal."
    Write-Host ""
}

# Si el panel ya está en marcha (por ejemplo, en la ventana del panel), solo se vuelve a mostrar cómo entrar.
if (Test-Panel $Puerto) {
    if ($SoloPC) { Start-Process $url }
    elseif (-not (Test-Panel $Puerto $lanIp)) {
        Write-Host "Ya hay un panel abierto en el puerto $Puerto, pero solo para este PC. Detenlo y vuelve a abrirlo." -ForegroundColor Yellow
        exit 1
    } else { Show-WifiInfo }
    Write-Host "El panel ya estaba en marcha." -ForegroundColor Green
    Start-Sleep -Seconds 2
    exit 0
}

# Arranca el servidor en esta consola, para ver sus mensajes. PANEL_PADRE: si se cierra la consola, se cierra también.
$env:PANEL_TOKEN = $token
$env:PANEL_PORT = "$Puerto"
$env:PANEL_PADRE = "$PID"
if ($lanIp) { $env:PANEL_LAN_IP = $lanIp } else { Remove-Item Env:PANEL_LAN_IP -ErrorAction SilentlyContinue }
$server = Start-Process $PanelNode -ArgumentList 'server.js' -NoNewWindow -PassThru

# Espera a que responda.
$ok = $false
for ($i = 0; $i -lt 40; $i++) {
    if ((Test-Panel $Puerto) -and (-not $lanIp -or (Test-Panel $Puerto $lanIp))) { $ok = $true; break }
    if ($server.HasExited) { break }
    Start-Sleep -Milliseconds 250
}
if (-not $ok) { Write-Host "El servidor no arrancó." -ForegroundColor Red; Stop-Process $server -ErrorAction SilentlyContinue; exit 1 }

try {
    if ($SoloPC) { Start-Process $url } else { Show-WifiInfo }
    # Desde este PC no se nota si el firewall de Windows no deja entrar al celular: se revisa aparte.
    if ($lanIp -and $red.Categoria -ne 'Public') {
        $programa = try { $server.Path } catch { $null }
        $fw = Get-PanelFirewall $(if ($programa) { $programa } else { Get-PanelNodeRuta }) $red.Categoria
        if ($fw -eq 'sin-permiso') { Write-Host "El firewall de Windows todavía no deja entrar al celular: si Windows pregunta, elige Permitir (o usa verificar.cmd)." -ForegroundColor Yellow }
        elseif ($fw -eq 'bloqueado') { Write-Host "El firewall de Windows está bloqueando Node.js: el celular no podrá entrar. Si Windows está preguntando, elige Permitir; si no, verificar.cmd lo desbloquea." -ForegroundColor Yellow }
        elseif ($fw -eq 'todo-bloqueado') { Write-Host "El firewall de Windows tiene activado «Bloquear todas las conexiones entrantes»: el celular no podrá entrar." -ForegroundColor Yellow }
    }
    Write-Host "Ctrl+C para detener."
    while (-not $server.HasExited) { Start-Sleep -Seconds 3 }
}
finally {
    if (-not $server.HasExited) { Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue }
    Remove-Item Env:PANEL_TOKEN, Env:PANEL_LAN_IP, Env:PANEL_PADRE -ErrorAction SilentlyContinue
}
