import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/core/calendar/local_date.dart';
import 'package:shnayim_mikrah/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikrah/features/parsha/parsha_heading.dart';

void main() {
  const diaspora = ParshaSchedule(israel: false);
  const israel = ParshaSchedule(israel: true);

  ParshaHeading heading(ReadingWeek week, LocalDate day, {bool inIsrael = false}) =>
      parshaHeadingFor(week, day, schedule: inIsrael ? israel : diaspora, oneDayYomTov: inIsrael);

  group('parshaHeadingFor', () {
    test('Shemini 5786 is the next parsha until the Shabbat of Pesach is over', () {
      final week = diaspora.weekFor(LocalDate(2026, 3, 29));
      expect(week.occasion, LocalDate(2026, 4, 11));
      // A weekday, the first day of Pesach, and Shabbat Chol HaMoed.
      for (final day in [LocalDate(2026, 3, 29), LocalDate(2026, 4, 2), LocalDate(2026, 4, 4)]) {
        expect(heading(week, day), ParshaHeading.next, reason: '$day');
      }
      // From the Sunday after, its own Shabbat is coming.
      expect(heading(week, LocalDate(2026, 4, 5)), ParshaHeading.thisWeek);
      expect(heading(week, LocalDate(2026, 4, 11)), ParshaHeading.thisWeek);
    });

    test('Shemini 5789 is this week\'s in Israel on the eighth day of Pesach, and the next one abroad', () {
      final day = LocalDate(2029, 4, 7);
      expect(heading(israel.weekFor(day), day, inIsrael: true), ParshaHeading.thisWeek);
      expect(heading(diaspora.weekFor(day), day), ParshaHeading.next);
    });

    test('Vezot HaBerachah is headed by Simchat Torah, but on a day of rest before it is the next parsha', () {
      final week = diaspora.weekFor(LocalDate(2026, 9, 21));
      expect(week.portion.isVezotHaberakhah, isTrue);
      // Yom Kippur, the first day of Sukkot, and Shemini Atzeret.
      for (final day in [LocalDate(2026, 9, 21), LocalDate(2026, 9, 26), LocalDate(2026, 10, 3)]) {
        expect(heading(week, day), ParshaHeading.next, reason: '$day');
      }
      // Hoshana Rabbah, its reading day, and Simchat Torah.
      expect(heading(week, LocalDate(2026, 10, 2)), ParshaHeading.simchatTorah);
      expect(heading(week, LocalDate(2026, 10, 4)), ParshaHeading.simchatTorah);
      // In Israel, Shemini Atzeret is Simchat Torah.
      final day = LocalDate(2026, 10, 3);
      expect(heading(israel.weekFor(day), day, inIsrael: true), ParshaHeading.simchatTorah);
    });

    test('Naso 5786 is the next parsha over Shavuot abroad, and this week\'s in Israel', () {
      final week = diaspora.weekFor(LocalDate(2026, 5, 22));
      expect(heading(week, LocalDate(2026, 5, 22)), ParshaHeading.next);
      expect(heading(week, LocalDate(2026, 5, 23)), ParshaHeading.next);
      final day = LocalDate(2026, 5, 22);
      expect(heading(israel.weekFor(day), day, inIsrael: true), ParshaHeading.thisWeek);
    });

    test('Ha\'azinu 5787 is the next parsha on Rosh Hashanah on Shabbat, and this week\'s from the day after', () {
      final week = diaspora.weekFor(LocalDate(2026, 9, 12));
      expect(week.occasion, LocalDate(2026, 9, 19));
      expect(heading(week, LocalDate(2026, 9, 12)), ParshaHeading.next);
      expect(heading(week, LocalDate(2026, 9, 13)), ParshaHeading.thisWeek);
    });

    test('an ordinary week is this week\'s every day', () {
      final week = diaspora.weekFor(LocalDate(2026, 10, 11));
      for (var day = week.start; day <= week.occasion; day = day.addDays(1)) {
        expect(heading(week, day), ParshaHeading.thisWeek, reason: '$day');
      }
    });
  });

  group('shabbatWithoutPortionInRest', () {
    LocalDate? inRest(LocalDate day, {bool inIsrael = false}) =>
        shabbatWithoutPortionInRest(day, schedule: inIsrael ? israel : diaspora, oneDayYomTov: inIsrael);

    test('is the festival Shabbat on it, and on a Yom Tov that runs into it', () {
      // The first day of Pesach 5786, a Thursday, and Shabbat Chol HaMoed.
      expect(inRest(LocalDate(2026, 4, 2)), LocalDate(2026, 4, 4));
      expect(inRest(LocalDate(2026, 4, 4)), LocalDate(2026, 4, 4));
      // The first day of Shavuot 5786, before its second on Shabbat.
      expect(inRest(LocalDate(2026, 5, 22)), LocalDate(2026, 5, 23));
    });

    test('is null on a reading day, before a Shabbat days away, and where the Shabbat reads its parsha', () {
      // Chol HaMoed Pesach 5786.
      expect(inRest(LocalDate(2026, 3, 31)), isNull);
      // Yom Kippur 5787, a Monday: Sukkot's Shabbat is days away.
      expect(inRest(LocalDate(2026, 9, 21)), isNull);
      // Shavuot 5786 in Israel, where Naso is read that Shabbat.
      expect(inRest(LocalDate(2026, 5, 22), inIsrael: true), isNull);
    });
  });
}
