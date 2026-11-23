// Ejecutable portátil del panel: un solo "Panel del PC.exe" que lleva dentro todo el panel y Node.js (recursos panel.zip
// y panel.version). Lo genera herramientas\portatil.ps1, que compila este archivo junto con lib\lanzador.cs.
//
// Al abrirlo:
// - La primera vez, o si la versión que lleva dentro es otra, descomprime el panel en %LOCALAPPDATA%\Panel del PC con un
//   aviso mientras tanto. Los archivos de cada PC (config.json, .token, data) no vienen en el .zip: nunca se pisan.
// - Se copia a esa carpeta y, si el menú Inicio no tiene ya un icono "Panel del PC" (por ejemplo, el de una instalación
//   con instalar.cmd), crea uno que apunta a esa copia.
// - Después abre la ventana desde esa carpeta, igual que el .exe normal.
// Para pruebas: la variable de entorno PANEL_PORTATIL_CARPETA cambia la carpeta y evita el icono del menú Inicio.
using System;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Threading;
using System.Windows.Forms;

static partial class Lanzador {
    static partial void PrepararPortatil(ref string carpeta) {
        Assembly yo = Assembly.GetExecutingAssembly();
        string version;
        using (Stream v = yo.GetManifestResourceStream("panel.version")) {
            if (v == null) return; // no lleva el panel dentro: es el .exe normal
            using (var r = new StreamReader(v)) version = r.ReadToEnd().Trim();
        }
        string prueba = Environment.GetEnvironmentVariable("PANEL_PORTATIL_CARPETA");
        bool esPrueba = !string.IsNullOrEmpty(prueba);
        string destino = esPrueba ? Path.GetFullPath(prueba)
            : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Panel del PC");
        try {
            Directory.CreateDirectory(destino);
            string marca = Path.Combine(destino, "version.txt");
            // Si se abre dos veces seguidas, la segunda espera a que la primera termine de descomprimir.
            using (var m = new Mutex(false, @"Local\PanelDelPC-preparando")) {
                try { m.WaitOne(); } catch (AbandonedMutexException) { }
                try {
                    bool alDia = File.Exists(marca) && File.ReadAllText(marca).Trim() == version
                        && File.Exists(Path.Combine(destino, "ventana.ps1"));
                    if (!alDia) {
                        if (EnUso(Path.Combine(destino, @"node\node.exe"))) {
                            Error(T("Hay otra versión del panel abierta. Ciérrala con «Detener el panel» y vuelve a abrir este programa.",
                                    "Another version of the panel is open. Close it with \"Stop the panel\" and open this program again."));
                            carpeta = null;
                            return;
                        }
                        ConAviso(delegate { Descomprimir(yo, destino); });
                        File.WriteAllText(marca, version);
                    }
                    Copiarse(yo, destino, alDia);
                    if (!esPrueba) CrearIcono(destino);
                } finally { m.ReleaseMutex(); }
            }
            carpeta = destino;
        } catch (Exception e) {
            Error(T("No se pudo preparar el panel en ", "Couldn't set up the panel in ") + destino + ":\n\n" + e.Message);
            carpeta = null;
        }
    }

    // ¿Está abierto ese programa? (un .exe en marcha no se puede abrir para escribir)
    static bool EnUso(string archivo) {
        if (!File.Exists(archivo)) return false;
        try { using (File.Open(archivo, FileMode.Open, FileAccess.ReadWrite, FileShare.None)) { } return false; }
        catch (IOException) { return true; }
        catch (UnauthorizedAccessException) { return false; }
    }

