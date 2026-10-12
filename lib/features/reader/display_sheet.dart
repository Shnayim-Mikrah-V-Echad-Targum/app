import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../services/optional_fonts.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/paper_group.dart';
import '../../ui/widgets/sefer_choice_chip.dart';
import '../../ui/widgets/theme_swatch_picker.dart';
import '../settings/app_settings.dart';
import '../settings/screens/display_settings_screen.dart';
import '../settings/widgets/settings_widgets.dart';
import 'scripture_text.dart' show ScriptureStyles;

/// Quick display controls available while reading. The sheet and its scrim
/// cover the whole screen, the navigation bar too when the page (the
/// haftarah, say) is shown within a tab. It opens on the lower part of the
/// screen, over a light scrim, so the verse it changes stays in view; it can
/// be drawn up for the rest.
///
/// The reader's, with [listenAlong], also offers Listen along, which reads
/// its steps one after another, and the full text's, with [sideBySide], its
/// parallel columns, wherever they would show: with the Targum or the
/// translation beside the verse, in a pane wide enough, at a measure and a
/// size they fit.
Future<void> showDisplaySheet(BuildContext context, {bool listenAlong = false, bool sideBySide = false}) {
  // Each font's chip is set in that font.
  OptionalFonts.ensureAll([for (final f in ScriptureFont.values) f.family]);
  return showAppSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    barrierColor: Colors.black12,
    builder: (_) => _DisplaySheet(listenAlong: listenAlong, sideBySide: sideBySide, page: context),
  );
}

void changeReadingScale(WidgetRef ref, double delta) {
  ref.read(settingsProvider.notifier).update(
        (s) => s.copyWith(readingScale: (s.readingScale + delta).clamp(kMinReadingScale, kMaxReadingScale)),
      );
}

class _DisplaySheet extends ConsumerWidget {
  const _DisplaySheet({required this.listenAlong, required this.sideBySide, required this.page});

  final bool listenAlong;
  final bool sideBySide;

