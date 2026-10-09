// Generates the text and parsha assets bundled with the app.
//
//   cd tool/data && npm ci && NODE_USE_ENV_PROXY=1 node build_data.mjs
//
// Sources (downloaded into tool/data/.cache on first run):
//   * Torah & haftarah Hebrew: "Miqra according to the Masorah" (MAM), CC BY-SA 4.0,
//     via the Sefaria public export bucket.
//   * Targum Onkelos: Torat Emet edition (public domain), via Sefaria.
//   * English: JPS 1917 (public domain), via Sefaria.
//   * Rashi, Hebrew and English: Rosenbaum & Silbermann, London 1929–1934
//     (public domain), via Sefaria.
//   * Aliyah divisions & haftarah references: @hebcal/leyning (BSD-2-Clause).
//
// Output (all under the Flutter project):
//   assets/text/mikra/<book>.json      structured Hebrew text with section breaks
//   assets/text/onkelos/<book>.json    Aramaic text
//   assets/text/english/<book>.json    English text
//   assets/text/rashi/<book>.json      Rashi (Hebrew), per verse
//   assets/text/rashi_en/<book>.json   Rashi (English), per verse
//   assets/text/haftarot.json          only the Nevi'im verses any haftarah uses
//   assets/data/parshiyot.json         parsha metadata, aliyot, haftarah refs

import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {getLeyningForParsha, getLeyningOnDate} from '@hebcal/leyning';
import {HDate} from '@hebcal/core';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..', '..');
const cacheDir = path.join(here, '.cache');
const BUCKET = 'https://storage.googleapis.com/sefaria-export/json';

const TORAH = ['Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy'];
const BOOK_HE = {
  Genesis: 'בראשית', Exodus: 'שמות', Leviticus: 'ויקרא', Numbers: 'במדבר', Deuteronomy: 'דברים',
  Joshua: 'יהושע', Judges: 'שופטים', 'I Samuel': 'שמואל א', 'II Samuel': 'שמואל ב',
  'I Kings': 'מלכים א', 'II Kings': 'מלכים ב', Isaiah: 'ישעיהו', Jeremiah: 'ירמיהו',
  Ezekiel: 'יחזקאל', Hosea: 'הושע', Joel: 'יואל', Amos: 'עמוס', Obadiah: 'עובדיה',
  Jonah: 'יונה', Micah: 'מיכה', Nahum: 'נחום', Habakkuk: 'חבקוק', Zephaniah: 'צפניה',
  Haggai: 'חגי', Zechariah: 'זכריה', Malachi: 'מלאכי',
};

// Ashkenazi-pronunciation transliterations, keyed by the Sephardi-style keys
// used throughout the app (which match @hebcal's parsha names).
const ASHKENAZI = {
  'Bereshit': 'Bereishis', 'Noach': 'Noach', 'Lech-Lecha': 'Lech Lecha', 'Vayera': 'Vayeira',
  'Chayei Sara': 'Chayei Sarah', 'Toldot': 'Toldos', 'Vayetzei': 'Vayeitzei',
  'Vayishlach': 'Vayishlach', 'Vayeshev': 'Vayeishev', 'Miketz': 'Mikeitz', 'Vayigash': 'Vayigash',
  'Vayechi': 'Vayechi', 'Shemot': 'Shemos', 'Vaera': "Va'eira", 'Bo': 'Bo', 'Beshalach': 'Beshalach',
  'Yitro': 'Yisro', 'Mishpatim': 'Mishpatim', 'Terumah': 'Terumah', 'Tetzaveh': 'Tetzaveh',
  'Ki Tisa': 'Ki Sisa', 'Vayakhel': 'Vayakhel', 'Pekudei': 'Pekudei', 'Vayikra': 'Vayikra',
  'Tzav': 'Tzav', 'Shmini': 'Shemini', 'Tazria': 'Tazria', 'Metzora': 'Metzora',
  'Achrei Mot': 'Acharei Mos', 'Kedoshim': 'Kedoshim', 'Emor': 'Emor', 'Behar': 'Behar',
  'Bechukotai': 'Bechukosai', 'Bamidbar': 'Bamidbar', 'Nasso': 'Nasso',
  "Beha'alotcha": "Beha'aloscha", "Sh'lach": 'Shelach', 'Korach': 'Korach', 'Chukat': 'Chukas',
  'Balak': 'Balak', 'Pinchas': 'Pinchas', 'Matot': 'Matos', 'Masei': 'Masei', 'Devarim': 'Devarim',
  'Vaetchanan': "Va'eschanan", 'Eikev': 'Eikev', "Re'eh": "Re'eh", 'Shoftim': 'Shoftim',
  'Ki Teitzei': 'Ki Seitzei', 'Ki Tavo': 'Ki Savo', 'Nitzavim': 'Nitzavim', 'Vayeilech': 'Vayeilech',
  "Ha'azinu": "Ha'azinu", 'Vezot Haberakhah': 'Vezos Habrachah',
};

