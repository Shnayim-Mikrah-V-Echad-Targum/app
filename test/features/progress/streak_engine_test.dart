import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/features/progress/domain/streak_engine.dart';

const diaspora = ParshaSchedule(israel: false);

LocalDate d(String iso) => LocalDate.parse(iso);

/// Helper that builds a progress log fluently.
class Log {
  final Map<String, WeekProgress> map = {};
  final ReadingPlanner planner;
  Log(this.planner);

  String idFor(String anyDateInWeek) {
    final w = diaspora.weekFor(d(anyDateInWeek));
    return weekIdFor(w.portion, w.occasion);
  }

  void read(String weekDate, List<int> aliyot, String on) {
    final id = idFor(weekDate);
    var p = map[id] ?? WeekProgress(weekId: id);
    for (final a in aliyot) {
      p = p.withAliyah(a, d(on));
    }
    map[id] = p;
  }

  void readAll(String weekDate, String on) => read(weekDate, [0, 1, 2, 3, 4, 5, 6], on);
}

void main() {
  const planner = ReadingPlanner(schedule: diaspora);
  const engine = StreakEngine(planner: planner);

  test('the worked example week from the design research', () {
    // Noach 5787: Sunday 11 Oct – Friday 16 Oct 2026, read Shabbat 17 Oct.
    final log = Log(planner)
      ..read('2026-10-12', [0], '2026-10-11') // Sunday: Rishon
      ..read('2026-10-12', [1, 2], '2026-10-13') // Tuesday: Sheni + Shlishi
      ..read('2026-10-12', [3], '2026-10-15') // Thursday: Revi'i only
      ..read('2026-10-12', [4, 5], '2026-10-16') // Friday: Chamishi + Shishi
      ..read('2026-10-12', [6], '2026-10-17'); // Shabbat, logged afterwards

    final s = engine.evaluate(progress: log.map, joinDate: d('2026-10-11'), today: d('2026-10-18'));
    expect(s.days[d('2026-10-11')], DayStatus.kept);
    expect(s.days[d('2026-10-12')], DayStatus.caughtUp);
    expect(s.days[d('2026-10-13')], DayStatus.kept);
    expect(s.days[d('2026-10-14')], DayStatus.grace);
    expect(s.days[d('2026-10-15')], DayStatus.kept);
    expect(s.days[d('2026-10-16')], DayStatus.kept);
    expect(s.days.containsKey(d('2026-10-17')), isFalse, reason: 'Shabbat is never a plan day');
    expect(s.weeks.first.status, WeekStatus.onTime);
    expect(s.daysOnTrack, 5);
    expect(s.parshaStreak, 1);
    expect(s.graceBalance, 2, reason: 'one used, one earned for finishing on time');
  });

  test('reading ahead never costs anything', () {
    final log = Log(planner)..readAll('2026-10-12', '2026-10-11');
    final s = engine.evaluate(progress: log.map, joinDate: d('2026-10-11'), today: d('2026-10-16'));
    expect(s.days[d('2026-10-11')], DayStatus.kept);
    for (final day in ['2026-10-12', '2026-10-13', '2026-10-14', '2026-10-15', '2026-10-16']) {
      expect(s.days[d(day)], DayStatus.ahead, reason: day);
    }
    expect(s.daysOnTrack, 6);
    expect(s.weeks.last.status, WeekStatus.onTime);
  });

  test('today and not-yet-final days are open and do not reset the streak', () {
    final log = Log(planner)..read('2026-10-12', [0], '2026-10-11');
    final s = engine.evaluate(progress: log.map, joinDate: d('2026-10-11'), today: d('2026-10-13'));
    expect(s.days[d('2026-10-12')], DayStatus.open);
    expect(s.days[d('2026-10-13')], DayStatus.open);
    expect(s.daysOnTrack, 1);
    expect(s.weeks.last.status, WeekStatus.inProgress);
  });

  test('at most two grace days per week; a third missed day resets the count', () {
    final log = Log(planner)
      ..read('2026-10-12', [0], '2026-10-11')
      ..read('2026-10-12', [6], '2026-10-16');
    final s = engine.evaluate(progress: log.map, joinDate: d('2026-10-11'), today: d('2026-10-18'));
    final statuses = [for (var i = 12; i <= 15; i++) s.days[d('2026-10-$i')]];
    expect(statuses.where((x) => x == DayStatus.grace), hasLength(2));
    expect(statuses.where((x) => x == DayStatus.missed), hasLength(2));
    expect(s.days[d('2026-10-16')], DayStatus.kept);
    expect(s.daysOnTrack, 1, reason: 'reset by the missed days, then Friday kept');
  });

  test('late completion (by Tuesday) continues the parsha streak', () {
    final log = Log(planner)
      ..readAll('2026-10-12', '2026-10-16') // Noach on time
      ..readAll('2026-10-19', '2026-10-27'); // Lech Lecha finished Tuesday after
    final s = engine.evaluate(progress: log.map, joinDate: d('2026-10-11'), today: d('2026-10-28'));
    expect(s.weeks[0].status, WeekStatus.onTime);
    expect(s.weeks[1].status, WeekStatus.late);
    expect(s.parshaStreak, 2);
  });

  test('a missed week can be restored by doubling up once per book', () {
    final log = Log(planner)
      ..readAll('2026-10-12', '2026-10-16') // Noach on time
      ..readAll('2026-10-19', '2026-10-29') // Lech Lecha: after the late deadline...
      ..readAll('2026-10-26', '2026-10-30'); // ...but Vayera done by its Shabbat too
    final s = engine.evaluate(progress: log.map, joinDate: d('2026-10-11'), today: d('2026-11-01'));
    expect(s.weeks[1].status, WeekStatus.restored);
    expect(s.weeks[2].status, WeekStatus.onTime);
    expect(s.parshaStreak, 3);
    expect(s.restoreAvailable, isFalse, reason: 'the token for Bereshit is used');
  });

  test('an unfinished week past its deadline is overdue, then missed', () {
    final log = Log(planner)..readAll('2026-10-12', '2026-10-16');
    var s = engine.evaluate(progress: log.map, joinDate: d('2026-10-11'), today: d('2026-10-28'));
    expect(s.weeks[1].status, WeekStatus.overdue);
    expect(s.parshaStreak, 1, reason: 'held while a restore is possible');
    s = engine.evaluate(progress: log.map, joinDate: d('2026-10-11'), today: d('2026-11-01'));
    expect(s.weeks[1].status, WeekStatus.missed);
    expect(s.parshaStreak, 0);
  });

  test('made-up portions count toward the siyum but not the streak', () {
    final log = Log(planner)
      ..readAll('2026-10-12', '2026-10-16')
      ..readAll('2026-10-19', '2026-11-05');
    final s = engine.evaluate(progress: log.map, joinDate: d('2026-10-11'), today: d('2026-11-08'));
    expect(s.weeks[1].status, WeekStatus.madeUp);
    expect(s.weeks[1].status.isComplete, isTrue);
  });

  test('paused days and weeks neither count nor break', () {
    final log = Log(planner)..readAll('2026-10-12', '2026-10-16');
    final s = engine.evaluate(
      progress: log.map,
      joinDate: d('2026-10-11'),
      today: d('2026-11-01'),
      pauses: [Pause(d('2026-10-18'), d('2026-10-24'))],
    );
    expect(s.days[d('2026-10-19')], DayStatus.paused);
    expect(s.weeks[1].status, WeekStatus.transparent);
    expect(s.parshaStreak, 1);
  });

  test('joining midweek: an unfinished first week is transparent', () {
    final s = engine.evaluate(progress: const {}, joinDate: d('2026-10-14'), today: d('2026-10-21'));
    expect(s.weeks.first.status, WeekStatus.transparent);
    expect(s.days.containsKey(d('2026-10-12')), isFalse);
  });

  test('joining midweek: what was planned before joining is never expected', () {
    // Joined on Wednesday of Noach, with the usual plan: Rishon to Shlishi
    // fell before joining. Nothing on Wednesday, then Revi'i and Chamishi on
    // Thursday: back on plan, as far as anything was planned since joining.
    final log = Log(planner)..read('2026-10-12', [3, 4], '2026-10-15');
    final s = engine.evaluate(progress: log.map, joinDate: d('2026-10-14'), today: d('2026-10-16'));
    expect(s.days[d('2026-10-14')], DayStatus.caughtUp);
    expect(s.days[d('2026-10-15')], DayStatus.kept);
    expect(s.days[d('2026-10-16')], DayStatus.open);
    expect(s.graceBalance, 2, reason: 'no grace day spent on the first day');
    expect(s.daysOnTrack, 2);
  });

  test('joining midweek: reading what was planned since joining is on plan', () {
    // Revi'i and Chamishi read on Wednesday, the day of joining: on plan
    // through Thursday without reading more.
    final log = Log(planner)..read('2026-10-12', [3, 4], '2026-10-14');
    final s = engine.evaluate(progress: log.map, joinDate: d('2026-10-14'), today: d('2026-10-16'));
    expect(s.days[d('2026-10-14')], DayStatus.kept);
    expect(s.days[d('2026-10-15')], DayStatus.ahead);
  });

  test('only the week of joining discounts what was planned before', () {
    // Joined on Wednesday of Noach; in Lech Lecha, the whole plan counts.
    final log = Log(planner)
      ..readAll('2026-10-12', '2026-10-14')
      ..read('2026-10-19', [0, 1, 2], '2026-10-18');
    final s = engine.evaluate(progress: log.map, joinDate: d('2026-10-14'), today: d('2026-10-23'));
    expect(s.days[d('2026-10-20')], DayStatus.ahead, reason: 'three aliyot read, three planned by Tuesday');
    expect(s.days[d('2026-10-21')], isNot(DayStatus.ahead), reason: 'four planned by Wednesday');
  });

  group('plans', () {
    test('Shevi\'i on Shabbat leaves the 7th aliyah for Shabbat morning', () {
      const p = ReadingPlanner(schedule: diaspora, type: ReadingPlanType.sheviiOnShabbat);
      final plan = p.planFor(diaspora.weekFor(d('2026-10-12')));
      expect(plan.days.map((x) => x.aliyot), [[0], [1], [2], [3], [4], [5]]);
      expect(plan.shabbatAliyot, [6]);
    });

    test('Erev Shabbat puts the whole portion on Friday', () {
      const p = ReadingPlanner(schedule: diaspora, type: ReadingPlanType.erevShabbat);
      final plan = p.planFor(diaspora.weekFor(d('2026-10-12')));
      expect(plan.days.single.date, d('2026-10-16'));
      expect(plan.days.single.aliyot, hasLength(7));
    });

    test('Tisha B\'Av is a quiet day by default', () {
      // Tisha B'Av 5787 is Thursday 12 August 2027.
      final plan = planner.planFor(diaspora.weekFor(d('2027-08-10')));
      expect(plan.days.map((x) => x.date), isNot(contains(d('2027-08-12'))));
      expect(plan.days.expand((x) => x.aliyot), [0, 1, 2, 3, 4, 5, 6]);
    });

    test('week ids are stable across the Israel/Diaspora switch for the same portion', () {
      const il = ParshaSchedule(israel: true);
      final a = diaspora.weekFor(d('2026-10-12'));
      final b = il.weekFor(d('2026-10-12'));
      expect(weekIdFor(a.portion, a.occasion), weekIdFor(b.portion, b.occasion));
      expect(weekIdFor(a.portion, a.occasion), '5787:2');
    });

    test('Vezot HaBerakhah belongs to the cycle that is ending', () {
      final w = diaspora.weekFor(d('2026-09-30'));
      expect(weekIdFor(w.portion, w.occasion), '5786:54');
    });
  });
}
