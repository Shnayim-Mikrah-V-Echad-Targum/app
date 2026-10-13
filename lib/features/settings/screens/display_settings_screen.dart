import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device_accessibility.dart';
import '../../../app/providers.dart';
import '../../../data/models/verse_ref.dart';
import '../../../data/text_repository.dart';
import '../../../services/optional_fonts.dart';
import '../../../ui/l10n.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/common.dart';
import '../../../ui/widgets/paper_group.dart';
import '../../../ui/widgets/theme_swatch_picker.dart';
import '../../reader/reader_screen.dart';
import '../../reader/scripture_text.dart';
import '../app_settings.dart';
import '../widgets/divine_name_switch.dart';
import '../widgets/settings_widgets.dart';

/// The words each scripture font is shown in, as its sample.
const scriptureFontSample = 'בְּרֵאשִׁית בָּרָא';

/// The letters each interface font is shown in: Latin, and Hebrew, which
/// the accessibility fonts leave to Noto Sans Hebrew.
const _uiFontSample = 'Aa Bb אב';

/// Settings → Display (docs/DESIGN_SYSTEM.md §9): a page of the text held at
/// the top, showing each change as it is made, then the theme, size and
/// spacing, what the text shows, its width and its fonts.
class DisplaySettingsScreen extends ConsumerStatefulWidget {
  const DisplaySettingsScreen({super.key});

  @override
  ConsumerState<DisplaySettingsScreen> createState() => _DisplaySettingsScreenState();
}

