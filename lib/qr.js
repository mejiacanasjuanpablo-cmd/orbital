'use strict';
// Generador de códigos QR sin dependencias (modo byte, corrección de errores nivel M, versiones 1 a 10).
// Sigue la norma ISO/IEC 18004. Uso desde la consola:  node lib/qr.js "texto"   → dibuja el QR en la terminal.

// ---------- Aritmética en GF(256) y Reed-Solomon
function gfMul(x, y) {
  let z = 0;
  for (let i = 7; i >= 0; i--) {
    z = (z << 1) ^ ((z >>> 7) * 0x11d);
    z ^= ((y >>> i) & 1) * x;
  }
  return z & 0xff;
}
function rsDivisor(degree) {
  const result = new Array(degree).fill(0);
  result[degree - 1] = 1;
  let root = 1;
  for (let i = 0; i < degree; i++) {
    for (let j = 0; j < result.length; j++) {
      result[j] = gfMul(result[j], root);
      if (j + 1 < result.length) result[j] ^= result[j + 1];
    }
    root = gfMul(root, 0x02);
  }
  return result;
}
function rsRemainder(data, divisor) {
  const result = divisor.map(() => 0);
  for (const b of data) {
    const factor = b ^ result.shift();
    result.push(0);
    divisor.forEach((coef, i) => { result[i] ^= gfMul(coef, factor); });
  }
  return result;
}

// ---------- Tablas para el nivel M (índice = versión)
const ECC_PER_BLOCK_M = [-1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26];
const NUM_BLOCKS_M = [-1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5];
const MAX_VERSION = 10;
const FORMAT_M = 0; // bits de formato del nivel M (L=1, M=0, Q=3, H=2)

function numRawDataModules(ver) {
  let result = (16 * ver + 128) * ver + 64;
  if (ver >= 2) {
    const numAlign = Math.floor(ver / 7) + 2;
    result -= (25 * numAlign - 10) * numAlign - 55;
    if (ver >= 7) result -= 36;
  }
  return result;
}
const numDataCodewords = (ver) => Math.floor(numRawDataModules(ver) / 8) - ECC_PER_BLOCK_M[ver] * NUM_BLOCKS_M[ver];

function alignmentPositions(ver) {
  if (ver === 1) return [];
  const numAlign = Math.floor(ver / 7) + 2;
  const step = Math.floor((ver * 8 + numAlign * 3 + 5) / (numAlign * 4 - 4)) * 2;
  const result = [6];
  for (let pos = ver * 4 + 10; result.length < numAlign; pos -= step) result.splice(1, 0, pos);
  return result;
}

const getBit = (x, i) => ((x >>> i) & 1) !== 0;

// 15 bits de formato (nivel de corrección + máscara) con su código BCH.
function formatBits(eccBits, mask) {
  const data = (eccBits << 3) | mask;
  let rem = data;
  for (let i = 0; i < 10; i++) rem = (rem << 1) ^ ((rem >>> 9) * 0x537);
  return ((data << 10) | rem) ^ 0x5412;
}
// 18 bits de versión (solo versiones 7+).
function versionBits(ver) {
  let rem = ver;
  for (let i = 0; i < 12; i++) rem = (rem << 1) ^ ((rem >>> 11) * 0x1f25);
  return (ver << 12) | rem;
}

// ---------- Codificación de los datos
function encodeData(bytes) {
  let ver = 1;
  for (; ver <= MAX_VERSION; ver++) {
    const ccBits = ver <= 9 ? 8 : 16;
    if (4 + ccBits + bytes.length * 8 <= numDataCodewords(ver) * 8) break;
  }
  if (ver > MAX_VERSION) throw new Error('texto demasiado largo para el QR');
  const bits = [];
  const push = (val, len) => { for (let i = len - 1; i >= 0; i--) bits.push((val >>> i) & 1); };
  push(0x4, 4);                       // modo byte
  push(bytes.length, ver <= 9 ? 8 : 16);
  for (const b of bytes) push(b, 8);
  const capacity = numDataCodewords(ver) * 8;
  push(0, Math.min(4, capacity - bits.length));        // terminador
  push(0, (8 - (bits.length % 8)) % 8);                 // completar el byte
  for (let pad = 0xec; bits.length < capacity; pad ^= 0xec ^ 0x11) push(pad, 8);
  const data = [];
  for (let i = 0; i < bits.length; i += 8) data.push(parseInt(bits.slice(i, i + 8).join(''), 2));
  return { ver, data };
}

