import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/city_providers.dart';
import 'package:shnayim_mikra/core/calendar/city.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/zmanim.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../helpers.dart';

const _london = City(
  id: 2643743,
  nameEn: 'London',
  nameHe: 'לונדון',
  countryCode: 'GB',
  latitude: 51.5085,
  longitude: -0.1257,
  timeZone: 'Europe/London',
);

final _settings = AppSettings(onboardingComplete: true, joinDate: LocalDate(2026, 9, 1), city: _london);

/// A device keeping the clock of the IANA time zone [name].
Duration Function(LocalDate) _clockOf(String name) {
  final location = Zmanim.timeZone(name)!;
  return (d) => tz.TZDateTime(location, d.year, d.month, d.day, 12).timeZoneOffset;
}

/// Friday of Noach 5787, 16 October 2026: candles are lit at 17:47 in London.
final _friday = DateTime(2026, 10, 16, 10);

void main() {
  // Loaded as the app loads it once the first frame is up, which tests never
  // report.
  setUpAll(() => Zmanim.timeZone('UTC'));

  /// Opens Today on a device keeping London's clock, or [clock]'s.
  Future<void> openToday(WidgetTester tester, AppSettings settings, DateTime now, {String clock = 'Europe/London'}) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(tester, settings: settings, now: now, overrides: [
      deviceClockProvider.overrideWithValue(_clockOf(clock)),
    ]);
    await tester.pumpAndSettle();
  }

  /// The text [data], whatever spaces the time format puts before "PM".
  Finder text(String data) => find.byWidgetPredicate(
        (w) => w is Text && w.data?.replaceAll(RegExp('[\u00A0\u202F]'), ' ') == data,
      );

  testWidgets('on Erev Shabbat, Today says when candles are lit in the city, in place of the countdown',
      (tester) async {
    await openToday(tester, _settings, _friday);
    expect(text('Candle-lighting 5:47 PM'), findsOneWidget);
    expect(find.text('Shabbat is tomorrow'), findsNothing);
  });

  testWidgets('in Hebrew, the time is a left-to-right run', (tester) async {
    await openToday(tester, _settings.copyWith(language: AppLanguage.hebrew), _friday);
    expect(find.text('הדלקת נרות \u206617:47\u2069'), findsOneWidget);
  });

  testWidgets('on Erev Yom Tov, in place of the countdown to Shabbat', (tester) async {
    // Wednesday 20 September 2028, Erev Rosh Hashanah 5789, in the week of
    // Haazinu, which is read on Shabbat the 23rd.
    final erev = DateTime(2028, 9, 20, 10);
    await openToday(tester, _settings.copyWith(city: null), erev);
    expect(find.text('Shabbat in 3 days'), findsOneWidget);

    await openToday(tester, _settings, erev);
    expect(find.textContaining('Candle-lighting'), findsOneWidget);
    expect(find.text('Shabbat in 3 days'), findsNothing);
  });

  testWidgets('on other days, and without a city, the countdown stays', (tester) async {
    await openToday(tester, _settings, DateTime(2026, 10, 15, 10));
    expect(find.text('Shabbat in 2 days'), findsOneWidget);
    expect(find.textContaining('Candle-lighting'), findsNothing);

    await openToday(tester, _settings.copyWith(city: null), _friday);
    expect(find.text('Shabbat is tomorrow'), findsOneWidget);
    expect(find.textContaining('Candle-lighting'), findsNothing);
  });

  testWidgets("on a device keeping another clock, the countdown stays: the city's time would read as local",
      (tester) async {
    // Travelling in New York, with London still chosen: candles there are
    // lit at 17:47 London time, 12:47 in New York.
    await openToday(tester, _settings, _friday, clock: 'America/New_York');
    expect(find.text('Shabbat is tomorrow'), findsOneWidget);
    expect(find.textContaining('Candle-lighting'), findsNothing);

    // Back home, once the clocks agree, it shows again.
    await openToday(tester, _settings, _friday, clock: 'Europe/London');
    expect(text('Candle-lighting 5:47 PM'), findsOneWidget);
  });

  testWidgets('it fits at 200% text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await openToday(tester, _settings, _friday);
    expect(text('Candle-lighting 5:47 PM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
