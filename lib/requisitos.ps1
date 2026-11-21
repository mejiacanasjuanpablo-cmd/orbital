# Verificación de requisitos del panel. La usan verificar.ps1, instalar.ps1, iniciar.ps1 y empaquetar.ps1.
# Solo define funciones y listas; no hace nada al cargarse.

# Archivos sin los que el panel no funciona (también son los que se empaquetan, junto con la guía y los instaladores).
$PanelArchivos = @(
    'server.js', 'config.ejemplo.json', 'panel.ico',
    'iniciar.ps1', 'iniciar.cmd', 'iniciar-wifi.cmd',
    'lib\allow.js', 'lib\keys.ps1', 'lib\media.ps1', 'lib\requisitos.ps1',
    'public\index.html', 'public\manifest.webmanifest', 'public\icon-192.png', 'public\icon-512.png'
)
# server.js usa fetch y AbortSignal.timeout, disponibles desde Node.js 18.
$PanelNodeMinimo = [version]'18.0.0'

function Find-Adb {
    $cmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidates = @("$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe", "$env:LOCALAPPDATA\Microsoft\WinGet\Links\adb.exe")
    $candidates += Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Google.PlatformTools*" -Recurse -Filter adb.exe -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName
    foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { return $c } }
    return $null
}

