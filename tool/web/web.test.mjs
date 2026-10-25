// Tests for the web build's JavaScript, run against fixtures in Node's vm:
// the scripts in web/index.html (an older link's redirect and the loading
// screen), web/flutter_bootstrap.js, the service worker's update script and
// configuration (tool/web/sw_update.js, sw_build.cjs and
// workbox-config.cjs), the fonts' preloads (tool/web/preload_fonts.mjs), and
// the site's robots.txt, sitemap and asset links (tool/web/site_files.mjs and
// asset_links.mjs).
//
//   node --test tool/web/web.test.mjs
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { after, describe, it } from 'node:test';
import vm from 'node:vm';

const ROOT = new URL('../../', import.meta.url);
const read = (path) => readFileSync(new URL(path, ROOT), 'utf8');
const require = createRequire(import.meta.url);
const { cacheNames, fileNavigation, missingFromPrecache, serverPage, writeUpdateScript } = require('./sw_build.cjs');
// Glob matching as Workbox's globPatterns use it (Node 20.17 and later).
const { matchesGlob } = require('node:path');
const { fontAssets, preloadFonts, withPreloads } = await import('./preload_fonts.mjs');
const { isSiteUrl, robots, sitemap } = await import('./site_files.mjs');
const { PACKAGE, assetLinks, certificateFingerprints } = await import('./asset_links.mjs');
const { DOCS, LANGS } = await import('../legal/build_html.mjs');

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
/// The one inline script that has [marker] in it.
const inlineScript = (marker) => {
  const found = inlineScripts.filter((script) => script.includes(marker));
  assert.equal(found.length, 1, marker);
  return found[0];
};
/// The head's script, the install offer's and the body's loading screen's.
const headSource = inlineScript('flutter.settings.v1');
const installSource = inlineScript('beforeinstallprompt');
const loadingSource = inlineScript("'flutter-first-frame'");

/// Runs the head's script on the page at [href], whose <base href> makes
/// [base] its base URI. It moves an older link's #/ page to its own address,
/// and reads the saved settings before the first paint, with [stored] as
/// localStorage's flutter.settings.v1 (an object is stored as
/// shared_preferences stores it, JSON inside a JSON string) and [languages]
/// as the browser's. Returns the attributes it set on <html>, and the
/// address it gave the page in place of its own, if it did.
function headScript({
  href = 'https://example.org/app/',
  base = 'https://example.org/app/',
  stored,
  languages = ['en-US'],
  language = languages[0],
  throws = false,
} = {}) {
  const attributes = {};
  const root = { lang: 'en', setAttribute: (name, value) => (attributes[name] = value) };
  const value = stored === undefined ? null : typeof stored === 'string' ? stored : JSON.stringify(JSON.stringify(stored));
  const replaced = [];
  vm.runInNewContext(headSource, {
    localStorage: {
      getItem(key) {
        if (throws) throw new Error('SecurityError');
        return key === 'flutter.settings.v1' ? value : null;
      },
    },
    navigator: { languages, language },
    location: new URL(href),
    history: { replaceState: (state, title, url) => replaced.push({ state, title, url }) },
    document: { documentElement: root, baseURI: base },
  });
  assert.ok(replaced.length <= 1);
  return { attributes: { ...attributes, lang: root.lang }, replaced: replaced[0] };
}

/// The attributes the head's script set on <html> (see [headScript]).
const loader = (fixture) => headScript(fixture).attributes;

