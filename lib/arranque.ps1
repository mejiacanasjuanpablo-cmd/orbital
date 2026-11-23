# Arranque del panel: funciones que comparten la ventana (ventana.ps1), el modo consola (iniciar.ps1) e instalar.ps1.
# Solo define funciones; no hace nada al cargarse. Necesita lib\requisitos.ps1 (Invoke-Oculto).
# Todos los programas externos (node, el compilador) se ejecutan con Invoke-Oculto, sin ventanas de consola.

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

# ¿Responde el panel en este puerto? (en 127.0.0.1 o en la IP de la red local)
function Test-Panel([int]$Puerto, [string]$Ip = '127.0.0.1') {
    try {
        $r = [Net.HttpWebRequest]::Create("http://${Ip}:$Puerto/")
        $r.Timeout = 1500; $r.Proxy = $null
        $r.GetResponse().Close()
        return $true
    } catch { return $false }
}

# ---------- Dispositivos autorizados (config.json → wifi.dispositivos)
function Test-ListaWifiVacia([string]$Raiz) {
    [IO.File]::ReadAllText((Join-Path $Raiz 'config.json')) -notmatch '"dispositivos"\s*:\s*\[\s*"'
}


# ---------- Servidor
# Arranca server.js sin ventana, con el Node.js incluido en el panel o el instalado ($PanelNode, de lib\requisitos.ps1).
# PANEL_PADRE hace que el servidor se cierre solo si este proceso desaparece.
# Solo se captura stderr (para mostrar el motivo si el servidor no arranca); lo normal se ve en la ventana del panel.
function Start-PanelServidor([string]$Raiz, [int]$Puerto, [string]$Token, [string]$LanIp) {
    $psi = New-Object Diagnostics.ProcessStartInfo $PanelNode, 'server.js'
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
