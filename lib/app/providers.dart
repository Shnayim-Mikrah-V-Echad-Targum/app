import 'dart:async';
import 'dart:convert';

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

  void update(AppSettings Function(AppSettings s) change) {
    state = change(state);
    ref.read(sharedPreferencesProvider).setString(storageKey, jsonEncode(state.toJson()));
  }

  void replace(AppSettings settings) => update((_) => settings);
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

// ---------------------------------------------------------------------------
// Calendar

/// The current "reading day". The day rolls over at 3 a.m. so late-night
/// reading counts for the evening it began; and because no one reads on a
/// device on Shabbat or Yom Tov, use on those civil dates (i.e. after
/// Havdalah) counts toward the next day.
LocalDate effectiveReadingDay(DateTime now, {required bool israel}) {
  var d = LocalDate.fromDateTime(now.subtract(const Duration(hours: 3)));
  while (JewishHolidays.isRestDay(d, israel: israel)) {
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
    final israel = ref.watch(settingsProvider.select((s) => s.israel));
    _lifecycle ??= AppLifecycleListener(onResume: _refresh);
    ref.onDispose(() {
      _timer?.cancel();
      _lifecycle?.dispose();
      _lifecycle = null;
    });
    _schedule();
    return effectiveReadingDay(now(), israel: israel);
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
    final israel = ref.read(settingsProvider).israel;
    final today = effectiveReadingDay(now(), israel: israel);
    if (today != state) state = today;
    _schedule();
  }
}

final todayProvider = NotifierProvider<TodayController, LocalDate>(TodayController.new);

final scheduleProvider = Provider<ParshaSchedule>(
  (ref) => ParshaSchedule(israel: ref.watch(settingsProvider.select((s) => s.israel))),
);

final plannerProvider = Provider<ReadingPlanner>((ref) {
  final s = ref.watch(settingsProvider);
  return ReadingPlanner(
    schedule: ref.watch(scheduleProvider),
    type: s.plan,
    tishaBavQuiet: s.tishaBavQuiet,
    cholHamoedQuiet: s.cholHamoedQuiet,
  );
});

final streakEngineProvider = Provider<StreakEngine>((ref) {
  final s = ref.watch(settingsProvider);
  return StreakEngine(
    planner: ref.watch(plannerProvider),
    lateWindow: s.lateWindow,
    haftarahRequired: s.haftarahEnabled && s.haftarahRequired,
  );
});

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
    this.unknownWeeks = const {},
    this.unknownPauses = const [],
  });

  final Map<String, WeekProgress> weeks;
  final List<Pause> pauses;

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
  ProgressState get readable =>
      unknownWeeks.isEmpty && unknownPauses.isEmpty ? this : ProgressState(weeks: weeks, pauses: pauses);

  /// Ids of [unknownWeeks] hidden behind a readable week of the same id.
  Iterable<String> get shadowedWeeks => unknownWeeks.keys.where(weeks.containsKey);

  ProgressState copyWith({
    Map<String, WeekProgress>? weeks,
    List<Pause>? pauses,
    Map<String, Object?>? unknownWeeks,
  }) =>
      ProgressState(
        weeks: weeks ?? this.weeks,
        pauses: pauses ?? this.pauses,
        unknownWeeks: unknownWeeks ?? this.unknownWeeks,
        unknownPauses: unknownPauses,
      );

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
        'pauses': [for (final p in [...pauses]..sort(_byDates)) p.toJson()],
        if (unknownWeeks.isNotEmpty) 'unknownWeeks': canonicalJson(unknownWeeks),
        if (unknownPauses.isNotEmpty)
          'unknownPauses': [for (final p in unknownPauses) jsonEncode(canonicalJson(p))]..sort(),
      });

  static int _byDates(Pause p, Pause q) => p.start != q.start ? p.start.compareTo(q.start) : p.end.compareTo(q.end);

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
    return ProgressState(weeks: weeks, pauses: pauses, unknownWeeks: unknownWeeks, unknownPauses: unknownPauses);
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

  void _updateWeek(String weekId, WeekProgress Function(WeekProgress w) change) =>
      _set(state.copyWith(weeks: {...state.weeks, weekId: change(state.week(weekId))}));

  void markUnit(String weekId, int aliyah, ReadingPass pass, LocalDate? date) =>
      _updateWeek(weekId, (w) => w.withUnit(aliyah, pass, date));

  void markAliyah(String weekId, int aliyah, LocalDate? date) =>
      _updateWeek(weekId, (w) => w.withAliyah(aliyah, date));

  void markWeek(String weekId, LocalDate date) => _updateWeek(weekId, (w) => w.withAll(date));

  void clearWeek(String weekId) => _updateWeek(weekId, (w) => WeekProgress(weekId: weekId));

  void markHaftarah(String weekId, LocalDate? date) => _updateWeek(weekId, (w) => w.withHaftarah(date));

  void savePosition(String weekId, int aliyah, List<int> versesDone) =>
      _updateWeek(weekId, (w) => w.withPosition(aliyah, versesDone));

  void addPause(Pause pause) => _set(state.copyWith(pauses: [...state.pauses, pause]));

  /// Ends any pause covering [today] as of yesterday.
  void endPause(LocalDate today) => _set(state.copyWith(
        pauses: [
          for (final p in state.pauses)
            if (!p.contains(today)) p else if (p.start < today) Pause(p.start, today.addDays(-1)),
        ],
      ));

  /// Replaces all progress (an import, an undo or a cloud merge). Equal
  /// progress is ignored, so listeners only hear about real changes.
  void replaceAll(ProgressState s) {
    if (s == state) return;
    _set(s);
  }

  void reset() => _set(const ProgressState());
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
