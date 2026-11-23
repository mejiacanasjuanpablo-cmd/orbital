# Funciones compartidas: volumen del sistema (Core Audio), canción actual y controles de música (Windows Media Controls).
$ErrorActionPreference = 'SilentlyContinue'

Add-Type -ErrorAction Stop -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
[Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioEndpointVolume {
  int f(); int g(); int h(); int i();
  int SetMasterVolumeLevelScalar(float fLevel, Guid pguidEventContext);
  int j();
  int GetMasterVolumeLevelScalar(out float pfLevel);
  int k(); int l(); int m(); int n();
  int SetMute([MarshalAs(UnmanagedType.Bool)] bool bMute, Guid pguidEventContext);
  int GetMute(out bool pbMute);
}
[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice { int Activate(ref Guid id, int clsCtx, int activationParams, out IAudioEndpointVolume aev); }
[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator { int f(); int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice endpoint); }
[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumeratorComObject { }
public static class PanelAudio {
  static IAudioEndpointVolume Vol() {
    var en = new MMDeviceEnumeratorComObject() as IMMDeviceEnumerator;
    IMMDevice dev = null; Marshal.ThrowExceptionForHR(en.GetDefaultAudioEndpoint(0, 1, out dev));
    IAudioEndpointVolume epv = null; var id = typeof(IAudioEndpointVolume).GUID;
    Marshal.ThrowExceptionForHR(dev.Activate(ref id, 23, 0, out epv)); return epv;
  }
  public static float Volume {
    get { float v = -1; Marshal.ThrowExceptionForHR(Vol().GetMasterVolumeLevelScalar(out v)); return v; }
    set { Marshal.ThrowExceptionForHR(Vol().SetMasterVolumeLevelScalar(value, Guid.Empty)); }
  }
  public static bool Mute {
    get { bool m; Marshal.ThrowExceptionForHR(Vol().GetMute(out m)); return m; }
    set { Marshal.ThrowExceptionForHR(Vol().SetMute(value, Guid.Empty)); }
  }
}
// Teclas multimedia de verdad, por su código de tecla virtual (no por un carácter, como hacía SendKeys).
public static class PanelMediaKeys {
  [DllImport("user32.dll")] static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  public static void Press(byte vk) {
    keybd_event(vk, 0, 1, UIntPtr.Zero);       // tecla extendida, abajo
    keybd_event(vk, 0, 1 | 2, UIntPtr.Zero);   // tecla extendida, arriba
  }
}
'@

$script:mediaMgr = $null
try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $script:asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
    $script:asStreamForRead = ([System.IO.WindowsRuntimeStreamExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsStreamForRead' -and $_.GetParameters().Count -eq 1 })[0]
    function Wait-WinRT($op, [Type]$type) {
        $t = $script:asTask.MakeGenericMethod($type).Invoke($null, @($op)); $null = $t.Wait(3000); $t.Result
    }
    $null = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType = WindowsRuntime]
    $null = [Windows.Storage.Streams.IRandomAccessStreamWithContentType, Windows.Storage.Streams, ContentType = WindowsRuntime]
    $script:mediaMgr = Wait-WinRT ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])
} catch { }

$script:lastArtKey = $null
function Get-PanelMedia {
    $out = @{ title = $null; artist = $null; app = $null; status = 'none'; position = 0; duration = 0; artKey = $null; art = $null }
    if (-not $script:mediaMgr) { return $out }
    $s = $script:mediaMgr.GetCurrentSession()
    if (-not $s) { return $out }
    $p = Wait-WinRT ($s.TryGetMediaPropertiesAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties])
    $info = $s.GetPlaybackInfo(); $tl = $s.GetTimelineProperties()
    $out.title = $p.Title; $out.artist = $p.Artist; $out.app = $s.SourceAppUserModelId
    $out.status = "$($info.PlaybackStatus)".ToLower()
    $out.duration = [math]::Round(($tl.EndTime - $tl.StartTime).TotalSeconds)
    $pos = $tl.Position.TotalSeconds
    if ($out.status -eq 'playing') { $pos += ([DateTimeOffset]::Now - $tl.LastUpdatedTime).TotalSeconds }
    $out.position = [math]::Round([math]::Min([math]::Max($pos, 0), [math]::Max($out.duration, 0)))
    $key = "$($p.Title)|$($p.Artist)"
    $out.artKey = $key
    if ($key -ne $script:lastArtKey -and $p.Thumbnail) {
        try {
            $ras = Wait-WinRT ($p.Thumbnail.OpenReadAsync()) ([Windows.Storage.Streams.IRandomAccessStreamWithContentType])
            # PowerShell 5.1 no proyecta el tipo WinRT, así que se usa reflexión.
            $st = $script:asStreamForRead.Invoke($null, @($ras))
            $ms = New-Object IO.MemoryStream; $st.CopyTo($ms)
            $ct = [Windows.Storage.Streams.IContentTypeProvider].GetProperty('ContentType').GetValue($ras)
            if (-not $ct) { $ct = 'image/png' }
            $out.art = 'data:' + $ct + ';base64,' + [Convert]::ToBase64String($ms.ToArray())
            $st.Dispose()
        } catch { }
        $script:lastArtKey = $key
    }
    return $out
}

# Controles de música: siguiente, anterior, play/pausa, stop, y volumen o silencio del sistema.
# Primero se le pide a la sesión multimedia actual (la misma que usan los controles de Windows: Spotify, Opera, Chrome...),
# sin depender del teclado ni de qué ventana está al frente. Si no hay sesión o no respondió, se pulsa la tecla multimedia.
# Antes se usaba SendKeys con [char]176..179, pero en teclados latinoamericanos [char]176 es '°', una tecla normal:
# en vez de pasar la canción, escribía "°" en la ventana que estuviera al frente.
$script:panelTeclasMedia = @{ mute = 0xAD; voldown = 0xAE; volup = 0xAF; next = 0xB0; prev = 0xB1; stop = 0xB2; playpause = 0xB3 }
function Invoke-PanelMedia([string]$Accion) {
    if (-not $script:panelTeclasMedia.ContainsKey($Accion)) { throw "Tecla multimedia desconocida: $Accion" }
    if ($script:mediaMgr -and $Accion -in 'next', 'prev', 'playpause', 'stop') {
        $s = $script:mediaMgr.GetCurrentSession()
        if ($s) {
            $op = switch ($Accion) {
                'next' { $s.TrySkipNextAsync() }
                'prev' { $s.TrySkipPreviousAsync() }
                'playpause' { $s.TryTogglePlayPauseAsync() }
                'stop' { $s.TryStopAsync() }
            }
            if (Wait-WinRT $op ([bool])) { return 'sesion' }
        }
    }
    [PanelMediaKeys]::Press([byte]$script:panelTeclasMedia[$Accion])
    'tecla'
}

function Get-PanelVolume {
    try { @{ level = [math]::Round([PanelAudio]::Volume * 100); muted = [PanelAudio]::Mute } } catch { @{ level = $null; muted = $false } }
}
