import 'dart:math';

import '../../../core/calendar/hebrew_date.dart';
import '../../../core/calendar/local_date.dart';
import '../../../core/calendar/parsha_schedule.dart';

/// The three readings of each aliyah.
enum ReadingPass {
  /// First reading of the Hebrew text.
  mikra1,

  /// Second reading of the Hebrew text.
  mikra2,

  /// Targum Onkelos (or Rashi, per the user's choice).
  targum,
}

/// Number of aliyot in every weekly portion.
const kAliyot = 7;

/// The version of the stored progress format that this build reads and
/// writes. Data written by a newer build is kept, never merged blindly.
///
/// Version 2 stamps every change with its time (see [ProgressClock]), so
/// that a merge can tell a reading marked as not read from one that was
/// never marked, and a removal survives syncing. Version 1 data reads as
/// stamped at time 0, older than any change.
const kProgressFormat = 2;

/// Stamps changes to progress with their time, in milliseconds since the
/// epoch, so that merging two copies can tell which change came later.
abstract final class ProgressClock {
  /// The wall clock. Tests replace it.
  static int Function() nowMs = _wallClock;

  static int _wallClock() => DateTime.now().millisecondsSinceEpoch;

  static int _floor = 0;

  /// The stamp for a change that replaces one stamped [previous]: the time
  /// now, but always later than [previous] (and than the floor set by
  /// [above]), so that a change outranks what it replaces even when this
  /// device's clock is behind the one that made the earlier stamp.
  static int after(int previous) => max(nowMs(), max(previous, _floor) + 1);

  /// Runs [change] with every stamp it takes from [after] later than
  /// [floor]: changes made after a reset must survive it.
  static T above<T>(int floor, T Function() change) {
    final saved = _floor;
    _floor = max(saved, floor);
    try {
      return change();
    } finally {
      _floor = saved;
    }
  }
}

/// A stable identifier for one weekly portion within one annual cycle,
/// e.g. `"5787:22-23"`. Keyed by portion rather than date so that switching
/// between the Israel and Diaspora schedules never orphans progress.
String weekIdFor(PortionId portion, LocalDate occasion) =>
    '${cycleYearOf(portion, occasion)}:${portion.key}';

/// The Hebrew year in which the cycle containing this reading began
/// (the year whose Simchat Torah started it with Bereshit).
int cycleYearOf(PortionId portion, LocalDate occasion) {
  final h = HebrewDate.fromLocalDate(occasion);
  // Vayeilech (when separate), Ha'azinu and Vezot HaBerakhah are read in
  // Tishrei, after Rosh Hashana of the next year.
  if (h.month == HebrewMonth.tishrei && portion.number >= 52) return h.year - 1;
  return h.year;
}

/// Progress through one week's portion.
///
/// Each of the 7 × 3 "units" (aliyah × reading) records the day it was
/// completed, which drives streaks. [positions] remembers how far into each
/// unit the reader got, for resuming.
///
/// Every value has a stamp (see [ProgressClock]) of when it last changed,
/// and a removal keeps its stamp, so that merging with another device can
/// tell "marked as not read" from "never marked".
class WeekProgress {
  WeekProgress({
    required this.weekId,
    List<List<LocalDate?>>? units,
    List<List<int>>? stamps,
    this.haftarah,
    this.haftarahStamp = 0,
    Map<int, List<int>>? positions,
    Map<int, int>? positionStamps,
  })  : units = units ?? List.generate(kAliyot, (_) => List<LocalDate?>.filled(3, null)),
        stamps = stamps ?? List.generate(kAliyot, (_) => List<int>.filled(3, 0)),
        positions = positions ?? const {},
        positionStamps = positionStamps ?? const {};

