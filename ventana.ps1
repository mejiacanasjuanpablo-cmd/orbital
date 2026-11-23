# Panel del PC: ventana para arrancar y controlar el panel, sin consola.
# La abre "Panel del PC.exe" (lo crea instalar.cmd) o, si no existe, iniciar.cmd con PowerShell oculto.
#   ventana.ps1             modo USB (en la edición solo Wi-Fi, siempre Wi-Fi)
#   ventana.ps1 -Wifi       modo Wi-Fi
#   ventana.ps1 -Puerto N   otro puerto (por defecto 8787)
# Para ver los mensajes del servidor en una consola, usa iniciar.ps1.
param([int]$Puerto = 8787, [switch]$Wifi)
$ErrorActionPreference = 'Stop'
$Raiz = $PSScriptRoot
Set-Location $Raiz
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

if (-not (Test-Path (Join-Path $Raiz 'lib\requisitos.ps1')) -or -not (Test-Path (Join-Path $Raiz 'lib\arranque.ps1'))) {
    [void][Windows.MessageBox]::Show('Faltan archivos del panel. Vuelve a descomprimir el .zip del panel completo.', 'Panel del PC', 'OK', 'Error')
    return
}
. (Join-Path $Raiz 'lib\requisitos.ps1')
. (Join-Path $Raiz 'lib\arranque.ps1')
$modoInicial = if ($Wifi -or $PanelSoloWifi) { 'wifi' } else { 'usb' }

# Funciones nativas (barra de título oscura, pasar al frente). Ya vienen dentro de Panel del PC.exe; si no, se compilan.
if (-not ('PanelNativo' -as [type])) {
    try { Add-Type -Path (Join-Path $Raiz 'lib\lanzador.cs') -ReferencedAssemblies System.Windows.Forms } catch { }
}
$hayNativo = [bool]('PanelNativo' -as [type])

