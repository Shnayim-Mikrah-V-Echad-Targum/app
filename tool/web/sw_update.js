// Imported by the web app's service worker (sw.js, which Workbox generates
// from workbox-config.cjs). tool/web/sw_build.cjs writes it into build/web
// with CACHES filled in: this version's runtime caches, named after the
// engine and the books it was built with.
//
// The engine and the books are cached as they are used, not precached. A
// new version's worker installs while the app is online, then waits until
// the old version's windows have closed, so it may activate only when the
// app is next opened, offline. While it installs, it therefore fetches into
// its own caches every file that older caches of the same kind hold: the
// update finishes installing with them, or not at all, and the old version
// stays, with its own caches, until it can. Once the new version is active,
// the older caches go.

const CACHES = null;

/// The kind of cache [name] is, a key of CACHES, or null for any other: the
/// name of each kind is its prefix, a hyphen and the version's hash (or the
/// bare prefix, as the books' cache was once named).
function kindOf(name) {
  for (const [kind, current] of Object.entries(CACHES)) {
    const prefix = current.slice(0, current.lastIndexOf('-'));
    if (name === prefix || name.startsWith(`${prefix}-`)) return kind;
  }
  return null;
}

async function fillCaches() {
  const names = await caches.keys();
  for (const [kind, current] of Object.entries(CACHES)) {
    const urls = new Set();
    for (const name of names.filter((n) => n !== current && kindOf(n) === kind)) {
      for (const request of await (await caches.open(name)).keys()) urls.add(request.url);
    }
    if (urls.size === 0) continue;
    const cache = await caches.open(current);
    const held = new Set((await cache.keys()).map((request) => request.url));
    await Promise.all(
      [...urls]
        .filter((url) => !held.has(url))
        .map(async (url) => {
          // From the server, never the browser's own cache: these files keep
          // their URLs from one version to the next.
          const response = await fetch(url, { cache: 'reload' });
          // A file this version no longer has.
          if (response.status === 404) return;
          if (!response.ok) throw new Error(`${url}: HTTP ${response.status}`);
          await cache.put(url, response);
        }),
    );
  }
}

async function dropOlderCaches() {
  for (const name of await caches.keys()) {
    const kind = kindOf(name);
    if (kind !== null && name !== CACHES[kind]) await caches.delete(name);
  }
}

self.addEventListener('install', (event) => event.waitUntil(fillCaches()));
self.addEventListener('activate', (event) => event.waitUntil(dropOlderCaches()));
