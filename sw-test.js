const CACHE_NAME = 'minisheet-test-v18';
const ASSETS = [
  'index.html',
  'manifest-test.webmanifest',
  'icons/icon-192.png',
  'icons/icon-512.png',
  'icons/icon-512-maskable.png',
  'icons/apple-touch-icon-180.png',
  'fonts/RobotoCondensed-Regular.woff2',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(ASSETS)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;

  event.respondWith(
    caches.match(event.request).then((cached) => {
      if (cached) {
        // Serve from cache instantly (no network round-trip), then refresh
        // the cache in the background for next time. Users pull updates
        // explicitly via the "Force Code Refresh" button.
        fetch(event.request, { cache: 'no-store' })
          .then((response) => caches.open(CACHE_NAME).then((cache) => cache.put(event.request, response)))
          .catch(() => {});
        return cached;
      }
      return fetch(event.request, { cache: 'no-store' }).then((response) => {
        const copy = response.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(event.request, copy));
        return response;
      });
    })
  );
});