function Get-NodeVersion {
    try { $v = (& node --version 2>$null) -replace '^v', ''; if ($v) { return [version]$v } } catch { }
    return $null
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
        $r += New-Requisito 'Archivos del panel' 'FALTA' "faltan: $($faltan -join ', ')" $true 'Vuelve a descomprimir Panel-USB.zip completo, en una carpeta fija (no lo abras desde dentro del .zip).'
    } else { $r += New-Requisito 'Archivos del panel' 'OK' "$($PanelArchivos.Count) archivos" $true }

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

    # 5. Componentes de Windows que usa el panel: volumen, música y envío de atajos de teclado
    if (-not $faltan.Count) {
        $lib = (Join-Path $Raiz 'lib') -replace "'", "''"
        $cmd = ". '$lib\media.ps1'; . '$lib\keys.ps1'; `$v = Get-PanelVolume; " +
               "@{ vol = `$v.level; media = [bool]`$script:mediaMgr; keys = [bool]('PanelKeys' -as [type]) } | ConvertTo-Json -Compress"
        $out = Invoke-Nativo { powershell -NoProfile -ExecutionPolicy Bypass -Command $cmd }
        $j = $null; try { $j = ($out | Where-Object { $_ -match '^\{' } | Select-Object -Last 1) | ConvertFrom-Json } catch { }
        if (-not $j -or -not $j.keys) {
            $r += New-Requisito 'Componentes de Windows' 'FALTA' 'no se pudieron cargar' $true "Revisa .NET Framework. Detalle: $(($out | Select-Object -First 2) -join ' ')"
        } else {
            $partes = @('atajos de teclado')
            $partes += $(if ($j.vol -ne $null) { 'volumen' } else { 'volumen (sin salida de audio)' })
            $partes += $(if ($j.media) { 'música' } else { 'música (no disponible)' })
            $estado = if ($j.vol -ne $null -and $j.media) { 'OK' } else { 'AVISO' }
            $r += New-Requisito 'Componentes de Windows' $estado ($partes -join ', ') $true $(if ($estado -eq 'AVISO') { 'El panel funciona, pero esa parte no se mostrará.' })
        }
    }

    # 6. adb (solo para el modo USB)
    $adb = Find-Adb
    if ($adb) {
        $ver = (Invoke-Nativo { & $adb version } | Select-Object -First 1) -replace '.*version ', ''
        $r += New-Requisito 'adb (modo USB)' 'OK' "versión $ver" $false
    } else {
        $r += New-Requisito 'adb (modo USB)' 'AVISO' 'no está instalado; solo hace falta para usar el cable' $false 'Se puede instalar ahora (herramientas oficiales de Google).' 'Adb'
    }

    # 7. Puerto del panel
    $l = Get-NetTCPConnection -LocalPort $Puerto -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $l) { $r += New-Requisito "Puerto $Puerto" 'OK' 'libre' $true }
    else {
        $p = Get-CimInstance Win32_Process -Filter "ProcessId=$($l.OwningProcess)" -ErrorAction SilentlyContinue
        if ($p.Name -eq 'node.exe' -and $p.CommandLine -match 'server\.js') { $r += New-Requisito "Puerto $Puerto" 'OK' 'en uso por el panel (ya está abierto)' $true }
        else { $r += New-Requisito "Puerto $Puerto" 'FALTA' "lo usa otro programa ($($p.Name))" $true "Cierra ese programa o arranca el panel con otro puerto: .\iniciar.ps1 -Puerto 8788" }
    }

    # 8. Red local (solo para el modo Wi-Fi)
    $cfg = Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } |
        Where-Object { $_.IPv4Address.IPAddress -match '^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)' } | Select-Object -First 1
    if (-not $cfg) { $r += New-Requisito 'Red (modo Wi-Fi)' 'AVISO' 'el PC no está conectado a una red local' $false 'El modo USB funciona igual. Para el Wi-Fi, conecta el PC al router.' }
    else {
        $cat = "$((Get-NetConnectionProfile -InterfaceIndex $cfg.InterfaceIndex -ErrorAction SilentlyContinue).NetworkCategory)"
        $ip = @($cfg.IPv4Address.IPAddress)[0]
        if ($cat -eq 'Public') { $r += New-Requisito 'Red (modo Wi-Fi)' 'AVISO' "$ip en una red marcada como Pública" $false 'Si es la red de tu casa, márcala como Privada: Configuración > Red e Internet > propiedades de la red.' }
        else { $r += New-Requisito 'Red (modo Wi-Fi)' 'OK' "$ip, red privada" $false }
    }

    # 9. Firewall de Windows para Node.js (solo para el modo Wi-Fi)
    $permitido = $false
    try {
        $permitido = [bool](Get-NetFirewallApplicationFilter -ErrorAction Stop | Where-Object { $_.Program -match '\\node\.exe$' } |
            Get-NetFirewallRule | Where-Object { $_.Enabled -eq 'True' -and $_.Direction -eq 'Inbound' -and $_.Action -eq 'Allow' -and ("$($_.Profile)" -match 'Private|Any') })
    } catch { }
    if ($permitido) { $r += New-Requisito 'Firewall (modo Wi-Fi)' 'OK' 'Node.js permitido en redes privadas' $false }
    else { $r += New-Requisito 'Firewall (modo Wi-Fi)' 'INFO' 'Node.js aún no tiene permiso' $false 'La primera vez que abras Panel Wi-Fi, Windows preguntará: permite el acceso en redes privadas.' }

    # 10. Celular (opcional: solo si está conectado por cable)
    if ($adb) {
        Invoke-Nativo { & $adb start-server } | Out-Null
        $lineas = Invoke-Nativo { & $adb devices } | Select-Object -Skip 1 | Where-Object { $_ -match '\S' -and $_ -notmatch '^\*' }
        $listo = $lineas | Where-Object { $_ -match '\tdevice$' } | Select-Object -First 1
        if ($listo) {
            $serial = ($listo -split "`t")[0]
            $model = "$(Invoke-Nativo { & $adb -s $serial shell getprop ro.product.model } | Select-Object -First 1)".Trim()
            $chrome = (Invoke-Nativo { & $adb -s $serial shell pm list packages com.android.chrome }) -join ' '
            if ($chrome -match 'package:com\.android\.chrome') { $r += New-Requisito 'Celular' 'OK' "$model conectado, con Chrome" $false }
            else { $r += New-Requisito 'Celular' 'AVISO' "$model conectado, pero sin Google Chrome" $false 'Instala Google Chrome en el celular desde Play Store.' }
        } elseif ($lineas -match 'unauthorized') {
            $r += New-Requisito 'Celular' 'AVISO' 'conectado pero sin autorizar' $false "Desbloquéalo y acepta 'Permitir depuración USB' (marca 'Permitir siempre')."
        } else {
            $pnp = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue
            $adbIf = $pnp | Where-Object { $_.FriendlyName -match 'ADB' }
            if ($adbIf | Where-Object { $_.Status -ne 'OK' }) {
                $r += New-Requisito 'Celular' 'AVISO' 'Windows ve el celular pero falla el controlador ADB' $false 'Instala el controlador USB del fabricante del celular (o el Google USB Driver) y vuelve a conectarlo.'
            } elseif (-not $adbIf -and ($pnp | Where-Object { $_.Class -eq 'WPD' -and $_.FriendlyName -notmatch 'Volume|Volumen' })) {
                $r += New-Requisito 'Celular' 'INFO' 'hay un dispositivo conectado, pero sin depuración USB' $false 'En el celular: Opciones de desarrollador > activa Depuración USB.'
            } else {
                $r += New-Requisito 'Celular' 'INFO' 'no hay ninguno conectado por cable' $false 'Opcional: conéctalo para revisarlo también.'
            }
        }
    }

    # 11. Discord (opcional: solo para la página Discord)
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

