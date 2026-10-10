import '../../../core/calendar/local_date.dart';
import 'progress_models.dart';
import 'streak_engine.dart';

enum MilestoneKind { firstAliyah, firstParsha, perfectWeek, parshaStreak, daysOnTrack, sefer, siyum, comeback }

class Milestone {
  const Milestone(this.kind, {this.value = 0, required this.achieved});
  final MilestoneKind kind;

  /// Threshold (streak length) or book index for [MilestoneKind.sefer].
  final int value;
  final bool achieved;
}

const kParshaStreakMilestones = [4, 13, 18, 26, 36, 54];
const kDaysOnTrackMilestones = [7, 30, 66, 100, 180, 365];

/// Milestones are informational — no points, currency or leaderboards.
List<Milestone> computeMilestones({
  required StreakSummary summary,
  required Map<String, WeekProgress> progress,
  required Set<int> parshiyotDoneThisCycle,
}) {
  final anyAliyah = progress.values.any((w) => w.completedAliyot > 0);
  final anyParsha = progress.values.any((w) => w.isComplete);
  final perfect = summary.weeks.any((e) =>
      e.status == WeekStatus.onTime &&
      e.plan.days.every((d) {
        final s = summary.days[d.date];
        return s == null || s == DayStatus.kept || s == DayStatus.ahead;
      }));
  var comeback = false;
  for (var i = 1; i < summary.weeks.length; i++) {
    final prev = summary.weeks[i - 1].status;
    if ((prev == WeekStatus.missed || prev == WeekStatus.transparent || prev == WeekStatus.madeUp) &&
        summary.weeks[i].status.counts) {
      comeback = true;
    }
  }
  bool bookDone(int b) => parshiyotOfBook(b).every(parshiyotDoneThisCycle.contains);

  return [
    Milestone(MilestoneKind.firstAliyah, achieved: anyAliyah),
    Milestone(MilestoneKind.firstParsha, achieved: anyParsha),
    Milestone(MilestoneKind.perfectWeek, achieved: perfect),
    for (final n in kParshaStreakMilestones)
      Milestone(MilestoneKind.parshaStreak, value: n, achieved: summary.longestParshaStreak >= n),
    for (final n in kDaysOnTrackMilestones)
      Milestone(MilestoneKind.daysOnTrack, value: n, achieved: summary.longestDaysOnTrack >= n),
    for (var b = 0; b < 5; b++) Milestone(MilestoneKind.sefer, value: b, achieved: bookDone(b)),
    Milestone(MilestoneKind.siyum, achieved: parshiyotDoneThisCycle.length >= 54),
    Milestone(MilestoneKind.comeback, achieved: comeback),
  ];
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
