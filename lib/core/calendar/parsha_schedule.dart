import 'hebrew_date.dart';
import 'jewish_holidays.dart';
import 'local_date.dart';
import 'parsha_table.g.dart';

/// Number of weekly portions, Bereshit (1) through Vezot HaBerachah (54).
const int kParshaCount = 54;
const int kVezotHaberakhah = 54;

/// Identifies one weekly reading: a single parsha, or two read together.
class PortionId {
  const PortionId(this.number, {this.combined = false})
      : assert(number >= 1 && number <= kParshaCount);

  /// Parses the form produced by [key]: `"22"` or `"22-23"`.
  factory PortionId.parse(String key) {
    final parts = key.split('-');
    return PortionId(int.parse(parts.first), combined: parts.length == 2);
  }

  /// 1-based parsha number (the first of the pair when [combined]).
  final int number;
  final bool combined;

  List<int> get parshiyot => combined ? [number, number + 1] : [number];

  String get key => combined ? '$number-${number + 1}' : '$number';

  bool get isVezotHaberakhah => number == kVezotHaberakhah;

  @override
  bool operator ==(Object other) =>
      other is PortionId && other.number == number && other.combined == combined;

  @override
  int get hashCode => Object.hash(number, combined);

  @override
  String toString() => 'PortionId($key)';
}

/// A day on which a portion is read publicly: a Shabbat, or Simchat Torah for
/// Vezot HaBerachah.
class ReadingOccasion {
  const ReadingOccasion(this.portion, this.date);

  final PortionId portion;
  final LocalDate date;

  @override
  bool operator ==(Object other) =>
      other is ReadingOccasion && other.portion == portion && other.date == date;

  @override
  int get hashCode => Object.hash(portion, date);

  @override
  String toString() => 'ReadingOccasion(${portion.key} on $date)';
}

/// One week of Shnayim Mikra: the period between the previous public reading
/// and this portion's public reading, with a suggested daily division.
class ReadingWeek {
  const ReadingWeek({
    required this.portion,
    required this.occasion,
    required this.start,
    required this.plan,
    required this.israel,
  });

  final PortionId portion;

  /// The day this portion is read in synagogue. Ideally Shnayim Mikra is
  /// finished before then (Shulchan Aruch OC 285:3–4).
  final LocalDate occasion;

  /// The first day of this reading period: the day after the previous
  /// portion's public reading.
  final LocalDate start;

  /// Suggested division by day, in date order. Each entry lists the 0-based
  /// aliyah indices (0–6) to read that day.
  final List<DailyAssignment> plan;

  final bool israel;

  /// A stable identifier for persisting progress.
  String get id => occasion.toIso();

  /// "Until Wednesday": the latest time one may still complete the portion
  /// after Shabbat in the usual sense (SA 285:4). Modeled as the end of
  /// Tuesday. For Vezot HaBerachah there is no later time.
  LocalDate get lateDeadline =>
      portion.isVezotHaberakhah ? occasion : occasion.addDays(3);

  bool contains(LocalDate date) => date >= start && date <= occasion;

  /// The assignment for [date], if it is one of the planned reading days.
  DailyAssignment? assignmentFor(LocalDate date) {
    for (final a in plan) {
      if (a.date == date) return a;
    }
    return null;
  }

  /// Aliyot (0-based) scheduled on or before [date].
  Set<int> aliyotDueBy(LocalDate date) => {
        for (final a in plan)
          if (a.date <= date) ...a.aliyot,
      };

  /// The last planned reading day (usually Friday).
  LocalDate get lastPlannedDay => plan.last.date;
}

class DailyAssignment {
  const DailyAssignment(this.date, this.aliyot);
  final LocalDate date;
  final List<int> aliyot;

  @override
  String toString() => 'DailyAssignment($date, $aliyot)';
}

/// Computes which portion is read when, for Israel or the Diaspora.
class ParshaSchedule {
  const ParshaSchedule({required this.israel});

  final bool israel;

  /// The portion read on [shabbat], or null if that Shabbat is a festival
  /// with its own reading.
  PortionId? portionOnShabbat(LocalDate shabbat) {
    assert(shabbat.isShabbat, '$shabbat is not a Shabbat');
    final year = HebrewDate.fromLocalDate(shabbat).year;
    final rh = HebrewDate.newYearRd(year);
    final firstShabbat = LocalDate.fromRd(rh).onOrAfter(6);
    final index = shabbat.differenceInDays(firstShabbat) ~/ 7;
    final key =
        '${rh % 7}_${HebrewDate.daysInYear(year)}_${israel ? 'il' : 'd'}';
    final row = parshaTable[key];
    if (row == null || index >= row.length) {
      throw StateError('No schedule for $shabbat ($key, #$index)');
    }
    final code = row[index];
    if (code == 0) return null;
    return code > 0 ? PortionId(code) : PortionId(-code, combined: true);
  }

