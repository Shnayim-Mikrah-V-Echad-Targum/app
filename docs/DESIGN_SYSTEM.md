# Shnayim Mikrah: "Klaf & Techelet" design system v1 (final, for implementation)

> Reference mockups: [mock_today.png](design/mock_today.png), [mock_reader.png](design/mock_reader.png). They predate the spelling Mikrah and later changes, so the captures are the current record. Render the current app with `CAPTURE=1 flutter test test/screens/capture_test.dart` (PNGs in build/screens/) to compare.


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
6. The hero CTA goes to `WeekContext.nextAliyah` (Shlishi in the scenario), not Revi’i.
7. The icon uses a font size of 300 px. The letters are then 177 px tall and 744 px wide.
8. The English UI keeps the transliterated Hebrew date ("28 Tishrei 5787"). Only the Hebrew UI uses Hebrew numerals.

## 1. Defects this spec fixes (evidence)

| # | Defect | Evidence |
|---|---|---|
| D1 | The app icon text is reversed. ש is the leftmost glyph, so it reads "ת״ומש". | assets/branding/icon.png (also icon_foreground.png and icon_monochrome.png); crop at scratchpad/icon_left.png |
| D2 | Seeded palette: lavender cards on cream, a mauve Targum ring and a pink demo banner. | app_theme.dart:92-146; progress_widgets.dart:55; community_ui.dart:145; reader_screen.dart:747; phone_today.png, phone_community.png |
| D3 | The focus ring is invisible on FilledButton (primary ring on primary fill). | app_theme.dart:171, 217-222 |
| D4 | Buttons request w600, but only 400/500/700 are bundled, so labels render Bold. | app_theme.dart:221; pubspec.yaml:82-95 |
| D5 | The reader's ChoiceChip shows a check on the selected, unread Revi’i. Shlishi (2 of 3 passes) shows nothing. | reader_screen.dart:536-541; phone_reader.png |
| D6 | Mikrah 2 ring = primary at 80% alpha, which can't be told apart from Mikrah 1. | progress_widgets.dart:55 |
| D7 | Focus-mode dimmed verses use 55% alpha: 3.82:1, which fails AA. | scripture_text.dart:114, 118, 129, 223 |
| D8 | Torah map: "late" tiles are white text on 70%-alpha primary. "Missed" and "upcoming" differ only by border colour. | progress_screen.dart:274-281 |
| D9 | Trophy and lock milestones, and party-popper icons. | progress_screen.dart:366; today_screen.dart:181; reader_screen.dart:850; notification_prompt.dart:20 |
| D10 | Today has competing CTAs, an outlined "2 of 7 aliyot" that looks like a button, and "0 weeks" in bold. | today_screen.dart:187-196, 251-255, 321; phone_today.png |
| D11 | Desktop: the title sits at x=273 while content starts at x=448. Reader Back and Next are 1,240 px apart and the chips sit flush left. The rail shows "SM". | desktop_today.png; desktop_reader.png; shell.dart:58-66 |
| D12 | The reader stacks three layers of chrome above the verse. | phone_reader.png |
| D13 | Hebrew UI: an English thread title is cut at the wrong end, and the post header mixes directions in one string. | thread_screen.dart:102; he_thread.png |
| D14 | On native platforms the UI uses the platform font, so the brand changes per OS. | app_theme.dart:158 |
| D15 | Settings has both "About Shnayim Mikrah" (the guide) and "About". | settings_screen.dart:51-52 |
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
- `lib/ui/theme/focus.dart`: `FocusRingBorder`, `SeferInkWell` and the rings of navigation destinations, menu items and list tiles.
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
- `lib/ui/theme/layout.dart`: the layout tokens of §5 (`Space`, `Breakpoints`, `Gutter`, `ContentWidth`, `Rhythm`).
- `lib/ui/widgets/page_columns.dart`: `PageColumns`, the two columns of a page on a desktop (Today, Progress, a week's page; §9).
- `lib/ui/widgets/common.dart`:
  - `PageBody` defaults become maxWidth 720 and padding `fromLTRB(g, 8, g, 40)`, where g is the gutter from §5, plus the safe area below, so a page over the whole screen clears the gesture bar;
  - `PageScaffold`, the scaffold of every routed page, and `DocumentTitle` (§5);
  - `SectionHeader` is restyled as an eyebrow (§6.4);
  - `NoticeBanner` per §6.20;
  - `EmptyState` per §6.22.
- `lib/features/reader/aliyah_ribbon.dart`, `pass_track.dart` and `reader_bottom_bar.dart`: extracted from reader_screen.dart.
- `tool/fonts/build_fonts.sh` (§4.1) and `tool/branding/make_icon.py` (§7.8).
- `test/ui/palette_contrast_test.dart` (§11).

## 3. Colour

### 3.1 Rules

1. **Techelet (`primary`)** is used for:
   - buttons, links, the selected tab and indicators;
   - Mikrah progress and the focus ring;
   - the Hebrew display title of a parsha (the Today hero, the Parsha header and Welcome/About).
   It is used for no other text: no section headers, chapter heads or verse numbers.
2. **Gold ink (`secondary`)** is the rubric colour: eyebrows, verse numbers, chapter heads, petuchah/setumah marks, the Targum pass, overdue state and rest days. Gold is never used for buttons.
3. **goldLeaf** is decorative only: frame rules, lozenges, the Targum rule in full-text mode. It never carries information. In high contrast it becomes solid `secondary`, or is removed where noted.
4. **Hyssop green (`tertiary`)** is only for grace.
5. **Missed** is always `neutral` plus a dash glyph. Never red. `error` is only for validation and destruction: form validation, destructive confirmations, and a deletion's row or Text button (§6.3, §6.5).
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
| ringMikrah1 | #1D3F75 | #AFC6EE | #25406C | #0A2A5E | #B5CEFF |
| ringMikrah2 | #55779F | #7E9BC8 | #4F6B92 | #3D629C | #7A9FE8 |
| ringTargum | #946C1E | #C9A458 | #8A651C | #4F3500 | #FFD970 |
| ringTrack | #E8E1D3 | #36312A | #E0D3B4 | #E0E0E0 | #333333 |
| yearTrack (the year bar's open segments, §6.15) | = outlineVariant | = outlineVariant | = outlineVariant | #949494 | #5C5C5C |
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
| onSurface / secondaryContainer (the verse opened at) | 14.07 | 8.85 | 11.49 | 18.50 | 13.21 |
| onSurfaceVariant / secondaryContainer (its Targum and translation) | 6.47 | 5.73 | 6.74 | 14.52 | 11.08 |
| secondary / secondaryContainer (its verse numbers, and the rule) | 5.34 | 5.88 | 5.77 | 10.04 | 9.70 |
| primary / secondaryContainer (its note marks) | 8.46 | 6.36 | 7.54 | 12.28 | 8.33 |
| tertiary (grace) / paper | 6.24 | 9.89 | 6.32 | 10.84 | 13.67 |
| onLate / late (map tile) | 5.49 | 5.32 | 6.20 | 8.20 | 9.64 |
| late / paper | 5.40 | 6.09 | 5.61 | 8.20 | 9.64 |
| error / surface | 7.13 | 10.95 | 6.95 | 9.93 | 12.37 |
| onInverseSurface / inverseSurface (snackbar) | 12.55 | 13.91 | 10.82 | 21.00 | 21.00 |
| inversePrimary / inverseSurface (snackbar action) | 8.32 | 8.36 | 7.57 | 13.24 | 13.95 |
| outline / surface (UI boundaries) | 3.89 | 5.36 | 3.96 | 21.00 | 21.00 |
| outline / paper (also the slider's inactive track and the sheet's drag handle) | 4.09 | 5.02 | 4.32 | 21.00 | 21.00 |
| outline / surfaceContainer | 3.41 | 4.70 | 3.48 | 18.76 | 19.17 |
| neutral / paper (missed glyph) | 4.53 | 5.27 | 4.60 | 8.45 | 11.18 |
| focus / surface (ring) | 9.72 | 10.80 | 8.58 | 21.00 | 21.00 |
| ringMikrah1 / paper | 10.23 | 10.12 | 9.36 | 13.95 | 13.24 |
| ringMikrah2 / paper | 4.56 | 6.18 | 4.93 | 6.13 | 7.95 |
| ringTargum / paper | 4.67 | 7.45 | 4.80 | 11.40 | 15.41 |
| ringMikrah2 / ringTrack | 3.57 | 4.55 | 3.67 | 4.64 | 4.78 |
| ringTargum / ringTrack | 3.65 | 5.48 | 3.57 | 8.64 | 9.27 |
| yearTrack / paper (an open segment; at least 3:1 in high contrast, tested) | 1.52 | 1.82 | 1.74 | 3.03 | 3.14 |
| yearTrack / done (open against finished; at least 4:1 in high contrast, tested) | 6.73 | 5.57 | 5.38 | 4.60 | 4.22 |
| goldLeaf / surface (decorative only, exempt) | 2.89 | 6.62 | 2.85 | 11.40 | 15.41 |
| hairline / paper (decorative only, exempt; HC uses 2 px outline) | 1.52 | 1.82 | 1.74 | 21.00 | 21.00 |

Notes:
- The current app's 55% alpha dimming measures 3.82:1 in light; `dimInk` replaces it.
- Dimmed verses (5.1:1 or more) are below the 7:1 scripture target on purpose. They are not the verse being read, and focus mode is opt-in.
- ringMikrah1 and ringMikrah2 are both techelet, told apart by shade: 2.24, 1.64, 1.90, 2.28 and 1.66:1 between them. Each high-contrast theme sets them at least as far apart as the theme it heightens (tested), and its RingLegend also keys each row by the ring's position (§6.11).

### 3.6 Platform colours

- `web/manifest.json`: theme_color #1D3F75, background_color #FAF7F0.
- `web/index.html`: `<meta name="theme-color" content="#1D3F75" class="boot-theme">` until the first frame, when it is removed and the app's surface takes over (`MaterialApp.color`, and the status bar's colour on the web). The loading screen before it has the saved theme's surface as its background (#FAF7F0 by default), with the mark and a 3 px bar in primary on ringTrack, and fades away over the first frame (§8).
- `pubspec.yaml` flutter_launcher_icons:
  - `adaptive_icon_background: "#1D3F75"`;
  - web `background_color: "#FAF7F0"`, `theme_color: "#1D3F75"`;
  - `remove_alpha_ios: true`.
- Android reminders: the status-bar glyph (§7.8) tinted primary #1D3F75 (`Palettes.light.primary`).
- Launch screens (`pubspec.yaml` flutter_native_splash, Android and iOS): `color: "#FAF7F0"`, `color_dark: "#14120F"`, the same on Android 12 and later, with the mark's tile (§7.8) and no icon background. Android's window background behind the app (`NormalTheme`) is `@color/app_bg`, the same two surfaces, so in the Light and Dark themes nothing changes colour between the launch screen and the first frame. From Android 12 the launch screen takes the theme's brightness even where it differs from the system's, so there is no light flash before a dark theme, nor the reverse: Light and Dark match it exactly, and Sepia (#F3E9D2), high contrast light (#FFFFFF) and high contrast dark (#000000) open on the nearest launch surface, cream or lamplight brown, which is accepted. On Android the app holds the system's night mode for itself to its theme (`lib/app/android_night_mode.dart`, `setApplicationNightMode` in MainActivity), on for Dark and high contrast dark, off for Light, Sepia and high contrast light, and the system's own while it follows the system, and Android 12 and later draw the launch screen of a cold start in it. Android then reports the theme's brightness as the device's, so the app takes the device's only to follow it, and the quick setups (§9) are as dark as the theme in use. iOS and Android 11 and earlier show the system's launch screen, which is accepted.
- System bars: edge to edge and transparent, with dark icons over the light, sepia and high-contrast light themes and light icons over the dark ones; no contrast scrim (`lib/app/system_bars.dart`, and the launch themes in `android/app/src/main/res/values*/styles.xml`). Where the app can't run beneath Android's navigation bar (Android 9 and earlier), the bar is painted the colour of what lies just above it: `surfaceContainer` below the phone's navigation bar (§6.9), which wraps itself in its own `SystemBars`, and `surface` elsewhere. A theme can give that bar dark icons only from Android 8.1, so before then the light launch theme leaves it black.

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
- The opt-in fonts (Taamey Frank CLM, Ezra SIL, Atkinson Hyperlegible Next, Lexend and OpenDyslexic, about 874 KB) are plain assets in `assets/fonts/optional/` too, registered by `OptionalFonts` (lib/services/optional_fonts.dart): the chosen ones before the first frame, and any other when it is chosen (each family's files requested at once, and one that failed tried again as the app resumes). The theme switches to a chosen interface font only once it has loaded, so nothing is drawn or measured in a stand-in; and what measures text while building (the navigation bar's labels, the week strip and legend, the Torah map) depends on `FontsChangeScope`, so it measures again when a font arrives.
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
- Never request a weight that isn't bundled. EBG and FRL: 500, 600, 700. NS and NSH: 400, 500, 700. Never w600 on NS or NSH. Accessibility fonts: 400 and 700, except that in the Hebrew UI their 500 roles keep 500: the Hebrew is drawn by the fallback, Noto Sans Hebrew, in its Medium, and a Latin word falls to the font's 400.

### 4.3 Text theme: English UI

| Role | Family | Size / line height | Weight | Letter spacing | Use |
|---|---|---|---|---|---|
| displayLarge | EBG | 44/52 | 500 | -0.25 | Sefer-complete panel |
| displayMedium | EBG | 38/46 | 500 | -0.2 | (reserved) |
| displaySmall | EBG | 32/40 | 500 | 0 | Finished-panel title ≥600 dp, the rest-day greeting |
| headlineLarge | EBG | 30/38 | 500 | 0 | Latin parsha name in the Today hero |
| headlineMedium | EBG | 28/36 | 500 | 0 | Masthead, Parsha header Latin name, finished panel |
| headlineSmall | EBG | 24/30 | 500 | 0 | Card titles, thread title, onboarding questions, the rest-day hero's Latin parsha name |
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
- **Whole words.** A word of the interface never breaks across lines. Where the largest text sizes leave a word too wide for its room (an eyebrow, a row's title, subtitle and detail line, a notice, a line of marginalia, a ledger column, a day of the week strip, an aliyah's row on a week's page, a book's heading on the Torah map, the reader's Back and Next, the masthead), it is set just small enough to fit (`WholeWords`, lib/ui/widgets/lines.dart; `WholeWords.rich` for a paragraph in more than one style, and `BalancedText` and `DotLine` keep their lines' words whole too). Words that may be of any length, as a member's name and email address on the account page or a discussion's title, are set no smaller than labelSmall's 12 (`WholeWords.minFontSize`, `WholeWords.smallestSize`), and one too long even so wraps at that size. In a sentence a line may still end after a hyphen; a name of two parshiyot ("Matot-Masei") stays whole, measured as one word and set with a word joiner after its hyphen, so that a line never ends there even among other words ("Acharei" over "Mot-Kedoshim"). An eyebrow or a row's title that names a parsha says so (`Eyebrow.breakAtHyphens`, `PaperRow.breakTitleAtHyphens`: the haftarah page's eyebrow, Progress's weeks to make up), as do the parsha's name on Today's and a week's title page and a week's row on Progress. Browse keeps each parsha's names whole as a name of two is kept, a maqaf's too ("לך־לך"). A spaced en dash, as in a run of aliyot ("Shlishi – Shevi’i") or a Hebrew range across chapters ("א, א – ו, ח", §4.6), is held to the word before it by a no-break space, so that no line starts with it.
- **Serif numbers** always use `FontFeature.liningFigures()` and `tabularFigures()`.
- **Accessibility-font override:** when `uiFont` is atkinson, lexend or openDyslexic, every EBG/FRL role uses that family at the same size:
  - display, headline and title at w700;
  - eyebrow 13/16 w700, letter spacing 0.8, with `toUpperCase()` applied only when `!hebrewUi` and the string has no Hebrew;
  - marginalia 16/24 w400 upright;
  - longformBody 18/30 w400;
  - ledgerNumeral and ringNumeral w700 with tabular figures;
  - hebrewDisplay is NOT overridden: Hebrew titles stay FRL, because those fonts have no Hebrew.
- **UiFont.system** changes only the NS/NSH roles, and only their Latin: the family is left to the platform, with fallback `['NotoSansHebrew', 'NotoSerifHebrew']` in both UIs, so Hebrew and nikud still come from the bundled fonts (§13.1). Segoe UI, which has Hebrew of its own, draws the Hebrew on Windows.
- **High contrast:**
  - EBG roles use w600 (w700 when bold text is on); FRL roles use w700;
  - eyebrow w700;
  - marginalia becomes upright EBG 19/28 w600.

### 4.6 Numerals and bidi

- Counts use Latin digits in both locales, with tabular figures.
- Hebrew numerals (גימטריה) are used for:
  - verse numbers, chapter heads and aliyah ordinals (א–ז);
  - Hebrew dates in the Hebrew UI.
- A reference in the Hebrew UI gives its chapter and verse in Hebrew numerals, joined by a comma: "בראשית כח, י" (`Names.reference`). A range within a chapter closes its dash up, "ב, כ–כא"; one across chapters spaces it, "בראשית א, א – ו, ח" (`Names.verseRange`), since "א, א–ו, ח" would read as chapter 1, verses 1–6 and 8. No-break spaces hold each chapter to its verse, in a single reference and in a range, as "1:1" holds together, and a range's spaced dash to the verse before it, so that a line breaks only after the book or the dash ("בראשית / כח, י", "בראשית / א, א – ו, ח"), and none starts with the dash. Go to verse reads a reference copied from the app as it is written. English ranges stay closed: "Genesis 1:1–6:8".
- Dates of the practice (Shabbat, a pause, when a parsha opens or closes) are Hebrew dates in the Hebrew UI, without the year, so that one card never dates the same Shabbat in two calendars: in a sentence `Names.practiceDate`, "Paused until Sunday, October 18." / "בהשהיה עד יום ראשון, ז׳ בחשון."; after a word that names the day `Names.practiceDayMonth`, "Read on Shabbat, October 10" / "תאריך הקריאה: שבת, כ״ט בתשרי"; and in a list or on a chip `Names.practiceDateShort`, "Oct 10" / "כ״ט בתשרי" (with the year for a week of another year, a Hebrew year in the Hebrew UI). The civil date stays Gregorian: the Today running head's second calendar, the week header's second date, backup and import dates, forum timestamps and milestones.
- A long date inside a sentence is held together (`Names.dateInText`, and `Names.practiceDate`, which is built on it): it wraps after its weekday's comma or not at all, never between a day and its month ("October / 18", "ז׳ / בחשון").
- Add `String ltr(String s) => '⁦$s⁩'` in `lib/ui/l10n.dart`. Wrap every Latin-digit run that is interpolated into a Hebrew string with it: references "3:22–4:18", "2/7", times and counts. In Hebrew UI layouts, author names in post headers also go in their own Text widget (§9 Thread).

### 4.7 Scripture (`ScriptureStyles` and `ScriptureVerse`, lib/features/reader/scripture_text.dart)

**Mikrah**
- Family, 26sp × readingScale, `height = settings.lineHeight` (default 1.9, minimum 1.6) and the bold rules are unchanged.
- Add a `StrutStyle(fontFamily: scriptureFamily, fontSize: size, height: lineHeight, leadingDistribution: even, forceStrutHeight: false)`, so a verse-number span in another family never changes the line pitch.
- Colour `onSurface`.

**Targum**
- 0.90× (was 0.92×), `onSurfaceVariant`, height `max(1.6, lineHeight - 0.1)`.
- In full-text mode, add a 2 px `goldLeaf` rule at the scripture's start, the right in either language of the app, with 12 px padding. Remove the rule in high contrast. The guided reader's block for a verse read a third time among the Targum is ruled at the right too (3 px `outline`), where the Hebrew begins.

**Line breaks**
- A paseq is bound to the word before it by a no-break space, and a maqaf to the word after it by a word joiner (`keepLinesSound`), wherever the words it joins fit on a line together. Where they don't, at a very large reading or text size on a phone, that maqaf goes without its joiner (`joinWhereFits`, measured against the column by `JoinsThatFit`), so the line ends after it rather than inside a word; words joined one after another stay together as far as they fit, as many to a line as fit. Only a word wider than the column on its own breaks.

**Verse numbers**
- FRL 600 at 0.55× of the verse size, colour `secondary` (`dimInk` when dimmed).
- Follow the number with U+00A0 NO-BREAK SPACE instead of a plain space, so a number is never stranded at the end of a line. The space is the verse's own and carries the reader's word spacing as letter spacing (the text engine widens only spaces a line may break at), so the number stands a word's space from its word however wide the spacing.
- Guided mode only: the number hangs in a start gutter 1.4 × verse size wide. Use `Row(textDirection: rtl, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic)` with the number Text, then `Expanded` verse Text. What goes with the verse (its translation, Rashi, notes and layer labels) is set in by the same gutter at the right (`HangingIndent`), so every block shares the edge the text starts at and the number alone stands in the margin. Where the gutter would take more than a quarter of the line, or numbers are hidden, there is none.
- Full-text mode keeps the number inline.

**Chapter heading**
- Centred "פרק ג" in FRL 600 at `20 × sqrt(readingScale)`, colour `secondary`.
- Flanked by 32 px hairlines with a 12 px gap.
- English UI only: below it, "Chapter 3" (existing `chapterLabel`, not uppercased) in labelMedium `onSurfaceVariant`.
- 16 px above, 8 px below. This replaces the start-aligned "Chapter 3" label (phone_reader_full.png).
- In a week of two parshiyot read together, the verse the second begins at is headed by its name, set the same way (`ChapterHeading.book`): the pointed Hebrew name in gold ("פְקוּדֵי" over 38:21) and, in the English UI, its name beneath ("Pekudei"); in the guided reader, at each step that shows the verse. One heading to a screen reader, named in the UI's language, at the level of the chapters' headings around it, and above the chapter's own head where it begins one.

**Petuchah / setumah**
- `SectionBreakMark` (§7.3) replaces the grey letter in reader_screen.dart full-text rendering.
- Vertical space: petuchah 20 px above and below; setumah 10 px.
- The full text's last verse takes none: the aliyah's SeferDivider follows it and marks the end, and two ornaments on one break would crowd it.
- The guided reader marks them under the steps that read the Hebrew, never the Targum's or Rashi's.

**Other text**
- Ketiv and alternate readings: 0.62×, `onSurfaceVariant`, as now (dimmed: `dimInk`).
- Large letters (the bet of Bereshit): 1.45× the verse, with a line height that sets their top no higher above the baseline than the verse's own line box, so they stand above the line, as in print, and move no line apart.
- Rashi: Noto Serif Hebrew 0.78×, height 1.7, `onSurfaceVariant`.
  - New Display switch "Rashi script" (off by default) switches to NotoRashiHebrew 400 at 0.80×, height 1.75. The switch shows only while Rashi is shown (beside the Torah or as the second reading), and the script loads only then.
  - Dibbur hamatchil: FRL 700 in `onSurface` (never primary).
- English translation (study aid): EBG 500, 20sp × readingScale, height 1.5, `onSurfaceVariant`.
  - Verse number EBG 600 in `secondary` with lining figures.
  - If `uiFont` is not standard or system, use uiFont at 17/26.

**Focus mode**
- The current verse's whole block (Mikrah, Targum, translation and Rashi, one tap target, `VerseGroup`) gets `BoxDecoration(color: verseHighlight, border: BorderDirectional(start: BorderSide(color: primary, width: 3)))`, faded in over `Motion.short`. No radius: Flutter forbids a radius with non-uniform borders.
- Padding, on every block whether highlighted or not, so that focus mode never moves a line: start 12 (the rule's 3 included), end 12, so the highlight frames a line that runs the full measure (the translation, or justified text), and vertical 4.
- Start here, as for the Targum's rule, is the scripture's start: the right, in either language of the app.
- All other verses, including their numbers, ketiv, Rashi and Rashi's eyebrow, use `dimInk`, and the Targum's gold rule recedes to the hairline colour, leaving the gold to the verse being read. Delete every `withValues(alpha: 0.55)` in scripture_text.dart.

**The verse opened at** (`TargetVerseMark`, lib/features/reader/verse_anchor.dart)
- A verse the reader opens at, from a search result, Go to verse (§6.26) or a link (`/read/{week}/{aliyah}?verse=28:12`), opens the full text and is scrolled to a fifth of the way down the text's viewport (`Scrollable.ensureVisible`, alignment 0.2, 300 ms on `Motion.standard`, at once under Reduce Motion).
- It is marked until the next tap on the text, another aliyah or a change of mode: its whole block (Mikrah, Targum, translation, Rashi) on a `secondaryContainer` wash, the gold wash search marks matches with, with radius 8, painted 8 px past the text at each side and 4 above and below, so nothing moves when it goes; and a 3 px `secondary` rule at its right edge, where the verse and its number begin, clipped to the wash's corners. The rule is the cue in high contrast, where the wash is close to the paper. Scripture on the wash keeps 7:1 in every theme (§3.5).
- It is not focus mode's verse and shows with focus mode off. With focus mode on, it is also the focused verse, so the others dim around it, and focus mode's own highlight yields to the mark.
- Where the platform takes announcements, its reference is said once the scroll ends ("Genesis 28:12").

**The verse Listen reads** (§6.28)
- Has focus mode's highlight, whether focus mode is on or not: in the full text, its block's own (`VerseGroup`); in the guided reader and the haftarah, where verses have no blocks, the same paper and 3 px primary rule painted around the verse and what goes with it, 12 past it at the sides and 4 above and below (`SpeakingVerseMark`), so nothing moves as it passes on. Faded in over `Motion.short`.
- In focus mode it is the focused verse, so the others dim around it, never it.
- Brought into view as the voice reaches it, unless it is wholly in view already: a fifth of the way down the text's viewport, over `Motion.medium`, at once under Reduce Motion, and never under a finger scrolling the text (`FollowedVerse`).
- It replaces the mark of the verse opened at, which goes as Listen starts.

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
  - two-column container 1040 at ≥1200: Today, Progress and a week's page (`PageColumns`, §9), the app bar's title and actions on its edges.
- **Rhythm:** card padding 20 (16 under 360 dp); gap between cards 12; gap between sections 28; inside a card 12.
- **Radii:**
  - chips and map tiles 6–8;
  - buttons and inputs 10;
  - cards and paper groups 12;
  - dialogs 16;
  - sheets 20 (top only);
  - the nav indicator is the only stadium shape.
- **Elevation:** 0 everywhere. Separation comes from paper on surface plus a 1 px hairline. FAB and menus are 2, with `shadowColor` = shadow token.
- **App bar title alignment on wide screens:** `PageScaffold` reads the pane's width with a `LayoutBuilder` (the window less the rail and its hairline) and computes `inset = max(gutter, (paneWidth - contentMaxWidth) / 2 + gutter)`, where the column's content starts. The title is padded `inset` at its start, or `max(gutter, inset - 56)` after a back or home button, and a gutter at its end (as `titleSpacing` the inset would be kept after it too, leaving a narrow column's title no room on a wide screen), and `actionsPadding` ends `inset - gutter` from the pane's end, at the column's edge, as a phone's end at the screen's. This puts the title edge on the content edge, fixing D11. The title is a level-1 heading. Pages of list tiles pad the column `gutter - 16` at the sides (`PageBody.tilePadding`), so the tiles' own 16 brings their text to the same edge.
- **Floating button:** where the pane is wider than the page's column, a `PageScaffold`'s floating action button ends where the column's content does, beside its cards and under the app bar's actions, rather than in the pane's far corner. Where the column fills the pane, Material's 16 from the edge. It is extended, icon and label (`PageScaffold.floatingButton`), while it takes at most two thirds of the window's width and its label a line of at most 40 (8 clear of its top and bottom); at text large enough to break either (200% on a phone, 300% on a tablet), its icon alone, 56 square, with the label as its tooltip, which screen readers read too, rather than run off a 320 dp screen with its label clipped. The label is measured as set, in bold where the device asks for Bold text. Either way it is an extended button to the Scaffold, so it fades in as it appears (§8).
- **Document title:** on the web, the page on show names the browser's tab, its history and bookmarks: "Settings · Shnayim Mikrah" (`DocumentTitle`, which `PageScaffold` applies; the reader, Today and Welcome apply it themselves). A page names it again whenever it comes back into view, as the page over it closes or its tab is chosen again. Its colour is the app's (`MaterialApp.color`, the surface), since the web takes it for the theme-color (§3.6). Elsewhere the platform keeps the app's name.

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

Chips draw every border outside the chip (`strokeAlign: BorderSide.strokeAlignOutside`), so selecting or focusing one never resizes it. Their `shape` is a `WidgetStateOutlinedBorder` that resolves focused to `FocusRingBorder(borderRadius: 8, …)`, which starts its gap past an outside border. The selection border stays visible under focus, and in high contrast the ring is not confused with the 2 px outline. `SeferChoiceChip` also clears the chip's focus tint, which would read as a selection fill.

Icon buttons keep Material's circle; focused, they take a `FocusRingBorder` of radius 24. The slider rings its thumb the same way (`FocusRingSliderOverlay`), and the FAB takes the ring at its own radius, 12.

Controls pick the ring as they build, but Material rebuilds them only when their own states change, and a switch between touch and keyboard is not one of them. `FocusHighlightScope`, in `MaterialApp.builder`, records the highlight mode in the theme, so a control that keeps its focus shows or drops its ring the moment the user switches.

`SeferInkWell` is used for cards, PaperRows, week cells, map tiles and ribbon tabs:
- an InkWell with `onFocusChange`;
- when focused and `FocusManager.instance.highlightMode == FocusHighlightMode.traditional`, a foreground `ShapeDecoration(RoundedRectangleBorder(radius, side: BorderSide(color: focus, width: 3, strokeAlign: outside)))`;
- only for its own focus: `onFocusChange` also fires while a control inside it (a PaperRow's trailing menu or text button) has focus, and that control draws its own ring, so the row draws none.

Navigation destinations, menu items and list tiles have no shape a ring can go on, and Material marks their focus only with a wash in onSurface, under 3:1 (on the bar, darker than the selected indicator, so focus read as selection). Each draws the ring instead, and clears the wash. The rings below ask the focus manager for the highlight mode, as `SeferInkWell` does, since a popup menu keeps the theme it was opened with.
- **Bar and rail** (`IndicatorFocusRing`, around each destination's icon and selected icon): `FocusRingBorder`'s gap and ring around the indicator, 64×32 radius 16 on the bar and 56×32 radius 12 on the rail, centred on the icon, whether or not the destination is selected. Nothing between the icon and the bar clips it, nor the edges of the rail as it scrolls in a short window: each destination has room above its indicator for the ring (§6.10).
- **Popup menu items** (`SeferMenuItem`, a `PopupMenuItem` whose content is a `MenuItemFocusRing`): a 3 px ring in focus inside the item, 4 in from its edges, radius 8 (the menu's own edges are near). The content is laid out as Material's (12 in, centred in at least 48), so the item has no padding of its own, and kept 10 clear of the item's top and bottom, so that a label set on two lines by large text clears the ring.
- **List tiles** (`TileFocusRing`, around a ListTile or CheckboxListTile): a 3 px ring in focus, radius 8, 4 in from the tile's edges as a menu item's, clear of the edges (and the high-contrast outline) of a sheet the tile spans. A tile with no content padding, in a dialog, has its text and icons at its sides, so its ring stands 4 out from them instead, as high as the tile (`outside: true`), within the padding of a dialog that scrolls with it (`AlertDialog(scrollable: true)`). The only tile that still shows the wash is the haftarah page's ExpansionTile; the date sheet's rows are PaperRows (§9 Today), ringed by `SeferInkWell`, and the check-in's and the Chumash reading's sheets are ringed tiles until they too become paper rows (§6.19).

Text fields: focused border 2 px primary (was 3), 3 px in high contrast (§6.7). The ring appears instantly.

### 6.2 App bar

- Height 64; background surface; `surfaceTintColor` transparent; `scrolledUnderElevation: 0`, so never a shadow. When content scrolls under it, a 1 px hairline (`hairline`, full width, in the bar's last row) fades in over 150 ms (`Motion.short`, standard; at once under Reduce Motion), and out again at the top: `ScrolledUnderRule` (common.dart) wraps the app bar of `PageScaffold` and of the reader, and follows the app bar's own `notificationPredicate` (the reader's is off while the text scrolls under the aliyah ribbon, which has its own rule). Flutter's own licence pages (About → Open-source licenses), whose app bars the app doesn't build, keep Material's scrolled-under elevation instead, its shadow hairline-thin in outlineVariant (none in high contrast), so their text never slips under the bar unmarked.
- High contrast: a permanent 2 px bottom outline, and no hairline.
- Title: titleLarge (serif), onSurface, start-aligned. Where it has no room beside the actions (a wider interface font, or enlarged text, beside the Demo tag), it is set a little smaller, to 75% at most, and cut short only past that.
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
- Leading icon 22 in onSurfaceVariant, in a 38 slot (icon then 16 gap); or, in its place, a `leading` widget, such as a member's initial disc, in the same slot and aligned as the icon is.
- Title bodyLarge onSurface; subtitle bodyMedium onSurfaceVariant, 2 lines max. Once the system text is enlarged, the subtitle is never cut short (WCAG 1.4.4). A subtitle of parts between middle dots, such as a haftarah's passages, is a `DotLine` (`subtitleParts`, §9 Today 1), never cut short: its lines break between parts, not inside one.
- An optional detail line under the subtitle, 4 below it, in bodySmall onSurfaceVariant: a line of facts, such as how busy a forum is, or the special haftarah of the week. With a detail line, the icon and chevron line up with the title's line, rather than float beside the middle of three lines.
- Trailing: an optional value in bodyMedium onSurfaceVariant, then `Icons.chevron_right` 20 in outline (mirrors in RTL automatically).
  - The value ends the title's line, 4 before the chevron. When the two don't fit side by side (large text), it moves under the title instead of squeezing it. With a subtitle under them, the icon and chevron line up with the title's line too.
  - A trailing button with a label (a TextButton, such as "About streaks" or "Sign in") goes with the title the same way: at the end of its line, or under it when the two don't fit, so that no word of the title ever breaks. With a subtitle under them, the icon (or leading widget) lines up with that line too, as high as the button, 48 at least: a blocked member's initial stays by their name over why their Unblock failed.
- Large text: where the text beside the icon slot and room for the widest control a row has at its end (12 and a switch's 52, whatever the row has there at the moment) would be narrower than 112 times the title's own text scale (`PaperRow.squeezes`), the row stacks, rather than leave its text a word or two a line. At 300% that is any phone; at 200%, a phone under about 395 dp (356 dp for rows without an icon). The decision rests only on the width, the text's size and whether the row has an icon, so that the rows of a group decide alike, and a row keeps its layout as a control at its end comes and goes (a button shown while a setting is on). The title's own scale is the factor its size is enlarged by (on Android 14 and later the system's scale grows large text less than small: at its 200%, 16 to 28, 14 to 26), never a width scaled as a font size.
  - The title's line: the icon, growing with the text to 1.5× at most, 8 before the title, and the chevron at its end, 12 after it, while that leaves the title at least 88 times its scale (a 412 dp phone at 300%); the hairline under the row then starts where the title does (57 at 300%). Narrower (a 320 dp phone), the icon and the chevron go on a line of their own, 4 above the title, and the title takes the full width; the hairline under such a row starts at 16, where all its text then does.
  - The subtitle and the detail line under it, the row's full width; then a trailing control (a menu, a switch), 8 below them, at the start.
  - A title set smaller to keep a long word whole (§4, `WholeWords`), stacked or not, sets the lines under it, and a value beside it, no larger as drawn, so that it is never smaller than its subtitle.
- A spinner while the row's tap is under way (a discussion opening, `progress`) takes the chevron's place, 20 square, so the row keeps its layout.
- It decides its layout at layout (a LayoutBuilder), so it doesn't answer intrinsic size queries: in a dialog, whose content is set at its intrinsic width, it is given a width of its own, and it never stands in an `IntrinsicHeight` row.
- Tap via SeferInkWell.
- Semantics: the row is one item, its text and its tap. A trailing control (a menu or text button) keeps an item of its own beside it, so both actions can be reached; a switch or checkbox that the row's tap also toggles merges into the row (`mergeTrailing`), which then reads in the control's role rather than as a button. A row whose value another control moves is a live region (`liveRegion`).
- The one row of a page that erases sets its title in `error` (`destructive`), with no icon.

**GroupHeader**
- Eyebrow, 28 above and 8 below, start inset 4.
- Semantics header level 2.

### 6.4 SectionHeader (common.dart)

- Restyle as an Eyebrow in `secondary` (was titleMedium in blue w600), 28 above and 8 below.
- Keep the `header`/`headingLevel` semantics and the trailing slot.
- A header with digits in it ("2 of 7 aliyot") is `SectionHeader.plain`, titleSmall in onSurfaceVariant: eyebrows never hold digits (§4.5).
- An eyebrow set in capitals (an accessibility font, §4.5) is read as written.

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
- Destructive (confirm dialogs only): Filled error / onError (`AppButtons.destructive`), for what can't be undone, which the dialog says: in its own words where it explains more (deleting the account), or as `cantBeUndone` ("This can’t be undone.") under a bare question (deleting a post). An action that can be undone is confirmed with the primary Filled button (blocking a member), or not at all.
- A deletion offered without a confirmation, which a status message's Undo reverses, is a Text button in error's ink (`AppButtons.destructiveText`), its washes in error too.

### 6.6 Chips

- Height 36, padded to 48; radius 8; labelMedium.
- ChoiceChip:
  - `showCheckmark: false`;
  - unselected: 1 px outline, transparent;
  - selected: primaryContainer fill, 1.5 px primary border, label w700 onPrimaryContainer. The border width and weight are the non-colour cue;
  - a label too long for the line, as at the largest text sizes, wraps between its words and the chip grows taller, rather than fading out mid-word (`SeferChoiceChip`; one with an avatar keeps one line).
- FilterChip (multi-select) keeps its checkmark.
- A leading check icon anywhere else means "done" only.

### 6.7 Inputs

- Outlined, radius 10; enabled 1 px outline (2 px in high contrast); focused 2 px primary; error 2 px error.
- High contrast: focused (and focused error) borders are 3 px. The enabled border is already 2 px there, and primary is only about 1.5:1 from outline, so the width has to change as well as the colour.
- Label bodyLarge onSurfaceVariant; helper and counter bodySmall with tabular figures.
- Code entry (account): six 48×56 boxes (narrower on a phone too small for them, taller with enlarged text), radius 10, titleLarge's size in NS w500 with tabular figures; auto-advance; paste fills all six. Borders as a field's: 1 px outline, 2 px primary on the box the next digit goes in while focused, 2 px error with an error (3 px focused in high contrast).
- Counters (`quietCounter`): hidden until 80% of the limit, then in the locale's number format.

### 6.8 Switch, slider, segmented control

**Switch**
- Selected: track primary, thumb onPrimary with a check icon (16).
- Unselected: track surfaceContainerHighest with a 2 px outline border; thumb outline, 16 px, no icon. Thumb size and position are the non-colour cue.
- High contrast: icons on both states (keep the check/close thumbIcon, app_theme.dart:258).

**Slider**
- Active track primary, inactive outline (a boundary, at 3:1 or 4.5:1 in high contrast, so the whole range shows), the inactive part 2 high and the active part 6 (`SliderTrack`, app_theme.dart), so it reads apart from the inactive part by its weight, not only its colour: in high contrast primary and outline are barely apart (about 1.5:1); round thumb primary 20 (`RoundSliderThumbShape(enabledThumbRadius: 10)`). Every shape is named in the theme, so the deprecated `year2023` flag is left unset and neither Material slider generation shows through.
- `tickMarkShape: SliderTickMarkShape.noTickMark`.
- Value at the end in labelLarge with tabular figures, 12 clear of the title; −/+ IconButtons 48. Where the title, whole on one line, wouldn't fit beside the value at its size (large text on a phone), the value goes under the title rather than either being squeezed, and the title's words stay whole. The value is allowed as much as the widest it may show, measured at every step (the speech rate's widest, "Normal", is mid-range), and at least a percentage's width, so that none changes its layout as its value moves; and the sliders of one paper (Display's size and spacing) decide alike, by the longest of their titles (`LabeledSlider.group`).

**Scrollbar**
- The thumb is outline, a boundary as the slider's track is, and onSurfaceVariant under the pointer or while dragged, on every platform (`scrollbarTheme`). It is named because Material's own thumb on Android is the theme's highlight colour made opaque, which here would be the press wash's ink (§6.5) in full.

**SegmentedButton**
- Radius 10, height 48; selected primaryContainer with label w700 and a check icon (keep the M3 check here; it's the non-colour cue); unselected transparent with 1 px outline.
- Focus: the ring goes around the whole group (Flutter gives each segment a plain shape of its own), so the focused segment is also washed in its ink at 24% and its label is underlined.
- A settings choice (`ChoiceGroup.segmented`) lies across the column while every label fits beside the check in two lines, no word broken. The selected segment always bears the check, and every other label keeps the check's room (30: the check, its gap, and the 4 more a button with an icon pads its end by) beside it, half on either side, so that all are set as narrow and none changes its lines as the choice changes. Otherwise the segments stand one under another, each the column's width, checked.

### 6.9 Navigation bar (phone)

- Height 72; background surfaceContainer; 1 px hairline top border.
- Indicator primaryContainer 64×32 (stadium, the platform idiom).
- Icons 24, outlined; filled when selected.
- Labels always shown, labelSmall with letter spacing 0, so "Community" fits a 360 dp phone's 72 px slot in bold: selected onSurface w700, unselected onSurfaceVariant w500 (6.51:1).
- Large text: the labels grow (Material allows up to 1.3×) only while the widest, in bold, still fits its slot on one line, so no word ever breaks; a font too wide even at its normal size shrinks them, to 70% at most. The bar grows to fit them (72 at 1×).
- Keyboard focus: the §6.1 ring around the indicator (no wash). The indicator moves over Material's 500 ms, or at once under Reduce Motion.
- Icons: Today `today`; Parsha `menu_book`; Progress `donut_large_outlined`/`donut_large` (echoes the rings; replaces the sparkle `insights`); Community `forum`; Settings `settings`.

### 6.10 Navigation rail (≥600)

- Background surface, with a 1 px hairline end border (replaces surfaceContainer and the VerticalDivider in shell.dart).
- Leading: the app mark (`AppMark`, 40×40, ClipRRect radius 10). It draws mark_128.png wherever 128 px covers the pixels drawn and icon.png above that: decoding the 1024 px master straight to 40 px breaks up the letters.
- Extended at ≥1200: the mark plus a 12 gap plus the wordmark "Shnayim Mikrah" (EBG 500 20/24) or "שניים מקרא" (FRL 500 20/24) in onSurface. Semantics header. Replaces "SM" / "ש״מ".
- Indicator primaryContainer radius 12; destination height 56 in the extended rail. The compact rail's are 70: Material's 64 (the 32 indicator, 4, a 16 px label and 12 below), spacing the framework fixes, and 6 above the indicator, where Material puts none, so that the focus ring, 5 out from it, is never cut off by the rail's top as it scrolls.
- Keyboard focus: the §6.1 ring around the indicator (no wash).

### 6.11 ParshaRings and RingLegend (progress_widgets.dart)

**Rings**
- Sizes: 104 (Today hero), 88 (Parsha header), 40 (compact).
- `stroke = size × 0.055`; `r0 = size/2 - stroke/2`, `r1 = r0 - 1.6·stroke`, `r2 = r1 - 1.6·stroke`. At 104 this leaves a 56 px hole.
- Arc weights by verse count, as now. Gap 0.042 rad between aliyot; butt caps.
- Start at −π/2 and sweep CLOCKWISE in both directions. Do not mirror.
- Colours: ring 0 ringMikrah1, ring 1 ringMikrah2, ring 2 ringTargum; track ringTrack.
- At every size the track is drawn as the same seven arcs and gaps, under the done arcs, so a week not yet begun shows its seven parts to come rather than three blank circles.
- Centre: "2/7" in ringNumeral, plus "aliyot" in labelSmall onSurfaceVariant, scaled down as needed to fit the square inscribed in the hole (with 5% clearance), so large, bold or accessibility-font text never reaches the Targum ring.
- Wrap in RepaintBoundary. Existing semantics stay.

**RingLegend** (always beside or under rings of size 88 or more)
- Three rows, each 24 high: a 9 px dot in the ring colour, a 10 gap, the label in bodyMedium (`passMikrah1`, `passMikrah2`, `passTargum`/`passRashi`), and the count end-aligned "3 of 7" in bodyMedium onSurfaceVariant with tabular figures.
- In high contrast a 16 px key (`RingKey`) takes each dot's place, then an 8 gap, so it never runs into the name (the names start 5 further in than beside a dot; two themes are never seen side by side). It names each ring by its position as well as its shade: three concentric rings, the row's own stroked 2 px in its colour and the other two 1 px in onSurface. Each edge falls a whole pixel from the centre, which is set on a corner of the device's pixels, so at 1x no stroke smears into grey over two pixels and a pixel stands clear between rings: a 1 px ring spans 7–8, 4–5 and 2–3 px from the centre (radii 7.5, 4.5, 2.5), and the row's own 6–8, 4–6 and 1–3 (radii 7, 5, 2).
- Excluded from semantics: the rings' label already says it.
- `RingsWithLegend` sets the legend beside the rings whenever it fits there, each count under its name if the two can't share a line (as on a 360 dp phone); otherwise, on a narrower phone or with large text, the rings sit centred above it. Beside the rings on a wide card, the legend grows at most 40 past its natural width, so the counts stay near their names.

### 6.12 LedgerCard (replaces the two streak cards, today_screen.dart:300-325)

- One card with two equal columns and a full-height hairline between them. Lay it out as a `Table` with a `verticalInside` hairline border rather than `IntrinsicHeight(Row(...))`, so the labels still line up when a sentence in place of a count wraps.
- Each column: padding 16; ledgerNumeral (the count), then bodySmall label (`streakParsha`, `streakDays`); on Progress, an extra bodySmall "Longest: …".
- When the value is 0, the numeral slot shows titleMedium text instead, a sentence that reads on into its label and says what starts the run, its lines balanced (`BalancedText`). That is for the Hebrew phrasing, which takes two lines in a phone's column, so the parsha's name is not left alone on the last ("יתחיל עם סיום / פרשת בראשית"); the English takes three there ("Starts when / Bereshit is / complete", as the column, 154 at 412 dp and 128 at 360, is narrower than "Bereshit is complete"), where balancing changes nothing. Both settings are pinned by a test with the app's fonts, so a change of copy that adds a line is a deliberate one:
  - parsha streak: `streakBeginsWith(name)` = "Starts when Bereshit is complete" / "יתחיל עם סיום פרשת בראשית";
  - days on track: `daysBeginToday` = "Starts with today’s reading" / "יתחיל בקריאה של היום".
  - Never show a stark 0.
- The whole card is a SeferInkWell to /progress. Semantics: "Parsha streak: starts when Bereshit is complete. Days on track: 2".

### 6.13 WeekStrip

- Seven equal cells; min 48×68; radius 10; horizontal margin 2. The 48 is the day's slot, margins included: the day's Semantics node covers the whole slot, and a tap on its margins opens the day too, so the whole slot is the 48 dp target.
- Weekday label in labelMedium onSurfaceVariant (today: onSurface w700). Icon 22, 8 below the label, growing with the text to 1.5× (33 from 150% up), so a glyph is never a speck beside a weekday at twice its size, and never smaller than 22 (system text under 100%). The legend (`WeekStripLegendButton`) draws each glyph at the same size, in a swatch of 36 grown with it.
- Under the icon, 4 below it, the day's planned aliyot as Hebrew ordinals in labelSmall onSurfaceVariant: "א", "ד·ה" for two, "א–ז" for a run. Shabbat shows the plan's Shabbat-morning aliyot, if any; a day before the join date shows none. A Yom Tov that is not Shabbat (Yom Kippur and Rosh Hashana included) shows `yomTovShort` ("Yom Tov" / "יו״ט") instead, so Simchat Torah is not taken for Shabbat. It keeps to one line across the day, untracked, 2 clear of the wash on each side, where it fits there at its size (in English, a day of 56 or more: a phone of about 440 dp at 100%, a tablet, a desktop); where it doesn't, it wraps between words instead ("Yom / Tov"), whole and centred, rather than shrink: at 100% that would set it under labelSmall's 12, the smallest the interface is set at (§4.3), and at 130% enlarging the text would change nothing. The strip is then a line taller that week. "יו״ט" fits every day. Tisha B'Av with no reading planned on it shows `tishaBavShort` ("9 Av" / "ט׳ באב", on the 10th too when the fast is postponed) in the same way, where "Tisha B’Av" would wrap, and its label adds `tishaBavTitle` as the reason it has none ("Thursday: No reading planned. Tisha B’Av").
- Cells in a row are as tall as the tallest (`IntrinsicHeight`).
- Cell states:
  - Today: primaryContainer fill at 100% (was 35%) plus a 1.5 px primary border, drawn over the cell so its content sits where the other days' does. Icon: a 2 px primary ring with an 8 px centre dot (`TodayMark`).
  - Rest (Shabbat or Yom Tov): restWash fill plus candles (§7.6) in `rest`. A rest day that is today keeps the wash and takes today's border. The days of Yom Tov are the reader's own custom (`oneDayYomTov`), not the reading schedule's.
  - Kept: a filled 20 px circle in `done` with a 14 px onDone check.
  - Ahead / caught up: the same disc with the existing fast_forward / published_with_changes glyph.
  - Grace: `shield_outlined` in grace.
  - Missed: `remove_circle_outline` in neutral.
  - Open (past, and still to read in full or in part): `hourglass_bottom_rounded` in overdue (`stillToReadIcon`), the mark of reading still to do after its day, as on the week page's overdue line and the Torah map's tile that can still be finished; never `history`, which means made up later (the map's made-up tile, the badge of a week made up, the make-up list). Labelled `dayOpen` ("Still to read" / "עדיין לקריאה", as the week page's "still to read"), which stays true of a day with one or two readings done, as a day counts once three are; the pair of Missed's `dayMissed` ("Not read").
  - Upcoming: `circle_outlined` in **outline** (was outlineVariant, D16).
  - No reading: `horizontal_rule` in outline.
- Fills are `Ink`, so a press shows on them. A glyph that changes cross-fades over `Motion.medium` (§8).
- `LayoutBuilder`: when a seventh of the width is under 48, or under the widest weekday label at the current text size, the strip takes two rows, Sunday to Wednesday and then Thursday to Shabbat, in a four-column grid.
- A card around the strip alone uses `WeekStrip.cardPadding` (8), so the days stay in one row on a 412 dp phone (52 each).
- `WeekStripLegendButton`: an `info_outline` IconButton (tooltip `statusLegend`) for the strip's card or section header. It opens a sheet that shows every glyph beside its label, today and rest days on their fills.
- Each day is one node with the ink well's tap and focus, its label and tooltip `dayChipLabel` ("Tuesday: Still to read. Sheni"). Today's says so, so a screen reader can find it (WCAG 1.3.1): `dayChipLabelToday` ("Friday, today: Still to read. Shishi and Shevi’i" / "יום שישי, היום: …"), the weekday still first. It is not marked selected: today is not a choice the strip makes.

### 6.14 Torah map (progress_screen.dart tile())

**Layout**
- Fixed grid, by the map's own width rather than the window's: 3 columns under 440 (a phone), 4 from 440 (beside the year on a desktop, 500 to 555), 6 from 640 (a tablet's column, or a window's just under 1200); gap 6.
- A name wraps between words, never inside one. A tile whose name has a word too long to sit beside its icon (Beha’alotcha on a 360 or 412 dp phone, or in a tablet's six columns) puts the icon above the name, 2 apart; a one-line name still fits the 52 minimum. A name with a word too long for the tile at all is set just small enough for it, measured at the size it is set (letter spacing doesn't shrink with the text), and no smaller than 80% of its size: only when large text would shrink a book's longest word (set bold) further does that book's grid take fewer columns. Each book counts its own words, so a long word in one book never changes another's grid.
- Build each row as `IntrinsicHeight(Row([Expanded(tile) …]))` so tiles grow with text scale. No GridView aspect ratio.

**Tile**
- minHeight 52; radius 6; padding 8/6.
- `Row(mainAxisAlignment: center)`: an optional 14 px icon (growing with the text to 1.5×, 21 px, and never smaller than 14; whether a name fits beside it is measured at the size it is drawn), a 4 gap, then `Flexible(Text(maxLines: 2, textAlign: center))` in labelMedium (a Column instead, as above, for a word too long). Once the system text is enlarged, a name is never cut short.
- The fill is `Ink`; the border is drawn over the tile, so every tile's content sits in the same place.

**States**

| State | Fill | Border | Text | Icon |
|---|---|---|---|---|
| on time | done | none | onDone | check |
| late | late | none | onLate (5.49) | check_circle_outline |
| finished with the next parsha (`restored`) | late | none | onLate | done_all |
| made up | paper | 1.5 px late | onSurface | history in late |
| missed | paper | 1 px outline (2 in high contrast) | onSurfaceVariant | remove 14 in neutral (the non-colour cue, D8) |
| can still be finished with the next parsha (`overdue`) | paper | 1.5 px overdue (2 in high contrast) | onSurface | hourglass_bottom_rounded in overdue (`stillToReadIcon`, the glyph of `WeekStatusBadge` for `overdue` too, so the Recent weeks row and the week's page mark it alike; not history, the made-up tile's) |
| current | primaryContainer | 2 px primary | onPrimaryContainer w700 | timelapse |
| upcoming | paper | hairline | onSurfaceVariant | none |
| untracked | paper | hairline | onSurfaceVariant | pause_circle_outline |

A tile's screen-reader label and tooltip name its exact status ("Noach: Finished with the next parsha", "Lech Lecha: Can still be finished with the next parsha"). The rescue of a missed parsha has one name in every string, the plain words of what it takes: finished with the next parsha ("הושלם עם הפרשה הבאה"), never a double-up or a restore.

**Book header row**
- Hebrew book name (FRL 600 18 in `secondary`, the rubric's gold, as Browse names its books), a 8 gap, the Latin name (titleSmall), and "3 of 12" end-aligned in bodySmall with tabular figures, then an `expand_more` chevron that turns over `Motion.short`. The two names are one paragraph, so with large text the Latin name wraps under the Hebrew one.
- In the Hebrew UI, the Latin name is dropped.
- The row (min 48) is a SeferInkWell that folds or opens its book. Only the book with the current portion starts open, so the map is the current book plus four headers. Semantics: a level-3 heading and a button with an expanded state, labelled `torahMapBook` ("Genesis: 3 of 12 parshiyot").

**Help:** the section header's `info_outline` IconButton (tooltip `torahMapHelp`) opens a sheet with `torahMapHelp` and each state's swatch (fill, border and icon) beside its label, balanced (`BalancedText`), so that a label of two lines leaves no word alone on the second ("Can still be finished / with the next parsha" on a phone).

### 6.15 YearBar

- 54 segments across the content width; segment gap 2; an extra 4 px between books; height 8; radius 1.5.
- Current is 4 taller than the bar (2 above, 2 below: `YearBar.tick`), so it marks "you are here" at any width; the bar is painted 12 high, with the names 4 under the bar itself.
- Colours: on time = done; late = late; made up = paper with a 1 px late border; current = primaryContainer with a 1 px primary border; open (everything else) = `yearTrack`: outlineVariant, and in high contrast a grey between the card and a finished segment (#949494, #5C5C5C: 3:1 from the card, over 4:1 from done), where outlineVariant would be as loud as a finished segment and ringTrack all but vanishes.
- Below 8 px a segment (`YearBar.compactSegment`: every phone), a 1 px border leaves a speck of fill that reads as a "0", so made up is solid late, and current loses the border at its sides: its primaryContainer body sits between the two ticks, drawn in primary, a bracket around the week. It is never solid primary, which is done's colour, so this week never looks like the week before it finished on time (tested in every theme).
- Below it, book abbreviations in labelSmall onSurfaceVariant at each book's start: "Gen Exo Lev Num Deu" / "בר׳ שמ׳ וי׳ במ׳ דב׳". If very large text would run one into the next book's, all five shrink together to the size the tightest needs.
- Its states and the Torah map's come from one function (`parshaStandings`), so the two never disagree.
- One Semantics node: "This year: 0 of 54 parshiyot complete; Bereshit in progress". RepaintBoundary.

### 6.16 AliyahRibbon (replaces _AliyahSelector, reader_screen.dart:517-549; fixes D5)

**Layout**
- At least 76 high, growing with the text to 200% at most (as the rest of the reader's chrome, §9 Reader, guided), with a 1 px hairline below. Horizontal padding 8.
- `LayoutBuilder`: if a seventh of the width is at least 56 and holds the widest name in bold (labelSmall without tracking, as the navigation bar's labels), use a Row of 7 Expanded tabs. Otherwise (a narrow phone, or large text) the tabs scroll, each 64 wide or as wide as the widest name needs, and the selected tab is scrolled into view (`Scrollable.ensureVisible`, duration `Motion.medium`). No name is ever cut.
- Hidden in the full text while focus mode is on; the overflow menu still switches modes and marks the aliyah read.

**Each tab** (SeferInkWell, min 56 wide), top to bottom:
- the Hebrew ordinal א–ז in `ordinal` style (selected onSurface, else onSurfaceVariant);
- 2 gap, then the name in labelSmall (selected onSurface w700);
- 6 gap, then mini PassPips (§7.5, size 6, gap 3), growing with the text to twice that (12, gap 6) as the ribbon does, and never smaller than 6. With enlarged text, which outgrows the ribbon's 76, a gap beneath them keeps them clear of the selected indicator: 4 from 150% up, in proportion below that, and none at the normal size.

**Selected indicator:** a 3 px primary bar, radius 1.5, inset 8 at the bottom.

**Semantics:** `button: true, selected: isSelected`, label `aliyahTabLabel(name, n)` + state: "read", "{done} of 3 readings done", or "not started".

On desktop the ribbon is constrained to the reading-column width and centred.

### 6.17 PassTrack (replaces _StepHeader card and LayerLabel, reader_screen.dart:678-734 and 652-664; fixes D12)

Row of three Expanded segments with an 8 gap, growing with the text to 200% at most, its labels and their checks alike, as the instruction line beneath it (§9 Reader, guided). Each segment is a Column:
- Label in labelMedium: `passTrackLabel(n, name)` = "1 · Mikrah", "2 · Mikrah", "3 · Targum" (or Rashi, or the third Mikrah).
  - Done: onSurfaceVariant with a leading 14 px check in primary.
  - Current: onSurface w700.
  - Upcoming: onSurfaceVariant.
- 6 gap, then a 4 px bar with radius 2.
  - Done and current: ringMikrah1 / ringMikrah2 / ringTargum for segments 1/2/3.
  - Upcoming: ringTrack.

Below the track:
- 8 gap, then ONE instruction line in bodyLarge onSurface, growing with the text to 200% at most: the existing step title ("Read the Hebrew", "Read the Hebrew again", "Read the Targum"). Screen readers hear it with the step's count ("Read the Hebrew again, Reading 2 of 3"), as a live region where the platform takes no announcements; they skip the track, which shows the same.
- 12 gap, then the chapter heading (§4.7) when a chapter starts, then the verse.

Nothing else sits above the first verse. A label stays on one line, set a little smaller should large text need it. The third segment is named for what is read in it: the Targum or Rashi, or "Mikrah" for a verse read a third time in Hebrew. Ending with the last verse once more comes after all three.

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
- Below 400 wide, or when large text sets 14sp past 24, the bar is two rows: the progress bar with "Verse 1 of 21" at the end of its line, 12 after it and centred on it, then Back and Next, 12 apart, sharing the width. The position never takes a row of its own, which with large text on a phone would take the verse's room.
- Its text grows to 200% at most (§9 Reader, guided).

It sits in the scaffold's bottom slot, so status messages rise above it, and runs under the gesture bar in surface, so no strip of another colour shows beneath it. Keep the keyboard shortcuts.

### 6.19 Sheets, dialogs, snackbars, tooltips

**Bottom sheet**
- Background paper; top radius 20; `showDragHandle: true` (36×4, in full outline: the handle is also a dismiss button, so it is held to a control's 3:1).
- Title titleLarge serif (`SheetTitle`), its lines balanced where it wraps, so that no word stands alone on the last; padding 24 (16 under 360); max width 640, centred.
- Rows: on PaperGroups (§6.3) within the same padding (`sheetPadding`), never bare list tiles, so that from sheet to sheet the paper's edge is on the title's, the icons (or a member's initial disc, or a radio) 16 in from it and the text 54 in, and a row's focus is a ring (§6.1): the verse's actions (§6.27), the choice sheets and the language's (§9 Settings), onboarding's restore sheet and the blocked members (§9). A row that does something in place has no chevron; one that leads to a page has one. Three sheets still set bare tiles across the sheet, ringed in focus (`TileFocusRing`, §6.1), and are to become paper checkbox and radio rows in their turn: the after-Shabbat check-in's aliyot (`CheckInSheet`, check_in.dart), the reading from a Chumash (`_BookSheet`, today_screen.dart), each a CheckboxListTile, and the date sheet (`read_date_sheet.dart`).

**Dialog**
- Background paper, radius 16, padding 24.
- Title titleLarge serif; body bodyMedium onSurfaceVariant.
- Actions end-aligned: text buttons plus at most one Filled.
- Enter: fade plus scale from 0.98, 150 ms.

**Snackbar**
- Floating; radius 10; margin 16; inverseSurface with onInverseSurface; action in inversePrimary.
- From 600 dp, at most 640 wide (a sheet's width), centred on the page that shows it: within a tab, the pane beside the rail, not the whole window. The page on show sets it in its own Scaffold, as it lays out (`StatusMessageArea`, feedback.dart), so a message that stays on as another page opens, or as the window is resized, is set again for where it now is. Within the safe area, so a phone held sideways keeps it clear of the notch and centred on the page where it can.
- Duration 4 s, or 8 s with an action. A message with an action stays until dismissed, with a Close button (`showCloseIcon`, in onInverseSurface), for screen-reader users (`accessibleNavigation`) and while focus is shown for the keyboard (`FocusHighlightMode.traditional`): on every desktop, and in a desktop's browser, until a touch, as a mouse never leaves that mode; on a phone or tablet once a key is pressed. Otherwise it leaves after 8 s. One that stays leaves as the page that showed it is popped, covered by another page or hidden with its tab, as its action (an Undo) is about what was done there; a page that shows one as it closes, about what it did, keeps it (`outlivesPage`, the posted question's View the discussion). The next message takes its place. Its action and Close stay on its line while they take at most 45% of its width (`actionOverflowThreshold`, Material's 25% being too little for the Hebrew Undo and Close on a phone), a share that shrinks as the text is enlarged, since Material measures the action at its unscaled size.
- Sits above the page's bottom bar (the reader's, a thread's reply box) and its floating button, and on a phone above the navigation bar. The shell has no Scaffold of its own, around the rail and the pane or over the navigation bar (which would show the message over a page's reply box), so that each page is the one that shows it, and a tab chosen while one is on show switches without its fade (§8), so that the message stays steady.

**Tooltip:** inverseSurface, radius 6, bodySmall in onInverseSurface; waitDuration 400 ms (existing).

**High contrast:** paper and surface are the same colour there, so sheets and dialogs (including the date and time pickers) also take a 2 px outline.

**Code:** open dialogs with `showAppDialog` and sheets with `showAppSheet` (common.dart; a sheet's heading is `SheetTitle`), and status messages with `showStatus` (feedback.dart). They carry the timing and Reduce Motion; test/ui/motion_usage_test.dart fails on a direct `showDialog`, `showModalBottomSheet`, picker or `showSnackBar`, and on a `DropdownButton`, whose menu always fades in: a picker field is a select-only `DropdownMenu`, which opens at once.

### 6.20 NoticeBanner (common.dart) and the demo notice

**NoticeBanner**
- Inset within gutters (never full-bleed); secondaryContainer; radius 12; no border (2 px outline in high contrast).
- Padding 12/16; icon 20 in onSecondaryContainer; bodyMedium onSecondaryContainer; optional trailing TextButton.
  - Where the text wraps, its lines are balanced (`BalancedText`), as the title's are, so that no word stands alone on the last where an even setting of its lines can avoid it ("Log what you read from / a printed Chumash — it / counts just the same." on a 360 dp phone, not "… just the / same.").
  - The text holds each spaced dash to the word before it (`dashHeldToWord`), so that no line starts with one, as the Hebrew preview notice's "— הפרשה" did at 300%. A date in it is held together but after its comma (`Names.practiceDate`, §4.6): the Hebrew preview notice breaks "ביום ראשון, / ל׳ בתשרי", never "ל׳ / בתשרי".
  - Beside or below a TextButton the end padding is 8: the button's own padding makes up the rest, and the text keeps 16.
- **Close button** (`onDismiss`): optional, a 48 dp IconButton (`close` 20 in onSecondaryContainer, tooltip `dismissLabel`, such as `actionDismiss`) at the top end, 4 from the edge, so that its 48 dp target reaches the banner's edge: on the first line (below), or, beside a trailing TextButton, centred with the text and the button, all three in a line.
- **First line:** the icon and the text align to the top, and the icon is centred on the first line (the title's, or the text's), however many lines the text runs to (the reader's note on a third reading, the Chabad haftarah note, a week's preview), as a close button is, raised into the padding while the line is shorter than its 48 dp target. So the two keep to one line however large the text: Today's divergence notice, a close button and no title, at 200% has both on the middle of its 44 px first line. Only a text with a button at its end (no title or marginalia) is centred with the icon and the button on the row, and with a close button after it (the web's offer of a new version, below), all in a line.
- **Title** (`title`): optional, a heading in titleMedium onSecondaryContainer, a size above the text so that it reads as a heading rather than as the text's first sentence: a header node, 2 above the text, and the first line the icon and a close button are centred on. Where it wraps, its lines are balanced (`BalancedText`), so that no word stands alone on the last ("Shavua tov! Did you read / Bereshit on Shabbat?"). Like `WholeWords`, `BalancedText` answers intrinsic size queries (but for `bySentence`, or `holdDashes` on a text with a spaced dash), so a titled notice or a sheet's title may stand in a dialog or an `IntrinsicHeight` row.
- **Action below** (`actionBelow`): for a text longer than a line or two, which a trailing button would squeeze. The icon and text align to the top (First line, above), and the TextButton sits under the text at the end, with 4 bottom padding. Beside a close button, which keeps to the first line, the actions run on under it to the banner's end, 8 from its edge as without one (the welcome back after a pause, the divergence notice), rather than end a button's width short of it.
  - A row of actions below that ends with a Tonal button (the after-Shabbat check-in, the welcome after a pause) is inset 4 more at the end and 8 more at the foot (`NoticeBanner.tonalActionInset`): a text button's own padding makes up the banner's, but the Tonal's fill shows, so it stands 12 from the banner's end and foot, as the text stands 12 from its top.
- **Action ink:** the TextButton is `primary` where primary on secondaryContainer meets AA (4.5:1); otherwise, as in the high-contrast themes, it is `onSecondaryContainer`, with a 3 px focus ring in the same colour.
- **Marginalia** (`marginalia`): for a gentle word in the margin rather than news, such as onboarding's honor statement, the text is set as marginalia (§4.5) in onSecondaryContainer, and the icon sits beside its first line.

**Demo notice** (`DemoBanner` and `DemoTag`, community_ui.dart)
- A NoticeBanner with `info_outline` (replaces the pink `tertiaryContainer` strip and the flask icon).
- Shown on the Community home only, dismissible for the session.
- Forum, Thread, Compose and Account instead show a small "Demo" tag in the app bar actions:
  - labelSmall, secondaryContainer fill, radius 6, padding 6/2;
  - tapping it opens a sheet with the full explanation (how to sign in to try it only to a reader signed out);
  - its tooltip, "About the demo", says what it does, to screen readers too ("Demo, About the demo, button"), so it isn't taken for a switch to a demo.

**New version** (`WebUpdateBanner`, lib/ui/widgets/web_update_banner.dart; the web only)
- Once a new version of the web app has installed and waits for the open one to close (`webUpdateReadyProvider`, lib/services/web_update.dart, as `web/flutter_bootstrap.js` tells of it), a NoticeBanner with `system_update_alt_outlined`, `webUpdateReady` ("A new version is ready.") and a TextButton `webUpdateRestart` ("Restart"), which saves the settings and progress held back and reloads into the new version (and if storage fails, reloads all the same). A restart in another window of the app lets the new version take this one over too, and it restarts at once in the same way, wherever it is.
- Restart trails the sentence while the two fit on one line, and otherwise, as on a 360 dp phone or with large text, goes under it (`actionBelow`), rather than squeeze the sentence into a narrow column.
- At the top of Today's reading column, with a close button that puts it away for the session (`webUpdateDismissedProvider`); in About under the title page, without one, so that it can be found there again. Never in the reader, a discussion or a post being written, and never on the day of rest's title page.
- Not a live region: it appears quietly, as a window comes back to the front.

**Tags** (`SeferTag`, lib/ui/widgets/sefer_tag.dart): a word that labels what stands beside it, never a control, so it has no ink, no focus and no button's shape: labelSmall in onSecondaryContainer on secondaryContainer, radius 6, padding 6/1, with a 2 px outline outside it in high contrast only, where the pale fill alone barely shows; with an icon, it leads at 14 in onSecondaryContainer, 4 before the word and level with its first line. Its words stay whole (`WholeWords`, §4, no smaller than 12): "Moderator" beside the account card's initial, at 200% on a 360 dp phone, is set a little smaller rather than broken. It marks the member who began a discussion on their posts (§6.21), a source's license (Sources) and a moderator on the account card (Account). The Demo tag, which opens an explanation, is a button instead (`DemoTag`, above).

### 6.21 Forum posts as "letters" (thread_screen.dart)

- No card per post. Posts are separated by full-width 1 px hairlines (2 px outline in high contrast), the first under the thread's title. About 20 of air above the initial and below the last line: 12 and 6 of padding, plus what the header's and footer's 48 dp rows leave around their text.
- **Header row:**
  - 32 px initial disc in secondaryContainer, initial in EBG 600 16 onSecondaryContainer (`InitialDisc`, excluded from semantics; a person when the name is empty), centred on the name's first line however large the text (a line as tall as the tag beside the name, where that stands taller, as its high-contrast outline does);
  - 12 gap, then the author in titleSmall in its OWN Text with `textDirection: autoDirection(name)`;
  - on the posts of the member who began the thread, a tag (`SeferTag`, §6.20): "Question" on the post that asked a question, "Author" on the asker's later posts and on the posts of whoever began any other discussion, none in a weekly thread;
  - then " · " and the relative time in bodySmall onSurfaceVariant in a separate Text, with the full date in a tooltip; when the three don't fit on one line (enlarged text, a long name) the time goes under the name, without the separator;
  - then the overflow menu, its 48 dp box reaching 12 into the end gutter so that its glyph lines up with the column's edge, as the app bar's do with the screen's. The post itself reaches into the gutter by as much (`PostCard.menuBleed`), so the whole box takes a tap; the rest of the post keeps to the column. Reply is not in it.
  - Separate widgets fix the mixed-direction header in he_thread.png. Screen readers hear one label: name, tag, full date and "edited".
- **Body:** bodyLarge 16/26 in both UIs (NSH in Hebrew), `autoDirection`, tagged with its language, start-inset 44 to align with the name. A quoted post sits above it on surfaceContainerLow with a 2 px gold-ink (`secondary`) start rule, in bodySmall onSurfaceVariant: a question on a verse (the opening post) by its question, or by its verse where the post is nothing more; any other post as it begins.
- **A verse quoted** (`VerseQuote`, community_ui.dart): a question asked from a verse (§6.27) begins with it. The post keeps it as text, as it always has: "> " and the verse's Hebrew, then a blank line and the question, with a left-to-right mark first where the question runs from the left (`withVerseQuote`). The post that opened the thread, the only one a question is begun as, is parted at its first blank line where it begins so, "> " followed by Hebrew (`splitVerseQuote`); one that quotes words in English is left as written, and so is any other post, a reply that begins with "> " and Hebrew of its own among them. The verse is never shown as that text (but in the moderators' queue, which shows a reported post as it is stored: it can't tell an opening post's verse from a member's own quote): it stands above the question as a quotation, whole, in the scripture's font at 20 / 1.7 in onSurface, right to left, its lines broken as the reader breaks them, with a 2 px `secondary` rule at its right, where the Hebrew begins, 12 from the text, in either UI (as the verse's options show it, §6.27); then, 12 below, the question in its own direction, as any body. The two are selected as one text (a `SelectionArea`, where any other post is a `SelectableText`), and copied as the post is written: the verse without the word joiners and no-break spaces set for the screen, a blank line, then the question (`copiedFromQuestion`). Screen readers read it as part of the post, in a Hebrew voice, spoken as the reader's verses are (the Name as it is said). A forum lists the discussion by its question: the server's excerpt starts after the verse (supabase/migrations/20261012010000_excerpt_after_verse.sql), and one that begins with the verse instead, cut short within it, is not shown.
- **Footer**, its icons in line with the text:
  - TextButton "Todah" with `volunteer_activism_outlined` 18 (filled `volunteer_activism` when given), then the count in tabular figures once there is one. A toggle for screen readers, named for what a tap does and how many have thanked, in words that hold the one it shows, and the count in digits as it shows it, one too ("Say todah to Rivka. Thanked 4 times", "… Thanked 1 time"), so that voice control finds it by them.
  - The footer's buttons keep their 12 start padding at any text size (Material's would shrink), so their icons stay in line with the text.
  - 8 gap, then TextButton "Reply" with `Icons.reply` 18 ("Reply to Rivka" for screen readers), on every post the reader can answer; none in a locked thread, except for moderators.
  - Under your own post, no Todah button: the icon and count in onSurfaceVariant, once it has been thanked; until then Reply comes first.
- The opening post gets a 3 px primary start rule, from the top of the initial to the foot of the footer's label, hung in the start gutter 12 before the column, so that its text keeps the 44 px column every letter shares. It is the first post shown only if its member began the thread, as it began: a weekly thread opens with no post of its own, so none takes the rule; nor does a long thread's first post shown until its earliest posts are loaded, nor a reply shown first because the opening post is hidden (deleted, or its member blocked).

### 6.22 Empty states

Centred, max width 320, 40 top padding:
1. SeferDivider;
2. 12 gap, then one marginalia sentence;
3. 16 gap, then a Tonal button.

**Error state** (`ErrorMessage` and `ErrorState`, fallbacks.dart): what couldn't load is said the same way, never as a bare sentence: the divider, why in one marginalia sentence (`communityError`, or `errorGeneric`), and a Tonal "Try again" with `Icons.refresh`. `ErrorState` stands for a whole page, 40 under the app bar, and can be pulled to refresh: it scrolls even when it fits, under the page's `RefreshIndicator` (a forum's, a forum link's whose forums failed, the reports'); any other way on, such as All forums, follows Try again as a Text button. `ErrorMessage` doesn't scroll, so it sits in a page that shows more: under the Community page's Forums heading, under a thread's title (kept where it is known), in a new discussion in place of the forums' chips (Post waits for them), under the city search field, in the blocked members' sheet. Nothing is offered over a failed load: no floating button, no reply box. Pressed, Try again stays enabled, so that it keeps the keyboard focus, and its icon turns to a spinner ("Loading…") until the outcome, while the message stays in place. Should it fail again, nothing on the page changes, so the message is said again to screen readers (announced, or where the platform takes no announcements, as a live region new each time); a refresh from the app bar, or a pull, then shows no status message to repeat it. What a page shows with Try again is never retried behind the reader's back (`noRetry`): Riverpod's own retries would keep it loading for most of a minute before it said why, and a refresh as long before it said it had failed. A failure from before a page shows it (on another page, or before the reader went back and came again) is no failure of that page's: it is fetched again as the page opens, shown loading meanwhile (`FetchAgainIfFailed`, lib/app/retry.dart), on the Community page, a forum, a thread (the forum's name in its app bar too), a new discussion and the blocked members' sheet; the reports to review are fetched afresh each time the queue opens. A thread's Try again and refresh fetch the forums again too, where they had failed.

**A widget that fails** (`AppErrorPanel`, fallbacks.dart): in a release or profile build, a widget that throws as it builds shows this in its place rather than Flutter's grey box (a debug build keeps the red screen). It paints no paper of its own within the theme: the surface it lies on shows through, whatever paints it (a card, a sheet, a group's row with the hairline under it, a notice's wash, the page), so a failed row keeps its group's hairlines and corners rather than standing as a recessed box. Only above the theme, where nothing else would, does it paint #FAF7F0 or #14120F as the device is set. On it, centred, one sentence in Noto Sans (Noto Sans Hebrew in the Hebrew UI) 16/24 in onSurface (in the theme's surface where the nearest Material beneath is of the other brightness): "Something on this page didn’t load." / "חלק מהדף לא נטען." (`errorPanelMessage`, taken straight from the translations, in the sentence's own direction), as many lines as fit and an ellipsis after, and only where the slot is at least 48 high and 120 wide: a smaller one is the surface alone. In a list it is as tall as the line, 12 above and below. Screen readers hear the sentence either way. It looks up nothing that could fail. Every error, its own and any other the app meets, is kept in memory for About's Copy details for support (§9; `recentErrors`, lib/services/recent_errors.dart).

### 6.23 Finished panel (reader_screen.dart `_FinishedPanel`; replaces the celebration icon)

Centred, max width 480:
1. SeferDivider at 200 wide (animated, §8).
2. 16 gap, then the title in headlineMedium (displaySmall from 600 dp): `aliyahDoneTitle`, "Revi’i is complete". The warmer `aliyahComplete` ("Yasher koach! Revi’i is complete.") is what is spoken, by the announcement or, where the platform takes none, the title's live region.
3. 8 gap, then a marginalia line about the aliyah to continue with (the first after this one not yet read, then the first before it): `nextAliyahLength`, "Chamishi is 31 verses."
4. 24 gap, then actions: Filled "Next aliyah · Chamishi" (52 high, a trailing chevron) and Text "Done". The first button takes the focus.
5. Once everything planned for today and before is read, with the parsha unfinished, a marginalia line comes first: `todayReadingDone`, "That’s today’s reading. See you tomorrow." (or "See you on Sunday." when the next day with reading is later; a day whose aliyot were read ahead has none left), or on the plan's last day `erevShabbatDone`, "That’s this week’s reading. Shabbat shalom!" ("The rest is for Shabbat morning." when the plan leaves aliyot for it, and "Chag sameach!" when Yom Tov begins the next day). Done is then the Filled button, and continuing a Text "Keep going: Chamishi". While anything planned is still unread, the panel stays as in 4.
6. When the parsha is complete:
   - the title becomes `parshaDoneTitle`, "Parshat Bereshit is complete" (`parshaComplete` is spoken);
   - a status line, bodyMedium onSurfaceVariant after the status's icon in its colour (§6.14), says how the week stands, from its WeekEvaluation: on time, "On time · 3-week parsha streak · +1 grace day" (the grace day only when finishing earned one; the streak and the grace day are left out while streak numbers are hidden, and when the finish completed nothing new, as stepping again through a parsha read weeks ago, which shows the plain status); late, "After Shabbat — and it still counts. Your streak continues."; finished with the next parsha, "Finished together with the next parsha — your streak continues.";
   - a Tonal "Read the haftarah" (if enabled and not read) over a Text "Done", or else a Filled "Done".

**Sefer complete** (`lib/features/reader/sefer_complete_screen.dart`, `/celebrate/sefer:5787:0`): a one-time full-screen page, centred, max width 480. SeferDivider, then "חֲזַק חֲזַק וְנִתְחַזֵּק" in hebrewDisplay 40/56 primary, untranslated (a level-1 heading, read from its letters), then SeferDivider, then bodyMedium onSurfaceVariant `seferDoneBody`, "Genesis complete — 1,533 verses, twice, with Targum.", then a Filled "Continue". It fades in over 400 ms (at once under Reduce Motion) and never auto-dismisses.
- `celebrationListenerProvider` (`lib/app/celebrations.dart`), which the app watches, opens it whenever the reading log changes and a book of this cycle or the last is newly finished, however it was finished: in the reader, from Today, on the week's page or by the check-in.
- The books celebrated are kept on the device alone (`celebrated.v1`), never synced or backed up, so each is celebrated once on each device that sees it finished there. Books already finished when the app starts, and a book that arrives finished from elsewhere (a sync with another device, or a backup restored: `ProgressController.logChangeArrived`), are recorded without a celebration, which would otherwise be pushed over whatever the reader is doing; so is a book of the reader's own reading finished more than a week before (logged late with an earlier day), or finished before onboarding is complete.

### 6.24 Theme swatches (Display settings)

- A 3-column grid (2 columns under 360) of cards 96 high, radius 12, each painted in its own theme:
  - surface background;
  - "אָ" in Noto Serif Hebrew 24 in onSurface;
  - a 24×4 primary bar and a 24×1 goldLeaf rule;
  - the label in labelMedium below the card; high contrast's two on two lines, `themeHc` over Light or Dark ("High contrast / Light"), so that no line starts with a dash, read as one name (`themeHcLight` / `themeHcDark`).
- Selected: 2 px primary border plus a 20 px check badge (primary disc, onPrimary check) at the top-end corner.
- Radio semantics: one group container named `themeLabel`, each swatch a radio button (its name, checked state and tap); the arrow keys move from swatch to swatch, on the web too. Match device is a separate row above the grid (switch).
- Matching the device, the two themes it switches between are both marked for the eye: light and dark, or the two high-contrast themes when the device asks for high contrast. To assistive technology none is checked (the switch says the device is followed), and the pair carry a hint, `themeUsedWhenLight` / `themeUsedWhenDark`. Choosing a swatch stops matching; turning the switch off keeps the theme the device had.
- `ThemeSwatchPicker` (lib/ui/widgets/theme_swatch_picker.dart) is shared with the reader's display sheet, where its cards are 64 high (`compact`).

### 6.25 Search results (lib/features/search/)

- The search field as in §6.7, at the content width, with `search` leading and a clear button once there is text. Hebrew in it runs right to left and English left to right, in either UI; empty, it takes the UI's direction.
- While the index is first built: a marginalia line over a determinate bar, 4 px with radius 2, primary on ringTrack; centred, at most 320 wide, 40 below the field.
- With nothing to search yet: an empty state (§6.22) with `searchIntro`. With nothing found: `searchNoResults` in bodyLarge and a hint in bodyMedium onSurfaceVariant, 24 below the field and 8 apart: in Hebrew `searchNoResultsHint`, "Try fewer words, or another word or spelling." (the Torah's spellings have been tried by then), in English `searchNoResultsHintEnglish`, which names the 1917 translation's older English.
- Results: the count in bodySmall onSurfaceVariant, 16 below the field, then a GroupHeader (§6.3) per parsha over one PaperGroup of verses. Hebrew found only as the Torah spells it, with fewer ו and י (DESIGN.md, Search), has `searchSpellingFallback` ("No verse has “אהרון”. Showing “אהרן”, as the Torah spells it.", what was typed and the spelling each isolated in its own direction) above the count, where `searchNoResults` would stand: bodyMedium onSurfaceVariant, 24 below the field, the count 8 under it. A screen reader hears it before the count, with what was typed and the spelling shown tagged as Hebrew, as a verse's Hebrew is; the announcement of the count, which is plain text, says the note in the interface's voice.
- **Verse row:** min 72; padding start 16, end 12, vertical 12; a chevron 20 in outline at the end. On top the reference ("Genesis 28:10" / "בראשית כח, י") in titleSmall onSurfaceVariant with tabular figures, followed by " · Targum" when only the Targum holds the search, or " · Translation (JPS 1917)" (`translationLabel`) for a verse found in the translation, a study aid labelled as such. Then each layer, 4 apart:
  - Mikrah in the scripture font, 20 / 1.7, onSurface; Targum 18, onSurfaceVariant, under it as in the reader; the translation in bodyLarge onSurface. Never cantillation; vowels as the reader shows them.
  - About 16 Hebrew or 26 English words around the first match, cut at word breaks; a verse up to a third longer stays whole. Ellipses mark a cut, joined to the text by a no-break space. A word joiner follows each maqaf, as in the reader, so joined words stay on one line; where they are too wide together for the line, at a very large text size on a phone, that maqaf goes without it (`joinWhereFits`, through `JoinsThatFit`) and the line ends after it rather than inside a word, the marks moved back over the joiners left out (`shiftForRemovedJoiners`).
  - **Match:** w700 in onSecondaryContainer on a secondaryContainer wash (11.24:1 in light) as tall as the letters, not the line (`MarkedText`, a tight text box with a 2 px bleed each side and radius 3), so washes on lines one above the other never meet. The weight is the non-colour cue, needed in high contrast where the wash is close to the paper. With bold text on, where every letter is bold, and in high contrast, each wash is also outlined, 1.5 px in onSecondaryContainer. The washes are placed again when a font finishes loading.
- Semantics: each row is one button whose label is the reference, then each layer tagged with its language and spoken as verses are (§8 of DESIGN.md), from the pointed words whether or not vowels are shown, the Targum and the translation named. A list of results opens at its top, with its count.

### 6.26 Go to verse (lib/features/search/go_to_verse_sheet.dart)

The Parsha tab's search button, and Ctrl+K (⌘K) on any tab, open one sheet (§6.19) over the whole window, the navigation too:
- `SheetTitle` `searchTitle`, then the field as in §6.7 at the sheet's width: label `goToVerseLabel` ("A verse, word or phrase"), hint `goToVerseHint` ("Bereshit 28:12" with the reader's spelling of parsha names, "בראשית כח, יב" in Hebrew), `search` leading and a clear button once there is text, focused as the sheet opens. Hebrew in it runs right to left and English left to right, in either UI.
- 16 below the field, one PaperGroup (§6.3) of what the text leads to, in order:
  - **A verse** the text names (§3 of DESIGN.md): `menu_book_outlined`, the reference as Names.reference writes it, and the week of this year's cycle that reads it and its aliyah ("Vayetzei · Rishon") as subtitle. It opens the reader at the verse (§4.7).
  - **Or why there is none**, for numbers past the end of a book or chapter that are plainly numbers: `info_outline` and `goToVerseChapters` ("Genesis has 50 chapters.") or `goToVerseVerses` ("Genesis 28 has 22 verses."), with no tap.
  - **A search** of the text, `search` and `goToVerseSearch` ("Search for “ladder”", the query isolated in its own direction), for words worth searching: not for a reference by its numbers, which the text has none of, but for a parsha's name alone (ויצא), which is also a word, and for a reference that rests on unmarked Hebrew words that are also numerals (דבר נא, שלח לו), which may be a phrase. It opens the Search page (§6.25) with the query.
  - **Or, with nothing else to offer** (a number alone, say), `info_outline` and `goToVerseHelp`, which says what the sheet takes, with no tap.
- Enter takes the first row that leads somewhere; with none, the field keeps the focus.
- Once typing pauses, the first row is announced where the platform takes announcements.

### 6.27 Verse actions (lib/features/reader/verse_actions_sheet.dart)

A long press on a verse, in the guided reader, the full text (anywhere in the verse's block, with no ink outside focus mode) or the haftarah, opens one sheet (§6.19); so do a secondary click, and Shift+F10 or the menu key for the verse focus mode is on, or the first in view:
- `SheetTitle` with the verse's reference, as Names.reference writes it ("Genesis 3:22", "בראשית ג, כב").
- The verse as it will go, at most three lines, in the scripture's font at 20 / 1.7 in onSurface, right to left, its lines broken as the reader breaks them (never before a paseq, and after a maqaf only where the words it joins are too wide together for the line; the copy carries none of that), set off as a quotation is (§6.21, `VerseQuote`): a 2 px `secondary` rule at its right, 12 from the text. Screen readers skip it; the title has named the verse.
- 16 below, for a verse of the Torah, a PaperGroup of the reader's own marks: Bookmark (`bookmark_border`, or `bookmark` in primary once on) with a switch, one item to screen readers that reads as a switch (the switch itself is no item or tab stop of its own, as Account's backup row); then `addNote` (`note_add_outlined`), or `yourNote` (`sticky_note_2_outlined`) with the note beneath it, in its own direction, which closes the sheet and opens the note (below). Neither has a chevron. A verse of the haftarah has no such group.
- 12 below that (or 16 below the verse), one PaperGroup (§6.3): Copy (`content_copy_outlined`) and Share (`share_outlined`, or `ios_share` on Apple devices), with no chevron; then Ask about this verse (`help_outline`, the forum's icon) with `askAboutVerseDesc` beneath and a chevron, as it leads to a page.
- Copy closes the sheet and says `verseCopied`. Share leaves the sheet open beneath the platform's share sheet, which points from its row, and closes it once that is done with; where nothing can share, the verse is copied and `shareCopiedInstead` says so.
- Screen readers: each verse (in the full text, the verse and its Targum) carries the custom action `verseOptions` and a long press.
- Bookmark changes at once, and the sheet stays, its switch showing it.
- **The note** (lib/features/notes/note_dialog.dart): a dialog (§6.19) titled `noteTitle` ("Note on Genesis 3:22"), its field outlined, 4 to 10 lines, labelled `yourNote` with the hint `noteHint`, up to 2,000 characters (`quietCounter`), in the direction of what is written, and taking the focus. Actions: Delete (while there is a note) in error's ink with no confirmation, since its Undo brings the note back (`AppButtons.destructiveText`), Cancel, and a Filled Save that waits for a change; Ctrl+Enter (⌘Enter) saves. Saved, the page says `noteSaved`; deleted, by Delete or by emptying it, `noteDeleted` with Undo.

### 6.28 Listen bar (lib/features/reader/listen_bar.dart)

While Listen reads, playing or paused, a player sits above the reader's bottom bar, or at the foot of the full text and of the haftarah's page (above a tab's navigation bar):
- Background surface, 1 px hairline top border; it runs under the gesture bar where it is the page's last bar. Content constrained to the reading column and centred, as the bottom bar's; padding 4 above and below, the buttons' own padding bringing their glyphs to the column's edges.
- At its start, the speech rate: a Text button in onSurfaceVariant, `speed` 18, 6, and the rate as Settings shows it (padding 12 at the start and 8 at the end, closer than a text button with an icon sets them, so that each of the player's sides, 96 on a 360 dp phone, holds "Normal" with its icon), relative to the default (`speechRateLabel`): "Normal" (`speechRateNormal`), else a multiple of it to one decimal ("1.2×", `speechRateTimes`, a left-to-right run in Hebrew so that the sign stays after the number); labelLarge, tabular figures. Tooltip `speechRate`, read as `speechRateValue` ("Speech rate: Normal"). The icon goes only where the rate would have no room beside it even at nine tenths of its size: "Normal" keeps it from a 356 dp phone at 100% text (a little smaller below 366 dp), and loses it on a narrower phone and at larger text (on a 412 dp phone at 200%), where the rate stands alone; the rate is set smaller before it is ever cut short. It opens a menu (paper, §6.19) of 0.6×, 0.8×, Normal, 1.2×, 1.4×, 1.8× and 2.2×, with the rate set among them if it is another: each a radio icon (`radio_button_checked` in primary, unchecked in onSurfaceVariant) and its rate, the one chosen in w700. A rate chosen is the setting's (Settings → Accessibility → Speech rate), and the verse being read starts again at it.
- At its centre, left to right in either language, as media controls are: `skip_previous_rounded` (`listenPreviousVerse`), 8, a tonal 48 dp icon button in primaryContainer / onPrimaryContainer with `pause_rounded` (`listenPause`) or `play_arrow_rounded` (`listenResume`), 8, and `skip_next_rounded` (`listenNextVerse`). Back and on are disabled where there is no verse to move to; between Listen along's readings, back reads the last verse again and on goes to the next reading.
- At its end, `close` (`stopListening`).
- Wherever it shows, in the reader and on the haftarah's page, its text grows to 200% at most, as the reader's bottom bar's (§9 Reader, guided): `ListenBar` holds itself to it.
- The app bar's Listen button reads `stopListening` with `stop_circle_outlined` while the player shows.

### 6.29 Bookmarks and notes (lib/features/notes/)

**The verse's marks** (`VerseMarks`, scripture_text.dart): after the verse number, wherever the verse shows it (the Torah's verse, and the Targum in the guided reader's Targum step; never the full text's Targum beneath its verse), in the number's size and in primary, the techelet of the scroll's note marks (`dimInk` with a dimmed verse): a ribbon 0.46 × 0.72 of the number's size, notched at its foot, for a bookmark, and a dot 0.34 across at the middle of the number's letters for a note, ribbon first, 0.28 apart and 0.28 from the number. They stand on the baseline (a WidgetSpan above it). In the full text they are joined to the number by a word joiner, and to the verse by its no-break space; in the guided reader's margin they follow the number, or go beneath it where the margin has no room for both and 0.2 of the verse's size clear of the verse (`gutterClearance`; a number of two letters, and large text). They scale with the text once, as the number does. With numbers hidden, they lead the verse. The verse's label ends "Bookmarked", "With your note".

**The list** (`/notes`, over the tabs; `/notes?week=5787:1` for a week's parsha): `notesTitle` in the app bar, in the 720 column.
- A heading per book (one per parsha, filtered): the Hebrew name in FRL 600 20 onSurface, then in the English UI the English name in titleSmall onSurfaceVariant, one paragraph; a level-2 heading; 8 above the first, 28 above the rest, 4 below. Filtered, the parsha's name (`parshaLabel`).
- Per chapter, `chapterLabel` ("Chapter 3", "פרק ג") in titleSmall onSurfaceVariant with tabular figures, a level-3 heading, 16 above and 8 below; then a PaperGroup of its verses, hairlines inset 54.
- **Row:** padding start 16, vertical 12; where a row's icon sits (a 38 slot), centred on the reference's line, `bookmark` in primary for a bookmark, or `sticky_note_2_outlined` in onSurfaceVariant for a note alone; then the reference in titleSmall onSurfaceVariant with tabular figures, 4, the verse in the scripture font 20 / 1.7 onSurface, right to left, without cantillation (two lines), 4, and the note in bodyLarge onSurface in its own direction (four lines). Nothing is cut short once the text is enlarged. At the end, a `more_vert` IconButton (`verseOptions`), its glyph on the paper's edge as a paper row's menu's.
- A tap opens the full text at the verse (§4.7): in the week of this year's cycle that reads it, or the filtered week. The menu button, a long press, a secondary click, Shift+F10 or the menu key open the verse's options (§6.27). One item to screen readers: the reference, `verseBookmarked`, the verse spoken as the reader's are, tagged `he`, and `yourNoteLabel`, with the `verseOptions` action and the long press; the menu button is an item of its own.
- Empty: the empty state (§6.22) with `notesEmpty`, or filtered `notesEmptyParsha`. Filtered, a centred Text `notesShowAll` ends the page, 24 below.

**On a week's page:** while its parsha has any, a PaperRow (`bookmarks_outlined`, `parshaNotes`, and beneath it `notesCount` · `bookmarksCount`) to the filtered list, in the page's second PaperGroup between the haftarah and the discussion (§9 Parsha). The whole list is a `bookmarks_outlined` IconButton (tooltip `notesTitle`) in the Parsha tab's app bar from 600 dp, between All parshiyot and search (on a phone it gives its room to the title revealed on scrolling), and the second item of the week's menu (`notesTitle`), after Full text and above the hairline that sets marking and clearing apart (§9 Parsha).

### 6.30 Home-screen widgets (Android and iOS)

The week's title page in miniature, on the home screen: the calmest reminder there is, with nothing to tick and nothing asked on Shabbat (DESIGN.md §5). The app works out what it shows (`lib/services/home_widget_sync.dart`); the widgets only lay it out: Android's in `ParshaWidgetProvider.kt` with `res/layout/widget_parsha_small.xml` and `widget_parsha_medium.xml`, iOS's in `ios/ParshaWidget/ParshaWidget.swift`.

**Sizes**
- **Small** (about 2×2 cells; iOS `systemSmall`): the eyebrow (`parshatHashavua`; `erevShabbat` from midday on Friday, and `erevYomTov` from midday on the eve of a Yom Tov that is not Shabbat, as Today's; `simchatTorahEyebrow` for Vezot HaBerachah), the parsha's Hebrew name (pointed unless the reader hides vowels) and, in the English UI, its transliteration in the reader's style (the Hebrew UI names it in Hebrew alone, as Today does), then three bars and `aliyotProgress` ("2 of 7 aliyot").
- **Medium** (about 4×2; iOS `systemMedium`; where Android's widget opens): the small widget's column, a 1 px hairline with 16 either side, and beside it the day's reading in one line or two (`widgetToday` "Today: Shlishi", `widgetCatchUp` "Catching up: Shlishi – Revi’i" while aliyot planned before are unread, `todayDone`, `widgetNothingToday`, `widgetPaused`, `widgetWeekComplete`, `widgetTishaBav`), and under it **Continue**: the label of Today's button ("Continue · Shlishi, Targum", `startAt` before anything is read), in primary with a forward chevron, 48 dp (44 pt) tall. It is gone once the week is complete.
- **Tisha B'Av** with no reading planned on it (`WidgetDayKind.tishaBav`), and with a city for Shabbat times on a day the device keeps its clock, its eve from sunset, as Today: the eyebrow `tishaBavTitle`, the bars and `aliyotProgress` as they stand, and on the medium widget `widgetTishaBav` ("Torah study is set aside today") with no Continue. The app gives the day a week of its own without a `next`, so the widgets, which show Continue wherever a week has one, need no rule of their own; nor does the day greet.
- **Day of rest** (Shabbat and Yom Tov, by the reader's days of Yom Tov): no bars and no Continue; the candles (§7.6) at 22 in `rest`, 6, and the day's greeting as Today's (`shabbatShalom`, `chagSameach`, `shanaTova`, `gmarChatimaTova`) in up to two lines (three, smaller, in the narrowest Android widget), with the parsha read that day.
- **Days over** (the app not opened since the last day it gave): on a weekday, the last week's parsha and `widgetStale`, no bars; on Shabbat and Yom Tov, which the app gives for about four months beyond, the candles and the greeting alone, asking nothing. **Before onboarding:** the app's name in primary and "Open Shnayim Mikrah to begin." (native strings, in the device's language).

**Colour:** the app's light and dark tokens (§3), following the system's appearance (`values-night`, the colour assets' Dark appearance), never the wallpaper's dynamic colours: `paper`, the eyebrow in `secondary`, the Hebrew name in `primary`, the transliteration and the day's reading in `onSurface`, other lines in `onSurfaceVariant`, and the bars in `ringMikrah1`, `ringMikrah2` and `ringTargum` on `ringTrack`, the rings' order. Android draws the card with a 1 px `hairline`, at the system's widget radius from Android 12 (16 dp before it); iOS sets `paper` as the widget's container background, at the system's corners. `test/app/home_widget_platform_test.dart` checks every colour against `lib/ui/theme/palette.dart`.

**Type**
- iOS bundles the display serifs in the extension (Frank Ruhl Libre 500 and 600, EB Garamond 500): the Hebrew name FRL 500 28, the transliteration EBG 500 18, the greeting EBG 500 18 (FRL 500 17 in the Hebrew UI); the lines are the system's 12–14, scaled with the reader's text size as the serifs are (`@ScaledMetric`). The eyebrow is the one place the widget has no room for the app's: EBG small capitals at 18 would be set far smaller in the small widget, below §4's floor, so it is set in the system's serif (New York), 600 12 in capitals tracked 0.6, which is drawn to be read at that size (FRL 600 14 in the Hebrew UI).
- Android's launcher can't load an app's fonts, so the widget uses the system's: the eyebrow serif bold 11sp in capitals spaced 0.1 (13sp, unspaced, in Hebrew), the Hebrew name serif 24sp, the transliteration serif 15sp, the greeting serif 16sp, the lines sans 12–13sp.
- The eyebrow and the names keep to one line, set smaller rather than cut short (Android 8 and later autosize them, within boxes sized in sp; iOS scales them down), so a long name such as Vayakhel-Pekudei fits the small widget. The greeting takes up to two lines, broken between words, and is set smaller too where even two are too narrow ("G'mar Chatimah Tovah", "גמר חתימה טובה"); in the narrowest Android widget, about 110 dp wide, it may take a third, within the same box, rather than lose a word.

**Layout:** padding 16; the bars 4 thick and 3 apart, with round ends, 10 below the names and filling from the start; `aliyotProgress` 4 below them. The whole widget follows the app's language, not the device's: in the Hebrew UI it is mirrored, the bars fill from the right and the chevron points left.

**Short widgets:** where Android's widget is too short for all of it at the system's text size (two rows in landscape, or the largest text sizes), it leaves lines out rather than squeeze or cut them, in this order: `aliyotProgress` (the bars still show it), the eyebrow, the transliteration, on the medium widget the day's reading (Continue stays), and on a day of rest or with a note the parsha's name; a reading day always keeps the Hebrew name and the bars. At the app's text size the small widget shows everything from about 154 dp tall, and the least from 96. Android works out each of these heights from the dimensions the layouts are set in (`res/values/widget_styles.xml`), at the system's text size, and from Android 12 hands the launcher a layout for each, which picks the fullest that fits; before it, the widget's size in each orientation chooses. Whatever is left out, TalkBack reads the whole sentence. iOS gives a widget only its own fixed sizes, so it sets lines smaller to fit (each to its least scale) rather than leave them out, and holds the widget's text to the largest of the standard text sizes (xxxLarge), beyond which the small widget has no room; VoiceOver reads the whole sentence.

**Turning:** the widget can't run the app's code, so the app sends a timeline: an entry for each day from today through next week's Shabbat, and through a Yom Tov straight after it (about 9 to 15, more over the festivals), every string in the app's language and the week's progress as it stands, with a link for each tap; and the dates of the days of rest for about four months after, each with its greeting (all under 8 KB). An entry is for the app's day, which turns three hours after midnight, counted in hours that pass as the app counts them (so on the night the clocks go forward, at 4 o'clock); one may end sooner, at midday on Friday and on the eve of Yom Tov (the eyebrow), and with a city for Shabbat times on a day the device keeps its clock, at candle-lighting on the eve and as the days of rest end, by the reader's own times, and at sunset on the eve of a quiet Tisha B'Av, as Today turns. The app sends a new timeline at launch, on resuming, and within a second of any change to the progress or the settings it shows. Android updates the widget at each day boundary through the day after its last, at the start and end of each day of rest after it, and each time an entry ends (inexact alarms, armed again by each update and after a reboot), and hourly as a safety net; iOS's timeline has an entry for each of those moments.

**Taps:** the widget opens Today; Continue opens the reader where Today's button leads. Like a shortcut on the app's icon, each names a page (`shnayimmikrah://widget/today`, `…/continue`), and the app opens it in the current week as it is when tapped, over Today.

**Preview:** Android 12 and later show `widget_parsha_preview.xml` in the picker, the medium widget for a reader partway through Bereshit, in the device's language and theme; older launchers show `drawable-nodpi/widget_preview.png` (`tool/branding/make_widget_preview.py`). iOS's gallery shows the same reader, or the reader's own week once the app has sent it.

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
   - `scale` grows them with the text, lozenges and gaps alike: the aliyah ribbon's mini pips grow to 2× (12 with gap 6 at 200%, §6.16), as the week strip's glyphs and the Torah map's icons grow to 1.5× (§6.13, §6.14); none of them shrinks with text under 100%;
   - done: filled in ringMikrah1 / ringMikrah2 / ringTargum;
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
   - `help_outline` is drawn with `AppIcon` (lib/ui/widgets/app_icon.dart), which keeps it unmirrored in the Hebrew UI: Material mirrors its question mark for Arabic, but Hebrew writes "?" as English does.
8. **App icon** (critical, D1). `tool/branding/make_icon.py` writes `assets/branding/icon.svg` plus all PNGs.

   **Shaping**
   - Use `uharfbuzz` with FrankRuhlLibre-Bold.ttf. Text "שמו״ת" = U+05E9 U+05DE U+05D5 U+05F4 U+05EA, added with `buf.add_codepoints`, direction 'rtl', script 'Hebr', language 'he'.
   - **Assert** that the output clusters in visual order are `[4,3,2,1,0]`, i.e. ש is the rightmost glyph. Fail the build otherwise.
   - Draw the outlines with fontTools `SVGPathPen` and rasterize with `cairosvg`.

   **Master** (1024², opaque):
   - background: a vertical linear gradient from #23497F (top) to #16315C (bottom);
   - text: font size 300 px (letters 177 px tall, about 744 px wide), fill #F6F0E2, centred horizontally, baseline y=500;
   - three rules, each 440×26 with radius 13 at x 292–732, at y 580, 628 and 676, filled #F6F0E2, #F6F0E2, #D2A64A (two Mikrah and the Targum);
   - the group is vertically centred.
   - Contrast: cream on gradient 7.93–11.35; gold rule 5.71.

   **Variants**
   - Android adaptive foreground: the same group, transparent background, scaled 0.70 about (512,512) so every point lies within 300 px of the centre (inside the 66/108 safe circle). The background layer is solid #1D3F75.
   - Monochrome: the foreground with every shape #FFFFFF.
   - iOS: the master without alpha.
   - Web: Icon-192/512 from the master; maskable 192/512 with the group scaled 0.90 on the full-bleed gradient.
   - Sizes ≤32 px (favicon.png, and the favicon.ico and Windows .ico entries at 16/20/24/32): the three rules only, each 62.5% of the canvas wide and 9.4% high, gaps 7.8%, vertically centred, on the gradient with corner radius 18.75%.
   - The Windows .ico also carries 40, 48, 64 and 256, and favicon.ico carries 48: the master's art on the gradient, with the same 18.75% corners (transparent outside them) rather than the master's square. Every entry then has one shape, so the icon doesn't change outline as Windows switches entries between views and DPI settings.
   - Android status bar (`ic_stat_reminder`, a 24 dp vector drawn as a white silhouette): the three rules alone, 2.7 high with round ends, at y 5.7, 10.65 and 15.6. The two Mikrah rules span x 3–21. The Targum's gold is lost in white, so its rule is 60% as long (x 10.2–21), aligned to the right like the last line of a Hebrew paragraph: three equal bars read as a menu icon. To be confirmed with the owner.
   - The MSIX package matches the .ico size for size. The msix tool makes every icon from `windows/msix/logo.png`: the .ico's larger tile at 1240², the size of the largest icon the tool makes (the large tile at 400%). `tool/windows/make_msix.sh` then replaces the app icons of 32 px and below (`windows/msix/Images`: 16, 20, 24, 30 and 32, plated and unplated) with the three rules alone.
   - Launch screens (`splash_logo.png`, read at 4×, so 288 dp or pt): a transparent 1152² canvas with the in-app mark's tile in the middle, the master on the gradient, 576 px wide with 22% corners. The corners reach 355 px from the centre, inside the 384 px (192 dp) circle that Android 12 and later show.
   - Web link preview (`web/og.png`, 1200×630): the About header on surface (#FAF7F0) in a TitlePageFrame at 2×. The mark's tile at 168, then "שניים מקרא ואחד תרגום" in Frank Ruhl Libre Medium 58 primary, a SeferDivider at 2×, and "Shnayim Mikrah v’Echad Targum" in EB Garamond Medium 36 onSurfaceVariant, all within the middle 630 px so a square crop keeps them.
   - Google Play's feature graphic (`store/play/feature-graphic.png`, 1024×500, opaque; `make_icon.py --feature-graphic`): the link preview's title block at 0.85 in the same frame, its letters centred and everything but the frame within the middle 70% each way.
   - Store screenshots (`tool/store/frame.py`, from the capture harness's store modes): each capture at 82% of the canvas's height, its corners rounded (48 px on a 1920 px canvas, in proportion on the others) with a 1 px hairline round it, on surface (#FAF7F0), under a two-line headline in primary: EB Garamond Medium, or Frank Ruhl Libre Medium in Hebrew, 64 px on a 1920 px canvas, every headline of a set on the same baselines and at the same size. Each headline is broken by hand where it reads best, after its comma or colon where it has one, so that no phrase ("aliyah by aliyah") is split; and it says only what that device's screenshot shows (side by side only on the iPad, whose full text sets the Targum beside each verse).
   - Web shortcut icons (`web/icons/shortcut-*.png`, 192²): the navigation's `today` and `donut_large` glyphs in #F6F0E2, their em box 58% of the favicons' tile.
   - Shortcuts on the app's icon (`lib/services/app_shortcuts.dart`): Android's wear the launcher icon itself (`@mipmap/ic_launcher`). iOS draws a shortcut's icon as a template, from its alpha alone in the menu's ink, so iOS's wear `ShortcutMark` (`ios/Runner/Assets.xcassets`, 35 pt at 2× and 3×): the mark alone in one ink on transparent, centred and 94% of the canvas wide.
   - Web loading screen: the in-app mark's tile as inline SVG in `web/index.html`, 96 px.

   Then run `dart run flutter_launcher_icons`, `dart run flutter_native_splash:create` and `make_icon.py --post` (the full command is above `flutter_launcher_icons` in pubspec.yaml).

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
- The Android slides mirror in RTL, as Android's own do: in Hebrew the next page arrives from the left (`FadeForwardsDirectionalPageTransitionsBuilder`).
- An Android back swipe keeps the predictive back gesture (on by default from Android 16 for apps targeting it): the page follows the finger and reveals the one beneath, in the framework's `PredictiveBackPageTransitionsBuilder`. Every other push and pop uses the directional slides.

**Tabs:** the incoming tab fades in over 150 ms (`Motion.short`, decelerate) on Android, desktop (Windows and Linux) and the web, whatever its host, as pages fade in there (`tabsFadeOn`), as its indicator moves to it; the tab left goes offstage at once. None in an iOS or macOS app, whose tabs switch without a transition, or with Reduce Motion (the app's or the system's). None while a status message is on show (`statusMessageShown`, feedback.dart): each page's own Scaffold shows it (§6.19), and it carries across unbroken rather than fade out and in with the tab. The tab is heard by screen readers from its first frame (`_TabFadeIn`, lib/app/router.dart).

**Welcome entrance** (§9 Onboarding): once a run, as the app opens on the welcome. A static flag in the welcome's State keeps it from playing again when the page is built anew (back from step 1, or in the other language). One 900 ms controller (`Motion.frame`), each part arriving on decelerate:
- the frame, with its lozenge and the Hebrew title: opacity 0→1 at 0–250 ms, rising 8 px into place (`Transform.translate`);
- the SeferDivider's hairlines draw outward from its lozenge (`progress`) at 150–550 ms;
- the English name and the body fade in at 400–650 ms;
- the Filled button, the restore link and the disclaimer at 550–800 ms.
- The language, the page's own control, is there from the first frame.
- Every fade is `FadeTransition(alwaysIncludeSemantics: true)`, with nothing ignoring the pointer, so the page is tappable, focusable and heard from its first frame.
- With Reduce Motion the controller starts at 1: the page is whole from its first frame.

**Web loading screen** (`web/index.html`): at Flutter's first frame (`flutter-first-frame`), the boot theme-color goes at once (§3.6), and the loading screen, kept above the app's view (`z-index: 1`), fades out over 250 ms on decelerate (`cubic-bezier(0.05, 0.7, 0.1, 1)`). The app beneath takes taps at once (`pointer-events: none`), and screen readers leave the loader (`aria-hidden`); it is removed as the fade ends (`transitionend`, or after 400 ms at the latest). With Reduce Motion, the app's (`data-reduce-motion`) or the system's (`prefers-reduced-motion`), it is removed at once.

**Floating button:** it fades in as it appears (Material's entrance for an extended button, 200 ms), never scaling and turning in as a round one does; the forum's appears so once its discussions come.

**Reduce Motion everywhere:** dialogs, sheets, snackbars, a page's floating button (`floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation`, in `PageScaffold`) and every `PopupMenuButton` (`popUpAnimationStyle: Motion.of(context).style`) appear at once, and ink doesn't spread: `ThemeData.splashFactory` is `PressWash(reduced: true)` (below), whose wash holds 100 ms after a press and goes at once.

**Ink:** none that spreads on Apple platforms (iOS and macOS, in a browser too), which darken a control while it is pressed: `splashFactory` is `PressWash` there, a wash of the press colour over the whole shape of the control (its corners, or its custom border) from the moment it is pressed, which never grows. A quick tap in a scroll view is pressed and released in one frame, before an ink well's highlight can fade in, so the wash holds 50 ms after the press ends and then fades over `Motion.short`; a press held stays washed until it ends. Its colour is the control's pressed overlay (10% of its ink, §6.5), or for the ink wells with none of their own (rows, cards, list tiles) `ThemeData.splashColor`, which, as `highlightColor`, is 10% of onSurface rather than Material's 40% grey. Android keeps Material's `InkSparkle`, and the web and other desktops `InkRipple`.

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
- Parsha: the hero's inner goldLeaf frame rule draws around the card once over 900 ms (`PathMetric.extractPath`), then stays static. It draws when the week is finished while the app is open (the hero has shown it unfinished in this run), once per week, and waits until the hero can be seen; a restarted app shows it static, as the rings show progress without a sweep.
- Sefer: a panel fade of 400 ms.

**Never:** looping, idle or time-based animation anywhere. Nothing at all moves on the rest-day Today. Animate only opacity, transform and CustomPaint progress; never BoxShadow or blur.

## 9. Screen by screen

### Today (today_screen.dart; phone_today, he_today, dark_today, desktop_today)

Remove the AppBar. Everything sits in a SafeArea PageBody (on a day of rest, a scroll view of the same column, 8).

1. **TodayHeader** (12 top):
   - Row of `Expanded(Column)` and a help IconButton (help_outline, tooltip `guideTitle`).
   - The column holds a running head in bodySmall w500 onSurfaceVariant (`'${names.dateLong(civil)} · ${names.hebrewDate(today)}'`; in the Hebrew UI the Hebrew date first, `'${names.weekday(today)}, ${names.hebrewDate(today)} · ${names.dateMonthDay(civil)}'`), a 2 gap, and the masthead in headlineMedium: `appTitle`, or `navToday` ("Today", "היום") from 1200 dp, where the extended rail beside the page carries the wordmark (§6.10), as every other tab titles its page with its name; on reading days and days of rest alike. `today` is the day shown, the reading day or the day of rest (8), and gives the Hebrew date with its weekday; `civil` gives the Gregorian one. On a reading day `civil` is `today`, so that on Motzaei Shabbat after nightfall the head reads "Sunday, October 11 · 30 Tishrei 5787", as the hero's days to Shabbat, Today's reading and the week strip count. On a day of rest it is the device's date (`civilDateProvider`, turning at 3 a.m. as the reading day does), which differs only on its eve from candle-lighting, when by the Hebrew reckoning the day of rest has begun: "Friday, October 9 · 29 Tishrei 5787" (in Hebrew "יום שבת, כ״ט בתשרי תשפ״ז · 9 באוקטובר").
   - A line of parts between middle dots (the running head, the hero's reference and reading day, and the Today card's facts) sets as many parts to a line as fit, so it breaks between parts rather than inside one ("October / 10", "96 / verses"), and starts or ends no line with a dot. A part too long for a line of its own, as with large text, breaks after a comma before anywhere else ("Read on Shabbat, / October 10"), never between a number and the word after it ("about / 33 min", not "about 33 / min"), and never inside a closed range, so that a reference breaks after its book ("Deuteronomy / 33:8–12", not "Deuteronomy 33:8– / 12") (`DotLine`, lib/ui/widgets/lines.dart). It measures its parts in the ambient style merged with its own, as they are drawn, so a list tile's subtitle needs no style of its own.
   - The masthead is not a heading; the parsha name stays heading level 1.
2. Paused banner and open-previous-week card: NoticeBanner style.
   - On the web, above them all, the offer of a new version (§6.20, New version), until put away for the session.
   - Resuming from the paused banner says `pauseEnded` in a status message. A pause that ended while the app was closed (not one made or changed once it was over, by its stamp's reading day: entered after the fact, or ended early) is welcomed instead, on the first reading day the app is opened after it, until the reader puts it away (a close button, `actionDismiss`; `pauseEndSeen`) or reads again: a NoticeBanner titled `pauseEnded` with `pauseEndedOn(date)`, a Tonal `pauseEndedStart` or `pauseEndedContinue` to `/read/{id}/{next}`, and a TextButton `catchUpOn(name)` to last week while it can still count (`WeekStatus.inProgress`, within its late window, or `overdue`, still to be finished with the next parsha). Where it offers last week, the open-previous-week card waits until it is put away; where it doesn't, as for Vezot HaBerachah, asked about after Simchat Torah though it can no longer count late, the card stands beneath it.
   - **After-Shabbat check-in** (the open-previous-week card's first form): after a Shabbat whose parsha is unfinished, on the first reading day after it (`checkInDay`: past Tisha B'Av straight after it, whatever is planned on the fast, since its "Shavua tov" is not said then, SA OC 554:20) and on each one after that while the week can still count as late (`WeekStatus.inProgress`), until it is answered (`checkInAnsweredFor`); never for a week that counts neither way (`WeekStatus.transparent`: begun before the reader joined, or paused). `checkInTitle(name)` (`checkInTitleShabbatYomTov(name)` when the days of rest after that Shabbat run on into Yom Tov, by the reader's days of Yom Tov; `checkInQuestion`) and `checkInBody`, then a TextButton `checkInNotThisTime`, a TextButton `checkInPick` and a Tonal `checkInFinished(name)` (its label balanced where it wraps), each naming last week's parsha (both of a double portion, by its combined name), as this week's stands beneath. Vezot HaBerachah, read on Simchat Torah, a Yom Tov (MB 285:18), is asked about too: from the first reading day after it until the next parsha is read, as it has no late window: Bereshit, the Shabbat after, or Noach where Bereshit's Shabbat is among the days of rest straight after Simchat Torah (outside Israel when Simchat Torah is a Friday; `openPreviousWeekProvider` then gives Vezot HaBerachah, two weeks back, before Bereshit, whose check-in follows once it is answered). It has `checkInTitleVezot(name)` and a Tonal `checkInFinishedYomTov(name)` (its "Yom Tov" held together by a no-break space, so that at large text "Tov" never stands alone), which logs it for Simchat Torah, on time; for a reader to whom Simchat Torah was not Yom Tov (one day of Yom Tov, the reading outside Israel), `checkInTitleSimchatTorah(name)` and `checkInFinishedSimchatTorah(name)`, as its sheet dates that day plainly. Choose aliyot opens one sheet, titled with the same question: each aliyah not yet read as a checked CheckboxListTile with its reference and verses (a `DotLine`, so that at large text "21 verses" goes whole under a long Hebrew range rather than leave "21" behind), the haftarah too where it is shown and not logged, the line `checkInReadOnShabbat` (`checkInReadOnYomTov` for Simchat Torah, or a day of Yom Tov chosen; `checkInReadOn` once another day is chosen; a `DotLine` too, broken after its comma, never inside the date) beside a TextButton `changeDate` (`pickReadDate`: PaperRows on one PaperGroup within the sheet's padding (§6.19), with no chevron, as each chooses in place: Today (`today_outlined`), Yesterday (`history`), `whenOnShabbat` and a `whenOnYomTov` row (`wb_sunny_outlined`) for each Yom Tov of the week before today, of the days of rest that run on from its Shabbat (Shavuot on the Sunday after), and of the day of rest before the week where it is a Yom Tov (Simchat Torah, before the Diaspora's week of Bereshit that begins on Monday, so that its row's title and the check-in's line, "Read on Yom Tov", agree), latest first, by the reader's days of Yom Tov and never Yom Kippur, each dated as a day of the practice (`practiceDate`, broken only after its comma), Yesterday left out where it is named as the Shabbat or Yom Tov it was. Then the other days since the Shabbat afternoon before the week (that Shabbat a plain day of the list, as `whenOnShabbat` is this week's): six or fewer (`kListedReadDays`), each a row of its own, latest first, on a second PaperGroup 12 below, with no icon to repeat down the rows, dated as the rows above date theirs over its day in the other calendar, as a week's header gives it ("Wednesday, October 7" over "26 Tishrei"; "יום רביעי, כ״ו בתשרי" over "7 באוקטובר"); more (as in a week of the usual shape on the Sunday and Monday after its Shabbat, which leave seven: Friday back to the Shabbat before), `whenPickDate` (`edit_calendar_outlined`) ends the first group, and its date picker marks the app's reading day as today (`currentDate`), not the device's date, from which it differs until 3 a.m. and on Shabbat and Yom Tov, which it passes over. It scrolls where large text makes it taller than the screen), and a Filled `logReading` that logs every checked reading in one change. Logging, either way, answers the check-in and says so in a status message with Undo, which puts the week and the question back as they were.
   - Within the late window, when the card doesn't ask the check-in, it says when the window closes, by the day it is: `openWeekLate(when, date)`, "Finish by tonight and it still counts." on its last day, "Finish by tomorrow night and it still counts." on the day before, and otherwise "Finish by the end of Tuesday, October 13, and it still counts." (`lateDeadlineDay`; the date by `Names.practiceDate`). The day is the last reading day of the window (`lastLateReadingDay`): where the window's last day is Shabbat or Yom Tov (Pesach on the Tuesday), the reading day before it, since reading logged on a day of rest counts for the next reading day. Where that day is the eve of Shabbat or Yom Tov, the window closes as the day of rest begins, not at night: `openWeekLateEve(holiday, when, date)`, "Finish before Yom Tov begins this evening and it still counts.", "… begins tomorrow evening …", "Finish before Yom Kippur begins on Tuesday, September 18, and it still counts." (`restBeginsAfter`).
   - After the late window, a week that can still be finished with the next parsha says so by the reader's parsha streak: `openWeekRestore(name, next, count)` with one, `openWeekRestoreZero` without.
   - After the paused banner, the **divergence notice**: a NoticeBanner with `info_outline` and the action below. It appears in a week when Israel and the Diaspora read different portions, for a reader whose reading and days of Yom Tov follow different places:
     - a visitor to Israel (Israel's reading, two days of Yom Tov): `readingDivergence`, with a row of TextButtons at the end, in the order the text speaks of them: `readingDivergenceOpen` to the home portion's week (last week's in Israel; none in a week that holds it), and `readingDivergenceChange` ("Change the reading") to Settings → Reading & customs (`/settings/reading`);
     - an Israeli abroad (the Diaspora's reading, one day): `readingDivergenceAhead`, with no action.
     - Either has a close button (`actionDismiss`), which puts it away for the week (`divergenceDismissedFor`, the week's id, on this device only): it is told again the next week if the two schedules still differ.
   - The open-previous-week card also shows a week whose haftarah, which counts, is all that is left: it adds `openWeekHaftarahLeft` and opens the haftarah.
   - **Tisha B'Av** with no reading planned on it (`ReadingPlanner.isQuietTishaBav`, the default): no welcome back and no open-previous-week card, which invite reading; both come back the next day. The fast begins at sunset on its eve: with a city chosen for Shabbat times and the device on its clock, Today is quiet from sunset there (`fastBegunProvider`), in every way set out here for the fast, its card naming the day after the fast as the day the parsha goes on (4); without one, from the morning of the fast, as the day turns. Whatever is planned on the fast, while the check-in waits for the day after it (`awaitsCheckIn`), the open-previous-week card waits too, so that the check-in is the first word about last week.
3. **Hero card** (TitlePageFrame, padding 24, centred):
   - **Eyebrow:** `parshatHashavua` by default; `erevShabbat` on Friday at or after 12:00 local; `erevYomTov(holiday)` at or after 12:00 on the eve of a Yom Tov that is not Shabbat, by the reader's days of Yom Tov (`JewishHolidays.erevYomTov`: "Erev Rosh Hashanah", "Erev Yom Kippur", otherwise "Erev Yom Tov"); `tishaBavTitle` ("Tisha B’Av") on Tisha B'Av with no reading planned on it; "Simchat Torah" when the portion is Vezot HaBerachah.
   - 8 gap, then the Hebrew pointed name: new `Names.portionPointed(p)` = `HebrewText.forDisplay(p.nameHe, nikud: true, teamim: false)`, in hebrewDisplay 46/60 primary. Semantics header level 1 with label `parshaLabel(name)`.
   - English UI: the Latin name in headlineLarge onSurface. Hebrew UI: nothing; the pointed name is the parsha's name, and the line under it gives the reading in Hebrew, so no transliteration is left in a Hebrew page.
   - 4 gap, then bodyMedium onSurfaceVariant: "Genesis 1:1–6:8 · Read on Shabbat, 10 October". Its second part is `names.readOnLabel(week)`, which in the Hebrew UI gives the Hebrew date without the year: "נקראת בשבת, כ״ט בתשרי". Then bodySmall onSurfaceVariant `shabbatInDays` (`simchatTorahInDays` in the week of Vezot HaBerachah), or on Friday `shabbatBeginsTonight` ("Shabbat begins this evening"), or on the eve of a Yom Tov that is not Shabbat `yomTovBeginsTonight(holiday)` ("Rosh Hashanah begins this evening", "Yom Kippur begins this evening", otherwise "Yom Tov begins this evening"), since reading stops then however far off Shabbat is, or Shabbat or Simchat Torah in the long week of Vezot HaBerachah (on Friday, `shabbatBeginsTonight`, and on Erev Sukkot, on Erev Yom Kippur when Haazinu was read before it, and outside Israel on Hoshana Rabbah, `yomTovBeginsTonight`, whatever the day; on Simchat Torah's own eve, "Simchat Torah is tomorrow" says it); on Erev Shabbat and Erev Yom Tov, with a city chosen for Shabbat times and the device on the city's clock, `todayCandleLighting` ("Candle-lighting 4:12 PM") in its place.
   - 16 gap, SeferDivider, 16 gap.
   - Row of ParshaRings 104, a 20 gap, and `Expanded(RingLegend)`. Under the legend, an end-aligned TextButton `allAliyot` ("All aliyot") with a chevron, to /today/week/{id} (within the Today tab). Under 360 dp the rings sit centred above the legend.
   - 20 gap, then a Filled button (52) with `menu_book` and a label naming the destination, full width up to max(360, the rings group's width: the rings, the gap and the legend's natural width with its 40, §6.11), centred: the whole frame where the frame is narrower than that (a phone, a compact window, a tablet at large text), and otherwise centred under the rings, as wide as their group. Let `next = ctx.nextAliyah` (the first aliyah not read, passing over those planned only before the reader joined, unless begun, until the rest are read: so the first aliyah due whenever any are) and `p` = the first ReadingPass of `next` that is not done:
     - nothing read this week: `startAt(name)` = "Start · Rishon";
     - `next` has some passes done: `continueAtPass(name, passLabel(p))` = "Continue · Shlishi, Targum";
     - otherwise: `continueAt(name)`.
     - It routes to `/read/{id}/{next}`; the reader already resumes via `flow.resumeFrom` (reader_screen.dart:318-319). If a unit was marked done without saved positions, derive positions from `isUnitDone` so it resumes at the first unread pass. The guided reader then starts each chunk past the readings of the Hebrew done before it was opened (`ReaderFlow.entryStep`), so "Continue · Shlishi, Targum" goes on from Targum to Targum, and Back retraces that way.
   - **Tisha B'Av** with no reading planned on it: no Filled button, nor the gap above it; the rings, the legend and `allAliyot` stay, so the frame ends under the link. Torah study is set aside on the fast but for the passages of mourning (SA OC 554:1), so nothing on the page invites reading.
   - Delete the outlined "2 of 7 aliyot" button (D10).
   - **Complete state:** the rings and CTA are replaced by the animated frame (§8), titleLarge `weekComplete`, and a marginalia line, `weekCompleteNote` ("Ready to hear it read on Shabbat."; `weekCompleteNoteSimchatTorah` for Vezot HaBerachah). Add a Tonal `readTheHaftarah` if the haftarah is shown and not yet read, and a TextButton.icon `forum_outlined` `discussTheParsha` (its spinner in the icon's place while the discussion opens). On a quiet Tisha B'Av, neither button: the marginalia line ends the page.
   - Centred lines of more than one sentence (`weekComplete`, `restDayBody`) that don't fit on one line give each sentence a line or more of its own, and every centred line that wraps is set as narrow as its number of lines allows, so that no word stands alone on the last line.
4. **Today card** (start-aligned):
   - Eyebrow `todayReadingTitle`, then headlineSmall `names.aliyot(day.aliyot)`, then bodyMedium onSurfaceVariant the verses and minutes of what is left of it (the aliyot not yet read), a line of parts (`DotLine`, 1), as is the catching-up line of facts below.
   - **Catching up** (aliyot planned for earlier days unread, and not paused): Eyebrow `todayCatchUpTitle`, then headlineSmall every aliyah due (`ctx.dueAliyot()`): a run of three or more as `Names.aliyahRange` ("Shlishi – Shevi’i", its dash held to the name before it), otherwise by name, each word whole (§4); then bodyMedium "5 aliyot · 96 verses · about 33 min", the minutes counting only the readings not done (`remainingMinutes`); then a marginalia line honest about the day (§10), never "midweek" after Wednesday. Every line counts the same aliyot, those the card names, today's included:
     - Sunday to Wednesday: `todayBehind`;
     - Thursday: `todayBehindThursday`, that two days remain before Shabbat;
     - Erev Shabbat or Erev Yom Tov (by the reader's days of Yom Tov): `todayLastDayShabbat` or `todayLastDayYomTov`, with the Chumash as the calm alternative, logged after the day that ends the days of rest, as the rest-day page says (8): `todayLastDayShabbatThenYomTov` when Shabbat runs into Yom Tov, `todayLastDayYomTovThenShabbat` when Yom Tov runs into Shabbat;
     - Erev Yom Kippur, whatever the day (Yom Kippur is neither called Yom Tov nor the end of a week, which always has a reading day after it): `todayLastDayYomKippur`, that there is still time after it.
   - 16 gap, then actions:
     - a Tonal `readAliyah(firstUnreadToday)` = "Read Shishi", ONLY when `firstUnreadToday != next` (as while paused, when the hero's button leads to an aliyah planned before). In catch-up mode it is omitted: the hero's button already starts the backlog, at the first aliyah due;
     - a TextButton.icon `import_contacts` `readFromBook`, always. It opens a sheet (`readFromBookTitle`) of the aliyot the card names and has not seen read (every aliyah due when catching up; otherwise today's, paused or not), each a checked CheckboxListTile, then `pickReadDate`, and marks the checked ones in one change. Where it starts a line, it moves by its padding so its icon sits on the text's edge.
     - Never two Filled buttons; never two unlabelled CTAs to different places.
   - Its marginalia lines, like the note under the week strip (5), set their lines evenly (`BalancedText`) and hold a dash to the word before it (`dashHeldToWord`), so that no line starts with one.
   - Done: a check_circle 20 in primary with titleSmall `todayDone`, and the verses without minutes.
   - No reading today: bodyMedium onSurfaceVariant `todayNothingPlanned`.
   - **Paused:** a marginalia line `pausedTodayNote` in place of the catching-up line, under today's reading.
   - **Erev Tisha B'Av** (`JewishHolidays.isTishaBav(today + 1)`): a marginalia line `erevTishaBavNote`.
   - **Tisha B'Av** with no reading planned on it, in place of everything above: the eyebrow `todayReadingTitle` (the title page above names the fast), then bodyMedium onSurfaceVariant `todayTishaBav` ("Torah study is set aside today, apart from the passages of mourning (Iyov, Eicha, parts of Yirmiyahu).") and, while the parsha is unfinished, the day it goes on: `todayTishaBavTomorrow(name)` ("Va’etchanan continues tomorrow.") where the card will have reading tomorrow (aliyot planned for it, or earlier ones to catch up on) and no pause covers it, otherwise `todayTishaBavOn(name, weekday)` ("Va’etchanan continues on Friday.") for the first such day before Shabbat, as with the whole parsha on Erev Shabbat or a pause that runs past the fast, and nothing where there is none. The day after the fast is always a reading day, but the reader's plan need not have reading on it. No aliyot, no catching up, no actions (not even `readFromBook`), no notes. A reader who has turned the setting off gets the day's reading like any other.
5. **WeekStrip card** (§6.13).
   - Its header inside the card: the SectionHeader `weekStripLabel` ("This week’s plan") with the legend button, its words 12 in from the card's 8 (`WeekStrip.cardPadding`), on the line of the other cards' content. Progress frames its strip alike.
   - Under the strip, at most one marginalia line, with a close IconButton (18, onSurfaceVariant, tooltip `actionDismiss`) on its first line's centre, inset like the card's header, its lines balanced: first the grace days spent within the last week, every one not yet told, named together ("Monday and Tuesday were covered by grace days…", `graceUsedNote(count, weekdays, parsha)`, or `graceUsedNoteShort` when finishing this parsha by Shabbat would not earn one back), then today read ahead (`todayAhead`), then yesterday made up today (`caughtUpNote`).
   - A grace day is news once the planned day after it is over without the reading made up. A line tells only what was decided after the day the reader last put it away (`lastStripAck`) or last saw one (`stripNoteShownOn`, recorded while the page is in sight): seen, a line stays for the rest of the day and is not told again.
6. **LedgerCard**, if `showStreaks` (§6.12).
7. **"Also this week" PaperGroup** (`thisWeek`, "ועוד השבוע"), the rest of the week beside the plan the strip's card heads ("This week’s plan"):
   - Haftarah row: `auto_stories_outlined`, title "Haftarah", subtitle the reference, its passages a `DotLine` (`subtitleParts`), broken between passages rather than inside one and never cut short (two lines hold all but Re'eh's for Sephardim on Rosh Chodesh Elul, which takes three on a phone: "Isaiah 54:11–55:5 · Isaiah 66:1" over "Isaiah 66:23 · I Samuel 20:18" over "I Samuel 20:42", today_reeh_rosh_chodesh); a special haftarah in the detail line, by name alone ("Shabbat Machar Chodesh", `Names.specialHaftarah`). Where it displaces the portion's own, only Chabad, whose custom is to read both, is told of the regular haftarah: `haftarahSpecialChabadRegular` ("Shabbat Machar Chodesh · Chabad custom: the regular haftarah too"); the other customs' pages offer it, folded, under its own title (Haftarah below). The week's page has the same row.
   - Discuss row: `forum_outlined`, `discussThisWeek`; while the discussion opens, a spinner in its chevron's place.
   - These replace two separate cards.
8. **Rest day** (`JewishHolidays.isRestDay(date, israel: settings.oneDayYomTov)`, the reader's Yom Tov custom rather than the reading schedule). The reading day is never a day of rest, so this is the device's date (`restDayProvider`), turning at 3 a.m.; with a city chosen for Shabbat times and the device on its clock, it begins at candle-lighting there on its eve (`Zmanim.candleLighting`), and the last day of rest ends as Shabbat ends there (`Zmanim.havdalah`), by the reader's candle-lighting minutes and end of Shabbat (`AppSettings.shabbatCity`), so that Motzaei Shabbat is a reading day for the check-in. Without one it lasts from 3 a.m. to 3 a.m.:
   - The header's running head gives the day of rest's Hebrew date, beside the device's date (1): from candle-lighting on its eve, still the eve's.
   - The hero (TitlePageFrame, padding 40 above and 24 elsewhere, 28 and 16 under 360 dp) shows candles at 48, 16, the day's greeting in displaySmall (`gmarChatimaTova` on Yom Kippur and `shanaTova` on Rosh Hashanah, on Shabbat too; `chagSameach` on the festivals' Yom Tov; otherwise `shabbatShalom`), 20, the eyebrow `parshatHashavua` (`simchatTorahEyebrow` for Vezot HaBerachah), 4, the pointed parsha name in hebrewDisplay 40/52 (heading level 1, `parshaLabel(name)`) and directly under it, in the English UI, the Latin name, as on a reading day's hero (3), a size smaller, in headlineSmall onSurface, for the eye alone, as the heading's label says it; the Hebrew UI, as there, has none. Then 16, and bodyMedium onSurfaceVariant `restDayBody`, or `restDayBodyChag` when the days of rest end with Yom Tov (`restDayBodyYomKippur` with Yom Kippur). The parsha is the week the day falls in: the one read today, or on the Shabbat after a Yom Tov.
   - The title page stands in the space under the header, in the page's 720 column: 16 below the header and 40 above the page's foot, two fifths of the free space above it and three below, as a book's title stands a little above the middle of its page, so that it doesn't sit at the top of an empty screen. Where it is taller than that space, as with large text, it follows the header 16 below it and the page scrolls.
   - No rings, CTAs, notices, Today card, week strip, ledger or "Also this week"; only a TextButton `openTheParsha` to its week, /today/week/{id}.
   - Nothing animates.
   - The wording goes to the rabbinic advisor (DESIGN.md §11).
9. **Desktop ≥1200:**
   - A container of max width 1040 with columns 7/5 and a 24 gap (`PageColumns`, as Progress and the week's page have).
   - Left: any notices, the hero and the Today card. Right: week strip, ledger, "Also this week".
   - The header runs across the container above them, so its help button ends where the columns do, as an app bar's actions end on the column's edge, and the two columns start level under it.
   - Each column is a focus traversal group, so Tab goes down the left column before the right, in the order a screen reader reads them, rather than across to the week strip, which stands higher on the page than the hero's controls.
   - The day of rest keeps the single 720 column: its title page is all there is.
   - 600–1199: a single 720 column.

### Parsha tab / Week overview (week_overview_screen.dart, parsha_tab.dart; phonetall_parsha, phonetall_week, he_parsha)

1. **Header** (no card, start-aligned):
   - Hebrew pointed name in hebrewDisplay 36/48 primary, the page's level-1 heading, labelled `parshaLabel(name)`, which names the route; in the English UI, the Latin name in headlineMedium (the Hebrew UI has none, as on Today);
   - bodyMedium onSurfaceVariant "Genesis 1:1–6:8 · 146 verses", then "Read on Shabbat, 10 October · 29 Tishrei 5787": `names.readOnLabel(week)`, as on Today, and the date in the other calendar (the Gregorian one with its year in the Hebrew UI);
   - the status line (icon plus label) in bodySmall;
   - ParshaRings 88 with RingLegend (`RingsWithLegend`), beside it where it fits and under it otherwise.
   - The app bar shows no title while the name is in sight; once it has scrolled under the app bar, the title (`parshaLabel(name)`; on the Parsha tab, which names it a parsha already, the name alone, "Bereshit" / "בראשית", as the Latin name under the heading gives it) fades in over `Motion.short`, for the eye alone (`PageScaffold.titleRevealed`). It is whole or not at all (`AppBarTitle.wholeOnly`): set down to 75% of its size where the room is short, and left out where even that would cut it, as it only repeats the heading. On a phone every name fits whole but the longest in English under about 404 dp (Acharei Mot-Kedoshim at 360 dp; narrowphone_parsha_scrolled_double), which is left out. It is looked at again whenever the page scrolls and whenever its size or content changes without a scroll (`HeadingReveal.watchHeading`: a resized window, larger text). The Parsha tab's actions: a TextButton `browseAll` ("All parshiyot") to Browse, labelled rather than an icon (its label set smaller rather than crowd the app bar with very large text on a phone), from 600 dp a `bookmarks_outlined` IconButton (tooltip `notesTitle`) to every bookmark and note (§6.29; on a phone the revealed title needs its 48 dp, and the menu's second item leads there), the search button, and the week's menu: `fullTextMode` and `notesTitle`, then under a hairline `markWholeWeek` (while the week is open and unfinished) and `clearWeek` (while any reading is marked), the destructive item last. Clearing asks first (`clearWeekConfirm`), then says so with Undo: `weekCleared` ("Progress for Bereshit cleared").
2. **GroupHeader** with `aliyotProgress` ("2 of 7 aliyot", no digits in the eyebrow, so render it as titleSmall onSurfaceVariant instead of an eyebrow, inset 4 as a GroupHeader is).
3. **One PaperGroup with seven rows** (replaces seven cards), its hairlines inset 72, where the rows' text starts:
   - Leading 40 disc, 16 from the start and 16 before the text: done = primary fill with an onPrimary check 20; otherwise ringTrack fill with the Hebrew ordinal (FRL 600 18, onSurface).
   - Title in titleMedium, e.g. "Rishon" (read out as `aliyahWithName`, "Rishon · aliyah 1"); subtitle bodySmall "1:1–2:3 · 34 verses · about 15 min", without the book, which the header names, so that it keeps to one line on a phone; a second line bodySmall "Planned for Monday":
     - today's aliyot: `plannedForToday` ("Planned for today") in onSurface w700;
     - an aliyah still to read after its day: its day in `overdue`, after a 14 px `hourglass_bottom_rounded` icon (`stillToReadIcon`, as the week strip marks a day still to read), and read as `plannedForOverdue` ("Planned for Wednesday, still to read"; `plannedForShabbatOverdue` for Shabbat morning), since the colour and mark say it to the eye alone. Never for a day that doesn't count: before the reader joined, one a pause covered, any while paused, or in a week not counted (`WeekStatus.transparent`), which stays neutral (§3.4).
   - In a week of two parshiyot read together, the aliyah the second begins in says where, in a line of marginalia under its plan: `secondParshaBegins` ("Pekudei begins at 38:21", under Revi’i of Vayakhel-Pekudei; "פרשת פקודי מתחילה ב־לח, כא"), the verse without the book.
   - The alternative-division note becomes a third line in bodySmall onSurfaceVariant after a 14 px `info_outline` in onSurfaceVariant, 4 before the words ("Some sources use 4:19–26", `aliyahOtherDivision`, in either UI, its verses kept on one line): a line of meta, quieter than the aliyah's name and lines. The mark leads it in the line, on its first line's middle, as the hourglass leads an overdue plan, and grows with the text as that does, so that the two lines wrap alike with large text.
   - Trailing: PassPips (size 12) on the title's line, the reading under way ringed in the row of the aliyah the reading continues at, above the existing overflow menu, in a 52 column 4 from the text and 10 from the end.
   - Large text: where the text between the disc and that column would be narrower than 112 as scaled (`PaperRow.squeezes`, as a PaperRow stacks), the row stacks: the disc and the name on one line, the lines under them the row's full width ("1:1–2:3 · 34 verses", a fact to a line where two don't fit), then the pips at the start and the menu at the end of a line of their own.
   - Tap opens the reader. The row is one button whose value is the state of each reading; the menu keeps its own item.
4. **Second PaperGroup**, 28 below: Haftarah and Discuss rows, as on Today (`HaftarahRow`, `DiscussRow`), and between them, while the parsha has any bookmarks or notes, the row to them (`WeekNotesRow`, §6.29).
5. **Footer:** a centred TextButton "Mark the whole parsha as read", while the week is open and unfinished.
6. **Desktop ≥1200** (desktop_week, deskhe_week, desktop_parsha, and desk1200_parsha, the narrowest: within the Parsha tab beside the extended rail, a pane of 943 and columns of about 356 and 499; a week opened over the tabs fills the 1040 container at 1200 as at 1366):
   - A container of max width 1040, as Today's, with columns 5/7 and a 24 gap (`PageColumns`); the app bar's title, revealed as the name scrolls away, starts on its edge, and its actions end on its other.
   - Start: the header (1), and under it the notice of a week not yet open. End: the aliyot's count (2), with nothing above it, so that it stands level with the Hebrew name, the aliyot (3), the second PaperGroup (4) and the footer (5).
   - Each column is a focus traversal group and a node of its own for screen readers, so both go down the header before the aliyot.
   - 600–1199: a single 720 column, the header over the aliyot as above, a section's gap apart.

**Browse** (browse_screen.dart; phone_browse, phonetall_browse, phone_browse_summer):
- One PaperGroup per book, its hairlines inset 54, under a book header inset 4 (12 above the first, 28 above the rest, 8 below): "בראשית" in FRL 600 20 `secondary`, then "Genesis" in titleSmall onSurfaceVariant (English UI only), and at its end `browseBookParshiyot` ("12 parshiyot") in labelSmall onSurfaceVariant with tabular figures. Where the names and the count don't fit on one line (large text), the count goes under the names, at the start, and each word stays whole. A level-2 heading named in the UI's language.
- Rows (padding start 16, end 16, or 12 before a chevron; vertical 12):
  - leading: a 28 px column, 10 before the text, with the parsha's number in the Torah (1–54) in labelMedium onSurfaceVariant with tabular figures, set on the title's baseline. Read this year (every reading of its week): `check_circle` 18 in primary instead; begun: `timelapse` 18 in primary. Both grow with the text to 1.5× at most;
  - title: the Latin name in EBG 500 20/26 onSurface, with the Hebrew name in FRL 500 18 onSurfaceVariant at the end of its line, on its baseline. When the two don't fit side by side (large text), the Hebrew name goes under the title. Each word of a name is kept whole (`WholeWords`), and a maqaf's words together ("לך־לך"), set smaller only where a word is too wide for the row;
  - subtitle bodySmall onSurfaceVariant, a DotLine: the reference, then the day it is read in this year's cycle (`dateMonthDay`; the Hebrew date without the year in the Hebrew UI). A parsha read together with another this year says so first: "Numbers 19:1–22:1 · Read with Balak · July 17" (`browseReadWith`);
  - a chevron only at 600 dp and wider, centred on the title and subtitle;
  - the `menu_book` icon is removed.
- Tap opens the week within the Parsha tab, by the week's own id (`/parsha/week/5787:39-40`).
- The row is one button; how far the parsha is read is its value (`stateDone`, `weekInProgress`). The number, and the Hebrew name in the English UI, are not read.
- This week's row has a 3 px primary start rule, inside the sheet's hairline and clipped to its corners, and the Eyebrow `browseThisWeek` ("This week") above its title. Two parshiyot read together share one continuous rule and one eyebrow, over the first; the second is still read as this week's.
- The page opens with this week's row in view: after the first frame, unless it already shows whole, `Scrollable.ensureVisible` at alignment 0.3 over `Motion.medium` (at once under Reduce Motion).
- In the Hebrew UI, the Hebrew name is the title (FRL 500 20/28 onSurface) and the Latin name is end-aligned in bodySmall, inside Lang(en).

### Reader, guided (reader_screen.dart; phone_reader, he_reader, dark_reader, desktop_reader)

- App bar, two lines:
  - Eyebrow: the parsha name;
  - titleLarge: "Revi’i · רביעי" in the English UI, "רביעי" in the Hebrew UI.
  - Actions unchanged (Listen, Aa, more).
  - On a wide screen the title starts, and the actions end, where the text does. Screen readers hear the title as the page names itself ("Bereshit · Revi’i").
- Then the AliyahRibbon (§6.16), then a 16 gap, then the PassTrack (§6.17), then the verse.
- Text column: max per LineWidth; side padding 20; top 16.
- Typesetting per §4.7: gold hanging verse number, centred chapter head, section-break marks.
- **_Note** (no Targum or Rashi available; reader_screen.dart:736-760): a NoticeBanner with `info_outline` (replaces tertiaryContainer).
- Bottom bar per §6.18; finished panel per §6.23.
- Desktop: ribbon, track, text and bottom bar all share one centred column.
- Large text: the chrome around the text stops growing before the text does. The app bar's title grows to 1.34× (as Flutter's), and the ribbon, the pass track, the step's title, the bottom bar and Listen's player to 2×, the 200% that WCAG 1.4.4 asks for (`ReaderScreen.chromeMaxTextScale`); past that, only the scripture grows. At 300% on a 320 × 640 phone, the reader opens with the first line of a verse in view above the bottom bar, in either language.
- A week not yet open, previewed from the Parsha screen or the Torah map: a NoticeBanner with `visibility_outlined`, `previewNotOpen(date)`, at the top of the text, above the pass track or the full text's first verse, and scrolling with it, so that it can never squeeze the text off the screen; it too grows to 200% at most. At 300% on a 320 × 640 phone its verse comes beneath it, a scroll away.
- The keyboard shortcuts (F1, or the menu's Keyboard shortcuts): a dialog (§6.19) of rows, the action in bodyMedium and its keys as keycaps at the end. Where the rows run past the dialog's foot (a phone, large text), they scroll with their scrollbar kept in sight, in a 12 band of the end padding clear of the keys, so that a list cut off between two rows isn't taken to be complete.

### Reader, full text (phone_reader_full, desktop_reader_full)

- Verse blocks 20 apart. Targum under each verse with the goldLeaf start rule (§4.7) and no repeated number.
- When Rashi is on: a "רש״י" eyebrow, then the Rashi style.
- Petuchah and setumah marks.
- At the end: a SeferDivider, then a centred Tonal "Mark this aliyah as read" (the existing label, which the tests rely on).
- Focus mode per §4.7.
- **Parallel columns** (`ParallelVerse`, scripture_text.dart; desktop_reader_full): when the Targum (or, without it, the translation) is shown, the pane is at least 960 wide, the line width isn't narrow, the Torah is at most 34 px at the system text scale (`ScriptureStyles.parallelColumns`) and Display → Side by side is on (`AppSettings.parallelColumns`, default on; the switch shows in the full text's display sheet only where the columns would show, `ScriptureStyles.parallelFits`, measured on the reader's pane within the window's side insets):
  - the measure is 1160, and the title, ribbon and listen bar keep to it;
  - each verse is a row, right to left: the Torah (flex 6), with the translation and Rashi beneath it in its column, then a 40 gutter, then the Targum (flex 5) without its rule or number, at least 48 tall for its long press; first lines on one baseline;
  - above the first row, the columns' names (`ParallelHeading`): `mikrahLabel` and `targumLabel` (or `translationLabel`) in labelLarge onSurfaceVariant, each where its text begins, over a 1 px hairline as wide as its column, inset as the verses are;
  - the chapter heading, section marks and the verse's block (focus mode, the verse opened at, Listen) span the row; screen readers hear the verse, the Targum, the translation and Rashi, in that order.
- **Whole parsha** (the overflow menu's `wholeParsha` / `oneAliyahAtATime`, full text only; `AppSettings.fullTextWholeParsha`; phone_reader_parsha, desktop_reader_parsha*):
  - one `SliverMainAxisGroup` per aliyah: the `AliyahHeader` pinned while its aliyah is read, its verses built lazily (`SliverList.builder`), then the SeferDivider and the Tonal Mark as read of that aliyah;
  - `AliyahHeader` (whole_parsha.dart): surface, keeping to the text's measure, padding 10 vertical; the Hebrew ordinal in `ordinal` gold, 12, the name in titleMedium onSurface, 12, the verses in bodyMedium onSurfaceVariant with tabular figures (wrapping under the name when they don't fit), and at the end a 20 check in primary once the aliyah is read. A hairline beneath only while the text passes under it. One heading of level 2 to screen readers ("Revi’i, aliyah 4 of 7, Genesis 3:22–4:18, read"); the chapter headings beneath it are level 3;
  - it opens at the aliyah chosen, out of sight until it is there; a ribbon tab scrolls to its aliyah's heading; the title, ribbon and menu follow the aliyah a quarter of the way down the text, or the verse focus mode moves to;
  - focus mode's ↓ and ↑, Listen and the verse opened at run through the whole parsha; a button reached by Tab is brought into view again once the verses before it are built.

### Haftarah (haftarah_screen.dart)

- The same paper layout and verse styling as the full text: the reader's measure between the page's gutters, verses 20 apart.
- Header, under an app bar with no title of its own: Eyebrow "Haftarah · Bereshit", then the reference in headlineSmall, "I Samuel 20:18–42" (the page's level-1 heading), then the special haftarah, "Shabbat Machar Chodesh", in marginalia, its lines balanced where it wraps ("Shabbat Rosh Chodesh, with verses / for Sunday’s Rosh Chodesh").
- A chapter's head (§4.7) where the chapter changes from one verse to the next. A haftarah drawn from more than one book heads each book's verses with its name, set the same way ("הושע" over "Hosea"); one drawn from a single book doesn't name it again.
- For Chabad, where the haftarah's Chabad reading isn't listed and the Ashkenazi and Sephardi readings differ, a NoticeBanner under the header, 16 below it and 24 above the verses, says the Ashkenazi reading is shown (`chabadFallbackNote`; phone_haftarah_chabad has none, as every custom reads Machar Chodesh's alike). A haftarah its customs read alike has none.
- In a week a special haftarah displaces the portion's own, the regular one follows the verses, before the divider: an ExpansionTile under a hairline, titled in titleMedium (a level-2 heading), its lines balanced where it wraps (`BalancedText`, so that "read it too)" never stands alone), over its reference: for Chabad, whose custom is to read both, `regularHaftarahOf` ("Also: the regular haftarah of Bereshit"), open; for the other customs `regularHaftarahSomeRead` ("The regular haftarah of Bereshit (some read it too)"), folded (phone_haftarah_regular). Open, its verses are set as above, their chapters' heads at level 3. Where the note above applies to the regular haftarah, it stands inside it, 8 under its reference and 24 above its verses (phone_haftarah_chabad_regular).
- A haftarah's passages (`Names.passage`, `Names.haftarah`: here, in the week's Haftarah row and in the check-in sheet) hold a book's name of two words on one line ("I Samuel", "שמואל א"), a closed range together ("Ezekiel / 45:16–46:18", never "Ezekiel 45:16– / 46:18"; a Hebrew range across chapters may still break after its spaced dash, §4.6) and each dot to the passage before it, so that no line ends with "I" or starts with "·". The heading, the week's Haftarah row and the check-in sheet set them as a `DotLine`, so that their lines break between passages rather than inside one; screen readers hear the heading as one heading. A passage of one verse, as a haftarah adds, is named by the verse alone: "Isaiah 66:1–24 · I Samuel 20:18 · I Samuel 20:42" (Shabbat Rosh Chodesh on the 30th, phone_haftarah_rosh_chodesh and phone_haftarah_rosh_chodesh_sunday).
- At the end: a SeferDivider and a centred Tonal "Mark the haftarah as read", at most 360 wide. Once read, a check_circle in primary and `haftarahReadOn`, "Read on Thursday, 8 October", over a Text "Mark as not read", which clears it and offers Undo in its status message. The focus moves from one button to the one that takes its place.

### Progress (progress_screen.dart; phonetall_progress, dark_progress, he_progress, desktop_progress)

In order:
1. **LedgerCard** with "Longest" lines.
2. **Grace PaperRow:** `shield_outlined` in grace, `graceAvailable(n)` = "1 grace day available", trailing TextButton `aboutStreaks` (under the title at large text, §6.3). That opens a sheet holding the two explanatory paragraphs, which leave the page; the streak's names the reader's window after Shabbat (`streakExplainer`, by the setting: "by Tuesday night", "by the end of Wednesday", or no clause).
3. **This year**, a card:
   - Eyebrow `thisYear`;
   - when the log holds more than one cycle, ChoiceChips (§6.6) of their years ("5786", "תשפ״ו" in the Hebrew UI) choose the year this card and the Torah map show; for an earlier one the eyebrow reads `earlierYear`, the year bar names its year to screen readers, the map's heading names it too (`torahMapOfYear`, "Torah map · 5786", in plain type as it holds digits; "מפת התורה · תשפ״ו" as an eyebrow in the Hebrew UI), and nothing in the map is current or still to come. The chips sit here rather than over the map, so the first thing they change is under them;
   - headlineSmall `parshiyotOfYear(12, 54)`, "12 of 54 parshiyot". In the year being read, before any of it is finished, a sentence instead of "0 of 54": `yearBeginsWith(name)`, this week's parsha, "Begins with Bereshit" / "מתחילה בפרשת בראשית" (feminine, as its subject is השנה), as long as no earlier week of the year has come due since the reader joined (one missed, one still to finish with the next, or one in its late window): a new year, or a reader who joined partway through it. A reader who joined on Bereshit and read nothing sees "0 of 54 parshiyot" in the week of Vayera, as the make-up list under it offers Bereshit and Noach. An earlier year always shows its count;
   - bodySmall "5787 · 50 verses read twice with Targum", the verses of the year shown;
   - YearBar.
4. **This week’s plan:** the WeekStrip card, framed as on Today (§9 Today, 5): `WeekStrip.cardPadding`, its SectionHeader `weekStripLabel` with the legend button inside the card, its words 12 in from the card's 8 so that they stand on the line of the other cards' content; 28 below This year's card.
5. **Torah map** (§6.14), keeping the info button.
6. **Make-up list:** unchanged content, as a PaperGroup, for this year's weeks only.
7. **Recent weeks:** a PaperGroup. Rows show the name in titleMedium, a status icon plus label in bodySmall (wrapped at the reader's text size with its lines balanced, `BalancedText`, so large text leaves no word alone on its last line: "הושלם / מאוחר יותר"; the labels hold no no-break spaces, which would make a pair one word, set smaller to fit), and the date end-aligned in bodySmall with tabular figures (with the year for a week of another year), then a chevron.
   - A week before the join date with nothing read is left out (the Vezot HaBerakhah of a reader who joined on Simchat Torah).
   - Ten rows, then a centred TextButton `showAllWeeks` ("Show all (45)") that shows the rest in place, passing the keyboard's focus to the first week it adds.
8. **"Life happens":** a PaperRow with a pause icon and `pauseRowBody` that opens the existing pause flow. Its ChoiceChips follow §6.6. While a pause covers today, the row says `pausedBanner` under its title (the last day of the pauses that run on from today's, `pauseCovering`, as Today and Settings say), over a Tonal `endPause`, which ends it as Today's banner does (`resumePause`), and a Text `extendPause`, shown while there is room. Extend opens the one dialog that extends a pause, as Settings' pause row does (`showExtendPause`, pause_setting.dart): titled `extendPauseTitle`, it asks `extendPauseBy` how many days more (1, 3, 7 or 14, `pauseExtensions`: as long as the pause then lasts 30 days in all, counted from its first day, as a new pause may; a pause over before today, even one that today's follows straight on from, is not part of it, since each lasts 30 days on its own and a new one may follow one ended), a week chosen if there is room for one and otherwise the most there is, and shows the new end as the choice changes (`extendPauseUntil`, "The pause will end on …", until it is confirmed); Cancel and a Filled `extendPause` then move the end of the pause covering today (the day the dialog opened, should the day turn while it is open) out to it (`extendPause`), rather than add another. The keyboard's focus moves on to what takes a button's place: the row once End pause ends the pause, End pause once an extension uses up the room for another.
9. **Record** (replaces Milestones, progress_screen.dart:337-376):
   - GroupHeader `recordTitle`;
   - achieved items only, newest first (on the same day, a siyum before the book that completed it), dated by the day each was first reached and never stored (DESIGN.md §4);
   - each row: an 8 px lozenge where a row's icon sits, the title in bodyLarge, the date in bodySmall; hairlines inset 54;
   - a completed sefer adds "חֲזַק חֲזַק וְנִתְחַזֵּק" in FRL 500 17 in `secondary` under its row;
   - a reader who joined partway through a year has `milestoneSiyumFrom`, "Siyum from Parshat Vayera";
   - "Welcome back" (`milestoneComeback`) follows a week missed, made up or paused, never the week the reader joined after it began;
   - with streak numbers hidden, the streak lengths are left out;
   - no locked items, trophies or counts of what remains.
10. **Desktop ≥1200** (desktop_progress, deskhe_progress, desk1200_progress), so that the Torah map stands beside the year rather than below the fold:
   - A container of max width 1040, as Today's, with columns 5/7 and a 24 gap (`PageColumns`); the app bar's title starts on its edge.
   - Start: the LedgerCard and the grace row (1, 2), or the notice that streaks are hidden, This year (3) and This week’s plan (4). End: the Torah map's header, with nothing above it, so that it stands level with the ledger, and the map (5) in four columns, then everything after it (6–9).
   - Each column is a focus traversal group and a node of its own for screen readers, so both go down the streaks, the year and the week before the map.
   - Widened or narrowed across 1200, the page keeps what it holds: a book of the map opened, the weeks shown in full, the keyboard's focus.
   - 600–1199: a single 720 column in the order above, the map a section's gap below the week (in six columns once it is 640 wide, §6.14).

### Community (community_screen.dart, forum_screen.dart, thread_screen.dart, compose_screen.dart, account_screen.dart)

**Home**
- The app bar's account button: a person signed out; signed in, the member's initial on a 32 px disc (`InitialDisc`), with a person on the disc until their profile comes and while it keeps a machine's name ("user_1a2b3c4d"), whose initial would be no one's.
- Demo NoticeBanner (§6.20).
- Featured row (a Card with SeferInkWell, no primaryContainer fill): the Hebrew parsha name in FRL 600 20 primary, titleMedium "This week: Parshat Bereshit", bodySmall "Open the discussion", and a chevron.
- Sign-in: one PaperRow with `info_outline`, text, and a trailing TextButton "Sign in".
- GroupHeader "Forums", then one PaperGroup: icons in onSurfaceVariant, titles titleMedium, descriptions bodySmall onSurface (2 lines), as a thread's excerpt is, and under them, once it comes, the forum's activity as a detail line, "12 discussions · active 3 hours ago" ("No discussions yet" in an empty forum; no "active" until one has been posted in). As the page first loads, the forums wait a moment (1.5 s) for it, still loading, so that no row grows by a line under a finger or a screen reader's cursor as it comes; past that, a forum is listed without it until it comes, or where it can't be had. It is fetched again wherever a forum's discussions change: one begun, this week's opened (which may begin it), and an account deleted with its own. Forums that can't be had leave the error state (§6.22) under the heading, 16 more below it, and the rest of the page as it is.

**Forum**
- The description in bodyMedium onSurfaceVariant.
- Parshat HaShavua first shows this week's card, as on Home, so that forum is never empty.
- GroupHeader "Pinned" and "Recent", each over a PaperGroup of thread rows. A row: title titleMedium with `autoDirection` (in its own direction, from its own start edge, 2 lines), so that a title in the other language starts each of its lines on one edge rather than mid-row; 2 below it the excerpt of its first post (of a question on a verse, its question: §6.21), bodySmall onSurface, in its own direction, from its own start edge and tagged with its language like the title, 2 lines (whole once the text is enlarged), and none where the reader may not see that post; then 4 below it (2 below the title where there is no excerpt), bodySmall onSurfaceVariant "Rivka · 3 hours ago · 4 replies · thanked 12 times" with the name isolated, the thanks only once there are any, on the page's start edge, as the tags are. A pinned or locked thread has a 16 px icon (`push_pin_outlined`, `lock_outline`) and a labelSmall tag ("Pinned", "Locked") above its title, so that the row says so wherever it is met, not only under its group's heading; screen readers hear the tags first. No leading icon or chevron.
- The rows are built only as they scroll into view, each its share of its group's paper (`PaperGroupRow`), as a forum paged through may hold hundreds. Each but the last lays its paper a little past its foot, and each but the first leaves as much of its top bare, so that the row below, painted after it, never covers the foot of its focus ring.
- Empty state per §6.22 with `emptyForum`, its action New discussion; in a locked forum, to a member who may not begin one there, `emptyLockedForum` ("No discussions here yet.") with no action.
- Opened from a link while the forums can't be had, the page says so (§6.22, with All forums after Try again) under "Community" as its title, as a thread names its forum then; while they first load it has no title.
- FAB: extended "New discussion", primaryContainer / onPrimaryContainer, radius 12, elevation 2; its icon alone at large text (§5). FAB only over a non-empty list; the empty state's action stands in for it. None while the discussions load (again too, for another account signed in or out) or can't (§6.22), and the room left for it at the list's end goes with it.

**Thread**
- App bar title: the forum's name (Community where it can't be found), which is no heading and doesn't name the page to a screen reader as it opens. The thread's title is the page's one heading of level 1, in its own language, which names the page (`namesRoute`) and the browser's tab; it is never cut short (fixes D13).
- App bar actions: the Demo tag, Refresh, then More options (`actionMore`) where it has anything to offer: to every member, "Copy link" (`copyLink`) where the build knows the site's address (`AppConfig.webUrl`, from `WEB_URL`) and the discussion is on the community's server (never in the on-device demo, whose discussions are the device's own, so a link would find another's or none), which copies the discussion's address there (`…/community/thread/<id>`) and says `linkCopied` in a status message; then, to a moderator, Pin to top or Unpin, and Lock or Unlock discussion.
- A link to a discussion that isn't there (deleted, or one the reader may not see) says so as a forum's does: titled "Page not found", `threadNotFound` in a centred message with a Tonal "All forums".
- headlineSmall title with `autoDirection`, tagged with its language and starting at its own start edge, as its posts do (and as its forum lists it), then "2 posts" in bodySmall onSurfaceVariant.
- Posts as letters (§6.21). A thread with none yet (a week's discussion before its first post) shows an empty state (§6.22) with no button, the reply box beneath being its action: `noPostsYet`, "No posts yet — share a thought on Parshat Bereshit."
- Posts that can't load: the thread's title stays, where it is known, with the error state (§6.22) 32 under it; no reply box is docked until the posts come. A reply's draft, restored as the page opens, is said to be (`draftRestored`) once the box it is in is docked, above it.
- Composer docked on surface with a top hairline across the pane, apart from the navigation bar's surfaceContainer below it; its content in the 720 column, within the gutters, so it lines up with the posts:
  - a radius-10 outlined field labelled "Write a reply", in the direction of what is typed, or the interface's while empty, growing to 5 lines, or as many as 30% of the screen's visible height holds where that is fewer (large text on a short phone, or with the keyboard up), so that the box never climbs over the app bar; past them, what is written scrolls within the field;
  - a Filled "Reply" 48 high, level with a one-line field and by the last line as it grows, disabled until there is a reply (2 characters); while it is sent, a 20 px spinner read as "Sending…";
  - the field's label is never cut short. Where the button beside the field would leave the label too little room (large text on a phone: 300% on 320 dp, 200% on 360), the button goes under the field, 8 below it, at its end; where even the whole width is too little (300% on 320 dp, or on 360 with Bold text), the label stays on the outline, as it stands when the field has the focus. Both are measured as the label and the button are set, in bold where the device asks for Bold text. Half of a label on the outline (three quarters of its font size, the field setting it one font size high) stands above the field, so at large text the field leaves room above it for what the space above doesn't hold: the 12 under the hairline, or the 8 under the post being answered. It is one field throughout, which keeps the focus and what is written as the button moves (the phone turned);
  - above them, while answering a post, a strip on surfaceContainerLow with a 3 px primary start rule: the reply icon, "Replying to Rivka" (the name isolated) and a close button.
- Editing a post: a dialog whose field is labelled "Your message", up to 10,000 characters (its counter quiet, §6.7), and takes the focus. Save waits for a change, of 2 characters at least, as Reply does. A question on a verse keeps its verse, quoted above the field (§6.21) in at most three lines, 12 above it, and only the question is edited; beside the verse, the close button that takes it out, as Compose's does, after which the field takes the focus, and Save keeps the post without it. That dialog is as wide as the window lets it, up to 560, and scrolls once the text is too large for both.
- Reporting a post: a dialog with the reasons, none chosen at first, then a details field three lines high, its label at the top of them (`alignLabelWithHint`) and its counter quiet (§6.7); Report waits for a reason.

**Compose**
- App bar: leading close, trailing Filled "Post" (height 40, radius 10, its end on the column's edge).
- Post is enabled whenever a forum is chosen and nothing is being sent; while it is sent, a 20 px spinner read as "Sending…". Pressed too soon, it shows under each field what it needs ("The title needs at least 5 characters."), gives the first such field the focus and says the error where the platform takes announcements (elsewhere the error's live region says it). Each error then follows the text and goes once the field is long enough. Ctrl+Enter (⌘Enter) posts too.
- An error from the server about a field (`fieldFor` in community_ui.dart: the title's length; the message's length, links, wording or a duplicate) is shown the same way, and stays until that field's own text changes (not the other field's, nor the window). Only what is about no one field, a rate limit or a failed connection, is a status message.
- The forum: "Forum" in titleSmall onSurfaceVariant over a row of ChoiceChips with the forums' icons (`CommunityScreen.iconFor`), which scrolls sideways out to the column's edges, the one asked for brought into view. From 600 dp, where a mouse can't drag the row, they wrap. Forums that can't be had leave the error state (§6.22) under the label in place of the chips, and Post waits for them.
- The fields in a paper group (a Card, padding 20), outlined, with helpers "At least 5 characters" and "At least 2 characters". Counters stay hidden until 80% of the limit, then "8,000/10,000" in the locale's number format.
- Asked about a verse (§6.27), the title names it ("Question on Genesis 3:22"), and the verse stands between the title and the message, 12 from each: quoted as a post shows it (§6.21), in at most three lines, read-only, never in the field. At its end a close button (`removeVerseQuote`, "Remove the verse"), level with its first line however large the text (`RemovableVerseQuote`: where that line is shorter than the button's 48, the button reaches up into the 12 above rather than push the verse down), takes it out of the question, and the message, which the button stood beside, takes the focus; a status message (`verseQuoteRemoved`, "Verse removed") offers Undo, which puts it back. The message is left empty for the question, which it needs (2 characters) as any message does; posted, the verse goes before it in the post's own form (§6.21), and the message's limit leaves room for it. A draft keeps the verse apart from the message (`{title, quote, body}`), so that it comes back above the field, and a message the member begins with a quote of their own comes back as they wrote it; a draft kept before, its verse at the head of its message, is parted as a post is. A question begun and left as it was, its verse taken out or not, is no draft.
- The title wraps, growing with it so that all of it stays in view rather than scrolling sideways, yet takes no line break: the keyboard's action goes on to the message, and a line break pasted in becomes a space.
- Signed in with a name, the paper begins with "Posting as Rivka" after a 24 px initial disc.
- Until the guidelines are accepted, one line in bodySmall onSurfaceVariant, start-aligned, ending with the link to them (`LinkedText`).
- Post is the app bar's alone, which stays in reach above the keyboard. Once anything is written, Discard draft (Text with `delete_outline`, centred) 16 below the guidelines' line, or below the paper where there is none.

**Lines of facts** (`metaLine`, community_ui.dart): the facts of a thread's row and of a forum's activity are joined by " · ", the dot held to the fact before it by a no-break space, so that a line too long for its row wraps after a dot and none leads a line.

**Inline links** (`LinkedText`, community_ui.dart): a sentence in bodySmall onSurfaceVariant ending with a link in primary w500, always underlined. The link is a WidgetSpan holding a SeferInkWell, so it takes the keyboard focus with the ring (4 px of room either side: the 3 px ring, drawn outside the link, and a hairline clear of the words) and Enter follows it; screen readers read it as a link after the sentence. As a link in running text it is as tall as the line (WCAG 2.5.8's inline exception).

**Account**
- Centred, max width 440 (the app bar's title too). The app bar says "Account & community" in every state.
- Signed out: the app mark at 56, headlineSmall "Sign in", the explanation in marginalia; the email field, then Filled "Email me a code" (the existing label, used by tests); then, centred, "We use your email only to sign you in. Privacy" with the policy as its link.
- The code: the mark and heading again, "We sent a 6-digit code to …" in marginalia (and the demo's hint), the boxes per §6.7, Filled "Sign in", then Text "Resend in 30s", which counts down to "Resend code", and "Use a different email". Where the code went is said once, by that line: no status message repeats it, and screen readers hear it as the step appears (announced, or as a live region where the platform takes no announcements); only a code sent again is said in a status message. One field lies under the boxes, so typing moves on box by box, a pasted code fills all six (digits only), the platform can fill a code it has read, and screen readers meet one field, "6-digit code". The box the next digit goes in shows the focus. The sixth digit signs in. A wrong code is said under the boxes, which keep the focus, and what is typed next replaces it. Sign in (or the keyboard's Done) before all six digits are typed sends nothing: "Enter all 6 digits of the code." is said there instead (`codeIncomplete`), and what is typed next goes on from the digits typed, on every platform: the field never selects all its digits as it takes the focus back from a click on Sign in (`selectAllOnFocus: false`).
- A new account starts with a machine's name ("user_1a2b3c4d"), so signing in leads to a name step: the member's initial at 56 as the name is typed, headlineSmall "Display name", the field (named by the heading, so it shows no label of its own) with the helper "Shown with your posts. 2–40 characters.", and Filled "Save name". The field takes the focus as the step appears, after the code or as the page opens on it. Opened to sign in before a post, the page goes back only once the name is saved; a post never goes out under a machine's name (`ensureSignedIn(named: true)` asks for one first).
- Signed in: a card with the initial on a 56 px disc, the name in titleLarge (or the email until a name is chosen), the email in bodySmall, a Moderator tag (`SeferTag` with `shield_outlined`, 8 below the email), and an edit button that opens a dialog titled "Display name" with the field and Save.
  - Cloud backup: one row, "Back up my progress", with its switch (the row toggles it, and reads as one switch to screen readers: the switch itself, beside Sync now, is no item or tab stop of its own), "Last synced …" as its subtitle and Sync now (`Icons.sync`) beside the switch while backup is on; what backing up does in bodySmall under the group; the notice to update when a newer version wrote the backup.
  - Privacy & safety: "Blocked members (n)", with "You haven’t blocked anyone." under it when there are none, and otherwise a sheet that lists them on one PaperGroup (§6.19), each by their initial disc (§6.21, in the leading slot) and name, in its own direction at the row's start (isolated where it runs the other way; `anonymousMember` for none), with Unblock at the end of the name's line; a moderator's reports. The count shows once it is known: while it loads, or can't, the row says "Blocked members" and still opens the sheet, which says why and offers Try again. An Unblock that fails says why under its member, in the sheet (a status message would sit behind it), and its button waits while it is sent.
  - Account: Sign out, and Delete my account in error's ink. Its dialog (§6.19), at most 560 wide and scrolling at large text, says what goes with the account (its posts, and the cloud backup of the progress, bookmarks and notes among it, whether or not backup is on now: a backup made before stays until the account goes), that a discussion it started stays without its name where others have replied, as the privacy policy says, and that what is on each device stays (`deleteAccountConfirm`). Its actions: "Save a backup file first" (`saveBackupFirst`), which opens Your data, whose Back comes back to the account (from the account shown over the tabs, Your data opens in Settings instead: `openTabPage`; from the account opened by Your data's Cloud backup row, `?from=data`, it goes back to that Your data rather than open a second), Cancel, and the confirmation, Filled error / onError.

### Settings (settings_screen.dart and screens/)

**Top level:** three PaperGroups with GroupHeaders, every leading icon outlined.
- **Practice:** Reading & customs; Reminders; the "Show streak numbers" switch row; "Pause streaks", which opens the pause dialog (no chevron) and, while a pause lasts, says until when (the last day of the pauses that run on from today's, `pauseCovering`) and opens instead Progress's dialog that extends it (`showExtendPause`, §9 Progress 8), with the same choices and the same change, titled `pauseManageTitle` over `pauseManageBody`, and with a Text `resume` ("End pause", as Today's banner ends it, `resumePause`) before Cancel and Extend. A pause with no room left (30 days) says `pauseAtMost` in its place, with only End pause and Cancel.
- The rows' subtitles are never cut short, however narrow the phone and long the language's.
- **Reading:** Display; Accessibility.
- **You:** Account & community ("Signed in as …", or `settingsAccountDesc`, "Sign in to post, say todah or report"); Your data; Language. Language is ONE row whose value is Device / English / עברית (a language's name tagged with its own language, `PaperRow.valueLocale`); it opens a choice sheet (`showChoiceSheet`, below), over the navigation bar, of the same paper radio rows (each language's name tagged with its own language, `Choice.locale`), which closes as one is chosen, the chosen one too, and replaces the three inline radios. The app takes the language chosen as the sheet closes: an arrow key moves the choice but doesn't turn the whole interface, and the sheet with it, under the keys.
- **About:**
  - "How it works": the guide (`school_outlined`), `guideTitle` value changed (§10);
  - "About this app": `settingsAbout` value changed, with "Version, sources, privacy" under it.
  - This resolves D15.

**Rows of a settings page** (`settings_widgets.dart`)
- `SettingsPage(paper: true)` stands its paper on the gutters; pages not yet set in paper keep `PageBody.tilePadding`, and a `ChoiceGroup` on them takes a 16 margin.
- `ChoiceGroup`: a `SettingHeading` (level 2, a GroupHeader; or level 3, a subheading in titleMedium onSurface for one of several settings in a section), its help in bodyMedium onSurfaceVariant or, with `helpIsSource`, a `SourceNote` (marginalia on surfaceContainerLow, radius 12, padding 12; outlined in high contrast), or a `source`'s note and then the help, then radio rows on one PaperGroup (a RadioListTile underneath, its text where a PaperRow's starts, ringed rather than washed when focused) or, `segmented`, a SegmentedButton (§6.8). `prominent`, for a question on a page of its own (onboarding's steps): the question in headlineSmall as a level-2 heading, plain help only, and the options as paper radio cards (§9 Onboarding).
- `showChoiceSheet`: for a setting whose row shows its choice (a PaperRow with a chevron), the options in a sheet over the whole window (`useRootNavigator`): its `SheetTitle`, then the same radio rows on one PaperGroup, inset by the sheet's padding and scrolling at large text, each title balanced over its lines (`BalancedText`), so that one large text wraps leaves no word alone on its last ("15 minutes / before sunset"). A tap, Space or Enter chooses and closes the sheet, on the choice already made as well (its radio is toggleable, and the rows are radios of the choices' places, so that the group's null means only that, never a choice of none); the arrow keys move the choice from row to row, applying each, and leave it open, so a keyboard can try them in turn, then Enter, Space or Escape closes it.
- `SwitchRow`: a PaperRow whose whole row toggles its switch, read as one switch; its description is never cut short; disabled with no `onChanged`, when its title and icon are dimmed to 38% as Material dims a disabled control's (the switch shows it in its own way). Its description is not dimmed: a disabled row's says why it can't be changed (`settingOnInDevice`, "On in your device’s settings"), in onSurfaceVariant at its full contrast, as information for readers who often have low vision rather than an inactive control's label.
  - A switch for a setting the device can turn on too (Reduce motion, Bold text), while the device has it on, is on and disabled, with `settingOnInDevice` ("On in your device’s settings") in place of its description: the device's is in force whatever the app's says. The app's MediaQuery has each on where either turns it on, so the switch reads the device's own from `DeviceAccessibility` (lib/app/device_accessibility.dart).

**Display**
- The preview becomes a paper "page" showing a chapter head, two verses, a Targum line and a setumah mark. It reflects settings live and is pinned at the top: `SliverPersistentHeader`, collapsing 220 → 140.
  - The page is Deuteronomy 14:1–2, a section of its own: the chapter head (§4.7), each verse and its Targum, and the setumah that closes it, at the reader's line width. It is a window on the text, which rises with the settings as the window shrinks and fades where the window cuts it (not in high contrast). A hairline marks the settings passing under it, and the app bar stays flat.
  - It is pinned only where the window is at least 640 high and 16 sp text is no larger than 24 (`SettingsPage.previewPinned`); elsewhere it scrolls away, whole. To screen readers it is one node, "Preview".
- A Match-device switch, then theme swatches (§6.24).
- Sliders per §6.8.
- Toggles in PaperGroups:
  - Text: nikud, ta'amim, ketiv, verse numbers, the Divine Names as ה׳ and אלקים in a verse that leaves the app (`copyDivineName`, `DivineNameSwitch`), justify;
  - Study aids: English, Rashi, Rashi script (NEW);
  - Reading: focus mode, bold (on and disabled while the device's Bold text is on, as a SwitchRow above), keep screen on.
- Line width as a SegmentedButton.
- Scripture fonts as radio rows whose title is "בְּרֵאשִׁית בָּרָא" at 22 in that font, named under it; interface fonts likewise, "Aa Bb אב" in each family, Device font included. Screen readers read the names alone. Every font's regular face is loaded as the page opens (`OptionalFonts.ensureSamples`), so each sample is drawn in its own; an interface font's bold waits until it is chosen.

**Reading & customs**
- Sections with GroupHeaders, their settings 24 apart:
  - **Where & when:** the reading heard and the days of Yom Tov as SegmentedButtons, Shabbat times (the city), the weekly plan, the after-Shabbat window;
    - Shabbat times: one PaperGroup. The City row (`place_outlined`) has the city as its value and this week's times under it, on two lines: `shabbatTimesSummary` ("Candle-lighting 5:34 PM / Shabbat ends 6:50 PM"), or, when Yom Tov begins as Shabbat ends, `shabbatTimesSummaryYomTov` ("Yom Tov candles after 8:13 PM" on the second line). With a city chosen, two rows follow it, each with its choice under its title, in full (as a value, one would end the title's line and the other not), opening a `showChoiceSheet`: Candle-lighting (`wb_twilight_outlined`; "City default (40 min)", then 15, 18, 20, 22, 30 and 40 "minutes before sunset", with any other a backup brought in its place among them) and Shabbat ends (`bedtime_outlined`; "Nightfall (sun 8.5° below)", "42 minutes after sunset", "50 minutes after sunset", "72 minutes (Rabbeinu Tam)"). A number and its unit are joined by a no-break space.
  - **How I read:** the method, the second reading, then End with Mikrah and the third-reading prompts as switch rows;
  - **Haftarah:** its switch ("Read the week’s haftarah once", the section naming it); while it is on, set in by 16 behind a 2 px outlineVariant start rule, the custom as a SegmentedButton [Ashkenazi | Sephardi | Chabad] and "Count the haftarah toward completion";
  - **Special days:** Tisha B'Av, its switch with `tishaBavQuietDesc` under it ("Torah study is set aside on the fast, apart from the passages of mourning (Shulchan Aruch OC 554:1)"), and Chol HaMoed;
  - **Parsha names:** a SegmentedButton.
- Radio groups inside PaperGroups with 56/72 rows.
- Source citations, e.g. "(Shulchan Aruch OC 285:2)", in SourceNotes: the second reading's (its citation alone, `secondSource`, with the advice after it as plain help, `secondAdvice`; `ChoiceGroup.source`) and the after-Shabbat window's. The marginalia keep their own size (EB Garamond's 19 sp floor, §4.5; Frank Ruhl Libre 17/26 in Hebrew).
- A segment's label and its gloss ("One, as in Israel"; "Sephardi (Bereshit)") are set on two lines, so that the label breaks there or nowhere, whichever segment bears the check.
- The customs disclaimer closes the page in marginalia.

**Accessibility**
- Quick setups as a 2×2 grid of cards 88 high, radius 12: icon 24 in primary, titleSmall, one bodySmall line that names what changes most, the cantillation hidden and the theme among it ("Clear font, no cantillation"; "Largest text, high contrast").
  - A setup in force (`presetActive`: the settings it sets, sizes within a hair) is washed in primaryContainer with a primary border and a check, and reads as selected. Two may be, as Low vision includes High contrast.
  - High contrast and Low vision choose high contrast light or dark as the theme in use is: the device's while the app follows it, and otherwise the app's own (Sepia's is light).
  - Applying one says so with Undo, which restores the settings exactly as they were.
- Reset display as a TextButton (`restart_alt`) under the grid, with the same Undo.
- The remaining rows in PaperGroups: the Display page, Motion and touch, the screen reader's text and the Divine Name, Speech, and Statement and feedback.
  - Reduce motion is on and disabled while the device's is on (as a SwitchRow above).
  - Speech: the speech rate's slider (`LabeledSlider`), its value shown and read as the Listen player shows it, relative to the default ("Normal", "1.2×"; §6.28). The setting keeps its own scale, 0.1 to 1.0 in steps of 0.05, the default 0.45 (`kDefaultSpeechRate`).

**Reader display sheet** (lib/features/reader/display_sheet.dart)
- Opens at 42% of the screen over a light scrim (`Colors.black12`), so the verse it changes stays in view; drawn up, 95%.
- A change in it, or by a shortcut, that lays the full text out again keeps the reader's place: the verse at the top of the text (the one marked, focused or being read, while it is in view) stays where it stood once the text is laid out anew, in one aliyah or the whole parsha; the guided reader keeps its step. While texts it now shows load (Rashi, the translation), the reader goes on showing what it showed, and the keyboard focus stays in the sheet. Esc closes it, as it closes every sheet and dialog, whatever has the focus.
- Text size: outlined 56×48 buttons (`text_decrease`, `text_increase`, radius 10) either side of the size in titleMedium, which screen readers hear as it changes.
- Scripture font: four ChoiceChips sharing the width, each "בְּרֵאשִׁית" at 18 in its font and named for screen readers; four across where the word fits, else two, or one under another. The sample keeps its font's weight, so the chosen chip's mark beyond its fill and border is a 24×2 primary rule under its word.
- Theme: the compact swatches. Then a PaperGroup of switches (vowels, cantillation, translation, Rashi, Rashi script, Side by side, focus mode, Listen along) with line spacing (from 1.6), and a row to the Display page. Side by side shows only in the full text's sheet, where its columns would show (§9 Reader, full text); Listen along only in the reader's, not the haftarah's.

**Reminders**
- Native: a PaperGroup for each reminder: its switch row and, once on, its time as a row's value (and for the daily reminder, the routine chips), 12 apart; the offer of a city below them, 28 apart.
- A daily reminder more than four hours from its routine's usual time (`HabitAnchor.isNear`) leaves the routine out of its message, and under the chips, 8 below them, `reminderMoveHint` ("Your reminder comes at 8:00 PM. Move it to 7:30 AM?") in bodySmall onSurfaceVariant offers that time, with a TextButton `reminderMove` at its end, or under it at the end once the text is enlarged. Moving it gives the time's row the focus, which reads out the new time.
- The Shabbat note is a NoticeBanner with candles (§7.6, in `rest`): "Never on Shabbat or Yom Tov, and at most once a day."
- Web: one NoticeBanner (`install_mobile`) saying that reminders need the installed app, with "Get the app" where the build gives `INSTALL_URL`, over the three reminders' switch rows, disabled and off, whatever a backup from a phone brought (replaces two stacked banners).

**Your data**
- Group 1, "Backup & restore": a "Cloud backup" row (cloud_outlined, chevron) that opens the account page, then Export (`ios_share_outlined`), Import (`download_outlined`) and "Paste backup text" (`content_paste_outlined`), which open dialogs and have no chevron. The descriptions of Cloud backup and Export, which say what each keeps, are never cut short (`subtitleMaxLines: null`): Export's takes three lines on a 360 dp phone.
- Group 2, apart: "Reset all progress" in error-coloured text with no icon tile, and `cantBeUndone` ("This can’t be undone.", the sentence a confirmation of what can't be undone says, §6.5) under it. The confirm dialog uses the destructive Filled button.

### Onboarding (onboarding_screen.dart; phone_welcome, he_welcome, dark_welcome, desktop_welcome)

**Welcome**
- At the top end: a SegmentedButton English / עברית, each label tagged with its own language. The selected segment is the EFFECTIVE locale even when language = system (fixes the unselected toggle in phone_welcome.png), and a selection can't be emptied: choosing the language already shown changes nothing, so an app that follows the device goes on following it.
- The block is vertically centred in the available height, max width 520, on the gutters below that; the language ends where the block does. The page scrolls when the block doesn't fit (large text).
- TitlePageFrame (padding 32, 24 below 360) containing:
  - an 8 px lozenge;
  - "שְׁנַיִם מִקְרָא / וְאֶחָד תַּרְגּוּם" in hebrewDisplay 40/60 primary (two lines, broken only between words), the page's heading (level 1), read as `appTitleFull`;
  - a SeferDivider;
  - English UI only: "Shnayim Mikrah v’Echad Targum" in EBG MediumItalic 24/30 onSurface (upright in high contrast and in an accessibility font), hidden from screen readers, since the heading says it. The Hebrew UI doesn't repeat the unpointed name;
  - body in bodyLarge onSurfaceVariant.
  - The English name, the body and the disclaimer set their lines evenly (`BalancedText`, lib/ui/widgets/lines.dart), so no word is left alone on a last line; the body keeps "once —" (and "פעם אחת —") together with no-break spaces.
  - The two names, display sizes already, grow with the text to 1.4× at most, so that with very large text the call to action isn't pushed far below the fold; the body and the buttons grow in full.
- Outside the frame: 24 gap, a Filled "Start this week’s parsha" 52 high (max width 400).
- An 8 gap, then a TextButton "I already use Shnayim Mikrah" (the same max width), which opens the restore sheet (§6.19): one PaperGroup of sign in (`cloud_download_outlined`, with a chevron, as it leads to the account page; only with a real community backend), a backup file (`restore_page_outlined`) or pasted text (`content_paste_outlined`), each with what it restores from under it, never cut short. While the account's backup comes in, a row 48 high takes its place, as a live region: a centred 18 px spinner (stroke 2), a 12 gap and "Restoring your progress…" in bodyMedium onSurfaceVariant.
- Then, 16 below, the disclaimer in bodySmall onSurfaceVariant.
- As the app opens on it, it enters once (§8, Welcome entrance): the frame and the title rise into place, the divider draws outward, then come the English name and the body, and last the way on and the disclaimer, all within 900 ms. It is whole from its first frame with Reduce Motion, and tappable and heard from its first frame either way.

**The three steps** (after the welcome)
- At the top, 16 below the app bar (clear of its rule): three 12 px lozenges, one for each step (the welcome is none), 12 apart and centred: filled up to the current step, outlined after it, in primary (onSurface in high contrast), hidden from screen readers. The app bar's title says the same in words ("Step 1 of 3"), so that the marks agree with it: one of three filled on the first step.
- 24 below, the question in headlineSmall, a level-2 heading (`ChoiceGroup(prominent: true)`).
- Options as paper radio cards: min 72 high, radius 12, 8 apart; selected = 2 px primary border plus primaryContainer fill, unselected = paper within a 1 px outline (3 px and 2 px in high contrast), with RadioGroup semantics and arrow keys. A focused card takes the focus ring with its gap (§6.1), clear of its own border.
- The location's options are in Settings' order, In Israel then Outside Israel, whichever the time zone's guess chose.
- The second reading and this week's start stay ChoiceGroups of paper rows under eyebrows. The second reading offers Onkelos, Rashi and both, with its citation alone as help (`secondSource`); the advice on translated Rashi (`secondAdvice`) stays in Reading & customs, where Rashi in English is offered.
- The honor statement as marginalia inside a NoticeBanner, a section's gap below the choices.
- The way on is docked below the page (`Scaffold.bottomNavigationBar`), on surface under a hairline, so it is always in view, however large the text: on the gutters, 12 above and 16 below, `onbChangeAnytime` in bodySmall onSurfaceVariant, 8, then the Filled button 52 high and at most 480 wide. Its labels stay as now ("Continue", "Start reading").

### About, Guide, Sources, Privacy (about_screen.dart, guide_screen.dart, sources_screen.dart, legal_screen.dart)

**About header**
- The app mark at 72 (corners 16), then "שניים מקרא ואחד תרגום" in hebrewDisplay 28/40 primary, the page's one heading of level 1, read as `appTitleFull`; the app bar shows "About" only once it has scrolled away, for the eye alone (`titleRevealed`), as on the policies.
- English UI: "Shnayim Mikrah v’Echad Targum" in EBG 500 20 onSurfaceVariant, hidden from screen readers. The Hebrew UI doesn't repeat the name.
- Both names set their lines evenly (`BalancedText`) should large text need two.
- Version in labelSmall, then a SeferDivider.
- On the web, while a new version waits, its offer 16 under the title page, without a close button (§6.20, New version).
- TitlePageFrame at ≥600 only.
- Link rows in PaperGroups under GroupHeaders: **Learn** (Texts & sources); **Policies** (Privacy, Terms, Community guidelines, Accessibility statement, Open-source licenses); **Contact** (Contact us where the build has an address, Send feedback, and, only once something has gone wrong since the app started, Copy details for support, `Icons.content_copy_outlined`, with “What went wrong since the app opened, to paste into a message to us” under it and no chevron). Every Send feedback row takes one way (`sendFeedback`, about_screen.dart): by email where the build has an address and a mail app opens it, else the feedback forum where there is a community server, else the issue tracker; About's skips the email, which Contact us sends. Copy details for support copies the app's version and platform, then each error kept (the last 20 distinct ones, one that recurs counted where it first came): its first line, what the app was doing where the framework says so (a profile build names the widget that failed to build; a release build can't, and its bare "building Widget" is left out), and the first 8 frames of its stack (after the lines a trace without its symbols begins with, which `flutter symbolize` needs), in English for the maintainers; then says `supportDetailsCopied`. Nothing is sent: the reader pastes it into a message. The guide is reached from Today's help button and from Settings.

**Guide, Sources, Privacy**
- Where they open: within the tab that opens them, so that the navigation bar or rail stays beside them, with Back to the page beneath: the guide from Today's help button (`/today/guide`) and from Settings (`/settings/guide`); the sources and the policies from About (`/settings/about/sources`, `/settings/about/legal/privacy`); the accessibility statement from Accessibility (`/settings/accessibility/legal/accessibility`); the privacy policy from the account and the guidelines from a new discussion, within whichever tab shows them (`policyPath`, routes.dart), under the page that opens them where the address can say so, so that a reload or a shared link puts back the same page beneath: the account's under the account (`/community/account/legal/privacy`, `/settings/account/legal/privacy`), and a new discussion's under Community (`/community/legal/guidelines`; the discussion's own address carries its forum and verse, which a policy's beneath it couldn't). On their own, over the tabs, with a home button when nothing lies beneath (`/guide`, `/sources`, `/legal/privacy`): from a page that is itself shown over the tabs (signing in from the welcome, a question asked over the reader), and for links and the web, before onboarding too, when a tab's address of theirs leads to them, as the tabs wait for onboarding. Search, the bookmarks and notes, and the reader stay over the tabs.
- longformBody, max width 620 (the app bar's title on the column's edge, §5).
- Headings in longformHeading, onSurface (not blue).
- **Guide:** it opens with a card (the card rhythm's 20, 16 under 360 dp, and 4 more above and below the words) of the Talmud's words, "לְעוֹלָם יַשְׁלִים אָדָם פָּרָשִׁיּוֹתָיו עִם הַצִּבּוּר, / שְׁנַיִם מִקְרָא וְאֶחָד תַּרְגּוּם" in Noto Serif Hebrew 24, centred, each phrase on a line of its own (balanced over two where it doesn't fit), tagged Hebrew and read as one sentence; "Berachot 8a" in labelMedium secondary; in the English UI, the translation in marginalia. Then using the app ("Using the app" / "השימוש באפליקציה": Today and its rings, a Chumash and logging after Shabbat, a missed day made up or covered by a grace day, a verse's long press, and Listen, a point each); the practice and when (its first paragraph building on the card, from the Shulchan Aruch, rather than saying the words again); how and Targum or Rashi; the special cases and Shabbat; and the sources, a SeferDivider between each part. The How section begins with the three filled PassPips and "1 · Mikrah  2 · Mikrah  3 · Targum" in labelMedium onSurfaceVariant, for the eye alone. The guide's lists are one string each, an item to a line, and every item hangs from a lozenge (`Lozenge`, 6 at the text's own size and growing with it, level with the item's first line), 12 before the text: the points on using the app and the seven special cases in longformBody, 8 apart, and the sources in marginalia, 4 apart. Each special case is led by its words up to the first colon ("Vezot HaBerachah:"), set apart from the rest so that it is found at a glance: a step heavier, Semibold over EB Garamond's Medium, and Bold over Frank Ruhl Libre's Medium (whose Semibold barely shows at this size), high contrast's Semibold serifs or an accessibility font's Regular; and where the text is Bold already (Bold text, and the presets that turn it on, or Frank Ruhl Libre in high contrast), as heavy as the text, on a line of its own above it. The text selects, an item or paragraph at a time, and is set in bold with Bold text, as every Text is. A source in a sentence ("MB 285:14", "מ״ב רפה, יד") keeps to one line, and a dash to the word before it (no-break spaces). The closing "Customs vary…" is a NoticeBanner.
- **Sources:** each source is a card that opens it (SeferInkWell), read as one link: its name and license, then what it is. The name in titleLarge, with the license as a tag beside it (`SeferTag`, §6.20), or under it where the two don't fit, and `open_in_new` 18 at the card's end, level with the name's first line; the description in bodyMedium onSurfaceVariant. The note on the adapted files closes the page under a SeferDivider, in bodySmall onSurfaceVariant.
- **Policies** (privacy, terms, guidelines, accessibility): the texts are in `assets/legal/legal.json`, which the static web pages are made from too (docs/RELEASE.md). The page's title is its heading, in headlineMedium (above the 24 of the section headings), with "Last updated: October 2026" in bodySmall onSurfaceVariant under it; the app bar shows the title once it has scrolled away. Paragraphs are 12 apart; a bullet hangs, its wrapped lines aligned past the bullet (in onSurfaceVariant, 8 before the text, 6 between items). The way to reach us is a link in its sentence, primary and underlined: the support address, isolated in Hebrew, or "GitHub issues" / "דף התקלות ב־GitHub" where the build has none, never the raw address. The keyboard reaches it through its sentence, which takes the focus ring; Enter opens it. Where nothing opens it, a status message says so (`linkOpenFailed`, or `emailOpenFailed` with a Copy action that copies the bare address). The page selects as one text (`SelectionArea`), the contact line too, and a copy leaves out the marks that isolate a Latin run in Hebrew, which would break an address pasted into a mail app.

## 10. Copy and l10n (app_en.arb / app_he.arb; the build fails on missing keys)

**Typography.** The English is typeset: an apostrophe is ’ (Revi’i, today’s) and quotation marks are “ ”, never the typewriter's ' and ", which EB Garamond draws as straight ticks; the Hebrew has its own ׳ and ״. test/lint/typography_test.dart checks the strings of both languages and the English policies. The parsha names and the keys of the special haftarot keep the data's straight apostrophe, which progress, the calendar and the weekly threads' titles are matched by: `PortionInfo.displayName` and `Names.specialHaftarah` set it curly as they name them, and `City.name` does the same for a city.

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
| streakBeginsWith | Starts when {name} is complete | יתחיל עם סיום פרשת {name} |
| daysBeginToday | Starts with today’s reading | יתחיל בקריאה של היום |
| finishStep | Finish | סיום |
| shabbatShalom | Shabbat Shalom | שבת שלום |
| chagSameach | Chag Sameach | חג שמח |
| shanaTova | Shanah Tovah | שנה טובה |
| gmarChatimaTova | G’mar Chatimah Tovah | גמר חתימה טובה |
| restDayBody | Reading from a printed Chumash today? You can log it after Shabbat. | קוראים היום מתוך חומש? אפשר לרשום זאת אחרי השבת. |
| restDayBodyChag | Reading from a printed Chumash today? You can log it after Yom Tov. | קוראים היום מתוך חומש? אפשר לרשום זאת אחרי החג. |
| restDayBodyYomKippur | Reading from a printed Chumash today? You can log it after Yom Kippur. | קוראים היום מתוך חומש? אפשר לרשום זאת אחרי יום כיפור. |
| openTheParsha | Open the parsha | לפרשה |
| weekCompleteNote | Ready to hear it read on Shabbat. | הכול מוכן לקריאת התורה בשבת. |
| discussTheParsha | Discuss the parsha | לדיון בפרשה |
| checkInTitle | Shavua tov! Did you read {name} on Shabbat? | שבוע טוב! קראת את פרשת {name} בשבת? |
| checkInFinished | I finished {name} on Shabbat | סיימתי את פרשת {name} בשבת |
| checkInTitleShabbatYomTov | Shavua tov! Did you read {name} over Shabbat and Yom Tov? | שבוע טוב! קראת את פרשת {name} בשבת וביום טוב? |
| checkInTitleVezot | Did you finish {name} over Yom Tov? | סיימת את פרשת {name} ביום טוב? |
| checkInFinishedYomTov | I finished {name} on Yom Tov | סיימתי את פרשת {name} ביום טוב |
| checkInNotThisTime | Not this time | לא הפעם |
| checkInReadOnShabbat | Read on Shabbat, {date} | תאריך הקריאה: שבת, {date} |
| checkInReadOnYomTov | Read on Yom Tov, {date} | תאריך הקריאה: יום טוב, {date} |
| whenOnYomTov | On Yom Tov | ביום טוב |
| changeDate | Change date | שינוי התאריך |
| logReading | Log reading | רישום הקריאה (logging is לרשום throughout; סימון is kept for the mark-as-read actions) |
| openWeekRestoreZero | Finish {name} and {next} by Shabbat and both count — you can do this once in each book of the Torah. | אם מסיימים את {name} ואת {next} עד שבת, שתיהן נחשבות — אפשר לעשות זאת פעם אחת בכל חומש. |
| pausedTodayNote | Paused — read whenever you like; nothing counts against you. | בהשהיה — אפשר לקרוא מתי שנוח; שום דבר לא נחשב לחובתך. |
| pauseEndedOn | Your pause ended on {date}, and nothing during it counts against you. | ההשהיה הסתיימה ב{date}, ושום דבר בזמנה לא נחשב לחובתך. |
| graceUsedNote | plural: {weekdays} was covered by a grace day / {weekdays} were covered by grace days — your rhythm continues. You’ll earn one back when you finish {parsha} by Shabbat. | plural: {weekdays} כוסה ביום חסד — הקצב נמשך. עם סיום פרשת {parsha} עד שבת, יום החסד יחזור. / {weekdays} כוסו בימי חסד — הקצב נמשך. עם סיום פרשת {parsha} עד שבת, יום חסד אחד יחזור. (a no-break space inside יום חסד) |
| caughtUpNote | Caught up — today’s reading made up for yesterday. | חזרה לתוכנית — הקריאה של היום השלימה את אתמול. |
| erevTishaBavNote | Erev Tisha B’Av: many finish their learning before midday. | ערב תשעה באב: רבים מסיימים את הלימוד לפני חצות היום. |
| tishaBavTitle | Tisha B’Av | תשעה באב |
| todayTishaBav | Torah study is set aside today, apart from the passages of mourning (Iyov, Eicha, parts of Yirmiyahu). | היום אין לומדים תורה, מלבד הדברים הרעים (איוב, איכה ומקצת ירמיהו). |
| todayTishaBavTomorrow | {portion} continues tomorrow. | פרשת {portion} נמשכת מחר. |
| tishaBavShort | 9 Av | ט׳ באב |
| aboutStreaks | About streaks | על הרצפים |
| graceAvailable | plural: 1 grace day available / {count} grace days available | plural: נותר יום חסד אחד / נותרו {count} ימי חסד |
| thisYear | This year | השנה |
| parshiyotOfYear | {done} of {total} parshiyot | {done} מתוך {total} פרשות |
| yearBeginsWith | Begins with {name} | מתחילה בפרשת {name} |
| recordTitle | Finished so far | הושלם עד כה |
| demoTag | Demo | הדגמה |
| emptyForum | No discussions yet — begin the first. | עדיין אין דיונים — אפשר לפתוח את הראשון. |
| askedTag / authorTag | Question (the post that asked) / Author (the member) | שאלה / פתיחת הדיון (no slashed gender forms) |
| todahAction | Todah | תודה |
| replyToName | Reply to {name} | תגובה ל{name} |
| sending | Sending… | בשליחה… |
| passTrackLabel | {n} · {name} | {n} · {name} |
| aliyahTabLabel | {name}, aliyah {n} of 7 | {name}, עלייה {n} מתוך 7 |
| tabRead / tabPartial / tabNotStarted | read / {done} of 3 readings done / not started | נקראה / {done} מתוך 3 קריאות / טרם התחילה |
| uiFontSystem | Device font | גופן המכשיר |
| rashiScript | Rashi script | כתב רש״י |

**Changed values**
- `todayBehind` (Sunday to Wednesday only; it counts every aliyah the card names, today's included):
  - English: "{count, plural, =1{One aliyah to catch up — very normal midweek.} other{{count} aliyot to catch up — very normal midweek.}}"
  - Hebrew: "{count, plural, =1{עוד עלייה אחת להשלים — רגיל לגמרי באמצע השבוע.} other{עוד {count} עליות להשלים — רגיל לגמרי באמצע השבוע.}}"
- On the other days the line is honest about the day (§9 Today, 4):
  - `todayBehindThursday`: "{count} aliyot to catch up — and there are still two days before Shabbat." / "עוד {count} עליות להשלים — ויש עוד יומיים עד שבת."
  - `todayLastDayShabbat`: "{count} aliyot left to read before Shabbat — or finish Shabbat morning from a Chumash and log it after Shabbat." / "עוד {count} עליות לקרוא לפני שבת — או לסיים בשבת בבוקר מתוך חומש ולרשום אחרי השבת."
  - `todayLastDayYomTov`: "{count} aliyot left to read before Yom Tov — or finish on Yom Tov from a Chumash and log it after Yom Tov." / "עוד {count} עליות לקרוא לפני החג — או לסיים בחג מתוך חומש ולרשום אחרי החג."
  - `todayLastDayShabbatThenYomTov`: "{count} aliyot left to read before Shabbat — or finish Shabbat morning from a Chumash and log it after Yom Tov." / "עוד {count} עליות לקרוא לפני שבת — או לסיים בשבת בבוקר מתוך חומש ולרשום אחרי החג."
  - `todayLastDayYomTovThenShabbat`: "{count} aliyot left to read before Yom Tov — or finish on Yom Tov or Shabbat from a Chumash and log it after Shabbat." / "עוד {count} עליות לקרוא לפני החג — או לסיים בחג או בשבת מתוך חומש ולרשום אחרי השבת."
  - `todayLastDayYomKippur`: "{count} aliyot to catch up before Yom Kippur — and there is still time after it, too." / "עוד {count} עליות להשלים לפני יום כיפור — ויש זמן גם אחריו."
  - Each has a singular form ("One aliyah…" / "עוד עלייה אחת…").
- `openWeekRestore` takes the reader's parsha streak: "Finish {name} and {next} by Shabbat and your {count}-week streak continues — you can do this once in each book of the Torah." / "סיום {name} ו{next} עד שבת ימשיך את הרצף של {count} שבועות — אפשר לעשות זאת פעם אחת בכל חומש." (one week: "של שבוע אחד").
- The parsha statuses name the rescue as the banner does: `weekRestored` "Finished with the next parsha" / "הושלם עם הפרשה הבאה", `weekOverdue` "Can still be finished with the next parsha" / "עוד אפשר להשלים עם הפרשה הבאה", and `weekMadeUp` "Made up later" / "הושלם מאוחר יותר".
- `translationDisclaimer`, under the translation's switch: "Helps with the meaning; it doesn’t take the place of the Targum." / "עוזר להבין את הפשט, אך אינו בא במקום תרגום אונקלוס." The Hebrew names Onkelos, since תרגום is the word for both.
- Thanks are counted in words that agree with one: `todahCount` "Thanked once" / "Thanked {count} times", under one's own post; on the Todah button, whose name holds the digits it shows, `todahButtonCount` "Thanked 1 time" / "Thanked {count} times" ("תודה 1" / "{count} תודות"); in a forum row's lowercase list, `threadThanksCount` "thanked 12 times", the count held to "times" by a no-break space and nothing more, so that at 300% on a phone the row's line can break after "thanked". The shortcut `shortcutLogFromBook` is "Log a Chumash reading" / "רישום קריאה מתוך חומש", within the 25 characters a launcher shows.
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
3. **Font loading for widget tests:** add `loadBundledFonts()` to test/helpers.dart. It reads FontManifest.json and runs `FontLoader` for each family, then loads the fonts `OptionalFonts` loads on demand. Pixel-sampled contrast checks (`textContrastGuideline`) stay on the test font: with real glyphs, anti-aliased edge pixels can outnumber the text colour (test/accessibility/text_contrast_test.dart).
4. **Goldens** (`matchesGoldenFile`): Today, Reader guided, Parsha, Progress and Community × 5 themes × {en, he}. Today and Reader in light English, and Today at 1366 × 860, are also written to `web/screenshots/`, the web manifest's install screenshots. Plus the mixed headings "Revi’i · רביעי" and "בְּרֵאשִׁית" in titleLarge and hebrewDisplay (catches fallback tofu).
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
4. **Bundle size and web start-up.** About 571 KB is loaded eagerly; Rashi is lazy. Subset exactly as in §4.1. The first frame waits for every font in the build's FontManifest.json, so after the build `tool/web/preload_fonts.mjs` adds a `<link rel="preload" as="fetch" crossorigin>` for each to index.html (web/index.html itself preloads EBGaramond-Medium and FrankRuhlLibre-Medium, for a build without it). The engine reads fonts with `fetch()`, so `as="font"` would not match and the files would download twice.
5. **User-chosen fonts must win.** Every serif role maps to Atkinson, Lexend or OpenDyslexic when one is selected (§4.5).
6. **Departing from M3 defaults.** Every ColorScheme role is explicit (§3.2) so stock widgets don't pull seeded lavender. Button `animationDuration` is zero for the focus ring.
7. **High-contrast dark primary.** It moves from yellow to light techelet (13.24:1, AAA) to keep one meaning per colour across themes. Gold-yellow #FFD970 remains for the rubric. Collect feedback from low-vision testers.
8. **Tone.** Completion moments happen once and are silent. No counters on ornaments and no "unlock" language. Review against DESIGN.md principles 1 and 5.
9. **Shabbat and Yom Tov state.** It is informational only, with no reading prompt. Its copy goes to the rabbinic advisor.
10. **Icon change visibility.** Ship it before the first public release. Store screenshots and goldens will change.