# Una sola ventana por puerto: si ya hay una abierta, se le pide que se muestre (en el modo pedido) y esta termina.
$creada = $false
$mutex = New-Object Threading.Mutex($true, "Local\PanelDelPC-$Puerto", [ref]$creada)
$senal = @{}
foreach ($m in 'wifi', 'usb') {
    $senal[$m] = New-Object Threading.EventWaitHandle($false, [Threading.EventResetMode]::AutoReset, "Local\PanelDelPC-$Puerto-$m")
}
if (-not $creada) {
    if ($hayNativo) { [PanelNativo]::PermitirPrimerPlano() }
    [void]$senal[$modoInicial].Set()
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
      <Border x:Name="Modos" DockPanel.Dock="Right" VerticalAlignment="Center" Background="{StaticResource Tile}"
              BorderBrush="{StaticResource Linea}" BorderThickness="1" CornerRadius="12" Padding="3">
        <StackPanel Orientation="Horizontal">
          <Button x:Name="ModoWifi" Content="Wi-Fi" Style="{StaticResource Segmento}" ToolTip="El celular entra por la red Wi-Fi de la casa"/>
          <Button x:Name="ModoUsb" Content="Cable USB" Style="{StaticResource Segmento}" ToolTip="El celular se conecta por cable, con la depuración USB"/>
        </StackPanel>
      </Border>
      <Button x:Name="AbrirPaginas" DockPanel.Dock="Right" Style="{StaticResource Boton}" Margin="0,0,10,0" Padding="12,7" VerticalAlignment="Center"
              AutomationProperties.Name="Páginas del celular" ToolTip="Elige qué páginas ves en el celular y en qué orden">
        <StackPanel Orientation="Horizontal">
          <Path Width="13" Height="13" Stretch="Uniform" Stroke="#2DD4BF" StrokeThickness="1.8" StrokeLineJoin="Round" Margin="0,0,8,0" VerticalAlignment="Center"
                Data="M4,4 L10,4 L10,10 L4,10 Z M14,4 L20,4 L20,10 L14,10 Z M4,14 L10,14 L10,20 L4,20 Z M14,14 L20,14 L20,20 L14,20 Z"/>
          <TextBlock Text="Páginas del celular"/>
        </StackPanel>
      </Button>
    </DockPanel>

    <Border x:Name="Aviso" Grid.Row="1" Visibility="Collapsed" CornerRadius="12" Padding="14,10" Margin="0,0,0,14" BorderThickness="1">
      <DockPanel>
        <Button x:Name="AvisoBoton" DockPanel.Dock="Right" Style="{StaticResource Boton}" Margin="14,0,0,0" Padding="12,6" VerticalAlignment="Center"/>
        <TextBlock x:Name="AvisoTexto" TextWrapping="Wrap" VerticalAlignment="Center" LineHeight="19"/>
      </DockPanel>
    </Border>

    <!-- Páginas del celular: una tarjeta por página, con su vista previa, en el orden en que salen en el celular
         (ocupa el lugar de la vista de conexión mientras está abierta) -->
    <DockPanel x:Name="VistaPaginas" Grid.Row="2" Visibility="Collapsed" LastChildFill="True">
      <DockPanel DockPanel.Dock="Top" Margin="0,0,0,16" LastChildFill="True">
        <StackPanel DockPanel.Dock="Right" Orientation="Horizontal" VerticalAlignment="Center" Margin="20,0,0,0">
          <Button x:Name="RestablecerPaginas" Content="Restablecer" Style="{StaticResource Boton}" Margin="0,0,10,0"
                  ToolTip="Vuelve al orden original, con todas las páginas"/>
          <Button x:Name="ListoPaginas" Content="Listo" Style="{StaticResource BotonPrincipal}" Padding="26,8"/>
        </StackPanel>
        <StackPanel VerticalAlignment="Center">
          <TextBlock Text="Páginas del celular" FontSize="16" FontWeight="SemiBold"/>
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

          <StackPanel x:Name="VistaUsb" Visibility="Collapsed">
            <TextBlock Text="CELULAR POR CABLE" Style="{StaticResource Etiqueta}"/>
            <Border x:Name="UsbIcono" Width="76" Height="76" CornerRadius="22" Background="#1AFB923C" HorizontalAlignment="Center" Margin="0,36,0,18">
              <Path x:Name="UsbIconoPath" Width="36" Height="36" Stretch="Uniform" Stroke="#FB923C" StrokeThickness="1.8"
                    StrokeLineJoin="Round" StrokeStartLineCap="Round" StrokeEndLineCap="Round"
                    Data="M8,2.5 L16,2.5 A2,2 0 0 1 18,4.5 L18,19.5 A2,2 0 0 1 16,21.5 L8,21.5 A2,2 0 0 1 6,19.5 L6,4.5 A2,2 0 0 1 8,2.5 Z M10.5,18.2 L13.5,18.2"/>
            </Border>
            <TextBlock x:Name="UsbTitulo" Text="Buscando el celular…" FontSize="16" FontWeight="SemiBold" TextAlignment="Center" TextWrapping="Wrap"/>
            <TextBlock x:Name="UsbDetalle" Margin="6,8,6,0" Foreground="{StaticResource Tenue}" TextAlignment="Center" TextWrapping="Wrap" LineHeight="19"/>
            <Button x:Name="AbrirCelular" Content="Abrir en el celular" Style="{StaticResource BotonPrincipal}" Margin="0,24,0,0"
                    HorizontalAlignment="Center" Visibility="Collapsed" ToolTip="Vuelve a abrir el panel en el Chrome del celular"/>
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
foreach ($n in 'Logo', 'Punto', 'Estado', 'Modos', 'ModoWifi', 'ModoUsb', 'Aviso', 'AvisoTexto', 'AvisoBoton', 'VistaWifi', 'Qr', 'QrEspera',
    'Direccion', 'Copiar', 'VistaUsb', 'UsbIcono', 'UsbIconoPath', 'UsbTitulo', 'UsbDetalle', 'AbrirCelular', 'TarjetaDispositivos',
    'ListaDispositivos', 'SinDispositivos', 'ListaActividad', 'AbrirPc', 'Detener',
    'AbrirPaginas', 'VistaConexion', 'VistaPaginas', 'ListaPaginas', 'RestablecerPaginas', 'ListoPaginas') {
    $ui[$n] = $w.FindName($n)
}
try {
    $w.Icon = [Windows.Media.Imaging.BitmapFrame]::Create((New-Object Uri (Join-Path $Raiz 'panel.ico')))
    $logo = New-Object Windows.Media.Imaging.BitmapImage
    $logo.BeginInit(); $logo.UriSource = New-Object Uri (Join-Path $Raiz 'public\icon-192.png'); $logo.DecodePixelWidth = 96; $logo.CacheOption = 'OnLoad'; $logo.EndInit()
    $ui.Logo.Background = New-Object Windows.Media.ImageBrush $logo
} catch { }

# ---------- Estado
$script:modo = $modoInicial
$script:token = $null
$script:servidor = $null       # proceso de node (server.js)
$script:errServidor = $null    # lo que el servidor escribe en stderr (solo se lee si se cierra)
$script:adb = $null
$script:serial = $null
$script:modelo = ''
$script:tunel = $false
$script:abierto = $false
$script:lanIp = $null
$script:url = $null
$script:qrPuesto = $false
$script:arrancando = $false
$script:saliendo = $false
$script:inicioHecho = $false
$script:avisoBandeja = $false
$script:avisoAccion = $null
$script:copiadoHasta = $null
$script:estadoNormal = @('Arrancando…', $C.Naranja)
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
    try { & $Bloque } catch { try { Add-EventoLocal "Error: $($_.Exception.Message)" 'error' } catch { } }
}

