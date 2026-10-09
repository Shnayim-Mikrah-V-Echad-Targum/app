import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/text/hebrew_text.dart';
import '../../../services/feedback.dart';
import '../../../ui/l10n.dart';
import '../../../ui/widgets/common.dart';
import '../app_settings.dart';
import '../widgets/settings_widgets.dart';

/// Ready-made combinations of display settings.
enum DisplayPreset { largePrint, dyslexia, highContrast, lowVision, reset }

AppSettings applyPreset(AppSettings s, DisplayPreset p, {required bool darkPreferred}) {
  const d = AppSettings();
  switch (p) {
    case DisplayPreset.largePrint:
      return s.copyWith(readingScale: 1.8, lineHeight: 2.1, lineWidth: LineWidth.medium);
    case DisplayPreset.dyslexia:
      return s.copyWith(
        uiFont: UiFont.lexend,
        wordSpacing: 4,
        lineHeight: 2.2,
        showTeamim: false,
        focusMode: true,
        justify: false,
        lineWidth: LineWidth.narrow,
      );
    case DisplayPreset.highContrast:
      return s.copyWith(
        theme: darkPreferred ? AppThemeMode.highContrastDark : AppThemeMode.highContrastLight,
        boldText: true,
      );
    case DisplayPreset.lowVision:
      return s.copyWith(
        readingScale: 2.6,
        lineHeight: 2.0,
        theme: darkPreferred ? AppThemeMode.highContrastDark : AppThemeMode.highContrastLight,
        boldText: true,
        focusMode: true,
        lineWidth: LineWidth.wide,
      );
    case DisplayPreset.reset:
      return s.copyWith(
        theme: d.theme,
        readingScale: d.readingScale,
        lineHeight: d.lineHeight,
        wordSpacing: d.wordSpacing,
        letterSpacing: d.letterSpacing,
        showNikud: d.showNikud,
        showTeamim: d.showTeamim,
        justify: d.justify,
        lineWidth: d.lineWidth,
        scriptureFont: d.scriptureFont,
        uiFont: d.uiFont,
        boldText: d.boldText,
        focusMode: d.focusMode,
      );
  }
}

class AccessibilitySettingsScreen extends ConsumerWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    void update(AppSettings Function(AppSettings) f) => ref.read(settingsProvider.notifier).update(f);
    final presets = [
      (DisplayPreset.largePrint, l.presetLargePrint, Icons.format_size),
      (DisplayPreset.dyslexia, l.presetDyslexia, Icons.spellcheck),
      (DisplayPreset.highContrast, l.presetHighContrast, Icons.contrast),
      (DisplayPreset.lowVision, l.presetLowVision, Icons.visibility),
      (DisplayPreset.reset, l.presetReset, Icons.restart_alt),
    ];

    return SettingsPage(
      title: l.settingsAccessibility,
      children: [
        SectionHeader(l.presetsTitle, padding: const EdgeInsetsDirectional.only(start: 16, top: 16, bottom: 8)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (preset, label, icon) in presets)
                ActionChip(
                  avatar: Icon(icon),
                  label: Text(label),
                  onPressed: () {
                    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
                    update((s) => applyPreset(s, preset, darkPreferred: dark));
                    showStatus(context, l.presetApplied(label));
                  },
                ),
            ],
          ),
        ),
        const Gap(8),
        SwitchListTile(
          title: Text(l.reduceMotion),
          subtitle: Text(l.reduceMotionDesc),
          value: s.reduceMotion,
          onChanged: (v) => update((s) => s.copyWith(reduceMotion: v)),
        ),
        SwitchListTile(
          title: Text(l.haptics),
          value: s.haptics,
          onChanged: (v) => update((s) => s.copyWith(haptics: v)),
        ),
        ListTile(
          leading: const Icon(Icons.text_fields),
          title: Text(l.settingsDisplay),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/settings/display'),
        ),
        ChoiceGroup<ScreenReaderText>(
          title: l.screenReaderText,
          value: s.screenReaderText,
          choices: [
            Choice(ScreenReaderText.simplified, l.srSimplified),
            Choice(ScreenReaderText.consonants, l.srConsonants),
            Choice(ScreenReaderText.allMarks, l.srAllMarks),
          ],
          onChanged: (v) => update((s) => s.copyWith(screenReaderText: v)),
        ),
        ChoiceGroup<DivineNameSpeech>(
          title: l.divineNameLabel,
          value: s.divineName,
          choices: [Choice(DivineNameSpeech.adonai, l.divineAdonai), Choice(DivineNameSpeech.hashem, l.divineHashem)],
          onChanged: (v) => update((s) => s.copyWith(divineName: v)),
        ),
        LabeledSlider(
          title: l.speechRate,
          value: s.speechRate,
          min: 0.1,
          max: 1.0,
          step: 0.05,
          format: (v) => '${(v * 100).round()}%',
          onChanged: (v) => update((s) => s.copyWith(speechRate: v)),
        ),
        const Divider(height: 32),
        ListTile(
          leading: const Icon(Icons.accessibility),
          title: Text(l.accessibilityStatement),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/settings/about/legal/accessibility'),
        ),
        ListTile(
          leading: const Icon(Icons.feedback_outlined),
          title: Text(l.sendFeedback),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/settings/about'),
        ),
      ],
    );
  }
}
