import 'dart:math' as math;

import '../../../core/calendar/jewish_holidays.dart';
import '../../../core/calendar/local_date.dart';
import '../../../core/calendar/parsha_schedule.dart';
import 'progress_models.dart';
import 'reading_plan.dart';

/// Status of one planned reading day ("Days on track").
enum DayStatus {
  /// At least one aliyah's worth of reading (3 units) was logged that day,
  /// from any open portion — catch-up counts.
  kept,

  /// Nothing logged, but the portion was already at or ahead of plan.
  ahead,

  /// Behind at the end of the day, but back on plan by the end of the next
  /// planned day ("doubling up tomorrow repairs today").
  caughtUp,

  /// Covered automatically by a grace day.
  grace,

  /// Covered by a pause.
  paused,

  /// Not yet final (today, or awaiting the next day's catch-up).
  open,

  missed,
}

/// Status of one weekly portion ("Parsha streak").
enum WeekStatus {
  /// Finished by the Shabbat it is read (including on Shabbat itself).
  onTime,

  /// Finished by the late deadline ("until Wednesday", SA 285:4).
  late,

  /// Finished late, but together with the next portion by its Shabbat
  /// (one "double-up" per book of the Torah).
  restored,

  /// Finished later, before Simchat Torah. Counts toward the year's siyum
  /// but does not continue the streak.
  madeUp,

  /// Not finished in time; can still be made up until Simchat Torah.
  missed,

  /// Neither counts nor breaks the streak (paused, or a partial first week).
  transparent,

  /// Past the late deadline, but a double-up can still restore it.
  overdue,

  /// The current portion, not yet due.
  inProgress,
}

extension DayStatusX on DayStatus {
  bool get counts => this == DayStatus.kept || this == DayStatus.ahead || this == DayStatus.caughtUp;
}

extension WeekStatusX on WeekStatus {
  bool get counts => this == WeekStatus.onTime || this == WeekStatus.late || this == WeekStatus.restored;
  bool get breaks => this == WeekStatus.madeUp || this == WeekStatus.missed;
  bool get isComplete => counts || this == WeekStatus.madeUp;
}

/// How long after Shabbat a portion still counts as done (SA 285:4).
enum LateWindow {
  /// Until the end of Tuesday (the common reading of "until Wednesday").
  tuesday,

  /// Until the end of Wednesday.
  wednesday,

  /// No late window: only completion before Shabbat counts.
  none;

  int get daysAfterShabbat => switch (this) {
        LateWindow.tuesday => 3,
        LateWindow.wednesday => 4,
        LateWindow.none => 0,
      };
}

/// Rules for streak forgiveness.
abstract final class GraceRules {
  static const startingBalance = 2;
  static const maxBalance = 3;
  static const maxPerWeek = 2;
  static const unitsForKeptDay = 3;
}

class WeekEvaluation {
  const WeekEvaluation(this.plan, this.status, this.completedOn);
  final WeekPlan plan;
  final WeekStatus status;
  final LocalDate? completedOn;
}

/// The result of evaluating a user's whole history.
class StreakSummary {
  const StreakSummary({
    required this.parshaStreak,
    required this.longestParshaStreak,
    required this.daysOnTrack,
    required this.longestDaysOnTrack,
    required this.graceBalance,
    required this.days,
    required this.weeks,
    required this.restoreAvailable,
  });

  /// Consecutive portions completed on time, late or restored.
  final int parshaStreak;
  final int longestParshaStreak;

  /// Consecutive planned days kept, ahead or caught up.
  final int daysOnTrack;
  final int longestDaysOnTrack;

  /// Grace days available.
  final int graceBalance;

  /// Status of every evaluated planned day.
  final Map<LocalDate, DayStatus> days;

  /// Evaluated weeks in chronological order, ending with the current week.
  final List<WeekEvaluation> weeks;

  /// Whether a double-up restore is still available in the current book.
  final bool restoreAvailable;

  WeekEvaluation? get current => weeks.isEmpty ? null : weeks.last;

  static const empty = StreakSummary(
    parshaStreak: 0,
    longestParshaStreak: 0,
    daysOnTrack: 0,
    longestDaysOnTrack: 0,
    graceBalance: GraceRules.startingBalance,
    days: {},
    weeks: [],
    restoreAvailable: true,
  );
}

