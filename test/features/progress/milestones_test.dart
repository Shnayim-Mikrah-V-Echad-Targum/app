import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/features/progress/domain/milestones.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/features/progress/domain/streak_engine.dart';

void main() {
  /// Weeks [ids] read whole on [on].
  Map<String, WeekProgress> readWeeks(Iterable<String> ids, LocalDate on) =>
      {for (final id in ids) id: WeekProgress(weekId: id).withAll(on)};

  final genesis = [for (var n = 1; n <= 12; n++) '5787:$n'];

  group('seferCompletions', () {
    test('finds a book once every one of its parshiyot is complete, on the day the last was', () {
      final progress = {
        ...readWeeks(genesis.take(11), LocalDate(2026, 12, 1)),
        '5787:12': WeekProgress(weekId: '5787:12').withAll(LocalDate(2027, 1, 1)),
      };
      expect(seferCompletions(progress, 5787), {0: LocalDate(2027, 1, 1)});
      expect(seferCompletions(progress, 5786), isEmpty, reason: 'another cycle');
    });

    test('takes no book with a parsha unfinished, however little is left', () {
      final progress = readWeeks(genesis, LocalDate(2027, 1, 1));
      progress['5787:12'] = progress['5787:12']!.withUnit(6, ReadingPass.targum, null);
      expect(seferCompletions(progress, 5787), isEmpty);
    });

    test('counts both parshiyot of a week read together', () {
      // Exodus: Shemot to Ki Tisa alone, and Vayakhel-Pekudei together.
      final progress = readWeeks([for (var n = 13; n <= 21; n++) '5787:$n', '5787:22-23'], LocalDate(2027, 3, 1));
      expect(seferCompletions(progress, 5787).keys, [1]);
      expect(parshiyotDoneInCycle(progress, 5787), containsAll([22, 23]));
    });

    test('ends Deuteronomy with Vezot HaBerakhah', () {
      final progress = readWeeks([for (var n = 44; n <= 53; n++) '5787:$n'], LocalDate(2027, 9, 1));
      expect(seferCompletions(progress, 5787), isEmpty);
      progress['5787:54'] = WeekProgress(weekId: '5787:54').withAll(LocalDate(2027, 10, 22));
      expect(seferCompletions(progress, 5787), {4: LocalDate(2027, 10, 22)});
    });
  });

  group('computeMilestones', () {
    /// The milestones of [progress], with no weeks evaluated.
    List<Milestone> milestonesOf(
      Map<String, WeekProgress> progress, {
      StreakSummary summary = StreakSummary.empty,
      LocalDate? joinDate,
    }) =>
        computeMilestones(
          summary: summary,
          progress: progress,
          doneByCycle: parshiyotDoneByCycle(progress),
          joinDate: joinDate,
        );
    List<Milestone> achieved(List<Milestone> all, MilestoneKind kind) =>
        all.where((m) => m.kind == kind && m.achieved).toList();

    /// Every parsha of [cycle] from [from] on, each read whole a week after
    /// the one before, from [start].
    Map<String, WeekProgress> yearFrom(int cycle, int from, LocalDate start) => {
          for (var n = from; n <= kParshaCount; n++)
            '$cycle:$n': WeekProgress(weekId: '$cycle:$n').withAll(start.addDays(7 * (n - from))),
        };

    test('a year read through stays a siyum, with its books, once the next year begins', () {
      final start = LocalDate(2025, 10, 17);
      final progress = {
        ...yearFrom(5786, 1, start),
        // The new year begun, with nothing finished in it yet.
        '5787:1': WeekProgress(weekId: '5787:1').withUnit(0, ReadingPass.mikra1, LocalDate(2026, 10, 5)),
      };
      final all = milestonesOf(progress);
      final siyum = achieved(all, MilestoneKind.siyum).single;
      expect(siyum.fromParsha, isNull, reason: 'the whole Torah');
      expect(siyum.achievedOn, start.addDays(7 * 53), reason: 'the day the last parsha was finished');
      expect(achieved(all, MilestoneKind.sefer).map((m) => m.value), [0, 1, 2, 3, 4]);
      expect(achieved(all, MilestoneKind.sefer).first.achievedOn, start.addDays(7 * 11), reason: 'Vayechi');
    });

    test('a reader who joined at Vayera completes the Torah from Vayera', () {
      final all = milestonesOf(yearFrom(5786, 4, LocalDate(2025, 11, 7)));
      final siyum = achieved(all, MilestoneKind.siyum).single;
      expect(siyum.fromParsha, 4);
      expect(siyum.achievedOn, LocalDate(2025, 11, 7).addDays(7 * 50));
      expect(achieved(all, MilestoneKind.sefer).map((m) => m.value), [1, 2, 3, 4], reason: 'Genesis was begun late');
    });

    test('a year with any parsha unfinished, or begun in Deuteronomy, is no siyum', () {
      final gap = yearFrom(5786, 4, LocalDate(2025, 11, 7))..remove('5786:30');
      expect(achieved(milestonesOf(gap), MilestoneKind.siyum), isEmpty);
      final deuteronomy = yearFrom(5786, 45, LocalDate(2026, 8, 1));
      expect(achieved(milestonesOf(deuteronomy), MilestoneKind.siyum), isEmpty);
    });

    test('a year begun partway is no siyum of its own after the whole Torah was completed', () {
      final progress = {...yearFrom(5786, 1, LocalDate(2025, 10, 17)), ...yearFrom(5787, 2, LocalDate(2026, 10, 16))};
      final siyum = achieved(milestonesOf(progress), MilestoneKind.siyum);
      expect(siyum.map((m) => m.fromParsha), [null]);
      expect(siyum.single.achievedOn, LocalDate(2025, 10, 17).addDays(7 * 53), reason: 'the first time');
    });

    test('streaks are dated by the day each length was first reached', () {
      const planner = ReadingPlanner(schedule: ParshaSchedule(israel: false));
      const engine = StreakEngine(planner: planner);
      // Each aliyah of Bereshit to Vayera 5787 on its planned day.
      final progress = <String, WeekProgress>{};
      var week = planner.schedule.weekFor(LocalDate(2026, 10, 5));
      for (var i = 0; i < 4; i++, week = planner.schedule.nextWeek(week)) {
        final plan = planner.planFor(week);
        var w = WeekProgress(weekId: plan.weekId);
        for (final day in plan.days) {
          for (final a in day.aliyot) {
            w = w.withAliyah(a, day.date);
          }
        }
        progress[plan.weekId] = w;
      }
      final summary =
          engine.evaluate(progress: progress, joinDate: LocalDate(2026, 10, 4), today: LocalDate(2026, 11, 8));
      final all = milestonesOf(progress, summary: summary);
      final fourWeeks = all.singleWhere((m) => m.kind == MilestoneKind.parshaStreak && m.value == 4);
      expect(fourWeeks.achieved, isTrue);
      // Vayera, the fourth week read: the reader joined in the week of Vezot
      // HaBerakhah, on Simchat Torah, which doesn't count.
      expect(fourWeeks.achievedOn, LocalDate(2026, 10, 30));
      expect(summary.weeks.where((e) => e.status.counts).elementAt(3).plan.weekId, '5787:4');
      final sevenDays = all.singleWhere((m) => m.kind == MilestoneKind.daysOnTrack && m.value == 7);
      final kept = summary.days.keys.where((d) => summary.days[d]!.counts).toList()..sort();
      expect(sevenDays.achievedOn, kept[6], reason: 'the seventh day on track');
      expect(all.singleWhere((m) => m.kind == MilestoneKind.firstAliyah).achievedOn, LocalDate(2026, 10, 5));
      expect(all.where((m) => m.kind == MilestoneKind.parshaStreak && m.value == 13).single.achieved, isFalse);
    });
  });

  group('welcome back', () {
    const planner = ReadingPlanner(schedule: ParshaSchedule(israel: false));
    const engine = StreakEngine(planner: planner);

    /// The week of [anyDay], each aliyah read on its planned day, or all on
    /// [on].
    MapEntry<String, WeekProgress> week(LocalDate anyDay, {LocalDate? on}) {
      final plan = planner.planFor(planner.schedule.weekFor(anyDay));
      var w = WeekProgress(weekId: plan.weekId);
      for (final day in plan.days) {
        for (final a in day.aliyot) {
          w = w.withAliyah(a, on ?? day.date);
        }
      }
      return MapEntry(plan.weekId, w);
    }

    Milestone comeback(Map<String, WeekProgress> progress, {required LocalDate joinDate, required LocalDate today, List<Pause> pauses = const []}) {
      final summary = engine.evaluate(progress: progress, joinDate: joinDate, today: today, pauses: pauses);
      return computeMilestones(
        summary: summary,
        progress: progress,
        doneByCycle: parshiyotDoneByCycle(progress),
        joinDate: joinDate,
      ).singleWhere((m) => m.kind == MilestoneKind.comeback);
    }

    // Joined on Simchat Torah, the last day of Vezot HaBerakhah's week, and
    // read Bereshit; or partway through Bereshit's week, left unfinished, and
    // read Noach.
    for (final (label, joined, first) in [
      ('on Simchat Torah', LocalDate(2026, 10, 4), LocalDate(2026, 10, 5)),
      ('midweek', LocalDate(2026, 10, 7), LocalDate(2026, 10, 12)),
    ]) {
      test('is not for a new reader who joined $label and finished a first parsha', () {
        final progress = Map.fromEntries([week(first)]);
        final summary = engine.evaluate(progress: progress, joinDate: joined, today: LocalDate(2026, 10, 20));
        expect(summary.weeks.first.status, WeekStatus.transparent, reason: 'the week joined in');
        expect(comeback(progress, joinDate: joined, today: LocalDate(2026, 10, 20)).achieved, isFalse);
      });
    }

    test('is for a reader back after a missed week, on the day they finished', () {
      // Bereshit read, Noach missed, Lech-Lecha read.
      final lechLecha = week(LocalDate(2026, 10, 19));
      final progress = Map.fromEntries([week(LocalDate(2026, 10, 5)), lechLecha]);
      final m = comeback(progress, joinDate: LocalDate(2026, 10, 4), today: LocalDate(2026, 10, 28));
      expect(m.achieved, isTrue);
      expect(m.achievedOn, lechLecha.value.completedOn);
    });

    test('is for a reader back after a pause', () {
      // Bereshit read, then a pause over the whole week of Noach.
      final lechLecha = week(LocalDate(2026, 10, 19));
      final progress = Map.fromEntries([week(LocalDate(2026, 10, 5)), lechLecha]);
      final m = comeback(
        progress,
        joinDate: LocalDate(2026, 10, 4),
        today: LocalDate(2026, 10, 28),
        pauses: [Pause(LocalDate(2026, 10, 11), LocalDate(2026, 10, 17))],
      );
      expect(m.achieved, isTrue);
      expect(m.achievedOn, lechLecha.value.completedOn);
    });
  });

  test('a sefer key names its cycle and book, and nothing else reads as one', () {
    expect(seferKey(5787, 0), 'sefer:5787:0');
    expect(parseSeferKey('sefer:5787:4'), (cycleYear: 5787, book: 4));
    for (final key in ['sefer:5787:5', 'sefer:5787', 'parsha:5787:0', 'sefer:x:0', '']) {
      expect(parseSeferKey(key), isNull, reason: key);
    }
  });
}