  /// Reads a stored week leniently: the unit and stamp grids are normalized
  /// to 7 × 3 (a missing row or cell, or one that isn't a day number, reads
  /// as not done; a stamp that isn't a time reads as 0) and malformed
  /// positions are dropped. With [strict], anything that would need fixing
  /// or dropping throws a [FormatException] instead. A week whose shape isn't
  /// recognized at all always throws. Stamps missing from version 1 data
  /// read as 0.
  factory WeekProgress.fromJson(String weekId, Map<String, dynamic> j, {bool strict = false}) {
    final rawUnits = j['u'];
    final rawStamps = j['t'];
    final rawPositions = j['p'];
    final rawPositionStamps = j['pt'];
    if ((rawUnits != null && rawUnits is! List) ||
        (rawStamps != null && rawStamps is! List) ||
        (rawPositions != null && rawPositions is! Map) ||
        (rawPositionStamps != null && rawPositionStamps is! Map)) {
      throw FormatException('Unrecognized progress for week $weekId');
    }
    var clean = j.keys.every(const {'u', 't', 'h', 'ht', 'p', 'pt'}.contains);

    LocalDate? day(Object? rd) {
      if (rd is int) return LocalDate.fromRd(rd);
      if (rd != null) clean = false;
      return null;
    }

    int stamp(Object? ms) {
      if (ms is int && ms >= 0) return ms;
      clean = false;
      return 0;
    }

    List<T> row<T>(Object? cells, T Function(Object?) read, T missing) {
      if (cells is! List || cells.length != 3) clean = false;
      final list = cells is List ? cells : const [];
      return [for (var p = 0; p < 3; p++) p < list.length ? read(list[p]) : missing];
    }

    List<List<T>> grid<T>(List<Object?> rows, T Function(Object?) read, T missing) {
      if (rows.length != kAliyot) clean = false;
      return [for (var a = 0; a < kAliyot; a++) row(a < rows.length ? rows[a] : null, read, missing)];
    }

    final units = grid((rawUnits as List?) ?? const [], day, null);
    final stamps = rawStamps == null ? null : grid(rawStamps as List, stamp, 0);

    /// The aliyah a position key names, or null (and not clean) if none.
    int? aliyahOf(Object? key) {
      final a = int.tryParse('$key');
      if (a == null || a < 0 || a >= kAliyot) {
        clean = false;
        return null;
      }
      if ('$a' != key) clean = false;
      return a;
    }

    final positions = <int, List<int>>{};
    for (final MapEntry(:key, :value) in ((rawPositions as Map?) ?? const {}).entries) {
      final a = aliyahOf(key);
      if (a == null || value is! List || !value.every((n) => n is int && n >= 0)) {
        clean = false;
        continue;
      }
      if (value.length != 3) clean = false;
      positions[a] = List<int>.unmodifiable([for (var i = 0; i < 3; i++) i < value.length ? value[i] as int : 0]);
    }

    final positionStamps = <int, int>{};
    for (final MapEntry(:key, :value) in ((rawPositionStamps as Map?) ?? const {}).entries) {
      final a = aliyahOf(key);
      final t = stamp(value);
      if (a != null && t > 0) positionStamps[a] = t;
    }

    final haftarah = day(j['h']);
    final haftarahStamp = j.containsKey('ht') ? stamp(j['ht']) : 0;
    if (strict && !clean) throw FormatException('Malformed progress for week $weekId');
    return WeekProgress(
      weekId: weekId,
      units: units,
      stamps: stamps,
      haftarah: haftarah,
      haftarahStamp: haftarahStamp,
      positions: positions,
      positionStamps: positionStamps,
    );
  }

  final String weekId;

  /// `units[aliyah][pass]`: the day that reading was completed.
  final List<List<LocalDate?>> units;

  /// `stamps[aliyah][pass]`: when `units[aliyah][pass]` last changed, from
  /// [ProgressClock]; 0 if never or unknown.
  final List<List<int>> stamps;

  /// The day the haftarah was read, if it was.
  final LocalDate? haftarah;

  /// When [haftarah] last changed.
  final int haftarahStamp;

  /// `positions[aliyah]` = verses completed in each of the three readings.
  final Map<int, List<int>> positions;

  /// `positionStamps[aliyah]`: when `positions[aliyah]` last changed,
  /// including when it was removed. Only stamps after 0 are kept.
  final Map<int, int> positionStamps;

  /// Positions are written in aliyah order so that equal progress always
  /// encodes identically (`ProgressState` equality relies on this). Stamps
  /// that are all 0 (as in version 1) are left out.
  Map<String, dynamic> toJson() => {
        'u': [
          for (final row in units) [for (final d in row) d?.rd],
        ],
        if (stamps.any((row) => row.any((t) => t != 0)))
          't': [
            for (final row in stamps) [...row],
          ],
        if (haftarah != null) 'h': haftarah!.rd,
        if (haftarahStamp != 0) 'ht': haftarahStamp,
        if (positions.isNotEmpty) 'p': {for (final a in positions.keys.toList()..sort()) '$a': positions[a]},
        if (positionStamps.isNotEmpty)
          'pt': {for (final a in positionStamps.keys.toList()..sort()) '$a': positionStamps[a]},
      };

