import 'dart:math' as math;

import 'package:timezone/timezone.dart' as tz;

import '../core/calendar/city.dart';
import '../core/calendar/jewish_holidays.dart';
import '../core/calendar/local_date.dart';
import '../core/calendar/zmanim.dart';
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

/// No reminder on Erev Shabbat or Erev Yom Tov after this time when
/// candle-lighting isn't known (no city is chosen), nor on Erev Tisha B'Av.
/// Conservative on purpose: a reminder must never arrive on Shabbat or Yom
/// Tov.
const kErevCutoffMinutes = 12 * 60;

/// The latest the Erev Shabbat reminder comes when candle-lighting isn't
/// known: half an hour before [kErevCutoffMinutes].
const kErevShabbatLatestMinutes = kErevCutoffMinutes - 30;

/// A day's Shabbat times in the reader's city, in minutes after its
/// midnight: candle-lighting, and Havdalah (nightfall), 1440 or more when
/// that is after the next midnight. Either is null where it can't be given:
/// where the sun doesn't set or the sky doesn't get dark enough, and on a
/// day the device's clock isn't the city's (see [reminderZmanim]).
typedef ReminderZmanim = ({int? candles, int? havdalah});

/// With candle-lighting known, nothing on the eve of Shabbat or Yom Tov from
/// this many minutes before it.
const kCutoffBeforeCandles = 60;

/// With candle-lighting known, the daily reminder on the eve of Shabbat or
/// Yom Tov comes this many minutes before it at the latest: half an hour
/// before the cutoff, as the Erev Shabbat reminder without a city.
const kDailyBeforeCandles = 90;

/// With candle-lighting known, the Erev Shabbat reminder comes this many
/// minutes before it at the latest, with time left to finish.
const kErevShabbatBeforeCandles = 180;

/// With Havdalah known, the check-in comes this many minutes after it, on
/// Motzaei Shabbat, unless that is after [kCheckInLatestMinutes].
const kCheckInAfterHavdalah = 60;

/// The latest the check-in comes on Motzaei Shabbat: after this, it waits
/// for the morning.
const kCheckInLatestMinutes = 22 * 60 + 30;

/// The Shabbat times of [city], for [planReminders]. On a day the device's
/// clock differs from the city's, as when travelling with the city left
/// behind, there are none, and the planner keeps to its rules for when no
/// city is chosen. [deviceOffset] stands in for the device's offset from
/// UTC on a day, for tests.
///
/// Needs the time-zone database, which it loads if no one has.
ReminderZmanim Function(LocalDate) reminderZmanim(City city, {Duration Function(LocalDate date)? deviceOffset}) {
  final location = Zmanim.timeZone(city.timeZone);
  final offset = deviceOffset ?? (d) => DateTime(d.year, d.month, d.day, 12).timeZoneOffset;
  return (date) {
    // Clocks change at night, so noon tells the day's offset.
    if (location == null ||
        tz.TZDateTime(location, date.year, date.month, date.day, 12).timeZoneOffset != offset(date)) {
      return (candles: null, havdalah: null);
    }
    final z = Zmanim.of(city, date);
    return (candles: z.minutesOf(z.candleLighting), havdalah: z.minutesOf(z.havdalah));
  };
}

