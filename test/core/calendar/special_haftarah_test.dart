import 'package:flutter_test/flutter_test.dart';
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

    test("Ashkenazim read the Rosh Chodesh haftarah for Re'eh, then Re'eh's with Ki Tetze's", () {
      expect(key(reeh, HaftarahNusach.ashkenazi), 'Shabbat Rosh Chodesh');
      expect(key(kiTeitzei, HaftarahNusach.ashkenazi), 'Ki Teitzei with 3rd Haftarah of Consolation');
      expect(key(kedoshim, HaftarahNusach.ashkenazi), 'Kedoshim following Special Shabbat');
    });

    for (final nusach in [HaftarahNusach.sephardi, HaftarahNusach.chabad]) {
      test("the ${nusach.name} custom keeps Re'eh's own haftarah, and Ki Tetze's", () {
        expect(key(reeh, nusach), "Re'eh on Shabbat Rosh Chodesh");
        expect(key(kiTeitzei, nusach), isNull);
      });
    }

    test("Sephardim keep Kedoshim's own haftarah, and Chabad the Ashkenazi rule", () {
      expect(key(kedoshim, HaftarahNusach.sephardi), isNull);
      // Chabad reads Acharei Mot's haftarah as Ashkenazim do, and no Chabad
      // source yet says what it reads for Kedoshim after it is displaced.
      expect(key(kedoshim, HaftarahNusach.chabad), 'Kedoshim following Special Shabbat');
    });
  });
}
