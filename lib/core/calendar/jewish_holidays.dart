import 'hebrew_date.dart';
import 'local_date.dart';

/// Festival rules needed by the app: which days are Yom Tov (no device use,
/// so they never count against a streak and never get notifications).
abstract final class JewishHolidays {
  /// Whether [date] is a Yom Tov on which work is forbidden. Yom Kippur and
  /// both days of Rosh Hashana are included; Chol HaMoed is not.
  static bool isYomTov(HebrewDate date, {required bool israel}) {
    final d = date.day;
    switch (date.month) {
      case HebrewMonth.tishrei:
        // Rosh Hashana, Yom Kippur, Sukkot, Shemini Atzeret (+ Simchat Torah).
        if (d == 1 || d == 2 || d == 10 || d == 15 || d == 22) return true;
        return !israel && (d == 16 || d == 23);
      case HebrewMonth.nisan:
        if (d == 15 || d == 21) return true;
        return !israel && (d == 16 || d == 22);
      case HebrewMonth.sivan:
        if (d == 6) return true;
        return !israel && d == 7;
      default:
        return false;
    }
  }

  /// Shabbat or Yom Tov: a day on which the app expects no activity.
  static bool isRestDay(LocalDate date, {required bool israel}) =>
      date.isShabbat ||
      isYomTov(HebrewDate.fromLocalDate(date), israel: israel);

  /// Chol HaMoed or a festival day of Pesach or Sukkot (including Shemini
  /// Atzeret / Simchat Torah). A Shabbat in this range has no weekly portion.
  static bool isPesachOrSukkot(HebrewDate date, {required bool israel}) {
    final d = date.day;
    if (date.month == HebrewMonth.nisan) return d >= 15 && d <= (israel ? 21 : 22);
    if (date.month == HebrewMonth.tishrei) return d >= 15 && d <= (israel ? 22 : 23);
    return false;
  }

  /// The day the Torah reading cycle is completed (Vezot HaBerakhah is read).
  static LocalDate simchatTorah(int hebrewYear, {required bool israel}) =>
      HebrewDate(hebrewYear, HebrewMonth.tishrei, israel ? 22 : 23).toLocalDate();

  /// Rosh Chodesh: the 30th of a month (first day of a two-day Rosh Chodesh)
  /// or the 1st of a month other than Tishrei.
  static bool isRoshChodesh(HebrewDate date) =>
      date.day == 30 || (date.day == 1 && date.month != HebrewMonth.tishrei);

  /// The 1-based day of Chanukah, or null if [date] is not during Chanukah.
  static int? chanukahDay(HebrewDate date) {
    final first = HebrewDate(date.year, HebrewMonth.kislev, 25).rd;
    // Chanukah never crosses a Hebrew year boundary.
    final n = date.rd - first + 1;
    return n >= 1 && n <= 8 ? n : null;
  }
}
