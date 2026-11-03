// Cross-origin isolation for hosts that cannot set headers (GitHub Pages):
// every same-origin response gets COOP/COEP, so the page may use threads —
// the recitation model (ONNX Runtime Web) runs ~4x faster than real time
// with them, and slower than real time without. COEP "credentialless", so
// reciters' audio from other hosts still loads (sent without cookies).
// Nothing is cached here: the browser's own HTTP cache does that.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET' || new URL(request.url).origin !== self.location.origin) return;
  // (Avoids a Chrome error for this cache mode outside same-origin.)
  if (request.cache === 'only-if-cached' && request.mode !== 'same-origin') return;
  event.respondWith(
    fetch(request).then((response) => {
      if (response.status === 0 || response.type === 'opaque') return response;
      const headers = new Headers(response.headers);
      headers.set('Cross-Origin-Opener-Policy', 'same-origin');
      headers.set('Cross-Origin-Embedder-Policy', 'credentialless');
      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers,
      });
    }),
  );
});
