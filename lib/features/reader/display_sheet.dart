import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../ui/l10n.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/sefer_choice_chip.dart';
import '../settings/app_settings.dart';
import '../settings/screens/display_settings_screen.dart';
import '../settings/widgets/settings_widgets.dart';

/// Quick display controls available while reading. The sheet and its scrim
/// cover the whole screen, the navigation bar too when the page (the
/// haftarah, say) is shown within a tab.
Future<void> showDisplaySheet(BuildContext context) => showAppSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => const _DisplaySheet(),
    );

void changeReadingScale(WidgetRef ref, double delta) {
  ref.read(settingsProvider.notifier).update(
        (s) => s.copyWith(readingScale: (s.readingScale + delta).clamp(kMinReadingScale, kMaxReadingScale)),
      );
}

class _DisplaySheet extends ConsumerWidget {
  const _DisplaySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final update = ref.read(settingsProvider.notifier).update;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SheetTitle(l.displaySettings),
          ListTile(
            title: Text(l.textSize),
            subtitle: Text(l.readingSizeValue((s.readingScale * 100).round())),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.outlined(
                  tooltip: l.textSmaller,
                  icon: const Icon(Icons.text_decrease),
                  onPressed: s.readingScale > kMinReadingScale ? () => changeReadingScale(ref, -0.1) : null,
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: l.textLarger,
                  icon: const Icon(Icons.text_increase),
                  onPressed: s.readingScale < kMaxReadingScale ? () => changeReadingScale(ref, 0.1) : null,
                ),
              ],
            ),
          ),
          SwitchListTile(
            title: Text(l.showNikud),
            value: s.showNikud,
            onChanged: (v) => update((s) => s.copyWith(showNikud: v)),
          ),
          SwitchListTile(
            title: Text(l.showTeamim),
            value: s.showTeamim,
            onChanged: (v) => update((s) => s.copyWith(showTeamim: v)),
          ),
          SwitchListTile(
            title: Text(l.showTranslation),
            subtitle: Text(l.translationDisclaimer),
            value: s.showTranslation,
            onChanged: (v) => update((s) => s.copyWith(showTranslation: v)),
          ),
          SwitchListTile(
            title: Text(l.showRashi),
            value: s.showRashi,
            onChanged: (v) => update((s) => s.copyWith(showRashi: v)),
          ),
          SwitchListTile(
            title: Text(l.rashiScript),
            value: s.rashiScript,
            onChanged: (v) => update((s) => s.copyWith(rashiScript: v)),
          ),
          SwitchListTile(
            title: Text(l.focusMode),
            subtitle: Text(l.focusModeDesc),
            value: s.focusMode,
            onChanged: (v) => update((s) => s.copyWith(focusMode: v)),
          ),
          LabeledSlider(
            title: l.lineSpacing,
            value: s.lineHeight,
            min: kMinLineHeight,
            max: kMaxLineHeight,
            step: 0.1,
            format: (v) => v.toStringAsFixed(1),
            onChanged: (v) => update((s) => s.copyWith(lineHeight: v)),
          ),
          ListTile(
            title: Text(l.themeLabel),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (mode, label) in [
                    (AppThemeMode.system, l.themeSystem),
                    (AppThemeMode.light, l.themeLight),
                    (AppThemeMode.sepia, l.themeSepia),
                    (AppThemeMode.dark, l.themeDark),
                    (AppThemeMode.highContrastLight, l.themeHcLight),
                    (AppThemeMode.highContrastDark, l.themeHcDark),
                  ])
                    SeferChoiceChip(
                      label: Text(label),
                      selected: s.theme == mode,
                      onSelected: (_) => update((s) => s.copyWith(theme: mode)),
                    ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: Text(l.settingsDisplay),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Over the page that opened the sheet, which it goes back to,
              // and over the navigation bar like the sheet: the Settings
              // tab's own page would leave the reader or the haftarah.
              final navigator = Navigator.of(context)..pop();
              navigator.push(MaterialPageRoute<void>(builder: (_) => const DisplaySettingsScreen()));
            },
          ),
        ],
      ),
    );
  }
}
