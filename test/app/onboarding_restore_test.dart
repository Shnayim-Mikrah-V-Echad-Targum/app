import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/community/data/demo_forum_repository.dart';
import 'package:shnayim_mikra/features/community/data/forum_repository.dart';
import 'package:shnayim_mikra/features/community/ui/account_screen.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_merge.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/today/today_screen.dart';
import 'package:shnayim_mikra/services/backup_files.dart';

import '../fake_backup_files.dart';
import '../helpers.dart';

/// The demo community, standing in for a real one, whose backups outlive
/// the app.
class _Cloud extends DemoForumRepository {
  @override
  bool get isDemo => false;
}

/// "I already use Shnayim Mikra", on the welcome of a new install, on the
/// Wednesday of Toldot 5787.
void main() {
  final now = DateTime(2026, 11, 11, 10);
  final simchatTorah = LocalDate(2026, 10, 4);
  final bereshitFriday = LocalDate(2026, 10, 9);
  const email = 'reader@example.org';

  /// A reader who joined on Simchat Torah and read every portion on its
  /// Friday, Bereshit to Chayei Sara: a parsha streak of 5.
  ProgressState fiveWeeks() => ProgressState(weeks: {
        for (var i = 0; i < 5; i++)
          '5787:${i + 1}': WeekProgress(weekId: '5787:${i + 1}').withAll(bereshitFriday.addDays(7 * i)),
      });

  /// A first launch, with the restore sheet open, where the reader would
  /// choose [file] as a backup.
  Future<ProviderContainer> openRestore(WidgetTester tester, ForumRepository forums, {String? file}) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(
      tester,
      settings: const AppSettings(),
      now: now,
      forums: forums,
      overrides: [backupFilesProvider.overrideWithValue(FakeBackupFiles(file: file))],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('I already use Shnayim Mikra'));
    await tester.pumpAndSettle();
    expect(find.text('Restore your progress'), findsOneWidget);
    return c;
  }

  String location(ProviderContainer c) => c.read(routerProvider).state.uri.path;

  Future<void> signIn(WidgetTester tester) async {
    await tester.tap(find.text('Sign in to restore'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), email);
    await tester.tap(find.text('Email me a code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
  }

  group('signing in', () {
    testWidgets('restores the backup with its join date, and opens Today with the streak', (tester) async {
      final cloud = _Cloud();
      await cloud.verifyCode(email, '123456');
      final backup = fiveWeeks();
      await cloud.saveProgress(syncPayload(backup, simchatTorah));
      await cloud.signOut();

      final c = await openRestore(tester, cloud);
      await signIn(tester);

      expect(location(c), '/today');
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.text('Your progress is restored.'), findsOneWidget);
      final settings = c.read(settingsProvider);
      expect(settings.onboardingComplete, isTrue);
      expect(settings.cloudSync, isTrue);
      expect(settings.joinDate, simchatTorah);
      expect(c.read(progressProvider), backup);
      expect(c.read(streakSummaryProvider).parshaStreak, 5);
    });

    testWidgets('restores a backup that holds only the join date, and opens Today', (tester) async {
      // Reset everywhere, say, and nothing read since.
      final cloud = _Cloud();
      await cloud.verifyCode(email, '123456');
      await cloud.saveProgress(syncPayload(const ProgressState(), simchatTorah));
      await cloud.signOut();

      final c = await openRestore(tester, cloud);
      await signIn(tester);

      expect(location(c), '/today');
      expect(find.text('Your progress is restored.'), findsOneWidget);
      final settings = c.read(settingsProvider);
      expect(settings.onboardingComplete, isTrue);
      expect(settings.joinDate, simchatTorah);
    });

    testWidgets('to an account with no backup goes on to the first step, with backup on', (tester) async {
      final c = await openRestore(tester, _Cloud());
      await signIn(tester);

      expect(location(c), '/welcome/location');
      expect(find.text('Where will you be this Shabbat?'), findsOneWidget);
      expect(find.text("This account has no backup yet. Let's set up your reading."), findsOneWidget);
      final settings = c.read(settingsProvider);
      expect(settings.onboardingComplete, isFalse);
      expect(settings.cloudSync, isTrue);
      expect(settings.joinDate, isNull);
    });

    testWidgets('and coming back without signing in changes nothing', (tester) async {
      final c = await openRestore(tester, _Cloud());
      await tester.tap(find.text('Sign in to restore'));
      await tester.pumpAndSettle();
      expect(location(c), '/welcome/account');
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(location(c), '/welcome');
      expect(c.read(settingsProvider).cloudSync, isFalse);
      expect(find.text("Start this week's parsha"), findsOneWidget);
    });

    testWidgets('when the sync fails says so, and stays on the welcome', (tester) async {
      final cloud = _Offline();
      await cloud.verifyCode(email, '123456');
      final c = await openRestore(tester, cloud);
      await tester.tap(find.text('Sign in to restore'));
      await tester.pumpAndSettle();

      expect(location(c), '/welcome', reason: 'already signed in');
      expect(find.text("Couldn't sync right now. We'll try again later."), findsOneWidget);
      expect(c.read(settingsProvider).onboardingComplete, isFalse);
      expect(find.text('I already use Shnayim Mikra'), findsOneWidget, reason: 'to try again');
    });

    testWidgets('says so while the backup comes in', (tester) async {
      final cloud = _Slow();
      await cloud.verifyCode(email, '123456');
      final c = await openRestore(tester, cloud);
      await tester.tap(find.text('Sign in to restore'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Restoring your progress…'), findsOneWidget);
      expect(find.text('I already use Shnayim Mikra'), findsNothing);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(location(c), '/welcome/location', reason: 'an empty backup');
      // The sync that turning backup on started, after the one awaited.
      await tester.pump(const Duration(seconds: 3));
    });
  });

  testWidgets('the demo community has no backup to sign in to', (tester) async {
    await openRestore(tester, DemoForumRepository());
    expect(find.text('Sign in to restore'), findsNothing);
    expect(find.text('Restore from a backup file'), findsOneWidget);
    expect(find.text('Paste backup text'), findsOneWidget);
  });

  group('a backup file', () {
    /// Chooses [backup] as the file to restore from.
    Future<ProviderContainer> chooseFile(WidgetTester tester, Map<String, dynamic> backup) async {
      final c = await openRestore(
        tester,
        DemoForumRepository(),
        file: jsonEncode({'app': 'shnayim_mikra', 'exportedAt': '2026-11-01T12:00:00.000Z', ...backup}),
      );
      await tester.tap(find.text('Restore from a backup file'));
      await tester.pumpAndSettle();
      return c;
    }

    Future<ProviderContainer> restoreFile(WidgetTester tester, Map<String, dynamic> backup) async {
      final c = await chooseFile(tester, backup);
      await tester.tap(find.widgetWithText(FilledButton, 'Import progress'));
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('says what it holds, with nothing here to merge with or keep', (tester) async {
      final saved = AppSettings(onboardingComplete: true, joinDate: simchatTorah);
      await chooseFile(tester, {'progress': fiveWeeks().toJson(), 'settings': saved.toJson()});

      expect(find.text('Backup from November 1, 2026: 5\u00a0weeks logged, no pauses.'), findsOneWidget);
      expect(find.text('Merge'), findsNothing);
      expect(find.text('Replace instead'), findsNothing);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
        reason: 'a new install has no settings of its own to keep',
      );
    });

    testWidgets('restores its progress and settings, and opens Today with the streak', (tester) async {
      final saved = AppSettings(onboardingComplete: true, joinDate: simchatTorah, plan: ReadingPlanType.erevShabbat);
      final c = await restoreFile(tester, {'progress': fiveWeeks().toJson(), 'settings': saved.toJson()});

      expect(location(c), '/today');
      expect(find.text('Your progress is restored.'), findsOneWidget);
      final settings = c.read(settingsProvider);
      expect(settings.onboardingComplete, isTrue);
      expect(settings.joinDate, simchatTorah);
      expect(settings.plan, ReadingPlanType.erevShabbat);
      expect(c.read(progressProvider).week('5787:5').isComplete, isTrue);
      expect(c.read(streakSummaryProvider).parshaStreak, 5);
    });

    testWidgets('without settings counts from its earliest reading', (tester) async {
      final c = await restoreFile(tester, {'progress': fiveWeeks().toJson()});

      expect(location(c), '/today');
      expect(c.read(settingsProvider).onboardingComplete, isTrue);
      expect(c.read(settingsProvider).joinDate, bereshitFriday);
      expect(c.read(streakSummaryProvider).parshaStreak, 5);
    });

    testWidgets('can leave its settings out', (tester) async {
      final saved = AppSettings(onboardingComplete: true, joinDate: simchatTorah, plan: ReadingPlanType.erevShabbat);
      final c = await chooseFile(tester, {'progress': fiveWeeks().toJson(), 'settings': saved.toJson()});
      await tester.tap(find.text('Also restore settings'));
      await tester.tap(find.widgetWithText(FilledButton, 'Import progress'));
      await tester.pumpAndSettle();

      expect(location(c), '/today');
      expect(c.read(settingsProvider).plan, isNot(ReadingPlanType.erevShabbat));
      expect(c.read(settingsProvider).joinDate, simchatTorah, reason: 'the join date comes with the progress');
      expect(c.read(streakSummaryProvider).parshaStreak, 5);
    });

    testWidgets("that can't be read says so, and stays on the welcome", (tester) async {
      final c = await chooseFile(tester, {'progress': 'none'});

      expect(location(c), '/welcome');
      expect(find.text("That backup couldn't be read."), findsOneWidget);
      expect(c.read(settingsProvider).onboardingComplete, isFalse);
    });
  });

  testWidgets('a backup pasted as text restores as a file does', (tester) async {
    final c = await openRestore(tester, DemoForumRepository());
    await tester.tap(find.text('Paste backup text'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      jsonEncode({'app': 'shnayim_mikra', 'progress': fiveWeeks().toJson()}),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.text('5\u00a0weeks logged, no pauses.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Import progress'));
    await tester.pumpAndSettle();

    expect(location(c), '/today');
    expect(find.text('Your progress is restored.'), findsOneWidget);
    expect(c.read(settingsProvider).joinDate, bereshitFriday);
    expect(c.read(streakSummaryProvider).parshaStreak, 5);
  });

  testWidgets('Your data has a row for the cloud backup, which opens the account page', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, now: now);
    c.read(routerProvider).go('/settings/data');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cloud backup'));
    await tester.pumpAndSettle();
    expect(location(c), '/settings/account');
    expect(find.byType(AccountScreen), findsOneWidget);
  });
}

/// A community that can't be reached for backups.
class _Offline extends _Cloud {
  @override
  Future<Map<String, dynamic>?> loadProgress() async => throw Exception('offline');
}

/// A community whose backups take a while to come.
class _Slow extends _Cloud {
  @override
  Future<Map<String, dynamic>?> loadProgress() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    return super.loadProgress();
  }
}
