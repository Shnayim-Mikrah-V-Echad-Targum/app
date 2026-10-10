import 'dart:math' as math;

import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'city.dart';
import 'local_date.dart';

/// The sun's times, and Shabbat's, on one day in one place, on the place's
/// own clock. Worked out on the device and never fetched (DESIGN.md §2).
///
/// Sunrise and sunset are those of the sun's upper edge at sea level, with
/// the usual allowance for refraction, as Hebcal and most calendars have
/// them.
class Zmanim {
  const Zmanim._(this.date, {this.sunrise, this.sunset, this.candleLighting, this.havdalah, this.timeZoneKnown = true});

  /// The times of [city] on [date]. Every time is null in a time zone the
  /// device doesn't know ([timeZoneKnown]).
  factory Zmanim.of(City city, LocalDate date) {
    final location = timeZone(city.timeZone);
    if (location == null) return Zmanim._(date, timeZoneKnown: false);
    final lat = city.latitude, lon = city.longitude;
    // The UTC day whose noon at the place falls on [date] on its clock. It is
    // [date] itself unless the clock is far from the sun (Kiribati's, a day
    // ahead of its longitude).
    var day = _julianDay(date);
    for (var i = 0; i < 2; i++) {
      final noon = _instant(day, _Sun.noon(day, lon), location);
      final ahead = LocalDate(noon.year, noon.month, noon.day).differenceInDays(date);
      if (ahead == 0) break;
      day -= ahead;
    }
    tz.TZDateTime? at(double? minutes) => minutes == null ? null : _instant(day, minutes, location);
    final sunset = at(_Sun.event(day, lat, lon, _sunsetZenith, rising: false));
    final nightfall = at(_Sun.event(day, lat, lon, _havdalahZenith, rising: false));
    return Zmanim._(
      date,
      sunrise: at(_Sun.event(day, lat, lon, _sunsetZenith, rising: true)),
      sunset: sunset,
      candleLighting: sunset == null ? null : _toMinute(sunset.subtract(Duration(minutes: city.candleMinutes))),
      havdalah: nightfall == null ? null : _toMinute(nightfall, up: true),
    );
  }

  final LocalDate date;

  /// Whether the device knows the place's time zone, without which no time
  /// can be given.
  final bool timeZoneKnown;

  /// Null on a day the sun doesn't rise, or doesn't set, there: near the
  /// poles.
  final tz.TZDateTime? sunrise;
  final tz.TZDateTime? sunset;

  /// [sunset] less the place's candle-lighting minutes ([City.candleMinutes]),
  /// rounded down to the minute so that it is never late.
  final tz.TZDateTime? candleLighting;

  /// Nightfall, when three small stars are out: the sun 8.5° below the
  /// horizon. Rounded up to the minute so that it is never early. Null where
  /// the sky never gets that dark, as in a northern summer above about 58°.
  final tz.TZDateTime? havdalah;

  /// [time] as minutes after the midnight that begins [date] on the place's
  /// clock: 1440 or more for a time after the next midnight (Havdalah in a
  /// northern summer).
  int? minutesOf(tz.TZDateTime? time) {
    if (time == null) return null;
    return LocalDate(time.year, time.month, time.day).differenceInDays(date) * 1440 + time.hour * 60 + time.minute;
  }

  /// The sun's upper edge on the horizon: 90° from the zenith, plus 34′ of
  /// refraction and 16′ for its radius.
  static const _sunsetZenith = 90 + 50 / 60;

  /// The sun's centre 8.5° below the horizon.
  static const _havdalahZenith = 98.5;

  /// The IANA time zone [name], or null if the device doesn't know it.
  static tz.Location? timeZone(String name) {
    // The notification service also loads the database, and loading it again
    // would reset its local time zone.
    if (!tz.timeZoneDatabase.isInitialized) tzdata.initializeTimeZones();
    try {
      return tz.getLocation(name);
    } on tz.LocationNotFoundException {
      return null;
    }
  }

  /// Whether [city]'s clock reads as a clock [offset] from UTC at noon on
  /// [date] does, such as the device's ([deviceNoonOffset]): clocks change at
  /// night, so noon tells the day's offset. When it doesn't, as for a
  /// traveller who has left the city behind, the city's times are not the
  /// device's, and given on its clock they would mislead. False in a time
  /// zone the device doesn't know.
  static bool keepsClock(City city, LocalDate date, Duration offset) {
    final location = timeZone(city.timeZone);
    return location != null && tz.TZDateTime(location, date.year, date.month, date.day, 12).timeZoneOffset == offset;
  }

