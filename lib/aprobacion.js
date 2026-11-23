'use strict';
// Aprobación de dispositivos nuevos de la red Wi-Fi.
// Un dispositivo que no está en config.json → wifi.dispositivos, pero que tiene el token (lo leyó del código QR),
// puede pedir acceso. El PC muestra un aviso "¿Permitir este dispositivo?"; si respondes Sí, su IP se guarda
// en config.json y desde ese momento entra como cualquier dispositivo autorizado.

const fs = require('fs');
const { spawn } = require('child_process');

// Añade la IP a wifi.dispositivos conservando el formato del archivo.
function addDevice(configPath, ip) {
  let txt = fs.readFileSync(configPath, 'utf8').replace(/^﻿/, '');
  const cfg = JSON.parse(txt);
  const list = cfg.wifi && Array.isArray(cfg.wifi.dispositivos) ? cfg.wifi.dispositivos : [];
  if (list.includes(ip)) return false;
  const re = /("dispositivos"\s*:\s*\[)([^\]]*)(\])/;
  if (re.test(txt)) {
    txt = txt.replace(re, (m, open, inner, close) => open + (inner.trim() ? inner.trimEnd() + ', ' : '') + JSON.stringify(ip) + close);
  } else {
    cfg.wifi = { ...(cfg.wifi || {}), dispositivos: [...list, ip] };
    txt = JSON.stringify(cfg, null, 2) + '\n';
  }
  JSON.parse(txt); // nunca se guarda un config.json inválido
  fs.writeFileSync(configPath, txt);
  return true;
}

// Quita la IP de wifi.dispositivos (desde la ventana del panel). Devuelve false si no estaba.
function removeDevice(configPath, ip) {
  let txt = fs.readFileSync(configPath, 'utf8').replace(/^﻿/, '');
  const cfg = JSON.parse(txt);
  const list = cfg.wifi && Array.isArray(cfg.wifi.dispositivos) ? cfg.wifi.dispositivos.map(String) : [];
  if (!list.includes(ip)) return false;
  const rest = list.filter((d) => d !== ip).map((d) => JSON.stringify(d)).join(', ');
  txt = txt.replace(/("dispositivos"\s*:\s*\[)([^\]]*)(\])/, (m, open, inner, close) => open + rest + close);
  const check = JSON.parse(txt); // nunca se guarda un config.json inválido
  if (((check.wifi || {}).dispositivos || []).map(String).includes(ip)) return false;
  fs.writeFileSync(configPath, txt);
  return true;
}

// Descripción corta del dispositivo a partir del navegador (por ejemplo "Android 10 · Chrome/131").
function describeDevice(userAgent) {
  const ua = String(userAgent || '');
  // Se prueba en orden de prioridad (un Android también dice "Linux").
  const osPatterns = [/Android [\d.]+/, /iPhone OS [\d_]+/, /iPad/, /Windows NT [\d.]+/, /Mac OS X [\d_]+/, /CrOS/, /Linux/];
  const osMatch = osPatterns.map((re) => ua.match(re)).find(Boolean);
  const os = (osMatch ? osMatch[0] : 'sistema desconocido')
    .replace(/_/g, '.').replace('Windows NT 10.0', 'Windows 10/11').replace('iPhone OS', 'iPhone iOS');
  const model = (ua.match(/Android [\d.]+; ([^;)]+)\)/) || [])[1];
  const browserPatterns = [/SamsungBrowser\/\d+/, /HuaweiBrowser\/\d+/, /EdgA?\/\d+/, /OPR\/\d+/, /Firefox\/\d+/, /CriOS\/\d+/, /Chrome\/\d+/, /Safari\/\d+/];
  const brMatch = browserPatterns.map((re) => ua.match(re)).find(Boolean);
  const clean = (s) => String(s).replace(/[^\w .,;:/()+-]/g, '').trim();
  const parts = [clean(os), model && clean(model) !== 'K' ? clean(model) : null, brMatch ? clean(brMatch[0]) : null];
  return parts.filter(Boolean).join(' · ').slice(0, 100) || 'sistema desconocido';
}

// Rellena {0}, {1}… (sin traducir): lo que se usa si quien llama no pasa su propia función de traducción.
const rellenar = (texto, ...datos) => datos.reduce((t, d, i) => t.split(`{${i}}`).join(String(d)), texto);

// Muestra el aviso en el PC (ventana de Windows, por encima de todo) y llama a done(true|false).
function askOnPc(ip, device, done, tr = rellenar) {
  const text = `${tr('Un dispositivo quiere usar el panel por Wi-Fi.')}\n\n    IP: ${ip}\n    ${tr('Equipo: {0}', device)}\n\n` +
    `${tr('¿Permitir este dispositivo?')}\n\n${tr('Acepta solo si es tu celular y acabas de escanear el código QR del panel.')}`;
  // Los textos van por variables de entorno: nunca se mezclan con el código de PowerShell.
  const script = "Add-Type -AssemblyName System.Windows.Forms; $r = [System.Windows.Forms.MessageBox]::Show($env:PANEL_AVISO, $env:PANEL_AVISO_TITULO, 'YesNo', 'Question', 'Button2', 'DefaultDesktopOnly'); [Console]::Out.Write([string]$r)";
  const child = spawn('powershell.exe', ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', script], {
    windowsHide: true, env: { ...process.env, PANEL_AVISO: text, PANEL_AVISO_TITULO: tr('Panel del PC: dispositivo nuevo') },
  });
  let out = '';
  child.stdout.on('data', (d) => { out += d; });
  child.on('error', () => done(null));
  child.on('exit', () => done(out.trim() === 'Yes' ? true : out.trim() === 'No' ? false : null));
  return child;
}

function createApprovals({ configPath, ask = askOnPc, log = (m) => console.log(`[${new Date().toLocaleTimeString()}] ${m}`), tr = rellenar }) {
  const state = new Map(); // ip → 'pendiente' | 'rechazado'
  let current = null;      // ip cuyo aviso está abierto
  let child = null;

  function request(ip, device) {
    const s = state.get(ip);
    if (s === 'rechazado') return 'rechazado';
    if (current === ip) return 'pendiente';
    state.set(ip, 'pendiente');
    if (current) return 'pendiente'; // hay otro aviso abierto: este se pregunta cuando se cierre
    current = ip;
    log(tr('{0} ({1}) pide acceso: responde el aviso que apareció en el PC.', ip, device));
    child = ask(ip, device, (ok) => {
      current = null; child = null;
      if (ok === true) {
        try {
          addDevice(configPath, ip);
          state.delete(ip);
          log(tr('Dispositivo autorizado: {0}. Quedó guardado en config.json.', ip));
        } catch (e) {
          state.delete(ip);
          log(tr('No se pudo guardar {0} en config.json: {1}', ip, e.message));
        }
      } else if (ok === false) {
        state.set(ip, 'rechazado');
        log(tr('Dispositivo rechazado: {0}. No se volverá a preguntar hasta reiniciar el panel.', ip));
      } else {
        state.delete(ip); // el aviso se cerró sin respuesta: se vuelve a preguntar en el siguiente intento
      }
    }, tr);
    return 'pendiente';
  }

  return { request, pending: () => current, close: () => { if (child) child.kill(); } };
}

module.exports = { createApprovals, addDevice, removeDevice, describeDevice, askOnPc };
