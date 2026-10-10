import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/calendar/jewish_holidays.dart';
import '../../core/calendar/local_date.dart';
import '../../core/calendar/parsha_schedule.dart';
import '../../data/models/parsha.dart';
import '../../data/models/verse_ref.dart';
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

/// Where verse [r] of [book] is read in the cycle that began in [cycle]: the
/// id of the week whose portion holds it, and the aliyah of that week's
/// portion that holds it. A combined week divides its aliyot differently from
/// either parsha alone, so the aliyah is counted in the week's own portion.
/// Null for a verse that is not in the Torah.
({String weekId, int aliyah})? locateVerse(
  ParshaRepository repo,
  ParshaSchedule schedule,
  int cycle,
  String book,
  VerseRef r,
) {
  final parsha = repo.all.where((p) => p.book == book && p.range.contains(r)).firstOrNull;
  if (parsha == null) return null;
  final week = findWeekById(schedule, '$cycle:${parsha.id.number}');
  if (week == null) return null;
  final portion = repo.portion(week.portion);
  final aliyah = portion.aliyot.indexWhere((a) => a.contains(r));
  if (aliyah < 0) return null;
  return (weekId: weekIdFor(week.portion, week.occasion), aliyah: aliyah);
}

/// [locateVerse] in the cycle of the current week, the one Browse lists.
final verseLocatorProvider = Provider<({String weekId, int aliyah})? Function(String book, VerseRef r)>((ref) {
  final repo = ref.watch(parshaRepositoryProvider);
  final schedule = ref.watch(scheduleProvider);
  final current = ref.watch(currentWeekProvider);
  final cycle = cycleYearOf(current.portion, current.occasion);
  return (book, r) => locateVerse(repo, schedule, cycle, book, r);
});

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
    required this.aliyahVerses,
    this.joinDate,
    this.haftarahRequired = false,
  });

  final ReadingWeek week;
  final WeekPlan plan;
  final PortionInfo portion;
  final WeekProgress progress;
  final LocalDate today;

  /// Status from the streak engine, if this week was evaluated.
  final WeekStatus? status;
  final WeekHaftarah haftarah;

  /// The number of verses in each aliyah, in order.
  final List<int> aliyahVerses;

  /// When the user started; earlier days are never counted as behind.
  final LocalDate? joinDate;

  /// Whether the haftarah counts toward finishing this week, by the settings
  /// the week is judged by. It can be shown for a past week that still needs
  /// it after the haftarah was turned off.
  final bool haftarahRequired;

  String get id => plan.weekId;

  bool get isCurrent => week.contains(today);

  /// Reading for this week can be credited (it has opened).
  bool get isOpen => week.start <= today;

  /// Whether the haftarah counts toward finishing this week and is not read.
  bool get haftarahDue => haftarahRequired && progress.haftarah == null;

  /// Whether everything that counts toward finishing this week is read.
  bool get isFinished => progress.isComplete && !haftarahDue;

  /// The first aliyah not yet fully read, in order; null when complete.
  int? get nextAliyah {
    for (var a = 0; a < kAliyot; a++) {
      if (!progress.isAliyahDone(a)) return a;
    }
    return null;
  }

  /// Aliyot not yet read that were planned for today or earlier (and not
  /// before joining), in order. Aliyot planned for Shabbat morning are due
  /// once Shabbat has passed.
  List<int> dueAliyot() => _unreadPlannedFor((d) => d <= today);

  /// How many of [dueAliyot] were planned before today.
  int behindBy() => _unreadPlannedFor((d) => d < today).length;

  List<int> _unreadPlannedFor(bool Function(LocalDate date) due) {
    final days = [...plan.days, PlanDay(week.occasion, plan.shabbatAliyot)];
    return [
      for (final d in days)
        if (due(d.date) && (joinDate == null || d.date >= joinDate!))
          for (final a in d.aliyot)
            if (!progress.isAliyahDone(a)) a,
    ]..sort();
  }

  /// About how many minutes it takes to finish [aliyot], counting only the
  /// readings of each not yet done.
  int remainingMinutes(Iterable<int> aliyot) {
    var verseReadings = 0;
    for (final a in aliyot) {
      verseReadings += aliyahVerses[a] * progress.units[a].where((d) => d == null).length;
    }
    // kSecondsPerVerse covers all three readings of a verse. Rounded up in
    // whole numbers, so that an exact minute stays exact.
    const divisor = 3 * 60;
    return (verseReadings * kSecondsPerVerse + divisor - 1) ~/ divisor;
  }
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
  final info = repo.portion(week.portion);
  final settings = ref.watch(settingsProvider);
  final summary = ref.watch(streakSummaryProvider);
  WeekStatus? status;
  for (final e in summary.weeks) {
    if (e.plan.weekId == plan.weekId) status = e.status;
  }
  return WeekContext(
    week: week,
    plan: plan,
    portion: info,
    progress: ref.watch(progressProvider).week(plan.weekId),
    today: ref.watch(todayProvider),
    status: status,
    haftarah: repo.haftarahFor(week.portion, week.occasion, settings.nusach),
    aliyahVerses: [for (var a = 0; a < kAliyot; a++) repo.aliyahVerseCount(info, a)],
    joinDate: settings.joinDate,
    haftarahRequired: ref.watch(streakEngineProvider).settingsFor(week).haftarahRequired,
  );
}

