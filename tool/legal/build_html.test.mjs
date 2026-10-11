// Tests for build_html.mjs:  node --test tool/legal/build_html.test.mjs
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { after, describe, it } from 'node:test';

import { DOCS, LANGS, build, issuesUrl, loadTexts, monthYear } from './build_html.mjs';

const ROOT = new URL('../../', import.meta.url);
const read = (path) => readFileSync(new URL(path, ROOT), 'utf8');
const quiet = { warn() {} };
const dirs = [];
after(() => dirs.forEach((dir) => rmSync(dir, { recursive: true, force: true })));

function buildInto(env) {
  const dir = mkdtempSync(join(tmpdir(), 'legal-'));
  dirs.push(dir);
  build(dir, { env, log: quiet });
  return (doc, lang = 'en') => readFileSync(join(dir, 'legal', `${doc}${lang === 'en' ? '' : `.${lang}`}.html`), 'utf8');
}

describe('the texts', () => {
  const texts = loadTexts();

  it('has every doc and title in both languages', () => {
    for (const lang of LANGS) {
      assert.deepEqual(Object.keys(texts[lang].docs), DOCS);
      for (const doc of DOCS) assert.ok(texts[lang].titles[doc], `${lang} ${doc}`);
    }
  });

  it("gives every Hebrew page the shape of the English one", () => {
    const json = JSON.parse(read('assets/legal/legal.json'));
    assert.deepEqual(Object.keys(json.he), Object.keys(json.en));
    const shape = (sections) =>
      sections.map((s) => [s.when, Boolean(s.heading), s.blocks.map((b) => [b.type, b.when, Boolean(b.subject)])]);
    for (const doc of Object.keys(json.en)) {
      assert.deepEqual(shape(json.he[doc]), shape(json.en[doc]), doc);
    }
  });

  it("has the app's policies, which say how to reach us with {contact} alone", () => {
    const json = JSON.parse(read('assets/legal/legal.json'));
    for (const lang of LANGS) {
      for (const doc of ['privacy', 'terms', 'guidelines', 'accessibility']) {
        const blocks = json[lang][doc].flatMap((s) => s.blocks);
        assert.ok(blocks.length > 2, `${lang} ${doc}`);
        for (const { type, text } of blocks) {
          const placeholders = text.match(/\{[^}]*\}/g) ?? [];
          assert.deepEqual(placeholders, type === 'contact' ? ['{contact}'] : [], `${lang} ${doc}: ${text}`);
        }
      }
    }
    assert.match(json.en.privacy[0].blocks[0].text, /^Shnayim Mikra is built to need as little/);
  });

  it('says when each page was last updated, as a month', () => {
    for (const doc of DOCS) assert.match(texts.en.updated[doc], /^\d{4}-\d{2}$/, doc);
    assert.equal(monthYear('2026-10', 'en'), 'October 2026');
    assert.equal(monthYear('2026-10', 'he'), 'אוקטובר 2026');
  });

  it('takes the issue tracker from SOURCE_URL or the app config', () => {
    assert.equal(issuesUrl({ SOURCE_URL: 'https://example.org/repo/' }), 'https://example.org/repo/issues');
    assert.match(issuesUrl({}), /^https:\/\/github\.com\/.+\/issues$/);
  });
});

describe('the pages', () => {
  it('are static, in the language and direction of their text', () => {
    const page = buildInto({ SUPPORT_EMAIL: 'help@example.org' });
    for (const doc of DOCS) {
      const en = page(doc);
      const he = page(doc, 'he');
      assert.match(en, /^<!DOCTYPE html>\n<html lang="en" dir="ltr">/);
      assert.match(he, /^<!DOCTYPE html>\n<html lang="he" dir="rtl">/);
      for (const html of [en, he]) {
        assert.doesNotMatch(html, /<script/i);
        assert.doesNotMatch(html, /\{(contact|issues|link)/, `${doc}: a placeholder is left`);
        assert.match(html, /<h1>[^<]+<\/h1>/);
      }
      assert.match(en, new RegExp(`<a class="lang" href="${doc}.he.html" hreflang="he" lang="he">`));
    }
  });

  it('link the support address, with the subject an account deletion needs', () => {
    const page = buildInto({ SUPPORT_EMAIL: 'help@example.org' });
    assert.match(page('privacy'), /Questions or requests: <a href="mailto:help@example\.org" dir="ltr">help@example\.org<\/a>/);
    assert.match(page('delete-account'), /<h2>By email<\/h2>/);
    assert.match(page('delete-account'), /href="mailto:help@example\.org\?subject=Delete%20my%20account"/);
    assert.match(page('support'), /<a href="https:\/\/github\.com\/[^"]+\/issues">GitHub issue tracker<\/a>/);
    assert.match(page('support'), /<a href="delete-account\.html">Delete your account<\/a>/);
    assert.match(page('support', 'he'), /<a href="delete-account\.he\.html">מחיקת החשבון<\/a>/);
    // The bullets become a list item each, beside the footer's one for each
    // page.
    const bullets = JSON.parse(read('assets/legal/legal.json'))
      .en.accessibility.flatMap((s) => s.blocks)
      .filter((b) => b.type === 'bullet').length;
    assert.ok(bullets > 0);
    const main = page('accessibility').split('<main>')[1].split('</main>')[0];
    assert.equal(main.match(/<li>/g).length, bullets);
    assert.equal(main.match(/<ul>/g).length, 1);
    assert.equal(page('accessibility').match(/<li>/g).length, bullets + DOCS.length);
  });

  it('say under the title when the page was last updated', () => {
    const page = buildInto({});
    assert.match(page('privacy'), /<h1>Privacy policy<\/h1>\n<p class="updated">Last updated: October 2026<\/p>\n<\/div>/);
    assert.match(page('privacy', 'he'), /<p class="updated">עודכן לאחרונה: אוקטובר 2026<\/p>/);
    // The date left the opening paragraph for its own line.
    assert.doesNotMatch(page('privacy'), /<p>[^<]*Last updated/);
  });

  it('draw the gold rule in the text colour in high contrast', () => {
    const css = buildInto({})('privacy').split('<style>')[1].split('</style>')[0];
    const contrast = [...css.matchAll(/@media \(prefers-contrast: more\)[^{]*\{\s*:root \{([^}]*)\}/g)];
    assert.equal(contrast.length, 2);
    for (const [, vars] of contrast) {
      const value = (name) => new RegExp(`--${name}: (#[0-9A-F]{6})`).exec(vars)[1];
      assert.equal(value('gold-leaf'), value('on-surface'));
    }
  });

  it('give every link a 48 px target', () => {
    const css = buildInto({})('privacy').split('<style>')[1].split('</style>')[0];
    for (const selector of ['header a', 'footer a']) {
      assert.match(css, new RegExp(`\\n${selector} \\{[^}]*min-height: 48px`), selector);
    }
  });

  it('point to the issue tracker without a support address', () => {
    const page = buildInto({});
    assert.match(page('privacy'), /Questions or requests: <a href="https:\/\/github\.com\/[^"]+\/issues">GitHub issues<\/a>/);
    assert.match(page('privacy', 'he'), /<a href="https:\/\/github\.com\/[^"]+\/issues">דף התקלות ב־GitHub<\/a>/);
    assert.doesNotMatch(page('delete-account'), /By email|mailto:/);
    assert.doesNotMatch(page('support'), /GitHub issue tracker/);
  });

  it('refuse a support address that is not one', () => {
    assert.throws(() => buildInto({ SUPPORT_EMAIL: 'https://example.org' }), /not an email address/);
  });
});
