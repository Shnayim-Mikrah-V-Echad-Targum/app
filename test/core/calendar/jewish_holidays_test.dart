import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/hebrew_date.dart';
import 'package:shnayim_mikra/core/calendar/jewish_holidays.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';

import 'fixtures.dart';

void main() {
  final fixture = loadFixture('yom_tov.json') as Map<String, dynamic>;

  for (final israel in [false, true]) {
    test('Yom Tov days match the reference (${israel ? 'Israel' : 'Diaspora'})', () {
      final years = fixture[israel ? 'il' : 'diaspora'] as Map<String, dynamic>;
      for (final MapEntry(key: year, value: days) in years.entries) {
        final y = int.parse(year);
        final start = LocalDate.fromRd(HebrewDate.newYearRd(y));
        final end = LocalDate.fromRd(HebrewDate.newYearRd(y + 1));
        final actual = <String>[
          for (var d = start; d < end; d = d.addDays(1))
            if (JewishHolidays.isYomTov(HebrewDate.fromLocalDate(d), israel: israel)) d.toIso(),
        ];
        expect(actual, (days as List).cast<String>(), reason: 'year $y');
      }
    });
  }

  test('the days of rest run on from Shabbat into the Yom Tov after it, by the days kept', () {
    // Shabbat Bamidbar 5789, then Shavuot on Sunday (and Monday outside
    // Israel).
    final shabbat = LocalDate(2029, 5, 19);
    expect(JewishHolidays.lastRestDay(shabbat, israel: false), shabbat.addDays(2));
    expect(JewishHolidays.lastRestDay(shabbat, israel: true), shabbat.addDays(1));
    // Rosh Hashanah 5789 on Thursday and Friday, into Shabbat Shuva.
    final roshHashanah = LocalDate(2028, 9, 21);
    expect(JewishHolidays.lastRestDay(roshHashanah, israel: true), roshHashanah.addDays(2));
    // An ordinary Shabbat ends the days of rest itself.
    expect(JewishHolidays.lastRestDay(LocalDate(2026, 10, 10), israel: false), LocalDate(2026, 10, 10));
  });

  test('the eve of a Yom Tov on a weekday names it, by the days kept', () {
    ErevYomTov? eve(LocalDate date, {bool israel = false}) => JewishHolidays.erevYomTov(date, israel: israel);
    expect(eve(LocalDate(2028, 9, 20)), ErevYomTov.roshHashanah);
    expect(eve(LocalDate(2025, 10, 1)), ErevYomTov.yomKippur);
    // Erev Shavuot 5787, a Thursday, and the eve of the seventh day of
    // Pesach 5787, a Tuesday.
    for (final israel in [false, true]) {
      expect(eve(LocalDate(2027, 6, 10), israel: israel), ErevYomTov.other);
      expect(eve(LocalDate(2027, 4, 27), israel: israel), ErevYomTov.other);
    }
    // In Israel the seventh day of Pesach is the last.
    expect(eve(LocalDate(2027, 4, 28), israel: true), isNull);
    // Before a Yom Tov on Shabbat, as Yom Kippur 5789, it is Erev Shabbat,
    // as any Friday is, Friday 18 May 2029 among them.
    expect(eve(LocalDate(2028, 9, 29)), isNull);
    expect(eve(LocalDate(2029, 5, 18)), isNull);
    expect(eve(LocalDate(2026, 10, 14)), isNull);
  });

  test('a day of rest is no eve, though Yom Tov begins as it ends', () {
    ErevYomTov? eve(LocalDate date, {bool israel = false}) => JewishHolidays.erevYomTov(date, israel: israel);
    // Shabbat 19 May 2029, before Shavuot 5789 on Sunday.
    expect(eve(LocalDate(2029, 5, 19)), isNull);
    expect(eve(LocalDate(2029, 5, 19), israel: true), isNull);
    // The first day of Rosh Hashanah 5789, Thursday 21 September 2028, and
    // outside Israel the first day of Pesach 5787, Thursday 22 April 2027,
    // each with a second day of Yom Tov on Friday.
    expect(eve(LocalDate(2028, 9, 21)), isNull);
    expect(eve(LocalDate(2028, 9, 21), israel: true), isNull);
    expect(eve(LocalDate(2027, 4, 22)), isNull);
    // In Israel that Thursday is the one day of Yom Tov, and Friday Chol
    // HaMoed.
    expect(eve(LocalDate(2027, 4, 22), israel: true), isNull);
  });

  test('Chanukah days', () {
    expect(JewishHolidays.chanukahDay(const HebrewDate(5787, HebrewMonth.kislev, 25)), 1);
    expect(JewishHolidays.chanukahDay(const HebrewDate(5787, HebrewMonth.tevet, 2)), 8);
    expect(JewishHolidays.chanukahDay(const HebrewDate(5787, HebrewMonth.tevet, 3)), anyOf(isNull, 8));
    expect(JewishHolidays.chanukahDay(const HebrewDate(5787, HebrewMonth.kislev, 24)), isNull);
  });
}
