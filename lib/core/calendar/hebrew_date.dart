import 'local_date.dart';

/// Hebrew months, numbered as in the Torah: Nisan is the first month.
abstract final class HebrewMonth {
  static const nisan = 1;
  static const iyar = 2;
  static const sivan = 3;
  static const tammuz = 4;
  static const av = 5;
  static const elul = 6;
  static const tishrei = 7;
  static const cheshvan = 8;
  static const kislev = 9;
  static const tevet = 10;
  static const shevat = 11;

  /// Adar in a common year; Adar I in a leap year.
  static const adar = 12;

  /// Adar II, which exists only in leap years.
  static const adar2 = 13;
}

/// A date in the Hebrew calendar.
///
/// The arithmetic follows the fixed rules of the calendar as codified by the
/// Rambam (Hilchot Kiddush HaChodesh 6–8): the molad of Tishrei, the four
/// postponements (dechiyot), and the 19-year leap cycle. It is implemented
/// here in the "fixed day number" style of Reingold & Dershowitz, and
/// verified in tests against an independent implementation over 700 years.
class HebrewDate implements Comparable<HebrewDate> {
  const HebrewDate(this.year, this.month, this.day);

  factory HebrewDate.fromLocalDate(LocalDate date) => HebrewDate.fromRd(date.rd);

  factory HebrewDate.fromRd(int rd) {
    final approx = ((rd - _epoch) * 98496) ~/ 35975351 + 1;
    var year = approx - 1;
    while (newYearRd(year + 1) <= rd) {
      year++;
    }
    var month =
        rd < HebrewDate(year, HebrewMonth.nisan, 1).rd ? HebrewMonth.tishrei : HebrewMonth.nisan;
    while (rd > HebrewDate(year, month, daysInMonth(year, month)).rd) {
      month++;
    }
    final day = rd - HebrewDate(year, month, 1).rd + 1;
    return HebrewDate(year, month, day);
  }

  final int year;
  final int month;
  final int day;

  /// R.D. of 1 Tishrei, year 1.
  static const _epoch = -1373427;

  static bool isLeapYear(int year) => (7 * year + 1) % 19 < 7;

  static int monthsInYear(int year) => isLeapYear(year) ? 13 : 12;

  /// Days from the epoch to the molad of Tishrei of [year], after the
  /// postponement rules that depend only on the molad itself.
  static int _elapsedDays(int year) {
    final monthsElapsed = (235 * year - 234) ~/ 19;
    final partsElapsed = 12084 + 13753 * monthsElapsed;
    final day = 29 * monthsElapsed + partsElapsed ~/ 25920;
    // Lo AD"U Rosh: Rosh Hashana never falls on Sunday, Wednesday or Friday.
    return (3 * (day + 1)) % 7 < 3 ? day + 1 : day;
  }

  /// Postponements that keep the year length within the permitted values.
  static int _yearLengthCorrection(int year) {
    final ny0 = _elapsedDays(year - 1);
    final ny1 = _elapsedDays(year);
    final ny2 = _elapsedDays(year + 1);
    if (ny2 - ny1 == 356) return 2;
    if (ny1 - ny0 == 382) return 1;
    return 0;
  }

  static final _newYearCache = <int, int>{};

  /// The fixed day number of Rosh Hashana (1 Tishrei) of [year].
  static int newYearRd(int year) => _newYearCache.putIfAbsent(
      year, () => _epoch + _elapsedDays(year) + _yearLengthCorrection(year));

  static int daysInYear(int year) => newYearRd(year + 1) - newYearRd(year);

  static bool _longCheshvan(int year) => daysInYear(year) % 10 == 5;
  static bool _shortKislev(int year) => daysInYear(year) % 10 == 3;

  static int daysInMonth(int year, int month) {
    switch (month) {
      case HebrewMonth.iyar:
      case HebrewMonth.tammuz:
      case HebrewMonth.elul:
      case HebrewMonth.tevet:
      case HebrewMonth.adar2:
        return 29;
      case HebrewMonth.adar:
        return isLeapYear(year) ? 30 : 29;
      case HebrewMonth.cheshvan:
        return _longCheshvan(year) ? 30 : 29;
      case HebrewMonth.kislev:
        return _shortKislev(year) ? 29 : 30;
      default:
        return 30;
    }
  }

  int get rd {
    var days = newYearRd(year) + day - 1;
    if (month < HebrewMonth.tishrei) {
      for (var m = HebrewMonth.tishrei; m <= monthsInYear(year); m++) {
        days += daysInMonth(year, m);
      }
      for (var m = HebrewMonth.nisan; m < month; m++) {
        days += daysInMonth(year, m);
      }
    } else {
      for (var m = HebrewMonth.tishrei; m < month; m++) {
        days += daysInMonth(year, m);
      }
    }
    return days;
  }

  LocalDate toLocalDate() => LocalDate.fromRd(rd);

  bool get isLeap => isLeapYear(year);

  /// The Adar in which Purim and the special Shabbatot fall
  /// (Adar II in a leap year).
  static int purimMonth(int year) =>
      isLeapYear(year) ? HebrewMonth.adar2 : HebrewMonth.adar;

  @override
  int compareTo(HebrewDate other) => rd.compareTo(other.rd);

  @override
  bool operator ==(Object other) =>
      other is HebrewDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => '$day/$month/$year';
}