/// Plans the reminders for the next [days] days. Pure: depends only on its
/// inputs, so it's easy to test and to recompute whenever anything changes.
///
/// Rules (see docs/research/streaks_ux.md §10.10):
///  * never on Shabbat or Yom Tov, nor on their eve after midday;
///  * nothing after midday on Erev Tisha B'Av, when Torah study stops;
///  * at most one a day — Erev Shabbat > after-Shabbat check-in > daily;
///  * daily reminders only on planned days whose reading isn't done yet;
///  * nothing during a pause, and after a pause that runs past the [days]
///    ahead, [days] more of them from its end;
///  * after the last of them, one message that reminders have paused. Every
///    app open plans again, so only someone away for that long sees it.
///
/// With the Shabbat times of the reader's city, [zmanim], the eve's rules
/// follow candle-lighting rather than midday:
///  * nothing from [kCutoffBeforeCandles] before it;
///  * a daily reminder set later comes [kDailyBeforeCandles] before it;
///  * the Erev Shabbat reminder comes [kErevShabbatBeforeCandles] before it
///    at the latest;
///  * the check-in comes [kCheckInAfterHavdalah] after Shabbat ends (or the
///    Yom Tov that follows it), unless that is after
///    [kCheckInLatestMinutes], when it comes the next morning as without
///    them.
List<PlannedReminder> planReminders({
  required ReminderPrefs prefs,
  required ReadingPlanner planner,
  required WeekProgress Function(String weekId) progressOf,
  required DateTime now,
  required LocalDate today,
  List<Pause> pauses = const [],
  ReminderZmanim Function(LocalDate date)? zmanim,
  int days = 14,
}) {
  bool rest(LocalDate d) => JewishHolidays.isRestDay(d, israel: planner.oneDayYomTov);
  bool paused(LocalDate d) => pauses.any((p) => p.contains(d));
  final nowMinutes = now.hour * 60 + now.minute;
  final civilToday = LocalDate.fromDateTime(now);

  final times = <LocalDate, ReminderZmanim>{};
  ReminderZmanim? timesOf(LocalDate d) => zmanim == null ? null : times.putIfAbsent(d, () => zmanim(d));

  /// Candle-lighting on [d] if it is the eve of Shabbat or Yom Tov and the
  /// time is known.
  int? candlesOn(LocalDate d) => rest(d.addDays(1)) ? timesOf(d)?.candles : null;

  /// The time from which nothing comes on [d], the eve of Shabbat or Yom Tov.
  int cutoffOn(LocalDate d) {
    final candles = candlesOn(d);
    return candles == null ? kErevCutoffMinutes : candles - kCutoffBeforeCandles;
  }

  /// Whether the calendar has room for a reminder at [minutes] on [date].
  /// One [afterRest] may come on the last day of Shabbat or Yom Tov, once it
  /// has ended.
  bool fits(LocalDate date, int minutes, {bool afterRest = false}) {
    if (paused(date)) return false;
    if (rest(date)) {
      final havdalah = afterRest ? timesOf(date)?.havdalah : null;
      if (havdalah == null || minutes < havdalah) return false;
    }
    if (rest(date.addDays(1)) && minutes >= cutoffOn(date)) return false;
    if (JewishHolidays.isTishaBav(date.addDays(1)) && minutes >= kErevCutoffMinutes) return false;
    return true;
  }

  bool allowed(LocalDate date, int minutes, {bool afterRest = false}) {
    if (date < civilToday || (date == civilToday && minutes <= nowMinutes)) return false;
    return fits(date, minutes, afterRest: afterRest);
  }

  /// The daily reminder's time on [d]: the reader's, or earlier on the eve
  /// of Shabbat or Yom Tov, to come before candle-lighting.
  int dailyAt(LocalDate d) {
    final candles = candlesOn(d);
    if (candles == null) return prefs.dailyMinutes;
    return math.max(0, math.min(prefs.dailyMinutes, candles - kDailyBeforeCandles));
  }

  final byDay = <LocalDate, PlannedReminder>{};
  void offer(PlannedReminder r) {
    if (!allowed(r.date, r.minutes, afterRest: r.kind == ReminderKind.checkIn)) return;
    final existing = byDay[r.date];
    if (existing == null || _priority(r.kind) > _priority(existing.kind)) byDay[r.date] = r;
  }

  // A pause chosen for longer than the horizon moves it on: reminders
  // resume when the pause ends, rather than the message that they have
  // paused coming first.
  var end = today.addDays(days);
  for (var moved = true; moved;) {
    moved = false;
    for (final p in pauses) {
      if (p.contains(end)) {
        end = p.end.addDays(days);
        moved = true;
      }
    }
  }
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
            minutes: dailyAt(day.date),
            plan: plan,
            aliyot: day.aliyot,
          ));
        }
      }
    }

    if (prefs.erevShabbat && !progress.isComplete && plan.days.isNotEmpty && !week.portion.isVezotHaberakhah) {
      final last = plan.days.last.date;
      final candles = candlesOn(last);
      offer(PlannedReminder(
        kind: ReminderKind.erevShabbat,
        date: last,
        minutes: candles == null
            ? prefs.erevShabbatMinutes.clamp(0, kErevShabbatLatestMinutes)
            : math.max(0, math.min(prefs.erevShabbatMinutes, candles - kErevShabbatBeforeCandles)),
        plan: plan,
      ));
    }

    if (prefs.checkIn && !progress.isComplete && week.occasion.isShabbat) {
      var after = week.occasion.addDays(1);
      while (rest(after)) {
        after = after.addDays(1);
      }
      // On Motzaei Shabbat, or at the end of a Yom Tov that follows it, when
      // that is known and not too late; otherwise the next morning. Chosen
      // by the calendar alone: once the evening's has been sent, a plan made
      // later that evening must not send the morning's too.
      final lastRest = after.addDays(-1);
      final havdalah = timesOf(lastRest)?.havdalah;
      final evening = havdalah == null ? null : havdalah + kCheckInAfterHavdalah;
      offer(evening != null && evening <= kCheckInLatestMinutes && fits(lastRest, evening, afterRest: true)
          ? PlannedReminder(kind: ReminderKind.checkIn, date: lastRest, minutes: evening, plan: plan)
          : PlannedReminder(kind: ReminderKind.checkIn, date: after, minutes: prefs.checkInMinutes, plan: plan));
    }

    week = planner.schedule.nextWeek(week);
  }

  if (prefs.daily || prefs.erevShabbat || prefs.checkIn) {
    // After the horizon and after every other reminder (an Erev Shabbat or
    // check-in can fall just past the horizon), so that it is the last.
    var date = byDay.keys.fold(end, (LocalDate last, d) => d > last ? d : last).addDays(1);
    while (!allowed(date, dailyAt(date))) {
      date = date.addDays(1);
    }
    offer(PlannedReminder(
      kind: ReminderKind.paused,
      date: date,
      minutes: dailyAt(date),
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
