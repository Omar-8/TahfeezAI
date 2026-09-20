// Structural validation of the full 604-page Quran Engine corpus, using
// the REAL compiled engine (the exact `qvp_ffi.wasm` binary Web ships,
// driven through the real `qvp.js` wrapper) — not a hand-rolled `.qvp`
// binary-format parser. This is what makes "the engine loads it, geometry
// exists, no exception" a real, verified claim rather than a check of the
// file header alone.
//
// Runs under plain Node.js (no browser, no Android device needed) because
// `WebAssembly.instantiate` and the small set of JS globals `qvp.js`
// actually touches (`TextEncoder`/`TextDecoder`/typed arrays) are already
// present in Node — `qvp.js`'s own UMD wrapper
// (`(function (global) {...})(typeof window !== 'undefined' ? window :
// globalThis)`) falls back to `globalThis` correctly. `Path2D` is stubbed
// only because `qvp.js`'s `buildPaths()` (a rendering-only step this
// script deliberately never calls) references it at class-definition
// time; the real per-page geometry counts this script checks come from
// `loadPage()`/`qvp_page_info`/`qvp_geometry` directly, not from
// `buildPaths()`.
//
// Usage (from the repo root):
//   node tool/quran_engine/verify_all_pages_structural.mjs
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
  '..',
);
const PAGES_DIR = path.join(REPO_ROOT, 'assets/quran/quran_engine/pages');
const WASM_PATH = path.join(REPO_ROOT, 'web/quran_engine/qvp_ffi.wasm');
const QVP_JS_PATH = path.join(REPO_ROOT, 'web/quran_engine/qvp.js');
const RESULTS_PATH = path.join(
  REPO_ROOT,
  'tool/quran_engine/structural_test_results.json',
);

if (!fs.existsSync(PAGES_DIR)) {
  console.error(
    `${PAGES_DIR} does not exist — run ` +
      '`tool/quran_engine/fetch_page_data.sh --all` first.',
  );
  process.exit(1);
}
if (!fs.existsSync(WASM_PATH) || !fs.existsSync(QVP_JS_PATH)) {
  console.error(
    'web/quran_engine/{qvp_ffi.wasm,qvp.js} not found — run ' +
      '`tool/quran_engine/fetch_web_runtime.sh` first.',
  );
  process.exit(1);
}

const sandbox = {
  globalThis: {},
  TextEncoder,
  TextDecoder,
  Uint8Array,
  Uint32Array,
  Float32Array,
  DataView,
  WebAssembly,
  Path2D: class {},
  console,
};
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(QVP_JS_PATH, 'utf8'), sandbox, {
  filename: QVP_JS_PATH,
});
const QVP = sandbox.QVP;
if (!QVP) throw new Error('QVP did not load from qvp.js');

const engine = await QVP.QvpEngine.init(fs.readFileSync(WASM_PATH));

const results = [];
for (let p = 1; p <= 604; p++) {
  const key = String(p).padStart(3, '0');
  const qvpPath = path.join(PAGES_DIR, `${key}.qvp`);
  try {
    const page = engine.loadPage(new Uint8Array(fs.readFileSync(qvpPath)));
    const ok =
      page.page === p && page.nWords > 0 && page.nLines > 0 && page.nPaths > 0;
    results.push({
      page: p,
      ok,
      reportedPage: page.page,
      nLines: page.nLines,
      nWords: page.nWords,
      nAyahs: page.nAyahs,
      nPaths: page.nPaths,
      nDecos: page.nDecos,
      width: page.width,
      height: page.height,
    });
    page.free();
  } catch (e) {
    results.push({ page: p, ok: false, error: String((e && e.stack) || e) });
  }
}

const failures = results.filter((r) => !r.ok);
console.log(`${results.length - failures.length}/604 pages loaded successfully.`);
if (failures.length) {
  console.log('FAILURES:');
  for (const f of failures) console.log(JSON.stringify(f));
} else {
  console.log('604/604 SUCCESS.');
}

for (const p of [1, 2, 42, 106, 302, 604]) {
  console.log(`page ${p}:`, JSON.stringify(results.find((x) => x.page === p)));
}

fs.writeFileSync(RESULTS_PATH, JSON.stringify(results, null, 2));
process.exit(failures.length ? 1 : 0);
