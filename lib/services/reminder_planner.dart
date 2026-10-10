import '../core/calendar/jewish_holidays.dart';
import '../core/calendar/local_date.dart';
import '../features/progress/domain/progress_models.dart';
import '../features/progress/domain/reading_plan.dart';

enum ReminderKind {
  daily,
  erevShabbat,
  checkIn,

  /// The last message when the app hasn't been opened for the whole planning
  /// horizon: reminders stop until it is opened again.
  paused,
}

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
///  * nothing after midday on Erev Tisha B'Av, when Torah study stops;
///  * at most one a day — Erev Shabbat > after-Shabbat check-in > daily;
///  * daily reminders only on planned days whose reading isn't done yet;
///  * nothing during a pause;
///  * after the last of them, one message that reminders have paused. Every
///    app open plans again, so only someone away for [days] days sees it.
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

  bool allowed(LocalDate date, int minutes) {
    if (rest(date) || paused(date)) return false;
    if (date < civilToday || (date == civilToday && minutes <= nowMinutes)) return false;
    final afternoon = minutes >= kErevCutoffMinutes;
    if (afternoon && (rest(date.addDays(1)) || JewishHolidays.isTishaBav(date.addDays(1)))) return false;
    return true;
  }

  final byDay = <LocalDate, PlannedReminder>{};
  void offer(PlannedReminder r) {
    if (!allowed(r.date, r.minutes)) return;
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

  if (prefs.daily || prefs.erevShabbat || prefs.checkIn) {
    // After the horizon and after every other reminder (an Erev Shabbat or
    // check-in can fall just past the horizon), so that it is the last.
    var date = byDay.keys.fold(end, (LocalDate last, d) => d > last ? d : last).addDays(1);
    while (!allowed(date, prefs.dailyMinutes)) {
      date = date.addDays(1);
    }
    offer(PlannedReminder(
      kind: ReminderKind.paused,
      date: date,
      minutes: prefs.dailyMinutes,
      plan: planner.planFor(planner.schedule.weekFor(today)),
    ));
  }

  return byDay.values.toList()..sort((a, b) => a.localDateTime.compareTo(b.localDateTime));
}

int _priority(ReminderKind k) => switch (k) {
      ReminderKind.erevShabbat => 3,
      ReminderKind.checkIn => 2,
      ReminderKind.daily => 1,
      ReminderKind.paused => 0,
    };
