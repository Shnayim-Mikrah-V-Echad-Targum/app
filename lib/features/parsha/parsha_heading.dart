import '../../core/calendar/jewish_holidays.dart';
import '../../core/calendar/local_date.dart';
import '../../core/calendar/parsha_schedule.dart';

/// How a week's parsha is headed on a day: the eyebrow over its name on
/// Today and on the home-screen widget.
enum ParshaHeading {
  /// "Parshat HaShavua": the coming Shabbat reads it.
  thisWeek,

  /// "Simchat Torah", for Vezot HaBerachah, which is read then.
  simchatTorah,

  /// "Next parsha": the coming Shabbat, or Simchat Torah still days away
  /// after a day of rest, reads something else first.
  next,
}

/// How [week]'s parsha is headed on [day], Today's and the widget's one rule.
///
/// On the day it is read, as this week's (or Simchat Torah's). Vezot
/// HaBerachah keeps Simchat Torah on its reading days, which already say when
/// that is, and is the next parsha on a Shabbat or Yom Tov before it. Any
/// other parsha is the next one whenever the coming Shabbat reads no weekly
/// portion ([ParshaSchedule.shabbatWithoutPortion]): on that festival
/// Shabbat, on the days before it and on a Yom Tov just before it.
/// [schedule] is the reading heard, and [oneDayYomTov] the days of Yom Tov
/// kept.
ParshaHeading parshaHeadingFor(
  ReadingWeek week,
  LocalDate day, {
  required ParshaSchedule schedule,
  required bool oneDayYomTov,
}) {
  final vezot = week.portion.isVezotHaberakhah;
  if (day == week.occasion) return vezot ? ParshaHeading.simchatTorah : ParshaHeading.thisWeek;
  if (vezot) {
    return JewishHolidays.isRestDay(day, israel: oneDayYomTov) ? ParshaHeading.next : ParshaHeading.simchatTorah;
  }
  return schedule.shabbatWithoutPortion(day) != null ? ParshaHeading.next : ParshaHeading.thisWeek;
}

/// The coming Shabbat with no weekly portion
/// ([ParshaSchedule.shabbatWithoutPortion]) when [day] is a day of rest and
/// the days of rest that run on from it ([JewishHolidays.lastRestDay])
/// reach it: on that Shabbat itself, or on a Yom Tov straight before it.
/// Null on a reading day, and when Shabbat is days away (on Yom Kippur on a
/// Monday, say).
LocalDate? shabbatWithoutPortionInRest(
  LocalDate day, {
  required ParshaSchedule schedule,
  required bool oneDayYomTov,
}) {
  if (!JewishHolidays.isRestDay(day, israel: oneDayYomTov)) return null;
  final shabbat = schedule.shabbatWithoutPortion(day);
  if (shabbat == null || shabbat > JewishHolidays.lastRestDay(day, israel: oneDayYomTov)) return null;
  return shabbat;
}