  /// The Julian day at the midnight (UT) that begins [date].
  static double _julianDay(LocalDate date) => date.rd + 1721424.5;

  /// The moment [minutes] after the midnight (UT) of the Julian day [day].
  static tz.TZDateTime _instant(double day, double minutes, tz.Location location) =>
      tz.TZDateTime.fromMillisecondsSinceEpoch(location, (((day - 2440587.5) * 1440 + minutes) * 60000).round());

  /// [time] rounded down, or [up], to the minute. Time zones differ from UTC
  /// by whole minutes, so this is the minute on the place's clock too.
  static tz.TZDateTime _toMinute(tz.TZDateTime time, {bool up = false}) {
    final ms = time.millisecondsSinceEpoch;
    final into = ms % 60000;
    if (into == 0) return time;
    return tz.TZDateTime.fromMillisecondsSinceEpoch(time.location, ms - into + (up ? 60000 : 0));
  }
}

/// The device clock's offset from UTC at noon on [date].
Duration deviceNoonOffset(LocalDate date) => DateTime(date.year, date.month, date.day, 12).timeZoneOffset;

/// The sun's position and times by the formulas of NOAA's Solar Calculator
/// (after Meeus, Astronomical Algorithms), which are in the public domain.
/// Angles are in degrees and times in minutes.
abstract final class _Sun {
  static double _rad(double degrees) => degrees * math.pi / 180;
  static double _deg(double radians) => radians * 180 / math.pi;

  /// The sun's declination and the equation of time, [minutes] after the
  /// midnight (UT) of the Julian day [day].
  static ({double declination, double equationOfTime}) _position(double day, double minutes) {
    final t = (day + minutes / 1440 - 2451545) / 36525; // Julian centuries since J2000.0
    final meanLongitude = (280.46646 + t * (36000.76983 + t * 0.0003032)) % 360;
    final meanAnomaly = _rad(357.52911 + t * (35999.05029 - 0.0001537 * t));
    final eccentricity = 0.016708634 - t * (0.000042037 + 0.0000001267 * t);
    final centre = math.sin(meanAnomaly) * (1.914602 - t * (0.004817 + 0.000014 * t)) +
        math.sin(2 * meanAnomaly) * (0.019993 - 0.000101 * t) +
        math.sin(3 * meanAnomaly) * 0.000289;
    final omega = _rad(125.04 - 1934.136 * t);
    final apparentLongitude = meanLongitude + centre - 0.00569 - 0.00478 * math.sin(omega);
    final meanObliquity = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60;
    final obliquity = _rad(meanObliquity + 0.00256 * math.cos(omega));
    final declination = _deg(math.asin(math.sin(obliquity) * math.sin(_rad(apparentLongitude))));
    final y = math.pow(math.tan(obliquity / 2), 2);
    final l0 = _rad(meanLongitude);
    final e = eccentricity;
    final equation = y * math.sin(2 * l0) -
        2 * e * math.sin(meanAnomaly) +
        4 * e * y * math.sin(meanAnomaly) * math.cos(2 * l0) -
        0.5 * y * y * math.sin(4 * l0) -
        1.25 * e * e * math.sin(2 * meanAnomaly);
    return (declination: declination, equationOfTime: 4 * _deg(equation));
  }

  /// Minutes after the midnight (UT) of the Julian day [day] of the sun's
  /// transit at [longitude] (east positive).
  static double noon(double day, double longitude) {
    var minutes = 720 - 4 * longitude;
    for (var i = 0; i < 2; i++) {
      minutes = 720 - 4 * longitude - _position(day, minutes).equationOfTime;
    }
    return minutes;
  }

  /// Minutes after the midnight (UT) of the Julian day [day] at which the
  /// sun's centre, [rising] or setting, is [zenith] from the zenith at
  /// [latitude] and [longitude], or null if it isn't that day.
  static double? event(double day, double latitude, double longitude, double zenith, {required bool rising}) {
    // From the place's noon, three times at the time found, as the sun moves.
    var minutes = noon(day, longitude);
    for (var i = 0; i < 3; i++) {
      final sun = _position(day, minutes);
      final lat = _rad(latitude), dec = _rad(sun.declination);
      final cosHourAngle = math.cos(_rad(zenith)) / (math.cos(lat) * math.cos(dec)) - math.tan(lat) * math.tan(dec);
      if (cosHourAngle.isNaN || cosHourAngle.abs() > 1) return null;
      final hourAngle = _deg(math.acos(cosHourAngle));
      minutes = 720 - 4 * (longitude + (rising ? hourAngle : -hourAngle)) - sun.equationOfTime;
    }
    return minutes;
  }
}
