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
const kProgressFormat = 1;

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
class WeekProgress {
  WeekProgress({
    required this.weekId,
    List<List<LocalDate?>>? units,
    this.haftarah,
    Map<int, List<int>>? positions,
  })  : units = units ?? List.generate(kAliyot, (_) => List<LocalDate?>.filled(3, null)),
        positions = positions ?? const {};

  /// Reads a stored week leniently: the unit grid is normalized to 7 × 3 (a
  /// missing row or cell, or one that isn't a day number, reads as not done)
  /// and malformed positions are dropped. With [strict], anything that would
  /// need fixing or dropping throws a [FormatException] instead. A week whose
  /// shape isn't recognized at all always throws.
  factory WeekProgress.fromJson(String weekId, Map<String, dynamic> j, {bool strict = false}) {
    final rawUnits = j['u'];
    final rawPositions = j['p'];
    if ((rawUnits != null && rawUnits is! List) || (rawPositions != null && rawPositions is! Map)) {
      throw FormatException('Unrecognized progress for week $weekId');
    }
    var clean = j.keys.every(const {'u', 'h', 'p'}.contains);

    LocalDate? day(Object? rd) {
      if (rd is int) return LocalDate.fromRd(rd);
      if (rd != null) clean = false;
      return null;
    }

    List<LocalDate?> row(Object? cells) {
      if (cells is! List || cells.length != 3) clean = false;
      final list = cells is List ? cells : const [];
      return [for (var p = 0; p < 3; p++) p < list.length ? day(list[p]) : null];
    }

    final rows = (rawUnits as List?) ?? const [];
    if (rows.length != kAliyot) clean = false;
    final units = [for (var a = 0; a < kAliyot; a++) row(a < rows.length ? rows[a] : null)];

    final positions = <int, List<int>>{};
    for (final MapEntry(:key, :value) in ((rawPositions as Map?) ?? const {}).entries) {
      final a = int.tryParse('$key');
      if (a == null || a < 0 || a >= kAliyot || value is! List || !value.every((n) => n is int && n >= 0)) {
        clean = false;
        continue;
      }
      if (value.length != 3 || '$a' != key) clean = false;
      positions[a] = List<int>.unmodifiable([for (var i = 0; i < 3; i++) i < value.length ? value[i] as int : 0]);
    }

    final haftarah = day(j['h']);
    if (strict && !clean) throw FormatException('Malformed progress for week $weekId');
    return WeekProgress(weekId: weekId, units: units, haftarah: haftarah, positions: positions);
  }

  final String weekId;

  /// `units[aliyah][pass]`: the day that reading was completed.
  final List<List<LocalDate?>> units;

  /// The day the haftarah was read, if it was.
  final LocalDate? haftarah;

  /// `positions[aliyah]` = verses completed in each of the three readings.
  final Map<int, List<int>> positions;

  /// Positions are written in aliyah order so that equal progress always
  /// encodes identically (`ProgressState` equality relies on this).
  Map<String, dynamic> toJson() => {
        'u': [
          for (final row in units) [for (final d in row) d?.rd],
        ],
        if (haftarah != null) 'h': haftarah!.rd,
        if (positions.isNotEmpty) 'p': {for (final a in positions.keys.toList()..sort()) '$a': positions[a]},
      };

  bool isUnitDone(int aliyah, ReadingPass pass) => units[aliyah][pass.index] != null;

  bool isAliyahDone(int aliyah) => units[aliyah].every((d) => d != null);

  int get completedUnits => units.fold(0, (n, row) => n + row.where((d) => d != null).length);

  int get completedAliyot => [for (var a = 0; a < kAliyot; a++) a].where(isAliyahDone).length;

  bool get isComplete => completedUnits == kAliyot * 3;

  /// Whether any reading has been completed or begun.
  bool get isStarted => completedUnits > 0 || positions.values.any((p) => p.any((n) => n > 0));

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

  WeekProgress _copy({List<List<LocalDate?>>? units, Object? haftarah = _keep, Map<int, List<int>>? positions}) =>
      WeekProgress(
        weekId: weekId,
        units: units ?? this.units,
        haftarah: identical(haftarah, _keep) ? this.haftarah : haftarah as LocalDate?,
        positions: positions ?? this.positions,
      );

  /// Marks one reading of one aliyah complete on [date] (if not already), or
  /// with a null [date], not done. Un-marking also forgets how far into that
  /// reading the reader got, so that it starts over rather than counting as
  /// complete again at the next step.
  WeekProgress withUnit(int aliyah, ReadingPass pass, LocalDate? date) {
    final u = [for (final row in units) [...row]];
    if (date != null) {
      u[aliyah][pass.index] ??= date;
      return _copy(units: u);
    }
    u[aliyah][pass.index] = null;
    final pos = [...(positions[aliyah] ?? const [0, 0, 0])];
    while (pos.length < 3) {
      pos.add(0);
    }
    pos[pass.index] = 0;
    return _copy(units: u, positions: {...positions, aliyah: List.unmodifiable(pos)});
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

  WeekProgress withHaftarah(LocalDate? date) => _copy(haftarah: date);

  WeekProgress withPosition(int aliyah, List<int> versesDone) =>
      _copy(positions: {...positions, aliyah: List.unmodifiable(versesDone)});

  static const _keep = Object();
}

/// A user-declared break ("Life happens"): streaks are frozen on these days.
class Pause {
  const Pause(this.start, this.end);

  factory Pause.fromJson(Map<String, dynamic> j) =>
      Pause(LocalDate.fromRd(j['s'] as int), LocalDate.fromRd(j['e'] as int));

  final LocalDate start;
  final LocalDate end;

  bool contains(LocalDate d) => d >= start && d <= end;

  Map<String, dynamic> toJson() => {'s': start.rd, 'e': end.rd};
}
