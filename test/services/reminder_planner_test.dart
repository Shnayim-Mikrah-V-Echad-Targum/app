import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/city.dart';
import 'package:shnayim_mikra/core/calendar/hebrew_date.dart';
import 'package:shnayim_mikra/core/calendar/jewish_holidays.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/core/calendar/zmanim.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/services/notifications.dart';
import 'package:shnayim_mikra/services/reminder_planner.dart';
import 'package:timezone/timezone.dart' as tz;

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
      final fast = ninth.addDays(1);
      expect(ninth.isShabbat, isTrue);
      expect(JewishHolidays.isTishaBav(ninth), isFalse, reason: 'the fast is postponed');
      expect(JewishHolidays.isTishaBav(fast), isTrue);
      for (final minutes in [9 * 60, 20 * 60]) {
        expect(around(fast, minutes).where((r) => r.date == ninth), isEmpty, reason: '$minutes');
      }
      // Friday, 8 Av, is not the eve of the fast: its morning reminder
      // stays, and only Shabbat's rule takes its evening one.
      final friday = ninth.addDays(-1);
      expect(planner.planFor(planner.schedule.weekFor(friday)).days.map((d) => d.date), contains(friday));
      expect(around(fast, 9 * 60).where((r) => r.date == friday).single.kind, ReminderKind.daily);
      expect(around(fast, 20 * 60).where((r) => r.date == friday), isEmpty);
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

    test('follows the reminders that resume after a pause longer than the horizon', () {
      // A pause of 30 days, from 9 days ahead: it runs past the 14 days
      // planned.
      final pause = Pause(LocalDate(2026, 10, 20), LocalDate(2026, 11, 18));
      final reminders = plan(days: 14, pauses: [pause]);
      final others = reminders.where((r) => r.kind != ReminderKind.paused).toList();
      expect(others.where((r) => pause.contains(r.date)), isEmpty);
      final after = others.where((r) => r.date > pause.end).toList();
      expect(after, isNotEmpty, reason: 'reminders resume once the pause ends');
      expect(after.first.date, LocalDate(2026, 11, 19));
      expect(after.where((r) => r.kind == ReminderKind.daily), isNotEmpty);
      expect(after.last.date.rd - pause.end.rd, lessThanOrEqualTo(14 + 7), reason: "for the horizon's length, or a week more");
      final paused = pausedIn(reminders);
      expect(reminders.last, same(paused));
      expect(paused.date > pause.end.addDays(14), isTrue);
      expect(reminders.length, lessThan(64), reason: 'within the pending notifications iOS allows');
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

  group("with the Shabbat times of the reader's city", () {
    const london = City(
      id: 2643743,
      nameEn: 'London',
      countryCode: 'GB',
      latitude: 51.5085,
      longitude: -0.1257,
      timeZone: 'Europe/London',
    );
    const newYork = City(
      id: 5128581,
      nameEn: 'New York City',
      countryCode: 'US',
      region: 'US.NY',
      latitude: 40.7143,
      longitude: -74.006,
      timeZone: 'America/New_York',
    );
    const jerusalem = City(
      id: 281184,
      nameEn: 'Jerusalem',
      countryCode: 'IL',
      latitude: 31.769,
      longitude: 35.2163,
      timeZone: 'Asia/Jerusalem',
      candleMinutes: 40,
    );

    /// The UTC offset of [place]'s clock on a day.
    Duration Function(LocalDate) clockOf(City place) {
      final location = Zmanim.timeZone(place.timeZone)!;
      return (d) => tz.TZDateTime(location, d.year, d.month, d.day, 12).timeZoneOffset;
    }

    /// [city]'s times, on a device that keeps [city]'s clock (or [device]'s).
    ReminderZmanim Function(LocalDate) timesIn(City city, {City? device}) =>
        reminderZmanim(city, deviceOffset: clockOf(device ?? city));
    int candles(City city, LocalDate d) => timesIn(city)(d).candles!;
    int havdalah(City city, LocalDate d) => timesIn(city)(d).havdalah!;

    /// Planned on the morning of [from], for a week and a day, in [city] if
    /// any.
    List<PlannedReminder> plan(
      LocalDate from,
      ReminderPrefs prefs, {
      City? city,
      City? device,
      ReadingPlanner planner = planner,
    }) =>
        planReminders(
          prefs: prefs,
          planner: planner,
          progressOf: empty,
          now: DateTime(from.year, from.month, from.day, 8),
          today: from,
          zmanim: city == null ? null : timesIn(city, device: device),
          days: 8,
        );
    PlannedReminder? on(List<PlannedReminder> reminders, LocalDate d) =>
        reminders.where((r) => r.date == d && r.kind != ReminderKind.paused).singleOrNull;
    String hm(int minutes) => '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';

    group('a winter Friday in London', () {
      final friday = LocalDate(2026, 11, 27);
      final sunday = friday.addDays(-5);

      test('candles are lit at about 15:40', () {
        expect(hm(candles(london, friday)), '15:39');
      });

      test('the daily reminder at 20:00 comes before candle-lighting, not never', () {
        const daily = ReminderPrefs(daily: true, dailyMinutes: 20 * 60);
        expect(on(plan(sunday, daily), friday), isNull, reason: 'without a city, nothing after midday');
        final reminders = plan(sunday, daily, city: london);
        final r = on(reminders, friday)!;
        expect(r.kind, ReminderKind.daily);
        expect(r.aliyot, [5, 6]);
        expect(r.minutes, candles(london, friday) - kDailyBeforeCandles);
        expect(hm(r.minutes), '14:09');
        // Thursday's keeps its time, and so does an earlier one on Friday.
        expect(on(reminders, friday.addDays(-1))!.minutes, 20 * 60);
        expect(on(plan(sunday, const ReminderPrefs(daily: true, dailyMinutes: 9 * 60), city: london), friday)!.minutes,
            9 * 60);
      });

      test('the Erev Shabbat reminder comes three hours before candle-lighting at the latest', () {
        ReminderPrefs at(int minutes) => ReminderPrefs(erevShabbat: true, erevShabbatMinutes: minutes);
        expect(on(plan(sunday, at(14 * 60), city: london), friday)!.minutes, candles(london, friday) - 180);
        expect(on(plan(sunday, at(10 * 60), city: london), friday)!.minutes, 10 * 60);
        expect(on(plan(sunday, at(14 * 60)), friday)!.minutes, kErevShabbatLatestMinutes, reason: 'without a city');
      });

      test('the check-in comes on Motzaei Shabbat, an hour after Havdalah', () {
        const checkIn = ReminderPrefs(checkIn: true);
        final shabbat = friday.addDays(1);
        final r = on(plan(sunday, checkIn, city: london), shabbat)!;
        expect(r.kind, ReminderKind.checkIn);
        expect(r.minutes, havdalah(london, shabbat) + kCheckInAfterHavdalah);
        expect(hm(r.minutes), '17:54');
        expect(on(plan(sunday, checkIn, city: london), shabbat.addDays(1)), isNull, reason: 'once');
        // Without a city, on Sunday morning.
        expect(on(plan(sunday, checkIn), shabbat), isNull);
        expect(on(plan(sunday, checkIn), shabbat.addDays(1))!.minutes, checkIn.checkInMinutes);
      });
    });

    group('a summer Friday in New York', () {
      final friday = LocalDate(2027, 6, 25);
      final sunday = friday.addDays(-5);

      test('candles are lit at about 20:10', () {
        expect(hm(candles(newYork, friday)), '20:13');
      });

      test('the daily reminder at 20:00 comes an hour and a half before candle-lighting', () {
        final r = on(plan(sunday, const ReminderPrefs(daily: true, dailyMinutes: 20 * 60), city: newYork), friday)!;
        expect(r.kind, ReminderKind.daily);
        expect(hm(r.minutes), '18:43');
        // Up to an hour before candle-lighting it was already allowed, but
        // comes as early as a later one.
        expect(
            on(plan(sunday, const ReminderPrefs(daily: true, dailyMinutes: 19 * 60), city: newYork), friday)!.minutes,
            r.minutes);
        expect(
            on(plan(sunday, const ReminderPrefs(daily: true, dailyMinutes: 18 * 60), city: newYork), friday)!.minutes,
            18 * 60);
      });

      test('the Erev Shabbat reminder may come in the afternoon', () {
        final r = on(
            plan(sunday, const ReminderPrefs(erevShabbat: true, erevShabbatMinutes: 18 * 60), city: newYork), friday)!;
        expect(hm(r.minutes), '17:13');
      });

      test('the check-in comes on Motzaei Shabbat, before 22:30', () {
        final shabbat = friday.addDays(1);
        final r = on(plan(sunday, const ReminderPrefs(checkIn: true), city: newYork), shabbat)!;
        expect(r.kind, ReminderKind.checkIn);
        expect(hm(r.minutes), '22:22');
      });
    });

    test('when Shabbat ends late, the check-in waits for Sunday morning', () {
      // London in June: Shabbat ends at 22:37.
      final shabbat = LocalDate(2027, 6, 26);
      expect(hm(havdalah(london, shabbat)), '22:37');
      final reminders = plan(shabbat.addDays(-6), const ReminderPrefs(checkIn: true), city: london);
      expect(on(reminders, shabbat), isNull);
      expect(on(reminders, shabbat.addDays(1))!.minutes, const ReminderPrefs().checkInMinutes);
    });

    group('Yom Tov followed by Shabbat: Rosh Hashanah 5789, Thursday to Shabbat Shuva', () {
      final erev = LocalDate(2028, 9, 20);
      final shabbat = erev.addDays(3);
      final sunday = erev.addDays(-3);

      test('the days are as expected', () {
        expect(HebrewDate.fromLocalDate(erev.addDays(1)), HebrewDate(5789, HebrewMonth.tishrei, 1));
        for (final d in [erev.addDays(1), erev.addDays(2), shabbat]) {
          expect(JewishHolidays.isRestDay(d, israel: false), isTrue, reason: '$d');
        }
        final week = planner.schedule.weekFor(erev);
        expect(week.occasion, shabbat);
        expect(planner.planFor(week).days.last.date, erev);
      });

      test('on Erev Rosh Hashanah, reminders keep to its candle-lighting', () {
        final lit = candles(newYork, erev);
        final reminders = plan(
          sunday,
          const ReminderPrefs(daily: true, dailyMinutes: 20 * 60, erevShabbat: true, erevShabbatMinutes: 17 * 60),
          city: newYork,
        );
        expect((on(reminders, erev)!.kind, on(reminders, erev)!.minutes), (ReminderKind.erevShabbat, lit - 180));
        final daily = on(plan(sunday, const ReminderPrefs(daily: true, dailyMinutes: 20 * 60), city: newYork), erev)!;
        expect(daily.minutes, lit - kDailyBeforeCandles);
      });

      test('nothing over the three days but the check-in after Shabbat', () {
        final reminders = plan(sunday, all, city: newYork);
        expect(on(reminders, erev.addDays(1)), isNull);
        expect(on(reminders, erev.addDays(2)), isNull);
        final r = on(reminders, shabbat)!;
        expect((r.kind, r.minutes), (ReminderKind.checkIn, havdalah(newYork, shabbat) + kCheckInAfterHavdalah));
      });
    });

    test('Shabbat followed by Yom Tov: the check-in comes after the Yom Tov ends', () {
      // Shabbat Bamidbar 5789, and Shavuot on Sunday and Monday.
      final shabbat = LocalDate(2029, 5, 19);
      final monday = shabbat.addDays(2);
      expect(JewishHolidays.isRestDay(monday, israel: false), isTrue);
      final reminders = plan(shabbat.addDays(-6), const ReminderPrefs(checkIn: true), city: newYork);
      expect(on(reminders, shabbat), isNull);
      expect(on(reminders, shabbat.addDays(1)), isNull);
      final r = on(reminders, monday)!;
      expect((r.kind, r.minutes), (ReminderKind.checkIn, havdalah(newYork, monday) + kCheckInAfterHavdalah));
    });

    test("no check-in as Tisha B'Av begins on Motzaei Shabbat", () {
      final ninth = HebrewDate(5789, HebrewMonth.av, 9).toLocalDate();
      expect(ninth.isShabbat, isTrue);
      expect(JewishHolidays.isTishaBav(ninth.addDays(1)), isTrue);
      final reminders = plan(ninth.addDays(-6), const ReminderPrefs(checkIn: true), city: newYork);
      expect(on(reminders, ninth), isNull);
      expect(on(reminders, ninth.addDays(1))!.minutes, const ReminderPrefs().checkInMinutes);
    });

    test("on a device keeping another city's clock, the rules without a city apply", () {
      final friday = LocalDate(2026, 11, 27);
      expect(timesIn(london, device: newYork)(friday), (candles: null, havdalah: null));
      const prefs = ReminderPrefs(daily: true, dailyMinutes: 20 * 60, erevShabbat: true, erevShabbatMinutes: 14 * 60);
      List<(LocalDate, ReminderKind, int)> times(List<PlannedReminder> reminders) =>
          [for (final r in reminders) (r.date, r.kind, r.minutes)];
      final sunday = friday.addDays(-5);
      expect(times(plan(sunday, prefs, city: london, device: newYork)), times(plan(sunday, prefs)));
    });

    for (final (place, schedule) in [(london, false), (newYork, false), (jerusalem, true)]) {
      test('in ${place.nameEn}, over a year: never on Shabbat or Yom Tov, nor from an hour before candle-lighting', () {
        final planner = ReadingPlanner(schedule: ParshaSchedule(israel: schedule));
        final times = timesIn(place);
        // The latest times, to press against the limits.
        const latest = ReminderPrefs(
          daily: true,
          dailyMinutes: 23 * 60 + 59,
          erevShabbat: true,
          erevShabbatMinutes: 23 * 60 + 59,
          checkIn: true,
        );
        final from = LocalDate(2026, 10, 11);
        final reminders = planReminders(
          prefs: latest,
          planner: planner,
          progressOf: empty,
          now: DateTime(from.year, from.month, from.day, 8),
          today: from,
          zmanim: times,
          days: 365,
        );
        expect(reminders.length, greaterThan(250));
        var evenings = 0;
        for (final r in reminders) {
          final rest = JewishHolidays.isRestDay(r.date, israel: planner.oneDayYomTov);
          if (rest) {
            // Only the check-in, after Shabbat or Yom Tov has ended.
            expect(r.kind, ReminderKind.checkIn, reason: '$r');
            expect(r.minutes, greaterThanOrEqualTo(times(r.date).havdalah! + kCheckInAfterHavdalah), reason: '$r');
            expect(r.minutes, lessThanOrEqualTo(kCheckInLatestMinutes), reason: '$r');
            expect(JewishHolidays.isRestDay(r.date.addDays(1), israel: planner.oneDayYomTov), isFalse, reason: '$r');
            evenings++;
          } else if (JewishHolidays.isRestDay(r.date.addDays(1), israel: planner.oneDayYomTov)) {
            expect(r.minutes, lessThan(times(r.date).candles! - kCutoffBeforeCandles), reason: '$r');
          }
        }
        expect(evenings, greaterThan(10), reason: 'most weeks, on Motzaei Shabbat');
      });
    }
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
