import '../../../core/calendar/parsha_schedule.dart';
import 'progress_models.dart';
import 'streak_engine.dart';

/// Where one parsha of a year's cycle stands. The Torah map and the year
/// bar both show it, each in its own way, from [parshaStandings], so the two
/// can never disagree on the same screen.
enum ParshaStanding {
  /// Finished by its Shabbat.
  onTime,

  /// Finished by the late deadline.
  late,

  /// Finished late, together with the next portion by its Shabbat.
  restored,

  /// Finished later in the year.
  madeUp,

  /// This week's parsha, not yet finished.
  inProgress,

  /// Its week passed unfinished.
  missed,

  /// Its Shabbat has passed, but it can still be finished in time to count
  /// as late (or to be restored).
  overdue,

  /// Still to come this year.
  upcoming,

  /// Before the reader joined, or paused: it counts for nothing.
  untracked,
}

/// The standing of each of the 54 parshiyot in [cycle] (index 0 is
/// Bereshit), from how each of its weeks ended in [weeks] (the last one
/// wins), the parshiyot finished at any time in the cycle ([done], as
/// `parshiyotDoneInCycle` gives them), and the [current] portion: null for a
/// year gone by, in which nothing is in progress or still to come.
List<ParshaStanding> parshaStandings({
  required Iterable<WeekEvaluation> weeks,
  required int cycle,
  required Set<int> done,
  required PortionId? current,
}) {
  final status = <int, WeekStatus>{};
  for (final e in weeks) {
    if (cycleYearOf(e.plan.portion, e.plan.week.occasion) != cycle) continue;
    for (final n in e.plan.portion.parshiyot) {
      status[n] = e.status;
    }
  }
  return [
    for (var n = 1; n <= kParshaCount; n++)
      switch (status[n]) {
        WeekStatus.onTime => ParshaStanding.onTime,
        WeekStatus.late => ParshaStanding.late,
        WeekStatus.restored => ParshaStanding.restored,
        // This week's portion, finished already, is finished on time.
        _ when current != null && current.parshiyot.contains(n) =>
          done.contains(n) ? ParshaStanding.onTime : ParshaStanding.inProgress,
        final s when done.contains(n) || s == WeekStatus.madeUp => ParshaStanding.madeUp,
        WeekStatus.missed => ParshaStanding.missed,
        WeekStatus.overdue => ParshaStanding.overdue,
        _ when current != null && n > current.number => ParshaStanding.upcoming,
        _ => ParshaStanding.untracked,
      },
  ];
}
