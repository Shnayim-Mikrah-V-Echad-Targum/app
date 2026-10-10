import 'dart:convert';
import 'dart:math';

import 'package:collection/collection.dart';

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
/// - A reading (or the haftarah) marked as not read drops every mark made
///   before that, on either device; on a tie, it stays read. Of the marks
///   left, the earliest day wins, so a sync never lowers a streak, and a
///   reading marked again on a later day keeps that day (see
///   [ReadingRecord]).
/// - The later saved place in an aliyah wins; on a tie, the furthest.
/// - The later change to a pause wins; on a tie, a cancellation.
///
/// The merge is commutative, associative and idempotent.
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

/// This device's progress, [local], with a backup file's, [imported],
/// merged in at the reader's request: what either holds is kept, merged as
/// [mergeProgress] merges two devices' copies, except that neither side's
/// reset erases the other's progress. A sync applies a reset to the copies
/// it reaches, but a reader merging a backup made before one, or a backup
/// made after a reset elsewhere into progress from before it, is asking to
/// keep both.
///
/// Restore the result with [ProgressController.restore], so that what the
/// backup adds counts as a new change, which a sync keeps.
ProgressState mergeBackup(ProgressState local, ProgressState imported) =>
    mergeProgress(_withoutReset(local), _withoutReset(imported));

/// [s] as if never reset. All it holds is from after its reset, so nothing
/// comes back; only the other side's progress is no longer cut.
ProgressState _withoutReset(ProgressState s) => ProgressState(
      weeks: s.weeks,
      pauses: s.pauses,
      unknownWeeks: s.unknownWeeks,
      unknownPauses: s.unknownPauses,
    );

/// What a sync saves to the reader's account: their [progress], and the day
/// they joined (see [mergeSyncPayload]). Earlier versions saved the
/// progress alone, and read past the join date.
Map<String, dynamic> syncPayload(ProgressState progress, LocalDate? joinDate) =>
    {...progress.toJson(), 'joinDate': ?joinDate?.rd};

/// The join date a sync [payload] holds, if any.
LocalDate? syncPayloadJoinDate(Map<String, dynamic> payload) =>
    payload['joinDate'] is int ? LocalDate.fromRd(payload['joinDate'] as int) : null;

/// Merges this device's progress, [local], and the day the reader joined
/// here, [localJoin], with the account's backup, [remote], as [syncPayload]
/// wrote it.
///
/// The progress merges as [mergeProgress] does, and the earliest join date
/// wins, so that a new device counts the history it restores: keeping the
/// day it was set up would leave out every week before, and the streaks
/// would start again from 0, when a sync must never lower one. A backup
/// saved without a join date (by an earlier version) counts as joined on
/// the day of its earliest reading. A side that hasn't seen the latest
/// reset has no say, since the reset started the reader again; nor does a
/// reading logged for a day before the reset.
///
/// The join date is null when neither side has one to give.
({ProgressState progress, LocalDate? joinDate}) mergeSyncPayload(
  ProgressState local,
  LocalDate? localJoin,
  Map<String, dynamic> remote,
) {
  final theirs = ProgressState.fromJson(remote);
  final progress = mergeProgress(local, theirs);
  final cut = progress.resetAt;
  final restart = cut == 0 ? null : rolloverDate(DateTime.fromMillisecondsSinceEpoch(cut));
  final theirJoin = syncPayloadJoinDate(remote) ?? earliestReadDate(theirs, from: restart);
  final joins = [
    if (local.resetAt == cut) localJoin,
    if (theirs.resetAt == cut) theirJoin,
  ];
  return (progress: progress, joinDate: joins.nonNulls.minOrNull);
}

/// The earliest day on which a reading or the haftarah in [progress] counts
/// as done, of those from [from] on; null if there is none.
LocalDate? earliestReadDate(ProgressState progress, {LocalDate? from}) {
  LocalDate? earliest;
  for (final week in progress.weeks.values) {
    for (final day in [for (final unit in week.units) ...unit, week.haftarah]) {
      if (day == null || (from != null && day < from)) continue;
      if (earliest == null || day < earliest) earliest = day;
    }
  }
  return earliest;
}

WeekProgress _mergeWeek(WeekProgress x, WeekProgress y, int cut) {
  final records = [
    for (var a = 0; a < kAliyot; a++)
      [for (var p = 0; p < 3; p++) x.records[a][p].merge(y.records[a][p], cut: cut)],
  ];
  final haftarah = x.haftarahRecord.merge(y.haftarahRecord, cut: cut);

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

  return WeekProgress.fromRecords(
    weekId: x.weekId,
    records: records,
    haftarahRecord: haftarah,
    positions: positions,
    positionStamps: positionStamps,
  );
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
