# Verificación de requisitos del panel. La usan verificar.ps1, instalar.ps1, iniciar.ps1, ventana.ps1 y empaquetar.ps1.
# Solo define funciones y listas; no hace nada al cargarse.

# Archivos sin los que el panel no funciona (también son los que se empaquetan, junto con la guía y los instaladores).
$PanelArchivosComunes = @(
    'server.js', 'config.ejemplo.json', 'panel.ico', 'ventana.ps1', 'iniciar.ps1', 'iniciar.cmd',
    'lib\allow.js', 'lib\aprobacion.js', 'lib\qr.js', 'lib\keys.ps1', 'lib\media.ps1', 'lib\requisitos.ps1',
    'lib\arranque.ps1', 'lib\lanzador.cs', 'lib\mezclador.ps1',
    'public\index.html', 'public\espera.html', 'public\manifest.webmanifest', 'public\icon-192.png', 'public\icon-512.png'
)
# Vistas previas de las páginas del celular (ventana → Páginas del celular). Van en el .zip, pero no se exigen para
# arrancar: si falta alguna, la ventana lo indica en esa tarjeta. Las genera herramientas\miniaturas.js (en español y en inglés).
$PanelMiniaturas = foreach ($carpeta in 'public\miniaturas', 'public\miniaturas\en') {
    foreach ($p in 'inicio', 'mezclador', 'sistema', 'rendimiento', 'procesos', 'enfoque', 'calendario', 'discord', 'comandos') { "$carpeta\$p.jpg" }
}
$PanelArchivos = $PanelArchivosComunes
# server.js usa fetch y AbortSignal.timeout, disponibles desde Node.js 18.
$PanelNodeMinimo = [version]'18.0.0'

function Get-NodeVersion {
    try { $v = (Invoke-Oculto 'node' @('--version') -EsperaMs 10000).Salida -replace '^v', ''; if ($v -match '^\d+\.\d+\.\d+') { return [version]$Matches[0] } } catch { }
    return $null
}

# Ejecuta un programa sin abrir ninguna ventana de consola (también desde la ventana del panel) y devuelve
# su código de salida y lo que escribió. -SinSalida no captura nada: para programas que dejan un proceso
# de fondo, que heredaría la salida y nunca la cerraría.
function Invoke-Oculto {
    param([string]$Programa, [string[]]$Argumentos = @(), [int]$EsperaMs = 15000, [switch]$SinSalida)
    $psi = New-Object Diagnostics.ProcessStartInfo $Programa
    $psi.Arguments = ($Argumentos | ForEach-Object { if ($_ -eq '' -or $_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ } }) -join ' '
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    if (-not $SinSalida) {
        $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
        $psi.StandardOutputEncoding = [Text.Encoding]::UTF8; $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
    }
    try { $p = [Diagnostics.Process]::Start($psi) } catch { return [pscustomobject]@{ Codigo = -1; Salida = $_.Exception.Message } }
    if (-not $SinSalida) { $out = $p.StandardOutput.ReadToEndAsync(); $err = $p.StandardError.ReadToEndAsync() }
    if (-not $p.WaitForExit($EsperaMs)) { try { $p.Kill() } catch { }; return [pscustomobject]@{ Codigo = -1; Salida = 'tiempo agotado' } }
    $texto = if ($SinSalida) { '' } else { "$($out.Result)$($err.Result)".Trim() }
    [pscustomobject]@{ Codigo = $p.ExitCode; Salida = $texto }
}

function Get-ArchivosFaltantes([string]$Raiz) {
    @($PanelArchivos | Where-Object { -not (Test-Path (Join-Path $Raiz $_)) })
}

function Update-RutaSesion {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}

# Ejecuta un comando nativo sin que sus mensajes de error detengan el script.
function Invoke-Nativo([scriptblock]$Bloque) {
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { & $Bloque 2>&1 | ForEach-Object { "$_" } } catch { } finally { $ErrorActionPreference = $prev }
}

