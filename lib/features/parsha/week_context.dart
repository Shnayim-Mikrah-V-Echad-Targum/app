import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/calendar/jewish_holidays.dart';
import '../../core/calendar/local_date.dart';
import '../../core/calendar/parsha_schedule.dart';
import '../../data/models/parsha.dart';
import '../../data/parsha_repository.dart';
import '../progress/domain/progress_models.dart';
import '../progress/domain/reading_plan.dart';
import '../progress/domain/streak_engine.dart';

/// Finds the reading week for a stable week id such as `"5787:22-23"`.
ReadingWeek? findWeekById(ParshaSchedule schedule, String id) {
  final colon = id.indexOf(':');
  if (colon < 0) return null;
  final cycle = int.tryParse(id.substring(0, colon));
  if (cycle == null) return null;
  final PortionId target;
  try {
    target = PortionId.parse(id.substring(colon + 1));
  } catch (_) {
    return null;
  }
  var week = schedule.weekFor(JewishHolidays.simchatTorah(cycle, israel: schedule.israel).addDays(1));
  for (var i = 0; i < 60; i++) {
    if (week.portion.parshiyot.contains(target.number)) return week;
    if (week.portion.isVezotHaberakhah) return null;
    week = schedule.nextWeek(week);
  }
  return null;
}

/// Everything the UI needs about one week, bundled.
class WeekContext {
  const WeekContext({
    required this.week,
    required this.plan,
    required this.portion,
    required this.progress,
    required this.today,
    required this.status,
    required this.haftarah,
    this.joinDate,
  });

  final ReadingWeek week;
  final WeekPlan plan;
  final PortionInfo portion;
  final WeekProgress progress;
  final LocalDate today;

  /// Status from the streak engine, if this week was evaluated.
  final WeekStatus? status;
  final WeekHaftarah haftarah;

  /// When the user started; earlier days are never counted as behind.
  final LocalDate? joinDate;

  String get id => plan.weekId;

  bool get isCurrent => week.contains(today);

  /// Reading for this week can be credited (it has opened).
  bool get isOpen => week.start <= today;

  /// The first aliyah not yet fully read, in order; null when complete.
  int? get nextAliyah {
    for (var a = 0; a < kAliyot; a++) {
      if (!progress.isAliyahDone(a)) return a;
    }
    return null;
  }

  /// Aliyot due since joining, by the end of yesterday, not yet read.
  int behindBy() => [
        for (final d in plan.days)
          if (d.date < today && (joinDate == null || d.date >= joinDate!)) ...d.aliyot,
      ].where((a) => !progress.isAliyahDone(a)).length;
}

final weekContextProvider = Provider.family<WeekContext?, String>((ref, id) {
  final schedule = ref.watch(scheduleProvider);
  final week = findWeekById(schedule, id);
  if (week == null) return null;
  return _contextFor(ref, week);
});

final currentWeekContextProvider = Provider<WeekContext>((ref) => _contextFor(ref, ref.watch(currentWeekProvider)));

WeekContext _contextFor(Ref ref, ReadingWeek week) {
  final plan = ref.watch(plannerProvider).planFor(week);
  final repo = ref.watch(parshaRepositoryProvider);
  final settings = ref.watch(settingsProvider);
  final summary = ref.watch(streakSummaryProvider);
  WeekStatus? status;
  for (final e in summary.weeks) {
    if (e.plan.weekId == plan.weekId) status = e.status;
  }
  return WeekContext(
    week: week,
    plan: plan,
    portion: repo.portion(week.portion),
    progress: ref.watch(progressProvider).week(plan.weekId),
    today: ref.watch(todayProvider),
    status: status,
    haftarah: repo.haftarahFor(week.portion, week.occasion, settings.nusach),
    joinDate: settings.joinDate,
  );
}

/// The previous week, when it still needs attention: unfinished and either
/// within its late window or restorable by doubling up.
final openPreviousWeekProvider = Provider<WeekContext?>((ref) {
  final current = ref.watch(currentWeekProvider);
  final schedule = ref.watch(scheduleProvider);
  final previous = schedule.previousWeek(current);
  final ctx = _contextFor(ref, previous);
  if (ctx.progress.isComplete) return null;
  final join = ref.watch(settingsProvider).joinDate;
  if (join != null && previous.occasion < join) return null;
  final s = ctx.status;
  if (s == WeekStatus.inProgress || s == WeekStatus.overdue) return ctx;
  return null;
});
