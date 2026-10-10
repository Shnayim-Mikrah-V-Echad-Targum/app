import '../../../core/calendar/hebrew_date.dart';
import '../../../core/calendar/jewish_holidays.dart';
import '../../../core/calendar/local_date.dart';
import '../../../core/calendar/parsha_schedule.dart';
import 'progress_models.dart';

/// Seconds to read one verse twice and its Targum once, for time estimates.
const kSecondsPerVerse = 25;

/// How a user spreads the week's reading.
enum ReadingPlanType {
  /// One aliyah a day, and two on the last day before Shabbat: usually
  /// Sunday–Thursday, and the 6th and 7th on Friday.
  aliyahPerDay,

  /// Aliyot 1–6 Sunday–Friday, the 7th on Shabbat morning before the meal,
  /// logged after Shabbat (the Vilna Gaon's practice, MB 285:8).
  sheviiOnShabbat,

  /// The whole portion on Friday: after Shacharit (Arizal), or after midday
  /// (Shelah; Shulchan Aruch HaRav).
  erevShabbat,
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

/// The settings that decide how reading weeks are planned and judged, in
/// force from [from] on. A change to them applies from the day it is made:
/// the days before stay planned and judged as they were, so that switching
/// plans or customs can never spend a grace day or break a streak after the
/// fact.
class PlanSettingsEntry {
  const PlanSettingsEntry({
    this.from = earliest,
    this.plan = ReadingPlanType.aliyahPerDay,
    this.tishaBavQuiet = true,
    this.cholHamoedQuiet = false,
    this.lateWindow = LateWindow.tuesday,
    this.haftarahRequired = false,
  });

  /// A [from] before any reading: settings that have always applied.
  static const earliest = LocalDate.fromRd(1);

  /// The first day these settings apply to.
  final LocalDate from;
  final ReadingPlanType plan;

  /// Tisha B'Av has no reading assigned (Torah study is restricted).
  final bool tishaBavQuiet;

  /// Chol HaMoed days have no reading assigned.
  final bool cholHamoedQuiet;
  final LateWindow lateWindow;

  /// Whether the haftarah must be read for the week to count as complete.
  final bool haftarahRequired;

  /// Whether [other] holds the same settings, whenever they applied from.
  bool sameSettingsAs(PlanSettingsEntry other) =>
      plan == other.plan &&
      tishaBavQuiet == other.tishaBavQuiet &&
      cholHamoedQuiet == other.cholHamoedQuiet &&
      lateWindow == other.lateWindow &&
      haftarahRequired == other.haftarahRequired;

  /// The same settings, applying from [from] on.
  PlanSettingsEntry startingOn(LocalDate from) => PlanSettingsEntry(
        from: from,
        plan: plan,
        tishaBavQuiet: tishaBavQuiet,
        cholHamoedQuiet: cholHamoedQuiet,
        lateWindow: lateWindow,
        haftarahRequired: haftarahRequired,
      );

  Map<String, dynamic> toJson() => {
        'from': from.rd,
        'plan': plan.name,
        'tishaBavQuiet': tishaBavQuiet,
        'cholHamoedQuiet': cholHamoedQuiet,
        'lateWindow': lateWindow.name,
        'haftarahRequired': haftarahRequired,
      };

  /// Reads an entry, tolerating missing or unknown values (which fall back
  /// to the defaults). Throws a [FormatException] if it has no day.
  factory PlanSettingsEntry.fromJson(Map<String, dynamic> j) {
    const d = PlanSettingsEntry();
    final from = j['from'];
    if (from is! int) throw FormatException('Plan settings without a day: $j');
    T e<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    bool b(String k, bool fallback) => j[k] is bool ? j[k] as bool : fallback;
    return PlanSettingsEntry(
      from: LocalDate.fromRd(from),
      plan: e(ReadingPlanType.values, j['plan'], d.plan),
      tishaBavQuiet: b('tishaBavQuiet', d.tishaBavQuiet),
      cholHamoedQuiet: b('cholHamoedQuiet', d.cholHamoedQuiet),
      lateWindow: e(LateWindow.values, j['lateWindow'], d.lateWindow),
      haftarahRequired: b('haftarahRequired', d.haftarahRequired),
    );
  }

