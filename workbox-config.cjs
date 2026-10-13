// The web build's service worker, so the app works offline after its first
// visit. After `flutter build web`, CI runs
//
//   npx --yes workbox-cli@7.4.1 generateSW workbox-config.cjs
//
// which writes build/web/sw.js; web/flutter_bootstrap.js registers it.
//
// Precached: the app shell and its deferred parts, its start-up fonts and
// data. Cached on first use: the engine (only the variant the browser
// loads), the books, the fonts loaded on demand, and the policy pages.
//
// Every page of the app has an address of its own (lib/main.dart), and each
// is the app: index.html, which the worker serves for any of them, offline
// too, as the server serves its copy, 404.html (CI's web job), for an
// address it has no file for.
//
// The engine's and the books' caches are named after the engine and the
// texts this version was built with, so a new version never reads, or
// refreshes, another's. Its worker fills them while it installs, online,
// from the older versions' caches (tool/web/sw_update.js): an update
// downloads again the engine and the books read so far, and finishes
// installing only with them, so the app still opens, and opens those books,
// offline after it.
const { join } = require('node:path');
const { cacheNames, fileNavigation, writeUpdateScript } = require('./tool/web/sw_build.cjs');

const web = join(__dirname, 'build', 'web');
const runtimeCaches = cacheNames(web);

module.exports = {
  globDirectory: web,
  swDest: join(web, 'sw.js'),
  globPatterns: [
    'index.html',
    'main.dart.js',
    // Its deferred parts, such as the time-zone database
    // (lib/core/calendar/tz_database.dart), loaded once the app is up.
    'main.dart.js_*.part.js',
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
  // Any page of the app, such as …/community/thread/1, opened or reloaded.
  // A file, such as a policy page (legal/privacy.html), is left to the
  // server and to the pages' cache below.
  navigateFallback: 'index.html',
  navigateFallbackDenylist: [fileNavigation],
  ignoreURLParametersMatching: [/^utm_/, /^fbclid$/, /^cachebuster$/],
  // A new version waits until every window of the old one has closed, so a
  // window never mixes the two. The app offers to restart into it instead
  // (web/flutter_bootstrap.js), with the SKIP_WAITING message that the worker
  // Workbox writes without skipWaiting answers.
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
      // Pages other than the app itself, such as legal/privacy.html (see
      // navigateFallbackDenylist).
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
