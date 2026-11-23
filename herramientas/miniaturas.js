// Genera las miniaturas de las páginas del celular que muestra la ventana del panel en "Selección de widgets", en
// español (public/miniaturas/<página>.jpg) y en inglés (public/miniaturas/en/<página>.jpg). Vuelve a ejecutarlo cuando
// cambie el diseño de alguna página.
//
// Sirve la página del celular desde aquí mismo y responde a todo con datos de ejemplo y con config.ejemplo.json:
// no usa el servidor del panel, ni tu config.json, ni lo que pasa en este PC.
// Necesita Node.js 22 o superior (por WebSocket) y Microsoft Edge.
//
// Uso:  node herramientas/miniaturas.js [iconos.json]
//   iconos.json (opcional): { "discord": "data:image/png;base64,…", … } para los iconos del mezclador.
const fs = require('fs');
const path = require('path');
const http = require('http');
const { spawn, execFileSync } = require('child_process');
const os = require('os');

const ROOT = path.join(__dirname, '..');
const PUBLIC = path.join(ROOT, 'public');
const SALIDA = path.join(PUBLIC, 'miniaturas');
let IDIOMA = 'es'; // el de la tanda que se está generando
const en = () => IDIOMA === 'en';
const ICONOS = process.argv[2] ? JSON.parse(fs.readFileSync(process.argv[2], 'utf8')) : {};
const EDGE = ['C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', 'C:/Program Files/Microsoft/Edge/Application/msedge.exe'].find((p) => fs.existsSync(p));
const PAGINAS = ['inicio', 'mezclador', 'sistema', 'rendimiento', 'procesos', 'enfoque', 'calendario', 'discord', 'comandos'];
const ANCHO = 848, ALTO = 392, ESCALA = 0.75; // celular en horizontal; la imagen sale de 636 × 294
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ---------- Datos de ejemplo
const cfg = JSON.parse(fs.readFileSync(path.join(ROOT, 'config.ejemplo.json'), 'utf8').replace(/^\uFEFF/, ''));
const config = {
  title: cfg.title || 'Panel',
  relojes: cfg.relojes || [],
  pomodoro: cfg.pomodoro || null,
  groups: (cfg.groups || []).map((g) => ({
    name: g.name, place: g.place || 'atajos',
    items: (g.items || []).map(({ id, label, icon, color, type, confirm, hint }) => ({ id, label, icon, color, type, hint, confirm: !!confirm })),
  })),
};
const GB = 1024 ** 3;
let n = 0;
function stats() {
  const t = ++n / 7, ola = (a, f, d = 0) => a * Math.sin(t * f + d);
  const cpu = Math.max(3, 22 + ola(9, 1) + ola(6, 2.6, 1) + Math.random() * 5);
  return {
    host: 'MI-PC', uptime: 3 * 3600 + 42 * 60,
    cpu: { percent: cpu, cores: 16, model: 'AMD Ryzen 7 5800X 8-Core Processor',
      perCore: Array.from({ length: 16 }, (_, i) => Math.round(Math.max(1, Math.min(100, cpu + ola(22, 1.3, i * 1.7) + (i % 5) * 4)))) },
    procs: {
      total: 214,
      byCpu: [['chrome', 24, 6.4], ['Discord', 6, 3.1], ['Code', 9, 2.7], ['Spotify', 5, 1.9], ['explorer', 1, 1.2], ['dwm', 1, 0.9], ['node', 2, 0.6], ['steam', 3, 0.4]]
        .map(([name, count, c]) => ({ name, count, cpu: Math.max(0.05, c + ola(c / 3, 1.9)), mem: 0 })),
      byMem: [['chrome', 24, 3.1], ['Code', 9, 1.4], ['Discord', 6, 0.9], ['Spotify', 5, 0.6], ['steam', 3, 0.5], ['explorer', 1, 0.3], ['node', 2, 0.25], ['dwm', 1, 0.2]]
        .map(([name, count, g]) => ({ name, count, cpu: 0, mem: g * GB })),
    },
    apps: { discord: true },
    mem: { total: 16 * GB, free: 16 * GB * (0.46 + ola(0.03, 0.4)) },
    disks: [{ name: 'C:', total: 1000e9, free: 412e9 }, { name: 'D:', total: 2000e9, free: 1320e9 }],
    net: { rxBps: Math.max(0, 900e3 + ola(700e3, 1.7) + Math.random() * 300e3), txBps: Math.max(0, 120e3 + ola(90e3, 2.3)) },
    media: { app: 'Spotify.exe', title: en() ? 'City lights' : 'Luces de la ciudad', artist: en() ? 'Sample band' : 'Banda de ejemplo', status: 'playing', position: 74, duration: 213, artKey: null },
    volume: { level: 64, muted: false },
    artKey: null,
    paginas: PAGINAS,
    idioma: IDIOMA,
    time: Date.now(),
  };
}
const hoy = new Date();
const dia = (i) => new Date(hoy.getTime() + i * 86400e3).toISOString().slice(0, 10);
const RESPUESTAS = {
  '/api/config': () => config,
  '/api/stats': stats,
  '/api/tasks': () => (en() ? ['Send the weekly report', 'Review the project to-dos', 'Call tech support', 'Buy coffee']
    : ['Enviar el informe semanal', 'Revisar los pendientes del proyecto', 'Llamar a soporte técnico', 'Comprar café'])
    .map((text, i) => ({ id: String(i + 1), text, done: i === 0 })),
  '/api/weather': () => ({ activo: true, ciudad: 'Madrid', now: { temp: 18, feels: 17, hum: 62, code: 2, wind: 9, day: true },
    days: [2, 3, 61, 1, 0].map((code, i) => ({ date: dia(i), code, max: 19 + i, min: 9 + (i % 3), rain: 10 })) }),
  // Días con algo agendado (el punto bajo el número en la página Calendario)
  '/api/agenda': () => ({ conectado: true, nombre: en() ? 'My calendar' : 'Mi calendario',
    eventos: [-6, -2, 0, 1, 3, 8, 12].map((d, i) => ({ titulo: `${i}`, lugar: '', dia: dia(d), dias: 1 })) }),
  '/api/art': () => ({ key: null, data: null }),
  '/api/mixer': () => {
    const s = (k) => `{0.0.0.00000000}.{0000000${k}-0000-0000-0000-000000000000}`;
    return {
      dispositivo: en() ? 'Speakers (Realtek(R) Audio)' : 'Altavoces (Realtek(R) Audio)', salida: s(1),
      salidas: [{ id: s(1), nombre: en() ? 'Speakers (Realtek(R) Audio)' : 'Altavoces (Realtek(R) Audio)', tipo: 'altavoces' },
        { id: s(2), nombre: en() ? 'Headphones (Bluetooth)' : 'Audífonos (Bluetooth)', tipo: 'audifonos' }],
      general: { nivel: 64, silencio: false, pico: 0.62 },
      apps: [
        { clave: 'discord', nombre: 'Discord', nivel: 72, silencio: false, pico: 0.34, activa: true, sistema: false, icono: !!ICONOS.discord },
        { clave: 'edge', nombre: 'Microsoft Edge', nivel: 100, silencio: false, pico: 0, activa: false, sistema: false, icono: !!ICONOS.edge },
        { clave: 'steam', nombre: 'Steam', nivel: 40, silencio: true, pico: 0, activa: false, sistema: false, icono: !!ICONOS.steam },
        { clave: 'vlc', nombre: 'VLC media player', nivel: 86, silencio: false, pico: 0.74, activa: true, sistema: false, icono: !!ICONOS.vlc },
        { clave: 'sistema', nombre: en() ? 'System sounds' : 'Sonidos del sistema', nivel: 100, silencio: false, pico: 0, activa: false, sistema: true },
      ],
    };
  },
};
const TIPOS = { '.html': 'text/html; charset=utf-8', '.png': 'image/png', '.jpg': 'image/jpeg', '.webmanifest': 'application/manifest+json', '.js': 'text/javascript' };