function New-Requisito($Nombre, $Estado, $Detalle, [bool]$Obligatorio = $false, $Solucion = $null, $Instalar = $null) {
    [pscustomobject]@{ Nombre = $Nombre; Estado = $Estado; Detalle = $Detalle; Obligatorio = $Obligatorio; Solucion = $Solucion; Instalar = $Instalar }
}

# Revisa todo y devuelve una lista de requisitos con su estado: OK, FALTA, AVISO o INFO.
function Get-Requisitos([string]$Raiz, [int]$Puerto = 8787) {
    $r = @()

    # 1. Archivos del panel
    $faltan = Get-ArchivosFaltantes $Raiz
    if ($faltan.Count) {
        $r += New-Requisito 'Archivos del panel' 'FALTA' "faltan: $($faltan -join ', ')" $true 'Vuelve a descomprimir el .zip del panel completo, en una carpeta fija (no lo abras desde dentro del .zip).'
    } else { $r += New-Requisito 'Archivos del panel' 'OK' "$($PanelArchivos.Count) archivos" $true }
    if (Test-Path (Join-Path $Raiz 'Panel del PC.exe')) { $r += New-Requisito 'Ventana del panel' 'OK' 'Panel del PC.exe' $false }
    else { $r += New-Requisito 'Ventana del panel' 'INFO' 'todavía no se ha creado Panel del PC.exe' $false 'Se crea al ejecutar instalar.cmd. Sin él, el panel abre su ventana con PowerShell.' }

    # 2. Windows
    $build = [Environment]::OSVersion.Version.Build
    if ($build -lt 10240) { $r += New-Requisito 'Windows' 'FALTA' "build $build" $true 'Se necesita Windows 10 u 11.' }
    elseif ($build -lt 17763) { $r += New-Requisito 'Windows' 'AVISO' "build $build" $false 'Actualiza Windows (1809 o superior) para ver la música que suena en el PC.' }
    else { $r += New-Requisito 'Windows' 'OK' "$(if ($build -ge 22000) { 'Windows 11' } else { 'Windows 10' }) (build $build)" $true }

    # 3. PowerShell y .NET Framework (vienen con Windows; el panel compila pequeños componentes en C#)
    $r += New-Requisito 'PowerShell' $(if ($PSVersionTable.PSVersion.Major -ge 5) { 'OK' } else { 'FALTA' }) "$($PSVersionTable.PSVersion)" $true 'Instala Windows Management Framework 5.1.'
    $rel = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -ErrorAction SilentlyContinue).Release
    if ($rel -ge 378389) { $r += New-Requisito '.NET Framework' 'OK' '4.5 o superior' $true }
    else { $r += New-Requisito '.NET Framework' 'FALTA' 'no se encontró la versión 4.5+' $true 'Instala .NET Framework 4.8 desde https://dotnet.microsoft.com/download/dotnet-framework' }

    # 4. Node.js
    $nv = Get-NodeVersion
    if (-not $nv) { $r += New-Requisito 'Node.js' 'FALTA' 'no está instalado' $true 'Se puede instalar ahora (Node.js LTS).' 'Node' }
    elseif ($nv -lt $PanelNodeMinimo) { $r += New-Requisito 'Node.js' 'FALTA' "versión $nv; se necesita $($PanelNodeMinimo.Major) o superior" $true 'Se puede actualizar ahora (Node.js LTS).' 'Node' }
    else { $r += New-Requisito 'Node.js' 'OK' "v$nv" $true }

    # 5. Componentes de Windows que usa el panel: volumen, música, mezclador y envío de atajos de teclado
    if (-not $faltan.Count) {
        $lib = (Join-Path $Raiz 'lib') -replace "'", "''"
        $cmd = ". '$lib\media.ps1'; . '$lib\keys.ps1'; try { . '$lib\mezclador.ps1' } catch { }; `$v = Get-PanelVolume; " +
               "@{ vol = `$v.level; media = [bool]`$script:mediaMgr; keys = [bool]('PanelKeys' -as [type]); mezclador = [bool]('PanelMx.Mezclador' -as [type]) } | ConvertTo-Json -Compress"
        $out = Invoke-Nativo { powershell -NoProfile -ExecutionPolicy Bypass -Command $cmd }
        $j = $null; try { $j = ($out | Where-Object { $_ -match '^\{' } | Select-Object -Last 1) | ConvertFrom-Json } catch { }
        if (-not $j -or -not $j.keys) {
            $r += New-Requisito 'Componentes de Windows' 'FALTA' 'no se pudieron cargar' $true "Revisa .NET Framework. Detalle: $(($out | Select-Object -First 2) -join ' ')"
        } else {
            $partes = @('atajos de teclado')
            $partes += $(if ($j.vol -ne $null) { 'volumen' } else { 'volumen (sin salida de audio)' })
            $partes += $(if ($j.media) { 'música' } else { 'música (no disponible)' })
            $partes += $(if ($j.mezclador) { 'mezclador' } else { 'mezclador (no disponible)' })
            $estado = if ($j.vol -ne $null -and $j.media -and $j.mezclador) { 'OK' } else { 'AVISO' }
            $r += New-Requisito 'Componentes de Windows' $estado ($partes -join ', ') $true $(if ($estado -eq 'AVISO') { 'El panel funciona, pero esa parte no se mostrará.' })
        }
    }

    # 6. Puerto del panel
    $l = Get-NetTCPConnection -LocalPort $Puerto -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $l) { $r += New-Requisito "Puerto $Puerto" 'OK' 'libre' $true }
    else {
        $p = Get-CimInstance Win32_Process -Filter "ProcessId=$($l.OwningProcess)" -ErrorAction SilentlyContinue
        if ($p.Name -eq 'node.exe' -and $p.CommandLine -match 'server\.js') { $r += New-Requisito "Puerto $Puerto" 'OK' 'en uso por el panel (ya está abierto)' $true }
        else { $r += New-Requisito "Puerto $Puerto" 'FALTA' "lo usa otro programa ($($p.Name))" $true "Cierra ese programa o arranca el panel con otro puerto: .\iniciar.ps1 -Puerto 8788" }
    }

    # 7. Red local: el celular entra por la red Wi-Fi de la casa
    $cfg = Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } |
        Where-Object { $_.IPv4Address.IPAddress -match '^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)' } | Select-Object -First 1
    if (-not $cfg) { $r += New-Requisito 'Red local' 'FALTA' 'el PC no está conectado a una red local' $true 'Conecta el PC al router (por cable o Wi-Fi), en la misma red que el celular.' }
    else {
        $cat = "$((Get-NetConnectionProfile -InterfaceIndex $cfg.InterfaceIndex -ErrorAction SilentlyContinue).NetworkCategory)"
        $ip = @($cfg.IPv4Address.IPAddress)[0]
        if ($cat -eq 'Public') { $r += New-Requisito 'Red local' 'AVISO' "$ip en una red marcada como Pública" $false 'Si es la red de tu casa, márcala como Privada: Configuración > Red e Internet > propiedades de la red.' }
        else { $r += New-Requisito 'Red local' 'OK' "$ip, red privada" $true }
    }

    # 8. Firewall de Windows para Node.js
    $permitido = $false
    try {
        $permitido = [bool](Get-NetFirewallApplicationFilter -ErrorAction Stop | Where-Object { $_.Program -match '\\node\.exe$' } |
            Get-NetFirewallRule | Where-Object { $_.Enabled -eq 'True' -and $_.Direction -eq 'Inbound' -and $_.Action -eq 'Allow' -and ("$($_.Profile)" -match 'Private|Any') })
    } catch { }
    if ($permitido) { $r += New-Requisito 'Firewall' 'OK' 'Node.js permitido en redes privadas' $false }
    else { $r += New-Requisito 'Firewall' 'INFO' 'Node.js aún no tiene permiso' $false 'La primera vez que abras el panel, Windows preguntará: permite el acceso en redes privadas.' }


    # 9. Discord (opcional: solo para la página Discord)
    if (Test-Path "$env:LOCALAPPDATA\Discord\Update.exe") { $r += New-Requisito 'Discord (opcional)' 'OK' 'instalado' $false }
    else { $r += New-Requisito 'Discord (opcional)' 'INFO' 'no está instalado' $false 'Solo hace falta para los botones de la página Discord.' }

    return $r
}

