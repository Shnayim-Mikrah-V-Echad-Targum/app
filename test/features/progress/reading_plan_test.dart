import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/features/progress/domain/streak_engine.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

const diaspora = ParshaSchedule(israel: false);

LocalDate d(String iso) => LocalDate.parse(iso);

/// Each planned day as "date [aliyot]", e.g. "2026-10-14 [0, 1]".
List<String> daysOf(WeekPlan plan) => [for (final p in plan.days) '${p.date} ${p.aliyot}'];

void main() {
  const usual = ReadingPlanner(schedule: diaspora);
  ReadingPlanner joinedOn(String date, {ReadingPlanType type = ReadingPlanType.aliyahPerDay}) =>
      ReadingPlanner(schedule: diaspora, type: type, starterFrom: d(date));

  // Noach 5787: Sunday 11 Oct – Friday 16 Oct 2026, read Shabbat 17 Oct.
  final noach = diaspora.weekFor(d('2026-10-12'));
  final lechLecha = diaspora.weekFor(d('2026-10-19'));

  group('the week of joining', () {
    test('joining on Wednesday spreads Rishon to Shevi\'i over Wednesday to Friday', () {
      expect(daysOf(joinedOn('2026-10-14').planFor(noach)), [
        '2026-10-14 [0, 1]',
        '2026-10-15 [2, 3]',
        '2026-10-16 [4, 5, 6]',
      ]);
    });

    test('joining on Friday leaves the whole portion for Friday', () {
      expect(daysOf(joinedOn('2026-10-16').planFor(noach)), [
        '2026-10-16 [0, 1, 2, 3, 4, 5, 6]',
      ]);
    });

    test('Shevi\'i on Shabbat still keeps the seventh aliyah for Shabbat morning', () {
      final plan = joinedOn('2026-10-14', type: ReadingPlanType.sheviiOnShabbat).planFor(noach);
      expect(daysOf(plan), [
        '2026-10-14 [0, 1]',
        '2026-10-15 [2, 3]',
        '2026-10-16 [4, 5]',
      ]);
      expect(plan.shabbatAliyot, [6]);
    });

    test('Erev Shabbat is unchanged', () {
      final plan = joinedOn('2026-10-14', type: ReadingPlanType.erevShabbat).planFor(noach);
      expect(daysOf(plan), [
        '2026-10-16 [0, 1, 2, 3, 4, 5, 6]',
      ]);
    });

    test('joining on the first reading day, or in an earlier week, keeps the usual plan', () {
      expect(daysOf(joinedOn('2026-10-11').planFor(noach)), daysOf(usual.planFor(noach)));
      expect(daysOf(joinedOn('2026-10-14').planFor(lechLecha)), daysOf(usual.planFor(lechLecha)));
      expect(daysOf(usual.planFor(lechLecha)).first, '2026-10-18 [0]');
    });

    test('with no reading day left before the portion is read, the usual days are planned', () {
      expect(daysOf(joinedOn('2026-10-17').planFor(noach)), daysOf(usual.planFor(noach)));
    });

    test('joining on Simchat Torah leaves Bereshit, and Vezot HaBerakhah, as usual', () {
      // 4 Oct 2026 is Simchat Torah in the Diaspora, so Bereshit's week
      // begins the next day.
      final bereshit = diaspora.weekFor(d('2026-10-09'));
      expect(bereshit.start, d('2026-10-05'));
      expect(daysOf(joinedOn('2026-10-04').planFor(bereshit)), [
        '2026-10-05 [0]',
        '2026-10-06 [1]',
        '2026-10-07 [2]',
        '2026-10-08 [3, 4]',
        '2026-10-09 [5, 6]',
      ]);
      final vezot = diaspora.weekFor(d('2026-10-04'));
      expect(vezot.portion.isVezotHaberakhah, isTrue);
      expect(daysOf(joinedOn('2026-10-04').planFor(vezot)), daysOf(usual.planFor(vezot)));
    });
  });

  group('judging the first days', () {
    final id = weekIdFor(noach.portion, noach.occasion);
    Map<String, WeekProgress> read(Map<int, String> aliyot) => {
          id: aliyot.entries.fold(WeekProgress(weekId: id), (w, e) => w.withAliyah(e.key, d(e.value))),
        };

    test('without the starter plan, the usual plan stands and what fell before joining is not expected', () {
      expect(daysOf(usual.planFor(noach)), [
        '2026-10-11 [0]',
        '2026-10-12 [1]',
        '2026-10-13 [2]',
        '2026-10-14 [3]',
        '2026-10-15 [4]',
        '2026-10-16 [5, 6]',
      ]);
      // Wednesday's and Thursday's aliyot, read on Thursday, catch Wednesday
      // up: Rishon to Shlishi are not owed.
      final s = const StreakEngine(planner: usual).evaluate(
        progress: read({3: '2026-10-15', 4: '2026-10-15'}),
        joinDate: d('2026-10-14'),
        today: d('2026-10-16'),
      );
      expect(s.days.keys, [d('2026-10-14'), d('2026-10-15'), d('2026-10-16')]);
      expect(s.days[d('2026-10-14')], DayStatus.caughtUp);
      expect(s.graceBalance, GraceRules.startingBalance);
    });

    test('with it, the days after joining are judged by the starter plan', () {
      // Rishon and Sheni on Wednesday, then nothing on Thursday.
      final s = StreakEngine(planner: joinedOn('2026-10-14')).evaluate(
        progress: read({0: '2026-10-14', 1: '2026-10-14'}),
        joinDate: d('2026-10-14'),
        today: d('2026-10-16'),
      );
      expect(s.days[d('2026-10-14')], DayStatus.kept);
      expect(s.days[d('2026-10-15')], DayStatus.open,
          reason: 'Shlishi and Revi\'i were planned for Thursday, and Friday can still catch up');
    });
  });

  group('plannerProvider', () {
    Future<ReadingPlanner> plannerFor(AppSettings settings) async {
      SharedPreferences.setMockInitialValues({SettingsController.storageKey: jsonEncode(settings.toJson())});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(container.dispose);
      return container.read(plannerProvider);
    }

    test('plans the week of joining from the join date by default', () async {
      final planner = await plannerFor(AppSettings(joinDate: d('2026-10-14')));
      expect(planner.starterFrom, d('2026-10-14'));
      expect(planner.planFor(noach).days.first.date, d('2026-10-14'));
    });

    test('keeps the usual plan when the starter plan is off', () async {
      final planner = await plannerFor(AppSettings(joinDate: d('2026-10-14'), starterCatchUp: false));
      expect(planner.starterFrom, isNull);
      expect(daysOf(planner.planFor(noach)), daysOf(usual.planFor(noach)));
    });
  });
}
