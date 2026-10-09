# Shnayim Mikra: "Klaf & Techelet" design system v1 (final, for implementation)

> Reference mockups: [mock_today.png](design/mock_today.png), [mock_reader.png](design/mock_reader.png). Render the current app with `CAPTURE=1 flutter test test/screens/capture_test.dart` (PNGs in build/screens/) to compare.


Owner goal: an app that feels like a well-made chumash brought onto a screen with care. It should be calm, dignified and legible for a 75-year-old, and still feel current to a 25-year-old learner. This document is the contract. Where it conflicts with an earlier proposal, this document wins.

## 0. Decisions

**Base direction:** Klaf & Techelet. The look:
- warm parchment surfaces and warm ink;
- techelet blue as the one colour for interaction and for the current parsha's Hebrew title;
- gold as the rubric colour (verse numbers, eyebrows, chapter heads, Targum, Shabbat);
- a classical serif for display text (EB Garamond for Latin, Frank Ruhl Libre for Hebrew), with Noto Sans and Noto Sans Hebrew for body text;
- hairlines, no shadows;
- five ornaments in total.

**Taken from Techelet Calm:**
- a real `dimInk` token for focus mode;
- a labeled three-segment pass track in the reader;
- the bundled UI font on every platform, plus a `system` option;
- FSI/PDI isolates for Latin runs inside Hebrew text;
- snackbar timing;
- no slider tick marks;
- `Motion.of(context)`;
- the welcome segmented control shows the effective locale;
- RepaintBoundary and performance rules.

**Taken from Oneg:**
- the hero CTA names the exact next unit, including the pass;
- mini pass pips on each aliyah tab;
- a hanging verse number in guided mode;
- a sentence instead of a bold "0";
- bidi-safe thread titles and post headers;
- the Torah-map tile contrast fix;
- a pure-Dart palette contrast test that checks AAA in high contrast.

**Rejected:**
- Inter, and borderless shadow cards (boundaries at 1.08:1);
- monochrome rings, the floating dock, custom nav glyphs;
- a terracotta primary, Rubik and Fraunces;
- the illustration set and time-of-day greetings.

**Corrections to the Klaf proposal itself:**
1. The ring sweep stays clockwise in both directions. A ring is not text, and the same data must look the same in both languages.
2. The EB Garamond size floor is raised: eyebrow small caps at 18sp, running text at 19sp or more, long-form at 20sp.
3. Weights are 500/600/700 plus italic 500. There is no 400; it is too thin on screens.
4. Chapter heads and Rashi's dibbur hamatchil use gold or ink, never techelet.
5. Next uses a direction chevron. A check appears only on Finish.
6. The hero CTA goes to `WeekContext.nextAliyah` (Shlishi in the scenario), not Revi'i.
7. The icon uses a font size of 300 px. The letters are then 177 px tall and 744 px wide.
8. The English UI keeps the transliterated Hebrew date ("28 Tishrei 5787"). Only the Hebrew UI uses Hebrew numerals.

## 1. Defects this spec fixes (evidence)

| # | Defect | Evidence |
|---|---|---|
| D1 | The app icon text is reversed. ש is the leftmost glyph, so it reads "ת״ומש". | assets/branding/icon.png (also icon_foreground.png and icon_monochrome.png); crop at scratchpad/icon_left.png |
| D2 | Seeded palette: lavender cards on cream, a mauve Targum ring and a pink demo banner. | app_theme.dart:92-146; progress_widgets.dart:55; community_ui.dart:145; reader_screen.dart:747; phone_today.png, phone_community.png |
| D3 | The focus ring is invisible on FilledButton (primary ring on primary fill). | app_theme.dart:171, 217-222 |
| D4 | Buttons request w600, but only 400/500/700 are bundled, so labels render Bold. | app_theme.dart:221; pubspec.yaml:82-95 |
| D5 | The reader's ChoiceChip shows a check on the selected, unread Revi'i. Shlishi (2 of 3 passes) shows nothing. | reader_screen.dart:536-541; phone_reader.png |
| D6 | Mikra 2 ring = primary at 80% alpha, which can't be told apart from Mikra 1. | progress_widgets.dart:55 |
| D7 | Focus-mode dimmed verses use 55% alpha: 3.82:1, which fails AA. | scripture_text.dart:114, 118, 129, 223 |
| D8 | Torah map: "late" tiles are white text on 70%-alpha primary. "Missed" and "upcoming" differ only by border colour. | progress_screen.dart:274-281 |
| D9 | Trophy and lock milestones, and party-popper icons. | progress_screen.dart:366; today_screen.dart:181; reader_screen.dart:850; notification_prompt.dart:20 |
| D10 | Today has competing CTAs, an outlined "2 of 7 aliyot" that looks like a button, and "0 weeks" in bold. | today_screen.dart:187-196, 251-255, 321; phone_today.png |
| D11 | Desktop: the title sits at x=273 while content starts at x=448. Reader Back and Next are 1,240 px apart and the chips sit flush left. The rail shows "SM". | desktop_today.png; desktop_reader.png; shell.dart:58-66 |
| D12 | The reader stacks three layers of chrome above the verse. | phone_reader.png |
| D13 | Hebrew UI: an English thread title is cut at the wrong end, and the post header mixes directions in one string. | thread_screen.dart:102; he_thread.png |
| D14 | On native platforms the UI uses the platform font, so the brand changes per OS. | app_theme.dart:158 |
| D15 | Settings has both "About Shnayim Mikra" (the guide) and "About". | settings_screen.dart:51-52 |
| D16 | The week-strip "upcoming" circle is in outlineVariant, about 1.5:1. | progress_widgets.dart:201-202 |
| D17 | The Display screen has dotted slider ticks and an X on every off switch. | phonetall_s_display.png |

## 2. Code structure

New and changed files:

- `lib/ui/theme/palette.dart`: five `const ColorScheme`s, five `const SeferColors` and five `const StatusColors` (values in §3).
- `lib/ui/theme/sefer_colors.dart`: `SeferColors extends ThemeExtension<SeferColors>`, with copyWith and lerp. Add `static SeferColors of(BuildContext)`.
- `lib/ui/theme/typography.dart`:
  - `abstract final class AppTypography { static TextTheme textTheme({required ColorScheme scheme, required UiFont uiFont, required bool hebrewUi, required bool highContrast}); static SeferType sefer({...same}) }`
  - `SeferType extends ThemeExtension<SeferType>`.
- `lib/ui/theme/motion.dart`: `Motion` tokens and `Motion.of(context)`.
- `lib/ui/theme/focus.dart`: `FocusRingBorder` and `SeferInkWell`.
- `lib/ui/theme/app_theme.dart`:
  - signature becomes `AppTheme.build({required AppThemeMode mode /* resolved; never system */, required UiFont uiFont, required bool hebrewUi, required bool reduceMotion})`;
  - `AppTheme.scheme()` returns the `Palettes.*` constants;
  - `StatusColors` gains `overdue`.
- `lib/app/app.dart`: compute `hebrewUi` from the same locale resolution MaterialApp uses (`settings.language`, or for `system` `basicLocaleListResolution(PlatformDispatcher.instance.locales, AppLocalizations.supportedLocales).languageCode == 'he'`) and pass it to every `themeFor`.
- `lib/ui/widgets/ornaments.dart`: `Lozenge`, `SeferDivider`, `SectionBreakMark`, `TitlePageFrame`, `PassPips`, `Eyebrow`.
- `lib/ui/widgets/paper_group.dart`: `PaperGroup`, `PaperRow`, `GroupHeader`.
- `lib/ui/widgets/ledger.dart`: `LedgerCard`.
- `lib/ui/widgets/year_bar.dart`: `YearBar`.
- `lib/ui/widgets/progress_widgets.dart`: ParshaRings, the new `RingLegend`, WeekStrip and the candles, per §6.
- `lib/ui/widgets/common.dart`:
  - `PageBody` defaults become maxWidth 720 and padding `fromLTRB(g, 8, g, 40)`, where g is the gutter from §5;
  - `SectionHeader` is restyled as an eyebrow (§6.4);
  - `NoticeBanner` per §6.20.
- `lib/features/reader/aliyah_ribbon.dart`, `pass_track.dart` and `reader_bottom_bar.dart`: extracted from reader_screen.dart.
- `tool/fonts/build_fonts.sh` (§4.1) and `tool/branding/make_icon.py` (§7.8).
- `test/ui/palette_contrast_test.dart` (§11).

## 3. Colour

### 3.1 Rules

1. **Techelet (`primary`)** is used for:
   - buttons, links, the selected tab and indicators;
   - Mikra progress and the focus ring;
   - the Hebrew display title of a parsha (the Today hero, the Parsha header and Welcome/About).
   It is used for no other text: no section headers, chapter heads or verse numbers.
2. **Gold ink (`secondary`)** is the rubric colour: eyebrows, verse numbers, chapter heads, petuchah/setumah marks, the Targum pass, overdue state and rest days. Gold is never used for buttons.
3. **goldLeaf** is decorative only: frame rules, lozenges, the Targum rule in full-text mode. It never carries information. In high contrast it becomes solid `secondary`, or is removed where noted.
4. **Hyssop green (`tertiary`)** is only for grace.
5. **Missed** is always `neutral` plus a dash glyph. Never red. `error` is only for form validation and destructive confirmations.
6. **No Material tint anywhere:**
   - `surfaceTint: Colors.transparent`;
   - every component theme sets `surfaceTintColor: Colors.transparent`;
   - elevation is 0 everywhere except FAB 2 and menus 2.
7. **High contrast (both themes):**
   - every hairline becomes `outline` at 2 px;
   - the goldLeaf frame rule and the Targum rule are removed;
   - ornaments are drawn in `onSurface`;
   - `dimInk` equals `onSurfaceVariant` (no dimming);
   - the focus ring is `onSurface`.
8. Never alpha-fade a fill that carries text. Every pair below is listed and tested.

### 3.2 ColorScheme roles (build with the `const ColorScheme(...)` constructor, every role set)