  bool isUnitDone(int aliyah, ReadingPass pass) => units[aliyah][pass.index] != null;

  bool isAliyahDone(int aliyah) => units[aliyah].every((d) => d != null);

  int get completedUnits => units.fold(0, (n, row) => n + row.where((d) => d != null).length);

  int get completedAliyot => [for (var a = 0; a < kAliyot; a++) a].where(isAliyahDone).length;

  bool get isComplete => completedUnits == kAliyot * 3;

  /// Whether any reading has been completed or begun.
  bool get isStarted => completedUnits > 0 || positions.values.any((p) => p.any((n) => n > 0));

  /// Whether this week holds nothing at all: no reading, no saved place, and
  /// no stamp of one having been removed.
  bool get isBlank =>
      haftarah == null &&
      haftarahStamp == 0 &&
      positions.isEmpty &&
      positionStamps.isEmpty &&
      units.every((row) => row.every((d) => d == null)) &&
      stamps.every((row) => row.every((t) => t == 0));

  /// The latest stamp in this week, or 0.
  int get latestStamp => [
        haftarahStamp,
        ...positionStamps.values,
        for (final row in stamps) ...row,
      ].fold(0, max);

  /// Units completed on or before [date].
  int unitsBy(LocalDate date) =>
      units.fold(0, (n, row) => n + row.where((d) => d != null && d <= date).length);

  /// Units completed on exactly [date].
  int unitsOn(LocalDate date) => units.fold(0, (n, row) => n + row.where((d) => d == date).length);

  /// The day the last unit was completed, or null if incomplete.
  LocalDate? get completedOn {
    if (!isComplete) return null;
    LocalDate? last;
    for (final row in units) {
      for (final d in row) {
        if (last == null || d! > last) last = d;
      }
    }
    return last;
  }

  WeekProgress _copy({
    List<List<LocalDate?>>? units,
    List<List<int>>? stamps,
    Object? haftarah = _keep,
    int? haftarahStamp,
    Map<int, List<int>>? positions,
    Map<int, int>? positionStamps,
  }) =>
      WeekProgress(
        weekId: weekId,
        units: units ?? this.units,
        stamps: stamps ?? this.stamps,
        haftarah: identical(haftarah, _keep) ? this.haftarah : haftarah as LocalDate?,
        haftarahStamp: haftarahStamp ?? this.haftarahStamp,
        positions: positions ?? this.positions,
        positionStamps: positionStamps ?? this.positionStamps,
      );

  /// One unit set to [date], stamped now.
  WeekProgress _withCell(int aliyah, int pass, LocalDate? date) {
    final u = [for (final row in units) [...row]];
    final t = [for (final row in stamps) [...row]];
    u[aliyah][pass] = date;
    t[aliyah][pass] = ProgressClock.after(t[aliyah][pass]);
    return _copy(units: u, stamps: t);
  }

  /// Marks one reading of one aliyah complete on [date] (if not already), or
  /// with a null [date], not done. Un-marking also forgets how far into that
  /// reading the reader got, so that it starts over rather than counting as
  /// complete again at the next step.
  ///
  /// Only what changes is stamped, and a change to nothing returns this
  /// same week.
  WeekProgress withUnit(int aliyah, ReadingPass pass, LocalDate? date) {
    final p = pass.index;
    final current = units[aliyah][p];
    // Marking keeps the day a reading was first completed.
    final next = current == date || (current != null && date != null) ? this : _withCell(aliyah, p, date);
    final pos = positions[aliyah];
    if (date != null || pos == null) return next;
    return next.withPosition(aliyah, [for (var i = 0; i < 3; i++) i != p && i < pos.length ? pos[i] : 0]);
  }

  /// Marks all three readings of [aliyah] complete on [date], or with a null
  /// [date], not done.
  WeekProgress withAliyah(int aliyah, LocalDate? date) {
    var p = this;
    for (final pass in ReadingPass.values) {
      p = p.withUnit(aliyah, pass, date);
    }
    return p;
  }

  /// Marks every remaining unit complete on [date].
  WeekProgress withAll(LocalDate date) {
    var p = this;
    for (var a = 0; a < kAliyot; a++) {
      p = p.withAliyah(a, date);
    }
    return p;
  }

