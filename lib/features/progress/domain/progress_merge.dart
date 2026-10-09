import 'dart:math';

import '../../../app/providers.dart';
import '../../../core/calendar/local_date.dart';
import 'progress_models.dart';

export '../../../app/providers.dart' show ProgressState;

/// Merges two copies of a user's progress (e.g. this device and the cloud).
/// For every reading, the earliest recorded completion wins, so nothing read
/// on either device is lost and streaks are computed from the true dates.
/// The merge is commutative and idempotent.
ProgressState mergeProgress(ProgressState a, ProgressState b) {
  final weeks = <String, WeekProgress>{};
  for (final id in {...a.weeks.keys, ...b.weeks.keys}) {
    final x = a.weeks[id];
    final y = b.weeks[id];
    if (x == null || y == null) {
      weeks[id] = (x ?? y)!;
      continue;
    }
    final units = [
      for (var i = 0; i < kAliyot; i++)
        [
          for (var p = 0; p < 3; p++) _earliest(x.units[i][p], y.units[i][p]),
        ],
    ];
    int at(List<int>? list, int i) => list != null && i < list.length ? list[i] : 0;
    final positions = <int, List<int>>{
      for (final k in {...x.positions.keys, ...y.positions.keys})
        k: [for (var i = 0; i < 3; i++) max(at(x.positions[k], i), at(y.positions[k], i))],
    };
    weeks[id] = WeekProgress(
      weekId: id,
      units: units,
      haftarah: _earliest(x.haftarah, y.haftarah),
      positions: positions,
    );
  }
  final pauses = <String, Pause>{};
  for (final p in [...a.pauses, ...b.pauses]) {
    pauses['${p.start.rd}-${p.end.rd}'] = p;
  }
  final sortedPauses = pauses.values.toList()..sort((p, q) => p.start.compareTo(q.start));
  return ProgressState(weeks: weeks, pauses: sortedPauses);
}

LocalDate? _earliest(LocalDate? a, LocalDate? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a <= b ? a : b;
}
