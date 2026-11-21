# Arranque del panel: funciones que comparten la ventana (ventana.ps1), el modo consola (iniciar.ps1) e instalar.ps1.
# Solo define funciones; no hace nada al cargarse. Necesita lib\requisitos.ps1 (Invoke-Oculto, Find-Adb).
# Todos los programas externos (adb, node, el compilador) se ejecutan con Invoke-Oculto, sin ventanas de consola.

# Token fijo guardado en .token, para que el icono de la pantalla de inicio del celular siga funcionando.
# Para invalidarlo (por ejemplo, si cambias de celular), borra el archivo .token.
function Get-PanelToken([string]$Raiz) {
    $archivo = Join-Path $Raiz '.token'
    $token = if (Test-Path $archivo) { "$(Get-Content $archivo -Raw)".Trim() } else { '' }
    if ($token -notmatch '^[0-9a-f]{32,}$') {
        $bytes = New-Object byte[] 24
        [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
        $token = -join ($bytes | ForEach-Object { $_.ToString('x2') })
        Set-Content -Path $archivo -Value $token -NoNewline -Encoding ascii
    }
    $token
}

# La primera vez se crea config.json a partir del ejemplo (el servidor también lo hace al arrancar).
function Initialize-PanelConfig([string]$Raiz) {
    $cfg = Join-Path $Raiz 'config.json'
    $ejemplo = Join-Path $Raiz 'config.ejemplo.json'
    if (-not (Test-Path $cfg) -and (Test-Path $ejemplo)) { Copy-Item $ejemplo $cfg }
}

# IP de este PC en la red local (la del adaptador con puerta de enlace) y si Windows marca esa red como Pública.
# Devuelve $null si el PC no está conectado a ninguna red local.
function Get-PanelRed {
    $cfg = Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } |
        Where-Object { $_.IPv4Address.IPAddress -match '^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)' } | Select-Object -First 1
    if (-not $cfg) { return $null }
    $categoria = "$((Get-NetConnectionProfile -InterfaceIndex $cfg.InterfaceIndex -ErrorAction SilentlyContinue).NetworkCategory)"
    [pscustomobject]@{ Ip = @($cfg.IPv4Address.IPAddress)[0]; Nombre = "$($cfg.NetProfile.Name)"; Publica = ($categoria -eq 'Public') }
}

# ¿Responde el panel en este puerto? (en 127.0.0.1 o, en modo Wi-Fi, en la IP de la red local)
function Test-Panel([int]$Puerto, [string]$Ip = '127.0.0.1') {
    try {
        $r = [Net.HttpWebRequest]::Create("http://${Ip}:$Puerto/")
        $r.Timeout = 1500; $r.Proxy = $null
        $r.GetResponse().Close()
        return $true
    } catch { return $false }
}

# ---------- Celular por cable (adb)
function Start-Adb([string]$Adb) { Invoke-Oculto $Adb @('start-server') -SinSalida -EsperaMs 20000 | Out-Null }

# El celular que ve adb: Serial y Estado (device = listo, unauthorized = falta aceptar el aviso, offline = conectando).
# Si hay varios, prefiere uno listo. Devuelve $null si no hay ninguno.
function Get-CelularAdb([string]$Adb) {
    $salida = (Invoke-Oculto $Adb @('devices') -EsperaMs 10000).Salida
    $lista = @($salida -split "`r?`n" | ForEach-Object {
        if ($_ -match '^(\S+)\t(\S+)') { [pscustomobject]@{ Serial = $Matches[1]; Estado = $Matches[2] } }
    })
    $listo = $lista | Where-Object { $_.Estado -eq 'device' } | Select-Object -First 1
    if ($listo) { return $listo }
    $lista | Select-Object -First 1
}

function Get-IpWifiCelular([string]$Adb, [string]$Serial) {
    $salida = (Invoke-Oculto $Adb @('-s', $Serial, 'shell', 'ip -4 addr show wlan0') -EsperaMs 8000).Salida
    if ($salida -match 'inet (\d+\.\d+\.\d+\.\d+)/') { return $Matches[1] }
    $null
}

