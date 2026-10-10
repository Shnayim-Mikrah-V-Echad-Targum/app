import 'dart:convert';

import 'package:flutter/material.dart';
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

import '../../helpers.dart';

const diaspora = ParshaSchedule(israel: false);

LocalDate d(String iso) => LocalDate.parse(iso);

/// Each planned day as "date [aliyot]", e.g. "2026-10-14 [0, 1]".
List<String> daysOf(WeekPlan plan) => [for (final p in plan.days) '${p.date} ${p.aliyot}'];

/// The plan settings in force on each day, from [entries] (oldest first).
PlanSettingsEntry Function(LocalDate) settingsChanging(List<PlanSettingsEntry> entries) =>
    (day) => entries.lastWhere((e) => e.from <= day, orElse: () => entries.first);

void main() {
  const usual = ReadingPlanner(schedule: diaspora);
  ReadingPlanner joinedOn(String date, {ReadingPlanType type = ReadingPlanType.aliyahPerDay}) =>
      ReadingPlanner(schedule: diaspora, settingsAt: (_) => PlanSettingsEntry(plan: type), starterFrom: d(date));

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

    test('startingFrom plans the week of joining from another day, by the same calendar and settings', () {
      final planner = ReadingPlanner(
        schedule: diaspora,
        oneDayYomTov: true,
        settingsAt: (_) => const PlanSettingsEntry(plan: ReadingPlanType.sheviiOnShabbat),
        starterFrom: d('2026-10-14'),
      );
      final fromFriday = planner.startingFrom(d('2026-10-16'));
      expect(fromFriday.starterFrom, d('2026-10-16'));
      expect(fromFriday.schedule, same(diaspora));
      expect(fromFriday.oneDayYomTov, isTrue);
      final plan = fromFriday.planFor(noach);
      expect(daysOf(plan), ['2026-10-16 [0, 1, 2, 3, 4, 5]']);
      expect(plan.shabbatAliyot, [6]);

      final asUsual = planner.startingFrom(null);
      expect(asUsual.starterFrom, isNull);
      expect(daysOf(asUsual.planFor(noach)).first, '2026-10-11 [0]');
    });

    test('with no reading day left before the portion is read, the usual days are planned', () {
      expect(daysOf(joinedOn('2026-10-17').planFor(noach)), daysOf(usual.planFor(noach)));
    });

    test('joining on Simchat Torah leaves Bereshit, and Vezot HaBerachah, as usual', () {
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

  group('a change of settings', () {
    final wed = d('2026-10-14');
    final thu = d('2026-10-15');
    final fri = d('2026-10-16');
    ReadingPlanner changing(List<PlanSettingsEntry> entries, {LocalDate? starterFrom}) =>
        ReadingPlanner(schedule: diaspora, settingsAt: settingsChanging(entries), starterFrom: starterFrom);

    test('to All on Friday midweek keeps the days already planned, and leaves the rest for Friday', () {
      final p = changing([const PlanSettingsEntry(), PlanSettingsEntry(from: wed, plan: ReadingPlanType.erevShabbat)]);
      expect(daysOf(p.planFor(noach)), [
        '2026-10-11 [0]',
        '2026-10-12 [1]',
        '2026-10-13 [2]',
        '2026-10-16 [3, 4, 5, 6]',
      ]);
    });

    test('from All on Friday midweek spreads the portion over the days left', () {
      final p = changing([
        const PlanSettingsEntry(plan: ReadingPlanType.erevShabbat),
        PlanSettingsEntry(from: wed, plan: ReadingPlanType.aliyahPerDay),
      ]);
      expect(daysOf(p.planFor(noach)), [
        '2026-10-14 [0, 1]',
        '2026-10-15 [2, 3]',
        '2026-10-16 [4, 5, 6]',
      ]);
    });

    test('to or from Shevi\'i on Shabbat moves the seventh aliyah', () {
      var plan = changing([
        const PlanSettingsEntry(),
        PlanSettingsEntry(from: thu, plan: ReadingPlanType.sheviiOnShabbat),
      ]).planFor(noach);
      expect(daysOf(plan).sublist(4), ['2026-10-15 [4]', '2026-10-16 [5]']);
      expect(plan.shabbatAliyot, [6]);

      plan = changing([
        const PlanSettingsEntry(plan: ReadingPlanType.sheviiOnShabbat),
        PlanSettingsEntry(from: fri, plan: ReadingPlanType.aliyahPerDay),
      ]).planFor(noach);
      expect(daysOf(plan).sublist(4), ['2026-10-15 [4]', '2026-10-16 [5, 6]']);
      expect(plan.shabbatAliyot, isEmpty);
    });

    test('plans the weeks before it by the old settings and the weeks after by the new', () {
      final p = changing([
        const PlanSettingsEntry(plan: ReadingPlanType.erevShabbat),
        PlanSettingsEntry(from: wed, plan: ReadingPlanType.aliyahPerDay),
      ]);
      expect(daysOf(p.planFor(diaspora.previousWeek(noach))), ['2026-10-09 [0, 1, 2, 3, 4, 5, 6]']);
      expect(daysOf(p.planFor(lechLecha)), daysOf(usual.planFor(lechLecha)));
    });

    test('made before the first planned day plans the whole week by the new settings', () {
      final p = changing([
        const PlanSettingsEntry(),
        PlanSettingsEntry(from: noach.start.addDays(-1), plan: ReadingPlanType.erevShabbat),
      ]);
      expect(daysOf(p.planFor(noach)), ['2026-10-16 [0, 1, 2, 3, 4, 5, 6]']);
    });

    test('back to the same settings changes nothing', () {
      final p = changing([const PlanSettingsEntry(), PlanSettingsEntry(from: wed)]);
      expect(daysOf(p.planFor(noach)), daysOf(usual.planFor(noach)));
    });

    test('in the week of joining, keeps what the starter plan gave the days before', () {
      final p = changing(
        [const PlanSettingsEntry(), PlanSettingsEntry(from: thu, plan: ReadingPlanType.erevShabbat)],
        starterFrom: wed,
      );
      expect(daysOf(p.planFor(noach)), ['2026-10-14 [0, 1]', '2026-10-16 [2, 3, 4, 5, 6]']);
    });

    test('quiet days follow the settings in force on the day', () {
      // Tisha B'Av 5787 is Thursday 12 August 2027; it stops being a quiet
      // day on Tuesday.
      final week = diaspora.weekFor(d('2027-08-10'));
      final p = changing([const PlanSettingsEntry(), PlanSettingsEntry(from: d('2027-08-10'), tishaBavQuiet: false)]);
      expect(daysOf(usual.planFor(week)), [
        '2027-08-08 [0]',
        '2027-08-09 [1]',
        '2027-08-10 [2]',
        '2027-08-11 [3, 4]',
        '2027-08-13 [5, 6]',
      ]);
      expect(daysOf(p.planFor(week)), [
        '2027-08-08 [0]',
        '2027-08-09 [1]',
        '2027-08-10 [2]',
        '2027-08-11 [3]',
        '2027-08-12 [4]',
        '2027-08-13 [5, 6]',
      ]);
      final tishaBav5786 = d('2026-07-23');
      expect(
        [for (final day in p.planFor(diaspora.weekFor(tishaBav5786)).days) day.date],
        isNot(contains(tishaBav5786)),
        reason: 'Tisha B\'Av 5786, before the change, is still quiet',
      );
    });
  });

  group('the days of Yom Tov', () {
    // Pesach 5787: Acharon shel Pesach, 22 Nisan, is Thursday 29 April 2027,
    // a Yom Tov only outside Israel. Acharei Mot is read on Shabbat 1 May.
    const israel = ParshaSchedule(israel: true);
    final acharon = d('2027-04-29');
    List<String> datesOf(ReadingPlanner p) => [for (final day in p.planFor(p.schedule.weekFor(acharon)).days) '${day.date}'];

    test('follow the reading schedule by default', () {
      expect(const ReadingPlanner(schedule: israel).oneDayYomTov, isTrue);
      expect(usual.oneDayYomTov, isFalse);
      expect(datesOf(const ReadingPlanner(schedule: israel)), contains('$acharon'));
      expect(datesOf(usual), isNot(contains('$acharon')));
    });

    test('a visitor to Israel reads Israel\'s portion, with nothing planned on the second day of Yom Tov', () {
      const visitor = ReadingPlanner(schedule: israel, oneDayYomTov: false);
      expect(visitor.planFor(israel.weekFor(acharon)).portion, israel.weekFor(acharon).portion);
      expect(datesOf(visitor), ['2027-04-25', '2027-04-26', '2027-04-27', '2027-04-30']);
    });

    test('an Israeli abroad reads the Diaspora\'s portion, with reading planned on the day after Pesach in Israel', () {
      const abroad = ReadingPlanner(schedule: diaspora, oneDayYomTov: true);
      expect(datesOf(abroad), ['2027-04-25', '2027-04-26', '2027-04-27', '2027-04-29', '2027-04-30']);
      expect(datesOf(abroad), isNot(contains('2027-04-28')), reason: 'the seventh day is Yom Tov everywhere');
    });
  });

  group('effectiveReadingDay', () {
    // Pesach 5789: 15 Nisan is Shabbat 31 March 2029; 16 Nisan, Sunday
    // 1 April, is Yom Tov only for those who keep two days.
    test("rolls a visitor's second day of Yom Tov over to the next day", () {
      expect(effectiveReadingDay(DateTime(2029, 4, 1, 10), oneDayYomTov: false), d('2029-04-02'));
      expect(effectiveReadingDay(DateTime(2029, 4, 1, 10), oneDayYomTov: true), d('2029-04-01'));
    });

    test('rolls over at 3 a.m., and past every day of Yom Tov after Shabbat', () {
      expect(effectiveReadingDay(DateTime(2029, 4, 2, 2), oneDayYomTov: true), d('2029-04-01'));
      expect(effectiveReadingDay(DateTime(2029, 4, 2, 2), oneDayYomTov: false), d('2029-04-02'));
      expect(effectiveReadingDay(DateTime(2029, 3, 31, 22), oneDayYomTov: false), d('2029-04-02'));
      expect(effectiveReadingDay(DateTime(2029, 3, 31, 22), oneDayYomTov: true), d('2029-04-01'));
    });
  });

  group('for a visitor to Israel, who keeps two days of Yom Tov,', () {
    testWidgets('the week strip shows the second day of Yom Tov as a rest day', (tester) async {
      // Acharon shel Pesach 5787, 22 Nisan: Thursday 29 April 2027.
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final visitor = AppSettings(
        onboardingComplete: true,
        joinDate: d('2027-04-25'),
        readingSchedule: ReadingSchedule.israel,
        oneDayYomTov: false,
      );
      await pumpApp(tester, settings: visitor, now: DateTime(2027, 4, 27, 10));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Thursday: Shabbat or Yom Tov'), findsOneWidget);

      await pumpApp(tester, settings: visitor.copyWith(oneDayYomTov: true), now: DateTime(2027, 4, 27, 10));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Thursday: Shabbat or Yom Tov'), findsNothing);
      expect(find.byTooltip(RegExp('^Thursday: ')), findsOneWidget, reason: 'a reading day in Israel');
    });

    testWidgets('the check-in after Shabbat comes on the first day they read', (tester) async {
      // Shavuot 5789 is Sunday and Monday, 20 and 21 May 2029, after
      // Bamidbar was read on Shabbat; Israel keeps only the Sunday.
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const checkIn = 'Shavua tov! Did you read on Shabbat?';
      final visitor = AppSettings(
        onboardingComplete: true,
        joinDate: d('2029-05-01'),
        readingSchedule: ReadingSchedule.israel,
        oneDayYomTov: false,
      );
      await pumpApp(tester, settings: visitor, now: DateTime(2029, 5, 22, 10));
      await tester.pumpAndSettle();
      expect(find.text(checkIn), findsOneWidget, reason: 'Tuesday is their first reading day after Shabbat');

      await pumpApp(tester, settings: visitor.copyWith(oneDayYomTov: true), now: DateTime(2029, 5, 22, 10));
      await tester.pumpAndSettle();
      expect(find.text(checkIn), findsNothing, reason: 'in Israel, that was Monday');
      expect(find.text('Bamidbar is still open'), findsOneWidget);
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

    test('follows the reading schedule and keeps the days of Yom Tov set apart from it', () async {
      final planner = await plannerFor(
        const AppSettings(readingSchedule: ReadingSchedule.israel, oneDayYomTov: false),
      );
      expect(planner.schedule.israel, isTrue);
      expect(planner.oneDayYomTov, isFalse);
    });

    test('keeps the usual plan when the starter plan is off', () async {
      final planner = await plannerFor(AppSettings(joinDate: d('2026-10-14'), starterCatchUp: false));
      expect(planner.starterFrom, isNull);
      expect(daysOf(planner.planFor(noach)), daysOf(usual.planFor(noach)));
    });

    test('plans each week by the settings in force at the time', () async {
      final before = AppSettings(joinDate: d('2026-09-01'), plan: ReadingPlanType.erevShabbat);
      final after = before.copyWith(plan: ReadingPlanType.aliyahPerDay).recordingPlanChange(before, d('2026-10-14'));
      final planner = await plannerFor(after);
      expect(daysOf(planner.planFor(diaspora.previousWeek(noach))), ['2026-10-09 [0, 1, 2, 3, 4, 5, 6]']);
      expect(daysOf(planner.planFor(noach)).first, '2026-10-14 [0, 1]');
      expect(daysOf(planner.planFor(lechLecha)), daysOf(usual.planFor(lechLecha)));
    });
  });
}
