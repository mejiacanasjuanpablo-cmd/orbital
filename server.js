// Panel USB — servidor local sin dependencias.
// Escucha en 127.0.0.1 (el celular llega por el túnel `adb reverse`) y, en modo Wi-Fi, también en la IP local.
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
function loadConfig() {
  return JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
}
function findAction(id) {
  const cfg = loadConfig();
  for (const group of cfg.groups || []) {
    for (const item of group.items || []) if (item.id === id) return item;
  }
  return null;
}
// Lo que se envía al celular: sin los comandos en sí.
function publicConfig() {
  const cfg = loadConfig();
  return {
    title: cfg.title || 'Panel',
    relojes: (cfg.relojes || []).slice(0, 6).map((r) => ({ nombre: String(r.nombre || ''), zona: String(r.zona || '') })),
    pomodoro: cfg.pomodoro || null,
    groups: (cfg.groups || []).map((g) => ({
      name: g.name,
      place: g.place || 'atajos',
      items: (g.items || []).map(({ id, label, icon, color, type, confirm, hint }) => ({ id, label, icon, color, type, hint, confirm: !!confirm })),
    })),
  };
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

// Teclas multimedia: SendKeys acepta el código de tecla virtual como carácter.
const MEDIA = { mute: 173, voldown: 174, volup: 175, next: 176, prev: 177, stop: 178, playpause: 179 };

function scriptFor(action) {
  switch (action.type) {
    case 'open': {
      const args = action.args ? ` -ArgumentList ${psQuote(action.args)}` : '';
      return `Start-Process ([Environment]::ExpandEnvironmentVariables(${psQuote(action.target)}))${args}`;
    }
    case 'media': {
      const vk = MEDIA[action.key];
      if (!vk) throw new Error(`Tecla multimedia desconocida: ${action.key}`);
      const times = Math.min(Math.max(Number(action.repeat) || 1, 1), 20);
      return `$w = New-Object -ComObject WScript.Shell; 1..${times} | ForEach-Object { $w.SendKeys([string][char]${vk}) }`;
    }
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
let ctl = null;
function startControlWorker() {
  const script = `
while (Get-Process -Id ${process.pid} -ErrorAction SilentlyContinue) {
  $line = [Console]::In.ReadLine(); if ($null -eq $line) { break }
  $p = $line.Split(' ')
  try {
    switch ($p[0]) {
      'vol'  { [PanelAudio]::Mute = $false; [PanelAudio]::Volume = [float]([math]::Min([math]::Max([int]$p[1], 0), 100) / 100) }
      'mute' { [PanelAudio]::Mute = ($p[1] -eq '1') }
    }
  } catch { }
}`;
  ctl = spawn('powershell.exe', ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', PS_PRELUDE + script], { windowsHide: true });
  ctl.on('exit', () => { ctl = null; setTimeout(startControlWorker, 3000); });
  process.on('exit', () => ctl && ctl.kill());
}
startControlWorker();
function control(cmd) {
  if (ctl && ctl.stdin.writable) ctl.stdin.write(cmd + '\n');
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
    time: Date.now(),
  };
}

// ---------- Tareas (lista de pendientes, se guarda en data/tareas.json)
const TASKS_PATH = path.join(ROOT, 'data', 'tareas.json');
function readTasks() {
  try { return JSON.parse(fs.readFileSync(TASKS_PATH, 'utf8')); } catch { return []; }
}
function writeTasks(list) {
  if (!Array.isArray(list) || list.length > 200) throw new Error('lista de tareas inválida');
  const clean = list.map((t) => ({
    id: String(t.id || crypto.randomUUID()).slice(0, 64),
    text: String(t.text || '').trim().slice(0, 200),
    done: !!t.done,
  })).filter((t) => t.text);
  fs.mkdirSync(path.dirname(TASKS_PATH), { recursive: true });
  fs.writeFileSync(TASKS_PATH, JSON.stringify(clean, null, 2));
  return clean;
}

// ---------- Clima (Open-Meteo, solo si está activado en config.json; caché de 15 min)
let weatherCache = { at: 0, key: '', data: null };
async function getWeather() {
  const c = loadConfig().clima || {};
  if (!c.activo) return { activo: false };
  const lat = Number(c.lat), lon = Number(c.lon);
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return { activo: false, error: 'faltan lat/lon en config.json' };
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
    activo: true, ciudad: c.ciudad || '',
    now: { temp: j.current.temperature_2m, feels: j.current.apparent_temperature, hum: j.current.relative_humidity_2m, code: j.current.weather_code, wind: j.current.wind_speed_10m, day: !!j.current.is_day },
    days: j.daily.time.map((d, i) => ({ date: d, code: j.daily.weather_code[i], max: j.daily.temperature_2m_max[i], min: j.daily.temperature_2m_min[i], rain: j.daily.precipitation_probability_max[i] })),
  };
  weatherCache = { at: Date.now(), key, data };
  return data;
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
// Solo se aceptan conexiones desde la propia máquina o desde direcciones de red privada.
const isPrivate = (a) => /^(::ffff:)?(127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/.test(a || '') || a === '::1';

const handler = async (req, res) => {
  if (DEBUG && !req.url.startsWith('/api/stats')) {
    dlog('→', req.method, req.url.replace(/[?#].*/, ''), 'desde', req.socket.remoteAddress, 'host', req.headers.host, 'len', req.headers['content-length'] || '-', 'te', req.headers['transfer-encoding'] || '-');
    req.on('end', () => dlog('  cuerpo recibido', req.method, req.url.replace(/[?#].*/, '')));
    res.on('finish', () => dlog('←', res.statusCode, req.method, req.url.replace(/[?#].*/, '')));
  }
  // Protección contra DNS rebinding: solo se aceptan los nombres de host del panel.
  if (!allowedHosts.has(req.headers.host)) return send(res, 403, { error: 'host no permitido' });
  if (!isPrivate(req.socket.remoteAddress)) return send(res, 403, { error: 'origen no permitido' });

  const url = new URL(req.url, `http://${req.headers.host}`);

  if (url.pathname.startsWith('/api/')) {
    const given = req.headers['x-panel-token'] || '';
    const ok = given.length === TOKEN.length && crypto.timingSafeEqual(Buffer.from(given), Buffer.from(TOKEN));
    if (!ok) return send(res, 401, { error: 'token inválido' });

    try {
      if (url.pathname === '/api/config' && req.method === 'GET') return send(res, 200, publicConfig());
      if (url.pathname === '/api/stats' && req.method === 'GET') return send(res, 200, stats());
      if (url.pathname === '/api/tasks' && req.method === 'GET') return send(res, 200, readTasks());
      if (url.pathname === '/api/tasks' && req.method === 'PUT') return send(res, 200, writeTasks(JSON.parse((await readBody(req)) || '[]')));
      if (url.pathname === '/api/weather' && req.method === 'GET') {
        try { return send(res, 200, await getWeather()); } catch (e) { return send(res, 200, { activo: true, error: String(e.message || e) }); }
      }
      if (url.pathname === '/api/art' && req.method === 'GET') return send(res, 200, { key: art.key, data: art.data });
      if (url.pathname === '/api/volume' && req.method === 'POST') {
        const body = JSON.parse((await readBody(req)) || '{}');
        if (typeof body.muted === 'boolean') control(`mute ${body.muted ? 1 : 0}`);
        else if (Number.isFinite(body.level)) control(`vol ${Math.round(body.level)}`);
        else return send(res, 400, { error: 'falta level o muted' });
        return send(res, 200, { ok: true });
      }
      if (url.pathname === '/api/action' && req.method === 'POST') {
        const { id } = JSON.parse((await readBody(req)) || '{}');
        const action = findAction(id);
        if (!action) return send(res, 404, { error: 'acción no encontrada' });
        const started = Date.now();
        const result = await runPowerShell(scriptFor(action), { cwd: action.cwd, timeoutMs: (action.timeout || 60) * 1000 });
        console.log(`[${new Date().toLocaleTimeString()}] ${action.label} -> código ${result.code}`);
        return send(res, 200, { ...result, ms: Date.now() - started, showOutput: action.type === 'command' });
      }
      return send(res, 404, { error: 'no encontrado' });
    } catch (e) {
      dlog('ERROR', req.method, url.pathname, String(e.message || e));
      return send(res, 500, { error: String(e.message || e) });
    }
  }

  // Archivos estáticos de /public
  const rel = url.pathname === '/' ? 'index.html' : url.pathname.slice(1);
  const file = path.normalize(path.join(ROOT, 'public', rel));
  if (!file.startsWith(path.join(ROOT, 'public'))) return send(res, 403, 'prohibido', 'text/plain');
  fs.readFile(file, (err, data) => {
    if (err) return send(res, 404, 'no encontrado', 'text/plain');
    send(res, 200, data, MIME[path.extname(file)] || 'application/octet-stream');
  });
};

http.createServer(handler).listen(PORT, '127.0.0.1', () => {
  console.log(`Panel USB escuchando en http://localhost:${PORT}`);
  if (!process.env.PANEL_TOKEN) console.log(`Abrir en este PC: http://localhost:${PORT}/#t=${TOKEN}`);
});
if (LAN_IP) {
  http.createServer(handler)
    .on('error', (e) => console.log(`No se pudo escuchar en la red Wi-Fi (${LAN_IP}): ${e.message}`))
    .listen(PORT, LAN_IP, () => console.log(`Modo Wi-Fi: también en http://${LAN_IP}:${PORT}`));
}
