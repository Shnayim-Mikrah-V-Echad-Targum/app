import 'dart:math' as math;

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
    this.afterYomTov = false,
    this.onYomTov = true,
    this.erevYomTov,
    this.endsWithYomTov = false,
  });

  final ReminderKind kind;
  final LocalDate date;

  /// Minutes after local midnight.
  final int minutes;

  /// The week the reminder is about.
  final WeekPlan plan;

  /// For daily reminders: the aliyot due that day.
  final List<int> aliyot;

  /// For a check-in after Shabbat: whether the days of rest it comes after
  /// run on into Yom Tov, as when Shavuot falls on the Sunday, so that it
  /// asks about both.
  final bool afterYomTov;

  /// For the check-in after Simchat Torah: whether that day was Yom Tov for
  /// the reader. It is not for one who keeps a single day of Yom Tov but
  /// hears the reading outside Israel, a day after theirs.
  final bool onYomTov;

  /// For the Erev Shabbat reminder: the Yom Tov that begins the evening it
  /// comes, when the days of rest begin with one rather than with Shabbat.
  final ErevYomTov? erevYomTov;

  /// For the Erev Shabbat reminder: whether the days of rest that begin that
  /// evening end with a Yom Tov, as when Shavuot follows Shabbat.
  final bool endsWithYomTov;

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

/// No reminder on Erev Shabbat or Erev Yom Tov due after this time when
/// candle-lighting isn't known (no city is chosen), nor on Erev Tisha B'Av.
/// Conservative on purpose: a reminder must never arrive on Shabbat or Yom
/// Tov. The hours between midday and Shabbat leave ample room for one
/// delivered late ([kMaxDeliveryDelay]).
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

/// With candle-lighting known, nothing arrives on the eve of Shabbat or Yom
/// Tov from this many minutes before it.
const kCutoffBeforeCandles = 60;

/// How late a reminder may arrive after the time it is due. Android delivers
/// the inexact alarms reminders are scheduled with (from Android 12, where
/// exact ones need a permission the app doesn't ask for) up to an hour late;
/// before Android 12 the app schedules exact ones, which need none (see
/// NotificationService). iOS and Windows deliver them on time.
///
/// With candle-lighting known, nothing is due from [kCutoffBeforeCandles]
/// plus this before it, so that a reminder an hour late still arrives in
/// time. On Android 9 to 11, an app the reader hardly opens can have even an
/// exact alarm held for up to two hours, and the reminders due latest on the
/// eve, [kDailyBeforeCandles] before candle-lighting, still arrive before it.
const kMaxDeliveryDelay = 60;

/// With candle-lighting known, the daily reminder on the eve of Shabbat or
/// Yom Tov is due this many minutes before it at the latest: half an hour
/// before the last time one may be due ([kCutoffBeforeCandles] and
/// [kMaxDeliveryDelay] before it), as the Erev Shabbat reminder without a
/// city comes half an hour before midday.
const kDailyBeforeCandles = kCutoffBeforeCandles + kMaxDeliveryDelay + 30;

/// With candle-lighting known, the Erev Shabbat reminder comes this many
/// minutes before it at the latest, with time left to finish.
const kErevShabbatBeforeCandles = 180;

/// The time, in minutes after midnight, from which nothing is due on the
/// eve of Shabbat or Yom Tov: [kCutoffBeforeCandles] and
/// [kMaxDeliveryDelay] before [candles], candle-lighting there, where it is
/// known, and otherwise [kErevCutoffMinutes], midday. The reminders keep to
/// it, and so does anything else the app would otherwise bring up then,
/// such as the offer of an update (lib/services/updates/).
int erevCutoffMinutes({int? candles}) =>
    candles == null ? kErevCutoffMinutes : candles - kCutoffBeforeCandles - kMaxDeliveryDelay;

/// With Havdalah known, the check-in comes this many minutes after it, on
/// Motzaei Shabbat, unless that is after [kCheckInLatestMinutes].
const kCheckInAfterHavdalah = 60;

/// The latest the check-in comes on Motzaei Shabbat: after this, it waits
/// for the morning.
const kCheckInLatestMinutes = 22 * 60 + 30;

