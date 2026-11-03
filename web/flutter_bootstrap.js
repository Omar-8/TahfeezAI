{{flutter_js}}
{{flutter_build_config}}

// Cross-origin isolation (threads for the recitation model): served with
// COOP/COEP by the host, or else through isolation_sw.js — registered at
// the first visit, then the page loads once more through it (a moment,
// once only). Browsers without "credentialless" (Safari) stay as they are.
(async () => {
  const flag = 'tahfeez.isolationReload';
  if (!self.crossOriginIsolated && window.isSecureContext && 'serviceWorker' in navigator) {
    try {
      await navigator.serviceWorker.register('isolation_sw.js');
      if (!navigator.serviceWorker.controller && !sessionStorage.getItem(flag)) {
        sessionStorage.setItem(flag, '1');
        await navigator.serviceWorker.ready;
        location.reload();
        return;
      }
    } catch (e) {
      // No worker: the app runs without threads.
    }
  }
  _flutter.loader.load();
})();
