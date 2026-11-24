'use strict';
// Agenda de la página Calendario: lee un calendario desde su enlace privado en formato iCal (.ics), por ejemplo la
// «Dirección secreta en formato iCal» de Google Calendar, y da los eventos de unos días.
// Sin dependencias. Entiende lo que usan Google Calendar, Outlook e iCloud: eventos de todo el día y con hora, zonas
// horarias, repeticiones (RRULE diaria, semanal, mensual y anual), fechas quitadas (EXDATE) y repeticiones movidas o
// canceladas (RECURRENCE-ID).

const DIA = 86400000;
const DIAS = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA']; // en el orden de getUTCDay()

// ---------- Lectura del archivo .ics

// Las líneas largas siguen en la siguiente, que empieza con un espacio o un tabulador.
const lineas = (texto) => texto.replace(/\r\n?/g, '\n').replace(/\n[ \t]/g, '').split('\n');

// NOMBRE;PARAM=valor;PARAM="valor:con:dos puntos":VALOR
function propiedad(linea) {
  let i = 0, comillas = false;
  for (; i < linea.length; i++) {
    if (linea[i] === '"') comillas = !comillas;
    else if (linea[i] === ':' && !comillas) break;
  }
  if (i >= linea.length) return null;
  const [nombre, ...partes] = linea.slice(0, i).split(';');
  const params = {};
  for (const p of partes) { const j = p.indexOf('='); if (j > 0) params[p.slice(0, j).toUpperCase()] = p.slice(j + 1).replace(/^"|"$/g, ''); }
  return { nombre: nombre.toUpperCase(), params, valor: linea.slice(i + 1) };
}

const desescapar = (v) => v.replace(/\\([\\;,nN])/g, (m, c) => (c === 'n' || c === 'N' ? '\n' : c));