const servidor = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://x');
  if (url.pathname.startsWith('/api/')) {
    const r = url.pathname === '/api/mixer/icono' ? { data: ICONOS[url.searchParams.get('k')] || null }
      : RESPUESTAS[url.pathname] && req.method === 'GET' ? RESPUESTAS[url.pathname]() : { ok: true };
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify(r));
  }
  const archivo = path.join(PUBLIC, url.pathname === '/' ? 'index.html' : path.normalize(url.pathname).replace(/^[\\/]+/, ''));
  if (!archivo.startsWith(PUBLIC) || !fs.existsSync(archivo)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': TIPOS[path.extname(archivo)] || 'application/octet-stream' });
  fs.createReadStream(archivo).pipe(res);
});

// ---------- Edge sin ventana, manejado por el protocolo de depuración (CDP)
function cdp(wsUrl) {
  const ws = new WebSocket(wsUrl);
  let id = 0; const pendientes = new Map();
  ws.onmessage = (m) => { const d = JSON.parse(m.data); const p = pendientes.get(d.id); if (p) { pendientes.delete(d.id); d.error ? p.rej(new Error(d.error.message)) : p.res(d.result); } };
  const listo = new Promise((r, j) => { ws.onopen = r; ws.onerror = j; });
  const send = (method, params = {}) => new Promise((res, rej) => { const i = ++id; pendientes.set(i, { res, rej }); ws.send(JSON.stringify({ id: i, method, params })); });
  return { listo, send, close: () => ws.close() };
}
async function esperar(url, ms = 20000) {
  const fin = Date.now() + ms;
  while (Date.now() < fin) { try { return await fetch(url, { signal: AbortSignal.timeout(1500) }); } catch { await sleep(300); } }
  throw new Error('no respondió: ' + url);
}

