// Orbital — servidor local sin dependencias.
// Escucha en 127.0.0.1 (para abrirlo en este PC) y en la IP de la red local (PANEL_LAN_IP), por donde entra el celular.
// Sin PANEL_LAN_IP solo responde a este PC (iniciar.ps1 -SoloPC y las pruebas).
'use strict';

const http = require('http');
const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');
const { spawn } = require('child_process');

const PORT = Number(process.env.PANEL_PORT) || 8787;
const TOKEN = process.env.PANEL_TOKEN || crypto.randomBytes(16).toString('hex');
const ROOT = __dirname;
const CONFIG_PATH = path.join(ROOT, 'config.json');

// ---------- Configuración (se relee en cada petición para editar sin reiniciar)
// Primera vez (por ejemplo, al recibir el panel en un .zip): se crea config.json a partir del ejemplo.
if (!fs.existsSync(CONFIG_PATH) && fs.existsSync(path.join(ROOT, 'config.ejemplo.json'))) {
  fs.copyFileSync(path.join(ROOT, 'config.ejemplo.json'), CONFIG_PATH);
}
function loadConfig() {
  return JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8').replace(/^﻿/, ''));
}
// Cambia (o añade) una sección de una sola línea de config.json, como "clima": { … }, sin tocar el formato del resto.
function guardarEnConfig(clave, valor) {
  let txt = fs.readFileSync(CONFIG_PATH, 'utf8').replace(/^﻿/, '');
  const eol = txt.includes('\r\n') ? '\r\n' : '\n';
  const linea = '{ ' + Object.entries(valor).map(([k, v]) => `${JSON.stringify(k)}: ${JSON.stringify(v)}`).join(', ') + ' }';
  const seccion = (k) => new RegExp(`("${k}"\\s*:\\s*)\\{[^{}]*\\}`);
  if (seccion(clave).test(txt)) txt = txt.replace(seccion(clave), (m, inicio) => inicio + linea);
  else if (seccion('clima').test(txt)) txt = txt.replace(seccion('clima'), (m) => `${m},${eol}  ${JSON.stringify(clave)}: ${linea}`);
  else txt = txt.replace(/^\s*\{/, (m) => `${m}${eol}  ${JSON.stringify(clave)}: ${linea},`);
  let cfg;
  try { cfg = JSON.parse(txt); } catch { cfg = null; }
  if (!cfg || JSON.stringify(cfg[clave]) !== JSON.stringify(valor)) { // formato inesperado: se reescribe entero
    cfg = loadConfig(); cfg[clave] = valor; txt = JSON.stringify(cfg, null, 2) + eol;
  }
  fs.writeFileSync(CONFIG_PATH, txt);
}
function findAction(id) {
  const cfg = loadConfig();
  for (const group of cfg.groups || []) {
    for (const item of group.items || []) if (item.id === id) return item;
  }
  return null;
}
// ---------- Idioma de los mensajes (español o inglés). Lo elige la ventana del panel, que lo guarda en
// data/preferencias.json; el celular lo recibe con cada lectura del estado. Si nunca se eligió, se usa el del sistema.
const PREFS_PATH = path.join(ROOT, 'data', 'preferencias.json');
function leerIdioma() {
  try {
    const p = JSON.parse(fs.readFileSync(PREFS_PATH, 'utf8').replace(/^\uFEFF/, ''));
    if (p.idioma === 'es' || p.idioma === 'en') return p.idioma;
  } catch {}
  return /^en\b/i.test(Intl.DateTimeFormat().resolvedOptions().locale) ? 'en' : 'es';
}
let idioma = leerIdioma();
const EN = {
  'Conexión rechazada desde {0}. Si es tu celular, escanea el código QR del panel para pedir acceso.': "Connection refused from {0}. If it's your phone, scan the panel's QR code to ask for access.",
  'Dispositivo quitado: {0}. Si vuelve a escanear el código, el PC te preguntará otra vez.': 'Device removed: {0}. If it scans the code again, this PC will ask you again.',
  '{0}: falló (código {1})': '{0}: failed (code {1})',
  '{0} ({1}) pide acceso: responde el aviso que apareció en el PC.': '{0} ({1}) is asking for access: answer the prompt that appeared on this PC.',
  'Dispositivo autorizado: {0}. Quedó guardado en config.json.': 'Device authorized: {0}. It was saved in config.json.',
  'No se pudo guardar {0} en config.json: {1}': "Couldn't save {0} in config.json: {1}",
  'Dispositivo rechazado: {0}. No se volverá a preguntar hasta reiniciar el panel.': "Device rejected: {0}. You won't be asked again until the panel restarts.",
  'Un dispositivo quiere usar el panel por Wi-Fi.': 'A device wants to use the panel over Wi-Fi.',
  'Equipo: {0}': 'Device: {0}',
  '¿Permitir este dispositivo?': 'Allow this device?',
  'Acepta solo si es tu celular y acabas de escanear el código QR del panel.': "Accept only if it's your phone and you just scanned the panel's QR code.",
  'Orbital: dispositivo nuevo': 'Orbital: new device',
  'token inválido': 'invalid token',
  'host no permitido': 'host not allowed',
  'solo desde este PC': 'only from this PC',
  'idioma inválido': 'invalid language',
  'tiene que quedar al menos una página': 'at least one page has to stay',
  'lista de tareas inválida': 'invalid task list',
  'la ubicación de Windows está desactivada. Actívala en Configuración > Privacidad y seguridad > Ubicación, también para las aplicaciones de escritorio.':
    'Windows location is turned off. Turn it on in Settings > Privacy & security > Location, also for desktop apps.',
  'Windows todavía no sabe dónde está este PC. Prueba otra vez en un momento.': "Windows doesn't know where this PC is yet. Try again in a moment.",
  'no se pudo preguntar la ubicación a Windows': "couldn't ask Windows for the location",
  'Ese enlace no sirve: tiene que empezar por https:// (la dirección secreta en formato iCal de tu calendario).':
    "That link won't work: it has to start with https:// (your calendar's secret address in iCal format).",
  'No se pudo leer el calendario: {0}': "Couldn't read the calendar: {0}",
  'tiempo agotado': 'timed out', 'sin conexión': 'no connection', 'enlace no válido': 'invalid link', 'no es un calendario': "it isn't a calendar",
  'fechas inválidas': 'invalid dates',
  'cada atajo necesita un nombre': 'every shortcut needs a name', 'tipo de atajo inválido: {0}': 'invalid shortcut type: {0}',
  'a «{0}» le falta {1}': '"{0}" is missing {1}', 'qué abrir': 'what to open', 'el atajo de teclado': 'the keyboard shortcut',
  'el comando': 'the command', 'como mucho {0} atajos': 'at most {0} shortcuts',
  'falta level o muted': 'level or muted is missing',
  'el mezclador no está disponible': "the mixer isn't available",
  'salida inválida': 'invalid output',
  'el PC no respondió': "the PC didn't respond",
  'esa salida ya no está conectada': "that output isn't connected anymore",
  'aplicación inválida': 'invalid app',
  'falta nivel o silencio': 'nivel or silencio is missing',
  'acción no encontrada': 'action not found',
  'no encontrado': 'not found',
  'prohibido': 'forbidden',
};
// Traduce un mensaje escrito en español y rellena {0}, {1}… con los datos.
function tr(texto, ...datos) {
  let t = (idioma === 'en' && EN[texto]) || texto;
  datos.forEach((d, i) => { t = t.split(`{${i}}`).join(String(d)); });
  return t;
}
// Los errores del mezclador llegan en español desde lib/mezclador.ps1.
function trMezclador(e) {
  if (idioma !== 'en') return e;
  return tr(e).replace(/^Windows no dejó cambiar la salida/, "Windows wouldn't switch the output").replace(/^no se pudo cambiar la salida:/, "couldn't switch the output:");
}

// Lo que se envía al celular: sin los comandos en sí.
function publicConfig() {
  const cfg = loadConfig();
  return {
    // «Panel del PC» era el nombre de antes: los config.json que lo tengan muestran el nombre nuevo.
    title: cfg.title && cfg.title !== 'Panel del PC' ? cfg.title : 'Orbital',
    relojes: (cfg.relojes || []).slice(0, 6).map((r) => ({ nombre: String(r.nombre || ''), zona: String(r.zona || '') })),
    pomodoro: cfg.pomodoro || null,
    groups: (cfg.groups || []).map((g) => ({
      name: g.name,
      place: g.place || 'atajos',
      items: (g.items || []).map(({ id, label, icon, color, type, confirm, hint }) => ({ id, label, icon, color, type, hint, confirm: !!confirm })),
    })),
  };
}

// ---------- Actividad reciente: sale en la consola y la muestra la ventana del panel en el PC
const actividad = [];
function evento(tipo, msg) {
  const t = Date.now();
  actividad.push({ t, tipo, msg });
  if (actividad.length > 30) actividad.shift();
  console.log(`[${new Date(t).toLocaleTimeString()}] ${msg}`);
}

// Si la ventana del panel se cierra de golpe (por ejemplo, desde el Administrador de tareas), el servidor también se cierra.
const PADRE = Number(process.env.PANEL_PADRE) || 0;
if (PADRE) {
  setInterval(() => {
    try { process.kill(PADRE, 0); } catch (e) { if (e.code === 'ESRCH') process.exit(0); }
  }, 3000).unref();
}

// ---------- Ejecución de acciones
function runPowerShell(script, { cwd, timeoutMs = 60000 } = {}) {
  return new Promise((resolve) => {
    const child = spawn('powershell.exe', ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', script], {
      cwd: cwd || os.homedir(),
      windowsHide: true,
    });
    let out = '';
    let err = '';
    const cap = (s, chunk) => (s.length < 20000 ? s + chunk.toString() : s);
    child.stdout.on('data', (d) => (out = cap(out, d)));
    child.stderr.on('data', (d) => (err = cap(err, d)));
    const timer = setTimeout(() => {
      child.kill();
      err += '\n[tiempo agotado]';
    }, timeoutMs);
    child.on('close', (code) => {
      clearTimeout(timer);
      resolve({ code, stdout: out.trim(), stderr: err.trim() });
    });
    child.on('error', (e) => {
      clearTimeout(timer);
      resolve({ code: -1, stdout: '', stderr: String(e) });
    });
  });
}