  LocalDate _simchatTorahOnOrAfter(LocalDate date) {
    final year = HebrewDate.fromLocalDate(date).year;
    final st = JewishHolidays.simchatTorah(year, israel: israel);
    return st >= date ? st : JewishHolidays.simchatTorah(year + 1, israel: israel);
  }

  LocalDate _simchatTorahOnOrBefore(LocalDate date) {
    final year = HebrewDate.fromLocalDate(date).year;
    final st = JewishHolidays.simchatTorah(year, israel: israel);
    return st <= date ? st : JewishHolidays.simchatTorah(year - 1, israel: israel);
  }

  /// The first public reading on or after [date].
  ReadingOccasion nextOccasion(LocalDate date) {
    final st = _simchatTorahOnOrAfter(date);
    for (var s = date.onOrAfter(6);; s = s.addDays(7)) {
      if (st < s) return ReadingOccasion(const PortionId(kVezotHaberakhah), st);
      final p = portionOnShabbat(s);
      if (p != null) return ReadingOccasion(p, s);
    }
  }

  /// The last public reading strictly before [date].
  ReadingOccasion previousOccasion(LocalDate date) {
    final before = date.addDays(-1);
    final st = _simchatTorahOnOrBefore(before);
    for (var s = before.onOrBefore(6);; s = s.addDays(-7)) {
      if (st > s) return ReadingOccasion(const PortionId(kVezotHaberakhah), st);
      final p = portionOnShabbat(s);
      if (p != null) return ReadingOccasion(p, s);
    }
  }

  /// The reading week that [date] belongs to. On the day of a public reading
  /// itself, that reading's week is returned.
  ReadingWeek weekFor(LocalDate date) {
    final occasion = nextOccasion(date);
    final previous = previousOccasion(occasion.date);
    return _buildWeek(occasion, previous.date.addDays(1));
  }

  /// The week whose public reading is [occasion].
  ReadingWeek weekForOccasion(ReadingOccasion occasion) =>
      _buildWeek(occasion, previousOccasion(occasion.date).date.addDays(1));

  /// The week after [week].
  ReadingWeek nextWeek(ReadingWeek week) => weekFor(week.occasion.addDays(1));

  /// The week before [week].
  ReadingWeek previousWeek(ReadingWeek week) =>
      weekFor(week.start.addDays(-1));

  ReadingWeek _buildWeek(ReadingOccasion occasion, LocalDate start) {
    bool rest(LocalDate d) => JewishHolidays.isRestDay(d, israel: israel);
    final days = <LocalDate>[];
    if (occasion.portion.isVezotHaberakhah) {
      // Read in one sitting, ideally on Hoshana Rabbah (MB 285:18).
      var d = occasion.date.addDays(-1);
      while (rest(d) && d > start) {
        d = d.addDays(-1);
      }
      days.add(d);
    } else {
      var first = occasion.date.addDays(-6);
      if (first < start) first = start;
      for (var d = first; d < occasion.date; d = d.addDays(1)) {
        if (!rest(d)) days.add(d);
      }
      if (days.isEmpty) days.add(occasion.date.addDays(-1));
    }
    return ReadingWeek(
      portion: occasion.portion,
      occasion: occasion.date,
      start: start,
      plan: divideAliyot(days),
      israel: israel,
    );
  }

  /// Spreads the seven aliyot over [days] in order. With six days this gives
  /// the customary Sunday–Thursday one aliyah each and Friday the sixth and
  /// seventh; with fewer days the later days take the extra aliyot.
  static List<DailyAssignment> divideAliyot(List<LocalDate> days) {
    final n = days.length;
    final base = 7 ~/ n;
    final extra = 7 % n;
    final result = <DailyAssignment>[];
    var next = 0;
    for (var i = 0; i < n; i++) {
      final size = base + (i >= n - extra ? 1 : 0);
      result.add(DailyAssignment(days[i], [for (var j = 0; j < size; j++) next + j]));
      next += size;
    }
    return result;
  }
}
