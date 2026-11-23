# Panel del PC: ventana para arrancar y controlar el panel, sin consola. El celular entra por la red Wi-Fi de la casa.
# La abre "Panel del PC.exe" (lo crea instalar.cmd) o, si no existe, iniciar.cmd con PowerShell oculto.
#   ventana.ps1             puerto 8787
#   ventana.ps1 -Puerto N   otro puerto
# -Wifi se acepta y no hace nada: lo pasan los iconos "Panel Wi-Fi" de versiones anteriores.
# Para ver los mensajes del servidor en una consola, usa iniciar.ps1.
param([int]$Puerto = 8787, [switch]$Wifi)
$ErrorActionPreference = 'Stop'
$Raiz = $PSScriptRoot
Set-Location $Raiz
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# ---------- Idioma: español o inglés. Es el mismo para la ventana y para el celular: se guarda en data\preferencias.json
# y el servidor se lo pasa al celular. Los textos se escriben en español; T() da su traducción y TF() la rellena con datos.
$archivoPreferencias = Join-Path $Raiz 'data\preferencias.json'
function Get-IdiomaGuardado {
    try { $p = [IO.File]::ReadAllText($archivoPreferencias).TrimStart([char]0xFEFF) | ConvertFrom-Json; if ($p.idioma -in 'es', 'en') { return [string]$p.idioma } } catch { }
    if ((Get-UICulture).TwoLetterISOLanguageName -eq 'en') { 'en' } else { 'es' } # la primera vez, el de Windows
}
$script:idioma = Get-IdiomaGuardado
# Una traducción por línea: «español ⇒ inglés». {0}, {1}… son los datos que se rellenan.
$EN = New-Object 'Collections.Generic.Dictionary[string,string]'
foreach ($linea in @'
Faltan archivos del panel. Vuelve a descomprimir el .zip del panel completo. ⇒ Some panel files are missing. Unzip the full panel .zip again.
Arrancando… ⇒ Starting…
Buscando la red… ⇒ Looking for the network…
Arrancando el servidor… ⇒ Starting the server…
En marcha por Wi-Fi · {0} ⇒ Running over Wi-Fi · {0}
No está funcionando ⇒ Not running
Deteniendo… ⇒ Stopping…
{0} pide entrar: responde el aviso del PC ⇒ {0} wants to connect: answer the prompt on this PC
Preparando… ⇒ Getting ready…
Sin conexión ⇒ No connection
Faltan archivos del panel: {0}. Vuelve a descomprimir el .zip del panel completo. ⇒ Some panel files are missing: {0}. Unzip the full panel .zip again.
Node.js {0} es muy antiguo (se necesita la versión {1} o superior). La revisión de requisitos te ofrece instalarlo. ⇒ Node.js {0} is too old (version {1} or later is needed). The requirements check offers to install it.
No se encontró Node.js, que el panel necesita. La revisión de requisitos te ofrece instalarlo. ⇒ Node.js, which the panel needs, wasn't found. The requirements check offers to install it.
Revisar requisitos ⇒ Check requirements
Este PC no está conectado a una red local. Conéctalo al router (por cable o Wi-Fi), en la misma red que el celular. ⇒ This PC isn't connected to a local network. Connect it to the router (by cable or Wi-Fi), on the same network as your phone.
Reintentar ⇒ Try again
Windows tiene la red «{0}» marcada como Pública, así que el celular no podrá entrar. Si es la red de tu casa, cámbiala a Privada. ⇒ Windows has the network "{0}" marked as Public, so your phone won't be able to connect. If it's your home network, change it to Private.
Abrir configuración ⇒ Open settings
En marcha, pero el celular no puede entrar ⇒ Running, but your phone can't connect
El firewall de Windows todavía no deja que el celular entre al panel. Permítelo en el aviso de Windows, si apareció, o con este botón (Windows te pedirá permiso de administrador). ⇒ Windows Firewall isn't letting your phone into the panel yet. Allow it in the Windows prompt, if one appeared, or with this button (Windows will ask for administrator permission).
El firewall de Windows está bloqueando el panel, así que el celular no podrá entrar. Si Windows te está preguntando, elige Permitir; si no, este botón lo desbloquea (Windows te pedirá permiso de administrador). ⇒ Windows Firewall is blocking the panel, so your phone won't be able to connect. If Windows is asking you, choose Allow; if not, this button unblocks it (Windows will ask for administrator permission).
El firewall de Windows tiene activado «Bloquear todas las conexiones entrantes» en esta red, así que el celular no podrá entrar. Desactívalo en «Firewall y protección de red». ⇒ Windows Firewall has "Block all incoming connections" turned on for this network, so your phone won't be able to connect. Turn it off in "Firewall & network protection".
Permitir el acceso ⇒ Allow access
Abrir el firewall ⇒ Open the firewall
Listo: el celular ya puede entrar al panel. ⇒ Done: your phone can now connect to the panel.
No se cambió el firewall: no se dio el permiso de administrador. ⇒ The firewall wasn't changed: administrator permission wasn't given.
No se pudo cambiar el firewall de Windows. ⇒ Windows Firewall couldn't be changed.
Hay otra copia del panel abierta en el puerto {0}, probablemente en una ventana de consola. ⇒ Another copy of the panel is open on port {0}, probably in a console window.
Cerrarla y continuar ⇒ Close it and continue
No se pudo abrir Node.js: {0} ⇒ Couldn't start Node.js: {0}
El servidor del panel no arrancó. ⇒ The panel server didn't start.
El servidor del panel no arrancó: {0} ⇒ The panel server didn't start: {0}
El panel se detuvo. ⇒ The panel stopped.
El panel se detuvo: {0} ⇒ The panel stopped: {0}
Volver a arrancar ⇒ Start again
el puerto {0} lo está usando otro programa. ⇒ port {0} is being used by another program.
Windows no dejó abrir el puerto del panel. ⇒ Windows didn't allow opening the panel's port.
Aquí verás lo que hagas desde el celular y los dispositivos que pidan entrar. ⇒ Here you'll see what you do from your phone and the devices that ask to connect.
Error: {0} ⇒ Error: {0}
Error inesperado: {0} ⇒ Unexpected error: {0}
todavía no se ha conectado ⇒ hasn't connected yet
conectado ahora ⇒ connected now
hace un momento ⇒ a moment ago
hace {0} min ⇒ {0} min ago
hace {0} h ⇒ {0} h ago
Quitar ⇒ Remove
Dejar de permitir {0} ⇒ Stop allowing {0}
¿Quitar {0} de los dispositivos autorizados? ⇒ Remove {0} from the authorized devices?
Dejará de poder usar el panel. Si vuelve a escanear el código, este PC te preguntará otra vez. ⇒ It will no longer be able to use the panel. If it scans the code again, this PC will ask you again.
CONECTA TU CELULAR ⇒ CONNECT YOUR PHONE
Escanéalo con la cámara del celular. Tiene que estar en la misma red Wi-Fi que este PC. ⇒ Scan it with your phone's camera. It has to be on the same Wi-Fi network as this PC.
Copiar enlace ⇒ Copy link
Copiado ⇒ Copied
Copia la dirección completa del panel, para abrirla a mano en el celular ⇒ Copies the panel's full address, to open it by hand on your phone
Abrir en este PC ⇒ Open on this PC
Abre el panel en el navegador de este PC ⇒ Opens the panel in this PC's browser
Detener el panel ⇒ Stop the panel
Cierra el panel: el celular deja de poder usarlo hasta que lo vuelvas a abrir ⇒ Closes the panel: your phone can't use it until you open it again
Si cierras esta ventana, el panel sigue funcionando. Vuelve a ella desde el menú Inicio o desde el icono junto al reloj. ⇒ If you close this window, the panel keeps running. Come back to it from the Start menu or from the icon next to the clock.
DISPOSITIVOS AUTORIZADOS ⇒ AUTHORIZED DEVICES
Todavía ninguno. Escanea el código con el celular y acepta el aviso que aparecerá en este PC. ⇒ None yet. Scan the code with your phone and accept the prompt that will appear on this PC.
ACTIVIDAD ⇒ ACTIVITY
Mostrar la ventana ⇒ Show the window
El panel sigue funcionando ⇒ The panel is still running
Para volver a la ventana, haz clic en este icono o abre el panel desde el menú Inicio. Para cerrarlo del todo, usa «Detener el panel». ⇒ To get back to the window, click this icon or open the panel from the Start menu. To close it completely, use "Stop the panel".
Selección de widgets ⇒ Widget selection
Elige qué páginas ves en el celular y en qué orden ⇒ Choose which pages your phone shows, and in what order
Restablecer ⇒ Reset
Vuelve al orden original, con todas las páginas ⇒ Go back to the original order, with every page
Listo ⇒ Done
Activa las que quieres ver y arrástralas para cambiar el orden. La primera es la que aparece al conectar el celular, y cada cambio le llega al momento. ⇒ Turn on the ones you want and drag them to change the order. The first one is what your phone shows when it connects, and every change reaches it right away.
Para elegir las páginas del celular, el panel tiene que estar funcionando. ⇒ To choose the phone pages, the panel has to be running.
No se pudieron guardar las páginas: el panel no respondió. ⇒ The pages couldn't be saved: the panel didn't respond.
¿Volver al orden original, con todas las páginas? ⇒ Go back to the original order, with every page?
Al conectar ⇒ On connect
Oculta ⇒ Hidden
Sin vista previa ⇒ No preview
Mover {0} antes ⇒ Move {0} earlier
Mover {0} después ⇒ Move {0} later
Mover antes ⇒ Move earlier
Mover después ⇒ Move later
Mostrar {0} ⇒ Show {0}
Tiene que quedar al menos una página ⇒ At least one page has to stay
Inicio ⇒ Home
Mezclador ⇒ Mixer
Sistema ⇒ System
Rendimiento ⇒ Performance
Procesos ⇒ Processes
Enfoque ⇒ Focus
Calendario ⇒ Calendar
Comandos ⇒ Commands
Reloj, música, volumen y uso del PC ⇒ Clock, music, volume and PC usage
Volumen de cada aplicación y salida de audio ⇒ Volume of each app, and audio output
Indicadores y botones de atajos ⇒ Gauges and shortcut buttons
Historial de CPU, RAM y red, y cada núcleo ⇒ CPU, RAM and network history, and each core
Los programas que más CPU y memoria usan ⇒ The programs using the most CPU and memory
Pomodoro, tareas y accesos rápidos ⇒ Pomodoro, tasks and quick links
El mes con tu agenda, relojes del mundo y el clima ⇒ The month with your schedule, world clocks and the weather
Compartir pantalla, micrófono y más ⇒ Screen sharing, microphone and more
Botones de comandos y su consola ⇒ Command buttons and their console
'@ -split "`r?`n") {
    $partes = $linea -split ' ⇒ ', 2
    if ($partes.Count -eq 2) { $EN[$partes[0]] = $partes[1] }
}
function T([string]$Texto) { if ($script:idioma -eq 'en' -and $Texto -and $EN.ContainsKey($Texto)) { $EN[$Texto] } else { $Texto } }
function Format-Texto([string]$Texto, [object[]]$Datos) { $t = T $Texto; if ($Datos -and $Datos.Count) { $t -f $Datos } else { $t } }
function TF([string]$Formato) { Format-Texto $Formato $args }