// Divide en bloques, añade la corrección de errores e intercala.
function addEccAndInterleave(ver, data) {
  const numBlocks = NUM_BLOCKS_M[ver];
  const blockEcc = ECC_PER_BLOCK_M[ver];
  const rawCodewords = Math.floor(numRawDataModules(ver) / 8);
  const numShort = numBlocks - (rawCodewords % numBlocks);
  const shortLen = Math.floor(rawCodewords / numBlocks);
  const divisor = rsDivisor(blockEcc);
  const blocks = [];
  for (let i = 0, k = 0; i < numBlocks; i++) {
    const len = shortLen - blockEcc + (i < numShort ? 0 : 1);
    const dat = data.slice(k, k + len);
    k += len;
    blocks.push({ dat, ecc: rsRemainder(dat, divisor) });
  }
  const result = [];
  for (let i = 0; i <= shortLen - blockEcc; i++) for (const b of blocks) if (i < b.dat.length) result.push(b.dat[i]);
  for (let i = 0; i < blockEcc; i++) for (const b of blocks) result.push(b.ecc[i]);
  return result;
}

// ---------- Matriz
function buildMatrix(ver, codewords) {
  const size = ver * 4 + 17;
  const mod = Array.from({ length: size }, () => new Array(size).fill(false));
  const fn = Array.from({ length: size }, () => new Array(size).fill(false));
  const setF = (x, y, dark) => { mod[y][x] = dark; fn[y][x] = true; };

  // Patrones de sincronización, de búsqueda (esquinas) y de alineación
  for (let i = 0; i < size; i++) { setF(6, i, i % 2 === 0); setF(i, 6, i % 2 === 0); }
  for (const [cx, cy] of [[3, 3], [size - 4, 3], [3, size - 4]]) {
    for (let dy = -4; dy <= 4; dy++) for (let dx = -4; dx <= 4; dx++) {
      const x = cx + dx, y = cy + dy;
      if (x >= 0 && x < size && y >= 0 && y < size) { const d = Math.max(Math.abs(dx), Math.abs(dy)); setF(x, y, d !== 2 && d !== 4); }
    }
  }
  const al = alignmentPositions(ver);
  for (let i = 0; i < al.length; i++) for (let j = 0; j < al.length; j++) {
    if ((i === 0 && j === 0) || (i === 0 && j === al.length - 1) || (i === al.length - 1 && j === 0)) continue;
    for (let dy = -2; dy <= 2; dy++) for (let dx = -2; dx <= 2; dx++) setF(al[i] + dx, al[j] + dy, Math.max(Math.abs(dx), Math.abs(dy)) !== 1);
  }

  const drawFormat = (mask) => {
    const bits = formatBits(FORMAT_M, mask);
    for (let i = 0; i <= 5; i++) setF(8, i, getBit(bits, i));
    setF(8, 7, getBit(bits, 6));
    setF(8, 8, getBit(bits, 7));
    setF(7, 8, getBit(bits, 8));
    for (let i = 9; i < 15; i++) setF(14 - i, 8, getBit(bits, i));
    for (let i = 0; i < 8; i++) setF(size - 1 - i, 8, getBit(bits, i));
    for (let i = 8; i < 15; i++) setF(8, size - 15 + i, getBit(bits, i));
    setF(8, size - 8, true); // módulo oscuro fijo
  };
  drawFormat(0); // reserva las zonas de formato
  if (ver >= 7) {
    const bits = versionBits(ver);
    for (let i = 0; i < 18; i++) {
      const a = size - 11 + (i % 3), b = Math.floor(i / 3);
      setF(a, b, getBit(bits, i)); setF(b, a, getBit(bits, i));
    }
  }

  // Datos en zigzag, de dos en dos columnas, de derecha a izquierda
  let i = 0;
  for (let right = size - 1; right >= 1; right -= 2) {
    if (right === 6) right = 5;
    for (let vert = 0; vert < size; vert++) {
      for (let j = 0; j < 2; j++) {
        const x = right - j;
        const upward = ((right + 1) & 2) === 0;
        const y = upward ? size - 1 - vert : vert;
        if (!fn[y][x] && i < codewords.length * 8) { mod[y][x] = getBit(codewords[i >>> 3], 7 - (i & 7)); i++; }
      }
    }
  }

  const applyMask = (m) => {
    for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
      if (fn[y][x]) continue;
      let inv;
      switch (m) {
        case 0: inv = (x + y) % 2 === 0; break;
        case 1: inv = y % 2 === 0; break;
        case 2: inv = x % 3 === 0; break;
        case 3: inv = (x + y) % 3 === 0; break;
        case 4: inv = (Math.floor(x / 3) + Math.floor(y / 2)) % 2 === 0; break;
        case 5: inv = ((x * y) % 2) + ((x * y) % 3) === 0; break;
        case 6: inv = (((x * y) % 2) + ((x * y) % 3)) % 2 === 0; break;
        default: inv = (((x + y) % 2) + ((x * y) % 3)) % 2 === 0;
      }
      if (inv) mod[y][x] = !mod[y][x];
    }
  };
  // Penalización simplificada (reglas 1, 2 y 4 de la norma) para elegir la máscara más legible.
  const penalty = () => {
    let score = 0, dark = 0;
    for (let a = 0; a < size; a++) {
      for (const horiz of [true, false]) {
        let run = 1;
        for (let b = 1; b < size; b++) {
          const cur = horiz ? mod[a][b] : mod[b][a], prev = horiz ? mod[a][b - 1] : mod[b - 1][a];
          if (cur === prev) { run++; if (run === 5) score += 3; else if (run > 5) score++; } else run = 1;
        }
      }
    }
    for (let y = 0; y < size - 1; y++) for (let x = 0; x < size - 1; x++) {
      const c = mod[y][x];
      if (c === mod[y][x + 1] && c === mod[y + 1][x] && c === mod[y + 1][x + 1]) score += 3;
    }
    for (const row of mod) for (const c of row) if (c) dark++;
    const total = size * size;
    score += (Math.ceil(Math.abs(dark * 20 - total * 10) / total) - 1) * 10;
    return score;
  };
  let best = 0, bestScore = Infinity;
  for (let m = 0; m < 8; m++) {
    applyMask(m); drawFormat(m);
    const s = penalty();
    if (s < bestScore) { bestScore = s; best = m; }
    applyMask(m);
  }
  applyMask(best); drawFormat(best);
  return { size, modules: mod, mask: best };
}

