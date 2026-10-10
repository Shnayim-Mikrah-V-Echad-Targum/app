import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/city.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/zmanim.dart';

import 'fixtures.dart';

City _place(String name, double lat, double lon, String tz) =>
    City(id: 0, nameEn: name, countryCode: '', latitude: lat, longitude: lon, timeZone: tz);

void main() {
  final cities = {
    for (final c in (jsonDecode(File('assets/data/cities.json').readAsStringSync())['cities'] as List))
      (c as Map<String, dynamic>)['id'] as int: City.fromJson(c),
  };
  City city(String name) => cities.values.firstWhere((c) => c.nameEn == name);

  test('candle-lighting and Havdalah match Hebcal to the minute, in every fixture', () {
    final fixture = loadFixture('zmanim.json') as Map<String, dynamic>;
    final misses = <String>[];
    var count = 0;
    for (final c in (fixture['cities'] as List).cast<Map<String, dynamic>>()) {
      final place = cities[c['id']]!;
      for (final [String date, String kind, int expected] in (c['times'] as List).cast<List<dynamic>>()) {
        final z = Zmanim.of(place, LocalDate.parse(date));
        final actual = z.minutesOf(kind == 'c' ? z.candleLighting : z.havdalah);
        count++;
        if (actual == null || (actual - expected).abs() > 1) {
          misses.add('${place.nameEn} $date $kind: $actual, Hebcal $expected');
        }
      }
    }
    expect(count, greaterThan(5000));
    expect(misses, isEmpty, reason: '${misses.length} of $count differ by more than a minute');
  });

  test('candles are lit the city\'s own minutes before sunset, rounded down', () {
    final friday = LocalDate(2026, 10, 16);
    for (final (name, minutes) in [('Jerusalem', 40), ('Haifa', 30), ('Tel Aviv', 20), ('London', 18)]) {
      final z = Zmanim.of(city(name), friday);
      expect(city(name).candleMinutes, minutes, reason: name);
      final lit = z.candleLighting!;
      expect((lit.second, lit.millisecond), (0, 0), reason: name);
      final before = z.sunset!.difference(lit);
      expect(before, greaterThanOrEqualTo(Duration(minutes: minutes)), reason: name);
      expect(before, lessThan(Duration(minutes: minutes + 1)), reason: name);
    }
  });

  test('Havdalah is a whole minute after sunset', () {
    final z = Zmanim.of(city('Jerusalem'), LocalDate(2026, 10, 17));
    expect((z.havdalah!.second, z.havdalah!.millisecond), (0, 0));
    // About 37 minutes in Jerusalem in October.
    expect(z.havdalah!.difference(z.sunset!).inMinutes, inInclusiveRange(30, 45));
  });

  test('times are on the city\'s own clock, across a change to daylight saving', () {
    final ny = city('New York City');
    // Clocks went forward on Sunday 8 March 2026.
    final before = Zmanim.of(ny, LocalDate(2026, 3, 6));
    final after = Zmanim.of(ny, LocalDate(2026, 3, 13));
    expect(before.candleLighting!.location.name, 'America/New_York');
    expect((before.candleLighting!.hour, after.candleLighting!.hour), (17, 18));
    expect(before.candleLighting!.timeZoneOffset, const Duration(hours: -5));
    expect(after.candleLighting!.timeZoneOffset, const Duration(hours: -4));
  });

  test('a clock a day ahead of its longitude still gets the day asked for', () {
    // Kiritimati keeps UTC+14 at 157° west.
    final z = Zmanim.of(_place('Kiritimati', 1.87, -157.43, 'Pacific/Kiritimati'), LocalDate(2026, 10, 16));
    expect((z.sunset!.year, z.sunset!.month, z.sunset!.day), (2026, 10, 16));
    expect(z.sunset!.hour, inInclusiveRange(18, 19));
    expect(z.sunrise!.isBefore(z.sunset!), isTrue);
  });

  test('Havdalah after midnight counts from the midnight that began the day', () {
    // Riga in June: three small stars only after midnight.
    final z = Zmanim.of(_place('Riga', 56.946, 24.106, 'Europe/Riga'), LocalDate(2026, 6, 20));
    expect((z.havdalah!.month, z.havdalah!.day), (6, 21));
    expect(z.minutesOf(z.havdalah), greaterThan(24 * 60));
    expect(z.minutesOf(z.havdalah), lessThan(24 * 60 + 60));
  });

  group('near the poles', () {
    test('a northern summer\'s sky never gets dark enough for Havdalah', () {
      final z = Zmanim.of(_place('Stockholm', 59.329, 18.069, 'Europe/Stockholm'), LocalDate(2026, 6, 20));
      expect(z.sunset, isNotNull);
      expect(z.candleLighting, isNotNull);
      expect(z.havdalah, isNull);
      expect(z.minutesOf(z.havdalah), isNull);
    });

    test('there is no sunset in the midnight sun, and no sunrise in the polar night', () {
      final murmansk = _place('Murmansk', 68.979, 33.093, 'Europe/Moscow');
      final summer = Zmanim.of(murmansk, LocalDate(2026, 6, 19));
      expect([summer.sunrise, summer.sunset, summer.candleLighting, summer.havdalah], everyElement(isNull));
      final winter = Zmanim.of(murmansk, LocalDate(2026, 12, 18));
      expect([winter.sunrise, winter.sunset, winter.candleLighting], everyElement(isNull));
    });
  });

  test('a time zone the device doesn\'t know gives no times', () {
    final z = Zmanim.of(_place('Nowhere', 31.77, 35.22, 'Mars/Olympus_Mons'), LocalDate(2026, 10, 16));
    expect([z.sunrise, z.sunset, z.candleLighting, z.havdalah], everyElement(isNull));
  });
}