if (-not (Test-Path (Join-Path $Raiz 'lib\requisitos.ps1')) -or -not (Test-Path (Join-Path $Raiz 'lib\arranque.ps1'))) {
    [void][Windows.MessageBox]::Show((T 'Faltan archivos del panel. Vuelve a descomprimir el .zip del panel completo.'), 'Panel del PC', 'OK', 'Error')
    return
}
. (Join-Path $Raiz 'lib\requisitos.ps1')
. (Join-Path $Raiz 'lib\arranque.ps1')

# Funciones nativas (barra de título oscura, pasar al frente). Ya vienen dentro de Panel del PC.exe; si no, se compilan.
if (-not ('PanelNativo' -as [type])) {
    try { Add-Type -Path (Join-Path $Raiz 'lib\lanzador.cs') -ReferencedAssemblies System.Windows.Forms } catch { }
}
$hayNativo = [bool]('PanelNativo' -as [type])

# Una sola ventana por puerto: si ya hay una abierta, se le pide que se muestre y esta termina.
$creada = $false
$mutex = New-Object Threading.Mutex($true, "Local\PanelDelPC-$Puerto", [ref]$creada)
$senal = New-Object Threading.EventWaitHandle($false, [Threading.EventResetMode]::AutoReset, "Local\PanelDelPC-$Puerto-mostrar")
if (-not $creada) {
    if ($hayNativo) { [PanelNativo]::PermitirPrimerPlano() }
    [void]$senal.Set()
    return
}

# ---------- Diseño (los mismos colores que el panel del celular)
$C = @{
    Fondo = '#07090C'; Tile = '#10141A'; Tile2 = '#161B23'; Texto = '#EEF1F6'; Tenue = '#7D8696'; Apagado = '#4B5363'
    Teal = '#2DD4BF'; Verde = '#4ADE80'; Naranja = '#FB923C'; Rojo = '#F87171'
}
$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Panel del PC" Width="780" SizeToContent="Height" ResizeMode="CanMinimize"
        WindowStartupLocation="CenterScreen" Background="#07090C" Foreground="#EEF1F6"
        FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="13" UseLayoutRounding="True">
  <Window.Resources>
    <SolidColorBrush x:Key="Tile" Color="#10141A"/>
    <SolidColorBrush x:Key="Tile2" Color="#161B23"/>
    <SolidColorBrush x:Key="Linea" Color="#12FFFFFF"/>
    <SolidColorBrush x:Key="Linea2" Color="#1FFFFFFF"/>
    <SolidColorBrush x:Key="Texto" Color="#EEF1F6"/>
    <SolidColorBrush x:Key="Tenue" Color="#7D8696"/>
    <SolidColorBrush x:Key="Teal" Color="#2DD4BF"/>
    <SolidColorBrush x:Key="Rojo" Color="#F87171"/>
    <Style x:Key="Tarjeta" TargetType="Border">
      <Setter Property="Background" Value="{StaticResource Tile}"/>
      <Setter Property="BorderBrush" Value="{StaticResource Linea}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="CornerRadius" Value="18"/>
      <Setter Property="Padding" Value="18,16"/>
    </Style>
    <Style x:Key="Etiqueta" TargetType="TextBlock">
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="FontWeight" Value="Bold"/>
      <Setter Property="Foreground" Value="{StaticResource Tenue}"/>
      <Setter Property="Margin" Value="0,0,0,12"/>
    </Style>
    <Style x:Key="Boton" TargetType="Button">
      <Setter Property="Foreground" Value="{StaticResource Texto}"/>
      <Setter Property="Background" Value="{StaticResource Tile2}"/>
      <Setter Property="BorderBrush" Value="{StaticResource Linea2}"/>
      <Setter Property="Padding" Value="14,8"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Caja" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="1" CornerRadius="10" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" RecognizesAccessKey="False"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Caja" Property="Opacity" Value="0.82"/></Trigger>
              <Trigger Property="IsPressed" Value="True"><Setter TargetName="Caja" Property="Opacity" Value="0.66"/></Trigger>
              <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Caja" Property="BorderBrush" Value="{StaticResource Teal}"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="Caja" Property="Opacity" Value="0.4"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="BotonPrincipal" TargetType="Button" BasedOn="{StaticResource Boton}">
      <Setter Property="Background" Value="{StaticResource Teal}"/>
      <Setter Property="BorderBrush" Value="{StaticResource Teal}"/>
      <Setter Property="Foreground" Value="#07090C"/>
    </Style>
    <Style x:Key="BotonPeligro" TargetType="Button" BasedOn="{StaticResource Boton}">
      <Setter Property="Background" Value="#1AF87171"/>
      <Setter Property="BorderBrush" Value="#40F87171"/>
      <Setter Property="Foreground" Value="{StaticResource Rojo}"/>
    </Style>
    <Style x:Key="BotonEnlace" TargetType="Button" BasedOn="{StaticResource Boton}">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="BorderBrush" Value="Transparent"/>
      <Setter Property="Foreground" Value="{StaticResource Tenue}"/>
      <Setter Property="Padding" Value="10,5"/>
      <Setter Property="FontSize" Value="12"/>
    </Style>
    <Style x:Key="Segmento" TargetType="Button" BasedOn="{StaticResource BotonEnlace}">
      <Setter Property="Padding" Value="14,6"/>
    </Style>
    <!-- Botón redondo sobre la vista previa de una página (mover antes o después) -->
    <Style x:Key="BotonFlotante" TargetType="Button" BasedOn="{StaticResource Boton}">
      <Setter Property="Background" Value="#E607090C"/>
      <Setter Property="BorderBrush" Value="#33FFFFFF"/>
      <Setter Property="Padding" Value="0"/>
      <Setter Property="Width" Value="30"/>
      <Setter Property="Height" Value="30"/>
    </Style>
    <!-- Interruptor (activar o quitar una página del celular); el texto va a la derecha y también se puede pulsar. -->
    <Style x:Key="Interruptor" TargetType="CheckBox">
      <Setter Property="Foreground" Value="{StaticResource Texto}"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Padding" Value="12,0,0,0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <DockPanel Background="Transparent">
              <Border x:Name="Pista" DockPanel.Dock="Left" Width="34" Height="20" CornerRadius="10" Background="#262C36"
                      BorderBrush="{StaticResource Linea2}" BorderThickness="1" VerticalAlignment="Center">
                <Ellipse x:Name="Bola" Width="14" Height="14" Fill="#7D8696" HorizontalAlignment="Left" Margin="2,0,0,0"/>
              </Border>
              <ContentPresenter Margin="{TemplateBinding Padding}" VerticalAlignment="Center" RecognizesAccessKey="False"/>
            </DockPanel>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="Pista" Property="Background" Value="#2DD4BF"/>
                <Setter TargetName="Pista" Property="BorderBrush" Value="#2DD4BF"/>
                <Setter TargetName="Bola" Property="Fill" Value="#07090C"/>
                <Setter TargetName="Bola" Property="HorizontalAlignment" Value="Right"/>
                <Setter TargetName="Bola" Property="Margin" Value="0,0,2,0"/>
              </Trigger>
              <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Pista" Property="BorderBrush" Value="#EEF1F6"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="Pista" Property="Opacity" Value="0.45"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <Grid Margin="20,16,20,20">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <DockPanel Grid.Row="0" Margin="0,0,0,16" LastChildFill="False">
      <Border x:Name="Logo" DockPanel.Dock="Left" Width="42" Height="42" CornerRadius="12" Margin="0,0,12,0"
              BorderBrush="{StaticResource Linea2}" BorderThickness="1"/>
      <StackPanel DockPanel.Dock="Left" VerticalAlignment="Center">
        <TextBlock Text="Panel del PC" FontSize="18" FontWeight="SemiBold"/>
        <StackPanel Orientation="Horizontal" Margin="0,2,0,0">
          <Ellipse x:Name="Punto" Width="8" Height="8" Fill="#FB923C" VerticalAlignment="Center" Margin="0,1,8,0"/>
          <TextBlock x:Name="Estado" Text="Arrancando…" Foreground="{StaticResource Tenue}"/>
        </StackPanel>
      </StackPanel>
      <!-- Idioma de la ventana y del celular; cada idioma se nombra en sí mismo -->
      <Border x:Name="Idiomas" DockPanel.Dock="Right" VerticalAlignment="Center" Background="{StaticResource Tile}"
              BorderBrush="{StaticResource Linea}" BorderThickness="1" CornerRadius="12" Padding="3">
        <StackPanel Orientation="Horizontal">
          <Button x:Name="IdiomaEs" Content="Español" Style="{StaticResource Segmento}"/>
          <Button x:Name="IdiomaEn" Content="English" Style="{StaticResource Segmento}"/>
        </StackPanel>
      </Border>
      <Button x:Name="AbrirPaginas" DockPanel.Dock="Right" Style="{StaticResource Boton}" Margin="0,0,10,0" Padding="12,7" VerticalAlignment="Center"
              AutomationProperties.Name="Selección de widgets" ToolTip="Elige qué páginas ves en el celular y en qué orden">
        <StackPanel Orientation="Horizontal">
          <Path Width="13" Height="13" Stretch="Uniform" Stroke="#2DD4BF" StrokeThickness="1.8" StrokeLineJoin="Round" Margin="0,0,8,0" VerticalAlignment="Center"
                Data="M4,4 L10,4 L10,10 L4,10 Z M14,4 L20,4 L20,10 L14,10 Z M4,14 L10,14 L10,20 L4,20 Z M14,14 L20,14 L20,20 L14,20 Z"/>
          <TextBlock Text="Selección de widgets"/>
        </StackPanel>
      </Button>
    </DockPanel>

    <Border x:Name="Aviso" Grid.Row="1" Visibility="Collapsed" CornerRadius="12" Padding="14,10" Margin="0,0,0,14" BorderThickness="1">
      <DockPanel>
        <Button x:Name="AvisoBoton" DockPanel.Dock="Right" Style="{StaticResource Boton}" Margin="14,0,0,0" Padding="12,6" VerticalAlignment="Center"/>
        <TextBlock x:Name="AvisoTexto" TextWrapping="Wrap" VerticalAlignment="Center" LineHeight="19"/>
      </DockPanel>
    </Border>

    <!-- Selección de widgets: una tarjeta por página, con su vista previa, en el orden en que salen en el celular
         (ocupa el lugar de la vista de conexión mientras está abierta) -->
    <DockPanel x:Name="VistaPaginas" Grid.Row="2" Visibility="Collapsed" LastChildFill="True">
      <DockPanel DockPanel.Dock="Top" Margin="0,0,0,16" LastChildFill="True">
        <StackPanel DockPanel.Dock="Right" Orientation="Horizontal" VerticalAlignment="Center" Margin="20,0,0,0">
          <Button x:Name="RestablecerPaginas" Content="Restablecer" Style="{StaticResource Boton}" Margin="0,0,10,0"
                  ToolTip="Vuelve al orden original, con todas las páginas"/>
          <Button x:Name="ListoPaginas" Content="Listo" Style="{StaticResource BotonPrincipal}" Padding="26,8"/>
        </StackPanel>
        <StackPanel VerticalAlignment="Center">
          <TextBlock Text="Selección de widgets" FontSize="16" FontWeight="SemiBold"/>
          <TextBlock Margin="0,3,0,0" Foreground="{StaticResource Tenue}" FontSize="12" TextWrapping="Wrap" LineHeight="17"
                     Text="Activa las que quieres ver y arrástralas para cambiar el orden. La primera es la que aparece al conectar el celular, y cada cambio le llega al momento."/>
        </StackPanel>
      </DockPanel>
      <!-- El margen negativo compensa el espacio que cada tarjeta deja a su derecha y debajo -->
      <UniformGrid x:Name="ListaPaginas" Columns="3" Margin="0,0,-16,-16"/>
    </DockPanel>

    <Grid x:Name="VistaConexion" Grid.Row="2">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="316"/>
        <ColumnDefinition Width="16"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>

      <Border Grid.Column="0" Style="{StaticResource Tarjeta}" MinHeight="420">
        <Grid>
          <StackPanel x:Name="VistaWifi">
            <TextBlock Text="CONECTA TU CELULAR" Style="{StaticResource Etiqueta}"/>
            <Border Background="White" CornerRadius="14" Padding="8" HorizontalAlignment="Center">
              <Grid Width="224" Height="224">
                <Image x:Name="Qr" RenderOptions.BitmapScalingMode="NearestNeighbor" Stretch="Uniform"/>
                <TextBlock x:Name="QrEspera" Text="Preparando…" Foreground="#7D8696" HorizontalAlignment="Center" VerticalAlignment="Center"/>
              </Grid>
            </Border>
            <TextBlock Margin="4,16,4,0" TextWrapping="Wrap" TextAlignment="Center" Foreground="{StaticResource Tenue}" LineHeight="19"
                       Text="Escanéalo con la cámara del celular. Tiene que estar en la misma red Wi-Fi que este PC."/>
            <Border Margin="0,16,0,0" Background="{StaticResource Tile2}" CornerRadius="10" Padding="12,3,3,3">
              <DockPanel>
                <Button x:Name="Copiar" DockPanel.Dock="Right" Content="Copiar enlace" Style="{StaticResource BotonEnlace}"
                        ToolTip="Copia la dirección completa del panel, para abrirla a mano en el celular"/>
                <TextBlock x:Name="Direccion" VerticalAlignment="Center" FontFamily="Cascadia Mono, Consolas" FontSize="12"
                           Foreground="{StaticResource Tenue}" TextTrimming="CharacterEllipsis"/>
              </DockPanel>
            </Border>
          </StackPanel>

        </Grid>
      </Border>

      <DockPanel Grid.Column="2" LastChildFill="True">
        <StackPanel DockPanel.Dock="Bottom" Margin="0,14,0,0">
          <DockPanel LastChildFill="False">
            <Button x:Name="AbrirPc" DockPanel.Dock="Left" Content="Abrir en este PC" Style="{StaticResource Boton}"
                    ToolTip="Abre el panel en el navegador de este PC"/>
            <Button x:Name="Detener" DockPanel.Dock="Right" Content="Detener el panel" Style="{StaticResource BotonPeligro}"
                    ToolTip="Cierra el panel: el celular deja de poder usarlo hasta que lo vuelvas a abrir"/>
          </DockPanel>
          <TextBlock Margin="2,12,0,0" FontSize="12" Foreground="{StaticResource Tenue}" TextWrapping="Wrap" LineHeight="17"
                     Text="Si cierras esta ventana, el panel sigue funcionando. Vuelve a ella desde el menú Inicio o desde el icono junto al reloj."/>
        </StackPanel>
        <Border x:Name="TarjetaDispositivos" DockPanel.Dock="Top" Style="{StaticResource Tarjeta}" Margin="0,0,0,14">
          <StackPanel>
            <TextBlock Text="DISPOSITIVOS AUTORIZADOS" Style="{StaticResource Etiqueta}"/>
            <StackPanel x:Name="ListaDispositivos"/>
            <TextBlock x:Name="SinDispositivos" Foreground="{StaticResource Tenue}" TextWrapping="Wrap" LineHeight="19"
                       Text="Todavía ninguno. Escanea el código con el celular y acepta el aviso que aparecerá en este PC."/>
          </StackPanel>
        </Border>
        <Border Style="{StaticResource Tarjeta}" ClipToBounds="True">
          <DockPanel>
            <TextBlock DockPanel.Dock="Top" Text="ACTIVIDAD" Style="{StaticResource Etiqueta}"/>
            <StackPanel x:Name="ListaActividad"/>
          </DockPanel>
        </Border>
      </DockPanel>
    </Grid>
  </Grid>