/// The previous week, when it still needs attention: unfinished (perhaps
/// only its haftarah) and either within its late window or restorable by
/// doubling up.
final openPreviousWeekProvider = Provider<WeekContext?>((ref) {
  final current = ref.watch(currentWeekProvider);
  final schedule = ref.watch(scheduleProvider);
  final previous = schedule.previousWeek(current);
  final ctx = _contextFor(ref, previous);
  if (ctx.isFinished) return null;
  final join = ref.watch(settingsProvider).joinDate;
  if (join != null && previous.occasion < join) return null;
  final s = ctx.status;
  if (s == WeekStatus.inProgress || s == WeekStatus.overdue) return ctx;
  return null;
});

/// This week's portions in Israel and outside it, for a reader who hears
/// one place's reading but keeps the other's days of Yom Tov, in a week when
/// the two differ, as they can for a few weeks after Pesach or Shavuot.
/// Israel is then a parsha ahead.
class ReadingDivergence {
  const ReadingDivergence({required this.israel, required this.diaspora, required this.hearsIsrael, this.previous});

  final PortionId israel;
  final PortionId diaspora;

  /// Whether the reader hears Israel's reading (a visitor to Israel), whose
  /// home portion this week was read in Israel last week. Otherwise (an
  /// Israeli abroad) Israel's portion is next week's in their own schedule.
  final bool hearsIsrael;

  /// For a visitor to Israel, the week in their own schedule that holds the
  /// Diaspora's portion (last week), which they can still read; null when
  /// this week holds it.
  final ReadingWeek? previous;
}

final readingDivergenceProvider = Provider<ReadingDivergence?>((ref) {
  if (!ref.watch(settingsProvider.select((s) => s.readingAndYomTovDiffer))) return null;
  final today = ref.watch(todayProvider);
  final israel = const ParshaSchedule(israel: true).weekFor(today);
  final diaspora = const ParshaSchedule(israel: false).weekFor(today);
  if (israel.portion == diaspora.portion) return null;
  // On the Diaspora's Simchat Torah, Israel has begun Bereshit a day early:
  // the same week's reading, not two.
  if (israel.portion.isVezotHaberakhah || diaspora.portion.isVezotHaberakhah) return null;
  final schedule = ref.watch(scheduleProvider);
  final current = ref.watch(currentWeekProvider);
  final elsewhere = schedule.israel ? diaspora : israel;
  var other = findWeekById(schedule, weekIdFor(elsewhere.portion, elsewhere.occasion));
  if (other != null && other.occasion == current.occasion) other = null;
  // Hearing the Diaspora's reading, a week that also holds Israel's portion
  // (the two read together) differs in nothing that matters.
  if (!schedule.israel && other == null) return null;
  return ReadingDivergence(
    israel: israel.portion,
    diaspora: diaspora.portion,
    hearsIsrael: schedule.israel,
    previous: schedule.israel ? other : null,
  );
});
