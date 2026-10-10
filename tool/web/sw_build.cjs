// The parts of the service worker that depend on the build, for
// workbox-config.cjs: the runtime caches' names, and the script that keeps
// them across an update (tool/web/sw_update.js), written into build/web.
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

module.exports = { cacheNames, engineRevision, textsHash, writeUpdateScript };