</Window>
'@

$w = [Windows.Markup.XamlReader]::Parse($xaml)
$ui = @{}
foreach ($n in 'Logo', 'Punto', 'Estado', 'Idiomas', 'IdiomaEs', 'IdiomaEn', 'Aviso', 'AvisoTexto', 'AvisoBoton', 'Qr', 'QrEspera',
    'Direccion', 'Copiar', 'TarjetaDispositivos', 'ListaDispositivos', 'SinDispositivos', 'ListaActividad', 'AbrirPc', 'Detener',
    'AbrirPaginas', 'VistaConexion', 'VistaPaginas', 'ListaPaginas', 'RestablecerPaginas', 'ListoPaginas') {
    $ui[$n] = $w.FindName($n)
}
try {
    $w.Icon = [Windows.Media.Imaging.BitmapFrame]::Create((New-Object Uri (Join-Path $Raiz 'panel.ico')))
    $logo = New-Object Windows.Media.Imaging.BitmapImage
    $logo.BeginInit(); $logo.UriSource = New-Object Uri (Join-Path $Raiz 'public\icon-192.png'); $logo.DecodePixelWidth = 96; $logo.CacheOption = 'OnLoad'; $logo.EndInit()
    $ui.Logo.Background = New-Object Windows.Media.ImageBrush $logo
} catch { }

# Textos fijos de la plantilla, en español, para traducirlos (y volver) al cambiar de idioma. Los que cambia el código
# (estado, aviso, QR, enlace) y los nombres de los idiomas no entran.
$script:textosFijos = New-Object Collections.ArrayList
$noTraducir = 'Estado', 'QrEspera', 'AvisoTexto', 'AvisoBoton', 'Direccion', 'Copiar', 'IdiomaEs', 'IdiomaEn'
function Find-TextosFijos($Elemento) {
    if ($Elemento -isnot [Windows.DependencyObject]) { return }
    if ($Elemento -is [Windows.FrameworkElement] -and $Elemento.Name -in $noTraducir) { return }
    $guardar = { param($P, $V) if ($V -is [string] -and $V.Trim()) { [void]$script:textosFijos.Add([pscustomobject]@{ E = $Elemento; P = $P; Es = $V }) } }
    if ($Elemento -is [Windows.Controls.TextBlock]) { & $guardar 'Text' $Elemento.Text }
    if ($Elemento -is [Windows.Controls.ContentControl]) { & $guardar 'Content' $Elemento.Content }
    if ($Elemento -is [Windows.FrameworkElement]) { & $guardar 'ToolTip' $Elemento.ToolTip }
    & $guardar 'Auto' ([Windows.Automation.AutomationProperties]::GetName($Elemento))
    foreach ($hijo in [Windows.LogicalTreeHelper]::GetChildren($Elemento)) { Find-TextosFijos $hijo }
}
Find-TextosFijos $w
function Set-TextosFijos {
    foreach ($f in $script:textosFijos) {
        $v = T $f.Es
        switch ($f.P) {
            'Text' { $f.E.Text = $v }
            'Content' { $f.E.Content = $v }
            'ToolTip' { $f.E.ToolTip = $v }
            'Auto' { [Windows.Automation.AutomationProperties]::SetName($f.E, $v) }
        }
    }
}

# ---------- Estado
$script:token = $null
$script:servidor = $null       # proceso de node (server.js)
$script:errServidor = $null    # lo que el servidor escribe en stderr (solo se lee si se cierra)
$script:lanIp = $null
$script:red = $null            # red local del PC (Get-PanelRed)
$script:accesoRed = $null      # por qué el celular no puede entrar: 'publica', 'sin-permiso', 'bloqueado', 'todo-bloqueado' o $null
$script:revisionRed = [datetime]::MinValue
$script:permisoEnCurso = $false
$script:url = $null
$script:qrPuesto = $false
$script:arrancando = $false
$script:saliendo = $false
$script:inicioHecho = $false
$script:avisoBandeja = $false
$script:avisoAccion = $null
$script:copiadoHasta = $null
$script:estadoNormal = @('Arrancando…', $C.Naranja, @())
$script:estadoActual = $script:estadoNormal
$script:avisoActual = $null
$script:qrEspera = 'Preparando…'
$script:eventosLocales = New-Object Collections.ArrayList
$script:eventosServidor = @()
$script:firmaActividad = $null
$script:firmaDispositivos = $null
$script:ticks = 0

# ---------- Ayudas de la interfaz
function Get-Pincel([string]$Hex) { $p = (New-Object Windows.Media.BrushConverter).ConvertFromString($Hex); $p.Freeze(); $p }

