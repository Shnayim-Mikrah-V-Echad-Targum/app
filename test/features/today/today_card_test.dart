import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/today/today_screen.dart';

import '../../helpers.dart';

/// Joined on Sunday 4 October 2026 (Simchat Torah outside Israel), before
/// the week of Bereshit began on Monday the 5th.
final _settings = AppSettings(onboardingComplete: true, joinDate: LocalDate(2026, 10, 4));

/// Rishon and Sheni read, and Shlishi read twice in Hebrew: the Targum is
/// left.
ProgressState _bereshit() {
  final mon = LocalDate(2026, 10, 5);
  var w = WeekProgress(weekId: '5787:1').withAliyah(0, mon).withAliyah(1, mon.addDays(1));
  w = w.withUnit(2, ReadingPass.mikra1, mon.addDays(2)).withUnit(2, ReadingPass.mikra2, mon.addDays(2));
  return ProgressState(weeks: {'5787:1': w});
}

/// Friday 9 October 2026, Erev Shabbat Bereshit, in the morning. Shishi and
/// Shevi'i are today's; Shlishi, Revi'i and Chamishi were planned before.
final _friday = DateTime(2026, 10, 9, 11);

void main() {
  Future<ProviderContainer> openToday(
    WidgetTester tester, {
    AppSettings? settings,
    DateTime? now,
    ProgressState? progress,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: settings ?? _settings, now: now ?? _friday, progress: progress);
    await tester.pumpAndSettle();
    return c;
  }

  Future<void> show(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  group('behind on Erev Shabbat', () {
    testWidgets('the card gathers every aliyah due, with an honest estimate', (tester) async {
      await openToday(tester, progress: _bereshit());
      expect(find.text('Catching up'), findsOneWidget);
      expect(find.text("Shlishi – Shevi'i"), findsOneWidget);
      // Shlishi's Targum, and all three readings of the other four.
      expect(find.text('5 aliyot · 96 verses · about 33 min'), findsOneWidget);
      expect(
        find.text('5 aliyot left to read before Shabbat — or finish Shabbat morning from a Chumash and log it after '
            'Shabbat.'),
        findsOneWidget,
      );
      expect(find.textContaining('midweek'), findsNothing);
      // The hero's button already starts the backlog, at Shlishi.
      expect(find.textContaining('Continue · Shlishi'), findsOneWidget);
      expect(find.textContaining(RegExp('^Read (Shlishi|Shishi)')), findsNothing);
      expect(find.bySubtype<FilledButton>(), findsOneWidget);
    });

    testWidgets('the Chumash sheet checks each aliyah due, and logs those still checked at once', (tester) async {
      final c = await openToday(tester, progress: _bereshit());
      final book = find.text('I read it in a Chumash');
      await show(tester, book);
      await tester.tap(book);
      await tester.pumpAndSettle();

      expect(find.text('Which aliyot did you read?'), findsOneWidget);
      final boxes = find.byType(CheckboxListTile);
      expect(boxes, findsNWidgets(5));
      expect([for (final b in tester.widgetList<CheckboxListTile>(boxes)) b.value], everyElement(isTrue));
      expect(find.text('Genesis 2:20–3:21 · 27 verses'), findsOneWidget, reason: "Shlishi's reference");

      // Shevi'i is left for Shabbat morning.
      await tester.tap(find.widgetWithText(CheckboxListTile, "Shevi'i"));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('When did you read it?'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Today'));
      await tester.pumpAndSettle();

      final week = c.read(progressProvider).week('5787:1');
      expect([for (var a = 0; a < 7; a++) week.isAliyahDone(a)], [true, true, true, true, true, true, false]);
      // Marking keeps the day a reading was first done.
      expect(week.units[2], [LocalDate(2026, 10, 7), LocalDate(2026, 10, 7), LocalDate(2026, 10, 9)]);
      expect(week.units[5], everyElement(LocalDate(2026, 10, 9)));
      expect(find.text('Marked as read'), findsOneWidget);
      // One aliyah is left, and it is today's.
      expect(find.text('Catching up'), findsNothing);
      expect(find.text("Shishi and Shevi'i"), findsOneWidget);
    });

    testWidgets('with nothing checked, the sheet logs nothing', (tester) async {
      await openToday(tester, progress: _bereshit());
      final book = find.text('I read it in a Chumash');
      await show(tester, book);
      await tester.tap(book);
      await tester.pumpAndSettle();
      for (final name in ['Shlishi', "Revi'i", 'Chamishi', 'Shishi', "Shevi'i"]) {
        await tester.tap(find.widgetWithText(CheckboxListTile, name));
        await tester.pump();
      }
      final next = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'));
      expect(next.onPressed, isNull);
    });
  });

  group('the catch-up line is honest about the day', () {
    // The week of Noach 5787, read on Shabbat 17 October 2026: an aliyah a
    // day from Sunday, and Shishi and Shevi'i on Friday. Nothing read.
    testWidgets('from Sunday to Wednesday, it is midweek', (tester) async {
      await openToday(tester, now: DateTime(2026, 10, 13, 10));
      expect(find.text('Rishon – Shlishi'), findsOneWidget);
      expect(find.text('2 aliyot to catch up — very normal midweek.'), findsOneWidget);

      await openToday(tester, now: DateTime(2026, 10, 14, 10));
      expect(find.text("Rishon – Revi'i"), findsOneWidget);
      expect(find.text('3 aliyot to catch up — very normal midweek.'), findsOneWidget);
    });

    testWidgets('one aliyah behind is said in words', (tester) async {
      await openToday(tester, now: DateTime(2026, 10, 12, 10));
      expect(find.text('Rishon and Sheni'), findsOneWidget, reason: 'two aliyot are named, not spanned');
      expect(find.text('One aliyah to catch up — very normal midweek.'), findsOneWidget);
    });

    testWidgets('on Thursday, two days remain before Shabbat', (tester) async {
      await openToday(tester, now: DateTime(2026, 10, 15, 10));
      expect(find.text('Rishon – Chamishi'), findsOneWidget);
      expect(find.text('4 aliyot to catch up — and there are still two days before Shabbat.'), findsOneWidget);
      expect(find.textContaining('midweek'), findsNothing);
    });

    testWidgets('on Erev Shabbat, it counts every aliyah left before Shabbat', (tester) async {
      await openToday(tester, now: DateTime(2026, 10, 16, 10));
      expect(find.text('The whole parsha'), findsOneWidget);
      expect(find.text('7 aliyot · 153 verses · about 64 min'), findsOneWidget);
      expect(
        find.text('7 aliyot left to read before Shabbat — or finish Shabbat morning from a Chumash and log it after '
            'Shabbat.'),
        findsOneWidget,
      );
      expect(find.textContaining('midweek'), findsNothing);
    });

    testWidgets('on Erev Yom Tov, it counts every aliyah left before Yom Tov', (tester) async {
      // Wednesday 20 September 2028, Erev Rosh Hashanah 5789, in the week of
      // Haazinu, which is read on Shabbat the 23rd, after both days of Yom
      // Tov. Nothing read since Sunday.
      await openToday(
        tester,
        settings: _settings.copyWith(joinDate: LocalDate(2028, 9, 1)),
        now: DateTime(2028, 9, 20, 10),
      );
      expect(find.text('The whole parsha'), findsOneWidget);
      expect(
        find.text('7 aliyot left to read before Yom Tov — or finish on Yom Tov from a Chumash and log it after Yom Tov.'),
        findsOneWidget,
      );
      expect(find.textContaining('midweek'), findsNothing);
      expect(find.textContaining('before Shabbat'), findsNothing);
    });

    testWidgets('in Hebrew too', (tester) async {
      final hebrew = _settings.copyWith(language: AppLanguage.hebrew);
      await openToday(tester, settings: hebrew, now: DateTime(2026, 10, 13, 10));
      expect(find.text('משלימים'), findsOneWidget);
      expect(find.text('ראשון – שלישי'), findsOneWidget);
      expect(find.text('עוד 2 עליות להשלים — רגיל לגמרי באמצע השבוע.'), findsOneWidget);

      await openToday(tester, settings: hebrew, now: DateTime(2026, 10, 15, 10));
      expect(find.text('עוד 4 עליות להשלים — ויש עוד יומיים עד שבת.'), findsOneWidget);

      await openToday(tester, settings: hebrew, progress: _bereshit());
      expect(find.text('עוד 5 עליות לקרוא לפני שבת — או לסיים בשבת בבוקר מתוך חומש ולסמן אחרי השבת.'), findsOneWidget);

      await openToday(
        tester,
        settings: hebrew.copyWith(joinDate: LocalDate(2028, 9, 1)),
        now: DateTime(2028, 9, 20, 10),
      );
      expect(find.text('עוד 7 עליות לקרוא לפני החג — או לסיים בחג מתוך חומש ולסמן אחרי החג.'), findsOneWidget);
    });

    test('only Sunday to Wednesday are midweek, and the eve of Shabbat or Yom Tov is its own', () {
      // The week of Noach 5787.
      expect(catchUpDayFor(LocalDate(2026, 10, 11), oneDayYomTov: false), CatchUpDay.midweek);
      expect(catchUpDayFor(LocalDate(2026, 10, 14), oneDayYomTov: false), CatchUpDay.midweek);
      expect(catchUpDayFor(LocalDate(2026, 10, 15), oneDayYomTov: false), CatchUpDay.thursday);
      expect(catchUpDayFor(LocalDate(2026, 10, 16), oneDayYomTov: false), CatchUpDay.erevShabbat);
      // Pesach 5787 begins on Thursday 22 April 2027: its eve is a
      // Wednesday, whatever the custom.
      expect(catchUpDayFor(LocalDate(2027, 4, 21), oneDayYomTov: true), CatchUpDay.erevYomTov);
      expect(catchUpDayFor(LocalDate(2027, 4, 21), oneDayYomTov: false), CatchUpDay.erevYomTov);
      // In Israel the Friday after is a reading day, the eve of Shabbat.
      expect(catchUpDayFor(LocalDate(2027, 4, 23), oneDayYomTov: true), CatchUpDay.erevShabbat);
      // The seventh day is Wednesday 28 April: Tuesday is its eve. In
      // Israel the Thursday after is a reading day, with Friday still to
      // come before Shabbat.
      expect(catchUpDayFor(LocalDate(2027, 4, 26), oneDayYomTov: true), CatchUpDay.midweek);
      expect(catchUpDayFor(LocalDate(2027, 4, 27), oneDayYomTov: true), CatchUpDay.erevYomTov);
      expect(catchUpDayFor(LocalDate(2027, 4, 29), oneDayYomTov: true), CatchUpDay.thursday);
    });
  });

  group('not behind', () {
    testWidgets("shows today's reading, and logs it from a Chumash", (tester) async {
      // Thursday of Noach, with Rishon to Revi'i read on their days.
      var w = WeekProgress(weekId: '5787:2');
      for (var a = 0; a < 4; a++) {
        w = w.withAliyah(a, LocalDate(2026, 10, 11 + a));
      }
      await openToday(tester, now: DateTime(2026, 10, 15, 10), progress: ProgressState(weeks: {'5787:2': w}));
      expect(find.text("Today's reading"), findsOneWidget);
      expect(find.text('Chamishi'), findsOneWidget);
      expect(find.textContaining('to catch up'), findsNothing);
      // The hero's button opens Chamishi already.
      expect(find.text('Continue · Chamishi'), findsOneWidget);
      expect(find.text('Read Chamishi'), findsNothing);
      expect(find.text('I read it in a Chumash'), findsOneWidget);
    });

    testWidgets("while paused, offers today's first aliyah where the hero's button leads elsewhere", (tester) async {
      final c = await openToday(
        tester,
        progress: ProgressState(
          weeks: _bereshit().weeks,
          pauses: [Pause(LocalDate(2026, 10, 8), LocalDate(2026, 10, 18), id: 'travel')],
        ),
      );
      expect(find.text('Catching up'), findsNothing);
      expect(find.text("Shishi and Shevi'i"), findsOneWidget);
      expect(find.textContaining('to catch up'), findsNothing);
      final read = find.widgetWithText(FilledButton, 'Read Shishi');
      await show(tester, read);
      expect(find.bySubtype<FilledButton>(), findsNWidgets(2), reason: "the hero's, and this tonal one");
      expect(tester.widget<FilledButton>(read).style?.backgroundColor, isNotNull, reason: 'it is tonal');
      await tester.tap(read);
      await tester.pump();
      expect(c.read(routerProvider).state.uri.path, '/read/5787:1/5');
    });

    testWidgets("says when today's reading is done", (tester) async {
      var w = WeekProgress(weekId: '5787:2');
      for (var a = 0; a < 5; a++) {
        w = w.withAliyah(a, LocalDate(2026, 10, 11 + a));
      }
      await openToday(tester, now: DateTime(2026, 10, 15, 10), progress: ProgressState(weeks: {'5787:2': w}));
      expect(find.text("Today's reading is done"), findsOneWidget);
      expect(find.text('I read it in a Chumash'), findsNothing);
    });

    testWidgets('says when nothing is planned for today', (tester) async {
      // Everything on Erev Shabbat: nothing on Tuesday.
      await openToday(
        tester,
        settings: _settings.copyWith(plan: ReadingPlanType.erevShabbat),
        now: DateTime(2026, 10, 13, 10),
      );
      expect(find.text('No reading is planned for today. A good day to catch up or read ahead.'), findsOneWidget);
      expect(find.text('I read it in a Chumash'), findsNothing);
    });
  });
}
