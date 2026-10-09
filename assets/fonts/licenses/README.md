# Bundled font licenses

| Font | Files | License |
|---|---|---|
| Noto Serif Hebrew (default scripture font) | `NotoSerifHebrew-*.ttf` — static weights instanced from the variable font in google/fonts | SIL OFL 1.1 |
| Noto Sans Hebrew | `NotoSansHebrew-*.ttf` | SIL OFL 1.1 |
| Noto Sans (Latin UI; subset to Latin scripts) | `NotoSans-*.ttf` | SIL OFL 1.1 |
| Atkinson Hyperlegible Next | `AtkinsonHyperlegibleNext-*.ttf` | SIL OFL 1.1 |
| Lexend | `Lexend-*.ttf` | SIL OFL 1.1 |
| OpenDyslexic | `OpenDyslexic-*.otf` | SIL OFL 1.1 (Reserved Font Name "OpenDyslexic") |
| Ezra SIL | `EzraSIL-Regular.ttf` (unmodified `SILEOT.ttf` 2.51) | SIL OFL 1.1 (RFN "SIL", "Ezra"); Hebrew layout logic MIT |
| Taamey Frank CLM | `TaameyFrankCLM-Medium.ttf` (unmodified) | GPL-2.0 with font exception — see `TaameyFrankCLM-LICENSE.txt` and `GPL-2.0.txt`. Source: Culmus project (https://culmus.sourceforge.io/taamim/), mirrored at https://github.com/aharonium/fonts |

Only the Medium weight of Taamey Frank CLM is bundled: its Bold file renders the
cantillation marks as empty glyphs.

The Taamey Frank font is distributed as a separate, unmodified file alongside the
app (mere aggregation). If you prefer to ship only OFL-licensed fonts, remove it
from `pubspec.yaml`, `ScriptureFont` (`lib/features/settings/app_settings.dart`),
the font picker (`lib/features/settings/screens/display_settings_screen.dart`) and the
license registration in `lib/main.dart`.
