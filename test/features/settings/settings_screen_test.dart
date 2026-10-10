import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/community/data/demo_forum_repository.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/settings/widgets/settings_widgets.dart';
import 'package:shnayim_mikra/services/notifications.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';
import 'package:shnayim_mikra/ui/widgets/paper_group.dart';

import '../../helpers.dart';

/// Settings, its pages of the practice and the reader's data
/// (docs/DESIGN_SYSTEM.md §9 Settings).
void main() {
  /// Monday of Noach 5787.
  final now = DateTime(2026, 10, 12, 10);

  Future<ProviderContainer> open(
    WidgetTester tester,
    String route, {
    AppSettings settings = const AppSettings(onboardingComplete: true),
    ProgressState? progress,
    DemoForumRepository? forums,
    NotificationService? notifications,
  }) async {
    tester.view.physicalSize = const Size(412, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(
      tester,
      settings: settings,
      now: now,
      progress: progress,
      forums: forums,
      notifications: notifications,
    );
    c.read(routerProvider).go(route);
    await tester.pumpAndSettle();
    return c;
  }

  Finder header(String text) => find.widgetWithText(GroupHeader, text);

  group('the top level', () {
    testWidgets('is three groups and About, with one row for the language and one About', (tester) async {
      await open(tester, '/settings');
      for (final name in ['Practice', 'Reading', 'You', 'About']) {
        expect(header(name), findsOneWidget, reason: name);
      }
      expect(find.byType(PaperGroup), findsNWidgets(4));
      // Practice, top to bottom.
      final practice = find.byType(PaperGroup).first;
      final rows = [
        for (final title in ['Reading & customs', 'Reminders', 'Show streak numbers', 'Pause streaks'])
          tester.getTopLeft(find.descendant(of: practice, matching: find.text(title))).dy,
      ];
      expect(rows, orderedEquals([...rows]..sort()));
      expect(find.text('How it works'), findsOneWidget);
      expect(find.text('About this app'), findsOneWidget);
      expect(find.text('Version, sources, privacy'), findsOneWidget);
      // The language is a row and its value, not a radio for each.
      expect(find.byType(RadioListTile<AppLanguage>), findsNothing);
      expect(find.widgetWithText(PaperRow, 'Language'), findsOneWidget);
      expect(find.text('Device'), findsOneWidget);
    });

    testWidgets('every leading icon is outlined', (tester) async {
      await open(tester, '/settings');
      final icons = [
        // Switch rows are paper rows too.
        for (final row in tester.widgetList<PaperRow>(find.byWidgetPredicate((w) => w is PaperRow))) ?row.icon,
      ];
      expect(icons, [
        Icons.menu_book_outlined,
        Icons.notifications_outlined,
        Icons.visibility_outlined,
        Icons.pause_circle_outline,
        Icons.text_fields_outlined,
        Icons.accessibility_new_outlined,
        Icons.person_outline,
        Icons.backup_outlined,
        Icons.translate_outlined,
        Icons.school_outlined,
        Icons.info_outline,
      ]);
    });

    testWidgets('the language is chosen in a sheet, which closes as one is chosen', (tester) async {
      final c = await open(tester, '/settings');
      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();
      expect(find.byType(SheetTitle), findsOneWidget);
      expect(find.byType(RadioListTile<AppLanguage>), findsNWidgets(3));
      expect(
        tester.widget<RadioGroup<AppLanguage>>(find.byType(RadioGroup<AppLanguage>)).groupValue,
        AppLanguage.system,
      );

      await tester.tap(find.text('עברית').last);
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).language, AppLanguage.hebrew);
      expect(find.byType(SheetTitle), findsNothing);
      // The row now says it, in the language chosen.
      expect(find.widgetWithText(PaperRow, 'שפה'), findsOneWidget);
      expect(find.descendant(of: find.widgetWithText(PaperRow, 'שפה'), matching: find.text('עברית')), findsOneWidget);
    });

    testWidgets('streak numbers are a switch the whole row toggles', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await open(tester, '/settings');
      final row = find.widgetWithText(SwitchRow, 'Show streak numbers');
      expect(tester.getSemantics(row), isSemantics(hasToggledState: true, isToggled: true));
      expect(tester.getSemantics(row), isSemantics(isButton: false));
      await tester.tap(find.text('Hide them if you\'d rather focus on the learning itself'));
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).showStreaks, isFalse);
      handle.dispose();
    });

    testWidgets('pausing streaks opens its dialog, and while paused the row says until when', (tester) async {
      final c = await open(tester, '/settings');
      expect(find.text('Illness, travel, mourning, a new baby: nothing resets while paused'), findsOneWidget);
      await tester.tap(find.text('Pause streaks'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
      await tester.pumpAndSettle();
      // A week, from today.
      final pause = c.read(progressProvider).pauses.single;
      expect((pause.start, pause.end), (LocalDate(2026, 10, 12), LocalDate(2026, 10, 18)));
      expect(
        find.descendant(
          of: find.widgetWithText(PaperRow, 'Pause streaks'),
          matching: find.text('Paused until Sunday, October 18. Nothing resets while paused.'),
        ),
        findsOneWidget,
      );
    });

    testWidgets("the account's row asks to sign in, or names who is signed in", (tester) async {
      await open(tester, '/settings');
      expect(find.text('Sign in to post, say thanks or report.'), findsOneWidget);

      final forums = DemoForumRepository();
      await forums.verifyCode('reader@example.org', '123456');
      await forums.updateDisplayName('Rivka');
      await open(tester, '/settings', forums: forums);
      expect(find.text('Signed in as \u2068Rivka\u2069'), findsOneWidget);
    });
  });

  group('Reminders', () {
    testWidgets('where they can be sent, a note with the candles over a sheet for each', (tester) async {
      await open(
        tester,
        '/settings/reminders',
        notifications: PhoneNotifications(),
        // The offer of a city put aside.
        settings: const AppSettings(onboardingComplete: true, dailyReminder: true, cityOfferAnswered: true),
      );
      final banner = find.byType(NoticeBanner);
      expect(banner, findsOneWidget);
      expect(find.descendant(of: banner, matching: find.text('Never on Shabbat or Yom Tov, and at most once a day.')),
          findsOneWidget);
      expect(tester.widget<NoticeBanner>(banner).leading, isNotNull);
      expect(find.byIcon(Icons.nights_stay_outlined), findsNothing);
      expect(find.byType(PaperGroup), findsNWidgets(3));
      expect(find.text('Daily reminder time'), findsOneWidget);
    });

    testWidgets('on the web, one notice that they need the installed app, over the reminders disabled',
        (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, '/settings/reminders');
      final banner = find.byType(NoticeBanner);
      expect(banner, findsOneWidget);
      expect(tester.widget<NoticeBanner>(banner).icon, Icons.install_mobile);
      expect(find.textContaining('Reminders need the installed app'), findsOneWidget);
      expect(find.text('Never on Shabbat or Yom Tov, and at most once a day.'), findsNothing);
      // Without an INSTALL_URL, nothing to get the app from.
      expect(find.text('Get the app'), findsNothing);

      final rows = find.byType(SwitchRow);
      expect(rows, findsNWidgets(3));
      for (final title in ['Daily reminder', 'Erev Shabbat reminder', 'After-Shabbat check-in']) {
        final row = find.widgetWithText(SwitchRow, title);
        expect(tester.getSemantics(row), isSemantics(hasEnabledState: true, isEnabled: false), reason: title);
      }
      await tester.tap(find.text('Daily reminder'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      handle.dispose();
    });
  });

  group('Your data', () {
    testWidgets('backs up in one group, and resets apart in error ink, with no icon', (tester) async {
      await open(tester, '/settings/data');
      expect(header('Backup & restore'), findsOneWidget);
      expect(find.byType(PaperGroup), findsNWidgets(2));
      final backup = find.byType(PaperGroup).first;
      for (final icon in [
        Icons.cloud_outlined,
        Icons.ios_share_outlined,
        Icons.download_outlined,
        Icons.content_paste_outlined,
      ]) {
        expect(find.descendant(of: backup, matching: find.byIcon(icon)), findsOneWidget, reason: '$icon');
      }

      final reset = find.byType(PaperGroup).last;
      final title = tester.widget<Text>(find.text('Reset all progress'));
      expect(title.style?.color, Theme.of(tester.element(reset)).colorScheme.error);
      expect(find.descendant(of: reset, matching: find.byType(Icon)), findsNothing);
      expect(find.text("This can't be undone."), findsOneWidget);
    });

    testWidgets('the reset is confirmed with the destructive button', (tester) async {
      final c = await open(tester, '/settings/data');
      await tester.tap(find.text('Reset all progress'));
      await tester.pumpAndSettle();
      final confirm = find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton));
      final scheme = Theme.of(tester.element(confirm)).colorScheme;
      final material = tester.widget<Material>(find.descendant(of: confirm, matching: find.byType(Material)).first);
      expect(material.color, scheme.error);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(c.read(progressProvider).weeks, isEmpty);
      expect(find.text('Progress reset.'), findsOneWidget);
    });
  });
}
