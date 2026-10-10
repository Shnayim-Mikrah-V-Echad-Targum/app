import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/calendar/local_date.dart';
import '../features/progress/domain/milestones.dart';
import '../features/progress/domain/progress_models.dart';
import 'providers.dart';
import 'router.dart';

/// Celebrates each book of the Torah once, as it is finished
/// (DESIGN_SYSTEM.md §6.23): whenever the reading log changes, the books
/// finished in this cycle and the last are compared with those already
/// celebrated, and a book newly finished opens `/celebrate/sefer:5787:0`.
///
/// It watches the log rather than the reader, since a book can be finished
/// from Today, the week's page or the check-in after Shabbat too. Watched by
/// the app, so that it lives as long as the app does.
///
/// The books celebrated are kept on this device alone ([storageKey]): they
/// are the interface's state, never synced or backed up. Books already
/// finished when the app starts are taken as celebrated, as is a book that
/// arrives finished long ago (restored from a backup, say): only a book
/// finished in the last week is celebrated.
final celebrationListenerProvider = Provider<void>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);

  Set<String> celebrated() => {...?prefs.getStringList(CelebrationKeys.storageKey)};

  // The books finished in the current cycle and the one before, by key,
  // with the day each was finished.
  Map<String, LocalDate> finished() {
    final week = ref.read(currentWeekProvider);
    final cycle = cycleYearOf(week.portion, week.occasion);
    final progress = ref.read(progressProvider).weeks;
    return {
      for (final year in [cycle - 1, cycle])
        for (final MapEntry(key: book, value: on) in seferCompletions(progress, year).entries)
          seferKey(year, book): on,
    };
  }

  void record(Set<String> seen, Iterable<String> keys) =>
      prefs.setStringList(CelebrationKeys.storageKey, ({...seen, ...keys}.toList()..sort()));

  final seen = celebrated();
  final already = finished().keys.where((k) => !seen.contains(k));
  if (already.isNotEmpty) record(seen, already);

  // Only a change to what was read, not each step's saved place.
  ref.listen(progressProvider.select((p) => p.logRevision), (_, _) {
    final seen = celebrated();
    final fresh = finished().entries.where((e) => !seen.contains(e.key)).toList();
    if (fresh.isEmpty) return;
    record(seen, fresh.map((e) => e.key));
    final since = ref.read(todayProvider).addDays(-CelebrationKeys.recentDays);
    final recent = fresh.where((e) => e.value >= since).toList()..sort((a, b) => a.value.compareTo(b.value));
    if (recent.isEmpty || !ref.read(settingsProvider).onboardingComplete) return;
    // Once the change has been built, over whatever page made it (and after
    // a sheet that made it has closed).
    final key = recent.last.key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.mounted) ref.read(routerProvider).push('/celebrate/$key');
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  });
});

/// Where and for how long the celebration listener keeps what it has seen.
abstract final class CelebrationKeys {
  /// The books already celebrated on this device, as [seferKey]s.
  static const storageKey = 'celebrated.v1';

  /// How recently a book must have been finished, in days, to be celebrated
  /// as its finish arrives: long enough for a reading on Shabbat logged
  /// after it, or a late finish.
  static const recentDays = 7;
}
