import '../../../core/calendar/hebrew_date.dart';
import '../../../core/calendar/jewish_holidays.dart';
import '../../../core/calendar/local_date.dart';
import '../../../core/calendar/parsha_schedule.dart';
import 'progress_models.dart';

/// How a user spreads the week's reading.
enum ReadingPlanType {
  /// One aliyah a day, Sunday–Thursday, and the 6th and 7th on Friday
  /// (the Vilna Gaon's practice, MB 285:8).
  aliyahPerDay,

  /// Aliyot 1–6 Sunday–Friday, the 7th on Shabbat morning before the meal,
  /// logged after Shabbat.
  sheviiOnShabbat,

  /// The whole portion on Friday (Arizal; Shulchan Aruch HaRav).
  erevShabbat,
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

/// Builds [WeekPlan]s from the calendar and the user's preferences.
class ReadingPlanner {
  const ReadingPlanner({
    required this.schedule,
    this.type = ReadingPlanType.aliyahPerDay,
    this.tishaBavQuiet = true,
    this.cholHamoedQuiet = false,
  });

  final ParshaSchedule schedule;
  final ReadingPlanType type;

  /// Tisha B'Av has no reading assigned (Torah study is restricted).
  final bool tishaBavQuiet;

  /// Chol HaMoed days have no reading assigned.
  final bool cholHamoedQuiet;

  bool get israel => schedule.israel;

  /// Shabbat, Yom Tov, or a day the user has chosen to keep free.
  bool isTransparentDay(LocalDate d) {
    if (JewishHolidays.isRestDay(d, israel: israel)) return true;
    if (tishaBavQuiet && JewishHolidays.isTishaBav(d)) return true;
    if (cholHamoedQuiet && JewishHolidays.isCholHamoed(HebrewDate.fromLocalDate(d), israel: israel)) return true;
    return false;
  }

  WeekPlan planFor(ReadingWeek week) {
    final id = weekIdFor(week.portion, week.occasion);
    final available = <LocalDate>[];
    if (week.portion.isVezotHaberakhah) {
      // One sitting, ideally on Hoshana Rabbah (MB 285:18).
      available.addAll(week.plan.map((a) => a.date));
    } else {
      var first = week.occasion.addDays(-6);
      if (first < week.start) first = week.start;
      for (var d = first; d < week.occasion; d = d.addDays(1)) {
        if (!isTransparentDay(d)) available.add(d);
      }
      if (available.isEmpty) available.add(week.plan.last.date);
    }

    if (week.portion.isVezotHaberakhah || type == ReadingPlanType.erevShabbat) {
      return WeekPlan(
        week: week,
        weekId: id,
        days: [PlanDay(available.last, const [0, 1, 2, 3, 4, 5, 6])],
        shabbatAliyot: const [],
      );
    }
    if (type == ReadingPlanType.sheviiOnShabbat && week.occasion.isShabbat) {
      return WeekPlan(
        week: week,
        weekId: id,
        days: divide(available, 6),
        shabbatAliyot: const [6],
      );
    }
    return WeekPlan(week: week, weekId: id, days: divide(available, kAliyot), shabbatAliyot: const []);
  }

  /// Spreads aliyot 0..count-1 over [days] in order. With as many days as
  /// aliyot (minus one) the last day takes two — the customary Friday double.
  static List<PlanDay> divide(List<LocalDate> days, int count) {
    if (days.length > count) days = days.sublist(days.length - count);
    final n = days.length;
    final base = count ~/ n;
    final extra = count % n;
    final out = <PlanDay>[];
    var next = 0;
    for (var i = 0; i < n; i++) {
      final size = base + (i >= n - extra ? 1 : 0);
      out.add(PlanDay(days[i], [for (var j = 0; j < size; j++) next + j]));
      next += size;
    }
    return out;
  }
}
