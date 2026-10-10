// Tests for the web build's JavaScript, run against fixtures in Node's vm:
// the loading screen's script in web/index.html, web/flutter_bootstrap.js,
// and the service worker's update script (tool/web/sw_update.js and
// sw_build.cjs).
//
//   node --test tool/web/web.test.mjs
import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { after, describe, it } from 'node:test';
import vm from 'node:vm';

const ROOT = new URL('../../', import.meta.url);
const read = (path) => readFileSync(new URL(path, ROOT), 'utf8');
const require = createRequire(import.meta.url);
const { cacheNames, writeUpdateScript } = require('./sw_build.cjs');

const dirs = [];
after(() => dirs.forEach((dir) => rmSync(dir, { recursive: true, force: true })));
const tempDir = () => {
  const dir = mkdtempSync(join(tmpdir(), 'web-'));
  dirs.push(dir);
  return dir;
};

// ---------------------------------------------------------------------------
// web/index.html

const html = read('web/index.html');
/// The inline scripts of index.html, in order.
const inlineScripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);

/// Runs the head's script, which reads the saved settings before the first
/// paint, with [stored] as localStorage's flutter.settings.v1 (an object is
/// stored as shared_preferences stores it, JSON inside a JSON string) and
/// [languages] as the browser's. Returns the attributes it set on <html>.
function loader({ stored, languages = ['en-US'], language = languages[0], throws = false } = {}) {
  const attributes = {};
  const root = { lang: 'en', setAttribute: (name, value) => (attributes[name] = value) };
  const value = stored === undefined ? null : typeof stored === 'string' ? stored : JSON.stringify(JSON.stringify(stored));
  vm.runInNewContext(inlineScripts[0], {
    localStorage: {
      getItem(key) {
        if (throws) throw new Error('SecurityError');
        return key === 'flutter.settings.v1' ? value : null;
      },
    },
    navigator: { languages, language },
    document: { documentElement: root },
  });
  return { ...attributes, lang: root.lang };
}

describe('the loading screen', () => {
  it('takes the saved theme, and only a theme the app has', () => {
    for (const theme of ['light', 'dark', 'sepia', 'highContrastLight', 'highContrastDark']) {
      assert.equal(loader({ stored: { theme } })['data-theme'], theme);
    }
    for (const theme of ['system', 'bogus', undefined]) {
      assert.equal(loader({ stored: { theme } })['data-theme'], undefined, String(theme));
    }
  });

  it('takes Reduce Motion only when it is on', () => {
    assert.equal(loader({ stored: { reduceMotion: true } })['data-reduce-motion'], '');
    for (const reduceMotion of [false, 'true', 1]) {
      assert.equal(loader({ stored: { reduceMotion } })['data-reduce-motion'], undefined, String(reduceMotion));
    }
  });

  it('takes the language the app was set to', () => {
    assert.equal(loader({ stored: { language: 'hebrew' }, languages: ['en-US'] }).lang, 'he');
    assert.equal(loader({ stored: { language: 'english' }, languages: ['he-IL'] }).lang, 'en');
  });

  it("follows the browser's languages as Flutter does, when the app follows the system", () => {
    for (const [languages, lang] of [
      [['he-IL'], 'he'],
      [['iw'], 'he'],
      [['fr-FR', 'he', 'en'], 'he'],
      [['fr-FR', 'en-GB', 'he'], 'en'],
      [['en-US', 'he'], 'en'],
      [['fr-FR', 'de'], 'en'],
    ]) {
      assert.equal(loader({ languages }).lang, lang, languages.join());
      assert.equal(loader({ stored: { language: 'system' }, languages }).lang, lang, languages.join());
    }
    // Without navigator.languages, navigator.language.
    assert.equal(loader({ languages: [], language: 'he-IL' }).lang, 'he');
  });

  it('starts in its defaults when the settings cannot be read', () => {
    for (const fixture of [{ stored: 'not json' }, { stored: '"[1, 2"' }, { stored: 'null' }, { throws: true }]) {
      assert.deepEqual(loader({ ...fixture, languages: ['en-US'] }), { lang: 'en' }, JSON.stringify(fixture));
    }
  });

  /// Runs the body's script on a page in [lang]: the loading text, the slow
  /// notice and the first frame.
  function loadingText(lang) {
    const timers = [];
    const listeners = {};
    const removed = [];
    const loading = { dir: '', remove: () => removed.push('loading') };
    const text = { textContent: 'Loading…' };
    vm.runInNewContext(inlineScripts[1], {
      document: {
        documentElement: { lang },
        getElementById: (id) => ({ loading, 'loading-text': text })[id],
        querySelectorAll: (selector) =>
          selector === 'meta.boot-theme' ? [{ remove: () => removed.push('boot-theme') }] : [],
      },
      window: { addEventListener: (type, listener) => (listeners[type] = listener) },
      setTimeout: (callback, ms) => timers.push({ callback, ms }) - 1,
      clearTimeout: (id) => (timers[id].cleared = true),
    });
    return { timers, listeners, removed, loading, text };
  }

  it('says when loading is slow, in either language', () => {
    const en = loadingText('en');
    assert.equal(en.loading.dir, '');
    assert.equal(en.timers[0].ms, 8000);
    en.timers[0].callback();
    assert.equal(en.text.textContent, 'Still loading…');

    const he = loadingText('he');
    assert.equal(he.loading.dir, 'rtl');
    assert.equal(he.text.textContent, 'טוען…');
    he.timers[0].callback();
    assert.equal(he.text.textContent, 'עדיין טוען…');
  });

  it("goes at the first frame, with the brand's theme-color", () => {
    const page = loadingText('en');
    page.listeners['flutter-first-frame']();
    assert.ok(page.timers[0].cleared);
    assert.deepEqual(page.removed, ['loading', 'boot-theme']);
  });
});