class _DisplaySettingsScreenState extends ConsumerState<DisplaySettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Each font's sample is set in that font, at its regular weight, so that
    // face of every one is loaded (the bold waits until one is chosen); the
    // samples are laid out again as each arrives.
    OptionalFonts.ensureSamples([for (final f in ScriptureFont.values) f.family, for (final f in UiFont.values) f.family]);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    void update(AppSettings Function(AppSettings) f) => ref.read(settingsProvider.notifier).update(f);
    SwitchRow toggle(
      String title,
      bool value,
      AppSettings Function(AppSettings, bool) set, {
      String? subtitle,
      bool enabled = true,
    }) =>
        SwitchRow(
          title: title,
          subtitle: subtitle,
          value: value,
          onChanged: enabled ? (v) => update((s) => set(s, v)) : null,
        );
    // The device's Bold text is in force whatever the app's says: the switch
    // shows it on, and leaves it to the device's settings.
    final deviceBold = DeviceAccessibility.boldTextOf(context);
    // A slider is a row of its paper, its title where a row's text starts.
    Widget slider(LabeledSlider slider) =>
        Padding(padding: const EdgeInsets.only(top: Space.sm, bottom: Space.xs), child: slider);
    // The sliders on one paper, which set their values alike.
    final sizes = [l.readingSize, l.lineSpacing, l.wordSpacing, l.letterSpacing];

    return SettingsPage(
      title: l.settingsDisplay,
      paper: true,
      preview: (context, shrunk) => _PreviewPage(shrunk: shrunk),
      children: [
        GroupHeader(l.themeLabel),
        ThemeSwatchPicker(value: s.theme, onChanged: (v) => update((s) => s.copyWith(theme: v))),
        GroupHeader(l.displayGroupSize),
        PaperGroup(
          children: [
            slider(LabeledSlider(
              title: l.readingSize,
              group: sizes,
              value: s.readingScale,
              min: kMinReadingScale,
              max: kMaxReadingScale,
              step: 0.1,
              format: (v) => l.readingSizeValue((v * 100).round()),
              onChanged: (v) => update((s) => s.copyWith(readingScale: v)),
            )),
            slider(LabeledSlider(
              title: l.lineSpacing,
              group: sizes,
              value: s.lineHeight,
              min: kMinLineHeight,
              max: kMaxLineHeight,
              step: 0.1,
              format: (v) => v.toStringAsFixed(1),
              onChanged: (v) => update((s) => s.copyWith(lineHeight: v)),
            )),
            slider(LabeledSlider(
              title: l.wordSpacing,
              group: sizes,
              value: s.wordSpacing,
              min: 0,
              max: 16,
              step: 1,
              format: (v) => v.toStringAsFixed(0),
              onChanged: (v) => update((s) => s.copyWith(wordSpacing: v)),
            )),
            slider(LabeledSlider(
              title: l.letterSpacing,
              group: sizes,
              value: s.letterSpacing,
              min: 0,
              max: 4,
              step: 0.2,
              format: (v) => v.toStringAsFixed(1),
              onChanged: (v) => update((s) => s.copyWith(letterSpacing: v)),
            )),
          ],
        ),
        GroupHeader(l.displayGroupText),
        PaperGroup(
          children: [
            toggle(l.showNikud, s.showNikud, (s, v) => s.copyWith(showNikud: v)),
            toggle(l.showTeamim, s.showTeamim, (s, v) => s.copyWith(showTeamim: v)),
            toggle(l.showKetiv, s.showKetiv, (s, v) => s.copyWith(showKetiv: v)),
            toggle(l.showVerseNumbers, s.showVerseNumbers, (s, v) => s.copyWith(showVerseNumbers: v)),
            const DivineNameSwitch(),
          ],
        ),
        GroupHeader(l.displayGroupStudy),
        PaperGroup(
          children: [
            toggle(l.showTranslation, s.showTranslation, (s, v) => s.copyWith(showTranslation: v),
                subtitle: l.translationDisclaimer),
            toggle(l.showRashi, s.showRashi, (s, v) => s.copyWith(showRashi: v)),
            // Only while Rashi is shown, beside the Torah or as the second
            // reading.
            if (s.showsRashi)
              toggle(l.rashiScript, s.rashiScript, (s, v) => s.copyWith(rashiScript: v), subtitle: l.rashiScriptDesc),
          ],
        ),
        GroupHeader(l.displayGroupReading),
        PaperGroup(
          children: [
            toggle(l.focusMode, s.focusMode, (s, v) => s.copyWith(focusMode: v), subtitle: l.focusModeDesc),
            toggle(
              l.boldText,
              s.boldText || deviceBold,
              (s, v) => s.copyWith(boldText: v),
              subtitle: deviceBold ? l.settingOnInDevice : null,
              enabled: !deviceBold,
            ),
            toggle(l.keepScreenOn, s.keepScreenOn, (s, v) => s.copyWith(keepScreenOn: v)),
          ],
        ),
        ChoiceGroup<LineWidth>(
          title: l.lineWidthLabel,
          segmented: true,
          value: s.lineWidth,
          choices: [
            Choice(LineWidth.narrow, l.lineNarrow),
            Choice(LineWidth.medium, l.lineMedium),
            Choice(LineWidth.wide, l.lineWide),
          ],
          onChanged: (v) => update((s) => s.copyWith(lineWidth: v)),
        ),
        // Beside the measure it depends on.
        ChoiceGroup<JustifyMode>(
          title: l.justifyText,
          help: l.justifyHelp,
          segmented: true,
          value: s.justifyMode,
          choices: [
            Choice(JustifyMode.auto, l.justifyAuto),
            Choice(JustifyMode.always, l.justifyAlways),
            Choice(JustifyMode.never, l.justifyNever),
          ],
          onChanged: (v) => update((s) => s.copyWith(justifyMode: v)),
        ),
        ChoiceGroup<ScriptureFont>(
          title: l.scriptureFontLabel,
          value: s.scriptureFont,
          choices: [
            for (final (font, name) in [
              (ScriptureFont.notoSerif, l.fontNotoSerif),
              (ScriptureFont.taameyFrank, l.fontTaamey),
              (ScriptureFont.ezra, l.fontEzra),
              (ScriptureFont.notoSans, l.fontNotoSans),
            ])
              Choice(font, scriptureFontSample, subtitle: name, sampleStyle: scriptureSampleStyle(font, 22)),
          ],
          onChanged: (v) => update((s) => s.copyWith(scriptureFont: v)),
        ),
        ChoiceGroup<UiFont>(
          title: l.uiFontLabel,
          value: s.uiFont,
          choices: [
            for (final (font, name) in [
              (UiFont.standard, l.uiFontStandard),
              (UiFont.atkinson, l.uiFontAtkinson),
              (UiFont.lexend, l.uiFontLexend),
              (UiFont.openDyslexic, l.uiFontOpenDyslexic),
              // The web can't use the device's fonts. Still list the option
              // if it was imported from another device, so the group shows a
              // value.
              if (!kIsWeb || s.uiFont == UiFont.system) (UiFont.system, l.uiFontSystem),
            ])
              Choice(font, _uiFontSample, subtitle: name, sampleStyle: _uiSampleStyle(context, font)),
          ],
          onChanged: (v) => update((s) => s.copyWith(uiFont: v)),
        ),
      ],
    );
  }

  /// [font]'s letters as the interface would set them: the standard font in
  /// the UI's language, and the device's as the platform names it.
  static TextStyle _uiSampleStyle(BuildContext context, UiFont font) {
    final hebrewUi = context.isHebrewUi;
    final standard = hebrewUi ? 'NotoSansHebrew' : 'NotoSans';
    final family = switch (font) {
      UiFont.standard => standard,
      UiFont.system => kIsWeb ? standard : Theme.of(context).typography.black.bodyLarge?.fontFamily,
      _ => font.family,
    };
    return TextStyle(
      fontFamily: family,
      fontFamilyFallback: const ['NotoSansHebrew', 'NotoSans', 'NotoSerifHebrew'],
      fontSize: 20,
      height: 1.4,
      leadingDistribution: TextLeadingDistribution.even,
      fontWeight: FontWeight.w400,
    );
  }
}