/// The Shabbat times of [place], by the reader's customs, for
/// [planReminders]. On a day the device's clock differs from the city's, as
/// when travelling with the city left behind, there are none, and the
/// planner keeps to its rules for when no city is chosen. [deviceOffset]
/// stands in for the device's offset from UTC on a day, for tests.
///
/// Needs the time-zone database already in (`ensureTimeZones`; see
/// `timeZonesReady`): before then, every day reads as one on which the
/// device doesn't keep the city's clock, and has no times.
ReminderZmanim Function(LocalDate) reminderZmanim(ShabbatCity place,
    {Duration Function(LocalDate date) deviceOffset = deviceNoonOffset}) {
  return (date) {
    if (!Zmanim.keepsClock(place.city, date, deviceOffset(date))) return (candles: null, havdalah: null);
    final z = place.on(date);
    return (candles: z.minutesOf(z.candleLighting), havdalah: z.minutesOf(z.havdalah));
  };
}

/// Plans the reminders for the next [days] days. Pure: depends only on its
/// inputs, so it's easy to test and to recompute whenever anything changes.
///
/// Times are when a reminder is due; it may arrive up to
/// [kMaxDeliveryDelay] later.
///
/// Rules (see docs/research/streaks_ux.md §10.10):
///  * never on Shabbat or Yom Tov, nor on their eve after midday;
///  * nothing after midday on Erev Tisha B'Av, when Torah study stops, nor
///    on the fast while it has no reading planned; the check-in after a
///    Shabbat just before it comes the morning after it;
///  * at most one a day — Erev Shabbat > after-Shabbat check-in > daily;
///  * the Erev Shabbat reminder only on the last planned day straight before
///    the parsha's days of rest, named for the Yom Tov when one begins that
///    evening;
///  * the check-in only after a Shabbat whose parsha isn't finished, or
///    after Simchat Torah while Vezot HaBerachah isn't;
///  * daily reminders only on planned days whose reading isn't done yet;
///    on the eve of Shabbat or Yom Tov, one set for after midday comes at
///    [kErevShabbatLatestMinutes];
///  * nothing during a pause, and after a pause that runs past the [days]
///    ahead, [days] more of them from its end;
///  * after the last of them, one message that reminders have paused. Every
///    app open plans again, so only someone away for that long sees it.
///
/// With the Shabbat times of the reader's city, [zmanim], the eve's rules
/// follow candle-lighting rather than midday:
///  * nothing arrives from [kCutoffBeforeCandles] before it, even
///    [kMaxDeliveryDelay] late;
///  * a daily reminder set later comes [kDailyBeforeCandles] before it;
///  * the Erev Shabbat reminder comes [kErevShabbatBeforeCandles] before it
///    at the latest;
///  * the check-in comes [kCheckInAfterHavdalah] after Shabbat ends (or the
///    Yom Tov that follows it, or Simchat Torah), unless that is after
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

  /// The time from which nothing is due on [d], the eve of Shabbat or Yom
  /// Tov: with candle-lighting known, early enough for a reminder delivered
  /// late to arrive before the cutoff.
  int cutoffOn(LocalDate d) => erevCutoffMinutes(candles: candlesOn(d));

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
    // Nothing on the fast itself while it has no reading planned.
    if (planner.isQuietTishaBav(date)) return false;
    return true;
  }

  bool allowed(LocalDate date, int minutes, {bool afterRest = false}) {
    if (date < civilToday || (date == civilToday && minutes <= nowMinutes)) return false;
    return fits(date, minutes, afterRest: afterRest);
  }

  /// The daily reminder's time on [d]: the reader's, or earlier on the eve
  /// of Shabbat or Yom Tov, to come before candle-lighting. Without it, a
  /// daily reminder set later comes at 11:30 on the eve rather than not at
  /// all: on Hoshana Rabbah, the one reading day of Vezot HaBerachah, and on
  /// a Friday without the Erev Shabbat reminder.
  int dailyAt(LocalDate d) {
    final candles = candlesOn(d);
    if (candles != null) return math.max(0, math.min(prefs.dailyMinutes, candles - kDailyBeforeCandles));
    if (rest(d.addDays(1))) return math.min(prefs.dailyMinutes, kErevShabbatLatestMinutes);
    return prefs.dailyMinutes;
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
  // Or two, where that week is Bereshit, read on the Shabbat straight after
  // Simchat Torah: Vezot HaBerachah's check-in then comes after that Shabbat,
  // before Bereshit's, as Today asks it first.
  var week = planner.schedule.previousWeek(planner.schedule.weekFor(today));
  final beforeIt = planner.schedule.previousWeek(week);
  if (beforeIt.portion.isVezotHaberakhah) week = beforeIt;
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

    // On the last planned day, when nothing but days of rest lies between
    // it and the parsha's Shabbat: not where weekdays kept free (Chol
    // HaMoed) come between.
    final last = plan.days.lastOrNull?.date;
    if (prefs.erevShabbat &&
        !progress.isComplete &&
        last != null &&
        !week.portion.isVezotHaberakhah &&
        _onlyRestBetween(last, week.occasion, rest)) {
      final candles = candlesOn(last);
      offer(PlannedReminder(
        kind: ReminderKind.erevShabbat,
        date: last,
        minutes: candles == null
            ? prefs.erevShabbatMinutes.clamp(0, kErevShabbatLatestMinutes)
            : math.max(0, math.min(prefs.erevShabbatMinutes, candles - kErevShabbatBeforeCandles)),
        plan: plan,
        erevYomTov: JewishHolidays.erevYomTov(last, israel: planner.oneDayYomTov),
        endsWithYomTov: !JewishHolidays.lastRestDay(last.addDays(1), israel: planner.oneDayYomTov).isShabbat,
      ));
    }

    // After a Shabbat, and after Simchat Torah, the Yom Tov Vezot HaBerachah
    // is read on (MB 285:18), which Today asks about too. The day it comes is
    // the first Today asks on (firstDayToAskAfter): where Bereshit's Shabbat
    // follows Simchat Torah straight away, after that Shabbat, which takes
    // the place of Bereshit's own check-in that day.
    if (prefs.checkIn && !progress.isComplete && (week.occasion.isShabbat || week.portion.isVezotHaberakhah)) {
      // On Motzaei Shabbat, or at the end of a Yom Tov that follows it, when
      // that is known and not too late; otherwise the next morning, or the
      // one after Tisha B'Av, when its greeting is not given (Shulchan Aruch
      // OC 554:20), whatever is planned on the fast. Chosen by the calendar
      // alone: once the evening's has been sent, a plan made later that
      // evening must not send the morning's too. A Simchat Torah that is not
      // Yom Tov for the reader has no evening's: it is still the reading day
      // Vezot HaBerachah is read on, and Today asks the morning after.
      final lastRest = JewishHolidays.lastRestDay(week.occasion, israel: planner.oneDayYomTov);
      final havdalah = rest(lastRest) ? timesOf(lastRest)?.havdalah : null;
      final evening = havdalah == null ? null : havdalah + kCheckInAfterHavdalah;
      var morning = lastRest.addDays(1);
      while (JewishHolidays.isTishaBav(morning)) {
        morning = morning.addDays(1);
      }
      final afterYomTov = lastRest != week.occasion;
      final onYomTov = rest(week.occasion);
      offer(evening != null && evening <= kCheckInLatestMinutes && fits(lastRest, evening, afterRest: true)
          ? PlannedReminder(
              kind: ReminderKind.checkIn,
              date: lastRest,
              minutes: evening,
              plan: plan,
              afterYomTov: afterYomTov,
              onYomTov: onYomTov,
            )
          : PlannedReminder(
              kind: ReminderKind.checkIn,
              date: morning,
              minutes: prefs.checkInMinutes,
              plan: plan,
              afterYomTov: afterYomTov,
              onYomTov: onYomTov,
            ));
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

/// Whether every day after [from] and before [to] is a day of [rest].
bool _onlyRestBetween(LocalDate from, LocalDate to, bool Function(LocalDate) rest) {
  for (var d = from.addDays(1); d < to; d = d.addDays(1)) {
    if (!rest(d)) return false;
  }
  return true;
}

int _priority(ReminderKind k) => switch (k) {
      ReminderKind.erevShabbat => 3,
      ReminderKind.checkIn => 2,
      ReminderKind.daily => 1,
      ReminderKind.paused => 0,
    };
