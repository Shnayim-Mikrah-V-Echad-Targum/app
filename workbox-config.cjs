// The web build's service worker, so the app works offline after its first
// visit. After `flutter build web`, CI runs
//
//   npx --yes workbox-cli@7.4.1 generateSW workbox-config.cjs
//
// which writes build/web/sw.js; web/flutter_bootstrap.js registers it.
//
// Precached: the app shell, its start-up fonts and data. Cached on first use:
// the engine (only the variant the browser loads), the books, the fonts
// loaded on demand, and the policy pages.
//
// The engine's and the books' caches are named after the engine and the
// texts this version was built with, so a new version never reads, or
// refreshes, another's. Its worker fills them while it installs, online,
// from the older versions' caches (tool/web/sw_update.js): an update
// downloads again the engine and the books read so far, and finishes
// installing only with them, so the app still opens, and opens those books,
// offline after it.
const { join } = require('node:path');
const { cacheNames, writeUpdateScript } = require('./tool/web/sw_build.cjs');

const web = join(__dirname, 'build', 'web');
const runtimeCaches = cacheNames(web);

module.exports = {
  globDirectory: web,
  swDest: join(web, 'sw.js'),
  globPatterns: [
    'index.html',
    'main.dart.js',
    'flutter.js',
    'flutter_bootstrap.js',
    'manifest.json',
    // About's version (package_info_plus asks for version.json?cachebuster=…).
    'version.json',
    'favicon.*',
    'icons/*',
    'assets/FontManifest.json',
    'assets/AssetManifest.bin*',
    // Material icons and the engine's fallback font.
    'assets/fonts/**',
    // The fonts declared in pubspec.yaml, which the engine loads at start-up;
    // the rashi/ and optional/ folders load on demand.
    'assets/assets/fonts/*.{ttf,otf}',
    'assets/assets/data/**',
    'assets/assets/branding/*',
    'assets/shaders/*',
    'assets/packages/**',
  ],
  // The notifications plugin's worker goes unused: the web build schedules no
  // notifications.
  globIgnores: ['**/*.symbols', '**/NOTICES', '**/notifications_service_worker.js'],
  maximumFileSizeToCacheInBytes: 6e6,
  ignoreURLParametersMatching: [/^utm_/, /^fbclid$/, /^cachebuster$/],
  // A new version waits until every window of the old one has closed, so a
  // window never mixes the two.
  skipWaiting: false,
  clientsClaim: true,
  cleanupOutdatedCaches: true,
  sourcemap: false,
  importScripts: [writeUpdateScript(web, runtimeCaches)],
  runtimeCaching: [
    {
      // CanvasKit, in whichever variant the browser loads; not precached, as
      // the variants come to some 30 MB.
      urlPattern: /\/canvaskit\//,
      handler: 'CacheFirst',
      options: {
        cacheName: runtimeCaches.engine,
        cacheableResponse: { statuses: [200] },
      },
    },
    {
      // The books, the fonts loaded on demand and the licences: served from
      // the cache, and refreshed in the background.
      urlPattern: /\/assets\/(?:NOTICES$|assets\/(?:text|fonts\/(?:optional|rashi|licenses))\/)/,
      handler: 'StaleWhileRevalidate',
      options: {
        cacheName: runtimeCaches.content,
        cacheableResponse: { statuses: [200] },
      },
    },
    {
      // Pages other than the app itself, such as legal/privacy.html.
      urlPattern: ({ request }) => request.mode === 'navigate',
      handler: 'NetworkFirst',
      options: {
        cacheName: 'pages',
        networkTimeoutSeconds: 5,
        cacheableResponse: { statuses: [200] },
      },
    },
  ],
};
