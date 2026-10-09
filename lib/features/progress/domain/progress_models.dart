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

  factory WeekProgress.fromJson(String weekId, Map<String, dynamic> j) {
    final u = (j['u'] as List?)
        ?.map((row) => (row as List).map((d) => d == null ? null : LocalDate.fromRd(d as int)).toList())
        .toList();
    final pos = <int, List<int>>{
      for (final e in ((j['p'] as Map<String, dynamic>?) ?? const {}).entries)
        int.parse(e.key): (e.value as List).cast<int>(),
    };
    return WeekProgress(
      weekId: weekId,
      units: u,
      haftarah: j['h'] == null ? null : LocalDate.fromRd(j['h'] as int),
      positions: pos,
    );
  }

  final String weekId;

  /// `units[aliyah][pass]`: the day that reading was completed.
  final List<List<LocalDate?>> units;

  /// The day the haftarah was read, if it was.
  final LocalDate? haftarah;

  /// `positions[aliyah]` = verses completed in each of the three readings.
  final Map<int, List<int>> positions;

  Map<String, dynamic> toJson() => {
        'u': [
          for (final row in units) [for (final d in row) d?.rd],
        ],
        if (haftarah != null) 'h': haftarah!.rd,
        if (positions.isNotEmpty) 'p': {for (final e in positions.entries) '${e.key}': e.value},
      };

  bool isUnitDone(int aliyah, ReadingPass pass) => units[aliyah][pass.index] != null;

  bool isAliyahDone(int aliyah) => units[aliyah].every((d) => d != null);

  int get completedUnits => units.fold(0, (n, row) => n + row.where((d) => d != null).length);

  int get completedAliyot => [for (var a = 0; a < kAliyot; a++) a].where(isAliyahDone).length;

  bool get isComplete => completedUnits == kAliyot * 3;

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

  /// Marks one reading of one aliyah complete on [date] (if not already).
  WeekProgress withUnit(int aliyah, ReadingPass pass, LocalDate? date) {
    final u = [for (final row in units) [...row]];
    if (date == null) {
      u[aliyah][pass.index] = null;
    } else {
      u[aliyah][pass.index] ??= date;
    }
    return _copy(units: u);
  }

  /// Marks all three readings of [aliyah] complete on [date].
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
