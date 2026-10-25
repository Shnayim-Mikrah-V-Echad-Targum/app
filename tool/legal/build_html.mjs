#!/usr/bin/env node
// Writes the policies, the support page and the account-deletion page as
// static HTML that needs no JavaScript: the public URLs the app stores ask
// for (docs/RELEASE.md). Plain Node, no dependencies. After `flutter build web`:
//
//   SUPPORT_EMAIL=… node tool/legal/build_html.mjs build/web
//
// writes build/web/legal/<doc>.html in English and <doc>.he.html in Hebrew,
// for every doc in DOCS.
//
// The texts are in assets/legal/legal.json, which the app shows too, so the
// pages never drift from it. It is shaped as
//   {updated: {doc: 'yyyy-mm'}, titles: {en: {doc: title}}, en: {doc: [
//     {heading, when?, blocks: [{type: 'para' | 'bullet' | 'contact', text,
//     when?, subject?}]}]}, he: …}.
// The app shows the policies (privacy, terms, guidelines, accessibility),
// titled by its own strings (lib/l10n/app_*.arb); the support and
// delete-account pages are web-only, titled in "titles".
//
// In the texts:
//   {contact}          the SUPPORT_EMAIL address, or the issue tracker without one
//   {issues}           the issue tracker (SOURCE_URL/issues)
//   {link:doc}         another of these pages, by its title
//   {name|label}       any of these, with its own link text
// The app's own policies use {contact} alone. A section or block with
// "when": "email" is left out when there is no SUPPORT_EMAIL, and one with
// "when": "no-email" when there is; a contact block's "subject" fills in the
// email's subject.

import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');

export const DOCS = ['privacy', 'terms', 'guidelines', 'accessibility', 'support', 'delete-account'];
export const LANGS = ['en', 'he'];

// Titles of the docs the app shows, from its strings (lib/l10n/app_*.arb).
const ARB_TITLES = {
  privacy: 'privacyTitle',
  terms: 'termsTitle',
  guidelines: 'guidelinesTitle',
  accessibility: 'accessibilityStatement',
};

const UI = {
  en: {
    otherLanguage: 'עברית',
    pages: 'Policies and help',
    open: 'Open Shnayim Mikrah',
  },
  he: {
    otherLanguage: 'English',
    pages: 'מדיניות ועזרה',
    open: 'לפתיחת שניים מקרא',
  },
};

// ---------------------------------------------------------------------------
// Loading everything

/// The docs in both languages, their titles, when each was last updated and
/// the app's strings the pages use, from the repository at [root].
export function loadTexts(root = ROOT) {
  const read = (path) => readFileSync(join(root, path), 'utf8');
  const json = JSON.parse(read('assets/legal/legal.json'));
  const updated = json.updated ?? {};
  for (const [doc, month] of Object.entries(updated)) {
    if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(month)) throw new Error(`"updated" for ${doc} is not yyyy-mm: ${month}`);
  }
  const texts = {};
  for (const lang of LANGS) {
    const arb = JSON.parse(read(`lib/l10n/app_${lang}.arb`));
    const docs = {};
    const titles = {};
    for (const doc of DOCS) {
      const sections = json[lang]?.[doc];
      if (!sections) throw new Error(`no ${lang} text for ${doc}: add it to assets/legal/legal.json`);
      docs[doc] = sections;
      const title = json.titles?.[lang]?.[doc] ?? arb[ARB_TITLES[doc]];
      if (!title) throw new Error(`no ${lang} title for ${doc}: add it to "titles" in assets/legal/legal.json`);
      titles[doc] = title;
    }
    texts[lang] = {
      docs,
      titles,
      updated,
      appTitle: arb.appTitle,
      lastUpdated: arb.legalLastUpdated,
      // The issue tracker's link text, as the app names it.
      issuesLabel: arb.feedbackLinkLabel,
    };
  }
  return texts;
}

/// "October 2026" for '2026-10', in [lang].
export function monthYear(month, lang) {
  const [year, number] = month.split('-').map(Number);
  return new Intl.DateTimeFormat(lang, { year: 'numeric', month: 'long', timeZone: 'UTC' }).format(
    Date.UTC(year, number - 1, 1),
  );
}

