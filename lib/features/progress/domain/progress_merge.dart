import 'dart:convert';
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

  // Entries neither side could read are carried along untouched. Where both
  // sides hold a different one for the same week, the choice must not depend
  // on the argument order.
  final unknownWeeks = <String, Object?>{};
  for (final id in {...a.unknownWeeks.keys, ...b.unknownWeeks.keys}) {
    final x = a.unknownWeeks.containsKey(id) ? _canonical(a.unknownWeeks[id]) : null;
    final y = b.unknownWeeks.containsKey(id) ? _canonical(b.unknownWeeks[id]) : null;
    final xFirst = y == null || (x != null && x.compareTo(y) <= 0);
    unknownWeeks[id] = xFirst ? a.unknownWeeks[id] : b.unknownWeeks[id];
  }
  final unknownPauses = {
    for (final p in [...a.unknownPauses, ...b.unknownPauses]) _canonical(p): p,
  };
  return ProgressState(
    weeks: weeks,
    pauses: sortedPauses,
    unknownWeeks: unknownWeeks,
    unknownPauses: [for (final k in unknownPauses.keys.toList()..sort()) unknownPauses[k]],
  );
}

String _canonical(Object? json) => jsonEncode(ProgressState.canonicalJson(json));

LocalDate? _earliest(LocalDate? a, LocalDate? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a <= b ? a : b;
}
