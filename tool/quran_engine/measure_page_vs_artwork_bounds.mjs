// Real, engine-computed measurement of each representative page's full
// logical page bounds vs its actual artwork/content bounds
// (page.cropBox(T.page())), using the exact same real, compiled
// qvp_ffi.wasm + qvp.js load path tool/quran_engine/
// verify_all_pages_structural.mjs already uses under plain Node.js (no
// browser, no Android device needed -- see that script's own comment for
// why this is a genuine load of the real engine, not a synthetic check).
//
// This does NOT answer the Android maxAspectSlack question (this pinned
// engine build predates that field entirely -- see
// third_party/qvp_flutter/PATCHES.md's provenance note), but cropBox()
// is present at this commit and gives a real, non-fabricated answer to
// "does the page's own logical bounds include blank margin beyond the
// actual printed artwork" -- see the investigation's §4/§10.
//
// Usage: node tool/quran_engine/measure_page_vs_artwork_bounds.mjs
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

const pages = [42, 106, 302, 1, 2, 604];
const results = [];

for (const p of pages) {
  const key = String(p).padStart(3, '0');
  const qvpPath = path.join(PAGES_DIR, `${key}.qvp`);
  const page = engine.loadPage(new Uint8Array(fs.readFileSync(qvpPath)));

  const pageWidth = page.width;
  const pageHeight = page.height;

  // pad: 0 -- the raw artwork extent, no extra breathing room added, so
  // this is the tightest real bounding box the engine reports, not
  // inflated by a margin choice of ours.
  const artwork = page.cropBox(QVP.T.page(), { pad: 0, keepAyahMarks: true });

  const row = {
    page: p,
    reportedPage: page.page,
    pageWidth,
    pageHeight,
    pageAspect: pageWidth / pageHeight,
    artworkX0: artwork.x0,
    artworkY0: artwork.y0,
    artworkX1: artwork.x1,
    artworkY1: artwork.y1,
    artworkWidth: artwork.x1 - artwork.x0,
    artworkHeight: artwork.y1 - artwork.y0,
    artworkNWords: artwork.nWords,
  };
  row.artworkWidthRatio = row.artworkWidth / pageWidth;
  row.artworkHeightRatio = row.artworkHeight / pageHeight;
  row.artworkAspect = row.artworkWidth / row.artworkHeight;
  results.push(row);
  page.free();
}

console.log(
  'page | pageW x pageH (aspect) | artwork bbox (x0,y0)-(x1,y1) | artworkW x artworkH (aspect) | artworkW/pageW | artworkH/pageH',
);
for (const r of results) {
  console.log(
    `${String(r.page).padStart(3)} | ` +
      `${r.pageWidth.toFixed(1)} x ${r.pageHeight.toFixed(1)} (${r.pageAspect.toFixed(4)}) | ` +
      `(${r.artworkX0.toFixed(1)},${r.artworkY0.toFixed(1)})-(${r.artworkX1.toFixed(1)},${r.artworkY1.toFixed(1)}) | ` +
      `${r.artworkWidth.toFixed(1)} x ${r.artworkHeight.toFixed(1)} (${r.artworkAspect.toFixed(4)}) | ` +
      `${(r.artworkWidthRatio * 100).toFixed(1)}% | ` +
      `${(r.artworkHeightRatio * 100).toFixed(1)}%`,
  );
}

fs.writeFileSync(
  path.join(REPO_ROOT, 'tool/quran_engine/page_vs_artwork_bounds.json'),
  JSON.stringify(results, null, 2),
);
