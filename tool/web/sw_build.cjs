// The parts of the service worker that depend on the build, for
// workbox-config.cjs: the runtime caches' names, and the script that keeps
// them across an update (tool/web/sw_update.js), written into build/web;
// which pages the worker leaves to the network; and, once Workbox has
// written the worker, whether it precaches what the app needs offline.
const { createHash } = require('node:crypto');
const { readFileSync, readdirSync, writeFileSync } = require('node:fs');
const { join, relative } = require('node:path');

const UPDATE_SCRIPT = 'sw_update.js';

/// The engine's files keep their names from one Flutter release to the next,
/// so their cache is named after the engine that built them.
function engineRevision(web) {
  const bootstrap = readFileSync(join(web, 'flutter_bootstrap.js'), 'utf8');
  const revision = /"engineRevision":"([0-9a-f]+)"/.exec(bootstrap)?.[1];
  if (!revision) throw new Error(`${join(web, 'flutter_bootstrap.js')} names no engine revision; build the app first`);
  return revision.slice(0, 12);
}

/// A hash of the books (assets/assets/text), so that a version whose texts
/// differ, in content or in format, has a cache of its own.
function textsHash(web) {
  const root = join(web, 'assets', 'assets', 'text');
  const files = [];
  const walk = (dir) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const path = join(dir, entry.name);
      if (entry.isDirectory()) walk(path);
      else files.push(path);
    }
  };
  walk(root);
  if (files.length === 0) throw new Error(`${root} has no texts; build the app first`);
  const hash = createHash('sha256');
  for (const path of files.map((f) => relative(root, f).split('\\').join('/')).sort()) {
    hash.update(`${path}\n`);
    hash.update(readFileSync(join(root, path)));
    hash.update('\n');
  }
  return hash.digest('hex').slice(0, 12);
}

/// This build's runtime caches: the engine, and the books with the fonts
/// loaded on demand.
function cacheNames(web) {
  return { engine: `canvaskit-${engineRevision(web)}`, content: `content-${textsHash(web)}` };
}

/// Writes build/web/sw_update.js for [caches] and returns its name, for
/// Workbox's importScripts.
function writeUpdateScript(web, caches) {
  const template = readFileSync(join(__dirname, UPDATE_SCRIPT), 'utf8');
  const script = template.replace(/^const CACHES = null;$/m, `const CACHES = ${JSON.stringify(caches)};`);
  if (script === template) throw new Error(`${UPDATE_SCRIPT} has no "const CACHES = null;" line`);
  writeFileSync(join(web, UPDATE_SCRIPT), script);
  return UPDATE_SCRIPT;
}

/// A navigation to a file rather than to one of the app's pages, which have
/// no extension (lib/app/router.dart): one whose address ends in a name with
/// a dot, before any query. The policy pages (legal/privacy.html) are such
/// files, and so are the icons, og.png and the rest, should a link open one.
/// Tested against a URL's path and query, as Workbox's NavigationRoute does.
const fileNavigation = /^[^?]*\/[^/?]*\.[^/?]*(?:\?|$)/;

/// The files of [web] that the app needs offline, and which the service
/// worker Workbox wrote there (sw.js) leaves out of its precache: the page,
/// the bootstrap, the app itself and its deferred parts, without which it
/// can't start, and the policies' text, without which their pages
/// (lib/features/about/legal_texts.dart) show only an error. Workbox passes
/// over a file larger than maximumFileSizeToCacheInBytes with no more than a
/// warning, and the app then opens offline on its loading screen, for good;
/// CI checks the worker with this.
function missingFromPrecache(web) {
  const worker = readFileSync(join(web, 'sw.js'), 'utf8');
  // {url:"main.dart.js",revision:"…"}, minified or not.
  const precached = new Set([...worker.matchAll(/["']?url["']?\s*:\s*"([^"]+)"/g)].map((m) => m[1]));
  if (precached.size === 0) throw new Error(`${join(web, 'sw.js')} precaches nothing; is it Workbox's?`);
  const needed = [
    'index.html',
    'flutter.js',
    'flutter_bootstrap.js',
    'main.dart.js',
    ...readdirSync(web).filter((name) => /^main\.dart\.js_\d+\.part\.js$/.test(name)).sort(),
    'assets/assets/legal/legal.json',
  ];
  return needed.filter((name) => !precached.has(name));
}

module.exports = { cacheNames, engineRevision, fileNavigation, missingFromPrecache, textsHash, writeUpdateScript };

//   node tool/web/sw_build.cjs check build/web
if (require.main === module) {
  const [command, web] = process.argv.slice(2);
  if (command !== 'check' || !web) {
    console.error('usage: node tool/web/sw_build.cjs check <build/web>');
    process.exit(2);
  }
  const missing = missingFromPrecache(web);
  for (const name of missing) {
    console.log(`::error file=workbox-config.cjs::The service worker doesn't precache ${name}, which the app needs offline`);
  }
  process.exit(missing.length === 0 ? 0 : 1);
}