  /// The page the sheet was opened over, whose pane the columns would fill:
  /// the sheet's own keeps clear of the window's side insets.
  final BuildContext page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final update = ref.read(settingsProvider.notifier).update;
    final theme = Theme.of(context);
    final inset = EdgeInsets.symmetric(horizontal: sheetPadding(context));
    // A setting's name, over its controls.
    Widget heading(String text) => Padding(
          padding: inset.copyWith(top: Space.xl, bottom: Space.sm),
          child: Semantics(header: true, headingLevel: 3, child: Text(text, style: theme.textTheme.titleMedium)),
        );
    SwitchRow toggle(String title, bool value, AppSettings Function(AppSettings, bool) set, {String? subtitle}) =>
        SwitchRow(title: title, subtitle: subtitle, value: value, onChanged: (v) => update((s) => set(s, v)));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.42,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: EdgeInsets.only(bottom: Space.xxl + MediaQuery.paddingOf(context).bottom),
        children: [
          SheetTitle(l.displaySettings),
          Padding(padding: inset, child: _SizeRow(scale: s.readingScale, onStep: (step) => changeReadingScale(ref, step))),
          heading(l.scriptureFontLabel),
          Padding(
            padding: inset,
            child: _FontChips(
              value: s.scriptureFont,
              names: {
                ScriptureFont.notoSerif: l.fontNotoSerif,
                ScriptureFont.taameyFrank: l.fontTaamey,
                ScriptureFont.ezra: l.fontEzra,
                ScriptureFont.notoSans: l.fontNotoSans,
              },
              onChanged: (font) => update((s) => s.copyWith(scriptureFont: font)),
            ),
          ),
          heading(l.themeLabel),
          Padding(
            padding: inset,
            child: ThemeSwatchPicker(
              compact: true,
              value: s.theme,
              onChanged: (v) => update((s) => s.copyWith(theme: v)),
            ),
          ),
          const Gap(Space.xxl),
          Padding(
            padding: inset,
            child: PaperGroup(
              children: [
                toggle(l.showNikud, s.showNikud, (s, v) => s.copyWith(showNikud: v)),
                toggle(l.showTeamim, s.showTeamim, (s, v) => s.copyWith(showTeamim: v)),
                toggle(l.showTranslation, s.showTranslation, (s, v) => s.copyWith(showTranslation: v),
                    subtitle: l.translationDisclaimer),
                toggle(l.showRashi, s.showRashi, (s, v) => s.copyWith(showRashi: v)),
                // Only while Rashi is shown.
                if (s.showsRashi) toggle(l.rashiScript, s.rashiScript, (s, v) => s.copyWith(rashiScript: v)),
                // Only where the columns would show: elsewhere it would
                // change nothing to be seen.
                if (sideBySide &&
                    page.mounted &&
                    (s.usesOnkelos || s.showTranslation) &&
                    ScriptureStyles(context, s).parallelFits(ScriptureStyles.paneWidth(page)))
                  toggle(l.sideBySide, s.parallelColumns, (s, v) => s.copyWith(parallelColumns: v),
                      subtitle: l.sideBySideDesc),
                toggle(l.focusMode, s.focusMode, (s, v) => s.copyWith(focusMode: v), subtitle: l.focusModeDesc),
                if (listenAlong)
                  toggle(l.listenAlong, s.listenAlong, (s, v) => s.copyWith(listenAlong: v), subtitle: l.listenAlongDesc),
                // In line with the rows' text, as on the paper of a page.
                ListTileTheme.merge(
                  contentPadding: const EdgeInsets.symmetric(horizontal: PaperGroup.plainInset),
                  child: Padding(
                    padding: const EdgeInsets.only(top: Space.sm, bottom: Space.xs),
                    child: LabeledSlider(
                      title: l.lineSpacing,
                      value: s.lineHeight,
                      min: kMinLineHeight,
                      max: kMaxLineHeight,
                      step: 0.1,
                      format: (v) => v.toStringAsFixed(1),
                      onChanged: (v) => update((s) => s.copyWith(lineHeight: v)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Gap(Space.md),
          Padding(
            padding: inset,
            child: PaperGroup(
              children: [
                PaperRow(
                  icon: Icons.tune,
                  title: l.settingsDisplay,
                  subtitle: l.settingsDisplayDesc,
                  onTap: () {
                    // Over the page that opened the sheet, which it goes back
                    // to, and over the navigation bar like the sheet: the
                    // Settings tab's own page would leave the reader or the
                    // haftarah.
                    final navigator = Navigator.of(context)..pop();
                    navigator.push(MaterialPageRoute<void>(builder: (_) => const DisplaySettingsScreen()));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The scripture fonts as chips, each "בְּרֵאשִׁית" in its font and named
/// for screen readers. They share the width evenly, four across where the
/// word fits so, else two, or one under another when the text is very large.
class _FontChips extends StatelessWidget {
  const _FontChips({required this.value, required this.names, required this.onChanged});

  final ScriptureFont value;
  final Map<ScriptureFont, String> names;
  final ValueChanged<ScriptureFont> onChanged;

  static const _sample = 'בְּרֵאשִׁית';

  /// The chip's own padding and its label's, at both sides (the theme's).
  static const _chrome = 32.0;

  /// The widest of the fonts' samples, and some room.
  static const _word = 76.0;

  /// The width of the mark under the chosen font's sample.
  static const _mark = 24.0;

  @override
  Widget build(BuildContext context) {
    final word = MediaQuery.textScalerOf(context).scale(_word);
    return LayoutBuilder(builder: (context, constraints) {
      double cell(int columns) => (constraints.maxWidth - (columns - 1) * Space.sm) / columns;
      final columns = [4, 2].firstWhere((c) => cell(c) - _chrome >= word, orElse: () => 1);
      final fonts = ScriptureFont.values;
      return Column(
        children: [
          for (var row = 0; row < fonts.length; row += columns) ...[
            if (row > 0) const Gap(Space.sm),
            Row(
              children: [
                for (var i = row; i < row + columns; i++) ...[
                  if (i > row) const SizedBox(width: Space.sm),
                  Expanded(
                    child: Center(
                      child: SeferChoiceChip(
                        label: SizedBox(
                          width: cell(columns) - _chrome,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // The word in that font, named for screen
                              // readers. One word, which the columns are
                              // chosen to fit: it never breaks.
                              Text(
                                _sample,
                                semanticsLabel: names[fonts[i]],
                                textAlign: TextAlign.center,
                                style: scriptureSampleStyle(fonts[i], 18),
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.fade,
                              ),
                              // The chosen one underlined, as its sample can't
                              // be bold: a mark that doesn't rest on colour.
                              const SizedBox(height: 2),
                              SizedBox(
                                width: _mark,
                                height: 2,
                                child: ColoredBox(
                                  color: value == fonts[i] ? Theme.of(context).colorScheme.primary : Colors.transparent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        selected: value == fonts[i],
                        onSelected: (_) => onChanged(fonts[i]),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      );
    });
  }
}

/// The reading size: its name, then smaller and larger buttons, 56 by 48,
/// either side of the size it is now.
class _SizeRow extends StatelessWidget {
  const _SizeRow({required this.scale, required this.onStep});

  final double scale;
  final ValueChanged<double> onStep;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final sefer = SeferColors.of(context);
    final scheme = theme.colorScheme;
    const corners = BorderRadius.all(Radius.circular(10));
    final style = ButtonStyle(
      fixedSize: const WidgetStatePropertyAll(Size(56, 48)),
      // Buttons are never round (§6.5), and keep the ring when focused.
      shape: WidgetStateProperty.resolveWith(
        (states) => showsFocusRing(states)
            ? FocusRingBorder(borderRadius: corners, ring: sefer.focus, gap: sefer.focusGap)
            : const RoundedRectangleBorder(borderRadius: corners),
      ),
      side: WidgetStateProperty.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.disabled) ? scheme.onSurface.withValues(alpha: 0.12) : scheme.outline,
          width: sefer.isHighContrast ? 2 : 1,
        ),
      ),
    );
    final percent = l.readingSizeValue((scale * 100).round());
    return Row(
      children: [
        Expanded(
          // Read with the size, which it says again as the buttons change it.
          child: Semantics(
            liveRegion: true,
            label: '${l.textSize}, $percent',
            excludeSemantics: true,
            child: Text(l.textSize, style: theme.textTheme.titleMedium),
          ),
        ),
        IconButton.outlined(
          style: style,
          tooltip: l.textSmaller,
          icon: const Icon(Icons.text_decrease),
          onPressed: scale > kMinReadingScale ? () => onStep(-0.1) : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.sm),
          child: ConstrainedBox(
            // As wide as the size takes, and never narrower, so that the
            // buttons hold still as it changes.
            constraints: const BoxConstraints(minWidth: 48),
            child: ExcludeSemantics(
              child: Text(
                percent,
                softWrap: false,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
          ),
        ),
        IconButton.outlined(
          style: style,
          tooltip: l.textLarger,
          icon: const Icon(Icons.text_increase),
          onPressed: scale < kMaxReadingScale ? () => onStep(0.1) : null,
        ),
      ],
    );
  }
}
