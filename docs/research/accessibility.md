# Accessibility Research: Weekly Torah Portion Reader (Flutter: Android, iOS, Web, Windows)

*Prepared 2026-10-09. Scope: Hebrew with nikud and cantillation (te'amim), Aramaic Targum (Onkelos), daily and weekly streaks, community forums.*

> **Method and caveats.** I gathered this research with web search. Direct page fetching was blocked in this environment, so many citations point to the official page as it showed up in search results rather than to a full read of the page. Items marked **[verify]** come from developer knowledge or from secondary sources that I could not confirm against a primary source. Check them against the current SDK and docs before you rely on them. The Flutter docs current at the time of writing reflect **Flutter 3.44.x** (docs page updated 2026-05-31). One third-party source reports fixes in 3.47.

---

## Contents

0. [Executive summary: the 15 things that matter most](#0-executive-summary)
1. [Standards and legal context](#1-standards-and-legal-context)
2. [WCAG 2.2 criteria mapped to this app](#2-wcag-22-criteria-mapped-to-this-app)
3. [Apple HIG and Material Design 3 / Android guidance](#3-apple-hig-and-material-design-3--android-guidance)
4. [Flutter implementation: APIs, platform notes, pitfalls](#4-flutter-implementation)
5. [Hebrew, nikud, cantillation, Aramaic, and RTL](#5-hebrew-nikud-cantillation-aramaic-and-rtl)
6. [Cognitive and learning accessibility](#6-cognitive-and-learning-accessibility)
7. [Low vision and color](#7-low-vision-and-color)
8. [Motor accessibility](#8-motor-accessibility)
9. [Hearing accessibility](#9-hearing-accessibility)
10. [Accessibility statement and feedback channel](#10-accessibility-statement-and-feedback-channel)
11. [Release testing checklist](#11-release-testing-checklist)
12. [Feature checklist for this app](#12-feature-checklist-for-this-app)
13. [Flutter implementation notes (API reference and snippets)](#13-flutter-implementation-notes)
14. [Sources](#14-sources)

---

## 0. Executive summary

1. **Expose scripture to screen readers verse by verse, with a cleaned-up spoken label.** Hebrew TTS voices are built for modern Hebrew. Some biblical marks are not spoken, braille displays can show Unicode placeholders, and untagged Hebrew may be read letter by letter in English ([AppleVis thread, 2021](https://www.applevis.com/comment/128206)). Build each verse's semantics label from text with the te'amim removed and the nikud kept (configurable). Keep the visible text full-fidelity. Tag the label as Hebrew with `LocaleStringAttribute` / `Semantics.localeForSubtree`.
2. **Let users choose how the Divine Name is spoken** (Adonai / HaShem / spelled out). Without a setting, a TTS engine will try to pronounce the Tetragrammaton, which many users will find offensive or confusing ([Logos forum discussion of the same problem](https://community.logos.com/discussion/comment/610518)). Read the *qere*, not the *ketiv*.
3. **Give the scripture its own font size control, separate from and multiplied with the system text scale,** going well past 200% (target 400% or more of the base size). Do not clamp the system text scale with `MediaQuery.withClampedTextScaling` unless there is no other way.
4. **Offer reading themes:** light, dark, sepia/cream, high-contrast light, high-contrast dark, and a custom foreground/background (WCAG 1.4.8 AAA). Map the system *Increase Contrast* setting to `MaterialApp.highContrastTheme` / `highContrastDarkTheme`. Aim for **7:1 contrast for scripture text**, because nikud and te'amim are hair-thin strokes.
5. **Add display toggles:** show/hide te'amim, show/hide nikud, show/hide Targum, adjust line spacing, word spacing, and letter spacing, align to start instead of justifying, and set a maximum line width. Sefaria already offers vowel and cantillation toggles, and users will expect them ([Sefaria help](https://help.sefaria.org/hc/en-us/articles/18613829394204-How-to-View-a-Hebrew-Text-With-or-Without-Vowels-Cantillation-Markings-and-Punctuation)).
6. **Add a focus or reading-ruler mode** (highlight the current verse and dim the rest) and a narrow-column option. Evidence: digital reading rulers help many readers, with the biggest gains for readers with dyslexia, but no single style suits everyone, so make it configurable ([Adobe/CHI 2023](https://research.adobe.com/publication/digital-reading-rulers-evaluating-inclusively-designed-rulers-for-readers-with-dyslexia-and-without)). Shorter lines improved reading speed by 27% for readers with dyslexia ([Schneps et al. 2013](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3734020/)).
7. **Don't ship OpenDyslexic as "the dyslexia fix".** The best-controlled study found no benefit ([Wery & Diliberto](https://pmc.ncbi.nlm.nih.gov/articles/PMC5629233/)). It is also Latin-only. Letter and word spacing have better evidence, including a Hebrew study ([Dotan & Katzir 2018](https://cris.iucc.ac.il/en/publications/mind-the-gap-increased-inter-letter-spacing-as-a-means-of-improvi/)).
8. **Make streaks forgiving and culturally aware.** Shabbat and Yom Tov must never break a daily streak. Provide automatic freezes or repairs, a plain-language definition of "a day" (time zone, sunset or midnight), an option to hide streaks entirely, and no shame-based copy ([streak design review](https://screensdesign.com/articles/mobile-app-streak-design-examples/), [W3C COGA "avoid mistakes" objective](https://www.w3.org/WAI/WCAG2/supplemental/objectives/o4-minimize-mistakes/)).
9. **Never make a gesture the only way to do something.** Swiping between aliyot also needs buttons. Swipe-to-dismiss also needs `customSemanticsActions`. Drag sliders also need +/- buttons (WCAG 2.5.1, 2.5.7).
10. **Size touch targets at 48x48 dp on Android and 44x44 pt on iOS** (WCAG AA minimum: 24x24 CSS px). Make each verse row one large tap target. Enforce this in CI with `meetsGuideline(androidTapTargetGuideline)` and the other three guidelines.
11. **Make keyboard use first-class on Windows and web:** visible focus rings (3:1), logical `FocusTraversalGroup`s, `Shortcuts`/`Actions` for next or previous verse and aliyah, font size, and theme. Single-key shortcuts must be remappable or off by default (WCAG 2.1.4).
12. **Flutter web: semantics are off until the user activates the hidden "Enable accessibility" placeholder.** Either call `SemanticsBinding.instance.ensureSemantics()` (this has a performance cost) or make sure the placeholder works and is documented ([Flutter web accessibility](https://docs.flutter.dev/ui/accessibility/web-accessibility)).
13. **Status messages** ("Portion completed", "Streak: 12 weeks", "Post published", "Saved draft") must be announced without moving focus. Use `Semantics(liveRegion: true)`, or `SemanticsService.announce` where `MediaQuery.supportsAnnounceOf` is true (WCAG 4.1.3).
14. **Make forum sign-in and posting accessible:** password manager autofill (`AutofillGroup`), paste always allowed, passkey or magic-link options, no cognitive CAPTCHAs (WCAG 3.3.8), auto-saved drafts, inline error messages tied to fields (3.3.1–3.3.3), and per-post RTL/LTR auto-direction.
15. **Publish an accessibility statement and add an in-app "Report an accessibility problem" path.** Fill in Apple's **Accessibility Nutrition Labels** honestly. They are voluntary today but will become required ([Apple](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels)).

---

## 1. Standards and legal context

| Standard / law | Relevance | Notes |
|---|---|---|
| **WCAG 2.2** (W3C Rec., Oct 2023) | Baseline target: **AA**, plus selected AAA criteria for the reading view | New in 2.2: 2.4.11 Focus Not Obscured (AA), 2.4.12 (AAA), 2.4.13 Focus Appearance (AAA), 2.5.7 Dragging (AA), 2.5.8 Target Size Min (AA), 3.2.6 Consistent Help (A), 3.3.7 Redundant Entry (A), 3.3.8 Accessible Auth (AA), 3.3.9 (AAA). 4.1.1 Parsing removed. ([Deque summary](https://dequeuniversity.com/resources/wcag-2.2), [W3C WCAG 2.2](https://www.w3.org/TR/WCAG22/)) |
| **WCAG2ICT** (W3C Group Note, published Oct 8, 2024) | How each WCAG criterion applies to *non-web software* (native apps) | Informative, not normative. Referenced by the US ADA Title II rule. Likely to influence EN 301 549 ([US Access Board](https://www.access-board.gov/news/2024/10/08/wcag2ict-published-as-w3c-group-note/), [TetraLogical](https://tetralogical.com/blog/2024/07/18/WCAG2ICT/)) |
| **WCAG2Mobile** (W3C draft note) | Mobile-specific mapping (native, mobile web, hybrid) | [w3.org/TR/wcag2mobile](https://www.w3.org/TR/wcag2mobile/) (still a draft when found) |
| **European Accessibility Act** (in force since **June 28, 2025**) | Applies if you have EU users. Covers mobile apps for consumer services and **e-books and dedicated reading software** | Tested against EN 301 549 (WCAG 2.1 AA plus software clauses). Microenterprise exemption for services (<10 staff and ≤€2M) **[verify for your org]** ([Inside Global Tech](https://www.insideglobaltech.com/2025/06/10/european-accessibility-act-june-2025-deadline-has-arrived/), [SGS](https://www.sgs.com/en/news/2025/09/safeguards-13925-european-accessibility-act-eaa-takes-effect-unifying-standards-across-the-eu)) |
| **Israel, Equal Rights for Persons with Disabilities regulations / IS 5568** | Likely Hebrew-speaking audience. Secondary sources say mobile apps are in scope | Legal floor treated as WCAG 2.0 AA. Sources disagree on 2.0 vs 2.1. Requires an accessibility statement and coordinator contact **[verify with counsel]** ([BOIA](https://www.boia.org/blog/israels-digital-accessibility-laws-an-overview), [Wawsome](https://www.wawsome.com/blog/israel-digital-accessibility-law-is-5568-guide)) |
| **Apple Accessibility Nutrition Labels** | App Store listing declares support for VoiceOver, Voice Control, Larger Text, Dark Interface, Differentiate Without Color Alone, Sufficient Contrast, Reduced Motion, Captions, Audio Descriptions | Declare support only if **all common tasks** (first launch, login, purchase, settings, core flows) work with that feature. Voluntary now, required later ([overview](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels), [WWDC25 session 224](https://developer.apple.com/videos/play/wwdc2025/224/)) |
| **Google Play** | Store listing accessibility tags (screen-reader friendly, visual/hearing/learning/motor assistance) | AccessibilityService declarations apply only if you *implement* an accessibility service, which you shouldn't need to ([Play Console help](https://support.google.com/googleplay/android-developer/answer/10964491)) |

**Native-app applicability debates to know about:**
- **1.4.4 Resize Text** applies to native apps as written (WCAG2ICT). Test with the OS text-size settings and your in-app control. System "Larger Text" is *not* treated as assistive technology, so it counts. Screen magnifiers do not ([WebAIM list](https://webaim.org/discussion/mail_message?id=42120), [WCAG2ICT minutes 2024](https://www.w3.org/2024/04/26-wcag2ict-minutes.html)).
- **1.4.10 Reflow** is web-oriented and its mapping to native screens is unsettled. Apply its spirit: no two-dimensional scrolling for reading text at 320 dp width or at the largest text sizes ([W3C Understanding Reflow](https://www.w3.org/WAI/WCAG22/Understanding/reflow)).
- **1.4.12 Text Spacing** is contested for native apps, because there is no OS-level spacing setting ([W3C WAI-IG thread](https://lists.w3.org/Archives/Public/w3c-wai-ig/2020JulSep/0002.html), [Patrick Lauke / html5accessibility](https://html5accessibility.com/stuff/2024/07/09/peaky-wcag-level-aa-bang-for-your-app-a11y-buck/)). **For this app, satisfy it anyway** by offering in-app spacing controls (line ≥1.5×, paragraph ≥2×, letter ≥0.12×, word ≥0.16×) without clipping. Flutter **web** honors user-stylesheet and extension text-spacing overrides since Flutter 3.41 (see §4.7).

---

## 2. WCAG 2.2 criteria mapped to this app

Level shown in brackets. **Bold** criteria are high risk for this app.

### Perceivable
| SC | Requirement | What it means here |
|---|---|---|
| 1.1.1 Non-text Content [A] | Text alternatives | Icon buttons (bookmark, share, audio, settings) need labels. Decorative ornaments (parasha dividers, flourishes) go in `ExcludeSemantics`. Forum images need user-entered alt text (prompt for it on upload) |
| 1.2.1–1.2.5 Time-based media [A/AA] | Transcripts / captions / audio description | If you add chanting audio, the Hebrew text is the transcript, but it must be reachable from the player. Synchronized highlighting is a bonus. Any video (shiurim) needs captions |
| **1.3.1 Info & Relationships [A]** | Structure is programmatic | Parasha → aliyah → chapter:verse headings use `Semantics(headingLevel: n)` so VoiceOver's rotor and TalkBack's heading navigation work. Forum threads use list semantics and headings |
| **1.3.2 Meaningful Sequence [A]** | Reading order is correct | Hebrew verse, then its Targum, then the English (if any) must come in a logical order for screen readers in RTL. Verify, and set `OrdinalSortKey` explicitly where needed |
| 1.3.4 Orientation [AA] | Don't lock orientation | Support portrait and landscape (landscape reading is popular on tablets) |
| 1.3.5 Identify Input Purpose [AA] | Autofill purposes | `autofillHints` on username, email, password, and new-password fields |
| **1.4.1 Use of Color [A]** | Color is not the only cue | Streak calendar (done/missed/freeze) needs icons or patterns plus labels. Te'amim category coloring (disjunctive vs. conjunctive) needs a non-color cue. Forum unread state needs a dot or bold plus a label |
| **1.4.3 Contrast (Min) [AA]** | 4.5:1 text, 3:1 large text (≥18pt, or ≥14pt bold) | Applies to nikud and te'amim if you color them differently ("gray te'amim" commonly fails) |
| **1.4.6 Contrast (Enhanced) [AAA]** | 7:1 / 4.5:1 | **Target for the scripture view.** The diacritics are very small strokes |
| **1.4.4 Resize Text [AA]** | 200% with no loss | Every screen must work at Android 200% and iOS AX5 (body text over 300%) ([Apple Larger Text criteria](https://developer-rno.apple.com/help/app-store-connect/manage-app-accessibility/larger-text-evaluation-criteria)) |
| 1.4.5 Images of Text [AA] | Use real text | Never render pesukim or headings as images |
| 1.4.8 Visual Presentation [AAA] | User-chosen fg/bg, width ≤80 chars, no justification, line spacing ≥1.5, resize 200% without horizontal scroll | **Implement as reading settings** (§12). Traditional Chumash layout is justified, so offer "align start" ([Understanding 1.4.8](https://www.w3.org/WAI/WCAG22/Understanding/visual-presentation)) |
| 1.4.10 Reflow [AA] | No 2D scroll at 320 CSS px | Reading text must wrap, with no horizontal scrolling at large sizes. Side-by-side Hebrew and Targum columns must stack at narrow widths or large text |
| **1.4.11 Non-text Contrast [AA]** | 3:1 for UI components, focus rings, icons, and graphical states | Streak rings and progress bars, checkbox borders, focus indicators |
| 1.4.12 Text Spacing [AA] | No loss at 1.5 / 2 / 0.12 / 0.16 | See §1. Provide the controls in-app and test that nothing clips |
| 1.4.13 Content on Hover/Focus [AA] | Dismissible, hoverable, persistent | Desktop/web tooltips (e.g., te'am name on hover) must be dismissible with Esc and must not vanish when the pointer moves onto them |

### Operable
| SC | Requirement | What it means here |
|---|---|---|
| **2.1.1 Keyboard [A]** / 2.1.2 No Trap [A] | Everything works by keyboard | Windows and web: reader, settings, forum composer, dialogs. Esc closes dialogs. No focus trap in the rich text editor |
| **2.1.4 Character Key Shortcuts [A]** | Single-key shortcuts can be turned off, remapped, or apply only on focus | If you add `j`/`k` for next/previous verse, make them active only when the reader has focus, or provide a toggle |
| **2.2.1 Timing Adjustable [A]** | Time limits can be adjusted | Avoid timed quizzes. Session expiry while composing a post must warn the user and preserve the draft |
| 2.2.2 Pause, Stop, Hide [A] | Auto-moving content can be stopped | No auto-advancing carousels. Auto-scroll or "teleprompter" reading must have pause and speed controls |
| 2.3.1 Three Flashes [A] | No flashing | Streak celebrations (confetti) must not flash more than 3 times per second |
| **2.3.3 Animation from Interactions [AAA]** | Motion triggered by interaction can be disabled | Respect `MediaQuery.disableAnimationsOf` and add an in-app "Reduce motion" setting (W3C lists an in-app preference as a sufficient technique) ([Understanding 2.3.3](https://w3c.github.io/wcag/understanding/animation-from-interactions.html)) |
| 2.4.2 Page Titled [A] | Screen titles | Web: set the `Title` widget per route. Native: announce the route name (AppBar title is a header) |
| **2.4.3 Focus Order [A]** | Logical order | `FocusTraversalGroup` per region (top bar, reader, bottom player). RTL order verified |
| 2.4.6 Headings & Labels [AA] | Descriptive | "Aliyah 3 (Shlishi), Genesis 1:14–23" rather than "Section 3" |
| **2.4.7 Focus Visible [AA]** | Visible focus | Custom verse rows need a clear focus ring (not just a subtle tint) |
| **2.4.11 Focus Not Obscured (Min) [AA]** | Focused item not *entirely* hidden by sticky UI | The sticky audio player and bottom nav must not cover the focused verse. Scroll focused items into view, accounting for those bars |
| 2.4.12 / 2.4.13 [AAA] | Not obscured at all / focus indicator ≥2px and 3:1 | Good targets for desktop |
| **2.5.1 Pointer Gestures [A]** | Path-based or multi-touch gestures have single-pointer alternatives | Swipe between aliyot: add prev/next buttons. Pinch-to-zoom text: add an A−/A+ control |
| 2.5.2 Pointer Cancellation [A] | Activate on up-event | Use standard `onTap` (fires on up). Avoid `onTapDown` for actions |
| **2.5.3 Label in Name [A]** | Accessible name contains the visible label | Critical for **Voice Control** ("Tap Mark complete"). Don't label a button visibly "Done" and semantically "Complete reading" |
| 2.5.4 Motion Actuation [A] | Shake or tilt has an alternative and can be disabled | Don't use shake-to-undo or shake-to-report without a button and a toggle |
| **2.5.7 Dragging Movements [AA]** | Drag has a single-pointer alternative | Font-size slider also gets +/- buttons. Reordering bookmarks also gets "Move up/down" actions |
| **2.5.8 Target Size (Min) [AA]** | ≥24×24 CSS px, or enough spacing | Platform targets are larger (44pt / 48dp). Aim for those. Inline forum links are exempt (inline exception) |

### Understandable
| SC | Requirement | What it means here |
|---|---|---|
| **3.1.1 Language of Page [A]** / **3.1.2 Language of Parts [AA]** | Programmatic language | UI locale (en/he). Hebrew passages tagged `he`. Targum tagged `arc` (Aramaic) or `he` for a practical TTS fallback (see §5.6). English translation tagged `en` |
| 3.2.1/3.2.2 On Focus / On Input [A] | No surprise context changes | Changing a setting must not navigate away. Selecting a parasha from a dropdown must not auto-jump unless that is clearly expected |
| 3.2.3 / 3.2.4 Consistent Navigation & Identification [AA] | Consistency | Same icons and labels everywhere |
| 3.2.6 Consistent Help [A] | Help in the same place | "Help & accessibility feedback" in the same menu position on every screen |
| **3.3.1 Error Identification [A]** / **3.3.3 Error Suggestion [AA]** | Errors described in text with fixes | Forum: "Post is empty. Write at least one word." tied to the field (`InputDecoration.errorText`) and announced |
| 3.3.2 Labels or Instructions [A] | Persistent labels | Use `labelText`, not placeholder-only `hintText` |
| 3.3.4 Error Prevention [AA] | Reversible / confirm | Deleting a post or resetting streak data: confirm and allow undo |
| **3.3.7 Redundant Entry [A]** | Don't re-ask | Remember display name and preferences. Don't re-enter email at multi-step signup |
| **3.3.8 Accessible Authentication (Min) [AA]** | No cognitive test without an alternative | Allow paste and password managers. Offer passkeys, Sign in with Apple/Google, or magic links. No puzzle CAPTCHAs ([Understanding 3.3.8](https://www.w3.org/WAI/WCAG22/Understanding/accessible-authentication.html)) |

### Robust
| SC | Requirement | What it means here |
|---|---|---|
| **4.1.2 Name, Role, Value [A]** | Custom widgets expose role and state | Custom toggles (show te'amim), the streak calendar day cells ("Tuesday 7 October, read, streak day 12"), and the audio scrubber (`Semantics(slider: true, value:, increasedValue:, onIncrease:)`) |
| **4.1.3 Status Messages [AA]** | Announced without focus | "Marked as read", "Streak extended", "Draft saved", "3 new replies". Use `liveRegion` or `announce` (§4.4) ([ARIA22 role=status technique](https://www.w3.org/WAI/WCAG22/Techniques/aria/ARIA22)) |

---

## 3. Apple HIG and Material Design 3 / Android guidance

### 3.1 Apple (iOS, iPadOS, macOS via web)
- **Hit targets: at least 44×44 pt** for all interactive elements, with spacing between them ([HIG Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) **[verify wording]**).
- **Dynamic Type:** text must follow the system size up to the accessibility sizes. AX3 is over 200% and AX5 body text is over 300%. Apple's *Larger Text* label requires ≥200% without clipped or overlapped text in common tasks, and layouts should switch from horizontal to vertical arrangement at accessibility sizes ([Larger Text criteria](https://developer-rno.apple.com/help/app-store-connect/manage-app-accessibility/larger-text-evaluation-criteria)).
- **Bold Text:** honor it. In Flutter, read `MediaQuery.boldTextOf` (Material text styles do this partly. Custom Hebrew fonts need a bold weight available, and note that *Taamey Frank CLM Bold hides te'amim*, see §5.8).
- **Increase Contrast and Reduce Transparency:** Apple's *Sufficient Contrast* test asks you to turn on **Bold Text, Increase Contrast, and Reduce Transparency** together before testing. Your own in-app contrast setting must match the system behavior or offer finer control. Non-text elements need 3:1 ([Sufficient Contrast criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/sufficient-contrast-evaluation-criteria)).
- **Reduce Motion:** swap parallax, zoom, spin, and confetti for fades or static states.
- **Smart Invert:** images and media should not be inverted. Flutter has no per-widget "ignore invert" API. Read `MediaQuery.invertColorsOf` and re-invert photo widgets with a `ColorFiltered` matrix if needed **[verify behavior on device]** ([SwiftUI accessible appearance](https://developer.apple.com/documentation/swiftui/accessible-appearance)).
- **Differentiate Without Color Alone:** test the app in Grayscale. If it can't be understood, redesign ([Apple criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/differentiate-without-color-alone-evaluation-criteria)).
- **Dark Interface:** common-task screens stay dark, with no white flashes during loading or in modals ([Dark Interface criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/dark-interface-evaluation-criteria)).
- **Voice Control:** every tappable element must show a number with "Show numbers" and a name with "Show names". All common tasks must be possible by voice alone ([Voice Control criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/voice-control-accessibility-evaluation-criteria)). Native iOS can add alternative spoken names with `accessibilityUserInputLabels`. **I found no evidence that Flutter exposes this**, so keep visible labels short, unique, and speakable ([Swiftjectivec](https://www.swiftjectivec.com/voice-control-accessibility-tweaks-ios)).
- **Switch Control:** works through the semantics tree. Group related items (`MergeSemantics`) and keep the order logical so scanning is efficient.
- **Full Keyboard Access (iPad and hardware keyboards):** the same keyboard work you do for desktop pays off here.

### 3.2 Material Design 3 / Android
- **Touch targets: at least 48×48 dp**, separated by about 8 dp. A 24 dp icon is fine if its padding makes the target 48 dp ([Google Accessibility help](https://support.google.com/accessibility/android/answer/7101858)). The Material components enforce 48 dp through `MaterialTapTargetSize.padded` ([M3 minimum interactive size](https://kotlinlang.org/api/compose-multiplatform/material3/androidx.compose.material3/minimum-interactive-component-size.html), [M3 accessibility](https://m3.material.io/foundations/accessibility) **[verify]**).
- **Font scale:** up to 200%. **Android 14+ uses non-linear scaling** (large text grows less than small text). Flutter's `TextScaler` models this, and Flutter recommends testing at the maximum 200% ([Flutter migration note](https://docs.flutter.dev/release/breaking-changes/android-14-nonlinear-text-scaling-migration)).
- **TalkBack:** supports Hebrew (with a Google TTS Hebrew voice, which varies by device). Custom actions appear in the TalkBack actions menu (swipe up then down).
- **Switch Access, Voice Access, Accessibility Menu, Camera Switches:** all are driven by the semantics tree ([Flutter assistive tech page](https://docs.flutter.dev/ui/accessibility/assistive-technologies)).
- **Remove animations** (developer and accessibility setting) maps to `MediaQuery.disableAnimationsOf`.
- **High-contrast text, color correction, color inversion:** test with each.

### 3.3 Windows (desktop)
- **Narrator** (built in) and **NVDA** (most popular, free). Flutter's docs recommend testing with both ([Flutter assistive technologies](https://docs.flutter.dev/ui/accessibility/assistive-technologies)).
- **Contrast themes (High Contrast)** are user-chosen, forced palettes (e.g., white on black, black on white, or custom). Flutter paints its own colors, so test whether `MediaQuery.highContrastOf` reflects them on Windows. If it doesn't, rely on an in-app high-contrast theme ([MS Edge high-contrast explainer](https://github.com/hpsin/MSEdgeExplainers/blob/main/Accessibility/HighContrast/explainer.md)).
- **Text size setting:** reports suggest Flutter Windows apps may not follow the Windows "Text size" slider. A Flutter team member said system-wide scaling is reported but display-specific scaling is not. **Ship an in-app text size control** ([itsallwidgets forum thread](https://forum.itsallwidgets.com/t/windows-text-scaling-seems-unrelated-to-mediaquery-of-context-textscaler/4037)).
- **Hebrew voices:** install the Hebrew language pack with its Speech component. Voices include Hila and Avri (Microsoft neural voices). NVDA's default eSpeak NG reportedly lacks good Hebrew, so users rely on OneCore Hebrew voices or paid engines such as *Carmel*. JAWS is said to handle Hebrew better ([Microsoft Q&A](https://learn.microsoft.com/en-us/answers/a/12407670), [user-a.co.il](https://user-a.co.il/en/assistive-technologies/what-screen-reader-software-do-blind-users-choose), [AppleVis](https://www.applevis.com/comment/128234)).

---

## 4. Flutter implementation

### 4.1 How Flutter accessibility works
Flutter draws to a canvas and builds a parallel **semantics tree**, which the engine translates for each platform: Android `AccessibilityNodeInfo`, iOS `UIAccessibility`, Windows MSAA/UIA (via `AXPlatformNodeWin`), and an ARIA DOM overlay on the web ([Windows engine doc](https://flutter.googlesource.com/mirrors/flutter/+show/3a5c2cefdfc73bd2e4e47d8ef80489c060436b37/docs/platforms/desktop/windows/Accessibility-on-Windows.md)). Standard widgets produce semantics automatically. Custom painting (verse layout with `CustomPaint`, streak rings) produces **nothing** until you wrap it in `Semantics`.

### 4.2 The `Semantics` family

| API | Use in this app |
|---|---|
| `Semantics(label:, hint:, value:, button:, toggled:, checked:, selected:, enabled:, slider:, link:, textField:, image:)` | Name, role, and state for custom widgets (verse row, te'amim toggle chip, streak day cell) |
| `Semantics(headingLevel: 1..6)` | Parasha (h1), aliyah (h2), chapter (h3). **`header: true` is now a no-op on iOS/Android. Migrate to `headingLevel`.** On web, 1–6 map to `<h1>`–`<h6>` ([breaking change](https://docs.flutter.dev/release/breaking-changes/semantics-header-heading-level)) |
| `Semantics(liveRegion: true)` | Status text that should be announced when it changes ("Portion completed"). Polite. Can be dropped if the screen reader is busy ([liveRegion API](https://api.flutter.dev/flutter/semantics/SemanticsProperties/liveRegion.html)). `SnackBar` already uses it |
| `Semantics(sortKey: OrdinalSortKey(n))` | Force reading order (verse, then Targum, then translation) when layout order differs. All keys in a group must be the same kind. Unkeyed nodes use the platform default order ([OrdinalSortKey](https://api.flutter.dev/flutter/semantics/OrdinalSortKey-class.html)) |
| `Semantics(excludeSemantics: true, label: ...)` | Replace the raw visible Hebrew (with te'amim) with a cleaned spoken label |
| `ExcludeSemantics` | Decorative separators, ornament glyphs, duplicate text |
| `MergeSemantics` | Combine "icon + count + caption" into one stop (e.g., the streak badge "12-week streak") |
| `BlockSemantics` | Hide content behind custom modal sheets or overlays |
| `IndexedSemantics` / `semanticChildCount` | "Verse 3 of 31" position info in lists |
| `Semantics(customSemanticsActions: {CustomSemanticsAction(label: 'Bookmark'): ...})` | Alternatives to swipe and long-press: bookmark verse, copy verse, play from here, delete post. They show up in the TalkBack actions menu and the VoiceOver Actions rotor ([Droids On Roids guide](https://www.thedroidsonroids.com/blog/flutter-accessibility-guide-part-2)) |
| `Semantics(onTapHint: 'play audio from this verse')` | Custom "double-tap to ..." hint |
| `Semantics(attributedLabel: AttributedString(text, attributes: [LocaleStringAttribute(range:, locale: Locale('he'))]))` | Tell the screen reader to switch to a Hebrew voice for that range. `label` and `attributedLabel` are mutually exclusive ([LocaleStringAttribute](https://api.flutter.dev/flutter/dart-ui/LocaleStringAttribute-class.html), [attributedLabel](https://api.flutter.dev/flutter/semantics/SemanticsProperties/attributedLabel.html)) |
| `Semantics(localeForSubtree: Locale('he'))` | Set the language for a whole subtree ([localeForSubtree](https://api.flutter.dev/flutter/widgets/Semantics/localeForSubtree.html)). **Unconfirmed whether Flutter web emits a `lang` attribute from this. Test with NVDA on web** |
| `TextSpan(locale:, spellOut:)` | Per-span language. `spellOut` spells character by character (handy for abbreviations such as ה׳) ([commit adding locale/spellOut](https://dart.googlesource.com/external/github.com/flutter/flutter/+/67cee6308744d50ec84c32f200e9fd7d730f227c%5E%21/)) |
| `Semantics(role: SemanticsRole.xxx)` | Explicit roles (tab, dialog, table, menu item, combobox, progress bar...). Mapped to ARIA on web first, other platforms later (Flutter 3.32+) ([dcm.dev](https://dcm.dev/blog/2025/06/30/accessibility-flutter-practical-tips-tools-code-youll-actually-use/)) |
| `Semantics(identifier: 'verse-1-1')` | Stable IDs for UI automation (maps to resource-id / accessibilityIdentifier). Not spoken |
| `SliverSemantics` | Semantics for sliver-based reading lists |

### 4.3 Reading the user's system settings (`MediaQuery`)
Use the narrow `*Of` accessors. They rebuild only when that one value changes.

| Accessor | Platform source | App response |
|---|---|---|
| `MediaQuery.textScalerOf(context)` | iOS Dynamic Type, Android font scale (non-linear on 14+), web/desktop varies | Apply to all text. Multiply the scripture size by the in-app reading size |
| `MediaQuery.boldTextOf` | iOS Bold Text, Android "Bold text" **[verify Android mapping]** | Use heavier weights. Make sure the Hebrew font has a bold weight that *keeps* te'amim |
| `MediaQuery.highContrastOf` | iOS Increase Contrast (documented as iOS-oriented) | Pick `highContrastTheme` / `highContrastDarkTheme` |
| `MediaQuery.disableAnimationsOf` | Android Remove animations, iOS Reduce Motion **[verify exact mapping]** | Zero or short durations, no confetti, no auto-scroll smoothing |
| `MediaQuery.accessibleNavigationOf` | TalkBack / VoiceOver running | Avoid auto-dismissing UI. Expose explicit buttons instead of hidden gestures. **Don't create a separate "screen-reader version" of the app** |
| `MediaQuery.invertColorsOf` | iOS Smart/Classic Invert | Counter-invert photos and avatars |
| `MediaQuery.onOffSwitchLabelsOf` | iOS On/Off labels | Show I/O glyphs on custom switches |
| `MediaQuery.supportsAnnounceOf` | `true` on iOS/web, `false` where announcements are deprecated (Android) | Decide between `SemanticsService.announce` and `liveRegion` |

`dart:ui` `AccessibilityFeatures` also has `reduceMotion` ("simplify certain animations, remove parallax") alongside `disableAnimations` ([AccessibilityFeatures](https://api.flutter.dev/flutter/dart-ui/AccessibilityFeatures-class.html)).

### 4.4 Announcements
- `SemanticsService.announce(message, textDirection, {assertiveness})`. Assertiveness only has an effect on web. **Android has deprecated announcement events** (TalkBack flushes its queue), so Flutter recommends liveRegion-driven implicit announcements there. Check `MediaQuery.supportsAnnounceOf(context)` first ([announce API](https://api.flutter.dev/flutter/semantics/SemanticsService/announce.html), [supportsAnnounce](https://api.flutter.dev/flutter/dart-ui/AccessibilityFeatures/supportsAnnounce.html)).
- **API churn:** some recent SDKs have a view-aware `SemanticsService.sendAnnouncement(View.of(context), ...)`, and there have been reverts between `announce` and `sendAnnouncement` ([sendAnnouncement](https://api.flutter.dev/flutter/semantics/SemanticsService/sendAnnouncement.html), [engine revert commit](https://flutter.googlesource.com/mirrors/flutter/+/5e146d47a61098e5ed967352812bcbbe0fe24f20%5E%21/)). Wrap it in one helper (`A11y.announce(context, msg)`) so you only update one place.
- Pass `TextDirection.rtl` for Hebrew messages.

### 4.5 Text scaling: pitfalls
- `textScaleFactor` is **deprecated** in favor of `TextScaler` (non-linear scaling). Use `textScaler.scale(fontSize)` for any manual sizing ([deprecation guide](https://docs.flutter.dev/release/breaking-changes/deprecate-textscalefactor)).
- `TextScaler.clamp(minScaleFactor:, maxScaleFactor:)` and `MediaQuery.withClampedTextScaling` cap growth ([clamp](https://api.flutter.dev/flutter/painting/TextScaler/clamp.html)). Clamping is the common way to "fix" overflow, and it **defeats 1.4.4 and Apple's Larger Text criteria while the automated guideline tests still pass**. Clamp only fixed-height chrome (e.g., tab labels, at maybe 2×). Never clamp reading text or settings.
- `RichText` does **not** pick up the ambient text scale automatically. Prefer `Text.rich`, or pass `textScaler: MediaQuery.textScalerOf(context)`.
- Lay out with `Wrap`, `Flexible`, and `LayoutBuilder` breakpoints that switch from Row to Column at large scales. Avoid fixed heights and `FittedBox` on text, and avoid `maxLines` + ellipsis on meaningful text.
- **Android WebView regression (third-party report):** Flutter web 3.41–3.44 inside an Android WebView misread `textZoom` as a line-height override and could make text vanish. Reported fixed in 3.47 ([startdebugging.net](https://startdebugging.net/2026/09/fix-flutter-text-renders-off-screen-in-an-android-webview-with-font-scaling/)). Relevant only if you embed the web build in a WebView.

### 4.6 Focus, keyboard, shortcuts
- `FocusTraversalGroup` per region. The default policy is `ReadingOrderTraversalPolicy`. Use `OrderedTraversalPolicy` + `FocusTraversalOrder(order: NumericFocusOrder(n))` for explicit ordering. Mixing incomparable orders in one group asserts ([Flutter input & a11y](https://docs.flutter.dev/ui/adaptive-responsive/input), [OrderedTraversalPolicy](https://api.flutter.dev/flutter/widgets/OrderedTraversalPolicy-class.html)).
- `FocusableActionDetector` for custom interactive widgets (verse rows, chips). It bundles focus, hover, shortcuts, actions, and a focus-highlight callback.
- `Shortcuts` + `Actions` + `Intent`, with `SingleActivator` (use modifiers, and use `meta` on macOS-web) and `CallbackShortcuts` for simple cases. Put an app-level `Shortcuts` near the root and reader-specific ones on the reader's `Focus`.
- Make focus visible: set `ThemeData.focusColor` / `InputDecorationTheme` focus borders, and draw a custom ring (≥2 px, ≥3:1) around focused verse rows. `FocusManager.instance.highlightMode` tells you when keyboard focus highlights should show.
- **Focus not obscured (2.4.11):** when the sticky audio player or bottom nav is visible, add matching bottom padding to the scroll view so `Scrollable.ensureVisible` (used during traversal) doesn't leave the focused verse underneath it.
- Desktop menus: `MenuAnchor` / `MenuBar` (or `PlatformMenuBar` on macOS) expose keyboard-navigable menus with roles.

### 4.7 Flutter web specifics
- **Semantics are off by default.** An invisible `<flt-semantics-placeholder role="button">` labeled "Enable accessibility" lets screen-reader users turn them on. To force semantics on, call `SemanticsBinding.instance.ensureSemantics()` after `runApp`, guarded by `kIsWeb`. Flutter warns this has a real performance cost ([web accessibility docs](https://docs.flutter.dev/ui/accessibility/web-accessibility), [Flutter blog](https://flutter.dev/blog/accessibility-in-flutter-on-the-web)). **Recommendation:** since the user base includes screen-reader users reading long texts, test the performance with semantics forced on for a long parasha (about 150+ verses). If acceptable, enable it always. Otherwise keep the placeholder and add a visible "Accessibility mode" toggle in settings.
- `SemanticsRole` maps to ARIA roles. `headingLevel` maps to `h1`–`h6`. Inspect the generated DOM in Chrome DevTools. A debug flag can visualize semantics nodes (`--dart-define=FLUTTER_WEB_DEBUG_SHOW_SEMANTICS=true` **[verify flag name]**).
- **Text-spacing overrides (WCAG 1.4.12):** supported since Flutter 3.41 through a hidden probe element ([3.41 release notes](https://docs.flutter.dev/release/release-notes/release-notes-3.41.0), [startdebugging.net](https://startdebugging.net/2026/09/fix-flutter-text-renders-off-screen-in-an-android-webview-with-font-scaling/)).
- **Browser find-in-page (Ctrl+F) generally doesn't search canvas text.** Provide **in-app search** (by word, root, verse reference). Browser zoom should be tested at 200% and 400%. Consider an in-app zoom as well.
- Links: use `Semantics(link: true, linkUrl: Uri)` or `url_launcher`'s `Link` widget so they're real links.
- Set `Title` per route and keep URLs meaningful (`/parasha/bereshit/aliyah/3`).

### 4.8 Windows desktop specifics
- The semantics bridge targets MSAA and UIA. Test with **Narrator and NVDA**, and inspect with **Accessibility Insights for Windows** **[verify it can see Flutter's UIA tree]**.
- Provide in-app text size and high contrast (see §3.3). Keyboard support is essential here.
- Respect the Windows "Show animations" setting if it reaches `disableAnimations` **[verify]**. Either way, provide the in-app reduce-motion toggle.

### 4.9 Other known Flutter pitfalls
- **Links inside `RichText`/`TextSpan` on Android** are announced as buttons, not links (iOS handles them correctly) ([accessible_text_view README](https://pub.dev/documentation/accessible_text_view/latest/)). Prefer separate link widgets in forum posts, or accept the limitation.
- **Very long single `Text` nodes:** a whole chapter in one node forces the screen reader to read it all at once, with no verse-level navigation. **Use one semantics node per verse**, and optionally a heading per aliyah.
- **`SnackBar` with an action no longer auto-dismisses** by default (since 3.38). Use `persist:` to control it ([breaking change](https://docs.flutter.dev/release/breaking-changes/snackbar-with-action-behavior-update)). Don't put critical actions only in a timed snackbar.
- **Double announcements** when wrapping a Material widget that already has semantics in an extra `Semantics` with a label. Use `excludeSemantics: true` or `MergeSemantics`.
- **Icons without tooltips:** `IconButton(tooltip: ...)` gives both the semantics label and a desktop hover tooltip.
- **RTL focus/reading order:** default ordering is platform-dependent. Verify with TalkBack and VoiceOver in a Hebrew locale and add `OrdinalSortKey` where needed.
- A 2023 study found some Flutter UI elements stayed inaccessible even after semantic optimization and needed platform-specific workarounds, so manual testing is mandatory ([CMS Conferences paper](https://openaccess.cms-conferences.org/publications/book/978-1-958651-13-1/article/978-1-958651-13-1_5)).

### 4.10 Automated tests
- `meetsGuideline(androidTapTargetGuideline)` (48×48), `iOSTapTargetGuideline` (44×44), `labeledTapTargetGuideline` (every tap/long-press node has a label), `textContrastGuideline` (WCAG text contrast). Call `tester.ensureSemantics()` first, await each `expectLater`, then dispose the handle ([meetsGuideline](https://api.flutter.dev/flutter/flutter_test/meetsGuideline.html), [accessibility testing](https://docs.flutter.dev/ui/accessibility/accessibility-testing)).
- Limitations: these tests only see what's in the semantics tree. `textContrastGuideline` can't evaluate text on images or gradients well. They won't catch clamped text scaling.
- Add semantics assertions (`matchesSemantics`, `containsSemantics`, `find.bySemanticsLabel`) and run the guideline suite across a matrix: text scale 1.0 / 2.0 / 3.0+, LTR/RTL, light/dark/high-contrast, bold text, using `tester.platformDispatcher.textScaleFactorTestValue` and `tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(...)` **[verify setter names]**.

---

## 5. Hebrew, nikud, cantillation, Aramaic, and RTL

### 5.1 What screen readers do with biblical Hebrew (findings)
- **VoiceOver (iOS/macOS):** Hebrew TTS arrived in iOS 8 (2014, Nuance "Carmit") ([Use Your Loaf](https://useyourloaf.com/blog/ios-8-adds-hebrew-speech-synthesis/), [IBI-L list](https://groups.google.com/g/ibi-l/c/3quEwkjweFM)). A professor of biblical languages (2021) reported that iOS "is designed to read modern Hebrew, not biblical Hebrew", so **some vowel and cantillation marks are not spoken**. Braille output shows **Unicode placeholder codes** for marks it doesn't know. On macOS, untagged Hebrew passages may be **read as letters in English**. iOS detects the language better ([AppleVis 128206](https://www.applevis.com/comment/128206), [AppleVis 128198](https://www.applevis.com/comment/128198)).
- **NVDA:** same problems reported. The default eSpeak NG voice reportedly lacks usable Hebrew, so users install OneCore Hebrew voices (Windows Hebrew language pack with Speech) or a third-party engine (Carmel) ([AppleVis 128234](https://www.applevis.com/comment/128234), [user-a.co.il](https://user-a.co.il/en/assistive-technologies/what-screen-reader-software-do-blind-users-choose), [Microsoft Q&A](https://learn.microsoft.com/en-us/answers/a/12407670)). NVDA reads uncommon combining marks via its symbol dictionary, and missing entries can fall back to awkward Unicode names ([NVDA developer guide](https://download.nvaccess.org/releases/2024.2/documentation/developerGuide.html)).
- **JAWS:** reported to handle Hebrew better than NVDA or VoiceOver ([AppleVis 128234](https://www.applevis.com/comment/128234)).
- **TalkBack:** has Hebrew support ([AppleVis 2014](https://www.applevis.com/forum/voiceover-hebrew-support-needed)). Quality depends on the installed Google Speech Services Hebrew voice. I found no source documenting TalkBack's handling of te'amim **[test]**.
- **Nikud helps TTS:** unvowelized Hebrew is ambiguous (one spelling, several words) and screen readers guess wrong ([W3C WAI-GL 2004](https://lists.w3.org/Archives/Public/w3c-wai-gl/2004JanMar/0198.html)). Hebrew TTS systems benefit from niqqud for correct pronunciation ([Hebrew TTS overview](https://speechactors.com/article/hebrew-text-to-speech)). Some TTS voices *require* nekudot to be intelligible ([Hebrew TTS providers comparison](https://github.com/danielrosehill/Hebrew-TTS-Providers)).
- **Rabbinic and biblical Hebrew TTS quality is acknowledged as poor**, even by Sefaria ([Sefaria contest page](https://www.sefaria.org.il/powered-by-sefaria-contest-2021)).

**Do cantillation marks confuse screen readers?** The evidence says yes. At best they are skipped silently. At worst they are spoken as Unicode names or symbols, interrupt words, or (in braille) appear as placeholder codes. **Recommendation: yes, provide a stripped-text semantics label.**

### 5.2 The spoken-label pipeline (recommended)
Build each verse's semantics label from the source text with these steps, and make each step a user setting with sensible defaults:

| Step | Unicode | Default | Why |
|---|---|---|---|
| Remove te'amim | U+0591–U+05AF | **On** | Not spoken, or spoken badly. Clutters braille |
| Remove meteg / siluq | U+05BD | **On** | Functions as a stress or accent mark, not a vowel |
| Remove Masoretic upper/lower dots | U+05C4, U+05C5 | On | Not pronounced |
| Remove nikud | U+05B0–U+05BC, U+05BF, U+05C1, U+05C2, U+05C7 | **Off** (keep vowels) | Vowels improve TTS pronunciation. Offer "consonants only" for users whose voice mispronounces vocalized text |
| Maqaf | U+05BE | Replace with space **[test per engine]** | Some engines say "hyphen" or merge the joined words |
| Sof pasuq | U+05C3 | Replace with "." or remove | Otherwise may be spoken as "colon" |
| Paseq | U+05C0 | Remove | May be spoken as "vertical line" |
| Nun hafukha | U+05C6 | Remove | Rare. Not pronounced |
| Setumah / petuchah markers (ס / פ) | letters | Exclude from verse label. Expose as "closed section" / "open section" only if useful | Otherwise read as random letters |
| Ketiv/qere | data | Speak the **qere** | Matches the reading practice |
| Divine Name (יהוה and variants, אדני יהוה, ה׳, etc.) | data | User choice: **Adonai** / **HaShem** / spell out letters / as written | Religious sensitivity. TTS would otherwise attempt a pronunciation ([Logos discussion](https://community.logos.com/discussion/comment/610518)) |
| Verse number (Hebrew letter numerals) | — | Speak "verse 14" / "פסוק יד" in the UI language | Letter numerals are read as words |

Use the code-point lists from the Unicode Hebrew block chart ([Unicode names list](https://unicode.org/charts/nameslist/n_0590.html), [Microsoft Hebrew OpenType spec](https://learn.microsoft.com/en-us/typography/script-development/hebrew)). **Don't** strip with a broad `U+0591–U+05C7` range: that also removes maqaf, paseq, sof pasuq, and nun hafukha in uncontrolled ways.

**Braille users:** add a setting, "Screen reader/braille text: Simplified (default) / With all marks". Some braille users want the full text, and an experimental braille cantillation code (**BRITH**, by Danny Sadinoff and Batya Sperling-Milner) exists ([BRITH repo](https://github.com/dsadinoff/brith), [Kveller](https://www.kveller.com/?p=71154), [Hebrew Braille](https://en.wikipedia.org/wiki/Hebrew_Braille)). Standard Hebrew braille omits trop. Consider a P2 feature: **export the parasha with te'amim names in words** (e.g., "בְּרֵאשִׁית (tipcha) בָּרָא (etnachta)...") for blind learners preparing a leining. JBI (Jewish Braille Institute) is a natural partner and tester ([JBI](https://jbilibrary.org/what-we-do)).

### 5.3 Learning cantillation without seeing it
For blind and low-vision users learning to lein, **te'amim names on demand** help a lot: a custom semantics action "Describe cantillation" that speaks each word with its te'am name, plus audio of the te'am melody. This matches the BRITH idea in speech form.

### 5.4 Hebrew TTS availability for in-app "read aloud"
| Platform | Hebrew voice availability | Notes |
|---|---|---|
| iOS / macOS | Built in (Carmit, he-IL), plus enhanced variants | `AVSpeechSynthesizer` supports he-IL |
| Android | Device-dependent. Google Speech Services Hebrew usually downloadable | `flutter_tts` `isLanguageAvailable('he-IL')`. Try `he`, `he-IL`, and `iw-IL` (legacy code) **[verify]**. If missing, prompt the user to install voice data |
| Windows | Hebrew language pack plus Speech feature. Voices Hila / Avri (neural, also via Edge "Read aloud") | Some users will have no Hebrew voice installed. Show install instructions |
| Web | `speechSynthesis.getVoices()` varies by browser and OS | Feature-detect. Fall back to recorded audio |

Prefer **human-recorded audio** (Torah readers chanting with te'amim) for the scripture. TTS can't chant, and biblical-Hebrew TTS is poor. Use TTS only for UI, forum posts, or a "read plainly" mode.

### 5.5 Language tagging
- UI strings: app locale (`he`, `en`). Use `flutter_localizations` with `GlobalMaterialLocalizations.delegate`, etc.
- Hebrew text: `Locale('he')` via `LocaleStringAttribute` / `localeForSubtree` / `TextSpan.locale`. This is required for 3.1.2 and stops VoiceOver from reading Hebrew as English letters.
- English translation inside a Hebrew UI (or the reverse): tag each part.

### 5.6 Aramaic (Targum Onkelos)
- The correct BCP-47 tag is `arc` (Official Aramaic). **No mainstream screen reader has an Aramaic voice**, so tagging `arc` may produce silence or a fallback to the default voice **[test]**. Practical recommendation: expose a setting "Read Targum with: Hebrew voice (default) / Default voice". Internally keep `arc` in your data and apply `he` for speech. Mention this in the accessibility statement.
- The Targum usually has nikud but no te'amim. Apply the same stripping pipeline.

### 5.7 Bidi and RTL layout
- Wrap the app in the correct `Directionality` (automatic from the locale with `MaterialApp`). Use **directional** APIs everywhere: `EdgeInsetsDirectional`, `AlignmentDirectional`, `BorderRadiusDirectional`, `PositionedDirectional`, `TextAlign.start/end`.
- **Mirror directional icons** (back/forward arrows, "next aliyah" chevrons, progress direction) in RTL. Many Material icons set `matchTextDirection`, and `BackButtonIcon` handles it. **Don't mirror** non-directional icons (play ▶ is commonly *not* mirrored, nor checkmarks or clocks).
- **Mixed English/Hebrew strings:** the bidi algorithm misplaces punctuation and numbers at run boundaries ([W3C H56](https://www.w3.org/WAI/WCAG21/Techniques/html/H56)). Prefer separate `TextSpan`s with explicit direction, or wrap embedded runs in Unicode **isolates**: FSI U+2068 / LRI U+2066 / RLI U+2067 … PDI U+2069 ([Unicode bidi isolates proposal](https://www.unicode.org/L2/L2012/12186r-bidi-isolates.pdf), [W3C Hebrew gap analysis](https://www.w3.org/TR/2025/DNOTE-hebr-gap-20250117)). Whether screen readers voice isolate characters cleanly is **untested in the literature [test]**. Strip them from semantics labels to be safe.
- **Forum posts:** set the direction per post or paragraph from its first strong character (e.g., `intl`'s `Bidi.estimateDirectionOfText` / `Bidi.detectRtlDirectionality` **[verify names]**). Give the composer `TextField` `textDirection` auto-switching, or a manual RTL/LTR toggle.
- Verse references like "Gen 1:1" vs "בראשית א:א": keep each in a single direction run.
- Numbers, dates, and streak counts in Hebrew UI: use `intl` formatting and test announcements ("12 weeks" vs "12 שבועות").

### 5.8 Hebrew fonts for nikud and te'amim
- Fonts with te'amim support: **Taamey Frank CLM** (Culmus; extra line spacing for marks; **its Bold variants make te'amim transparent**; no longer maintained, replaced by **Taamey D**), **Noto Serif Hebrew** (te'amim and nikud, with some positioning errors for meteg/holam with vav and no qamats qatan), **Ezra SIL**, **SBL Hebrew** **[verify te'amim quality]**, **Shofar**, **Taamey Ashkenaz** ([Open Siddur font list](https://opensiddur.org/help/fonts/), [Culmus Taamey](https://culmus.sourceforge.io/taamim/)).
- **Bundle** the fonts and set `fontFamilyFallback` to them. Don't rely on platform fallback, because mixing fonts within a cluster misplaces marks.
- Offer 2–3 font choices, including a clear **sans-serif Hebrew** option for low-vision and dyslexic readers. Make sure the chosen bold weight still shows te'amim.
- **Letter spacing and combining marks:** applying `letterSpacing` to text with combining marks may separate marks from their base letters in some engines. This is untested for Flutter's SkParagraph **[test with בְּרֵאשִׁית֙ at several spacings]**. If it breaks, make the "letter spacing" control in the scripture view adjust **word spacing** (`wordSpacing`) and line height instead.
- Increase line height for te'amim (they sit above and below the line). A default of **≥1.8–2.0** for pointed and cantillated text avoids marks colliding across lines.

---

## 6. Cognitive and learning accessibility

### 6.1 W3C COGA "Making Content Usable" (8 objectives)
1. Help users understand what things are and how to use them
2. Help users find what they need
3. Use clear and understandable content
4. Help users avoid mistakes and know how to correct them
5. Help users focus
6. Ensure processes do not rely on memory
7. Provide help and support
8. Support adaptation and personalisation

([W3C COGA note](https://www.w3.org/TR/coga-usable/), [UK DfE summary of the 8 objectives](https://apply-the-service-standard.education.gov.uk/guides/guidelines/cognitive-accessibility-guidelines), [COGA Task Force](https://www.w3.org/WAI/GL/task-forces/coga/)). The note is informative and contains about 53 patterns.

**Applied to this app:**
- **Familiar, labeled controls** (icon plus text label, not icon-only). Consistent placement of "Mark as read".
- **Clear "where am I"**: breadcrumb "Bereshit › Aliyah 3 › 1:14". Show progress ("Verse 5 of 19", "Aliyah 3 of 7").
- **One primary task per screen.** Today's portion has one big "Start reading" action. Avoid dashboards crowded with stats.
- **Don't rely on memory:** resume exactly where the user left off, show "last read" and "next up", save forum drafts automatically, and support passkeys and password managers (3.3.8).
- **Mistake recovery:** undo for "mark as read", deleting a post, or leaving a group. A confirmation step for destructive actions.
- **Help:** short in-context help ("What are te'amim?"), a glossary of Hebrew terms (aliyah, haftarah, Targum, te'amim), and a consistent help location (3.2.6).
- **Personalization:** saved reading profiles ("Study mode", "Leining practice", "Large print").
- **Plain language** for UI, notifications, and community guidelines. Short sentences. Explain jargon on first use. Offer an "easy explanation" of streak rules.

### 6.2 Dyslexia-friendly typography: what the evidence says
| Intervention | Evidence | Recommendation |
|---|---|---|
| **OpenDyslexic** | Wery & Diliberto (Annals of Dyslexia, 2017): no improvement in rate or accuracy, and no student preferred it ([PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC5629233/), [Springer](https://link.springer.com/article/10.1007/s11881-016-0127-1)). Rello & Baeza-Yates: dyslexia fonts were not easier to read ([ASSETS 2013](https://doi.org/10.1145/2513383.2513447)). Very small studies claim gains | Optional at most, and **Latin-only** (useless for Hebrew). Don't market it as a fix |
| **Font style** | Rello & Baeza-Yates (48 dyslexic readers): sans-serif, monospaced, and roman styles improved performance. **Italics were worst** ([BYU summary](https://editingresearch.byu.edu/2020/05/28/which-fonts-are-best-for-dyslexia/)) | No italics for emphasis in reading text. Offer a sans-serif option |
| **Letter spacing** | Zorzi et al. (PNAS 2012, 74 Italian/French children): extra-large spacing doubled accuracy and gave >20% speed gains, benefiting the weakest readers most ([PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC3396504)). **Hebrew:** Dotan & Katzir (2018, 132 1st/3rd graders): 150% spacing improved accuracy (not speed) for all 1st graders on long words and for low-achieving 3rd graders ([IUCC](https://cris.iucc.ac.il/en/publications/mind-the-gap-increased-inter-letter-spacing-as-a-means-of-improvi/)). A 2025 follow-up with digital texts: helped 2nd graders' comprehension, opposite trend in 3rd graders ([MDPI](https://www.mdpi.com/2227-7102/15/10/1306)) | Offer spacing as an **adjustable** setting, not a forced default. Benefits are individual |
| **Nikud and dyslexia (Hebrew)** | Adult dyslexic readers read *pointed* words more slowly than unpointed ones. Controls didn't ([Weiss, Katzir & Bitan 2015](https://newiipdm.haifa.ac.il/wp-content/uploads/2015/05/WeissKatzirBitan2015.pdf)). Dyslexic 4th graders showed no speed difference but lower accuracy on vowelized script ([Schiff, Katzir & Shoshan 2013](https://education.biu.ac.il/en/node/5367)) | The **nikud/te'amim toggles help readers with dyslexia**: practice the consonantal reading, reveal vowels on demand (tap a word to show its vowels), or dim te'amim to reduce clutter |
| **Line length / windowing** | Short lines: +27% speed, half the regressions, no comprehension cost ([Schneps 2013](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3734020/)). WCAG 1.4.8: ≤80 chars. BDA: 60–70 chars ([BDA guide copy](https://www.wigan.gov.uk/Docs/PDF/Business/Professionals/SEN/HEFA/Dyslexia-Style-Guide.pdf)) | Max-width setting (narrow / medium / wide) for the reading column |
| **Reading rulers** | CHI 2023 (91 dyslexic, 86 non-dyslexic readers): many benefit, most strongly dyslexic readers. **No single ruler style preferred** ([Adobe Research](https://research.adobe.com/publication/digital-reading-rulers-evaluating-inclusively-designed-rulers-for-readers-with-dyslexia-and-without)) | Configurable focus mode: highlight band / underline / dim others, color, height |
| **Spacing and background (BDA style guide)** | 12–14pt or larger, line spacing 1.5, letter spacing ~35% of average letter width, word spacing ≥3.5× letter spacing, cream or pastel instead of white, avoid italics and underline, left-align (start-align) ([BDA via Wigan](https://www.wigan.gov.uk/Docs/PDF/Business/Professionals/SEN/HEFA/Dyslexia-Style-Guide.pdf), [Dyslexia Scotland](https://dyslexiascotland.org.uk/dyslexia-friendly-typed-formats)) | Sepia/cream theme, start-aligned text option, spacing controls |
| **Atkinson Hyperlegible** | Braille Institute font for low vision, with deliberately distinct letterforms (l/1/I). Design intent is strong. I found no published peer-reviewed results (a CSUN 2024 session announced a study) ([All About Vision](https://www.allaboutvision.com/low-vision/atkinson-hyperlegible-typeface/), [CSUN 2024](https://csun.edu/cod/conference/sessions/index.php/public/presentations/view/3108)) | Good choice for the **Latin UI and English text**. Free. Doesn't cover Hebrew |
| **Lexend** | Claims of improved fluency. I couldn't verify the underlying study ([fontalternatives review](https://fontalternatives.com/blog/best-free-accessible-fonts-dyslexia-low-vision/)) | Optional Latin UI font. Not evidence-based enough to default to |

### 6.3 ADHD and attention-friendly design
- **One task per screen.** **Focus mode** hides the app bar, nav, and social counters while reading.
- **Chunking and progress:** split the parasha into aliyot (natural chunks of about 5 minutes) with a progress indicator and an estimated reading time. Make "Read one aliyah a day" a first-class plan (the traditional *shnayim mikra* schedule or a daily-aliyah schedule).
- **No autoplay, no infinite scroll** in forums (use explicit pagination or "load more", which is also better for screen readers. Sefaria acknowledged that infinite scroll harms screen-reader navigation ([Sefaria help section](https://help.sefaria.org/hc/en-us/sections/12756520483868-Text-Formatting-and-Accessibility))).
- **Notifications:** user-scheduled, batched, quiet hours, and suppressed on Shabbat and Yom Tov. Never guilt-based.
- **Timers optional** (e.g., "read for 10 minutes" goals should be opt-in).

### 6.4 Streaks without harm
Research on streaks finds fear of missing out and stress, plus loss-aversion pressure ([BI Norway thesis](https://biopen.bi.no/bi-xmlui/handle/11250/2623593), [UX Magazine](https://uxmag.com/articles/gamification-or-manipulation-understanding-the-ethics-of-engagement-loops)). ADHD-focused writers argue that punitive streaks cause shame and abandonment ([DEV](https://dev.to/nucleusos/adhd-support-app-no-streaks-why-gamification-hurts-more-than-it-helps-1ae0)). There are **no studies of streaks with people with cognitive disabilities**, so design defensively:
- **Shabbat and Yom Tov are never streak-breaking days.** Days are computed in the user's time zone. Explain whether the day boundary is midnight or nightfall in one plain sentence.
- **Automatic** streak freezes (users with executive-function challenges won't remember to apply them manually), a repair window, and "weekly streak" as an alternative metric.
- Option to **hide streaks** completely without losing features. Use "consistency" language rather than "you lost your streak".
- Celebrations respect Reduce Motion, have no flashing, and include a text equivalent that is announced.

---

## 7. Low vision and color

### 7.1 Themes
Provide (and remember per device): **Light**, **Dark**, **Sepia/Cream**, **High-contrast light** (black on white, 21:1), **High-contrast dark** (white or yellow on black), and **Custom** (pick text and background colors, per 1.4.8). Default to "Follow system" ([FlexColorScheme guidance](https://docs.flexcolorscheme.com/theme_scheme)).
- Wire up `MaterialApp(theme:, darkTheme:, highContrastTheme:, highContrastDarkTheme:, themeMode:)`. Flutter picks the high-contrast variants automatically when the platform requests them ([highContrastTheme](https://api.flutter.dev/flutter/material/MaterialApp/highContrastTheme.html), [highContrastDarkTheme](https://api.flutter.dev/flutter/material/MaterialApp/highContrastDarkTheme.html)).
- **Polarity evidence:** dark text on light (positive polarity) gives better performance for normal-vision readers of all ages ([Piepenbrock et al.](https://documentacion.fundacionmapfre.org/documentacion/publico/pt/bib/143702.do), [cogsci.nl](https://cogsci.nl/blog/is-bright-text-on-a-dark-background-a-good-idea)). Some low-vision users, especially those with **cloudy ocular media such as cataract**, read better in dark mode ([NN/g](https://www.nngroup.com/articles/dark-mode/)). So offer both, and make switching easy (a quick toggle in the reader).
- **Contrast targets:** UI ≥4.5:1 (text) and ≥3:1 (components). **Scripture ≥7:1.** If te'amim are tinted (some readers like a softer color to separate them from vowels), keep them ≥4.5:1 and make tinting optional.

### 7.2 Color-blind safety
- Don't rely on color alone (1.4.1). Pair color with icons, patterns, text, or shape (streak calendar, forum badges, te'amim categories).
- A categorical palette such as **Okabe-Ito** is distinguishable across common color-vision deficiencies, but several of its colors **fail 3:1 on white** (yellow about 1.3:1, sky blue about 2.3:1, orange about 2.2:1). Use them only with outlines or on dark backgrounds ([Okabe-Ito reference](https://search.r-project.org/CRAN/refmans/thematic/html/okabe_ito.html)).
- Test with Android color correction, iOS Color Filters / Grayscale ([Apple](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/differentiate-without-color-alone-evaluation-criteria)), and a simulator such as Chrome DevTools "Emulate vision deficiencies" on the web build.

### 7.3 Size beyond system limits (scripture only)
- **Separate reading size** setting: base × (50% … 500%), applied **on top of** the system `TextScaler`. Make it reachable with A−/A+ buttons, keyboard (Ctrl/Cmd +/−), and optionally pinch (pinch must not be the only way).
- At very large sizes: a single column, Targum stacked below each verse, verse numbers inline, no horizontal scroll, and optionally one verse per screen ("large print paging" mode).
- Bold-text option independent of the system setting. Line-height control (1.5–2.5).
- **Magnifier-friendly:** avoid content that moves on its own. Keep the reading position stable when settings change (anchor to the current verse).

---

## 8. Motor accessibility
- **Targets:** 48 dp / 44 pt minimum. Spacing ≥8 dp. Whole verse row tappable (opens verse actions). Streak calendar cells at least 44/48 even if visually smaller (pad the hit area).
- **No gesture-only actions:** every swipe or long-press has a visible button or menu alternative **and** a `CustomSemanticsAction`. Pinch-zoom has A−/A+. Drag-to-reorder has "Move up/down" (2.5.1, 2.5.7).
- **No time pressure:** snackbars with actions persist. "Undo" stays available in a history. No double-tap-speed dependencies.
- **Switch Access / Switch Control:** a minimal number of focus stops (merge decorative parts), logical grouping, and every action reachable through semantics. Test scanning through a full aliyah. Provide "Next/previous verse" buttons so switch users don't need to scroll.
- **Keyboard (Windows, web, iPad):** Tab order, arrow-key verse navigation, Enter/Space activation, Esc to close, and shortcuts with modifiers such as:
  - `Ctrl/Cmd + =` / `−` / `0` change text size or reset it
  - `Alt+↓/↑` (or `J`/`K` *only when the reader has focus*) for next/previous verse
  - `Alt+PageDown/PageUp` for next/previous aliyah
  - `Ctrl/Cmd + T` toggles te'amim, `Ctrl/Cmd + Shift + N` toggles nikud
  - `Space` plays or pauses audio (only when the player has focus)
  - `?` opens the shortcut help sheet (remappable or toggleable, per 2.1.4)
- **Voice Control / Voice Access:** short, unique visible labels that match semantics (2.5.3). Avoid two buttons both called "More".
- **Reduce precision demands:** no tiny close "x" buttons. Bottom sheets have a "Close" button and don't rely on swipe-down alone.

---

## 9. Hearing accessibility
- If you include **chanted audio**: the on-screen text is the transcript. Add **synchronized verse/word highlighting** ("karaoke" mode), which also helps deaf and hard-of-hearing learners and dyslexic readers. Expose playback speed (0.5×–1.5×) and loop-a-verse.
- **Video (shiurim, tutorials):** captions (1.2.2), or transcripts for audio-only content (1.2.1). Honor system caption styles where the player supports them (Apple's *Captions* nutrition label) ([Apple overview](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels)).
- **No sound-only feedback:** every sound (completion chime) has a visual (and announced) equivalent.
- **Haptics as an extra channel:** `HapticFeedback.selectionClick()` on verse step, `lightImpact()` on mark-complete, `mediumImpact()` on streak milestone. Add an in-app **haptics toggle** (some users find vibration uncomfortable). Never use haptics as the only signal.
- **Learning trop without hearing:** show te'am names and optional musical notation or contour, as a visual alternative to the melody.

---

## 10. Accessibility statement and feedback channel
**W3C minimum content:** (1) commitment to accessibility, (2) the standard applied (e.g., "WCAG 2.2 AA, plus selected AAA for the reading view"), (3) contact details for problems ([W3C WAI: Developing an Accessibility Statement](https://www.w3.org/WAI/planning/statements/)). The W3C generator also covers a **typical response time** and **formal complaints** ([WAI-EO thread](https://lists.w3.org/Archives/Public/wai-eo-editors/2018Nov/0024.html)).

**Recommended contents for this app:**
- Conformance status per platform (Android, iOS, Web, Windows) and the date of the last audit, with the method (internal / external, which screen readers and versions).
- **Known limitations**, stated honestly. For example: "Screen readers do not voice cantillation marks. We provide simplified spoken text and an optional te'amim description." "Aramaic Targum is read with a Hebrew voice." "On the web, accessibility mode must be enabled (or is enabled automatically)." "In-browser find (Ctrl+F) is not supported. Use in-app search."
- **Compatibility:** tested with VoiceOver (iOS x), TalkBack (Android x), NVDA (x) and Narrator on Windows 11, NVDA + Chrome/Firefox and VoiceOver + Safari on the web, plus the Hebrew voices used.
- A list of the accessibility features and where to find them in settings.
- **Feedback:** an in-app "Report an accessibility problem" form (the form itself accessible), an email address, and optionally a phone or relay service. Offer to attach the device model, OS, app version, and **current accessibility settings** (text scale, screen reader on, theme), with the user's consent. Commit to a response time you can meet. Public-sector benchmarks range from 2 weeks (Finland) to 15 business days (Canada) to 20 working days (UK) ([examples](https://www.canada.ca/en/economic-development-quebec-regions/about/accessibility/accessibility-feedback-process.html)).
- Israel: name an **accessibility coordinator** with contact details if you're subject to IS 5568 **[verify]**.
- Store listings: fill in Apple's **Accessibility Nutrition Labels** only for features that pass the "all common tasks" bar. Keep them updated with each release ([Apple](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels)).
- Recruit testers from the community (blind Hebrew readers, the JBI network, dyslexic learners, older adults). Credit them, and pay for testing if possible.

---

## 11. Release testing checklist

### 11.1 Automated (CI, every PR)
- [ ] `meetsGuideline`: `androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline` on every main screen (Home/Today, Reader, Settings, Streaks, Forum list, Thread, Composer, Login).
- [ ] The same suite under a **matrix**: text scale 1.0 / 2.0 / 3.2, `TextDirection.rtl` and `ltr`, light/dark/high-contrast themes, `boldText: true`.
- [ ] Golden screenshots at 200% and 320% text scale. No `RenderFlex overflowed` errors (fail the test on overflow).
- [ ] Semantics assertions for key widgets: verse node label (stripped, Hebrew locale), headingLevel on aliyah headers, liveRegion on status widgets, custom actions present.
- [ ] Unit tests for the **Hebrew spoken-label pipeline** (te'amim stripping, maqaf/sof pasuq handling, Divine Name substitution, ketiv/qere).
- [ ] Lint: no `textScaleFactor`, no `withClampedTextScaling` on reading content, no `IconButton` without `tooltip`, no hard-coded `EdgeInsets.only(left:)` in directional layouts.
- [ ] Web: axe-core / Lighthouse run against the semantics DOM with semantics enabled.

### 11.2 Tool-assisted (each release candidate)
- [ ] **Android Accessibility Scanner** on each screen ([Flutter testing docs](https://docs.flutter.dev/ui/accessibility/accessibility-testing)).
- [ ] **Xcode Accessibility Inspector** in Point to Inspect mode, plus an Audit.
- [ ] **Accessibility Insights for Windows** (and Accessibility Insights for Android if useful).
- [ ] Chrome DevTools accessibility tree, Lighthouse, and vision-deficiency emulation on the web build.
- [ ] Contrast checks on all theme palettes, including te'amim tint colors and focus rings.

### 11.3 Manual, task-based (each release; all "common tasks")
Common tasks: first launch and onboarding, sign up / log in, open today's parasha, read an aliyah, toggle te'amim and nikud, change text size and theme, play audio from a verse, mark as read, view the streak, post a reply in the forum, report a post, change settings, open help or feedback.

| Configuration | Platforms | Pass criteria |
|---|---|---|
| **VoiceOver** (Hebrew + English voices) | iOS, macOS Safari (web) | All tasks done. Verses are read in Hebrew, verse by verse. Headings rotor works. Actions rotor offers bookmark/copy/play. No te'amim noise. Divine Name per setting |
| **TalkBack** | Android | Same. Actions menu works. Reading controls navigate by heading. Hebrew voice is used |
| **NVDA** + Chrome/Firefox | Web | "Enable accessibility" (or auto) works. Browse mode reads verses. Headings (H key) work. Forms are labeled |
| **NVDA** and **Narrator** | Windows desktop | Same tasks. Focus is always visible. No unlabeled controls |
| Keyboard only | Windows, web, iPad with keyboard | Every task without a mouse. Visible focus. No traps. Shortcuts work and are documented |
| **Voice Control** ("Show names/numbers") / **Voice Access** | iOS / Android | Every control can be activated by name |
| **Switch Control / Switch Access** | iOS / Android | Can read an aliyah and mark it complete |
| Largest text (iOS AX5, Android 200%), plus in-app reading size at maximum | All | No clipping or overlap. Rows stack vertically. Reading text wraps |
| Bold Text + Increase Contrast + Reduce Transparency | iOS | Readable. High-contrast theme applied |
| Windows Contrast Themes (Aquatic, Desert, Dusk, Night sky) | Windows | Content readable (or the in-app high contrast works) |
| Reduce Motion / Remove animations | All | No parallax, confetti, or animated page turns |
| Smart Invert, Grayscale, color filters | iOS/Android | Photos not inverted. Meaning survives grayscale |
| Browser zoom 200% / 400%, plus the text-spacing bookmarklet | Web | No loss of content. Spacing applied (Flutter ≥3.41) |
| RTL (Hebrew UI) and LTR (English UI) | All | Mirrored layout, correct icon mirroring, correct reading order |

**Hebrew test passages:** Gen 1:1 (baseline), a verse with **maqaf** chains, a verse with **paseq**, a **ketiv/qere** verse, verses containing the **Divine Name** (including אדני יהוה), a **setumah/petuchah** boundary, and a long verse (e.g., Esther 8:9 for haftarah or Megillot) to stress layout.

---

## 12. Feature checklist for this app

Priority: **P0** = launch blocker, **P1** = soon after launch, **P2** = later or differentiator.

### Reading view
- [ ] **P0** Per-verse semantics nodes with a **cleaned spoken label** (te'amim and meteg stripped, nikud kept), tagged Hebrew. Verse number spoken as "verse N"
- [ ] **P0** Headings: parasha (h1), aliyah (h2), chapter (h3) via `headingLevel`
- [ ] **P0** Toggles: **show te'amim**, **show nikud**, **show Targum**, show translation
- [ ] **P0** **Reading size** control (50%–500%) multiplied with the system scale. A−/A+ buttons plus keyboard shortcuts
- [ ] **P0** Themes: Light / Dark / **Sepia** / **High-contrast light** / **High-contrast dark** / Follow system. Auto-select high contrast via `highContrastTheme`
- [ ] **P0** No gesture-only navigation: visible Prev/Next verse and aliyah buttons. Custom actions for verse long-press options
- [ ] **P0** Bundled Hebrew fonts with te'amim support. Bold weight verified to keep te'amim
- [ ] **P1** **Divine Name speech setting** (Adonai / HaShem / spell / as written). Read the **qere**
- [ ] **P1** Spacing controls: line height (1.5–2.5), word spacing, letter spacing (if safe with marks, see §5.8), paragraph spacing. Text alignment: justified / start
- [ ] **P1** Max line width (narrow / medium / wide). Single-column stacking at large sizes. "One verse per screen" large-print paging
- [ ] **P1** **Focus / reading-ruler mode** (highlight band, underline, or dim others; adjustable color and height). Distraction-free mode that hides chrome
- [ ] **P1** Custom text and background colors (1.4.8). Optional te'amim tint with a contrast check
- [ ] **P1** Font choice (2–3 Hebrew fonts, including a sans), plus Atkinson Hyperlegible for the English UI
- [ ] **P1** Tap a word to reveal its vowels (for consonant-only practice). Tap a word for its te'am name
- [ ] **P1** In-app search (needed on web because browser find doesn't work on canvas)
- [ ] **P1** "Screen reader text" setting: Simplified (default) / Consonants only / All marks (for braille users)
- [ ] **P1** Targum speech: Hebrew voice (default) / default voice
- [ ] **P2** "Describe cantillation" action (word + te'am name) and export with te'amim names, for blind learners (BRITH-style)
- [ ] **P2** Synchronized highlighting with chanted audio. Loop a verse. Speed control
- [ ] **P2** Read-aloud via TTS for UI and forum text, with Hebrew-voice detection and install guidance

### Streaks and progress
- [ ] **P0** Accessible streak calendar: each day cell labeled ("Tuesday 7 October, read"), icons or patterns plus color, 44/48 targets
- [ ] **P0** Shabbat and Yom Tov never break streaks. Plain-language day definition (time zone, day boundary)
- [ ] **P0** Status announcements for "Marked as read" and "Streak: N" (liveRegion / announce)
- [ ] **P1** Automatic freezes or repair window. Weekly-streak alternative. **Hide streaks** option. No shame language
- [ ] **P1** Progress: "Aliyah 3 of 7", "Verse 5 of 19", estimated reading time
- [ ] **P1** Celebrations respect Reduce Motion, don't flash, and have text equivalents. Haptics toggle

### Forums
- [ ] **P0** Sign-in: password manager autofill, paste allowed, passkeys or Sign in with Apple/Google, or magic link. No puzzle CAPTCHA
- [ ] **P0** Composer: persistent labels, inline errors announced, **auto-saved drafts**, RTL/LTR auto-direction per post plus a manual toggle
- [ ] **P0** Thread structure: headings, list semantics, explicit pagination or "Load more" (no infinite scroll trap), unread state not color-only
- [ ] **P1** Alt-text prompt for image uploads. Display alt text. Optionally block posting images without alt text, or warn
- [ ] **P1** Report and undo for destructive actions. Confirmation dialogs with clear text
- [ ] **P1** Plain-language community guidelines. Notification digests. Quiet hours and Shabbat silence
- [ ] **P2** Read a thread aloud. Simplified "focus" thread view

### App-wide
- [ ] **P0** All icon buttons labeled (`tooltip`). Targets ≥48 dp / 44 pt. Focus visible (≥3:1, ≥2 px). Focus not obscured by sticky bars
- [ ] **P0** Full keyboard support on Windows and web. Shortcut help sheet. Single-key shortcuts scoped or toggleable
- [ ] **P0** Respect system text scale without clamping reading content. Layouts reflow at 200–320%
- [ ] **P0** Respect Reduce Motion / Remove animations, plus an in-app "Reduce motion" setting
- [ ] **P0** Full RTL support with directional widgets and correct icon mirroring. Localized semantics labels (he/en)
- [ ] **P0** Web: semantics enabled (auto or clear opt-in). Route titles. Real links
- [ ] **P0** Accessibility statement and in-app feedback form (with consented diagnostics)
- [ ] **P1** Accessibility settings hub ("Display & reading", "Speech", "Motion", "Haptics", "Shortcuts") with reading profiles (presets: Large print, Dyslexia-friendly, High contrast, Leining practice)
- [ ] **P1** Apple Accessibility Nutrition Labels and Google Play accessibility metadata filled in honestly
- [ ] **P1** Glossary of terms. Contextual help. Consistent help location
- [ ] **P2** Sync accessibility preferences across devices (account-level)

---

## 13. Flutter implementation notes

### 13.1 API inventory (by concern)
- **Semantics:** `Semantics` (`label`, `attributedLabel`, `hint`, `value`, `button`, `link`, `linkUrl`, `headingLevel`, `liveRegion`, `sortKey`, `excludeSemantics`, `container`, `explicitChildNodes`, `customSemanticsActions`, `onTapHint`, `localeForSubtree`, `textDirection`, `identifier`, `role`), `MergeSemantics`, `ExcludeSemantics`, `BlockSemantics`, `IndexedSemantics`, `SliverSemantics`, `OrdinalSortKey`, `CustomSemanticsAction`, `AttributedString`, `LocaleStringAttribute`, `SpellOutStringAttribute`, `TextSpan(locale:, spellOut:)`.
- **Announcements:** `SemanticsService.announce` (or `sendAnnouncement(View.of(context), ...)` on SDKs that have it), `MediaQuery.supportsAnnounceOf`, `Assertiveness`.
- **System settings:** `MediaQuery.textScalerOf`, `boldTextOf`, `highContrastOf`, `disableAnimationsOf`, `accessibleNavigationOf`, `invertColorsOf`, `onOffSwitchLabelsOf`, `supportsAnnounceOf`. `dart:ui` `AccessibilityFeatures.reduceMotion`. `PlatformDispatcher.instance.onAccessibilityFeaturesChanged`.
- **Text scaling:** `TextScaler`, `TextScaler.linear`, `TextScaler.clamp`, `SystemTextScaler`, `MediaQuery.withClampedTextScaling`, `MediaQuery.withNoTextScaling` (avoid both for reading text).
- **Themes:** `MaterialApp.theme/darkTheme/highContrastTheme/highContrastDarkTheme/themeMode`, `ColorScheme.fromSeed(contrastLevel:)` **[verify availability in your SDK]**, `ThemeData.materialTapTargetSize = MaterialTapTargetSize.padded`, `VisualDensity.standard`, `kMinInteractiveDimension` (48).
- **Focus and keyboard:** `Focus`, `FocusNode`, `FocusScope`, `FocusTraversalGroup`, `ReadingOrderTraversalPolicy`, `OrderedTraversalPolicy`, `FocusTraversalOrder`, `NumericFocusOrder`, `FocusableActionDetector`, `Shortcuts`, `Actions`, `Intent`, `CallbackAction`, `SingleActivator`, `CharacterActivator`, `CallbackShortcuts`, `FocusManager.instance.highlightMode`, `Scrollable.ensureVisible`, `MenuAnchor`, `MenuBar`, `PlatformMenuBar`.
- **RTL:** `Directionality`, `TextDirection.rtl`, `EdgeInsetsDirectional`, `AlignmentDirectional`, `BorderRadiusDirectional`, `PositionedDirectional`, `TextAlign.start`, `IconData.matchTextDirection`, `BackButtonIcon`, `flutter_localizations` (`GlobalMaterialLocalizations`, `GlobalWidgetsLocalizations`, `GlobalCupertinoLocalizations`), `intl` `Bidi` helpers.
- **Forms and auth:** `AutofillGroup`, `AutofillHints.username/email/password/newPassword/oneTimeCode`, `TextInput.finishAutofillContext()`, `InputDecoration(labelText:, errorText:, helperText:)`.
- **Feedback:** `SnackBar(persist:)`, `HapticFeedback.selectionClick/lightImpact/mediumImpact/heavyImpact`, `Tooltip`, `IconButton(tooltip:)`.
- **Web:** `SemanticsBinding.instance.ensureSemantics()`, `kIsWeb`, `Title`, `Link` (url_launcher), `SemanticsRole`.
- **Testing and debugging:** `tester.ensureSemantics()`, `meetsGuideline(androidTapTargetGuideline | iOSTapTargetGuideline | labeledTapTargetGuideline | textContrastGuideline)`, `matchesSemantics`, `containsSemantics`, `find.bySemanticsLabel`, `FakeAccessibilityFeatures`, `tester.platformDispatcher.textScaleFactorTestValue` / `accessibilityFeaturesTestValue` / `clearAllTestValues()`, `MaterialApp(showSemanticsDebugger: true)`, `debugDumpSemanticsTree()`, DevTools Inspector.

### 13.2 Hebrew spoken-label helper (sketch)
```dart
/// Builds the text a screen reader should speak for one verse.
/// The visible text stays untouched (full nikud + te'amim).
class HebrewSpeech {
  static final _teamim = RegExp(r'[֑-ֽׅ֯ׄ]'); // accents, meteg, upper/lower dots
  static final _nikud  = RegExp(r'[ְ-ׇּֿׁׂ]'); // vowels, dagesh, rafe, shin/sin dots, qamats qatan
  static final _maqaf  = RegExp('־');
  static final _sofPasuq = RegExp('׃');
  static final _paseqEtc = RegExp(r'[׀׆⁦-⁩]'); // paseq, nun hafukha, bidi isolates

  static String spoken(String verse, SpeechPrefs p) {
    var s = verse.replaceAll(_teamim, '');
    if (!p.keepNikud) s = s.replaceAll(_nikud, '');
    s = s.replaceAll(_maqaf, p.maqafAsSpace ? ' ' : '־')
         .replaceAll(_sofPasuq, '.')
         .replaceAll(_paseqEtc, '');
    s = _applyDivineName(s, p.divineName); // operate on a consonant-only shadow copy to match יהוה + prefixes
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
```
Do the Divine Name and ketiv/qere substitution from **structured source data** (a word-level model with qere fields) rather than regex where possible.

### 13.3 Verse widget semantics
```dart
Semantics(
  container: true,
  identifier: 'verse-$chapter-$verse',
  sortKey: OrdinalSortKey(index.toDouble()),
  attributedLabel: AttributedString(
    '$verseWord $verseNumber. $spoken',
    attributes: [LocaleStringAttribute(
      range: TextRange(start: 0, end: '$verseWord $verseNumber. $spoken'.length),
      locale: const Locale('he'),
    )],
  ),
  textDirection: TextDirection.rtl,
  customSemanticsActions: {
    const CustomSemanticsAction(label: 'Play from this verse'): () => player.playFrom(ref),
    const CustomSemanticsAction(label: 'Bookmark'): () => bookmarks.toggle(ref),
    const CustomSemanticsAction(label: 'Copy verse'): () => copy(ref),
    const CustomSemanticsAction(label: 'Describe cantillation'): () => describeTeamim(ref),
  },
  excludeSemantics: true, // hide raw glyph runs (with te'amim) from AT
  child: FocusableActionDetector(/* keyboard focus ring + Enter → verse menu */
    child: VerseText(verse, prefs),
  ),
)
```
Localize the action labels (Hebrew UI gets Hebrew labels).

### 13.4 Reading size multiplied with the system scale
```dart
final style = TextStyle(
  fontFamily: prefs.hebrewFont,               // bundled, with fontFamilyFallback
  fontSize: 22 * prefs.readingScale,          // in-app 0.5–5.0
  height: prefs.lineHeight,                   // default ~1.9 for pointed + cantillated text
  wordSpacing: prefs.wordSpacing,
  fontWeight: (MediaQuery.boldTextOf(context) || prefs.bold) ? FontWeight.w700 : FontWeight.w400,
);
// Text/Text.rich picks up MediaQuery.textScalerOf(context) automatically → system scale stacks on top.
```

### 13.5 Motion
```dart
bool reduceMotion(BuildContext c) =>
    MediaQuery.disableAnimationsOf(c) || context.read<Prefs>().reduceMotion;
// AnimatedSwitcher(duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 200), ...)
// Skip confetti/Lottie when reduceMotion; announce the milestone text instead.
```

### 13.6 Announcements helper
```dart
void announce(BuildContext context, String msg, {TextDirection? dir}) {
  final d = dir ?? Directionality.of(context);
  if (MediaQuery.supportsAnnounceOf(context)) {
    SemanticsService.announce(msg, d); // or sendAnnouncement(View.of(context), msg, d) on newer SDKs
  } else {
    statusNotifier.value = msg; // rendered inside Semantics(liveRegion: true) → Android announces politely
  }
}
```

### 13.7 Keyboard shortcuts (reader)
```dart
final isMac = defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
Shortcuts(
  shortcuts: {
    const SingleActivator(LogicalKeyboardKey.arrowDown, alt: true): const NextVerseIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true): const PrevVerseIntent(),
    SingleActivator(LogicalKeyboardKey.equal, control: !isMac, meta: isMac): const ZoomInIntent(),
    SingleActivator(LogicalKeyboardKey.minus, control: !isMac, meta: isMac): const ZoomOutIntent(),
    SingleActivator(LogicalKeyboardKey.keyT, control: !isMac, meta: isMac): const ToggleTeamimIntent(),
  },
  child: Actions(
    actions: {
      NextVerseIntent: CallbackAction<NextVerseIntent>(onInvoke: (_) => reader.next()),
      // ...
    },
    child: FocusTraversalGroup(child: Focus(autofocus: true, child: reader)),
  ),
);
```
In RTL, decide deliberately whether ←/→ mean "next" (they visually point the other way). Alt+↑/↓ avoids the ambiguity.

### 13.8 Web bootstrap
```dart
void main() {
  runApp(const TorahApp());
  if (kIsWeb && prefs.forceWebSemantics /* default true after perf testing */) {
    SemanticsBinding.instance.ensureSemantics();
  }
}
```

### 13.9 CI accessibility test template
```dart
for (final scale in [1.0, 2.0, 3.2]) {
  for (final dir in [TextDirection.ltr, TextDirection.rtl]) {
    testWidgets('a11y: reader @${scale}x $dir', (tester) async {
      final handle = tester.ensureSemantics();
      tester.platformDispatcher.textScaleFactorTestValue = scale;          // [verify API on your SDK]
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.pumpWidget(TestApp(direction: dir, child: const ReaderScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull); // catches overflow errors
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }
}
```

### 13.10 Things to verify on-device early (spikes)
1. VoiceOver, TalkBack, NVDA, and Narrator reading a verse with (a) raw text, (b) te'amim stripped, (c) all marks stripped, each with and without `LocaleStringAttribute('he')`. Record which voice each uses and what it says.
2. Whether Flutter web emits `lang` for `localeForSubtree` / `LocaleStringAttribute` (NVDA language switching on web).
3. `letterSpacing` with combining marks in SkParagraph and on the web renderer.
4. Performance of `ensureSemantics()` on web with a full parasha.
5. Windows: does `highContrastOf` reflect Contrast Themes? Does the Windows text-size slider reach `textScalerOf`?
6. Maqaf handling per engine (space vs. keep).
7. Aramaic `arc` tagging: silence, fallback, or error per platform.

---

## 14. Sources

**W3C / WCAG**
- WCAG 2.2: https://www.w3.org/TR/WCAG22/
- Deque, WCAG 2.2 updates: https://dequeuniversity.com/resources/wcag-2.2
- Understanding 2.5.8 Target Size (Minimum): https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html
- Understanding 1.4.10 Reflow: https://www.w3.org/WAI/WCAG22/Understanding/reflow
- Understanding 1.4.12 Text Spacing: https://www.w3.org/WAI/WCAG21/Understanding/text-spacing
- Understanding 1.4.8 Visual Presentation: https://www.w3.org/WAI/WCAG22/Understanding/visual-presentation
- Understanding 2.3.3 Animation from Interactions: https://w3c.github.io/wcag/understanding/animation-from-interactions.html
- ARIA22 role=status technique: https://www.w3.org/WAI/WCAG22/Techniques/aria/ARIA22
- Understanding 3.3.8 Accessible Authentication: https://www.w3.org/WAI/WCAG22/Understanding/accessible-authentication.html
- H56 dir attribute for nested bidi text: https://www.w3.org/WAI/WCAG21/Techniques/html/H56
- Hebrew Gap Analysis (W3C draft note, 2025): https://www.w3.org/TR/2025/DNOTE-hebr-gap-20250117
- Unicode bidi isolates proposal: https://www.unicode.org/L2/L2012/12186r-bidi-isolates.pdf
- WCAG2ICT published (US Access Board): https://www.access-board.gov/news/2024/10/08/wcag2ict-published-as-w3c-group-note/
- TetraLogical on WCAG2ICT: https://tetralogical.com/blog/2024/07/18/WCAG2ICT/
- WCAG2Mobile: https://www.w3.org/TR/wcag2mobile/
- WCAG2ICT minutes (Apr 2024): https://www.w3.org/2024/04/26-wcag2ict-minutes.html
- WAI-IG thread on 1.4.12 in native apps: https://lists.w3.org/Archives/Public/w3c-wai-ig/2020JulSep/0002.html
- html5accessibility (Lauke) on AA for apps: https://html5accessibility.com/stuff/2024/07/09/peaky-wcag-level-aa-bang-for-your-app-a11y-buck/
- WebAIM list on 1.4.4 in apps: https://webaim.org/discussion/mail_message?id=42120
- COGA, Making Content Usable: https://www.w3.org/TR/coga-usable/
- COGA Task Force: https://www.w3.org/WAI/GL/task-forces/coga/
- UK DfE cognitive accessibility guidelines (8 objectives): https://apply-the-service-standard.education.gov.uk/guides/guidelines/cognitive-accessibility-guidelines
- COGA objective, avoid mistakes: https://www.w3.org/WAI/WCAG2/supplemental/objectives/o4-minimize-mistakes/
- Developing an Accessibility Statement: https://www.w3.org/WAI/planning/statements/
- WAI-EO thread on the statement generator: https://lists.w3.org/Archives/Public/wai-eo-editors/2018Nov/0024.html
- W3C WAI-GL 2004, Hebrew without vowels: https://lists.w3.org/Archives/Public/w3c-wai-gl/2004JanMar/0198.html

**Flutter**
- meetsGuideline: https://api.flutter.dev/flutter/flutter_test/meetsGuideline.html
- Accessibility testing: https://docs.flutter.dev/ui/accessibility/accessibility-testing
- Accessibility overview and release checklist: https://docs.flutter.dev/ui/accessibility
- Assistive technologies: https://docs.flutter.dev/ui/accessibility/assistive-technologies
- Web accessibility: https://docs.flutter.dev/ui/accessibility/web-accessibility
- Accessibility on the web (blog): https://flutter.dev/blog/accessibility-in-flutter-on-the-web
- AccessibilityFeatures: https://api.flutter.dev/flutter/dart-ui/AccessibilityFeatures-class.html
- MediaQuery: https://api.flutter.dev/flutter/widgets/MediaQuery-class.html
- boldTextOf: https://api.flutter.dev/flutter/widgets/MediaQuery/boldTextOf.html
- highContrastOf: https://api.flutter.dev/flutter/widgets/MediaQuery/highContrastOf.html
- Deprecate textScaleFactor: https://docs.flutter.dev/release/breaking-changes/deprecate-textscalefactor
- Android 14 non-linear scaling: https://docs.flutter.dev/release/breaking-changes/android-14-nonlinear-text-scaling-migration
- TextScaler.clamp: https://api.flutter.dev/flutter/painting/TextScaler/clamp.html
- SemanticsService.announce: https://api.flutter.dev/flutter/semantics/SemanticsService/announce.html
- SemanticsService.sendAnnouncement: https://api.flutter.dev/flutter/semantics/SemanticsService/sendAnnouncement.html
- Announce revert commit: https://flutter.googlesource.com/mirrors/flutter/+/5e146d47a61098e5ed967352812bcbbe0fe24f20%5E%21/
- supportsAnnounce: https://api.flutter.dev/flutter/dart-ui/AccessibilityFeatures/supportsAnnounce.html
- liveRegion: https://api.flutter.dev/flutter/semantics/SemanticsProperties/liveRegion.html
- LocaleStringAttribute: https://api.flutter.dev/flutter/dart-ui/LocaleStringAttribute-class.html
- attributedLabel: https://api.flutter.dev/flutter/semantics/SemanticsProperties/attributedLabel.html
- localeForSubtree: https://api.flutter.dev/flutter/widgets/Semantics/localeForSubtree.html
- TextSpan locale/spellOut commit: https://dart.googlesource.com/external/github.com/flutter/flutter/+/67cee6308744d50ec84c32f200e9fd7d730f227c%5E%21/
- headingLevel breaking change: https://docs.flutter.dev/release/breaking-changes/semantics-header-heading-level
- Semantics constructor: https://api.flutter.dev/flutter/widgets/Semantics/Semantics.html
- OrdinalSortKey: https://api.flutter.dev/flutter/semantics/OrdinalSortKey-class.html
- OrderedTraversalPolicy: https://api.flutter.dev/flutter/widgets/OrderedTraversalPolicy-class.html
- NumericFocusOrder: https://api.flutter.dev/flutter/widgets/NumericFocusOrder-class.html
- User input & accessibility: https://docs.flutter.dev/ui/adaptive-responsive/input
- highContrastTheme: https://api.flutter.dev/flutter/material/MaterialApp/highContrastTheme.html
- highContrastDarkTheme: https://api.flutter.dev/flutter/material/MaterialApp/highContrastDarkTheme.html
- SnackBar with action behavior change: https://docs.flutter.dev/release/breaking-changes/snackbar-with-action-behavior-update
- TextField.autofillHints: https://api.flutter.dev/flutter/material/TextField/autofillHints.html
- Windows engine accessibility doc: https://flutter.googlesource.com/mirrors/flutter/+show/3a5c2cefdfc73bd2e4e47d8ef80489c060436b37/docs/platforms/desktop/windows/Accessibility-on-Windows.md
- Windows text scaling forum thread: https://forum.itsallwidgets.com/t/windows-text-scaling-seems-unrelated-to-mediaquery-of-context-textscaler/4037
- Flutter 3.41 release notes: https://docs.flutter.dev/release/release-notes/release-notes-3.41.0
- WebView text-spacing regression write-up: https://startdebugging.net/2026/09/fix-flutter-text-renders-off-screen-in-an-android-webview-with-font-scaling/
- accessible_text_view (Android link limitation): https://pub.dev/documentation/accessible_text_view/latest/
- Droids On Roids guide, part 2: https://www.thedroidsonroids.com/blog/flutter-accessibility-guide-part-2
- DCM Flutter accessibility tips (3.32 roles): https://dcm.dev/blog/2025/06/30/accessibility-flutter-practical-tips-tools-code-youll-actually-use/
- Wonderous app accessibility: https://www.mintlify.com/gskinnerTeam/flutter-wonderous-app/architecture/accessibility
- Flutter screen-reader study: https://openaccess.cms-conferences.org/publications/book/978-1-958651-13-1/article/978-1-958651-13-1_5
- FlexColorScheme theme mode guidance: https://docs.flexcolorscheme.com/theme_scheme

**Apple**
- HIG Accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility
- Accessibility Nutrition Labels overview: https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels
- Voice Control criteria: https://developer.apple.com/help/app-store-connect/manage-app-accessibility/voice-control-accessibility-evaluation-criteria
- Sufficient Contrast criteria: https://developer.apple.com/help/app-store-connect/manage-app-accessibility/sufficient-contrast-evaluation-criteria
- Differentiate Without Color criteria: https://developer.apple.com/help/app-store-connect/manage-app-accessibility/differentiate-without-color-alone-evaluation-criteria
- Larger Text criteria: https://developer-rno.apple.com/help/app-store-connect/manage-app-accessibility/larger-text-evaluation-criteria
- Dark Interface criteria: https://developer.apple.com/help/app-store-connect/manage-app-accessibility/dark-interface-evaluation-criteria
- WWDC25 session 224: https://developer.apple.com/videos/play/wwdc2025/224/
- SwiftUI accessible appearance: https://developer.apple.com/documentation/swiftui/accessible-appearance
- Voice Control tweaks (Swiftjectivec): https://www.swiftjectivec.com/voice-control-accessibility-tweaks-ios
- accessibilityUserInputLabels forum thread: https://developer.apple.com/forums/thread/765999

**Android / Material / Google Play**
- Touch target size: https://support.google.com/accessibility/android/answer/7101858
- M3 accessibility: https://m3.material.io/foundations/accessibility
- Compose minimumInteractiveComponentSize: https://kotlinlang.org/api/compose-multiplatform/material3/androidx.compose.material3/minimum-interactive-component-size.html
- Play accessibility declarations: https://support.google.com/googleplay/android-developer/answer/10964491

**Legal**
- EAA in force: https://www.insideglobaltech.com/2025/06/10/european-accessibility-act-june-2025-deadline-has-arrived/
- SGS on EAA: https://www.sgs.com/en/news/2025/09/safeguards-13925-european-accessibility-act-eaa-takes-effect-unifying-standards-across-the-eu
- Israel overview (BOIA): https://www.boia.org/blog/israels-digital-accessibility-laws-an-overview
- IS 5568 guide: https://www.wawsome.com/blog/israel-digital-accessibility-law-is-5568-guide
- Canada feedback process example: https://www.canada.ca/en/economic-development-quebec-regions/about/accessibility/accessibility-feedback-process.html

**Hebrew, screen readers, TTS, fonts, braille**
- AppleVis, Studying Biblical Hebrew: https://www.applevis.com/comment/128206 · https://www.applevis.com/comment/128198 · https://www.applevis.com/comment/128234
- AppleVis, VoiceOver Hebrew support needed (2014): https://www.applevis.com/forum/voiceover-hebrew-support-needed
- Screen readers used in Israel (NVDA/Carmel): https://user-a.co.il/en/assistive-technologies/what-screen-reader-software-do-blind-users-choose
- iOS 8 Hebrew speech: https://useyourloaf.com/blog/ios-8-adds-hebrew-speech-synthesis/
- IBI-L, Carmit in iOS 8: https://groups.google.com/g/ibi-l/c/3quEwkjweFM
- Microsoft Q&A, Hebrew voices (Hila/Avri): https://learn.microsoft.com/en-us/answers/a/12407670
- Hebrew TTS providers comparison: https://github.com/danielrosehill/Hebrew-TTS-Providers
- Hebrew TTS and niqqud: https://speechactors.com/article/hebrew-text-to-speech
- NVDA developer guide (symbols): https://download.nvaccess.org/releases/2024.2/documentation/developerGuide.html
- Unicode Hebrew names list: https://unicode.org/charts/nameslist/n_0590.html
- Microsoft Hebrew OpenType development: https://learn.microsoft.com/en-us/typography/script-development/hebrew
- Hebrew punctuation (maqaf, sof pasuq, paseq): https://en.wikipedia.org/wiki/Hebrew_punctuation
- Sefaria vowels/cantillation toggles: https://help.sefaria.org/hc/en-us/articles/18613829394204-How-to-View-a-Hebrew-Text-With-or-Without-Vowels-Cantillation-Markings-and-Punctuation
- Sefaria formatting & accessibility: https://help.sefaria.org/hc/en-us/sections/12756520483868-Text-Formatting-and-Accessibility
- Sefaria contest (TTS quality): https://www.sefaria.org.il/powered-by-sefaria-contest-2021
- Logos forum, Tetragrammaton in TTS: https://community.logos.com/discussion/comment/610518
- Hebrew Braille: https://en.wikipedia.org/wiki/Hebrew_Braille
- BRITH braille cantillation: https://github.com/dsadinoff/brith
- Kveller, braille trop bat mitzvah: https://www.kveller.com/?p=71154
- JBI Library: https://jbilibrary.org/what-we-do
- Open Siddur Hebrew fonts: https://opensiddur.org/help/fonts/
- Culmus Taamey fonts: https://culmus.sourceforge.io/taamim/

**Cognitive, dyslexia, reading**
- Wery & Diliberto, OpenDyslexic: https://pmc.ncbi.nlm.nih.gov/articles/PMC5629233/ · https://link.springer.com/article/10.1007/s11881-016-0127-1
- Edutopia on dyslexia fonts: https://www.edutopia.org/article/do-dyslexia-fonts-actually-work/
- Rello & Baeza-Yates, Good Fonts for Dyslexia: https://doi.org/10.1145/2513383.2513447 · summary: https://editingresearch.byu.edu/2020/05/28/which-fonts-are-best-for-dyslexia/
- Zorzi et al. 2012, letter spacing: https://pmc.ncbi.nlm.nih.gov/articles/PMC3396504
- Dotan & Katzir 2018, Hebrew letter spacing: https://cris.iucc.ac.il/en/publications/mind-the-gap-increased-inter-letter-spacing-as-a-means-of-improvi/
- Dotan & Katzir 2025: https://www.mdpi.com/2227-7102/15/10/1306
- Schiff, Katzir & Shoshan 2013: https://education.biu.ac.il/en/node/5367
- Weiss, Katzir & Bitan 2015: https://newiipdm.haifa.ac.il/wp-content/uploads/2015/05/WeissKatzirBitan2015.pdf
- Digital reading rulers (CHI 2023): https://research.adobe.com/publication/digital-reading-rulers-evaluating-inclusively-designed-rulers-for-readers-with-dyslexia-and-without
- Schneps et al. 2013, shorter lines: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3734020/
- BDA Dyslexia Style Guide (copy): https://www.wigan.gov.uk/Docs/PDF/Business/Professionals/SEN/HEFA/Dyslexia-Style-Guide.pdf
- Dyslexia Scotland formats: https://dyslexiascotland.org.uk/dyslexia-friendly-typed-formats
- Atkinson Hyperlegible: https://www.allaboutvision.com/low-vision/atkinson-hyperlegible-typeface/
- CSUN 2024 Atkinson session: https://csun.edu/cod/conference/sessions/index.php/public/presentations/view/3108
- Accessible fonts review: https://fontalternatives.com/blog/best-free-accessible-fonts-dyslexia-low-vision/
- Streaks and stress (BI thesis): https://biopen.bi.no/bi-xmlui/handle/11250/2623593
- UX Magazine, gamification ethics: https://uxmag.com/articles/gamification-or-manipulation-understanding-the-ethics-of-engagement-loops
- Streak design examples: https://screensdesign.com/articles/mobile-app-streak-design-examples/
- ADHD and streaks (opinion): https://dev.to/nucleusos/adhd-support-app-no-streaks-why-gamification-hurts-more-than-it-helps-1ae0

**Low vision and color**
- Piepenbrock et al., polarity in older adults: https://documentacion.fundacionmapfre.org/documentacion/publico/pt/bib/143702.do
- cogsci.nl, dark backgrounds: https://cogsci.nl/blog/is-bright-text-on-a-dark-background-a-good-idea
- NN/g, Dark mode vs light mode: https://www.nngroup.com/articles/dark-mode/
- Okabe-Ito palette: https://search.r-project.org/CRAN/refmans/thematic/html/okabe_ito.html
- MS Edge high-contrast explainer: https://github.com/hpsin/MSEdgeExplainers/blob/main/Accessibility/HighContrast/explainer.md
