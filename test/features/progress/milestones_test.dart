import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/progress/domain/milestones.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';

void main() {
  /// Weeks [ids] read whole on [on].
  Map<String, WeekProgress> readWeeks(Iterable<String> ids, LocalDate on) =>
      {for (final id in ids) id: WeekProgress(weekId: id).withAll(on)};

  final genesis = [for (var n = 1; n <= 12; n++) '5787:$n'];

  group('seferCompletions', () {
    test('finds a book once every one of its parshiyot is complete, on the day the last was', () {
      final progress = {
        ...readWeeks(genesis.take(11), LocalDate(2026, 12, 1)),
        '5787:12': WeekProgress(weekId: '5787:12').withAll(LocalDate(2027, 1, 1)),
      };
      expect(seferCompletions(progress, 5787), {0: LocalDate(2027, 1, 1)});
      expect(seferCompletions(progress, 5786), isEmpty, reason: 'another cycle');
    });

    test('takes no book with a parsha unfinished, however little is left', () {
      final progress = readWeeks(genesis, LocalDate(2027, 1, 1));
      progress['5787:12'] = progress['5787:12']!.withUnit(6, ReadingPass.targum, null);
      expect(seferCompletions(progress, 5787), isEmpty);
    });

    test('counts both parshiyot of a week read together', () {
      // Exodus: Shemot to Ki Tisa alone, and Vayakhel-Pekudei together.
      final progress = readWeeks([for (var n = 13; n <= 21; n++) '5787:$n', '5787:22-23'], LocalDate(2027, 3, 1));
      expect(seferCompletions(progress, 5787).keys, [1]);
      expect(parshiyotDoneInCycle(progress, 5787), containsAll([22, 23]));
    });

    test('ends Deuteronomy with Vezot HaBerakhah', () {
      final progress = readWeeks([for (var n = 44; n <= 53; n++) '5787:$n'], LocalDate(2027, 9, 1));
      expect(seferCompletions(progress, 5787), isEmpty);
      progress['5787:54'] = WeekProgress(weekId: '5787:54').withAll(LocalDate(2027, 10, 22));
      expect(seferCompletions(progress, 5787), {4: LocalDate(2027, 10, 22)});
    });
  });

  test('a sefer key names its cycle and book, and nothing else reads as one', () {
    expect(seferKey(5787, 0), 'sefer:5787:0');
    expect(parseSeferKey('sefer:5787:4'), (cycleYear: 5787, book: 4));
    for (final key in ['sefer:5787:5', 'sefer:5787', 'parsha:5787:0', 'sefer:x:0', '']) {
      expect(parseSeferKey(key), isNull, reason: key);
    }
  });
}
