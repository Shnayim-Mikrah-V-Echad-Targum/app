import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../ui/l10n.dart';
import '../../../ui/widgets/common.dart';
import '../../../ui/widgets/lang.dart';
import '../../../ui/widgets/paper_group.dart';
import '../../community/data/community_providers.dart';
import '../../progress/progress_screen.dart' show showPauseDialog;
import '../app_settings.dart';
import '../widgets/pause_setting.dart';
import '../widgets/settings_widgets.dart';

/// Settings (docs/DESIGN_SYSTEM.md §9): the practice, the reading on the
/// screen, the reader's own, and about the app, each a group of paper rows.
/// Every page opens over Settings and goes back to it.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final names = Names(context);
    final settings = ref.watch(settingsProvider);
    final today = ref.watch(todayProvider);
    // The pause covering today, if any, through any that run on from it: the
    // row says until when.
    final pause = ref.watch(progressProvider.select((p) => pauseCovering(p.pauses, today)));
    final user = ref.watch(communityUserProvider).value;
    final name = user == null ? null : ref.watch(myProfileProvider).value?.displayName ?? user.email;
    // Subtitles in full, however narrow the phone and long the language's.
    PaperRow page(IconData icon, String title, String? subtitle, String route) => PaperRow(
          icon: icon,
          title: title,
          subtitle: subtitle,
          subtitleMaxLines: null,
          onTap: () => context.push(route),
        );

    return SettingsPage(
      title: l.settingsTitle,
      paper: true,
      children: [
        GroupHeader(l.settingsGroupPractice),
        PaperGroup(
          children: [
            page(Icons.menu_book_outlined, l.settingsReading, l.settingsReadingDesc, '/settings/reading'),
            page(Icons.notifications_outlined, l.settingsReminders, l.settingsRemindersDesc, '/settings/reminders'),
            SwitchRow(
              icon: Icons.visibility_outlined,
              title: l.showStreaks,
              subtitle: l.showStreaksDesc,
              value: settings.showStreaks,
              onChanged: (v) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(showStreaks: v)),
            ),
            // A dialog, not a page: no chevron. While paused, it offers to
            // lengthen the pause or end it, rather than make another.
            PaperRow(
              icon: Icons.pause_circle_outline,
              title: l.pauseAction,
              subtitle: pause == null ? l.settingsPauseDesc : l.pausedBanner(names.dateLong(pause.end)),
              subtitleMaxLines: null,
              chevron: false,
              onTap: () => pause == null ? showPauseDialog(context, ref) : showPauseOptions(context, ref, pause),
            ),
          ],
        ),
        GroupHeader(l.settingsGroupReading),
        PaperGroup(
          children: [
            page(Icons.text_fields_outlined, l.settingsDisplay, l.settingsDisplayDesc, '/settings/display'),
            page(Icons.accessibility_new_outlined, l.settingsAccessibility, l.settingsAccessibilityDesc,
                '/settings/accessibility'),
          ],
        ),
        GroupHeader(l.settingsGroupYou),
        PaperGroup(
          children: [
            page(
              Icons.person_outline,
              l.settingsAccount,
              // A name in either script keeps its own direction in the sentence.
              user == null ? l.signInPrompt : (name == null ? null : l.signedInAs('\u2068$name\u2069')),
              '/settings/account',
            ),
            page(Icons.backup_outlined, l.settingsData, l.settingsDataDesc, '/settings/data'),
            PaperRow(
              icon: Icons.translate_outlined,
              title: l.settingsLanguage,
              value: switch (settings.language) {
                AppLanguage.system => l.languageDevice,
                AppLanguage.english => l.languageEnglish,
                AppLanguage.hebrew => l.languageHebrew,
              },
              // A language's name in itself, read in its own voice, as in the
              // sheet.
              valueLocale: switch (settings.language) {
                AppLanguage.system => null,
                AppLanguage.english => const Locale('en'),
                AppLanguage.hebrew => const Locale('he'),
              },
              onTap: () => _chooseLanguage(context, ref),
            ),
          ],
        ),
        GroupHeader(l.aboutTitle),
        PaperGroup(
          children: [
            page(Icons.school_outlined, l.guideTitle, null, '/guide'),
            page(Icons.info_outline, l.settingsAbout, l.settingsAboutDesc, '/settings/about'),
          ],
        ),
      ],
    );
  }

  /// The language, chosen in a sheet: the device's, English or Hebrew. The
  /// sheet closes as one is chosen, which the whole app then speaks.
  static Future<void> _chooseLanguage(BuildContext context, WidgetRef ref) => showAppSheet<void>(
        context: context,
        // Over the navigation bar too.
        useRootNavigator: true,
        builder: (context) {
          final l = context.l10n;
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SheetTitle(l.settingsLanguage),
                RadioGroup<AppLanguage>(
                  groupValue: ref.read(settingsProvider).language,
                  onChanged: (v) {
                    if (v == null) return;
                    Navigator.pop(context);
                    ref.read(settingsProvider.notifier).update((s) => s.copyWith(language: v));
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<AppLanguage>(value: AppLanguage.system, title: Text(l.languageSystem)),
                      // Each language's name in itself, read in its own voice.
                      RadioListTile<AppLanguage>(
                        value: AppLanguage.english,
                        title: Lang(const Locale('en'), child: Text(l.languageEnglish)),
                      ),
                      RadioListTile<AppLanguage>(
                        value: AppLanguage.hebrew,
                        title: Lang(const Locale('he'), child: Text(l.languageHebrew)),
                      ),
                    ],
                  ),
                ),
                const Gap(8),
              ],
            ),
          );
        },
      );
}
