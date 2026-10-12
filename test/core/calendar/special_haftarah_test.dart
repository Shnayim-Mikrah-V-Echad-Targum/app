import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/hebrew_date.dart';
import 'package:shnayim_mikra/core/calendar/jewish_holidays.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/core/calendar/special_haftarah.dart';

import 'fixtures.dart';

void main() {
  final fixture = loadFixture('special_haftarot.json') as Map<String, dynamic>;
  final byCustom = loadFixture('special_haftarot_by_custom.json') as Map<String, dynamic>;

  for (final israel in [false, true]) {
    final place = israel ? 'Israel' : 'Diaspora';
    final schedule = ParshaSchedule(israel: israel);

    test('special haftarot 2000-2100 match the reference ($place)', () {
      final data = fixture[israel ? 'il' : 'diaspora'] as Map<String, dynamic>;
      final expected = (data['special'] as Map<String, dynamic>).cast<String, String>();
      final mismatches = <String>[];
      var count = 0;
      for (var d = LocalDate.parse(data['from'] as String);
          d <= LocalDate.parse(data['to'] as String);
          d = d.addDays(7)) {
        final portion = schedule.portionOnShabbat(d);
        if (portion == null) continue;
        count++;
        final actual = specialHaftarahKey(d, portion, nusach: HaftarahNusach.ashkenazi);
        if (actual != expected[d.toIso()]) {
          mismatches.add('$d ${portion.key}: expected ${expected[d.toIso()]}, got $actual');
        }
      }
      expect(count, greaterThan(4800));
      expect(mismatches, isEmpty, reason: mismatches.take(25).join('\n'));
    });

    for (final nusach in HaftarahNusach.values) {
      test('special haftarot 5780-5800 match the reference for the ${nusach.name} custom ($place)', () {
        final data = byCustom[israel ? 'il' : 'diaspora'] as Map<String, dynamic>;
        final expected = (data[nusach.name] as Map<String, dynamic>).cast<String, String>();
        final mismatches = <String>[];
        var count = 0;
        for (var d = LocalDate.parse(data['from'] as String);
            d <= LocalDate.parse(data['to'] as String);
            d = d.addDays(7)) {
          final portion = schedule.portionOnShabbat(d);
          if (portion == null) continue;
          count++;
          final actual = specialHaftarahKey(d, portion, nusach: nusach);
          if (actual != expected[d.toIso()]) {
            mismatches.add('$d ${portion.key}: expected ${expected[d.toIso()]}, got $actual');
          }
        }
        // 21 years of Shabbatot, less those that are festivals.
        expect(count, greaterThan(1000));
        expect(mismatches, isEmpty, reason: mismatches.take(25).join('\n'));
      });
    }
  }

  group('where the customs differ', () {
    const schedule = ParshaSchedule(israel: false);
    String? key(LocalDate d, HaftarahNusach nusach) =>
        specialHaftarahKey(d, schedule.portionOnShabbat(d)!, nusach: nusach);

    // Re'eh (47) 5782 was read on 30 Av, the first day of Rosh Chodesh Elul,
    // and Ki Tetze (49) two weeks later.
    final reeh = LocalDate(2022, 8, 27);
    final kiTeitzei = LocalDate(2022, 9, 10);
    // Kedoshim (30) 5782, a week after Acharei Mot was Shabbat Machar Chodesh.
    final kedoshim = LocalDate(2022, 5, 7);

    test('in these weeks', () {
      expect(schedule.portionOnShabbat(reeh), const PortionId(47));
      expect(schedule.portionOnShabbat(kiTeitzei), const PortionId(49));
      expect(schedule.portionOnShabbat(kedoshim), const PortionId(30));
      expect(key(kedoshim.addDays(-7), HaftarahNusach.ashkenazi), 'Shabbat Machar Chodesh');
    });

    // Ashkenazim, and Chabad by Sefer HaMinhagim.
    for (final nusach in [HaftarahNusach.ashkenazi, HaftarahNusach.chabad]) {
      test("the ${nusach.name} custom reads the Rosh Chodesh haftarah for Re'eh, then Re'eh's with Ki Tetze's", () {
        // On 30 Av, with verses for Sunday's Rosh Chodesh (below).
        expect(key(reeh, nusach), 'Shabbat Rosh Chodesh (and Sunday)');
        expect(key(kiTeitzei, nusach), 'Ki Teitzei with 3rd Haftarah of Consolation');
      });
    }

    test('Ashkenazim read Acharei Mot’s haftarah for Kedoshim', () {
      expect(key(kedoshim, HaftarahNusach.ashkenazi), 'Kedoshim following Special Shabbat');
    });

    test("Sephardim keep Re'eh's own haftarah, with Machar Chodesh's verses on the 30th, and Ki Tetze's", () {
      expect(key(reeh, HaftarahNusach.sephardi), "Re'eh on Shabbat Rosh Chodesh (and Sunday)");
      expect(key(kiTeitzei, HaftarahNusach.sephardi), isNull);
      // Re'eh 5789, on 30 Av too.
      final reeh5789 = LocalDate(2029, 8, 11);
      expect(schedule.portionOnShabbat(reeh5789), const PortionId(47));
      expect(HebrewDate.fromLocalDate(reeh5789).day, 30);
      expect(key(reeh5789, HaftarahNusach.sephardi), "Re'eh on Shabbat Rosh Chodesh (and Sunday)");
      expect(key(reeh5789, HaftarahNusach.chabad), 'Shabbat Rosh Chodesh (and Sunday)');
    });

    test('Rosh Chodesh Elul on Shabbat is always 30 Av, with Sunday Rosh Chodesh too', () {
      // 1 Elul falls the day before Rosh Hashanah's weekday, which is never
      // Sunday.
      for (var year = 5700; year <= 5900; year++) {
        expect(HebrewDate(year, HebrewMonth.elul, 1).toLocalDate().isShabbat, isFalse, reason: '$year');
      }
    });

    test("Sephardim keep Kedoshim's own haftarah, and Chabad the Ashkenazi rule", () {
      expect(key(kedoshim, HaftarahNusach.sephardi), isNull);
      // Chabad reads Acharei Mot's haftarah as Ashkenazim do, and no Chabad
      // source yet says what it reads for Kedoshim after it is displaced.
      expect(key(kedoshim, HaftarahNusach.chabad), 'Kedoshim following Special Shabbat');
    });
  });

  group('Shabbat Rosh Chodesh', () {
    const schedule = ParshaSchedule(israel: false);

    // Months whose Rosh Chodesh brings no other special haftarah (as
    // Chanukah, Shekalim, HaChodesh, Av's and Elul's do).
    const plain = {
      HebrewMonth.iyar,
      HebrewMonth.sivan,
      HebrewMonth.tammuz,
      HebrewMonth.cheshvan,
      HebrewMonth.kislev,
      HebrewMonth.shevat,
    };

    /// The first Shabbat on or after [from] that is the [day] of a month (1
    /// or 30) and Rosh Chodesh of one of those months.
    LocalDate next(LocalDate from, int day) {
      var d = from;
      while (!d.isShabbat) {
        d = d.addDays(1);
      }
      for (;; d = d.addDays(7)) {
        final h = HebrewDate.fromLocalDate(d);
        final month = day == 30 ? HebrewDate.fromLocalDate(d.addDays(1)).month : h.month;
        if (h.day == day && JewishHolidays.isRoshChodesh(h) && plain.contains(month)) return d;
      }
    }

    test('on the 30th, with Sunday Rosh Chodesh too, adds verses of Machar Chodesh for every custom', () {
      final shabbat = next(LocalDate(2026, 10, 10), 30);
      // Korach 5788, on 30 Sivan.
      expect(shabbat, LocalDate(2028, 6, 24));
      expect(JewishHolidays.isRoshChodesh(HebrewDate.fromLocalDate(shabbat.addDays(1))), isTrue);
      for (final nusach in HaftarahNusach.values) {
        expect(
          specialHaftarahKey(shabbat, schedule.portionOnShabbat(shabbat)!, nusach: nusach),
          'Shabbat Rosh Chodesh (and Sunday)',
          reason: nusach.name,
        );
      }
    });

    test('on the 1st is the Rosh Chodesh haftarah alone', () {
      final shabbat = next(LocalDate(2026, 10, 10), 1);
      expect(JewishHolidays.isRoshChodesh(HebrewDate.fromLocalDate(shabbat.addDays(1))), isFalse);
      for (final nusach in HaftarahNusach.values) {
        expect(
          specialHaftarahKey(shabbat, schedule.portionOnShabbat(shabbat)!, nusach: nusach),
          'Shabbat Rosh Chodesh',
          reason: '$shabbat ${nusach.name}',
        );
      }
    });
  });
}