// ---------------------------------------------------------------------------
// web/flutter_bootstrap.js

/// Runs flutter_bootstrap.js (without Flutter's own loader) on a page whose
/// service worker [controller] is set on a later visit, after the page has
/// loaded [loaded].
async function bootstrap({ controller = null, loaded = [], launchQueue = false, hash = '' } = {}) {
  const messages = [];
  const listeners = {};
  const registered = [];
  // Copied out of the page's realm, so that deepEqual compares plain values.
  const registration = { active: { postMessage: (message) => messages.push(JSON.parse(JSON.stringify(message))) } };
  const page = {
    _flutter: { loader: { load: () => (page.loaderStarted = true) } },
    navigator: {
      serviceWorker: {
        controller,
        register: async (url) => registered.push(url),
        ready: Promise.resolve(registration),
      },
    },
    performance: {
      setResourceTimingBufferSize: (size) => (page.bufferSize = size),
      getEntriesByType: (type) => (type === 'resource' ? loaded.map((name) => ({ name })) : []),
    },
    location: { origin: 'https://example.org', hash },
    addEventListener: (type, listener) => (listeners[type] = listener),
    URL,
    console,
  };
  page.window = page;
  if (launchQueue) page.launchQueue = { setConsumer: (consumer) => (page.consumer = consumer) };
  const source = read('web/flutter_bootstrap.js').replace('{{flutter_js}}', '').replace('{{flutter_build_config}}', '');
  vm.runInNewContext(source, page);
  if (listeners['flutter-first-frame']) {
    listeners['flutter-first-frame']();
    await new Promise((resolve) => setTimeout(resolve, 0));
  }
  return { page, messages, registered };
}