/// The issue tracker: SOURCE_URL (as passed to the app with --dart-define),
/// or the app's default in lib/app/config.dart.
export function issuesUrl(env = process.env, root = ROOT) {
  let source = env.SOURCE_URL?.trim();
  if (!source) {
    const config = readFileSync(join(root, 'lib/app/config.dart'), 'utf8');
    source = /'SOURCE_URL',\s*defaultValue:\s*'([^']+)'/.exec(config)?.[1];
    if (!source) throw new Error('lib/app/config.dart has no default SOURCE_URL');
  }
  return `${source.replace(/\/+$/, '')}/issues`;
}

// ---------------------------------------------------------------------------
// HTML

const escape = (text) =>
  text.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);

/// The page's file name in legal/: privacy.html, privacy.he.html.
export const pageFile = (doc, lang) => `${doc}${lang === 'en' ? '' : `.${lang}`}.html`;

/// Whether a section or block with [when] is shown.
function shown(item, email) {
  if (item.when === undefined) return true;
  if (item.when === 'email') return Boolean(email);
  if (item.when === 'no-email') return !email;
  throw new Error(`unknown "when": ${item.when}`);
}

/// [text] as HTML, with its placeholders as links.
function inline(text, ctx, block = {}) {
  let html = '';
  let last = 0;
  for (const match of text.matchAll(/\{([a-z]+)(?::([a-z-]+))?(?:\|([^}]+))?\}/g)) {
    const [whole, name, arg, label] = match;
    html += escape(text.slice(last, match.index));
    last = match.index + whole.length;
    if (name === 'contact' && ctx.email) {
      const subject = block.subject ? `?subject=${encodeURIComponent(block.subject)}` : '';
      html += `<a href="mailto:${escape(ctx.email)}${escape(subject)}" dir="ltr">${escape(label ?? ctx.email)}</a>`;
    } else if (name === 'contact' || name === 'issues') {
      html += `<a href="${escape(ctx.issues)}">${escape(label ?? ctx.issuesLabel)}</a>`;
    } else if (name === 'link' && DOCS.includes(arg)) {
      html += `<a href="${pageFile(arg, ctx.lang)}">${escape(label ?? ctx.titles[arg])}</a>`;
    } else {
      throw new Error(`${ctx.doc} (${ctx.lang}): unknown placeholder ${whole}`);
    }
  }
  return html + escape(text.slice(last));
}

function body(sections, ctx) {
  const out = [];
  for (const section of sections.filter((s) => shown(s, ctx.email))) {
    if (section.heading) out.push(`<h2>${inline(section.heading, ctx)}</h2>`);
    let list = false;
    for (const block of section.blocks.filter((b) => shown(b, ctx.email))) {
      if (!['para', 'bullet', 'contact'].includes(block.type)) throw new Error(`unknown block type: ${block.type}`);
      const bullet = block.type === 'bullet';
      if (bullet !== list) out.push(bullet ? '<ul>' : '</ul>');
      list = bullet;
      out.push(bullet ? `  <li>${inline(block.text, ctx, block)}</li>` : `<p>${inline(block.text, ctx, block)}</p>`);
    }
    if (list) out.push('</ul>');
  }
  return out.join('\n');
}

/// A plain-text summary for the description meta tag.
function summary(sections) {
  const text = sections[0].blocks[0].text.replace(/\{([a-z]+)(?::[a-z-]+)?\|([^}]+)\}/g, '$2');
  return text.length <= 160 ? text : `${text.slice(0, 157).replace(/\s+\S*$/, '')}…`;
}

