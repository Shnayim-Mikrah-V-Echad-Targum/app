import '../../../core/calendar/local_date.dart';
import '../../../core/calendar/parsha_schedule.dart';
import 'progress_models.dart';
import 'streak_engine.dart';

enum MilestoneKind { firstAliyah, firstParsha, perfectWeek, parshaStreak, daysOnTrack, sefer, siyum, comeback }

/// Something the reader has done, as the Record on Progress lists it.
///
/// Milestones are derived from the reading log every time, never stored, so
/// the streaks stay a pure function of progress, and one reached in an
/// earlier year stays reached when a new cycle begins.
class Milestone {
  const Milestone(this.kind, {this.value = 0, required this.achieved, this.achievedOn, this.fromParsha});
  final MilestoneKind kind;

  /// Threshold (streak length) or book index for [MilestoneKind.sefer].
  final int value;
  final bool achieved;

  /// The day it was first reached, if it has been.
  final LocalDate? achievedOn;

  /// For a siyum of a reader who joined partway through the year: the parsha
  /// it began with ("Siyum from Parshat Vayera"). Null for the whole Torah.
  final int? fromParsha;
}

const kParshaStreakMilestones = [4, 13, 18, 26, 36, 54];
const kDaysOnTrackMilestones = [7, 30, 66, 100, 180, 365];

/// Milestones are informational — no points, currency or leaderboards.
///
/// [doneByCycle] is the parshiyot completed in each cycle, as
/// [parshiyotDoneByCycle] gives them. A book counts as finished, and the
/// Torah as completed, if it was in any cycle, so neither is lost when the
/// next year begins. [joinDate] is the day the reader started: the week
/// they joined after it began is no part of their history, and no gap they
/// could come back from.
List<Milestone> computeMilestones({
  required StreakSummary summary,
  required Map<String, WeekProgress> progress,
  required Map<int, Set<int>> doneByCycle,
  LocalDate? joinDate,
}) {
  LocalDate? earliest(Iterable<LocalDate?> days) =>
      days.nonNulls.fold<LocalDate?>(null, (a, d) => a == null || d < a ? d : a);
  LocalDate? latest(Iterable<LocalDate?> days) =>
      days.nonNulls.fold<LocalDate?>(null, (a, d) => a == null || d > a ? d : a);

  // An aliyah is finished on the day the last of its readings was.
  final firstAliyah = earliest([
    for (final w in progress.values)
      for (var a = 0; a < kAliyot; a++)
        if (w.isAliyahDone(a)) latest(w.units[a]),
  ]);
  final firstParsha = earliest(progress.values.map((w) => w.completedOn));

  final perfect = summary.weeks
      .where((e) =>
          e.status == WeekStatus.onTime &&
          e.plan.days.every((d) {
            final s = summary.days[d.date];
            return s == null || s == DayStatus.kept || s == DayStatus.ahead;
          }))
      .firstOrNull;

  // Back after a week missed, made up or paused: not after the week the
  // reader joined once it had begun, which the engine leaves transparent
  // too when they don't finish it.
  bool gap(WeekEvaluation e) => switch (e.status) {
        WeekStatus.missed || WeekStatus.madeUp => true,
        WeekStatus.transparent => joinDate == null || !(e.plan.week.start < joinDate),
        _ => false,
      };
  LocalDate? comeback;
  for (var i = 1; i < summary.weeks.length && comeback == null; i++) {
    if (gap(summary.weeks[i - 1]) && summary.weeks[i].status.counts) {
      comeback = summary.weeks[i].completedOn;
    }
  }

  // The day each run first reached a length, counted as the engine counts
  // it: a week finished late or restored continues the run, and one made up
  // or missed breaks it.
  final parshaRunReached = <int, LocalDate?>{};
  var weeksRun = 0;
  for (final e in summary.weeks) {
    if (e.status.counts) {
      parshaRunReached.putIfAbsent(++weeksRun, () => e.completedOn);
    } else if (e.status.breaks) {
      weeksRun = 0;
    }
  }
  final daysRunReached = <int, LocalDate>{};
  var daysRun = 0;
  for (final d in summary.days.keys.toList()..sort()) {
    final s = summary.days[d]!;
    if (s.counts) {
      daysRunReached.putIfAbsent(++daysRun, () => d);
    } else if (s == DayStatus.missed) {
      daysRun = 0;
    }
  }

  // Books and the Torah, cycle by cycle, oldest first, so that each is dated
  // by the first time it was finished.
  final cycles = doneByCycle.keys.toList()..sort();
  final completions = {for (final c in cycles) c: _completionsInCycle(progress, c)};
  LocalDate? finishedOn(int cycle, Iterable<int> parshiyot) => latest(parshiyot.map((n) => completions[cycle]![n]));

  final books = <int, LocalDate?>{};
  for (var b = 0; b < 5; b++) {
    for (final c in cycles) {
      if (parshiyotOfBook(b).every(doneByCycle[c]!.contains)) {
        books[b] = finishedOn(c, parshiyotOfBook(b));
        break;
      }
    }
  }

  // The first year read through, and any year before it read from partway
  // through: once the whole Torah is completed, a later partial year is no
  // milestone of its own.
  LocalDate? siyum;
  var siyumDone = false;
  ({int from, LocalDate? on})? joinerSiyum;
  for (final c in cycles) {
    final from = _firstLogged(progress, c);
    if (from == null) continue;
    final rest = [for (var n = from; n <= kParshaCount; n++) n];
    if (!rest.every(doneByCycle[c]!.contains)) continue;
    if (from == 1) {
      siyumDone = true;
      siyum = finishedOn(c, rest);
      break;
    }
    // A reader who joined partway through the year completes it from where
    // they began, as long as that was before Deuteronomy: a siyum from one
    // of its parshiyot would be that book alone, which its own milestone
    // marks, or less.
    if (from < parshiyotOfBook(4).first) joinerSiyum ??= (from: from, on: finishedOn(c, rest));
  }

  return [
    Milestone(MilestoneKind.firstAliyah, achieved: firstAliyah != null, achievedOn: firstAliyah),
    Milestone(MilestoneKind.firstParsha, achieved: firstParsha != null, achievedOn: firstParsha),
    Milestone(MilestoneKind.perfectWeek, achieved: perfect != null, achievedOn: perfect?.completedOn),
    for (final n in kParshaStreakMilestones)
      Milestone(
        MilestoneKind.parshaStreak,
        value: n,
        achieved: summary.longestParshaStreak >= n,
        achievedOn: parshaRunReached[n],
      ),
    for (final n in kDaysOnTrackMilestones)
      Milestone(
        MilestoneKind.daysOnTrack,
        value: n,
        achieved: summary.longestDaysOnTrack >= n,
        achievedOn: daysRunReached[n],
      ),
    for (var b = 0; b < 5; b++)
      Milestone(MilestoneKind.sefer, value: b, achieved: books.containsKey(b), achievedOn: books[b]),
    Milestone(MilestoneKind.siyum, achieved: siyumDone, achievedOn: siyum),
    if (joinerSiyum case final s?) Milestone(MilestoneKind.siyum, achieved: true, achievedOn: s.on, fromParsha: s.from),
    Milestone(MilestoneKind.comeback, achieved: comeback != null, achievedOn: comeback),
  ];
}