describe('a link from before path URLs', () => {
  /// The address the page at [href] is given, or undefined where it keeps
  /// its own.
  const redirect = (href, base = 'https://example.org/app/') => {
    const { replaced } = headScript({ href, base });
    if (replaced) assert.deepEqual([replaced.state, replaced.title], [null, '']);
    return replaced?.url;
  };

  it('goes to the address of the page it names, in place of its own', () => {
    assert.equal(redirect('https://example.org/app/#/community/thread/1'), 'https://example.org/app/community/thread/1');
    assert.equal(redirect('https://example.org/app/#/progress'), 'https://example.org/app/progress');
    // Its query is the page's.
    assert.equal(redirect('https://example.org/app/#/search?q=light'), 'https://example.org/app/search?q=light');
    assert.equal(redirect('https://example.org/app/#/'), 'https://example.org/app/');
  });

  it("goes there under the site's base, wherever the site is served from", () => {
    assert.equal(redirect('https://example.org/#/legal/privacy', 'https://example.org/'), 'https://example.org/legal/privacy');
    assert.equal(
      redirect('https://example.org/app/index.html#/today', 'https://example.org/app/'),
      'https://example.org/app/today',
    );
  });

  it('leaves an address that names no page after # as it is', () => {
    for (const href of [
      'https://example.org/app/',
      'https://example.org/app/progress',
      'https://example.org/app/search?q=light',
      'https://example.org/app/#',
      'https://example.org/app/#top',
    ]) {
      assert.equal(redirect(href), undefined, href);
    }
  });

  it('goes there before the loading screen reads the settings, which may fail', () => {
    const { attributes, replaced } = headScript({ href: 'https://example.org/app/#/progress', throws: true });
    assert.equal(replaced.url, 'https://example.org/app/progress');
    assert.deepEqual(attributes, { lang: 'en' });
  });
});

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
  /// notice and the first frame. [reduceMotion] is the app's setting, as the
  /// head's script marks it on <html>, and [systemReduceMotion] the
  /// system's.
  function loadingText(lang, { reduceMotion = false, systemReduceMotion = false } = {}) {
    const timers = [];
    const listeners = {};
    const removed = [];
    const loading = {
      dir: '',
      style: {},
      attributes: {},
      listeners: {},
      setAttribute(name, value) {
        this.attributes[name] = value;
      },
      addEventListener(type, listener) {
        this.listeners[type] = listener;
      },
      remove: () => removed.push('loading'),
    };
    const text = { textContent: 'Loading…' };
    vm.runInNewContext(loadingSource, {
      document: {
        documentElement: { lang, hasAttribute: (name) => reduceMotion && name === 'data-reduce-motion' },
        getElementById: (id) => ({ loading, 'loading-text': text })[id],
        querySelectorAll: (selector) =>
          selector === 'meta.boot-theme' ? [{ remove: () => removed.push('boot-theme') }] : [],
      },
      window: {
        addEventListener: (type, listener) => (listeners[type] = listener),
        matchMedia: (query) => ({ matches: systemReduceMotion && query === '(prefers-reduced-motion: reduce)' }),
      },
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

  it("fades away over the app at the first frame, as the brand's theme-color goes", () => {
    const page = loadingText('en');
    page.listeners['flutter-first-frame']();
    assert.ok(page.timers[0].cleared);
    // The theme-color at once; the loading screen over 250 ms, decelerating,
    // letting taps through to the app and hidden from screen readers.
    assert.deepEqual(page.removed, ['boot-theme']);
    assert.equal(page.loading.style.opacity, '0');
    assert.equal(page.loading.style.transition, 'opacity 250ms cubic-bezier(0.05, 0.7, 0.1, 1)');
    assert.equal(page.loading.style.pointerEvents, 'none');
    assert.equal(page.loading.attributes['aria-hidden'], 'true');
    // Gone once the fade ends, and only once.
    page.loading.listeners.transitionend();
    assert.deepEqual(page.removed, ['boot-theme', 'loading']);
    const fallback = page.timers[1];
    assert.equal(fallback.ms, 400);
    fallback.callback();
    assert.deepEqual(page.removed, ['boot-theme', 'loading']);
  });

  it('goes after 400 ms if the fade never ends', () => {
    const page = loadingText('he');
    page.listeners['flutter-first-frame']();
    assert.deepEqual(page.removed, ['boot-theme']);
    page.timers[1].callback();
    assert.deepEqual(page.removed, ['boot-theme', 'loading']);
  });

  it("goes at once with Reduce Motion, the app's or the system's", () => {
    for (const motion of [{ reduceMotion: true }, { systemReduceMotion: true }]) {
      const page = loadingText('en', motion);
      page.listeners['flutter-first-frame']();
      assert.deepEqual(page.removed, ['boot-theme', 'loading'], JSON.stringify(motion));
      assert.deepEqual(page.loading.style, {}, JSON.stringify(motion));
      assert.equal(page.timers.length, 1, JSON.stringify(motion));
    }
  });

  it("stays above the app's view while it fades", () => {
    const rule = html.match(/#loading \{([^}]*)\}/)[1];
    assert.match(rule, /position: fixed;/);
    assert.match(rule, /z-index: 1;/);
  });
});

// ---------------------------------------------------------------------------
// web/flutter_bootstrap.js

/// A service worker of the fake page, in [state]: it records the messages
/// posted to it, and [become] moves it on, as the browser does.
function fakeWorker(state) {
  const listeners = {};
  return {
    state,
    messages: [],
    addEventListener: (type, listener) => (listeners[type] = listener),
    // Copied out of the page's realm, so that deepEqual compares plain values.
    postMessage(message) {
      this.messages.push(JSON.parse(JSON.stringify(message)));
    },
    become(next) {
      this.state = next;
      listeners.statechange?.();
    },
  };
}

/// Runs flutter_bootstrap.js (without Flutter's own loader) on a page at
/// [href], under the site's [base], whose service worker [controller] is set
/// on a later visit, after the page has loaded [loaded]. A version of the
/// app is [active] as the page registers the worker on a later visit, also
/// where a hard reload loaded the page past the worker (no [controller]); on
/// a first visit, the first version is active only once the page waits for
/// it (ready). The registration has [waiting] and [installing] workers, if
/// given; the clock reads [now] until the test moves it.
async function bootstrap({
  controller = null,
  active: activeAtStart = controller !== null,
  loaded = [],
  launchQueue = false,
  href = 'https://example.org/app/today',
  base = 'https://example.org/app/',
  waiting = null,
  installing = null,
} = {}) {
  const listeners = {};
  const registered = [];
  const dispatched = [];
  const clock = { now: 1e12 };
  const active = fakeWorker('activated');
  const registration = {
    active: activeAtStart ? active : null,
    waiting,
    installing,
    listeners: {},
    updates: 0,
    addEventListener: (type, listener) => (registration.listeners[type] = listener),
    update: async () => registration.updates++,
  };
  const serviceWorker = {
    controller,
    listeners: [],
    register: async (url) => {
      registered.push(url);
      return registration;
    },
    get ready() {
      registration.active = active;
      return Promise.resolve(registration);
    },
    addEventListener: (type, listener, options) => serviceWorker.listeners.push({ type, listener, options }),
  };
  const document = {
    baseURI: base,
    visibilityState: 'visible',
    listeners: {},
    addEventListener: (type, listener) => (document.listeners[type] = listener),
  };
  const { origin, pathname, search, hash } = new URL(href);
  // The window's history, which records each address pushed on it, and
  // moves the page's address there.
  const history = {
    pushed: [],
    pushState(state, title, url) {
      history.pushed.push({ state, title, url });
      const next = new URL(url, page.location.origin + page.location.pathname);
      Object.assign(page.location, { pathname: next.pathname, search: next.search, hash: next.hash });
    },
  };
  const page = {
    _flutter: { loader: { load: () => (page.loaderStarted = true) } },
    navigator: { serviceWorker },
    document,
    performance: {
      setResourceTimingBufferSize: (size) => (page.bufferSize = size),
      getEntriesByType: (type) => (type === 'resource' ? loaded.map((name) => ({ name })) : []),
    },
    location: { origin, pathname, search, hash, reloads: 0, reload: () => page.location.reloads++ },
    history,
    addEventListener: (type, listener) => (listeners[type] = listener),
    dispatchEvent: (event) => dispatched.push(event.type === 'popstate' ? { type: event.type, state: event.state } : event.type),
    Event: class {
      constructor(type) {
        this.type = type;
      }
    },
    PopStateEvent: class {
      constructor(type, init) {
        this.type = type;
        this.state = init?.state;
      }
    },
    Date: { now: () => clock.now },
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
  return { page, messages: active.messages, registered, registration, serviceWorker, document, history, dispatched, clock, listeners };
}

// ---------------------------------------------------------------------------
// web/index.html: the offer to install

/// Runs the install offer's script on a page whose display mode is [mode]
/// ('browser' in a tab, 'standalone' as an installed app), and where
/// [iosStandalone] is Safari's navigator.standalone, as a home-screen app
/// on an iPhone has it. Returns the page, with the events it dispatched and
/// a way to fire the browser's own.
function installPage({ mode = 'browser', iosStandalone } = {}) {
  const listeners = {};
  const dispatched = [];
  const page = {
    addEventListener: (type, listener) => (listeners[type] = listener),
    dispatchEvent: (event) => dispatched.push(event.type),
    matchMedia: (query) => ({ matches: query === `(display-mode: ${mode})` }),
    navigator: iosStandalone === undefined ? {} : { standalone: iosStandalone },
    Event: class {
      constructor(type) {
        this.type = type;
      }
    },
    Promise,
  };
  page.window = page;
  vm.runInNewContext(installSource, page);
  return { page, listeners, dispatched, install: page.smInstall };
}

/// The browser's beforeinstallprompt, which the reader's answer [outcome]
/// settles, or [fails] to show.
function installPrompt({ outcome = 'accepted', fails = false } = {}) {
  const event = {
    prevented: false,
    prompted: 0,
    preventDefault() {
      this.prevented = true;
    },
    prompt() {
      this.prompted++;
      if (fails) throw new Error('NotAllowedError');
      return Promise.resolve();
    },
    userChoice: Promise.resolve({ outcome, platform: 'web' }),
  };
  return event;
}

describe('the offer to install', () => {
  it('has none until the browser makes one, and asks nothing then', async () => {
    const { install, dispatched } = installPage();
    assert.equal(install.available(), false);
    assert.equal(install.installed(), false);
    assert.equal(install.standalone(), false);
    assert.equal(await install.prompt(), 'unavailable');
    assert.deepEqual(dispatched, []);
  });

  it("keeps the browser's offer for the app, in place of the browser's own bar, and tells the app", () => {
    const { install, listeners, dispatched } = installPage();
    const event = installPrompt();
    listeners.beforeinstallprompt(event);
    assert.ok(event.prevented);
    assert.equal(event.prompted, 0, 'only as the reader asks');
    assert.equal(install.available(), true);
    assert.deepEqual(dispatched, ['sm-install-change']);
  });

  it("asks the browser once, as the reader taps, and says the reader's answer", async () => {
    for (const outcome of ['accepted', 'dismissed']) {
      const { install, listeners, dispatched } = installPage();
      const event = installPrompt({ outcome });
      listeners.beforeinstallprompt(event);
      const answer = install.prompt();
      // Within the tap: the browser shows its dialog only then.
      assert.equal(event.prompted, 1);
      // An offer is made once.
      assert.equal(install.available(), false);
      assert.equal(await answer, outcome);
      assert.equal(await install.prompt(), 'unavailable');
      assert.equal(event.prompted, 1);
      assert.deepEqual(dispatched, ['sm-install-change', 'sm-install-change']);
    }
  });

  it("says there is nothing to ask where the browser won't show its dialog", async () => {
    const { install, listeners } = installPage();
    listeners.beforeinstallprompt(installPrompt({ fails: true }));
    assert.equal(await install.prompt(), 'unavailable');
    assert.equal(install.available(), false);
  });

  it('offers nothing more once the app is installed, and says so', () => {
    const { install, listeners, dispatched } = installPage();
    listeners.beforeinstallprompt(installPrompt());
    listeners.appinstalled({});
    assert.equal(install.installed(), true);
    assert.equal(install.available(), false);
    assert.deepEqual(dispatched, ['sm-install-change', 'sm-install-change']);
  });

  it('knows when it runs as an installed app: a window, a home-screen app, the Android app', () => {
    for (const mode of ['standalone', 'fullscreen', 'minimal-ui', 'window-controls-overlay']) {
      const { install, listeners } = installPage({ mode });
      assert.equal(install.standalone(), true, mode);
      listeners.beforeinstallprompt(installPrompt());
      assert.equal(install.available(), false, mode);
    }
    assert.equal(installPage({ iosStandalone: true }).install.standalone(), true);
    assert.equal(installPage({ iosStandalone: false }).install.standalone(), false);
    assert.equal(installPage({ mode: 'browser' }).install.standalone(), false);
  });

  it('comes before the app loads, so that an offer made early is kept', () => {
    assert.ok(html.indexOf(installSource) < html.indexOf('<script src="flutter_bootstrap.js" async></script>'));
    assert.ok(html.indexOf(installSource) < html.indexOf('</head>'));
  });
});

describe('the bootstrap', () => {
  const loaded = [
    'https://example.org/app/canvaskit/chromium/canvaskit.wasm',
    'https://example.org/app/assets/assets/text/mikrah/genesis.json#fragment',
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
            'https://example.org/app/assets/assets/text/mikrah/genesis.json',
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

  it('offers a new version that is waiting as the app starts', async () => {
    const waiting = fakeWorker('installed');
    const { page, dispatched } = await bootstrap({ controller: {}, waiting });
    assert.equal(page.smUpdateReady, waiting);
    assert.deepEqual(dispatched, ['sm-update-ready']);
  });

  it('offers a new version once it has installed, whenever it was found', async () => {
    // One the browser began installing as the page loaded.
    const early = fakeWorker('installing');
    const first = await bootstrap({ controller: {}, installing: early });
    assert.deepEqual(first.dispatched, []);
    early.become('installed');
    assert.equal(first.page.smUpdateReady, early);
    assert.deepEqual(first.dispatched, ['sm-update-ready']);

    // One found later, while the app is open.
    const { page, registration, dispatched } = await bootstrap({ controller: {} });
    const later = fakeWorker('installing');
    registration.installing = later;
    registration.listeners.updatefound();
    assert.deepEqual(dispatched, []);
    later.become('installed');
    assert.equal(page.smUpdateReady, later);
    assert.deepEqual(dispatched, ['sm-update-ready']);
    // A newer one still, which replaces it, is the one offered.
    const newer = fakeWorker('installing');
    registration.installing = newer;
    registration.listeners.updatefound();
    newer.become('installed');
    later.become('redundant');
    assert.equal(page.smUpdateReady, newer);
  });

  it('never offers the first version, which takes over at once', async () => {
    const installing = fakeWorker('installing');
    const { page, dispatched } = await bootstrap({ installing });
    installing.become('installed');
    installing.become('activated');
    assert.equal(page.smUpdateReady, undefined);
    assert.deepEqual(dispatched, []);
  });

  it('looks for a new version when the window comes back to the front, at most once an hour', async () => {
    const { registration, document, clock } = await bootstrap({ controller: {} });
    const hour = 60 * 60 * 1000;
    const shown = (state) => {
      document.visibilityState = state;
      document.listeners.visibilitychange();
    };
    // The browser looked as the page loaded.
    clock.now += hour - 1;
    shown('visible');
    assert.equal(registration.updates, 0);
    clock.now += 1;
    shown('hidden');
    assert.equal(registration.updates, 0, 'not as it goes behind');
    shown('visible');
    assert.equal(registration.updates, 1);
    clock.now += hour / 2;
    shown('visible');
    assert.equal(registration.updates, 1);
    clock.now += hour / 2;
    shown('visible');
    assert.equal(registration.updates, 2);
  });

  it('looks for a new version when a window is brought forward without having been hidden', async () => {
    const { registration, document, clock, listeners } = await bootstrap({ controller: {} });
    const hour = 60 * 60 * 1000;
    clock.now += hour - 1;
    listeners.focus();
    assert.equal(registration.updates, 0);
    clock.now += 1;
    listeners.focus();
    assert.equal(registration.updates, 1);
    // Within the hour, focused or shown again: not again.
    clock.now += hour / 2;
    listeners.focus();
    document.listeners.visibilitychange();
    assert.equal(registration.updates, 1);
    clock.now += hour / 2;
    document.listeners.visibilitychange();
    listeners.focus();
    assert.equal(registration.updates, 2);
  });

  /// The worker's controllerchange listeners: the restart's own (once), and
  /// the one that follows a restart in another window.
  const restartListeners = (serviceWorker) => serviceWorker.listeners.filter(({ options }) => options?.once);
  const takeoverListeners = (serviceWorker) =>
    serviceWorker.listeners.filter(({ type, options }) => type === 'controllerchange' && !options?.once);
  /// A new [controller] takes the page over.
  const changeController = (serviceWorker, controller) => {
    serviceWorker.controller = controller;
    serviceWorker.listeners.forEach(({ listener }) => listener());
  };

  it('restarts into the new version: it takes over, and the page reloads under it', async () => {
    const waiting = fakeWorker('installed');
    const { page, serviceWorker, dispatched } = await bootstrap({ controller: {}, waiting });
    page.smRestart();
    assert.deepEqual(waiting.messages, [{ type: 'SKIP_WAITING' }]);
    assert.equal(page.location.reloads, 0, 'not before it has taken over');
    // Pressed again before it has: told again, with one reload to come.
    page.smRestart();
    assert.equal(waiting.messages.length, 2);
    const restarts = restartListeners(serviceWorker);
    assert.equal(restarts.length, 1);
    assert.equal(restarts[0].type, 'controllerchange');
    changeController(serviceWorker, waiting);
    assert.equal(page.location.reloads, 1);
    // Its own restart, not another window's.
    assert.ok(!dispatched.includes('sm-update-took-over'));
    assert.equal(page.smUpdateTookOver, undefined);
  });

  it('reloads at once where the new version took over in another window', async () => {
    const waiting = fakeWorker('installed');
    const { page, serviceWorker } = await bootstrap({ controller: {}, waiting });
    waiting.become('activating');
    page.smRestart();
    assert.equal(page.location.reloads, 1);
    assert.deepEqual(waiting.messages, []);
    assert.deepEqual(restartListeners(serviceWorker), []);
  });

  it("tells the app when another window's restart has let the new version take this one over", async () => {
    const waiting = fakeWorker('installed');
    const { page, serviceWorker, dispatched } = await bootstrap({ controller: {}, waiting });
    assert.equal(takeoverListeners(serviceWorker).length, 1);
    waiting.become('activated');
    changeController(serviceWorker, waiting);
    assert.equal(page.smUpdateTookOver, true);
    assert.deepEqual(dispatched, ['sm-update-ready', 'sm-update-took-over']);
    // The app then saves and restarts, which simply reloads.
    page.smRestart();
    assert.equal(page.location.reloads, 1);
    assert.deepEqual(waiting.messages, []);
  });

  it('takes the first version taking over a first visit for no restart', async () => {
    const { page, registration, serviceWorker, dispatched } = await bootstrap();
    changeController(serviceWorker, registration.active);
    assert.equal(page.smUpdateTookOver, undefined);
    assert.deepEqual(dispatched, []);
    // A later version, which another window restarted into, is one.
    changeController(serviceWorker, fakeWorker('activated'));
    assert.equal(page.smUpdateTookOver, true);
    assert.deepEqual(dispatched, ['sm-update-took-over']);
  });

  // A hard reload (Ctrl+Shift+R) loads the page past the worker, which then
  // controls nothing, though it is active and the window's code is as old as
  // any other window's. Taken for a first visit, the window was never
  // offered a new version, and when another window's restart let it take
  // over every window, this one went on in the old version's code with the
  // new version's files.
  describe('in a window that a hard reload loaded past the worker', () => {
    it('offers a new version, waiting or once it has installed', async () => {
      const waiting = fakeWorker('installed');
      const first = await bootstrap({ active: true, waiting });
      assert.equal(first.page.smUpdateReady, waiting);
      assert.deepEqual(first.dispatched, ['sm-update-ready']);

      const { page, registration, dispatched } = await bootstrap({ active: true });
      const later = fakeWorker('installing');
      registration.installing = later;
      registration.listeners.updatefound();
      later.become('installed');
      assert.equal(page.smUpdateReady, later);
      assert.deepEqual(dispatched, ['sm-update-ready']);
    });

    it('restarts when the new version takes it over, at a restart in another window or once installed', async () => {
      const waiting = fakeWorker('installed');
      const { page, serviceWorker, dispatched } = await bootstrap({ active: true, waiting });
      waiting.become('activated');
      changeController(serviceWorker, waiting);
      assert.equal(page.smUpdateTookOver, true);
      assert.deepEqual(dispatched, ['sm-update-ready', 'sm-update-took-over']);
      page.smRestart();
      assert.equal(page.location.reloads, 1);
    });

    it('restarts into the new version itself', async () => {
      const waiting = fakeWorker('installed');
      const { page, serviceWorker, dispatched } = await bootstrap({ active: true, waiting });
      page.smRestart();
      assert.deepEqual(waiting.messages, [{ type: 'SKIP_WAITING' }]);
      changeController(serviceWorker, waiting);
      assert.equal(page.location.reloads, 1);
      assert.ok(!dispatched.includes('sm-update-took-over'));
    });

    it('is no first visit: what it loaded is left to the worker', async () => {
      const { messages } = await bootstrap({ active: true, loaded });
      assert.deepEqual(messages, []);
    });
  });

  it('takes no restart for the version a window loaded under taking it over, nor for none', async () => {
    // A window that registered the worker just as the first version, which
    // another window installed, became active, and before it took this
    // window over.
    const { page, registration, serviceWorker, dispatched } = await bootstrap({ active: true });
    changeController(serviceWorker, registration.active);
    // The worker gone, as when the site's data is cleared.
    changeController(serviceWorker, null);
    assert.equal(page.smUpdateTookOver, undefined);
    assert.deepEqual(dispatched, []);
  });

  describe("shows a shortcut's page in the window it opens in", () => {
    /// The addresses pushed on the window's history, each told to the app
    /// as the browser's Back and Forward are, with no state of the app's.
    const shown = ({ history, dispatched }) => {
      const popped = dispatched.filter((event) => event.type === 'popstate');
      assert.equal(popped.length, history.pushed.length);
      assert.ok(popped.every((event) => event.state === null));
      assert.ok(history.pushed.every(({ state, title }) => state === null && title === ''));
      return history.pushed.map(({ url }) => url);
    };

    it('at its own address, as the app goes there from Back and Forward', async () => {
      const fixture = await bootstrap({ launchQueue: true });
      fixture.page.consumer({ targetURL: 'https://example.org/app/progress' });
      assert.deepEqual(shown(fixture), ['/app/progress']);
      assert.equal(fixture.page.location.pathname, '/app/progress');
      fixture.page.consumer({ targetURL: 'https://example.org/app/today' });
      assert.deepEqual(shown(fixture), ['/app/progress', '/app/today']);
    });

    it('keeping the page on show for a plain launch, or the page it is on', async () => {
      const fixture = await bootstrap({ launchQueue: true, href: 'https://example.org/app/community/thread/1' });
      fixture.page.consumer({ targetURL: 'https://example.org/app/' });
      fixture.page.consumer({ targetURL: 'https://example.org/app/?source=pwa' });
      fixture.page.consumer({ targetURL: 'https://example.org/app/community/thread/1' });
      fixture.page.consumer({});
      assert.deepEqual(shown(fixture), []);
    });

    it("from an older version's shortcut, which names its page after #/", async () => {
      const fixture = await bootstrap({ launchQueue: true });
      fixture.page.consumer({ targetURL: 'https://example.org/app/#/progress' });
      fixture.page.consumer({ targetURL: 'https://example.org/app/#/progress' });
      fixture.page.consumer({ targetURL: 'https://example.org/app/#/search?q=light' });
      assert.deepEqual(shown(fixture), ['/app/progress', '/app/search?q=light']);
    });

    it("under the site's base, wherever the site is served from", async () => {
      const fixture = await bootstrap({ launchQueue: true, href: 'https://example.org/today', base: 'https://example.org/' });
      fixture.page.consumer({ targetURL: 'https://example.org/' });
      fixture.page.consumer({ targetURL: 'https://example.org/#/progress' });
      assert.deepEqual(shown(fixture), ['/progress']);
    });
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
    content: ['https://example.org/assets/assets/text/mikrah/genesis.json'],
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

/// workbox-config.cjs as Workbox reads it, for a build whose caches are
/// CURRENT.
function workboxConfig() {
  const module = { exports: {} };
  const required = {
    'node:path': require('node:path'),
    './tool/web/sw_build.cjs': {
      cacheNames: () => CURRENT,
      fileNavigation,
      writeUpdateScript: () => 'sw_update.0123456789ab.js',
    },
  };
  vm.runInNewContext(read('workbox-config.cjs'), {
    module,
    exports: module.exports,
    __dirname: '/repo',
    require: (name) => required[name] ?? assert.fail(`workbox-config.cjs requires ${name}`),
  });
  return module.exports;
}

/// The files the app bundles, pubspec.yaml's assets and fonts, at their
/// paths in the web build (assets/<asset>). A folder holds the files
/// directly in it.
function bundledAssets() {
  const lines = read('pubspec.yaml').split('\n');
  const declared = [];
  for (const line of lines.slice(lines.indexOf('  assets:') + 1)) {
    if (/^ {0,2}\S/.test(line)) break;
    const entry = /^ {4}- (\S+)$/.exec(line);
    if (entry) declared.push(entry[1]);
  }
  for (const line of lines) {
    const font = /^\s+- asset: (\S+)$/.exec(line);
    if (font) declared.push(font[1]);
  }
  return declared
    .flatMap((asset) => {
      if (!asset.endsWith('/')) return [asset];
      const dir = new URL(asset, ROOT);
      return readdirSync(dir).filter((name) => statSync(new URL(name, dir)).isFile()).map((name) => asset + name);
    })
    .map((asset) => `assets/${asset}`);
}

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
    const texts = { 'mikrah/genesis.json': '[1]', 'haftarot.json': '{}' };
    const names = cacheNames(build(texts));
    assert.equal(names.engine, 'canvaskit-0123456789ab');
    assert.match(names.content, /^content-[0-9a-f]{12}$/);
    assert.deepEqual(cacheNames(build(texts)), names, 'the same texts, the same name');
    assert.notEqual(cacheNames(build({ ...texts, 'mikrah/genesis.json': '[2]' })).content, names.content);
    assert.notEqual(cacheNames(build({ ...texts, 'mikrah/exodus.json': '[]' })).content, names.content);
  });

  it('refuses a folder that is not a build', () => {
    assert.throws(() => cacheNames(tempDir()), /flutter_bootstrap\.js/);
  });

  it('writes the update script with the caches filled in', () => {
    const web = build({ 'a.json': '1' });
    const names = cacheNames(web);
    const name = writeUpdateScript(web, names);
    const script = readFileSync(join(web, name), 'utf8');
    assert.ok(script.includes(`\nconst CACHES = ${JSON.stringify(names)};\n`));
    assert.doesNotMatch(script, /CACHES = null/);
  });

  // The browser takes the scripts a new worker imports from its own cache
  // while that copy is fresh, for ten minutes on GitHub Pages. Under the
  // same name in every build, a new version's worker could run the older
  // version's script, with its caches: it left its own engine's and books'
  // caches empty, and the app didn't open offline after the update.
  it('names the update script after its content, so that no version imports an older one', () => {
    const web = build({ 'a.json': '1' });
    const names = cacheNames(web);
    const name = writeUpdateScript(web, names);
    assert.match(name, /^sw_update\.[0-9a-f]{12}\.js$/);
    assert.equal(writeUpdateScript(web, names), name, 'the same caches, the same name: a build again changes nothing');
    const other = writeUpdateScript(web, { ...names, content: 'content-0123456789ab' });
    assert.notEqual(other, name, 'other caches, another name');
    // Only this build's script is left, not an earlier build's, nor one
    // from before the scripts were named so.
    writeFileSync(join(web, 'sw_update.js'), '');
    writeFileSync(join(web, 'sw_update.js.map'), '');
    assert.equal(writeUpdateScript(web, names), name);
    assert.deepEqual(readdirSync(web).filter((file) => file.startsWith('sw_update')).sort(), [name, 'sw_update.js.map']);
  });

  it('is what the Workbox config uses', () => {
    const config = read('workbox-config.cjs');
    assert.match(config, /importScripts: \[writeUpdateScript\(web, runtimeCaches\)\]/);
    assert.match(config, /cacheName: runtimeCaches\.engine/);
    assert.match(config, /cacheName: runtimeCaches\.content/);
    assert.match(config, /skipWaiting: false/);
  });

  // Workbox passes over a file above maximumFileSizeToCacheInBytes with a
  // warning alone; without main.dart.js the app opened offline on its
  // loading screen and stayed there.
  it('finds a file the app needs to open offline that the worker leaves out', () => {
    const web = tempDir();
    for (const name of ['index.html', 'flutter.js', 'flutter_bootstrap.js', 'main.dart.js', 'main.dart.js_1.part.js']) {
      writeFileSync(join(web, name), '');
    }
    const entry = (url) => `{url:"${url}",revision:"0123"}`;
    const worker = (urls) => `define(["./workbox-1"],(function(e){"use strict";e.precacheAndRoute([${urls.map(entry).join(',')}],{})}));`;
    const legal = 'assets/assets/legal/legal.json';
    const all = ['index.html', 'flutter.js', 'flutter_bootstrap.js', 'main.dart.js', 'main.dart.js_1.part.js', legal, 'icons/Icon-192.png'];
    writeFileSync(join(web, 'sw.js'), worker(all));
    assert.deepEqual(missingFromPrecache(web), []);
    writeFileSync(join(web, 'sw.js'), worker(all.filter((url) => !url.startsWith('main.dart.js'))));
    assert.deepEqual(missingFromPrecache(web), ['main.dart.js', 'main.dart.js_1.part.js']);
    // The policies' text, without which their pages show only an error.
    writeFileSync(join(web, 'sw.js'), worker(all.filter((url) => url !== legal)));
    assert.deepEqual(missingFromPrecache(web), [legal]);
    // Unminified, as Workbox's development mode writes it.
    writeFileSync(join(web, 'sw.js'), `precacheAndRoute(${JSON.stringify(all.slice(1).map((url) => ({ url, revision: '1' })), null, 2)});`);
    assert.deepEqual(missingFromPrecache(web), ['index.html']);
    writeFileSync(join(web, 'sw.js'), 'self.addEventListener("fetch", () => {});');
    assert.throws(() => missingFromPrecache(web), /precaches nothing/);
  });

  it('is checked in CI, once Workbox has written it, before the build is uploaded', () => {
    const ci = read('.github/workflows/ci.yml');
    const written = ci.indexOf('npx --yes workbox-cli@7.4.1 generateSW workbox-config.cjs');
    const checked = ci.indexOf('node tool/web/sw_build.cjs check build/web');
    assert.ok(written >= 0 && checked > written, 'the check follows the worker');
    assert.ok(checked < ci.indexOf('name: web\n'), 'and comes before the upload');
    // No size of its own leaves a file out.
    const limit = /maximumFileSizeToCacheInBytes: (.+),/.exec(read('workbox-config.cjs'));
    assert.ok(limit && Function(`return ${limit[1]}`)() >= 32 * 1024 * 1024, 'room for any main.dart.js');
  });

  it("serves the app for any of its pages' addresses, offline too, and leaves files to the server", () => {
    const config = read('workbox-config.cjs');
    assert.match(config, /navigateFallback: 'index\.html',/);
    assert.match(config, /navigateFallbackDenylist: \[fileNavigation, serverPage\],/);
    assert.match(config, /'index\.html',/, 'which the worker precaches');
    // As Workbox tests a navigation: its address's path and query.
    for (const page of [
      '/app/',
      '/app/community',
      '/app/community/thread/0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d',
      '/app/community/legal/guidelines',
      '/app/legal/privacy',
      '/app/read/5787:1/0?verse=28:12',
      '/app/celebrate/sefer:5787:0',
      '/app/search?q=1.5',
      '/app/search?q=a/b.c',
      '/today',
    ]) {
      assert.equal(fileNavigation.test(page), false, page);
    }
    for (const file of [
      '/app/legal/privacy.html',
      '/app/legal/delete-account.he.html?utm_source=play',
      '/app/og.png',
      '/app/manifest.json',
      '/legal/support.html',
    ]) {
      assert.equal(fileNavigation.test(file), true, file);
    }
    // The accounts' pages and the admin panel are the Worker's, never the app's.
    for (const page of ['/account', '/account/sign-up', '/account/reset/complete?token=abc', '/account?lang=he', '/admin', '/admin/accounts/3']) {
      assert.equal(serverPage.test(page), true, page);
    }
    for (const page of ['/accounts', '/administer', '/settings/account', '/community/account', '/today']) {
      assert.equal(serverPage.test(page), false, page);
    }
  });

  it("gives every page's address the app on GitHub Pages, as the finished index.html", () => {
    // In each job that builds the web app: CI's, and the site's (site-web).
    const jobs = read('.github/workflows/ci.yml').split(/^ {2}(?=[a-z-]+:\n)/m)
      .filter((job) => job.includes('cp build/web/index.html build/web/404.html'));
    assert.ok(jobs.length >= 1, 'CI copies index.html to 404.html');
    for (const ci of jobs) {
      const name = ci.slice(0, ci.indexOf(':'));
      const copied = ci.indexOf('cp build/web/index.html build/web/404.html');
      // After every step that changes index.html, before the worker precaches.
      for (const step of [
        'node tool/web/preload_fonts.mjs build/web',
        'node tool/legal/build_html.mjs build/web',
        'name: Absolute link-preview URLs',
      ]) {
        const at = ci.indexOf(step);
        assert.ok(at >= 0 && at < copied, `${name}: ${step}`);
      }
      assert.equal(ci.indexOf('build/web/index.html', copied + 'cp build/web/index.html'.length), -1, `${name}: nothing changes it after`);
      assert.ok(copied < ci.indexOf('generateSW workbox-config.cjs'), `${name}: before the service worker`);
    }
    assert.match(read('docs/RELEASE.md'), /`cp build\/web\/index\.html build\/web\/404\.html`/);
  });

  // The policies' text (assets/legal/legal.json) was neither precached nor
  // cached on use: offline, /legal/privacy and About's policies showed only
  // "Something went wrong".
  it('keeps every file the app bundles for offline use, the policies precached', () => {
    const config = workboxConfig();
    const precached = (path) =>
      config.globPatterns.some((glob) => matchesGlob(path, glob)) && !config.globIgnores.some((glob) => matchesGlob(path, glob));
    const cachedOnUse = (path) =>
      config.runtimeCaching.some(({ urlPattern }) => typeof urlPattern.test === 'function' && urlPattern.test(`https://example.org/app/${path}`));
    const assets = bundledAssets();
    assert.ok(assets.length > 20, 'the app bundles its files');
    for (const path of assets) assert.ok(precached(path) || cachedOnUse(path), path);
    // Precached, not cached on use, or a policy never opened online would
    // not open offline.
    for (const path of ['assets/assets/legal/legal.json', 'assets/assets/data/parshiyot.json']) {
      assert.ok(assets.includes(path), path);
      assert.ok(precached(path), path);
    }
    // The books, the fonts loaded on demand: cached as they are read, as the
    // update script keeps them.
    for (const path of assets.filter((p) => /^assets\/assets\/(text|fonts\/(optional|rashi))\//.test(p))) {
      assert.ok(!precached(path) && cachedOnUse(path), path);
    }
  });

  it("precaches main.dart.js's deferred parts, which the app loads once it is up, for offline use", () => {
    assert.match(read('workbox-config.cjs'), /'main\.dart\.js',\n(?:\s*\/\/.*\n)*\s*'main\.dart\.js_\*\.part\.js',/);
  });

  it('holds main.dart.js to the budget docs/RELEASE.md records, unless a repository variable sets one', () => {
    const budget = read('.github/workflows/ci.yml').match(/BUDGET: \$\{\{ vars\.BUDGET_MAIN_JS_GZIP \|\| '(\d+)' \}\}/);
    assert.ok(budget, 'the Bundle size budget step');
    assert.match(read('docs/RELEASE.md'), new RegExp(`\`${budget[1]}\` bytes`));
  });
});

// ---------------------------------------------------------------------------
// tool/web/preload_fonts.mjs

describe("the fonts' preloads", () => {
  /// A FontManifest.json as flutter build web writes it, in a build without
  /// the CDN, with a font listed twice and one whose name needs encoding.
  const manifest = [
    { family: 'MaterialIcons', fonts: [{ asset: 'fonts/MaterialIcons-Regular.otf' }] },
    {
      family: 'EBGaramond',
      fonts: [
        { weight: 500, asset: 'assets/fonts/EBGaramond-Medium.ttf' },
        { weight: 500, style: 'italic', asset: 'assets/fonts/EBGaramond-MediumItalic.ttf' },
      ],
    },
    { family: 'Display', fonts: [{ asset: 'assets/fonts/My Font&Co.ttf' }, { asset: 'assets/fonts/EBGaramond-Medium.ttf' }] },
    { family: 'Roboto', fonts: [{ asset: 'fonts/fallback/Roboto-Regular.ttf' }] },
  ];

  /// A build/web with the source index.html and [fonts] as its manifest.
  function build(fonts = manifest) {
    const web = tempDir();
    mkdirSync(join(web, 'assets'));
    writeFileSync(join(web, 'assets', 'FontManifest.json'), JSON.stringify(fonts));
    writeFileSync(join(web, 'index.html'), html);
    return web;
  }

  const preloads = (page) => [...page.matchAll(/<link rel="preload" href="([^"]*)" as="fetch" crossorigin>/g)].map((m) => m[1]);

  it("preloads the manifest and every font in it, once each, as the engine fetches them", () => {
    const web = build();
    assert.deepEqual(preloadFonts(web), [
      'fonts/MaterialIcons-Regular.otf',
      'assets/fonts/EBGaramond-Medium.ttf',
      'assets/fonts/EBGaramond-MediumItalic.ttf',
      'assets/fonts/My Font&Co.ttf',
      'fonts/fallback/Roboto-Regular.ttf',
    ]);
    const page = readFileSync(join(web, 'index.html'), 'utf8');
    assert.deepEqual(preloads(page), [
      'assets/FontManifest.json',
      'assets/fonts/MaterialIcons-Regular.otf',
      'assets/assets/fonts/EBGaramond-Medium.ttf',
      'assets/assets/fonts/EBGaramond-MediumItalic.ttf',
      'assets/assets/fonts/My%20Font&amp;Co.ttf',
      'assets/fonts/fallback/Roboto-Regular.ttf',
    ]);
    // In place of the source's two, in the head, before the engine's script.
    assert.equal(page.match(/rel="preload"/g).length, 6);
    assert.ok(page.indexOf('assets/FontManifest.json') < page.indexOf('</head>'));
    assert.ok(page.indexOf('</head>') < page.indexOf('flutter_bootstrap.js'));
    // Nothing else changes.
    const outside = (text) => text.replace(/<!-- preload:[\s\S]*?<!-- \/preload -->/, '');
    assert.equal(outside(page), outside(html));
  });

  it('gives the same page when it runs again', () => {
    const web = build();
    preloadFonts(web);
    const once = readFileSync(join(web, 'index.html'), 'utf8');
    preloadFonts(web);
    assert.equal(readFileSync(join(web, 'index.html'), 'utf8'), once);
  });

  it('keeps the indentation of its markers', () => {
    const page = withPreloads('<head>\n    <!-- preload: tool/web/preload_fonts.mjs -->\n    <!-- /preload -->\n</head>', [
      'fonts/a.otf',
    ]);
    assert.equal(
      page,
      [
        '<head>',
        '    <!-- preload: tool/web/preload_fonts.mjs -->',
        '    <link rel="preload" href="assets/FontManifest.json" as="fetch" crossorigin>',
        '    <link rel="preload" href="assets/fonts/a.otf" as="fetch" crossorigin>',
        '    <!-- /preload -->',
        '</head>',
      ].join('\n'),
    );
  });

  it("preloads the display fonts in the source, for a build that doesn't run it", () => {
    assert.deepEqual(preloads(html), [
      'assets/assets/fonts/EBGaramond-Medium.ttf',
      'assets/assets/fonts/FrankRuhlLibre-Medium.ttf',
    ]);
  });

  it('refuses a page without its markers, or a manifest without fonts', () => {
    assert.throws(() => withPreloads('<head></head>', ['fonts/a.otf']), /no <!-- preload/);
    assert.throws(() => fontAssets([]), /lists no fonts/);
    assert.throws(() => fontAssets({ fonts: [] }), /not a list/);
    assert.throws(() => fontAssets([{ family: 'A', fonts: [{ weight: 700 }] }]), /without an asset in A/);
    assert.throws(() => preloadFonts(tempDir()), /FontManifest\.json/);
  });

  it('runs in CI right after the build, before the service worker precaches the page', () => {
    const ci = read('.github/workflows/ci.yml');
    const built = ci.indexOf('flutter build web');
    const preloaded = ci.indexOf('node tool/web/preload_fonts.mjs build/web');
    assert.ok(built >= 0 && preloaded > built, 'after flutter build web');
    assert.ok(preloaded < ci.indexOf('generateSW workbox-config.cjs'), 'before the service worker');
    assert.match(read('docs/RELEASE.md'), /node tool\/web\/preload_fonts\.mjs build\/web/);
  });
});

// An APK as far as its signature goes: entries, a signing block with one
// signer of [certificate] under scheme [id] (v2 by default), and the end of
// the central directory that points just past it.
function fakeApk(certificate, id = 0x7109871a) {
  const u32 = (n) => {
    const b = Buffer.alloc(4);
    b.writeUInt32LE(n);
    return b;
  };
  const u64 = (n) => {
    const b = Buffer.alloc(8);
    b.writeBigUInt64LE(BigInt(n));
    return b;
  };
  const prefixed = (...parts) => {
    const body = Buffer.concat(parts);
    return Buffer.concat([u32(body.length), body]);
  };
  // Signed data: no digests, then the certificates.
  const signedData = Buffer.concat([prefixed(), prefixed(prefixed(certificate))]);
  // A signer: its signed data, signatures and public key.
  const signer = Buffer.concat([prefixed(signedData), prefixed(), prefixed()]);
  const value = prefixed(prefixed(signer));
  const pair = Buffer.concat([u64(4 + value.length), u32(id), value]);
  const size = pair.length + 8 + 16;
  const block = Buffer.concat([u64(size), pair, u64(size), Buffer.from('APK Sig Block 42', 'latin1')]);
  const entries = Buffer.from('the entries');
  const end = Buffer.alloc(22);
  end.write('PK\x05\x06', 0, 'latin1');
  end.writeUInt32LE(entries.length + block.length, 16);
  return Buffer.concat([entries, block, end]);
}

describe("the site's own files", () => {
  const SITE = 'https://shnayimmikrah.org/';

  it('points crawlers at the sitemap, away from the accounts and the API', () => {
    const text = robots(SITE);
    assert.match(text, /^User-agent: \*$/m);
    assert.match(text, /^Disallow: \/account$/m);
    assert.match(text, /^Disallow: \/api\/$/m);
    assert.match(text, /^Sitemap: https:\/\/shnayimmikrah\.org\/sitemap\.xml$/m);
  });

  it("lists the start and every static page in both languages, at the addresses the site serves", () => {
    const xml = sitemap(SITE, { privacy: '2026-10' });
    const locs = [...xml.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1]);
    assert.equal(locs.length, 1 + DOCS.length * LANGS.length);
    assert.equal(locs[0], SITE);
    assert.ok(locs.includes(`${SITE}legal/privacy`));
    assert.ok(locs.includes(`${SITE}legal/delete-account.he`));
    // The site redirects x.html to x.
    assert.ok(locs.every((loc) => !loc.endsWith('.html')), 'no .html');
    // Each page names itself and its other language.
    const privacy = xml.slice(xml.indexOf(`<loc>${SITE}legal/privacy</loc>`));
    const entry = privacy.slice(0, privacy.indexOf('</url>'));
    assert.match(entry, /<lastmod>2026-10<\/lastmod>/);
    assert.match(entry, /hreflang="he" href="https:\/\/shnayimmikrah\.org\/legal\/privacy\.he"/);
    assert.match(entry, /hreflang="en" href="https:\/\/shnayimmikrah\.org\/legal\/privacy"/);
    assert.doesNotMatch(xml.slice(xml.indexOf(`<loc>${SITE}legal/terms</loc>`)).split('</url>')[0], /lastmod/);
  });

  it("takes only a site's root address", () => {
    assert.equal(isSiteUrl(SITE), true);
    for (const url of ['http://shnayimmikrah.org/', 'https://shnayimmikrah.org', 'https://example.github.io/app/', '', undefined]) {
      assert.equal(isSiteUrl(url), false, String(url));
    }
  });

  it("vouches for an APK by its signing certificate's SHA-256", () => {
    const certificate = Buffer.from('a certificate');
    const hex = createHash('sha256').update(certificate).digest('hex').toUpperCase();
    const fingerprint = hex.match(/../g).join(':');
    assert.deepEqual(certificateFingerprints(fakeApk(certificate)), [fingerprint]);
    assert.deepEqual(certificateFingerprints(fakeApk(certificate, 0xf05368c0)), [fingerprint], 'v3');
    assert.throws(() => certificateFingerprints(fakeApk(certificate, 0x42726577)), /no v2 or v3 signer/);
    assert.throws(() => certificateFingerprints(Buffer.from('not a zip')), /not an APK/);
    const end = Buffer.alloc(22);
    end.write('PK\x05\x06', 0, 'latin1');
    assert.throws(() => certificateFingerprints(Buffer.concat([Buffer.alloc(40), end])), /no v2 or v3 signature block/);

    const [link] = assetLinks([fingerprint, 'AB']);
    assert.deepEqual(link.relation, ['delegate_permission/common.handle_all_urls']);
    assert.deepEqual(link.target, { namespace: 'android_app', package_name: PACKAGE, sha256_cert_fingerprints: [fingerprint, 'AB'] });
    // The package the Android web app is built as.
    assert.match(read('.github/workflows/prerelease.yml'), new RegExp(`package_name: "${PACKAGE.replaceAll('.', '\\.')}"`));
  });

  it('are in the build the site serves, before its service worker', () => {
    const ci = read('.github/workflows/ci.yml').split(/^ {2}(?=[a-z-]+:\n)/m).find((job) => job.startsWith('site-web:'));
    assert.ok(ci, 'the site-web job');
    // Run by hand on main too, which Publish pre-release does for a new APK's key.
    assert.match(ci, /if: github\.ref == 'refs\/heads\/main' && github\.event_name != 'pull_request'/);
    const worker = ci.indexOf('generateSW workbox-config.cjs');
    for (const step of [
      'cp tool/windows/install.ps1 build/web/install.ps1',
      'node tool/web/asset_links.mjs build/web',
      'node tool/web/site_files.mjs build/web',
    ]) {
      const at = ci.indexOf(step);
      assert.ok(at >= 0 && at < worker, step);
    }
    assert.ok(ci.indexOf('node tool/legal/build_html.mjs build/web') < ci.indexOf('node tool/web/site_files.mjs'), 'after the static pages');
    assert.match(read('.github/workflows/publish_prerelease.yml'), /gh workflow run ci\.yml --repo "\$GITHUB_REPOSITORY" --ref main/);
  });
});