  @override
  String toString() => 'PlanSettingsEntry(${toJson()})';
}

/// What a single day of the plan asks for.
class PlanDay {
  const PlanDay(this.date, this.aliyot);
  final LocalDate date;

  /// 0-based aliyah indices due on [date].
  final List<int> aliyot;

  @override
  String toString() => 'PlanDay($date, $aliyot)';
}

/// The user's plan for one reading week.
class WeekPlan {
  const WeekPlan({required this.week, required this.weekId, required this.days, required this.shabbatAliyot});

  final ReadingWeek week;
  final String weekId;

  /// Days with reading assigned, in order. Rest days and quiet days never
  /// appear here.
  final List<PlanDay> days;

  /// Aliyot planned for Shabbat morning (read from a printed Chumash).
  final List<int> shabbatAliyot;

  PortionId get portion => week.portion;

  /// Units (aliyah readings) the plan expects to be done by the end of [date].
  int targetUnitsBy(LocalDate date) =>
      3 * days.where((d) => d.date <= date).fold<int>(0, (n, d) => n + d.aliyot.length);

  PlanDay? dayFor(LocalDate date) {
    for (final d in days) {
      if (d.date == date) return d;
    }
    return null;
  }

  /// Aliyot due on or before [date].
  List<int> aliyotDueBy(LocalDate date) => [
        for (final d in days)
          if (d.date <= date) ...d.aliyot,
      ];
}

const _allAliyot = [0, 1, 2, 3, 4, 5, 6];

PlanSettingsEntry _defaultSettings(LocalDate day) => const PlanSettingsEntry();

/// Builds [WeekPlan]s from the calendar and the user's preferences.
class ReadingPlanner {
  const ReadingPlanner({
    required this.schedule,
    this._oneDayYomTov,
    this.settingsAt = _defaultSettings,
    this.starterFrom,
  });

  /// Which portion is read when: the reading heard in synagogue.
  final ParshaSchedule schedule;

  final bool? _oneDayYomTov;

  /// Whether Yom Tov is kept for one day, as in Israel, which decides the
  /// days that take no reading. It can differ from [schedule] (a visitor
  /// keeps their home custom); by default it follows it.
  bool get oneDayYomTov => _oneDayYomTov ?? schedule.israel;

  /// The plan settings in force on a day; by default, the default settings
  /// on every day. Each part of a week is planned by the settings in force
  /// then (see [planFor]), and the streak engine reads the late window and
  /// the haftarah rule from here too.
  final PlanSettingsEntry Function(LocalDate day) settingsAt;

  /// The day the reader started, to plan their first week from that day on
  /// (see [planFor]); null plans that week like any other.
  final LocalDate? starterFrom;

  /// This planner, with the reader's first week planned from [day] on (or,
  /// with null, like any other).
  ReadingPlanner startingFrom(LocalDate? day) =>
      ReadingPlanner(schedule: schedule, oneDayYomTov: _oneDayYomTov, settingsAt: settingsAt, starterFrom: day);

  /// Whether [d] takes no reading under [settings]: Shabbat, Yom Tov, or a
  /// day the user has chosen to keep free.
  bool _isTransparent(LocalDate d, PlanSettingsEntry settings) {
    if (JewishHolidays.isRestDay(d, israel: oneDayYomTov)) return true;
    if (settings.tishaBavQuiet && JewishHolidays.isTishaBav(d)) return true;
    if (settings.cholHamoedQuiet && JewishHolidays.isCholHamoed(HebrewDate.fromLocalDate(d), israel: oneDayYomTov)) {
      return true;
    }
    return false;
  }

