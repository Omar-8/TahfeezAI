// The Mushaf's own calligraphy of each surah's name, for the surah list:
// the surah-name decoration on the page where each surah starts, its
// outline taken from the Quran Engine page corpus (through the real
// engine, as verify_all_pages_structural.mjs loads it) and written as an
// SVG path in its own box. Licence: the page corpus's (CC BY 4.0, and the
// King Fahd Complex's usage rights) — docs/THIRD_PARTY_RESOURCES.md.
//
// Usage (from the repo root):
//   node tool/quran_engine/extract_surah_names.mjs
// writes assets/quran/surah_names/surah_names.json.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const OUT = path.join(ROOT, 'assets/quran/surah_names/surah_names.json');

const sandbox = {
  TextEncoder, TextDecoder, Uint8Array, Uint32Array, Float32Array, DataView,
  WebAssembly, Path2D: class {}, console,
};
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(path.join(ROOT, 'web/quran_engine/qvp.js'), 'utf8'), sandbox);
const engine = await sandbox.QVP.QvpEngine.init(
  fs.readFileSync(path.join(ROOT, 'web/quran_engine/qvp_ffi.wasm')),
);

const num = (v) => {
  const s = (Math.round(v * 10) / 10).toString();
  return s === '-0' ? '0' : s;
};

const names = {};
for (let p = 1; p <= 604; p++) {
  const file = path.join(ROOT, `assets/quran/quran_engine/pages/${String(p).padStart(3, '0')}.qvp`);
  const page = engine.loadPage(new Uint8Array(fs.readFileSync(file)));
  for (const d of page.decos) {
    if (d.kind !== 1 || names[d.surah]) continue; // surah name, first seen
    const parts = [];
    let evenOdd = false;
    for (let i = d.firstPath; i < d.firstPath + d.nPaths; i++) {
      evenOdd ||= page.pathEvenOdd(i);
      const t = page.table, ops = page.ops, pts = page.pts;
      let o = t[i * 8];
      const oe = o + t[i * 8 + 1];
      let k = t[i * 8 + 2];
      const x = (j) => num(pts[j] - d.x0), y = (j) => num(pts[j] - d.y0);
      for (; o < oe; o++) {
        switch (ops[o]) {
          case 0: parts.push(`M${x(k)} ${y(k + 1)}`); k += 2; break;
          case 1: parts.push(`L${x(k)} ${y(k + 1)}`); k += 2; break;
          case 2: parts.push(`Q${x(k)} ${y(k + 1)} ${x(k + 2)} ${y(k + 3)}`); k += 4; break;
          case 3: parts.push(`C${x(k)} ${y(k + 1)} ${x(k + 2)} ${y(k + 3)} ${x(k + 4)} ${y(k + 5)}`); k += 6; break;
          case 4: parts.push('Z'); break;
        }
      }
    }
    names[d.surah] = {
      page: p,
      w: Number(num(d.x1 - d.x0)),
      h: Number(num(d.y1 - d.y0)),
      evenOdd,
      d: parts.join(''),
    };
  }
  page.free();
}

// «سورة» before each name: the same artwork in all 114 (its size varying
// a little, pages 1–2 smaller). Its outlines are taken from An-Nas's, where
// it stands apart from the name, and removed from every name where one
// matches in place (from the right edge) and size; the name's box is then
// trimmed to what is left.
const contours = (d) =>
  d.match(/M[^M]*/g).map((c) => {
    const n = c.match(/-?[\d.]+/g).map(Number);
    const xs = n.filter((_, i) => i % 2 === 0), ys = n.filter((_, i) => i % 2 === 1);
    return { c, x0: Math.min(...xs), y0: Math.min(...ys), x1: Math.max(...xs), y1: Math.max(...ys) };
  });
const ref = contours(names[114].d);
const refRight = Math.max(...ref.map((c) => c.x1));
const prefix = ref
  .filter((c) => refRight - c.x0 <= 35.8 && refRight - c.x1 <= 32)
  .map((c) => ({ a: refRight - c.x1, b: refRight - c.x0, h: c.y1 - c.y0 }));
for (const [surah, art] of Object.entries(names)) {
  const cs = contours(art.d);
  const right = Math.max(...cs.map((c) => c.x1));
  // A looser match only where the close one misses an outline (Ibrahim's
  // «سورة» is drawn a little differently).
  let best = null;
  for (const tol of [0.9, 1.6, 2.4]) {
    for (let k = 0.75; k <= 1.1; k += 0.01) {
      const hits = new Set();
      for (const p of prefix) {
        const i = cs.findIndex(
          (c, j) =>
            !hits.has(j) &&
            Math.abs(right - c.x1 - p.a * k) < tol &&
            Math.abs(right - c.x0 - p.b * k) < tol &&
            Math.abs(c.y1 - c.y0 - p.h * k) < tol,
        );
        if (i >= 0) hits.add(i);
      }
      if (!best || hits.size > best.size) best = hits;
    }
    if (best.size === prefix.length) break;
  }
  if (best.size < prefix.length) {
    console.error(`surah ${surah}: «سورة» not found (${best.size}/${prefix.length})`);
    process.exit(1);
  }
  const kept = cs.filter((_, i) => !best.has(i));
  const x0 = Math.min(...kept.map((c) => c.x0)), x1 = Math.max(...kept.map((c) => c.x1));
  // Moved left by x0 (every x coordinate: the even numbers of a command).
  const moved = kept.map(({ c }) => {
    let i = 0;
    return c.replace(/[MLQCZ]|-?[\d.]+/g, (t) => {
      if (/[MLQCZ]/.test(t)) { i = 0; return t; }
      const v = i++ % 2 === 0 ? Number(t) - x0 : Number(t);
      return num(v);
    });
  });
  art.d = moved.join('');
  art.w = Number(num(x1 - x0));
}

const missing = [];
for (let s = 1; s <= 114; s++) if (!names[s]) missing.push(s);
if (missing.length) {
  console.error(`No surah-name decoration for surahs ${missing.join(', ')}`);
  process.exit(1);
}
fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, JSON.stringify({ source: 'quran-engine-pages-hafs-kfgqpc v0.3.0', names }));
console.log(`114 surah names → ${path.relative(ROOT, OUT)} (${fs.statSync(OUT).size} bytes)`);
