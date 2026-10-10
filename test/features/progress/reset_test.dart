import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/streak_engine.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

/// Wednesday of Noach 5787.
final _today = LocalDate(2026, 10, 14);

/// About three months earlier.
final _joined = LocalDate(2026, 7, 14);

class _FixedToday extends TodayController {
  @override
  LocalDate build() => _today;
}

String _weekOf(LocalDate date) {
  final w = const ParshaSchedule(israel: false).weekFor(date);
  return weekIdFor(w.portion, w.occasion);
}

/// A few portions read since joining, the rest not.
ProgressState _history() {
  WeekProgress all(String id, LocalDate on) => WeekProgress(weekId: id).withAll(on);
  final first = _weekOf(_joined.addDays(7));
  final second = _weekOf(_joined.addDays(14));
  final current = _weekOf(_today);
  return ProgressState(
    weeks: {
      first: all(first, _joined.addDays(7)),
      second: all(second, _joined.addDays(14)),
      current: WeekProgress(weekId: current).withAliyah(0, _today.addDays(-3)),
    },
    pauses: [Pause(_joined.addDays(30), _joined.addDays(33))],
  );
}

void main() {
  late SharedPreferences prefs;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      SettingsController.storageKey: jsonEncode(AppSettings(onboardingComplete: true, joinDate: _joined).toJson()),
      ProgressController.storageKey: jsonEncode(_history().toJson()),
    });
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      todayProvider.overrideWith(_FixedToday.new),
    ]);
    addTearDown(container.dispose);
  });

  StreakSummary summary() => container.read(streakSummaryProvider);
  ProgressController progress() => container.read(progressProvider.notifier);
  AppSettings settings() => container.read(settingsProvider);
  /// The settings in storage, once the change waiting to be saved is.
  Future<AppSettings> savedSettings() async {
    await container.read(settingsProvider.notifier).flush();
    return AppSettings.fromJson(jsonDecode(prefs.getString(SettingsController.storageKey)!) as Map<String, dynamic>);
  }

  group('resetting all progress', () {
    test('starts the reader afresh today, with no missed weeks behind them', () async {
      expect(summary().weeks.length, greaterThan(10));
      expect(summary().weeks.where((w) => w.status == WeekStatus.missed), isNotEmpty, reason: 'before the reset');

      progress().resetAll(_today);

      expect(container.read(progressProvider).weeks, isEmpty);
      expect(container.read(progressProvider).pauses, isEmpty);
      expect(settings().joinDate, _today);
      expect((await savedSettings()).joinDate, _today, reason: 'saved');
      final s = summary();
      expect(s.weeks, hasLength(1));
      expect(s.weeks.single.status, WeekStatus.inProgress);
      expect(s.weeks.where((w) => w.status == WeekStatus.missed), isEmpty);
      expect(s.graceBalance, GraceRules.startingBalance);
      expect(s.days.keys, [_today], reason: 'nothing before today is judged');
    });

    test('plans this week from today', () {
      progress().resetAll(_today);
      final plan = container.read(currentPlanProvider);
      expect(plan.days.first.date, _today);
      expect(plan.days.expand((d) => d.aliyot), [0, 1, 2, 3, 4, 5, 6]);
    });

    test('marks the reset for other devices only when asked to', () {
      progress().resetAll(_today);
      expect(container.read(progressProvider).resetAt, 0);

      progress().resetAll(_today, everywhere: true);
      expect(container.read(progressProvider).resetAt, greaterThan(0));
      expect(settings().joinDate, _today);
    });

    test('leaves the rest of the settings alone', () {
      container
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(readingSchedule: ReadingSchedule.israel, starterCatchUp: false));
      progress().resetAll(_today);
      expect(settings().readingSchedule, ReadingSchedule.israel);
      expect(settings().starterCatchUp, isFalse);
      expect(settings().onboardingComplete, isTrue);
    });
  });

  group('a reset arriving from another device', () {
    int at(int month, int day) => DateTime(2026, month, day, 9).millisecondsSinceEpoch;

    test('starts the reader afresh from the day of the reset', () async {
      progress().replaceAll(ProgressState(resetAt: at(10, 12)));
      expect(settings().joinDate, LocalDate(2026, 10, 12));
      expect((await savedSettings()).joinDate, LocalDate(2026, 10, 12));
      expect(summary().weeks, hasLength(1));
      expect(summary().weeks.single.status, WeekStatus.inProgress);
      expect(summary().days.keys.first, LocalDate(2026, 10, 12), reason: 'judged from the day of the reset');
    });

    test('never moves the join date back, nor past today', () {
      container.read(settingsProvider.notifier).update((s) => s.copyWith(joinDate: LocalDate(2026, 10, 13)));
      progress().replaceAll(ProgressState(resetAt: at(10, 12)));
      expect(settings().joinDate, LocalDate(2026, 10, 13), reason: 'joined after the reset');

      progress().replaceAll(ProgressState(resetAt: at(10, 20)));
      expect(settings().joinDate, _today, reason: 'a clock running ahead on the other device');
    });

    test('only a new reset moves the join date, not a merge or a restored backup', () {
      final before = container.read(progressProvider);
      progress().replaceAll(ProgressState(weeks: before.weeks, resetAt: before.resetAt));
      progress().restore(const ProgressState());
      expect(settings().joinDate, _joined);
    });
  });
}
