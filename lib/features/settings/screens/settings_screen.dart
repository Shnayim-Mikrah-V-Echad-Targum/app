import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../ui/l10n.dart';
import '../../../ui/widgets/common.dart';
import '../app_settings.dart';
import '../widgets/settings_widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider);
    Widget item(IconData icon, String title, String? subtitle, String route) => ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(route),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: PageBody(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          item(Icons.menu_book_outlined, l.settingsReading, l.settingsReadingDesc, '/settings/reading'),
          item(Icons.text_fields, l.settingsDisplay, l.settingsDisplayDesc, '/settings/display'),
          item(Icons.accessibility_new, l.settingsAccessibility, l.settingsAccessibilityDesc, '/settings/accessibility'),
          item(Icons.notifications_outlined, l.settingsReminders, l.settingsRemindersDesc, '/settings/reminders'),
          item(Icons.person_outline, l.settingsAccount, null, '/community/account'),
          item(Icons.save_alt, l.settingsData, l.settingsDataDesc, '/settings/data'),
          SwitchListTile(
            secondary: const Icon(Icons.auto_graph),
            title: Text(l.showStreaks),
            subtitle: Text(l.showStreaksDesc),
            value: settings.showStreaks,
            onChanged: (v) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(showStreaks: v)),
          ),
          ChoiceGroup<AppLanguage>(
            title: l.settingsLanguage,
            value: settings.language,
            choices: [
              Choice(AppLanguage.system, l.languageSystem),
              Choice(AppLanguage.english, l.languageEnglish),
              Choice(AppLanguage.hebrew, l.languageHebrew),
            ],
            onChanged: (v) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(language: v)),
          ),
          const Divider(height: 32),
          item(Icons.help_outline, l.guideTitle, null, '/guide'),
          item(Icons.info_outline, l.settingsAbout, null, '/settings/about'),
        ],
      ),
    );
  }
}
