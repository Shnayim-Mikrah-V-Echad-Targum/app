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
/// Version 2 stamps every change with its time (see [ProgressClock]), and
/// keeps when each reading was last marked as not read (see
/// [ReadingRecord]), so that a merge can tell a reading marked as not read
/// from one that was never marked, and a removal survives syncing. Version
/// 1 data reads as stamped at time 0, older than any change.
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

/// A day a reading was marked read, and when the mark was made (from
/// [ProgressClock]).
class ReadingMark {
  const ReadingMark(this.day, this.at);

  final LocalDate day;
  final int at;
}

/// Whether one reading (or the haftarah) is done, and since which day: the
/// marks that still count, and when it was last marked as not read.
///
/// Merging two copies keeps every mark and the later removal. A mark made
/// before the removal no longer counts, and of the marks that do, the
/// earliest day wins. So a reading marked again on a later day, after being
/// marked as not read, keeps the new day even against a copy that still
/// has the old one; and where two devices marked it independently, the
/// earlier day wins, so a sync never lowers a streak.
///
/// A mark that can never decide the day is dropped: one whose day is no
/// earlier than that of a mark made at the same time or later (which counts
/// for at least as long). Usually a single mark is left.
class ReadingRecord {
  const ReadingRecord._(this.marks, this.clearedAt);

  /// The record of [marks] and a removal at [clearedAt], keeping only the
  /// marks that can decide the day. Anything from before [cut] (a reset)
  /// counts as never recorded.
  factory ReadingRecord.of(Iterable<ReadingMark> marks, {int clearedAt = 0, int cut = 0}) {
    // A mark made at the same moment as the removal outranks it.
    final live = marks.where((m) => m.at >= clearedAt && m.at >= cut).toList()
      ..sort((a, b) => a.at != b.at ? b.at.compareTo(a.at) : a.day.compareTo(b.day));
    final kept = <ReadingMark>[];
    for (final m in live) {
      if (kept.isEmpty || m.day < kept.last.day) kept.add(m);
    }
    return ReadingRecord._(List.unmodifiable(kept.reversed), clearedAt < cut ? 0 : clearedAt);
  }

  /// Never marked, nor marked as not read.
  static const blank = ReadingRecord._([], 0);

  /// Marked read on [day] at [stamp], or with a null [day], marked as not
  /// read at [stamp] (or never, at 0).
  factory ReadingRecord.single(LocalDate? day, int stamp) =>
      day == null ? ReadingRecord._(const [], stamp) : ReadingRecord._([ReadingMark(day, stamp)], 0);

  /// The marks that count, in the order they were made, and so also by day:
  /// each is later than the one before.
  final List<ReadingMark> marks;

  /// When this reading was last marked as not read (or given another day);
  /// 0 if never.
  final int clearedAt;

  /// The day this reading counts as done, if it does.
  LocalDate? get day => marks.isEmpty ? null : marks.first.day;

  /// When this record last changed; 0 if never.
  int get stamp => marks.isEmpty ? clearedAt : max(clearedAt, marks.last.at);

  bool get isBlank => marks.isEmpty && clearedAt == 0;

  /// This reading marked read on [day], or with a null [day], not read, as a
  /// change made now. A new day replaces the old one everywhere.
  ReadingRecord changedTo(LocalDate? day) {
    final at = ProgressClock.after(stamp);
    if (day == null) return ReadingRecord._(const [], at);
    return ReadingRecord._([ReadingMark(day, at)], this.day == null ? clearedAt : at);
  }

  /// This record merged with [other], another copy of it, dropping anything
  /// from before [cut] (a reset).
  ReadingRecord merge(ReadingRecord other, {int cut = 0}) =>
      ReadingRecord.of([...marks, ...other.marks], clearedAt: max(clearedAt, other.clearedAt), cut: cut);
}

/// Progress through one week's portion.
///
/// Each of the 7 × 3 "units" (aliyah × reading) records the day it was
/// completed, which drives streaks. [positions] remembers how far into each
/// unit the reader got, for resuming.
///
/// Every value records when it last changed (see [ProgressClock]), and a
/// removal is recorded rather than forgotten, so that merging with another
/// device can tell "marked as not read" from "never marked". The readings
/// and the haftarah keep a [ReadingRecord] each.
class WeekProgress {
  /// A week whose readings are [units], each marked at the time in [stamps]
  /// (or for one not read, marked as not read then, or never at 0), and
  /// likewise the haftarah.
  WeekProgress({
    required String weekId,
    List<List<LocalDate?>>? units,
    List<List<int>>? stamps,
    LocalDate? haftarah,
    int haftarahStamp = 0,
    Map<int, List<int>>? positions,
    Map<int, int>? positionStamps,
  }) : this.fromRecords(
          weekId: weekId,
          records: [
            for (var a = 0; a < kAliyot; a++)
              [for (var p = 0; p < 3; p++) ReadingRecord.single(units?[a][p], stamps?[a][p] ?? 0)],
          ],
          haftarahRecord: ReadingRecord.single(haftarah, haftarahStamp),
          positions: positions,
          positionStamps: positionStamps,
        );

