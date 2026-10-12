import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/data/models/parsha.dart';
import 'package:shnayim_mikra/features/parsha/week_context.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/features/progress/domain/streak_engine.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/today/check_in.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart' show NoticeBanner;

import '../../helpers.dart';

/// Joined on Sunday 4 October 2026, before the week of Bereshit, read on
/// Shabbat 10 October.
final _settings = AppSettings(onboardingComplete: true, joinDate: LocalDate(2026, 10, 4));

const _checkIn = 'Shavua tov! Did you read Bereshit on Shabbat?';

const _finished = 'I finished Bereshit on Shabbat';

/// Of Bereshit, Rishon to Revi'i read on their days.
ProgressState _bereshit() {
  final monday = LocalDate(2026, 10, 5);
  var w = WeekProgress(weekId: '5787:1');
  for (var a = 0; a < 4; a++) {
    w = w.withAliyah(a, monday.addDays(a));
  }
  return ProgressState(weeks: {'5787:1': w});
}

/// The Monday after Shabbat Bereshit, the first time the app is opened since.
final _monday = DateTime(2026, 10, 12, 9);

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
    final c = await pumpApp(
      tester,
      settings: settings ?? _settings,
      now: now ?? _monday,
      progress: progress ?? _bereshit(),
    );
    await tester.pumpAndSettle();
    return c;
  }

  WeekProgress bereshit(ProviderContainer c) => c.read(progressProvider).week('5787:1');

  group('the check-in after Shabbat', () {
    testWidgets('is still asked when the app is first opened on Monday', (tester) async {
      await openToday(tester);
      expect(find.text(_checkIn), findsOneWidget);
      expect(find.text('Bereshit is still open'), findsNothing);
    });

    testWidgets('is asked while the week can count as late, and not after', (tester) async {
      await openToday(tester, now: DateTime(2026, 10, 13, 9));
      expect(find.text(_checkIn), findsOneWidget, reason: 'Tuesday is the last day it counts as late');

      await openToday(tester, now: DateTime(2026, 10, 14, 9));
      expect(find.text(_checkIn), findsNothing);
      expect(find.text('Bereshit is still open'), findsOneWidget);
    });

    testWidgets('without a late window, is asked on the first day after Shabbat alone', (tester) async {
      final settings = _settings.copyWith(lateWindow: LateWindow.none);
      await openToday(tester, settings: settings, now: DateTime(2026, 10, 11, 9));
      expect(find.text(_checkIn), findsOneWidget);
      await openToday(tester, settings: settings);
      expect(find.text(_checkIn), findsNothing);
    });

    testWidgets('can be put aside for this time', (tester) async {
      final c = await openToday(tester);
      await tester.tap(find.text('Not this time'));
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).checkInAnsweredFor, '5787:1');
      expect(find.text(_checkIn), findsNothing);
      expect(find.text('Bereshit is still open'), findsOneWidget);
      expect(bereshit(c).completedAliyot, 4, reason: 'nothing logged');

      // Answered, it isn't asked again.
      await openToday(tester, settings: c.read(settingsProvider), now: DateTime(2026, 10, 13, 9));
      expect(find.text(_checkIn), findsNothing);
    });

    testWidgets('logs three aliyot and the haftarah in one sheet, which Undo takes back', (tester) async {
      final c = await openToday(tester);
      final before = bereshit(c);
      await tester.tap(find.text('Choose aliyot'));
      await tester.pumpAndSettle();

      expect(find.text(_checkIn), findsNWidgets(2), reason: 'the sheet is titled with the question');
      final boxes = find.byType(CheckboxListTile);
      expect(boxes, findsNWidgets(4), reason: 'Chamishi, Shishi, Shevi\'i and the haftarah');
      expect([for (final b in tester.widgetList<CheckboxListTile>(boxes)) b.value], everyElement(isTrue));
      expect(find.text('Genesis 4:19–22 · 4 verses'), findsOneWidget, reason: "Chamishi's reference");
      expect(find.text('I Samuel 20:18–42'), findsOneWidget, reason: 'the haftarah of Machar Chodesh');
      expect(find.text('Read on Shabbat, October 10'), findsOneWidget);

      await tester.tap(find.text('Log reading'));
      await tester.pumpAndSettle();
      final shabbat = LocalDate(2026, 10, 10);
      final week = bereshit(c);
      expect(week.isComplete, isTrue);
      expect(week.units[4], everyElement(shabbat));
      expect(week.haftarah, shabbat);
      expect(week.units[0], before.units[0], reason: 'what was read keeps its day');
      expect(c.read(settingsProvider).checkInAnsweredFor, '5787:1');
      expect(find.text('Chazak! Parshat Bereshit is complete.'), findsOneWidget);
      expect(find.text(_checkIn), findsNothing);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(bereshit(c).units, before.units);
      expect(bereshit(c).haftarah, isNull);
      expect(c.read(settingsProvider).checkInAnsweredFor, isNull);
      expect(find.text(_checkIn), findsOneWidget, reason: 'asked again, as before');
    });

    testWidgets('logs only what is still checked, on the day chosen', (tester) async {
      final c = await openToday(tester);
      await tester.tap(find.text('Choose aliyot'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, "Shevi'i"));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Haftarah'));
      await tester.pump();

      await tester.tap(find.text('Change date'));
      await tester.pumpAndSettle();
      expect(find.text('When did you read it?'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Yesterday'));
      await tester.pumpAndSettle();
      expect(findWords('Read on Sunday, October 11'), findsOneWidget);

      await tester.tap(find.text('Log reading'));
      await tester.pumpAndSettle();
      final week = bereshit(c);
      expect([for (var a = 0; a < 7; a++) week.isAliyahDone(a)], [true, true, true, true, true, true, false]);
      expect(week.units[5], everyElement(LocalDate(2026, 10, 11)));
      expect(week.haftarah, isNull);
      expect(find.text('Marked as read'), findsOneWidget);
      expect(find.text('Bereshit is still open'), findsOneWidget);
    });

    testWidgets('with nothing checked, logs nothing', (tester) async {
      await openToday(tester);
      await tester.tap(find.text('Choose aliyot'));
      await tester.pumpAndSettle();
      for (final name in ['Chamishi', 'Shishi', "Shevi'i", 'Haftarah']) {
        await tester.tap(find.widgetWithText(CheckboxListTile, name));
        await tester.pump();
      }
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Log reading')).onPressed, isNull);
    });

    testWidgets('offers no haftarah where it is not shown', (tester) async {
      await openToday(tester, settings: _settings.copyWith(haftarahEnabled: false));
      await tester.tap(find.text('Choose aliyot'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(CheckboxListTile, 'Haftarah'), findsNothing);
    });

    testWidgets('finishes the parsha at once, which Undo takes back', (tester) async {
      final c = await openToday(tester);
      final before = bereshit(c);
      await tester.tap(find.text(_finished));
      await tester.pumpAndSettle();
      expect(bereshit(c).isComplete, isTrue);
      expect(find.text('Chazak! Parshat Bereshit is complete.'), findsOneWidget);
      expect(find.text(_checkIn), findsNothing);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(bereshit(c).units, before.units);
      expect(find.text(_checkIn), findsOneWidget);
    });

    testWidgets("sets its tonal button 12 from the notice's end and foot, clear of the corner", (tester) async {
      Rect banner() =>
          tester.getRect(find.descendant(of: find.byType(NoticeBanner), matching: find.byType(Material)).first);
      Rect button(String label) =>
          tester.getRect(find.ancestor(of: find.text(label), matching: find.byType(FilledButton)));

      await openToday(tester);
      expect(banner().right - button(_finished).right, 12);
      expect(banner().bottom - button(_finished).bottom, 12);

      // At the left in Hebrew.
      await openToday(tester, settings: _settings.copyWith(language: AppLanguage.hebrew));
      expect(button('סיימתי את פרשת בראשית בשבת').left - banner().left, 12);
      expect(banner().bottom - button('סיימתי את פרשת בראשית בשבת').bottom, 12);
    });

    testWidgets('names the parsha it asks about, above the next one', (tester) async {
      await openToday(tester);
      expect(find.text(_checkIn), findsOneWidget);
      expect(find.text(_finished), findsOneWidget);
      expect(find.bySemanticsLabel('Parshat Noach'), findsOneWidget, reason: "this week's, beneath it");
      await tester.tap(find.text('Choose aliyot'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(BottomSheet), matching: find.text(_checkIn)),
        findsOneWidget,
        reason: 'the sheet is titled with the same question',
      );
    });

    testWidgets('balances its question where it wraps, leaving no word alone', (tester) async {
      await openToday(tester);
      // In the test font, set in full "Shavua tov! Did you / read Bereshit on
      // / Shabbat?", and balanced "Shavua tov! Did / you read Bereshit / on
      // Shabbat?".
      final title = tester.renderObject<RenderParagraph>(
        find.descendant(of: find.byType(NoticeBanner), matching: find.text(_checkIn)),
      );
      double lineOf(int offset) => title.getOffsetForCaret(TextPosition(offset: offset), Rect.zero).dy;
      final lastLine = lineOf(_checkIn.length - 1);
      expect(lineOf(0), lessThan(lastLine), reason: 'the question wraps');
      expect(lineOf(_checkIn.lastIndexOf(' on ') + 1), lastLine, reason: 'the last line holds more than one word');
    });

    testWidgets('names both parshiyot of a week that reads them together', (tester) async {
      // Vayakhel-Pekudei 5786, read together on Shabbat 14 March 2026.
      final week = findWeekById(const ParshaSchedule(israel: false), '5786:22-23')!;
      final sunday = week.occasion.addDays(1);
      final settings = AppSettings(onboardingComplete: true, joinDate: LocalDate(2026, 3, 1));
      final progress = ProgressState(weeks: {
        '5786:22-23': WeekProgress(weekId: '5786:22-23').withAliyah(0, week.occasion.addDays(-6)),
      });
      final now = DateTime(sunday.year, sunday.month, sunday.day, 9);
      await openToday(tester, settings: settings, now: now, progress: progress);
      expect(find.text('Shavua tov! Did you read Vayakhel-Pekudei on Shabbat?'), findsOneWidget);
      expect(find.text('I finished Vayakhel-Pekudei on Shabbat'), findsOneWidget);

      await openToday(tester, settings: settings.copyWith(language: AppLanguage.hebrew), now: now, progress: progress);
      expect(find.text('שבוע טוב! קראת את פרשת ויקהל־פקודי בשבת?'), findsOneWidget);
      expect(find.text('סיימתי את פרשת ויקהל־פקודי בשבת'), findsOneWidget);
    });

    testWidgets('in Hebrew', (tester) async {
      await openToday(tester, settings: _settings.copyWith(language: AppLanguage.hebrew));
      const question = 'שבוע טוב! קראת את פרשת בראשית בשבת?';
      expect(find.text(question), findsOneWidget);
      expect(find.text('סיימתי את פרשת בראשית בשבת'), findsOneWidget);
      expect(find.text('לא הפעם'), findsOneWidget);
      await tester.tap(find.text('בחירת עליות'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text(question)), findsOneWidget);
      expect(find.text('תאריך הקריאה: שבת, 10 באוקטובר'), findsOneWidget);
      expect(find.text('שינוי התאריך'), findsOneWidget);
      expect(find.text('סימון הקריאה'), findsOneWidget);
    });
  });

  group('a week still open after its late window', () {
    testWidgets('can be restored by doubling up, which keeps a streak going', (tester) async {
      // Wednesday of Noach, with a two-week streak before Bereshit.
      final monday = LocalDate(2026, 9, 21);
      var weeks = <String, WeekProgress>{};
      for (final (id, first) in [('5786:53', monday), ('5786:54', monday)]) {
        weeks[id] = WeekProgress(weekId: id).withAll(first);
      }
      await openToday(
        tester,
        settings: _settings.copyWith(joinDate: LocalDate(2026, 9, 1)),
        now: DateTime(2026, 10, 14, 9),
        progress: ProgressState(weeks: {...weeks, ..._bereshit().weeks}),
      );
      expect(
        find.text('Finish Bereshit and Noach by Shabbat and your 2-week streak continues — one double-up per book.'),
        findsOneWidget,
      );
    });

    testWidgets('says both count, with no streak to keep', (tester) async {
      await openToday(tester, now: DateTime(2026, 10, 14, 9));
      expect(
        find.text('Finish Bereshit and Noach by Shabbat and both count — one double-up per book.'),
        findsOneWidget,
      );
      expect(find.textContaining('streak continues'), findsNothing);

      await openToday(tester, settings: _settings.copyWith(language: AppLanguage.hebrew), now: DateTime(2026, 10, 14, 9));
      expect(find.text('אם מסיימים את בראשית ואת נח עד שבת, שתיהן נחשבות — השלמה כפולה אחת לכל חומש.'), findsOneWidget);
    });
  });

  test("asks only after a Shabbat's reading, and only until answered", () async {
    final repo = await loadRepo();
    WeekContext previous({required LocalDate occasion, String id = '5787:1'}) {
      final week = findWeekById(const ParshaSchedule(israel: false), id)!;
      return WeekContext(
        week: week,
        plan: ReadingPlanner(schedule: const ParshaSchedule(israel: false)).planFor(week),
        portion: repo.portion(week.portion),
        progress: WeekProgress(weekId: id),
        today: occasion.addDays(2),
        status: WeekStatus.inProgress,
        haftarah: repo.haftarahFor(week.portion, week.occasion, HaftarahNusach.ashkenazi),
        aliyahVerses: const [0, 0, 0, 0, 0, 0, 0],
      );
    }

    final bereshit = previous(occasion: LocalDate(2026, 10, 10));
    final monday = LocalDate(2026, 10, 12);
    expect(asksCheckIn(bereshit, today: monday, settings: _settings), isTrue);
    expect(asksCheckIn(bereshit, today: monday, settings: _settings.copyWith(checkInAnsweredFor: '5787:1')), isFalse);
    expect(asksCheckIn(bereshit, today: monday, settings: _settings.copyWith(checkInAnsweredFor: '5786:54')), isTrue,
        reason: 'answered for an earlier week');
    // Vezot HaBerachah is read on Simchat Torah, a Yom Tov: no Shabbat to
    // ask about.
    final vezot = previous(occasion: LocalDate(2026, 10, 4), id: '5786:54');
    expect(asksCheckIn(vezot, today: LocalDate(2026, 10, 5), settings: _settings), isFalse);
  });
}
