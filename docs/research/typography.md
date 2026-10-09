# Report B: Hebrew typography for scripture (Flutter: Android, iOS, web, Windows)

Research date: 2026-10-09.

## How this was researched, and what was checked

- **Checked directly:** I downloaded every font listed below from `raw.githubusercontent.com`, pinned to a commit, and inspected it with fontTools 4.66: cmap coverage, OpenType `GPOS`/`GSUB` features and lookup types, metrics, and the license fields in the `name` table. I then rendered Genesis 1:1, Genesis 1:5 and a set of hard cases through HarfBuzz (Pillow 12.3 with libraqm). That is the same shaping engine Flutter uses through SkParagraph on every platform, including CanvasKit and skwasm on the web. I also measured the actual ink extent of the positioned marks against each font's ascent and descent.
- **Limits:** The shared WebSearch budget ran out early in this session, and the sandbox proxy blocks most sites (sourceforge.io/Culmus, sbl-site.org, unicode.org, supabase.com, Wikipedia and Google support all returned 403 or NXDOMAIN). Where a claim comes from prior knowledge or a search-result snippet rather than a page I fetched, it is marked **[unverified]**.

---

## 1. Fonts that render nikud and ta'amim

### 1.1 Coverage measured from the font files

Legend:
- "Ta'amim" = how many of the 31 accents in U+0591–U+05AF have glyphs.
- "Meteg" = U+05BD. "QQ" = qamats qatan, U+05C7.
- "05BE–05C7" = maqaf, rafe, paseq, shin and sin dots, sof pasuq, upper and lower dots, nun hafukha, qamats qatan.
- "mkmk" = has a GPOS mark-to-mark feature, which stacks a mark on top of another mark.

| Font (file tested) | License | Ta'amim | Meteg | QQ | 05BE–05C7 | GPOS | Notes |
|---|---|---|---|---|---|---|---|
| **Noto Serif Hebrew** v2.004, variable `[wdth,wght]` (google/fonts) | OFL 1.1 | 31/31 | ✓ | ✓ | 10/10 | mark + **mkmk** | Default instance is wght 400. Has Latin. 184 KB. Lacks U+034F CGJ, but HarfBuzz hides it anyway (tested). |
| Noto Serif Hebrew static Regular (notofonts.github.io, hinted) | OFL 1.1 | 31/31 | ✓ | ✓ | 10/10 | mark only (**no mkmk**) | Hebrew only, no Latin, 30 KB. Not recommended, because it has no mark-to-mark lookups. |
| **Noto Sans Hebrew** v3.001, variable (google/fonts) | OFL 1.1 | 31/31 | ✓ | ✓ | 10/10 | mark + mkmk | **Pitfall: the default instance is wght = 100 (Thin).** |
| **Taamey Frank CLM** Medium 0.110 (Culmus, Yoram Gnat) | GPL-2.0 + font exception (marks layout: MIT, Hancock & Hudson) | 31/31 | ✓ | ✓ | 10/10 | mark + mkmk | Sefaria's main Hebrew font; Sefaria's copy has the same SHA-256. **Bold has invisible ta'amim** (31 of 31 glyphs empty). 105 KB. |
| **Taamey David CLM** Medium 0.110 | GPL-2.0 + font exception | 31/31 | ✓ | ✓ | 10/10 | mark + mkmk | David style. Bold hides ta'amim (stated in its ChangeLog). |
| **Keter YG** Medium 0.103yg | GPL-2.0 + font exception (layout: MIT) | 31/31 | ✓ | ✓ | 10/10 | mark + mkmk | Based on the Aleppo Codex hand. Also ships in Culmus 0.140. **Bold has invisible ta'amim** (31 of 31 empty). |
| **Ezra SIL** 2.51 (`SILEOT.ttf`), plus Ezra SIL SR (`SILEOTSR.ttf`) | OFL 1.1 (Reserved Font Names "SIL" and "Ezra"); Hebrew layout logic MIT | 31/31 | ✓ | ✓ | 10/10 | mark (lookup types 4, 6, 8, so it does stack marks) | Dated 2007. Has the tallest metrics and needs the most line spacing. The SR variant draws the cantillation differently. |
| **Cardo** 1.0451 (google/fonts) | OFL 1.1 | 31/31 | ✓ | ✓ | 10/10 | mark (no mkmk feature) | Scholarly font with Greek and Latin. 400 KB. Bulky marks. |
| Frank Ruehl CLM 0.140, `.otf` (Culmus tarball) | GPL-2.0 (+ font exception per Culmus LICENSE) | 31/31 | ✓ | ✓ | 10/10 | mark + mkmk | Open Siddur lists it among the full-diacritics fonts. Tight metrics (ink fits in 1.01 em). |
| Shofar Regular 1.6 (Culmus 0.140) | GPL-2.0 + font exception | 31/31 | ✓ | ✓ | 10/10 | mark + mkmk | Sans-like. Marks extend above the ascent (0.98 em against 0.80 em). |
| **Frank Ruhl Libre** 6.004, variable (google/fonts) | OFL 1.1 | **0/31** | ✓ | ✓ | 7/10 (no U+05C4–05C6) | — | **Nikud only, no ta'amim.** Fine for modern Hebrew headings. |
| **David Libre** 1.100 (google/fonts) | OFL 1.1 | **0/31** | **✗** | ✓ | 10/10 | — | **No ta'amim and no meteg.** |
| SBL Hebrew | SBL's own EULA, not OFL/GPL **[unverified; sbl-site.org blocked]** | (full, by reputation) | | | | | It is absent from the Open Siddur "libre" font pack, which suggests it is not freely redistributable. Do not bundle it in an app without written permission from SBL. |

