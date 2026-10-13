import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/parsha/week_context.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/today/today_screen.dart';
import 'package:shnayim_mikra/ui/widgets/paper_group.dart' show PaperRow;

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

/// Noach 5787 with [read] read, each aliyah on its day from Sunday 11
/// October 2026 (Shishi and Shevi'i on Friday the 16th).
ProgressState _noach(Set<int> read) {
  var w = WeekProgress(weekId: '5787:2');
  for (final a in read) {
    w = w.withAliyah(a, LocalDate(2026, 10, 11 + (a > 5 ? 5 : a)));
  }
  return ProgressState(weeks: {'5787:2': w});
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
      expect(find.text('Shlishi\u00A0– Shevi’i'), findsOneWidget);
      // Shlishi's Targum, and all three readings of the other four.
      expect(findDotLine('5 aliyot · 96 verses · about 33 min'), findsOneWidget);
      expect(
        findWords('5 aliyot left to read before Shabbat — or finish Shabbat morning from a Chumash and log it after '
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
      expect(findDotLine('Genesis 2:20–3:21 · 27 verses'), findsOneWidget, reason: "Shlishi's reference");

      // Shevi'i is left for Shabbat morning.
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Shevi’i'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('When did you read it?'), findsOneWidget);
      await tester.tap(find.widgetWithText(PaperRow, 'Today'));
      await tester.pumpAndSettle();

      final week = c.read(progressProvider).week('5787:1');
      expect([for (var a = 0; a < 7; a++) week.isAliyahDone(a)], [true, true, true, true, true, true, false]);
      // Marking keeps the day a reading was first done.
      expect(week.units[2], [LocalDate(2026, 10, 7), LocalDate(2026, 10, 7), LocalDate(2026, 10, 9)]);
      expect(week.units[5], everyElement(LocalDate(2026, 10, 9)));
      expect(find.text('Marked as read'), findsOneWidget);
      // One aliyah is left, and it is today's.
      expect(find.text('Catching up'), findsNothing);
      expect(find.text('Shishi and Shevi’i'), findsOneWidget);
    });

    testWidgets('with nothing checked, the sheet logs nothing', (tester) async {
      await openToday(tester, progress: _bereshit());
      final book = find.text('I read it in a Chumash');
      await show(tester, book);
      await tester.tap(book);
      await tester.pumpAndSettle();
      for (final name in ['Shlishi', 'Revi’i', 'Chamishi', 'Shishi', 'Shevi’i']) {
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
      expect(find.text('Rishon\u00A0– Shlishi'), findsOneWidget);
      // Every aliyah the card names, today's too, counted alike.
      expect(find.textContaining(RegExp(r'^3 aliyot · \d+ verses')), findsOneWidget);
      expect(findWords('3 aliyot to catch up — very normal midweek.'), findsOneWidget);

      await openToday(tester, now: DateTime(2026, 10, 14, 10));
      expect(find.text('Rishon\u00A0– Revi’i'), findsOneWidget);
      expect(findWords('4 aliyot to catch up — very normal midweek.'), findsOneWidget);
    });

    testWidgets('two aliyot are named, not spanned', (tester) async {
      await openToday(tester, now: DateTime(2026, 10, 12, 10));
      expect(find.text('Rishon and Sheni'), findsOneWidget);
      expect(findWords('2 aliyot to catch up — very normal midweek.'), findsOneWidget);
    });

    testWidgets('one aliyah behind is said in words', (tester) async {
      // Monday's Sheni read, and Sunday's Rishon not.
      await openToday(tester, now: DateTime(2026, 10, 12, 10), progress: _noach({1}));
      expect(find.text('Rishon'), findsOneWidget);
      expect(findWords('One aliyah to catch up — very normal midweek.'), findsOneWidget);
    });

    testWidgets('on Thursday, two days remain before Shabbat', (tester) async {
      await openToday(tester, now: DateTime(2026, 10, 15, 10));
      expect(find.text('Rishon\u00A0– Chamishi'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^5 aliyot · \d+ verses')), findsOneWidget);
      expect(findWords('5 aliyot to catch up — and there are still two days before Shabbat.'), findsOneWidget);
      expect(find.textContaining('midweek'), findsNothing);
    });

    testWidgets('on Erev Shabbat, it counts every aliyah left before Shabbat', (tester) async {
      await openToday(tester, now: DateTime(2026, 10, 16, 10));
      expect(find.text('The whole parsha'), findsOneWidget);
      expect(findDotLine('7 aliyot · 153 verses · about 64 min'), findsOneWidget);
      expect(
        findWords('7 aliyot left to read before Shabbat — or finish Shabbat morning from a Chumash and log it after '
            'Shabbat.'),
        findsOneWidget,
      );
      expect(find.textContaining('midweek'), findsNothing);
    });

    testWidgets('on Erev Yom Tov, it counts every aliyah left before Yom Tov', (tester) async {
      // Tuesday 30 May 2028, Erev Shavuot 5788, in the week of Naso, read on
      // Shabbat 3 June: Friday is a reading day again. Nothing read since
      // Sunday, and Rishon to Chamishi planned by today.
      await openToday(
        tester,
        settings: _settings.copyWith(joinDate: LocalDate(2028, 5, 1)),
        now: DateTime(2028, 5, 30, 10),
      );
      expect(find.text('Rishon\u00A0– Chamishi'), findsOneWidget);
      expect(
        findWords('5 aliyot left to read before Yom Tov — or finish on Yom Tov from a Chumash and log it after Yom Tov.'),
        findsOneWidget,
      );
      expect(find.textContaining('midweek'), findsNothing);
      expect(find.textContaining('after Shabbat'), findsNothing);
    });

    testWidgets('on an Erev Yom Tov that runs into Shabbat, it is logged after Shabbat', (tester) async {
      // Wednesday 20 September 2028, Erev Rosh Hashanah 5789, in the week of
      // Haazinu, which is read on Shabbat the 23rd, straight after both days
      // of Yom Tov. Nothing read since Sunday.
      await openToday(
        tester,
        settings: _settings.copyWith(joinDate: LocalDate(2028, 9, 1)),
        now: DateTime(2028, 9, 20, 10),
      );
      expect(find.text('The whole parsha'), findsOneWidget);
      expect(
        findWords('7 aliyot left to read before Yom Tov — or finish on Yom Tov or Shabbat from a Chumash and log it '
            'after Shabbat.'),
        findsOneWidget,
      );
      expect(find.textContaining('log it after Yom Tov'), findsNothing);
      expect(find.textContaining('midweek'), findsNothing);
    });

    testWidgets('on an Erev Shabbat that runs into Yom Tov, it is logged after Yom Tov', (tester) async {
      // Friday 18 May 2029, the eve of Shabbat Bamidbar, with Shavuot on
      // Sunday and Monday. Nothing read since Sunday.
      await openToday(
        tester,
        settings: _settings.copyWith(joinDate: LocalDate(2029, 5, 1)),
        now: DateTime(2029, 5, 18, 10),
      );
      expect(find.text('The whole parsha'), findsOneWidget);
      expect(
        findWords('7 aliyot left to read before Shabbat — or finish Shabbat morning from a Chumash and log it after '
            'Yom Tov.'),
        findsOneWidget,
      );
      expect(find.textContaining('log it after Shabbat'), findsNothing);
    });

    testWidgets('on Erev Yom Kippur, it is neither Yom Tov nor the end of the week', (tester) async {
      // Tuesday 18 September 2029, Erev Yom Kippur 5790, in the week of
      // Haazinu, read on Shabbat the 22nd. Nothing read since Sunday.
      await openToday(
        tester,
        settings: _settings.copyWith(joinDate: LocalDate(2029, 9, 1)),
        now: DateTime(2029, 9, 18, 10),
      );
      expect(find.text('Rishon\u00A0– Shlishi'), findsOneWidget);
      expect(
        findWords('3 aliyot to catch up before Yom Kippur — and there is still time after it, too.'),
        findsOneWidget,
      );
      expect(find.textContaining('before Yom Tov'), findsNothing);
      expect(find.textContaining('midweek'), findsNothing);
    });

    testWidgets('in Hebrew too', (tester) async {
      final hebrew = _settings.copyWith(language: AppLanguage.hebrew);
      await openToday(tester, settings: hebrew, now: DateTime(2026, 10, 13, 10));
      expect(find.text('משלימים'), findsOneWidget);
      expect(find.text('ראשון\u00A0– שלישי'), findsOneWidget);
      expect(findWords('עוד 3 עליות להשלים — רגיל לגמרי באמצע השבוע.'), findsOneWidget);

      await openToday(tester, settings: hebrew, now: DateTime(2026, 10, 15, 10));
      expect(findWords('עוד 5 עליות להשלים — ויש עוד יומיים עד שבת.'), findsOneWidget);

      await openToday(tester, settings: hebrew, progress: _bereshit());
      expect(findWords('עוד 5 עליות לקרוא לפני שבת — או לסיים בשבת בבוקר מתוך חומש ולרשום אחרי השבת.'), findsOneWidget);

      await openToday(
        tester,
        settings: hebrew.copyWith(joinDate: LocalDate(2028, 5, 1)),
        now: DateTime(2028, 5, 30, 10),
      );
      expect(findWords('עוד 5 עליות לקרוא לפני החג — או לסיים בחג מתוך חומש ולרשום אחרי החג.'), findsOneWidget);

      await openToday(
        tester,
        settings: hebrew.copyWith(joinDate: LocalDate(2028, 9, 1)),
        now: DateTime(2028, 9, 20, 10),
      );
      expect(
        findWords('עוד 7 עליות לקרוא לפני החג — או לסיים בחג או בשבת מתוך חומש ולרשום אחרי השבת.'),
        findsOneWidget,
      );

      await openToday(
        tester,
        settings: hebrew.copyWith(joinDate: LocalDate(2029, 5, 1)),
        now: DateTime(2029, 5, 18, 10),
      );
      expect(
        findWords('עוד 7 עליות לקרוא לפני שבת — או לסיים בשבת בבוקר מתוך חומש ולרשום אחרי החג.'),
        findsOneWidget,
      );

      await openToday(
        tester,
        settings: hebrew.copyWith(joinDate: LocalDate(2029, 9, 1)),
        now: DateTime(2029, 9, 18, 10),
      );
      expect(findWords('עוד 3 עליות להשלים לפני יום כיפור — ויש זמן גם אחריו.'), findsOneWidget);
      expect(find.textContaining('לפני החג'), findsNothing);
    });

    testWidgets('one aliyah is said in words in Hebrew, on every kind of day', (tester) async {
      final hebrew = _settings.copyWith(language: AppLanguage.hebrew);
      // Tuesday, with Monday's Sheni and Tuesday's Shlishi read.
      await openToday(tester, settings: hebrew, now: DateTime(2026, 10, 13, 10), progress: _noach({1, 2}));
      expect(findWords('עוד עלייה אחת להשלים — רגיל לגמרי באמצע השבוע.'), findsOneWidget);
      // Thursday, with all but Revi'i read up to today.
      await openToday(tester, settings: hebrew, now: DateTime(2026, 10, 15, 10), progress: _noach({0, 1, 2, 4}));
      expect(findWords('עוד עלייה אחת להשלים — ויש עוד יומיים עד שבת.'), findsOneWidget);
      // Erev Shabbat, with all but Chamishi read.
      await openToday(tester, settings: hebrew, now: DateTime(2026, 10, 16, 10), progress: _noach({0, 1, 2, 3, 5, 6}));
      expect(
        findWords('עוד עלייה אחת לקרוא לפני שבת — או לסיים בשבת בבוקר מתוך חומש ולרשום אחרי השבת.'),
        findsOneWidget,
      );
    });

    test('only Sunday to Wednesday are midweek, and the eve of Shabbat or Yom Tov is its own, by the day that ends the rest',
        () {
      // The week of Noach 5787.
      expect(catchUpDayFor(LocalDate(2026, 10, 11), oneDayYomTov: false), CatchUpDay.midweek);
      expect(catchUpDayFor(LocalDate(2026, 10, 14), oneDayYomTov: false), CatchUpDay.midweek);
      expect(catchUpDayFor(LocalDate(2026, 10, 15), oneDayYomTov: false), CatchUpDay.thursday);
      expect(catchUpDayFor(LocalDate(2026, 10, 16), oneDayYomTov: false), CatchUpDay.erevShabbat);
      // Pesach 5787 begins on Thursday 22 April 2027: its eve is a
      // Wednesday, whatever the custom. With two days of Yom Tov they run
      // into Shabbat, and what is read then is logged after it.
      expect(catchUpDayFor(LocalDate(2027, 4, 21), oneDayYomTov: true), CatchUpDay.erevYomTov);
      expect(catchUpDayFor(LocalDate(2027, 4, 21), oneDayYomTov: false), CatchUpDay.erevYomTovThenShabbat);
      // Shavuot 5788 is on Wednesday 31 May 2028 (and Thursday): Friday is a
      // reading day again.
      expect(catchUpDayFor(LocalDate(2028, 5, 30), oneDayYomTov: false), CatchUpDay.erevYomTov);
      expect(catchUpDayFor(LocalDate(2028, 5, 30), oneDayYomTov: true), CatchUpDay.erevYomTov);
      // Shavuot 5789 is on Sunday 20 May 2029: Shabbat runs into it.
      expect(catchUpDayFor(LocalDate(2029, 5, 18), oneDayYomTov: false), CatchUpDay.erevShabbatThenYomTov);
      expect(catchUpDayFor(LocalDate(2029, 5, 18), oneDayYomTov: true), CatchUpDay.erevShabbatThenYomTov);
      // Sukkot 5789 begins on Thursday 5 October 2028: in Israel Friday is a
      // reading day; outside it, both days of Yom Tov run into Shabbat.
      expect(catchUpDayFor(LocalDate(2028, 10, 4), oneDayYomTov: true), CatchUpDay.erevYomTov);
      expect(catchUpDayFor(LocalDate(2028, 10, 4), oneDayYomTov: false), CatchUpDay.erevYomTovThenShabbat);
      // Yom Kippur is its own, on a weekday or on Shabbat (5785).
      expect(catchUpDayFor(LocalDate(2029, 9, 18), oneDayYomTov: false), CatchUpDay.erevYomKippur);
      expect(catchUpDayFor(LocalDate(2029, 9, 18), oneDayYomTov: true), CatchUpDay.erevYomKippur);
      expect(catchUpDayFor(LocalDate(2024, 10, 11), oneDayYomTov: false), CatchUpDay.erevYomKippur);
      // Rosh Hashanah 5789 is on Thursday and Friday, 21 and 22 September
      // 2028, everywhere: Shabbat follows.
      expect(catchUpDayFor(LocalDate(2028, 9, 20), oneDayYomTov: false), CatchUpDay.erevYomTovThenShabbat);
      expect(catchUpDayFor(LocalDate(2028, 9, 20), oneDayYomTov: true), CatchUpDay.erevYomTovThenShabbat);
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

  group('a reader who joined midweek without the starter plan', () {
    testWidgets('is led by both the hero and the card to the first aliyah expected of them', (tester) async {
      // Joined on Wednesday of Bereshit, starting with that day's reading
      // (Shlishi); Thursday, with Revi'i and Chamishi planned, nothing read.
      // Rishon and Sheni are not expected.
      final joined = _settings.copyWith(joinDate: LocalDate(2026, 10, 7), starterCatchUp: false);
      await openToday(tester, settings: joined, now: DateTime(2026, 10, 8, 10));
      expect(find.text('Shlishi\u00A0– Chamishi'), findsOneWidget);
      expect(findWords('3 aliyot to catch up — and there are still two days before Shabbat.'), findsOneWidget);
      expect(find.text('Start · Shlishi'), findsOneWidget);
      expect(find.textContaining('Rishon'), findsNothing);
      expect(find.bySubtype<FilledButton>(), findsOneWidget, reason: 'no second button to another aliyah');
    });
  });

  group('not behind', () {
    testWidgets("shows today's reading, and logs it from a Chumash", (tester) async {
      // Thursday of Noach, with Rishon to Revi'i read on their days.
      final c = await openToday(tester, now: DateTime(2026, 10, 15, 10), progress: _noach({0, 1, 2, 3}));
      expect(find.text('Today’s reading'), findsOneWidget);
      expect(find.text('Chamishi'), findsOneWidget);
      expect(find.textContaining('to catch up'), findsNothing);
      // The hero's button opens Chamishi already.
      expect(find.text('Continue · Chamishi'), findsOneWidget);
      expect(find.text('Read Chamishi'), findsNothing);

      final book = find.text('I read it in a Chumash');
      await show(tester, book);
      await tester.tap(book);
      await tester.pumpAndSettle();
      final boxes = find.byType(CheckboxListTile);
      expect(boxes, findsOneWidget, reason: "today's aliyah alone");
      expect(find.widgetWithText(CheckboxListTile, 'Chamishi'), findsOneWidget);
      expect(tester.widget<CheckboxListTile>(boxes).value, isTrue);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PaperRow, 'Today'));
      await tester.pumpAndSettle();

      final week = c.read(progressProvider).week('5787:2');
      expect([for (var a = 0; a < 7; a++) week.isAliyahDone(a)], [true, true, true, true, true, false, false]);
      expect(week.units[4], everyElement(LocalDate(2026, 10, 15)));
      expect(find.text('Today’s reading is done'), findsOneWidget);
    });

    testWidgets("counts the verses and minutes of what is left of today's reading", (tester) async {
      // Erev Shabbat Noach, with everything but Shevi'i read.
      final c = await openToday(tester, now: DateTime(2026, 10, 16, 10), progress: _noach({0, 1, 2, 3, 4, 5}));
      expect(find.text('Shishi and Shevi’i'), findsOneWidget);
      final ctx = c.read(currentWeekContextProvider);
      final shevii = ctx.aliyahVerses[6];
      expect(
        findDotLine('${shevii == 1 ? '1 verse' : '$shevii verses'} · about ${ctx.remainingMinutes([6])} min'),
        findsOneWidget,
        reason: "Shevi'i's alone, not Shishi's too",
      );
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
      expect(find.text('Shishi and Shevi’i'), findsOneWidget);
      expect(find.textContaining('to catch up'), findsNothing);
      final read = find.widgetWithText(FilledButton, 'Read Shishi');
      await show(tester, read);
      expect(find.bySubtype<FilledButton>(), findsNWidgets(2), reason: "the hero's, and this tonal one");
      expect(tester.widget<FilledButton>(read).style?.backgroundColor, isNotNull, reason: 'it is tonal');
      await tester.tap(read);
      await tester.pump();
      expect(c.read(routerProvider).state.uri.path, '/read/5787:1/5');
    });

    testWidgets("while paused, logs from a Chumash only today's aliyot, which the card names", (tester) async {
      final c = await openToday(
        tester,
        progress: ProgressState(
          weeks: _bereshit().weeks,
          pauses: [Pause(LocalDate(2026, 10, 8), LocalDate(2026, 10, 18), id: 'travel')],
        ),
      );
      final book = find.text('I read it in a Chumash');
      await show(tester, book);
      await tester.tap(book);
      await tester.pumpAndSettle();
      final boxes = find.byType(CheckboxListTile);
      expect([for (final b in tester.widgetList<CheckboxListTile>(boxes)) ((b.title as Text).data, b.value)], [
        ('Shishi', true),
        ('Shevi’i', true),
      ]);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PaperRow, 'Today'));
      await tester.pumpAndSettle();
      final week = c.read(progressProvider).week('5787:1');
      expect([for (var a = 0; a < 7; a++) week.isAliyahDone(a)], [true, true, false, false, false, true, true]);
    });

    testWidgets("says when today's reading is done", (tester) async {
      await openToday(tester, now: DateTime(2026, 10, 15, 10), progress: _noach({0, 1, 2, 3, 4}));
      expect(find.text('Today’s reading is done'), findsOneWidget);
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