| Role | Light "Klaf" | Dark "Lamplight" | Sepia "Vellum" | HC Light | HC Dark |
|---|---|---|---|---|---|
| surface | #FAF7F0 | #14120F | #F3E9D2 | #FFFFFF | #000000 |
| surfaceDim | #E6DFD1 | #14120F | #E1D4B6 | #E0E0E0 | #000000 |
| surfaceBright | #FFFDF8 | #3A352E | #FAF3E3 | #FFFFFF | #262626 |
| surfaceContainerLowest | #FFFDF8 | #0F0D0B | #FAF3E3 | #FFFFFF | #000000 |
| surfaceContainerLow | #F4EFE4 | #1C1915 | #EDE2C8 | #FFFFFF | #000000 |
| surfaceContainer | #EEE8DB | #221F1A | #E7DBBF | #F2F2F2 | #0F0F0F |
| surfaceContainerHigh | #E8E1D2 | #2B2721 | #E1D4B6 | #EBEBEB | #1A1A1A |
| surfaceContainerHighest | #E0D8C7 | #36312A | #D8CAA9 | #E0E0E0 | #262626 |
| onSurface | #1E1A16 | #EDE6D6 | #2B2115 | #000000 | #FFFFFF |
| onSurfaceVariant | #575046 | #C4BAA8 | #54452F | #1F1F1F | #EBEBEB |
| outline | #857B6D | #928878 | #83704F | #000000 | #FFFFFF |
| outlineVariant | #D8CFBF | #4A443A | #CBB994 | #4D4D4D | #B3B3B3 |
| primary | #1D3F75 | #AFC6EE | #25406C | #0A2A5E | #B5CEFF |
| onPrimary | #FFFFFF | #0E2547 | #FFFFFF | #FFFFFF | #000000 |
| primaryContainer | #DDE5F2 | #27416B | #D7DBE1 | #DCE6FA | #1B2A45 |
| onPrimaryContainer | #0E2547 | #DDE7F8 | #142A4D | #000000 | #FFFFFF |
| secondary (gold ink) | #7A5712 | #DDB96B | #6C4B0E | #4F3500 | #FFD970 |
| onSecondary | #FFFFFF | #2E2205 | #FFFFFF | #FFFFFF | #000000 |
| secondaryContainer | #F2E7CD | #4A3A16 | #EADBB4 | #FFF0C2 | #3D2E00 |
| onSecondaryContainer | #3B2A06 | #F4E5BC | #3A2905 | #000000 | #FFFFFF |
| tertiary (hyssop) | #2E6A56 | #8FD0B6 | #2B6350 | #00463A | #7FE3C2 |
| onTertiary | #FFFFFF | #003829 | #FFFFFF | #FFFFFF | #000000 |
| tertiaryContainer | #D5EADF | #1F4A3C | #D3E3D3 | #D6F5EA | #003D2E |
| onTertiaryContainer | #0B3B2C | #C9EEDD | #0E3528 | #000000 | #FFFFFF |
| error | #9A2B2B | #F2B8B5 | #8E2A22 | #8C0000 | #FFB4AB |
| onError | #FFFFFF | #601410 | #FFFFFF | #FFFFFF | #000000 |
| errorContainer | #F6DEDA | #5C1A17 | #F1D5C9 | #FFE0DC | #4A0000 |
| onErrorContainer | #5C1414 | #FFDAD5 | #4F120C | #000000 | #FFFFFF |
| inverseSurface | #2E2924 | #EDE6D6 | #3A2F20 | #000000 | #FFFFFF |
| onInverseSurface | #F4EFE4 | #1E1A16 | #F3E9D2 | #FFFFFF | #000000 |
| inversePrimary | #AFC6EE | #1D3F75 | #B4C6E6 | #B5CEFF | #0A2A5E |
| shadow | #1E1A16 | #000000 | #2B2115 | #000000 | #000000 |
| scrim | #000000 | #000000 | #000000 | #000000 | #000000 |
| surfaceTint | transparent | transparent | transparent | transparent | transparent |

Fixed roles:
- `primaryFixed = primaryFixedDim = primaryContainer` and `onPrimaryFixed = onPrimaryFixedVariant = onPrimaryContainer`.
- The same pattern applies to secondary and tertiary.

They must be set explicitly so no stock widget (DatePicker, SearchBar, Badge) falls back to a seeded colour.

### 3.3 SeferColors extension

| Token | Light | Dark | Sepia | HC Light | HC Dark |
|---|---|---|---|---|---|
| paper (cards, sheets, dialogs) | #FFFDF8 | #1C1915 | #FAF3E3 | #FFFFFF | #000000 |
| hairline | #D8CFBF | #4A443A | #CBB994 | #000000 (2 px) | #FFFFFF (2 px) |
| goldLeaf (decorative) | #B38D3F | #B8954B | #A9853A | #4F3500 | #FFD970 |
| ringMikra1 | #1D3F75 | #AFC6EE | #25406C | #0A2A5E | #B5CEFF |
| ringMikra2 | #55779F | #7E9BC8 | #4F6B92 | #2F4F82 | #8FB0F0 |
| ringTargum | #946C1E | #C9A458 | #8A651C | #4F3500 | #FFD970 |
| ringTrack | #E8E1D3 | #36312A | #E0D3B4 | #E0E0E0 | #333333 |
| restWash | #F2E7CD | #4A3A16 | #EADBB4 | #FFF0C2 | #3D2E00 |
| focus | #1D3F75 | #AFC6EE | #25406C | #000000 | #FFFFFF |
| focusGap | = surface | = surface | = surface | #FFFFFF | #000000 |
| dimInk (focus-mode dimmed verses) | #716859 | #9C9384 | #6E5F49 | #1F1F1F | #EBEBEB |
| verseHighlight (focus-mode current verse fill) | = paper | = paper | = paper | transparent | transparent |

### 3.4 StatusColors

| Token | Light | Dark | Sepia | HC Light | HC Dark |
|---|---|---|---|---|---|
| done | #1D3F75 | #AFC6EE | #25406C | #0A2A5E | #B5CEFF |
| onDone | #FFFFFF | #0E2547 | #FFFFFF | #FFFFFF | #000000 |
| late (finished late, restored) | #4A6A9B | #8199C6 | #46628C | #2F4F82 | #8FB0F0 |
| onLate | #FFFFFF | #0E2547 | #FFFFFF | #FFFFFF | #000000 |
| overdue (open after Shabbat), NEW | #7A5712 | #DDB96B | #6C4B0E | #4F3500 | #FFD970 |
| grace | #2E6A56 | #8FD0B6 | #2B6350 | #00463A | #7FE3C2 |
| neutral (missed glyph only) | #7D7466 | #958C7D | #7C6C55 | #4D4D4D | #BDBDBD |
| rest (candles) | #7A5712 | #DDB96B | #6C4B0E | #4F3500 | #FFD970 |

### 3.5 Verified contrast (WCAG 2.x relative luminance, computed)

Targets:
- text needs at least 4.5:1, or at least 7:1 in both high-contrast themes;
- UI and graphics need at least 3:1, or at least 4.5:1 in high contrast;
- scripture needs at least 7:1 in every theme.

| Pair | Light | Dark | Sepia | HC L | HC D |
|---|---|---|---|---|---|
| onSurface / surface (scripture, body) | 16.16 | 15.04 | 13.07 | 21.00 | 21.00 |
| onSurface / paper | 17.01 | 14.08 | 14.27 | 21.00 | 21.00 |
| onSurfaceVariant / surface (Targum, meta) | 7.43 | 9.74 | 7.67 | 16.48 | 17.62 |
| onSurfaceVariant / paper | 7.82 | 9.12 | 8.37 | 16.48 | 17.62 |
| onSurfaceVariant / surfaceContainer (nav labels) | 6.51 | 8.55 | 6.73 | 14.72 | 16.08 |
| dimInk / surface (focus mode) | 5.13 | 6.16 | 5.12 | 16.48 | 17.62 |
| primary / surface | 9.72 | 10.80 | 8.58 | 13.95 | 13.24 |
| primary / paper | 10.23 | 10.12 | 9.36 | 13.95 | 13.24 |
| onPrimary / primary | 10.40 | 8.83 | 10.35 | 13.95 | 13.24 |
| onPrimaryContainer / primaryContainer | 12.05 | 8.21 | 10.29 | 16.74 | 14.35 |
| onSurface / primaryContainer (week-strip today) | 13.64 | 8.22 | 11.35 | 16.74 | 14.35 |
| secondary (gold ink) / surface | 6.13 | 10.00 | 6.56 | 11.40 | 15.41 |
| secondary / paper | 6.46 | 9.36 | 7.17 | 11.40 | 15.41 |
| secondary / restWash (candles) | 5.34 | 5.88 | 5.77 | 10.04 | 9.70 |
| onSecondaryContainer / secondaryContainer (notices) | 11.24 | 8.79 | 10.20 | 18.50 | 13.21 |
| tertiary (grace) / paper | 6.24 | 9.89 | 6.32 | 10.84 | 13.67 |
| onLate / late (map tile) | 5.49 | 5.32 | 6.20 | 8.20 | 9.64 |
| late / paper | 5.40 | 6.09 | 5.61 | 8.20 | 9.64 |
| error / surface | 7.13 | 10.95 | 6.95 | 9.93 | 12.37 |
| onInverseSurface / inverseSurface (snackbar) | 12.55 | 13.91 | 10.82 | 21.00 | 21.00 |
| inversePrimary / inverseSurface (snackbar action) | 8.32 | 8.36 | 7.57 | 13.24 | 13.95 |
| outline / surface (UI boundaries) | 3.89 | 5.36 | 3.96 | 21.00 | 21.00 |
| outline / paper | 4.09 | 5.02 | 4.32 | 21.00 | 21.00 |
| outline / surfaceContainer | 3.41 | 4.70 | 3.48 | 18.76 | 19.17 |
| neutral / paper (missed glyph) | 4.53 | 5.27 | 4.60 | 8.45 | 11.18 |
| focus / surface (ring) | 9.72 | 10.80 | 8.58 | 21.00 | 21.00 |
| ringMikra1 / paper | 10.23 | 10.12 | 9.36 | 13.95 | 13.24 |
| ringMikra2 / paper | 4.56 | 6.18 | 4.93 | 8.20 | 9.64 |
| ringTargum / paper | 4.67 | 7.45 | 4.80 | 11.40 | 15.41 |
| ringMikra2 / ringTrack | 3.57 | 4.55 | 3.67 | 6.21 | 5.80 |
| ringTargum / ringTrack | 3.65 | 5.48 | 3.57 | 8.64 | 9.27 |
| goldLeaf / surface (decorative only, exempt) | 2.89 | 6.62 | 2.85 | 11.40 | 15.41 |
| hairline / paper (decorative only, exempt; HC uses 2 px outline) | 1.52 | 1.82 | 1.74 | 21.00 | 21.00 |

Notes:
- The current app's 55% alpha dimming measures 3.82:1 in light; `dimInk` replaces it.
- Dimmed verses (5.1:1 or more) are below the 7:1 scripture target on purpose. They are not the verse being read, and focus mode is opt-in.

### 3.6 Platform colours

- `web/manifest.json`: theme_color #1D3F75, background_color #FAF7F0.
- `web/index.html`: `<meta name="theme-color" content="#1D3F75">`, and body background #FAF7F0.
- `pubspec.yaml` flutter_launcher_icons:
  - `adaptive_icon_background: "#1D3F75"`;
  - web `background_color: "#FAF7F0"`, `theme_color: "#1D3F75"`;
  - `remove_alpha_ios: true`.

## 4. Typography