  /// The plan for [week]: its aliyot spread over the reading days among the
  /// six before its public reading. In the week containing [starterFrom],
  /// only the days from then on are used, so that a reader who starts
  /// midweek finds the whole portion still ahead of them rather than half
  /// of it already due.
  ///
  /// The week is planned by the settings in force on its first planned day.
  /// If they change later in the week, the days before the change keep what
  /// they were given, and the aliyot left are spread over the days from the
  /// change on by the new settings, just as the week of joining is.
  WeekPlan planFor(ReadingWeek week) {
    final id = weekIdFor(week.portion, week.occasion);
    if (week.portion.isVezotHaberakhah) {
      // One sitting, ideally on Hoshana Rabbah (MB 285:18).
      return WeekPlan(
        week: week,
        weekId: id,
        days: [PlanDay(week.plan.last.date, _allAliyot)],
        shabbatAliyot: const [],
      );
    }

    var first = week.occasion.addDays(-6);
    if (first < week.start) first = week.start;
    final from = starterFrom;
    // With no reading day left after the start, plan the usual days.
    if (from != null &&
        from > first &&
        week.contains(from) &&
        _readingDays(from, week.occasion, settingsAt(from)).isNotEmpty) {
      first = from;
    }
    var settings = settingsAt(first);
    var available = _readingDays(first, week.occasion, settings).toList();
    if (available.isEmpty) available = [week.plan.last.date];
    var (days, shabbatAliyot) = _spread(week, available, settings.plan, 0);

    for (var d = first.addDays(1); d < week.occasion; d = d.addDays(1)) {
      final changed = settingsAt(d);
      if (changed.sameSettingsAs(settings)) continue;
      settings = changed;
      final kept = [
        for (final p in days)
          if (p.date < d) p,
      ];
      final next = kept.fold<int>(0, (n, p) => n + p.aliyot.length);
      final rest = _readingDays(d, week.occasion, settings).toList();
      // With every aliyah given a day already, or no day left to give the
      // rest, the plan stands.
      if (next == kAliyot || rest.isEmpty) continue;
      final (more, shabbat) = _spread(week, rest, settings.plan, next);
      days = [...kept, ...more];
      shabbatAliyot = shabbat;
    }
    return WeekPlan(week: week, weekId: id, days: days, shabbatAliyot: shabbatAliyot);
  }

  /// Spreads aliyot [firstAliyah] to the last over [days] as [type] does:
  /// the days planned, and the aliyot left for Shabbat morning.
  (List<PlanDay>, List<int>) _spread(ReadingWeek week, List<LocalDate> days, ReadingPlanType type, int firstAliyah) {
    switch (type) {
      case ReadingPlanType.erevShabbat:
        return ([PlanDay(days.last, _allAliyot.sublist(firstAliyah))], const []);
      case ReadingPlanType.sheviiOnShabbat when week.occasion.isShabbat:
        final beforeShabbat = kAliyot - 1 - firstAliyah;
        return (beforeShabbat > 0 ? divide(days, beforeShabbat, first: firstAliyah) : const [], const [kAliyot - 1]);
      case _:
        return (divide(days, kAliyot - firstAliyah, first: firstAliyah), const []);
    }
  }

  /// The days from [first] up to (not including) [end] that can take reading.
  Iterable<LocalDate> _readingDays(LocalDate first, LocalDate end, PlanSettingsEntry settings) sync* {
    for (var d = first; d < end; d = d.addDays(1)) {
      if (!_isTransparent(d, settings)) yield d;
    }
  }

  /// Spreads [count] aliyot, numbered from [first], over [days] in order.
  /// With as many days as aliyot (minus one) the last day takes two — the
  /// customary Friday double.
  static List<PlanDay> divide(List<LocalDate> days, int count, {int first = 0}) {
    if (days.length > count) days = days.sublist(days.length - count);
    final n = days.length;
    final base = count ~/ n;
    final extra = count % n;
    final out = <PlanDay>[];
    var next = first;
    for (var i = 0; i < n; i++) {
      final size = base + (i >= n - extra ? 1 : 0);
      out.add(PlanDay(days[i], [for (var j = 0; j < size; j++) next + j]));
      next += size;
    }
    return out;
  }
}
