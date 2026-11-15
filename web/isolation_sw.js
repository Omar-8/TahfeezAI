// The web app's service worker (registered by flutter_bootstrap.js):
//
// 1. Cross-origin isolation for hosts that cannot set headers (GitHub
//    Pages): every same-origin response gets COOP/COEP, so the page may use
//    threads — the recitation model (ONNX Runtime Web) runs ~4x faster than
//    real time with them, and slower than real time without. COEP
//    "credentialless", so reciters' audio from other hosts still loads
//    (sent without cookies).
//
// 2. Offline (owner, 2026-11-15): network first — online, every file comes
//    fresh as before (a new version shows at once) and a copy is kept;
//    offline, the kept copy. So everything once opened works without a
//    connection: the app, the Mushaf pages seen, fonts, the recitation
//    model. (The Quran's text and the reader's data are in the browser's
//    own database already.) Partial responses (audio ranges) and other
//    hosts' files are not kept.
const CACHE = 'tahfeez-offline-v1';

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) =>
  event.waitUntil(
    (async () => {
      // Older caches of this worker gone (a new CACHE name).
      for (const name of await caches.keys()) {
        if (name.startsWith('tahfeez-offline-') && name !== CACHE) {
          await caches.delete(name);
        }
      }
      await self.clients.claim();
    })(),
  ),
);

/// [response] as served here: COOP/COEP set; its encoding and length left
/// out — the body comes here already decoded, and kept, Chrome waits for
/// bytes that never come (GitHub Pages gzips main.dart.wasm).
function isolated(response) {
  const headers = new Headers(response.headers);
  headers.delete('Content-Encoding');
  headers.delete('Content-Length');
  headers.set('Cross-Origin-Opener-Policy', 'same-origin');
  headers.set('Cross-Origin-Embedder-Policy', 'credentialless');
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

/// Whether [request]'s response is one to keep for offline: a whole file.
function keepable(request, response) {
  return (
    response.status === 200 &&
    response.type !== 'opaque' &&
    !request.headers.has('range')
  );
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET' || new URL(request.url).origin !== self.location.origin) return;
  // (Avoids a Chrome error for this cache mode outside same-origin.)
  if (request.cache === 'only-if-cached' && request.mode !== 'same-origin') return;
  event.respondWith(
    (async () => {
      try {
        const response = await fetch(request);
        if (response.status === 0 || response.type === 'opaque') return response;
        const served = isolated(response);
        if (keepable(request, served)) {
          const copy = served.clone();
          event.waitUntil(
            caches
              .open(CACHE)
              .then((cache) => cache.put(request, copy))
              .catch(() => {}), // storage full: served, not kept
          );
        }
        return served;
      } catch (offline) {
        // No connection: the copy kept, if any (a page asked for by its
        // address — the app's start — answered by the app's own page).
        const cache = await caches.open(CACHE);
        const kept =
          (await cache.match(request, { ignoreSearch: request.mode === 'navigate' })) ||
          (request.mode === 'navigate' ? await cache.match('./') : undefined) ||
          (request.mode === 'navigate' ? await cache.match('index.html') : undefined);
        if (kept) return kept;
        throw offline;
      }
    })(),
  );
});
