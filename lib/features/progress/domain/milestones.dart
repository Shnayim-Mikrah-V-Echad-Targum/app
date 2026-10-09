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
  bool bookDone(int b) {
    final range = switch (b) {
      0 => (1, 12),
      1 => (13, 23),
      2 => (24, 33),
      3 => (34, 43),
      _ => (44, 54),
    };
    for (var n = range.$1; n <= range.$2; n++) {
      if (!parshiyotDoneThisCycle.contains(n)) return false;
    }
    return true;
  }

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

/// Parsha numbers completed (in any status) during the given cycle.
Set<int> parshiyotDoneInCycle(Map<String, WeekProgress> progress, int cycleYear) {
  final out = <int>{};
  for (final e in progress.entries) {
    final colon = e.key.indexOf(':');
    if (colon < 0 || e.key.substring(0, colon) != '$cycleYear' || !e.value.isComplete) continue;
    for (final part in e.key.substring(colon + 1).split('-')) {
      final n = int.tryParse(part);
      if (n != null) out.add(n);
    }
  }
  return out;
}