/// [font]'s letters at [size], as a sample of it.
TextStyle scriptureSampleStyle(ScriptureFont font, double size) => TextStyle(
      fontFamily: font.family,
      fontFamilyFallback: const ['NotoSerifHebrew'],
      fontSize: size,
      height: 1.5,
      leadingDistribution: TextLeadingDistribution.even,
      fontWeight: FontWeight.w400,
    );

/// Deuteronomy 14:1–2, a section of its own, as a page of a chumash shows it
/// in the reader's settings: the chapter's head, each verse and its Targum,
/// and the setumah that closes it. The page is a window on the text, which
/// keeps its place as the window shrinks ([shrunk], 0 to 1) while the
/// settings scroll: the text goes up with them, the head first.
class _PreviewPage extends ConsumerWidget {
  const _PreviewPage({required this.shrunk});

  final double shrunk;

  static const _book = 'Deuteronomy';
  static const _chapter = 14;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final mikrah = ref.watch(bookTextProvider((TextLayer.mikrah, _book))).value;
    final onkelos = ref.watch(bookTextProvider((TextLayer.onkelos, _book))).value;
    final sefer = SeferColors.of(context);
    final styles = ScriptureStyles(context, s);

    // As the reader shows it in focus mode: the first verse is read, its
    // block marked as a whole, and the rest dimmed.
    Widget verse(int n, {required bool current}) {
      final at = VerseRef(_chapter, n);
      final dimmed = s.focusMode && !current;
      return _VerseBlock(
        highlighted: s.focusMode && current,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (mikrah != null)
              ScriptureVerse(verse: mikrah.verse(at), kind: ScriptureKind.mikrah, settings: s, dimmed: dimmed),
            if (onkelos != null)
              ScriptureVerse(
                verse: onkelos.verse(at),
                kind: ScriptureKind.targum,
                settings: s,
                dimmed: dimmed,
                secondary: true,
              ),
          ],
        ),
      );
    }

    // As wide as the reader's column, where the window is wider.
    final page = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The reader's own head and section mark; within the preview, which
        // is one image to a screen reader, the head is no heading.
        ChapterHeading(chapter: _chapter, settings: s),
        verse(1, current: true),
        verse(2, current: false),
        if (mikrah?.breaks[const VerseRef(_chapter, 2)] case final kind?) SectionGap(kind: kind, settings: s),
      ],
    );

    // How far the text has gone up: as far as the window has shrunk.
    final lifted = shrunk * (SettingsPage.previewMaxHeight - SettingsPage.previewMinHeight);
    final veil = sefer.isHighContrast ? null : sefer.paper;
    return Semantics(
      container: true,
      label: l.previewLabel,
      child: ExcludeSemantics(
        child: DecoratedBox(
          // Over the text and its fades, which would hide it at the edges.
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(color: sefer.hairline, width: sefer.hairlineWidth),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: sefer.paper)),
                Positioned.fill(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    child: Transform.translate(
                      offset: Offset(0, -lifted),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: _isNarrow(context) ? 16 : 20, vertical: 12),
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: styles.maxLineWidth),
                              child: page,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // The text runs on past the window's edges; it fades there,
                // except in high contrast, which keeps it whole to the edge.
                if (veil != null) ...[
                  if (lifted > 0) _Veil(color: veil, top: true, height: math.min(lifted, 20)),
                  _Veil(color: veil, top: false, height: 24),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static bool _isNarrow(BuildContext context) => MediaQuery.sizeOf(context).width < kNarrowScreenWidth;
}

/// A fade from the page's paper at one edge of the preview's window.
class _Veil extends StatelessWidget {
  const _Veil({required this.color, required this.top, required this.height});

  final Color color;
  final bool top;
  final double height;

  @override
  Widget build(BuildContext context) => Positioned(
        left: 0,
        right: 0,
        top: top ? 0 : null,
        bottom: top ? null : 0,
        height: height,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: top ? Alignment.topCenter : Alignment.bottomCenter,
                end: top ? Alignment.bottomCenter : Alignment.topCenter,
                colors: [color, color.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      );
}

/// One verse's block (its Mikrah and Targum) as focus mode sets it (§4.7):
/// every block inset alike, so that nothing moves as the verse being read
/// changes, and that one on the verse highlight with a 3 px techelet rule at
/// its start, the right, as scripture runs (the preview is set right to
/// left).
class _VerseBlock extends StatelessWidget {
  const _VerseBlock({required this.highlighted, required this.child});

  final bool highlighted;
  final Widget child;

  static const _rule = 3.0;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: highlighted ? SeferColors.of(context).verseHighlight : null,
          // The rule keeps its width when it isn't drawn.
          border: BorderDirectional(
            start: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: _rule,
              style: highlighted ? BorderStyle.solid : BorderStyle.none,
            ),
          ),
        ),
        child: Padding(padding: const EdgeInsetsDirectional.fromSTEB(12 - _rule, 4, 12, 4), child: child),
      );
}
