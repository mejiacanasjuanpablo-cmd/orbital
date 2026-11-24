# Orbital: ventana para arrancar y controlar el panel, sin consola. El celular entra por la red Wi-Fi de la casa.
# La abre "Orbital.exe" (lo crea instalar.cmd) o, si no existe, iniciar.cmd con PowerShell oculto.
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
Personaliza las pantallas ⇒ Customize the screens
Conecta el celular ⇒ Connect your phone
Personalizar sin el celular ⇒ Customize without the phone
Oculta esta tarjeta hasta que un celular se conecte y se vuelva a desconectar ⇒ Hides this card until a phone connects and disconnects again
Más ⇒ More
Dispositivos, actividad y abrir en este PC ⇒ Devices, activity and open on this PC
Pantalla completa (F11) ⇒ Full screen (F11)
Salir de pantalla completa (F11 o Esc) ⇒ Exit full screen (F11 or Esc)
Cambiar a modo claro ⇒ Switch to light mode
Cambiar a modo oscuro ⇒ Switch to dark mode
Atajos ⇒ Shortcuts
Edita los botones de la página Sistema del celular ⇒ Edit the buttons on your phone's System page
Vuelve a los atajos de ejemplo ⇒ Goes back to the sample shortcuts
Los botones de la página Sistema del celular (hasta {0}). Pulsa uno para editarlo y arrástralos para cambiar el orden; cada cambio le llega al celular al momento. ⇒ The buttons on your phone's System page (up to {0}). Click one to edit it and drag them to change the order; every change reaches your phone right away.
Para editar los atajos, el panel tiene que estar funcionando. ⇒ To edit the shortcuts, the panel has to be running.
El panel no respondió. ⇒ The panel didn't respond.
¿Volver a los atajos de ejemplo? Se pierden los que cambiaste. ⇒ Go back to the sample shortcuts? The ones you changed will be lost.
No se pudieron guardar los atajos: {0} ⇒ The shortcuts couldn't be saved: {0}
Abre {0} ⇒ Opens {0}
Teclas: {0} ⇒ Keys: {0}
Comando de PowerShell ⇒ PowerShell command
Pulsa para editarlo; arrástralo para cambiar el orden ⇒ Click to edit it; drag it to change the order
Editar {0} ⇒ Edit {0}
Agregar atajo ⇒ Add shortcut
Nuevo atajo ⇒ New shortcut
Así se verá el botón en la página Sistema del celular. ⇒ This is how the button will look on your phone's System page.
Sin nombre ⇒ No name
Color {0} ⇒ Color {0}
Icono {0} ⇒ Icon {0}
NOMBRE ⇒ NAME
COLOR ⇒ COLOR
ICONO ⇒ ICON
QUÉ HACE ⇒ WHAT IT DOES
Abrir ⇒ Open
Atajo de teclado ⇒ Keyboard shortcut
Comando ⇒ Command
Programa, carpeta, archivo o página web ⇒ Program, folder, file or web page
Examinar… ⇒ Browse…
Argumentos (opcional) ⇒ Arguments (optional)
Por ejemplo: calc.exe, https://www.google.com, una carpeta como C:\Users o shell:Downloads. ⇒ For example: calc.exe, https://www.google.com, a folder like C:\Users, or shell:Downloads.
Haz clic en el recuadro y pulsa la combinación de teclas ⇒ Click the box and press the key combination
Combinación de teclas ⇒ Key combination
Le llega al programa que esté al frente en el PC. Se pueden usar Ctrl, Shift y Alt; la tecla de Windows no. ⇒ It goes to the program in front on the PC. Ctrl, Shift and Alt work; the Windows key doesn't.
Lo que escriba se ve en la página Comandos del celular. ⇒ Its output shows up on your phone's Commands page.
Preguntar en el celular antes de hacerlo ⇒ Ask on the phone before doing it
Eliminar ⇒ Delete
Guardar ⇒ Save
Cancelar ⇒ Cancel
Ponle un nombre al atajo. ⇒ Give the shortcut a name.
Escribe qué tiene que abrir. ⇒ Write what it has to open.
Haz clic en el recuadro y pulsa la combinación de teclas. ⇒ Click the box and press the key combination.
Escribe el comando. ⇒ Write the command.
No se pudo guardar: {0} ⇒ Couldn't save: {0}
¿Eliminar el atajo {0}? ⇒ Delete the shortcut {0}?
Elige el programa o el archivo ⇒ Choose the program or file
Programas ⇒ Programs
Todos los archivos ⇒ All files
Esa tecla no se puede enviar. Prueba con otra. ⇒ That key can't be sent. Try another one.
Retroceso ⇒ Backspace
Supr ⇒ Del
Inicio ⇒ Home
Fin ⇒ End
RePág ⇒ PgUp
AvPág ⇒ PgDn
Espacio ⇒ Space
Impr Pant ⇒ PrtSc
Pausa ⇒ Pause
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
    [void][Windows.MessageBox]::Show((T 'Faltan archivos del panel. Vuelve a descomprimir el .zip del panel completo.'), 'Orbital', 'OK', 'Error')
    return
}
. (Join-Path $Raiz 'lib\requisitos.ps1')
. (Join-Path $Raiz 'lib\arranque.ps1')

# Funciones nativas (barra de título oscura, pasar al frente). Ya vienen dentro de Orbital.exe; si no, se compilan.
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

