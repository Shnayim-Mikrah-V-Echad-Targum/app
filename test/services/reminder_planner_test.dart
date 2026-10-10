import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/hebrew_date.dart';
import 'package:shnayim_mikra/core/calendar/jewish_holidays.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/services/notifications.dart';
import 'package:shnayim_mikra/services/reminder_planner.dart';

void main() {
  const planner = ReadingPlanner(schedule: ParshaSchedule(israel: false));
  const all = ReminderPrefs(daily: true, dailyMinutes: 20 * 60, erevShabbat: true, erevShabbatMinutes: 10 * 60, checkIn: true);
  WeekProgress empty(String id) => WeekProgress(weekId: id);

  List<PlannedReminder> plan({
    ReminderPrefs prefs = all,
    DateTime? now,
    WeekProgress Function(String)? progressOf,
    List<Pause> pauses = const [],
    int days = 60,
  }) {
    final n = now ?? DateTime(2026, 10, 11, 8);
    return planReminders(
      prefs: prefs,
      planner: planner,
      progressOf: progressOf ?? empty,
      now: n,
      today: LocalDate.fromDateTime(n),
      pauses: pauses,
      days: days,
    );
  }

  test('never on Shabbat or Yom Tov, across two months including Sukkot-free and Chanukah weeks', () {
    final reminders = plan(days: 120);
    expect(reminders, isNotEmpty);
    for (final r in reminders) {
      expect(JewishHolidays.isRestDay(r.date, israel: false), isFalse, reason: '$r');
    }
  });

  test('nothing after midday on the eve of Shabbat or Yom Tov', () {
    for (final r in plan(days: 120)) {
      if (JewishHolidays.isRestDay(r.date.addDays(1), israel: false)) {
        expect(r.minutes, lessThan(kErevCutoffMinutes), reason: '$r');
      }
    }
  });

  test('at most one reminder per day, Erev Shabbat taking priority', () {
    final reminders = plan();
    final days = reminders.map((r) => r.date).toList();
    expect(days.toSet().length, days.length);
    final friday = reminders.firstWhere((r) => r.date == LocalDate(2026, 10, 16));
    expect(friday.kind, ReminderKind.erevShabbat);
    expect(friday.minutes, 10 * 60);
  });

  test('a day whose reading is done gets no daily reminder', () {
    final week = planner.schedule.weekFor(LocalDate(2026, 10, 12));
    final id = weekIdFor(week.portion, week.occasion);
    final done = WeekProgress(weekId: id).withAliyah(1, LocalDate(2026, 10, 11));
    final reminders = plan(progressOf: (w) => w == id ? done : empty(w));
    expect(reminders.where((r) => r.date == LocalDate(2026, 10, 12)), isEmpty);
    expect(reminders.where((r) => r.date == LocalDate(2026, 10, 13)), isNotEmpty);
  });

  test('times already past today are skipped', () {
    final reminders = plan(now: DateTime(2026, 10, 11, 21));
    expect(reminders.where((r) => r.date == LocalDate(2026, 10, 11)), isEmpty);
  });

  test('the after-Shabbat check-in lands on the first weekday after Shabbat', () {
    // Besides the final "reminders paused" message, which follows them all.
    final reminders = plan(prefs: const ReminderPrefs(checkIn: true));
    expect(reminders.last.kind, ReminderKind.paused);
    final checkIns = reminders.sublist(0, reminders.length - 1);
    expect(checkIns, isNotEmpty);
    expect(checkIns.every((r) => r.kind == ReminderKind.checkIn), isTrue);
    expect(checkIns.first.date.weekday, 0);
  });

  test('no reminders during a pause', () {
    final reminders = plan(pauses: [Pause(LocalDate(2026, 10, 11), LocalDate(2026, 10, 20))]);
    expect(reminders.where((r) => r.date <= LocalDate(2026, 10, 20)), isEmpty);
  });

  test('in the week of joining, daily reminders follow the starter plan', () {
    // Joined on Wednesday of Noach: the whole portion is spread over
    // Wednesday to Friday, and Friday's reminder is the Erev Shabbat one.
    final wed = LocalDate(2026, 10, 14);
    final now = DateTime(2026, 10, 14, 8);
    final reminders = planReminders(
      prefs: all,
      planner: ReadingPlanner(schedule: planner.schedule, starterFrom: wed),
      progressOf: empty,
      now: now,
      today: wed,
      days: 2,
    );
    expect([for (final r in reminders.where((r) => r.date <= wed.addDays(2))) (r.date, r.kind, r.aliyot.join(','))], [
      (wed, ReminderKind.daily, '0,1'),
      (wed.addDays(1), ReminderKind.daily, '2,3'),
      (wed.addDays(2), ReminderKind.erevShabbat, ''),
    ]);
  });

  group("Erev Tisha B'Av", () {
    // A week either side of the fast, with only the daily reminder on.
    List<PlannedReminder> around(LocalDate fast, int minutes) {
      final today = fast.addDays(-7);
      return planReminders(
        prefs: ReminderPrefs(daily: true, dailyMinutes: minutes),
        planner: planner,
        progressOf: empty,
        now: DateTime(today.year, today.month, today.day, 8),
        today: today,
      );
    }

    for (final year in [5786, 5787]) {
      test('$year: nothing from midday on the eve, while a morning reminder stays', () {
        final fast = HebrewDate(year, HebrewMonth.av, 9).toLocalDate();
        expect(JewishHolidays.isTishaBav(fast), isTrue);
        final eve = fast.addDays(-1);
        expect(planner.planFor(planner.schedule.weekFor(eve)).days.map((d) => d.date), contains(eve));

        expect(around(fast, 20 * 60).where((r) => r.date == eve), isEmpty);
        expect(around(fast, kErevCutoffMinutes).where((r) => r.date == eve), isEmpty);
        expect(around(fast, 9 * 60).where((r) => r.date == eve).single.kind, ReminderKind.daily);
        // The day before the eve keeps its evening reminder.
        expect(around(fast, 20 * 60).where((r) => r.date == eve.addDays(-1)), isNotEmpty);
      });
    }

    test('when the fast is postponed to Sunday, its eve is Shabbat and has no reminder', () {
      final ninth = HebrewDate(5789, HebrewMonth.av, 9).toLocalDate();
      expect(ninth.isShabbat, isTrue);
      expect(JewishHolidays.isTishaBav(ninth.addDays(1)), isTrue);
      for (final minutes in [9 * 60, 20 * 60]) {
        final reminders = around(ninth.addDays(1), minutes);
        expect(reminders.where((r) => r.date == ninth), isEmpty, reason: '$minutes');
        for (final r in reminders.where((r) => JewishHolidays.isTishaBav(r.date.addDays(1)))) {
          expect(r.minutes, lessThan(kErevCutoffMinutes), reason: '$r');
        }
      }
    });
  });

  group('the final "reminders paused" message', () {
    PlannedReminder pausedIn(List<PlannedReminder> reminders) =>
        reminders.singleWhere((r) => r.kind == ReminderKind.paused);

    test('comes once, at the daily time, after every other reminder and the horizon', () {
      final reminders = plan(days: 14);
      final paused = pausedIn(reminders);
      expect(reminders.last, same(paused));
      expect(paused.minutes, all.dailyMinutes);
      expect(paused.date > LocalDate(2026, 10, 25), isTrue);
      // Lech Lecha's Erev Shabbat and check-in fall just past the horizon; the
      // message comes the next day, Monday.
      final others = reminders.where((r) => r.kind != ReminderKind.paused).toList();
      expect([others[others.length - 2].kind, others.last.kind], [ReminderKind.erevShabbat, ReminderKind.checkIn]);
      expect(paused.date, others.last.date.addDays(1));
      expect(paused.date, LocalDate(2026, 11, 2));
      expect(paused.id, paused.date.rd * 10 + 3);
      expect(reminderRoute(paused), '/today');
    });

    test('names the portion of the week it was planned in', () {
      final week = planner.schedule.weekFor(LocalDate(2026, 10, 11));
      expect(pausedIn(plan(days: 14)).plan.weekId, weekIdFor(week.portion, week.occasion));
    });

    test('skips Shabbat', () {
      // Daily reminders alone end at the horizon, here a Friday.
      final reminders = plan(prefs: const ReminderPrefs(daily: true, dailyMinutes: 9 * 60), days: 12);
      expect(LocalDate(2026, 10, 23).weekday, 5);
      expect(pausedIn(reminders).date, LocalDate(2026, 10, 25));
    });

    test('skips the eve of Shabbat when the daily time is after midday', () {
      final reminders = plan(prefs: const ReminderPrefs(daily: true, dailyMinutes: 20 * 60), days: 11);
      expect(pausedIn(reminders).date, LocalDate(2026, 10, 25));
    });

    test('skips Yom Tov', () {
      // The horizon ends on Erev Pesach 5787, Wednesday 21 April 2027: the two
      // days of Yom Tov run into Shabbat, so the message waits for Sunday.
      final now = DateTime(2027, 4, 11, 8);
      final reminders = planReminders(
        prefs: const ReminderPrefs(daily: true),
        planner: planner,
        progressOf: empty,
        now: now,
        today: LocalDate.fromDateTime(now),
        days: 10,
      );
      expect(JewishHolidays.isRestDay(LocalDate(2027, 4, 22), israel: false), isTrue);
      expect(JewishHolidays.isRestDay(LocalDate(2027, 4, 23), israel: false), isTrue);
      expect(pausedIn(reminders).date, LocalDate(2027, 4, 25));
    });

    test('waits for a pause to end', () {
      final reminders = plan(days: 14, pauses: [Pause(LocalDate(2026, 10, 20), LocalDate(2026, 11, 10))]);
      expect(pausedIn(reminders).date, LocalDate(2026, 11, 11));
    });

    test('is not sent when every reminder is off', () {
      expect(plan(prefs: const ReminderPrefs()), isEmpty);
    });

    const onlyOne = {
      'daily': ReminderPrefs(daily: true),
      'Erev Shabbat': ReminderPrefs(erevShabbat: true),
      'check-in': ReminderPrefs(checkIn: true),
    };
    for (final MapEntry(key: name, value: prefs) in onlyOne.entries) {
      test('is sent when only the $name reminder is on', () {
        expect(plan(prefs: prefs).where((r) => r.kind == ReminderKind.paused), hasLength(1));
      });
    }
  });

  group('hearing the reading in Israel but keeping two days of Yom Tov', () {
    const israel = ParshaSchedule(israel: true);
    const visitor = ReadingPlanner(schedule: israel, oneDayYomTov: false);
    const resident = ReadingPlanner(schedule: israel);

    List<PlannedReminder> remind(ReadingPlanner planner, DateTime now) => planReminders(
          prefs: all,
          planner: planner,
          progressOf: empty,
          now: now,
          today: LocalDate.fromDateTime(now),
          days: 21,
        );
    List<LocalDate> planned(ReadingPlanner planner, LocalDate day) =>
        [for (final p in planner.planFor(israel.weekFor(day)).days) p.date];

    test('no plan day and no reminder on 22 Nisan when Acharon shel Pesach falls on Shabbat outside Israel', () {
      // Pesach 5789 begins and ends on Shabbat outside Israel. Israel reads
      // Shemini on 22 Nisan, so its week runs through Chol HaMoed, from the
      // second day of Yom Tov, 16 Nisan.
      final secondDay = LocalDate(2029, 4, 1);
      final acharon = LocalDate(2029, 4, 7);
      expect((HebrewDate.fromLocalDate(secondDay).day, HebrewDate.fromLocalDate(acharon).day), (16, 22));
      expect(israel.weekFor(secondDay).occasion, acharon);

      expect(planned(visitor, secondDay), isNot(anyOf(contains(secondDay), contains(acharon))));
      final reminders = remind(visitor, DateTime(2029, 3, 26, 8));
      expect(reminders.where((r) => r.date == secondDay || r.date == acharon), isEmpty);
      for (final r in reminders) {
        expect(JewishHolidays.isRestDay(r.date, israel: false), isFalse, reason: '$r');
      }

      // In Israel, 16 Nisan is Chol HaMoed.
      expect(planned(resident, secondDay), contains(secondDay));
      expect(remind(resident, DateTime(2029, 3, 26, 8)).where((r) => r.date == secondDay), isNotEmpty);
    });

    test('no plan day and no reminder on 22 Nisan when it falls on a weekday', () {
      final acharon = LocalDate(2027, 4, 29); // Thursday
      expect(planned(visitor, acharon), isNot(contains(acharon)));
      expect(remind(visitor, DateTime(2027, 4, 18, 8)).where((r) => r.date == acharon), isEmpty);

      expect(planned(resident, acharon), contains(acharon));
      expect(remind(resident, DateTime(2027, 4, 18, 8)).where((r) => r.date == acharon), isNotEmpty);
    });
  });

  test('Erev Shabbat opens the week within Today; the daily reading and the check-in open Today', () {
    final reminders = plan();
    for (final kind in ReminderKind.values) {
      expect(reminders.where((r) => r.kind == kind), isNotEmpty, reason: '$kind');
    }
    for (final r in reminders) {
      expect(reminderRoute(r), r.kind == ReminderKind.erevShabbat ? '/today/week/${r.plan.weekId}' : '/today', reason: '$r');
    }
  });

  test('ids are unique', () {
    final ids = plan(days: 120).map((r) => r.id).toList();
    expect(ids.toSet().length, ids.length);
  });
}