function New-Texto([string]$Texto, [string]$Color = $C.Texto, [double]$Tamano = 13, $Peso = [Windows.FontWeights]::Normal) {
    $t = New-Object Windows.Controls.TextBlock
    $t.Text = $Texto; $t.Foreground = Get-Pincel $Color; $t.FontSize = $Tamano; $t.FontWeight = $Peso; $t.TextWrapping = 'Wrap'
    $t
}

# Deja que la ventana se redibuje en medio de un paso largo (por ejemplo, mientras arranca el servidor).
function Update-Ui { $w.Dispatcher.Invoke([Action] {}, [Windows.Threading.DispatcherPriority]::Background) }

function Invoke-Seguro([scriptblock]$Bloque) {
    try { & $Bloque } catch { try { Add-EventoLocal 'Error: {0}' 'error' $_.Exception.Message } catch { } }
}

# El texto va en español (con {0}, {1}… para $Datos); se guarda así para volver a mostrarlo si cambia el idioma.
function Set-Estado([string]$Texto, [string]$Color, [switch]$Normal, [object[]]$Datos = @()) {
    $script:estadoActual = @($Texto, $Color, $Datos)
    if ($Normal) { $script:estadoNormal = $script:estadoActual }
    $t = Format-Texto $Texto $Datos
    $ui.Estado.Text = $t
    $ui.Punto.Fill = Get-Pincel $Color
    $b = "Panel del PC: $t"
    $tray.Text = if ($b.Length -gt 63) { $b.Substring(0, 63) } else { $b }
}

# $Clave marca de quién es el aviso, para quitarlo solo si sigue siendo ese.
function Show-Aviso([string]$Texto, [string]$Tipo = 'aviso', [string]$Boton, [scriptblock]$Accion, [object[]]$Datos = @(), [string]$Clave) {
    $script:avisoActual = @{ Texto = $Texto; Boton = $Boton; Datos = $Datos; Clave = $Clave }
    $color = @{ error = $C.Rojo; aviso = $C.Naranja; info = $C.Teal }[$Tipo]
    $ui.Aviso.Background = Get-Pincel ($color -replace '^#', '#1A')
    $ui.Aviso.BorderBrush = Get-Pincel ($color -replace '^#', '#4D')
    $ui.AvisoTexto.Text = Format-Texto $Texto $Datos
    $ui.AvisoBoton.Content = T $Boton
    $ui.AvisoBoton.Visibility = if ($Boton) { 'Visible' } else { 'Collapsed' }
    $script:avisoAccion = $Accion
    $ui.Aviso.Visibility = 'Visible'
}
function Hide-Aviso { $ui.Aviso.Visibility = 'Collapsed'; $script:avisoAccion = $null }

function Set-Fallo([string]$Texto, [string]$Boton, [scriptblock]$Accion, [object[]]$Datos = @()) {
    Hide-Paginas
    Set-Estado 'No está funcionando' $C.Rojo -Normal
    Show-Aviso $Texto 'error' $Boton $Accion $Datos
    Set-QrEspera 'Sin conexión'; $ui.Qr.Source = $null; $script:qrPuesto = $false
    Show-Ventana
}

function Set-QrEspera([string]$Texto) {
    $script:qrEspera = $Texto
    $ui.QrEspera.Text = T $Texto; $ui.QrEspera.Visibility = 'Visible'
}

# El idioma no depende del servidor: sus botones funcionan siempre.
function Set-Botones([bool]$Activos) {
    foreach ($b in $ui.AbrirPc, $ui.Detener, $ui.AbrirPaginas) { $b.IsEnabled = $Activos }
}

function Reset-VistaConexion {
    $ui.Qr.Source = $null; Set-QrEspera 'Preparando…'; $ui.Direccion.Text = ''
    $script:qrPuesto = $false; $script:url = $null; $script:firmaDispositivos = $null; $script:firmaActividad = $null
}

# ---------- Cambiar de idioma: se guarda, se avisa al servidor (que se lo pasa al celular) y se vuelve a dibujar todo.
function Set-Idioma([string]$Idioma) {
    if ($Idioma -notin 'es', 'en' -or $Idioma -eq $script:idioma) { return }
    $script:idioma = $Idioma
    try {
        $prefs = @{}
        if (Test-Path $archivoPreferencias) { ([IO.File]::ReadAllText($archivoPreferencias).TrimStart([char]0xFEFF) | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $prefs[$_.Name] = $_.Value } }
        $prefs.idioma = $Idioma
        New-Item -ItemType Directory -Force (Split-Path $archivoPreferencias) | Out-Null
        [IO.File]::WriteAllText($archivoPreferencias, ($prefs | ConvertTo-Json -Compress), (New-Object Text.UTF8Encoding $false))
    } catch { }
    [void](Invoke-PanelApi 'POST' '/api/pc/idioma' @{ idioma = $Idioma })
    Update-Idioma
}

function Update-Idioma {
    Set-TextosFijos
    foreach ($par in @(@($ui.IdiomaEs, 'es'), @($ui.IdiomaEn, 'en'))) {
        $on = $script:idioma -eq $par[1]
        $par[0].Background = Get-Pincel $(if ($on) { $C.Tile2 } else { '#00000000' })
        $par[0].BorderBrush = Get-Pincel $(if ($on) { '#1FFFFFFF' } else { '#00000000' })
        $par[0].Foreground = Get-Pincel $(if ($on) { $C.Texto } else { $C.Tenue })
    }
    $ui.Copiar.Content = T $(if ($script:copiadoHasta) { 'Copiado' } else { 'Copiar enlace' })
    $ui.Copiar.ToolTip = T 'Copia la dirección completa del panel, para abrirla a mano en el celular'
    $ui.QrEspera.Text = T $script:qrEspera
    Set-Estado $script:estadoActual[0] $script:estadoActual[1] -Datos $script:estadoActual[2]
    $a = $script:avisoActual
    if ($a -and $ui.Aviso.Visibility -eq 'Visible') { $ui.AvisoTexto.Text = Format-Texto $a.Texto $a.Datos; $ui.AvisoBoton.Content = T $a.Boton }
    $itemMostrar.Text = T 'Mostrar la ventana'; $itemAbrir.Text = T 'Abrir en este PC'; $itemDetener.Text = T 'Detener el panel'
    $script:firmaActividad = $null; Update-Actividad
    $script:firmaDispositivos = $null # los dispositivos se vuelven a dibujar con la próxima lectura
    if ($script:enPaginas) { Update-ListaPaginas }
}

# El código QR llega del servidor como filas de "0" y "1"; se dibuja como imagen, con un margen blanco.
function Set-Qr($Filas) {
    $n = $Filas.Count; $margen = 2; $lado = $n + 2 * $margen
    $px = New-Object byte[] ($lado * $lado)
    for ($i = 0; $i -lt $px.Length; $i++) { $px[$i] = 255 }
    for ($y = 0; $y -lt $n; $y++) {
        $fila = [string]$Filas[$y]
        for ($x = 0; $x -lt $n; $x++) { if ($fila[$x] -eq '1') { $px[($y + $margen) * $lado + $x + $margen] = 0 } }
    }
    $img = [Windows.Media.Imaging.BitmapSource]::Create($lado, $lado, 96, 96, [Windows.Media.PixelFormats]::Gray8, $null, $px, $lado)
    $img.Freeze()
    $ui.Qr.Source = $img
    $ui.QrEspera.Visibility = 'Collapsed'
    $script:qrPuesto = $true
}

# Lo de esta ventana se guarda en español y se traduce al mostrarlo; lo del servidor ya llega en el idioma de ese momento.
function Add-EventoLocal([string]$Mensaje, [string]$Tipo = 'local', [object[]]$Datos = @()) {
    [void]$script:eventosLocales.Add([pscustomobject]@{ t = [DateTimeOffset]::Now.ToUnixTimeMilliseconds(); tipo = $Tipo; msg = $Mensaje; datos = $Datos; local = $true })
    while ($script:eventosLocales.Count -gt 20) { $script:eventosLocales.RemoveAt(0) }
    Update-Actividad
}

# Lo que ha pasado (del servidor y de esta ventana), lo más reciente arriba.
function Update-Actividad {
    $todos = @(@($script:eventosServidor) + @($script:eventosLocales) | Where-Object { $_ } |
        Sort-Object { [double]$_.t } -Descending | Select-Object -First 7)
    $firma = "$($script:idioma)`n" + (($todos | ForEach-Object { "$($_.t)|$($_.msg)" }) -join "`n")
    if ($null -ne $script:firmaActividad -and $firma -eq $script:firmaActividad) { return }
    $script:firmaActividad = $firma
    $ui.ListaActividad.Children.Clear()
    if (-not $todos.Count) {
        [void]$ui.ListaActividad.Children.Add((New-Texto (T 'Aquí verás lo que hagas desde el celular y los dispositivos que pidan entrar.') $C.Tenue))
        return
    }
    foreach ($e in $todos) {
        $fila = New-Object Windows.Controls.DockPanel
        $fila.Margin = '0,0,0,8'
        $hora = New-Texto ([DateTimeOffset]::FromUnixTimeMilliseconds([long]$e.t).LocalDateTime.ToString('HH:mm')) $C.Apagado 12
        $hora.FontFamily = 'Cascadia Mono, Consolas'; $hora.Width = 48; $hora.TextWrapping = 'NoWrap'; $hora.Margin = '0,1,0,0'
        [Windows.Controls.DockPanel]::SetDock($hora, 'Left')
        $color = switch ($e.tipo) { 'rechazo' { $C.Naranja } 'error' { $C.Rojo } 'aprobacion' { $C.Teal } default { $C.Texto } }
        [void]$fila.Children.Add($hora)
        $msg = if ($e.local) { Format-Texto ([string]$e.msg) @($e.datos) } else { [string]$e.msg }
        [void]$fila.Children.Add((New-Texto $msg $color))
        [void]$ui.ListaActividad.Children.Add($fila)
    }
}

function Format-Hace($Ms) {
    if ($null -eq $Ms) { return (T 'todavía no se ha conectado') }
    $Ms = [double]$Ms
    if ($Ms -lt 20000) { T 'conectado ahora' }
    elseif ($Ms -lt 120000) { T 'hace un momento' }
    elseif ($Ms -lt 3600000) { TF 'hace {0} min' ([math]::Floor($Ms / 60000)) }
    else { TF 'hace {0} h' ([math]::Floor($Ms / 3600000)) }
}

