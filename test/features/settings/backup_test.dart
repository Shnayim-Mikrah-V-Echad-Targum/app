import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/community/data/demo_forum_repository.dart';
import 'package:shnayim_mikra/features/community/data/forum_repository.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_merge.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/settings/backup.dart';
import 'package:shnayim_mikra/services/backup_files.dart';
import 'package:shnayim_mikra/services/notifications.dart';

import '../../fake_backup_files.dart';
import '../../helpers.dart';

final _simchatTorah = LocalDate(2026, 10, 4);
final _bereshitFriday = LocalDate(2026, 10, 9);

/// The Monday of Noach, the day this device was set up.
final _monday = LocalDate(2026, 10, 12);

/// A community that keeps backups.
class _Cloud extends DemoForumRepository {
  @override
  bool get isDemo => false;
}

/// Reminders that can be scheduled, where the OS [allows] them or not.
class _AskingNotifications extends PhoneNotifications {
  _AskingNotifications({required this.allows});

  final bool allows;
  var asked = 0;

  @override
  Future<bool> requestPermission() async {
    asked++;
    return allows;
  }
}

void main() {
  // A clock that only moves when a test moves it.
  final wallClock = ProgressClock.nowMs;
  late int now;
  setUp(() {
    now = DateTime.utc(2026, 10, 11, 9).millisecondsSinceEpoch;
    ProgressClock.nowMs = () => now;
  });
  tearDown(() => ProgressClock.nowMs = wallClock);
  void later() => now += const Duration(hours: 1).inMilliseconds;

  test('a backup is named for the day it is made', () {
    expect(backupFileName(DateTime(2026, 10, 9, 23, 59)), 'shnayim-mikra-backup-2026-10-09.json');
    expect(backupFileName(DateTime(2027, 1, 31)), 'shnayim-mikra-backup-2027-01-31.json');
  });

  group('parseBackup', () {
    test('says what a backup holds', () {
      final progress = ProgressState(
        weeks: {
          '5787:1': WeekProgress(weekId: '5787:1').withAll(_bereshitFriday),
          // The haftarah alone counts as logged.
          '5787:2': WeekProgress(weekId: '5787:2').withHaftarah(_monday),
          // A reading under way, and one marked then cleared, don't.
          '5787:3': WeekProgress(weekId: '5787:3').withPosition(0, const [3, 0, 0]),
          '5787:4': WeekProgress(weekId: '5787:4').withAliyah(1, _monday).cleared(),
        },
        pauses: [
          Pause(_monday, _monday.addDays(3), id: 'a'),
          Pause(_monday.addDays(10), _monday.addDays(12), id: 'b'),
          Pause(_monday.addDays(20), _monday.addDays(22), id: 'c', deleted: true),
        ],
      );
      final made = DateTime.utc(2026, 10, 12, 18, 30);
      final settings = AppSettings(onboardingComplete: true, joinDate: _simchatTorah);
      final backup = parseBackup(encodeBackup(progress, settings, now: made))!;

      expect(backup.weeksLogged, 2);
      expect(backup.pauses, 2);
      expect(backup.joinDate, _simchatTorah);
      expect(backup.exportedAt, made.toLocal());
      expect(backup.exportedAt!.isUtc, isFalse);
      expect(backup.progress, progress);
      expect(backup.settings!.toJson(), settings.toJson());
    });

    test('counts a backup without a join date from its earliest reading', () {
      final progress = ProgressState(weeks: {
        '5787:2': WeekProgress(weekId: '5787:2').withAliyah(0, _monday),
        '5787:1': WeekProgress(weekId: '5787:1').withAliyah(6, _bereshitFriday),
      });
      final raw = jsonEncode({'app': 'shnayim_mikra', 'progress': progress.toJson()});
      final backup = parseBackup(raw)!;
      expect(backup.joinDate, _bereshitFriday);
      expect(backup.settings, isNull);
      expect(backup.exportedAt, isNull);
    });

    test("keeps apart what the version that made it couldn't read", () {
      const unknownWeeks = {
        '5787:9': {'u': 'done'},
      };
      const unknownPauses = [
        {'start': '2026-10-11'},
      ];
      final progress = ProgressState(
        weeks: {'5787:1': WeekProgress(weekId: '5787:1').withAliyah(3, _monday)},
        unknownWeeks: unknownWeeks,
        unknownPauses: unknownPauses,
      );
      final backup = parseBackup(encodeBackup(progress, const AppSettings(), now: DateTime.utc(2026, 10, 12)))!;
      expect(backup.progress, progress.readable);
      expect(backup.unknownWeeks, unknownWeeks);
      expect(backup.unknownPauses, unknownPauses);
    });

    final good = {'app': 'shnayim_mikra', 'progress': const ProgressState().toJson()};
    for (final (name, raw) in [
      ('text that is not JSON', 'Shnayim Mikra'),
      ('JSON that is not an object', '[1, 2]'),
      ("another app's file", jsonEncode({...good, 'app': 'other'})),
      ('a file without progress', jsonEncode({'app': 'shnayim_mikra'})),
      (
        'progress this version cannot read exactly',
        jsonEncode({
          ...good,
          'progress': {
            'weeks': {
              '5787:2': {'u': 'done'},
            },
          },
        }),
      ),
    ]) {
      test('rejects $name', () => expect(parseBackup(raw), isNull));
    }

    test('reads a backup whose date is garbled, without the date', () {
      final backup = parseBackup(jsonEncode({...good, 'exportedAt': 'yesterday'}));
      expect(backup, isNotNull);
      expect(backup!.exportedAt, isNull);
    });
  });

  group('mergeBackup', () {
    test('keeps what either side holds', () {
      final backup = ProgressState(
        weeks: {'5787:1': WeekProgress(weekId: '5787:1').withAll(_bereshitFriday)},
        pauses: [Pause(_monday.addDays(7), _monday.addDays(9), id: 'p', updatedAt: now)],
      );
      later();
      final here = ProgressState(weeks: {'5787:2': WeekProgress(weekId: '5787:2').withAliyah(0, _monday)});
      final merged = mergeBackup(here, backup);
      expect(merged.week('5787:1').isComplete, isTrue);
      expect(merged.week('5787:2').isAliyahDone(0), isTrue);
      expect(merged.pauses.map((p) => p.id), ['p']);
    });

    test('keeps a change made here since the backup', () {
      final backup = ProgressState(weeks: {'5787:1': WeekProgress(weekId: '5787:1').withAll(_bereshitFriday)});
      later();
      // Shevi'i was marked as not read here, and Rishon read again on Monday.
      final week = backup
          .week('5787:1')
          .withAliyah(6, null)
          .withUnit(0, ReadingPass.mikra1, null)
          .withUnit(0, ReadingPass.mikra1, _monday);
      final here = ProgressState(weeks: {'5787:1': week});
      final merged = mergeBackup(here, backup).week('5787:1');
      expect(merged.isAliyahDone(6), isFalse);
      expect(merged.units[0][ReadingPass.mikra1.index], _monday);
      expect(merged.units[1][ReadingPass.mikra1.index], _bereshitFriday);
    });

    test("doesn't let a reset here erase what the backup brings back", () {
      final backup = ProgressState(weeks: {'5787:1': WeekProgress(weekId: '5787:1').withAll(_bereshitFriday)});
      later();
      // Reset everywhere since, and Rishon of Noach read.
      final reset = ProgressState(resetAt: ProgressClock.after(backup.latestStamp));
      later();
      final here = ProgressClock.above(
        reset.resetAt,
        () => reset.copyWith(weeks: {'5787:2': WeekProgress(weekId: '5787:2').withAliyah(0, _monday)}),
      );
      final merged = mergeBackup(here, backup);
      expect(merged.week('5787:1').isComplete, isTrue);
      expect(merged.week('5787:2').isAliyahDone(0), isTrue);
    });

    test("doesn't let a reset in the backup erase what is here", () {
      final here = ProgressState(weeks: {'5787:1': WeekProgress(weekId: '5787:1').withAll(_bereshitFriday)});
      later();
      final backup = ProgressState(
        weeks: {'5787:2': WeekProgress(weekId: '5787:2').withAliyah(0, _monday)},
        resetAt: ProgressClock.after(here.latestStamp),
      );
      final merged = mergeBackup(here, backup);
      expect(merged.week('5787:1').isComplete, isTrue);
      expect(merged.week('5787:2').isAliyahDone(0), isTrue);
    });
  });

  group('Your data', () {
    /// What a backup made on the Sunday of Noach, on another device, holds:
    /// Bereshit, read on its Friday, a pause to come, and settings with all
    /// three reminders on.
    ProgressState backedUp() => ProgressState(
          weeks: {'5787:1': WeekProgress(weekId: '5787:1').withAll(_bereshitFriday)},
          pauses: [Pause(_monday.addDays(14), _monday.addDays(16), id: 'trip', updatedAt: now)],
        );
    final savedSettings = AppSettings(
      onboardingComplete: true,
      joinDate: _simchatTorah,
      plan: ReadingPlanType.erevShabbat,
      dailyReminder: true,
      fridayReminder: true,
      checkInReminder: true,
      notificationPromptShown: true,
    );

    /// This device, set up on the Monday of Noach.
    final setUpHere = AppSettings(onboardingComplete: true, joinDate: _monday);

    /// Your data, on this device, with Rishon of Noach read since the backup
    /// was made (or [progress]), where the reader would choose [file] (by
    /// default, the backup) or [files] decide.
    Future<(ProviderContainer, FakeBackupFiles)> open(
      WidgetTester tester, {
      String? file,
      FakeBackupFiles? files,
      ProgressState Function()? progress,
      NotificationService? notifications,
      double textScale = 1,
      AppSettings? settings,
      ForumRepository? forums,
    }) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final fake = files ??
          FakeBackupFiles(
            file: file ?? encodeBackup(backedUp(), savedSettings, now: DateTime.utc(2026, 10, 11, 12)),
          );
      later();
      final c = await pumpApp(
        tester,
        settings: settings ?? setUpHere,
        progress: progress?.call() ??
            ProgressState(weeks: {'5787:2': WeekProgress(weekId: '5787:2').withAliyah(0, _monday)}),
        now: DateTime(2026, 10, 12, 10),
        notifications: notifications,
        forums: forums,
        overrides: [backupFilesProvider.overrideWithValue(fake)],
      );
      c.read(routerProvider).go('/settings/data');
      await tester.pumpAndSettle();
      return (c, fake);
    }

    Future<void> chooseFile(WidgetTester tester) async {
      await tester.tap(find.text('Import progress'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows what a backup file holds, and asks whether to merge it', (tester) async {
      await open(tester);
      await chooseFile(tester);
      expect(find.text('Backup from October 11, 2026: 1\u00a0week logged, 1\u00a0pause.'), findsOneWidget);
      expect(
        find.text('Merge this backup with the progress on this device? Merging keeps everything from both.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Merge'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Replace instead'), findsOneWidget);
      expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value, isFalse);
    });

    testWidgets('merging keeps what was read here, and adds the backup', (tester) async {
      final (c, _) = await open(tester);
      await chooseFile(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Merge'));
      await tester.pumpAndSettle();

      expect(find.text('Progress imported.'), findsOneWidget);
      final progress = c.read(progressProvider);
      expect(progress.week('5787:2').isAliyahDone(0), isTrue, reason: 'read here since the backup');
      expect(progress.week('5787:1').isComplete, isTrue);
      expect(progress.pauses.map((p) => p.id), ['trip']);
      final settings = c.read(settingsProvider);
      expect(settings.joinDate, _simchatTorah, reason: "so that the backup's history counts");
      expect(settings.plan, setUpHere.plan, reason: 'settings stay unless asked for');
      expect(settings.dailyReminder, isFalse);
      expect(c.read(streakSummaryProvider).parshaStreak, 1);
    });

    testWidgets('replacing asks first, saying what it erases', (tester) async {
      final (c, _) = await open(tester);
      final before = c.read(progressProvider);
      await chooseFile(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Replace instead'));
      await tester.pumpAndSettle();
      expect(find.text('Replace the progress here?'), findsOneWidget);
      expect(
        find.text('This erases the reading history and streaks on this device, and keeps only what the backup holds. '
            "It can't be undone."),
        findsOneWidget,
      );
      final replace = find.widgetWithText(FilledButton, 'Replace');
      expect(
        tester.widget<FilledButton>(replace).style?.backgroundColor?.resolve({}),
        Theme.of(tester.element(replace)).colorScheme.error,
        reason: 'the destructive button of a confirm dialog',
      );

      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(find.text('Replace the progress here?'), findsNothing);
      expect(find.text('Replace instead'), findsOneWidget, reason: 'back to the choice');
      expect(c.read(progressProvider), before);
    });

    testWidgets('replacing with backup on says that it erases the cloud backup too', (tester) async {
      final cloud = _Cloud();
      await cloud.verifyCode('reader@example.org', '123456');
      await open(tester, settings: setUpHere.copyWith(cloudSync: true), forums: cloud);
      await chooseFile(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Replace instead'));
      await tester.pumpAndSettle();
      expect(find.textContaining('on this device, in your cloud backup, and on your other devices'), findsOneWidget);
    });

    testWidgets('replacing keeps only the backup', (tester) async {
      final (c, _) = await open(tester);
      await chooseFile(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Replace instead'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Replace'));
      await tester.pumpAndSettle();

      expect(find.text('Progress imported.'), findsOneWidget);
      final progress = c.read(progressProvider);
      expect(progress.week('5787:2').isStarted, isFalse, reason: 'what the backup lacks is removed');
      expect(progress.week('5787:1').isComplete, isTrue);
      expect(progress.pauses.where((p) => !p.deleted).map((p) => p.id), ['trip']);
      expect(c.read(settingsProvider).joinDate, _simchatTorah);
    });

    testWidgets('merges a backup made before a reset, as a change that a sync keeps', (tester) async {
      final file = encodeBackup(backedUp(), savedSettings, now: DateTime.utc(2026, 10, 11, 12));
      later();
      // Progress was reset everywhere since, and Rishon of Noach read.
      final resetAt = ProgressClock.after(0);
      final (c, _) = await open(
        tester,
        file: file,
        progress: () => ProgressClock.above(
          resetAt,
          () => ProgressState(
            resetAt: resetAt,
            weeks: {'5787:2': WeekProgress(weekId: '5787:2').withAliyah(0, _monday)},
          ),
        ),
      );
      await chooseFile(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Merge'));
      await tester.pumpAndSettle();

      final imported = c.read(progressProvider);
      expect(imported.resetAt, resetAt);
      expect(imported.week('5787:1').isComplete, isTrue);
      expect(imported.week('5787:2').isAliyahDone(0), isTrue);
      // The account's backup, which the reset reached.
      final account = ProgressState(resetAt: resetAt);
      final synced = mergeProgress(imported, account);
      expect(synced.week('5787:1').isComplete, isTrue);
      expect(synced.pauses.map((p) => p.id), ['trip']);
    });

    testWidgets('merges a backup made after a reset elsewhere, keeping what is here through the next sync',
        (tester) async {
      // Bereshit, read here. Then progress was reset everywhere on another
      // device, which this one hasn't synced with since, Rishon of Noach
      // read there, and a backup made.
      final here = ProgressState(weeks: {'5787:1': WeekProgress(weekId: '5787:1').withAll(_bereshitFriday)});
      later();
      final resetAt = ProgressClock.after(here.latestStamp);
      later();
      final elsewhere = ProgressClock.above(
        resetAt,
        () => ProgressState(
          resetAt: resetAt,
          weeks: {'5787:2': WeekProgress(weekId: '5787:2').withAliyah(0, _monday)},
        ),
      );
      final file = encodeBackup(elsewhere, savedSettings, now: DateTime.utc(2026, 10, 11, 12));
      final (c, _) = await open(tester, file: file, progress: () => here);
      await chooseFile(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Merge'));
      await tester.pumpAndSettle();

      final imported = c.read(progressProvider);
      expect(imported.week('5787:1').isComplete, isTrue);
      expect(imported.week('5787:2').isAliyahDone(0), isTrue);
      expect(c.read(settingsProvider).joinDate, _simchatTorah);
      // The account's backup, which the reset reached, as the next sync
      // merges it.
      later();
      final synced = mergeProgress(imported, elsewhere);
      expect(synced.week('5787:1').isComplete, isTrue, reason: 'kept, as the merge promised');
      expect(synced.week('5787:2').isAliyahDone(0), isTrue);
      c.read(progressProvider.notifier).replaceAll(synced);
      expect(c.read(settingsProvider).joinDate, _simchatTorah, reason: 'the reset is no news here, to restart from');
    });

    testWidgets('can restore the settings too, keeping whether reminders were offered here', (tester) async {
      final (c, _) = await open(tester);
      await chooseFile(tester);
      await tester.tap(find.text('Also restore settings'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Merge'));
      await tester.pumpAndSettle();

      final settings = c.read(settingsProvider);
      expect(settings.plan, ReadingPlanType.erevShabbat);
      expect(settings.joinDate, _simchatTorah);
      expect(settings.onboardingComplete, isTrue);
      expect(settings.notificationPromptShown, isFalse, reason: "this device hasn't offered them");
      // Reminders can't be scheduled here, so there's no one to ask.
      expect(settings.dailyReminder, isTrue);
      expect(find.text('Progress imported.'), findsOneWidget);
    });

    for (final allows in [true, false]) {
      testWidgets('asks the OS before restoring reminders, and ${allows ? 'keeps them when allowed' : 'turns them off when refused'}',
          (tester) async {
        final notifications = _AskingNotifications(allows: allows);
        final (c, _) = await open(tester, notifications: notifications);
        await chooseFile(tester);
        await tester.tap(find.text('Also restore settings'));
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Merge'));
        await tester.pumpAndSettle();

        expect(notifications.asked, 1);
        final settings = c.read(settingsProvider);
        expect([settings.dailyReminder, settings.fridayReminder, settings.checkInReminder], everyElement(allows));
        expect(settings.notificationPromptShown, isTrue, reason: 'asked once, not again after the first aliyah');
        expect(settings.plan, ReadingPlanType.erevShabbat);
        expect(
          find.text(allows
              ? 'Progress imported.'
              : "Progress imported. Reminders are off, since notifications aren't allowed for this app."),
          findsOneWidget,
        );
        if (allows) return;
        // A change the reader didn't ask for, with the way to undo it.
        await tester.tap(find.widgetWithText(SnackBarAction, 'Reminders'));
        await tester.pumpAndSettle();
        expect(c.read(routerProvider).state.uri.path, '/settings/reminders');
      });
    }

    testWidgets("doesn't ask the OS when the settings stay", (tester) async {
      final notifications = _AskingNotifications(allows: false);
      final (c, _) = await open(tester, notifications: notifications);
      await chooseFile(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Merge'));
      await tester.pumpAndSettle();
      expect(notifications.asked, 0);
      expect(c.read(settingsProvider).dailyReminder, isFalse);
      expect(find.text('Progress imported.'), findsOneWidget);
    });

    testWidgets("doesn't ask the OS for settings without reminders", (tester) async {
      final notifications = _AskingNotifications(allows: false);
      final quiet = savedSettings.copyWith(dailyReminder: false, fridayReminder: false, checkInReminder: false);
      final (c, _) = await open(
        tester,
        notifications: notifications,
        file: encodeBackup(backedUp(), quiet, now: DateTime.utc(2026, 10, 11, 12)),
      );
      await chooseFile(tester);
      await tester.tap(find.text('Also restore settings'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Merge'));
      await tester.pumpAndSettle();
      expect(notifications.asked, 0);
      expect(c.read(settingsProvider).plan, ReadingPlanType.erevShabbat);
      expect(c.read(settingsProvider).notificationPromptShown, isFalse);
    });

    testWidgets("a file that isn't a backup changes nothing", (tester) async {
      for (final files in [FakeBackupFiles(file: 'not a backup'), FakeBackupFiles(openError: Exception('denied'))]) {
        final (c, _) = await open(tester, files: files);
        final before = c.read(progressProvider);
        await chooseFile(tester);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text("That backup couldn't be read."), findsOneWidget);
        expect(c.read(progressProvider), before);
      }
    });

    testWidgets('choosing no file changes nothing', (tester) async {
      final (c, _) = await open(tester, files: FakeBackupFiles());
      final before = c.read(progressProvider);
      await chooseFile(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(c.read(progressProvider), before);
    });

    testWidgets('a backup can be pasted from the clipboard', (tester) async {
      final file = encodeBackup(backedUp(), savedSettings, now: DateTime.utc(2026, 10, 11, 12));
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') return {'text': file};
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final (c, _) = await open(tester);
      await tester.tap(find.text('Paste backup text'));
      await tester.pumpAndSettle();

      // Something else first, which isn't a backup.
      await tester.enterText(find.byType(TextField), '{"app": "shnayim_mikra"}');
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pump();
      expect(find.text("That backup couldn't be read."), findsOneWidget);

      await tester.tap(find.text('Paste from clipboard'));
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, file);
      expect(find.text("That backup couldn't be read."), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Backup from October 11, 2026: 1\u00a0week logged, 1\u00a0pause.'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Merge'));
      await tester.pumpAndSettle();
      expect(c.read(progressProvider).week('5787:1').isComplete, isTrue);
      expect(c.read(progressProvider).week('5787:2').isAliyahDone(0), isTrue);
    });

    group('pasting', () {
      /// Opens the paste dialog with the clipboard answering as [clipboard]
      /// does.
      Future<void> openPaste(WidgetTester tester, Future<Object?> Function() clipboard) async {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') return clipboard();
          return null;
        });
        addTearDown(
            () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
        await open(tester);
        await tester.tap(find.text('Paste backup text'));
        await tester.pumpAndSettle();
      }

      const failed = "Couldn't paste from the clipboard. Paste into the field instead.";

      testWidgets('says so when the browser won\'t give the clipboard', (tester) async {
        await openPaste(tester, () async => throw PlatformException(code: 'denied'));
        await tester.tap(find.text('Paste from clipboard'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text(failed), findsOneWidget);
        expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);

        // Typing clears it.
        await tester.enterText(find.byType(TextField), '{');
        await tester.pump();
        expect(find.text(failed), findsNothing);
      });

      testWidgets('says so when the clipboard holds no text', (tester) async {
        for (final empty in [null, {'text': ''}, {'text': '  '}]) {
          await openPaste(tester, () async => empty);
          await tester.tap(find.text('Paste from clipboard'));
          await tester.pump();
          expect(find.text(failed), findsOneWidget, reason: '$empty');
        }
      });

      testWidgets('the field keeps its name once filled, and the dialog meets the guidelines', (tester) async {
        final handle = tester.ensureSemantics();
        await openPaste(tester, () async => null);
        expect(find.text('Paste the contents of your backup file.'), findsOneWidget);
        await tester.enterText(find.byType(TextField), '{"app": "shnayim_mikra"}');
        await tester.pump();
        expect(tester.getSemantics(find.byType(EditableText)).label, contains('Backup text'));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    });

    group('exporting', () {
      testWidgets('saves a file named for the day, holding everything', (tester) async {
        final (c, files) = await open(tester);
        await tester.tap(find.text('Export my progress'));
        await tester.pumpAndSettle();

        final saved = files.saved.single;
        expect(saved.name, 'shnayim-mikra-backup-2026-10-12.json');
        expect(saved.subject, "Shnayim Mikra v'Echad Targum");
        final backup = parseBackup(saved.data)!;
        expect(backup.progress, c.read(progressProvider));
        expect(backup.settings!.toJson(), c.read(settingsProvider).toJson());
        // The row, where the iPad anchors the share sheet.
        final row = tester.getRect(find.widgetWithText(ListTile, 'Export my progress'));
        expect(saved.origin, row);
        expect(find.text('Backup saved.'), findsOneWidget);
      });

      testWidgets('leaves it to the share sheet to say what became of it', (tester) async {
        final (_, files) = await open(tester, files: FakeBackupFiles(savesHere: false));
        await tester.tap(find.text('Export my progress'));
        await tester.pumpAndSettle();
        expect(files.saved, hasLength(1));
        expect(find.byType(SnackBar), findsNothing);
      });

      testWidgets("copies the backup to the clipboard if it can't be saved", (tester) async {
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
          return null;
        });
        addTearDown(
            () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
        final (c, _) = await open(tester, files: FakeBackupFiles(saveError: Exception('no share sheet')));
        await tester.tap(find.text('Export my progress'));
        await tester.pumpAndSettle();
        expect(find.text('Backup copied to the clipboard.'), findsOneWidget);
        expect(parseBackup(copied!)!.progress, c.read(progressProvider));
      });
    });

    group('accessibility', () {
      testWidgets('the import dialog meets the tap target and label guidelines', (tester) async {
        final handle = tester.ensureSemantics();
        await open(tester);
        await chooseFile(tester);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });

      for (final hebrew in [false, true]) {
        testWidgets('the dialogs fit at 200% text${hebrew ? ', in Hebrew' : ''}', (tester) async {
          await open(tester, textScale: 2, settings: setUpHere.copyWith(language: hebrew ? AppLanguage.hebrew : null));
          await tester.ensureVisible(find.byIcon(Icons.download));
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(Icons.download));
          await tester.pumpAndSettle();
          expect(find.byType(CheckboxListTile), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byIcon(Icons.content_paste));
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(Icons.content_paste));
          await tester.pumpAndSettle();
          expect(find.byType(TextField), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    });
  });
}
