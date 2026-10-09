import 'dart:convert';
import 'dart:math';

import '../../../app/providers.dart';
import '../../../core/calendar/local_date.dart';
import 'progress_models.dart';

export '../../../app/providers.dart' show ProgressState;

/// How long a cancelled pause is remembered, so that the cancellation can
/// reach devices that still have the pause. A device that hasn't synced for
/// longer than this may bring it back.
const kPauseTombstoneLife = Duration(days: 60);

/// Merges two copies of a user's progress (e.g. this device and the cloud),
/// keeping every change made on either, removals included. Every change is
/// stamped with its time (see [ProgressClock]):
///
/// - A reset drops everything stamped before it, from both copies.
/// - A reading logged on one device and removed on the other is whichever
///   happened later; on a tie, it stays read. Where both devices logged it,
///   the earliest day wins, so a sync never lowers a streak.
/// - The later saved place in an aliyah wins; on a tie, the furthest.
/// - The later change to a pause wins; on a tie, a cancellation.
///
/// The merge is commutative and idempotent.
ProgressState mergeProgress(ProgressState a, ProgressState b) {
  final cut = max(a.resetAt, b.resetAt);

  final weeks = <String, WeekProgress>{};
  for (final id in {...a.weeks.keys, ...b.weeks.keys}) {
    final week = _mergeWeek(a.week(id), b.week(id), cut);
    if (!week.isBlank) weeks[id] = week;
  }

  final expired = ProgressClock.nowMs() - kPauseTombstoneLife.inMilliseconds;
  final pauses = <String, Pause>{};
  for (final p in [...a.pauses, ...b.pauses]) {
    if (p.updatedAt < cut) continue;
    final q = pauses[p.id];
    if (q == null || _outranks(p, q)) pauses[p.id] = p;
  }
  pauses.removeWhere((_, p) => p.deleted && p.updatedAt < expired);
  final sortedPauses = pauses.values.toList()
    ..sort((p, q) => p.start != q.start ? p.start.compareTo(q.start) : p.id.compareTo(q.id));

  // Entries neither side could read are carried along untouched, except
  // from a side that hasn't seen the latest reset. Where both sides hold a
  // different one for the same week, the choice must not depend on the
  // argument order.
  final sides = [a, b].where((s) => s.resetAt == cut).toList();
  final unknownWeeks = <String, Object?>{};
  for (final side in sides) {
    for (final MapEntry(:key, :value) in side.unknownWeeks.entries) {
      if (!unknownWeeks.containsKey(key) || _canonical(value).compareTo(_canonical(unknownWeeks[key])) < 0) {
        unknownWeeks[key] = value;
      }
    }
  }
  final unknownPauses = {
    for (final side in sides)
      for (final p in side.unknownPauses) _canonical(p): p,
  };
  return ProgressState(
    weeks: weeks,
    pauses: sortedPauses,
    resetAt: cut,
    unknownWeeks: unknownWeeks,
    unknownPauses: [for (final k in unknownPauses.keys.toList()..sort()) unknownPauses[k]],
  );
}

WeekProgress _mergeWeek(WeekProgress x, WeekProgress y, int cut) {
  final units = List.generate(kAliyot, (_) => List<LocalDate?>.filled(3, null));
  final stamps = List.generate(kAliyot, (_) => List<int>.filled(3, 0));
  for (var a = 0; a < kAliyot; a++) {
    for (var p = 0; p < 3; p++) {
      final (date, stamp) = _mergeCell(
        _Cell(x.units[a][p], x.stamps[a][p], cut),
        _Cell(y.units[a][p], y.stamps[a][p], cut),
      );
      units[a][p] = date;
      stamps[a][p] = stamp;
    }
  }
  final (haftarah, haftarahStamp) = _mergeCell(
    _Cell(x.haftarah, x.haftarahStamp, cut),
    _Cell(y.haftarah, y.haftarahStamp, cut),
  );

  final positions = <int, List<int>>{};
  final positionStamps = <int, int>{};
  final aliyot = {...x.positions.keys, ...x.positionStamps.keys, ...y.positions.keys, ...y.positionStamps.keys};
  for (final a in aliyot) {
    var (xp, xt) = (x.positions[a], x.positionStamps[a] ?? 0);
    var (yp, yt) = (y.positions[a], y.positionStamps[a] ?? 0);
    if (xt < cut) (xp, xt) = (null, 0);
    if (yt < cut) (yp, yt) = (null, 0);
    final position = xt != yt ? (xt > yt ? xp : yp) : _furthest(xp, yp);
    if (position != null) positions[a] = List.unmodifiable(position);
    if (max(xt, yt) > 0) positionStamps[a] = max(xt, yt);
  }

  return WeekProgress(
    weekId: x.weekId,
    units: units,
    stamps: stamps,
    haftarah: haftarah,
    haftarahStamp: haftarahStamp,
    positions: positions,
    positionStamps: positionStamps,
  );
}

/// A reading (or the haftarah) as one copy has it: the day it was read, if
/// it was, and when that last changed. Anything from before [cut] (a reset)
/// counts as never recorded.
class _Cell {
  _Cell(LocalDate? date, int stamp, int cut)
      : date = stamp < cut ? null : date,
        stamp = stamp < cut ? 0 : stamp;

  final LocalDate? date;
  final int stamp;
}

(LocalDate?, int) _mergeCell(_Cell x, _Cell y) {
  final stamp = max(x.stamp, y.stamp);
  final (dx, dy) = (x.date, y.date);
  if (dx != null && dy != null) return (dx <= dy ? dx : dy, stamp);
  if (dx == null && dy == null) return (null, stamp);
  // Read in one copy and not in the other: the later change wins, and on a
  // tie the reading is kept.
  final (read, other) = dx != null ? (x, y) : (y, x);
  return (read.stamp >= other.stamp ? read.date : null, stamp);
}

/// The element-wise furthest of two saved places, either of which may be
/// missing.
List<int>? _furthest(List<int>? x, List<int>? y) {
  if (x == null || y == null) return x ?? y;
  int at(List<int> list, int i) => i < list.length ? list[i] : 0;
  return [for (var i = 0; i < 3; i++) max(at(x, i), at(y, i))];
}

/// Whether [p] replaces [q], another copy of the same pause.
bool _outranks(Pause p, Pause q) {
  if (p.updatedAt != q.updatedAt) return p.updatedAt > q.updatedAt;
  if (p.deleted != q.deleted) return p.deleted;
  return _canonical(p.toJson()).compareTo(_canonical(q.toJson())) < 0;
}

String _canonical(Object? json) => jsonEncode(ProgressState.canonicalJson(json));