// Devuelve la matriz del QR: modules[fila][columna] = true si el módulo es oscuro.
function encode(text) {
  const { ver, data } = encodeData([...Buffer.from(String(text), 'utf8')]);
  const qr = buildMatrix(ver, addEccAndInterleave(ver, data));
  return { version: ver, ...qr };
}

// Dibuja el QR para la consola con medios bloques (dos filas por línea), negro sobre blanco y margen de 4 módulos.
function toTerminal(qr, { margin = 4, color = true } = {}) {
  const n = qr.size + margin * 2;
  const dark = (x, y) => { x -= margin; y -= margin; return x >= 0 && y >= 0 && x < qr.size && y < qr.size && qr.modules[y][x]; };
  const lines = [];
  for (let y = 0; y < n; y += 2) {
    let line = '';
    for (let x = 0; x < n; x++) {
      const top = dark(x, y), bottom = y + 1 < n && dark(x, y + 1);
      line += top && bottom ? '█' : top ? '▀' : bottom ? '▄' : ' ';
    }
    lines.push(color ? `\x1b[30;107m${line}\x1b[0m` : line);
  }
  return lines.join('\n');
}

module.exports = { encode, toTerminal, _test: { rsRemainder, rsDivisor, formatBits, versionBits, alignmentPositions, numDataCodewords, encodeData, addEccAndInterleave } };

if (require.main === module) {
  const text = process.argv[2];
  if (!text) { console.error('Uso: node lib/qr.js "texto"'); process.exit(1); }
  process.stdout.write(toTerminal(encode(text)) + '\n');
}
