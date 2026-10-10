# Accessibility

The target is **WCAG 2.2 Level AA** on every platform, plus the platform guidelines: Apple's Human Interface Guidelines, Material 3, and Windows' Narrator and keyboard conventions. Where it costs little, the app goes further, for example AAA-level contrast themes, very large scripture text, and fonts for dyslexia.

The research behind this is in [research/accessibility.md](research/accessibility.md). The user-facing accessibility statement is in the app under *About → Accessibility statement*.

## What is supported

### Screen readers (TalkBack, VoiceOver, Narrator, NVDA, JAWS)

**Verses**
- Each verse is a single node with a curated spoken label, such as "Verse 9." followed by the text, or "Targum, verse 9." for Onkelos. This avoids reading glyph by glyph.
- The Hebrew is tagged `he`, so the screen reader can switch to a Hebrew voice:
  - **Android and iOS:** only the Hebrew part of the label is tagged, so "Verse 9." is read in the interface language.
  - **The web:** a node can carry only one language there, so the whole label is in Hebrew ("פסוק 9.") and the node is tagged `he`. This sets the `lang` attribute.
  - **Windows:** Flutter's bridge passes no language, so the label is as on Android and iOS, and Narrator or NVDA reads "Verse 9." (or "Targum, verse 9.") in its own voice.
- Cantillation is removed by default because screen readers mispronounce it or stop at it. The extraordinary points written over some words in the scroll (as over וישקהו, Genesis 33:4) are shown whether or not cantillation is, and are never spoken.
- *Settings → Accessibility → Screen reader text* changes what the label contains:
  - **vowels kept** (the default)
  - **letters only**
  - **every mark**, for braille displays
