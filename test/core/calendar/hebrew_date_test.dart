import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/hebrew_date.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';

import 'fixtures.dart';

void main() {
  final fixture = loadFixture('hebrew_calendar.json') as Map<String, dynamic>;

  test('Rosh Hashana, year length and leap years match the reference for 700 years', () {
    final years = fixture['years'] as List;
    expect(years, hasLength(greaterThan(700)));
    for (final row in years.cast<List>()) {
      final [year as int, rh as String, length as int, leap as int] = row;
      expect(LocalDate.fromRd(HebrewDate.newYearRd(year)).toIso(), rh, reason: 'RH $year');
      expect(HebrewDate.daysInYear(year), length, reason: 'length $year');
      expect(HebrewDate.isLeapYear(year), leap == 1, reason: 'leap $year');
    }
  });

  test('Gregorian <-> Hebrew conversion matches the reference sample', () {
    final samples = fixture['samples'] as List;
    for (final row in samples.cast<List>()) {
      final [iso as String, y as int, m as int, d as int] = row;
      final date = LocalDate.parse(iso);
      expect(HebrewDate.fromLocalDate(date), HebrewDate(y, m, d), reason: iso);
      expect(HebrewDate(y, m, d).toLocalDate(), date, reason: iso);
    }
  });

  test('every day round-trips across several years', () {
    final start = LocalDate(2024, 1, 1);
    for (var i = 0; i < 365 * 6; i++) {
      final date = start.addDays(i);
      final h = HebrewDate.fromLocalDate(date);
      expect(h.toLocalDate(), date);
      expect(h.day, inInclusiveRange(1, HebrewDate.daysInMonth(h.year, h.month)));
    }
  });

  test('known dates', () {
    expect(HebrewDate.fromLocalDate(LocalDate(2026, 9, 12)), const HebrewDate(5787, 7, 1));
    expect(HebrewDate.fromLocalDate(LocalDate(2026, 10, 9)), const HebrewDate(5787, 7, 28));
    expect(const HebrewDate(5784, HebrewMonth.adar2, 14).toLocalDate(), LocalDate(2024, 3, 24));
  });

  group('LocalDate', () {
    test('weekday uses Sunday = 0', () {
      expect(LocalDate(2026, 10, 10).weekday, 6);
      expect(LocalDate(2026, 10, 11).weekday, 0);
      expect(LocalDate(2026, 10, 10).isShabbat, isTrue);
    });

    test('onOrAfter / onOrBefore', () {
      final fri = LocalDate(2026, 10, 9);
      expect(fri.onOrAfter(6), LocalDate(2026, 10, 10));
      expect(fri.onOrBefore(6), LocalDate(2026, 10, 3));
      expect(LocalDate(2026, 10, 10).onOrAfter(6), LocalDate(2026, 10, 10));
    });

    test('is immune to daylight-saving transitions', () {
      final d = LocalDate(2026, 3, 7);
      expect(d.addDays(1), LocalDate(2026, 3, 8));
      expect(d.addDays(2), LocalDate(2026, 3, 9));
      expect(LocalDate.parse('2026-11-01').addDays(1).toIso(), '2026-11-02');
    });
  });
}
