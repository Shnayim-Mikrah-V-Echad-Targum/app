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
- The Torah map's book headers are headings and buttons that say whether their book is expanded. Only the current book starts expanded.

**Announcements and controls**
- Each step in the guided reader is announced once, with its reading and place ("Read the Hebrew again. Reading 2 of 3. Verse 1 of 14"): in an announcement where the platform takes them, and elsewhere by the step header, a live region. So is the step an aliyah opens on when it is chosen from the aliyah tabs. A completed aliyah is announced the same way: in an announcement, or elsewhere by the finished panel's heading, a live region.
- Status messages appear in a SnackBar and are spoken once: by its live region on Android, iOS and the web, and in an announcement on Windows and macOS.
- Search says how many verses were found once typing pauses, when the text is ready if it wasn't, and when Go to verse hands it a search. Each verse found is one item: its reference, then its text, tagged `he` (or `en` for the translation) and spoken as verses are, from the pointed words even when vowels are hidden, with the Targum and the translation named. With bold text or high contrast, matches are outlined as well as bold.
- Go to verse says what its first row offers once typing pauses: the verse found and the week and aliyah that read it, why there is none, or the search. The reader then says the reference of the verse it opened at, which it marks with a rule as well as a wash, so the mark doesn't rest on colour.
- Every icon button has a label and a tooltip. Where there are several alike, each is named for what it acts on ("More options for Rishon", "Increase Reading size").
- A slider is read by its setting and value ("Reading size, 100%"), with a button on either side to step it.

**Web**
- On the web, Flutter's semantics tree is turned on at startup (`SemanticsBinding.ensureSemantics`), so screen readers work without the hidden "enable accessibility" button.

### Vision
- **Themes:** light, dark, sepia, high-contrast light and high-contrast dark. They follow the system setting or can be set manually. The app also honours the platform's high-contrast and bold-text settings.
- **Text size:**
  - The interface follows the system text size; layouts are tested at 200%, and Today and the reader at 300% on a 320 dp phone. A word of the interface never breaks across lines: a label with a word too wide for its room, at the largest sizes, is set just small enough for it, and a name of two parshiyot ("Vayakhel-Pekudei") stays whole. In scripture, words joined by a maqaf stay on one line where the column has room for them; where it hasn't, the line ends after the maqaf, never inside a word. Only a word wider than the column on its own breaks, as some do at the largest reading size on a phone.
  - Scripture has its own reading size (0.5×–5×), which **multiplies** the system size. People with low vision can make the text very large without breaking the interface.
- **Typography controls:**
  - line height (at least 1.6; the default is 1.9)
  - word and letter spacing
  - line width (narrow, medium or wide)
  - justification on or off
  - vowels and cantillation each shown or hidden
  - verse numbers on or off
- **Fonts:** Atkinson Hyperlegible Next for the interface (designed for low vision), and a choice of four scripture fonts.
- **Presets** (*Settings → Accessibility*), as cards that show which are in force (screen readers hear "selected"), each with *Undo*, which puts every setting back as it was:
  - **Large print**
  - **Dyslexia-friendly:** Lexend, wider spacing, no cantillation, focus mode and a narrow column
  - **High contrast**
  - **Low vision**
  - **Reset display**
- **A preview that stays in view:** *Settings → Display* holds a page of the text at the top while its sliders and switches scroll beneath, so each change is seen as it is made. With very large text or a short window, it scrolls away instead, so as not to crowd the settings out. The reader's display sheet opens on the lower part of the screen, over a light scrim, so the verse it changes stays in view.
- **Focus mode** dims everything except the current verse. Dimmed verses use their own ink, which still meets 4.5:1; the high-contrast themes don't dim at all.

