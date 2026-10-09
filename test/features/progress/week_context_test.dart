import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/data/parsha_repository.dart';
import 'package:shnayim_mikra/features/parsha/week_context.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

class _FixedToday extends TodayController {
  _FixedToday(this.day);
  final LocalDate day;

  @override
  LocalDate build() => day;
}

/// Bereshit 5787 in the Diaspora: Simchat Torah was Sunday 4 October, so
/// its week runs from Monday 5 to Friday 9 October, read on Shabbat 10th.
const _bereshit = '5787:1';
final _mon = LocalDate(2026, 10, 5);
final _fri = LocalDate(2026, 10, 9);

/// Rishon on Monday and Sheni on Tuesday, both read three times; Shlishi
/// read twice on Wednesday, its Targum still to come.
WeekProgress _bereshitProgress() {
  var w = WeekProgress(weekId: _bereshit);
  for (final p in ReadingPass.values) {
    w = w.withUnit(0, p, _mon).withUnit(1, p, _mon.addDays(1));
  }
  return w.withUnit(2, ReadingPass.mikra1, _mon.addDays(2)).withUnit(2, ReadingPass.mikra2, _mon.addDays(2));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ParshaRepository repo;
  setUpAll(() async => repo = await ParshaRepository.load());

  Future<ProviderContainer> containerFor({
    required LocalDate today,
    required AppSettings settings,
    ProgressState progress = const ProgressState(),
  }) async {
    SharedPreferences.setMockInitialValues({
      SettingsController.storageKey: jsonEncode(settings.toJson()),
      ProgressController.storageKey: jsonEncode(progress.toJson()),
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      parshaRepositoryProvider.overrideWithValue(repo),
      todayProvider.overrideWith(() => _FixedToday(today)),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  group('on the Friday of Bereshit', () {
    late ProviderContainer container;
    setUp(() async {
      container = await containerFor(
        today: _fri,
        settings: AppSettings(onboardingComplete: true, joinDate: LocalDate(2026, 10, 4)),
        progress: ProgressState(weeks: {_bereshit: _bereshitProgress()}),
      );
    });
    WeekContext ctx() => container.read(currentWeekContextProvider);

    test('everything unread is due, and three aliyot are behind', () {
      expect(ctx().id, _bereshit);
      expect(ctx().dueAliyot(), [2, 3, 4, 5, 6]);
      expect(ctx().behindBy(), 3, reason: 'Shlishi, Revi\'i and Chamishi were planned before today');
    });

    test('estimates the time left from the readings not yet done', () {
      final c = ctx();
      expect(c.aliyahVerses, [for (var a = 0; a < kAliyot; a++) repo.aliyahVerseCount(c.portion, a)]);
      // Shlishi's Targum (a third of its 27 verses' time), then Revi'i to
      // Shevi'i in full: 78 verses' worth at 25 seconds, 32½ minutes.
      expect(c.aliyahVerses.sublist(2), [27, 21, 4, 28, 16]);
      expect(c.remainingMinutes(c.dueAliyot()), 33);
      expect(c.remainingMinutes([2]), 4, reason: '27 × 25 s / 3 = 3 min 45 s, rounded up');
      expect(c.remainingMinutes([5]), 12, reason: '28 × 25 s = 11 min 40 s, rounded up');
      expect(c.remainingMinutes([6]), 7, reason: '16 × 25 s = 6 min 40 s, rounded up');
      expect(c.remainingMinutes([0, 1]), 0, reason: 'already read');
      expect(c.remainingMinutes(const []), 0);
    });

    test('marking the due aliyot read is one change, and leaves nothing due', () {
      final due = ctx().dueAliyot();
      var changes = 0;
      container.listen(progressProvider, (_, _) => changes++);

      container.read(progressProvider.notifier).markAliyot(_bereshit, due, _fri);

      expect(changes, 1);
      expect(ctx().dueAliyot(), isEmpty);
      expect(ctx().behindBy(), 0);
      final week = container.read(progressProvider).week(_bereshit);
      expect(week.isComplete, isTrue);
      expect(week.units[2], [_mon.addDays(2), _mon.addDays(2), _fri], reason: 'readings already done keep their day');
      expect(week.units[0], [_mon, _mon, _mon]);
    });

    test('marking aliyot already read changes nothing', () {
      var changes = 0;
      container.listen(progressProvider, (_, _) => changes++);
      container.read(progressProvider.notifier).markAliyot(_bereshit, const [0, 1], _fri);
      expect(changes, 0);
    });
  });

  group('joining on Wednesday of Bereshit', () {
    final wed = LocalDate(2026, 10, 7);
    final thu = LocalDate(2026, 10, 8);

    test('everything planned since joining is due, from the starter plan', () async {
      final c = await containerFor(today: thu, settings: AppSettings(joinDate: wed));
      final ctx = c.read(currentWeekContextProvider);
      expect(ctx.plan.days.map((d) => d.aliyot), [[0, 1], [2, 3], [4, 5, 6]]);
      expect(ctx.dueAliyot(), [0, 1, 2, 3]);
      expect(ctx.behindBy(), 2);
    });

    test('without the starter plan, nothing planned before joining is due', () async {
      final c = await containerFor(today: thu, settings: AppSettings(joinDate: wed, starterCatchUp: false));
      final ctx = c.read(currentWeekContextProvider);
      expect(ctx.plan.days.first.date, _mon);
      expect(ctx.dueAliyot(), [2, 3, 4]);
      expect(ctx.behindBy(), 1);
    });
  });

  test('Shevi\'i planned for Shabbat morning is due once Shabbat has passed', () async {
    var bereshit = WeekProgress(weekId: _bereshit);
    for (var a = 0; a < 6; a++) {
      bereshit = bereshit.withAliyah(a, _mon);
    }
    final c = await containerFor(
      today: LocalDate(2026, 10, 11),
      settings: AppSettings(joinDate: LocalDate(2026, 10, 4), plan: ReadingPlanType.sheviiOnShabbat),
      progress: ProgressState(weeks: {_bereshit: bereshit}),
    );
    final previous = c.read(weekContextProvider(_bereshit))!;
    expect(previous.plan.shabbatAliyot, [6]);
    expect(previous.dueAliyot(), [6]);
    expect(previous.behindBy(), 1);
    final current = c.read(currentWeekContextProvider);
    expect(current.dueAliyot(), [0], reason: 'Noach\'s Rishon, today');
    expect(current.behindBy(), 0);
  });
}