function Get-ModeloCelular([string]$Adb, [string]$Serial) {
    "$((Invoke-Oculto $Adb @('-s', $Serial, 'shell', 'getprop ro.product.model') -EsperaMs 8000).Salida)".Trim()
}

# Túnel USB: el localhost del celular apunta al localhost del PC; nada se expone a la red Wi-Fi.
# Se pierde al desconectar el cable, por eso se revisa cada pocos segundos. Devuelve $true si está activo.
function Set-TunelUsb([string]$Adb, [string]$Serial, [int]$Puerto) {
    $lista = (Invoke-Oculto $Adb @('-s', $Serial, 'reverse', '--list') -EsperaMs 8000).Salida
    if ($lista -match "tcp:$Puerto\b") { return $true }
    (Invoke-Oculto $Adb @('-s', $Serial, 'reverse', "tcp:$Puerto", "tcp:$Puerto") -EsperaMs 8000).Codigo -eq 0
}

function Remove-TunelUsb([string]$Adb, [string]$Serial, [int]$Puerto) {
    Invoke-Oculto $Adb @('-s', $Serial, 'reverse', '--remove', "tcp:$Puerto") -EsperaMs 5000 | Out-Null
}

# Abre el panel en el Chrome del celular. application_id hace que Chrome reutilice la misma pestaña en lugar de
# abrir una nueva cada vez; ?v= cambia en cada apertura para que recargue y muestre siempre la última versión.
function Open-PanelEnCelular([string]$Adb, [string]$Serial, [string]$Servidor, [int]$Puerto, [string]$Token) {
    $abrir = "http://${Servidor}:$Puerto/?v=$([DateTime]::Now.Ticks)#t=$Token"
    Invoke-Oculto $Adb @('-s', $Serial, 'shell', 'am', 'start', '-a', 'android.intent.action.VIEW', '-d', "'$abrir'",
        '--es', 'com.android.browser.application_id', 'panelusb') -EsperaMs 10000 | Out-Null
}

# ---------- Dispositivos del modo Wi-Fi (config.json → wifi.dispositivos)
function Test-ListaWifiVacia([string]$Raiz) {
    [IO.File]::ReadAllText((Join-Path $Raiz 'config.json')) -notmatch '"dispositivos"\s*:\s*\[\s*"'
}

# Modo Wi-Fi con el celular conectado por cable: si todavía no hay ningún dispositivo autorizado, se autoriza su IP.
# Devuelve 'agregado', 'ya-estaba' u 'otros' (la lista ya tiene otros dispositivos y este no está).
function Add-CelularPorCable([string]$Raiz, [string]$Ip) {
    $ruta = Join-Path $Raiz 'config.json'
    $txt = [IO.File]::ReadAllText($ruta)
    if ($txt -match [regex]::Escape("`"$Ip`"")) { return 'ya-estaba' }
    if ($txt -match '"dispositivos"\s*:\s*\[\s*\]') {
        $txt = [regex]::Replace($txt, '"dispositivos"\s*:\s*\[\s*\]', "`"dispositivos`": [`"$Ip`"]")
        [IO.File]::WriteAllText($ruta, $txt, (New-Object Text.UTF8Encoding $false))
        return 'agregado'
    }
    'otros'
}

# ---------- Servidor
# Arranca server.js sin ventana. PANEL_PADRE hace que el servidor se cierre solo si este proceso desaparece.
# Solo se captura stderr (para mostrar el motivo si el servidor no arranca); lo normal se ve en la ventana del panel.
function Start-PanelServidor([string]$Raiz, [int]$Puerto, [string]$Token, [string]$LanIp) {
    $psi = New-Object Diagnostics.ProcessStartInfo 'node', 'server.js'
    $psi.WorkingDirectory = $Raiz
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardError = $true
    $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
    $psi.EnvironmentVariables['PANEL_TOKEN'] = $Token
    $psi.EnvironmentVariables['PANEL_PORT'] = "$Puerto"
    $psi.EnvironmentVariables['PANEL_PADRE'] = "$PID"
    if ($LanIp) { $psi.EnvironmentVariables['PANEL_LAN_IP'] = $LanIp } else { $psi.EnvironmentVariables.Remove('PANEL_LAN_IP') }
    [Diagnostics.Process]::Start($psi)
}

# El proceso que escucha en el puerto del panel (o $null).
function Get-ProcesoEnPuerto([int]$Puerto) {
    $c = Get-NetTCPConnection -LocalPort $Puerto -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c) { Get-Process -Id $c.OwningProcess -ErrorAction SilentlyContinue }
}