# ---------- Diseño: en modo oscuro, los mismos colores que el panel del celular; también hay una versión clara.
# $C tiene los del modo elegido (Set-Tema los cambia, junto con los colores del XAML). El celular sigue siempre oscuro.
$Temas = @{
    oscuro = @{ Fondo = '#07090C'; Tile = '#10141A'; Tile2 = '#161B23'; Linea = '#12FFFFFF'; Linea2 = '#1FFFFFFF'; LineaFuerte = '#59FFFFFF'
        Texto = '#EEF1F6'; Tenue = '#7D8696'; Apagado = '#4B5363'; Teal = '#2DD4BF'; TextoBoton = '#07090C'
        Verde = '#4ADE80'; Naranja = '#FB923C'; Rojo = '#F87171'; PistaApagada = '#262C36'; BolaApagada = '#7D8696'; Velo = '#B307090C' }
    claro = @{ Fondo = '#F3F5F8'; Tile = '#FFFFFF'; Tile2 = '#EDF0F4'; Linea = '#14000000'; Linea2 = '#21000000'; LineaFuerte = '#47000000'
        Texto = '#11161D'; Tenue = '#5B6573'; Apagado = '#9AA3AF'; Teal = '#0F766E'; TextoBoton = '#FFFFFF'
        Verde = '#15803D'; Naranja = '#C2410C'; Rojo = '#DC2626'; PistaApagada = '#D5DAE1'; BolaApagada = '#FFFFFF'; Velo = '#B3F3F5F8' }
}
$C = @{}; foreach ($k in $Temas.oscuro.Keys) { $C[$k] = $Temas.oscuro[$k] }
# El modo elegido (data\preferencias.json) o, si nunca se eligió, el de las aplicaciones de Windows.
function Get-TemaGuardado {
    try { $p = [IO.File]::ReadAllText($archivoPreferencias).TrimStart([char]0xFEFF) | ConvertFrom-Json; if ($p.tema -in 'claro', 'oscuro') { return [string]$p.tema } } catch { }
    try { if ((Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -ErrorAction Stop).AppsUseLightTheme -eq 1) { return 'claro' } } catch { }
    'oscuro'
}
$script:tema = Get-TemaGuardado
$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Orbital" Width="780" MinWidth="780" MinHeight="600" SizeToContent="Height" ResizeMode="CanResize"
        WindowStartupLocation="CenterScreen" Background="{DynamicResource Fondo}" Foreground="{DynamicResource Texto}"
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
    <!-- Los colores se cambian al elegir el modo claro u oscuro (Set-Tema); estos son los del oscuro -->
    <SolidColorBrush x:Key="Fondo" Color="#07090C"/>
    <SolidColorBrush x:Key="TextoBoton" Color="#07090C"/>
    <SolidColorBrush x:Key="PeligroFondo" Color="#1AF87171"/>
    <SolidColorBrush x:Key="PeligroBorde" Color="#40F87171"/>
    <SolidColorBrush x:Key="PistaApagada" Color="#262C36"/>
    <SolidColorBrush x:Key="BolaApagada" Color="#7D8696"/>
    <SolidColorBrush x:Key="Velo" Color="#B307090C"/>
    <Style x:Key="Tarjeta" TargetType="Border">
      <Setter Property="Background" Value="{DynamicResource Tile}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource Linea}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="CornerRadius" Value="18"/>
      <Setter Property="Padding" Value="18,16"/>
    </Style>
    <Style x:Key="Etiqueta" TargetType="TextBlock">
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="FontWeight" Value="Bold"/>
      <Setter Property="Foreground" Value="{DynamicResource Tenue}"/>
      <Setter Property="Margin" Value="0,0,0,12"/>
    </Style>
    <Style x:Key="Boton" TargetType="Button">
      <Setter Property="Foreground" Value="{DynamicResource Texto}"/>
      <Setter Property="Background" Value="{DynamicResource Tile2}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource Linea2}"/>
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
              <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Caja" Property="BorderBrush" Value="{DynamicResource Teal}"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="Caja" Property="Opacity" Value="0.4"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="BotonPrincipal" TargetType="Button" BasedOn="{StaticResource Boton}">
      <Setter Property="Background" Value="{DynamicResource Teal}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource Teal}"/>
      <Setter Property="Foreground" Value="{DynamicResource TextoBoton}"/>
    </Style>
    <Style x:Key="BotonPeligro" TargetType="Button" BasedOn="{StaticResource Boton}">
      <Setter Property="Background" Value="{DynamicResource PeligroFondo}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource PeligroBorde}"/>
      <Setter Property="Foreground" Value="{DynamicResource Rojo}"/>
    </Style>
    <Style x:Key="BotonEnlace" TargetType="Button" BasedOn="{StaticResource Boton}">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="BorderBrush" Value="Transparent"/>
      <Setter Property="Foreground" Value="{DynamicResource Tenue}"/>
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
    <!-- Campo de texto (editor de atajos) -->
    <Style x:Key="Campo" TargetType="TextBox">
      <Setter Property="Foreground" Value="{DynamicResource Texto}"/>
      <Setter Property="Background" Value="{DynamicResource Tile2}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource Linea2}"/>
      <Setter Property="CaretBrush" Value="{DynamicResource Texto}"/>
      <Setter Property="SelectionBrush" Value="{DynamicResource Teal}"/>
      <Setter Property="Padding" Value="8,7"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TextBox">
            <Border x:Name="Caja" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="10">
              <ScrollViewer x:Name="PART_ContentHost" Focusable="False"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Caja" Property="BorderBrush" Value="{DynamicResource Teal}"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <!-- Interruptor (activar o quitar una página del celular); el texto va a la derecha y también se puede pulsar. -->
    <Style x:Key="Interruptor" TargetType="CheckBox">
      <Setter Property="Foreground" Value="{DynamicResource Texto}"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Padding" Value="12,0,0,0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <DockPanel Background="Transparent">
              <Border x:Name="Pista" DockPanel.Dock="Left" Width="34" Height="20" CornerRadius="10" Background="{DynamicResource PistaApagada}"
                      BorderBrush="{DynamicResource Linea2}" BorderThickness="1" VerticalAlignment="Center">
                <Ellipse x:Name="Bola" Width="14" Height="14" Fill="{DynamicResource BolaApagada}" HorizontalAlignment="Left" Margin="2,0,0,0"/>
              </Border>
              <ContentPresenter Margin="{TemplateBinding Padding}" VerticalAlignment="Center" RecognizesAccessKey="False"/>
            </DockPanel>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="Pista" Property="Background" Value="{DynamicResource Teal}"/>
                <Setter TargetName="Pista" Property="BorderBrush" Value="{DynamicResource Teal}"/>
                <Setter TargetName="Bola" Property="Fill" Value="{DynamicResource TextoBoton}"/>
                <Setter TargetName="Bola" Property="HorizontalAlignment" Value="Right"/>
                <Setter TargetName="Bola" Property="Margin" Value="0,0,2,0"/>
              </Trigger>
              <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Pista" Property="BorderBrush" Value="{DynamicResource Texto}"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="Pista" Property="Opacity" Value="0.45"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <Grid x:Name="Raiz" Margin="20,16,20,20">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- Cabecera. Los botones de la derecha van primero, para que siempre quepan; el estado se recorta («…») si no. -->
    <DockPanel Grid.Row="0" Margin="0,0,0,16" LastChildFill="True">
      <!-- Idioma de la ventana y del celular; cada idioma se nombra en sí mismo -->
      <Border x:Name="Idiomas" DockPanel.Dock="Right" VerticalAlignment="Center" Background="{DynamicResource Tile}"
              BorderBrush="{DynamicResource Linea}" BorderThickness="1" CornerRadius="12" Padding="3">
        <StackPanel Orientation="Horizontal">
          <Button x:Name="IdiomaEs" Content="Español" Style="{StaticResource Segmento}"/>
          <Button x:Name="IdiomaEn" Content="English" Style="{StaticResource Segmento}"/>
        </StackPanel>
      </Border>
      <!-- Modo claro u oscuro: el icono es el del modo al que se cambia -->
      <Button x:Name="CambiarTema" DockPanel.Dock="Right" Style="{StaticResource Boton}" Margin="0,0,10,0" Padding="9,8" VerticalAlignment="Center">
        <Path x:Name="IconoTema" Width="16" Height="16" Stretch="Uniform" Stroke="{DynamicResource Texto}" StrokeThickness="1.8"
              StrokeLineJoin="Round" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
      </Button>
      <!-- Pantalla completa (F11); el icono cambia para salir de ella -->
      <Button x:Name="PantallaCompleta" DockPanel.Dock="Right" Style="{StaticResource Boton}" Margin="0,0,10,0" Padding="9,8" VerticalAlignment="Center">
        <Path x:Name="IconoPantalla" Width="16" Height="16" Stretch="Uniform" Stroke="{DynamicResource Texto}" StrokeThickness="1.8"
              StrokeLineJoin="Round" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
      </Button>
      <Button x:Name="AbrirAtajos" DockPanel.Dock="Right" Style="{StaticResource Boton}" Margin="0,0,10,0" Padding="12,7" VerticalAlignment="Center"
              AutomationProperties.Name="Atajos" ToolTip="Edita los botones de la página Sistema del celular">
        <StackPanel Orientation="Horizontal">
          <Path Width="14" Height="13" Stretch="Uniform" Stroke="{DynamicResource Teal}" StrokeThickness="1.8" StrokeLineJoin="Round" StrokeStartLineCap="Round" StrokeEndLineCap="Round"
                Margin="0,0,8,0" VerticalAlignment="Center"
                Data="M3,6 L21,6 L21,18 L3,18 Z M7,10 L7.01,10 M11,10 L11.01,10 M15,10 L15.01,10 M8,14 L16,14"/>
          <TextBlock Text="Atajos"/>
        </StackPanel>
      </Button>
      <!-- Más: dispositivos autorizados, actividad, abrir en este PC y detener el panel (en un menú que se despliega) -->
      <Button x:Name="AbrirMas" DockPanel.Dock="Right" Style="{StaticResource Boton}" Margin="0,0,10,0" Padding="12,7" VerticalAlignment="Center"
              AutomationProperties.Name="Más" ToolTip="Dispositivos, actividad y abrir en este PC">
        <Grid>
          <StackPanel Orientation="Horizontal">
            <Path Width="14" Height="4" Stretch="Uniform" Fill="{DynamicResource Teal}" Margin="0,0,8,0" VerticalAlignment="Center"
                  Data="M0,2 A2,2 0 1 0 4,2 A2,2 0 1 0 0,2 Z M8,2 A2,2 0 1 0 12,2 A2,2 0 1 0 8,2 Z M16,2 A2,2 0 1 0 20,2 A2,2 0 1 0 16,2 Z"/>
            <TextBlock Text="Más"/>
          </StackPanel>
          <Ellipse x:Name="AvisoMas" Width="8" Height="8" Fill="{DynamicResource Teal}" HorizontalAlignment="Right" VerticalAlignment="Top"
                   Margin="0,-5,-8,0" Visibility="Collapsed"/>
        </Grid>
      </Button>
      <Border x:Name="Logo" DockPanel.Dock="Left" Width="42" Height="42" CornerRadius="12" Margin="0,0,12,0"
              BorderBrush="{DynamicResource Linea2}" BorderThickness="1"/>
      <StackPanel VerticalAlignment="Center" Margin="0,0,12,0">
        <TextBlock Text="Orbital" FontSize="18" FontWeight="SemiBold" TextTrimming="CharacterEllipsis"/>
        <DockPanel Margin="0,2,0,0">
          <Ellipse x:Name="Punto" Width="8" Height="8" Fill="#FB923C" VerticalAlignment="Center" Margin="0,1,8,0"/>
          <TextBlock x:Name="Estado" Text="Arrancando…" Foreground="{DynamicResource Tenue}" TextTrimming="CharacterEllipsis"/>
        </DockPanel>
      </StackPanel>
    </DockPanel>

    <Border x:Name="Aviso" Grid.Row="1" Visibility="Collapsed" CornerRadius="12" Padding="14,10" Margin="0,0,0,14" BorderThickness="1">
      <DockPanel>
        <Button x:Name="AvisoBoton" DockPanel.Dock="Right" Style="{StaticResource Boton}" Margin="14,0,0,0" Padding="12,6" VerticalAlignment="Center"/>
        <TextBlock x:Name="AvisoTexto" TextWrapping="Wrap" VerticalAlignment="Center" LineHeight="19"/>
      </DockPanel>
    </Border>

    <!-- Pantalla principal: «Personaliza las pantallas» (una tarjeta por página del celular, con su vista previa, en el
         orden en que salen en el celular) y, encima, la tarjeta «Conecta el celular» mientras ningún celular use el panel -->
    <Grid x:Name="VistaPrincipal" Grid.Row="2" MinHeight="520">
      <DockPanel x:Name="VistaPaginas" LastChildFill="True">
        <DockPanel x:Name="CabeceraPaginas" DockPanel.Dock="Top" Margin="0,0,0,16" LastChildFill="True">
          <Button x:Name="RestablecerPaginas" DockPanel.Dock="Right" Content="Restablecer" Style="{StaticResource Boton}" Margin="20,0,0,0"
                  VerticalAlignment="Center" ToolTip="Vuelve al orden original, con todas las páginas"/>
          <StackPanel VerticalAlignment="Center">
            <TextBlock Text="Personaliza las pantallas" FontSize="16" FontWeight="SemiBold"/>
            <TextBlock Margin="0,3,0,0" Foreground="{DynamicResource Tenue}" FontSize="12" TextWrapping="Wrap" LineHeight="17"
                       Text="Activa las que quieres ver y arrástralas para cambiar el orden. La primera es la que aparece al conectar el celular, y cada cambio le llega al momento."/>
          </StackPanel>
        </DockPanel>
        <!-- El margen negativo compensa el espacio que cada tarjeta deja a su derecha y debajo -->
        <UniformGrid x:Name="ListaPaginas" Columns="3" VerticalAlignment="Top" Margin="0,0,-16,-16"/>
      </DockPanel>

      <!-- Conecta el celular: velo sobre las pantallas (que se ven desenfocadas detrás) y la tarjeta con el código QR -->
      <Border x:Name="Conexion" Background="{DynamicResource Velo}" CornerRadius="18" Margin="-8">
        <Border Style="{StaticResource Tarjeta}" Width="344" HorizontalAlignment="Center" VerticalAlignment="Center" Padding="24,22,24,14">
          <Border.Effect>
            <DropShadowEffect BlurRadius="48" ShadowDepth="10" Direction="270" Opacity="0.28" Color="#000000"/>
          </Border.Effect>
          <StackPanel>
            <TextBlock Text="Conecta el celular" FontSize="17" FontWeight="SemiBold" HorizontalAlignment="Center"/>
            <TextBlock Margin="4,6,4,16" Foreground="{DynamicResource Tenue}" FontSize="12" TextWrapping="Wrap" TextAlignment="Center" LineHeight="18"
                       Text="Escanéalo con la cámara del celular. Tiene que estar en la misma red Wi-Fi que este PC."/>
            <Border Background="White" CornerRadius="14" Padding="8" HorizontalAlignment="Center">
              <Grid Width="216" Height="216">
                <Image x:Name="Qr" RenderOptions.BitmapScalingMode="NearestNeighbor" Stretch="Uniform"/>
                <TextBlock x:Name="QrEspera" Text="Preparando…" Foreground="#7D8696" HorizontalAlignment="Center" VerticalAlignment="Center"/>
              </Grid>
            </Border>
            <Border Margin="0,16,0,0" Background="{DynamicResource Tile2}" CornerRadius="10" Padding="12,3,3,3">
              <DockPanel>
                <Button x:Name="Copiar" DockPanel.Dock="Right" Content="Copiar enlace" Style="{StaticResource BotonEnlace}"
                        ToolTip="Copia la dirección completa del panel, para abrirla a mano en el celular"/>
                <TextBlock x:Name="Direccion" VerticalAlignment="Center" FontFamily="Cascadia Mono, Consolas" FontSize="12"
                           Foreground="{DynamicResource Tenue}" TextTrimming="CharacterEllipsis"/>
              </DockPanel>
            </Border>
            <Button x:Name="SinCelular" Content="Personalizar sin el celular" Style="{StaticResource BotonEnlace}" HorizontalAlignment="Center"
                    Margin="0,8,0,0" ToolTip="Oculta esta tarjeta hasta que un celular se conecte y se vuelva a desconectar"/>
          </StackPanel>
        </Border>
      </Border>
    </Grid>

    <!-- Atajos: los botones de la página Sistema, en el orden del celular, y el editor de uno de ellos -->
    <DockPanel x:Name="VistaAtajos" Grid.Row="2" Visibility="Collapsed" LastChildFill="True" MaxWidth="1100">
      <DockPanel DockPanel.Dock="Top" Margin="0,0,0,16" LastChildFill="True">
        <StackPanel x:Name="BotonesAtajos" DockPanel.Dock="Right" Orientation="Horizontal" VerticalAlignment="Center" Margin="20,0,0,0">
          <Button x:Name="RestablecerAtajos" Content="Restablecer" Style="{StaticResource Boton}" Margin="0,0,10,0"
                  ToolTip="Vuelve a los atajos de ejemplo"/>
          <Button x:Name="ListoAtajos" Content="Listo" Style="{StaticResource BotonPrincipal}" Padding="26,8"/>
        </StackPanel>
        <StackPanel VerticalAlignment="Center">
          <TextBlock x:Name="TituloAtajos" FontSize="16" FontWeight="SemiBold"/>
          <TextBlock x:Name="AyudaAtajos" Margin="0,3,0,0" Foreground="{DynamicResource Tenue}" FontSize="12" TextWrapping="Wrap" LineHeight="17"/>
        </StackPanel>
      </DockPanel>
      <Grid>
        <UniformGrid x:Name="ListaAtajos" Columns="4" VerticalAlignment="Top" Margin="0,0,-12,-12"/>
        <Grid x:Name="EditorAtajo" Visibility="Collapsed">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="254"/>
            <ColumnDefinition Width="24"/>
            <ColumnDefinition Width="*"/>
          </Grid.ColumnDefinitions>
          <Grid.RowDefinitions>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>
          <StackPanel Grid.Column="0">
            <Border x:Name="EdVista" Height="88" CornerRadius="14" BorderBrush="{DynamicResource Linea2}" BorderThickness="1">
              <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
                <ContentControl x:Name="EdVistaIcono" HorizontalAlignment="Center" Focusable="False"/>
                <TextBlock x:Name="EdVistaNombre" Margin="10,8,10,0" FontWeight="SemiBold" HorizontalAlignment="Center" TextTrimming="CharacterEllipsis"/>
              </StackPanel>
            </Border>
            <TextBlock Text="NOMBRE" Style="{StaticResource Etiqueta}" Margin="0,16,0,6"/>
            <TextBox x:Name="EdNombre" Style="{StaticResource Campo}" MaxLength="40"/>
            <TextBlock Text="COLOR" Style="{StaticResource Etiqueta}" Margin="0,16,0,6"/>
            <WrapPanel x:Name="EdColores"/>
            <TextBlock Text="ICONO" Style="{StaticResource Etiqueta}" Margin="0,12,0,6"/>
            <WrapPanel x:Name="EdIconos"/>
          </StackPanel>
          <StackPanel Grid.Column="2">
            <TextBlock Text="QUÉ HACE" Style="{StaticResource Etiqueta}" Margin="0,0,0,6"/>
            <Border Background="{DynamicResource Tile}" BorderBrush="{DynamicResource Linea}" BorderThickness="1" CornerRadius="12" Padding="3" HorizontalAlignment="Left">
              <StackPanel Orientation="Horizontal">
                <Button x:Name="EdTipoAbrir" Content="Abrir" Style="{StaticResource Segmento}" Tag="open"/>
                <Button x:Name="EdTipoTeclas" Content="Atajo de teclado" Style="{StaticResource Segmento}" Tag="keys"/>
                <Button x:Name="EdTipoComando" Content="Comando" Style="{StaticResource Segmento}" Tag="command"/>
              </StackPanel>
            </Border>
            <StackPanel x:Name="EdAbrir" Margin="0,16,0,0">
              <TextBlock Text="Programa, carpeta, archivo o página web" Foreground="{DynamicResource Tenue}" FontSize="12" Margin="0,0,0,6"/>
              <DockPanel>
                <Button x:Name="EdExaminar" DockPanel.Dock="Right" Content="Examinar…" Style="{StaticResource Boton}" Margin="8,0,0,0" Padding="12,6"/>
                <TextBox x:Name="EdDestino" Style="{StaticResource Campo}"/>
              </DockPanel>
              <TextBlock Text="Argumentos (opcional)" Foreground="{DynamicResource Tenue}" FontSize="12" Margin="0,12,0,6"/>
              <TextBox x:Name="EdArgumentos" Style="{StaticResource Campo}"/>
              <TextBlock Margin="0,10,0,0" Foreground="{DynamicResource Tenue}" FontSize="12" TextWrapping="Wrap" LineHeight="17"
                         Text="Por ejemplo: calc.exe, https://www.google.com, una carpeta como C:\Users o shell:Downloads."/>
            </StackPanel>
            <StackPanel x:Name="EdTeclas" Margin="0,16,0,0">
              <TextBlock Text="Haz clic en el recuadro y pulsa la combinación de teclas" Foreground="{DynamicResource Tenue}" FontSize="12" Margin="0,0,0,6"/>
              <TextBox x:Name="EdTeclasCaja" Style="{StaticResource Campo}" IsReadOnly="True" IsReadOnlyCaretVisible="False" FontSize="15" FontWeight="SemiBold"
                       AutomationProperties.Name="Combinación de teclas"/>
              <TextBlock Margin="0,10,0,0" Foreground="{DynamicResource Tenue}" FontSize="12" TextWrapping="Wrap" LineHeight="17"
                         Text="Le llega al programa que esté al frente en el PC. Se pueden usar Ctrl, Shift y Alt; la tecla de Windows no."/>
            </StackPanel>
            <StackPanel x:Name="EdComando" Margin="0,16,0,0">
              <TextBlock Text="Comando de PowerShell" Foreground="{DynamicResource Tenue}" FontSize="12" Margin="0,0,0,6"/>
              <TextBox x:Name="EdComandoCaja" Style="{StaticResource Campo}" AcceptsReturn="True" TextWrapping="Wrap" Height="112"
                       VerticalScrollBarVisibility="Auto" FontFamily="Cascadia Mono, Consolas" FontSize="12"/>
              <TextBlock Margin="0,10,0,0" Foreground="{DynamicResource Tenue}" FontSize="12" TextWrapping="Wrap" LineHeight="17"
                         Text="Lo que escriba se ve en la página Comandos del celular."/>
            </StackPanel>
            <CheckBox x:Name="EdConfirmar" Style="{StaticResource Interruptor}" Margin="0,18,0,0" Content="Preguntar en el celular antes de hacerlo"/>
            <TextBlock x:Name="EdError" Foreground="{DynamicResource Rojo}" Margin="0,14,0,0" TextWrapping="Wrap" Visibility="Collapsed"/>
          </StackPanel>
          <DockPanel Grid.Row="1" Grid.ColumnSpan="3" Margin="0,18,0,0" LastChildFill="False">
            <Button x:Name="EdEliminar" DockPanel.Dock="Left" Content="Eliminar" Style="{StaticResource BotonPeligro}"/>
            <Button x:Name="EdGuardar" DockPanel.Dock="Right" Content="Guardar" Style="{StaticResource BotonPrincipal}" Padding="26,8"/>
            <Button x:Name="EdCancelar" DockPanel.Dock="Right" Content="Cancelar" Style="{StaticResource Boton}" Margin="0,0,10,0"/>
          </DockPanel>
        </Grid>
      </Grid>
    </DockPanel>

    <!-- Menú «Más»: se despliega bajo su botón y se cierra al hacer clic fuera -->
    <Popup x:Name="MenuMas" PlacementTarget="{Binding ElementName=AbrirMas}" Placement="Bottom" StaysOpen="False"
           AllowsTransparency="True" PopupAnimation="Fade" VerticalOffset="6">
      <Border Style="{StaticResource Tarjeta}" Width="380" Margin="16,0,16,20" Padding="18,16,18,14">
        <Border.Effect>
          <DropShadowEffect BlurRadius="28" ShadowDepth="6" Direction="270" Opacity="0.3" Color="#000000"/>
        </Border.Effect>
        <StackPanel>
          <TextBlock Text="DISPOSITIVOS AUTORIZADOS" Style="{StaticResource Etiqueta}"/>
          <StackPanel x:Name="ListaDispositivos"/>
          <TextBlock x:Name="SinDispositivos" Foreground="{DynamicResource Tenue}" TextWrapping="Wrap" LineHeight="19"
                     Text="Todavía ninguno. Escanea el código con el celular y acepta el aviso que aparecerá en este PC."/>
          <Border Height="1" Background="{DynamicResource Linea}" Margin="0,10,0,14"/>
          <TextBlock Text="ACTIVIDAD" Style="{StaticResource Etiqueta}"/>
          <StackPanel x:Name="ListaActividad"/>
          <Border Height="1" Background="{DynamicResource Linea}" Margin="0,6,0,14"/>
          <Button x:Name="AbrirPc" HorizontalAlignment="Left" Content="Abrir en este PC" Style="{StaticResource Boton}"
                  ToolTip="Abre el panel en el navegador de este PC"/>
        </StackPanel>
      </Border>
    </Popup>

    <!-- Barra de abajo: siempre a la vista, con «Detener el panel» -->
    <DockPanel Grid.Row="3" Margin="0,16,0,0" LastChildFill="True">
      <Button x:Name="Detener" DockPanel.Dock="Right" Content="Detener el panel" Style="{StaticResource BotonPeligro}" Margin="20,0,0,0"
              VerticalAlignment="Center" ToolTip="Cierra el panel: el celular deja de poder usarlo hasta que lo vuelvas a abrir"/>
      <TextBlock VerticalAlignment="Center" FontSize="12" Foreground="{DynamicResource Tenue}" TextWrapping="Wrap" LineHeight="17"
                 Text="Si cierras esta ventana, el panel sigue funcionando. Vuelve a ella desde el menú Inicio o desde el icono junto al reloj."/>
    </DockPanel>
  </Grid>