(U+FB37, FB3D, FB3F, FB42 and FB45 show as "missing" in every font only because those code points are unassigned.)

### 1.2 Rendering spot-check (HarfBuzz)

- **Clean results:** Every full-coverage font shaped Genesis 1:1, Genesis 1:5 and the hard cases without dotted circles or overlapping marks visible at 60 px. The hard cases were:
  - legarmeih (munach + paseq);
  - meteg + patah on one letter;
  - prepositive yetiv and dehi, and postpositive pashta, zarqa, telisha gedola and telisha qetana;
  - segolta, shalshelet and ole-veyored;
  - the upper dot U+05C4, nun hafukha and qamats qatan.
- **Ordering:** Yetiv typed before the vowel (as the Taamey README recommends) and yetiv in NFC order (after the vowel) both rendered acceptably in Noto Serif, Taamey and Ezra.
- **Look of each font:**
  - Noto Serif Hebrew has compact, modern marks and a tall straight paseq.
  - Taamey Frank and Keter YG look the most like a printed Chumash.
  - Ezra SIL and Cardo are large and heavy.
- **Fonts without ta'amim:** Frank Ruhl Libre and David Libre showed tofu boxes for every accent, as expected.

### 1.3 Verified download URLs (raw.githubusercontent.com, commit-pinned)

All of the URLs below returned HTTP 200 from this environment. SHA-256 prefixes are given for integrity pinning.

**OFL (simplest licensing; recommended for bundling in store apps):**
- Noto Serif Hebrew (variable; includes mkmk and Latin). SHA-256 `93caef921360788d…`
  `https://raw.githubusercontent.com/google/fonts/2eb0b48d5f760f62e286216f0859a8c540dbc1bd/ofl/notoserifhebrew/NotoSerifHebrew%5Bwdth,wght%5D.ttf`
  License: `…/ofl/notoserifhebrew/OFL.txt`. Upstream source: https://github.com/notofonts/hebrew
- Noto Sans Hebrew (variable). SHA-256 `7ef36a2c3593758c…`
  `https://raw.githubusercontent.com/google/fonts/2eb0b48d5f760f62e286216f0859a8c540dbc1bd/ofl/notosanshebrew/NotoSansHebrew%5Bwdth,wght%5D.ttf`
- Ezra SIL. SHA-256 `53c98ab95d2b5bd6…`. This is a mirror from the Open Siddur font pack (Aharon Varady); SIL's own site could not be reached.
  `https://raw.githubusercontent.com/aharonium/fonts/2b5e366ffaa89d42159092fcccd6d027b50a9ef9/Fonts/Hebrew%20Letters%20with%20Vowels%20and%20Cantillation/SIL%20(OFL)/Ezra%20SIL/SILEOT.ttf`
  SR variant: same folder, `SILEOTSR.ttf`. License: same folder, `Ezra%20SIL%20Hebrew%20Unicode%20Fonts%20license.htm`.
- Cardo Regular. SHA-256 `bcb81f376f1c3892…`
  `https://raw.githubusercontent.com/google/fonts/2eb0b48d5f760f62e286216f0859a8c540dbc1bd/ofl/cardo/Cardo-Regular.ttf`
- Frank Ruhl Libre (nikud only): `https://raw.githubusercontent.com/google/fonts/2eb0b48d5f760f62e286216f0859a8c540dbc1bd/ofl/frankruhllibre/FrankRuhlLibre%5Bwght%5D.ttf`
- David Libre (nikud only, no meteg): `https://raw.githubusercontent.com/google/fonts/2eb0b48d5f760f62e286216f0859a8c540dbc1bd/ofl/davidlibre/DavidLibre-Regular.ttf`