  WeekProgress.fromRecords({
    required this.weekId,
    List<List<ReadingRecord>>? records,
    this.haftarahRecord = ReadingRecord.blank,
    Map<int, List<int>>? positions,
    Map<int, int>? positionStamps,
  })  : records = records ?? _blankRecords,
        units = [
          for (final row in records ?? _blankRecords) [for (final r in row) r.day],
        ],
        stamps = [
          for (final row in records ?? _blankRecords) [for (final r in row) r.stamp],
        ],
        haftarah = haftarahRecord.day,
        haftarahStamp = haftarahRecord.stamp,
        positions = positions ?? const {},
        positionStamps = positionStamps ?? const {};

  static final _blankRecords = List<List<ReadingRecord>>.unmodifiable([
    for (var a = 0; a < kAliyot; a++) List<ReadingRecord>.unmodifiable(List.filled(3, ReadingRecord.blank)),
  ]);

  /// The keys a stored week may have.
  static const _keys = {'u', 't', 'c', 'x', 'h', 'ht', 'hc', 'hx', 'p', 'pt'};

  /// Reads a stored week leniently: the grids are normalized to 7 × 3 (a
  /// missing row or cell, or one that isn't a day number, reads as not done;
  /// a stamp that isn't a time reads as 0), and malformed marks and
  /// positions are dropped. With [strict], anything that would need fixing
  /// or dropping throws a [FormatException] instead. A week whose shape
  /// isn't recognized at all always throws: one without a unit grid, with a
  /// key this version doesn't know, or with a part of the wrong kind.
  /// Stamps missing from version 1 data read as 0.
  factory WeekProgress.fromJson(String weekId, Map<String, dynamic> j, {bool strict = false}) {
    final rawUnits = j['u'];
    if ((j.isNotEmpty && rawUnits is! List) ||
        !j.keys.every(_keys.contains) ||
        (j['t'] != null && j['t'] is! List) ||
        (j['c'] != null && j['c'] is! List) ||
        (j['x'] != null && j['x'] is! List) ||
        (j['hx'] != null && j['hx'] is! List) ||
        (j['p'] != null && j['p'] is! Map) ||
        (j['pt'] != null && j['pt'] is! Map)) {
      throw FormatException('Unrecognized progress for week $weekId');
    }
    var clean = true;

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

    /// A 7 × 3 grid, or all [missing] where none was stored.
    List<List<T>> grid<T>(Object? rows, T Function(Object?) read, T missing) {
      if (rows == null) return [for (var a = 0; a < kAliyot; a++) List.filled(3, missing)];
      final list = rows as List;
      if (list.length != kAliyot) clean = false;
      return [for (var a = 0; a < kAliyot; a++) row(a < list.length ? list[a] : null, read, missing)];
    }

    final units = grid(rawUnits, day, null);
    final stamps = grid(j['t'], stamp, 0);
    final cleared = grid(j['c'], stamp, 0);

    /// A mark stored as [day, stamp] after the first, or null (and not
    /// clean) if malformed.
    ReadingMark? mark(Object? m) {
      if (m is List && m.length == 2 && m[0] is int && m[1] is int && (m[1] as int) >= 0) {
        return ReadingMark(LocalDate.fromRd(m[0] as int), m[1] as int);
      }
      clean = false;
      return null;
    }

    final moreMarks = List.generate(kAliyot, (_) => List.generate(3, (_) => <ReadingMark>[]));
    for (final m in (j['x'] as List?) ?? const []) {
      // [aliyah, pass, day, stamp].
      if (m is List && m.length == 4 && m[0] is int && m[1] is int) {
        final (a, p) = (m[0] as int, m[1] as int);
        if (a >= 0 && a < kAliyot && p >= 0 && p < 3) {
          if (mark(m.sublist(2)) case final mark?) moreMarks[a][p].add(mark);
          continue;
        }
      }
      clean = false;
    }

    /// The record stored as [day] marked at [t] (or not read since [t]),
    /// last marked as not read at [c], with further marks [more].
    ReadingRecord record(LocalDate? day, int t, int c, List<ReadingMark> more) {
      if (day == null) {
        // Marks or a removal time beside a reading that isn't read.
        if (c != 0 || more.isNotEmpty) clean = false;
        return ReadingRecord.of(const [], clearedAt: max(t, c));
      }
      final r = ReadingRecord.of([ReadingMark(day, t), ...more], clearedAt: c);
      // Every mark stored must still count.
      if (r.day != day || r.marks.length != 1 + more.length) clean = false;
      return r;
    }

    final records = [
      for (var a = 0; a < kAliyot; a++)
        [for (var p = 0; p < 3; p++) record(units[a][p], stamps[a][p], cleared[a][p], moreMarks[a][p])],
    ];
    final haftarahRecord = record(
      day(j['h']),
      j.containsKey('ht') ? stamp(j['ht']) : 0,
      j.containsKey('hc') ? stamp(j['hc']) : 0,
      [for (final m in (j['hx'] as List?) ?? const []) ?mark(m)],
    );

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
    for (final MapEntry(:key, :value) in ((j['p'] as Map?) ?? const {}).entries) {
      final a = aliyahOf(key);
      if (a == null || value is! List || !value.every((n) => n is int && n >= 0)) {
        clean = false;
        continue;
      }
      if (value.length != 3) clean = false;
      positions[a] = List<int>.unmodifiable([for (var i = 0; i < 3; i++) i < value.length ? value[i] as int : 0]);
    }

    final positionStamps = <int, int>{};
    for (final MapEntry(:key, :value) in ((j['pt'] as Map?) ?? const {}).entries) {
      final a = aliyahOf(key);
      final t = stamp(value);
      if (a != null && t > 0) positionStamps[a] = t;
    }

    if (strict && !clean) throw FormatException('Malformed progress for week $weekId');
    return WeekProgress.fromRecords(
      weekId: weekId,
      records: records,
      haftarahRecord: haftarahRecord,
      positions: positions,
      positionStamps: positionStamps,
    );
  }

