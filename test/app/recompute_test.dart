import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/data/models/parsha.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/features/progress/domain/streak_engine.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../helpers.dart';

/// How many times the streaks have been evaluated, every week since joining.
var _evaluations = 0;

class _CountingEngine extends StreakEngine {
  const _CountingEngine({required super.planner});

  @override
  StreakSummary evaluate({
    required Map<String, WeekProgress> progress,
    required LocalDate joinDate,
    required LocalDate today,
    List<Pause> pauses = const [],
  }) {
    _evaluations++;
    return super.evaluate(progress: progress, joinDate: joinDate, today: today, pauses: pauses);
  }
}

final _countEvaluations = streakEngineProvider.overrideWith((ref) => _CountingEngine(planner: ref.watch(plannerProvider)));

/// Monday of Noach 5787.
final _monday = LocalDate(2026, 10, 12);
final _joined = LocalDate(2026, 7, 14);

class _Monday extends TodayController {
  @override
  LocalDate build() => _monday;
}

void main() {
  setUp(() => _evaluations = 0);

  group('the reading log revision', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(container.dispose);
    });

    ProgressController progress() => container.read(progressProvider.notifier);
    int revision() => container.read(progressProvider).logRevision;

    test('changes with what was read or paused, not with a saved place', () {
      final start = revision();
      progress().savePosition('5787:2', 0, const [3, 2, 0]);
      expect(revision(), start, reason: 'a place is not part of the log');
      expect(container.read(progressProvider).week('5787:2').positions[0], [3, 2, 0]);

      progress().markUnit('5787:2', 0, ReadingPass.mikra1, _monday);
      final marked = revision();
      expect(marked, isNot(start));
      progress().addPause(_monday, _monday);
      expect(revision(), isNot(marked));
    });

    test('is neither compared nor stored', () {
      final week = WeekProgress(weekId: '5787:2').withAliyah(0, _monday);
      final a = ProgressState(weeks: {week.weekId: week}, logRevision: 1);
      final b = ProgressState(weeks: {week.weekId: week}, logRevision: 2);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toJson(), isNot(contains('logRevision')));
      expect(jsonEncode(a.toJson()), jsonEncode(b.toJson()));
    });

    test('listeners hear a saved place, though the log has not changed', () {
      var heard = 0;
      container.listen(progressProvider, (_, _) => heard++);
      progress().savePosition('5787:2', 0, const [1, 1, 0]);
      expect(heard, 1);
    });
  });

  group('the streaks are evaluated again', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        SettingsController.storageKey: jsonEncode(AppSettings(onboardingComplete: true, joinDate: _joined).toJson()),
      });
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        todayProvider.overrideWith(_Monday.new),
        _countEvaluations,
      ]);
      addTearDown(container.dispose);
      container.listen(streakSummaryProvider, (_, _) {});
      expect(_evaluations, 1);
    });

    void change(AppSettings Function(AppSettings s) settings) =>
        container.read(settingsProvider.notifier).update(settings);

    test('when the reading log changes, not as the reader saves a place', () {
      final progress = container.read(progressProvider.notifier);
      for (var verse = 1; verse <= 5; verse++) {
        progress.savePosition('5787:2', 0, [verse, verse, verse]);
        container.read(streakSummaryProvider);
      }
      expect(_evaluations, 1);

      progress.markUnit('5787:2', 0, ReadingPass.mikra1, _monday);
      container.read(streakSummaryProvider);
      expect(_evaluations, 2);
    });

    test('when a setting that plans or judges weeks changes, and only then', () {
      change((s) => s.copyWith(theme: AppThemeMode.dark));
      change((s) => s.copyWith(showTranslation: true, readingScale: 1.3, uiFont: UiFont.lexend));
      change((s) => s.copyWith(dailyReminder: true, nusach: HaftarahNusach.sephardi));
      container.read(streakSummaryProvider);
      expect(_evaluations, 1);

      for (final (i, settings) in <AppSettings Function(AppSettings)>[
        (s) => s.copyWith(lateWindow: LateWindow.wednesday),
        (s) => s.copyWith(plan: ReadingPlanType.erevShabbat),
        (s) => s.copyWith(haftarahRequired: true),
        (s) => s.copyWith(starterCatchUp: false),
        (s) => s.copyWith(joinDate: _joined.addDays(7)),
      ].indexed) {
        change(settings);
        container.read(streakSummaryProvider);
        expect(_evaluations, i + 2);
      }
    });
  });

  testWidgets('stepping through the reader evaluates no streaks until an aliyah is read', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(
      tester,
      settings: AppSettings(onboardingComplete: true, joinDate: _joined),
      now: DateTime(2026, 10, 12, 10),
      overrides: [_countEvaluations],
    );
    c.read(routerProvider).go('/read/5787:2/0');
    await tester.pump();
    for (var i = 0; i < 20 && find.text('Next').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    final before = _evaluations;
    for (var step = 0; step < 6; step++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(c.read(progressProvider).week('5787:2').positions[0], [2, 2, 2]);
    expect(_evaluations, before);

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark this aliyah as read'));
    await tester.pumpAndSettle();
    expect(_evaluations, greaterThan(before));
  });

  testWidgets('the app keeps its themes through settings it is not built from', (tester) async {
    final c = await pumpApp(tester);
    ThemeData theme() => tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!;
    final before = theme();

    c.read(settingsProvider.notifier).update((s) => s.copyWith(showTranslation: true, readingScale: 1.3));
    await tester.pumpAndSettle();
    expect(identical(theme(), before), isTrue);

    c.read(settingsProvider.notifier).update((s) => s.copyWith(theme: AppThemeMode.sepia));
    await tester.pumpAndSettle();
    expect(identical(theme(), before), isFalse);
  });
}
