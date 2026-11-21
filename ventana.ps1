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
    </DockPanel>

    <Border x:Name="Aviso" Grid.Row="1" Visibility="Collapsed" CornerRadius="12" Padding="14,10" Margin="0,0,0,14" BorderThickness="1">
      <DockPanel>
        <Button x:Name="AvisoBoton" DockPanel.Dock="Right" Style="{StaticResource Boton}" Margin="14,0,0,0" Padding="12,6" VerticalAlignment="Center"/>
        <TextBlock x:Name="AvisoTexto" TextWrapping="Wrap" VerticalAlignment="Center" LineHeight="19"/>
      </DockPanel>
    </Border>

    <Grid Grid.Row="2">
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
    'ListaDispositivos', 'SinDispositivos', 'ListaActividad', 'AbrirPc', 'Detener') {
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
    Set-Estado 'No está funcionando' $C.Rojo -Normal
    Show-Aviso $Texto 'error' $Boton $Accion
    $ui.QrEspera.Text = 'Sin conexión'; $ui.QrEspera.Visibility = 'Visible'; $ui.Qr.Source = $null; $script:qrPuesto = $false
    Set-Usb 'El panel no está funcionando' 'Revisa el aviso de arriba.' $C.Rojo
    $ui.AbrirCelular.Visibility = 'Collapsed'
    Show-Ventana
}

function Set-Botones([bool]$Activos) {
    foreach ($b in $ui.AbrirPc, $ui.Detener, $ui.ModoWifi, $ui.ModoUsb) { $b.IsEnabled = $Activos }
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