function Show-Requisitos($Lista) {
    $colores = @{ OK = 'Green'; FALTA = 'Red'; AVISO = 'Yellow'; INFO = 'Gray' }
    foreach ($q in $Lista) {
        Write-Host ("[{0,-5}] " -f $q.Estado) -ForegroundColor $colores[$q.Estado] -NoNewline
        Write-Host ("{0,-24} {1}" -f $q.Nombre, $q.Detalle)
        if ($q.Estado -ne 'OK' -and $q.Solucion) { Write-Host ("        -> {0}" -f $q.Solucion) -ForegroundColor DarkGray }
    }
}

# Instala Node.js LTS con winget, o abre la página de descarga si no hay winget.
function Install-NodeLts {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "Instalando Node.js LTS con winget (Windows puede pedir permiso de administrador)..." -ForegroundColor Cyan
        winget install -e --id OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
        Update-RutaSesion
        $nv = Get-NodeVersion
        if ($nv -and $nv -lt $PanelNodeMinimo) {
            winget upgrade -e --id OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
            Update-RutaSesion
        }
    } else {
        Write-Host "No hay winget en este PC. Se abrirá la página oficial: descarga el instalador LTS de Windows y ejecútalo." -ForegroundColor Yellow
        Start-Process 'https://nodejs.org/es/download'
        Read-Host "Cuando termine la instalación, pulsa Enter para continuar"
        Update-RutaSesion
    }
}