function Update-Dispositivos($Lista) {
    $filas = @(@($Lista) | Where-Object { $_ } | ForEach-Object {
        $d = $_
        $detalle = @(([string]$d.equipo -replace '/', ' '), (Format-Hace $d.haceMs)) | Where-Object { $_ }
        [pscustomobject]@{ Ip = [string]$d.ip; Activo = ($null -ne $d.haceMs -and [double]$d.haceMs -lt 20000); Detalle = $detalle -join ' · ' }
    })
    $firma = ($filas | ForEach-Object { "$($_.Ip)|$($_.Activo)|$($_.Detalle)" }) -join "`n"
    if ($null -ne $script:firmaDispositivos -and $firma -eq $script:firmaDispositivos) { return }
    $script:firmaDispositivos = $firma
    $ui.ListaDispositivos.Children.Clear()
    $ui.SinDispositivos.Visibility = if ($filas.Count) { 'Collapsed' } else { 'Visible' }
    foreach ($f in $filas) {
        $fila = New-Object Windows.Controls.DockPanel
        $fila.Margin = '0,0,0,10'
        $punto = New-Object Windows.Shapes.Ellipse
        $punto.Width = 8; $punto.Height = 8; $punto.Margin = '0,6,12,0'; $punto.VerticalAlignment = 'Top'
        $punto.Fill = Get-Pincel $(if ($f.Activo) { $C.Verde } else { $C.Apagado })
        [Windows.Controls.DockPanel]::SetDock($punto, 'Left')
        $quitar = New-Object Windows.Controls.Button
        $quitar.Content = T 'Quitar'; $quitar.Style = $w.FindResource('BotonEnlace'); $quitar.Tag = $f.Ip; $quitar.VerticalAlignment = 'Center'
        $quitar.ToolTip = TF 'Dejar de permitir {0}' $f.Ip
        $quitar.Add_Click({ param($s) Invoke-Seguro { Remove-Dispositivo $s.Tag } })
        [Windows.Controls.DockPanel]::SetDock($quitar, 'Right')
        $textos = New-Object Windows.Controls.StackPanel
        [void]$textos.Children.Add((New-Texto $f.Ip $C.Texto 13 ([Windows.FontWeights]::SemiBold)))
        [void]$textos.Children.Add((New-Texto $f.Detalle $C.Tenue 12))
        [void]$fila.Children.Add($punto); [void]$fila.Children.Add($quitar); [void]$fila.Children.Add($textos)
        [void]$ui.ListaDispositivos.Children.Add($fila)
    }
}

function Show-Ventana {
    if (-not $w.IsVisible) { $w.Show() }
    if ($w.WindowState -eq 'Minimized') { $w.WindowState = 'Normal' }
    [void]$w.Activate()
    $w.Topmost = $true; $w.Topmost = $false
}

# ---------- Comunicación con el servidor (solo desde este PC, con el token)
function Invoke-PanelApi([string]$Metodo, [string]$Ruta, $Cuerpo = $null) {
    if (-not $script:token) { return $null }
    try {
        $r = [Net.HttpWebRequest]::Create("http://127.0.0.1:$Puerto$Ruta")
        $r.Method = $Metodo; $r.Timeout = 2000; $r.ReadWriteTimeout = 2000; $r.Proxy = $null
        $r.Headers.Add('x-panel-token', $script:token)
        if ($null -ne $Cuerpo) {
            $bytes = [Text.Encoding]::UTF8.GetBytes(($Cuerpo | ConvertTo-Json -Compress))
            $r.ContentType = 'application/json'; $r.ContentLength = $bytes.Length
            $s = $r.GetRequestStream(); $s.Write($bytes, 0, $bytes.Length); $s.Close()
        } elseif ($Metodo -eq 'POST') { $r.ContentLength = 0 }
        $resp = $r.GetResponse()
        $lector = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
        $texto = $lector.ReadToEnd(); $lector.Close(); $resp.Close()
        return ($texto | ConvertFrom-Json)
    } catch { return $null }
}

function Format-ErrorServidor([string]$Texto) {
    if ($Texto -match 'EADDRINUSE') { return (TF 'el puerto {0} lo está usando otro programa.' $Puerto) }
    if ($Texto -match 'EACCES|EADDRNOTAVAIL') { return (T 'Windows no dejó abrir el puerto del panel.') }
    $lineas = @($Texto -split "`r?`n" | Where-Object { $_ -match '\S' })
    $linea = ($lineas | Where-Object { $_ -match 'Error' } | Select-Object -First 1)
    if (-not $linea) { $linea = $lineas | Select-Object -Last 1 }
    ("$linea" -replace '\s+', ' ').Trim()
}

# ---------- Arranque y parada
function Stop-Servidor {
    $p = $script:servidor
    $script:servidor = $null
    if ($p -and -not $p.HasExited) {
        [void](Invoke-PanelApi 'POST' '/api/pc/detener')
        if (-not $p.WaitForExit(3000)) { try { $p.Kill() } catch { } }
    }
}

function Start-Flujo {
    if ($script:arrancando) { return }
    $script:arrancando = $true
    try { Start-Pasos } finally { $script:arrancando = $false; Set-Botones $true }
}

function Start-Pasos {
    Hide-Paginas
    Set-Botones $false
    Hide-Aviso
    $script:accesoRed = $null
    Reset-VistaConexion
    Set-Estado 'Arrancando…' $C.Naranja -Normal
    Update-Ui

    # 1. Archivos y Node.js
    $faltan = Get-ArchivosFaltantes $Raiz
    if ($faltan.Count) { Set-Fallo 'Faltan archivos del panel: {0}. Vuelve a descomprimir el .zip del panel completo.' -Datos ($faltan -join ', '); return }
    $nv = Get-NodeVersion
    if (-not $nv) { Update-RutaSesion; $nv = Get-NodeVersion }
    if (-not $nv -or $nv -lt $PanelNodeMinimo) {
        $requisitos = { Start-Process (Join-Path $Raiz 'verificar.cmd') }
        if ($nv) { Set-Fallo 'Node.js {0} es muy antiguo (se necesita la versión {1} o superior). La revisión de requisitos te ofrece instalarlo.' 'Revisar requisitos' $requisitos -Datos $nv, $PanelNodeMinimo.Major }
        else { Set-Fallo 'No se encontró Node.js, que el panel necesita. La revisión de requisitos te ofrece instalarlo.' 'Revisar requisitos' $requisitos }
        return
    }
    $script:token = Get-PanelToken $Raiz
    Initialize-PanelConfig $Raiz

    # 2. Red local
    Set-Estado 'Buscando la red…' $C.Naranja; Update-Ui
    $red = Get-PanelRed
    if (-not $red) {
        Set-Fallo 'Este PC no está conectado a una red local. Conéctalo al router (por cable o Wi-Fi), en la misma red que el celular.' 'Reintentar' { Start-Flujo }
        return
    }
    $script:lanIp = $red.Ip
    $script:red = $red

    # 3. ¿Ya hay un panel en marcha en este puerto? Si es uno de esta misma red, se usa; si no (por ejemplo, uno de una
    #    versión anterior abierto por cable), se cierra.
    $script:servidor = $null; $script:errServidor = $null
    if (Test-Panel $Puerto) {
        $e = Invoke-PanelApi 'GET' '/api/pc'
        if (-not $e) {
            Set-Fallo 'Hay otra copia del panel abierta en el puerto {0}, probablemente en una ventana de consola.' 'Cerrarla y continuar' {
                if (Stop-OtraCopia $Puerto) { Start-Sleep -Milliseconds 1000 }
                Start-Flujo
            } -Datos $Puerto
            return
        }
        $proc = Get-ProcesoEnPuerto $Puerto
        if ($proc -and $e.modo -eq 'wifi' -and $e.lanIp -eq $script:lanIp) { $script:servidor = $proc }
        else {
            [void](Invoke-PanelApi 'POST' '/api/pc/detener')
            if ($proc) { [void]$proc.WaitForExit(3000) }
        }
    }
    if ($script:servidor) { [void](Invoke-PanelApi 'POST' '/api/pc/idioma' @{ idioma = $script:idioma }) }

    # 4. Arranca el servidor y espera a que responda
    if (-not $script:servidor) {
        Set-Estado 'Arrancando el servidor…' $C.Naranja; Update-Ui
        try { $script:servidor = Start-PanelServidor $Raiz $Puerto $script:token $script:lanIp }
        catch { Set-Fallo 'No se pudo abrir Node.js: {0}' 'Revisar requisitos' { Start-Process (Join-Path $Raiz 'verificar.cmd') } -Datos $_.Exception.Message; return }
        $script:errServidor = $script:servidor.StandardError.ReadToEndAsync()
        $ok = $false
        for ($i = 0; $i -lt 40; $i++) {
            if ((Test-Panel $Puerto) -and (Test-Panel $Puerto $script:lanIp)) { $ok = $true; break }
            if ($script:servidor.HasExited) { break }
            Start-Sleep -Milliseconds 250; Update-Ui
        }
        if (-not $ok) {
            Stop-Servidor
            $detalle = if ($script:errServidor -and $script:errServidor.Wait(1000)) { Format-ErrorServidor $script:errServidor.Result } else { '' }
            if ($detalle) { Set-Fallo 'El servidor del panel no arrancó: {0}' 'Reintentar' { Start-Flujo } -Datos $detalle }
            else { Set-Fallo 'El servidor del panel no arrancó.' 'Reintentar' { Start-Flujo } }
            return
        }
    }

    # 5. Listo, si el celular puede entrar (red Privada y permiso en el firewall)
    Set-Estado 'En marcha por Wi-Fi · {0}' $C.Verde -Normal -Datos $script:lanIp
    Update-AccesoRed -Forzar
    Update-Tick -Forzar
}

# ---------- ¿Puede entrar el celular? La red tiene que estar marcada como Privada y el firewall de Windows tiene que dejar
# pasar al Node.js del panel. Desde este PC no se nota si no es así (sus conexiones no pasan por el firewall), así que se
# revisa al arrancar y, mientras haya un problema, cada 5 s: el aviso se quita solo en cuanto se arregla (por ejemplo, al
# elegir Permitir en el aviso de Windows o al cambiar la red a Privada).
function Get-ProgramaServidor {
    $p = $null
    try { $p = $script:servidor.Path } catch { }
    if ($p) { $p } else { Get-PanelNodeRuta }
}