  final String weekId;

  /// `records[aliyah][pass]`: when that reading was marked read and not.
  final List<List<ReadingRecord>> records;

  /// When the haftarah was marked read and not.
  final ReadingRecord haftarahRecord;

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

  /// Equal progress always encodes identically (`ProgressState` equality
  /// relies on this): positions are written in aliyah order, and what is
  /// all 0 or empty (as in version 1) is left out.
  ///
  /// `t` holds each reading's mark time (or, for one not read, the time it
  /// was marked as not read), `c` when a reading that is read was last
  /// marked as not read, and `x` any further marks as [aliyah, pass, day,
  /// stamp]; `ht`, `hc` and `hx` likewise for the haftarah.
  Map<String, dynamic> toJson() {
    int t(ReadingRecord r) => r.marks.isEmpty ? r.clearedAt : r.marks.first.at;
    int c(ReadingRecord r) => r.marks.isEmpty ? 0 : r.clearedAt;
    bool any(int Function(ReadingRecord) f) => records.any((row) => row.any((r) => f(r) != 0));
    return {
      'u': [
        for (final row in units) [for (final d in row) d?.rd],
      ],
      if (any(t))
        't': [
          for (final row in records) [for (final r in row) t(r)],
        ],
      if (any(c))
        'c': [
          for (final row in records) [for (final r in row) c(r)],
        ],
      if (records.any((row) => row.any((r) => r.marks.length > 1)))
        'x': [
          for (var a = 0; a < kAliyot; a++)
            for (var p = 0; p < 3; p++)
              for (final m in records[a][p].marks.skip(1)) [a, p, m.day.rd, m.at],
        ],
      if (haftarah != null) 'h': haftarah!.rd,
      if (t(haftarahRecord) != 0) 'ht': t(haftarahRecord),
      if (c(haftarahRecord) != 0) 'hc': c(haftarahRecord),
      if (haftarahRecord.marks.length > 1) 'hx': [for (final m in haftarahRecord.marks.skip(1)) [m.day.rd, m.at]],
      if (positions.isNotEmpty) 'p': {for (final a in positions.keys.toList()..sort()) '$a': positions[a]},
      if (positionStamps.isNotEmpty)
        'pt': {for (final a in positionStamps.keys.toList()..sort()) '$a': positionStamps[a]},
    };
  }

  bool isUnitDone(int aliyah, ReadingPass pass) => units[aliyah][pass.index] != null;

  bool isAliyahDone(int aliyah) => units[aliyah].every((d) => d != null);

  int get completedUnits => units.fold(0, (n, row) => n + row.where((d) => d != null).length);

  int get completedAliyot => [for (var a = 0; a < kAliyot; a++) a].where(isAliyahDone).length;

  bool get isComplete => completedUnits == kAliyot * 3;

  /// Whether any reading has been completed or begun.
  bool get isStarted => completedUnits > 0 || positions.values.any((p) => p.any((n) => n > 0));

  /// Whether this week holds nothing at all: no reading, no saved place, and
  /// no record of one having been removed.
  bool get isBlank =>
      haftarahRecord.isBlank &&
      positions.isEmpty &&
      positionStamps.isEmpty &&
      records.every((row) => row.every((r) => r.isBlank));

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
    List<List<ReadingRecord>>? records,
    ReadingRecord? haftarahRecord,
    Map<int, List<int>>? positions,
    Map<int, int>? positionStamps,
  }) =>
      WeekProgress.fromRecords(
        weekId: weekId,
        records: records ?? this.records,
        haftarahRecord: haftarahRecord ?? this.haftarahRecord,
        positions: positions ?? this.positions,
        positionStamps: positionStamps ?? this.positionStamps,
      );

  /// One unit set to [date] (or not read), as a change made now.
  WeekProgress _withCell(int aliyah, int pass, LocalDate? date) {
    final r = [for (final row in records) [...row]];
    r[aliyah][pass] = r[aliyah][pass].changedTo(date);
    return _copy(records: r);
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
      date == haftarah ? this : _copy(haftarahRecord: haftarahRecord.changedTo(date));

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
  /// removed as a change made now, so that the removal reaches other
  /// devices.
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