# Verifica, muestra el resultado y, si se pide, ofrece instalar lo que falta. Devuelve $true si no falta nada obligatorio.
function Invoke-Verificacion([string]$Raiz, [int]$Puerto = 8787, [switch]$Instalar, [switch]$SinPreguntas) {
    Write-Host ""
    Write-Host "Revisando requisitos del panel..." -ForegroundColor Cyan
    $lista = Get-Requisitos $Raiz $Puerto
    Show-Requisitos $lista

    $instalables = @($lista | Where-Object { $_.Instalar -and $_.Estado -ne 'OK' })
    if ($Instalar -and $instalables.Count) {
        $hecho = $false
        foreach ($q in $instalables) {
            Write-Host ""
            $pregunta = '¿Instalar Node.js LTS ahora? (obligatorio para el panel)'
            if ($SinPreguntas) { Write-Host "$pregunta -> omitido (-SinPreguntas)" -ForegroundColor DarkGray; continue }
            $resp = Read-Host "$pregunta (S/N)"
            if ($resp -notmatch '^(s|si|sí|y|yes)$') { continue }
            Install-NodeLts
            $hecho = $true
        }
        if ($hecho) {
            Write-Host ""
            Write-Host "Revisando de nuevo..." -ForegroundColor Cyan
            $lista = Get-Requisitos $Raiz $Puerto
            Show-Requisitos $lista
        }
    }

    $faltan = @($lista | Where-Object { $_.Obligatorio -and $_.Estado -eq 'FALTA' })
    Write-Host ""
    if ($faltan.Count) { Write-Host "Falta lo obligatorio: $(($faltan.Nombre) -join ', '). El panel no arrancará hasta resolverlo." -ForegroundColor Red }
    else { Write-Host "Todo lo necesario está listo." -ForegroundColor Green }
    return ($faltan.Count -eq 0)
}
