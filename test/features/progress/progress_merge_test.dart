import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_merge.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';

void main() {
  final d1 = LocalDate(2026, 10, 11);
  final d2 = LocalDate(2026, 10, 12);

  test('the earliest completion of each reading wins and nothing is lost', () {
    final a = ProgressState(weeks: {
      '5787:2': WeekProgress(weekId: '5787:2').withAliyah(0, d2).withUnit(1, ReadingPass.mikra1, d1),
    });
    final b = ProgressState(weeks: {
      '5787:2': WeekProgress(weekId: '5787:2').withAliyah(0, d1).withHaftarah(d2),
      '5787:3': WeekProgress(weekId: '5787:3').withAliyah(3, d2),
    }, pauses: [Pause(d1, d2)]);
    final m = mergeProgress(a, b);
    expect(m.week('5787:2').units[0], [d1, d1, d1]);
    expect(m.week('5787:2').units[1][0], d1);
    expect(m.week('5787:2').haftarah, d2);
    expect(m.week('5787:3').isAliyahDone(3), isTrue);
    expect(m.pauses, hasLength(1));
  });

  test('merge is commutative and idempotent', () {
    final a = ProgressState(weeks: {'5787:2': WeekProgress(weekId: '5787:2').withAliyah(0, d2).withPosition(1, const [3, 2, 1])});
    final b = ProgressState(weeks: {'5787:2': WeekProgress(weekId: '5787:2').withAliyah(0, d1).withPosition(1, const [1, 2, 4])});
    String j(ProgressState s) => s.toJson().toString();
    expect(j(mergeProgress(a, b)), j(mergeProgress(b, a)));
    final m = mergeProgress(a, b);
    expect(j(mergeProgress(m, m)), j(m));
    expect(m.week('5787:2').positions[1], [3, 2, 4]);
  });

  test('progress survives a JSON round trip', () {
    final s = ProgressState(
      weeks: {'5787:22-23': WeekProgress(weekId: '5787:22-23').withAll(d1).withPosition(6, const [9, 9, 9])},
      pauses: [Pause(d1, d2)],
    );
    final back = ProgressState.fromJson(s.toJson());
    expect(back.week('5787:22-23').isComplete, isTrue);
    expect(back.week('5787:22-23').positions[6], [9, 9, 9]);
    expect(back.pauses.single.end, d2);
  });
}
