import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/data/models/parsha.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/features/reader/haftarah_screen.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/settings/widgets/settings_widgets.dart';
import 'package:shnayim_mikra/ui/theme/app_theme.dart';
import 'package:shnayim_mikra/ui/widgets/paper_group.dart';

import '../../helpers.dart';

/// Tuesday of Noach 5787. Bereshit, the week before, was read on 10 October.
final _now = DateTime(2026, 10, 13, 10);
final _today = LocalDate(2026, 10, 13);
final _joined = LocalDate(2026, 9, 1);
const _applies = 'Applies from this week on';

/// The haftarah's switch, under the Haftarah section's heading.
const _haftarahSwitch = 'Read the week’s haftarah once';

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

    // The segment sets its gloss on a line of its own.
    await tapText(tester, 'One,\nas in Israel');
    s = c.read(settingsProvider);
    expect((s.readingSchedule, s.oneDayYomTov), (ReadingSchedule.israel, true));

    await tapText(tester, 'Outside Israel');
    await c.read(settingsProvider.notifier).flush();
    final prefs = await SharedPreferences.getInstance();
    final saved = AppSettings.fromJson(
      jsonDecode(prefs.getString(SettingsController.storageKey)!) as Map<String, dynamic>,
    );
    expect((saved.readingSchedule, saved.oneDayYomTov), (ReadingSchedule.diaspora, true));
    expect(find.text(_applies), findsNothing);
  });

  testWidgets('is set in sections, its choices of two or three as segments, and its sources as notes',
      (tester) async {
    tester.view.physicalSize = const Size(412, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await openReadingSettings(tester);
    for (final section in ['Where & when', 'How I read', 'Haftarah', 'Special days', 'Parsha names']) {
      expect(find.widgetWithText(GroupHeader, section), findsOneWidget, reason: section);
    }
    expect(find.byType(SegmentedButton<ReadingSchedule>), findsOneWidget);
    expect(find.byType(SegmentedButton<bool>), findsOneWidget);
    expect(find.byType(SegmentedButton<HaftarahNusach>), findsOneWidget);
    expect(find.byType(SegmentedButton<NameStyle>), findsOneWidget);
    // The plan, the window, the method and the second reading stay radios.
    expect(find.byType(RadioListTile<ReadingPlanType>), findsNWidgets(3));
    expect(find.byType(RadioListTile<LateWindow>), findsNWidgets(3));

    // The citations are notes in the margin, in its type.
    final notes = tester.widgetList<SourceNote>(find.byType(SourceNote)).map((n) => n.text);
    expect(notes, [
      'Reading finished after Shabbat, until this time, still counts (Shulchan Aruch OC 285:4).',
      startsWith('The Shulchan Aruch (OC 285:2) permits Rashi in place of Targum'),
    ]);
    final context = tester.element(find.byType(SourceNote).first);
    expect(
      tester.widget<Text>(find.descendant(of: find.byType(SourceNote).first, matching: find.byType(Text))).style,
      SeferType.of(context).marginalia,
    );
    // The citation alone is marginalia; the advice after it is plain help.
    const advice = 'A plain translation is a study aid, not a substitute. Ask your rav about translated Rashi.';
    expect(find.descendant(of: find.byType(SourceNote), matching: find.text(advice)), findsNothing);
    final help = tester.widget<Text>(find.text(advice)).style!;
    expect(help.fontSize, Theme.of(context).textTheme.bodyMedium!.fontSize);
    expect(help.fontStyle, isNot(FontStyle.italic));
  });

  testWidgets("the haftarah's custom and whether it counts show only while it is read, set in under it",
      (tester) async {
    await openReadingSettings(tester);
    final custom = find.byType(SegmentedButton<HaftarahNusach>);
    const counts = 'Count the haftarah toward completion';
    await tester.ensureVisible(custom);
    await tester.pumpAndSettle();
    expect(find.text(counts), findsOneWidget);
    // In by 16 behind its rule, from the haftarah's own switch.
    final haftarah = tester.getRect(find.widgetWithText(SwitchRow, _haftarahSwitch));
    expect(tester.getRect(custom).left, haftarah.left + 16 + 2);
    expect(tester.getRect(find.widgetWithText(SwitchRow, counts)).left, haftarah.left + 16 + 2);

    await tapText(tester, _haftarahSwitch);
    expect(c.read(settingsProvider).haftarahEnabled, isFalse);
    expect(custom, findsNothing);
    expect(find.text(counts), findsNothing);
  });

  testWidgets("the last verse's repeat follows the Chabad custom until the reader sets it", (tester) async {
    const desc = 'Repeat the parsha’s last verse in Hebrew after its Targum';
    const chabadDesc = 'Repeat the parsha’s last verse in Hebrew after its Targum (Chabad custom: not repeated)';
    bool repeat() => c.read(settingsProvider).repeatLastVerse;
    await openReadingSettings(tester);
    expect(find.text(desc), findsOneWidget);
    expect(repeat(), isTrue);

    await tapText(tester, 'Chabad');
    expect(repeat(), isFalse, reason: "Chabad's custom");
    expect(find.text(chabadDesc), findsOneWidget);
    expect(find.text(desc), findsNothing);
    // The switch is further up the page, so the change is said.
    expect(find.text('“End with Mikra” is now off, following the Chabad custom.'), findsOneWidget);
    await tapText(tester, 'Ashkenazi');
    expect(repeat(), isTrue);
    expect(find.text(desc), findsOneWidget);
    expect(find.text('“End with Mikra” is on again.'), findsOneWidget);
    // Between two customs that both repeat it, nothing changes, and nothing
    // is said.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    await tapText(tester, 'Sephardi');
    expect(find.byType(SnackBar), findsNothing);

    // Once set by the reader, it stays as set.
    await tapText(tester, 'Chabad');
    await tapText(tester, chabadDesc);
    expect(repeat(), isTrue);
    expect(c.read(settingsProvider).repeatLastVerseTouched, isTrue);
    await tapText(tester, 'Sephardi');
    await tapText(tester, 'Chabad');
    expect(repeat(), isTrue);
    expect(find.text(_applies), findsNothing);
  });

  testWidgets("each method's description names the reading after the Torah's two", (tester) async {
    await openReadingSettings(tester);
    expect(find.text('Each verse twice, then its Targum'), findsOneWidget);
    await tapText(tester, 'Rashi');
    expect(find.text('Each verse twice, then its Rashi'), findsOneWidget);
    expect(find.text('The whole aliyah twice, then its Rashi'), findsOneWidget);
    expect(find.textContaining('then its Targum'), findsNothing);
  });

  testWidgets('changes that don\'t affect how weeks are planned or judged say nothing', (tester) async {
    await openReadingSettings(tester);
    await tapText(tester, 'Section by section');
    await tapText(tester, _haftarahSwitch);
    expect(c.read(settingsProvider).method, ReadingMethod.sectionBySection);
    expect(c.read(settingsProvider).haftarahEnabled, isFalse);
    expect(find.text(_applies), findsNothing, reason: 'the haftarah did not count toward completion');
    expect(c.read(settingsProvider).planHistory, isEmpty);
  });

  group('a past week that counted the haftarah, after the haftarah is turned off,', () {
    final friday = LocalDate(2026, 10, 9);

    /// Opens the app on [now] with Bereshit's aliyot read on Friday (all of
    /// them, or all but the last), and its haftarah, which counted, not
    /// read; then turns the haftarah off. With [checkInAnswered], the reader
    /// has answered the check-in after its Shabbat.
    Future<void> turnHaftarahOff(
      WidgetTester tester,
      DateTime now, {
      int aliyotRead = 7,
      bool checkInAnswered = false,
    }) async {
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
        settings: AppSettings(
          onboardingComplete: true,
          joinDate: _joined,
          haftarahRequired: true,
          checkInAnsweredFor: checkInAnswered ? '5787:1' : null,
        ),
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
      // On Tuesday, the check-in is asked first until it is answered.
      await turnHaftarahOff(tester, _now, checkInAnswered: true);
      expect(find.text('Bereshit is still open'), findsOneWidget);
      expect(find.textContaining('Only the haftarah is left.'), findsOneWidget);
      await tester.tap(find.text('Read the haftarah'));
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
      final haftarahButton = find.ancestor(of: find.text('Read the haftarah'), matching: find.bySubtype<FilledButton>());

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
      expect(find.text('Parshat Bereshit is complete'), findsOneWidget);
      expect(haftarahButton, findsOneWidget, reason: 'Bereshit still needs its haftarah');

      await finishLastAliyah('5787:2');
      expect(find.text('Parshat Noach is complete'), findsOneWidget);
      expect(haftarahButton, findsNothing, reason: 'Noach does not');
    });
  });

  testWidgets('a past week that counted the haftarah still shows it after the haftarah is turned off', (tester) async {
    await openReadingSettings(tester, haftarahRequired: true);
    await tapText(tester, _haftarahSwitch);
    expect(find.text(_applies), findsOneWidget);

    c.read(routerProvider).go('/week/5787:1');
    await tester.pumpAndSettle();
    expect(find.text('Haftarah'), findsOneWidget, reason: 'Bereshit still needs its haftarah');

    c.read(routerProvider).go('/week/5787:2');
    await tester.pumpAndSettle();
    expect(find.text('Haftarah'), findsNothing, reason: 'Noach does not');
  });
}