function Get-NombreModo([string]$Modo) { if ($Modo -eq 'wifi') { 'Wi-Fi' } else { 'cable USB' } }

function Set-Estado([string]$Texto, [string]$Color, [switch]$Normal) {
    $ui.Estado.Text = $Texto
    $ui.Punto.Fill = Get-Pincel $Color
    if ($Normal) { $script:estadoNormal = @($Texto, $Color) }
    $t = "Panel del PC: $Texto"
    $tray.Text = if ($t.Length -gt 63) { $t.Substring(0, 63) } else { $t }
}

function Show-Aviso([string]$Texto, [string]$Tipo = 'aviso', [string]$Boton, [scriptblock]$Accion) {
    $color = @{ error = $C.Rojo; aviso = $C.Naranja; info = $C.Teal }[$Tipo]
    $ui.Aviso.Background = Get-Pincel ($color -replace '^#', '#1A')
    $ui.Aviso.BorderBrush = Get-Pincel ($color -replace '^#', '#4D')
    $ui.AvisoTexto.Text = $Texto
    $ui.AvisoBoton.Content = $Boton
    $ui.AvisoBoton.Visibility = if ($Boton) { 'Visible' } else { 'Collapsed' }
    $script:avisoAccion = $Accion
    $ui.Aviso.Visibility = 'Visible'
}
function Hide-Aviso { $ui.Aviso.Visibility = 'Collapsed'; $script:avisoAccion = $null }

function Set-Fallo([string]$Texto, [string]$Boton, [scriptblock]$Accion) {
    Hide-Paginas
    Set-Estado 'No está funcionando' $C.Rojo -Normal
    Show-Aviso $Texto 'error' $Boton $Accion
    $ui.QrEspera.Text = 'Sin conexión'; $ui.QrEspera.Visibility = 'Visible'; $ui.Qr.Source = $null; $script:qrPuesto = $false
    Set-Usb 'El panel no está funcionando' 'Revisa el aviso de arriba.' $C.Rojo
    $ui.AbrirCelular.Visibility = 'Collapsed'
    Show-Ventana
}

function Set-Botones([bool]$Activos) {
    foreach ($b in $ui.AbrirPc, $ui.Detener, $ui.ModoWifi, $ui.ModoUsb, $ui.AbrirPaginas) { $b.IsEnabled = $Activos }
}

function Set-Usb([string]$Titulo, [string]$Detalle, [string]$Color) {
    $ui.UsbTitulo.Text = $Titulo
    $ui.UsbDetalle.Text = $Detalle
    $ui.UsbIconoPath.Stroke = Get-Pincel $Color
    $ui.UsbIcono.Background = Get-Pincel ($Color -replace '^#', '#1A')
}