- The Divine Name is spoken as **Adonai** or **Hashem**, as the user chooses. This applies to screen-reader labels and to text-to-speech, in the Torah and haftarah, in Targum Onkelos (which writes it יְיָ) and in Rashi (who writes ה'). A ה' that cites a chapter, as in (ישעיהו ה'), or counts something stays a number.
- Each of Rashi's comments is its own node, read the same way and tagged `he`, or `en` for Rashi in English, whose quoted Hebrew is tagged `he` and read the same way. The English translation is tagged `en`, so it is read in an English voice in the Hebrew interface too.
- Notes, ketiv/qere and the Targum each have their own labels. A note is read like the verse: without cantillation, and with the Divine Name as chosen.

**Structure and state**
- Screen titles and section headers are marked as headings with levels, so heading navigation works.
- A heading is a node of its own, never merged with the text or controls around it. A card that opens something when tapped is read as one node.
- Progress, streak rings and status badges have text equivalents. Colour is never the only signal.
- Each aliyah tile announces the state of all three readings. The week strip announces each day's status, and a day with reading, like each parsha of the Torah map, is a button that opens it.

**Announcements and controls**
- Each step in the guided reader is announced once, with its reading and place ("Read the Hebrew again. Reading 2 of 3. Verse 1 of 14"): in an announcement where the platform takes them, and elsewhere by the step header, a live region. So is the step an aliyah opens on when it is chosen from the aliyah tabs. A completed aliyah is announced the same way: in an announcement, or elsewhere by the finished panel's heading, a live region.
- Status messages appear in a SnackBar and are spoken once: by its live region on Android, iOS and the web, and in an announcement on Windows and macOS.
- Every icon button has a label and a tooltip. Where there are several alike, each is named for what it acts on ("More options for Rishon", "Increase Reading size").
- A slider is read by its setting and value ("Reading size, 100%"), with a button on either side to step it.

**Web**
- On the web, Flutter's semantics tree is turned on at startup (`SemanticsBinding.ensureSemantics`), so screen readers work without the hidden "enable accessibility" button.

### Vision
- **Themes:** light, dark, sepia, high-contrast light and high-contrast dark. They follow the system setting or can be set manually. The app also honours the platform's high-contrast and bold-text settings.
- **Text size:**
  - The interface follows the system text size; layouts are tested at 200%.
  - Scripture has its own reading size (0.5×–5×), which **multiplies** the system size. People with low vision can make the text very large without breaking the interface.
- **Typography controls:**
  - line height (at least 1.6; the default is 1.9)
  - word and letter spacing
  - line width (narrow, medium or wide)
  - justification on or off
  - vowels and cantillation each shown or hidden
  - verse numbers on or off
- **Fonts:** Atkinson Hyperlegible Next for the interface (designed for low vision), and a choice of four scripture fonts.
- **Presets** (*Settings → Accessibility*):
  - **Large print**
  - **Dyslexia-friendly:** Lexend, wider spacing, no cantillation, focus mode and a narrow column
  - **High contrast**
  - **Low vision**
  - **Reset**
- **Focus mode** dims everything except the current verse.

### Motor and keyboard
- All tap targets are at least 48×48 dp, which also meets Apple's 44 pt.
- Every action can be done with the keyboard, with a visible focus ring. Tab order follows reading order and mirrors in Hebrew.
- The focus is never lost when the page changes in place:
  - When an aliyah is finished, the panel's first button (the next aliyah, else the haftarah, else Done) takes it. On Android, where announcements aren't taken, the panel's heading is a live region.
  - Continuing from the panel, leaving it with Back, or reaching the first step, where Back is disabled, gives it to Next.
  - After *Email me a code*, the code field takes it, and a status message says where the code went.
  - *Load more* keeps it while it loads. Then the first discussion loaded, in the button's place, takes it, and a status message says how many came.
  - *Show earlier posts* keeps it while it loads, and while more remain. Once the earliest posts are in and the button goes, the first post, in its place, takes it.
- Reader shortcuts. In the app, the display shortcuts are Ctrl chords. On the web they are single keys, because Chrome and Edge keep Ctrl+Shift+T, Ctrl+Shift+N and Ctrl+= for themselves. On macOS and iOS, use ⌘ in place of Ctrl and ⌥ in place of Alt. *Settings → Accessibility → Single-key shortcuts*, shown on the web only, turns the single keys off for speech input and screen-reader quick keys (WCAG 2.1.4).

  | Action | Windows, macOS, Linux, Android and iOS | Web |
  |---|---|---|
  | Scroll the text | Ctrl+↑ / Ctrl+↓ | ↑ / ↓, or Space |
  | Down a page, then the next step | Page Down | Page Down |
  | Up a page, then the previous step | Page Up | Page Up |
  | Next step | Alt+↓ | Alt+↓ |
  | Previous step | Alt+↑ | Alt+↑ |
  | Focus mode, full text: next or previous verse | ↓ / ↑ | ↓ / ↑ |
  | Larger / smaller scripture text | Ctrl+= / Ctrl+− | + or = / − |
  | Show or hide cantillation | Ctrl+Shift+T | T |
  | Show or hide vowels | Ctrl+Shift+N | N |
  | Listen / stop | Ctrl+Shift+L | L |
  | Show shortcuts | F1, or Ctrl+/ | ?, F1, or Ctrl+/ |

  Page Down and Page Up scroll a step that is longer than the screen before they move on, so nothing is skipped at a large reading size. In focus mode, the full text opens on the reader's place, and the verse that ↓ or ↑ moves to is scrolled into view, nearer the top of the screen than the bottom. Verses are not Tab stops of their own, so Tab reaches *Mark this aliyah as read* at the end of the text.

- In the community, F5 or Ctrl+R (⌘R on macOS) refreshes the forums, a forum, a thread or the moderation queue. On the web those keys stay the browser's. Each of these pages also has a Refresh button.
- No action needs a swipe, drag or multi-finger gesture. Pull to refresh has a Refresh button beside it. Everything is a tap, click or key press, and nothing has a time limit.
- The screen can be kept on while reading, which is on by default.

### Cognitive and learning
- One clear next step on the Today screen. The guided reader shows one step at a time with a progress bar.
- Plain-language copy, with no streak shaming and no countdown pressure. Grace days are applied automatically, and a "Life happens" pause is available.
- Fonts for dyslexia (Lexend, OpenDyslexic) are offered as choices, not defaults, because the evidence for them is mixed.
- Positions are saved automatically, so leaving and coming back is safe.
- Onboarding has four short screens, and every choice can be changed later.

### Motion, sound and haptics
- **Reduce motion** follows the system setting and can also be set in the app. It removes page transitions and celebration animations.
- Haptics can be turned off.
- Nothing plays sound without the user asking. Text-to-speech starts only on request.

### Language and direction
- The interface is fully translated into Hebrew, with a mirrored right-to-left layout.
- Scripture is always laid out right to left, whatever the interface language. Forum posts set their direction automatically from their first Hebrew or Latin letter.
- Dates appear in both the Gregorian and Hebrew calendars, and Hebrew numerals are used in the Hebrew interface.

## How it is tested

### Automated (on every pull request, in CI)
- `test/accessibility/screens_a11y_test.dart` runs Flutter's accessibility guidelines on 12 screens:
  - `androidTapTargetGuideline`
  - `iOSTapTargetGuideline`
  - `labeledTapTargetGuideline`
  - `textContrastGuideline`
- The same test also checks:
  - contrast in four themes: light, dark, high-contrast light and high-contrast dark
  - no overflow at 200% text on the busiest screens
  - the Hebrew right-to-left layout
  - the desktop layout with a navigation rail
- `test/app/reader_widget_test.dart` runs the guidelines on the reader and checks the labels of verses, notes, the Targum and Rashi, and their language tags on Android, Windows and the web.
- Unit tests check the spoken-label pipeline (`test/core/text/hebrew_text_test.dart`), including Divine Name substitution in the Torah, the Targum and Rashi, and stripping cantillation but not the extraordinary points.

### Manual (before each release)
Each item below is tested with the screen reader named:

| Platform | Screen reader |
|---|---|
| Android | TalkBack |
| iOS | VoiceOver |
| Windows | Narrator and NVDA |
| Web | NVDA + Chrome, and VoiceOver + Safari |

1. **First run:** complete onboarding using only the screen reader.
2. **Reading:** read one aliyah in the guided reader. Check that each step is announced, verses are read in Hebrew, and finishing is announced.
3. **Logging:** mark an aliyah as read from the week overview and choose a past date.
4. **Status:** find your streak and grace days on the Today and Progress screens.
5. **Community:** sign in with a code, open the weekly thread, post a reply, report a post and block a user.
6. **Settings:** change the theme, reading size and screen-reader text. Confirm that every control announces its name and current value.
7. **Large text:** repeat steps 2 and 4 at the largest system text size, and in the high-contrast dark theme.
8. **Keyboard:** repeat steps 2 and 5 with the keyboard only on Windows and the web. Check that the focus ring is always visible.
9. **Hebrew:** repeat steps 1 and 2 with the interface in Hebrew.
10. **Switch Access:** run Switch Access (Android) or Switch Control (iOS) on the reader.

Record the results in the release checklist ([RELEASE.md](RELEASE.md)).

## Known limitations

- **Hebrew screen-reader voices:**
  - Hebrew voices vary by platform, and some systems have none installed.
  - In that case the screen reader reads the Hebrew with its default voice, usually badly.
  - Before reading aloud, the app checks for a Hebrew text-to-speech voice. If there is none, it says so and points to the device's speech settings.
- **Narrator and NVDA on Windows** can't switch voices within the app, because Flutter's Windows accessibility bridge has no language property. They read the Hebrew labels in the voice of the screen reader's own language. Choosing a Hebrew voice in the screen reader's settings while reading is the workaround.
- **Cantillation:** no screen reader can convey it. Reading with ta'amim needs sight or a teacher. The *every mark* label setting lets braille users get every mark.
- **Flutter on the web** draws text on a canvas. The semantics tree is mirrored as accessible DOM nodes, but browser find-in-page and the browser's own text zoom do not apply to it. Use the in-app reading size instead.

## Reporting problems

The accessibility statement in the app gives a contact address (the `SUPPORT_EMAIL` build setting) and a link to the issue tracker. Accessibility bugs are treated as release blockers.