function Update-AccesoRed([switch]$Forzar) {
    $red = $script:red
    if (-not $red -or -not $script:servidor) { return }
    $script:revisionRed = Get-Date
    $categoria = "$((Get-NetConnectionProfile -InterfaceIndex $red.Interfaz -ErrorAction SilentlyContinue).NetworkCategory)"
    if ($categoria) { $red.Categoria = $categoria }
    $estado = $null
    if ($red.Categoria -eq 'Public') { $estado = 'publica' }
    else {
        $fw = Get-PanelFirewall (Get-ProgramaServidor) $red.Categoria
        if ($fw -in 'sin-permiso', 'bloqueado', 'todo-bloqueado') { $estado = $fw }
    }
    $antes = $script:accesoRed
    if ($estado -eq $antes -and -not $Forzar) {
        # Si el aviso se escondió (al pulsar su botón o al abrir las páginas) y el problema sigue, vuelve a mostrarse.
        if ($estado -and $ui.Aviso.Visibility -ne 'Visible' -and -not $script:enPaginas) { Show-AvisoRed }
        return
    }
    $script:accesoRed = $estado
    if ($estado) {
        Set-Estado 'En marcha, pero el celular no puede entrar' $C.Naranja -Normal
        Show-AvisoRed
    } else {
        Set-Estado 'En marcha por Wi-Fi · {0}' $C.Verde -Normal -Datos $script:lanIp
        if ($script:avisoActual -and $script:avisoActual.Clave -eq 'red') { Hide-Aviso }
        if ($antes) { Add-EventoLocal 'Listo: el celular ya puede entrar al panel.' }
    }
}

function Show-AvisoRed {
    switch ($script:accesoRed) {
        'publica' { Show-Aviso 'Windows tiene la red «{0}» marcada como Pública, así que el celular no podrá entrar. Si es la red de tu casa, cámbiala a Privada.' 'aviso' 'Abrir configuración' { Start-Process 'ms-settings:network' } -Datos $script:red.Nombre -Clave 'red' }
        'sin-permiso' { Show-Aviso 'El firewall de Windows todavía no deja que el celular entre al panel. Permítelo en el aviso de Windows, si apareció, o con este botón (Windows te pedirá permiso de administrador).' 'aviso' 'Permitir el acceso' { Grant-AccesoFirewall } -Clave 'red' }
        # Mientras Windows hace su pregunta, ya ha puesto una regla que bloquea (la cambia a permitir si se elige Permitir).
        'bloqueado' { Show-Aviso 'El firewall de Windows está bloqueando el panel, así que el celular no podrá entrar. Si Windows te está preguntando, elige Permitir; si no, este botón lo desbloquea (Windows te pedirá permiso de administrador).' 'aviso' 'Permitir el acceso' { Grant-AccesoFirewall } -Clave 'red' }
        'todo-bloqueado' { Show-Aviso 'El firewall de Windows tiene activado «Bloquear todas las conexiones entrantes» en esta red, así que el celular no podrá entrar. Desactívalo en «Firewall y protección de red».' 'aviso' 'Abrir el firewall' { Start-Process 'windowsdefender://network/' } -Clave 'red' }
    }
}

# Botón «Permitir el acceso»: da permiso al Node.js del panel en el firewall, con el aviso de administrador de Windows.
function Grant-AccesoFirewall {
    if ($script:permisoEnCurso) { return }
    $script:permisoEnCurso = $true
    try {
        try { $p = Start-PermisoFirewall (Get-ProgramaServidor) $script:red.Categoria }
        catch { Add-EventoLocal 'No se cambió el firewall: no se dio el permiso de administrador.' 'error'; return }
        $hasta = (Get-Date).AddSeconds(60)
        while (-not $p.HasExited -and (Get-Date) -lt $hasta) { Start-Sleep -Milliseconds 100; Update-Ui }
        $bien = $false
        try { $bien = $p.HasExited -and $p.ExitCode -eq 0 } catch { }
        if (-not $bien) { Add-EventoLocal 'No se pudo cambiar el firewall de Windows.' 'error' }
    } finally {
        $script:permisoEnCurso = $false
        Update-AccesoRed -Forzar
    }
}

function Exit-Panel {
    if ($script:saliendo) { return }
    $script:saliendo = $true
    $reloj.Stop(); $relojSenal.Stop()
    Set-Estado 'Deteniendo…' $C.Naranja
    Set-Botones $false
    Update-Ui
    Stop-Servidor
    $tray.Visible = $false
    $tray.Dispose()
    $w.Close()
    $app.Shutdown()
}

# ---------- Actualización periódica
function Update-Tick([switch]$Forzar) {
    if (($script:arrancando -and -not $Forzar) -or $script:saliendo) { return }
    $script:ticks++
    if (-not $script:servidor) { return }
    if ($script:servidor.HasExited) {
        $detalle = if ($script:errServidor -and $script:errServidor.Wait(500)) { Format-ErrorServidor $script:errServidor.Result } else { '' }
        $script:servidor = $null
        if ($detalle) { Set-Fallo 'El panel se detuvo: {0}' 'Volver a arrancar' { Start-Flujo } -Datos $detalle }
        else { Set-Fallo 'El panel se detuvo.' 'Volver a arrancar' { Start-Flujo } }
        return
    }
    $e = Invoke-PanelApi 'GET' '/api/pc'
    if ($e) {
        if (-not $script:qrPuesto -and $e.qr) {
            Set-Qr @($e.qr)
            $script:url = $e.url
            $ui.Direccion.Text = "$($e.lanIp):$($e.puerto)"
        }
        Update-Dispositivos $e.dispositivos
        $script:eventosServidor = @($e.actividad)
        Update-Actividad
        if ($e.pendiente) { Set-Estado '{0} pide entrar: responde el aviso del PC' $C.Teal -Datos $e.pendiente }
        else { Set-Estado $script:estadoNormal[0] $script:estadoNormal[1] -Datos $script:estadoNormal[2] }
    }
    if ($script:accesoRed -and -not $script:permisoEnCurso -and ((Get-Date) - $script:revisionRed).TotalSeconds -ge 5) { Update-AccesoRed }
}

function Remove-Dispositivo([string]$Ip) {
    $texto = (TF '¿Quitar {0} de los dispositivos autorizados?' $Ip) + "`n`n" + (T 'Dejará de poder usar el panel. Si vuelve a escanear el código, este PC te preguntará otra vez.')
    $r = [Windows.MessageBox]::Show($w, $texto, 'Panel del PC', 'YesNo', 'Question')
    if ("$r" -ne 'Yes') { return }
    [void](Invoke-PanelApi 'POST' '/api/pc/quitar' @{ ip = $Ip })
    $script:firmaDispositivos = $null
    Update-Tick
}

function Open-EnPc { if ($script:token) { Start-Process "http://localhost:$Puerto/#t=$($script:token)" } }

# ---------- Selección de widgets: cuáles se ven y en qué orden. Las guarda el servidor (data\paginas.json) y el celular
# las recibe con cada lectura del estado, así que cada cambio se guarda en el acto.
$script:paginas = @()
$script:enPaginas = $false
$script:miniaturas = @{}                                              # id → imagen de la vista previa (o $null)
$script:tarjetasDe = @{}; $script:marcosDe = @{}; $script:flechasDe = @{} # id → partes de su tarjeta
$script:arrastre = $null; $script:movimiento = $null; $script:destino = ''

function Show-Paginas {
    $r = Invoke-PanelApi 'GET' '/api/pc/paginas'
    if (-not $r) { Show-Aviso 'Para elegir las páginas del celular, el panel tiene que estar funcionando.' 'aviso'; return }
    Hide-Aviso
    $script:paginas = @($r.paginas)
    Update-ListaPaginas
    $ui.VistaPaginas.MinHeight = $ui.VistaConexion.ActualHeight # la ventana no cambia de alto al pasar de una vista a otra
    $ui.VistaConexion.Visibility = 'Collapsed'; $ui.VistaPaginas.Visibility = 'Visible'
    $ui.AbrirPaginas.Visibility = 'Collapsed'
    $script:enPaginas = $true
}

function Hide-Paginas {
    if (-not $script:enPaginas) { return }
    $script:enPaginas = $false
    $ui.VistaPaginas.Visibility = 'Collapsed'; $ui.VistaConexion.Visibility = 'Visible'
    $ui.AbrirPaginas.Visibility = 'Visible'
}

function Save-Paginas($Lista, [string]$Foco) {
    $cuerpo = @{ paginas = @(@($Lista) | Where-Object { $_ } | ForEach-Object { @{ id = [string]$_.id; ver = [bool]$_.ver } }) }
    $r = Invoke-PanelApi 'POST' '/api/pc/paginas' $cuerpo
    if (-not $r) { Show-Aviso 'No se pudieron guardar las páginas: el panel no respondió.' 'error' }
    else { $script:paginas = @($r.paginas) }
    Update-ListaPaginas $Foco
}

function Move-Pagina([string]$Id, [int]$Paso) {
    $l = @($script:paginas).Clone() # copia: si no se puede guardar, la lista de la ventana no cambia
    $i = 0; while ($i -lt $l.Count -and $l[$i].id -ne $Id) { $i++ }
    $j = $i + $Paso
    if ($i -ge $l.Count -or $j -lt 0 -or $j -ge $l.Count) { return }
    $t = $l[$i]; $l[$i] = $l[$j]; $l[$j] = $t
    Save-Paginas $l "$Paso|$Id"
}

function Set-PaginaVisible([string]$Id, [bool]$Ver) {
    $l = @($script:paginas | ForEach-Object { @{ id = $_.id; ver = $(if ($_.id -eq $Id) { $Ver } else { [bool]$_.ver }) } })
    Save-Paginas $l "ver|$Id"
}

function Reset-Paginas {
    $r = [Windows.MessageBox]::Show($w, (T '¿Volver al orden original, con todas las páginas?'), 'Panel del PC', 'YesNo', 'Question')
    if ("$r" -eq 'Yes') { Save-Paginas @() }
}

# Arrastrar y soltar: la página arrastrada ocupa el lugar de la tarjeta sobre la que se suelta.
function Move-PaginaA([string]$Id, [string]$DestinoId) {
    $l = New-Object Collections.ArrayList
    $l.AddRange(@($script:paginas))
    $i = -1; $j = -1
    for ($k = 0; $k -lt $l.Count; $k++) { if ($l[$k].id -eq $Id) { $i = $k }; if ($l[$k].id -eq $DestinoId) { $j = $k } }
    if ($i -lt 0 -or $j -lt 0 -or $i -eq $j) { return }
    $p = $l[$i]; $l.RemoveAt($i); $l.Insert($j, $p)
    Save-Paginas @($l) ''
}

