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

  test('Chanukah days', () {
    expect(JewishHolidays.chanukahDay(const HebrewDate(5787, HebrewMonth.kislev, 25)), 1);
    expect(JewishHolidays.chanukahDay(const HebrewDate(5787, HebrewMonth.tevet, 2)), 8);
    expect(JewishHolidays.chanukahDay(const HebrewDate(5787, HebrewMonth.tevet, 3)), anyOf(isNull, 8));
    expect(JewishHolidays.chanukahDay(const HebrewDate(5787, HebrewMonth.kislev, 24)), isNull);
  });
}