### Motor and keyboard
- All tap targets are at least 48×48 dp, which also meets Apple's 44 pt.
- Every action can be done with the keyboard, with a visible focus ring. Tab order follows reading order and mirrors in Hebrew.
- The focus is never lost when the page changes in place:
  - When an aliyah is finished, the panel's first button (the next aliyah, else the haftarah, else Done) takes it. On Android, where announcements aren't taken, the panel's heading is a live region. After the first aliyah ever, the reminders offered keep it until they are answered, and then the panel's first button takes it.
  - *Mark this aliyah as read* at the end of the full text goes once pressed, and the reader itself takes the focus: its keys keep working, and Tab goes on from the top.
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
  | Listen / pause | Ctrl+Shift+L | L |
  | While listening: back or on a verse | Ctrl+Shift+← / Ctrl+Shift+→ | Ctrl+Shift+← / Ctrl+Shift+→ |
  | A verse's options: bookmark, note, copy, share or ask | Shift+F10, or the menu key | Shift+F10, or the menu key |
  | Show shortcuts | F1, or Ctrl+/ | ?, F1, or Ctrl+/ |

  Page Down and Page Up scroll a step that is longer than the screen before they move on, so nothing is skipped at a large reading size. In focus mode, the full text opens on the reader's place, the first verse of the step the guided reader would resume at, and the verse that ↓ or ↑ moves to is scrolled into view, nearer the top of the screen than the bottom. The shortcuts list shows ↑ and ↓ for focus mode only while it is on. Verses are not Tab stops of their own, so Tab reaches *Mark this aliyah as read* at the end of the text. Shift+F10 opens the options of the verse focus mode is on, or else of the first verse in view; the haftarah's page takes it too.

- A verse's options (bookmark, note, copy, share, ask) are among its actions for screen readers: "Verse options" in TalkBack's actions menu and VoiceOver's Actions rotor, and a long press. In the full text, where a long press anywhere in a verse's block opens them, the verse and its Targum each keep their own node and offer them. So with focus mode's tap: a pointer's tap anywhere in the block moves the focus to its verse, and a screen reader's double tap on the verse or its Targum does, with no unlabelled node of the block's own between them.
- On any of the five tabs, Ctrl+K (⌘K on macOS) opens Search, where a verse is reached by its reference or words are searched for. It is not bound in the reader, whose own shortcuts take the keyboard there.
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
- **Listen** reads verse by verse, for readers who follow by ear: the verse being read is highlighted (a techelet rule at its start, which is the cue in high contrast too) and kept in view, scrolling at once under Reduce Motion. The player beneath the text pauses and goes on from the same verse, moves back or on a verse, sets the speech rate and stops; each of its buttons is named for screen readers and takes a 48 dp tap. *Listen along* reads the guided reader's steps one after another, hands-free, to the end of the aliyah.

### Language and direction
- The interface is fully translated into Hebrew, with a mirrored right-to-left layout.
- Scripture is always laid out right to left, whatever the interface language. Forum posts set their direction automatically from their first Hebrew or Latin letter.
- Dates appear in both the Gregorian and Hebrew calendars, and Hebrew numerals are used in the Hebrew interface.

## How it is tested

### Automated (on every pull request, in CI)
The screens are opened as a phone shows them (412 × 915 dp) on a reading-week Monday, Noach 5787, unless said otherwise. The lists of routes are in `test/accessibility/routes.dart`.

- **`test/accessibility/semantics_invariants_test.dart`** opens every route of the app's screens (Today, Parsha and Browse, Progress, the community with a discussion, a new one, a question on a verse and the account page, the bookmarks and notes, every Settings page, the guide, sources and privacy policy, a week within a tab and on its own, a book of the Torah finished, and the pages for links that lead nowhere), the reader (guided at Revi'i, and the full text), a haftarah, and the welcome and each step of onboarding. It shows each in all five themes in turn (light, dark, sepia, high-contrast light and high-contrast dark), as a reader who changes the theme sees it, and runs on each:
  - `SemanticsInvariants` (below)
  - `textContrastGuideline`
  - `androidTapTargetGuideline`
  - `labeledTapTargetGuideline`

  On the pages whose texts load (the reader and the haftarah), it first checks that their verses are shown, so that an error or an empty page can't pass. It runs the same on the full text in focus mode, in the light and sepia themes, once it has checked that the verses are there and that some are dimmed, and on Progress with a parsha read on time, one finished after its Shabbat, one missed and one made up, in all five themes. It keeps the test font: `textContrastGuideline` reads colours from rendered pixels, and the test font's solid glyphs show it the exact text colour where real glyphs show mostly anti-aliased edges.