// Zonas horarias con nombre de Windows (las usa Outlook); Google e iCloud usan las de siempre (America/Bogota…).
const ZONAS_WINDOWS = {
  'SA Pacific Standard Time': 'America/Bogota', 'Eastern Standard Time': 'America/New_York', 'Central Standard Time': 'America/Chicago',
  'Mountain Standard Time': 'America/Denver', 'Pacific Standard Time': 'America/Los_Angeles', 'Central Standard Time (Mexico)': 'America/Mexico_City',
  'Venezuela Standard Time': 'America/Caracas', 'SA Western Standard Time': 'America/La_Paz', 'Pacific SA Standard Time': 'America/Santiago',
  'Argentina Standard Time': 'America/Argentina/Buenos_Aires', 'E. South America Standard Time': 'America/Sao_Paulo', 'Romance Standard Time': 'Europe/Paris',
  'W. Europe Standard Time': 'Europe/Berlin', 'GMT Standard Time': 'Europe/London', 'UTC': 'UTC', 'Coordinated Universal Time': 'UTC',
};
const zonasVistas = new Map();
function zona(tzid) {
  if (!tzid) return null; // sin zona: la hora del PC
  if (zonasVistas.has(tzid)) return zonasVistas.get(tzid);
  let z = null;
  for (const candidata of [tzid, ZONAS_WINDOWS[tzid], tzid.replace(/^\/?[^/]+\.[a-z]+\/[^/]+\//i, '')]) {
    if (!candidata) continue;
    try { new Intl.DateTimeFormat('en-US', { timeZone: candidata }); z = candidata; break; } catch {}
  }
  zonasVistas.set(tzid, z);
  return z;
}

// Fecha de una propiedad: { y, m, d, dia: true } (todo el día) o { y, m, d, h, mi, s, zona } ('UTC', una zona o null).
function fecha(valor, params = {}) {
  const m = /^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$/.exec(String(valor).trim());
  if (!m) return null;
  const f = { y: +m[1], m: +m[2], d: +m[3] };
  if (!m[4] || params.VALUE === 'DATE') return { ...f, dia: true };
  return { ...f, h: +m[4], mi: +m[5], s: +(m[6] || 0), zona: m[7] ? 'UTC' : zona(params.TZID) };
}

function duracion(v) {
  const m = /^[+]?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/.exec(String(v).trim());
  if (!m) return null;
  return { dias: (+m[1] || 0) * 7 + (+m[2] || 0), ms: ((+m[3] || 0) * 3600 + (+m[4] || 0) * 60 + (+m[5] || 0)) * 1000 };
}

function regla(v) {
  const r = {};
  for (const par of String(v).split(';')) { const [k, x] = par.split('='); if (k && x != null) r[k.trim().toUpperCase()] = x.trim(); }
  if (!['DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY'].includes(r.FREQ)) return null; // por horas o minutos: no se repite
  return {
    freq: r.FREQ,
    intervalo: Math.max(1, Math.floor(+r.INTERVAL) || 1),
    cuenta: r.COUNT ? Math.max(0, Math.floor(+r.COUNT)) : null,
    hasta: r.UNTIL ? fecha(r.UNTIL) : null,
    porDia: (r.BYDAY || '').split(',').map((x) => /^([+-]?\d+)?(SU|MO|TU|WE|TH|FR|SA)$/.exec(x.trim().toUpperCase()))
      .filter(Boolean).map((x) => ({ n: x[1] ? +x[1] : 0, dia: DIAS.indexOf(x[2]) })),
    porDiaMes: (r.BYMONTHDAY || '').split(',').map(Number).filter((x) => x && Math.abs(x) <= 31),
    porMes: (r.BYMONTH || '').split(',').map(Number).filter((x) => x >= 1 && x <= 12),
  };
}

// Lee el texto de un .ics: { nombre, eventos }. Lo que no entiende lo salta.
function leerIcs(texto) {
  const eventos = [], pila = [];
  let ev = null, nombre = '';
  for (const l of lineas(String(texto))) {
    const p = propiedad(l);
    if (!p) continue;
    if (p.nombre === 'BEGIN') {
      pila.push(p.valor.trim().toUpperCase());
      if (pila[pila.length - 1] === 'VEVENT') ev = { exdates: [] };
      continue;
    }
    if (p.nombre === 'END') {
      if (pila.pop() === 'VEVENT' && ev) { if (ev.inicio) eventos.push(ev); ev = null; }
      continue;
    }
    if (!ev) { if (p.nombre === 'X-WR-CALNAME' && pila.length === 1) nombre = desescapar(p.valor).trim(); continue; }
    if (pila[pila.length - 1] !== 'VEVENT') continue; // por ejemplo, los recordatorios (VALARM) de un evento
    switch (p.nombre) {
      case 'UID': ev.uid = p.valor.trim(); break;
      case 'SUMMARY': ev.titulo = desescapar(p.valor).trim(); break;
      case 'LOCATION': ev.lugar = desescapar(p.valor).trim(); break;
      case 'STATUS': ev.estado = p.valor.trim().toUpperCase(); break;
      case 'DTSTART': ev.inicio = fecha(p.valor, p.params); break;
      case 'DTEND': ev.fin = fecha(p.valor, p.params); break;
      case 'DURATION': ev.duracion = duracion(p.valor); break;
      case 'RRULE': ev.regla = regla(p.valor); break;
      case 'EXDATE': for (const v of p.valor.split(',')) { const f = fecha(v, p.params); if (f) ev.exdates.push(f); } break;
      case 'RECURRENCE-ID': ev.recurrencia = fecha(p.valor, p.params); break;
    }
  }
  return { nombre, eventos };
}

// ---------- Fechas

// Los días se cuentan como números (días desde 1970) para sumar sin líos de horario.
const diaNum = (y, m, d) => Date.UTC(y, m - 1, d) / DIA;
const deNum = (n) => { const x = new Date(n * DIA); return { y: x.getUTCFullYear(), m: x.getUTCMonth() + 1, d: x.getUTCDate() }; };
const diaSemana = (n) => new Date(n * DIA).getUTCDay();
const diasDelMes = (y, m) => new Date(Date.UTC(y, m, 0)).getUTCDate();
const iso = (n) => { const f = deNum(n); return `${f.y}-${String(f.m).padStart(2, '0')}-${String(f.d).padStart(2, '0')}`; };

// Cuántos minutos va la zona por delante de UTC en ese instante.
const formatos = new Map();
function desfase(ms, z) {
  let f = formatos.get(z);
  if (!f) {
    f = new Intl.DateTimeFormat('en-US', { timeZone: z, hourCycle: 'h23', year: 'numeric', month: 'numeric', day: 'numeric', hour: 'numeric', minute: 'numeric', second: 'numeric' });
    formatos.set(z, f);
  }
  const p = Object.fromEntries(f.formatToParts(new Date(ms)).map((x) => [x.type, x.value]));
  return (Date.UTC(+p.year, +p.month - 1, +p.day, +p.hour, +p.minute, +p.second) - Math.floor(ms / 1000) * 1000) / 60000;
}

// Instante (ms) de una fecha con hora.
function instante(f) {
  const pared = Date.UTC(f.y, f.m - 1, f.d, f.h, f.mi, f.s);
  if (f.zona === 'UTC') return pared;
  if (!f.zona) return new Date(f.y, f.m - 1, f.d, f.h, f.mi, f.s).getTime(); // la hora del PC
  const primero = pared - desfase(pared, f.zona) * 60000;
  return pared - desfase(primero, f.zona) * 60000; // segunda vuelta, por los cambios de horario
}

// Medianoche (hora del PC) del día n.
const medianoche = (n) => { const f = deNum(n); return new Date(f.y, f.m - 1, f.d).getTime(); };

// ---------- Repeticiones

// Los días del mes que cumple la regla (o el día fijo, si no dice cuáles), en orden.
function diasEnMes(y, m, r, diaFijo) {
  const total = diasDelMes(y, m), primero = diaNum(y, m, 1);
  let lista = [];
  if (r.porDiaMes.length) lista = r.porDiaMes.map((d) => (d > 0 ? d : total + d + 1)).filter((d) => d >= 1 && d <= total);
  else if (r.porDia.length) {
    for (const { n, dia } of r.porDia) {
      const todos = [];
      for (let d = 1; d <= total; d++) if (diaSemana(primero + d - 1) === dia) todos.push(d);
      if (!n) lista.push(...todos);
      else { const x = n > 0 ? todos[n - 1] : todos[todos.length + n]; if (x) lista.push(x); }
    }
  } else if (diaFijo && diaFijo <= total) lista = [diaFijo];
  return [...new Set(lista)].sort((a, b) => a - b).map((d) => primero + d - 1);
}

// Los días (números) de cada repetición, en orden, desde el del primer evento y sin pasar de 'limite'.
function* diasDeRegla(inicio, r, limite) {
  const s = deNum(inicio);
  if (r.freq === 'DAILY') {
    for (let n = inicio; n <= limite; n += r.intervalo) yield n;
  } else if (r.freq === 'WEEKLY') {
    const orden = [...new Set((r.porDia.length ? r.porDia.map((x) => x.dia) : [diaSemana(inicio)]).map((d) => (d + 6) % 7))].sort((a, b) => a - b);
    for (let lunes = inicio - ((diaSemana(inicio) + 6) % 7); lunes <= limite; lunes += 7 * r.intervalo) {
      for (const o of orden) { const n = lunes + o; if (n >= inicio && n <= limite) yield n; }
    }
  } else if (r.freq === 'MONTHLY') {
    for (let k = 0; ; k += r.intervalo) {
      const total = s.m - 1 + k, y = s.y + Math.floor(total / 12), m = (total % 12) + 1;
      if (diaNum(y, m, 1) > limite) return;
      for (const n of diasEnMes(y, m, r, s.d)) if (n >= inicio && n <= limite) yield n;
    }
  } else if (r.freq === 'YEARLY') {
    const meses = r.porMes.length ? [...r.porMes].sort((a, b) => a - b) : [s.m];
    const diaFijo = r.porDia.length || r.porDiaMes.length ? null : s.d;
    for (let y = s.y; diaNum(y, 1, 1) <= limite; y += r.intervalo) {
      for (const m of meses) for (const n of diasEnMes(y, m, r, diaFijo)) if (n >= inicio && n <= limite) yield n;
    }
  }
}

// Las veces que ocurre un evento entre dos instantes: [{ inicio, fin }] en ms, o { dia, dias } si es de todo el día.
function ocurrencias(ev, desde, hasta, quitar) {
  const todoElDia = !!ev.inicio.dia;
  const dia0 = diaNum(ev.inicio.y, ev.inicio.m, ev.inicio.d);
  let dias = 1, ms = 0;
  if (todoElDia) {
    if (ev.fin && ev.fin.dia) dias = Math.max(1, diaNum(ev.fin.y, ev.fin.m, ev.fin.d) - dia0);
    else if (ev.duracion) dias = Math.max(1, ev.duracion.dias);
  } else if (ev.fin && !ev.fin.dia) ms = Math.max(0, instante(ev.fin) - instante(ev.inicio));
  else if (ev.duracion) ms = ev.duracion.dias * DIA + ev.duracion.ms;
  const una = (n) => (todoElDia
    ? { dia: iso(n), dias, ini: medianoche(n), fn: medianoche(n + dias) }
    : (() => { const f = deNum(n); const i = instante({ ...ev.inicio, ...f }); return { inicio: i, fin: i + ms, ini: i, fn: Math.max(i + ms, i + 1) }; })());
  const r = ev.regla;
  if (!r) { const o = una(dia0); return o.ini < hasta && o.fn > desde ? [o] : []; }

  const salida = [];
  // Los días muy anteriores a lo pedido solo se cuentan (para COUNT), sin calcular su hora: un evento diario de hace años
  // pasa por miles de días.
  const limiteDia = Math.ceil(hasta / DIA) + 2;
  const desdeDia = Math.floor(desde / DIA) - 2 - (todoElDia ? dias : Math.ceil(ms / DIA));
  const hastaMs = r.hasta && !r.hasta.dia ? instante(r.hasta) : null;
  const hastaDia = r.hasta ? (r.hasta.dia ? diaNum(r.hasta.y, r.hasta.m, r.hasta.d) : Math.floor(hastaMs / DIA) + 1) : Infinity;
  let cuenta = 0, vueltas = 0;
  for (const n of diasDeRegla(dia0, r, limiteDia)) {
    if (++vueltas > 200000) break;
    if (r.cuenta != null && ++cuenta > r.cuenta) break;
    if (n > hastaDia) break;
    if (n < desdeDia) continue;
    const o = una(n);
    if (hastaMs != null && o.ini > hastaMs) break;
    if (o.ini >= hasta) break;
    if (o.fn <= desde || quitar(o, n)) continue;
    salida.push(o);
  }
  return salida;
}

// Los eventos de un calendario (lo que devuelve leerIcs) entre dos instantes, ordenados. Cada uno:
// { titulo, lugar, inicio, fin } (ms) o { titulo, lugar, dia: 'AAAA-MM-DD', dias } si es de todo el día.
function eventosEntre(cal, desde, hasta) {
  const cambios = new Map(); // UID → repeticiones movidas o canceladas
  for (const ev of cal.eventos) if (ev.recurrencia && ev.uid) { if (!cambios.has(ev.uid)) cambios.set(ev.uid, []); cambios.get(ev.uid).push(ev); }
  const clave = (f) => (f.dia ? 'd' + diaNum(f.y, f.m, f.d) : 't' + instante(f));
  const salida = [];
  for (const ev of cal.eventos) {
    if (ev.estado === 'CANCELLED') continue;
    if (ev.recurrencia) {
      // una repetición movida: se muestra en su nueva fecha (la original se quita abajo)
      for (const o of ocurrencias({ ...ev, regla: null }, desde, hasta, () => false)) salida.push({ ev, o });
      continue;
    }
    const fuera = new Set([...ev.exdates, ...(ev.regla && cambios.get(ev.uid) || []).map((c) => c.recurrencia)].filter(Boolean).map(clave));
    const quitar = (o, n) => fuera.has(o.dia ? 'd' + n : 't' + o.inicio) || fuera.has('d' + n);
    for (const o of ocurrencias(ev, desde, hasta, quitar)) salida.push({ ev, o });
  }
  return salida
    .map(({ ev, o }) => ({ titulo: ev.titulo || '', lugar: ev.lugar || '', ...(o.dia ? { dia: o.dia, dias: o.dias } : { inicio: o.inicio, fin: o.fin }), orden: o.ini }))
    .sort((a, b) => a.orden - b.orden || (a.dia ? -1 : 1) - (b.dia ? -1 : 1) || a.titulo.localeCompare(b.titulo))
    .map(({ orden, ...e }) => e);
}

// ---------- Enlace del calendario

// El enlace que se puede guardar: https (o webcal, que es lo mismo) y nada más. Devuelve el enlace limpio o null.
function enlaceValido(texto) {
  let s = String(texto || '').trim();
  if (/^webcals?:\/\//i.test(s)) s = s.replace(/^webcals?:/i, 'https:');
  if (s.length > 2000) return null;
  try { const u = new URL(s); return u.protocol === 'https:' && u.hostname ? u.toString() : null; } catch { return null; }
}

// Descarga y lee el calendario. Lanza un error con un motivo corto (nunca con el enlace, que es privado).
async function descargarIcs(url) {
  let r;
  try { r = await fetch(url, { signal: AbortSignal.timeout(20000), headers: { 'User-Agent': 'Orbital/1.0', Accept: 'text/calendar, */*' } }); }
  catch (e) { const err = new Error(e.name === 'TimeoutError' ? 'tiempo agotado' : 'sin conexión'); err.motivo = err.message; throw err; }
  if (!r.ok) { const err = new Error(`HTTP ${r.status}`); err.motivo = r.status === 404 || r.status === 403 ? 'enlace no válido' : err.message; throw err; }
  const texto = await r.text();
  if (texto.length > 30 * 1024 * 1024 || !/BEGIN:VCALENDAR/i.test(texto.slice(0, 4000))) {
    const err = new Error('no es un calendario'); err.motivo = err.message; throw err;
  }
  return leerIcs(texto);
}

module.exports = { leerIcs, eventosEntre, enlaceValido, descargarIcs, instante, fecha };
