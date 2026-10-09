import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/features/reader/haftarah_screen.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../../helpers.dart';

/// Tuesday of Noach 5787. Bereshit, the week before, was read on 10 October.
final _now = DateTime(2026, 10, 13, 10);
final _today = LocalDate(2026, 10, 13);
final _joined = LocalDate(2026, 9, 1);
const _applies = 'Applies from this week on';

void main() {
  late ProviderContainer c;

  Future<void> openReadingSettings(WidgetTester tester, {bool haftarahRequired = false}) async {
    c = await pumpApp(
      tester,
      settings: AppSettings(onboardingComplete: true, joinDate: _joined, haftarahRequired: haftarahRequired),
      now: _now,
    );
    c.read(routerProvider).go('/settings/reading');
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('changing the plan says it applies from this week on, and records it from today', (tester) async {
    await openReadingSettings(tester);
    expect(find.text(_applies), findsNothing);

    await tapText(tester, 'All on Friday');

    expect(find.text(_applies), findsOneWidget);
    final s = c.read(settingsProvider);
    expect(s.settingsAt(_today).plan, ReadingPlanType.erevShabbat);
    expect(s.settingsAt(_today.addDays(-1)).plan, ReadingPlanType.aliyahPerDay);
  });

  testWidgets('the reading heard and the days of Yom Tov kept are set apart, and saved', (tester) async {
    await openReadingSettings(tester);
    expect(find.text('Which Torah reading will you hear this Shabbat?'), findsOneWidget);
    expect(find.text('How many days of Yom Tov do you keep?'), findsOneWidget);
    expect(find.text('Visitors usually keep their home custom. Ask your rav.'), findsOneWidget);

    // A visitor from abroad: Israel's reading, two days of Yom Tov.
    await tapText(tester, 'In Israel');
    var s = c.read(settingsProvider);
    expect((s.readingSchedule, s.oneDayYomTov), (ReadingSchedule.israel, false));

    await tapText(tester, 'One, as in Israel');
    s = c.read(settingsProvider);
    expect((s.readingSchedule, s.oneDayYomTov), (ReadingSchedule.israel, true));

    await tapText(tester, 'Outside Israel');
    final prefs = await SharedPreferences.getInstance();
    final saved = AppSettings.fromJson(
      jsonDecode(prefs.getString(SettingsController.storageKey)!) as Map<String, dynamic>,
    );
    expect((saved.readingSchedule, saved.oneDayYomTov), (ReadingSchedule.diaspora, true));
    expect(find.text(_applies), findsNothing);
  });

  testWidgets('changes that don\'t affect how weeks are planned or judged say nothing', (tester) async {
    await openReadingSettings(tester);
    await tapText(tester, 'Section by section');
    await tapText(tester, 'Haftarah');
    expect(c.read(settingsProvider).method, ReadingMethod.sectionBySection);
    expect(c.read(settingsProvider).haftarahEnabled, isFalse);
    expect(find.text(_applies), findsNothing, reason: 'the haftarah did not count toward completion');
    expect(c.read(settingsProvider).planHistory, isEmpty);
  });

  group('a past week that counted the haftarah, after the haftarah is turned off,', () {
    final friday = LocalDate(2026, 10, 9);

    /// Opens the app on [now] with Bereshit's aliyot read on Friday (all of
    /// them, or all but the last), and its haftarah, which counted, not
    /// read; then turns the haftarah off.
    Future<void> turnHaftarahOff(WidgetTester tester, DateTime now, {int aliyotRead = 7}) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var bereshit = WeekProgress(weekId: '5787:1');
      var noach = WeekProgress(weekId: '5787:2');
      for (var a = 0; a < aliyotRead; a++) {
        bereshit = bereshit.withAliyah(a, friday);
        noach = noach.withAliyah(a, _today);
      }
      c = await pumpApp(
        tester,
        settings: AppSettings(onboardingComplete: true, joinDate: _joined, haftarahRequired: true),
        progress: ProgressState(weeks: {'5787:1': bereshit, if (aliyotRead < kAliyot) '5787:2': noach}),
        now: now,
      );
      c.read(settingsProvider.notifier).update((s) => s.copyWith(haftarahEnabled: false));
      await tester.pumpAndSettle();
    }

    /// Waits for texts to load from the bundle (spinners never settle).
    Future<void> loadTexts(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    testWidgets('is still open on Today, which leads to its haftarah', (tester) async {
      await turnHaftarahOff(tester, _now);
      expect(find.text('Bereshit is still open'), findsOneWidget);
      expect(find.text('Only the haftarah is left.'), findsOneWidget);
      await tester.tap(find.text('Bereshit is still open'));
      await loadTexts(tester);
      expect(find.byType(HaftarahScreen), findsOneWidget);
    });

    testWidgets('is finished, haftarah and all, by the check-in after Shabbat', (tester) async {
      await turnHaftarahOff(tester, DateTime(2026, 10, 11, 10));
      expect(find.text('Shavua tov! Did you read on Shabbat?'), findsOneWidget);
      await tester.tap(find.text('I finished it on Shabbat'));
      await tester.pumpAndSettle();
      expect(c.read(progressProvider).week('5787:1').haftarah, LocalDate(2026, 10, 10));
      expect(find.text('Shavua tov! Did you read on Shabbat?'), findsNothing);
      expect(find.text('Bereshit is still open'), findsNothing);
    });

    testWidgets('offers its haftarah when its last aliyah is finished in the reader; a later week does not', (tester) async {
      await turnHaftarahOff(tester, _now, aliyotRead: kAliyot - 1);
      final haftarahButton = find.ancestor(of: find.text('Haftarah'), matching: find.bySubtype<FilledButton>());

      Future<void> finishLastAliyah(String weekId) async {
        c.read(routerProvider).go('/read/$weekId/${kAliyot - 1}');
        await loadTexts(tester);
        await tester.tap(find.byTooltip('More options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mark this aliyah as read'));
        await tester.pumpAndSettle();
        expect(c.read(progressProvider).week(weekId).isComplete, isTrue);
      }

      await finishLastAliyah('5787:1');
      expect(find.text('Chazak! Parshat Bereshit is complete.'), findsOneWidget);
      expect(haftarahButton, findsOneWidget, reason: 'Bereshit still needs its haftarah');

      await finishLastAliyah('5787:2');
      expect(find.text('Chazak! Parshat Noach is complete.'), findsOneWidget);
      expect(haftarahButton, findsNothing, reason: 'Noach does not');
    });
  });

  testWidgets('a past week that counted the haftarah still shows it after the haftarah is turned off', (tester) async {
    await openReadingSettings(tester, haftarahRequired: true);
    await tapText(tester, 'Haftarah');
    expect(find.text(_applies), findsOneWidget);

    c.read(routerProvider).go('/week/5787:1');
    await tester.pumpAndSettle();
    expect(find.text('Haftarah'), findsOneWidget, reason: 'Bereshit still needs its haftarah');

    c.read(routerProvider).go('/week/5787:2');
    await tester.pumpAndSettle();
    expect(find.text('Haftarah'), findsNothing, reason: 'Noach does not');
  });
}