# Mientras se arrastra, la tarjeta se ve tenue; si se suelta sobre otra, el cambio se hace al terminar el arrastre.
function Start-ArrastrePagina($Marco, [string]$Id) {
    $tarjeta = $script:tarjetasDe[$Id]
    if ($tarjeta) { $tarjeta.Opacity = 0.4 }
    $script:movimiento = $null
    try { [void][Windows.DragDrop]::DoDragDrop($Marco, (New-Object Windows.DataObject('PanelPagina', $Id)), [Windows.DragDropEffects]::Move) }
    finally { if ($tarjeta) { $tarjeta.Opacity = 1 }; Set-DestinoPagina '' }
    $m = $script:movimiento; $script:movimiento = $null
    if ($m) { Move-PaginaA $m[0] $m[1] }
}

function Set-DestinoPagina([string]$Id) {
    $antes = $script:destino
    if ($antes -eq $Id) { return }
    $script:destino = $Id
    Update-TarjetaPagina $antes; Update-TarjetaPagina $Id
}

# Las flechas aparecen al pasar el ratón por la tarjeta o al llegar a ella con el teclado; el borde se ilumina igual,
# y en verde azulado si es donde se va a soltar la que se arrastra.
function Update-TarjetaPagina([string]$Id) {
    if (-not $Id -or -not $script:tarjetasDe[$Id]) { return }
    $t = $script:tarjetasDe[$Id]; $m = $script:marcosDe[$Id]
    $activa = $t.IsMouseOver -or $t.IsKeyboardFocusWithin
    $script:flechasDe[$Id].Opacity = if ($activa) { 1 } else { 0 }
    if ($script:destino -eq $Id) { $m.BorderBrush = Get-Pincel $C.Teal; $m.BorderThickness = 2 }
    else { $m.BorderBrush = Get-Pincel $(if ($activa) { '#59FFFFFF' } else { '#1FFFFFFF' }); $m.BorderThickness = 1 }
}

# Vista previa de cada página en el idioma de la ventana (public\miniaturas\<página>.jpg, y en inglés en
# public\miniaturas\en; las genera herramientas\miniaturas.js). Se cargan una vez; si falta la del inglés se usa la del
# español, y si falta también, la tarjeta lo dice y todo lo demás funciona igual.
function Get-Miniatura([string]$Id) {
    $clave = "$($script:idioma)|$Id"
    if ($script:miniaturas.ContainsKey($clave)) { return $script:miniaturas[$clave] }
    $img = $null
    $ruta = Join-Path $Raiz "public\miniaturas\$Id.jpg"
    $rutaEn = Join-Path $Raiz "public\miniaturas\en\$Id.jpg"
    if ($script:idioma -eq 'en' -and (Test-Path $rutaEn)) { $ruta = $rutaEn }
    if (Test-Path $ruta) {
        try {
            $img = New-Object Windows.Media.Imaging.BitmapImage
            $img.BeginInit(); $img.UriSource = New-Object Uri $ruta; $img.DecodePixelWidth = 480; $img.CacheOption = 'OnLoad'; $img.EndInit()
            $img.Freeze()
        } catch { $img = $null }
    }
    $script:miniaturas[$clave] = $img
    $img
}

# Etiqueta sobre la vista previa ("Al conectar", "Oculta"). Radio 6: el del marco (14) menos los 8 px que la separan de su
# esquina, para que las dos curvas vayan paralelas.
function New-Pastilla([string]$Texto, [string]$Color, [string]$Punto) {
    $b = New-Object Windows.Controls.Border
    $b.Background = Get-Pincel '#E607090C'; $b.BorderBrush = Get-Pincel '#33FFFFFF'; $b.BorderThickness = 1
    $b.CornerRadius = 6; $b.Padding = '9,3,10,4'; $b.IsHitTestVisible = $false
    $sp = New-Object Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'
    if ($Punto) {
        $o = New-Object Windows.Shapes.Ellipse
        $o.Width = 6; $o.Height = 6; $o.Fill = Get-Pincel $Punto; $o.Margin = '0,1,6,0'; $o.VerticalAlignment = 'Center'
        [void]$sp.Children.Add($o)
    }
    $t = New-Texto (T $Texto) $Color 11 ([Windows.FontWeights]::SemiBold)
    $t.TextWrapping = 'NoWrap'
    [void]$sp.Children.Add($t)
    $b.Child = $sp
    $b
}

function New-Flecha([string]$Id, [int]$Paso, [bool]$Activa, [string]$Nombre) {
    $b = New-Object Windows.Controls.Button
    $b.Style = $w.FindResource('BotonFlotante')
    $p = New-Object Windows.Shapes.Path
    $p.Data = [Windows.Media.Geometry]::Parse($(if ($Paso -lt 0) { 'M15,6 L9,12 L15,18' } else { 'M9,6 L15,12 L9,18' }))
    $p.Stroke = Get-Pincel $C.Texto; $p.StrokeThickness = 2; $p.Width = 11; $p.Height = 11; $p.Stretch = 'Uniform'
    $p.StrokeStartLineCap = 'Round'; $p.StrokeEndLineCap = 'Round'; $p.StrokeLineJoin = 'Round'
    $b.Content = $p
    $b.IsEnabled = $Activa
    $b.Tag = "$Paso|$Id"
    [Windows.Automation.AutomationProperties]::SetName($b, $(if ($Paso -lt 0) { TF 'Mover {0} antes' $Nombre } else { TF 'Mover {0} después' $Nombre }))
    $b.ToolTip = if ($Paso -lt 0) { T 'Mover antes' } else { T 'Mover después' }
    $b.Add_Click({ param($s) Invoke-Seguro { $t = ([string]$s.Tag).Split('|', 2); Move-Pagina $t[1] ([int]$t[0]) } })
    $b
}

# Una tarjeta por página, en el orden del celular: la vista previa (tenue y con «Oculta» si no se ve; «Al conectar» en la
# primera), con flechas para moverla; debajo, su número en el celular (o «–»), el nombre y el interruptor.
# $Foco ("-1|id", "1|id" o "ver|id") devuelve el foco al mismo control si el cambio se hizo con el teclado.
function Update-ListaPaginas([string]$Foco) {
    $ui.ListaPaginas.Children.Clear()
    $script:tarjetasDe = @{}; $script:marcosDe = @{}; $script:flechasDe = @{}; $script:destino = ''
    $l = @($script:paginas)
    $visibles = @($l | Where-Object { $_.ver }).Count
    $n = 0; $controles = @{}
    for ($i = 0; $i -lt $l.Count; $i++) {
        $p = $l[$i]; $ver = [bool]$p.ver; $id = [string]$p.id; $nombre = T ([string]$p.nombre)
        if ($ver) { $n++ }
        $tarjeta = New-Object Windows.Controls.StackPanel
        $tarjeta.Margin = '0,0,16,16'; $tarjeta.Tag = $id; $tarjeta.AllowDrop = $true; $tarjeta.Background = Get-Pincel '#00000000'
        $tarjeta.ToolTip = T ([string]$p.detalle)

        # Vista previa
        $vista = New-Object Windows.Controls.Grid
        $vista.Height = 104
        $marco = New-Object Windows.Controls.Border
        $marco.CornerRadius = 14; $marco.BorderThickness = 1; $marco.BorderBrush = Get-Pincel '#1FFFFFFF'; $marco.Tag = $id
        $marco.Cursor = [Windows.Input.Cursors]::Hand
        $img = Get-Miniatura $id
        if ($img) {
            $pincel = New-Object Windows.Media.ImageBrush $img
            $pincel.Stretch = 'UniformToFill'; $pincel.AlignmentY = 'Top'
            $marco.Background = $pincel
        } else {
            $marco.Background = Get-Pincel $C.Tile2
            $sin = New-Texto (T 'Sin vista previa') $C.Apagado 12
            $sin.HorizontalAlignment = 'Center'; $sin.VerticalAlignment = 'Center'
            $marco.Child = $sin
        }
        if (-not $ver) { $marco.Opacity = 0.3 }
        [void]$vista.Children.Add($marco)
        if ($ver -and $n -eq 1) {
            $primera = New-Pastilla 'Al conectar' $C.Texto $C.Teal
            $primera.HorizontalAlignment = 'Left'; $primera.VerticalAlignment = 'Top'; $primera.Margin = '8'
            [void]$vista.Children.Add($primera)
        }
        if (-not $ver) {
            $oculta = New-Pastilla 'Oculta' $C.Texto $null
            $oculta.HorizontalAlignment = 'Center'; $oculta.VerticalAlignment = 'Center'
            [void]$vista.Children.Add($oculta)
        }
        $flechas = New-Object Windows.Controls.StackPanel
        $flechas.Orientation = 'Horizontal'; $flechas.HorizontalAlignment = 'Right'; $flechas.VerticalAlignment = 'Top'
        $flechas.Margin = '0,8,8,0'; $flechas.Opacity = 0
        $antes = New-Flecha $id -1 ($i -gt 0) $nombre
        $antes.Margin = '0,0,6,0'
        $despues = New-Flecha $id 1 ($i -lt $l.Count - 1) $nombre
        [void]$flechas.Children.Add($antes); [void]$flechas.Children.Add($despues)
        [void]$vista.Children.Add($flechas)

        # Pie
        $pie = New-Object Windows.Controls.DockPanel
        $pie.Margin = '2,10,0,0'
        $avatar = New-Object Windows.Controls.Border
        $avatar.Width = 26; $avatar.Height = 26; $avatar.CornerRadius = 8; $avatar.BorderThickness = 1 # cuadrado redondeado, como los marcos
        $avatar.Background = Get-Pincel $(if ($ver) { '#262DD4BF' } else { $C.Tile2 })
        $avatar.BorderBrush = Get-Pincel $(if ($ver) { '#592DD4BF' } else { '#1FFFFFFF' })
        $num = New-Texto $(if ($ver) { "$n" } else { '–' }) $(if ($ver) { $C.Teal } else { $C.Apagado }) 12 ([Windows.FontWeights]::SemiBold)
        $num.TextWrapping = 'NoWrap'; $num.HorizontalAlignment = 'Center'; $num.VerticalAlignment = 'Center'
        $avatar.Child = $num
        [Windows.Controls.DockPanel]::SetDock($avatar, 'Left')
        $chk = New-Object Windows.Controls.CheckBox
        $chk.Style = $w.FindResource('Interruptor'); $chk.Padding = '0'; $chk.IsChecked = $ver; $chk.Tag = $id; $chk.VerticalAlignment = 'Center'
        [Windows.Controls.DockPanel]::SetDock($chk, 'Right')
        [Windows.Automation.AutomationProperties]::SetName($chk, (TF 'Mostrar {0}' $nombre))
        if ($ver -and $visibles -eq 1) {
            $chk.IsEnabled = $false
            $chk.ToolTip = T 'Tiene que quedar al menos una página'
            [Windows.Controls.ToolTipService]::SetShowOnDisabled($chk, $true)
        }
        # Checked/Unchecked (y no Click): así también funciona desde el teclado y con lectores de pantalla.
        $chk.Add_Checked({ param($s) Invoke-Seguro { Set-PaginaVisible ([string]$s.Tag) $true } })
        $chk.Add_Unchecked({ param($s) Invoke-Seguro { Set-PaginaVisible ([string]$s.Tag) $false } })
        $titulo = New-Texto $nombre $(if ($ver) { $C.Texto } else { $C.Tenue }) 14 ([Windows.FontWeights]::SemiBold)
        $titulo.TextWrapping = 'NoWrap'; $titulo.TextTrimming = 'CharacterEllipsis'; $titulo.Margin = '10,0,8,1'; $titulo.VerticalAlignment = 'Center'
        [void]$pie.Children.Add($avatar); [void]$pie.Children.Add($chk); [void]$pie.Children.Add($titulo)
        [void]$tarjeta.Children.Add($vista); [void]$tarjeta.Children.Add($pie)

        # Pasar el ratón o llegar con el teclado
        $tarjeta.Add_MouseEnter({ param($s) Update-TarjetaPagina ([string]$s.Tag) })
        $tarjeta.Add_MouseLeave({ param($s) Update-TarjetaPagina ([string]$s.Tag) })
        $tarjeta.Add_IsKeyboardFocusWithinChanged({ param($s) Update-TarjetaPagina ([string]$s.Tag) })
        # Arrastrar desde la vista previa (las flechas y las pastillas no empiezan un arrastre)
        $marco.Add_PreviewMouseLeftButtonDown({ param($s, $e) $script:arrastre = @{ Id = [string]$s.Tag; Punto = $e.GetPosition($w) } })
        $marco.Add_PreviewMouseLeftButtonUp({ $script:arrastre = $null })
        $marco.Add_PreviewMouseMove({ param($s, $e)
            $a = $script:arrastre
            if (-not $a -or $e.LeftButton -ne [Windows.Input.MouseButtonState]::Pressed) { return }
            $q = $e.GetPosition($w)
            if ([math]::Abs($q.X - $a.Punto.X) -lt [Windows.SystemParameters]::MinimumHorizontalDragDistance -and
                [math]::Abs($q.Y - $a.Punto.Y) -lt [Windows.SystemParameters]::MinimumVerticalDragDistance) { return }
            $script:arrastre = $null
            Invoke-Seguro { Start-ArrastrePagina $s $a.Id }
        })
        # Soltar sobre otra tarjeta
        $tarjeta.Add_DragOver({ param($s, $e)
            $o = if ($e.Data.GetDataPresent('PanelPagina')) { [string]$e.Data.GetData('PanelPagina') } else { '' }
            if ($o -and $o -ne [string]$s.Tag) { $e.Effects = [Windows.DragDropEffects]::Move; Set-DestinoPagina ([string]$s.Tag) }
            else { $e.Effects = [Windows.DragDropEffects]::None; Set-DestinoPagina '' }
            $e.Handled = $true
        })
        $tarjeta.Add_DragLeave({ param($s, $e)
            $q = $e.GetPosition($s)
            if (($q.X -lt 0 -or $q.Y -lt 0 -or $q.X -ge $s.ActualWidth -or $q.Y -ge $s.ActualHeight) -and $script:destino -eq [string]$s.Tag) { Set-DestinoPagina '' }
        })
        $tarjeta.Add_Drop({ param($s, $e)
            $o = if ($e.Data.GetDataPresent('PanelPagina')) { [string]$e.Data.GetData('PanelPagina') } else { '' }
            if ($o -and $o -ne [string]$s.Tag) { $script:movimiento = @($o, [string]$s.Tag) }
            $e.Handled = $true
        })

        [void]$ui.ListaPaginas.Children.Add($tarjeta)
        $script:tarjetasDe[$id] = $tarjeta; $script:marcosDe[$id] = $marco; $script:flechasDe[$id] = $flechas
        $controles["-1|$id"] = $antes; $controles["1|$id"] = $despues; $controles["ver|$id"] = $chk
    }
    if ($Foco -and [Windows.Input.InputManager]::Current.MostRecentInputDevice -is [Windows.Input.KeyboardDevice]) {
        $c = $controles[$Foco]
        # Si la página llegó arriba (o abajo) del todo, esa flecha ya no se puede usar: el foco pasa a la otra.
        if ($c -and -not $c.IsEnabled -and $Foco -notlike 'ver|*') { $t = $Foco.Split('|', 2); $c = $controles["$(-[int]$t[0])|$($t[1])"] }
        if ($c -and $c.IsEnabled) { $ui.ListaPaginas.UpdateLayout(); [void]$c.Focus() }
    }
}