**GPL-2.0 with font exception (Culmus):**
- Taamey Frank CLM Medium. SHA-256 `f558d3564d385a6a…`. The two mirrors below are byte-identical.
  `https://raw.githubusercontent.com/aharonium/fonts/2b5e366ffaa89d42159092fcccd6d027b50a9ef9/Fonts/Hebrew%20Letters%20with%20Vowels%20and%20Cantillation/Culmus%20Project%20(GPL+FE)/Yoram%20Gnat%20(GPL+FE)/Taamey-Culmus/TaameyFrank/TaameyFrankCLM-Medium.ttf`
  `https://raw.githubusercontent.com/Sefaria/Sefaria-Project/00968f8a280ef7d4d5657f2484426084f8959c51/static/fonts/Taamey-Frank/TaameyFrankCLM-Medium.ttf`
  License: `…/TaameyFrank/LICENSE.txt` in the aharonium path.
- Taamey David CLM Medium. SHA-256 `2f668ae127a2bd17…`
  `https://raw.githubusercontent.com/aharonium/fonts/2b5e366ffaa89d42159092fcccd6d027b50a9ef9/Fonts/Hebrew%20Letters%20with%20Vowels%20and%20Cantillation/Culmus%20Project%20(GPL+FE)/Yoram%20Gnat%20(GPL+FE)/Taamey-Culmus/TaameyDavid/TaameyDavidCLM-Medium.ttf`
- Keter YG Medium. SHA-256 `8932f09803d78a0b…`
  `https://raw.githubusercontent.com/aharonium/fonts/2b5e366ffaa89d42159092fcccd6d027b50a9ef9/Fonts/Hebrew%20Letters%20with%20Vowels%20and%20Cantillation/Culmus%20Project%20(GPL+FE)/Yoram%20Gnat%20(GPL+FE)/Taamey-Culmus/KeterYG/KeterYG-Medium.ttf`
- Alternative source for Keter YG, Frank Ruehl CLM and Shofar (not GitHub): the Culmus 0.140 tarball, `https://sourceforge.net/projects/culmus/files/culmus/0.140/culmus-0.140.tar.gz/download`, released 2024-08-02. It does **not** contain the Taamey fonts.
- Note for curl: `+` in `(GPL+FE)` works as a literal; `%2B` also works.

**Why I don't give `woff2` URLs:** Wikimedia's UniversalLanguageSelector hosts `TaameyFrankCLM.woff2` (font.ini declares `GPL-2.0-or-later`), but Flutter does not support `.woff`/`.woff2` on desktop, so use the `.ttf` files above. Source for both claims: https://raw.githubusercontent.com/wikimedia/mediawiki-extensions-UniversalLanguageSelector/master/data/fontrepo/fonts/TaameyFrankCLM/font.ini and https://github.com/flutter/website/blob/main/sites/docs/src/content/cookbook/design/fonts.md

### 1.4 Licensing notes for a store-distributed app

- **OFL fonts** (Noto, Ezra SIL, Cardo, the Libre fonts) can be bundled in a commercial or store app. Ship `OFL.txt`, and don't rename a modified font to a Reserved Font Name.
- **Culmus fonts:**
  - **Embedded documents:** The font exception covers *documents* that embed the font.
  - **Bundling in an app:** Bundling the font file in an app binary is usually seen as "mere aggregation", so your app does not become GPL. You still have to ship the GPL text and offer the font source (the SFD sources are in each aharonium folder under `source/`).
  - **App Store terms:** The FSF considers Apple App Store terms incompatible with GPL distribution **[unverified; this is a well-known controversy, not legal advice]**.
  - **Lowest-risk option:** If you want minimum legal friction, make an OFL font (Noto Serif Hebrew or Ezra SIL) the default and offer Taamey Frank as an optional "classic" style.
