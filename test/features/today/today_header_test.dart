import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikra/app/city_providers.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/core/calendar/city.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/zmanim.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/today/today_clock.dart';
import 'package:shnayim_mikra/ui/widgets/lines.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../helpers.dart';

/// Joined before the week of Bereshit, read on Shabbat 10 October 2026
/// (29 Tishrei 5787).
final _settings = AppSettings(onboardingComplete: true, joinDate: LocalDate(2026, 10, 4));

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
  /// Today at [now], on a device in Jerusalem with the city chosen for
  /// Shabbat times, in [language].
  Future<void> openToday(WidgetTester tester, DateTime now, {AppLanguage language = AppLanguage.english}) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      settings: _settings.copyWith(city: _jerusalem, language: language),
      now: now,
      overrides: [
        timeZoneDatabaseProvider.overrideWith((ref) async {}),
        deviceClockProvider.overrideWithValue(_jerusalemClock),
      ],
    );
    await tester.pumpAndSettle();
  }

  /// The running head, its parts between middle dots: the first [DotLine]
  /// on the page.
  String runningHead(WidgetTester tester) =>
      tester.widget<DotLine>(find.byType(DotLine).first).parts.join(DotLine.separator);

  group("Today's running head", () {
    testWidgets('on a reading day gives its date in both calendars', (tester) async {
      await openToday(tester, DateTime(2026, 10, 9, 11));
      expect(runningHead(tester), 'Friday, October 9 · 28 Tishrei 5787');
      await openToday(tester, DateTime(2026, 10, 9, 11), language: AppLanguage.hebrew);
      expect(runningHead(tester), 'יום שישי, כ״ח בתשרי תשפ״ז · 9 באוקטובר');
    });

    testWidgets("on Friday night keeps the device's date beside Shabbat's Hebrew one", (tester) async {
      // After candle-lighting in Jerusalem, Today rests.
      await openToday(tester, DateTime(2026, 10, 9, 20));
      expect(find.text('Shabbat Shalom'), findsOneWidget);
      expect(runningHead(tester), 'Friday, October 9 · 29 Tishrei 5787');
      expect(find.textContaining('Saturday'), findsNothing);
      // The Hebrew weekday goes with the Hebrew date: by its reckoning,
      // Friday night is Shabbat already.
      await openToday(tester, DateTime(2026, 10, 9, 20), language: AppLanguage.hebrew);
      expect(runningHead(tester), 'יום שבת, כ״ט בתשרי תשפ״ז · 9 באוקטובר');
      // Past midnight, the date turns at 3 a.m., as the reading day does.
      await openToday(tester, DateTime(2026, 10, 10, 1));
      expect(runningHead(tester), 'Friday, October 9 · 29 Tishrei 5787');
    });

    testWidgets('on Shabbat gives its date', (tester) async {
      await openToday(tester, DateTime(2026, 10, 10, 11));
      expect(runningHead(tester), 'Saturday, October 10 · 29 Tishrei 5787');
      await openToday(tester, DateTime(2026, 10, 10, 11), language: AppLanguage.hebrew);
      expect(runningHead(tester), 'יום שבת, כ״ט בתשרי תשפ״ז · 10 באוקטובר');
    });

    testWidgets("on Motzaei Shabbat keeps the device's date beside Sunday's Hebrew one", (tester) async {
      // After nightfall in Jerusalem the reading day is Sunday's.
      await openToday(tester, DateTime(2026, 10, 10, 20));
      expect(runningHead(tester), 'Saturday, October 10 · 30 Tishrei 5787');
      await openToday(tester, DateTime(2026, 10, 10, 20), language: AppLanguage.hebrew);
      expect(runningHead(tester), 'יום ראשון, ל׳ בתשרי תשפ״ז · 10 באוקטובר');
    });
  });

  group('civilDateProvider', () {
    setUp(() {
      // It listens for the app resuming, as the reading day does.
      TestWidgetsFlutterBinding.ensureInitialized();
      TodayController.autoRollover = false;
    });

    test('is the date, which turns at 3 a.m., whatever the day of rest', () async {
      SharedPreferences.setMockInitialValues({SettingsController.storageKey: jsonEncode(_settings.toJson())});
      final prefs = await SharedPreferences.getInstance();
      final clock = TodayController.now;
      addTearDown(() => TodayController.now = clock);
      for (final (now, date) in [
        (DateTime(2026, 10, 9, 21), LocalDate(2026, 10, 9)),
        (DateTime(2026, 10, 10, 2, 59), LocalDate(2026, 10, 9)),
        (DateTime(2026, 10, 10, 3), LocalDate(2026, 10, 10)),
        (DateTime(2026, 10, 10, 22), LocalDate(2026, 10, 10)),
      ]) {
        TodayController.now = () => now;
        final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
        addTearDown(c.dispose);
        expect(c.read(civilDateProvider), date, reason: '$now');
      }
    });

    testWidgets('turns at 3 a.m. while the app is open', (tester) async {
      TodayController.autoRollover = true;
      addTearDown(() => TodayController.autoRollover = false);
      SharedPreferences.setMockInitialValues({SettingsController.storageKey: jsonEncode(_settings.toJson())});
      final prefs = await SharedPreferences.getInstance();
      // Motzaei Shabbat, past nightfall: the reading day is already Sunday,
      // and stays so as the date turns to it.
      var now = DateTime(2026, 10, 10, 23);
      final clock = TodayController.now;
      TodayController.now = () => now;
      addTearDown(() => TodayController.now = clock);
      final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      final seen = <LocalDate>[];
      c.listen(civilDateProvider, (_, next) => seen.add(next), fireImmediately: true);
      expect(seen, [LocalDate(2026, 10, 10)]);
      final turn = nextRollover(now);
      await tester.pump(turn.difference(now) - const Duration(seconds: 1));
      expect(seen, [LocalDate(2026, 10, 10)]);
      now = turn;
      await tester.pump(const Duration(seconds: 1));
      expect(seen, [LocalDate(2026, 10, 10), LocalDate(2026, 10, 11)]);
      expect(c.read(todayProvider), LocalDate(2026, 10, 11));
      // Its timers, and the reading day's, end with it.
      c.dispose();
    });
  });
}