- **`SemanticsInvariants`** (`test/accessibility/semantics_invariants.dart`) walks the whole semantics tree, skipping only nodes merged into a parent, and fails when:
  1. an enabled button or link has no tap action;
  2. a slider's label is empty or the same as its value;
  3. a text field has no label;
  4. a verse, as the reader labels it ("Verse 9." or "Targum, verse 9." and the Hebrew, or the same in Hebrew), is tagged Hebrew neither by its node's locale nor by a span of its label.

  Nodes Flutter marks hidden are checked too: they are scrolled out of view but still built, and TalkBack and VoiceOver reach them by swiping, so the controls just below the fold on a long page (Settings, Progress, the full text's later verses) are held to the same rules. Its own tests show that each rule fails where it should: a node that says it is a button or a link but has no tap action, as a tile whose gesture was dropped would be, fails the first. Two rules are scoped:
  - Rule 3 applies to fields that take input. Flutter's `SelectableText`, which sets a post and the guide, is a read-only text field whose text is its value.
  - Rule 4 applies to the reader's label of a verse only. Labels such as "Verse 1 of 14", "Verse by verse", "Targum Onkelos" or "תרגום לאנגלית" name parts of the interface, in its own language.
- **`test/accessibility/screens_a11y_test.dart`** lays the same screens out in the bundled fonts, so sizes and overflow are the real ones, and runs `androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline` and `SemanticsInvariants` on:
  - every route, and the reminders page with every reminder on;
  - the welcome and each step of onboarding, in English and Hebrew;
  - the reader, guided and full text, in English and Hebrew, and on a desktop (1366 × 860) the full text and the whole parsha in parallel columns.

  It also checks that nothing overflows and that no word breaks across lines, of the interface or of scripture, where a line may end after a maqaf but not inside a word:
  - at 200% text, in English, on Today, Parsha, Progress, Display settings, a link that leads nowhere, and the welcome and each step of onboarding;
  - at 200% text, in Hebrew, on Today, Progress and the week page;
  - at 200% text on the reader, guided and the whole parsha in English and Hebrew, and the full text in Hebrew;
  - at 300% text on a 320 × 640 phone, on Today and the reader, in English and Hebrew;
  - at a reading size of 400%, with 100% text, on the reader;
  - that Tab reaches Today's main button, which takes the focus ring: a `FocusRingBorder` in the theme's focus colour, drawn outside its fill;
  - that a day of the week strip and a parsha of the Torah map can be activated by a screen reader, that sliders are named by their setting and their buttons by what they do, and that a page keeps its headings, texts and controls apart;
  - the Hebrew right-to-left layout, and the desktop layout with a navigation rail.
- **`test/accessibility/text_contrast_test.dart`** runs `textContrastGuideline` on the reminders page with every reminder on, and checks the colours the guideline skips: the Torah map's tiles in every past state, the week strip's filled days and each book's count, in the light, sepia and high-contrast dark themes.
- **`test/goldens/`** compares Today, the guided reader, Parsha, Progress and Community, in all five themes and in English and Hebrew, with images of them as the capture harness shows them (Friday 9 October 2026, with Shlishi of Bereshit under way), in the bundled fonts. `typography_golden_test.dart` sets "Revi'i · רביעי" and "בְּרֵאשִׁית" in titleLarge and in the Hebrew display face, for each interface font in each language, so a missing glyph shows as a box. They run on Linux only, as CI does, and allow 0.5% of the pixels to differ, for anti-aliasing. After a deliberate visual change, review the captures and run `flutter test --update-goldens test/goldens/`.
- `test/app/reader_widget_test.dart` runs `textContrastGuideline` on the reader (on the test font, for the reason above), checks the labels of verses, notes, the Targum and Rashi, and their language tags on Android, Windows and the web, and checks that focus mode's dimmed verses keep 4.5:1 in every theme.
- `test/ui/palette_contrast_test.dart` computes the WCAG contrast of every text and graphics colour pair in the palette (docs/DESIGN_SYSTEM.md §3.5): 4.5:1 for text and 3:1 for graphics, 7:1 and 4.5:1 in the high-contrast themes, and 7:1 for scripture everywhere.
- `test/ui/focus_test.dart` checks the focus ring of buttons, the FAB, a notice's action, cards and rows, and the slider's thumb, and that it shows only while the keyboard is in use.
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