- **Culmus status:** According to a search-result snippet of the Culmus taamim page (https://culmus.sourceforge.io/taamim/, blocked here), *Taamey Frank is no longer maintained and has been superseded by "Taamey D", which has improved positioning of cantillation marks* **[unverified]**. Taamey D was not found on GitHub.

### 1.5 Recommendation

1. **Default scripture font:** Noto Serif Hebrew, using the google/fonts variable file.
   - Either pass `fontVariations: [FontVariation('wght', 400)]`, or instantiate static weights at build time:
     `fonttools varLib.instancer "NotoSerifHebrew[wdth,wght].ttf" wght=400 wdth=100 -o NotoSerifHebrew-Regular.ttf`. I tested this; the output keeps all 31 ta'amim and `mkmk`, and is 56 KB.
2. **"Classic Chumash" option:** Taamey Frank CLM **Medium only**.
   - **Never register the Bold file, because it makes the ta'amim invisible.** For emphasis, use color or a different weight of the Noto font.
3. **Optional "Aleppo Codex" style:** Keter YG Medium. Same caveat: never use its Bold.
4. **Never use** Frank Ruhl Libre or David Libre for text with ta'amim. They are fine for modern Hebrew UI text and for headings with nikud only.

pubspec sketch:

```yaml
flutter:
  fonts:
    - family: ScriptureSerif            # Noto Serif Hebrew (OFL)
      fonts:
        - asset: assets/fonts/NotoSerifHebrew-Regular.ttf   # instanced from variable
        - asset: assets/fonts/NotoSerifHebrew-Bold.ttf
          weight: 700
    - family: TaameyFrank              # GPL+FE; register Medium ONLY
      fonts:
        - asset: assets/fonts/TaameyFrankCLM-Medium.ttf
```

---

## 2. Size, line height and clipping; paseq/legarmeih, maqaf, sof pasuq, the Divine Name

### 2.1 Measured ink extents

All values are in em: font size 100 px, positioned with HarfBuzz, worst case over four dense verse lines.

| Font | ascent+descent (font metrics) | highest mark above baseline | lowest mark below baseline | total ink span |
|---|---|---|---|---|
| Noto Serif Hebrew | 1.19 | 0.88 | 0.30 (exceeds descent 0.29) | **1.18** |
| Noto Sans Hebrew | 1.37 | 0.80 | 0.25 | 1.05 |
| Taamey Frank CLM | 1.24 | 0.83 (exceeds ascent 0.80) | 0.30 | 1.13 |
| Taamey David CLM | 1.24 | 0.82 | 0.29 | 1.11 |
| Keter YG | 1.45 | 0.83 | 0.30 | 1.13 |
| Ezra SIL | 1.49 | 1.07 | 0.39 | **1.46** |
| Cardo | 1.37 | 0.97 | 0.31 | 1.28 |
| Shofar | 1.01 | 0.98 (exceeds ascent 0.80) | 0.28 | 1.26 |

What this means:
- **The basic problem:** The upper marks on one line and the lower marks on the line above can reach about **1.1–1.5 em** apart, while a line of plain text needs only about 0.7 em of ink. At Flutter's default spacing (font metrics), Noto Serif Hebrew and Taamey Frank leave almost no gap, and Shofar overlaps.
- **Minimum line height:** `height: 1.6`. This is what Sefaria uses for its base text: `.textRange.basetext { font-size: 2.2em; line-height: 1.6 }` with Taamey Frank (Sefaria `static/css/s2.css`). At 1.6, even Ezra SIL keeps about 0.14 em between the marks of adjacent lines.
- **For study views with full ta'amim,** 1.8–2.0 is more comfortable. Taamey's own README says *"Since the font supports cantillation marks positioning, the line spacing is wider than in the standard fonts so as to leave space for all marks."*
- **Font size:** Make Hebrew scripture about 1.25–1.5× the Latin body size, for example 22–26 logical px when the body text is 16–17 px. The letters in Hebrew fonts are small relative to the em (Noto Serif Hebrew's letter-plus-mark ink tops out at 0.88 em), and the marks are tiny. The W3C Hebrew Layout Requirements draft notes that vocalized text *"may need to use a different font … It may also be desirable to show the vocalized text in larger size"* (https://raw.githubusercontent.com/w3c/hlreq/gh-pages/index.html).
- **Respect the OS text scale.** Flutter text follows the system font-size setting; test at the largest setting (Flutter accessibility docs, `sites/docs/src/content/ui/accessibility/ui-design-and-styling.md` in flutter/website).

### 2.2 Flutter specifics: avoiding clipped or colliding marks

- **`TextStyle.height`:** It is a multiple of the font size. With `height` set, each line is exactly `fontSize * height` tall (Flutter source, `text_style.dart`). Use `leadingDistribution: TextLeadingDistribution.even` so the extra leading is split evenly above and below. The default *proportional* mode adds more above than below, which leaves too little room for the lower marks (tipcha, merkha, the vowels) that sit 0.3–0.4 em under the baseline.
- **First and last lines:** When `TextHeightBehavior(applyHeightToFirstAscent: false)` or `applyHeightToLastDescent: false` is used, the first or last line falls back to the font's ascent or descent. Marks then poke out of the `Text` box: about 0.03 em on Taamey Frank and 0.18 em on Shofar. Add top padding of at least 0.2 em, and avoid `ClipRect`, `clipBehavior` or fixed-height containers around verse text.
- **`StrutStyle(forceStrutHeight: true, height: …, leading: …)`** keeps the baseline grid even when a line falls back to another font (for example, Latin verse numbers).
- **Don't use `maxLines` with ellipsis on ta'amim text.** Clamped previews tend to cut through marks; use stripped text for previews.
- **Web:** Bundle the fonts. CanvasKit and skwasm otherwise fall back to Noto fonts downloaded at runtime from Google's CDN.
- **Synthetic bold:** If you request `FontWeight.bold` from a family that has only a Medium file, Flutter may synthesize a fake bold. That keeps the marks visible, unlike the real Taamey and Keter Bold files.

### 2.3 Special characters

- **Paseq U+05C0 and legarmeih:** Paseq is a spacing punctuation character with line-break class **AL** (UCD LineBreak). In common encodings it is typed with spaces on both sides (`אֱלֹהִ֤ים ׀ לָאוֹר֙`). Legarmeih is not a separate character; it is munach (or mahpakh) followed by a paseq, and looks identical to a plain paseq.
  - **Problem:** A line can break *before* the paseq, leaving it stranded at the start of a line.
  - **Fix:** Replace the space before ׀ with U+00A0 NO-BREAK SPACE or U+202F NARROW NO-BREAK SPACE. I tested both; they render invisibly in all the fonts.
  - Fonts draw paseq as a tall thin bar (Noto Serif) or a short bar (Ezra, Cardo).
- **Maqaf U+05BE:** It is a high hyphen that binds words into one accent unit.
  - **Line-break class:** **BA** (break after) up to Unicode 16.0. Unicode 17.0 moved it to the new class **HH** (UCD `LineBreak.txt` 16.0.0 vs 17.0.0 in unicode-org/unicodetools). Either way, a line **may break after a maqaf**. The ICU bundled with Flutter may still use pre-17 data.
  - **Keeping bound words together:** Insert U+2060 WORD JOINER after the maqaf (`…י־\u2060עֶ…`). I tested it: HarfBuzz hides it in every font, including fonts without a glyph for it. The W3C hlreq draft says only that maqaf *"should behave like a hyphen."*
- **Sof pasuq U+05C3:** Class AL, attached directly to the last word with no space. Some sources use an ASCII `:` instead, so normalize on import. Keep it when stripping marks; it is punctuation (see §3).
- **Nun hafukha U+05C6** (Numbers 10:35–36) is class **EX**; every full-coverage font has it.
- **The Divine Name (יְהוָה):**
  - **Encoding:** Unicode has no special treatment. The Masoretic text carries the *qere perpetuum* vowels: יְהוָה, or יֱהֹוִה / יֱהוִה where it is read *Elohim*, and the vowels differ between editions (some show holam). The fonts just need shva, hataf segol, holam and hiriq placed correctly, which all the full-coverage fonts do.
  - **Optional display choices:** Some apps offer a toggle for English translations ("the LORD" / "Hashem" / "YHWH" / "G-d"). Some communities prefer that user-generated text write ה׳ rather than the full Name. Make substitution a **display or community option**; never change the stored scripture text.
  - **Printing:** If you allow printing or PDF export, consider a small notice that pages contain the Divine Name **[community-practice suggestion; not sourced]**.
- **Bold and color emphasis:** Prefer color. The bold Culmus fonts hide the ta'amim (§1.1), and the W3C hlreq notes that italics are controversial in Hebrew.

---

## 3. Stripping marks: Unicode ranges and pitfalls

### 3.1 Inventory

Checked against Python `unicodedata` 15.1 and the UCD in unicode-org/unicodetools.

| Range / code point | What it is | General category, combining class | Strip for "no ta'amim"? | Strip for "no nikud"? |
|---|---|---|---|---|
| U+0591–U+05AF | 31 accents (etnahta … masora circle) | Mn, ccc 220–230 | **yes** | yes |
| U+05BD | METEG. **The same code point is also silluq**, the verse-final accent | Mn, ccc 22 | **yes** (silluq is an accent, and meteg is part of the accent system) | yes |
| U+05C0 | PASEQ (also the second half of legarmeih) | Po, ccc 0 | **yes**, then collapse the double space it leaves | yes |
| U+05B0–U+05BC | sheva … dagesh/mapiq | Mn | no | **yes** |
| U+05BF | RAFE | Mn | no (Sefaria removes it with the cantillation) | yes |
| U+05C1–U+05C2 | shin dot, sin dot | Mn | no | yes |
| U+05C4–U+05C5 | upper and lower dots (*puncta extraordinaria*; text-critical) | Mn, ccc 230/220 | your choice (Sefaria removes them) | yes |
| U+05C7 | QAMATS QATAN | Mn, ccc 18 | no | **yes** |
| **U+05C8–U+05C9** | SHEVA NA MUDGASH, DAGESH HAZAQ MUDGASH: **new in the Unicode 18.0 data** (unicodetools `dev`, Aug 2026) | Mn, ccc 10/21 | no | **yes** (future-proof your regex) |
| U+05BE | MAQAF | **Pd**, not a mark | **no** | **no**. Replace with a space or `-` only if you want plain modern text. Deleting it glues two words together. |
| U+05C3 | SOF PASUQ | Po | **no** | no (or map it to `:`) |
| U+05C6 | NUN HAFUKHA | Po | no | your choice |
| U+05F3/U+05F4 | geresh, gershayim | Po | no | no |
| U+034F CGJ, U+200C ZWNJ, U+200D ZWJ | used in some editions to control mark order (for example, hiriq in ירושלם) | | strip **after** you strip the marks | strip |
| U+FB1D–U+FB4F | presentation forms (precomposed with dagesh, etc.) | Lo | decompose first | decompose first |

### 3.2 Recommended regexes

Dart needs `unicode: true` for `\u{…}` syntax; plain `\uXXXX` works without it.

```dart
// Run after Unicode normalization (see pitfalls). Order matters.
final _taamim = RegExp(r'[\u0591-\u05AF\u05BD\u05C0]');      // accents + meteg/silluq + paseq
final _nikud  = RegExp(r'[\u05B0-\u05BC\u05BF\u05C1\u05C2\u05C4\u05C5\u05C7-\u05C9]');
final _joiners = RegExp(r'[\u034F\u200C\u200D]');
final _spaces = RegExp(r' {2,}');

String stripTaamim(String s) =>
    s.replaceAll(_taamim, '').replaceAll(_joiners, '').replaceAll(_spaces, ' ').trim();
String stripNikudAndTaamim(String s) =>
    stripTaamim(s).replaceAll(_nikud, '');
```

Postgres (for search columns) supports `\uXXXX` in regular expressions:

```sql
create or replace function public.he_plain(t text) returns text
language sql immutable parallel safe set search_path = '' as $$
  select translate(
           regexp_replace(normalize(t, NFD), '[\u0591-\u05C7\u05C8\u05C9\u034F\u200C\u200D]', '', 'g'),
           'ךםןףץ', 'כמנפצ')       -- optional: fold final letters for matching only
$$;
```

Note that this search version also removes maqaf, sof pasuq and paseq, which is what you want for a *match key* but not for *display*.

Precedent: Sefaria's `strip_cantillation()` uses `[\u0591-\u05AF\u05BD\u05BF\u05C0\u05C4\u05C5]` for ta'amim only, and `[\u0591-\u05BD\u05BF-\u05C5\u05C7]` for ta'amim plus vowels (https://raw.githubusercontent.com/Sefaria/Sefaria-Project/master/sefaria/utils/hebrew.py). Two cautions about that code:
- Its `strip_nikkud()` uses `[\u0591-\u05C7]`, which **also deletes maqaf, paseq, sof pasuq and nun hafukha**.
- Its vowel+ta'amim regex removes sof pasuq (U+05C3).

### 3.3 Pitfalls

1. **Meteg/silluq ambiguity:** The two cannot be told apart without context, so a "nikud only" view should remove U+05BD.
2. **Maqaf and paseq are not marks:** A blanket `[\u0591-\u05C7]` removes them. That joins words (ויהי־ערב becomes ויהיערב) or leaves double spaces.
3. **Normalization reorders marks:** Hebrew points have *different* canonical combining classes (sheva 10, hiriq 14, patah 17, qamats 18, holam 19, dagesh 21, meteg 22, shin dot 24, accents 220–230). So NFC/NFD sorts marks into a fixed order. Some editions use CGJ to keep a non-canonical order, for example a meteg before a vowel, or patah plus hiriq in ירושלם.
   - **Don't** normalize the *display* text if it relies on CGJ.
   - **Do** normalize both sides when comparing or searching. Dart has no built-in normalizer; `unorm_dart` 0.3.3 on pub.dev advertises Unicode 18.0 NFC/NFD/NFKC/NFKD. Postgres 13+ has `normalize()`.
4. **Presentation forms U+FB1D–FB4F:** These carry canonical decompositions and are composition exclusions, so NFD (or NFC) turns them into base letter plus marks. U+FB4F (alef-lamed) decomposes only under NFKD. Decompose before stripping, or the marks inside them survive.
5. **Prepositive and postpositive accents:** Yetiv and dehi (ccc 222) display before or below the start of a word, while pashta, telisha gedola and zarqa display at its end. They are still stored on the first or last letter, so stripping by code point is safe.
6. **Mixed text:** User posts may contain Hebrew with nikud alongside English. Apply stripping only to Hebrew runs if you also strip combining marks generically: U+0300–U+036F would hit Latin transliteration such as ḥ written with a combining dot below.
7. **Search on stripped text, highlight on original:** Keep a code-point index map, or match word by word.

---

## 4. Latin UI fonts with accessibility merit

All four were downloaded from GitHub and their license fields read from the files.

| Font | License | Verified download (commit-pinned) | Notes |
|---|---|---|---|
| **Atkinson Hyperlegible** (Braille Institute) | OFL 1.1 | `https://raw.githubusercontent.com/google/fonts/2eb0b48d5f760f62e286216f0859a8c540dbc1bd/ofl/atkinsonhyperlegible/AtkinsonHyperlegible-Regular.ttf` (also `-Bold`, `-Italic`, `-BoldItalic`). Source: https://github.com/googlefonts/atkinson-hyperlegible | Designed so that easily confused glyphs (I/l/1, 0/O) look distinct. **Missing the transliteration characters ḥ ṭ ṣ ʾ ʿ ō ĕ ŏ ə ḇ ḡ ḏ ḵ ṯ** (tested). |
| **Atkinson Hyperlegible Next** (2025) | OFL 1.1 | `https://raw.githubusercontent.com/google/fonts/2eb0b48d5f760f62e286216f0859a8c540dbc1bd/ofl/atkinsonhyperlegiblenext/AtkinsonHyperlegibleNext%5Bwght%5D.ttf` (variable, wght 200–800, default 400). Source: https://github.com/googlefonts/atkinson-hyperlegible-next | Same transliteration gaps as the original. |
| **Lexend** | OFL 1.1 | `https://raw.githubusercontent.com/google/fonts/2eb0b48d5f760f62e286216f0859a8c540dbc1bd/ofl/lexend/Lexend%5Bwght%5D.ttf` (variable, 100–900, default 400). Source: https://github.com/googlefonts/lexend | Wide letter spacing intended to reduce visual crowding. **Best transliteration coverage** of the four: lacks only precomposed ḇ and ḵ, and has combining U+0331 as a fallback. |
| **OpenDyslexic** | OFL 1.1 (RFN "OpenDyslexic") | `https://raw.githubusercontent.com/antijingoist/opendyslexic/1824da5c0e41dc3e13ffc7f3a636dcaf695d61b7/compiled/OpenDyslexic-Regular.otf` (also Bold, Italic, Bold-Italic) | **The GitHub repo is frozen.** Its README says the sources moved to https://forge.hackers.town/antijingoist/opendyslexic. Offer it as a user option, not the default: published studies have generally not found reading gains **[unverified here]**. |

Notes:
- None of these fonts contain Hebrew. For Hebrew UI strings, pair the Latin font with Noto Sans Hebrew at wght 400 (set the variation or instance the file) through `fontFamilyFallback`.
- If you show academic transliteration, choose Lexend, or put Noto Serif or Cardo in the fallback chain. Cardo lacks only ḇ, ḡ and ḵ precomposed.

---

## 5. Interlinear and parallel layout (Hebrew/Aramaic, Hebrew/English)

**Sefaria** (verified in its source code):
- **Bilingual layouts:** `biLayout` is `"stacked"` by default (Hebrew above English per segment), with `"heLeft"` and `"heRight"` for side-by-side.
- **Mark display:** A three-state `vowels` setting: `"all"` (nikud + ta'amim), `"partial"` (nikud only) and `"none"`. The menu enables the ta'amim toggle only when vowels are shown, and offers each toggle only if the text contains those marks (it checks `/[\u0591-\u05AF]/` for ta'amim and `/[\u05B0-\u05C3\u05C7]/` for vowels).
- **Continuity and aliyot:** `layoutTanakh: "segmented"` (verse by verse) vs `"continuous"`, plus an `aliyotTorah` on/off toggle.
- **Files:** `static/js/ReaderApp.jsx`, `ReaderDisplayOptionsMenu.jsx` and `LayoutButtons.jsx` in https://github.com/Sefaria/Sefaria-Project. When the two texts have different directions (Hebrew/English), Sefaria computes a "mixed" layout state and picks icons for which side the primary text goes on.

**Print traditions** (from prior knowledge, **[unverified]**):
- *Koren* Hebrew-English editions put Hebrew and English on facing pages, aligned by verse.
- *ArtScroll Stone Chumash*: Hebrew and English in parallel columns, with Targum Onkelos and Rashi below the Hebrew and commentary at the foot of the page.
- *ArtScroll Schottenstein Interlinear* (also in the ArtScroll digital library): a true interlinear, with an English gloss under each Hebrew word, read right to left.
- *Mikraot Gedolot* sets Onkelos beside or below the verse.
- The study practice of *shnayim mikra ve'echad targum* (reading each verse twice and the Targum once) favors interleaving verse by verse: Hebrew verse, Hebrew verse, Aramaic verse.

**Practical guidance for Flutter:**
1. **Lay out by verse, not by column.** Make each verse a unit (a row or card) holding the Hebrew text plus either the translation or the Targum. Continuous parallel columns drift out of alignment because Hebrew with ta'amim and English have different line counts.
2. **Responsive layout:** On wide screens (about 840 dp and up), show side-by-side `Row`s with two `Expanded` children, each in its own `Directionality`. Hebrew goes on the right in RTL UI; let the user swap sides, as Sefaria's `heLeft`/`heRight` does. On narrow screens, stack the texts (Sefaria's default).
3. **Aramaic Targum:** Use the same Hebrew-script font. Targum texts usually carry nikud but few or no ta'amim. Style it smaller or in a different color, and interleave it as an option ("Hebrew ×2 + Targum" mode).
4. **Interlinear mode:** Use a `Wrap` inside `Directionality(textDirection: TextDirection.rtl)` whose children are `Column(hebrewWord, gloss)` word units. Put spacing between units, and keep each maqaf-joined group as one unit. Provide per-word semantics ("word, gloss").
5. **Mixed-direction strings:** Put English inside Hebrew in its own `TextSpan`/widget, or wrap it in U+2068 FIRST STRONG ISOLATE … U+2069 POP DIRECTIONAL ISOLATE so punctuation and verse numbers stay put.
6. **Settings to offer:**
   - mark display (all / nikud only / none), following Sefaria's three states;
   - verse-by-verse vs continuous;
   - aliyah markers;
   - Hebrew font choice (Noto Serif Hebrew / Taamey Frank / Keter YG);
   - separate size controls for Hebrew and English.
7. **Screen readers:** Cantillation marks can confuse TTS. Consider giving each verse a `Semantics(label:)` that uses the ta'amim-stripped or fully stripped text (§3) **[suggestion; test with VoiceOver and TalkBack Hebrew voices]**.

---

## Sources

- Font files and metadata (fetched and analyzed):
  - google/fonts @ `2eb0b48d…`: `ofl/notoserifhebrew/METADATA.pb` and the fonts listed above;
  - aharonium/fonts @ `2b5e366f…`: README (Open Siddur font pack v2026.04.16, which lists the 20 full-diacritics fonts) and LICENSES.txt;
  - Sefaria-Project @ `00968f8a…`;
  - notofonts.github.io @ `47acfd38…`;
  - antijingoist/opendyslexic @ `1824da5c…`.
- Taamey Frank README, LICENSE and ChangeLog, and Taamey David ChangeLog (bold variants hide ta'amim): `…/Taamey-Culmus/TaameyFrank/README.txt` and `ChangeLog.txt` in aharonium/fonts.
- Culmus 0.140 tarball LICENSE (GPL-2 + font exception for Keter YG and Shofar): https://sourceforge.net/projects/culmus/files/culmus/0.140/
- Culmus taamim page (search snippet only, page blocked): https://culmus.sourceforge.io/taamim/
- Wikimedia ULS font.ini: https://raw.githubusercontent.com/wikimedia/mediawiki-extensions-UniversalLanguageSelector/master/data/fontrepo/fonts/TaameyFrankCLM/font.ini
- Flutter font formats: https://github.com/flutter/website/blob/main/sites/docs/src/content/cookbook/design/fonts.md
- Flutter `TextStyle.height` and `leadingDistribution`: https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/painting/text_style.dart
- W3C Hebrew Layout Requirements (draft): https://raw.githubusercontent.com/w3c/hlreq/gh-pages/index.html
- Unicode LineBreak.txt 15.1, 16.0, 17.0 and dev (18.0), and UnicodeData.txt: https://github.com/unicode-org/unicodetools/tree/main/unicodetools/data/ucd
- Sefaria Hebrew utilities: https://raw.githubusercontent.com/Sefaria/Sefaria-Project/master/sefaria/utils/hebrew.py
- Sefaria CSS: https://raw.githubusercontent.com/Sefaria/Sefaria-Project/master/static/css/s2.css and `fonts.css`.
- unorm_dart (pub.dev API): https://pub.dev/packages/unorm_dart
