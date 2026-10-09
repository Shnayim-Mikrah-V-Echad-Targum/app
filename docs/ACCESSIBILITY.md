# Accessibility

The target is **WCAG 2.2 Level AA** on every platform, plus the platform guidelines: Apple's Human Interface Guidelines, Material 3, and Windows' Narrator and keyboard conventions. Where it costs little, the app goes further, for example AAA-level contrast themes, very large scripture text, and fonts for dyslexia.

The research behind this is in [research/accessibility.md](research/accessibility.md). The user-facing accessibility statement is in the app under *About → Accessibility statement*.

## What is supported

### Screen readers (TalkBack, VoiceOver, Narrator, NVDA, JAWS)

**Verses**
- Each verse is a single node with a curated spoken label, such as "Verse 9." followed by the text. This avoids reading glyph by glyph.
- The Hebrew part of the label is tagged `he`, so the screen reader switches voice. Cantillation is removed by default because screen readers mispronounce it or stop at it.
- *Settings → Accessibility → Screen reader text* changes what the label contains:
  - **vowels kept** (the default)
  - **letters only**
  - **every mark**, for braille displays
- The Divine Name is spoken as **Adonai** or **Hashem**, as the user chooses. This applies to screen-reader labels and to text-to-speech.
- Notes, ketiv/qere and the Targum each have their own labels.

**Structure and state**
- Screen titles and section headers are marked as headings with levels, so heading navigation works.
- Progress, streak rings and status badges have text equivalents. Colour is never the only signal.
- Each aliyah tile announces the state of all three readings. The week strip announces each day's status.

**Announcements and controls**
- Steps in the guided reader and a completed aliyah are announced as live updates where the platform supports them. Elsewhere they appear in a SnackBar that is read aloud.
- Every icon button has a label and a tooltip.

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
- **Focus mode** dims everything except the current verse. Dimmed verses use their own ink, which still meets 4.5:1; the high-contrast themes don't dim at all.

### Motor and keyboard
- All tap targets are at least 48×48 dp, which also meets Apple's 44 pt.
- Every action can be done with the keyboard, with a visible focus ring. Tab order follows reading order and mirrors in Hebrew.
- Reader shortcuts. On macOS, use ⌘ in place of Ctrl.

  | Keys | Action |
  |---|---|
  | Page Down, or Alt+↓ | Next step |
  | Page Up, or Alt+↑ | Previous step |
  | Ctrl+= / Ctrl+− | Larger / smaller scripture text |
  | Ctrl+Shift+T | Show or hide cantillation |
  | Ctrl+Shift+N | Show or hide vowels |
  | Ctrl+Shift+L | Listen / stop |
  | F1, or Ctrl+/ | Show shortcuts |

- No action needs a swipe, drag or multi-finger gesture. Everything is a tap, click or key press, and nothing has a time limit.
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
  - contrast in all five themes: light, dark, sepia, high-contrast light and high-contrast dark
  - no overflow at 200% text on the busiest screens
  - the Hebrew right-to-left layout
  - the desktop layout with a navigation rail
- `test/app/reader_widget_test.dart` runs the guidelines on the reader, checks the verse labels, and checks that focus mode's dimmed verses keep 4.5:1 in every theme.
- `test/ui/palette_contrast_test.dart` computes the WCAG contrast of every text and graphics colour pair in the palette (docs/DESIGN_SYSTEM.md §3.5): 4.5:1 for text and 3:1 for graphics, 7:1 and 4.5:1 in the high-contrast themes, and 7:1 for scripture everywhere.
- Unit tests check the spoken-label pipeline (`test/core/text/hebrew_text_test.dart`), including Divine Name substitution and stripping cantillation.

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
- **Cantillation:** no screen reader can convey it. Reading with ta'amim needs sight or a teacher. The *every mark* label setting lets braille users get every mark.
- **Flutter on the web** draws text on a canvas. The semantics tree is mirrored as accessible DOM nodes, but browser find-in-page and the browser's own text zoom do not apply to it. Use the in-app reading size instead.

## Reporting problems

The accessibility statement in the app gives a contact address (the `SUPPORT_EMAIL` build setting) and a link to the issue tracker. Accessibility bugs are treated as release blockers.
