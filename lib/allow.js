'use strict';
// Decide si una conexión puede usar el panel.
// - El propio PC (127.0.0.1, o su IP de red en modo Wi-Fi) siempre puede: de ahí llega también el túnel USB.
// - Desde la red solo pueden los dispositivos de config.json → "wifi": { "dispositivos": ["192.168.x.x"] }.
//   Si la lista está vacía o no existe, no entra nadie por Wi-Fi.

const PRIVATE = /^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/;

const normalize = (addr) => String(addr || '').replace(/^::ffff:/, '');

function isAllowed(remote, lanIp, devices) {
  const a = normalize(remote);
  if (a === '127.0.0.1' || a === '::1') return true;
  if (lanIp && a === lanIp) return true;
  if (!PRIVATE.test(a)) return false;
  return Array.isArray(devices) && devices.map(String).map((d) => d.trim()).includes(a);
}

const isPrivate = (addr) => PRIVATE.test(normalize(addr));

module.exports = { isAllowed, isPrivate, normalize };
