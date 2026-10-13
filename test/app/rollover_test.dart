import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikrah/app/providers.dart';
import 'package:shnayim_mikrah/core/calendar/local_date.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/features/today/today_clock.dart';

/// Every half hour from [from] until [to], by the hours that pass.
Iterable<DateTime> _halfHours(DateTime from, DateTime to) sync* {
  for (var t = from; t.isBefore(to); t = t.add(const Duration(minutes: 30))) {
    yield t;
  }
}

/// Expects [nextRollover] after [t] to come just after [rolloverDate] turns
/// to the next day: not before, as a timer set for it would then find the
/// day unchanged, nor long after.
void _expectTurn(DateTime t) {
  final day = rolloverDate(t);
  final next = nextRollover(t);
  expect(next.isAfter(t), isTrue, reason: '$next, after $t');
  expect(rolloverDate(next), day.addDays(1), reason: 'the day has turned at $next, after $t');
  expect(
    rolloverDate(next.subtract(const Duration(seconds: 10))),
    day,
    reason: 'the day has not turned ten seconds before $next, after $t',
  );
}

// Local time follows the process's time zone. CI runs this file in
// Israel's too (TZ=Asia/Jerusalem), whose clocks change on the days below.
void main() {
  group('nextRollover', () {
    test('turns the day as the clocks go forward', () {
      // Israel's on Friday 26 March 2027 at 2:00: a timer set that night
      // for 3:00 on the wall came while the day was still Thursday's, and
      // Today stayed on Thursday. Europe's on Sunday 28 March.
      _halfHours(DateTime(2027, 3, 25), DateTime(2027, 3, 29)).forEach(_expectTurn);
    });

    test('turns the day as the clocks go back', () {
      // Israel's on Sunday 25 October 2026 and Sunday 31 October 2027,
      // Europe's on the same days, and America's on 1 and 7 November.
      _halfHours(DateTime(2026, 10, 22), DateTime(2026, 10, 27)).forEach(_expectTurn);
      _halfHours(DateTime(2026, 10, 31), DateTime(2026, 11, 2)).forEach(_expectTurn);
      _halfHours(DateTime(2027, 10, 22), DateTime(2027, 11, 1)).forEach(_expectTurn);
      _halfHours(DateTime(2027, 11, 6), DateTime(2027, 11, 8)).forEach(_expectTurn);
    });

    test('turns the day every day of the year, whatever the time zone', () {
      _halfHours(DateTime(2027, 1, 1), DateTime(2028, 1, 1)).forEach(_expectTurn);
    });

    test('is five seconds after 3 a.m. on a day the clocks keep', () {
      expect(nextRollover(DateTime(2026, 10, 9, 21)), DateTime(2026, 10, 10, 3, 0, 5));
      expect(nextRollover(DateTime(2026, 10, 10, 2, 59)), DateTime(2026, 10, 10, 3, 0, 5));
      expect(nextRollover(DateTime(2026, 10, 10, 3, 0, 5)), DateTime(2026, 10, 11, 3, 0, 5));
    });
  });

  // The timers that turn the day while the app is open, each aimed by
  // nextRollover. One aimed at 3 a.m. on the wall would, in Israel's time
  // zone, fire an hour before the turn on the night the clocks go forward
  // and wait for the next night, or an hour after it on the night they go
  // back; on UTC these pass either way.
  group('while the app is open, as the clocks change', () {
    late DateTime now;
    late ProviderContainer c;

    setUp(() {
      TodayController.autoRollover = true;
      final clock = TodayController.now;
      TodayController.now = () => now;
      addTearDown(() {
        TodayController.now = clock;
        TodayController.autoRollover = false;
      });
    });

    Future<void> open(DateTime start) async {
      now = start;
      SharedPreferences.setMockInitialValues({
        SettingsController.storageKey: jsonEncode(
          // No city: a day of rest lasts from 3 a.m. to 3 a.m.
          AppSettings(onboardingComplete: true, joinDate: LocalDate(2026, 9, 1)).toJson(),
        ),
      });
      final prefs = await SharedPreferences.getInstance();
      c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      for (final provider in [todayProvider, civilDateProvider, restDayProvider]) {
        c.listen(provider, (_, _) {});
      }
    }

    /// Lets the hours pass until [to], a minute at a time, the clock with
    /// them.
    Future<void> passUntil(WidgetTester tester, DateTime to) async {
      while (now.isBefore(to)) {
        now = now.add(const Duration(minutes: 1));
        await tester.pump(const Duration(minutes: 1));
      }
    }

    testWidgets('the reading day and the date turn as the clocks go forward', (tester) async {
      // Friday 26 March 2027, at 1:00: in Israel the clocks go forward at
      // 2:00, and the day turns at 4:00 on the wall.
      await open(DateTime(2027, 3, 26, 1));
      expect(c.read(todayProvider), LocalDate(2027, 3, 25));
      expect(c.read(civilDateProvider), LocalDate(2027, 3, 25));
      final turn = nextRollover(now);
      await passUntil(tester, turn.subtract(const Duration(minutes: 1)));
      expect(c.read(todayProvider), LocalDate(2027, 3, 25));
      await passUntil(tester, turn.add(const Duration(minutes: 1)));
      expect(c.read(todayProvider), LocalDate(2027, 3, 26));
      expect(c.read(civilDateProvider), LocalDate(2027, 3, 26));
      c.dispose();
    });

    testWidgets('Shabbat ends at the turn as the clocks go back', (tester) async {
      // Shabbat 24 October 2026, at 23:00: in Israel the clocks go back at
      // 2:00 on Sunday, and the day turns at 2:00 on the wall, the second
      // time. The reading day is Sunday's throughout, so only the day of
      // rest's own timer ends it.
      await open(DateTime(2026, 10, 24, 23));
      expect(c.read(restDayProvider), LocalDate(2026, 10, 24));
      expect(c.read(todayProvider), LocalDate(2026, 10, 25));
      final turn = nextRollover(now);
      await passUntil(tester, turn.subtract(const Duration(minutes: 1)));
      expect(c.read(restDayProvider), LocalDate(2026, 10, 24));
      await passUntil(tester, turn.add(const Duration(minutes: 1)));
      expect(c.read(restDayProvider), isNull);
      expect(c.read(civilDateProvider), LocalDate(2026, 10, 25));
      expect(c.read(todayProvider), LocalDate(2026, 10, 25));
      c.dispose();
    });
  });
}