    static void Descomprimir(Assembly yo, string destino) {
        string raiz = Path.GetFullPath(destino).TrimEnd('\\') + "\\";
        using (Stream s = yo.GetManifestResourceStream("panel.zip"))
        using (var zip = new ZipArchive(s, ZipArchiveMode.Read)) {
            foreach (ZipArchiveEntry e in zip.Entries) {
                string ruta = Path.GetFullPath(Path.Combine(raiz, e.FullName));
                if (!ruta.StartsWith(raiz, StringComparison.OrdinalIgnoreCase)) continue; // nunca fuera de la carpeta
                if (e.FullName.EndsWith("/")) { Directory.CreateDirectory(ruta); continue; }
                Directory.CreateDirectory(Path.GetDirectoryName(ruta));
                e.ExtractToFile(ruta, true);
            }
        }
    }

    // Una ventanita "Preparando…" mientras se descomprime (tarda unos segundos: Node.js ocupa casi 90 MB).
    static void ConAviso(Action trabajo) {
        Exception fallo = null;
        using (var f = new Form()) {
            f.Text = "Panel del PC";
            f.FormBorderStyle = FormBorderStyle.FixedSingle; f.ControlBox = false;
            f.StartPosition = FormStartPosition.CenterScreen; f.ClientSize = new Size(400, 110);
            f.BackColor = Color.FromArgb(0x10, 0x14, 0x1A);
            try { f.Icon = Icon.ExtractAssociatedIcon(Assembly.GetExecutingAssembly().Location); } catch { }
            var texto = new Label();
            texto.Dock = DockStyle.Fill; texto.TextAlign = ContentAlignment.MiddleCenter;
            texto.ForeColor = Color.FromArgb(0xEE, 0xF1, 0xF6); texto.Font = new Font("Segoe UI", 10.5f);
            texto.Text = T("Preparando el Panel del PC…\nTarda unos segundos.", "Getting Panel del PC ready…\nIt takes a few seconds.");
            f.Controls.Add(texto);
            f.HandleCreated += delegate { try { PanelNativo.BarraOscura(f.Handle, 0x10141A, 0x1B2029); } catch { } };
            f.Shown += delegate {
                var hilo = new Thread(delegate () {
                    try { trabajo(); } catch (Exception x) { fallo = x; }
                    try { f.BeginInvoke((Action)f.Close); } catch { }
                });
                hilo.IsBackground = true;
                hilo.Start();
            };
            Application.Run(f);
        }
        if (fallo != null) throw fallo;
    }

    // Copia de este .exe en la carpeta del panel: es a la que apunta el icono del menú Inicio, así que el .exe que se
    // compartió se puede borrar (o dejar en Descargas) sin que el icono deje de funcionar.
    static void Copiarse(Assembly yo, string destino, bool alDia) {
        string original = Path.GetFullPath(yo.Location);
        string copia = Path.Combine(destino, "Panel del PC.exe");
        if (string.Equals(original, Path.GetFullPath(copia), StringComparison.OrdinalIgnoreCase)) return;
        if (alDia && File.Exists(copia)) return;
        try { File.Copy(original, copia, true); } catch { } // si esa copia está abierta, se queda la que hay
    }

    static void CrearIcono(string destino) {
        try {
            string lnk = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "Panel del PC.lnk");
            if (File.Exists(lnk)) return; // ya hay uno: no se toca
            string exe = Path.Combine(destino, "Panel del PC.exe");
            Type tipo = Type.GetTypeFromProgID("WScript.Shell");
            object shell = Activator.CreateInstance(tipo);
            object acceso = tipo.InvokeMember("CreateShortcut", BindingFlags.InvokeMethod, null, shell, new object[] { lnk });
            Type t = acceso.GetType();
            t.InvokeMember("TargetPath", BindingFlags.SetProperty, null, acceso, new object[] { exe });
            t.InvokeMember("WorkingDirectory", BindingFlags.SetProperty, null, acceso, new object[] { destino });
            t.InvokeMember("IconLocation", BindingFlags.SetProperty, null, acceso, new object[] { exe + ",0" });
            t.InvokeMember("Description", BindingFlags.SetProperty, null, acceso, new object[] { "Panel del PC" });
            t.InvokeMember("Save", BindingFlags.InvokeMethod, null, acceso, null);
        } catch { } // sin icono, el panel funciona igual
    }
}
