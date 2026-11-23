# Mezclador de volumen: el volumen, el silencio y el nivel de sonido de cada aplicación (como el mezclador de Windows).
# Lo usa el proceso de control permanente del servidor. Necesita lib\media.ps1 cargado antes (volumen general).
Add-Type -ErrorAction Stop -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

namespace PanelMx {
  [Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IDeviceEnumerator {
    [PreserveSig] int EnumAudioEndpoints(int flow, int mask, out IntPtr devices);
    [PreserveSig] int GetDefaultAudioEndpoint(int flow, int role, out IDevice device);
  }
  [Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IDevice {
    [PreserveSig] int Activate(ref Guid iid, int ctx, IntPtr p, [MarshalAs(UnmanagedType.IUnknown)] out object o);
    [PreserveSig] int OpenPropertyStore(int access, out IPropStore store);
  }
  [Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IPropStore {
    [PreserveSig] int GetCount(out int n);
    [PreserveSig] int GetAt(int i, out PropKey k);
    [PreserveSig] int GetValue(ref PropKey k, out PropVar v);
  }
  [StructLayout(LayoutKind.Sequential)] struct PropKey { public Guid fmtid; public int pid; }
  [StructLayout(LayoutKind.Sequential)] struct PropVar { public ushort vt, r1, r2, r3; public IntPtr p, p2; }
  [Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface ISessionManager2 {
    [PreserveSig] int GetAudioSessionControl(IntPtr g, int f, out IntPtr c);
    [PreserveSig] int GetSimpleAudioVolume(IntPtr g, int f, out IntPtr v);
    [PreserveSig] int GetSessionEnumerator(out ISessionEnumerator e);
  }
  [Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface ISessionEnumerator {
    [PreserveSig] int GetCount(out int n);
    [PreserveSig] int GetSession(int i, [MarshalAs(UnmanagedType.IUnknown)] out object s);
  }
  [Guid("BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface ISessionControl2 {
    [PreserveSig] int GetState(out int state);
    [PreserveSig] int GetDisplayName([MarshalAs(UnmanagedType.LPWStr)] out string name);
    [PreserveSig] int SetDisplayName(IntPtr v, IntPtr ctx);
    [PreserveSig] int GetIconPath([MarshalAs(UnmanagedType.LPWStr)] out string path);
    [PreserveSig] int SetIconPath(IntPtr v, IntPtr ctx);
    [PreserveSig] int GetGroupingParam(out Guid g);
    [PreserveSig] int SetGroupingParam(IntPtr g, IntPtr ctx);
    [PreserveSig] int RegisterAudioSessionNotification(IntPtr n);
    [PreserveSig] int UnregisterAudioSessionNotification(IntPtr n);
    [PreserveSig] int GetSessionIdentifier([MarshalAs(UnmanagedType.LPWStr)] out string id);
    [PreserveSig] int GetSessionInstanceIdentifier([MarshalAs(UnmanagedType.LPWStr)] out string id);
    [PreserveSig] int GetProcessId(out int pid);
    [PreserveSig] int IsSystemSoundsSession();
    [PreserveSig] int SetDuckingPreference(bool optOut);
  }
  [Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface ISimpleVolume {
    [PreserveSig] int SetMasterVolume(float level, ref Guid ctx);
    [PreserveSig] int GetMasterVolume(out float level);
    [PreserveSig] int SetMute([MarshalAs(UnmanagedType.Bool)] bool mute, ref Guid ctx);
    [PreserveSig] int GetMute([MarshalAs(UnmanagedType.Bool)] out bool mute);
  }
  [Guid("C02216F6-8C67-4B5B-9D00-D008E73E0064"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IMeter { [PreserveSig] int GetPeakValue(out float peak); }

  class Sesion { public ISessionControl2 Ctl; public ISimpleVolume Vol; public IMeter Medidor; public string Clave, Nombre, Ruta; public bool Sistema; }
  class Grupo { public string Clave, Nombre, Ruta; public bool Sistema, Silencio, Activa; public float Nivel, Pico; }

  public static class Mezclador {
    [DllImport("kernel32.dll")] static extern IntPtr OpenProcess(int access, bool inherit, int pid);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern bool QueryFullProcessImageName(IntPtr h, int flags, StringBuilder name, ref int size);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern uint PrivateExtractIcons(string file, int index, int cx, int cy, IntPtr[] icons, int[] ids, uint n, uint flags);
    [DllImport("user32.dll")] static extern bool DestroyIcon(IntPtr h);
    [DllImport("ole32.dll")] static extern int PropVariantClear(ref PropVar v);

    static List<Sesion> sesiones = new List<Sesion>();
    static IMeter medidorGeneral;
    static string dispositivo = "";
    static DateTime enumerado = DateTime.MinValue, procesosLimpios = DateTime.UtcNow;
    static readonly Dictionary<int, string[]> procesos = new Dictionary<int, string[]>(); // pid → { ruta, nombre }
    static readonly HashSet<string> iconosEnviados = new HashSet<string>();
    static Guid contexto = Guid.Empty;
    static string error; // último error al leer las sesiones (se manda en el JSON para poder diagnosticarlo)

    // La lista de sesiones se vuelve a pedir a Windows como mucho una vez por segundo; el volumen y el nivel se leen siempre.
    static void Actualizar() {
      if ((DateTime.UtcNow - enumerado).TotalMilliseconds < 1000) return;
      enumerado = DateTime.UtcNow;
      if ((DateTime.UtcNow - procesosLimpios).TotalSeconds > 30) { procesos.Clear(); procesosLimpios = DateTime.UtcNow; }
      var nuevas = new List<Sesion>();
      medidorGeneral = null; dispositivo = ""; error = null;
      try {
        // Se crea por su CLSID (MMDeviceEnumerator) y no con una clase [ComImport]: media.ps1 ya declara una para el mismo
        // CLSID y, si se usó antes, .NET devuelve un objeto de esa otra clase y la conversión falla.
        var en = (IDeviceEnumerator)Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")));
        IDevice dev;
        if (en.GetDefaultAudioEndpoint(0, 1, out dev) != 0 || dev == null) { sesiones = nuevas; return; }
        dispositivo = NombreDispositivo(dev);
        object o;
        Guid iid = typeof(IMeter).GUID;
        if (dev.Activate(ref iid, 23, IntPtr.Zero, out o) == 0) medidorGeneral = o as IMeter;
        iid = typeof(ISessionManager2).GUID;
        if (dev.Activate(ref iid, 23, IntPtr.Zero, out o) != 0) { sesiones = nuevas; return; }
        ISessionEnumerator e;
        if (((ISessionManager2)o).GetSessionEnumerator(out e) != 0) { sesiones = nuevas; return; }
        int n; e.GetCount(out n);
        for (int i = 0; i < n; i++) {
          object so;
          if (e.GetSession(i, out so) != 0 || so == null) continue;
          var c = so as ISessionControl2;
          if (c == null) continue;
          int estado; c.GetState(out estado);
          if (estado == 2) continue; // sesión terminada
          var s = new Sesion { Ctl = c, Vol = so as ISimpleVolume, Medidor = so as IMeter };
          s.Sistema = c.IsSystemSoundsSession() == 0;
          if (s.Sistema) { s.Clave = "sistema"; s.Nombre = "Sonidos del sistema"; }
          else {
            int pid; c.GetProcessId(out pid);
            string[] info = Proceso(pid);
            if (info == null) continue; // el programa ya se cerró
            s.Ruta = info[0];
            s.Clave = info[0] != null ? info[0].ToLowerInvariant() : "pid:" + pid;
            string visible = null;
            try { c.GetDisplayName(out visible); } catch { }
            s.Nombre = !string.IsNullOrEmpty(visible) && !visible.StartsWith("@") ? visible : info[1];
          }
          nuevas.Add(s);
        }
      } catch (Exception ex) { error = ex.GetType().Name + ": " + ex.Message; }
      sesiones = nuevas;
    }

    static string[] Proceso(int pid) {
      string[] r;
      if (procesos.TryGetValue(pid, out r)) return r;
      string ruta = null, nombre = null;
      IntPtr h = OpenProcess(0x1000, false, pid); // PROCESS_QUERY_LIMITED_INFORMATION
      if (h != IntPtr.Zero) {
        var sb = new StringBuilder(1024); int tam = sb.Capacity;
        if (QueryFullProcessImageName(h, 0, sb, ref tam)) ruta = sb.ToString();
        CloseHandle(h);
      }
      if (ruta != null) {
        try { var v = FileVersionInfo.GetVersionInfo(ruta); nombre = Limpio(v.FileDescription) ?? Limpio(v.ProductName); } catch { }
        if (nombre == null) nombre = Path.GetFileNameWithoutExtension(ruta);
      } else {
        try { nombre = Process.GetProcessById(pid).ProcessName; } catch { return null; }
      }
      r = new[] { ruta, nombre };
      procesos[pid] = r;
      return r;
    }

    static string Limpio(string s) {
      if (string.IsNullOrWhiteSpace(s)) return null;
      s = s.Replace("®", "").Replace("™", "").Trim();
      return s.Length == 0 ? null : s;
    }

    static string NombreDispositivo(IDevice d) {
      try {
        IPropStore ps;
        if (d.OpenPropertyStore(0, out ps) != 0) return "";
        var k = new PropKey { fmtid = new Guid("a45c254e-df1c-4efd-8020-67d146a850e0"), pid = 14 }; // PKEY_Device_FriendlyName
        PropVar v;
        if (ps.GetValue(ref k, out v) != 0) return "";
        string s = v.vt == 31 ? Marshal.PtrToStringUni(v.p) : "";
        PropVariantClear(ref v);
        return s ?? "";
      } catch { return ""; }
    }

    // Icono del programa (64 px) como imagen PNG; se manda una sola vez por programa.
    static string Icono(string ruta) {
      try {
        var h = new IntPtr[1]; var ids = new int[1];
        uint r = PrivateExtractIcons(ruta, 0, 64, 64, h, ids, 1, 0);
        if (r == 0 || r == 0xFFFFFFFF || h[0] == IntPtr.Zero) return null;
        try {
          using (var ico = Icon.FromHandle(h[0])) using (var bmp = ico.ToBitmap()) using (var ms = new MemoryStream()) {
            bmp.Save(ms, ImageFormat.Png);
            return "data:image/png;base64," + Convert.ToBase64String(ms.ToArray());
          }
        } finally { DestroyIcon(h[0]); }
      } catch { return null; }
    }

    // Estado completo en JSON. El volumen general (nivel 0-100 y silencio) lo pasa media.ps1.
    public static string Estado(int nivelGeneral, bool silencioGeneral) {
      Actualizar();
      float picoGeneral = 0;
      try { if (medidorGeneral != null) medidorGeneral.GetPeakValue(out picoGeneral); } catch { }
      var grupos = new Dictionary<string, Grupo>(); var orden = new List<Grupo>();
      foreach (var s in sesiones) {
        try {
          int estado; s.Ctl.GetState(out estado);
          if (estado == 2) continue;
          float v = 1, p = 0; bool m = false;
          if (s.Vol != null) { s.Vol.GetMasterVolume(out v); s.Vol.GetMute(out m); }
          if (s.Medidor != null) s.Medidor.GetPeakValue(out p);
          Grupo g;
          if (!grupos.TryGetValue(s.Clave, out g)) {
            g = new Grupo { Clave = s.Clave, Nombre = s.Nombre, Ruta = s.Ruta, Sistema = s.Sistema, Nivel = v, Silencio = m, Pico = p, Activa = estado == 1 };
            grupos[s.Clave] = g; orden.Add(g);
          } else {
            g.Nivel = Math.Max(g.Nivel, v); g.Silencio = g.Silencio && m; g.Pico = Math.Max(g.Pico, p); g.Activa |= estado == 1;
          }
        } catch { }
      }
      // Orden estable por nombre (las columnas no saltan cuando una app empieza a sonar); los sonidos del sistema, al final.
      orden.Sort((a, b) => a.Sistema != b.Sistema ? (a.Sistema ? 1 : -1) : string.Compare(a.Nombre, b.Nombre, StringComparison.CurrentCultureIgnoreCase));
      var sb = new StringBuilder();
      sb.Append("{\"dispositivo\":").Append(Json(dispositivo));
      if (error != null) sb.Append(",\"error\":").Append(Json(error));
      sb.Append(",\"general\":{\"nivel\":").Append(nivelGeneral).Append(",\"silencio\":").Append(silencioGeneral ? "true" : "false");
      sb.Append(",\"pico\":").Append(F(picoGeneral)).Append("},\"apps\":[");
      for (int i = 0; i < orden.Count; i++) {
        var g = orden[i];
        if (i > 0) sb.Append(',');
        sb.Append("{\"clave\":").Append(Json(g.Clave)).Append(",\"nombre\":").Append(Json(g.Nombre));
        sb.Append(",\"nivel\":").Append((int)Math.Round(g.Nivel * 100)).Append(",\"silencio\":").Append(g.Silencio ? "true" : "false");
        sb.Append(",\"pico\":").Append(F(g.Pico)).Append(",\"activa\":").Append(g.Activa ? "true" : "false");
        sb.Append(",\"sistema\":").Append(g.Sistema ? "true" : "false");
        if (!g.Sistema && g.Ruta != null && iconosEnviados.Add(g.Clave)) {
          string ic = Icono(g.Ruta);
          if (ic != null) sb.Append(",\"icono\":").Append(Json(ic));
        }
        sb.Append('}');
      }
      return sb.Append("]}").ToString();
    }

    // Cambia el volumen (0-100) de todas las sesiones de un programa; subirlo también le quita el silencio.
    public static int Volumen(string clave, int nivel) {
      Actualizar();
      float v = Math.Max(0, Math.Min(100, nivel)) / 100f; int n = 0;
      foreach (var s in sesiones) if (s.Clave == clave && s.Vol != null) { s.Vol.SetMasterVolume(v, ref contexto); s.Vol.SetMute(false, ref contexto); n++; }
      return n;
    }

    public static int Silenciar(string clave, bool silencio) {
      Actualizar();
      int n = 0;
      foreach (var s in sesiones) if (s.Clave == clave && s.Vol != null) { s.Vol.SetMute(silencio, ref contexto); n++; }
      return n;
    }

    static string F(float x) { return Math.Max(0, Math.Min(1, x)).ToString("0.###", CultureInfo.InvariantCulture); }
    static string Json(string s) {
      if (s == null) return "null";
      var sb = new StringBuilder("\"");
      foreach (char ch in s) {
        if (ch == '"') sb.Append("\\\""); else if (ch == '\\') sb.Append("\\\\");
        else if (ch < 0x20) sb.Append("\\u").Append(((int)ch).ToString("x4")); else sb.Append(ch);
      }
      return sb.Append('"').ToString();
    }
  }
}
'@
