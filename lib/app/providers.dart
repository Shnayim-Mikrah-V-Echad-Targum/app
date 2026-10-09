import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/calendar/jewish_holidays.dart';
import '../core/calendar/local_date.dart';
import '../core/calendar/parsha_schedule.dart';
import '../data/parsha_repository.dart';
import '../data/text_repository.dart';
import '../features/progress/domain/progress_models.dart';
import '../features/progress/domain/reading_plan.dart';
import '../features/progress/domain/streak_engine.dart';
import '../features/settings/app_settings.dart';

/// Provided at startup (see main.dart).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override sharedPreferencesProvider at startup'),
);

/// Provided at startup (see main.dart).
final parshaRepositoryProvider = Provider<ParshaRepository>(
  (ref) => throw UnimplementedError('Override parshaRepositoryProvider at startup'),
);

final textRepositoryProvider = Provider<TextRepository>((ref) => TextRepository());

// ---------------------------------------------------------------------------
// Settings

class SettingsController extends Notifier<AppSettings> {
  static const storageKey = 'settings.v1';

  @override
  AppSettings build() {
    final raw = ref.read(sharedPreferencesProvider).getString(storageKey);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  /// Applies [change]. A change to how weeks are planned and judged applies
  /// from today on (see [AppSettings.recordingPlanChange]).
  void update(AppSettings Function(AppSettings s) change) {
    final next = change(state);
    if (next.planSettings.sameSettingsAs(state.planSettings)) return _save(next);
    // Today's reading day, as todayProvider has it (which depends on these
    // settings, so can't be read here).
    final today = effectiveReadingDay(TodayController.now(), oneDayYomTov: next.oneDayYomTov);
    _save(next.recordingPlanChange(state, today));
  }

  /// Replaces every setting, the plan history included (restoring a backup).
  void replace(AppSettings settings) => _save(settings);

  void _save(AppSettings settings) {
    state = settings;
    ref.read(sharedPreferencesProvider).setString(storageKey, jsonEncode(settings.toJson()));
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

// ---------------------------------------------------------------------------
// Calendar

/// The current "reading day". The day rolls over at 3 a.m. so late-night
/// reading counts for the evening it began; and because no one reads on a
/// device on Shabbat or Yom Tov, use on those civil dates (i.e. after
/// Havdalah) counts toward the next day. [oneDayYomTov] is the reader's
/// custom (see [AppSettings.oneDayYomTov]).
LocalDate effectiveReadingDay(DateTime now, {required bool oneDayYomTov}) {
  var d = LocalDate.fromDateTime(now.subtract(const Duration(hours: 3)));
  while (JewishHolidays.isRestDay(d, israel: oneDayYomTov)) {
    d = d.addDays(1);
  }
  return d;
}

/// Ticks over to the new reading day automatically and when the app resumes.
class TodayController extends Notifier<LocalDate> {
  Timer? _timer;
  AppLifecycleListener? _lifecycle;

  /// Overridable clock, for tests.
  static DateTime Function() now = DateTime.now;

  /// Tests disable the real-time rollover timer.
  static bool autoRollover = true;

  @override
  LocalDate build() {
    final oneDayYomTov = ref.watch(settingsProvider.select((s) => s.oneDayYomTov));
    _lifecycle ??= AppLifecycleListener(onResume: _refresh);
    ref.onDispose(() {
      _timer?.cancel();
      _lifecycle?.dispose();
      _lifecycle = null;
    });
    _schedule();
    return effectiveReadingDay(now(), oneDayYomTov: oneDayYomTov);
  }

  void _schedule() {
    _timer?.cancel();
    if (!autoRollover) return;
    final n = now();
    var next = DateTime(n.year, n.month, n.day, 3, 0, 5);
    if (!next.isAfter(n)) next = next.add(const Duration(days: 1));
    _timer = Timer(next.difference(n), _refresh);
  }

  void _refresh() {
    final today = effectiveReadingDay(now(), oneDayYomTov: ref.read(settingsProvider).oneDayYomTov);
    if (today != state) state = today;
    _schedule();
  }
}

final todayProvider = NotifierProvider<TodayController, LocalDate>(TodayController.new);

/// The reading the user hears in synagogue.
final scheduleProvider = Provider<ParshaSchedule>(
  (ref) => ParshaSchedule(
    israel: ref.watch(settingsProvider.select((s) => s.readingSchedule)) == ReadingSchedule.israel,
  ),
);

/// Plans every week by the plan settings in force at the time, so that a
/// change applies from the day it is made on. (The reading schedule and the
/// days of Yom Tov are not part of that history yet: switching either still
/// plans every week, past ones included, by the new setting.)
final plannerProvider = Provider<ReadingPlanner>((ref) {
  final s = ref.watch(settingsProvider);
  return ReadingPlanner(
    schedule: ref.watch(scheduleProvider),
    oneDayYomTov: s.oneDayYomTov,
    settingsAt: s.settingsAt,
    starterFrom: s.starterCatchUp ? s.joinDate : null,
  );
});

final streakEngineProvider = Provider<StreakEngine>((ref) => StreakEngine(planner: ref.watch(plannerProvider)));

/// This week's reading.
final currentWeekProvider = Provider<ReadingWeek>(
  (ref) => ref.watch(scheduleProvider).weekFor(ref.watch(todayProvider)),
);

final currentPlanProvider = Provider<WeekPlan>(
  (ref) => ref.watch(plannerProvider).planFor(ref.watch(currentWeekProvider)),
);

// ---------------------------------------------------------------------------
// Progress

/// All of the user's reading progress. Treat as immutable: equality is by
/// value and is cached per instance.
class ProgressState {
  const ProgressState({
    this.weeks = const {},
    this.pauses = const [],
    this.resetAt = 0,
    this.unknownWeeks = const {},
    this.unknownPauses = const [],
  });

  final Map<String, WeekProgress> weeks;

  /// Every pause, including cancelled ones (which cover no days), kept so
  /// that the cancellation reaches other devices.
  final List<Pause> pauses;

  /// When all progress was last reset everywhere (see
  /// [ProgressController.reset]), from [ProgressClock]; 0 if never. Merging
  /// drops anything stamped before it.
  final int resetAt;

  /// Stored weeks this version couldn't read (damaged, or written by a newer
  /// version), kept exactly as they were and written back out unchanged so
  /// that they are never lost. A readable week with the same id takes
  /// precedence.
  final Map<String, Object?> unknownWeeks;

  /// Stored pauses this version couldn't read, kept like [unknownWeeks].
  final List<Object?> unknownPauses;

  WeekProgress week(String id) => weeks[id] ?? WeekProgress(weekId: id);

  /// Only the progress this version can read: what a backup file holds, so
  /// that the file can always be imported again.
  ProgressState get readable => unknownWeeks.isEmpty && unknownPauses.isEmpty
      ? this
      : ProgressState(weeks: weeks, pauses: pauses, resetAt: resetAt);

  /// Ids of [unknownWeeks] hidden behind a readable week of the same id.
  Iterable<String> get shadowedWeeks => unknownWeeks.keys.where(weeks.containsKey);

  /// The latest stamp anywhere in this progress, or 0.
  int get latestStamp => [
        resetAt,
        for (final w in weeks.values) w.latestStamp,
        for (final p in pauses) p.updatedAt,
      ].fold(0, max);

  ProgressState copyWith({
    Map<String, WeekProgress>? weeks,
    List<Pause>? pauses,
    Map<String, Object?>? unknownWeeks,
  }) =>
      ProgressState(
        weeks: weeks ?? this.weeks,
        pauses: pauses ?? this.pauses,
        resetAt: resetAt,
        unknownWeeks: unknownWeeks ?? this.unknownWeeks,
        unknownPauses: unknownPauses,
      );

  /// This progress changed to read exactly like [target] (a backup being
  /// restored). Whatever differs takes [target]'s value as a new change, so
  /// that a sync carries it to other devices instead of undoing it: what
  /// [target] lacks is removed, and [target]'s own stamps and reset don't
  /// matter. Entries this version couldn't read are kept.
  ProgressState restoredTo(ProgressState target) => ProgressClock.above(resetAt, () {
        final weeks = <String, WeekProgress>{};
        for (final id in {...this.weeks.keys, ...target.weeks.keys}) {
          final w = week(id).restoredTo(target.week(id));
          if (!w.isBlank) weeks[id] = w;
        }
        final wanted = {for (final p in target.pauses) p.id: p};
        final had = {for (final p in this.pauses) p.id};
        final pauses = [
          for (final p in this.pauses)
            if (wanted[p.id] case final t?) p.restoredTo(t) else if (p.deleted) p else p.cancelled(),
          for (final t in wanted.values)
            if (!t.deleted && !had.contains(t.id))
              Pause(t.start, t.end, id: t.id, updatedAt: ProgressClock.after(t.updatedAt)),
        ];
        return ProgressState(
          weeks: weeks,
          pauses: pauses,
          resetAt: resetAt,
          unknownWeeks: unknownWeeks,
          unknownPauses: unknownPauses,
        );
      });

  /// Equal progress compares equal whatever order its maps and lists are in,
  /// so a sync that changes nothing doesn't look like a change. ([toJson]
  /// can't be compared directly: merging and the server's jsonb storage both
  /// reorder keys.)
  @override
  bool operator ==(Object other) => identical(this, other) || other is ProgressState && other._canon == _canon;

  @override
  int get hashCode => _canon.hashCode;

  // An Expando rather than a late field, which a const class can't have.
  static final _canonCache = Expando<String>('ProgressState.canon');

  String get _canon => _canonCache[this] ??= jsonEncode({
        'weeks': {for (final id in weeks.keys.toList()..sort()) id: weeks[id]!.toJson()},
        'pauses': [for (final p in pauses) jsonEncode(p.toJson())]..sort(),
        if (resetAt != 0) 'resetAt': resetAt,
        if (unknownWeeks.isNotEmpty) 'unknownWeeks': canonicalJson(unknownWeeks),
        if (unknownPauses.isNotEmpty)
          'unknownPauses': [for (final p in unknownPauses) jsonEncode(canonicalJson(p))]..sort(),
      });

  /// [json] with every object's keys sorted, so that equal JSON encodes
  /// identically.
  static Object? canonicalJson(Object? json) => switch (json) {
        Map() => {for (final k in json.keys.map((k) => '$k').toList()..sort()) k: canonicalJson(json[k])},
        List() => [for (final e in json) canonicalJson(e)],
        _ => json,
      };

  /// The format version of stored progress [json].
  static int formatOf(Map<String, dynamic> json) => switch (json['version']) {
        null => 1,
        final int v => v,
        final v => throw FormatException('Unrecognized progress version $v'),
      };

  Map<String, dynamic> toJson() => {
        'version': kProgressFormat,
        if (resetAt != 0) 'resetAt': resetAt,
        'weeks': {...unknownWeeks, for (final e in weeks.entries) e.key: e.value.toJson()},
        'pauses': [for (final p in pauses) p.toJson(), ...unknownPauses],
      };

  /// Reads stored progress leniently: each week and pause is read on its own,
  /// and one that can't be read is kept aside in [unknownWeeks] or
  /// [unknownPauses] rather than losing the rest. Throws only if the overall
  /// shape is wrong.
  ///
  /// With [strict] (for importing a backup), anything that can't be read
  /// exactly, or a newer format, throws a [FormatException] instead.
  factory ProgressState.fromJson(Map<String, dynamic> j, {bool strict = false}) {
    final version = formatOf(j);
    if (strict && version > kProgressFormat) {
      throw FormatException('Progress format $version is newer than $kProgressFormat');
    }
    final rawWeeks = j['weeks'] ?? const <String, dynamic>{};
    final rawPauses = j['pauses'] ?? const [];
    if (rawWeeks is! Map<String, dynamic> || rawPauses is! List) throw const FormatException('Unrecognized progress');
    // A reset that can't be read is ignored rather than dropping anything.
    final rawResetAt = j['resetAt'] ?? 0;
    final resetAt = rawResetAt is int && rawResetAt >= 0 ? rawResetAt : 0;
    if (strict && resetAt != rawResetAt) throw FormatException('Unrecognized reset time $rawResetAt');

    final weeks = <String, WeekProgress>{};
    final unknownWeeks = <String, Object?>{};
    for (final MapEntry(:key, :value) in rawWeeks.entries) {
      try {
        weeks[key] = WeekProgress.fromJson(key, value as Map<String, dynamic>, strict: strict);
      } catch (_) {
        if (strict) throw FormatException('Unreadable progress for week $key');
        unknownWeeks[key] = value;
      }
    }
    final pauses = <Pause>[];
    final unknownPauses = <Object?>[];
    for (final p in rawPauses) {
      try {
        pauses.add(Pause.fromJson(p as Map<String, dynamic>));
      } catch (_) {
        if (strict) throw FormatException('Unreadable pause $p');
        unknownPauses.add(p);
      }
    }
    return ProgressState(
      weeks: weeks,
      pauses: pauses,
      resetAt: resetAt,
      unknownWeeks: unknownWeeks,
      unknownPauses: unknownPauses,
    );
  }
}

class ProgressController extends Notifier<ProgressState> {
  static const storageKey = 'progress.v1';

  /// Prefixes of the keys under which stored progress is copied, with the
  /// time in milliseconds appended, before anything could overwrite it:
  /// progress written by a newer version of the app, and progress (or part of
  /// it) this version can't read.
  static const newerBackupPrefix = 'progress.newer.';
  static const corruptBackupPrefix = 'progress.corrupt.';

  @override
  ProgressState build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = prefs.getString(storageKey);
    if (raw == null) return const ProgressState();
    var version = kProgressFormat;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      version = ProgressState.formatOf(j);
      // Saving in this version's format would drop whatever it doesn't know.
      if (version > kProgressFormat) _backUp(prefs, newerBackupPrefix, raw);
      return ProgressState.fromJson(j);
    } catch (_) {
      // Unreadable, and the next save would replace it.
      if (version <= kProgressFormat) _backUp(prefs, corruptBackupPrefix, raw);
      return const ProgressState();
    }
  }

  /// Copies [raw] to a new key starting with [prefix], unless an identical
  /// copy is already there.
  static void _backUp(SharedPreferences prefs, String prefix, String raw) {
    final keys = prefs.getKeys().where((k) => k.startsWith(prefix));
    if (keys.any((k) => prefs.get(k) == raw)) return;
    var ms = DateTime.now().millisecondsSinceEpoch;
    while (prefs.containsKey('$prefix$ms')) {
      ms++;
    }
    prefs.setString('$prefix$ms', raw);
  }

  void _set(ProgressState s) {
    final prefs = ref.read(sharedPreferencesProvider);
    final shadowed = s.shadowedWeeks.toSet();
    if (shadowed.isNotEmpty) {
      // A week this version couldn't read is about to be replaced by a
      // readable one (e.g. the user marked it again): keep a copy.
      _backUp(prefs, corruptBackupPrefix, jsonEncode({
        'weeks': {for (final id in shadowed) id: s.unknownWeeks[id]},
      }));
      s = s.copyWith(unknownWeeks: {...s.unknownWeeks}..removeWhere((id, _) => shadowed.contains(id)));
    }
    state = s;
    prefs.setString(storageKey, jsonEncode(s.toJson()));
  }

  /// Applies [change] to one week, stamping it after the last reset. A
  /// change that changes nothing saves nothing.
  void _updateWeek(String weekId, WeekProgress Function(WeekProgress w) change) {
    final before = state.week(weekId);
    final after = ProgressClock.above(state.resetAt, () => change(before));
    if (identical(after, before)) return;
    _set(state.copyWith(weeks: {...state.weeks, weekId: after}));
  }

  void markUnit(String weekId, int aliyah, ReadingPass pass, LocalDate? date) =>
      _updateWeek(weekId, (w) => w.withUnit(aliyah, pass, date));

  void markAliyah(String weekId, int aliyah, LocalDate? date) =>
      _updateWeek(weekId, (w) => w.withAliyah(aliyah, date));

  /// Marks each of [aliyot] read on [date], as one change.
  void markAliyot(String weekId, List<int> aliyot, LocalDate date) =>
      _updateWeek(weekId, (w) => aliyot.fold(w, (w, a) => w.withAliyah(a, date)));

  void markWeek(String weekId, LocalDate date) => _updateWeek(weekId, (w) => w.withAll(date));

  void clearWeek(String weekId) => _updateWeek(weekId, (w) => w.cleared());

  /// Puts a week back the way it was in [before] (undoing a clear), as a new
  /// change that a sync won't undo.
  void restoreWeek(String weekId, WeekProgress before) => _updateWeek(weekId, (w) => w.restoredTo(before));

  void markHaftarah(String weekId, LocalDate? date) => _updateWeek(weekId, (w) => w.withHaftarah(date));

  void savePosition(String weekId, int aliyah, List<int> versesDone) =>
      _updateWeek(weekId, (w) => w.withPosition(aliyah, versesDone));

  /// Pauses streaks from [start] to [end]. The new pause is identified by
  /// the time it was created.
  void addPause(LocalDate start, LocalDate end) => ProgressClock.above(state.resetAt, () {
        final created = ProgressClock.after(0);
        var id = created;
        while (state.pauses.any((p) => p.id == '$id')) {
          id++;
        }
        _set(state.copyWith(pauses: [...state.pauses, Pause(start, end, id: '$id', updatedAt: created)]));
      });

  /// Ends any pause covering [today] as of yesterday, cancelling one that
  /// began today.
  void endPause(LocalDate today) => ProgressClock.above(state.resetAt, () {
        if (!state.pauses.any((p) => p.contains(today))) return;
        _set(state.copyWith(
          pauses: [
            for (final p in state.pauses)
              if (!p.contains(today))
                p
              else if (p.start < today)
                p.endingOn(today.addDays(-1))
              else
                p.cancelled(),
          ],
        ));
      });

  /// Replaces all progress with a cloud merge. Equal progress is ignored, so
  /// listeners only hear about real changes. A reset made on another device
  /// restarts the join date here too, as [resetAll] does there.
  void replaceAll(ProgressState s) {
    if (s == state) return;
    final resetElsewhere = s.resetAt > state.resetAt;
    _set(s);
    if (resetElsewhere) _joinNoEarlierThan(s.resetAt);
  }

  /// Moves the join date up to the reading day of [resetAt], if it was
  /// earlier: what the reset erased must not show as missed.
  void _joinNoEarlierThan(int resetAt) {
    final settings = ref.read(settingsProvider);
    final join = settings.joinDate;
    if (join == null) return;
    final today = ref.read(todayProvider);
    final day = effectiveReadingDay(DateTime.fromMillisecondsSinceEpoch(resetAt), oneDayYomTov: settings.oneDayYomTov);
    // A clock running ahead elsewhere must not start the reader in the future.
    final start = day > today ? today : day;
    if (join < start) ref.read(settingsProvider.notifier).update((s) => s.copyWith(joinDate: start));
  }

  /// Makes progress read exactly like [target] (an imported backup), as a
  /// new change that a sync carries to other devices rather than undoing.
  void restore(ProgressState target) => replaceAll(state.restoredTo(target));

  /// Erases all progress. With [everywhere] (when progress is backed up),
  /// the reset reaches the backup and the user's other devices too: syncing
  /// drops everything recorded before it. Otherwise the backup is untouched,
  /// and syncing later brings it back.
  void reset({bool everywhere = false}) =>
      _set(ProgressState(resetAt: everywhere ? ProgressClock.after(state.latestStamp) : state.resetAt));

  /// Erases all progress as [reset] does, and starts the reader afresh on
  /// [today]: with the history gone, the weeks before it must not show as
  /// missed.
  void resetAll(LocalDate today, {bool everywhere = false}) {
    reset(everywhere: everywhere);
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(joinDate: today));
  }
}

final progressProvider = NotifierProvider<ProgressController, ProgressState>(ProgressController.new);

final streakSummaryProvider = Provider<StreakSummary>((ref) {
  final engine = ref.watch(streakEngineProvider);
  final progress = ref.watch(progressProvider);
  final today = ref.watch(todayProvider);
  final joinDate = ref.watch(settingsProvider.select((s) => s.joinDate)) ?? today;
  return engine.evaluate(
    progress: progress.weeks,
    joinDate: joinDate,
    today: today,
    pauses: progress.pauses,
  );
});

/// Whether a pause covers today.
final isPausedProvider = Provider<bool>((ref) {
  final today = ref.watch(todayProvider);
  return ref.watch(progressProvider).pauses.any((p) => p.contains(today));
});