</Window>
'@

$w = [Windows.Markup.XamlReader]::Parse($xaml)
$ui = @{}
foreach ($n in 'Logo', 'Punto', 'Estado', 'Idiomas', 'IdiomaEs', 'IdiomaEn', 'Aviso', 'AvisoTexto', 'AvisoBoton', 'Qr', 'QrEspera',
    'Direccion', 'Copiar', 'ListaDispositivos', 'SinDispositivos', 'ListaActividad', 'AbrirPc', 'Detener',
    'CambiarTema', 'IconoTema', 'AbrirMas', 'AvisoMas', 'MenuMas', 'VistaPrincipal', 'Conexion', 'SinCelular',
    'PantallaCompleta', 'IconoPantalla', 'CabeceraPaginas', 'Raiz',
    'VistaPaginas', 'ListaPaginas', 'RestablecerPaginas',
    'AbrirAtajos', 'VistaAtajos', 'BotonesAtajos', 'RestablecerAtajos', 'ListoAtajos', 'TituloAtajos', 'AyudaAtajos', 'ListaAtajos', 'EditorAtajo',
    'EdVista', 'EdVistaIcono', 'EdVistaNombre', 'EdNombre', 'EdColores', 'EdIconos', 'EdTipoAbrir', 'EdTipoTeclas', 'EdTipoComando',
    'EdAbrir', 'EdExaminar', 'EdDestino', 'EdArgumentos', 'EdTeclas', 'EdTeclasCaja', 'EdComando', 'EdComandoCaja', 'EdConfirmar', 'EdError',
    'EdEliminar', 'EdGuardar', 'EdCancelar') {
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
$noTraducir = 'Estado', 'QrEspera', 'AvisoTexto', 'AvisoBoton', 'Direccion', 'Copiar', 'IdiomaEs', 'IdiomaEn', 'CambiarTema', 'PantallaCompleta',
    'TituloAtajos', 'AyudaAtajos', 'EdVistaNombre', 'EdNombre', 'EdDestino', 'EdArgumentos', 'EdTeclasCaja', 'EdComandoCaja', 'EdError'
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
$script:hayCelular = $false    # algún celular autorizado está usando el panel ahora
$script:sinCelular = $false    # se pulsó «Personalizar sin el celular»: la tarjeta del QR no se muestra hasta que uno se desconecte
$script:conexionPuesta = $false
$script:actividadVista = [DateTimeOffset]::Now.ToUnixTimeMilliseconds() # lo anterior a esto no enciende el punto de «Más»
$script:menuCerrado = [datetime]::MinValue
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

# ---------- Modo claro u oscuro. Cambia $C, los colores del XAML y la barra de título, y vuelve a dibujar lo que el código
# pinta con colores fijos.
$IconoSol = 'M12,8 A4,4 0 1 0 12,16 A4,4 0 1 0 12,8 Z M12,2.5 L12,4.5 M12,19.5 L12,21.5 M2.5,12 L4.5,12 M19.5,12 L21.5,12 M5.3,5.3 L6.7,6.7 M17.3,17.3 L18.7,18.7 M5.3,18.7 L6.7,17.3 M17.3,6.7 L18.7,5.3'
$IconoLuna = 'M20,14.5 A8,8 0 0 1 9.5,4 A8,8 0 1 0 20,14.5 Z'
function Set-Tema([string]$Tema, [switch]$Guardar) {
    if ($Tema -notin 'claro', 'oscuro') { $Tema = 'oscuro' }
    $antes = @{}; foreach ($k in $C.Keys) { $antes[$k] = $C[$k] }
    $script:tema = $Tema
    foreach ($k in @($Temas[$Tema].Keys)) { $C[$k] = $Temas[$Tema][$k] }
    foreach ($k in 'Fondo', 'Tile', 'Tile2', 'Linea', 'Linea2', 'Texto', 'Tenue', 'Teal', 'Rojo', 'TextoBoton', 'PistaApagada', 'BolaApagada', 'Velo') {
        $w.Resources[$k] = Get-Pincel $C[$k]
    }
    $w.Resources['PeligroFondo'] = Get-Pincel ($C.Rojo -replace '^#', '#1A')
    $w.Resources['PeligroBorde'] = Get-Pincel ($C.Rojo -replace '^#', '#40')
    # El icono es el del modo al que se cambia
    $ui.IconoTema.Data = [Windows.Media.Geometry]::Parse($(if ($Tema -eq 'oscuro') { $IconoSol } else { $IconoLuna }))
    Update-TextoTema
    Set-BarraTitulo
    # El estado guarda su color: se pasa al del mismo nombre en el modo nuevo
    $nombre = { param($Hex) foreach ($k in $antes.Keys) { if ($antes[$k] -eq $Hex) { return $k } } }
    foreach ($v in 'estadoActual', 'estadoNormal') {
        $e = Get-Variable -Scope Script -Name $v -ValueOnly
        $k = & $nombre $e[1]
        if ($k) { Set-Variable -Scope Script -Name $v -Value @($e[0], $C[$k], $e[2]) }
    }
    if ($Guardar) { Save-Preferencia 'tema' $Tema }
}
function Update-TextoTema {
    $t = T $(if ($script:tema -eq 'oscuro') { 'Cambiar a modo claro' } else { 'Cambiar a modo oscuro' })
    $ui.CambiarTema.ToolTip = $t
    [Windows.Automation.AutomationProperties]::SetName($ui.CambiarTema, $t)
}
# Barra de título oscura o clara, del mismo color que el fondo (Windows 11). El .exe de versiones anteriores solo
# sabe ponerla oscura.
function Set-BarraTitulo {
    if (-not $hayNativo) { return }
    $h = (New-Object Windows.Interop.WindowInteropHelper $w).Handle
    if ($h -eq [IntPtr]::Zero) { return }
    $rgb = { param($Hex) [Convert]::ToInt32($Hex.Substring($Hex.Length - 6), 16) }
    try {
        if ([PanelNativo].GetMethod('Barra')) {
            [PanelNativo]::Barra($h, $script:tema -eq 'oscuro', (& $rgb $C.Fondo), $(if ($script:tema -eq 'oscuro') { 0x1B2029 } else { 0xDCE1E7 }), (& $rgb $C.Texto))
        } elseif ($script:tema -eq 'oscuro') { [PanelNativo]::BarraOscura($h, 0x07090C, 0x1B2029) }
    } catch { }
}
# Guarda una preferencia de esta ventana en data\preferencias.json, sin tocar las demás.
function Save-Preferencia([string]$Clave, $Valor) {
    try {
        $prefs = @{}
        if (Test-Path $archivoPreferencias) { ([IO.File]::ReadAllText($archivoPreferencias).TrimStart([char]0xFEFF) | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $prefs[$_.Name] = $_.Value } }
        $prefs[$Clave] = $Valor
        New-Item -ItemType Directory -Force (Split-Path $archivoPreferencias) | Out-Null
        [IO.File]::WriteAllText($archivoPreferencias, ($prefs | ConvertTo-Json -Compress), (New-Object Text.UTF8Encoding $false))
    } catch { }
}
function Switch-Tema {
    Set-Tema $(if ($script:tema -eq 'oscuro') { 'claro' } else { 'oscuro' }) -Guardar
    # Lo que el código pinta con colores fijos se vuelve a dibujar
    $a = $script:avisoActual
    if ($a -and $ui.Aviso.Visibility -eq 'Visible') { Set-ColorAviso $a.Tipo }
    Update-Idioma
    $script:firmaDispositivos = $null; Update-Tick -Forzar
}

# ---------- Tarjeta «Conecta el celular»: se ve mientras ningún celular autorizado esté usando el panel (con las pantallas
# desenfocadas detrás) y se va con un fundido en cuanto uno se conecta. «Personalizar sin el celular» la esconde hasta
# que un celular se conecte y se vuelva a desconectar.
function Update-Conexion([bool]$HayCelular) {
    if ($HayCelular -ne $script:hayCelular) {
        if (-not $HayCelular) { $script:sinCelular = $false }
        $script:hayCelular = $HayCelular
    }
    $ver = -not $script:hayCelular -and -not $script:sinCelular
    $visible = $ui.Conexion.Visibility -eq 'Visible' -and $ui.Conexion.Tag -ne 'saliendo'
    if ($script:conexionPuesta -and $ver -eq $visible) { return }
    $script:conexionPuesta = $true
    $fundido = New-Object Windows.Media.Animation.DoubleAnimation($(if ($ver) { 1 } else { 0 }), [TimeSpan]::FromMilliseconds(220))
    if ($ver) {
        $ui.Conexion.Tag = $null
        $ui.Conexion.Visibility = 'Visible'
        $d = New-Object Windows.Media.Effects.BlurEffect; $d.Radius = 7
        $ui.VistaPaginas.Effect = $d; $ui.VistaPaginas.IsHitTestVisible = $false
    } else {
        $ui.Conexion.Tag = 'saliendo'
        $ui.VistaPaginas.Effect = $null; $ui.VistaPaginas.IsHitTestVisible = $true
        $fundido.Add_Completed({ if ($ui.Conexion.Tag -eq 'saliendo') { $ui.Conexion.Visibility = 'Collapsed'; $ui.Conexion.Tag = $null } })
    }
    $ui.Conexion.BeginAnimation([Windows.UIElement]::OpacityProperty, $fundido)
}

# ---------- Menú «Más» (dispositivos, actividad y botones). Se abre bajo su botón, alineado a su derecha. El punto del
# botón avisa de actividad nueva (no de cada botón pulsado en el celular) desde la última vez que se abrió.
function Switch-MenuMas {
    if ($ui.MenuMas.IsOpen) { $ui.MenuMas.IsOpen = $false; return }
    # Al pulsar el botón con el menú abierto, el menú ya se cerró solo al hacer clic fuera de él: no se vuelve a abrir
    if (((Get-Date) - $script:menuCerrado).TotalMilliseconds -lt 250) { return }
    $ui.MenuMas.HorizontalOffset = $ui.AbrirMas.ActualWidth - 396
    $ui.MenuMas.IsOpen = $true
    $script:actividadVista = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
    $ui.AvisoMas.Visibility = 'Collapsed'
}

# El texto va en español (con {0}, {1}… para $Datos); se guarda así para volver a mostrarlo si cambia el idioma.
function Set-Estado([string]$Texto, [string]$Color, [switch]$Normal, [object[]]$Datos = @()) {
    $script:estadoActual = @($Texto, $Color, $Datos)
    if ($Normal) { $script:estadoNormal = $script:estadoActual }
    $t = Format-Texto $Texto $Datos
    $ui.Estado.Text = $t
    $ui.Punto.Fill = Get-Pincel $Color
    $b = "Orbital: $t"
    $tray.Text = if ($b.Length -gt 63) { $b.Substring(0, 63) } else { $b }
}

# $Clave marca de quién es el aviso, para quitarlo solo si sigue siendo ese.
function Show-Aviso([string]$Texto, [string]$Tipo = 'aviso', [string]$Boton, [scriptblock]$Accion, [object[]]$Datos = @(), [string]$Clave) {
    $script:avisoActual = @{ Texto = $Texto; Boton = $Boton; Datos = $Datos; Clave = $Clave; Tipo = $Tipo }
    Set-ColorAviso $Tipo
    $ui.AvisoTexto.Text = Format-Texto $Texto $Datos
    $ui.AvisoBoton.Content = T $Boton
    $ui.AvisoBoton.Visibility = if ($Boton) { 'Visible' } else { 'Collapsed' }
    $script:avisoAccion = $Accion
    $ui.Aviso.Visibility = 'Visible'
}
function Set-ColorAviso([string]$Tipo) {
    $color = @{ error = $C.Rojo; aviso = $C.Naranja; info = $C.Teal }[$Tipo]
    if (-not $color) { $color = $C.Naranja }
    $ui.Aviso.Background = Get-Pincel ($color -replace '^#', '#1A')
    $ui.Aviso.BorderBrush = Get-Pincel ($color -replace '^#', '#4D')
}
function Hide-Aviso { $ui.Aviso.Visibility = 'Collapsed'; $script:avisoAccion = $null }

function Set-Fallo([string]$Texto, [string]$Boton, [scriptblock]$Accion, [object[]]$Datos = @()) {
    Hide-Atajos; Update-Conexion $false
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
    foreach ($b in $ui.AbrirPc, $ui.Detener, $ui.AbrirAtajos) { $b.IsEnabled = $Activos }
}

function Reset-VistaConexion {
    $ui.Qr.Source = $null; Set-QrEspera 'Preparando…'; $ui.Direccion.Text = ''
    $script:qrPuesto = $false; $script:url = $null; $script:firmaDispositivos = $null; $script:firmaActividad = $null
}

# ---------- Cambiar de idioma: se guarda, se avisa al servidor (que se lo pasa al celular) y se vuelve a dibujar todo.
function Set-Idioma([string]$Idioma) {
    if ($Idioma -notin 'es', 'en' -or $Idioma -eq $script:idioma) { return }
    $script:idioma = $Idioma
    Save-Preferencia 'idioma' $Idioma
    [void](Invoke-PanelApi 'POST' '/api/pc/idioma' @{ idioma = $Idioma })
    Update-Idioma
}

function Update-Idioma {
    Set-TextosFijos
    foreach ($par in @(@($ui.IdiomaEs, 'es'), @($ui.IdiomaEn, 'en'))) {
        $on = $script:idioma -eq $par[1]
        $par[0].Background = Get-Pincel $(if ($on) { $C.Tile2 } else { '#00000000' })
        $par[0].BorderBrush = Get-Pincel $(if ($on) { $C.Linea2 } else { '#00000000' })
        $par[0].Foreground = Get-Pincel $(if ($on) { $C.Texto } else { $C.Tenue })
    }
    Update-TextoTema; Update-TextoPantalla
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
    if ($script:enAtajos) {
        if ($script:edicion) {
            $e = $script:edicion
            $ui.TituloAtajos.Text = if ($e.nuevo) { T 'Nuevo atajo' } else { TF 'Editar {0}' $e.label }
            $ui.AyudaAtajos.Text = T 'Así se verá el botón en la página Sistema del celular.'
            $ui.EdTeclasCaja.Text = Format-Teclas $e.keys; Update-EditorAtajo
        } else { Update-ListaAtajos }
    }
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
    # Punto en «Más»: actividad que importa (no cada botón pulsado en el celular) desde la última vez que se abrió el menú
    $nueva = @($todos | Where-Object { $_.tipo -ne 'accion' -and [double]$_.t -gt $script:actividadVista }).Count
    $ui.AvisoMas.Visibility = if ($nueva -and -not $ui.MenuMas.IsOpen) { 'Visible' } else { 'Collapsed' }
    $firma = "$($script:idioma)|$($script:tema)`n" + (($todos | ForEach-Object { "$($_.t)|$($_.msg)" }) -join "`n")
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
# Si el servidor responde con un error, $script:errorApi guarda su mensaje (ya en el idioma elegido).
function Invoke-PanelApi([string]$Metodo, [string]$Ruta, $Cuerpo = $null) {
    $script:errorApi = $null
    if (-not $script:token) { return $null }
    try {
        $r = [Net.HttpWebRequest]::Create("http://127.0.0.1:$Puerto$Ruta")
        $r.Method = $Metodo; $r.Timeout = 2000; $r.ReadWriteTimeout = 2000; $r.Proxy = $null
        $r.Headers.Add('x-panel-token', $script:token)
        if ($null -ne $Cuerpo) {
            $bytes = [Text.Encoding]::UTF8.GetBytes(($Cuerpo | ConvertTo-Json -Compress -Depth 6))
            $r.ContentType = 'application/json'; $r.ContentLength = $bytes.Length
            $s = $r.GetRequestStream(); $s.Write($bytes, 0, $bytes.Length); $s.Close()
        } elseif ($Metodo -eq 'POST') { $r.ContentLength = 0 }
        $resp = $r.GetResponse()
        $lector = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
        $texto = $lector.ReadToEnd(); $lector.Close(); $resp.Close()
        return ($texto | ConvertFrom-Json)
    } catch {
        try {
            $e = $_.Exception; while ($e -and $e -isnot [Net.WebException]) { $e = $e.InnerException }
            if ($e -and $e.Response) {
                $lector = New-Object IO.StreamReader($e.Response.GetResponseStream(), [Text.Encoding]::UTF8)
                $script:errorApi = [string]($lector.ReadToEnd() | ConvertFrom-Json).error; $lector.Close()
            }
        } catch { }
        return $null
    }
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
    Hide-Atajos; Update-Conexion $false
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
    Show-Paginas
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
        if ($estado -and $ui.Aviso.Visibility -ne 'Visible') { Show-AvisoRed }
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
        Update-Conexion (@(@($e.dispositivos) | Where-Object { $_ -and $null -ne $_.haceMs -and [double]$_.haceMs -lt 20000 }).Count -gt 0)
        $script:eventosServidor = @($e.actividad)
        Update-Actividad
        if ($e.pendiente) { Set-Estado '{0} pide entrar: responde el aviso del PC' $C.Teal -Datos $e.pendiente }
        else { Set-Estado $script:estadoNormal[0] $script:estadoNormal[1] -Datos $script:estadoNormal[2] }
    }
    if ($script:accesoRed -and -not $script:permisoEnCurso -and ((Get-Date) - $script:revisionRed).TotalSeconds -ge 5) { Update-AccesoRed }
}

function Remove-Dispositivo([string]$Ip) {
    $texto = (TF '¿Quitar {0} de los dispositivos autorizados?' $Ip) + "`n`n" + (T 'Dejará de poder usar el panel. Si vuelve a escanear el código, este PC te preguntará otra vez.')
    $r = [Windows.MessageBox]::Show($w, $texto, 'Orbital', 'YesNo', 'Question')
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
$script:vistasDe = @{}   # id → vista previa de su tarjeta (se le cambia el alto según el tamaño de la ventana)
$script:altoVista = 104

# Tamaño de las tarjetas. Las vistas previas mantienen la proporción del celular en horizontal (2,27 : 1). Con la ventana
# en su tamaño normal (crece en alto con lo que tenga dentro) se llenan las tres columnas a lo ancho. Maximizada, en
# pantalla completa o con un tamaño elegido a mano, crecen hasta llenar también el alto; si el alto no alcanza, la
# cuadrícula se estrecha y queda centrada.
$ProporcionVista = 2.27
$AltoPie = 52 # bajo cada vista previa: el número, el nombre y el interruptor (36) y el espacio hasta la siguiente fila (16)
function Test-TamanoLibre { $w.WindowState -eq 'Maximized' -or $w.SizeToContent -ne 'Height' }
function Update-TamanoPaginas {
    $vistas = @($script:vistasDe.Values)
    $anchoTotal = $ui.VistaPrincipal.ActualWidth
    if (-not $vistas.Count -or $anchoTotal -le 0) { return }
    $filas = [math]::Ceiling($vistas.Count / 3)
    $ancho = ($anchoTotal + 16) / 3 - 16
    $alto = $ancho / $ProporcionVista
    $libre = Test-TamanoLibre
    if ($libre) {
        $disponible = $ui.VistaPrincipal.ActualHeight - $ui.CabeceraPaginas.ActualHeight - 16
        $maximo = ($disponible + 16) / $filas - $AltoPie
        if ($maximo -lt $alto) { $alto = [math]::Max(72, $maximo); $ancho = $alto * $ProporcionVista }
    }
    $alto = [math]::Floor($alto)
    $maxAncho = if ($libre) { [math]::Ceiling(3 * ($ancho + 16) - 16) } else { [double]::PositiveInfinity }
    if ([math]::Abs($script:altoVista - $alto) -lt 1 -and $ui.VistaPaginas.MaxWidth -eq $maxAncho) { return }
    $script:altoVista = $alto
    foreach ($v in $vistas) { $v.Height = $alto }
    $ui.VistaPaginas.MaxWidth = $maxAncho
}

# ---------- Pantalla completa (F11 o el botón de la cabecera): sin barra de título y por encima de la barra de tareas.
# Al salir, la ventana vuelve como estaba (normal o maximizada).
$IconoExpandir = 'M4,9 L4,4 L9,4 M20,9 L20,4 L15,4 M4,15 L4,20 L9,20 M20,15 L20,20 L15,20'
$IconoReducir = 'M9,4 L9,9 L4,9 M15,4 L15,9 L20,9 M9,20 L9,15 L4,15 M15,20 L15,15 L20,15'
$script:pantallaCompleta = $false
$script:estadoAntes = 'Normal'
function Switch-PantallaCompleta {
    if (-not $script:pantallaCompleta) {
        $script:estadoAntes = [string]$w.WindowState
        $script:pantallaCompleta = $true
        $w.SizeToContent = 'Manual'
        # Para cubrir también la barra de tareas, se quita el borde con la ventana sin maximizar y luego se maximiza.
        $w.WindowState = 'Normal'; $w.WindowStyle = 'None'; $w.ResizeMode = 'NoResize'; $w.WindowState = 'Maximized'
    } else {
        $script:pantallaCompleta = $false
        $w.WindowStyle = 'SingleBorderWindow'; $w.ResizeMode = 'CanResize'
        if ($script:estadoAntes -eq 'Maximized') { $w.WindowState = 'Maximized' }
        else { $w.WindowState = 'Normal'; $w.SizeToContent = 'Height' }
        Set-BarraTitulo
    }
    Update-TextoPantalla
}
function Update-TextoPantalla {
    $ui.IconoPantalla.Data = [Windows.Media.Geometry]::Parse($(if ($script:pantallaCompleta) { $IconoReducir } else { $IconoExpandir }))
    $t = T $(if ($script:pantallaCompleta) { 'Salir de pantalla completa (F11 o Esc)' } else { 'Pantalla completa (F11)' })
    $ui.PantallaCompleta.ToolTip = $t
    [Windows.Automation.AutomationProperties]::SetName($ui.PantallaCompleta, $t)
}
$script:arrastre = $null; $script:movimiento = $null; $script:destino = ''

# Es la pantalla principal: se llena en cuanto el servidor responde.
function Show-Paginas {
    $r = Invoke-PanelApi 'GET' '/api/pc/paginas'
    if (-not $r) { return }
    $script:paginas = @($r.paginas)
    $script:enPaginas = $true
    Update-ListaPaginas
    Update-TamanoPaginas
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
    $r = [Windows.MessageBox]::Show($w, (T '¿Volver al orden original, con todas las páginas?'), 'Orbital', 'YesNo', 'Question')
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
    else { $m.BorderBrush = Get-Pincel $(if ($activa) { $C.LineaFuerte } else { $C.Linea2 }); $m.BorderThickness = 1 }
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
            $img.BeginInit(); $img.UriSource = New-Object Uri $ruta; $img.CacheOption = 'OnLoad'; $img.EndInit() # a su tamaño: en pantalla completa se ven grandes
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
    $script:tarjetasDe = @{}; $script:marcosDe = @{}; $script:flechasDe = @{}; $script:vistasDe = @{}; $script:destino = ''
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
        $vista.Height = $script:altoVista; $script:vistasDe[$id] = $vista
        $marco = New-Object Windows.Controls.Border
        $marco.CornerRadius = 14; $marco.BorderThickness = 1; $marco.BorderBrush = Get-Pincel $C.Linea2; $marco.Tag = $id
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
            $primera = New-Pastilla 'Al conectar' '#EEF1F6' '#2DD4BF' # sobre la vista previa, que siempre es oscura
            $primera.HorizontalAlignment = 'Left'; $primera.VerticalAlignment = 'Top'; $primera.Margin = '8'
            [void]$vista.Children.Add($primera)
        }
        if (-not $ver) {
            $oculta = New-Pastilla 'Oculta' '#EEF1F6' $null
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
        $avatar.Background = Get-Pincel $(if ($ver) { $C.Teal -replace '^#', '#26' } else { $C.Tile2 })
        $avatar.BorderBrush = Get-Pincel $(if ($ver) { $C.Teal -replace '^#', '#59' } else { $C.Linea2 })
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

# ---------- Atajos: los botones de la página Sistema del celular. Se guardan en config.json (a través del servidor) y el
# celular los ve al momento. Desde aquí se agregan, editan, quitan y ordenan.
$script:atajos = @()
$script:atajosEjemplo = @()
$script:maxAtajos = 12
$script:enAtajos = $false
$script:edicion = $null        # el atajo que se está editando (hashtable), o $null en la lista
$script:arrastreAtajo = $null; $script:movAtajo = $null
$ColoresAtajo = '#2dd4bf', '#38bdf8', '#818cf8', '#a78bfa', '#f472b6', '#f87171', '#fb923c', '#f5b84b', '#4ade80', '#94a3b8'

# Iconos: los mismos del celular, leídos de public\index.html (sus <symbol> en SVG pasan a geometrías de WPF).
$script:iconos = [ordered]@{}
$sinIconoAtajo = 'pause', 'expand', 'shrink', 'reset', 'skip', 'check', 'chevron', 'moonsm', 'cloudsun', 'cloud', 'fog', 'rain', 'storm', 'snow', 'dot'
function Read-Iconos {
    if ($script:iconos.Count) { return }
    try { $html = [IO.File]::ReadAllText((Join-Path $Raiz 'public\index.html')) } catch { return }
    foreach ($m in [regex]::Matches($html, '<symbol id="i-([a-z]+)" viewBox="0 0 24 24">(.*?)</symbol>')) {
        $partes = @()
        try {
            foreach ($el in [regex]::Matches($m.Groups[2].Value, '<(path|circle|rect)\s([^>]*?)/?>')) {
                $at = @{}
                foreach ($a in [regex]::Matches($el.Groups[2].Value, '([\w-]+)="([^"]*)"')) { $at[$a.Groups[1].Value] = $a.Groups[2].Value }
                $g = switch ($el.Groups[1].Value) {
                    'path' { [Windows.Media.Geometry]::Parse($at['d']) }
                    'circle' { New-Object Windows.Media.EllipseGeometry((New-Object Windows.Point([double]$at['cx'], [double]$at['cy'])), [double]$at['r'], [double]$at['r']) }
                    'rect' { $rx = if ($at['rx']) { [double]$at['rx'] } else { 0 }; New-Object Windows.Media.RectangleGeometry((New-Object Windows.Rect([double]$at['x'], [double]$at['y'], [double]$at['width'], [double]$at['height'])), $rx, $rx) }
                }
                $g.Freeze()
                $partes += @{ Geo = $g; Relleno = ($at['fill'] -eq 'currentColor'); Grosor = $(if ($at['stroke-width']) { [double]$at['stroke-width'] } else { 1.9 }) }
            }
            $script:iconos[$m.Groups[1].Value] = $partes
        } catch { } # un icono que WPF no entiende no se ofrece
    }
}

function New-IconoVista([string]$Nombre, [string]$Color, [double]$Tamano) {
    Read-Iconos
    $partes = $script:iconos[$Nombre]; if (-not $partes) { $partes = $script:iconos['dot'] }
    $pincel = Get-Pincel $Color
    $lienzo = New-Object Windows.Controls.Canvas
    $lienzo.Width = 24; $lienzo.Height = 24
    foreach ($p in @($partes)) {
        $f = New-Object Windows.Shapes.Path
        $f.Data = $p.Geo
        if ($p.Relleno) { $f.Fill = $pincel } else {
            $f.Stroke = $pincel; $f.StrokeThickness = $p.Grosor
            $f.StrokeStartLineCap = 'Round'; $f.StrokeEndLineCap = 'Round'; $f.StrokeLineJoin = 'Round'
        }
        [void]$lienzo.Children.Add($f)
    }
    $vb = New-Object Windows.Controls.Viewbox
    $vb.Width = $Tamano; $vb.Height = $Tamano; $vb.Child = $lienzo; $vb.IsHitTestVisible = $false
    $vb
}

# Atajo de teclado en formato SendKeys (^+{ESC}) ↔ texto para leer (Ctrl + Shift + Esc)
$NombresTecla = @{ ESC = 'Esc'; ESCAPE = 'Esc'; ENTER = 'Enter'; TAB = 'Tab'; BACKSPACE = 'Retroceso'; BS = 'Retroceso'; DEL = 'Supr'; DELETE = 'Supr'
    INS = 'Insert'; INSERT = 'Insert'; HOME = 'Inicio'; END = 'Fin'; PGUP = 'RePág'; PGDN = 'AvPág'; UP = '↑'; DOWN = '↓'; LEFT = '←'; RIGHT = '→'
    SPACE = 'Espacio'; PRTSC = 'Impr Pant'; BREAK = 'Pausa' }
function Format-Teclas([string]$K) {
    if (-not $K) { return '' }
    $partes = @(); $i = 0
    while ($i -lt $K.Length -and '^+%'.Contains([string]$K[$i])) { $partes += @{ '^' = 'Ctrl'; '+' = 'Shift'; '%' = 'Alt' }[[string]$K[$i]]; $i++ }
    $resto = $K.Substring($i)
    if ($resto -match '^\{(.+)\}$') { $n = $Matches[1].ToUpper(); $resto = if ($NombresTecla[$n]) { T $NombresTecla[$n] } else { $Matches[1] } }
    elseif ($resto.Length -eq 1) { $resto = $resto.ToUpper() }
    ($partes + $resto) -join ' + '
}
function ConvertTo-TeclaSendKeys([Windows.Input.Key]$Tecla) {
    $n = [string]$Tecla
    if ($n -match '^[A-Z]$') { return $n.ToLower() }
    if ($n -match '^D(\d)$' -or $n -match '^NumPad(\d)$') { return $Matches[1] }
    if ($n -match '^F(\d{1,2})$' -and [int]$Matches[1] -le 24) { return "{$n}" }
    $mapa = @{ Escape = '{ESC}'; Return = '{ENTER}'; Enter = '{ENTER}'; Tab = '{TAB}'; Back = '{BACKSPACE}'; Delete = '{DEL}'; Insert = '{INS}'
        Home = '{HOME}'; End = '{END}'; PageUp = '{PGUP}'; Prior = '{PGUP}'; PageDown = '{PGDN}'; Next = '{PGDN}'; Up = '{UP}'; Down = '{DOWN}'
        Left = '{LEFT}'; Right = '{RIGHT}'; Space = '{SPACE}'; Snapshot = '{PRTSC}'; PrintScreen = '{PRTSC}'; Pause = '{BREAK}' }
    $mapa[$n]
}

function Get-ResumenAtajo($A) {
    switch ([string]$A.type) {
        'open' { $d = [string]$A.target; if ($A.args -and $d -match 'explorer(\.exe)?$') { $d = [string]$A.args } # una carpeta: se dice cuál
            if ($d -match '^https?://([^/]+)') { $d = $Matches[1] } elseif ($d -match '[\\/]([^\\/]+)$') { $d = $Matches[1] }; TF 'Abre {0}' $d }
        'keys' { TF 'Teclas: {0}' (Format-Teclas ([string]$A.keys)) }
        'command' { T 'Comando de PowerShell' }
        default { '' }
    }
}

function Show-Atajos {
    $r = Invoke-PanelApi 'GET' '/api/pc/atajos'
    if (-not $r) { Show-Aviso 'Para editar los atajos, el panel tiene que estar funcionando.' 'aviso'; return }
    $script:atajos = @($r.atajos); $script:atajosEjemplo = @($r.predeterminados); if ($r.maximo) { $script:maxAtajos = [int]$r.maximo }
    $script:edicion = $null
    Update-ListaAtajos
    $ui.VistaAtajos.MinHeight = $ui.VistaPrincipal.ActualHeight # la ventana no cambia de alto al pasar de una vista a otra
    $ui.VistaPrincipal.Visibility = 'Collapsed'; $ui.VistaAtajos.Visibility = 'Visible'
    $ui.AbrirAtajos.Visibility = 'Collapsed'
    $script:enAtajos = $true
}

function Hide-Atajos {
    if (-not $script:enAtajos) { return }
    $script:enAtajos = $false; $script:edicion = $null
    $ui.VistaAtajos.Visibility = 'Collapsed'; $ui.VistaPrincipal.Visibility = 'Visible'
    $ui.AbrirAtajos.Visibility = 'Visible'
}

# Guarda la lista entera. Devuelve $true si el servidor la aceptó; si no, deja el motivo en $script:errorAtajos.
function Save-Atajos($Lista) {
    $campos = 'id', 'label', 'icon', 'color', 'type', 'target', 'args', 'keys', 'command', 'confirm'
    $cuerpo = @{ atajos = @(@($Lista) | Where-Object { $_ } | ForEach-Object {
        $a = $_; $h = @{}
        foreach ($k in $campos) { $v = if ($a -is [hashtable]) { $a[$k] } else { $a.$k }; if ($null -ne $v -and "$v" -ne '') { $h[$k] = $v } }
        $h
    }) }
    $r = Invoke-PanelApi 'POST' '/api/pc/atajos' $cuerpo
    if (-not $r) { $script:errorAtajos = if ($script:errorApi) { $script:errorApi } else { T 'El panel no respondió.' }; return $false }
    $script:atajos = @($r.atajos); $script:errorAtajos = $null
    $true
}

function Reset-Atajos {
    $r = [Windows.MessageBox]::Show($w, (T '¿Volver a los atajos de ejemplo? Se pierden los que cambiaste.'), 'Orbital', 'YesNo', 'Question')
    if ("$r" -ne 'Yes') { return }
    if (Save-Atajos $script:atajosEjemplo) { Update-ListaAtajos } else { Show-Aviso 'No se pudieron guardar los atajos: {0}' 'error' -Datos $script:errorAtajos }
}

function Move-AtajoA([string]$Id, [string]$DestinoId) {
    $l = New-Object Collections.ArrayList; $l.AddRange(@($script:atajos))
    $i = -1; $j = -1
    for ($k = 0; $k -lt $l.Count; $k++) { if ($l[$k].id -eq $Id) { $i = $k }; if ($l[$k].id -eq $DestinoId) { $j = $k } }
    if ($i -lt 0 -or $j -lt 0 -or $i -eq $j) { return }
    $p = $l[$i]; $l.RemoveAt($i); $l.Insert($j, $p)
    if (-not (Save-Atajos @($l))) { Show-Aviso 'No se pudieron guardar los atajos: {0}' 'error' -Datos $script:errorAtajos }
    Update-ListaAtajos
}

# La lista: una tarjeta por atajo, como se ve en el celular (icono de su color y nombre), con lo que hace debajo. Se pulsa
# para editarla y se arrastra para cambiar el orden. Al final, «Agregar atajo» si caben más.
function Update-ListaAtajos {
    $ui.TituloAtajos.Text = T 'Atajos'
    $ui.AyudaAtajos.Text = TF 'Los botones de la página Sistema del celular (hasta {0}). Pulsa uno para editarlo y arrástralos para cambiar el orden; cada cambio le llega al celular al momento.' $script:maxAtajos
    $ui.BotonesAtajos.Visibility = 'Visible'; $ui.EditorAtajo.Visibility = 'Collapsed'; $ui.ListaAtajos.Visibility = 'Visible'
    $ui.ListaAtajos.Children.Clear()
    foreach ($a in @($script:atajos)) {
        $color = if ([string]$a.color -match '^#[0-9a-fA-F]{6}$') { [string]$a.color } else { $C.Texto }
        $b = New-Object Windows.Controls.Button
        $b.Style = $w.FindResource('Boton'); $b.Padding = '10,12'; $b.Margin = '0,0,12,12'; $b.Height = 104
        $b.Background = Get-Pincel $C.Tile; $b.Tag = [string]$a.id; $b.AllowDrop = $true
        $b.HorizontalContentAlignment = 'Stretch'
        $sp = New-Object Windows.Controls.StackPanel
        $ic = New-IconoVista ([string]$a.icon) $color 24; $ic.HorizontalAlignment = 'Center'
        $nom = New-Texto ([string]$a.label) $C.Texto 13 ([Windows.FontWeights]::SemiBold)
        $nom.TextWrapping = 'NoWrap'; $nom.TextTrimming = 'CharacterEllipsis'; $nom.HorizontalAlignment = 'Center'; $nom.Margin = '0,10,0,0'
        $res = New-Texto (Get-ResumenAtajo $a) $C.Tenue 11
        $res.TextWrapping = 'NoWrap'; $res.TextTrimming = 'CharacterEllipsis'; $res.HorizontalAlignment = 'Center'; $res.Margin = '0,3,0,0'
        [void]$sp.Children.Add($ic); [void]$sp.Children.Add($nom); [void]$sp.Children.Add($res)
        $b.Content = $sp
        $b.ToolTip = T 'Pulsa para editarlo; arrástralo para cambiar el orden'
        [Windows.Automation.AutomationProperties]::SetName($b, (TF 'Editar {0}' ([string]$a.label)))
        $b.Add_Click({ param($s) Invoke-Seguro { $id = [string]$s.Tag; Open-EditorAtajo (@($script:atajos) | Where-Object { $_.id -eq $id } | Select-Object -First 1) } })
        # Arrastrar para ordenar
        $b.Add_PreviewMouseLeftButtonDown({ param($s, $e) $script:arrastreAtajo = @{ Id = [string]$s.Tag; Punto = $e.GetPosition($w) } })
        $b.Add_PreviewMouseLeftButtonUp({ $script:arrastreAtajo = $null })
        $b.Add_PreviewMouseMove({ param($s, $e)
            $a = $script:arrastreAtajo
            if (-not $a -or $e.LeftButton -ne [Windows.Input.MouseButtonState]::Pressed) { return }
            $q = $e.GetPosition($w)
            if ([math]::Abs($q.X - $a.Punto.X) -lt [Windows.SystemParameters]::MinimumHorizontalDragDistance -and
                [math]::Abs($q.Y - $a.Punto.Y) -lt [Windows.SystemParameters]::MinimumVerticalDragDistance) { return }
            $script:arrastreAtajo = $null; $script:movAtajo = $null
            $s.Opacity = 0.4
            try { [void][Windows.DragDrop]::DoDragDrop($s, (New-Object Windows.DataObject('PanelAtajo', $a.Id)), [Windows.DragDropEffects]::Move) } finally { $s.Opacity = 1 }
            $m = $script:movAtajo; $script:movAtajo = $null
            if ($m) { Invoke-Seguro { Move-AtajoA $m[0] $m[1] } }
        })
        $b.Add_DragOver({ param($s, $e)
            $o = if ($e.Data.GetDataPresent('PanelAtajo')) { [string]$e.Data.GetData('PanelAtajo') } else { '' }
            $e.Effects = if ($o -and $o -ne [string]$s.Tag) { [Windows.DragDropEffects]::Move } else { [Windows.DragDropEffects]::None }
            $s.BorderBrush = Get-Pincel $(if ($o -and $o -ne [string]$s.Tag) { $C.Teal } else { $C.Linea2 })
            $e.Handled = $true
        })
        $b.Add_DragLeave({ param($s) $s.BorderBrush = Get-Pincel $C.Linea2 })
        $b.Add_Drop({ param($s, $e)
            $s.BorderBrush = Get-Pincel $C.Linea2
            $o = if ($e.Data.GetDataPresent('PanelAtajo')) { [string]$e.Data.GetData('PanelAtajo') } else { '' }
            if ($o -and $o -ne [string]$s.Tag) { $script:movAtajo = @($o, [string]$s.Tag) }
            $e.Handled = $true
        })
        [void]$ui.ListaAtajos.Children.Add($b)
    }
    if (@($script:atajos).Count -lt $script:maxAtajos) {
        $n = New-Object Windows.Controls.Button
        $n.Style = $w.FindResource('Boton'); $n.Margin = '0,0,12,12'; $n.Height = 104
        $n.Background = Get-Pincel '#00000000'; $n.BorderBrush = Get-Pincel $C.LineaFuerte
        $sp = New-Object Windows.Controls.StackPanel
        $mas = New-Texto '+' $C.Teal 26 ([Windows.FontWeights]::Light); $mas.HorizontalAlignment = 'Center'
        $txt = New-Texto (T 'Agregar atajo') $C.Tenue 12 ([Windows.FontWeights]::SemiBold); $txt.HorizontalAlignment = 'Center'
        [void]$sp.Children.Add($mas); [void]$sp.Children.Add($txt)
        $n.Content = $sp
        [Windows.Automation.AutomationProperties]::SetName($n, (T 'Agregar atajo'))
        $n.Add_Click({ Invoke-Seguro { Open-EditorAtajo $null } })
        [void]$ui.ListaAtajos.Children.Add($n)
    }
}

# ---------- Editor de un atajo ($A = $null: uno nuevo)
function Open-EditorAtajo($A) {
    $e = @{ nuevo = -not $A; id = ''; label = ''; icon = 'globe'; color = '#2dd4bf'; type = 'open'; target = ''; args = ''; keys = ''; command = ''; confirm = $false }
    if ($A) { foreach ($k in 'id', 'label', 'icon', 'color', 'type', 'target', 'args', 'keys', 'command') { if ($null -ne $A.$k) { $e[$k] = [string]$A.$k } }; $e.confirm = [bool]$A.confirm }
    if ($e.type -notin 'open', 'keys', 'command') { $e.type = 'open' }
    $script:edicion = $e
    $ui.TituloAtajos.Text = if ($e.nuevo) { T 'Nuevo atajo' } else { TF 'Editar {0}' $e.label }
    $ui.AyudaAtajos.Text = T 'Así se verá el botón en la página Sistema del celular.'
    $ui.BotonesAtajos.Visibility = 'Collapsed'; $ui.ListaAtajos.Visibility = 'Collapsed'; $ui.EditorAtajo.Visibility = 'Visible'
    $ui.EdNombre.Text = $e.label; $ui.EdDestino.Text = $e.target; $ui.EdArgumentos.Text = $e.args; $ui.EdComandoCaja.Text = $e.command
    $ui.EdTeclasCaja.Text = Format-Teclas $e.keys; $ui.EdConfirmar.IsChecked = $e.confirm
    $ui.EdEliminar.Visibility = if ($e.nuevo) { 'Collapsed' } else { 'Visible' }
    $ui.EdError.Visibility = 'Collapsed'
    Update-EditorAtajo
    [void]$ui.EdNombre.Focus()
}

# Vuelve a dibujar lo que depende de lo elegido: la vista previa, el color, el icono y el tipo de acción.
function Update-EditorAtajo {
    $e = $script:edicion; if (-not $e) { return }
    $ui.EdVista.Background = Get-Pincel ($e.color -replace '^#', '#1F')
    $ui.EdVista.BorderBrush = Get-Pincel ($e.color -replace '^#', '#59')
    $ui.EdVistaIcono.Content = New-IconoVista $e.icon $e.color 26
    $ui.EdVistaNombre.Text = if ($ui.EdNombre.Text.Trim()) { $ui.EdNombre.Text.Trim() } else { T 'Sin nombre' }
    $ui.EdColores.Children.Clear()
    foreach ($tono in $ColoresAtajo) { # ($c no: en PowerShell es la misma variable que $C, la de los colores de la ventana)
        $b = New-Object Windows.Controls.Button
        $b.Style = $w.FindResource('BotonFlotante'); $b.Width = 22; $b.Height = 22; $b.Margin = '0,0,3,3'; $b.Tag = $tono
        $b.Background = Get-Pincel $tono
        $b.BorderBrush = Get-Pincel $(if ($tono -eq $e.color) { $C.Texto } else { '#00000000' })
        if ($tono -eq $e.color) { $b.Width = 26; $b.Height = 26; $b.Margin = '0,0,1,1' }
        [Windows.Automation.AutomationProperties]::SetName($b, (TF 'Color {0}' $tono))
        $b.Add_Click({ param($s) Invoke-Seguro { $script:edicion.color = [string]$s.Tag; Update-EditorAtajo } })
        [void]$ui.EdColores.Children.Add($b)
    }
    $ui.EdIconos.Children.Clear()
    Read-Iconos
    foreach ($n in $script:iconos.Keys) {
        if ($n -in $sinIconoAtajo) { continue }
        $b = New-Object Windows.Controls.Button
        $b.Style = $w.FindResource('BotonFlotante'); $b.Width = 30; $b.Height = 30; $b.Margin = '0,0,4,4'; $b.Tag = $n
        $sel = $n -eq $e.icon
        $b.Background = Get-Pincel $(if ($sel) { $e.color -replace '^#', '#33' } else { $C.Tile2 })
        $b.BorderBrush = Get-Pincel $(if ($sel) { $e.color } else { $C.Linea2 })
        $b.Content = New-IconoVista $n $(if ($sel) { $e.color } else { $C.Tenue }) 15
        [Windows.Automation.AutomationProperties]::SetName($b, (TF 'Icono {0}' $n)); $b.ToolTip = $n
        $b.Add_Click({ param($s) Invoke-Seguro { $script:edicion.icon = [string]$s.Tag; Update-EditorAtajo } })
        [void]$ui.EdIconos.Children.Add($b)
    }
    foreach ($par in @(@($ui.EdTipoAbrir, 'open'), @($ui.EdTipoTeclas, 'keys'), @($ui.EdTipoComando, 'command'))) {
        $on = $e.type -eq $par[1]
        $par[0].Background = Get-Pincel $(if ($on) { $C.Tile2 } else { '#00000000' })
        $par[0].BorderBrush = Get-Pincel $(if ($on) { $C.Linea2 } else { '#00000000' })
        $par[0].Foreground = Get-Pincel $(if ($on) { $C.Texto } else { $C.Tenue })
    }
    $ui.EdAbrir.Visibility = if ($e.type -eq 'open') { 'Visible' } else { 'Collapsed' }
    $ui.EdTeclas.Visibility = if ($e.type -eq 'keys') { 'Visible' } else { 'Collapsed' }
    $ui.EdComando.Visibility = if ($e.type -eq 'command') { 'Visible' } else { 'Collapsed' }
}

function Show-ErrorEditor([string]$Texto) { $ui.EdError.Text = $Texto; $ui.EdError.Visibility = 'Visible' }

function Save-EditorAtajo {
    $e = $script:edicion; if (-not $e) { return }
    $e.label = $ui.EdNombre.Text.Trim(); $e.target = $ui.EdDestino.Text.Trim(); $e.args = $ui.EdArgumentos.Text.Trim()
    $e.command = $ui.EdComandoCaja.Text.Trim(); $e.confirm = [bool]$ui.EdConfirmar.IsChecked
    if (-not $e.label) { Show-ErrorEditor (T 'Ponle un nombre al atajo.'); [void]$ui.EdNombre.Focus(); return }
    if ($e.type -eq 'open' -and -not $e.target) { Show-ErrorEditor (T 'Escribe qué tiene que abrir.'); [void]$ui.EdDestino.Focus(); return }
    if ($e.type -eq 'keys' -and -not $e.keys) { Show-ErrorEditor (T 'Haz clic en el recuadro y pulsa la combinación de teclas.'); [void]$ui.EdTeclasCaja.Focus(); return }
    if ($e.type -eq 'command' -and -not $e.command) { Show-ErrorEditor (T 'Escribe el comando.'); [void]$ui.EdComandoCaja.Focus(); return }
    $nuevo = @{ id = $e.id; label = $e.label; icon = $e.icon; color = $e.color; type = $e.type; confirm = $e.confirm }
    switch ($e.type) { 'open' { $nuevo.target = $e.target; $nuevo.args = $e.args } 'keys' { $nuevo.keys = $e.keys } 'command' { $nuevo.command = $e.command } }
    $lista = @(@($script:atajos) | ForEach-Object { if (-not $e.nuevo -and $_.id -eq $e.id) { $nuevo } else { $_ } })
    if ($e.nuevo) { $lista += $nuevo }
    if (Save-Atajos $lista) { $script:edicion = $null; Update-ListaAtajos } else { Show-ErrorEditor (TF 'No se pudo guardar: {0}' $script:errorAtajos) }
}

function Remove-EditorAtajo {
    $e = $script:edicion; if (-not $e -or $e.nuevo) { return }
    $r = [Windows.MessageBox]::Show($w, (TF '¿Eliminar el atajo {0}?' $e.label), 'Orbital', 'YesNo', 'Question')
    if ("$r" -ne 'Yes') { return }
    if (Save-Atajos @(@($script:atajos) | Where-Object { $_.id -ne $e.id })) { $script:edicion = $null; Update-ListaAtajos }
    else { Show-ErrorEditor (TF 'No se pudo guardar: {0}' $script:errorAtajos) }
}

function Select-DestinoAtajo {
    $d = New-Object Microsoft.Win32.OpenFileDialog
    $d.Title = T 'Elige el programa o el archivo'
    $d.Filter = (T 'Programas') + ' (*.exe;*.lnk;*.bat;*.cmd)|*.exe;*.lnk;*.bat;*.cmd|' + (T 'Todos los archivos') + ' (*.*)|*.*'
    if ($d.ShowDialog($w)) { $ui.EdDestino.Text = $d.FileName; if (-not $ui.EdNombre.Text.Trim()) { $ui.EdNombre.Text = [IO.Path]::GetFileNameWithoutExtension($d.FileName) } }
}

# ---------- Icono junto al reloj
$tray = New-Object Windows.Forms.NotifyIcon
try { $tray.Icon = New-Object Drawing.Icon((Join-Path $Raiz 'panel.ico'), [Windows.Forms.SystemInformation]::SmallIconSize) } catch { $tray.Icon = [Drawing.SystemIcons]::Application }
$tray.Text = 'Orbital'
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
$ui.RestablecerPaginas.Add_Click({ Invoke-Seguro { Reset-Paginas } })
$ui.CambiarTema.Add_Click({ Invoke-Seguro { Switch-Tema } })
$ui.PantallaCompleta.Add_Click({ Invoke-Seguro { Switch-PantallaCompleta } })
$ui.VistaPrincipal.Add_SizeChanged({ Invoke-Seguro { Update-TamanoPaginas } })
# Maximizada, la ventana deja de crecer con lo que tiene dentro; al volver a su tamaño normal, vuelve a hacerlo.
$w.Add_StateChanged({ Invoke-Seguro {
    if (-not $script:pantallaCompleta) {
        if ($w.WindowState -eq 'Maximized') { $w.SizeToContent = 'Manual' }
        elseif ($w.WindowState -eq 'Normal') { $w.SizeToContent = 'Height' }
    }
    Update-TamanoPaginas
} })
$ui.AbrirMas.Add_Click({ Invoke-Seguro { Switch-MenuMas } })
$ui.MenuMas.Add_Closed({ $script:menuCerrado = Get-Date })
$ui.SinCelular.Add_Click({ Invoke-Seguro { $script:sinCelular = $true; Update-Conexion $script:hayCelular } })
$ui.AbrirAtajos.Add_Click({ Invoke-Seguro { Show-Atajos } })
$ui.ListoAtajos.Add_Click({ Invoke-Seguro { Hide-Atajos } })
$ui.RestablecerAtajos.Add_Click({ Invoke-Seguro { Reset-Atajos } })
$ui.EdGuardar.Add_Click({ Invoke-Seguro { Save-EditorAtajo } })
$ui.EdCancelar.Add_Click({ Invoke-Seguro { $script:edicion = $null; Update-ListaAtajos } })
$ui.EdEliminar.Add_Click({ Invoke-Seguro { Remove-EditorAtajo } })
$ui.EdExaminar.Add_Click({ Invoke-Seguro { Select-DestinoAtajo } })
foreach ($b in $ui.EdTipoAbrir, $ui.EdTipoTeclas, $ui.EdTipoComando) {
    $b.Add_Click({ param($s) Invoke-Seguro { $script:edicion.type = [string]$s.Tag; $ui.EdError.Visibility = 'Collapsed'; Update-EditorAtajo } })
}
$ui.EdNombre.Add_TextChanged({ if ($script:edicion) { $ui.EdVistaNombre.Text = if ($ui.EdNombre.Text.Trim()) { $ui.EdNombre.Text.Trim() } else { T 'Sin nombre' } } })
# Capturar la combinación: se guarda en el formato de SendKeys (^ Ctrl, + Shift, % Alt) y se muestra para leer.
$ui.EdTeclasCaja.Add_PreviewKeyDown({ param($s, $e)
    $k = if ($e.Key -eq [Windows.Input.Key]::System) { $e.SystemKey } else { $e.Key }
    $mods = [Windows.Input.Keyboard]::Modifiers
    if ($k -eq [Windows.Input.Key]::Tab -and $mods -eq 'None') { return } # Tab sola: pasar al siguiente campo
    $e.Handled = $true
    if ("$k" -match 'Ctrl$|Shift$|Alt$|Win$|^System$') { return }
    $tecla = ConvertTo-TeclaSendKeys $k
    if (-not $tecla) { Show-ErrorEditor (T 'Esa tecla no se puede enviar. Prueba con otra.'); return }
    $pre = ''
    if ($mods -band [Windows.Input.ModifierKeys]::Control) { $pre += '^' }
    if ($mods -band [Windows.Input.ModifierKeys]::Shift) { $pre += '+' }
    if ($mods -band [Windows.Input.ModifierKeys]::Alt) { $pre += '%' }
    $script:edicion.keys = $pre + $tecla
    $s.Text = Format-Teclas $script:edicion.keys
    $ui.EdError.Visibility = 'Collapsed'
})
$w.Add_KeyDown({ param($s, $e)
    if ($e.Key -eq 'F11' -and -not $ui.EdTeclasCaja.IsKeyboardFocused) { $e.Handled = $true; Invoke-Seguro { Switch-PantallaCompleta }; return }
    if ($e.Key -ne 'Escape') { return }
    if ($ui.MenuMas.IsOpen) { $ui.MenuMas.IsOpen = $false }
    elseif ($script:enAtajos -and $script:edicion) { if (-not $ui.EdTeclasCaja.IsKeyboardFocused) { Invoke-Seguro { $script:edicion = $null; Update-ListaAtajos } } }
    elseif ($script:pantallaCompleta) { Invoke-Seguro { Switch-PantallaCompleta } }
    elseif ($script:enAtajos) { Invoke-Seguro { Hide-Atajos } }
})

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
$w.Add_SourceInitialized({ Set-BarraTitulo })
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

Set-Tema $script:tema
Reset-VistaConexion
Update-Conexion $false
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