describe('the bootstrap', () => {
  const loaded = [
    'https://example.org/app/canvaskit/chromium/canvaskit.wasm',
    'https://example.org/app/assets/assets/text/mikra/genesis.json#fragment',
    'https://example.org/app/assets/assets/fonts/NotoSans-Regular.ttf',
    'https://example.org/app/main.dart.js',
    'https://fonts.gstatic.com/s/notocoloremoji/v1/a.woff2',
    'https://example.org.evil.test/canvaskit/canvaskit.wasm',
  ];

  it('starts Flutter, and registers the worker once the app has drawn', async () => {
    const { page, registered } = await bootstrap();
    assert.ok(page.loaderStarted);
    assert.deepEqual(registered, ['sw.js']);
    assert.ok(page.bufferSize >= 500);
  });

  it('on a first visit, hands the worker what loaded before it', async () => {
    const { messages } = await bootstrap({ loaded });
    assert.deepEqual(messages, [
      {
        type: 'CACHE_URLS',
        payload: {
          urlsToCache: [
            'https://example.org/app/canvaskit/chromium/canvaskit.wasm',
            'https://example.org/app/assets/assets/text/mikra/genesis.json',
            'https://example.org/app/assets/assets/fonts/NotoSans-Regular.ttf',
          ],
        },
      },
    ]);
  });

  it('on a later visit, leaves the worker to cache what it serves', async () => {
    const { messages } = await bootstrap({ loaded, controller: {} });
    assert.deepEqual(messages, []);
  });

  it("shows a shortcut's page in the window it opens in", async () => {
    const { page } = await bootstrap({ launchQueue: true, hash: '#/today' });
    page.consumer({ targetURL: 'https://example.org/app/#/progress' });
    assert.equal(page.location.hash, '#/progress');
    page.consumer({ targetURL: 'https://example.org/app/' });
    assert.equal(page.location.hash, '#/progress', 'a plain launch keeps the page');
    page.consumer({});
    assert.equal(page.location.hash, '#/progress');
  });
});

// ---------------------------------------------------------------------------
// The service worker's update script

/// Cache Storage in memory: cache name to a map of URL to response.
function cacheStorage(initial = {}) {
  const store = new Map(Object.entries(initial).map(([name, urls]) => [name, new Map(urls.map((u) => [u, 'old']))]));
  const open = (name) => {
    if (!store.has(name)) store.set(name, new Map());
    const cache = store.get(name);
    return {
      keys: async () => [...cache.keys()].map((url) => ({ url })),
      put: async (url, response) => cache.set(url, response),
    };
  };
  return {
    store,
    api: {
      keys: async () => [...store.keys()],
      open: async (name) => open(name),
      delete: async (name) => store.delete(name),
    },
  };
}

const CURRENT = { engine: 'canvaskit-new000000000', content: 'content-new000000000' };

/// Loads sw_update.js for CURRENT over [initial] caches, with [respond]
/// answering its fetches; returns a function to fire its events.
function worker(initial, respond = () => ({ ok: true, status: 200 })) {
  const caches = cacheStorage(initial);
  const fetched = [];
  const listeners = {};
  const source = read('tool/web/sw_update.js').replace('const CACHES = null;', `const CACHES = ${JSON.stringify(CURRENT)};`);
  vm.runInNewContext(source, {
    self: { addEventListener: (type, listener) => (listeners[type] = listener) },
    caches: caches.api,
    fetch: async (url, options) => {
      fetched.push([url, options]);
      return { ...respond(url), url };
    },
    Set,
    Error,
    Promise,
  });
  const fire = async (type) => {
    let wait;
    listeners[type]({ waitUntil: (promise) => (wait = promise) });
    await wait;
  };
  return { fire, fetched, store: caches.store };
}