/// The first parsha with any reading logged in [cycleYear], by number, or
/// null if none has any.
int? _firstLogged(Map<String, WeekProgress> progress, int cycleYear) {
  int? first;
  for (final e in progress.entries) {
    final colon = e.key.indexOf(':');
    if (colon < 0 || e.key.substring(0, colon) != '$cycleYear' || e.value.completedUnits == 0) continue;
    final n = int.tryParse(e.key.substring(colon + 1).split('-').first);
    if (n != null && (first == null || n < first)) first = n;
  }
  return first;
}

/// The numbers of the parshiyot of book [book] (0 Genesis … 4 Deuteronomy,
/// Vezot HaBerakhah included).
Iterable<int> parshiyotOfBook(int book) {
  final (first, last) = switch (book) {
    0 => (1, 12),
    1 => (13, 23),
    2 => (24, 33),
    3 => (34, 43),
    _ => (44, 54),
  };
  return [for (var n = first; n <= last; n++) n];
}

/// Parsha numbers completed (in any status) during the given cycle.
Set<int> parshiyotDoneInCycle(Map<String, WeekProgress> progress, int cycleYear) =>
    _completionsInCycle(progress, cycleYear).keys.toSet();

/// The parshiyot completed in each cycle with any reading logged, by the
/// year the cycle began, as [parshiyotDoneInCycle] gives them.
Map<int, Set<int>> parshiyotDoneByCycle(Map<String, WeekProgress> progress) =>
    {for (final c in cyclesLogged(progress)) c: parshiyotDoneInCycle(progress, c)};

/// The cycles with any reading logged, by the year each began.
Set<int> cyclesLogged(Map<String, WeekProgress> progress) => {
      for (final e in progress.entries)
        if (e.value.completedUnits > 0) ?int.tryParse(e.key.split(':').first),
    };

/// Each parsha completed during the given cycle, with the day it was: the
/// day the last reading of its week was marked.
Map<int, LocalDate> _completionsInCycle(Map<String, WeekProgress> progress, int cycleYear) {
  final out = <int, LocalDate>{};
  for (final e in progress.entries) {
    final colon = e.key.indexOf(':');
    if (colon < 0 || e.key.substring(0, colon) != '$cycleYear') continue;
    final on = e.value.completedOn;
    if (on == null) continue;
    for (final part in e.key.substring(colon + 1).split('-')) {
      final n = int.tryParse(part);
      if (n != null) out[n] = out[n] == null || on > out[n]! ? on : out[n]!;
    }
  }
  return out;
}

/// The books of the Torah finished during the cycle that began in
/// [cycleYear] (every one of their parshiyot completed, in any status), by
/// book index, each with the day it was finished: the day the last of its
/// parshiyot was.
Map<int, LocalDate> seferCompletions(Map<String, WeekProgress> progress, int cycleYear) {
  final done = _completionsInCycle(progress, cycleYear);
  return {
    for (var b = 0; b < 5; b++)
      if (parshiyotOfBook(b).every(done.containsKey))
        b: parshiyotOfBook(b).map((n) => done[n]!).reduce((a, c) => c > a ? c : a),
  };
}

/// A finished book as one key, the same on every device: "sefer:5787:0" for
/// Genesis in the cycle that began in 5787.
String seferKey(int cycleYear, int book) => 'sefer:$cycleYear:$book';

/// The cycle and book of a [seferKey], or null if [key] isn't one.
({int cycleYear, int book})? parseSeferKey(String key) {
  final parts = key.split(':');
  if (parts.length != 3 || parts[0] != 'sefer') return null;
  final cycle = int.tryParse(parts[1]);
  final book = int.tryParse(parts[2]);
  if (cycle == null || book == null || book < 0 || book > 4) return null;
  return (cycleYear: cycle, book: book);
}