// Klaf & Techelet (docs/DESIGN_SYSTEM.md §3): light, dark ("Lamplight") and
// the two high-contrast palettes. Headings in onSurface, links in primary.
const CSS = `
@font-face { font-family: 'EB Garamond'; font-weight: 500; font-display: swap; src: url('../assets/assets/fonts/EBGaramond-Medium.ttf') format('truetype'); }
@font-face { font-family: 'EB Garamond'; font-weight: 600; font-display: swap; src: url('../assets/assets/fonts/EBGaramond-SemiBold.ttf') format('truetype'); }
@font-face { font-family: 'Frank Ruhl Libre'; font-weight: 500; font-display: swap; src: url('../assets/assets/fonts/FrankRuhlLibre-Medium.ttf') format('truetype'); }
@font-face { font-family: 'Frank Ruhl Libre'; font-weight: 600; font-display: swap; src: url('../assets/assets/fonts/FrankRuhlLibre-SemiBold.ttf') format('truetype'); }
@font-face { font-family: 'Frank Ruhl Libre'; font-weight: 700; font-display: swap; src: url('../assets/assets/fonts/FrankRuhlLibre-Bold.ttf') format('truetype'); }
:root {
  color-scheme: light;
  --surface: #FAF7F0; --on-surface: #1E1A16; --muted: #575046; --primary: #1D3F75;
  --hairline: #D8CFBF; --gold-leaf: #B38D3F; --focus: #1D3F75; --rule: 1px;
  --serif: 'EB Garamond', 'Frank Ruhl Libre', Georgia, 'Times New Roman', serif;
  --sans: system-ui, -apple-system, 'Segoe UI', Roboto, 'Noto Sans', 'Noto Sans Hebrew', Arial, sans-serif;
}
@media (prefers-color-scheme: dark) {
  :root { color-scheme: dark; --surface: #14120F; --on-surface: #EDE6D6; --muted: #C4BAA8; --primary: #AFC6EE;
    --hairline: #4A443A; --gold-leaf: #B8954B; --focus: #AFC6EE; }
}
/* High contrast draws ornaments in onSurface, with no gold leaf (§3.1). */
@media (prefers-contrast: more) {
  :root { --surface: #FFFFFF; --on-surface: #000000; --muted: #1F1F1F; --primary: #0A2A5E;
    --hairline: #000000; --gold-leaf: #000000; --focus: #000000; --rule: 2px; }
}
@media (prefers-contrast: more) and (prefers-color-scheme: dark) {
  :root { --surface: #000000; --on-surface: #FFFFFF; --muted: #EBEBEB; --primary: #B5CEFF;
    --hairline: #FFFFFF; --gold-leaf: #FFFFFF; --focus: #FFFFFF; }
}
:lang(he) { --serif: 'Frank Ruhl Libre', 'EB Garamond', 'David', 'Times New Roman', serif; }
* { box-sizing: border-box; }
html { background: var(--surface); color: var(--on-surface); -webkit-text-size-adjust: 100%; text-size-adjust: 100%; }
body { margin: 0; font: 500 1.25rem/1.6 var(--serif); letter-spacing: 0.1px; }
:lang(he) body { font-size: 1.125rem; line-height: 1.667; letter-spacing: 0; }
.page { max-width: 42rem; margin: 0 auto; padding: 0 1rem; }
@media (min-width: 600px) { .page { padding: 0 1.5rem; } }
header { display: flex; align-items: center; justify-content: space-between; gap: 1rem; padding: 1rem 0;
  border-bottom: var(--rule) solid var(--hairline); }
header a { display: inline-flex; align-items: center; min-height: 48px; }
.brand { gap: 0.75rem; color: var(--on-surface); text-decoration: none; font-size: 1.375rem; line-height: 1.27; }
.brand img { border-radius: 22%; flex: none; }
.lang { font: 500 0.9375rem/1.33 var(--sans); }
main { padding: 2.5rem 0 3rem; }
h1 { margin: 0; font-size: 2rem; line-height: 1.25; font-weight: inherit; }
.title::after { content: ''; display: block; width: 4rem; margin-top: 1.25rem; border-top: var(--rule) solid var(--gold-leaf); }
.updated { margin: 0.375rem 0 0; font: 400 0.9375rem/1.47 var(--sans); color: var(--muted); }
main h2 { margin: 2.25rem 0 0; font-size: 1.5rem; line-height: 1.25; font-weight: inherit; }
:lang(he) h1 { font-size: 1.875rem; line-height: 1.4; }
:lang(he) main h2 { font-size: 1.375rem; line-height: 1.36; font-weight: 600; }
p, ul { margin: 0.75rem 0 0; }
.title + p { margin-top: 1.5rem; }
ul { padding-inline-start: 1.25em; }
li + li { margin-top: 0.375rem; }
li::marker { color: var(--muted); }
a { color: var(--primary); text-decoration-thickness: 1px; text-underline-offset: 0.18em; overflow-wrap: anywhere; }
a:hover { text-decoration-thickness: 2px; }
a:focus-visible { outline: 2px solid var(--focus); outline-offset: 2px; border-radius: 2px; }
footer { padding: 1.5rem 0 3rem; border-top: var(--rule) solid var(--hairline); font: 400 0.9375rem/1.47 var(--sans); color: var(--muted); }
footer h2 { margin: 0; font: inherit; font-weight: 500; color: var(--muted); }
footer ul { display: flex; flex-wrap: wrap; gap: 0 1.5rem; margin: 0.25rem 0 0; padding: 0; list-style: none; }
footer li + li { margin: 0; }
footer a { display: inline-flex; align-items: center; min-height: 48px; }
footer [aria-current] { color: var(--on-surface); text-decoration: none; }
/* High contrast: EB Garamond at 600, Frank Ruhl Libre at 700 (§4.5). */
@media (prefers-contrast: more) {
  main, .brand { font-weight: 600; }
  :lang(he) main, :lang(he) main h2, :lang(he) .brand { font-weight: 700; }
}
@media print {
  :root { --surface: #FFFFFF; --on-surface: #000000; --primary: #000000; }
  header, footer { display: none; }
}
`;

