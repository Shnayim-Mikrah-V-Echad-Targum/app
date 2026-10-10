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
const { readFileSync } = require('node:fs');
const { join } = require('node:path');

const web = join(__dirname, 'build', 'web');

// The engine's files keep their names from one Flutter release to the next,
// so their cache is named after the engine that built them.
function engineRevision() {
  const bootstrap = readFileSync(join(web, 'flutter_bootstrap.js'), 'utf8');
  const revision = /"engineRevision":"([0-9a-f]+)"/.exec(bootstrap)?.[1];
  if (!revision) throw new Error('build/web/flutter_bootstrap.js names no engine revision; build the app first');
  return revision.slice(0, 12);
}

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
  runtimeCaching: [
    {
      // CanvasKit, in whichever variant the browser loads; not precached, as
      // the variants come to some 30 MB.
      urlPattern: /\/canvaskit\//,
      handler: 'CacheFirst',
      options: {
        cacheName: `canvaskit-${engineRevision()}`,
        cacheableResponse: { statuses: [200] },
        plugins: [
          {
            // Once a new engine is cached, the older engines' caches go.
            cacheDidUpdate: async ({ cacheName }) => {
              for (const name of await caches.keys()) {
                if (name.startsWith('canvaskit-') && name !== cacheName) await caches.delete(name);
              }
            },
          },
        ],
      },
    },
    {
      // The books, the fonts loaded on demand and the licences: served from
      // the cache, and refreshed in the background, so a corrected text
      // arrives the next time the book opens.
      urlPattern: /\/assets\/(?:NOTICES$|assets\/(?:text|fonts\/(?:optional|rashi|licenses))\/)/,
      handler: 'StaleWhileRevalidate',
      options: {
        cacheName: 'content',
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