# Cierra otra copia del panel que ocupa el puerto (por ejemplo, la versión anterior con su ventana de consola):
# el servidor y, si lo abrió iniciar.ps1, también esa consola. Solo toca procesos del panel. Devuelve $true si cerró algo.
function Stop-OtraCopia([int]$Puerto) {
    $c = Get-NetTCPConnection -LocalPort $Puerto -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $c) { return $false }
    $nodo = Get-CimInstance Win32_Process -Filter "ProcessId=$($c.OwningProcess)" -ErrorAction SilentlyContinue
    if (-not $nodo -or $nodo.Name -ne 'node.exe' -or $nodo.CommandLine -notmatch 'server\.js') { return $false }
    $cerrar = @($nodo.ProcessId)
    $padre = Get-CimInstance Win32_Process -Filter "ProcessId=$($nodo.ParentProcessId)" -ErrorAction SilentlyContinue
    if ($padre -and $padre.CommandLine -match 'iniciar\.ps1') {
        $cerrar += $padre.ProcessId
        $abuelo = Get-CimInstance Win32_Process -Filter "ProcessId=$($padre.ParentProcessId)" -ErrorAction SilentlyContinue
        if ($abuelo -and $abuelo.Name -eq 'cmd.exe' -and $abuelo.CommandLine -match 'iniciar') { $cerrar += $abuelo.ProcessId }
    }
    foreach ($id in $cerrar) { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue }
    $true
}

# ---------- Panel del PC.exe
# Crea el programa que abre la ventana del panel sin consola. Se compila aquí, con el compilador de C# que trae
# Windows (.NET Framework 4), así que no se descarga nada. Devuelve la ruta del .exe, o $null si no se pudo.
function Build-PanelVentana([string]$Raiz) {
    $exe = Join-Path $Raiz 'Panel del PC.exe'
    $csc = Join-Path ([Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()) 'csc.exe'
    $sma = "$env:WINDIR\Microsoft.NET\assembly\GAC_MSIL\System.Management.Automation\v4.0_3.0.0.0__31bf3856ad364e35\System.Management.Automation.dll"
    if (-not (Test-Path $sma)) { $sma = [PSObject].Assembly.Location }
    if (-not (Test-Path $csc)) { return $null }
    $tmp = Join-Path ([IO.Path]::GetTempPath()) "panel-del-pc-$PID.exe"
    $r = Invoke-Oculto $csc @('/nologo', '/target:winexe', '/optimize+', "/out:$tmp", "/win32icon:$(Join-Path $Raiz 'panel.ico')",
        "/r:$sma", '/r:System.Windows.Forms.dll', (Join-Path $Raiz 'lib\lanzador.cs')) -EsperaMs 60000
    if ($r.Codigo -ne 0 -or -not (Test-Path $tmp)) { Write-Verbose $r.Salida; return $null }
    try { Move-Item $tmp $exe -Force -ErrorAction Stop }
    catch {
        # Si la ventana está abierta, el .exe está en uso: se conserva el que ya hay.
        Remove-Item $tmp -ErrorAction SilentlyContinue
        if (-not (Test-Path $exe)) { return $null }
    }
    $exe
}