/// When [doc] was last updated, under its title, if legal.json says.
function updatedLine(doc, ctx) {
  const month = ctx.updated[doc];
  if (!month) return '';
  return `\n<p class="updated">${escape(ctx.lastUpdated.replace('{date}', monthYear(month, ctx.lang)))}</p>`;
}

function page(doc, ctx) {
  const { lang, titles } = ctx;
  const other = lang === 'en' ? 'he' : 'en';
  const he = lang === 'he';
  const title = titles[doc];
  const nav = DOCS.map((d) => {
    const current = d === doc ? ' aria-current="page"' : '';
    return `      <li><a href="${pageFile(d, lang)}"${current}>${escape(titles[d])}</a></li>`;
  }).join('\n');
  return `<!DOCTYPE html>
<html lang="${lang}" dir="${he ? 'rtl' : 'ltr'}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light dark">
<meta name="theme-color" content="#FAF7F0" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#14120F" media="(prefers-color-scheme: dark)">
<title>${escape(title)} · ${escape(ctx.appTitle)}</title>
<meta name="description" content="${escape(summary(ctx.docs[doc]))}">
<link rel="alternate" hreflang="${lang}" href="${pageFile(doc, lang)}">
<link rel="alternate" hreflang="${other}" href="${pageFile(doc, other)}">
<link rel="icon" href="../favicon.ico" sizes="32x32">
<link rel="icon" type="image/png" sizes="32x32" href="../favicon.png">
<link rel="apple-touch-icon" href="../apple-touch-icon.png">
<style>${CSS}</style>
</head>
<body>
<div class="page">
  <header>
    <a class="brand" href="../"><img src="../icons/Icon-192.png" alt="" width="36" height="36">${escape(ctx.appTitle)}</a>
    <a class="lang" href="${pageFile(doc, other)}" hreflang="${other}" lang="${other}">${UI[lang].otherLanguage}</a>
  </header>
  <main>
<div class="title">
<h1>${escape(title)}</h1>${updatedLine(doc, ctx)}
</div>
${body(ctx.docs[doc], ctx)}
  </main>
  <footer>
    <nav aria-labelledby="pages">
      <h2 id="pages">${UI[lang].pages}</h2>
      <ul>
${nav}
      </ul>
    </nav>
    <a href="../">${UI[lang].open}</a>
  </footer>
</div>
</body>
</html>
`;
}

/// Writes every page into [outDir]/legal and returns their paths.
export function build(outDir, { env = process.env, root = ROOT, log = console } = {}) {
  const email = env.SUPPORT_EMAIL?.trim() ?? '';
  if (email && !/^[^\s@]+@[^\s@]+$/.test(email)) throw new Error(`SUPPORT_EMAIL is not an email address: ${email}`);
  if (!email) {
    const message =
      'SUPPORT_EMAIL is not set: the pages point to the issue tracker, and delete-account has no email route';
    log.warn(env.GITHUB_ACTIONS ? `::warning::${message}` : `build_html: ${message}`);
  }
  const issues = issuesUrl(env, root);
  const texts = loadTexts(root);
  const dir = join(outDir, 'legal');
  mkdirSync(dir, { recursive: true });
  const written = [];
  for (const lang of LANGS) {
    for (const doc of DOCS) {
      const path = join(dir, pageFile(doc, lang));
      writeFileSync(path, page(doc, { ...texts[lang], lang, doc, email, issues }));
      written.push(path);
    }
  }
  return written;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const outDir = resolve(process.argv[2] ?? join(ROOT, 'build', 'web'));
  try {
    const written = build(outDir);
    console.log(`Wrote ${written.length} pages to ${join(outDir, 'legal')}`);
  } catch (e) {
    console.error(`build_html: ${e.message}`);
    process.exit(1);
  }
}
