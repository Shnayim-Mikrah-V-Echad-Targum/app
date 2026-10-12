import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikra/app/city_providers.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/city.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/zmanim.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/today/today_clock.dart';
import 'package:shnayim_mikra/ui/widgets/ledger.dart';
import 'package:shnayim_mikra/ui/widgets/progress_widgets.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../helpers.dart';

final _settings = AppSettings(onboardingComplete: true, joinDate: LocalDate(2026, 10, 4));

/// Shabbat Bereshit, 10 October 2026 (29 Tishrei 5787), in the morning.
final _shabbat = DateTime(2026, 10, 10, 11);

const _jerusalem = City(
  id: 281184,
  nameEn: 'Jerusalem',
  nameHe: 'ירושלים',
  countryCode: 'IL',
  latitude: 31.769,
  longitude: 35.2163,
  timeZone: 'Asia/Jerusalem',
  candleMinutes: 40,
);

/// The clock of a device in Jerusalem: tests run on UTC.
Duration _jerusalemClock(LocalDate d) =>
    tz.TZDateTime(Zmanim.timeZone(_jerusalem.timeZone)!, d.year, d.month, d.day, 12).timeZoneOffset;

void main() {
  group('restDayProvider', () {
    /// The provider read at [now], with [settings], and a device on
    /// Jerusalem's clock with its time zones loaded.
    Future<ProviderContainer> containerAt(DateTime Function() now, {AppSettings? settings}) async {
      SharedPreferences.setMockInitialValues({
        SettingsController.storageKey: jsonEncode((settings ?? _settings).toJson()),
      });
      final prefs = await SharedPreferences.getInstance();
      final clock = TodayController.now;
      TodayController.now = now;
      final c = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        timeZoneDatabaseProvider.overrideWith((ref) async {}),
        deviceClockProvider.overrideWithValue(_jerusalemClock),
      ]);
      addTearDown(() {
        c.dispose();
        TodayController.now = clock;
      });
      await c.read(timeZoneDatabaseProvider.future);
      return c;
    }

    Future<LocalDate?> restAt(DateTime now, {AppSettings? settings}) async =>
        (await containerAt(() => now, settings: settings)).read(restDayProvider);

    setUp(() => TodayController.autoRollover = false);

    test('is the day of rest by the date, which turns at 3 a.m.', () async {
      final shabbat = LocalDate(2026, 10, 10);
      expect(await restAt(_shabbat), shabbat);
      expect(await restAt(DateTime(2026, 10, 10, 3, 0)), shabbat);
      // Friday night is still Friday until 3 a.m.
      expect(await restAt(DateTime(2026, 10, 10, 2, 59)), isNull);
      expect(await restAt(DateTime(2026, 10, 9, 21)), isNull);
      expect(await restAt(DateTime(2026, 10, 11, 10)), isNull);
    });

    test('without a city, lasts until 3 a.m., as nothing says when Shabbat ends', () async {
      final shabbat = LocalDate(2026, 10, 10);
      expect(await restAt(DateTime(2026, 10, 10, 22)), shabbat);
      expect(await restAt(DateTime(2026, 10, 11, 2, 30)), shabbat);
      expect(await restAt(DateTime(2026, 10, 11, 3, 0, 5)), isNull);
    });

    test("with a city, ends at nightfall there, on the city's clock", () async {
      final settings = _settings.copyWith(city: _jerusalem);
      final times = Zmanim.of(_jerusalem, LocalDate(2026, 10, 10));
      final minutes = times.minutesOf(times.havdalah)!;
      final nightfall = DateTime(2026, 10, 10, 0, minutes);
      expect(await restAt(nightfall.subtract(const Duration(minutes: 1)), settings: settings), LocalDate(2026, 10, 10));
      expect(await restAt(nightfall, settings: settings), isNull);
      expect(await restAt(DateTime(2026, 10, 10, 22), settings: settings), isNull);
    });

    test("with a city, begins as candles are lit there on its eve, on the city's clock", () async {
      final settings = _settings.copyWith(city: _jerusalem);
      final friday = LocalDate(2026, 10, 9);
      final times = Zmanim.of(_jerusalem, friday);
      final candles = DateTime(2026, 10, 9, 0, times.minutesOf(times.candleLighting)!);
      expect(await restAt(candles.subtract(const Duration(minutes: 1)), settings: settings), isNull);
      expect(await restAt(candles, settings: settings), LocalDate(2026, 10, 10));
      expect(await restAt(DateTime(2026, 10, 9, 21), settings: settings), LocalDate(2026, 10, 10));
      // Past midnight, the reading day is still Friday's; the rest goes on.
      expect(await restAt(DateTime(2026, 10, 10, 1), settings: settings), LocalDate(2026, 10, 10));
      // The eve of Yom Tov too: Erev Rosh Hashanah 5789, Wednesday 20
      // September 2028.
      final erev = Zmanim.of(_jerusalem, LocalDate(2028, 9, 20));
      final lit = DateTime(2028, 9, 20, 0, erev.minutesOf(erev.candleLighting)!);
      expect(await restAt(lit.subtract(const Duration(minutes: 1)), settings: settings), isNull);
      expect(await restAt(lit, settings: settings), LocalDate(2028, 9, 21));
    });

    test("by the reader's luach: from its candle-lighting until Shabbat ends by its rule", () async {
      final settings = _settings.copyWith(city: _jerusalem, candleMinutesOverride: 30, havdalah: HavdalahRule.min72);
      final friday = Zmanim.of(_jerusalem, LocalDate(2026, 10, 9), candleMinutes: 30);
      final candles = DateTime(2026, 10, 9, 0, friday.minutesOf(friday.candleLighting)!);
      // Ten minutes after the city's own forty.
      final cityCandles = Zmanim.of(_jerusalem, LocalDate(2026, 10, 9));
      expect(friday.minutesOf(friday.candleLighting), cityCandles.minutesOf(cityCandles.candleLighting)! + 10);
      expect(await restAt(candles.subtract(const Duration(minutes: 1)), settings: settings), isNull);
      expect(await restAt(candles, settings: settings), LocalDate(2026, 10, 10));

      final shabbat = Zmanim.of(_jerusalem, LocalDate(2026, 10, 10), havdalah: HavdalahRule.min72);
      final ends = DateTime(2026, 10, 10, 0, shabbat.minutesOf(shabbat.havdalah)!);
      expect(shabbat.minutesOf(shabbat.havdalah)! - shabbat.minutesOf(shabbat.sunset)!, inInclusiveRange(72, 73));
      // Past nightfall at 8.5°, Shabbat goes on until the luach's time.
      final nightfall = Zmanim.of(_jerusalem, LocalDate(2026, 10, 10));
      expect(await restAt(DateTime(2026, 10, 10, 0, nightfall.minutesOf(nightfall.havdalah)!), settings: settings),
          LocalDate(2026, 10, 10));
      expect(await restAt(ends.subtract(const Duration(minutes: 1)), settings: settings), LocalDate(2026, 10, 10));
      expect(await restAt(ends, settings: settings), isNull);
    });

    test("not from candle-lighting on a device that has left the city's clock behind", () async {
      final settings = _settings.copyWith(city: _jerusalem);
      SharedPreferences.setMockInitialValues({SettingsController.storageKey: jsonEncode(settings.toJson())});
      final prefs = await SharedPreferences.getInstance();
      TodayController.now = () => DateTime(2026, 10, 9, 21);
      final c = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        timeZoneDatabaseProvider.overrideWith((ref) async {}),
        deviceClockProvider.overrideWithValue((_) => const Duration(hours: -4)),
      ]);
      addTearDown(c.dispose);
      await c.read(timeZoneDatabaseProvider.future);
      expect(c.read(restDayProvider), isNull, reason: 'Friday until 3 a.m.');
    });

    test("not on a device that has left the city's clock behind", () async {
      final settings = _settings.copyWith(city: _jerusalem);
      SharedPreferences.setMockInitialValues({SettingsController.storageKey: jsonEncode(settings.toJson())});
      final prefs = await SharedPreferences.getInstance();
      TodayController.now = () => DateTime(2026, 10, 10, 22);
      final c = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        timeZoneDatabaseProvider.overrideWith((ref) async {}),
        // New York's clock.
        deviceClockProvider.overrideWithValue((_) => const Duration(hours: -4)),
      ]);
      addTearDown(c.dispose);
      await c.read(timeZoneDatabaseProvider.future);
      expect(c.read(restDayProvider), LocalDate(2026, 10, 10), reason: 'the day lasts until 3 a.m.');
    });

    test('goes on through Yom Tov after Shabbat, whatever the time', () async {
      // Shabbat 19 May 2029, then Shavuot on Sunday and, outside Israel,
      // Monday.
      final settings = _settings.copyWith(city: _jerusalem);
      expect(await restAt(DateTime(2029, 5, 19, 23), settings: settings), LocalDate(2029, 5, 19));
      expect(await restAt(DateTime(2029, 5, 21, 12), settings: settings), LocalDate(2029, 5, 21));
      expect(await restAt(DateTime(2029, 5, 21, 12), settings: settings.copyWith(oneDayYomTov: true)), isNull);
    });

    testWidgets('begins at candle-lighting while the app is open', (tester) async {
      TodayController.autoRollover = true;
      addTearDown(() => TodayController.autoRollover = false);
      final times = Zmanim.of(_jerusalem, LocalDate(2026, 10, 9));
      var now = DateTime(2026, 10, 9, 0, times.minutesOf(times.candleLighting)! - 1);
      SharedPreferences.setMockInitialValues({
        SettingsController.storageKey: jsonEncode(_settings.copyWith(city: _jerusalem).toJson()),
      });
      final prefs = await SharedPreferences.getInstance();
      final clock = TodayController.now;
      TodayController.now = () => now;
      addTearDown(() => TodayController.now = clock);
      final c = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        timeZoneDatabaseProvider.overrideWith((ref) async {}),
        deviceClockProvider.overrideWithValue(_jerusalemClock),
      ]);
      await c.read(timeZoneDatabaseProvider.future);
      final seen = <LocalDate?>[];
      c.listen(restDayProvider, (_, next) => seen.add(next), fireImmediately: true);
      expect(seen, [null]);
      now = now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      expect(seen, [null, LocalDate(2026, 10, 10)]);
      c.dispose();
    });

    testWidgets('turns at nightfall while the app is open', (tester) async {
      TodayController.autoRollover = true;
      addTearDown(() => TodayController.autoRollover = false);
      final times = Zmanim.of(_jerusalem, LocalDate(2026, 10, 10));
      var now = DateTime(2026, 10, 10, 0, times.minutesOf(times.havdalah)! - 1);
      SharedPreferences.setMockInitialValues({
        SettingsController.storageKey: jsonEncode(_settings.copyWith(city: _jerusalem).toJson()),
      });
      final prefs = await SharedPreferences.getInstance();
      final clock = TodayController.now;
      TodayController.now = () => now;
      addTearDown(() => TodayController.now = clock);
      final c = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        timeZoneDatabaseProvider.overrideWith((ref) async {}),
        deviceClockProvider.overrideWithValue(_jerusalemClock),
      ]);
      await c.read(timeZoneDatabaseProvider.future);
      final seen = <LocalDate?>[];
      c.listen(restDayProvider, (_, next) => seen.add(next), fireImmediately: true);
      expect(seen, [LocalDate(2026, 10, 10)]);
      now = now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      expect(seen, [LocalDate(2026, 10, 10), null]);
      // Its timers, and the reading day's, end with it.
      c.dispose();
    });
  });

  group('Today on Shabbat', () {
    Future<ProviderContainer> openToday(WidgetTester tester, {AppSettings? settings, DateTime? now}) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await pumpApp(tester, settings: settings ?? _settings, now: now ?? _shabbat);
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('shows only the rest: a greeting, the parsha, and the way to it', (tester) async {
      final c = await openToday(tester);
      expect(find.byType(ShabbatCandlesIcon), findsOneWidget);
      expect(find.text('Shabbat Shalom'), findsOneWidget);
      expect(find.bySemanticsLabel('Parshat Bereshit'), findsOneWidget);
      expect(find.text('Reading from a printed Chumash today?'), findsOneWidget);
      expect(find.text('You can log it after Shabbat.'), findsOneWidget);
      // The running head gives Shabbat's date, not the reading day's.
      expect(find.textContaining('Saturday, October 10'), findsOneWidget);
      // No rings, buttons to read, Today card, week or streaks.
      expect(find.byType(ParshaRings), findsNothing);
      expect(find.bySubtype<FilledButton>(), findsNothing);
      expect(find.text('Today’s reading'), findsNothing);
      expect(find.text('Catching up'), findsNothing);
      expect(find.byType(WeekStrip), findsNothing);
      expect(find.byType(LedgerCard), findsNothing);
      expect(find.text('Shavua tov! Did you read on Shabbat?'), findsNothing);
      // Nothing moves.
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.tap(find.text('Open the parsha'));
      await tester.pump();
      expect(c.read(routerProvider).state.uri.path, '/today/week/5787:1');
    });

    testWidgets('greets Yom Tov, and logs after the last day of rest', (tester) async {
      // Shavuot 5789, Sunday and Monday 20 and 21 May, after Shabbat
      // Bamidbar: Naso is next.
      await openToday(tester, now: DateTime(2029, 5, 20, 11));
      expect(find.text('Chag Sameach'), findsOneWidget);
      expect(find.bySemanticsLabel('Parshat Naso'), findsOneWidget);
      expect(find.text('You can log it after Yom Tov.'), findsOneWidget);

      // On the Shabbat before it, Shabbat's greeting, and after Yom Tov.
      await openToday(tester, now: DateTime(2029, 5, 19, 11));
      expect(find.text('Shabbat Shalom'), findsOneWidget);
      expect(find.bySemanticsLabel('Parshat Bamidbar'), findsOneWidget);
      expect(find.text('You can log it after Yom Tov.'), findsOneWidget);

      // Monday is the second day, kept only outside Israel.
      await openToday(tester, now: DateTime(2029, 5, 21, 11));
      expect(find.text('Chag Sameach'), findsOneWidget);
      await openToday(tester, settings: _settings.copyWith(oneDayYomTov: true), now: DateTime(2029, 5, 21, 11));
      expect(find.text('Chag Sameach'), findsNothing);
      expect(find.bySubtype<FilledButton>(), findsWidgets, reason: 'a reading day');
    });

    testWidgets('greets Rosh Hashanah and Yom Kippur with their own words', (tester) async {
      final joined = _settings.copyWith(joinDate: LocalDate(2024, 9, 1));
      // Rosh Hashanah 5787, on Shabbat 12 and Sunday 13 September 2026.
      await openToday(tester, settings: joined, now: DateTime(2026, 9, 12, 11));
      expect(find.text('Shanah Tovah'), findsOneWidget);
      await openToday(tester, settings: joined, now: DateTime(2026, 9, 13, 11));
      expect(find.text('Shanah Tovah'), findsOneWidget);
      expect(find.text('You can log it after Yom Tov.'), findsOneWidget);
      // Yom Kippur 5787, on Monday 21 September 2026, a fast: no "Chag
      // Sameach", and logged after Yom Kippur.
      await openToday(tester, settings: joined, now: DateTime(2026, 9, 21, 11));
      expect(find.text('G’mar Chatimah Tovah'), findsOneWidget);
      expect(find.text('Chag Sameach'), findsNothing);
      expect(find.text('You can log it after Yom Kippur.'), findsOneWidget);
      // On Shabbat too, as in 5785.
      await openToday(tester, settings: joined, now: DateTime(2024, 10, 12, 11));
      expect(find.text('G’mar Chatimah Tovah'), findsOneWidget);
      expect(find.text('Shabbat Shalom'), findsNothing);
      expect(find.text('You can log it after Yom Kippur.'), findsOneWidget);

      final hebrew = joined.copyWith(language: AppLanguage.hebrew);
      await openToday(tester, settings: hebrew, now: DateTime(2026, 9, 12, 11));
      expect(find.text('שנה טובה'), findsOneWidget);
      await openToday(tester, settings: hebrew, now: DateTime(2026, 9, 21, 11));
      expect(find.text('גמר חתימה טובה'), findsOneWidget);
      expect(find.text('חג שמח'), findsNothing);
      expect(find.text('אפשר לרשום זאת אחרי יום כיפור.'), findsOneWidget);
    });

    testWidgets("rests from candle-lighting on Friday evening in the reader's city", (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpApp(
        tester,
        settings: _settings.copyWith(city: _jerusalem),
        now: DateTime(2026, 10, 9, 21),
        overrides: [
          timeZoneDatabaseProvider.overrideWith((ref) async {}),
          deviceClockProvider.overrideWithValue(_jerusalemClock),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.text('Shabbat Shalom'), findsOneWidget);
      expect(find.textContaining('Saturday, October 10'), findsOneWidget);
      expect(find.bySubtype<FilledButton>(), findsNothing);
    });

    testWidgets('in Hebrew', (tester) async {
      await openToday(tester, settings: _settings.copyWith(language: AppLanguage.hebrew));
      expect(find.text('שבת שלום'), findsOneWidget);
      expect(find.text('קוראים היום מתוך חומש?'), findsOneWidget);
      expect(find.text('אפשר לרשום זאת אחרי השבת.'), findsOneWidget);
      expect(find.text('לפרשה'), findsOneWidget);
    });

    testWidgets("is a reading day again once Shabbat is out in the reader's city", (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpApp(
        tester,
        settings: _settings.copyWith(city: _jerusalem),
        now: DateTime(2026, 10, 10, 20),
        overrides: [
          timeZoneDatabaseProvider.overrideWith((ref) async {}),
          deviceClockProvider.overrideWithValue(_jerusalemClock),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.text('Shabbat Shalom'), findsNothing);
      expect(find.text('Shavua tov! Did you read on Shabbat?'), findsOneWidget);
    });
  });
}