### 4.1 Fonts (all SIL OFL 1.1; google/fonts at commit 2eb0b48d5f760f62e286216f0859a8c540dbc1bd, the commit already cited in docs/research/typography.md)

Sources, verified by SHA-256 prefix against the downloaded files:
- `ofl/ebgaramond/EBGaramond[wght].ttf` (ef9512f92f6d579e…)
- `ofl/ebgaramond/EBGaramond-Italic[wght].ttf` (bba2c4499c93c961…)
- `ofl/ebgaramond/OFL.txt`
- `ofl/frankruhllibre/FrankRuhlLibre[wght].ttf` (f9bf26966681037a…)
- `ofl/frankruhllibre/OFL.txt`
- `ofl/notorashihebrew/NotoRashiHebrew[wght].ttf` (4da0058f46aa66f9…)
- `ofl/notorashihebrew/OFL.txt`

`tool/fonts/build_fonts.sh` uses fontTools 4.66 (measured sizes in brackets):

```
LATIN='U+0020-007E,U+00A0-017F,U+02BB-02BF,U+0300-0331,U+1E00-1EFF,U+2000-206F,U+20AA,U+2190-2193,U+2212'
for W in 500:Medium 600:SemiBold 700:Bold; do
  fonttools varLib.instancer 'EBGaramond[wght].ttf' wght=${W%%:*} --update-name-table -o /tmp/e.ttf
  pyftsubset /tmp/e.ttf --unicodes="$LATIN" --layout-features='kern,liga,clig,calt,ccmp,locl,mark,mkmk,lnum,onum,pnum,tnum,smcp,c2sc,case' --output-file=assets/fonts/EBGaramond-${W##*:}.ttf   # ~114 KB each
done
fonttools varLib.instancer 'EBGaramond-Italic[wght].ttf' wght=500 --update-name-table -o /tmp/i.ttf
pyftsubset /tmp/i.ttf --unicodes="$LATIN" --layout-features='kern,liga,clig,calt,ccmp,locl,mark,mkmk,lnum,pnum,tnum' --output-file=assets/fonts/EBGaramond-MediumItalic.ttf   # ~75 KB
HEB='U+0020-007E,U+00A0-00FF,U+0591-05F4,U+FB1D-FB4F,U+2000-206F,U+20AA'
for W in 500:Medium 600:SemiBold 700:Bold; do
  fonttools varLib.instancer 'FrankRuhlLibre[wght].ttf' wght=${W%%:*} --update-name-table -o /tmp/f.ttf
  pyftsubset /tmp/f.ttf --unicodes="$HEB" --layout-features='*' --output-file=assets/fonts/FrankRuhlLibre-${W##*:}.ttf   # ~51 KB each
done
fonttools varLib.instancer 'NotoRashiHebrew[wght].ttf' wght=400 --update-name-table -o /tmp/r.ttf
pyftsubset /tmp/r.ttf --unicodes='U+0020-0040,U+0591-05F4,U+FB1D-FB4F,U+2000-206F' --layout-features='*' --output-file=assets/fonts/rashi/NotoRashiHebrew-Regular.ttf   # ~20 KB
```

I verified that the small-caps lookups survive subsetting (smcp: 209 mappings, c2sc: 204).

Bundle impact:
- About 571 KB is loaded eagerly: EB Garamond 4 files at about 417 KB, plus Frank Ruhl Libre 3 files at about 154 KB.
- Noto Rashi Hebrew is NOT declared in pubspec `fonts:`. It is a plain asset, loaded on first use with `FontLoader('NotoRashiHebrew')..addFont(rootBundle.load('assets/fonts/rashi/NotoRashiHebrew-Regular.ttf'))`, so web does not download it at startup.
- While doing this, re-instance NotoSansHebrew-Regular/Medium/Bold with `--update-name-table` (their name table still says "Thin").

pubspec families:
- `EBGaramond`: Medium 500, SemiBold 600, Bold 700, MediumItalic 500 (style: italic).
- `FrankRuhlLibre`: Medium 500, SemiBold 600, Bold 700.
- Bold (700) is required because Flutter's `Text` merges `FontWeight.bold` when `MediaQuery.boldTextOf` is true (text.dart:722).

Licenses:
- Add `EBGaramond-OFL.txt`, `FrankRuhlLibre-OFL.txt` and `NotoRashiHebrew-OFL.txt` to `assets/fonts/licenses/`.
- Add them to the README table there.
- Add them to the `LicenseRegistry` map in lib/main.dart:40-49.

Unchanged:
- Scripture: Noto Serif Hebrew (default), Taamey Frank CLM (Medium only), Ezra SIL.
- UI: Noto Sans 400/500/700 and Noto Sans Hebrew 400/500/700.
- Atkinson Hyperlegible Next, Lexend, OpenDyslexic.

**UiFont change:**
- `standard` now means the bundled Noto Sans (English UI) or Noto Sans Hebrew (Hebrew UI) on EVERY platform.
- Add `system(null)` (the platform font) as the last option, labelled "Device font" / "גופן המכשיר".
- Persisted values keep their names.

### 4.2 Families and fallbacks

- **EBG** = `fontFamily: 'EBGaramond'`, `fontFamilyFallback: ['FrankRuhlLibre', 'NotoSerifHebrew']`. A Hebrew name inside an English heading then renders in Frank Ruhl Libre.
- **FRL** = `'FrankRuhlLibre'`, fallback `['EBGaramond', 'NotoSerifHebrew']`.
- **NS** = `'NotoSans'`, fallback `['NotoSansHebrew', 'NotoSerifHebrew']`.
- **NSH** = `'NotoSansHebrew'`, fallback `['NotoSans', 'NotoSerifHebrew']`.
- **Accessibility fonts** (Atkinson, Lexend, OpenDyslexic) use fallback `['NotoSansHebrew', 'NotoSerifHebrew']`.
- Every style sets an explicit `height` and `leadingDistribution: TextLeadingDistribution.even`.
- Never request a weight that isn't bundled. EBG and FRL: 500, 600, 700. NS and NSH: 400, 500, 700. Never w600 on NS or NSH.

### 4.3 Text theme: English UI

