import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/features/progress/domain/parsha_standing.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/features/progress/domain/streak_engine.dart';

/// The one set of rules behind the Torah map and the year bar.
void main() {
  WeekEvaluation evaluation(int number, LocalDate occasion, WeekStatus status, {bool combined = false}) {
    final portion = PortionId(number, combined: combined);
    final week =
        ReadingWeek(portion: portion, occasion: occasion, start: occasion.addDays(-6), plan: const [], israel: false);
    return WeekEvaluation(
      WeekPlan(week: week, weekId: weekIdFor(portion, occasion), days: const [], shabbatAliyot: const []),
      status,
      null,
    );
  }

  // Shabbatot of 5787, from Bereshit on 10 October 2026.
  LocalDate shabbat(int n) => LocalDate(2026, 10, 10).addDays(7 * (n - 1));

  test('each week as it ended, then this week, made-up, missed, overdue, upcoming and untracked', () {
    final standings = parshaStandings(
      weeks: [
        evaluation(1, shabbat(1), WeekStatus.onTime),
        evaluation(2, shabbat(2), WeekStatus.late),
        evaluation(3, shabbat(3), WeekStatus.restored),
        evaluation(4, shabbat(4), WeekStatus.madeUp),
        // Missed, then finished later in the year.
        evaluation(5, shabbat(5), WeekStatus.missed),
        evaluation(6, shabbat(6), WeekStatus.missed),
        evaluation(7, shabbat(7), WeekStatus.overdue),
        evaluation(8, shabbat(8), WeekStatus.transparent),
        // A week of last year's cycle is not this year's.
        evaluation(9, LocalDate(2025, 11, 22), WeekStatus.onTime),
      ],
      cycle: 5787,
      done: {1, 2, 3, 4, 5},
      current: const PortionId(10),
    );
    expect(standings, hasLength(kParshaCount));
    expect(standings.sublist(0, 11), [
      ParshaStanding.onTime,
      ParshaStanding.late,
      ParshaStanding.restored,
      ParshaStanding.madeUp,
      ParshaStanding.madeUp,
      ParshaStanding.missed,
      ParshaStanding.overdue,
      ParshaStanding.untracked,
      ParshaStanding.untracked,
      ParshaStanding.inProgress,
      ParshaStanding.upcoming,
    ]);
    expect(standings.skip(10), everyElement(ParshaStanding.upcoming));
  });

  test("a parsha's last week in the cycle wins", () {
    // Overdue on Sunday, then finished late on Tuesday.
    final standings = parshaStandings(
      weeks: [evaluation(1, shabbat(1), WeekStatus.overdue), evaluation(1, shabbat(1), WeekStatus.late)],
      cycle: 5787,
      done: {1},
      current: const PortionId(2),
    );
    expect(standings.first, ParshaStanding.late);
  });

  test('a double portion stands as one in both its parshiyot', () {
    const vayakhelPekudei = PortionId(22, combined: true);
    expect(
      parshaStandings(weeks: const [], cycle: 5787, done: const {}, current: vayakhelPekudei).sublist(20, 24),
      [ParshaStanding.untracked, ParshaStanding.inProgress, ParshaStanding.inProgress, ParshaStanding.upcoming],
    );
    expect(
      parshaStandings(weeks: const [], cycle: 5787, done: const {22, 23}, current: vayakhelPekudei).sublist(21, 23),
      [ParshaStanding.onTime, ParshaStanding.onTime],
    );
    final restored = parshaStandings(
      weeks: [evaluation(22, LocalDate(2027, 3, 6), WeekStatus.restored, combined: true)],
      cycle: 5787,
      done: const {22, 23},
      current: const PortionId(24),
    );
    expect(restored.sublist(21, 23), [ParshaStanding.restored, ParshaStanding.restored]);
  });
}
