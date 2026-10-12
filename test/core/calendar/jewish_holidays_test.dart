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

  test('Chanukah days', () {
    expect(JewishHolidays.chanukahDay(const HebrewDate(5787, HebrewMonth.kislev, 25)), 1);
    expect(JewishHolidays.chanukahDay(const HebrewDate(5787, HebrewMonth.tevet, 2)), 8);
    expect(JewishHolidays.chanukahDay(const HebrewDate(5787, HebrewMonth.tevet, 3)), anyOf(isNull, 8));
    expect(JewishHolidays.chanukahDay(const HebrewDate(5787, HebrewMonth.kislev, 24)), isNull);
  });
}