describe("the service worker's update", () => {
  const older = {
    'canvaskit-old000000000': ['https://example.org/canvaskit/canvaskit.js', 'https://example.org/canvaskit/canvaskit.wasm'],
    // The books' cache, as it was named before it had a version.
    content: ['https://example.org/assets/assets/text/mikra/genesis.json'],
    'content-old000000000': ['https://example.org/assets/assets/fonts/optional/Lexend-Regular.ttf'],
    pages: ['https://example.org/legal/privacy.html'],
    'workbox-precache-v2-https://example.org/': ['https://example.org/index.html'],
  };

  it("installs with the engine and the books the older versions' caches hold, from the server", async () => {
    const { fire, fetched, store } = worker(older);
    await fire('install');
    assert.deepEqual([...store.get(CURRENT.engine).keys()], older['canvaskit-old000000000']);
    assert.deepEqual([...store.get(CURRENT.content).keys()].sort(), [...older.content, ...older['content-old000000000']].sort());
    assert.equal(fetched.length, 4);
    assert.ok(fetched.every(([, options]) => options.cache === 'reload'));
    assert.ok(store.get(CURRENT.engine).get(older['canvaskit-old000000000'][0]).url, 'a fresh response');
    // The old version may still be in use: its caches stay until this one is active.
    for (const name of Object.keys(older)) assert.ok(store.has(name), name);
  });

  it('fetches only what its own caches lack', async () => {
    const { fire, fetched } = worker({ ...older, [CURRENT.engine]: [older['canvaskit-old000000000'][0]] });
    await fire('install');
    assert.deepEqual(fetched.map(([url]) => url).filter((url) => url.includes('canvaskit')), [
      older['canvaskit-old000000000'][1],
    ]);
  });

  it('installs with nothing to fetch on a first visit', async () => {
    const { fire, fetched } = worker({});
    await fire('install');
    assert.deepEqual(fetched, []);
  });

  it('leaves out a file the new version no longer has', async () => {
    const { fire, store } = worker(older, (url) => (url.endsWith('.js') ? { ok: false, status: 404 } : { ok: true, status: 200 }));
    await fire('install');
    assert.deepEqual([...store.get(CURRENT.engine).keys()], [older['canvaskit-old000000000'][1]]);
  });

  it('fails to install, keeping the old version, when a file cannot be fetched', async () => {
    const failing = worker(older, (url) => (url.endsWith('.wasm') ? { ok: false, status: 503 } : { ok: true, status: 200 }));
    await assert.rejects(failing.fire('install'), /canvaskit\.wasm: HTTP 503/);
    const offline = worker(older, () => {
      throw new TypeError('Failed to fetch');
    });
    await assert.rejects(offline.fire('install'), /Failed to fetch/);
  });

  it("drops the older engines' and books' caches once active, and nothing else", async () => {
    const { fire, store } = worker({ ...older, [CURRENT.engine]: [], [CURRENT.content]: [] });
    await fire('activate');
    assert.deepEqual([...store.keys()].sort(), [
      CURRENT.engine,
      CURRENT.content,
      'pages',
      'workbox-precache-v2-https://example.org/',
    ].sort());
  });
});

describe('the build', () => {
  /// A build/web with an engine revision and the given texts.
  function build(texts) {
    const web = tempDir();
    writeFileSync(join(web, 'flutter_bootstrap.js'), '_flutter.buildConfig = {"engineRevision":"0123456789abcdef0123"};');
    for (const [path, content] of Object.entries(texts)) {
      mkdirSync(join(web, 'assets', 'assets', 'text', path, '..'), { recursive: true });
      writeFileSync(join(web, 'assets', 'assets', 'text', path), content);
    }
    return web;
  }

  it("names the caches after the engine and the texts", () => {
    const texts = { 'mikra/genesis.json': '[1]', 'haftarot.json': '{}' };
    const names = cacheNames(build(texts));
    assert.equal(names.engine, 'canvaskit-0123456789ab');
    assert.match(names.content, /^content-[0-9a-f]{12}$/);
    assert.deepEqual(cacheNames(build(texts)), names, 'the same texts, the same name');
    assert.notEqual(cacheNames(build({ ...texts, 'mikra/genesis.json': '[2]' })).content, names.content);
    assert.notEqual(cacheNames(build({ ...texts, 'mikra/exodus.json': '[]' })).content, names.content);
  });

  it('refuses a folder that is not a build', () => {
    assert.throws(() => cacheNames(tempDir()), /flutter_bootstrap\.js/);
  });

  it('writes the update script with the caches filled in', () => {
    const web = build({ 'a.json': '1' });
    const names = cacheNames(web);
    assert.equal(writeUpdateScript(web, names), 'sw_update.js');
    const script = readFileSync(join(web, 'sw_update.js'), 'utf8');
    assert.ok(script.includes(`\nconst CACHES = ${JSON.stringify(names)};\n`));
    assert.doesNotMatch(script, /CACHES = null/);
  });

  it('is what the Workbox config uses', () => {
    const config = read('workbox-config.cjs');
    assert.match(config, /importScripts: \[writeUpdateScript\(web, runtimeCaches\)\]/);
    assert.match(config, /cacheName: runtimeCaches\.engine/);
    assert.match(config, /cacheName: runtimeCaches\.content/);
    assert.match(config, /skipWaiting: false/);
  });
});
