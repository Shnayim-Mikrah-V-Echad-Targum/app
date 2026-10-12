import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/community/data/demo_forum_repository.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/settings/widgets/settings_widgets.dart';
import 'package:shnayim_mikra/services/notifications.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';
import 'package:shnayim_mikra/ui/widgets/lang.dart';
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
      await tester.tap(find.text('Hide them if you’d rather focus on the learning itself'));
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
          matching: findWords('Paused until Sunday, October 18. Nothing resets while paused.'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('while paused, the row offers to lengthen the pause, and says the later day', (tester) async {
      final c = await open(tester, '/settings');
      await tester.tap(find.text('Pause streaks'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
      await tester.pumpAndSettle();

      // Again: lengthened by a week from the day after, not a second pause
      // laid over the first.
      await tester.tap(find.text('Pause streaks'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(AlertDialog), matching: findWords('Paused until Sunday, October 18')),
          findsOneWidget);
      expect(find.text('Lengthen by'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('7 days')));
      await tester.tap(find.widgetWithText(FilledButton, 'Lengthen'));
      await tester.pumpAndSettle();
      final pauses = c.read(progressProvider).pauses;
      expect([for (final p in pauses) (p.start, p.end)], [
        (LocalDate(2026, 10, 12), LocalDate(2026, 10, 18)),
        (LocalDate(2026, 10, 19), LocalDate(2026, 10, 25)),
      ]);
      expect(find.text('Paused until Sunday, October\u00A025.'), findsOneWidget, reason: 'the status message');
      expect(
        find.descendant(
          of: find.widgetWithText(PaperRow, 'Pause streaks'),
          matching: findWords('Paused until Sunday, October 25. Nothing resets while paused.'),
        ),
        findsOneWidget,
      );
      // Today's banner says the same.
      c.read(routerProvider).go('/today');
      await tester.pumpAndSettle();
      expect(findWords('Paused until Sunday, October 25. Nothing resets while paused.'), findsOneWidget);
    });

    testWidgets('the row says the later end of pauses laid one over another', (tester) async {
      await open(
        tester,
        '/settings',
        progress: ProgressState(pauses: [
          Pause(LocalDate(2026, 10, 12), LocalDate(2026, 10, 18), id: 'a'),
          Pause(LocalDate(2026, 10, 12), LocalDate(2026, 10, 25), id: 'b'),
        ]),
      );
      expect(findWords('Paused until Sunday, October 25. Nothing resets while paused.'), findsOneWidget);
    });

    testWidgets('while paused, the row resumes, as Today does', (tester) async {
      final c = await open(
        tester,
        '/settings',
        progress: ProgressState(pauses: [Pause(LocalDate(2026, 10, 10), LocalDate(2026, 10, 18), id: 'a')]),
      );
      await tester.tap(find.text('Pause streaks'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Resume'));
      await tester.pumpAndSettle();
      expect(c.read(progressProvider).pauses.single.end, LocalDate(2026, 10, 11));
      expect(c.read(settingsProvider).pauseEndSeen, LocalDate(2026, 10, 11));
      expect(find.text('Welcome back! Your place is saved.'), findsOneWidget);
      expect(find.text('Illness, travel, mourning, a new baby: nothing resets while paused'), findsOneWidget);
    });

    testWidgets('a pause already 30 days long can only be resumed', (tester) async {
      await open(
        tester,
        '/settings',
        progress: ProgressState(pauses: [Pause(LocalDate(2026, 10, 1), LocalDate(2026, 10, 30), id: 'a')]),
      );
      await tester.tap(find.text('Pause streaks'));
      await tester.pumpAndSettle();
      expect(find.text('A pause lasts 30 days at most. You can resume now.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Lengthen'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Resume'), findsOneWidget);
    });

    for (final hebrew in [false, true]) {
      testWidgets('no subtitle is cut short on a 320 dp phone${hebrew ? ', in Hebrew' : ''}', (tester) async {
        tester.view.physicalSize = const Size(320, 2000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final c = await pumpApp(
          tester,
          settings: AppSettings(onboardingComplete: true, language: hebrew ? AppLanguage.hebrew : AppLanguage.english),
          now: now,
          progress: ProgressState(pauses: [Pause(LocalDate(2026, 10, 12), LocalDate(2026, 10, 30), id: 'a')]),
        );
        c.read(routerProvider).go('/settings');
        await tester.pumpAndSettle();
        final rows = find.byWidgetPredicate((w) => w is PaperRow && w.subtitle != null);
        expect(rows, findsWidgets);
        for (final row in tester.widgetList<PaperRow>(rows)) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: find.byWidget(row), matching: find.text(row.subtitle!)).first,
          );
          expect(paragraph.didExceedMaxLines, isFalse, reason: row.subtitle);
          expect(paragraph.maxLines, isNull, reason: row.subtitle);
        }
      });
    }

    testWidgets("the language's name is read in its own voice", (tester) async {
      for (final (language, name, code) in [(AppLanguage.english, 'English', 'en'), (AppLanguage.hebrew, 'עברית', 'he')]) {
        await open(tester, '/settings', settings: AppSettings(onboardingComplete: true, language: language));
        final row = find.byWidgetPredicate((w) => w is PaperRow && w.value == name);
        expect(
          find.descendant(
            of: row,
            matching: find.byWidgetPredicate((w) => w is Lang && w.locale == Locale(code)),
          ),
          findsOneWidget,
          reason: name,
        );
      }
      await open(tester, '/settings');
      expect(find.byWidgetPredicate((w) => w is Lang), findsNothing, reason: "the device's language is no name");
    });

    testWidgets("the account's row asks to sign in, or names who is signed in", (tester) async {
      await open(tester, '/settings');
      // A subtitle, without a full stop, as every other row's is.
      expect(find.text('Sign in to post, say todah or report'), findsOneWidget);

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
        // Its words dimmed as a disabled control's.
        final color = tester.widget<Text>(find.text(title)).style!.color!;
        expect(color.a, closeTo(0.38, 0.01), reason: title);
      }
      await tester.tap(find.text('Daily reminder'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      handle.dispose();
    });

    testWidgets('on the web, reminders a backup brought from a phone show off, as none can come', (tester) async {
      await open(
        tester,
        '/settings/reminders',
        settings: const AppSettings(onboardingComplete: true, dailyReminder: true, fridayReminder: true),
      );
      expect([for (final s in tester.widgetList<Switch>(find.byType(Switch))) s.value], everyElement(isFalse));
      expect(find.text('Daily reminder time'), findsNothing);
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

      // Every hairline of the backup group starts where its rows' text does,
      // Export's too, whose row is built in a context of its own.
      final insets = [
        for (final paint in tester.widgetList<CustomPaint>(find.descendant(of: backup, matching: find.byType(CustomPaint))))
          if (paint.painter?.runtimeType.toString() == '_RowRule') (paint.painter! as dynamic).inset as double,
      ];
      expect(insets, [PaperGroup.iconInset, PaperGroup.iconInset, PaperGroup.iconInset]);

      final reset = find.byType(PaperGroup).last;
      final title = tester.widget<Text>(find.text('Reset all progress'));
      expect(title.style?.color, Theme.of(tester.element(reset)).colorScheme.error);
      expect(find.descendant(of: reset, matching: find.byType(Icon)), findsNothing);
      expect(find.text('This can’t be undone.'), findsOneWidget);
    });

    for (final hebrew in [false, true]) {
      testWidgets('no description is cut short on a 320 dp phone${hebrew ? ', in Hebrew' : ''}', (tester) async {
        tester.view.physicalSize = const Size(320, 2000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final c = await pumpApp(
          tester,
          settings: AppSettings(onboardingComplete: true, language: hebrew ? AppLanguage.hebrew : AppLanguage.english),
          now: now,
        );
        c.read(routerProvider).go('/settings/data');
        await tester.pumpAndSettle();
        final rows = find.byWidgetPredicate((w) => w is PaperRow && w.subtitle != null);
        // Cloud backup, Export, Import, Paste and Reset.
        expect(rows, findsNWidgets(5));
        for (final row in tester.widgetList<PaperRow>(rows)) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: find.byWidget(row), matching: find.text(row.subtitle!)).first,
          );
          expect(paragraph.didExceedMaxLines, isFalse, reason: row.subtitle);
        }
      });
    }

    testWidgets('the reset is confirmed with the destructive button, and Cancel keeps everything', (tester) async {
      final progress = ProgressState(
        weeks: {'5787:1': WeekProgress(weekId: '5787:1').withAll(LocalDate(2026, 10, 9))},
        pauses: [Pause(LocalDate(2026, 9, 1), LocalDate(2026, 9, 3), id: 'a')],
      );
      final c = await open(tester, '/settings/data', progress: progress);
      bool kept() => c.read(progressProvider).week('5787:1').isComplete && c.read(progressProvider).pauses.isNotEmpty;
      expect(kept(), isTrue);

      await tester.tap(find.text('Reset all progress'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(kept(), isTrue);

      await tester.tap(find.text('Reset all progress'));
      await tester.pumpAndSettle();
      final confirm = find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton));
      final scheme = Theme.of(tester.element(confirm)).colorScheme;
      final material = tester.widget<Material>(find.descendant(of: confirm, matching: find.byType(Material)).first);
      expect(material.color, scheme.error);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(c.read(progressProvider).weeks.values.where((w) => w.completedUnits > 0), isEmpty);
      expect(c.read(progressProvider).pauses.where((p) => !p.deleted), isEmpty);
      expect(find.text('Progress reset.'), findsOneWidget);
    });
  });
}
