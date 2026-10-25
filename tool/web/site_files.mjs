#!/usr/bin/env node
// Writes the site's robots.txt and sitemap.xml into a web build, for the
// address it is served from. CI's site job (ci.yml, site-web) runs, after
// tool/legal/build_html.mjs:
//
//   SITE_URL=https://shnayimmikrah.org/ node tool/web/site_files.mjs build/web
//
// The sitemap lists the app's start and the static pages build_html.mjs
// writes, each with its page in the other language, at the addresses the site
// serves them from: without .html, which the site redirects away from.

import { writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { DOCS, LANGS, loadTexts, pageFile } from '../legal/build_html.mjs';

/// Whether [url] is a site's root address, https://host/.
export const isSiteUrl = (url) => /^https:\/\/[a-z0-9.-]+(:\d+)?\/$/i.test(url ?? '');

export function robots(siteUrl) {
  return [
    'User-agent: *',
    // The accounts' pages and the app's API are not for search results.
    'Disallow: /account',
    'Disallow: /api/',
    '',
    `Sitemap: ${siteUrl}sitemap.xml`,
    '',
  ].join('\n');
}

/// [updated] is legal.json's: when each page was last updated, yyyy-mm.
export function sitemap(siteUrl, updated = loadTexts().en.updated) {
  const address = (doc, lang) => `${siteUrl}legal/${pageFile(doc, lang).replace(/\.html$/, '')}`;
  const urls = [`  <url>\n    <loc>${siteUrl}</loc>\n  </url>`];
  for (const doc of DOCS) {
    for (const lang of LANGS) {
      const lines = [`    <loc>${address(doc, lang)}</loc>`];
      if (updated[doc]) lines.push(`    <lastmod>${updated[doc]}</lastmod>`);
      for (const other of LANGS) {
        lines.push(`    <xhtml:link rel="alternate" hreflang="${other}" href="${address(doc, other)}"/>`);
      }
      urls.push(`  <url>\n${lines.join('\n')}\n  </url>`);
    }
  }
  return [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">',
    ...urls,
    '</urlset>',
    '',
  ].join('\n');
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const siteUrl = process.env.SITE_URL ?? '';
  if (!isSiteUrl(siteUrl)) {
    console.error(`site_files: SITE_URL must be the site's root address, https://host/, not "${siteUrl}"`);
    process.exit(1);
  }
  const outDir = resolve(process.argv[2] ?? 'build/web');
  writeFileSync(join(outDir, 'robots.txt'), robots(siteUrl));
  writeFileSync(join(outDir, 'sitemap.xml'), sitemap(siteUrl));
  console.log(`Wrote robots.txt and sitemap.xml for ${siteUrl} to ${outDir}`);
}