function Update-VistaModo {
    $esWifi = $script:modo -eq 'wifi'
    $ui.VistaWifi.Visibility = if ($esWifi) { 'Visible' } else { 'Collapsed' }
    $ui.VistaUsb.Visibility = if ($esWifi) { 'Collapsed' } else { 'Visible' }
    $ui.TarjetaDispositivos.Visibility = if ($esWifi) { 'Visible' } else { 'Collapsed' }
    $ui.Modos.Visibility = if ($PanelSoloWifi) { 'Collapsed' } else { 'Visible' }
    foreach ($par in @(@($ui.ModoWifi, $esWifi), @($ui.ModoUsb, (-not $esWifi)))) {
        $on = $par[1]
        $par[0].Background = Get-Pincel $(if ($on) { $C.Tile2 } else { '#00000000' })
        $par[0].BorderBrush = Get-Pincel $(if ($on) { '#1FFFFFFF' } else { '#00000000' })
        $par[0].Foreground = Get-Pincel $(if ($on) { $C.Texto } else { $C.Tenue })
    }
    $ui.Qr.Source = $null; $ui.QrEspera.Text = 'Preparando…'; $ui.QrEspera.Visibility = 'Visible'; $ui.Direccion.Text = ''
    Set-Usb 'Buscando el celular…' '' $C.Naranja
    $ui.AbrirCelular.Visibility = 'Collapsed'
    $script:qrPuesto = $false; $script:url = $null; $script:firmaDispositivos = $null; $script:firmaActividad = $null
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

function Add-EventoLocal([string]$Mensaje, [string]$Tipo = 'local') {
    [void]$script:eventosLocales.Add([pscustomobject]@{ t = [DateTimeOffset]::Now.ToUnixTimeMilliseconds(); tipo = $Tipo; msg = $Mensaje })
    while ($script:eventosLocales.Count -gt 20) { $script:eventosLocales.RemoveAt(0) }
    Update-Actividad
}

# Lo que ha pasado (del servidor y de esta ventana), lo más reciente arriba.
function Update-Actividad {
    $todos = @(@($script:eventosServidor) + @($script:eventosLocales) | Where-Object { $_ } |
        Sort-Object { [double]$_.t } -Descending | Select-Object -First 7)
    $firma = ($todos | ForEach-Object { "$($_.t)|$($_.msg)" }) -join "`n"
    if ($null -ne $script:firmaActividad -and $firma -eq $script:firmaActividad) { return }
    $script:firmaActividad = $firma
    $ui.ListaActividad.Children.Clear()
    if (-not $todos.Count) {
        $vacio = if ($script:modo -eq 'wifi') { 'Aquí verás lo que hagas desde el celular y los dispositivos que pidan entrar.' } else { 'Aquí verás lo que hagas desde el celular.' }
        [void]$ui.ListaActividad.Children.Add((New-Texto $vacio $C.Tenue))
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
        [void]$fila.Children.Add((New-Texto ([string]$e.msg) $color))
        [void]$ui.ListaActividad.Children.Add($fila)
    }
}

function Format-Hace($Ms) {
    if ($null -eq $Ms) { return 'todavía no se ha conectado' }
    $Ms = [double]$Ms
    if ($Ms -lt 20000) { 'conectado ahora' }
    elseif ($Ms -lt 120000) { 'hace un momento' }
    elseif ($Ms -lt 3600000) { "hace $([math]::Floor($Ms / 60000)) min" }
    else { "hace $([math]::Floor($Ms / 3600000)) h" }
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
        $quitar.Content = 'Quitar'; $quitar.Style = $w.FindResource('BotonEnlace'); $quitar.Tag = $f.Ip; $quitar.VerticalAlignment = 'Center'
        $quitar.ToolTip = "Dejar de permitir $($f.Ip)"
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
    if ($Texto -match 'EADDRINUSE') { return "el puerto $Puerto lo está usando otro programa." }
    if ($Texto -match 'EACCES|EADDRNOTAVAIL') { return 'Windows no dejó abrir el puerto del panel.' }
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
    if ($script:modo -eq 'usb' -and $script:adb -and $script:serial) { Remove-TunelUsb $script:adb $script:serial $Puerto }
    $script:serial = $null; $script:tunel = $false; $script:abierto = $false
}

function Start-Flujo([string]$Modo) {
    if ($script:arrancando) { return }
    $script:arrancando = $true
    try { Start-Pasos $Modo } finally { $script:arrancando = $false; Set-Botones $true }
}

function Start-Pasos([string]$Modo) {
    $script:modo = $Modo
    Hide-Paginas
    Set-Botones $false
    Hide-Aviso
    Update-VistaModo
    Set-Estado 'Arrancando…' $C.Naranja -Normal
    Update-Ui

    # 1. Archivos y Node.js
    $faltan = Get-ArchivosFaltantes $Raiz
    if ($faltan.Count) { Set-Fallo "Faltan archivos del panel: $($faltan -join ', '). Vuelve a descomprimir el .zip del panel completo."; return }
    $nv = Get-NodeVersion
    if (-not $nv) { Update-RutaSesion; $nv = Get-NodeVersion }
    if (-not $nv -or $nv -lt $PanelNodeMinimo) {
        $que = if ($nv) { "Node.js $nv es muy antiguo (se necesita la versión $($PanelNodeMinimo.Major) o superior)." } else { 'No se encontró Node.js, que el panel necesita.' }
        Set-Fallo "$que La revisión de requisitos te ofrece instalarlo." 'Revisar requisitos' { Start-Process (Join-Path $Raiz 'verificar.cmd') }
        return
    }
    $script:token = Get-PanelToken $Raiz
    Initialize-PanelConfig $Raiz

    # 2. Red (Wi-Fi) y adb (cable)
    $script:lanIp = $null
    if ($Modo -eq 'wifi') {
        Set-Estado 'Buscando la red…' $C.Naranja; Update-Ui
        $red = Get-PanelRed
        if (-not $red) {
            Set-Fallo 'Este PC no está conectado a una red local. Conéctalo al router (por cable o Wi-Fi), en la misma red que el celular.' 'Reintentar' { Start-Flujo 'wifi' }
            return
        }
        $script:lanIp = $red.Ip
        if ($red.Publica) {
            Show-Aviso "Windows tiene la red «$($red.Nombre)» marcada como Pública, así que el celular no podrá entrar. Si es la red de tu casa, cámbiala a Privada." 'aviso' 'Abrir configuración' { Start-Process 'ms-settings:network' }
        }
    }
    $script:adb = if ($PanelSoloWifi) { $null } else { Find-Adb }
    if ($Modo -eq 'usb' -and -not $script:adb) {
        Set-Fallo 'Falta adb (las herramientas de Android), que el modo por cable necesita. La revisión de requisitos te ofrece instalarlo; también puedes usar el modo Wi-Fi.' 'Revisar requisitos' { Start-Process (Join-Path $Raiz 'verificar.cmd') }
        return
    }
    if ($script:adb) { Set-Estado 'Buscando el celular…' $C.Naranja; Update-Ui; Start-Adb $script:adb }

    # 3. ¿Ya hay un panel en marcha en este puerto?
    $script:servidor = $null; $script:errServidor = $null
    if (Test-Panel $Puerto) {
        $e = Invoke-PanelApi 'GET' '/api/pc'
        if (-not $e) {
            Set-Fallo "Hay otra copia del panel abierta en el puerto $Puerto, probablemente en una ventana de consola." 'Cerrarla y continuar' {
                if (Stop-OtraCopia $Puerto) { Start-Sleep -Milliseconds 1000 }
                Start-Flujo $script:modo
            }
            return
        }
        $proc = Get-ProcesoEnPuerto $Puerto
        if ($proc -and $e.modo -eq $Modo -and ($Modo -ne 'wifi' -or $e.lanIp -eq $script:lanIp)) { $script:servidor = $proc }
        else {
            [void](Invoke-PanelApi 'POST' '/api/pc/detener')
            if ($proc) { [void]$proc.WaitForExit(3000) }
        }
    }

    # 4. Arranca el servidor y espera a que responda
    if (-not $script:servidor) {
        Set-Estado 'Arrancando el servidor…' $C.Naranja; Update-Ui
        try { $script:servidor = Start-PanelServidor $Raiz $Puerto $script:token $script:lanIp }
        catch { Set-Fallo "No se pudo abrir Node.js: $($_.Exception.Message)" 'Revisar requisitos' { Start-Process (Join-Path $Raiz 'verificar.cmd') }; return }
        $script:errServidor = $script:servidor.StandardError.ReadToEndAsync()
        $ok = $false
        for ($i = 0; $i -lt 40; $i++) {
            if ((Test-Panel $Puerto) -and (-not $script:lanIp -or (Test-Panel $Puerto $script:lanIp))) { $ok = $true; break }
            if ($script:servidor.HasExited) { break }
            Start-Sleep -Milliseconds 250; Update-Ui
        }
        if (-not $ok) {
            Stop-Servidor
            $detalle = if ($script:errServidor -and $script:errServidor.Wait(1000)) { Format-ErrorServidor $script:errServidor.Result } else { '' }
            Set-Fallo "El servidor del panel no arrancó$(if ($detalle) { ": $detalle" } else { '.' })" 'Reintentar' { Start-Flujo $script:modo }
            return
        }
    }

    # 5. Listo
    if ($Modo -eq 'wifi') {
        Set-Estado "En marcha por Wi-Fi · $($script:lanIp)" $C.Verde -Normal
        Update-Ui
        # Si el celular está conectado por cable, se autoriza su IP (si todavía no hay ninguno) y se le abre el panel.
        if ($script:adb) {
            $cel = Get-CelularAdb $script:adb
            if ($cel -and $cel.Estado -eq 'device') {
                $ip = Get-IpWifiCelular $script:adb $cel.Serial
                if ($ip -and (Add-CelularPorCable $Raiz $ip) -eq 'agregado') { Add-EventoLocal "Celular autorizado por cable: $ip." 'aprobacion' }
                Open-PanelEnCelular $script:adb $cel.Serial $script:lanIp $Puerto $script:token
                Add-EventoLocal 'Panel abierto en el celular, que estaba conectado por cable. Ya puedes desconectarlo.'
            }
        }
    } else {
        Update-Usb
    }
    Update-Tick -Forzar
}

function Switch-Modo([string]$Modo) {
    Hide-Aviso
    Set-Estado "Cambiando a $(Get-NombreModo $Modo)…" $C.Naranja
    Set-Botones $false
    Update-Ui
    Stop-Servidor
    Start-Flujo $Modo
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

# ---------- Celular por cable: túnel, reconexión y apertura
function Update-Usb {
    if ($script:modo -ne 'usb' -or -not $script:adb -or -not $script:servidor) { return }
    $cel = Get-CelularAdb $script:adb
    $antes = $script:tunel
    if (-not $cel -or $cel.Estado -ne 'device') {
        $script:tunel = $false
        $ui.AbrirCelular.Visibility = 'Collapsed'
        if ($antes) { Add-EventoLocal 'Celular desconectado. El panel se vuelve a conectar solo en cuanto conectes el cable.' 'rechazo' }
        if ($cel -and $cel.Estado -eq 'unauthorized') {
            Set-Estado 'Esperando permiso en el celular' $C.Naranja -Normal
            Set-Usb 'Acepta el aviso en el celular' 'Desbloquéalo y pulsa Permitir en «¿Permitir depuración USB?». Marca «Permitir siempre desde este equipo» para que no vuelva a preguntar.' $C.Naranja
        } elseif ($cel) {
            Set-Estado 'Conectando con el celular…' $C.Naranja -Normal
            Set-Usb 'Conectando con el celular…' 'Un momento.' $C.Naranja
        } else {
            Set-Estado 'Esperando al celular' $C.Naranja -Normal
            Set-Usb 'Conecta el celular por cable' 'Con la depuración USB activada. El panel se abrirá solo en cuanto lo conectes.' $C.Naranja
        }
        return
    }
    if ($cel.Serial -ne $script:serial) {
        $script:serial = $cel.Serial
        $script:modelo = Get-ModeloCelular $script:adb $cel.Serial
        $script:abierto = $false
    }
    if (-not (Set-TunelUsb $script:adb $script:serial $Puerto)) {
        $script:tunel = $false
        Set-Estado 'No se pudo conectar con el celular' $C.Rojo -Normal
        Set-Usb 'No se pudo crear el túnel USB' 'Desconecta el cable y vuelve a conectarlo.' $C.Rojo
        return
    }
    $script:tunel = $true
    if (-not $antes -and $script:abierto) { Add-EventoLocal 'Celular reconectado: el panel volvió a conectarse.' 'aprobacion' }
    if (-not $script:abierto) {
        Open-PanelEnCelular $script:adb $script:serial 'localhost' $Puerto $script:token
        $script:abierto = $true
        Add-EventoLocal 'Panel abierto en el celular.'
    }
    Set-Estado 'En marcha por cable' $C.Verde -Normal
    Set-Usb 'Celular conectado' "$(if ($script:modelo) { "$($script:modelo) · " })Si desconectas el cable, el panel se vuelve a conectar solo." $C.Teal
    $ui.AbrirCelular.Visibility = 'Visible'
}

# ---------- Actualización periódica
function Update-Tick([switch]$Forzar) {
    if (($script:arrancando -and -not $Forzar) -or $script:saliendo) { return }
    $script:ticks++
    if (-not $script:servidor) { return }
    if ($script:servidor.HasExited) {
        $detalle = if ($script:errServidor -and $script:errServidor.Wait(500)) { Format-ErrorServidor $script:errServidor.Result } else { '' }
        $script:servidor = $null
        Set-Fallo "El panel se detuvo$(if ($detalle) { ": $detalle" } else { '.' })" 'Volver a arrancar' { Start-Flujo $script:modo }
        return
    }
    $e = Invoke-PanelApi 'GET' '/api/pc'
    if ($e) {
        if ($script:modo -eq 'wifi') {
            if (-not $script:qrPuesto -and $e.qr) {
                Set-Qr @($e.qr)
                $script:url = $e.url
                $ui.Direccion.Text = "$($e.lanIp):$($e.puerto)"
            }
            Update-Dispositivos $e.dispositivos
        }
        $script:eventosServidor = @($e.actividad)
        Update-Actividad
        if ($e.pendiente) { Set-Estado "$($e.pendiente) pide entrar: responde el aviso del PC" $C.Teal }
        else { Set-Estado $script:estadoNormal[0] $script:estadoNormal[1] }
    }
    if ($script:modo -eq 'usb' -and ($Forzar -or $script:ticks % 2 -eq 0)) { Update-Usb }
}

function Remove-Dispositivo([string]$Ip) {
    $r = [Windows.MessageBox]::Show($w, "¿Quitar $Ip de los dispositivos autorizados?`n`nDejará de poder usar el panel. Si vuelve a escanear el código, este PC te preguntará otra vez.",
        'Panel del PC', 'YesNo', 'Question')
    if ("$r" -ne 'Yes') { return }
    [void](Invoke-PanelApi 'POST' '/api/pc/quitar' @{ ip = $Ip })
    $script:firmaDispositivos = $null
    Update-Tick
}

function Open-EnPc { if ($script:token) { Start-Process "http://localhost:$Puerto/#t=$($script:token)" } }

# ---------- Páginas del celular: cuáles se ven y en qué orden. Las guarda el servidor (data\paginas.json) y el celular
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
    $ui.AbrirPaginas.Visibility = 'Collapsed'; $ui.Modos.Visibility = 'Collapsed'
    $script:enPaginas = $true
}

function Hide-Paginas {
    if (-not $script:enPaginas) { return }
    $script:enPaginas = $false
    $ui.VistaPaginas.Visibility = 'Collapsed'; $ui.VistaConexion.Visibility = 'Visible'
    $ui.AbrirPaginas.Visibility = 'Visible'
    $ui.Modos.Visibility = if ($PanelSoloWifi) { 'Collapsed' } else { 'Visible' }
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
    $r = [Windows.MessageBox]::Show($w, '¿Volver al orden original, con todas las páginas?', 'Panel del PC', 'YesNo', 'Question')
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

# Vista previa de cada página (public\miniaturas\<página>.jpg, las genera herramientas\miniaturas.js). Se cargan una vez;
# si falta alguna, la tarjeta lo dice y todo lo demás funciona igual.
function Get-Miniatura([string]$Id) {
    if ($script:miniaturas.ContainsKey($Id)) { return $script:miniaturas[$Id] }
    $img = $null
    $ruta = Join-Path $Raiz "public\miniaturas\$Id.jpg"
    if (Test-Path $ruta) {
        try {
            $img = New-Object Windows.Media.Imaging.BitmapImage
            $img.BeginInit(); $img.UriSource = New-Object Uri $ruta; $img.DecodePixelWidth = 480; $img.CacheOption = 'OnLoad'; $img.EndInit()
            $img.Freeze()
        } catch { $img = $null }
    }
    $script:miniaturas[$Id] = $img
    $img
}

# Pastilla sobre la vista previa ("Al conectar", "Oculta").
function New-Pastilla([string]$Texto, [string]$Color, [string]$Punto) {
    $b = New-Object Windows.Controls.Border
    $b.Background = Get-Pincel '#E607090C'; $b.BorderBrush = Get-Pincel '#33FFFFFF'; $b.BorderThickness = 1
    $b.CornerRadius = 99; $b.Padding = '9,3,10,4'; $b.IsHitTestVisible = $false
    $sp = New-Object Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'
    if ($Punto) {
        $o = New-Object Windows.Shapes.Ellipse
        $o.Width = 6; $o.Height = 6; $o.Fill = Get-Pincel $Punto; $o.Margin = '0,1,6,0'; $o.VerticalAlignment = 'Center'
        [void]$sp.Children.Add($o)
    }
    $t = New-Texto $Texto $Color 11 ([Windows.FontWeights]::SemiBold)
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
    [Windows.Automation.AutomationProperties]::SetName($b, $(if ($Paso -lt 0) { "Mover $Nombre antes" } else { "Mover $Nombre después" }))
    $b.ToolTip = if ($Paso -lt 0) { 'Mover antes' } else { 'Mover después' }
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
        $p = $l[$i]; $ver = [bool]$p.ver; $id = [string]$p.id; $nombre = [string]$p.nombre
        if ($ver) { $n++ }
        $tarjeta = New-Object Windows.Controls.StackPanel
        $tarjeta.Margin = '0,0,16,16'; $tarjeta.Tag = $id; $tarjeta.AllowDrop = $true; $tarjeta.Background = Get-Pincel '#00000000'
        $tarjeta.ToolTip = [string]$p.detalle

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
            $sin = New-Texto 'Sin vista previa' $C.Apagado 12
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
        $avatar.Width = 26; $avatar.Height = 26; $avatar.CornerRadius = 13; $avatar.BorderThickness = 1
        $avatar.Background = Get-Pincel $(if ($ver) { '#262DD4BF' } else { $C.Tile2 })
        $avatar.BorderBrush = Get-Pincel $(if ($ver) { '#592DD4BF' } else { '#1FFFFFFF' })
        $num = New-Texto $(if ($ver) { "$n" } else { '–' }) $(if ($ver) { $C.Teal } else { $C.Apagado }) 12 ([Windows.FontWeights]::SemiBold)
        $num.TextWrapping = 'NoWrap'; $num.HorizontalAlignment = 'Center'; $num.VerticalAlignment = 'Center'
        $avatar.Child = $num
        [Windows.Controls.DockPanel]::SetDock($avatar, 'Left')
        $chk = New-Object Windows.Controls.CheckBox
        $chk.Style = $w.FindResource('Interruptor'); $chk.Padding = '0'; $chk.IsChecked = $ver; $chk.Tag = $id; $chk.VerticalAlignment = 'Center'
        [Windows.Controls.DockPanel]::SetDock($chk, 'Right')
        [Windows.Automation.AutomationProperties]::SetName($chk, "Mostrar $nombre")
        if ($ver -and $visibles -eq 1) {
            $chk.IsEnabled = $false
            $chk.ToolTip = 'Tiene que quedar al menos una página'
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
$item = $menu.Items.Add('Mostrar la ventana'); $item.Font = New-Object Drawing.Font($item.Font, [Drawing.FontStyle]::Bold)
$item.Add_Click({ Invoke-Seguro { Show-Ventana } })
$menu.Items.Add('Abrir en este PC').Add_Click({ Invoke-Seguro { Open-EnPc } })
[void]$menu.Items.Add((New-Object Windows.Forms.ToolStripSeparator))
$menu.Items.Add('Detener el panel').Add_Click({ Invoke-Seguro { Exit-Panel } })
$tray.ContextMenuStrip = $menu
$tray.Add_MouseClick({ param($s, $e) if ($e.Button -eq [Windows.Forms.MouseButtons]::Left) { Invoke-Seguro { Show-Ventana } } })
$tray.Add_BalloonTipClicked({ Invoke-Seguro { Show-Ventana } })
$tray.Visible = $true

# ---------- Eventos de la ventana
$ui.AvisoBoton.Add_Click({ Invoke-Seguro { $accion = $script:avisoAccion; Hide-Aviso; if ($accion) { & $accion } } })
$ui.Copiar.Add_Click({ Invoke-Seguro {
    if ($script:url) { [Windows.Clipboard]::SetText($script:url); $ui.Copiar.Content = 'Copiado'; $script:copiadoHasta = (Get-Date).AddSeconds(2) }
} })
$ui.AbrirPc.Add_Click({ Invoke-Seguro { Open-EnPc } })
$ui.Detener.Add_Click({ Invoke-Seguro { Exit-Panel } })
$ui.AbrirCelular.Add_Click({ Invoke-Seguro {
    if ($script:serial) { Open-PanelEnCelular $script:adb $script:serial 'localhost' $Puerto $script:token; Add-EventoLocal 'Panel abierto otra vez en el celular.' }
} })
$ui.ModoWifi.Add_Click({ Invoke-Seguro { if ($script:modo -ne 'wifi') { Switch-Modo 'wifi' } } })
$ui.ModoUsb.Add_Click({ Invoke-Seguro { if ($script:modo -ne 'usb') { Switch-Modo 'usb' } } })
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
        $tray.ShowBalloonTip(6000, 'El panel sigue funcionando',
            'Para volver a la ventana, haz clic en este icono o abre el panel desde el menú Inicio. Para cerrarlo del todo, usa «Detener el panel».',
            [Windows.Forms.ToolTipIcon]::Info)
    }
})
$w.Add_SourceInitialized({
    if ($hayNativo) { try { [PanelNativo]::BarraOscura((New-Object Windows.Interop.WindowInteropHelper $w).Handle, 0x07090C, 0x1B2029) } catch { } }
})
$w.Add_ContentRendered({
    if ($script:inicioHecho) { return }
    $script:inicioHecho = $true
    [void]$w.Dispatcher.BeginInvoke([Action] { Invoke-Seguro { Start-Flujo $script:modo } }, [Windows.Threading.DispatcherPriority]::Background)
})

# Cada 1,5 s: estado del servidor (QR, dispositivos, actividad) y, en modo USB, el cable.
$reloj = New-Object Windows.Threading.DispatcherTimer
$reloj.Interval = [TimeSpan]::FromMilliseconds(1500)
$reloj.Add_Tick({ Invoke-Seguro { Update-Tick } })
# Cada 0,4 s: si se volvió a abrir el panel desde el menú Inicio, se muestra esta ventana.
$relojSenal = New-Object Windows.Threading.DispatcherTimer
$relojSenal.Interval = [TimeSpan]::FromMilliseconds(400)
$relojSenal.Add_Tick({ Invoke-Seguro {
    foreach ($m in 'wifi', 'usb') {
        if (-not $senal[$m].WaitOne(0)) { continue }
        Show-Ventana
        if ($script:arrancando) { continue }
        if ($m -ne $script:modo) {
            Show-Aviso "El panel está abierto en modo $(Get-NombreModo $script:modo)." 'info' "Cambiar a $(Get-NombreModo $m)" ([scriptblock]::Create("Switch-Modo '$m'"))
        } elseif ($m -eq 'usb' -and $script:tunel) {
            Open-PanelEnCelular $script:adb $script:serial 'localhost' $Puerto $script:token
            Add-EventoLocal 'Panel abierto otra vez en el celular.'
        }
    }
    if ($script:copiadoHasta -and (Get-Date) -gt $script:copiadoHasta) { $ui.Copiar.Content = 'Copiar enlace'; $script:copiadoHasta = $null }
} })

Update-VistaModo
Update-Actividad
$reloj.Start()
$relojSenal.Start()
$app = New-Object Windows.Application
$app.ShutdownMode = [Windows.ShutdownMode]::OnExplicitShutdown
$app.Add_DispatcherUnhandledException({ param($s, $e)
    $e.Handled = $true
    try { Add-EventoLocal "Error inesperado: $($e.Exception.Message)" 'error' } catch { }
})
try { [void]$app.Run($w) }
finally {
    if ($script:servidor -and -not $script:servidor.HasExited) { try { $script:servidor.Kill() } catch { } }
    try { $tray.Dispose() } catch { }
    try { $mutex.ReleaseMutex() } catch { }
}
