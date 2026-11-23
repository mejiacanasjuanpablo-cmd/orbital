// Panel del PC.exe: abre la ventana del panel (ventana.ps1) sin ninguna consola.
// instalar.ps1 lo compila en cada PC con el compilador de C# que trae Windows (.NET Framework 4); no se descarga nada.
// Ejecuta ventana.ps1 dentro de este mismo proceso, así que en la barra de tareas y en el Administrador de tareas
// aparece como "Panel del PC", con su icono.
using System;
using System.IO;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

[assembly: AssemblyTitle("Panel del PC")]
[assembly: AssemblyProduct("Panel del PC")]
[assembly: AssemblyDescription("Panel de control del PC en el celular")]
[assembly: AssemblyVersion("1.0.0.0")]

// Funciones de Windows que usa la ventana. ventana.ps1 también las compila con Add-Type si se abre sin este .exe.
public static class PanelNativo {
    [DllImport("dwmapi.dll")] static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
    [DllImport("user32.dll")] static extern bool AllowSetForegroundWindow(int processId);

    // Barra de título oscura (Windows 10 20H1 en adelante) y, en Windows 11, del mismo color que el fondo de la ventana.
    public static void BarraOscura(IntPtr hwnd, int fondoRgb, int bordeRgb) {
        int si = 1;
        if (DwmSetWindowAttribute(hwnd, 20, ref si, 4) != 0) DwmSetWindowAttribute(hwnd, 19, ref si, 4);
        int fondo = Bgr(fondoRgb), borde = Bgr(bordeRgb);
        DwmSetWindowAttribute(hwnd, 35, ref fondo, 4);
        DwmSetWindowAttribute(hwnd, 34, ref borde, 4);
    }

    // Deja que la ventana ya abierta pase al frente cuando se vuelve a pulsar el icono del panel.
    public static void PermitirPrimerPlano() { AllowSetForegroundWindow(-1); }

    static int Bgr(int rgb) { return ((rgb & 0xFF) << 16) | (rgb & 0xFF00) | ((rgb >> 16) & 0xFF); }
}

static partial class Lanzador {
    // Ejecutable portátil (lib\portatil.cs, que solo compila herramientas\portatil.ps1): deja el panel listo en su carpeta
    // y la devuelve en "carpeta" (o null si no se pudo). En el .exe normal no existe y esta llamada no hace nada.
    static partial void PrepararPortatil(ref string carpeta);

    [STAThread]
    static int Main(string[] args) {
        string carpeta = AppDomain.CurrentDomain.BaseDirectory;
        PrepararPortatil(ref carpeta);
        if (carpeta == null) return 1;
        string script = Path.Combine(carpeta, "ventana.ps1");
        if (!File.Exists(script)) {
            Error(T("No se encontró ventana.ps1 junto a este programa.\n\nVuelve a descomprimir el panel completo.",
                    "ventana.ps1 wasn't found next to this program.\n\nUnzip the full panel again."));
            return 1;
        }
        try {
            var estado = InitialSessionState.CreateDefault();
            estado.ExecutionPolicy = Microsoft.PowerShell.ExecutionPolicy.Bypass; // solo dentro de este proceso
            using (var rs = RunspaceFactory.CreateRunspace(estado)) {
                rs.ApartmentState = ApartmentState.STA;
                rs.ThreadOptions = PSThreadOptions.UseCurrentThread;
                rs.Open();
                using (var ps = PowerShell.Create()) {
                    ps.Runspace = rs;
                    ps.AddCommand(script);
                    // Solo se acepta -Puerto <número>. Lo demás (por ejemplo, el -Wifi que pasan los iconos de versiones
                    // anteriores) se ignora: el panel siempre funciona por Wi-Fi.
                    for (int i = 0; i < args.Length; i++) {
                        if (string.Equals(args[i], "-Puerto", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length) {
                            int puerto;
                            if (int.TryParse(args[++i], out puerto)) ps.AddParameter("Puerto", puerto);
                        }
                    }
                    ps.Invoke();
                }
            }
        } catch (Exception e) {
            Error(T("El panel no pudo abrirse:\n\n", "The panel couldn't open:\n\n") + e.Message);
            return 1;
        }
        return 0;
    }

    // Antes de abrir la ventana todavía no se sabe el idioma elegido: se usa el de Windows.
    static string T(string es, string en) {
        return System.Globalization.CultureInfo.CurrentUICulture.TwoLetterISOLanguageName == "en" ? en : es;
    }

    static void Error(string texto) {
        MessageBox.Show(texto, "Panel del PC", MessageBoxButtons.OK, MessageBoxIcon.Error);
    }
}