/// Computes streaks from the reading log. Pure and deterministic: the same
/// inputs always produce the same result, so grace days are "refunded"
/// automatically when a later entry fixes a day.
class StreakEngine {
  const StreakEngine({
    required this.planner,
    this.lateWindow = LateWindow.tuesday,
    this.haftarahRequired = false,
  });

  final ReadingPlanner planner;
  final LateWindow lateWindow;

  /// Whether the haftarah must be read for the week to count as complete.
  final bool haftarahRequired;

  ParshaSchedule get _schedule => planner.schedule;

  LocalDate lateDeadlineOf(ReadingWeek week) => week.portion.isVezotHaberakhah
      ? week.occasion
      : week.occasion.addDays(lateWindow.daysAfterShabbat);

  LocalDate makeUpDeadlineOf(WeekPlan plan) => JewishHolidays.simchatTorah(
        cycleYearOf(plan.portion, plan.week.occasion) + 1,
        israel: _schedule.israel,
      );

  StreakSummary evaluate({
    required Map<String, WeekProgress> progress,
    required LocalDate joinDate,
    required LocalDate today,
    List<Pause> pauses = const [],
  }) {
    if (today < joinDate) return StreakSummary.empty;
    bool paused(LocalDate d) => pauses.any((p) => p.contains(d));

    // Weeks from the one containing the join date through the current one,
    // plus the next (needed to judge catch-ups and restores).
    final plans = <WeekPlan>[];
    var week = _schedule.weekFor(joinDate);
    final currentOccasion = _schedule.weekFor(today).occasion;
    while (week.occasion <= currentOccasion) {
      plans.add(planner.planFor(week));
      week = _schedule.nextWeek(week);
    }
    final nextPlan = planner.planFor(week);

    final unitsByDay = <int, int>{};
    for (final p in progress.values) {
      for (final row in p.units) {
        for (final d in row) {
          if (d != null) unitsByDay[d.rd] = (unitsByDay[d.rd] ?? 0) + 1;
        }
      }
    }

    WeekProgress progressOf(WeekPlan plan) => progress[plan.weekId] ?? WeekProgress(weekId: plan.weekId);

    LocalDate? completionOf(WeekPlan plan) {
      final p = progressOf(plan);
      final done = p.completedOn;
      if (done == null) return null;
      if (!haftarahRequired) return done;
      final h = p.haftarah;
      if (h == null) return null;
      return h > done ? h : done;
    }

    final allDays = <(WeekPlan, PlanDay)>[
      for (final plan in [...plans, nextPlan])
        for (final d in plan.days) (plan, d),
    ];

    // Reading planned before the join date is never expected: in the week
    // the reader joined, targets count only what was planned from then on.
    final joinPlan = plans.first;
    final preJoin = joinPlan.targetUnitsBy(joinDate.addDays(-1));
    int sincePlanned(WeekPlan p, int units) => math.max(0, units - (identical(p, joinPlan) ? preJoin : 0));
    int target(WeekPlan p, LocalDate d) => sincePlanned(p, p.targetUnitsBy(d));

    var grace = GraceRules.startingBalance;
    final restoreUsed = <String>{};
    final dayStatus = <LocalDate, DayStatus>{};
    final evaluations = <WeekEvaluation>[];
    var dayIndex = 0;

    for (var w = 0; w < plans.length; w++) {
      final plan = plans[w];
      final wp = progressOf(plan);
      var graceUsedThisWeek = 0;

      // --- Days on track -------------------------------------------------
      for (; dayIndex < allDays.length && allDays[dayIndex].$1 == plan; dayIndex++) {
        final day = allDays[dayIndex].$2;
        final d = day.date;
        if (d < joinDate || d > today) continue;
        final next = dayIndex + 1 < allDays.length ? allDays[dayIndex + 1] : null;
        DayStatus status;
        if (paused(d)) {
          status = DayStatus.paused;
        } else if ((unitsByDay[d.rd] ?? 0) >= GraceRules.unitsForKeptDay) {
          status = DayStatus.kept;
        } else if (wp.unitsBy(d) >= target(plan, d)) {
          status = DayStatus.ahead;
        } else {
          final caughtUp = next != null &&
              wp.unitsBy(next.$2.date) >=
                  (next.$1 == plan ? target(plan, next.$2.date) : sincePlanned(plan, kAliyot * 3));
          if (caughtUp) {
            status = DayStatus.caughtUp;
          } else if (d == today || (next != null && today <= next.$2.date)) {
            status = DayStatus.open;
          } else if (grace > 0 && graceUsedThisWeek < GraceRules.maxPerWeek) {
            grace--;
            graceUsedThisWeek++;
            status = DayStatus.grace;
          } else {
            status = DayStatus.missed;
          }
        }
        dayStatus[d] = status;
      }

      // --- Parsha streak --------------------------------------------------
      final doneAt = completionOf(plan);
      final lateDeadline = lateDeadlineOf(plan.week);
      WeekStatus status;
      final starterWeek = plan.week.start < joinDate;
      final isPausedWeek = plan.days.isNotEmpty &&
          (paused(plan.days.last.date) || plan.days.where((d) => paused(d.date)).length * 2 >= plan.days.length);
      if (doneAt != null && doneAt <= plan.week.occasion) {
        status = WeekStatus.onTime;
      } else if (doneAt != null && doneAt <= lateDeadline) {
        status = WeekStatus.late;
      } else if (doneAt == null && today <= lateDeadline) {
        status = starterWeek && today > plan.week.occasion ? WeekStatus.transparent : WeekStatus.inProgress;
      } else if (doneAt == null && (starterWeek || isPausedWeek)) {
        status = WeekStatus.transparent;
      } else {
        // Missed the late deadline: a double-up may restore it.
        final next = w + 1 < plans.length ? plans[w + 1] : nextPlan;
        final tokenKey = '${cycleYearOf(plan.portion, plan.week.occasion)}:${_bookOf(plan.portion)}';
        final canRestore = !plan.portion.isVezotHaberakhah && !restoreUsed.contains(tokenKey);
        final nextDone = completionOf(next);
        if (canRestore && doneAt != null && nextDone != null && _max(doneAt, nextDone) <= next.week.occasion) {
          restoreUsed.add(tokenKey);
          status = WeekStatus.restored;
        } else if (canRestore && today <= next.week.occasion) {
          status = WeekStatus.overdue;
        } else if (doneAt != null && doneAt <= makeUpDeadlineOf(plan)) {
          status = WeekStatus.madeUp;
        } else {
          status = WeekStatus.missed;
        }
      }
      if (status == WeekStatus.onTime) grace = math.min(GraceRules.maxBalance, grace + 1);
      evaluations.add(WeekEvaluation(plan, status, doneAt));
    }

    // Streak counts.
    var daysRun = 0, daysBest = 0;
    final sortedDays = dayStatus.keys.toList()..sort();
    for (final d in sortedDays) {
      final s = dayStatus[d]!;
      if (s.counts) {
        daysRun++;
        daysBest = math.max(daysBest, daysRun);
      } else if (s == DayStatus.missed) {
        daysRun = 0;
      }
    }
    var weeksRun = 0, weeksBest = 0;
    for (final e in evaluations) {
      if (e.status.counts) {
        weeksRun++;
        weeksBest = math.max(weeksBest, weeksRun);
      } else if (e.status.breaks) {
        weeksRun = 0;
      }
    }

    final current = plans.last;
    final currentToken = '${cycleYearOf(current.portion, current.week.occasion)}:${_bookOf(current.portion)}';
    return StreakSummary(
      parshaStreak: weeksRun,
      longestParshaStreak: weeksBest,
      daysOnTrack: daysRun,
      longestDaysOnTrack: daysBest,
      graceBalance: grace,
      days: dayStatus,
      weeks: evaluations,
      restoreAvailable: !restoreUsed.contains(currentToken),
    );
  }

  static LocalDate _max(LocalDate a, LocalDate b) => a > b ? a : b;

  /// Book index (0–4) of a portion, from its parsha number.
  static int _bookOf(PortionId p) => bookIndexOfParsha(p.number);
}

/// Book of the Torah (0 = Genesis … 4 = Deuteronomy) containing parsha [n].
int bookIndexOfParsha(int n) {
  if (n <= 12) return 0;
  if (n <= 23) return 1;
  if (n <= 33) return 2;
  if (n <= 43) return 3;
  return 4;
}