  WeekProgress withHaftarah(LocalDate? date) =>
      date == haftarah ? this : _copy(haftarah: date, haftarahStamp: ProgressClock.after(haftarahStamp));

  WeekProgress withPosition(int aliyah, List<int> versesDone) {
    final current = positions[aliyah];
    if (current != null && _sameList(current, versesDone)) return this;
    return _copy(
      positions: {...positions, aliyah: List.unmodifiable(versesDone)},
      positionStamps: {...positionStamps, aliyah: ProgressClock.after(positionStamps[aliyah] ?? 0)},
    );
  }

  WeekProgress _withoutPosition(int aliyah) => !positions.containsKey(aliyah)
      ? this
      : _copy(
          positions: {...positions}..remove(aliyah),
          positionStamps: {...positionStamps, aliyah: ProgressClock.after(positionStamps[aliyah] ?? 0)},
        );

  /// This week with nothing read and no saved places. What was there is
  /// removed with a new stamp, so that the removal reaches other devices.
  WeekProgress cleared() => restoredTo(WeekProgress(weekId: weekId));

  /// This week changed to read exactly like [target] (an undo, or a restored
  /// backup). Whatever differs takes [target]'s value as a new change,
  /// stamped now, so that a sync carries it to other devices rather than
  /// undoing it. [target]'s own stamps don't matter.
  WeekProgress restoredTo(WeekProgress target) {
    var w = this;
    for (var a = 0; a < kAliyot; a++) {
      for (var p = 0; p < 3; p++) {
        if (w.units[a][p] != target.units[a][p]) w = w._withCell(a, p, target.units[a][p]);
      }
    }
    w = w.withHaftarah(target.haftarah);
    for (final a in {...positions.keys, ...target.positions.keys}) {
      final want = target.positions[a];
      w = want == null ? w._withoutPosition(a) : w.withPosition(a, want);
    }
    return w;
  }

  static bool _sameList(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static const _keep = Object();
}

/// A user-declared break ("Life happens"): streaks are frozen on these days.
///
/// A pause is changed in place, keeping its [id], and one cancelled before
/// it began is kept as [deleted] rather than removed, so that merging with
/// another device carries the change instead of restoring the original.
class Pause {
  /// A pause saved without an [id] (before pauses had ids) is identified by
  /// its dates.
  Pause(this.start, this.end, {String? id, this.updatedAt = 0, this.deleted = false})
      : id = id ?? '${start.rd}-${end.rd}';

  factory Pause.fromJson(Map<String, dynamic> j) {
    final id = j['id'];
    final updatedAt = j['t'] ?? 0;
    final deleted = j['deleted'] ?? false;
    if ((id != null && id is! String) || updatedAt is! int || updatedAt < 0 || deleted is! bool) {
      throw FormatException('Unrecognized pause $j');
    }
    return Pause(
      LocalDate.fromRd(j['s'] as int),
      LocalDate.fromRd(j['e'] as int),
      id: id as String?,
      updatedAt: updatedAt,
      deleted: deleted,
    );
  }

  final LocalDate start;
  final LocalDate end;

  /// Identifies this pause across changes and devices: the time it was
  /// created.
  final String id;

  /// When this pause last changed, from [ProgressClock]; 0 if unknown.
  final int updatedAt;

  /// Cancelled before it began: it covers no days.
  final bool deleted;

  bool contains(LocalDate d) => !deleted && d >= start && d <= end;

  /// This pause cut short to end on [day].
  Pause endingOn(LocalDate day) => Pause(start, day, id: id, updatedAt: ProgressClock.after(updatedAt));

  /// This pause cancelled.
  Pause cancelled() => Pause(start, end, id: id, updatedAt: ProgressClock.after(updatedAt), deleted: true);

  /// This pause changed to match [target], which has the same [id].
  Pause restoredTo(Pause target) => target.start == start && target.end == end && target.deleted == deleted
      ? this
      : Pause(
          target.start,
          target.end,
          id: id,
          updatedAt: ProgressClock.after(max(updatedAt, target.updatedAt)),
          deleted: target.deleted,
        );

  Map<String, dynamic> toJson() => {
        'id': id,
        's': start.rd,
        'e': end.rd,
        if (updatedAt != 0) 't': updatedAt,
        if (deleted) 'deleted': true,
      };
}
