import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/models/verse_ref.dart';
import '../../../data/text_repository.dart';
import '../../../ui/l10n.dart';
import '../../../ui/widgets/common.dart';
import '../../reader/reader_screen.dart';
import '../../reader/scripture_text.dart';
import '../app_settings.dart';
import '../widgets/settings_widgets.dart';

class DisplaySettingsScreen extends ConsumerWidget {
  const DisplaySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    void update(AppSettings Function(AppSettings) f) => ref.read(settingsProvider.notifier).update(f);

    return SettingsPage(
      title: l.settingsDisplay,
      children: [
        const _Preview(),
        ChoiceGroup<AppThemeMode>(
          title: l.themeLabel,
          value: s.theme,
          choices: [
            Choice(AppThemeMode.system, l.themeSystem),
            Choice(AppThemeMode.light, l.themeLight),
            Choice(AppThemeMode.sepia, l.themeSepia),
            Choice(AppThemeMode.dark, l.themeDark),
            Choice(AppThemeMode.highContrastLight, l.themeHcLight),
            Choice(AppThemeMode.highContrastDark, l.themeHcDark),
          ],
          onChanged: (v) => update((s) => s.copyWith(theme: v)),
        ),
        LabeledSlider(
          title: l.readingSize,
          value: s.readingScale,
          min: kMinReadingScale,
          max: kMaxReadingScale,
          step: 0.1,
          format: (v) => l.readingSizeValue((v * 100).round()),
          onChanged: (v) => update((s) => s.copyWith(readingScale: v)),
        ),
        LabeledSlider(
          title: l.lineSpacing,
          value: s.lineHeight,
          min: 1.5,
          max: 3.0,
          step: 0.1,
          format: (v) => v.toStringAsFixed(1),
          onChanged: (v) => update((s) => s.copyWith(lineHeight: v)),
        ),
        LabeledSlider(
          title: l.wordSpacing,
          value: s.wordSpacing,
          min: 0,
          max: 16,
          step: 1,
          format: (v) => v.toStringAsFixed(0),
          onChanged: (v) => update((s) => s.copyWith(wordSpacing: v)),
        ),
        LabeledSlider(
          title: l.letterSpacing,
          value: s.letterSpacing,
          min: 0,
          max: 4,
          step: 0.2,
          format: (v) => v.toStringAsFixed(1),
          onChanged: (v) => update((s) => s.copyWith(letterSpacing: v)),
        ),
        SwitchListTile(title: Text(l.showNikud), value: s.showNikud, onChanged: (v) => update((s) => s.copyWith(showNikud: v))),
        SwitchListTile(title: Text(l.showTeamim), value: s.showTeamim, onChanged: (v) => update((s) => s.copyWith(showTeamim: v))),
        SwitchListTile(title: Text(l.showKetiv), value: s.showKetiv, onChanged: (v) => update((s) => s.copyWith(showKetiv: v))),
        SwitchListTile(
          title: Text(l.showVerseNumbers),
          value: s.showVerseNumbers,
          onChanged: (v) => update((s) => s.copyWith(showVerseNumbers: v)),
        ),
        SwitchListTile(
          title: Text(l.showTranslation),
          subtitle: Text(l.translationDisclaimer),
          value: s.showTranslation,
          onChanged: (v) => update((s) => s.copyWith(showTranslation: v)),
        ),
        SwitchListTile(title: Text(l.showRashi), value: s.showRashi, onChanged: (v) => update((s) => s.copyWith(showRashi: v))),
        SwitchListTile(title: Text(l.justifyText), value: s.justify, onChanged: (v) => update((s) => s.copyWith(justify: v))),
        SwitchListTile(
          title: Text(l.focusMode),
          subtitle: Text(l.focusModeDesc),
          value: s.focusMode,
          onChanged: (v) => update((s) => s.copyWith(focusMode: v)),
        ),
        SwitchListTile(title: Text(l.boldText), value: s.boldText, onChanged: (v) => update((s) => s.copyWith(boldText: v))),
        SwitchListTile(
          title: Text(l.keepScreenOn),
          value: s.keepScreenOn,
          onChanged: (v) => update((s) => s.copyWith(keepScreenOn: v)),
        ),
        ChoiceGroup<LineWidth>(
          title: l.lineWidthLabel,
          value: s.lineWidth,
          choices: [
            Choice(LineWidth.narrow, l.lineNarrow),
            Choice(LineWidth.medium, l.lineMedium),
            Choice(LineWidth.wide, l.lineWide),
          ],
          onChanged: (v) => update((s) => s.copyWith(lineWidth: v)),
        ),
        ChoiceGroup<ScriptureFont>(
          title: l.scriptureFontLabel,
          value: s.scriptureFont,
          choices: [
            Choice(ScriptureFont.notoSerif, l.fontNotoSerif),
            Choice(ScriptureFont.taameyFrank, l.fontTaamey),
            Choice(ScriptureFont.ezra, l.fontEzra),
            Choice(ScriptureFont.notoSans, l.fontNotoSans),
          ],
          onChanged: (v) => update((s) => s.copyWith(scriptureFont: v)),
        ),
        ChoiceGroup<UiFont>(
          title: l.uiFontLabel,
          value: s.uiFont,
          choices: [
            Choice(UiFont.standard, l.uiFontStandard),
            Choice(UiFont.atkinson, l.uiFontAtkinson),
            Choice(UiFont.lexend, l.uiFontLexend),
            Choice(UiFont.openDyslexic, l.uiFontOpenDyslexic),
            // The web can't use the device's fonts. Still list the option if
            // it was imported from another device, so the group shows a value.
            if (!kIsWeb || s.uiFont == UiFont.system) Choice(UiFont.system, l.uiFontSystem),
          ],
          onChanged: (v) => update((s) => s.copyWith(uiFont: v)),
        ),
      ],
    );
  }
}

/// Live preview of the scripture settings, using Genesis 1:1–2.
class _Preview extends ConsumerWidget {
  const _Preview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final mikra = ref.watch(bookTextProvider((TextLayer.mikra, 'Genesis')));
    final onkelos = ref.watch(bookTextProvider((TextLayer.onkelos, 'Genesis')));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: InfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.previewLabel, style: Theme.of(context).textTheme.labelLarge),
            const Gap(8),
            if (mikra.value != null) ...[
              ScriptureVerse(verse: mikra.value!.verse(const VerseRef(1, 1)), kind: ScriptureKind.mikra, settings: s),
              ScriptureVerse(verse: mikra.value!.verse(const VerseRef(1, 2)), kind: ScriptureKind.mikra, settings: s),
            ],
            if (onkelos.value != null)
              ScriptureVerse(verse: onkelos.value!.verse(const VerseRef(1, 1)), kind: ScriptureKind.targum, settings: s),
          ],
        ),
      ),
    );
  }
}