const psQuote = (s) => "'" + String(s).replace(/'/g, "''") + "'";

// Controles de música y volumen (lib/media.ps1 → Invoke-PanelMedia): van directo a la sesión multimedia de Windows
// o, si no hay, se pulsa la tecla multimedia. Normalmente los hace el proceso permanente de control, al instante.
const MEDIA = new Set(['mute', 'voldown', 'volup', 'next', 'prev', 'stop', 'playpause']);
const mediaTimes = (action) => Math.min(Math.max(Number(action.repeat) || 1, 1), 20);

function scriptFor(action) {
  switch (action.type) {
    case 'open': {
      const args = action.args ? ` -ArgumentList ${psQuote(action.args)}` : '';
      return `Start-Process ([Environment]::ExpandEnvironmentVariables(${psQuote(action.target)}))${args}`;
    }
    case 'media':
      if (!MEDIA.has(action.key)) throw new Error(`Tecla multimedia desconocida: ${action.key}`);
      return `. ${psQuote(path.join(ROOT, 'lib', 'media.ps1'))}; 1..${mediaTimes(action)} | ForEach-Object { [void](Invoke-PanelMedia ${psQuote(action.key)}) }`;
    case 'keys':
      // Pulsación con scan code (lib/keys.ps1): Discord ignora SendKeys cuando su ventana está al frente.
      return `. ${psQuote(path.join(ROOT, 'lib', 'keys.ps1'))}; Send-PanelKeys ${psQuote(action.keys)}`;
    case 'command':
      return action.command;
    default:
      throw new Error(`Tipo de acción desconocido: ${action.type}`);
  }
}

// ---------- Monitor del sistema
let lastCpu = os.cpus();
let cpuPercent = 0;
let corePercents = [];
setInterval(() => {
  const now = os.cpus();
  let idle = 0;
  let total = 0;
  corePercents = now.map((c, i) => {
    const p = lastCpu[i].times;
    const t = c.times;
    const dTotal = t.user + t.nice + t.sys + t.idle + t.irq - (p.user + p.nice + p.sys + p.idle + p.irq);
    const dIdle = t.idle - p.idle;
    idle += dIdle;
    total += dTotal;
    return dTotal > 0 ? Math.round((1 - dIdle / dTotal) * 100) : 0;
  });
  cpuPercent = total > 0 ? Math.round((1 - idle / total) * 1000) / 10 : 0;
  lastCpu = now;
}, 1000).unref();

// Disco y red con un único proceso de PowerShell que emite una línea JSON cada 2 s.
let extra = { disks: [], net: { rxBps: 0, txBps: 0 }, media: null, volume: null };
let art = { key: null, data: null };
const PS_PRELUDE = `[Console]::OutputEncoding = [Text.Encoding]::UTF8; [Console]::InputEncoding = [Text.Encoding]::UTF8
. ${"'" + path.join(ROOT, 'lib', 'media.ps1').replace(/'/g, "''") + "'"}
`;

// Proceso permanente para cambiar el volumen al instante (sin recompilar en cada pulsación).
// Recibe una orden por línea. Solo "mixer" (el estado del mezclador) y "salida" (cambiar la salida de audio) responden,
// con exactamente una línea JSON; las demás no escriben nada, así que las respuestas llegan en el mismo orden en que se pidieron.
let ctl = null;
let ctlBuffer = '';
const ctlEspera = []; // funciones que esperan la respuesta de cada orden pendiente que responde
function startControlWorker() {
  const script = `
try { . ${psQuote(path.join(ROOT, 'lib', 'mezclador.ps1'))} } catch { }
while (Get-Process -Id ${process.pid} -ErrorAction SilentlyContinue) {
  $line = [Console]::In.ReadLine(); if ($null -eq $line) { break }
  $p = $line.Split(' ', 3)
  if ($p[0] -eq 'mixer' -or $p[0] -eq 'salida') {
    try {
      if ($p[0] -eq 'mixer') { $j = [PanelMx.Mezclador]::Estado([int][math]::Round([PanelAudio]::Volume * 100), [PanelAudio]::Mute) }
      else { $j = [PanelMx.Mezclador]::CambiarSalida($p[1]) }
    } catch { $j = '{"error":"el mezclador no esta disponible"}' }
    [Console]::Out.WriteLine($j); [Console]::Out.Flush(); continue
  }
  try {
    switch ($p[0]) {
      'vol'  { [PanelAudio]::Mute = $false; [PanelAudio]::Volume = [float]([math]::Min([math]::Max([int]$p[1], 0), 100) / 100) }
      'mute' { [PanelAudio]::Mute = ($p[1] -eq '1') }
      'media' { $n = [math]::Min([math]::Max([int]$p[2], 1), 20); for ($i = 0; $i -lt $n; $i++) { [void](Invoke-PanelMedia $p[1]) } }
      'appvol' { [void][PanelMx.Mezclador]::Volumen($p[2], [int]$p[1]) }
      'appmute' { [void][PanelMx.Mezclador]::Silenciar($p[2], ($p[1] -eq '1')) }
    }
  } catch { }
}`;
  ctl = spawn('powershell.exe', ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', PS_PRELUDE + script], { windowsHide: true });
  ctl.stdout.setEncoding('utf8');
  ctl.stdout.on('data', (d) => {
    ctlBuffer += d;
    let i;
    while ((i = ctlBuffer.indexOf('\n')) >= 0) {
      const line = ctlBuffer.slice(0, i).trim();
      ctlBuffer = ctlBuffer.slice(i + 1);
      if (line) { const responder = ctlEspera.shift(); if (responder) responder(line); }
    }
  });
  ctl.on('exit', () => {
    ctl = null; ctlBuffer = '';
    ctlEspera.splice(0).forEach((responder) => responder(null));
    setTimeout(startControlWorker, 3000);
  });
  process.on('exit', () => ctl && ctl.kill());
}
startControlWorker();
function control(cmd) {
  if (!ctl || !ctl.stdin.writable) return false;
  ctl.stdin.write(cmd + '\n');
  return true;
}

// Manda una orden que responde ("mixer" o "salida") y espera su línea JSON; null si no responde a tiempo.
function preguntar(cmd, ms = 3000) {
  return new Promise((resolve) => {
    let hecho = false;
    const fin = (v) => { if (!hecho) { hecho = true; resolve(v); } };
    // Aunque se agote el tiempo, la función sigue en la cola y se queda con su línea: así no se desordenan las respuestas.
    ctlEspera.push((line) => { try { fin(line ? JSON.parse(line) : null); } catch { fin(null); } });
    if (!control(cmd)) { ctlEspera.pop(); fin(null); return; }
    setTimeout(() => fin(null), ms);
  });
}

// ---------- Mezclador de volumen (lib/mezclador.ps1): volumen, silencio y nivel de cada aplicación, y salida de audio
const iconosMezclador = new Map(); // ruta del programa → icono (data URL); el proceso de control lo manda una sola vez
let mezcladorEnCurso = null;       // si varias peticiones llegan a la vez, comparten la misma lectura
function pedirMezclador() {
  if (mezcladorEnCurso) return mezcladorEnCurso;
  mezcladorEnCurso = preguntar('mixer').then((m) => {
    mezcladorEnCurso = null;
    if (m && Array.isArray(m.apps)) {
      for (const a of m.apps) {
        if (a.icono) iconosMezclador.set(a.clave, a.icono);
        a.icono = iconosMezclador.has(a.clave);
      }
    }
    return m;
  });
  return mezcladorEnCurso;
}

function startStatsWorker() {
  const script = `
$ErrorActionPreference = 'SilentlyContinue'
$prev = $null; $prevT = $null
$procPrev = @{}; $procT = $null; $cores = [Environment]::ProcessorCount
function Get-TopProcesses {
  $now = [DateTime]::UtcNow; $dt = if ($script:procT) { ($now - $script:procT).TotalSeconds } else { 0 }
  $cur = @{}; $groups = @{}
  foreach ($p in Get-Process) {
    $c = $null; try { $c = $p.TotalProcessorTime.TotalSeconds } catch { }
    $pct = 0
    if ($null -ne $c) { $cur[$p.Id] = $c; if ($dt -gt 0 -and $script:procPrev.ContainsKey($p.Id)) { $pct = [math]::Max(0, ($c - $script:procPrev[$p.Id]) / $dt / $cores * 100) } }
    $g = $groups[$p.ProcessName]
    if (-not $g) { $g = @{ name = $p.ProcessName; count = 0; cpu = 0.0; mem = 0.0 }; $groups[$p.ProcessName] = $g }
    $g.count++; $g.cpu += $pct; $g.mem += [double]$p.WorkingSet64
  }
  $script:procPrev = $cur; $script:procT = $now
  $list = $groups.Values | Where-Object { $_.name -ne 'Idle' }
  foreach ($g in $list) { $g.cpu = [math]::Round($g.cpu, 2) }
  @{ byCpu = @($list | Sort-Object { $_.cpu } -Descending | Select-Object -First 10); byMem = @($list | Sort-Object { $_.mem } -Descending | Select-Object -First 10); total = (@($list) | Measure-Object -Property count -Sum).Sum }
}
while (Get-Process -Id ${process.pid} -ErrorAction SilentlyContinue) {
  $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    @{ name = $_.DeviceID; total = [double]$_.Size; free = [double]$_.FreeSpace } }
  $s = Get-NetAdapterStatistics | Measure-Object -Property ReceivedBytes, SentBytes -Sum
  $rx = [double]$s[0].Sum; $tx = [double]$s[1].Sum; $t = [DateTime]::UtcNow
  $net = @{ rxBps = 0; txBps = 0 }
  if ($prev) {
    $dt = ($t - $prevT).TotalSeconds
    if ($dt -gt 0) { $net = @{ rxBps = [math]::Max(0, ($rx - $prev[0]) / $dt); txBps = [math]::Max(0, ($tx - $prev[1]) / $dt) } }
  }
  $prev = @($rx, $tx); $prevT = $t
  $media = $null; try { $media = Get-PanelMedia } catch { }
  $vol = Get-PanelVolume
  $procs = $null; try { $procs = Get-TopProcesses } catch { }
  $discord = [bool](Get-Process -Name Discord -ErrorAction SilentlyContinue)
  [Console]::Out.WriteLine((@{ disks = @($disks); net = $net; media = $media; volume = $vol; procs = $procs; discord = $discord } | ConvertTo-Json -Compress -Depth 5))
  [Console]::Out.Flush()
  Start-Sleep -Milliseconds 1500
}`;
  const child = spawn('powershell.exe', ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', PS_PRELUDE + script], { windowsHide: true });
  child.stdout.setEncoding('utf8');
  let buf = '';
  child.stdout.on('data', (d) => {
    buf += d;
    let i;
    while ((i = buf.indexOf('\n')) >= 0) {
      const line = buf.slice(0, i).trim();
      buf = buf.slice(i + 1);
      try {
        if (!line) continue;
        const data = JSON.parse(line);
        if (data.media && data.media.art) {
          art = { key: data.media.artKey, data: data.media.art };
        }
        if (data.media) delete data.media.art;
        extra = data;
      } catch {}
    }
  });
  child.on('exit', () => setTimeout(startStatsWorker, 3000));
  process.on('exit', () => child.kill());
}
startStatsWorker();
for (const sig of ['SIGINT', 'SIGTERM', 'SIGBREAK']) process.on(sig, () => process.exit(0));

function stats() {
  return {
    host: os.hostname(),
    uptime: os.uptime(),
    cpu: { percent: cpuPercent, cores: os.cpus().length, model: os.cpus()[0]?.model?.trim(), perCore: corePercents },
    procs: extra.procs || null,
    apps: { discord: !!extra.discord },
    mem: { total: os.totalmem(), free: os.freemem() },
    disks: extra.disks,
    net: extra.net,
    media: extra.media && extra.media.title ? extra.media : null,
    volume: extra.volume,
    artKey: extra.media && extra.media.artKey === art.key ? art.key : null,
    paginas: paginasVisibles(),
    idioma,
    cfgVer: versionConfig(),
    time: Date.now(),
  };
}

// ---------- Tareas (lista de pendientes, se guarda en data/tareas.json)
const TASKS_PATH = path.join(ROOT, 'data', 'tareas.json');
function readTasks() {
  try { return JSON.parse(fs.readFileSync(TASKS_PATH, 'utf8')); } catch { return []; }
}
function writeTasks(list) {
  if (!Array.isArray(list) || list.length > 200) throw new Error(tr('lista de tareas inválida'));
  const clean = list.map((t) => ({
    id: String(t.id || crypto.randomUUID()).slice(0, 64),
    text: String(t.text || '').trim().slice(0, 200),
    done: !!t.done,
  })).filter((t) => t.text);
  fs.mkdirSync(path.dirname(TASKS_PATH), { recursive: true });
  fs.writeFileSync(TASKS_PATH, JSON.stringify(clean, null, 2));
  return clean;
}

// ---------- Atajos de la página Sistema (el grupo con "place": "atajos" de config.json). Se editan en la ventana del panel
// (solo desde este PC); al guardarlos se reescribe solo la lista de ese grupo, un atajo por línea, sin tocar lo demás.
// El celular los vuelve a pedir en cuanto cambia config.json (stats.cfgVer).
const MAX_ATAJOS = 12;
const atajosDe = (cfg) => { const g = (cfg.groups || []).find((x) => x.place === 'atajos'); return g && Array.isArray(g.items) ? g.items : []; };
function atajosPredeterminados() {
  try { return atajosDe(JSON.parse(fs.readFileSync(path.join(ROOT, 'config.ejemplo.json'), 'utf8').replace(/^﻿/, ''))); } catch { return []; }
}
// Deja solo lo que un atajo puede tener, o lanza un error que se muestra en la ventana.
function limpiarAtajo(a, anterior, usados) {
  const label = String(a.label || '').trim().slice(0, 40);
  if (!label) throw new Error(tr('cada atajo necesita un nombre'));
  if (!['open', 'keys', 'command'].includes(a.type)) throw new Error(tr('tipo de atajo inválido: {0}', label));
  let id = String(a.id || '').replace(/[^\w-]/g, '').slice(0, 40);
  if (!id || usados.has(id)) id = 'atajo_' + crypto.randomBytes(3).toString('hex');
  usados.add(id);
  const r = { id, label, icon: /^[a-z]+$/.test(a.icon || '') ? a.icon : 'dot' };
  if (/^#[0-9a-f]{6}$/i.test(a.color || '')) r.color = a.color.toLowerCase();
  r.type = a.type;
  const campo = (k) => String(a[k] || '').trim();
  if (a.type === 'open') { r.target = campo('target'); if (campo('args')) r.args = campo('args'); }
  if (a.type === 'keys') r.keys = campo('keys');
  if (a.type === 'command') r.command = String(a.command || '').trim();
  const falta = { open: [r.target, 'qué abrir'], keys: [r.keys, 'el atajo de teclado'], command: [r.command, 'el comando'] }[a.type];
  if (!falta[0]) throw new Error(tr('a «{0}» le falta {1}', label, tr(falta[1])));
  if (a.confirm) r.confirm = true;
  for (const k of ['hint', 'cwd', 'timeout']) if (anterior && anterior[k] != null) r[k] = anterior[k]; // lo que la ventana no edita
  return r;
}
// Posición del corchete o la llave que cierra el que empieza en i (sin contar los que hay dentro de textos).
function cierre(txt, i) {
  let nivel = 0, enTexto = false;
  for (let k = i; k < txt.length; k++) {
    const c = txt[k];
    if (enTexto) { if (c === '\\') k++; else if (c === '"') enTexto = false; continue; }
    if (c === '"') enTexto = true;
    else if (c === '[' || c === '{') nivel++;
    else if ((c === ']' || c === '}') && --nivel === 0) return k;
  }
  return -1;
}
function guardarAtajos(lista) {
  if (!Array.isArray(lista) || lista.length > MAX_ATAJOS) throw new Error(tr('como mucho {0} atajos', MAX_ATAJOS));
  let txt = fs.readFileSync(CONFIG_PATH, 'utf8').replace(/^﻿/, '');
  const cfg = JSON.parse(txt), antes = atajosDe(cfg);
  const usados = new Set((cfg.groups || []).filter((g) => g.place !== 'atajos').flatMap((g) => (g.items || []).map((x) => x.id)));
  const items = lista.map((a) => limpiarAtajo(a || {}, antes.find((x) => x.id === a.id), usados));
  const eol = txt.includes('\r\n') ? '\r\n' : '\n';
  const linea = (o) => '{ ' + Object.entries(o).map(([k, v]) => `${JSON.stringify(k)}: ${JSON.stringify(v)}`).join(', ') + ' }';
  const lugar = /"place"\s*:\s*"atajos"/.exec(txt);
  const lista0 = lugar && /"items"\s*:\s*\[/g;
  let hecho = false;
  if (lista0) {
    lista0.lastIndex = lugar.index;
    const m = lista0.exec(txt), ini = m && m.index + m[0].length - 1, fin = m ? cierre(txt, ini) : -1;
    if (fin > ini) {
      const nuevo = items.length ? `[${eol}${items.map((o) => '        ' + linea(o)).join(',' + eol)}${eol}      ]` : '[]';
      const prueba = txt.slice(0, ini) + nuevo + txt.slice(fin + 1);
      try { if (JSON.stringify(atajosDe(JSON.parse(prueba))) === JSON.stringify(items)) { txt = prueba; hecho = true; } } catch {}
    }
  }
  if (!hecho) { // sin el grupo, o con un formato inesperado: se reescribe entero
    const g = (cfg.groups || (cfg.groups = [])).find((x) => x.place === 'atajos');
    if (g) g.items = items; else cfg.groups.unshift({ name: 'Atajos', place: 'atajos', items });
    txt = JSON.stringify(cfg, null, 2) + eol;
  }
  fs.writeFileSync(CONFIG_PATH, txt);
  return items;
}
// Cambia cada vez que se guarda config.json (desde la ventana, el panel o a mano).
const versionConfig = () => { try { return fs.statSync(CONFIG_PATH).mtimeMs; } catch { return 0; } };

// ---------- Páginas del celular: cuáles se ven y en qué orden. Se eligen en la ventana del panel y se guardan en
// data/paginas.json; el celular las recibe con cada lectura del estado y se reordena solo.
const PAGINAS = [
  { id: 'inicio', nombre: 'Inicio', detalle: 'Reloj, música, volumen y uso del PC' },
  { id: 'mezclador', nombre: 'Mezclador', detalle: 'Volumen de cada aplicación y salida de audio' },
  { id: 'sistema', nombre: 'Sistema', detalle: 'Indicadores y botones de atajos' },
  { id: 'rendimiento', nombre: 'Rendimiento', detalle: 'Historial de CPU, RAM y red, y cada núcleo' },
  { id: 'procesos', nombre: 'Procesos', detalle: 'Los programas que más CPU y memoria usan' },
  { id: 'enfoque', nombre: 'Enfoque', detalle: 'Pomodoro, tareas y accesos rápidos' },
  { id: 'calendario', nombre: 'Calendario', detalle: 'El mes con tu agenda, relojes del mundo y el clima' },
  { id: 'discord', nombre: 'Discord', detalle: 'Compartir pantalla, micrófono y más' },
  { id: 'comandos', nombre: 'Comandos', detalle: 'Botones de comandos y su consola' },
];
const PAGINAS_PATH = path.join(ROOT, 'data', 'paginas.json');
// Lista completa, en orden, con { id, ver }. Lo que no se conoce se descarta; las páginas que falten (por ejemplo,
// una nueva de otra versión) se agregan al final, visibles.
function normalizarPaginas(lista) {
  const conocidas = new Set(PAGINAS.map((p) => p.id)), puestas = new Set(), r = [];
  for (const p of Array.isArray(lista) ? lista : []) {
    const id = String((p && p.id) || '');
    if (!conocidas.has(id) || puestas.has(id)) continue;
    puestas.add(id);
    r.push({ id, ver: p.ver !== false });
  }
  for (const p of PAGINAS) if (!puestas.has(p.id)) r.push({ id: p.id, ver: true });
  return r;
}
function leerPaginas() {
  let guardadas = null;
  try { guardadas = JSON.parse(fs.readFileSync(PAGINAS_PATH, 'utf8').replace(/^﻿/, '')).paginas; } catch {} // sin BOM, por si se editó a mano
  const r = normalizarPaginas(guardadas);
  return r.some((p) => p.ver) ? r : normalizarPaginas(null); // si quedaron todas ocultas, se ven todas
}
let paginas = leerPaginas();
function guardarPaginas(lista) {
  const r = normalizarPaginas(lista);
  if (!r.some((p) => p.ver)) throw new Error(tr('tiene que quedar al menos una página'));
  fs.mkdirSync(path.dirname(PAGINAS_PATH), { recursive: true });
  fs.writeFileSync(PAGINAS_PATH, JSON.stringify({ paginas: r }, null, 2));
  paginas = r;
}
const paginasVisibles = () => paginas.filter((p) => p.ver).map((p) => p.id);
const paginasPc = () => ({ paginas: paginas.map((p) => ({ ...PAGINAS.find((x) => x.id === p.id), ver: p.ver })) });

// ---------- Ubicación del PC, para el clima: la da el servicio de ubicación de Windows (normalmente con unos km de
// precisión, por la red Wi-Fi). Se pregunta con PowerShell y se guarda 3 horas (si falla, se vuelve a probar a los 2 min).
// El nombre de la ciudad lo da OpenStreetMap (Nominatim). A los dos servicios solo se les mandan las coordenadas
// redondeadas a 2 decimales (alrededor de 1 km).
let ubicacion = { at: 0, data: null, error: null };
let ubicacionEnCurso = null;
async function ubicacionPc() {
  if (ubicacion.data && Date.now() - ubicacion.at < 3 * 3600e3) return ubicacion.data;
  if (ubicacion.error && Date.now() - ubicacion.at < 2 * 60e3) throw new Error(tr(ubicacion.error));
  if (!ubicacionEnCurso) ubicacionEnCurso = leerUbicacion().finally(() => { ubicacionEnCurso = null; });
  return ubicacionEnCurso;
}
async function leerUbicacion() {
  const script = `Add-Type -AssemblyName System.Device
$w = New-Object System.Device.Location.GeoCoordinateWatcher
[void]$w.TryStart($false, [TimeSpan]::FromSeconds(10))
$hasta = (Get-Date).AddSeconds(10)
while ($w.Status -ne 'Ready' -and $w.Status -ne 'Disabled' -and $w.Permission -ne 'Denied' -and (Get-Date) -lt $hasta) { Start-Sleep -Milliseconds 200 }
$l = $w.Position.Location
$estado = if ($w.Permission -eq 'Denied' -or $w.Status -eq 'Disabled') { 'apagada' } elseif ($l.IsUnknown) { 'desconocida' } else { 'ok' }
$w.Stop()
$c = [Globalization.CultureInfo]::InvariantCulture
'{0};{1};{2}' -f $estado, $l.Latitude.ToString($c), $l.Longitude.ToString($c)`;
  const r = await runPowerShell(script, { timeoutMs: 25000 });
  const [estado, lat, lon] = (r.stdout.split(/\r?\n/).pop() || '').split(';');
  const falla = (motivo) => { ubicacion = { at: Date.now(), data: null, error: motivo }; throw new Error(tr(motivo)); };
  if (estado === 'apagada') falla('la ubicación de Windows está desactivada. Actívala en Configuración > Privacidad y seguridad > Ubicación, también para las aplicaciones de escritorio.');
  if (estado === 'desconocida') falla('Windows todavía no sabe dónde está este PC. Prueba otra vez en un momento.');
  if (estado !== 'ok' || !Number.isFinite(+lat) || !Number.isFinite(+lon)) falla('no se pudo preguntar la ubicación a Windows');
  const data = { lat: Math.round(+lat * 100) / 100, lon: Math.round(+lon * 100) / 100, ciudad: '' };
  try {
    const u = new URL('https://nominatim.openstreetmap.org/reverse');
    u.search = new URLSearchParams({ format: 'jsonv2', lat: data.lat.toFixed(2), lon: data.lon.toFixed(2), zoom: '10', 'accept-language': idioma }).toString();
    const g = await fetch(u, { signal: AbortSignal.timeout(6000), headers: { 'User-Agent': 'Orbital/1.0' } });
    if (g.ok) {
      const a = (await g.json()).address || {};
      data.ciudad = a.city || a.town || a.village || a.municipality || a.county || a.state || '';
    }
  } catch {} // sin nombre de ciudad, el clima se muestra igual
  ubicacion = { at: Date.now(), data, error: null };
  return data;
}

// ---------- Clima (Open-Meteo, solo si está activado en config.json; caché de 15 min). Con "ubicacion": "pc" (o sin
// lat y lon) usa la ubicación del PC; si no, las coordenadas de config.json.
let weatherCache = { at: 0, key: '', data: null };
async function getWeather() {
  const c = loadConfig().clima || {};
  if (!c.activo) return { activo: false };
  let lat = Number(c.lat), lon = Number(c.lon), ciudad = c.ciudad || '';
  const auto = c.ubicacion === 'pc' || c.lat == null || c.lon == null || !Number.isFinite(lat) || !Number.isFinite(lon);
  if (auto) ({ lat, lon, ciudad } = await ubicacionPc());
  const key = `${lat},${lon}`;
  if (weatherCache.data && weatherCache.key === key && Date.now() - weatherCache.at < 15 * 60 * 1000) return weatherCache.data;
  const u = new URL('https://api.open-meteo.com/v1/forecast');
  u.search = new URLSearchParams({
    latitude: lat.toFixed(2), longitude: lon.toFixed(2), timezone: 'auto', forecast_days: '5',
    current: 'temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day',
    daily: 'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max',
  }).toString();
  const r = await fetch(u, { signal: AbortSignal.timeout(8000) });
  if (!r.ok) throw new Error(`clima: HTTP ${r.status}`);
  const j = await r.json();
  const data = {
    activo: true, ciudad, auto,
    now: { temp: j.current.temperature_2m, feels: j.current.apparent_temperature, hum: j.current.relative_humidity_2m, code: j.current.weather_code, wind: j.current.wind_speed_10m, day: !!j.current.is_day },
    days: j.daily.time.map((d, i) => ({ date: d, code: j.daily.weather_code[i], max: j.daily.temperature_2m_max[i], min: j.daily.temperature_2m_min[i], rain: j.daily.precipitation_probability_max[i] })),
  };
  weatherCache = { at: Date.now(), key, data };
  return data;
}

// ---------- Agenda (página Calendario): el calendario se lee desde su enlace privado iCal, guardado en config.json →
// "calendario": { "ics": "…" }. Ese enlace nunca se manda al celular ni sale en la actividad: da acceso al calendario.
// Se descarga como mucho cada 5 min; si falla, se usa la última copia (hasta 1 h).
const agenda = require('./lib/agenda');
let agendaCache = { url: '', at: 0, cal: null };
let agendaEnCurso = null;
const enlaceAgenda = () => { try { return agenda.enlaceValido((loadConfig().calendario || {}).ics); } catch { return null; } };
async function calendario(url, forzar = false) {
  const fresco = agendaCache.cal && agendaCache.url === url && Date.now() - agendaCache.at < 5 * 60e3;
  if (fresco && !forzar) return agendaCache.cal;
  if (!agendaEnCurso) {
    agendaEnCurso = agenda.descargarIcs(url)
      .then((cal) => { agendaCache = { url, at: Date.now(), cal }; return cal; })
      .finally(() => { agendaEnCurso = null; });
  }
  try { return await agendaEnCurso; } catch (e) {
    if (!forzar && agendaCache.cal && agendaCache.url === url && Date.now() - agendaCache.at < 3600e3) return agendaCache.cal;
    throw new Error(tr('No se pudo leer el calendario: {0}', tr(e.motivo || 'sin conexión')));
  }
}
// "AAAA-MM-DD" → medianoche de ese día en la hora del PC
const diaLocal = (s) => { const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(s || '')); return m ? new Date(+m[1], +m[2] - 1, +m[3]).getTime() : NaN; };
async function eventosAgenda(desdeTxt, hastaTxt) {
  const url = enlaceAgenda();
  if (!url) return { conectado: false };
  const desde = diaLocal(desdeTxt), hasta = diaLocal(hastaTxt) + 86400000;
  if (!Number.isFinite(desde) || !Number.isFinite(hasta) || hasta <= desde || hasta - desde > 70 * 86400000) throw Object.assign(new Error(tr('fechas inválidas')), { status: 400 });
  try {
    const cal = await calendario(url);
    return { conectado: true, nombre: cal.nombre, eventos: agenda.eventosEntre(cal, desde, hasta).slice(0, 500) };
  } catch (e) { return { conectado: true, error: e.message }; }
}

// ---------- HTTP
const MIME = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.svg': 'image/svg+xml', '.json': 'application/json', '.webmanifest': 'application/manifest+json', '.png': 'image/png' };

function send(res, status, body, type = 'application/json; charset=utf-8') {
  res.writeHead(status, {
    'Content-Type': type,
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff',
    'Referrer-Policy': 'no-referrer',
  });
  res.end(typeof body === 'string' || Buffer.isBuffer(body) ? body : JSON.stringify(body));
}

// Lee el cuerpo de la petición. Si no termina de llegar en 10 s, falla en lugar de quedarse esperando para siempre.
function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    const timer = setTimeout(() => reject(new Error('el cuerpo de la petición no llegó completo')), 10000);
    req.on('data', (c) => {
      data += c;
      if (data.length > 1e5) req.destroy();
    });
    req.on('end', () => { clearTimeout(timer); resolve(data); });
    req.on('error', (e) => { clearTimeout(timer); reject(e); });
  });
}

// Registro de depuración opcional (PANEL_DEBUG=1): data/debug.log, sin el token.
const DEBUG = process.env.PANEL_DEBUG === '1';
const dlog = (...a) => { if (DEBUG) fs.appendFile(path.join(ROOT, 'data', 'debug.log'), `[${new Date().toLocaleTimeString()}] ${a.join(' ')}\n`, () => {}); };

// Modo Wi-Fi (opcional): además de 127.0.0.1, escucha en la IP de la red local indicada en PANEL_LAN_IP.
const LAN_IP = /^(10|172\.(1[6-9]|2\d|3[01])|192\.168)\.\d{1,3}\.\d{1,3}(\.\d{1,3})?$/.test(process.env.PANEL_LAN_IP || '') ? process.env.PANEL_LAN_IP : null;
const allowedHosts = new Set([`localhost:${PORT}`, `127.0.0.1:${PORT}`]);
if (LAN_IP) allowedHosts.add(`${LAN_IP}:${PORT}`);
// Solo se aceptan conexiones del propio PC o de los dispositivos de config.json → wifi.dispositivos.
const { isAllowed, isPrivate, normalize } = require('./lib/allow');
const wifiDevices = () => { try { return (loadConfig().wifi || {}).dispositivos || []; } catch { return []; } };
const rejectedLog = new Map();
function logRejected(addr) {
  const a = normalize(addr), now = Date.now();
  if (now - (rejectedLog.get(a) || 0) < 60000) return;
  rejectedLog.set(a, now);
  evento('rechazo', tr('Conexión rechazada desde {0}. Si es tu celular, escanea el código QR del panel para pedir acceso.', a));
}

// Dispositivos nuevos en modo Wi-Fi: con el token del QR pueden pedir acceso, y el PC pregunta si se permite.
const { createApprovals, describeDevice, removeDevice } = require('./lib/aprobacion');
const approvals = LAN_IP ? createApprovals({ configPath: CONFIG_PATH, log: (m) => evento('aprobacion', m), tr }) : null;
process.on('exit', () => approvals && approvals.close());
const isLocal = (addr) => addr === '127.0.0.1' || addr === '::1';

// ---------- Estado para la ventana del panel (solo se consulta desde este PC)
const vistos = new Map(); // IP → { t, equipo }: última vez que cada dispositivo de la red usó el panel
let qrFilas = null;
function estadoPc() {
  const url = LAN_IP ? `http://${LAN_IP}:${PORT}/#t=${TOKEN}` : null;
  if (url && !qrFilas) qrFilas = require('./lib/qr').encode(url).modules.map((fila) => fila.map((on) => (on ? '1' : '0')).join(''));
  const ahora = Date.now();
  return {
    modo: LAN_IP ? 'wifi' : 'local',
    puerto: PORT,
    lanIp: LAN_IP,
    url,
    qr: qrFilas,
    dispositivos: wifiDevices().map(String).map((ip) => {
      const v = vistos.get(ip);
      return { ip, haceMs: v ? ahora - v.t : null, equipo: v ? v.equipo : null };
    }),
    pendiente: approvals ? approvals.pending() : null,
    actividad: actividad.slice(-12),
  };
}
const tokenOk = (req) => {
  const given = String(req.headers['x-panel-token'] || '');
  return given.length === TOKEN.length && crypto.timingSafeEqual(Buffer.from(given), Buffer.from(TOKEN));
};

const handler = async (req, res) => {
  if (DEBUG && !req.url.startsWith('/api/stats')) {
    dlog('→', req.method, req.url.replace(/[?#].*/, ''), 'desde', req.socket.remoteAddress, 'host', req.headers.host, 'len', req.headers['content-length'] || '-', 'te', req.headers['transfer-encoding'] || '-');
    req.on('end', () => dlog('  cuerpo recibido', req.method, req.url.replace(/[?#].*/, '')));
    res.on('finish', () => dlog('←', res.statusCode, req.method, req.url.replace(/[?#].*/, '')));
  }
  const remote = normalize(req.socket.remoteAddress);
  if (!isAllowed(remote, LAN_IP, wifiDevices())) {
    // Dispositivo nuevo de la red local en modo Wi-Fi: solo puede ver la página de espera y pedir acceso con el token.
    if (approvals && isPrivate(remote) && allowedHosts.has(req.headers.host)) {
      const p = req.url.split(/[?#]/)[0];
      if (req.method === 'GET' && p === '/') {
        return fs.readFile(path.join(ROOT, 'public', 'espera.html'), (err, data) => (err ? send(res, 500, 'error', 'text/plain') : send(res, 200, data, MIME['.html'])));
      }
      if (req.method === 'POST' && p === '/api/solicitar') {
        if (!tokenOk(req)) { logRejected(remote); return send(res, 401, { error: tr('token inválido'), idioma }); }
        return send(res, 200, { estado: approvals.request(remote, describeDevice(req.headers['user-agent'])), idioma });
      }
    }
    // Cualquier otra cosa: se corta la conexión sin responder nada.
    logRejected(remote);
    req.socket.destroy();
    return;
  }
  // Protección contra DNS rebinding: solo se aceptan los nombres de host del panel.
  if (!allowedHosts.has(req.headers.host)) return send(res, 403, { error: tr('host no permitido') });
  if (LAN_IP && !isLocal(remote) && remote !== LAN_IP) vistos.set(remote, { t: Date.now(), equipo: describeDevice(req.headers['user-agent']) });

  const url = new URL(req.url, `http://${req.headers.host}`);

  if (url.pathname.startsWith('/api/')) {
    if (!tokenOk(req)) return send(res, 401, { error: tr('token inválido') });

    try {
      // Ventana del panel en el PC: estado, quitar un dispositivo y detener el panel.
      if (url.pathname.startsWith('/api/pc')) {
        if (!isLocal(remote)) return send(res, 403, { error: tr('solo desde este PC') });
        if (url.pathname === '/api/pc' && req.method === 'GET') return send(res, 200, estadoPc());
        if (url.pathname === '/api/pc/quitar' && req.method === 'POST') {
          const ip = String(JSON.parse((await readBody(req)) || '{}').ip || '');
          const ok = removeDevice(CONFIG_PATH, ip);
          if (ok) {
            vistos.delete(ip);
            evento('aprobacion', tr('Dispositivo quitado: {0}. Si vuelve a escanear el código, el PC te preguntará otra vez.', ip));
          }
          return send(res, 200, { ok });
        }
        if (url.pathname === '/api/pc/idioma' && req.method === 'POST') {
          const pedido = String(JSON.parse((await readBody(req)) || '{}').idioma || '');
          if (pedido !== 'es' && pedido !== 'en') return send(res, 400, { error: tr('idioma inválido') });
          idioma = pedido; // la ventana ya lo guardó en data/preferencias.json
          return send(res, 200, { idioma });
        }
        if (url.pathname === '/api/pc/paginas' && req.method === 'GET') return send(res, 200, paginasPc());
        if (url.pathname === '/api/pc/paginas' && req.method === 'POST') {
          const body = JSON.parse((await readBody(req)) || '{}');
          try { guardarPaginas(body.paginas); } catch (e) { return send(res, 400, { error: e.message }); }
          return send(res, 200, paginasPc());
        }
        if (url.pathname === '/api/pc/atajos' && req.method === 'GET') {
          return send(res, 200, { atajos: atajosDe(loadConfig()), predeterminados: atajosPredeterminados(), maximo: MAX_ATAJOS });
        }
        if (url.pathname === '/api/pc/atajos' && req.method === 'POST') {
          const body = JSON.parse((await readBody(req)) || '{}');
          try { return send(res, 200, { atajos: guardarAtajos(body.atajos) }); } catch (e) { return send(res, 400, { error: e.message }); }
        }
        if (url.pathname === '/api/pc/detener' && req.method === 'POST') {
          send(res, 200, { ok: true });
          setTimeout(() => process.exit(0), 100);
          return;
        }
      }
      // La página de espera sigue preguntando hasta ver que el dispositivo ya está autorizado.
      if (url.pathname === '/api/solicitar' && req.method === 'POST') return send(res, 200, { estado: 'aprobado', idioma });
      if (url.pathname === '/api/config' && req.method === 'GET') return send(res, 200, publicConfig());
      if (url.pathname === '/api/stats' && req.method === 'GET') return send(res, 200, stats());
      if (url.pathname === '/api/tasks' && req.method === 'GET') return send(res, 200, readTasks());
      if (url.pathname === '/api/tasks' && req.method === 'PUT') return send(res, 200, writeTasks(JSON.parse((await readBody(req)) || '[]')));
      // Activar el clima con la ubicación del PC (o apagarlo): botón de la página Calendario.
      if (url.pathname === '/api/clima' && req.method === 'POST') {
        const b = JSON.parse((await readBody(req)) || '{}');
        guardarEnConfig('clima', b.activo === false ? { activo: false, ubicacion: 'pc' } : { activo: true, ubicacion: 'pc' });
        weatherCache = { at: 0, key: '', data: null };
        try { return send(res, 200, await getWeather()); } catch (e) { return send(res, 200, { activo: true, auto: true, error: String(e.message || e) }); }
      }
      if (url.pathname === '/api/agenda' && req.method === 'GET') {
        try { return send(res, 200, await eventosAgenda(url.searchParams.get('desde'), url.searchParams.get('hasta'))); }
        catch (e) { return send(res, e.status || 500, { error: e.message }); }
      }
      // Conectar (o desconectar, con un enlace vacío) el calendario: se prueba antes de guardarlo.
      if (url.pathname === '/api/agenda/enlace' && req.method === 'POST') {
        const texto = String(JSON.parse((await readBody(req)) || '{}').enlace || '').trim();
        if (!texto) { guardarEnConfig('calendario', { ics: '' }); agendaCache = { url: '', at: 0, cal: null }; return send(res, 200, { conectado: false }); }
        const enlace = agenda.enlaceValido(texto);
        if (!enlace) return send(res, 400, { error: tr('Ese enlace no sirve: tiene que empezar por https:// (la dirección secreta en formato iCal de tu calendario).') });
        let cal;
        try { cal = await calendario(enlace, true); } catch (e) { return send(res, 400, { error: e.message }); }
        guardarEnConfig('calendario', { ics: enlace });
        return send(res, 200, { conectado: true, nombre: cal.nombre, eventos: cal.eventos.length });
      }
      if (url.pathname === '/api/weather' && req.method === 'GET') {
        try { return send(res, 200, await getWeather()); } catch (e) { return send(res, 200, { activo: true, error: String(e.message || e) }); }
      }
      if (url.pathname === '/api/art' && req.method === 'GET') return send(res, 200, { key: art.key, data: art.data });
      if (url.pathname === '/api/volume' && req.method === 'POST') {
        const body = JSON.parse((await readBody(req)) || '{}');
        if (typeof body.muted === 'boolean') control(`mute ${body.muted ? 1 : 0}`);
        else if (Number.isFinite(body.level)) control(`vol ${Math.round(body.level)}`);
        else return send(res, 400, { error: tr('falta level o muted') });
        return send(res, 200, { ok: true });
      }
      if (url.pathname === '/api/mixer' && req.method === 'GET') {
        const m = await pedirMezclador();
        return m ? send(res, 200, m) : send(res, 503, { error: tr('el mezclador no está disponible') });
      }
      if (url.pathname === '/api/mixer/salida' && req.method === 'POST') {
        const body = JSON.parse((await readBody(req)) || '{}');
        const id = String(body.id || '');
        // Windows identifica cada salida así: {0.0.0.00000000}.{guid}
        if (!/^\{[0-9.]{1,40}\}\.\{[0-9a-f-]{36}\}$/i.test(id)) return send(res, 400, { error: tr('salida inválida') });
        const r = await preguntar(`salida ${id}`, 5000);
        if (!r) return send(res, 503, { error: tr('el PC no respondió') });
        return r.error ? send(res, 500, { error: trMezclador(r.error) }) : send(res, 200, r);
      }
      if (url.pathname === '/api/mixer/icono' && req.method === 'GET') {
        return send(res, 200, { data: iconosMezclador.get(url.searchParams.get('k')) || null });
      }
      if (url.pathname === '/api/mixer' && req.method === 'POST') {
        const body = JSON.parse((await readBody(req)) || '{}');
        const clave = String(body.clave || '');
        if (!clave || clave.length > 500 || /[\r\n]/.test(clave)) return send(res, 400, { error: tr('aplicación inválida') });
        if (typeof body.silencio === 'boolean') control(`appmute ${body.silencio ? 1 : 0} ${clave}`);
        else if (Number.isFinite(body.nivel)) control(`appvol ${Math.min(100, Math.max(0, Math.round(body.nivel)))} ${clave}`);
        else return send(res, 400, { error: tr('falta nivel o silencio') });
        return send(res, 200, { ok: true });
      }
      if (url.pathname === '/api/action' && req.method === 'POST') {
        const { id } = JSON.parse((await readBody(req)) || '{}');
        const action = findAction(id);
        if (!action) return send(res, 404, { error: tr('acción no encontrada') });
        const started = Date.now();
        // Música y volumen: al proceso de control permanente (instantáneo). Si no está listo, con un PowerShell nuevo.
        const rapido = action.type === 'media' && MEDIA.has(action.key) && control(`media ${action.key} ${mediaTimes(action)}`);
        const result = rapido ? { code: 0, stdout: '', stderr: '' } : await runPowerShell(scriptFor(action), { cwd: action.cwd, timeoutMs: (action.timeout || 60) * 1000 });
        evento(result.code === 0 ? 'accion' : 'error', result.code === 0 ? action.label : tr('{0}: falló (código {1})', action.label, result.code));
        return send(res, 200, { ...result, ms: Date.now() - started, showOutput: action.type === 'command' });
      }
      return send(res, 404, { error: tr('no encontrado') });
    } catch (e) {
      dlog('ERROR', req.method, url.pathname, String(e.message || e));
      return send(res, 500, { error: String(e.message || e) });
    }
  }

  // Archivos estáticos de /public
  const rel = url.pathname === '/' ? 'index.html' : url.pathname.slice(1);
  const file = path.normalize(path.join(ROOT, 'public', rel));
  if (!file.startsWith(path.join(ROOT, 'public'))) return send(res, 403, tr('prohibido'), 'text/plain');
  fs.readFile(file, (err, data) => {
    if (err) return send(res, 404, tr('no encontrado'), 'text/plain');
    send(res, 200, data, MIME[path.extname(file)] || 'application/octet-stream');
  });
};

http.createServer(handler).listen(PORT, '127.0.0.1', () => {
  console.log(`Orbital escuchando en http://localhost:${PORT}`);
  if (!process.env.PANEL_TOKEN) console.log(`Abrir en este PC: http://localhost:${PORT}/#t=${TOKEN}`);
});
if (LAN_IP) {
  http.createServer(handler)
    .on('error', (e) => console.log(`No se pudo escuchar en la red Wi-Fi (${LAN_IP}): ${e.message}`))
    .listen(PORT, LAN_IP, () => console.log(`Y en la red local: http://${LAN_IP}:${PORT}`));
}
// Si el clima usa la ubicación del PC, se pregunta ya, para que la página Calendario no tenga que esperarla.
try { const c = loadConfig().clima || {}; if (c.activo && c.ubicacion === 'pc') ubicacionPc().catch(() => {}); } catch {}