| Role | Family | Size / line height | Weight | Letter spacing | Use |
|---|---|---|---|---|---|
| displayLarge | EBG | 44/52 | 500 | -0.25 | Sefer-complete panel |
| displayMedium | EBG | 38/46 | 500 | -0.2 | (reserved) |
| displaySmall | EBG | 32/40 | 500 | 0 | Finished-panel title ≥600 dp |
| headlineLarge | EBG | 30/38 | 500 | 0 | Latin parsha name in the Today hero |
| headlineMedium | EBG | 28/36 | 500 | 0 | Masthead, Parsha header Latin name, finished panel |
| headlineSmall | EBG | 24/30 | 500 | 0 | Card titles, thread title, onboarding questions |
| titleLarge | EBG | 22/28 | 500 | 0 | App bar, dialog and sheet titles |
| titleMedium | NS | 16/24 | 500 | 0.1 | Row titles |
| titleSmall | NS | 14/20 | 500 | 0.1 | Author names, minor headers |
| bodyLarge | NS | 16/24 | 400 | 0.15 | Posts, settings row titles |
| bodyMedium | NS | 15/22 | 400 | 0.15 | Default body (up from M3's 14/20) |
| bodySmall | NS | 13/18 | 400 | 0.2 | Meta |
| labelLarge | NS | 15/20 | 500 | 0.1 | All buttons |
| labelMedium | NS | 13/16 | 500 | 0.3 | Chips, weekday labels, verse position |
| labelSmall | NS | 12/16 | 500 | 0.4 | Nav labels, ribbon names (minimum size anywhere) |

### 4.4 Text theme: Hebrew UI (separate TextTheme; letter spacing 0 everywhere; never uppercase)

| Role | Family | Size / line height | Weight |
|---|---|---|---|
| displayLarge | FRL | 40/56 | 500 |
| displayMedium | FRL | 34/48 | 500 |
| displaySmall | FRL | 30/42 | 500 |
| headlineLarge | FRL | 28/38 | 500 |
| headlineMedium | FRL | 26/36 | 500 |
| headlineSmall | FRL | 22/30 | 600 |
| titleLarge | FRL | 21/28 | 600 |
| titleMedium | NSH | 16/24 | 500 |
| titleSmall | NSH | 14/22 | 500 |
| bodyLarge | NSH | 16/26 | 400 |
| bodyMedium | NSH | 15/24 | 400 |
| bodySmall | NSH | 13/20 | 400 |
| labelLarge | NSH | 15/20 | 500 |
| labelMedium | NSH | 13/18 | 500 |
| labelSmall | NSH | 12/16 | 500 |

### 4.5 SeferType extension

| Token | English UI | Hebrew UI |
|---|---|---|
| eyebrow | EBG 18/22 w600, `[FontFeature.enable('smcp'), FontFeature.enable('c2sc')]`, letter spacing 0.8, `secondary` | FRL 16/20 w600, letter spacing 0, `secondary` |
| marginalia (one gentle sentence, never instructions) | EBG MediumItalic 19/28, `onSurfaceVariant` | FRL 17/26 w500, `onSurfaceVariant` (no italics in Hebrew) |
| ledgerNumeral | EBG 34/40 w600, `[liningFigures, tabularFigures]`, `onSurface` | same (Latin digits) |
| ringNumeral | EBG 22/24 w600, lining + tabular, `onSurface` | same |
| longformBody (Guide, About, Sources, Privacy) | EBG 20/32 w500, letter spacing 0.1 | FRL 18/30 w500 |
| longformHeading | EBG 24/30 w500, `onSurface` | FRL 22/30 w600 |
| hebrewDisplay (base; size set per use) | FRL w500, height 1.3, fallback `['NotoSerifHebrew']`, `primary` | same |
| ordinal (Hebrew aliyah letter) | FRL 20/24 w600 | same |

Rules:
- **Floors:** EB Garamond is never below 18sp (small-caps eyebrow) and never below 19sp for running text.
- **No digits in eyebrows.** Old-style small-cap figures make "1" read as "I", so put digits in the next line instead.
- **Serif numbers** always use `FontFeature.liningFigures()` and `tabularFigures()`.
- **Accessibility-font override:** when `uiFont` is atkinson, lexend or openDyslexic, every EBG/FRL role uses that family at the same size:
  - display, headline and title at w700;
  - eyebrow 13/16 w700, letter spacing 0.8, with `toUpperCase()` applied only when `!hebrewUi` and the string has no Hebrew;
  - marginalia 16/24 w400 upright;
  - longformBody 18/30 w400;
  - ledgerNumeral and ringNumeral w700 with tabular figures;
  - hebrewDisplay is NOT overridden: Hebrew titles stay FRL, because those fonts have no Hebrew.
- **UiFont.system** changes only the NS/NSH roles.
- **High contrast:**
  - EBG roles use w600 (w700 when bold text is on); FRL roles use w700;
  - eyebrow w700;
  - marginalia becomes upright EBG 19/28 w600.

### 4.6 Numerals and bidi

- Counts use Latin digits in both locales, with tabular figures.
- Hebrew numerals (גימטריה) are used for:
  - verse numbers, chapter heads and aliyah ordinals (א–ז);
  - Hebrew dates in the Hebrew UI.
- Add `String ltr(String s) => '⁦$s⁩'` in `lib/ui/l10n.dart`. Wrap every Latin-digit run that is interpolated into a Hebrew string with it: references "3:22–4:18", "2/7", times and counts. In Hebrew UI layouts, author names in post headers also go in their own Text widget (§9 Thread).

### 4.7 Scripture (`ScriptureStyles` and `ScriptureVerse`, lib/features/reader/scripture_text.dart)

**Mikra**
- Family, 26sp × readingScale, `height = settings.lineHeight` (default 1.9, minimum 1.6) and the bold rules are unchanged.
- Add a `StrutStyle(fontFamily: scriptureFamily, fontSize: size, height: lineHeight, leadingDistribution: even, forceStrutHeight: false)`, so a verse-number span in another family never changes the line pitch.
- Colour `onSurface`.

**Targum**
- 0.90× (was 0.92×), `onSurfaceVariant`, height `max(1.6, lineHeight - 0.1)`.
- In full-text mode, add a 2 px `goldLeaf` start-edge rule (`BorderDirectional(start:)`) with 12 px start padding. Remove the rule in high contrast.

**Verse numbers**
- FRL 600 at 0.55× of the verse size, colour `secondary` (`dimInk` when dimmed).
- Follow the number with U+00A0 NO-BREAK SPACE instead of a plain space, so a number is never stranded at the end of a line.
- Guided mode only: the number hangs in a start gutter 1.4 × verse size wide. Use `Row(textDirection: rtl, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic)` with the number Text, then `Expanded` verse Text.
- Full-text mode keeps the number inline.

**Chapter heading**
- Centred "פרק ג" in FRL 600 at `20 × sqrt(readingScale)`, colour `secondary`.
- Flanked by 32 px hairlines with a 12 px gap.
- English UI only: below it, "Chapter 3" (existing `chapterLabel`, not uppercased) in labelMedium `onSurfaceVariant`.
- 16 px above, 8 px below. This replaces the start-aligned "Chapter 3" label (phone_reader_full.png).

**Petuchah / setumah**
- `SectionBreakMark` (§7.3) replaces the grey letter in reader_screen.dart full-text rendering.
- Vertical space: petuchah 20 px above and below; setumah 10 px.

**Other text**
- Ketiv and alternate readings: 0.62×, `onSurfaceVariant`, as now (dimmed: `dimInk`).
- Rashi: Noto Serif Hebrew 0.78×, height 1.7, `onSurfaceVariant`.
  - New Display switch "Rashi script" (off by default) switches to NotoRashiHebrew 400 at 0.80×, height 1.75.
  - Dibbur hamatchil: FRL 700 in `onSurface` (never primary).
- English translation (study aid): EBG 500, 20sp × readingScale, height 1.5, `onSurfaceVariant`.
  - Verse number EBG 600 in `secondary` with lining figures.
  - If `uiFont` is not standard or system, use uiFont at 17/26.

**Focus mode**
- The current verse gets `BoxDecoration(color: verseHighlight, border: BorderDirectional(start: BorderSide(color: primary, width: 3)))`. No radius: Flutter forbids a radius with non-uniform borders.
- Padding: start 12, vertical 4.
- All other verses, including their numbers and ketiv, use `dimInk`. Delete every `withValues(alpha: 0.55)` in scripture_text.dart.

**Line widths:** `LineWidth.narrow` 560, `medium` 680 (default), `wide` 880 (was 1040, about 80 characters at 26sp).

## 5. Layout tokens

- **Grid:** 4 pt. Spacing scale: 4, 8, 12, 16, 20, 24, 28, 32, 40, 48.
- **Breakpoints:** compact <600, medium 600–1199, expanded ≥1200 (`Breakpoints` in shell.dart).
- **Gutters:** 20 / 24 / 32.
- **Content max width:**
  - 720 for lists and dashboards;
  - reading column per LineWidth;
  - long-form pages 620;
  - account/sign-in 440;
  - Today two-column container 1040 at ≥1200.
- **Rhythm:** card padding 20 (16 under 360 dp); gap between cards 12; gap between sections 28; inside a card 12.
- **Radii:**
  - chips and map tiles 6–8;
  - buttons and inputs 10;
  - cards and paper groups 12;
  - dialogs 16;
  - sheets 20 (top only);
  - the nav indicator is the only stadium shape.
- **Elevation:** 0 everywhere. Separation comes from paper on surface plus a 1 px hairline. FAB and menus are 2, with `shadowColor` = shadow token.
- **App bar title alignment on wide screens:** `PageScaffold` computes `titleSpacing = max(gutter, (MediaQuery.sizeOf(context).width - railWidth - 1 - contentMaxWidth) / 2 + gutter)` and the same value for `actionsPadding` at the end. railWidth is 0, 80, or 256 when extended. This puts the title edge on the content edge, fixing D11.

## 6. Components

### 6.1 Focus

`FocusRingBorder extends RoundedRectangleBorder`:
- fields `ring` and `gap`;
- `paint()` calls `super.paint`, then strokes `rrect.inflate(1)` in `gap` (width 2), then `rrect.inflate(3.5)` in `ring` (width 3);
- override `copyWith`, `scale`, `lerpFrom` and `lerpTo` to keep `ring` and `gap`.

Every ButtonStyle:
- `shape` resolves `WidgetState.focused` to `FocusRingBorder(borderRadius: 10, ring: sefer.focus, gap: sefer.focusGap)`, and otherwise to the normal shape;
- `animationDuration: Duration.zero`, so Material's shape lerp never drops the ring. Nothing else animates, since elevation is 0.

This fixes D3: the ring paints on the surface, outside the fill (9.72:1 in light).

Chips use `side: WidgetStateBorderSide.resolveWith` → focused gives `BorderSide(color: focus, width: 3, strokeAlign: BorderSide.strokeAlignOutside)`.

`SeferInkWell` is used for cards, PaperRows, week cells, map tiles and ribbon tabs:
- an InkWell with `onFocusChange`;
- when focused and `FocusManager.instance.highlightMode == FocusHighlightMode.traditional`, a foreground `ShapeDecoration(RoundedRectangleBorder(radius, side: BorderSide(color: focus, width: 3, strokeAlign: outside)))`.

Text fields: focused border 2 px primary (was 3). The ring appears instantly.

### 6.2 App bar

- Height 64; background surface; `surfaceTintColor` transparent; `scrolledUnderElevation: 1` with `shadowColor: outlineVariant`, giving a hairline when scrolled.
- High contrast: no elevation and a 2 px bottom outline.
- Title: titleLarge (serif), onSurface, start-aligned.
- Icons: 24, onSurfaceVariant, with 48 tap targets.
- Two-line variant (reader, haftarah): an Eyebrow over titleLarge, `toolbarHeight: 64`.

### 6.3 Cards and PaperGroup

**Card (InfoCard and CardTheme)**
- Colour paper, radius 12, 1 px hairline at FULL opacity (was 50%), elevation 0, `clipBehavior: antiAlias`, padding 20.
- High contrast: 2 px outline border.

**PaperGroup** (replaces runs of separate cards and ListTiles)
- A Card with zero padding, holding PaperRows separated by 1 px hairline dividers inset 54 at the start (16 when rows have no icon).

**PaperRow**
- Min height 56 (one line) or 72 (two lines); padding start 16, end 12, vertical 12.
- Leading icon 22 in onSurfaceVariant, in a 38 slot (icon then 16 gap).
- Title bodyLarge onSurface; subtitle bodyMedium onSurfaceVariant, 2 lines max.
- Trailing: an optional value in bodyMedium onSurfaceVariant, then `Icons.chevron_right` 20 in outline (mirrors in RTL automatically).
- Tap via SeferInkWell.

**GroupHeader**
- Eyebrow, 28 above and 8 below, start inset 4.
- Semantics header level 2.

### 6.4 SectionHeader (common.dart)

- Restyle as an Eyebrow in `secondary` (was titleMedium in blue w600).
- Keep the `header`/`headingLevel` semantics and the trailing slot.

### 6.5 Buttons (all radius 10; never a stadium)

**Filled**
- primary / onPrimary; min height 48 (52 for the single hero CTA and reader Next).
- Horizontal padding 24; icon 20 with an 8 gap; labelLarge w500.
- At most one Filled button per screen region.

**Tonal:** primaryContainer / onPrimaryContainer, height 48.

**Outlined:** 1 px outline (2 px in high contrast), foreground primary. Use only where a secondary action must look like a button; prefer Text.

**Text:** primary, min 48×48. Underlined in high contrast (`TextDecoration.underline`).

**States**
- Pressed overlay 10%; hover 6%.
- Disabled: M3 defaults (onSurface at 12% fill, 38% label).
- Destructive (confirm dialogs only): Filled error / onError.

### 6.6 Chips

- Height 36, padded to 48; radius 8; labelMedium.
- ChoiceChip:
  - `showCheckmark: false`;
  - unselected: 1 px outline, transparent;
  - selected: primaryContainer fill, 1.5 px primary border, label w700 onPrimaryContainer. The border width and weight are the non-colour cue.
- FilterChip (multi-select) keeps its checkmark.
- A leading check icon anywhere else means "done" only.

### 6.7 Inputs

- Outlined, radius 10; enabled 1 px outline (2 px in high contrast); focused 2 px primary; error 2 px error.
- Label bodyLarge onSurfaceVariant; helper and counter bodySmall with tabular figures.
- Code entry (account): six 48×56 boxes, radius 10, titleLarge NS w500 with tabular figures; auto-advance; paste fills all six.

### 6.8 Switch, slider, segmented control

**Switch**
- Selected: track primary, thumb onPrimary with a check icon (16).
- Unselected: track surfaceContainerHighest with a 2 px outline border; thumb outline, 16 px, no icon. Thumb size and position are the non-colour cue.
- High contrast: icons on both states (keep the check/close thumbIcon, app_theme.dart:258).

**Slider**
- `year2023: false`; active track primary, inactive surfaceContainerHighest, height 4; thumb primary 20.
- `tickMarkShape: SliderTickMarkShape.noTickMark`.
- Value at the end in labelLarge with tabular figures; −/+ IconButtons 48.

**SegmentedButton**
- Radius 10, height 48; selected primaryContainer with label w700 and a check icon (keep the M3 check here; it's the non-colour cue); unselected transparent with 1 px outline.

### 6.9 Navigation bar (phone)

- Height 72; background surfaceContainer; 1 px hairline top border.
- Indicator primaryContainer 64×32 (stadium, the platform idiom).
- Icons 24, outlined; filled when selected.
- Labels always shown, labelSmall: selected onSurface w700, unselected onSurfaceVariant w500 (6.51:1).
- Icons: Today `today`; Parsha `menu_book`; Progress `donut_large_outlined`/`donut_large` (echoes the rings; replaces the sparkle `insights`); Community `forum`; Settings `settings`.

### 6.10 Navigation rail (≥600)

- Background surface, with a 1 px hairline end border (replaces surfaceContainer and the VerticalDivider in shell.dart).
- Leading: the app mark (icon.png at 40×40, ClipRRect radius 10).
- Extended at ≥1200: the mark plus a 12 gap plus the wordmark "Shnayim Mikra" (EBG 500 20/24) or "שניים מקרא" (FRL 500 20/24) in onSurface. Semantics header. Replaces "SM" / "ש״מ".
- Indicator primaryContainer radius 12; destination height 56.

### 6.11 ParshaRings and RingLegend (progress_widgets.dart)

**Rings**
- Sizes: 104 (Today hero), 88 (Parsha header), 40 (compact).
- `stroke = size × 0.055`; `r0 = size/2 - stroke/2`, `r1 = r0 - 1.6·stroke`, `r2 = r1 - 1.6·stroke`. At 104 this leaves a 56 px hole.
- Arc weights by verse count, as now. Gap 0.042 rad between aliyot; butt caps.
- Start at −π/2 and sweep CLOCKWISE in both directions. Do not mirror.
- Colours: ring 0 ringMikra1, ring 1 ringMikra2, ring 2 ringTargum; track ringTrack.
- Centre: "2/7" in ringNumeral, plus "aliyot" in labelSmall onSurfaceVariant.
- Wrap in RepaintBoundary. Existing semantics stay.

**RingLegend** (always beside or under rings of size 88 or more)
- Three rows, each 24 high: a 9 px dot in the ring colour, a 10 gap, the label in bodyMedium (`passMikra1`, `passMikra2`, `passTargum`/`passRashi`), and the count end-aligned "3 of 7" in bodyMedium onSurfaceVariant with tabular figures.
- Excluded from semantics: the rings' label already says it.

### 6.12 LedgerCard (replaces the two streak cards, today_screen.dart:300-325)

- One card with `IntrinsicHeight(Row([col, VerticalDivider(width: 1, color: hairline), col]))`.
- Each column: padding 16; ledgerNumeral (the count), then bodySmall label (`streakParsha`, `streakDays`); on Progress, an extra bodySmall "Longest: …".
- When the value is 0, the numeral slot shows titleMedium text instead:
  - parsha streak: `streakBeginsWith(name)` = "Begins with Bereshit";
  - days on track: `daysBeginToday` = "Begins with today's reading".
  - Never show a stark 0.
- The whole card is a SeferInkWell to /progress. Semantics: "Parsha streak: begins with Bereshit. Days on track: 2".

### 6.13 WeekStrip

- Seven equal cells; min 48×68; radius 10; horizontal margin 2.
- Weekday label in labelMedium onSurfaceVariant (today: onSurface w700). Icon 22, 8 below the label.
- Cell states:
  - Today: primaryContainer fill at 100% (was 35%) plus a 1.5 px primary border. Icon: a 2 px primary ring with an 8 px centre dot.
  - Rest (Shabbat or Yom Tov): restWash fill plus candles (§7.6) in `rest`.
  - Kept: a filled 20 px circle in `done` with a 14 px onDone check.
  - Ahead / caught up: the same disc with the existing fast_forward / published_with_changes glyph.
  - Grace: `shield_outlined` in grace.
  - Missed: `remove_circle_outline` in neutral.
  - Open (past, unread): `radio_button_unchecked` in onSurfaceVariant.
  - Upcoming: `circle_outlined` in **outline** (was outlineVariant, D16).
  - No reading: `horizontal_rule` in outline.
- Keep the existing Tooltip and Semantics labels.

### 6.14 Torah map (progress_screen.dart tile())

**Layout**
- Fixed grid: 3 columns under 600, 4 at 600 and up, 6 at 1200 and up; gap 6.
- Build each row as `IntrinsicHeight(Row([Expanded(tile) …]))` so tiles grow with text scale. No GridView aspect ratio.

**Tile**
- minHeight 52; radius 6; padding 8/6.
- `Row(mainAxisAlignment: center)`: an optional 14 px icon, a 4 gap, then `Flexible(Text(maxLines: 2, textAlign: center))` in labelMedium.

**States**

| State | Fill | Border | Text | Icon |
|---|---|---|---|---|
| on time | done | none | onDone | check |
| late / restored | late | none | onLate (5.49) | check_circle_outline |
| made up | paper | 1.5 px late | onSurface | history |
| missed | paper | 1 px outline | onSurfaceVariant | remove 14 in neutral (the non-colour cue, D8) |
| current | primaryContainer | 2 px primary | onPrimaryContainer w700 | timelapse |
| upcoming / untracked | paper | 1 px hairline | onSurfaceVariant | none |

**Book header row**
- Hebrew book name (FRL 600 18), a 8 gap, the Latin name (titleSmall), and "3 of 12" end-aligned in bodySmall with tabular figures.
- In the Hebrew UI, the Latin name is dropped.

### 6.15 YearBar

- 54 segments across the content width; segment gap 2; an extra 4 px between books; height 8; radius 1.5.
- Colours: on time = done; late = late; made up = paper with a 1 px late border; current = primaryContainer with a 1 px primary border; everything else = ringTrack.
- Below it, book abbreviations in labelSmall onSurfaceVariant at each book's start: "Gen Exo Lev Num Deu" / "בר׳ שמ׳ וי׳ במ׳ דב׳".
- One Semantics node: "This year: 0 of 54 parshiyot complete; Bereshit in progress". RepaintBoundary.

### 6.16 AliyahRibbon (replaces _AliyahSelector, reader_screen.dart:517-549; fixes D5)

**Layout**
- Height 76, with a 1 px hairline below. Horizontal padding 8.
- `LayoutBuilder`: if `maxWidth >= 7 × 56`, use a Row of 7 Expanded tabs. Otherwise use a horizontal ListView with tabs 64 wide that auto-scrolls the selected tab into view (`Scrollable.ensureVisible`, duration `Motion.medium`).

**Each tab** (SeferInkWell, min 56 wide), top to bottom:
- the Hebrew ordinal א–ז in `ordinal` style (selected onSurface, else onSurfaceVariant);
- 2 gap, then the name in labelSmall (selected onSurface w700);
- 6 gap, then mini PassPips (§7.5, size 6, gap 3).

**Selected indicator:** a 3 px primary bar, radius 1.5, inset 8 at the bottom.

**Semantics:** `button: true, selected: isSelected`, label `aliyahTabLabel(name, n)` + state: "read", "{done} of 3 readings done", or "not started".

On desktop the ribbon is constrained to the reading-column width and centred.

### 6.17 PassTrack (replaces _StepHeader card and LayerLabel, reader_screen.dart:678-734 and 652-664; fixes D12)

Row of three Expanded segments with an 8 gap. Each segment is a Column:
- Label in labelMedium: `passTrackLabel(n, name)` = "1 · Mikra", "2 · Mikra", "3 · Targum" (or Rashi, or the third Mikra).
  - Done: onSurfaceVariant with a leading 14 px check in primary.
  - Current: onSurface w700.
  - Upcoming: onSurfaceVariant.
- 6 gap, then a 4 px bar with radius 2.
  - Done and current: ringMikra1 / ringMikra2 / ringTargum for segments 1/2/3.
  - Upcoming: ringTrack.

Below the track:
- 8 gap, then ONE instruction line in bodyLarge onSurface: the existing step title ("Read the Hebrew", "Read the Hebrew again", "Read the Targum"), with `liveRegion: true`.
- 12 gap, then the chapter heading (§4.7) when a chapter starts, then the verse.

Nothing else sits above the first verse.

### 6.18 Reader bottom bar (replaces _BottomBar, reader_screen.dart:762-824)

**Frame**
- Background surface, 1 px hairline top border.
- Content constrained to the reading-column width and centred, so on desktop Back and Next sit at most 680 apart (D11).
- Height 84 plus the safe area.

**Contents, top to bottom**
- A 3 px LinearProgressIndicator: primary on ringTrack, radius 2. It fills from the start edge and mirrors in RTL automatically.
- 8 gap, then a Row:
  - **Back:** `TextButton.icon` with `Icons.chevron_left` (matchTextDirection), label "Back", foreground onSurfaceVariant.
  - **Centre:** `Expanded(Center(Text('Verse 1 of 21', labelMedium, onSurfaceVariant, tabular figures)))`.
  - **Next:** `FilledButton` min 128×52, label "Next" with a trailing `Icons.chevron_right` (mirrored).
  - On the final step of the aliyah, the label becomes `finishStep` ("Finish") with a leading check.

Keep the keyboard shortcuts.

### 6.19 Sheets, dialogs, snackbars, tooltips

**Bottom sheet**
- Background paper; top radius 20; `showDragHandle: true` (36×4, outline at 40%).
- Title titleLarge serif; padding 24 (16 under 360); max width 640, centred.

**Dialog**
- Background paper, radius 16, padding 24.
- Title titleLarge serif; body bodyMedium onSurfaceVariant.
- Actions end-aligned: text buttons plus at most one Filled.
- Enter: fade plus scale from 0.98, 150 ms.

**Snackbar**
- Floating; radius 10; margin 16; inverseSurface with onInverseSurface; action in inversePrimary.
- Duration 4 s, or 8 s with an action. Flutter already holds action snackbars when `accessibleNavigation` is on.
- Sits above the reader bottom bar.

**Tooltip:** inverseSurface, radius 6, bodySmall in onInverseSurface; waitDuration 400 ms (existing).

### 6.20 NoticeBanner (common.dart) and the demo notice

**NoticeBanner**
- Inset within gutters (never full-bleed); secondaryContainer; radius 12; no border (2 px outline in high contrast).
- Padding 12/16; icon 20 in onSecondaryContainer; bodyMedium onSecondaryContainer; optional trailing TextButton.

**Demo notice** (community_ui.dart:139-155)
- A NoticeBanner with `info_outline` (replaces the pink `tertiaryContainer` strip and the flask icon).
- Shown on the Community home only, dismissible for the session.
- Forum, Thread and Compose instead show a small "Demo" tag in the app bar actions:
  - labelSmall, secondaryContainer fill, radius 6, padding 6/2;
  - tapping it opens a sheet with the full explanation.

### 6.21 Forum posts as "letters" (thread_screen.dart)

- No card per post. Posts are separated by full-width 1 px hairlines, with 16 vertical padding.
- **Header row:**
  - 32 px initial disc in secondaryContainer, initial in EBG 600 16 onSecondaryContainer;
  - 12 gap, then the author in titleSmall in its OWN Text with `textDirection: autoDirection(name)`;
  - then " · " and the relative time in bodySmall onSurfaceVariant in a separate Text;
  - then the overflow menu.
  - Separate widgets fix the mixed-direction header in he_thread.png.
- **Body:** bodyLarge 16/26 (Hebrew 16/26 NSH), `autoDirection`, start-inset 44 to align with the name.
- **Footer:** TextButton "Todah" with `volunteer_activism_outlined` 18 (filled `volunteer_activism` when given) and the count with tabular figures. Replaces favorite/favorite_border at thread_screen.dart:400.
- The opening post gets a 3 px primary start rule.

### 6.22 Empty states

Centred, max width 320, 40 top padding:
1. SeferDivider;
2. 12 gap, then one marginalia sentence;
3. 16 gap, then a Tonal button.

### 6.23 Finished panel (reader_screen.dart:826-884; replaces the celebration icon)

Centred, max width 480:
1. SeferDivider at 200 wide (animated, §8).
2. 16 gap, then the title in headlineMedium: "Revi'i is complete" (existing string).
3. 8 gap, then a marginalia line, e.g. "Chamishi is four verses."
4. 24 gap, then actions: Filled "Next aliyah · Chamishi" and Text "Done".
5. When the parsha is complete: the title becomes `weekComplete` and a Tonal "Read the haftarah" (if enabled) is added.

When a sefer is complete: a one-time full-screen panel. SeferDivider, then "חֲזַק חֲזַק וְנִתְחַזֵּק" in hebrewDisplay 40/56 primary, then SeferDivider, then a Filled "Continue". It never auto-dismisses.

### 6.24 Theme swatches (Display settings)

- A 3-column grid (2 columns under 360) of cards 96 high, radius 12, each painted in its own theme:
  - surface background;
  - "אָ" in Noto Serif Hebrew 24 in onSurface;
  - a 24×4 primary bar and a 24×1 goldLeaf rule;
  - the label in labelMedium below the card.
- Selected: 2 px primary border plus a 20 px check badge (primary disc, onPrimary check) at the top-end corner.
- Wrapped in the existing RadioGroup semantics. Match device is a separate row above the grid (switch).

## 7. Motifs and iconography

At most two ornaments per screen. All are CustomPainters in `lib/ui/widgets/ornaments.dart`, wrapped in ExcludeSemantics. In high contrast they draw in onSurface.

1. **Lozenge:** an 8×8 box, path M4,0 L8,4 L4,8 L0,4 Z. Filled in goldLeaf as a divider centre. Sizes 8 and 12.
2. **SeferDivider:**
   - width `min(200, 0.45 × column)`, height 16;
   - 1 px hairlines from each end to 10 px short of centre, at y=8;
   - an 8 px goldLeaf lozenge at the centre.
   - Use between hero sections, in finished panels, in empty states and between long-form sections. Never between list rows.
3. **SectionBreakMark:** a centred Row of a 40 px hairline, 8 gap, פ or ס in FRL 600 at 0.55× the verse size in `secondary`, 8 gap, and another 40 px hairline.
4. **TitlePageFrame:**
   - outer: a 1 px hairline at radius 12;
   - inner: a 1 px goldLeaf rule inset 6 at radius 8;
   - used ONLY on the Today hero, the Welcome title block and the About header at ≥600;
   - in high contrast: a 2 px outline, with no inner rule.
5. **PassPips:**
   - three lozenges (size 12 with gap 8, or mini 6 with gap 3) in reading order; the Row follows Directionality;
   - done: filled in ringMikra1 / ringMikra2 / ringTargum;
   - pending: a 1.5 px outline stroke;
   - current step (parsha rows only): an extra 2 px ring in its colour;
   - excluded from semantics.
6. **Shabbat candles** (refine _CandlesPainter, 24 box):
   - bodies: rounded rects at x=6.5 and x=14.0, w 3.5, y 11, h 10, r 0.8;
   - flames: centred at cx 8.25 and 15.75 with `M cx,3 C cx+2.6,5.6 cx+2.2,9.5 cx,9.5 C cx-2.2,9.5 cx-2.6,5.6 cx,3 Z`;
   - colour `rest`;
   - also replaces the moon icon in Reminders.
7. **Icon substitutions:**
   - `celebration`/`celebration_outlined` at today_screen.dart:181 and reader_screen.dart:850: removed (SeferDivider instead);
   - notification_prompt.dart:20: becomes `notifications_outlined`;
   - `emoji_events` and `lock_outline` milestones: removed (Record, §9 Progress);
   - `science_outlined`: becomes `info_outline`;
   - `favorite`: becomes `volunteer_activism`;
   - nav `insights`: becomes `donut_large`;
   - the streak-tile icons, the repeated `menu_book` on the 54 Browse rows, and the reader LayerLabel icons: removed.
   - The grace shield and `auto_stories_outlined` for the haftarah stay.
8. **App icon** (critical, D1). `tool/branding/make_icon.py` writes `assets/branding/icon.svg` plus all PNGs.

   **Shaping**
   - Use `uharfbuzz` with FrankRuhlLibre-Bold.ttf. Text "שמו״ת" = U+05E9 U+05DE U+05D5 U+05F4 U+05EA, added with `buf.add_codepoints`, direction 'rtl', script 'Hebr', language 'he'.
   - **Assert** that the output clusters in visual order are `[4,3,2,1,0]`, i.e. ש is the rightmost glyph. Fail the build otherwise.
   - Draw the outlines with fontTools `SVGPathPen` and rasterize with `cairosvg`.

   **Master** (1024², opaque):
   - background: a vertical linear gradient from #23497F (top) to #16315C (bottom);
   - text: font size 300 px (letters 177 px tall, about 744 px wide), fill #F6F0E2, centred horizontally, baseline y=500;
   - three rules, each 440×26 with radius 13 at x 292–732, at y 580, 628 and 676, filled #F6F0E2, #F6F0E2, #D2A64A (two Mikra and the Targum);
   - the group is vertically centred.
   - Contrast: cream on gradient 7.93–11.35; gold rule 5.71.

   **Variants**
   - Android adaptive foreground: the same group, transparent background, scaled 0.70 about (512,512) so every point lies within 300 px of the centre (inside the 66/108 safe circle). The background layer is solid #1D3F75.
   - Monochrome: the foreground with every shape #FFFFFF.
   - iOS: the master without alpha.
   - Web: Icon-192/512 from the master; maskable 192/512 with the group scaled 0.90 on the full-bleed gradient.
   - Sizes ≤32 px (favicon.png, Windows .ico entries at 16/24/32): the three rules only, each 62.5% of the canvas wide and 9.4% high, gaps 7.8%, vertically centred, on the gradient with corner radius 18.75%.
   - The Windows .ico also carries 48, 64 and 256 from the master.

   Then run `dart run flutter_launcher_icons`.

## 8. Motion (lib/ui/theme/motion.dart)

**Tokens**
- Durations: short 150 ms, medium 250 ms, long 400 ms, ring 600 ms, frame 900 ms.
- Curves:
  - standard `Cubic(0.2, 0.0, 0.0, 1.0)`;
  - decelerate `Cubic(0.05, 0.7, 0.1, 1.0)`;
  - accelerate `Cubic(0.3, 0.0, 0.8, 0.15)`.
- `Motion.of(context).d(Duration)` returns `Duration.zero` when `settings.reduceMotion || MediaQuery.disableAnimationsOf(context)`. Every animation call site uses it.

**Page transitions**
- Android: `FadeForwardsPageTransitionsBuilder`.
- iOS and macOS: Cupertino.
- Web, Windows and Linux: fade-through. Incoming page opacity 0→1 over 250 ms (decelerate) with a rise of 8 px; no zoom.
- Reduce Motion keeps `_NoTransitionsBuilder`.

**Reader**
- Step and verse change: `AnimatedSwitcher`, 180 ms, opacity only, keyed by (chunk, step). No horizontal slides.
- The scroll resets to the top instantly.
- PassTrack bar fill and pip fill: 150 ms colour cross-fade.
- Bottom progress: 250 ms tween (standard).
- Next press: a light haptic if haptics are on.

**Progress**
- When a unit completes, the ring arc sweeps from the old fraction to the new one over 600 ms (decelerate) the next time Today or Parsha is shown. Keep the previous value in memory only.
- The centre count cross-fades over 150 ms.
- A week-strip icon cross-fades over 250 ms. No bounce, no scale.

**Completion moments** (once each, silent, no confetti)
- Aliyah: the SeferDivider hairlines draw outward from the lozenge over 400 ms, then the title fades in over 150 ms; `hapticSuccess`.
- Parsha: the hero's inner goldLeaf frame rule draws around the card once over 900 ms (`PathMetric.extractPath`), then stays static.
- Sefer: a panel fade of 400 ms.

**Never:** looping, idle or time-based animation anywhere. Nothing at all moves on the rest-day Today. Animate only opacity, transform and CustomPaint progress; never BoxShadow or blur.

## 9. Screen by screen

### Today (today_screen.dart; phone_today, he_today, dark_today, desktop_today)

Remove the AppBar. Everything sits in a SafeArea PageBody.

1. **TodayHeader** (12 top):
   - Row of `Expanded(Column)` and a help IconButton (help_outline, tooltip `guideTitle`).
   - The column holds a running head in bodySmall w500 onSurfaceVariant (`'${names.dateLong(today)} · ${names.hebrewDate(today)}'`), a 2 gap, and the masthead `appTitle` in headlineMedium.
   - The masthead is not a heading; the parsha name stays heading level 1.
2. Paused banner and open-previous-week card: NoticeBanner style.
3. **Hero card** (TitlePageFrame, padding 24, centred):
   - **Eyebrow:** `parshatHashavua` by default; `erevShabbat` on Friday at or after 12:00 local; "Simchat Torah" when the portion is Vezot Haberakhah.
   - 8 gap, then the Hebrew pointed name: new `Names.portionPointed(p)` = `HebrewText.forDisplay(p.nameHe, nikud: true, teamim: false)`, in hebrewDisplay 46/60 primary. Semantics header level 1 with label `parshaLabel(name)`.
   - English UI: the Latin name in headlineLarge onSurface. Hebrew UI: the Latin name in bodyMedium onSurfaceVariant.
   - 4 gap, then bodyMedium onSurfaceVariant: "Genesis 1:1–6:8 · Read Shabbat, 10 October". Then bodySmall onSurfaceVariant `shabbatInDays`.
   - 16 gap, SeferDivider, 16 gap.
   - Row of ParshaRings 104, a 20 gap, and `Expanded(RingLegend)`. Under the legend, an end-aligned TextButton `allAliyot` ("All aliyot") with a chevron, to /week/{id}. Under 360 dp the rings sit centred above the legend.
   - 20 gap, then a full-width Filled button (52) with `menu_book` and a label naming the destination. Let `next = ctx.nextAliyah` and `p` = the first ReadingPass of `next` that is not done:
     - nothing read this week: `startAt(name)` = "Start · Rishon";
     - `next` has some passes done: `continueAtPass(name, passLabel(p))` = "Continue · Shlishi, Targum";
     - otherwise: `continueAt(name)`.
     - It routes to `/read/{id}/{next}`; the reader already resumes via `flow.resumeFrom` (reader_screen.dart:318-319). If a unit was marked done without saved positions, derive positions from `isUnitDone` so it resumes at the first unread pass.
   - Delete the outlined "2 of 7 aliyot" button (D10).
   - **Complete state:** the rings and CTA are replaced by the animated frame (§8), titleLarge `weekComplete`, and a marginalia line. Add a Tonal "Read the haftarah" if enabled and not yet read, and a Text "Discuss the parsha".
4. **Today card** (start-aligned):
   - Eyebrow `todayReadingTitle`, then headlineSmall `names.aliyot(day.aliyot)`, then bodyMedium onSurfaceVariant verses and minutes.
   - If behind and not done: marginalia with the new `todayBehind` copy (§10).
   - 16 gap, then actions:
     - a Tonal `readAliyah(firstUnreadToday)` = "Read Shishi", ONLY when `firstUnreadToday != next`;
     - a TextButton.icon `import_contacts` `readFromBook`, always.
     - Never two Filled buttons; never two unlabelled CTAs to different places.
   - Done: a check_circle 20 in primary with titleSmall `todayDone`.
   - No reading today: bodyMedium onSurfaceVariant `todayNothingPlanned`.
5. **WeekStrip card** (§6.13).
6. **LedgerCard**, if `showStreaks` (§6.12).
7. **"This week" PaperGroup:**
   - Haftarah row: `auto_stories_outlined`, title "Haftarah", subtitle the reference, plus a second subtitle line for a special haftarah.
   - Discuss row: `forum_outlined`, `discussThisWeek`.
   - These replace two separate cards.
8. **Rest day** (`JewishHolidays.isRestDay(today, israel)`):
   - The hero shows candles at 40, `shabbatShalom` or `chagSameach` in headlineMedium, the pointed parsha name in hebrewDisplay 32/44, and bodyMedium `restDayBody`.
   - No rings, CTAs, Today card or ledger; only a Text link "Open the parsha".
   - The wording goes to the rabbinic advisor (DESIGN.md §11).
9. **Desktop ≥1200:**
   - A container of max width 1040 with columns 7/5 and a 24 gap.
   - Left: header, hero, Today card. Right: week strip, ledger, "This week".
   - 600–1199: a single 720 column.

### Parsha tab / Week overview (week_overview_screen.dart, parsha_tab.dart; phonetall_parsha, phonetall_week, he_parsha)

1. **Header** (no card, start-aligned):
   - Hebrew pointed name in hebrewDisplay 36/48 primary; in the English UI, the Latin name in headlineMedium;
   - bodyMedium onSurfaceVariant "Genesis 1:1–6:8 · 146 verses · Read Shabbat, 10 October";
   - the status line (icon plus label) in bodySmall;
   - ParshaRings 88 with RingLegend in a Row at ≥360.
2. **GroupHeader** with `aliyotProgress` ("2 of 7 aliyot", no digits in the eyebrow, so render it as titleSmall onSurfaceVariant instead of an eyebrow).
3. **One PaperGroup with seven rows** (replaces seven cards):
   - Leading 40 disc: done = primary fill with an onPrimary check 20; otherwise ringTrack fill with the Hebrew ordinal (FRL 600 18, onSurface).
   - Title in titleMedium, e.g. "Rishon"; subtitle bodySmall "Genesis 1:1–2:3 · 34 verses · about 15 min"; a second line bodySmall "Planned for Monday".
   - The alternative-division note becomes a third line in marginalia at 17/24 ("Some sources use 4:19–26").
   - Trailing: PassPips (size 12) above the existing overflow menu.
   - Tap opens the reader.
4. **Second PaperGroup:** Haftarah and Discuss rows.
5. **Footer:** a centred TextButton "Mark the whole parsha as read".

**Browse** (browse_screen.dart):
- One PaperGroup per book under a book header ("בראשית" FRL 600 20 + "Genesis" titleSmall).
- Rows:
  - leading: a 28 px column with the ordinal in labelMedium onSurfaceVariant with tabular figures;
  - title: the Latin name in EBG 500 20/26;
  - Hebrew name FRL 500 18 end-aligned;
  - subtitle: the reference in bodySmall.
  - The `menu_book` icon is removed.
- The current parsha row has a 3 px primary start rule and the Eyebrow "This week" above its title.
- In the Hebrew UI, the Hebrew name is the title and the Latin name is end-aligned in bodySmall.

### Reader, guided (reader_screen.dart; phone_reader, he_reader, dark_reader, desktop_reader)

- App bar, two lines:
  - Eyebrow: the parsha name;
  - titleLarge: "Revi'i · רביעי" in the English UI, "רביעי" in the Hebrew UI.
  - Actions unchanged (Listen, Aa, more).
- Then the AliyahRibbon (§6.16), then a 16 gap, then the PassTrack (§6.17), then the verse.
- Text column: max per LineWidth; side padding 20; top 16.
- Typesetting per §4.7: gold hanging verse number, centred chapter head, section-break marks.
- **_Note** (no Targum or Rashi available; reader_screen.dart:736-760): a NoticeBanner with `info_outline` (replaces tertiaryContainer).
- Bottom bar per §6.18; finished panel per §6.23.
- Desktop: ribbon, track, text and bottom bar all share one centred column.

### Reader, full text (phone_reader_full, desktop_reader_full)

- Verse blocks 20 apart. Targum under each verse with the goldLeaf start rule (§4.7) and no repeated number.
- When Rashi is on: a "רש״י" eyebrow, then the Rashi style.
- Petuchah and setumah marks.
- At the end: a SeferDivider, then a centred Tonal "Mark this aliyah as read" (the existing label, which the tests rely on).
- Focus mode per §4.7.

### Haftarah (haftarah_screen.dart)

- The same paper layout and verse styling.
- Header: Eyebrow "Haftarah", headlineSmall reference "I Samuel 20:18–42", and the special-haftarah line in marginalia.
- Book labels become chapter heads.
- At the end: a SeferDivider and a Tonal "Mark the haftarah as read".

### Progress (progress_screen.dart; phonetall_progress, dark_progress, he_progress, desktop_progress)

In order:
1. **LedgerCard** with "Longest" lines.
2. **Grace PaperRow:** `shield_outlined` in grace, `graceAvailable(n)` = "1 grace day available", trailing TextButton `aboutStreaks`. That opens a sheet holding the two explanatory paragraphs, which leave the page.
3. **This year:**
   - Eyebrow `thisYear`;
   - headlineSmall `parshiyotOfYear(0, 54)`;
   - bodySmall "5787 · 50 verses read twice with Targum";
   - YearBar.
4. **This week's plan:** WeekStrip card.
5. **Torah map** (§6.14), keeping the info button.
6. **Make-up list:** unchanged content, as a PaperGroup.
7. **Recent weeks:** a PaperGroup. Rows show the name in titleMedium, a status icon plus label in bodySmall, and the date end-aligned in bodySmall with tabular figures.
8. **"Life happens":** a PaperRow with a pause icon that opens the existing pause flow. Its ChoiceChips follow §6.6.
9. **Record** (replaces Milestones, progress_screen.dart:337-376):
   - GroupHeader `recordTitle`;
   - achieved items only, newest first;
   - each row: an 8 px lozenge, the title in bodyLarge, the date in bodySmall;
   - a completed sefer adds "חֲזַק חֲזַק וְנִתְחַזֵּק" in FRL 500 17 in `secondary` under its row;
   - no locked items, trophies or counts of what remains.

### Community (community_screen.dart, forum_screen.dart, thread_screen.dart, compose_screen.dart, account_screen.dart)

**Home**
- Demo NoticeBanner (§6.20).
- Featured row (a Card with SeferInkWell, no primaryContainer fill): the Hebrew parsha name in FRL 600 20 primary, titleMedium "This week: Parshat Bereshit", bodySmall "Open the discussion", and a chevron.
- Sign-in: one PaperRow with `info_outline`, text, and a trailing TextButton "Sign in".
- GroupHeader "Forums", then one PaperGroup: icons in onSurfaceVariant, titles titleMedium, descriptions bodySmall (2 lines).

**Forum**
- The description in bodyMedium onSurfaceVariant.
- Thread rows in one PaperGroup: title titleMedium with `autoDirection`; bodySmall "Rivka · 3 hours ago · 4 replies".
- Empty state per §6.22 with `emptyForum`.
- FAB: extended "New discussion", primaryContainer / onPrimaryContainer, radius 12, elevation 2.

**Thread**
- App bar title gets `textDirection: autoDirection(t.title)` plus `overflow: ellipsis` (fixes D13 at thread_screen.dart:102).
- headlineSmall title with `autoDirection` (existing), then "2 posts" in bodySmall.
- Posts as letters (§6.21).
- Composer docked on surface with a top hairline: a radius-10 outlined field (max 5 lines) and a Filled "Reply" 48 high, disabled until there is text.

**Compose**
- App bar: leading close, trailing Filled "Post" (height 40, radius 10, disabled per M3).
- Fields in a paper group.
- The guidelines line as bodySmall with an inline TextButton.

**Account**
- Centred, max width 440. The app mark at 56, headlineSmall title, explanation in marginalia.
- Email field, then Filled "Email me a code" (the existing label, used by tests).
- Code boxes per §6.7.

### Settings (settings_screen.dart and screens/)

**Top level:** three PaperGroups with GroupHeaders.
- **Practice:** Reading & customs; Reminders; the "Show streak numbers" switch row.
- **Reading:** Display; Accessibility.
- **You:** Account & community; Your data; Language. Language is ONE row whose value is Device / English / עברית; it opens a sheet with RadioGroup rows and replaces the three inline radios.
- **About:**
  - "How it works": the guide, `guideTitle` value changed (§10);
  - "About this app": `settingsAbout` value changed.
  - This resolves D15.

**Display**
- The preview becomes a paper "page" showing a chapter head, two verses, a Targum line and a setumah mark. It reflects settings live and is pinned at the top: `SliverPersistentHeader`, collapsing 220 → 140.
- A Match-device switch, then theme swatches (§6.24).
- Sliders per §6.8.
- Toggles in PaperGroups:
  - Text: nikud, ta'amim, ketiv, verse numbers, justify;
  - Study aids: English, Rashi, Rashi script (NEW);
  - Reading: focus mode, bold, keep screen on.
- Line width as a SegmentedButton.

**Reading & customs**
- Radio groups inside PaperGroups with 56/72 rows.
- Source citations, e.g. "(Shulchan Aruch OC 285:2)", in marginalia at 17/24.

**Accessibility**
- Quick setups as a 2×2 grid of cards 88 high, radius 12: icon 24 in primary, titleSmall, one bodySmall line.
- Reset display as a TextButton.
- The remaining rows in PaperGroups.

**Reminders**
- Native: rows per type.
- The Shabbat note is a NoticeBanner with candles: "Never on Shabbat or Yom Tov, and at most once a day."
- Web: one NoticeBanner explaining that reminders need the installed app (replaces two stacked banners).

**Your data**
- Group 1: Export, Import.
- Group 2: "Reset all progress" in error-coloured text with no icon tile. The confirm dialog uses the destructive Filled button.

### Onboarding (onboarding_screen.dart; phone_welcome, he_welcome, dark_welcome, desktop_welcome)

**Welcome**
- At the top end: a SegmentedButton English / עברית. The selected segment is the EFFECTIVE locale even when language = system (fixes the unselected toggle in phone_welcome.png).
- The block is vertically centred in the available height, max width 520.
- TitlePageFrame (padding 32) containing:
  - an 8 px lozenge;
  - "שְׁנַיִם מִקְרָא / וְאֶחָד תַּרְגּוּם" in hebrewDisplay 40/60 primary (two lines);
  - a SeferDivider;
  - English UI only: "Shnayim Mikra v'Echad Targum" in EBG MediumItalic 24/30;
  - body in bodyLarge onSurfaceVariant.
- Outside the frame: 24 gap, a Filled "Start this week's parsha" 52 high (max width 400), then the disclaimer in bodySmall.

**Steps 2–4**
- At the top: four 12 px lozenges (filled = done, outlined = pending). Semantics still announce "Step 2 of 4".
- The question in headlineSmall.
- Options as paper radio cards: min 72 high, radius 12; selected = 2 px primary border plus primaryContainer fill, with RadioGroup semantics.
- The honor statement as marginalia inside a NoticeBanner.
- Button labels stay as now ("Continue", "Start reading").

### About, Guide, Sources, Privacy (about_screen.dart, guide_screen.dart, sources_screen.dart, legal_screen.dart)

**About header**
- The app mark at 72, then "שניים מקרא ואחד תרגום" in hebrewDisplay 28/40 primary.
- English UI: "Shnayim Mikra v'Echad Targum" in EBG 500 20.
- Version in labelSmall, then a SeferDivider.
- TitlePageFrame at ≥600 only.
- Link rows in one PaperGroup.

**Guide, Sources, Privacy**
- longformBody, max width 620.
- Headings in longformHeading, onSurface (not blue).
- SeferDivider between major sections; source lines in marginalia.
- The closing "Customs vary…" as a NoticeBanner.

## 10. Copy and l10n (app_en.arb / app_he.arb; the build fails on missing keys)

**New keys**

| Key | English | Hebrew |
|---|---|---|
| parshatHashavua | Parshat HaShavua | פרשת השבוע |
| erevShabbat | Erev Shabbat | ערב שבת |
| startAt | Start · {aliyah} | התחלה · {aliyah} |
| continueAt | Continue · {aliyah} | המשך · {aliyah} |
| continueAtPass | Continue · {aliyah}, {pass} | המשך · {aliyah}, {pass} |
| allAliyot | All aliyot | כל העליות |
| readAliyah | Read {aliyah} | לקריאת {aliyah} |
| streakBeginsWith | Begins with {name} | יתחיל בפרשת {name} |
| daysBeginToday | Begins with today's reading | יתחיל בקריאה של היום |
| finishStep | Finish | סיום |
| shabbatShalom | Shabbat Shalom | שבת שלום |
| chagSameach | Chag Sameach | חג שמח |
| restDayBody | Reading from a printed chumash today? You can log it after Shabbat. | קוראים היום מתוך חומש? אפשר לסמן זאת אחרי השבת. |
| restDayBodyChag | Reading from a printed chumash today? You can log it after Yom Tov. | קוראים היום מתוך חומש? אפשר לסמן זאת אחרי החג. |
| aboutStreaks | About streaks | על הרצפים |
| graceAvailable | plural: 1 grace day available / {count} grace days available | plural: יום חסד אחד זמין / {count} ימי חסד זמינים |
| thisYear | This year | השנה |
| parshiyotOfYear | {done} of {total} parshiyot | {done} מתוך {total} פרשות |
| recordTitle | Finished so far | הושלם עד כה |
| demoTag | Demo | הדגמה |
| emptyForum | No discussions yet — begin the first. | עדיין אין דיונים — אפשר לפתוח את הראשון. |
| passTrackLabel | {n} · {name} | {n} · {name} |
| aliyahTabLabel | {name}, aliyah {n} of 7 | {name}, עלייה {n} מתוך 7 |
| tabRead / tabPartial / tabNotStarted | read / {done} of 3 readings done / not started | נקראה / {done} מתוך 3 קריאות / טרם התחילה |
| uiFontSystem | Device font | גופן המכשיר |
| rashiScript | Rashi script | כתב רש״י |

**Changed values**
- `todayBehind`:
  - English: "{count, plural, =1{One aliyah to catch up — very normal midweek.} other{{count} aliyot to catch up — very normal midweek.}}"
  - Hebrew: "{count, plural, =1{עוד עלייה אחת להשלים — רגיל לגמרי באמצע השבוע.} other{עוד {count} עליות להשלים — רגיל לגמרי באמצע השבוע.}}"
- `guideTitle`: "How it works" / "איך זה עובד".
- `settingsAbout`: "About this app" / "אודות האפליקציה".

The literal "חֲזַק חֲזַק וְנִתְחַזֵּק" is not translated.

## 11. Tests and QA

1. **`test/ui/palette_contrast_test.dart`** (pure Dart, imports palette.dart):
   - asserts every pair in §3.5 meets 4.5 (text) or 3.0 (UI) in light, dark and sepia;
   - asserts 7.0 (text) and 4.5 (UI) in both high-contrast themes;
   - asserts that no ColorScheme role equals a `fromSeed` default.
2. **`test/accessibility/screens_a11y_test.dart`** (and `text_contrast_test.dart` for contrast):
   - run `textContrastGuideline` for /today, the reader, /parsha, /progress, /community and /settings/display in all five themes;
   - add 200%-text-scale overflow tests for the Hebrew locale on /today, /progress and the reader;
   - add a focus-traversal test asserting that a focused FilledButton paints `FocusRingBorder`.
3. **Font loading for widget tests:** add `loadBundledFonts()` to test/helpers.dart. It reads FontManifest.json and runs `FontLoader` for each family. Pixel-sampled contrast checks (`textContrastGuideline`) stay on the test font: with real glyphs, anti-aliased edge pixels can outnumber the text colour (test/accessibility/text_contrast_test.dart).
4. **Goldens** (`matchesGoldenFile`): Today, Reader guided, Parsha, Progress and Community × 5 themes × {en, he}. Plus the mixed headings "Revi'i · רביעי" and "בְּרֵאשִׁית" in titleLarge and hebrewDisplay (catches fallback tofu).
5. **Update tests that depend on removed visuals:**
   - reader_widget_test.dart:39 expects 'Targum Onkelos' (the removed LayerLabel). Change it to expect the PassTrack label '3 · Targum'.
   - All other existing finders keep working: 'Read the Hebrew', 'Verse 1 of 14', 'Next', 'Chapter 6', 'Mark this aliyah as read', 'Email me a code', 'Start this week's parsha', and 'Parshat' via the eyebrow.
6. **Manual checks:**
   - an icon check at 48 and 1024 px on a device;
   - TalkBack and VoiceOver passes on the ribbon and PassTrack;
   - Windows Contrast Themes;
   - a review of every he_* screen for mirrored chevrons, start rules, pip order and ribbon underline.

## 12. Build order (each step leaves both locales and all five themes coherent and the a11y suite green)

1. **Tokens and type foundation:**
   - palette.dart, SeferColors, StatusColors.overdue;
   - the font build plus pubspec and licenses; typography.dart and SeferType;
   - app.dart `hebrewUi`; UiFont standard/system;
   - focus.dart applied in every component theme;
   - the component themes in §6.2–6.10 and 6.19;
   - the palette contrast test.
   - This fixes D2, D3, D4, D14, D16 and D17 and most of the "seeded" look on its own.
2. **App icon regeneration** (D1).
3. **Shared widgets:** ornaments, PaperGroup, LedgerCard, NoticeBanner and demo notice, rings and legend, WeekStrip, YearBar, map tiles (D6, D8).
4. **Today, Parsha/Week and Browse** (D10).
5. **Reader:** ribbon, PassTrack, typesetting, dimInk, bottom bar, finished panel, haftarah (D5, D7, D12).
6. **Progress** with Record (D9).
7. **Community** (D13).
8. **Settings, onboarding and About/Guide/legal** (D15).
9. **Desktop layout pass** (titleSpacing, Today two columns; D11), motion polish and goldens.

## 13. Risks and mitigations

1. **Cross-script fallback.** A single TextStyle relies on `fontFamilyFallback` for mixed Latin and Hebrew, and for nikud on fallback letters. The fallback lists in §4.2 are mandatory; goldens (§11.4) guard them on CanvasKit, Android, iOS and Windows.
2. **Variable fonts.** Never drive the wght axis; ship the static instances. A missing weight silently snaps to the nearest one, which is the current w600 → Bold bug.
3. **EB Garamond x-height (0.40 em).** The floors in §4.5 are mandatory. Test the ribbon and two-line map tiles at 200% text scale.
4. **Bundle size and web start-up.** About 571 KB is loaded eagerly; Rashi is lazy. Subset exactly as in §4.1. Add `<link rel="preload" as="fetch" crossorigin>` in web/index.html for EBGaramond-Medium and FrankRuhlLibre-Medium. The engine reads fonts with `fetch()`, so `as="font"` would not match and the files would download twice.
5. **User-chosen fonts must win.** Every serif role maps to Atkinson, Lexend or OpenDyslexic when one is selected (§4.5).
6. **Departing from M3 defaults.** Every ColorScheme role is explicit (§3.2) so stock widgets don't pull seeded lavender. Button `animationDuration` is zero for the focus ring.
7. **High-contrast dark primary.** It moves from yellow to light techelet (13.24:1, AAA) to keep one meaning per colour across themes. Gold-yellow #FFD970 remains for the rubric. Collect feedback from low-vision testers.
8. **Tone.** Completion moments happen once and are silent. No counters on ornaments and no "unlock" language. Review against DESIGN.md principles 1 and 5.
9. **Shabbat and Yom Tov state.** It is informational only, with no reading prompt. Its copy goes to the rabbinic advisor.
10. **Icon change visibility.** Ship it before the first public release. Store screenshots and goldens will change.
