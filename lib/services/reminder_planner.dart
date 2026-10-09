import '../core/calendar/jewish_holidays.dart';
import '../core/calendar/local_date.dart';
import '../features/progress/domain/progress_models.dart';
import '../features/progress/domain/reading_plan.dart';

enum ReminderKind { daily, erevShabbat, checkIn }

/// A reminder to be scheduled on the device.
class PlannedReminder {
  const PlannedReminder({
    required this.kind,
    required this.date,
    required this.minutes,
    required this.plan,
    this.aliyot = const [],
  });

  final ReminderKind kind;
  final LocalDate date;

  /// Minutes after local midnight.
  final int minutes;

  /// The week the reminder is about.
  final WeekPlan plan;

  /// For daily reminders: the aliyot due that day.
  final List<int> aliyot;

  /// Stable, unique per day and kind.
  int get id => date.rd * 10 + kind.index;

  DateTime get localDateTime => DateTime(date.year, date.month, date.day, minutes ~/ 60, minutes % 60);

  @override
  String toString() => 'PlannedReminder($kind, $date ${minutes ~/ 60}:${minutes % 60})';
}

/// Settings that affect reminders.
class ReminderPrefs {
  const ReminderPrefs({
    this.daily = false,
    this.dailyMinutes = 20 * 60,
    this.erevShabbat = false,
    this.erevShabbatMinutes = 10 * 60,
    this.checkIn = false,
    this.checkInMinutes = 9 * 60 + 30,
  });

  final bool daily;
  final int dailyMinutes;
  final bool erevShabbat;
  final int erevShabbatMinutes;
  final bool checkIn;
  final int checkInMinutes;
}

/// No reminder on Erev Shabbat or Erev Yom Tov after this time, since
/// candle-lighting time isn't known without a location. Conservative on
/// purpose: a reminder must never arrive on Shabbat or Yom Tov.
const kErevCutoffMinutes = 12 * 60;

/// Plans the reminders for the next [days] days. Pure: depends only on its
/// inputs, so it's easy to test and to recompute whenever anything changes.
///
/// Rules (see docs/research/streaks_ux.md §10.10):
///  * never on Shabbat or Yom Tov, nor on their eve after midday;
///  * at most one a day — Erev Shabbat > after-Shabbat check-in > daily;
///  * daily reminders only on planned days whose reading isn't done yet;
///  * nothing during a pause.
List<PlannedReminder> planReminders({
  required ReminderPrefs prefs,
  required ReadingPlanner planner,
  required WeekProgress Function(String weekId) progressOf,
  required DateTime now,
  required LocalDate today,
  List<Pause> pauses = const [],
  int days = 14,
}) {
  bool rest(LocalDate d) => JewishHolidays.isRestDay(d, israel: planner.oneDayYomTov);
  bool paused(LocalDate d) => pauses.any((p) => p.contains(d));
  final nowMinutes = now.hour * 60 + now.minute;
  final civilToday = LocalDate.fromDateTime(now);

  final byDay = <LocalDate, PlannedReminder>{};
  void offer(PlannedReminder r) {
    if (rest(r.date) || paused(r.date)) return;
    if (r.date < civilToday || (r.date == civilToday && r.minutes <= nowMinutes)) return;
    if (rest(r.date.addDays(1)) && r.minutes >= kErevCutoffMinutes) return;
    final existing = byDay[r.date];
    if (existing == null || _priority(r.kind) > _priority(existing.kind)) byDay[r.date] = r;
  }

  final end = today.addDays(days);
  // Start a week back: last week's after-Shabbat check-in may be due today.
  var week = planner.schedule.previousWeek(planner.schedule.weekFor(today));
  while (week.start <= end) {
    final plan = planner.planFor(week);
    final progress = progressOf(plan.weekId);

    if (prefs.daily) {
      for (final day in plan.days) {
        if (day.date < today || day.date > end) continue;
        final done = day.aliyot.every(progress.isAliyahDone);
        if (!done) {
          offer(PlannedReminder(
            kind: ReminderKind.daily,
            date: day.date,
            minutes: prefs.dailyMinutes,
            plan: plan,
            aliyot: day.aliyot,
          ));
        }
      }
    }

    if (prefs.erevShabbat && !progress.isComplete && plan.days.isNotEmpty && !week.portion.isVezotHaberakhah) {
      final last = plan.days.last.date;
      offer(PlannedReminder(
        kind: ReminderKind.erevShabbat,
        date: last,
        minutes: prefs.erevShabbatMinutes.clamp(0, kErevCutoffMinutes - 30),
        plan: plan,
      ));
    }

    if (prefs.checkIn && !progress.isComplete && week.occasion.isShabbat) {
      var after = week.occasion.addDays(1);
      while (rest(after)) {
        after = after.addDays(1);
      }
      offer(PlannedReminder(kind: ReminderKind.checkIn, date: after, minutes: prefs.checkInMinutes, plan: plan));
    }

    week = planner.schedule.nextWeek(week);
  }

  return byDay.values.toList()..sort((a, b) => a.localDateTime.compareTo(b.localDateTime));
}

int _priority(ReminderKind k) => switch (k) {
      ReminderKind.erevShabbat => 3,
      ReminderKind.checkIn => 2,
      ReminderKind.daily => 1,
    };
