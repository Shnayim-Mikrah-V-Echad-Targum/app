import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/hebrew_date.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';

import 'fixtures.dart';

int _encode(PortionId? p) => p == null ? 0 : (p.combined ? -p.number : p.number);

void main() {
  final fixture = loadFixture('parsha_schedule.json') as Map<String, dynamic>;

  for (final israel in [false, true]) {
    final label = israel ? 'Israel' : 'Diaspora';
    final schedule = ParshaSchedule(israel: israel);

    test('weekly portion on every Shabbat 5700-5900 matches the reference ($label)', () {
      final years = fixture[israel ? 'il' : 'diaspora'] as Map<String, dynamic>;
      expect(years, hasLength(201));
      for (final MapEntry(key: year, value: expected) in years.entries) {
        final y = int.parse(year);
        var shabbat = LocalDate.fromRd(HebrewDate.newYearRd(y)).onOrAfter(6);
        final actual = <int>[];
        for (var i = 0; i < (expected as List).length; i++) {
          actual.add(_encode(schedule.portionOnShabbat(shabbat)));
          shabbat = shabbat.addDays(7);
        }
        expect(actual, expected.cast<int>(), reason: 'year $y');
      }
    });

    test('every portion 1-53 is read exactly once per cycle ($label)', () {
      // Walk 30 full cycles starting after Simchat Torah 5787.
      var week = schedule.weekFor(LocalDate(2026, 10, 5));
      for (var cycle = 0; cycle < 30; cycle++) {
        final seen = <int>[];
        expect(week.portion.number, 1, reason: 'cycle $cycle starts with Bereshit');
        while (true) {
          seen.addAll(week.portion.parshiyot);
          if (week.portion.isVezotHaberakhah) break;
          week = schedule.nextWeek(week);
        }
        expect(seen, [for (var i = 1; i <= 54; i++) i], reason: 'cycle $cycle');
        week = schedule.nextWeek(week);
      }
    });
  }

  group('weeks', () {
    const diaspora = ParshaSchedule(israel: false);
    const israel = ParshaSchedule(israel: true);

    test('Bereshit 5787 follows Simchat Torah, Monday to Friday', () {
      final week = diaspora.weekFor(LocalDate(2026, 10, 9));
      expect(week.portion, const PortionId(1));
      expect(week.occasion, LocalDate(2026, 10, 10));
      expect(week.start, LocalDate(2026, 10, 5)); // day after Simchat Torah
      expect(week.plan.map((a) => a.aliyot), [
        [0], [1], [2], [3, 4], [5, 6],
      ]);
    });

    test('a regular week assigns one aliyah per day and two on Friday', () {
      final week = diaspora.weekFor(LocalDate(2026, 10, 12));
      expect(week.portion, const PortionId(2)); // Noach
      expect(week.plan.first.date, LocalDate(2026, 10, 11));
      expect(week.plan.map((a) => a.aliyot), [
        [0], [1], [2], [3], [4], [5, 6],
      ]);
      expect(week.lateDeadline, LocalDate(2026, 10, 20));
    });

    test('Vezot HaBerakhah is read on Hoshana Rabbah', () {
      final week = diaspora.weekFor(LocalDate(2026, 9, 25));
      expect(week.portion.isVezotHaberakhah, isTrue);
      expect(week.occasion, LocalDate(2026, 10, 4)); // Simchat Torah (Diaspora)
      expect(week.plan.single.date, LocalDate(2026, 10, 2)); // Hoshana Rabbah
      expect(week.plan.single.aliyot, [0, 1, 2, 3, 4, 5, 6]);

      final il = israel.weekFor(LocalDate(2026, 9, 25));
      expect(il.occasion, LocalDate(2026, 10, 3)); // Shemini Atzeret
      expect(il.plan.single.date, LocalDate(2026, 10, 2));
    });

    test('the week of Pesach skips Yom Tov days', () {
      // Pesach 5787 begins Thursday 22 April 2027.
      final week = diaspora.weekFor(LocalDate(2027, 4, 26));
      expect(week.portion, const PortionId(29)); // Achrei Mot (5787 is a leap year)
      expect(week.occasion, LocalDate(2027, 5, 1));
      expect(week.plan.map((a) => a.date.toIso()), [
        '2027-04-25', '2027-04-26', '2027-04-27', '2027-04-30',
      ]);
      final il = israel.weekFor(LocalDate(2027, 4, 26));
      expect(il.plan.map((a) => a.date.toIso()), [
        '2027-04-25', '2027-04-26', '2027-04-27', '2027-04-29', '2027-04-30',
      ]);
    });

    test('divideAliyot covers all seven aliyot in order', () {
      for (var n = 1; n <= 6; n++) {
        final days = [for (var i = 0; i < n; i++) LocalDate(2026, 1, 4).addDays(i)];
        final plan = ParshaSchedule.divideAliyot(days);
        expect(plan.expand((a) => a.aliyot), [0, 1, 2, 3, 4, 5, 6], reason: 'n=$n');
        expect(plan.every((a) => a.aliyot.isNotEmpty), isTrue);
      }
    });

    test('previous / next week are inverses', () {
      var week = diaspora.weekFor(LocalDate(2026, 10, 9));
      for (var i = 0; i < 120; i++) {
        final next = diaspora.nextWeek(week);
        expect(diaspora.previousWeek(next).occasion, week.occasion);
        expect(next.start, week.occasion.addDays(1));
        week = next;
      }
    });
  });
}
