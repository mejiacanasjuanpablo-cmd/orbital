// Panel USB — servidor local sin dependencias.
// Solo escucha en 127.0.0.1; el celular llega por el túnel `adb reverse`.
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
    groups: (cfg.groups || []).map((g) => ({
      name: g.name,
      place: g.place || 'atajos',
      items: (g.items || []).map(({ id, label, icon, color, type, confirm }) => ({ id, label, icon, color, type, confirm: !!confirm })),
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
      return `Start-Process ${psQuote(action.target)}${args}`;
    }
    case 'media': {
      const vk = MEDIA[action.key];
      if (!vk) throw new Error(`Tecla multimedia desconocida: ${action.key}`);
      const times = Math.min(Math.max(Number(action.repeat) || 1, 1), 20);
      return `$w = New-Object -ComObject WScript.Shell; 1..${times} | ForEach-Object { $w.SendKeys([string][char]${vk}) }`;
    }
    case 'keys':
      return `$w = New-Object -ComObject WScript.Shell; $w.SendKeys(${psQuote(action.keys)})`;
    case 'command':
      return action.command;
    default:
      throw new Error(`Tipo de acción desconocido: ${action.type}`);
  }
}

// ---------- Monitor del sistema
let lastCpu = os.cpus();
let cpuPercent = 0;
setInterval(() => {
  const now = os.cpus();
  let idle = 0;
  let total = 0;
  now.forEach((c, i) => {
    const p = lastCpu[i].times;
    const t = c.times;
    const dTotal = t.user + t.nice + t.sys + t.idle + t.irq - (p.user + p.nice + p.sys + p.idle + p.irq);
    idle += t.idle - p.idle;
    total += dTotal;
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
  [Console]::Out.WriteLine((@{ disks = @($disks); net = $net; media = $media; volume = $vol } | ConvertTo-Json -Compress -Depth 4))
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
    cpu: { percent: cpuPercent, cores: os.cpus().length, model: os.cpus()[0]?.model?.trim() },
    mem: { total: os.totalmem(), free: os.freemem() },
    disks: extra.disks,
    net: extra.net,
    media: extra.media && extra.media.title ? extra.media : null,
    volume: extra.volume,
    artKey: extra.media && extra.media.artKey === art.key ? art.key : null,
    time: Date.now(),
  };
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

function readBody(req) {
  return new Promise((resolve) => {
    let data = '';
    req.on('data', (c) => {
      data += c;
      if (data.length > 1e5) req.destroy();
    });
    req.on('end', () => resolve(data));
  });
}

const allowedHosts = new Set([`localhost:${PORT}`, `127.0.0.1:${PORT}`]);

const server = http.createServer(async (req, res) => {
  // Protección contra DNS rebinding: solo se acepta el host local.
  if (!allowedHosts.has(req.headers.host)) return send(res, 403, { error: 'host no permitido' });

  const url = new URL(req.url, `http://${req.headers.host}`);

  if (url.pathname.startsWith('/api/')) {
    const given = req.headers['x-panel-token'] || '';
    const ok = given.length === TOKEN.length && crypto.timingSafeEqual(Buffer.from(given), Buffer.from(TOKEN));
    if (!ok) return send(res, 401, { error: 'token inválido' });

    try {
      if (url.pathname === '/api/config' && req.method === 'GET') return send(res, 200, publicConfig());
      if (url.pathname === '/api/stats' && req.method === 'GET') return send(res, 200, stats());
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
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`Panel USB escuchando en http://localhost:${PORT}`);
  if (!process.env.PANEL_TOKEN) console.log(`Abrir en este PC: http://localhost:${PORT}/#t=${TOKEN}`);
  console.log('Ctrl+C para detener.');
});
