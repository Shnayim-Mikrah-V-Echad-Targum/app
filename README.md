# Shnayim Mikra

An app for *shnayim mikra v'echad targum*, reading each week's Torah portion twice and the Targum once. It runs on Android, iOS, the web and Windows, in English and Hebrew.

It always knows the right portion for the week, in Israel or abroad and in any year type. It guides you through the reading verse by verse, section by section or aliyah by aliyah. It tracks a daily streak and a weekly streak with forgiving, Shabbat-aware rules. It also has a community forum with a thread for every parsha.

Accessibility is a core requirement, not an add-on. See [docs/ACCESSIBILITY.md](docs/ACCESSIBILITY.md).

## Features

**Reading**
- The full Torah in the Masoretic text (Miqra according to the Masorah), with Targum Onkelos, Rashi (Hebrew or English) and the JPS 1917 translation as an optional study aid.
- Guided mode with three reading methods:
  - verse by verse (Arizal)
  - section by section, following the parasha breaks (Shelah, Gra)
  - aliyah by aliyah
- Full-text mode with the Torah and Targum interleaved.
- Search for a word or phrase in the Torah, the Targum or the translation, from the Parsha tab. Hebrew is matched without vowels or cantillation, and each verse found opens in the reader.
- Go to a verse by its reference, in English or Hebrew ("Gen 28:12", "Vayetzei 28 12", "בראשית כח, יב", or "3:22" in this week's book), from the same search button or Ctrl+K. The reader opens at the verse and marks it.
- The reader handles the special cases:
  - Bamidbar 32:3, where Onkelos is mostly place names (a third Mikra reading)
  - verses Rashi is silent on, when Rashi replaces the Targum (a third Mikra reading)
  - repeating the last verse
  - ketiv/qere
  - large and small letters
- Every week's haftarah, including the special haftarot (Rosh Chodesh, the four parshiyot, Chanukah, Shabbat Shuva and others). Ashkenazi or Sephardi rite.
- Choice of scripture font: Noto Serif Hebrew, Taamey Frank, Ezra SIL or Noto Sans Hebrew. Vowels and cantillation can each be shown or hidden. Settings for line height, word spacing and line width.
- Text-to-speech, where a Hebrew voice is installed.

**Calendar**
- A Hebrew calendar and parsha schedule, validated against hebcal for every year from 5700 to 5900:
  - Israel and Diaspora
  - double portions
  - holidays that displace Shabbat
  - Vezot HaBerachah on Simchat Torah
- A reading week runs from the day after the previous public reading through Shabbat.
- The "day" rolls over at 3 a.m., and Shabbat and Yom Tov never count against you.

**Streaks and progress**
- **Days on track:** a daily streak based on a weekly plan you choose:
  - an aliyah a day
  - Shevi'i on Shabbat
  - everything on Erev Shabbat

  Reading ahead counts, and catching up the same week counts.
- **Parsha streak:** a weekly streak. A portion finished by Shabbat is on time. One finished by Tuesday is late but still counts. A missed portion can be restored once per book of the Torah.
- **Grace days:**
  - earned by finishing weeks on time
  - used up automatically
  - at most two per week
- **Pause:** for illness, travel or mourning. A pause doesn't break the streak.
- The rules are honest, with no dark patterns:
  - no points, XP or loss-framed copy
  - you can log reading done away from the app or on a printed chumash
- A progress screen with a map of the Torah, milestones and a list of portions to make up.

**Reminders**
- Daily, check-in and Erev Shabbat reminders. They never fire on Shabbat or Yom Tov, never after midday on the eve, and never more than one a day.

**Community**
- Forums, including an automatic thread for each week's parsha.
- Sign-in with a six-digit email code: no passwords and no deep links.
- Reporting, blocking, a moderation queue and community guidelines. Posts are hidden automatically after three reports.
- Optional cloud backup of reading progress, plus account deletion.
- Without a backend configured, the community runs as an on-device demo.

**Accessibility (summary)**
- **Screen readers:** each verse has a curated spoken label, with cantillation removed, tagged as Hebrew, and the Divine Name spoken as you choose. Headings and live announcements.
- **Visual:** light, dark, sepia and two high-contrast themes. Scripture text can be scaled up to 5× on top of the system text size.
- **Cognitive and motion:** fonts for dyslexia and low vision, presets, reduce motion and bold text.
- **Input and layout:** full keyboard support with shortcuts, 48 dp tap targets and a correct right-to-left layout.

## Getting started

You need Flutter 3.47 or later (Dart 3.13 or later).

```sh
flutter pub get
flutter run                # a connected device, or pass -d chrome / -d windows
```

The bundled texts and calendar tables are committed, so nothing has to be downloaded or generated to build the app.

### Configuration

The app is configured at build time with `--dart-define`:

| Define | Purpose |
|---|---|
| `SUPABASE_URL` | Supabase project URL for the community and backup. Leave it empty for demo mode. |
| `SUPABASE_PUBLISHABLE_KEY` | The project's publishable (anon) key. It is safe to ship because row-level security protects all data. |
| `SUPPORT_EMAIL` | Contact address shown in About and in the accessibility statement. Hidden if empty. |
| `SOURCE_URL` | Link to the source code and issue tracker. |

Example:

```sh
flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co \
            --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

Setting up the backend is covered in [docs/BACKEND.md](docs/BACKEND.md).

### Building for each platform

| Platform | Command | Notes |
|---|---|---|
| Android | `flutter build appbundle` | Release signing reads `android/key.properties` if present (see [docs/RELEASE.md](docs/RELEASE.md)). |
| iOS | `flutter build ipa` | Needs Xcode and an Apple developer team. Bundle id `org.shnayimmikra.app`. |
| Web | `flutter build web --no-web-resources-cdn` | Always pass `--no-web-resources-cdn`. Without it, every visitor's browser fetches the rendering engine from Google's CDN. With it, the engine is served from your own host, which is better for privacy and works on restricted networks. Then `node tool/legal/build_html.mjs build/web` writes the static policy pages, and `npx --yes workbox-cli@7.4.1 generateSW workbox-config.cjs` the service worker that keeps the app working offline (see [docs/RELEASE.md](docs/RELEASE.md#web)). |
| Windows | `flutter build windows` | Output in `build/windows/x64/runner/Release`. `bash tool/windows/make_msix.sh` then packages it as an MSIX installer (see [docs/RELEASE.md](docs/RELEASE.md#windows)). |

CI (`.github/workflows/ci.yml`) runs analysis and every test, then builds all four platforms on each pull request. On `main` it can also deploy the web build to GitHub Pages: set the repository variable `DEPLOY_WEB=true`, set `WEB_BASE_HREF` if the site isn't served from the root, and set `WEB_URL` to the site's address for link previews.

## Tests

```sh
flutter analyze
flutter test                     # unit, widget, data-integrity and accessibility tests
supabase/tests/run_tests.sh      # database policies and triggers (needs PostgreSQL 15+)
python3 tool/l10n/build_he.py    # regenerates app_he.arb; fails if a string is untranslated
```

What the tests cover:
- **Calendar:** checked against fixtures generated from hebcal: 200 years of parsha schedules, 100 years of holidays and special haftarot.
- **Data integrity:** all 5,846 Torah verses are present, and the Hebrew, Targum, English and Rashi layers line up verse for verse.
- **Domain logic:** the streak engine, plan, progress merging and reminder planner, each tested in isolation.
- **Widgets:** onboarding, the guided reader and the community.
- **Accessibility:** Flutter's tap-target, label and contrast checks on twelve screens, in four themes, at 200% text and in Hebrew.

## Project layout

```
lib/
  app/            app shell, routing, providers, build configuration
  core/calendar/  Hebrew calendar, holidays, parsha schedule, special haftarot (pure Dart)
  core/text/      Hebrew text utilities: stripping marks, gematria, spoken labels
  data/           models and repositories for the bundled texts and parsha data
  features/
    today/        the home screen
    parsha/       week overview and browsing
    reader/       guided and full-text reader, haftarah, display options
    progress/     streak engine, plans, milestones (domain/) and progress screen
    community/    forum repository (Supabase and demo), screens
    settings/     settings model and screens
    onboarding/   first-run flow
    about/        guide, sources, legal texts
  services/       notifications, reminder planner, text-to-speech, feedback, optional fonts
  ui/             theme, localization helpers, shared widgets
  l10n/           ARB files (English source and generated Hebrew)
assets/
  text/           Torah, Targum, English, Rashi and haftarot as JSON
  data/           parsha metadata, aliyot, haftarah references, cities for Shabbat times
  fonts/          bundled fonts and their licenses
supabase/         database migrations, local config, email template, SQL tests
tool/
  data/           scripts that generate the text assets, calendar tables and test fixtures
  l10n/           Hebrew translations and the ARB builder
  fonts/          builds static font instances from pinned google/fonts sources
docs/             design notes, research, backend and release guides
```

State is managed with Riverpod and navigation with go_router. The calendar, plan, streak and reminder logic is pure Dart with no Flutter dependency, so it is tested directly.

## Regenerating data

You only need to do this when a source text or the schedule rules change:

```sh
cd tool/data && npm ci
NODE_USE_ENV_PROXY=1 node build_data.mjs      # assets/text/** and assets/data/parshiyot.json
node build_cities.mjs                         # assets/data/cities.json (before the fixtures)
node gen_fixtures.mjs                         # calendar tables and test fixtures
python3 gen_supabase_reference.py             # forum categories and parashot reference data
```

`@hebcal/core` is used only as a test oracle during generation. It is GPL-licensed and is not part of the app.

EB Garamond, Frank Ruhl Libre, the Rashi script and Noto Sans Hebrew are bundled as static instances of variable fonts. Rebuild them, byte for byte, with:

```sh
pip install -r tool/fonts/requirements.txt
bash tool/fonts/build_fonts.sh
```

## Sources and licenses

| Text | Edition | License |
|---|---|---|
| Torah and haftarot | Miqra according to the Masorah (MAM) | CC BY-SA 4.0 |
| Targum Onkelos | Torat Emet | Public domain |
| English | JPS 1917 | Public domain |
| Rashi (Hebrew and English) | Rosenbaum & Silbermann, 1929–1934 | Public domain |
| Aliyot and haftarah references | @hebcal/leyning | BSD-2-Clause |
| Cities for Shabbat times | GeoNames, via geonamescache 3.0.2 | CC BY 4.0 |

The texts come from the Sefaria public export. Font licenses are listed in [assets/fonts/licenses/README.md](assets/fonts/licenses/README.md) and shown in the app under *About → Open-source licenses*.

The halachic defaults follow the Shulchan Aruch and Mishnah Berurah (OC 285). Where opinions differ, the app offers a choice and suggests asking your rav. The research behind each choice is in [docs/research/halacha.md](docs/research/halacha.md).

## Documentation

- [docs/DESIGN.md](docs/DESIGN.md): product and design decisions, and why they were made.
- [docs/ACCESSIBILITY.md](docs/ACCESSIBILITY.md): what is supported, how it is tested, and the manual test checklist.
- [docs/BACKEND.md](docs/BACKEND.md): setting up Supabase for the community and backup.
- [docs/RELEASE.md](docs/RELEASE.md): store submission and release checklist.
- [docs/research/](docs/research/): the underlying research on halacha, accessibility, streak UX, forums and Hebrew typography.
