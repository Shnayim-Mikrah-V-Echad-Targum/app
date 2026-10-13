#!/usr/bin/env node
// Preloads every font the web build loads at start-up. The engine downloads
// the fonts in assets/FontManifest.json only once it runs, and its first
// frame waits for all of them; preloaded from index.html, they download
// while the engine does. After `flutter build web`:
//
//   node tool/web/preload_fonts.mjs build/web
//
// writes into build/web/index.html, between its preload markers, one
//
//   <link rel="preload" href="assets/<asset>" as="fetch" crossorigin>
//
// for the manifest, which the engine reads first, and for each font it
// lists: those declared in pubspec.yaml, Material Icons and, in a build
// without the CDN, the engine's fallback font. The engine reads them with
// fetch(), so as="fetch" (not "font") is what lets it reuse the responses
// instead of downloading them twice. Plain Node, no dependencies.

import { readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

/// The markers in web/index.html between which the preloads go. What is
/// between them in the source, the display fonts' preloads, is for a build
/// that skips this script (flutter run).
const START = '<!-- preload: tool/web/preload_fonts.mjs -->';
const END = '<!-- /preload -->';
const escapeRegExp = (text) => text.replace(/[.*+?^${}()|[\]\\/]/g, '\\$&');
const BLOCK = new RegExp(`^([ \\t]*)${escapeRegExp(START)}\\n[\\s\\S]*?^[ \\t]*${escapeRegExp(END)}$`, 'm');

/// The font assets [manifest] (FontManifest.json, parsed) lists, in its
/// order, each once.
export function fontAssets(manifest) {
  if (!Array.isArray(manifest)) throw new Error('FontManifest.json is not a list of font families');
  const assets = new Set();
  for (const family of manifest) {
    for (const font of family?.fonts ?? []) {
      if (typeof font?.asset !== 'string' || !font.asset) {
        throw new Error(`FontManifest.json has a font without an asset in ${family?.family}`);
      }
      assets.add(font.asset);
    }
  }
  if (assets.size === 0) throw new Error('FontManifest.json lists no fonts');
  return [...assets];
}

const escapeAttribute = (value) => value.replaceAll('&', '&amp;').replaceAll('"', '&quot;');

/// The preload of the build's asset [path], relative to the <base href> as
/// the engine fetches it (assets/<path>, its URL encoded as Uri.encodeFull
/// encodes it).
const preload = (path) => `<link rel="preload" href="${escapeAttribute(encodeURI(`assets/${path}`))}" as="fetch" crossorigin>`;

/// [html] with the preloads of the manifest and of each of [assets] between
/// its markers, indented as the first marker is. Throws without the markers.
export function withPreloads(html, assets) {
  const match = html.match(BLOCK);
  if (!match) throw new Error(`index.html has no ${START} … ${END} block`);
  const indent = match[1];
  const lines = [START, preload('FontManifest.json'), ...assets.map(preload), END];
  return html.replace(BLOCK, () => lines.map((line) => indent + line).join('\n'));
}

/// Writes the preloads into the build in [webDir] and returns the font
/// assets preloaded.
export function preloadFonts(webDir) {
  const manifest = JSON.parse(readFileSync(join(webDir, 'assets', 'FontManifest.json'), 'utf8'));
  const assets = fontAssets(manifest);
  const index = join(webDir, 'index.html');
  writeFileSync(index, withPreloads(readFileSync(index, 'utf8'), assets));
  return assets;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const webDir = resolve(process.argv[2] ?? join('build', 'web'));
  try {
    const assets = preloadFonts(webDir);
    console.log(`Preloaded ${assets.length} fonts and the font manifest in ${join(webDir, 'index.html')}`);
  } catch (e) {
    console.error(`preload_fonts: ${e.message}`);
    process.exit(1);
  }
}
