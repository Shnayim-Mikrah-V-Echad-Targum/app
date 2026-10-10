# Bundled font licenses

| Font | Files | License |
|---|---|---|
| Noto Serif Hebrew (default scripture font) | `NotoSerifHebrew-*.ttf` — static weights instanced from the variable font in google/fonts | SIL OFL 1.1 |
| Noto Sans Hebrew | `NotoSansHebrew-*.ttf` — static weights instanced from the variable font in google/fonts | SIL OFL 1.1 |
| EB Garamond (Latin display serif) | `EBGaramond-*.ttf` — static weights instanced from the variable fonts in google/fonts, subset to Latin | SIL OFL 1.1 |
| Frank Ruhl Libre (Hebrew display serif) | `FrankRuhlLibre-*.ttf` — static weights instanced from the variable font in google/fonts, subset to Hebrew and basic Latin | SIL OFL 1.1 |
| Noto Rashi Hebrew (optional Rashi script; loaded on first use) | `rashi/NotoRashiHebrew-Regular.ttf` — static weight instanced from the variable font in google/fonts, subset to Hebrew | SIL OFL 1.1 |
| Noto Sans (Latin UI; subset to Latin scripts) | `NotoSans-*.ttf` | SIL OFL 1.1 |
| Atkinson Hyperlegible Next (optional interface font; loaded on first use) | `optional/AtkinsonHyperlegibleNext-*.ttf` | SIL OFL 1.1 |
| Lexend (optional interface font; loaded on first use) | `optional/Lexend-*.ttf` | SIL OFL 1.1 |
| OpenDyslexic (optional interface font; loaded on first use) | `optional/OpenDyslexic-*.otf` | SIL OFL 1.1 (Reserved Font Name "OpenDyslexic") |
| Ezra SIL (optional scripture font; loaded on first use) | `optional/EzraSIL-Regular.ttf` (unmodified `SILEOT.ttf` 2.51) | SIL OFL 1.1 (RFN "SIL", "Ezra"); Hebrew layout logic MIT |
| Taamey Frank CLM (optional scripture font; loaded on first use) | `optional/TaameyFrankCLM-Medium.ttf` (unmodified) | GPL-2.0 with font exception — see `TaameyFrankCLM-LICENSE.txt` and `GPL-2.0.txt`. Source: Culmus project (https://culmus.sourceforge.io/taamim/), mirrored at https://github.com/aharonium/fonts |

`tool/fonts/build_fonts.sh` rebuilds the EB Garamond, Frank Ruhl Libre, Noto Rashi
Hebrew and Noto Sans Hebrew files from google/fonts at commit
`2eb0b48d5f760f62e286216f0859a8c540dbc1bd`, and copies the first three's license
texts here.

Only the Medium weight of Taamey Frank CLM is bundled: its Bold file renders the
cantillation marks as empty glyphs.

Fonts under `optional/` and `rashi/` are plain assets rather than `fonts:` in
`pubspec.yaml`, so the web build downloads one only when the reader chooses it;
`OptionalFonts` (`lib/services/optional_fonts.dart`) registers them.

The Taamey Frank font is distributed as a separate, unmodified file alongside the
app (mere aggregation). If you prefer to ship only OFL-licensed fonts, delete
`optional/TaameyFrankCLM-Medium.ttf` and remove it from `OptionalFonts`,
`ScriptureFont` (`lib/features/settings/app_settings.dart`), the font picker
(`lib/features/settings/screens/display_settings_screen.dart`) and the license
registration in `lib/main.dart`.