(async () => {
  if (!EDGE) throw new Error('No se encontró Microsoft Edge.');
  await new Promise((r) => servidor.listen(0, '127.0.0.1', r));
  const puerto = servidor.address().port, depuracion = 9300 + Math.floor(Math.random() * 500);
  const perfil = fs.mkdtempSync(path.join(os.tmpdir(), 'panel-miniaturas-'));
  const edge = spawn(EDGE, ['--headless=new', `--remote-debugging-port=${depuracion}`, `--user-data-dir=${perfil}`, '--no-first-run', '--disable-extensions', '--hide-scrollbars', 'about:blank'], { stdio: 'ignore' });
  try {
    await esperar(`http://127.0.0.1:${depuracion}/json/version`);
    const pagina = (await (await fetch(`http://127.0.0.1:${depuracion}/json/list`)).json()).find((t) => t.type === 'page');
    const c = cdp(pagina.webSocketDebuggerUrl);
    await c.listo;
    await c.send('Page.enable');
    // La página pide el estado cada 1,5 s; aquí, cada 50 ms, para llenar en segundos las gráficas de 3 minutos.
    await c.send('Page.addScriptToEvaluateOnNewDocument', { source: 'const _si = window.setInterval; window.setInterval = (f, ms, ...a) => _si(f, ms === 1500 ? 50 : ms, ...a);' });
    await c.send('Emulation.setDeviceMetricsOverride', { width: ANCHO, height: ALTO, deviceScaleFactor: 1, mobile: true });
    for (const idioma of ['es', 'en']) {
      IDIOMA = idioma;
      const carpeta = idioma === 'es' ? SALIDA : path.join(SALIDA, idioma);
      fs.mkdirSync(carpeta, { recursive: true });
      // El celular toma el idioma del estado (stats.idioma); se guarda también para que empiece ya en ese idioma.
      await c.send('Page.navigate', { url: `http://127.0.0.1:${puerto}/#t=ejemplo` });
      await sleep(1500);
      await c.send('Runtime.evaluate', { expression: `localStorage.setItem('panelLang', '${idioma}'); location.reload()` });
      await sleep(9000);
      for (const [i, id] of PAGINAS.entries()) {
        await c.send('Runtime.evaluate', { expression: `document.getElementById('pages').scrollLeft = ${i} * document.getElementById('pages').clientWidth` });
        await sleep(1200);
        const r = await c.send('Page.captureScreenshot', { format: 'jpeg', quality: 82, clip: { x: 0, y: 0, width: ANCHO, height: ALTO, scale: ESCALA } });
        const destino = path.join(carpeta, `${id}.jpg`);
        fs.writeFileSync(destino, Buffer.from(r.data, 'base64'));
        console.log(`${path.relative(SALIDA, destino)}  ${Math.round(fs.statSync(destino).size / 1024)} KB`);
      }
    }
    try { await c.send('Browser.close'); } catch {}
    c.close();
  } finally {
    try { execFileSync('taskkill', ['/PID', String(edge.pid), '/T', '/F'], { stdio: 'ignore' }); } catch {}
    servidor.close();
    await sleep(800);
    try { fs.rmSync(perfil, { recursive: true, force: true }); } catch {}
  }
})().catch((e) => { console.error(e.message); process.exit(1); });