const COMBINED = [
  ['Vayakhel', 'Pekudei'], ['Tazria', 'Metzora'], ['Achrei Mot', 'Kedoshim'],
  ['Behar', 'Bechukotai'], ['Chukat', 'Balak'], ['Matot', 'Masei'], ['Nitzavim', 'Vayeilech'],
];

// ---------------------------------------------------------------------------
// Downloading

async function fetchSource(relPath) {
  const file = path.join(cacheDir, relPath.replace(/[\/ ]/g, '_'));
  if (fs.existsSync(file)) return JSON.parse(fs.readFileSync(file, 'utf8'));
  const url = `${BUCKET}/${relPath.split('/').map(encodeURIComponent).join('/')}`;
  process.stdout.write(`  downloading ${relPath}\n`);
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${res.status} for ${url}`);
  const text = await res.text();
  fs.mkdirSync(cacheDir, {recursive: true});
  fs.writeFileSync(file, text);
  return JSON.parse(text);
}

const mamPath = (book) => {
  const cat = TORAH.includes(book) ? 'Torah' : ['Joshua', 'Judges', 'I Samuel', 'II Samuel', 'I Kings', 'II Kings'].includes(book) ? 'Prophets' : 'Prophets';
  return `Tanakh/${cat}/${book}/Hebrew/Miqra according to the Masorah.json`;
};
const jpsPath = (book) => `Tanakh/${TORAH.includes(book) ? 'Torah' : 'Prophets'}/${book}/English/The Holy Scriptures A New Translation JPS 1917.json`;
const onkPath = (book) => `Tanakh/Targum/Onkelos/Torah/Onkelos ${book}/Hebrew/Onkelos ${book}.json`;
const RASHI_VERSION = "Pentateuch with Rashi's commentary by M. Rosenbaum and A.M. Silbermann, 1929-1934";
const rashiPath = (book, lang) => {
  // Sefaria titles the Numbers Hebrew edition by its corrected vocalization.
  const version = book === 'Numbers' && lang === 'Hebrew' ? `${RASHI_VERSION.replace(', 1929-1934', '')} -- corrected vocalization` : RASHI_VERSION;
  return `Tanakh/Rishonim on Tanakh/Rashi/Torah/Rashi on ${book}/${lang}/${version}.json`;
};

// ---------------------------------------------------------------------------
// Parsing
//
// A verse is emitted either as a plain string or, when it contains special
// features, as a list of segments:
//   "text"                plain text
//   {"k": K, "q": Q}      ketiv (as written, unvocalized) / qere (as read)
//   {"n": note}           textual note (e.g. Ashkenazi/Sephardi scribal variant)
//   {"big": x} / {"small": x} / {"sup": x}  large / small / raised letters
//   {"alt": x}            (Onkelos) bracketed alternate reading or gloss

const SONG_GAP = ' '; // em space between hemistichs in the Torah's songs

function stripTags(s) {
  return s.replace(/<[^>]+>/g, '');
}

function finalizeSegments(segs) {
  const out = [];
  for (const seg of segs) {
    if (typeof seg === 'string') {
      if (!seg) continue;
      if (typeof out[out.length - 1] === 'string') out[out.length - 1] += seg;
      else out.push(seg);
    } else {
      out.push(seg);
    }
  }
  // Normalize whitespace inside strings.
  for (let i = 0; i < out.length; i++) {
    if (typeof out[i] === 'string') {
      out[i] = out[i].replace(/ {2,}/g, ' ');
      if (i === 0) out[i] = out[i].replace(/^[ \u2003]+/, '');
      if (i === out.length - 1) out[i] = out[i].replace(/[ \u2003]+$/, '');
    }
  }
  const cleaned = out.filter((s) => s !== '');
  for (const s of cleaned) {
    const str = typeof s === 'string' ? s : Object.values(s).join('');
    if (/[<>&]/.test(str)) throw new Error(`Unparsed markup left in: ${str}`);
  }
  if (cleaned.length === 1 && typeof cleaned[0] === 'string') return cleaned[0];
  return cleaned;
}

function parseMamVerse(raw) {
  let s = raw;
  let brk = null;
  if (s.includes('mam-spi-pe')) brk = 'P';
  else if (s.includes('mam-spi-samekh')) brk = 'S';
  s = s.replace(/(?:&nbsp;)*<span class="mam-spi-(?:pe|samekh)">\{[פס]\}<\/span>(?:<br>)?(?:&nbsp;)*/g, '');
  // Paseq / legarmeih: MAM distinguishes them visually; for readers a plain paseq suffices.
  s = s.replace(/&thinsp;<(small|b)>׀<\/\1>(?:&thinsp;)?/g, ' ׀ ');
  s = s.replace(/<span class="mam-spi-invnun">׆<\/span>(?:&nbsp;)?/g, '׆ ');
  s = s.replace(/<span class="mam-kq-trivial">([^<]*)<\/span>/g, '$1');
  s = s.replace(/(?:&nbsp;){2,}/g, ` ${SONG_GAP} `);
  s = s.replace(/&nbsp;/g, ' ').replace(/&thinsp;/g, ' ');

  const segs = [];
  const re = new RegExp(
    [
      // 1-4: ketiv/qere in either order
      '<span class="mam-kq"><span class="mam-kq-(k|q)">([^<]*)</span>[\\s־]*<span class="mam-kq-(k|q)">([^<]*)</span></span>',
      // 5: footnote
      '<sup class="footnote-marker">\\*</sup><i class="footnote">(.*?)</i>',
      // 6-7: big/small/sup letters
      '<(big|small|sup)>([^<]*)</\\6>',
      // 8-9: ketiv without qere / qere without ketiv
      '<span class="mam-kq-(k|q)">([^<]*)</span>',
    ].join('|'),
    'g',
  );
  let last = 0;
  for (const m of s.matchAll(re)) {
    segs.push(s.slice(last, m.index));
    last = m.index + m[0].length;
    if (m[1]) {
      const parts = {[m[1]]: m[2], [m[3]]: m[4]};
      const k = parts.k.replace(/^\(|\)$/g, '').trim();
      const q = parts.q.replace(/^\[|\]$/g, '').trim();
      segs.push({k, q});
    } else if (m[5] !== undefined) {
      segs.push({n: stripTags(m[5]).replace(/^\(|\)$/g, '').trim()});
    } else if (m[6]) {
      segs.push({[m[6]]: m[7]});
    } else if (m[8]) {
      // e.g. 2 Kings 5:18 "(נא)־" is written but not read; Jer 31:38 "[בָּאִים]" is read but not written.
      const t = m[9].trim();
      if (m[8] === 'k') segs.push({k: t.replace(/^\(|\)(־?)$/g, '$1'), q: ''});
      else segs.push({k: '', q: t.replace(/^\[|\]$/g, '')});
    }
  }
  segs.push(s.slice(last));
  return {verse: finalizeSegments(segs), brk};
}

function parseOnkelosVerse(raw) {
  let s = raw.replace(/‎/g, '').replace(/''/g, '״').replace(/\s+/g, ' ').trim();
  s = s.replace(/\s*:$/, '');
  const segs = [];
  let last = 0;
  for (const m of s.matchAll(/\(([^)]*)\)/g)) {
    segs.push(s.slice(last, m.index));
    segs.push({alt: m[1].trim()});
    last = m.index + m[0].length;
  }
  segs.push(s.slice(last));
  return finalizeSegments(segs);
}

// Rashi comments are "<b>dibbur hamatchil.</b> comment". Emitted as
// {"d": heading, "t": text} or a plain string when there is no heading.
function parseRashiComment(raw) {
  const s = raw.replace(/<\/?small>/g, '').replace(/\s+/g, ' ').trim();
  const m = s.match(/^<b>(.*?)<\/b>\s*(.*)$/);
  const clean = (x) => {
    const out = x.replace(/<\/?(b|i)>/g, '').trim();
    if (/[<>]/.test(out)) throw new Error(`Unparsed Rashi markup: ${out}`);
    return out;
  };
  return m ? {d: clean(m[1]), t: clean(m[2])} : clean(s);
}

function parseRashiEnglish(raw) {
  const out = raw.replace(/<\/?(i|b|small)>/g, '').replace(/<br\s*\/?>/g, ' ').replace(/\s+/g, ' ').trim();
  if (/[<>]/.test(out)) throw new Error(`Unparsed Rashi markup: ${out}`);
  return out;
}

// Pads/truncates a commentary (chapter → verse → comments) to the verse
// structure of the Torah text so indices line up.
function alignCommentary(text, chapters, parse) {
  return chapters.map((ch, ci) =>
    ch.map((_, vi) => ((text[ci] || [])[vi] || []).filter((c) => c && c.trim()).map(parse)),
  );
}

function parseEnglishVerse(raw) {
  return raw.replace(/<br>/g, ' ').replace(/<\/?small>/g, '').replace(/\s+/g, ' ').trim();
}

// ---------------------------------------------------------------------------
// Parsha metadata

function refs(h) {
  if (!h) return undefined;
  const list = Array.isArray(h) ? h.flat() : [h];
  return list.map((x) => ({k: x.k, b: x.b, e: x.e}));
}

function leyningEntry(key) {
  const l = getLeyningForParsha(key);
  const fk = l.fullkriyah;
  const aliyot = [];
  for (let i = 1; i <= 7; i++) {
    const a = fk[String(i)];
    const entry = {b: a.b, e: a.e};
    if (a.reason) entry.note = a.reason;
    aliyot.push(entry);
  }
  const book = fk['1'].k;
  for (let i = 2; i <= 7; i++) {
    if (fk[String(i)].k !== book) throw new Error(`${key}: aliyot span books`);
  }
  const out = {
    key,
    he: l.name.he,
    book,
    start: aliyot[0].b,
    end: aliyot[6].e,
    aliyot,
  };
  if (fk.M) out.maftir = {b: fk.M.b, e: fk.M.e};
  const haftarah = {ashkenazi: refs(l.haft)};
  if (l.seph) haftarah.sephardi = refs(l.seph);
  if (l.chabad) haftarah.chabad = refs(l.chabad);
  out.haftarah = haftarah;
  return out;
}

// ---------------------------------------------------------------------------

function writeJson(rel, data) {
  const file = path.join(root, rel);
  fs.mkdirSync(path.dirname(file), {recursive: true});
  fs.writeFileSync(file, JSON.stringify(data) + '\n');
  const kb = (fs.statSync(file).size / 1024).toFixed(0);
  process.stdout.write(`  wrote ${rel} (${kb} KB)\n`);
}

function cmp(a, b) {
  const [ac, av] = a.split(':').map(Number);
  const [bc, bv] = b.split(':').map(Number);
  return ac - bc || av - bv;
}

function nextVerse(chapters, ref) {
  let [c, v] = ref.split(':').map(Number);
  if (v < chapters[c - 1].length) return `${c}:${v + 1}`;
  return `${c + 1}:1`;
}

function* versesInRange(chapters, b, e) {
  let ref = b;
  while (true) {
    yield ref;
    if (ref === e) return;
    ref = nextVerse(chapters, ref);
    if (cmp(ref, e) > 0) throw new Error(`bad range ${b}-${e}`);
  }
}

async function main() {
  const lower = (b) => b.toLowerCase();
  const mikraChapters = {};

  process.stdout.write('Torah text\n');
  for (const book of TORAH) {
    const mam = await fetchSource(mamPath(book));
    const onk = await fetchSource(onkPath(book));
    const jps = await fetchSource(jpsPath(book));
    if (mam.license !== 'CC-BY-SA' || onk.license !== 'Public Domain' || jps.license !== 'Public Domain') {
      throw new Error(`Unexpected license for ${book}`);
    }
    const breaks = {};
    const chapters = mam.text.map((ch, ci) =>
      ch.map((raw, vi) => {
        const {verse, brk} = parseMamVerse(raw);
        if (brk) breaks[`${ci + 1}:${vi + 1}`] = brk;
        return verse;
      }),
    );
    mikraChapters[book] = chapters;
    const counts = (t) => t.map((c) => c.length).join(',');
    if (counts(mam.text) !== counts(onk.text) || counts(mam.text) !== counts(jps.text)) {
      throw new Error(`Versification mismatch in ${book}`);
    }
    writeJson(`assets/text/mikra/${lower(book)}.json`, {book, he: BOOK_HE[book], chapters, breaks});
    writeJson(`assets/text/onkelos/${lower(book)}.json`, {
      book,
      chapters: onk.text.map((ch) => ch.map(parseOnkelosVerse)),
    });
    writeJson(`assets/text/english/${lower(book)}.json`, {
      book,
      chapters: jps.text.map((ch) => ch.map(parseEnglishVerse)),
    });

    const rashiHe = await fetchSource(rashiPath(book, 'Hebrew'));
    const rashiEn = await fetchSource(rashiPath(book, 'English'));
    if (rashiHe.license !== 'Public Domain' || rashiEn.license !== 'Public Domain') throw new Error(`Rashi license ${book}`);
    writeJson(`assets/text/rashi/${lower(book)}.json`, {
      book,
      chapters: alignCommentary(rashiHe.text, mam.text, parseRashiComment),
    });
    writeJson(`assets/text/rashi_en/${lower(book)}.json`, {
      book,
      chapters: alignCommentary(rashiEn.text, mam.text, parseRashiEnglish),
    });
  }

  process.stdout.write('Parsha metadata\n');
  const keys = Object.keys(ASHKENAZI);
  const parshiyot = keys.map((key, i) => ({num: i + 1, ...leyningEntry(key), ashkenazi: ASHKENAZI[key]}));
  const combined = COMBINED.map(([a, b]) => {
    const e = leyningEntry(`${a}-${b}`);
    return {...e, ashkenazi: `${ASHKENAZI[a]}-${ASHKENAZI[b]}`, parts: [keys.indexOf(a) + 1, keys.indexOf(b) + 1]};
  });

  // Sanity: aliyot are contiguous and cover each parsha exactly.
  for (const p of [...parshiyot, ...combined]) {
    const ch = mikraChapters[p.book];
    for (let i = 1; i < 7; i++) {
      if (nextVerse(ch, p.aliyot[i - 1].e) !== p.aliyot[i].b) throw new Error(`${p.key}: gap before aliyah ${i + 1}`);
    }
  }
  for (const c of combined) {
    const [a, b] = c.parts.map((n) => parshiyot[n - 1]);
    if (a.start !== c.start || b.end !== c.end) throw new Error(`${c.key}: range mismatch`);
  }

  // Special haftarot (Shekalim, Chanukah, Rosh Chodesh, ...), keyed by hebcal's reason text.
  const special = {};
  const allHaftarahRefs = [];
  for (const p of [...parshiyot, ...combined]) {
    for (const list of Object.values(p.haftarah)) allHaftarahRefs.push(...list);
  }
  for (const il of [false, true]) {
    let d = new HDate(new Date(2000, 0, 1));
    while (d.getDay() !== 6) d = d.next();
    const end = new HDate(new Date(2100, 0, 1));
    for (; d.deltaDays(end) < 0; d = d.add(7, 'd')) {
      const l = getLeyningOnDate(d, il);
      if (!l || !l.reason || !l.reason.haftara) continue;
      const reason = l.reason.haftara;
      const entry = {ashkenazi: refs(l.haft)};
      if (l.seph) entry.sephardi = refs(l.seph);
      const prev = special[reason];
      if (prev && JSON.stringify(prev) !== JSON.stringify(entry)) throw new Error(`Inconsistent special haftarah ${reason}`);
      special[reason] = entry;
      allHaftarahRefs.push(...entry.ashkenazi, ...(entry.sephardi || []));
    }
  }

  const chapterLengths = Object.fromEntries(TORAH.map((b) => [b, mikraChapters[b].map((c) => c.length)]));
  writeJson('assets/data/parshiyot.json', {parshiyot, combined, specialHaftarot: special, chapterLengths});

  process.stdout.write('Haftarot\n');
  const haftHe = {};
  const haftEn = {};
  const needed = {};
  for (const r of allHaftarahRefs) (needed[r.k] ||= []).push(r);
  for (const book of Object.keys(needed).sort()) {
    const mam = await fetchSource(mamPath(book));
    const jps = await fetchSource(jpsPath(book));
    if (mam.license !== 'CC-BY-SA' || jps.license !== 'Public Domain') throw new Error(`license ${book}`);
    haftHe[book] = {};
    haftEn[book] = {};
    for (const r of needed[book]) {
      for (const ref of versesInRange(mam.text, r.b, r.e)) {
        const [c, v] = ref.split(':').map(Number);
        haftHe[book][ref] = parseMamVerse(mam.text[c - 1][v - 1]).verse;
        haftEn[book][ref] = parseEnglishVerse(jps.text[c - 1][v - 1]);
      }
    }
  }
  writeJson('assets/text/haftarot.json', {
    books: Object.fromEntries(Object.keys(needed).map((b) => [b, BOOK_HE[b]])),
    he: haftHe,
    en: haftEn,
  });
  process.stdout.write('Done.\n');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
