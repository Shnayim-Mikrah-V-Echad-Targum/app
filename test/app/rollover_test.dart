import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';

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
}