# Descarga adb directamente de Google (dl.google.com), comprueba la firma digital de Google y lo deja en
# %LOCALAPPDATA%\Android\Sdk\platform-tools. Es más fiable que winget, cuyo paquete a veces falla por cambios del archivo.
function Install-AdbGoogle([string]$Destino = "$env:LOCALAPPDATA\Android\Sdk") {
    $url = 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip'
    $id = [guid]::NewGuid().ToString('N')
    $zip = Join-Path $env:TEMP "platform-tools-$id.zip"
    $tmp = Join-Path $env:TEMP "platform-tools-$id"
    $prevProg = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
    try {
        Write-Host "Descargando adb desde dl.google.com..." -ForegroundColor Cyan
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest $url -OutFile $zip -UseBasicParsing
        Expand-Archive $zip -DestinationPath $tmp -Force
        $nuevo = Join-Path $tmp 'platform-tools\adb.exe'
        if (-not (Test-AdbFirmado $nuevo)) { throw 'la firma digital de adb.exe no es de Google; no se instaló' }
        $actual = Join-Path $Destino 'platform-tools\adb.exe'
        if (Test-Path $actual) { Invoke-Nativo { & $actual kill-server } | Out-Null; Start-Sleep -Milliseconds 500 }
        New-Item -ItemType Directory -Force $Destino | Out-Null
        Copy-Item (Join-Path $tmp 'platform-tools') $Destino -Recurse -Force
        Write-Host "adb instalado en $Destino\platform-tools" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "No se pudo instalar adb: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    } finally {
        $ProgressPreference = $prevProg
        Remove-Item $zip, $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Test-AdbFirmado([string]$Ruta) {
    $s = Get-AuthenticodeSignature $Ruta
    return ($s.Status -eq 'Valid' -and $s.SignerCertificate.Subject -match 'O=Google')
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
            if ($q.Instalar -eq 'Node') { $pregunta = '¿Instalar Node.js LTS ahora? (obligatorio para el panel)' }
            else { $pregunta = '¿Descargar e instalar adb ahora? (unos 15 MB desde dl.google.com; solo para el modo USB)' }
            if ($SinPreguntas) { Write-Host "$pregunta -> omitido (-SinPreguntas)" -ForegroundColor DarkGray; continue }
            $resp = Read-Host "$pregunta (S/N)"
            if ($resp -notmatch '^(s|si|sí|y|yes)$') { continue }
            if ($q.Instalar -eq 'Node') { Install-NodeLts } else { [void](Install-AdbGoogle) }
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
