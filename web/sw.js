// Recipe Box offline service worker.
// The app shell is fetched network-first (so updates arrive when online) and
// everything else (recipe photos, fonts, engine files) is cache-first, so the
// whole cookbook keeps working with no connection.
const VERSION = '__BUILD_VERSION__';
const CACHE = 'recipebox-' + VERSION;
const SHELL = ['./', 'index.html', 'flutter_bootstrap.js', 'version.json', 'manifest.json'];

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    let files = [];
    try { files = await (await fetch('sw_files.json', { cache: 'no-store' })).json(); } catch (e) {}
    const core = files.filter((f) => !f.startsWith('assets/assets/photos/'));
    await cache.addAll([...new Set([...SHELL, ...core])]);
    self.skipWaiting();
    // Recipe photos download in the background.
    const photos = files.filter((f) => f.startsWith('assets/assets/photos/'));
    (async () => {
      for (let i = 0; i < photos.length; i += 20) {
        await Promise.all(photos.slice(i, i + 20).map((p) => cache.add(p).catch(() => {})));
      }
    })();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const k of await caches.keys()) if (k.startsWith('recipebox-') && k !== CACHE) await caches.delete(k);
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return; // web imports etc. go straight to the network
  const path = url.pathname.slice(new URL(self.registration.scope).pathname.length);
  const shell = req.mode === 'navigate' || SHELL.includes(path) || path === '' || path === 'main.dart.js';
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    if (shell) {
      try {
        const fresh = await fetch(req, { cache: 'no-store' });
        if (fresh.ok && !url.search) cache.put(req, fresh.clone());
        return fresh;
      } catch (e) {
        return (await cache.match(req, { ignoreSearch: true })) || (await cache.match('index.html')) || Response.error();
      }
    }
    const hit = await cache.match(req, { ignoreSearch: true });
    if (hit) return hit;
    const res = await fetch(req);
    if (res.ok) cache.put(req, res.clone());
    return res;
  })());
});