# ---------- Icono junto al reloj
$tray = New-Object Windows.Forms.NotifyIcon
try { $tray.Icon = New-Object Drawing.Icon((Join-Path $Raiz 'panel.ico'), [Windows.Forms.SystemInformation]::SmallIconSize) } catch { $tray.Icon = [Drawing.SystemIcons]::Application }
$tray.Text = 'Panel del PC'
$menu = New-Object Windows.Forms.ContextMenuStrip
$itemMostrar = $menu.Items.Add('Mostrar la ventana'); $itemMostrar.Font = New-Object Drawing.Font($itemMostrar.Font, [Drawing.FontStyle]::Bold)
$itemMostrar.Add_Click({ Invoke-Seguro { Show-Ventana } })
$itemAbrir = $menu.Items.Add('Abrir en este PC')
$itemAbrir.Add_Click({ Invoke-Seguro { Open-EnPc } })
[void]$menu.Items.Add((New-Object Windows.Forms.ToolStripSeparator))
$itemDetener = $menu.Items.Add('Detener el panel')
$itemDetener.Add_Click({ Invoke-Seguro { Exit-Panel } })
$tray.ContextMenuStrip = $menu
$tray.Add_MouseClick({ param($s, $e) if ($e.Button -eq [Windows.Forms.MouseButtons]::Left) { Invoke-Seguro { Show-Ventana } } })
$tray.Add_BalloonTipClicked({ Invoke-Seguro { Show-Ventana } })
$tray.Visible = $true

# ---------- Eventos de la ventana
$ui.AvisoBoton.Add_Click({ Invoke-Seguro { $accion = $script:avisoAccion; Hide-Aviso; if ($accion) { & $accion } } })
$ui.Copiar.Add_Click({ Invoke-Seguro {
    if ($script:url) { [Windows.Clipboard]::SetText($script:url); $ui.Copiar.Content = T 'Copiado'; $script:copiadoHasta = (Get-Date).AddSeconds(2) }
} })
$ui.AbrirPc.Add_Click({ Invoke-Seguro { Open-EnPc } })
$ui.Detener.Add_Click({ Invoke-Seguro { Exit-Panel } })
$ui.IdiomaEs.Add_Click({ Invoke-Seguro { Set-Idioma 'es' } })
$ui.IdiomaEn.Add_Click({ Invoke-Seguro { Set-Idioma 'en' } })
$ui.AbrirPaginas.Add_Click({ Invoke-Seguro { Show-Paginas } })
$ui.ListoPaginas.Add_Click({ Invoke-Seguro { Hide-Paginas } })
$ui.RestablecerPaginas.Add_Click({ Invoke-Seguro { Reset-Paginas } })
$w.Add_KeyDown({ param($s, $e) if ($e.Key -eq 'Escape' -and $script:enPaginas) { Invoke-Seguro { Hide-Paginas } } })

# Cerrar la ventana la esconde: el panel sigue funcionando y se vuelve a ella desde el icono o el menú Inicio.
# Si el panel no está funcionando (por ejemplo, porque falló al arrancar), cerrarla lo cierra todo.
$w.Add_Closing({ param($s, $e)
    if ($script:saliendo) { return }
    $e.Cancel = $true
    if (-not $script:servidor -and -not $script:arrancando) { [void]$w.Dispatcher.BeginInvoke([Action] { Invoke-Seguro { Exit-Panel } }); return }
    $w.Hide()
    if (-not $script:avisoBandeja) {
        $script:avisoBandeja = $true
        $tray.ShowBalloonTip(6000, (T 'El panel sigue funcionando'),
            (T 'Para volver a la ventana, haz clic en este icono o abre el panel desde el menú Inicio. Para cerrarlo del todo, usa «Detener el panel».'),
            [Windows.Forms.ToolTipIcon]::Info)
    }
})
$w.Add_SourceInitialized({
    if ($hayNativo) { try { [PanelNativo]::BarraOscura((New-Object Windows.Interop.WindowInteropHelper $w).Handle, 0x07090C, 0x1B2029) } catch { } }
})
$w.Add_ContentRendered({
    if ($script:inicioHecho) { return }
    $script:inicioHecho = $true
    [void]$w.Dispatcher.BeginInvoke([Action] { Invoke-Seguro { Start-Flujo } }, [Windows.Threading.DispatcherPriority]::Background)
})

# Cada 1,5 s: estado del servidor (QR, dispositivos y actividad).
$reloj = New-Object Windows.Threading.DispatcherTimer
$reloj.Interval = [TimeSpan]::FromMilliseconds(1500)
$reloj.Add_Tick({ Invoke-Seguro { Update-Tick } })
# Cada 0,4 s: si se volvió a abrir el panel desde el menú Inicio, se muestra esta ventana.
$relojSenal = New-Object Windows.Threading.DispatcherTimer
$relojSenal.Interval = [TimeSpan]::FromMilliseconds(400)
$relojSenal.Add_Tick({ Invoke-Seguro {
    if ($senal.WaitOne(0)) { Show-Ventana }
    if ($script:copiadoHasta -and (Get-Date) -gt $script:copiadoHasta) { $script:copiadoHasta = $null; $ui.Copiar.Content = T 'Copiar enlace' }
} })

Reset-VistaConexion
Update-Idioma
$reloj.Start()
$relojSenal.Start()
$app = New-Object Windows.Application
$app.ShutdownMode = [Windows.ShutdownMode]::OnExplicitShutdown
$app.Add_DispatcherUnhandledException({ param($s, $e)
    $e.Handled = $true
    try { Add-EventoLocal 'Error inesperado: {0}' 'error' $e.Exception.Message } catch { }
})
try { [void]$app.Run($w) }
finally {
    if ($script:servidor -and -not $script:servidor.HasExited) { try { $script:servidor.Kill() } catch { } }
    try { $tray.Dispose() } catch { }
    try { $mutex.ReleaseMutex() } catch { }
}
