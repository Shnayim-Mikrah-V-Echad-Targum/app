import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/streak_engine.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/today/today_screen.dart';
import 'package:shnayim_mikra/ui/widgets/lines.dart';
import 'package:shnayim_mikra/ui/widgets/progress_widgets.dart';

import '../../helpers.dart';

/// Joined on Sunday 4 October 2026, before the week of Bereshit (Monday 5 to
/// Shabbat 10 October); Noach follows, from Sunday 11 to Shabbat 17.
final _settings = AppSettings(onboardingComplete: true, joinDate: LocalDate(2026, 10, 4));

LocalDate _d(int month, int day) => LocalDate(2026, month, day);

/// Week [id] read an aliyah a day from [first], the last two on the fifth
/// day, up to aliyah [upTo] (exclusive).
WeekProgress _onTheirDays(String id, LocalDate first, {int upTo = 7}) {
  var w = WeekProgress(weekId: id);
  for (var a = 0; a < upTo; a++) {
    w = w.withAliyah(a, first.addDays(a < 6 ? a : 4));
  }
  return w;
}

/// Bereshit read on its days.
WeekProgress _bereshit() => _onTheirDays('5787:1', _d(10, 5));

void main() {
  Future<ProviderContainer> openToday(
    WidgetTester tester, {
    AppSettings? settings,
    required DateTime now,
    required ProgressState progress,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: settings ?? _settings, now: now, progress: progress);
    await tester.pumpAndSettle();
    return c;
  }

  Future<void> show(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  group('while paused', () {
    testWidgets("Today's card says nothing counts, in place of catching up", (tester) async {
      // Friday of Bereshit, Rishon alone read, paused from Thursday.
      await openToday(
        tester,
        now: DateTime(2026, 10, 9, 11),
        progress: ProgressState(
          weeks: {'5787:1': _onTheirDays('5787:1', _d(10, 5), upTo: 1)},
          pauses: [Pause(_d(10, 8), _d(10, 18), id: 'travel')],
        ),
      );
      expect(findWords('Paused — read whenever you like; nothing counts against you.'), findsOneWidget);
      expect(find.text('Catching up'), findsNothing);
      expect(findWords('before Shabbat — or'), findsNothing);
    });

    testWidgets('ending the pause by choice says so, without a welcome back', (tester) async {
      final c = await openToday(
        tester,
        now: DateTime(2026, 10, 9, 11),
        progress: ProgressState(pauses: [Pause(_d(10, 8), _d(10, 18), id: 'travel')]),
      );
      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back! Your place is saved.'), findsOneWidget, reason: 'the status message alone');
      expect(find.textContaining('Your pause ended'), findsNothing);
      expect(c.read(settingsProvider).pauseEndSeen, _d(10, 8));
    });
  });

  group('after a pause has ended', () {
    // Paused from Thursday of Bereshit to Sunday; Monday is the first day
    // back.
    final pause = Pause(_d(10, 8), _d(10, 11), id: 'travel');
    final monday = DateTime(2026, 10, 12, 9);
    ProgressState halfRead() =>
        ProgressState(weeks: {'5787:1': _onTheirDays('5787:1', _d(10, 5), upTo: 3)}, pauses: [pause]);

    testWidgets('welcomes the reader back, with this week and last week to read', (tester) async {
      final c = await openToday(tester, now: monday, progress: halfRead());
      expect(find.text('Welcome back! Your place is saved.'), findsOneWidget);
      expect(findWords('Your pause ended on Sunday, October 11, and nothing during it counts against you.'),
          findsOneWidget);
      // The day and its month kept together on one line.
      expect(find.textContaining('October\u00A011,'), findsOneWidget);
      // It offers last week itself, so the check-in waits.
      expect(find.text('Shavua tov! Did you read Bereshit on Shabbat?'), findsNothing);

      await tester.tap(find.text('Catch up on Bereshit'));
      await tester.pump();
      expect(c.read(routerProvider).state.uri.path, '/today/week/5787:1');
      c.read(routerProvider).go('/today');
      await tester.pumpAndSettle();
      await tester.tap(find.text("Start this week's parsha"));
      await tester.pump();
      expect(c.read(routerProvider).state.uri.path, '/read/5787:2/0');
    });

    testWidgets('can be put away, for good', (tester) async {
      final c = await openToday(tester, now: monday, progress: halfRead());
      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).pauseEndSeen, _d(10, 11));
      expect(find.text('Welcome back! Your place is saved.'), findsNothing);
      expect(find.text('Shavua tov! Did you read Bereshit on Shabbat?'), findsOneWidget);

      await openToday(tester, settings: c.read(settingsProvider), now: monday, progress: halfRead());
      expect(find.text('Welcome back! Your place is saved.'), findsNothing);
    });

    testWidgets("continues this week's parsha where it was begun, and offers no week that's done", (tester) async {
      await openToday(
        tester,
        now: DateTime(2026, 10, 12, 9),
        progress: ProgressState(
          weeks: {'5787:1': _bereshit(), '5787:2': WeekProgress(weekId: '5787:2').withPosition(0, const [3, 0, 0])},
          pauses: [pause],
        ),
      );
      expect(find.text("Continue this week's parsha"), findsOneWidget);
      expect(find.textContaining('Catch up on'), findsNothing);
    });

    test('is welcomed until reading is logged for a day after it', () {
      final today = _d(10, 12);
      expect(pauseEndToWelcome(ProgressState(pauses: [pause]), today), _d(10, 11));
      // Still paused, or not yet over.
      expect(pauseEndToWelcome(ProgressState(pauses: [pause]), _d(10, 11)), isNull);
      expect(pauseEndToWelcome(ProgressState(pauses: [Pause(_d(10, 8), _d(10, 20))]), today), isNull);
      // A cancelled pause covers no days.
      expect(pauseEndToWelcome(ProgressState(pauses: [pause.cancelled()]), today), isNull);
      // The latest pause.
      expect(pauseEndToWelcome(ProgressState(pauses: [Pause(_d(9, 1), _d(9, 3)), pause]), today), _d(10, 11));
      // Read since: back already.
      final readMonday = WeekProgress(weekId: '5787:2').withAliyah(0, _d(10, 12));
      expect(pauseEndToWelcome(ProgressState(weeks: {'5787:2': readMonday}, pauses: [pause]), today), isNull);
      final readBefore = _onTheirDays('5787:1', _d(10, 5), upTo: 3);
      expect(pauseEndToWelcome(ProgressState(weeks: {'5787:1': readBefore}, pauses: [pause]), today), _d(10, 11));
    });

    test('is not welcomed when it was made, or changed, once it was over', () {
      final today = _d(10, 12);
      int at(DateTime t) => t.millisecondsSinceEpoch;
      // Made on Thursday, before it began: it ended while the app was closed.
      final made = Pause(_d(10, 8), _d(10, 11), id: 'a', updatedAt: at(DateTime(2026, 10, 8, 9)));
      expect(pauseEndToWelcome(ProgressState(pauses: [made]), today), _d(10, 11));
      // Made on its last day: still welcomed once it is over.
      final lastDay = Pause(_d(10, 9), _d(10, 11), id: 'b', updatedAt: at(DateTime(2026, 10, 11, 20)));
      expect(pauseEndToWelcome(ProgressState(pauses: [lastDay]), today), _d(10, 11));
      // A day's pause entered this morning for yesterday.
      final backdated = Pause(_d(10, 11), _d(10, 11), id: 'c', updatedAt: at(DateTime(2026, 10, 12, 9)));
      expect(pauseEndToWelcome(ProgressState(pauses: [backdated]), today), isNull);
      // Entered on Motzaei Shabbat for Shabbat: that evening counts toward
      // Sunday.
      final shabbat = Pause(_d(10, 9), _d(10, 10), id: 'd', updatedAt: at(DateTime(2026, 10, 10, 21)));
      expect(pauseEndToWelcome(ProgressState(pauses: [shabbat]), today), isNull);
      // Ended early, by choice.
      final ended = Pause(_d(10, 8), _d(10, 11), id: 'e', updatedAt: at(DateTime(2026, 10, 12, 8)));
      expect(pauseEndToWelcome(ProgressState(pauses: [ended]), today), isNull);
    });

    testWidgets('a pause entered after the fact gets no welcome back', (tester) async {
      final clock = ProgressClock.nowMs;
      ProgressClock.nowMs = () => monday.millisecondsSinceEpoch;
      addTearDown(() => ProgressClock.nowMs = clock);
      final c = await openToday(tester, now: monday, progress: halfRead().copyWith(pauses: const []));
      // A day's pause, from yesterday, as the pause dialog allows.
      c.read(progressProvider.notifier).addPause(_d(10, 11), _d(10, 11));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back! Your place is saved.'), findsNothing);
      expect(find.textContaining('Your pause ended'), findsNothing);
    });
  });

  group('under the week strip', () {
    // Friday of Noach: Rishon to Shlishi read on their days, nothing on
    // Wednesday, Chamishi alone on Thursday. A grace day covers Wednesday.
    ProgressState graceWeek() => ProgressState(weeks: {
          '5787:1': _bereshit(),
          '5787:2': _onTheirDays('5787:2', _d(10, 11), upTo: 3).withAliyah(4, _d(10, 15)),
        });
    final friday = DateTime(2026, 10, 16, 9);
    const grace = "Wednesday was covered by a grace day — your rhythm continues. You'll earn one back when you "
        'finish Noach by Shabbat.';

    testWidgets('a grace day spent is explained, until put away', (tester) async {
      final c = await openToday(tester, now: friday, progress: graceWeek());
      final note = findWords(grace);
      await show(tester, note);
      expect(note, findsOneWidget);
      expect(find.byTooltip(RegExp('^Wednesday: Covered by a grace day')), findsOneWidget);

      await tester.tap(find.descendant(of: find.byType(Card), matching: find.byTooltip('Dismiss')).last);
      await tester.pumpAndSettle();
      expect(findWords(grace), findsNothing);
      expect(c.read(settingsProvider).lastStripAck, _d(10, 16));

      await openToday(tester, settings: c.read(settingsProvider), now: friday, progress: graceWeek());
      expect(findWords(grace), findsNothing);
    });

    testWidgets('a note seen is not told again the next day', (tester) async {
      final c = await openToday(tester, now: friday, progress: graceWeek());
      await show(tester, findWords(grace));
      expect(c.read(settingsProvider).stripNoteShownOn, _d(10, 16));
      // Seen today, it stays for the day.
      await openToday(tester, settings: c.read(settingsProvider), now: friday, progress: graceWeek());
      expect(findWords(grace), findsOneWidget);

      final sunday = DateTime(2026, 10, 18, 9);
      await openToday(tester, settings: c.read(settingsProvider), now: sunday, progress: graceWeek());
      expect(findWords(grace), findsNothing);
      expect(findWords('covered by a grace day —'), findsNothing);
    });

    testWidgets('says so when today was read ahead', (tester) async {
      // Thursday of Noach, with Chamishi read on Wednesday too.
      await openToday(
        tester,
        now: DateTime(2026, 10, 15, 9),
        progress: ProgressState(weeks: {
          '5787:1': _bereshit(),
          '5787:2': _onTheirDays('5787:2', _d(10, 11), upTo: 4).withAliyah(4, _d(10, 14)),
        }),
      );
      await show(tester, find.byType(WeekStrip));
      expect(find.text("You're ahead of plan. Well done!"), findsOneWidget);
    });

    testWidgets('says so when doubling up today made up for yesterday', (tester) async {
      // Thursday of Noach: Revi'i, Wednesday's, read with Chamishi.
      await openToday(
        tester,
        now: DateTime(2026, 10, 15, 9),
        progress: ProgressState(weeks: {
          '5787:1': _bereshit(),
          '5787:2': _onTheirDays('5787:2', _d(10, 11), upTo: 3).withAliyah(3, _d(10, 15)).withAliyah(4, _d(10, 15)),
        }),
      );
      await show(tester, find.byType(WeekStrip));
      expect(findWords('Caught up — doubling up repaired yesterday.'), findsOneWidget);
    });

    testWidgets('in Hebrew', (tester) async {
      final hebrew = _settings.copyWith(language: AppLanguage.hebrew);
      await openToday(tester, settings: hebrew, now: friday, progress: graceWeek());
      final note = findWords('יום רביעי כוסה ביום\u00A0חסד — הקצב נמשך. עם סיום פרשת נח עד שבת, יום\u00A0החסד יחזור.');
      await show(tester, note);
      expect(note, findsOneWidget);
    });

    testWidgets('names every grace day spent, the first not lost behind the second', (tester) async {
      // Friday of Noach: Rishon on Sunday, nothing on Monday or Tuesday,
      // Revi'i alone on Wednesday and Chamishi on Thursday. Grace days cover
      // Monday and Tuesday.
      final weeks = {
        '5787:1': _bereshit(),
        '5787:2': WeekProgress(weekId: '5787:2')
            .withAliyah(0, _d(10, 11))
            .withAliyah(3, _d(10, 14))
            .withAliyah(4, _d(10, 15)),
      };
      await openToday(tester, now: friday, progress: ProgressState(weeks: weeks));
      final note = findWords("Monday and Tuesday were covered by grace days — your rhythm continues. You'll earn one "
          'back when you finish Noach by Shabbat.');
      await show(tester, note);
      expect(note, findsOneWidget);

      await openToday(
        tester,
        settings: _settings.copyWith(language: AppLanguage.hebrew),
        now: friday,
        progress: ProgressState(weeks: weeks),
      );
      final hebrew = findWords(
          'יום שני ויום שלישי כוסו בימי\u00A0חסד — הקצב נמשך. עם סיום פרשת נח עד שבת, יום\u00A0חסד אחד יחזור.');
      await show(tester, hebrew);
      expect(hebrew, findsOneWidget);
    });

    group('promises no grace day back where finishing would not earn one', () {
      const short = 'Wednesday was covered by a grace day — your rhythm continues.';

      testWidgets('once the week is finished', (tester) async {
        // Revi'i, Shishi and Shevi'i read on Friday: Noach is finished.
        final week = graceWeek().weeks['5787:2']!.withAliyah(3, _d(10, 16)).withAliyah(5, _d(10, 16)).withAliyah(
              6,
              _d(10, 16),
            );
        await openToday(tester, now: friday, progress: ProgressState(weeks: {'5787:1': _bereshit(), '5787:2': week}));
        final note = findWords(short);
        await show(tester, note);
        expect(note, findsOneWidget);
        expect(find.textContaining('earn one back'), findsNothing);
      });

      /// Today on [now], its streaks [summary] in place of the engine's.
      Future<void> openWith(WidgetTester tester, DateTime now, StreakSummary summary) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pumpApp(
          tester,
          settings: _settings.copyWith(joinDate: LocalDate(2026, 9, 1)),
          now: now,
          progress: graceWeek(),
          overrides: [streakSummaryProvider.overrideWithValue(summary)],
        );
        await tester.pumpAndSettle();
      }

      StreakSummary withGrace(LocalDate day, {required int balance}) => StreakSummary(
            parshaStreak: 0,
            longestParshaStreak: 0,
            daysOnTrack: 0,
            longestDaysOnTrack: 0,
            graceBalance: balance,
            days: {day: DayStatus.grace, day.addDays(1): DayStatus.kept},
            weeks: const [],
            restoreAvailable: false,
          );

      testWidgets('while every grace day is in hand', (tester) async {
        await openWith(tester, friday, withGrace(_d(10, 14), balance: GraceRules.maxBalance));
        final note = findWords(short);
        await show(tester, note);
        expect(note, findsOneWidget);
      });

      testWidgets("in Vezot HaBerachah's week, read on Simchat Torah", (tester) async {
        // Thursday 1 October 2026, Chol HaMoed Sukkot.
        await openWith(tester, DateTime(2026, 10, 1, 9), withGrace(_d(9, 29), balance: 1));
        final note = findWords('Tuesday was covered by a grace day — your rhythm continues.');
        await show(tester, note);
        expect(note, findsOneWidget);
      });
    });

    group('stripNoteFor', () {
      final days = {
        _d(10, 11): DayStatus.kept,
        _d(10, 12): DayStatus.kept,
        _d(10, 13): DayStatus.kept,
        _d(10, 14): DayStatus.grace,
        _d(10, 15): DayStatus.kept,
        _d(10, 16): DayStatus.open,
      };

      test('tells of a grace day once the day after it is over', () {
        expect(stripNoteFor(days, today: _d(10, 16)), StripNote(StripNoteKind.grace, [_d(10, 14)]));
        // Decided on Friday: put away or seen on Thursday, it is still news.
        expect(stripNoteFor(days, today: _d(10, 16), acknowledged: _d(10, 15)),
            StripNote(StripNoteKind.grace, [_d(10, 14)]));
        expect(stripNoteFor(days, today: _d(10, 16), acknowledged: _d(10, 16)), isNull);
        // Within a week of it.
        expect(stripNoteFor(days, today: _d(10, 22)), StripNote(StripNoteKind.grace, [_d(10, 14)]));
        expect(stripNoteFor(days, today: _d(10, 23)), isNull);
      });

      test('then today read ahead, then yesterday made up', () {
        final ahead = {...days, _d(10, 16): DayStatus.ahead};
        expect(stripNoteFor(ahead, today: _d(10, 16), acknowledged: _d(10, 16)), isNull);
        expect(stripNoteFor(ahead, today: _d(10, 16), acknowledged: _d(10, 15)),
            StripNote(StripNoteKind.grace, [_d(10, 14)]),
            reason: 'the grace day first');
        final noGrace = {...ahead, _d(10, 14): DayStatus.kept};
        expect(stripNoteFor(noGrace, today: _d(10, 16)), StripNote(StripNoteKind.ahead, [_d(10, 16)]));
        final caughtUp = {...noGrace, _d(10, 15): DayStatus.caughtUp, _d(10, 16): DayStatus.kept};
        expect(stripNoteFor(caughtUp, today: _d(10, 16)), StripNote(StripNoteKind.caughtUp, [_d(10, 15)]));
        expect(stripNoteFor(caughtUp, today: _d(10, 17)), isNull, reason: 'only yesterday');
      });

      test('tells of every grace day not yet told, in one line', () {
        // Monday and Tuesday missed, decided on Wednesday and Thursday.
        final two = {...days, _d(10, 12): DayStatus.grace, _d(10, 13): DayStatus.grace, _d(10, 14): DayStatus.kept};
        expect(stripNoteFor(two, today: _d(10, 16)), StripNote(StripNoteKind.grace, [_d(10, 12), _d(10, 13)]));
        // Monday's told on Wednesday; Tuesday's is still news.
        expect(stripNoteFor(two, today: _d(10, 16), acknowledged: _d(10, 14)),
            StripNote(StripNoteKind.grace, [_d(10, 13)]));
        // Opened first on Saturday: Monday's, decided Wednesday, is not lost
        // behind Tuesday's.
        expect(stripNoteFor(two, today: _d(10, 17), acknowledged: _d(10, 10)),
            StripNote(StripNoteKind.grace, [_d(10, 12), _d(10, 13)]));
        expect(stripNoteFor(two, today: _d(10, 16), acknowledged: _d(10, 16)), isNull);
      });
    });
  });

  testWidgets("on the eve of Tisha B'Av, many finish their learning by midday", (tester) async {
    // Wednesday 11 August 2027, 8 Av 5787: the day the reader joined.
    await openToday(
      tester,
      settings: _settings.copyWith(joinDate: LocalDate(2027, 8, 11)),
      now: DateTime(2027, 8, 11, 9),
      progress: const ProgressState(),
    );
    expect(find.text("Erev Tisha B'Av: many finish their learning before midday."), findsOneWidget);
    // Set evenly, so that no word is left alone on its last line.
    expect(
      find.ancestor(of: find.text("Erev Tisha B'Av: many finish their learning before midday."), matching: find.byType(BalancedText)),
      findsOneWidget,
    );

    await openToday(
      tester,
      settings: _settings.copyWith(joinDate: LocalDate(2027, 8, 10)),
      now: DateTime(2027, 8, 10, 9),
      progress: const ProgressState(),
    );
    expect(find.textContaining('Tisha B'), findsNothing);
  });

  setUp(TodayScreen.forgetCompletions);
}
