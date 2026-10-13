import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikrah/app/city_providers.dart';
import 'package:shnayim_mikrah/app/providers.dart';
import 'package:shnayim_mikrah/core/calendar/city.dart';
import 'package:shnayim_mikrah/core/calendar/local_date.dart';
import 'package:shnayim_mikrah/core/calendar/tz_database.dart';
import 'package:shnayim_mikrah/core/calendar/zmanim.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:timezone/timezone.dart' as tz;

const _jerusalem = City(
  id: 281184,
  nameEn: 'Jerusalem',
  countryCode: 'IL',
  latitude: 31.769,
  longitude: 35.2163,
  timeZone: 'Asia/Jerusalem',
  candleMinutes: 40,
);

// The tests run in order and share this test file's time-zone database,
// which nothing unloads: those before the one that loads it see the app as
// it starts, before the database is in.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A reader with a city for Shabbat times, and the database's provider as
  /// [database] has it.
  Future<ProviderContainer> containerWith(Future<void> Function(Ref ref) database) async {
    SharedPreferences.setMockInitialValues({
      SettingsController.storageKey: jsonEncode(const AppSettings(onboardingComplete: true, city: _jerusalem).toJson()),
    });
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      timeZoneDatabaseProvider.overrideWith(database),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('no city’s times are worked out before the database is in', () async {
    expect(timeZonesLoaded, isFalse);
    expect(Zmanim.timeZone('Asia/Jerusalem'), isNull);
    expect(Zmanim.keepsClock(_jerusalem, LocalDate(2026, 10, 16), const Duration(hours: 3)), isFalse);
    // Every zone would read as one the device doesn't know.
    expect(() => Zmanim.of(_jerusalem, LocalDate(2026, 10, 16)), throwsAssertionError);
    // Settings shows the city alone meanwhile, not that its times can't be
    // told.
    final c = await containerWith((ref) => Completer<void>().future);
    expect(c.read(shabbatTimesProvider), isNull);
  });

  test('decodes it when its schedule says, and once, however many callers wait', () async {
    final idle = Completer<void>();
    final scheduled = ensureTimeZones(schedule: (decode) async {
      await idle.future;
      decode();
    });
    await pumpEventQueue();
    expect(timeZonesLoaded, isFalse, reason: 'it waits for the UI to be idle');
    // The list of cities doesn't wait.
    await ensureTimeZones();
    expect(timeZonesLoaded, isTrue);
    // As the notification service sets the device's zone, which decoding
    // again would reset to UTC.
    tz.setLocalLocation(tz.getLocation('Asia/Jerusalem'));
    idle.complete();
    await scheduled;
    expect(tz.local.name, 'Asia/Jerusalem');
    await ensureTimeZones(schedule: (_) => fail('scheduled with the database in'));
    expect(Zmanim.timeZone('America/New_York')?.name, 'America/New_York');
  });

  test('Settings gives the city’s times once it is in', () async {
    final c = await containerWith((ref) async {});
    await c.read(timeZoneDatabaseProvider.future);
    final times = c.read(shabbatTimesProvider)!;
    expect(times.friday.timeZoneKnown, isTrue);
    expect(times.friday.candleLighting, isNotNull);
    expect(times.shabbat.havdalah, isNotNull);
  });
}
