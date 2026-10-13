import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikrah/app/city_providers.dart';
import 'package:shnayim_mikrah/app/providers.dart';
import 'package:shnayim_mikrah/app/router.dart';
import 'package:shnayim_mikrah/core/calendar/city.dart';
import 'package:shnayim_mikrah/core/calendar/hebrew_date.dart';
import 'package:shnayim_mikrah/core/calendar/local_date.dart';
import 'package:shnayim_mikrah/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikrah/core/calendar/tz_database.dart';
import 'package:shnayim_mikrah/core/calendar/zmanim.dart';
import 'package:shnayim_mikrah/data/parsha_repository.dart';
import 'package:shnayim_mikrah/features/onboarding/onboarding_screen.dart';
import 'package:shnayim_mikrah/features/parsha/week_context.dart';
import 'package:shnayim_mikrah/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikrah/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikrah/features/reader/reader_screen.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/features/today/today_screen.dart';
import 'package:shnayim_mikrah/l10n/app_localizations.dart';
import 'package:shnayim_mikrah/services/app_shortcuts.dart';
import 'package:shnayim_mikrah/services/home_widget_sync.dart';
import 'package:shnayim_mikrah/ui/l10n.dart';
import 'package:timezone/timezone.dart' as tz;

import '../helpers.dart';

/// The platform side of home_widget: records what the app saves and asks to
/// update, and reports taps through [tap].
class FakeHomeWidget {
  FakeHomeWidget() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      final args = call.arguments;
      switch (call.method) {
        case 'saveWidgetData':
          if (failSaves) throw PlatformException(code: '-1');
          saved.add((args as Map)['data'] as String?);
          return true;
        case 'getWidgetData':
          return null;
        case 'updateWidget':
          updates.add(Map<String, Object?>.from(args as Map));
          return true;
        case 'initiallyLaunchedFromHomeWidget':
          return launchedWith;
        case 'setAppGroupId':
          return true;
      }
      return null;
    });
    messenger.setMockStreamHandler(
      _events,
      // Block bodies: what the handlers return is sent back over the channel.
      MockStreamHandler.inline(onListen: (_, sink) {
        _sink = sink;
      }, onCancel: (_) {
        _sink = null;
      }),
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(_channel, null);
      messenger.setMockStreamHandler(_events, null);
    });
  }

  static const _channel = MethodChannel('home_widget');
  static const _events = EventChannel('home_widget/updates');

  final calls = <MethodCall>[];

  /// Each timeline saved, in order; null when the widget was cleared.
  final saved = <String?>[];
  final updates = <Map<String, Object?>>[];

  /// The link the platform says launched the app.
  String? launchedWith;
  bool failSaves = false;

  MockStreamHandlerEventSink? _sink;

  /// A tap on the widget, as the platform reports it while the app runs.
  void tap(String uri) => _sink!.success(uri);

  Map<String, dynamic> get lastTimeline => jsonDecode(saved.last!) as Map<String, dynamic>;
}

/// Monday 12 October 2026, 9 a.m., in the week of Noach 5787.
final _monday = DateTime(2026, 10, 12, 9);

/// Monday 26 October 2026, 9 a.m., in the week of Vayera 5787 (Vayeira, in
/// the Ashkenazi spelling).
final _vayeraMonday = DateTime(2026, 10, 26, 9);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ensureTimeZones);
  late ParshaRepository repo;
  setUpAll(() async => repo = await loadRepo());

  final en = lookupAppLocalizations(const Locale('en'));
  final he = lookupAppLocalizations(const Locale('he'));

  WidgetTimeline timeline(
    DateTime now, {
    AppSettings? settings,
    ProgressState progress = const ProgressState(),
    AppLocalizations? l,
    RestTimes? Function(LocalDate day)? restTimes,
  }) {
    final s = settings ?? AppSettings(joinDate: captureJoinDate);
    return widgetTimeline(
      now: now,
      l: l ?? en,
      settings: s,
      repo: repo,
      // As plannerProvider plans.
      planner: ReadingPlanner(
        schedule: ParshaSchedule(israel: s.readingSchedule == ReadingSchedule.israel),
        oneDayYomTov: s.oneDayYomTov,
        settingsAt: s.settingsAt,
        starterFrom: s.starterCatchUp ? s.joinDate : null,
      ),
      progress: progress,
      restTimes: restTimes,
    );
  }

  /// The entries for [date], in order.
  List<WidgetDay> on(WidgetTimeline t, LocalDate date) => [for (final d in t.days) if (d.date == date) d];

  WidgetDay only(WidgetTimeline t, LocalDate date) => on(t, date).single;

  group('the timeline', () {
    test('runs from today through the Shabbat of next week, across the week boundary', () {
      // Friday of Bereshit: Rishon and Sheni read, and Shlishi twice.
      final t = timeline(captureNow, progress: captureProgress());
      expect(t.days.first.date, LocalDate(2026, 10, 9));
      expect(t.days.last.date, LocalDate(2026, 10, 17), reason: 'the Shabbat of Noach');
      expect({for (final d in t.days) d.date}, hasLength(9));
      expect([for (final w in t.weeks) w.id], ['5787:1', '5787:2']);

      final bereshit = t.weeks[0];
      expect((bereshit.hebrew, bereshit.name, bereshit.spoken), ('בְּרֵאשִׁית', 'Bereshit', 'Bereshit'));
      expect((bereshit.mikrah1, bereshit.mikrah2, bereshit.targum), (3, 3, 2));
      expect(bereshit.progress, '2 of 7 aliyot');
      expect(
        bereshit.spokenProgress,
        '2 of 7 aliyot. First reading: 3 of 7. Second reading: 3 of 7. Targum: 2 of 7',
        reason: "the rings' own label",
      );
      expect(bereshit.next, 'Continue · Shlishi, Targum', reason: "Today's button");
      expect(on(t, LocalDate(2026, 10, 9)).first.line, 'Catching up: Shlishi\u00A0– Shevi’i');

      // Shabbat rests, with the parsha read that day.
      final shabbat = only(t, LocalDate(2026, 10, 10));
      expect((shabbat.kind, shabbat.week, shabbat.eyebrow, shabbat.line),
          (WidgetDayKind.shabbat, 0, 'Parshat HaShavua', 'Shabbat Shalom'));

      // Then Noach, with the progress as it stands: what Today would say
      // each day if nothing more were read.
      expect(t.weeks[1].next, 'Start · Rishon');
      expect((t.weeks[1].mikrah1, t.weeks[1].mikrah2, t.weeks[1].targum), (0, 0, 0));
      final sunday = only(t, LocalDate(2026, 10, 11));
      expect((sunday.kind, sunday.week, sunday.line), (WidgetDayKind.weekday, 1, 'Today: Rishon'));
      expect(only(t, LocalDate(2026, 10, 12)).line, 'Catching up: Rishon and Sheni');
      expect(only(t, LocalDate(2026, 10, 13)).line, 'Catching up: Rishon\u00A0– Shlishi');
      expect(on(t, LocalDate(2026, 10, 16)).last.line, 'Catching up: The whole parsha');
      expect(only(t, LocalDate(2026, 10, 17)).kind, WidgetDayKind.shabbat);
    });

    test("names the day's reading as Today's card does", () {
      final week = WeekProgress(weekId: '5787:2');
      // Rishon read on Sunday: Monday's reading is Sheni alone.
      var t = timeline(_monday, progress: ProgressState(weeks: {'5787:2': week.withAliyah(0, LocalDate(2026, 10, 11))}));
      expect(only(t, LocalDate(2026, 10, 12)).line, 'Today: Sheni');
      expect(t.weeks.first.next, 'Continue · Sheni');

      // And Sheni too: done.
      t = timeline(_monday,
          progress: ProgressState(weeks: {
            '5787:2': week.withAliyah(0, LocalDate(2026, 10, 11)).withAliyah(1, LocalDate(2026, 10, 12)),
          }));
      expect(only(t, LocalDate(2026, 10, 12)).line, 'Today’s reading is done');
      expect(only(t, LocalDate(2026, 10, 13)).line, 'Today: Shlishi');

      // Every aliyah read: the week is complete, with nothing to continue.
      t = timeline(_monday, progress: ProgressState(weeks: {'5787:2': week.withAll(LocalDate(2026, 10, 12))}));
      expect(only(t, LocalDate(2026, 10, 12)).line, 'Parsha complete · Yasher koach!');
      expect(t.weeks.first.next, isNull);
      expect((t.weeks.first.mikrah1, t.weeks.first.mikrah2, t.weeks.first.targum), (7, 7, 7));

      // A plan that reads everything on Friday plans nothing before it.
      t = timeline(_monday, settings: AppSettings(joinDate: captureJoinDate, plan: ReadingPlanType.erevShabbat));
      expect(only(t, LocalDate(2026, 10, 12)).line, 'No reading planned today');
      expect(on(t, LocalDate(2026, 10, 16)).first.line, 'Today: The whole parsha');
      // In the very words of Today's card.
      expect(AliyahNames(en).aliyot([for (var a = 0; a < kAliyot; a++) a]), 'The whole parsha');
      t = timeline(
        _monday,
        l: he,
        settings: AppSettings(joinDate: captureJoinDate, plan: ReadingPlanType.erevShabbat, language: AppLanguage.hebrew),
      );
      expect(on(t, LocalDate(2026, 10, 16)).first.line, 'היום: כל הפרשה');
    });

    test("turns with the app's day, at 3 a.m.", () {
      final night = timeline(DateTime(2026, 10, 11, 2, 59));
      expect(night.days.first.date, LocalDate(2026, 10, 10), reason: 'still Shabbat by the app');
      expect(night.days.first.kind, WidgetDayKind.shabbat);
      // The week after the reading week Shabbat ends.
      expect(night.days.last.date, LocalDate(2026, 10, 24));

      final morning = timeline(DateTime(2026, 10, 11, 3));
      expect(morning.days.first.date, LocalDate(2026, 10, 11));
      expect(morning.days.last.date, LocalDate(2026, 10, 24));
    });

    test('turns to Erev Shabbat at midday on Friday', () {
      final friday = LocalDate(2026, 10, 9);
      final morning = on(timeline(captureNow), friday);
      expect([for (final d in morning) (d.kind, d.eyebrow, d.until)], [
        (WidgetDayKind.erevShabbat, 'Parshat HaShavua', DateTime(2026, 10, 9, 12)),
        (WidgetDayKind.erevShabbat, 'Erev Shabbat', null),
      ]);
      // The morning's entry is over by the afternoon.
      final afternoon = on(timeline(DateTime(2026, 10, 9, 13)), friday);
      expect([for (final d in afternoon) d.eyebrow], ['Erev Shabbat']);
    });

    test('turns to Erev Yom Tov at midday on its eve, in the words of Today', () {
      // Wednesday 20 September 2028, Erev Rosh Hashanah 5789.
      final erev = LocalDate(2028, 9, 20);
      final settings = AppSettings(joinDate: LocalDate(2028, 9, 1));
      final morning = on(timeline(DateTime(2028, 9, 20, 10), settings: settings), erev);
      expect([for (final d in morning) (d.kind, d.eyebrow, d.until)], [
        (WidgetDayKind.erevYomTov, 'Parshat HaShavua', DateTime(2028, 9, 20, 12)),
        (WidgetDayKind.erevYomTov, 'Erev Rosh Hashanah', null),
      ]);
      final hebrew = on(
        timeline(DateTime(2028, 9, 20, 13), l: he, settings: settings.copyWith(language: AppLanguage.hebrew)),
        erev,
      );
      expect([for (final d in hebrew) d.eyebrow], ['ערב ראש השנה']);

      // Erev Yom Kippur 5786, in the week of Haazinu.
      final yomKippur = timeline(DateTime(2025, 10, 1, 13), settings: AppSettings(joinDate: LocalDate(2025, 9, 1)));
      expect([for (final d in on(yomKippur, LocalDate(2025, 10, 1))) d.eyebrow], ['Erev Yom Kippur']);

      // Erev Yom Kippur 5787 is in the week of Vezot HaBerachah, whose
      // eyebrow, Simchat Torah, stays all day, as Today's does.
      final vezot = timeline(DateTime(2026, 9, 20, 10), settings: AppSettings(joinDate: LocalDate(2026, 9, 1)));
      expect([for (final d in on(vezot, LocalDate(2026, 9, 20))) d.eyebrow], ['Simchat Torah']);
    });

    test('with a city, rests from candle-lighting until nightfall, as Today does', () {
      const times = (candleLighting: 17 * 60 + 30, sunset: 17 * 60 + 48, nightfall: 18 * 60 + 40);
      final t = timeline(DateTime(2026, 10, 9, 13), restTimes: (_) => times);
      expect(on(t, LocalDate(2026, 10, 9)).single.until, DateTime(2026, 10, 9, 17, 30));
      expect(only(t, LocalDate(2026, 10, 10)).until, DateTime(2026, 10, 10, 18, 40));
      expect(only(t, LocalDate(2026, 10, 11)).until, isNull);

      // Two days of Rosh Hashanah, from Shabbat: it ends at nightfall on the
      // second day.
      final roshHashanah = timeline(DateTime(2026, 9, 10, 10), restTimes: (_) => times);
      expect(only(roshHashanah, LocalDate(2026, 9, 12)).until, isNull);
      expect(only(roshHashanah, LocalDate(2026, 9, 13)).until, DateTime(2026, 9, 13, 18, 40));

      // A day the device keeps another clock (a traveller) has no times.
      final away = timeline(DateTime(2026, 10, 9, 13), restTimes: (day) => day.weekday == 5 ? null : times);
      expect(on(away, LocalDate(2026, 10, 9)).single.until, isNull);
    });

    test('in weeks with Yom Tov, by the days of Yom Tov kept', () {
      // Shavuot 5787: Friday and Shabbat outside Israel.
      final diaspora = timeline(DateTime(2027, 6, 7, 10), settings: AppSettings(joinDate: LocalDate(2026, 9, 1)));
      // Its eve, Erev Yom Tov from midday.
      expect([for (final d in on(diaspora, LocalDate(2027, 6, 10))) (d.kind, d.eyebrow)], [
        (WidgetDayKind.erevYomTov, 'Parshat HaShavua'),
        (WidgetDayKind.erevYomTov, 'Erev Yom Tov'),
      ]);
      for (final day in [LocalDate(2027, 6, 11), LocalDate(2027, 6, 12)]) {
        final d = only(diaspora, day);
        expect((d.kind, d.line), (WidgetDayKind.yomTov, 'Chag Sameach'), reason: '$day');
      }
      // In Israel, one day: Shabbat is Shabbat.
      final israel = timeline(
        DateTime(2027, 6, 7, 10),
        settings: AppSettings(joinDate: LocalDate(2026, 9, 1)).locatedIn(ReadingSchedule.israel),
      );
      expect(only(israel, LocalDate(2027, 6, 11)).kind, WidgetDayKind.yomTov);
      final shabbat = only(israel, LocalDate(2027, 6, 12));
      expect((shabbat.kind, shabbat.line), (WidgetDayKind.shabbat, 'Shabbat Shalom'));

      // The days of awe have their own greetings, and Vezot HaBerachah is
      // read on Simchat Torah.
      final tishrei = timeline(DateTime(2026, 9, 10, 10), settings: AppSettings(joinDate: LocalDate(2026, 9, 1)));
      expect(only(tishrei, LocalDate(2026, 9, 12)).line, 'Shanah Tovah');
      expect(only(tishrei, LocalDate(2026, 9, 21)).line, 'G’mar Chatimah Tovah');
      expect(only(tishrei, LocalDate(2026, 9, 20)).kind, WidgetDayKind.erevYomTov, reason: 'Erev Yom Kippur');
      expect(only(tishrei, LocalDate(2026, 9, 26)).line, 'Chag Sameach', reason: 'Sukkot');
      expect(only(tishrei, LocalDate(2026, 10, 4)).eyebrow, 'Simchat Torah');
      expect(tishrei.days.last.date, LocalDate(2026, 10, 4));
    });

    test('runs on through a Yom Tov straight after its last Shabbat', () {
      // Two weeks before Pesach 5785, which begins on Sunday 13 April, the
      // day after the timeline's last Shabbat: outside Israel for two days.
      final settings = AppSettings(joinDate: LocalDate(2024, 9, 1));
      const times = (candleLighting: 19 * 60, sunset: 19 * 60 + 18, nightfall: 20 * 60 + 10);
      final diaspora = timeline(DateTime(2025, 3, 31, 10), settings: settings, restTimes: (_) => times);
      expect(diaspora.days.last.date, LocalDate(2025, 4, 14));
      final shabbat = only(diaspora, LocalDate(2025, 4, 12));
      expect((shabbat.kind, shabbat.line, shabbat.until), (WidgetDayKind.shabbat, 'Shabbat Shalom', null),
          reason: 'the days of rest go on');
      for (final (day, until) in [(13, null), (14, DateTime(2025, 4, 14, 20, 10))]) {
        final d = only(diaspora, LocalDate(2025, 4, day));
        expect((d.kind, d.line, d.until), (WidgetDayKind.yomTov, 'Chag Sameach', until), reason: '$day April');
      }
      expect(diaspora.rests.keys.first, LocalDate(2025, 4, 19));

      // In Israel, one day.
      final israel = timeline(DateTime(2025, 3, 31, 10),
          settings: settings.locatedIn(ReadingSchedule.israel), restTimes: (_) => times);
      expect(israel.days.last.date, LocalDate(2025, 4, 13));
      expect(only(israel, LocalDate(2025, 4, 13)).until, DateTime(2025, 4, 13, 20, 10));
    });

    test('then gives the days of rest for months, each with its greeting', () {
      final t = timeline(captureNow);
      // Every Shabbat from the one after the timeline's last, for about four
      // months.
      expect(t.days.last.date, LocalDate(2026, 10, 17));
      expect(t.rests.keys.first, LocalDate(2026, 10, 24));
      expect(t.rests.keys.last, LocalDate(2027, 2, 13));
      expect(t.rests, hasLength(17));
      expect(t.rests.keys.every((d) => d.isShabbat), isTrue);
      expect(t.rests.values.toSet(), {'Shabbat Shalom'});

      // Yom Tov by the days kept, in the app's language: Pesach and Shavuot
      // 5787.
      final spring = timeline(DateTime(2027, 3, 1, 10), settings: AppSettings(joinDate: LocalDate(2026, 9, 1)));
      final yomTov = {for (final MapEntry(:key, :value) in spring.rests.entries) if (!key.isShabbat) key: value};
      expect(yomTov, {
        for (final day in [(4, 22), (4, 23), (4, 28), (4, 29), (6, 11)]) LocalDate(2027, day.$1, day.$2): 'Chag Sameach',
      });
      expect(spring.rests[LocalDate(2027, 6, 12)], 'Chag Sameach', reason: 'Shavuot on Shabbat');
      final israel = timeline(
        DateTime(2027, 3, 1, 10),
        l: he,
        settings: AppSettings(joinDate: LocalDate(2026, 9, 1), language: AppLanguage.hebrew).locatedIn(ReadingSchedule.israel),
      );
      expect({for (final MapEntry(:key, :value) in israel.rests.entries) if (!key.isShabbat) key: value}, {
        for (final day in [(4, 22), (4, 28), (6, 11)]) LocalDate(2027, day.$1, day.$2): 'חג שמח',
      });
      expect(israel.rests[LocalDate(2027, 6, 12)], 'שבת שלום');
    });

    test('while paused, says that nothing counts against the reader', () {
      final progress = ProgressState(pauses: [Pause(LocalDate(2026, 10, 11), LocalDate(2026, 10, 13))]);
      final t = timeline(_monday, progress: progress);
      for (final day in [LocalDate(2026, 10, 12), LocalDate(2026, 10, 13)]) {
        final d = only(t, day);
        expect((d.kind, d.line), (WidgetDayKind.paused, 'Paused · read whenever you like'), reason: '$day');
      }
      final after = only(t, LocalDate(2026, 10, 14));
      expect(after.kind, WidgetDayKind.weekday);
      expect(after.line, startsWith('Catching up:'));
      // Today's button still leads on.
      expect(t.weeks.first.next, 'Start · Rishon');
    });

    test("on Tisha B'Av, is headed by the fast and asks for no reading, as Today is", () {
      // Monday 9 August 2027, in the week of Va'etchanan 5787 (5787:45), with
      // Rishon read on Sunday: Thursday the 12th is 9 Av.
      final settings = AppSettings(joinDate: LocalDate(2027, 8, 1));
      final progress = ProgressState(weeks: {
        '5787:45': WeekProgress(weekId: '5787:45').withAliyah(0, LocalDate(2027, 8, 8)),
      });
      final now = DateTime(2027, 8, 9, 9);
      final fast = LocalDate(2027, 8, 12);
      final t = timeline(now, settings: settings, progress: progress);
      final day = only(t, fast);
      expect(
        (day.kind, day.eyebrow, day.line),
        (WidgetDayKind.tishaBav, 'Tisha B’Av', 'Torah study is set aside today'),
      );
      // The week's progress, as Today keeps its rings, but no Continue, as
      // Today has no button: the fast has the week to itself.
      final week = t.weeks[day.week];
      final regular = t.weeks[only(t, fast.addDays(-1)).week];
      expect(week.id, regular.id);
      expect(
        (week.mikrah1, week.progress, week.spokenProgress),
        (regular.mikrah1, regular.progress, regular.spokenProgress),
      );
      expect(regular.next, 'Continue · Sheni');
      expect(week.next, isNull);
      expect(week.toJson().containsKey('next'), isFalse);
      // The day after, a reading day like any other, without a greeting.
      final friday = on(t, fast.addDays(1)).first;
      expect((friday.kind, friday.week), (WidgetDayKind.erevShabbat, only(t, fast.addDays(-1)).week));
      expect(friday.line, startsWith('Catching up: '));

      final hebrew = only(
        timeline(now, l: he, settings: settings.copyWith(language: AppLanguage.hebrew), progress: progress),
        fast,
      );
      expect((hebrew.eyebrow, hebrew.line), ('תשעה באב', 'היום אין לומדים תורה'));

      // A reader who plans a reading on the fast is asked for it.
      final reading = timeline(now, settings: settings.copyWith(tishaBavQuiet: false), progress: progress);
      final asked = only(reading, fast);
      expect((asked.kind, asked.eyebrow), (WidgetDayKind.weekday, 'Parshat HaShavua'));
      expect(asked.line, startsWith('Catching up: '));
      expect(reading.weeks.where((w) => w.id == '5787:45').single.next, 'Continue · Sheni');

      // Postponed from Shabbat, the fast opens the week (Sunday 10 Av 5789).
      final sunday = HebrewDate(5789, HebrewMonth.av, 10).toLocalDate();
      final postponed = timeline(
        DateTime(sunday.year, sunday.month, sunday.day, 9),
        settings: AppSettings(joinDate: sunday.addDays(-21)),
      );
      final first = postponed.days.first;
      expect((first.date, first.kind, first.eyebrow), (sunday, WidgetDayKind.tishaBav, 'Tisha B’Av'));
      expect(postponed.weeks[first.week].next, isNull);
      final monday = postponed.days[1];
      expect((monday.kind, monday.eyebrow), (WidgetDayKind.weekday, 'Parshat HaShavua'));
      expect(postponed.weeks[monday.week].next, 'Start · Rishon');
    });

    test("with a city, is quiet from sunset on the eve of Tisha B'Av, as Today is", () {
      // Wednesday 11 August 2027, 8 Av 5787: the fast begins at sunset.
      final settings = AppSettings(joinDate: LocalDate(2027, 8, 1));
      final eve = LocalDate(2027, 8, 11);
      const times = (candleLighting: 19 * 60, sunset: 19 * 60 + 39, nightfall: 20 * 60 + 10);
      final t = timeline(DateTime(2027, 8, 11, 9), settings: settings, restTimes: (_) => times);
      final [day, evening] = on(t, eve);
      expect(
        (day.kind, day.eyebrow, day.until),
        (WidgetDayKind.weekday, 'Parshat HaShavua', DateTime(2027, 8, 11, 19, 39)),
      );
      expect(t.weeks[day.week].next, isNotNull);
      expect(
        (evening.kind, evening.eyebrow, evening.line, evening.until),
        (WidgetDayKind.tishaBav, 'Tisha B’Av', 'Torah study is set aside today', null),
      );
      expect(t.weeks[evening.week].next, isNull, reason: 'no Continue, as on the fast');
      expect(evening.week, only(t, LocalDate(2027, 8, 12)).week, reason: "the fast's own week");
      // After sunset, only the evening's.
      expect(on(timeline(DateTime(2027, 8, 11, 20), settings: settings, restTimes: (_) => times), eve), [
        isA<WidgetDay>().having((d) => d.kind, 'kind', WidgetDayKind.tishaBav),
      ]);

      // Without a city, or a reading planned on the fast, the day as before.
      expect(only(timeline(DateTime(2027, 8, 11, 9), settings: settings), eve).kind, WidgetDayKind.weekday);
      final reading = timeline(
        DateTime(2027, 8, 11, 9),
        settings: settings.copyWith(tishaBavQuiet: false),
        restTimes: (_) => times,
      );
      expect(only(reading, eve).until, isNull);
    });

    test("in Hebrew, with the app's words and the reader's spelling", () {
      final t = timeline(
        captureNow,
        l: he,
        settings: AppSettings(joinDate: captureJoinDate, language: AppLanguage.hebrew),
        progress: captureProgress(),
      );
      expect(t.rtl, isTrue);
      expect(t.stale, 'יש לפתוח את האפליקציה כדי לעדכן');
      final bereshit = t.weeks.first;
      expect((bereshit.hebrew, bereshit.name, bereshit.spoken), ('בְּרֵאשִׁית', 'Bereshit', 'בראשית'));
      expect(bereshit.progress, '2 מתוך 7 עליות');
      expect(bereshit.next, 'המשך · שלישי, תרגום');
      final friday = on(t, LocalDate(2026, 10, 9));
      expect([for (final d in friday) d.eyebrow], ['פרשת השבוע', 'ערב שבת']);
      expect(friday.first.line, 'משלימים: שלישי\u00A0– שביעי');
      expect(only(t, LocalDate(2026, 10, 10)).line, 'שבת שלום');
      expect(only(t, LocalDate(2026, 10, 11)).line, 'היום: ראשון');

      expect(timeline(captureNow).rtl, isFalse);
    });

    test("follows the reader's names, vowels and second reading", () {
      final t = timeline(
        captureNow,
        settings: AppSettings(
          joinDate: captureJoinDate,
          nameStyle: NameStyle.ashkenazi,
          showNikud: false,
          secondReading: SecondReading.rashi,
        ),
        progress: captureProgress(),
      );
      final bereshit = t.weeks.first;
      expect((bereshit.hebrew, bereshit.name), ('בראשית', 'Bereishis'));
      expect(bereshit.next, 'Continue · Shlishi, Rashi');
      expect(bereshit.spokenProgress, endsWith('Rashi: 2 of 7'));
    });

    test('is sent as compact JSON, under 8 KB at its longest', () {
      final json = jsonDecode(timeline(captureNow, progress: captureProgress()).encode()) as Map<String, dynamic>;
      expect(json.keys, ['v', 'rtl', 'open', 'continue', 'stale', 'weeks', 'days', 'rest']);
      expect((json['rest'] as Map).entries.first, isA<MapEntry<String, dynamic>>());
      expect((json['rest'] as Map)['2026-10-24'], 'Shabbat Shalom');
      expect(json['open'], 'shnayimmikrah://widget/today?homeWidget');
      expect(json['continue'], 'shnayimmikrah://widget/continue?homeWidget');
      final days = (json['days'] as List).cast<Map<String, dynamic>>();
      expect(days.first, {
        'date': '2026-10-09',
        'until': DateTime(2026, 10, 9, 12).millisecondsSinceEpoch,
        'week': 0,
        'kind': 'erevShabbat',
        'eyebrow': 'Parshat HaShavua',
        'line': 'Catching up: Shlishi\u00A0– Shevi’i',
      });
      expect((json['weeks'] as List).last, containsPair('next', 'Start · Rishon'));
      expect((json['weeks'] as List).first, containsPair('m1', 3));

      // The Shabbat before Ha'azinu, whose week and Vezot HaBerachah's after
      // it run on through the festivals: a month of days, in Hebrew, each
      // eve and Shabbat with a city's times.
      final longest = timeline(
        DateTime(2026, 9, 5, 12),
        l: he,
        settings: AppSettings(joinDate: LocalDate(2026, 9, 1), language: AppLanguage.hebrew),
        restTimes: (_) => (candleLighting: 18 * 60, sunset: 18 * 60 + 18, nightfall: 19 * 60 + 15),
      );
      expect({for (final d in longest.days) d.date}.length, greaterThanOrEqualTo(30));
      expect(utf8.encode(longest.encode()).length, lessThan(8 * 1024));
    });
  });

  group('links', () {
    test('name a page, which the app reads back', () {
      expect(WidgetLink.today.uri.toString(), 'shnayimmikrah://widget/today?homeWidget');
      expect(WidgetLink.continueReading.uri.toString(), 'shnayimmikrah://widget/continue?homeWidget');
      for (final link in WidgetLink.values) {
        expect(WidgetLink.fromUri(link.uri), link);
      }
      for (final other in [
        'https://widget/today',
        'shnayimmikrah://other/today?homeWidget',
        'shnayimmikrah://widget/elsewhere?homeWidget',
        '',
      ]) {
        expect(WidgetLink.fromUri(Uri.parse(other)), isNull, reason: other);
      }
      expect(WidgetLink.fromUri(null), isNull);
    });

    test("open Today, and the reader where Today's button continues", () async {
      final settings = AppSettings(joinDate: captureJoinDate, onboardingComplete: true);
      SharedPreferences.setMockInitialValues({
        SettingsController.storageKey: jsonEncode(settings.toJson()),
        ProgressController.storageKey: jsonEncode(captureProgress().toJson()),
      });
      final prefs = await SharedPreferences.getInstance();
      final clock = TodayController.now;
      TodayController.now = () => captureNow;
      TodayController.autoRollover = false;
      final c = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        parshaRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(() {
        c.dispose();
        TodayController.now = clock;
      });
      final week = c.read(currentWeekContextProvider);
      expect(WidgetLink.today.route(week), '/today');
      expect(WidgetLink.continueReading.route(week), '/read/5787:1/2');
      expect(WidgetLink.continueReading.route(week), AppShortcut.continueReading.route(week));
    });
  });

  group('the service', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('runs on Android and iOS only, sharing the App Group on iOS', () async {
      for (final platform in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = platform;
        final fake = FakeHomeWidget();
        final service = await HomeWidgetService.create();
        final expected = platform == TargetPlatform.android || platform == TargetPlatform.iOS;
        expect(service.supported, expected, reason: platform.name);
        final groups = [
          for (final call in fake.calls)
            if (call.method == 'setAppGroupId') (call.arguments as Map)['groupId'],
        ];
        expect(groups, platform == TargetPlatform.iOS ? [kWidgetAppGroup] : isEmpty, reason: platform.name);
      }
    });

    test('is disabled where the plugin is missing', () async {
      // No fake platform side: every call fails.
      final service = await HomeWidgetService.create();
      expect(service.supported, isFalse);
    });

    test('holds the link that launched the app until it is listened to', () async {
      final fake = FakeHomeWidget()..launchedWith = 'shnayimmikrah://widget/continue?homeWidget';
      final service = await HomeWidgetService.create();
      final opened = <WidgetLink>[];
      service.listen(opened.add);
      expect(opened, [WidgetLink.continueReading]);
      expect(fake.saved, isEmpty);
    });

    test('hands on each tap once, and ignores links that are not its own', () async {
      final fake = FakeHomeWidget();
      var now = DateTime(2026, 10, 12, 9);
      final service = await HomeWidgetService.create(now: () => now);
      final opened = <WidgetLink>[];
      service.listen(opened.add);

      fake.tap('shnayimmikrah://widget/today?homeWidget');
      await pumpEventQueue();
      expect(opened, [WidgetLink.today]);

      // The same tap reported again at once, as the app resumes.
      fake.tap('shnayimmikrah://widget/today?homeWidget');
      await pumpEventQueue();
      expect(opened, [WidgetLink.today]);

      fake.tap('https://example.org/');
      now = now.add(const Duration(seconds: 3));
      fake.tap('shnayimmikrah://widget/today?homeWidget');
      fake.tap('shnayimmikrah://widget/continue?homeWidget');
      await pumpEventQueue();
      expect(opened, [WidgetLink.today, WidgetLink.today, WidgetLink.continueReading]);
    });
  });

  group('pushes', () {
    late SharedPreferences prefs;
    late DateTime Function() clock;

    Future<void> store(AppSettings settings, {ProgressState? progress}) async {
      SharedPreferences.setMockInitialValues({
        SettingsController.storageKey: jsonEncode(settings.toJson()),
        if (progress != null) ProgressController.storageKey: jsonEncode(progress.toJson()),
      });
      prefs = await SharedPreferences.getInstance();
    }

    setUp(() async {
      clock = TodayController.now;
      TodayController.now = () => _vayeraMonday;
      TodayController.autoRollover = false;
      await store(AppSettings(joinDate: captureJoinDate, onboardingComplete: true));
    });
    tearDown(() => TodayController.now = clock);

    /// A container kept alive the way the app keeps it, with the widget's
    /// [service], and any other [overrides].
    ProviderContainer containerFor(HomeWidgetService service, {List<Override> overrides = const []}) {
      final c = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        parshaRepositoryProvider.overrideWithValue(repo),
        homeWidgetServiceProvider.overrideWithValue(service),
        ...overrides,
      ]);
      c.listen(homeWidgetSyncProvider, (_, _) {});
      addTearDown(c.dispose);
      return c;
    }

    /// The service, created on the fake platform outside the fake clock.
    Future<(FakeHomeWidget, HomeWidgetService)> platform() async {
      final fake = FakeHomeWidget();
      return (fake, await HomeWidgetService.create());
    }

    test('at startup, within a second, to both platforms', () async {
      final (fake, service) = await platform();
      fakeAsync((async) {
        containerFor(service);
        async.elapse(HomeWidgetService.throttle - const Duration(milliseconds: 1));
        expect(fake.saved, isEmpty);
        async.elapse(const Duration(milliseconds: 1));
        expect(fake.saved, hasLength(1));
        expect(fake.lastTimeline['days'], isNotEmpty);
        expect(fake.updates, [
          {'name': null, 'android': null, 'ios': kIOSWidgetKind, 'qualifiedAndroidName': kAndroidWidgetProvider},
        ]);
        final saves = [for (final call in fake.calls) if (call.method == 'saveWidgetData') call.arguments as Map];
        expect(saves.single['id'], kWidgetTimelineKey);
      });
    });

    test('whenever the progress or the settings it shows change, at most once a second', () async {
      final (fake, service) = await platform();
      fakeAsync((async) {
        final c = containerFor(service);
        async.elapse(const Duration(seconds: 2));
        expect(fake.saved, hasLength(1));

        void change(void Function() edit, String reason, bool Function(Map<String, dynamic> t) shows) {
          final before = fake.saved.length;
          edit();
          async.elapse(const Duration(seconds: 2));
          expect(fake.saved, hasLength(before + 1), reason: reason);
          expect(shows(fake.lastTimeline), isTrue, reason: reason);
        }

        Map<String, dynamic> week(Map<String, dynamic> t) => (t['weeks'] as List).first as Map<String, dynamic>;
        Map<String, dynamic> day(Map<String, dynamic> t) => (t['days'] as List).first as Map<String, dynamic>;
        final settings = c.read(settingsProvider.notifier);

        change(() => c.read(progressProvider.notifier).markAliyah('5787:4', 0, LocalDate(2026, 10, 25)), 'a reading',
            (t) => week(t)['m1'] == 1);
        change(() => settings.update((s) => s.copyWith(language: AppLanguage.hebrew)), 'the language',
            (t) => t['rtl'] == true && day(t)['eyebrow'] == 'פרשת השבוע');
        change(() => settings.update((s) => s.copyWith(nameStyle: NameStyle.ashkenazi)), 'the names',
            (t) => week(t)['name'] == 'Vayeira');
        change(() => settings.update((s) => s.copyWith(showNikud: false)), 'the vowels', (t) => week(t)['he'] == 'וירא');
        change(() => settings.update((s) => s.copyWith(secondReading: SecondReading.rashi)), 'the second reading',
            (t) => (week(t)['sayProgress'] as String).contains('רש״י'));
        change(() => c.read(progressProvider.notifier).addPause(LocalDate(2026, 10, 26), LocalDate(2026, 11, 3)),
            'a pause', (t) => day(t)['kind'] == 'paused');

        // Several changes in a moment are sent once.
        final before = fake.saved.length;
        settings.update((s) => s.copyWith(language: AppLanguage.english));
        async.elapse(const Duration(milliseconds: 300));
        settings.update((s) => s.copyWith(nameStyle: NameStyle.sephardi));
        async.elapse(const Duration(milliseconds: 300));
        c.read(progressProvider.notifier).markAliyah('5787:4', 1, LocalDate(2026, 10, 26));
        async.elapse(const Duration(seconds: 2));
        expect(fake.saved, hasLength(before + 1));
        expect(fake.lastTimeline['rtl'], isFalse);
        expect(week(fake.lastTimeline)['m1'], 2);
      });
    });

    test('when the reader moves to Israel, or back', () async {
      // The week of Shavuot 5787, Friday and Shabbat outside Israel.
      TodayController.now = () => DateTime(2027, 6, 7, 10);
      final (fake, service) = await platform();
      fakeAsync((async) {
        final c = containerFor(service);
        async.elapse(const Duration(seconds: 2));
        String kindOn(String date) =>
            ((fake.lastTimeline['days'] as List).cast<Map>().firstWhere((d) => d['date'] == date))['kind'] as String;
        expect(kindOn('2027-06-12'), 'yomTov');
        c.read(settingsProvider.notifier).update((s) => s.locatedIn(ReadingSchedule.israel));
        async.elapse(const Duration(seconds: 2));
        expect(fake.saved, hasLength(2));
        expect(kindOn('2027-06-12'), 'shabbat');
        c.read(settingsProvider.notifier).update((s) => s.locatedIn(ReadingSchedule.diaspora));
        async.elapse(const Duration(seconds: 2));
        expect(fake.saved, hasLength(3));
        expect(kindOn('2027-06-12'), 'yomTov');
      });
    });

    test("with a city, turns at the reader's candle-lighting and end of Shabbat, and again as they change", () async {
      const jerusalem = City(
        id: 281184,
        nameEn: 'Jerusalem',
        countryCode: 'IL',
        latitude: 31.769,
        longitude: 35.2163,
        timeZone: 'Asia/Jerusalem',
        candleMinutes: 40,
      );
      await store(AppSettings(joinDate: captureJoinDate, onboardingComplete: true, city: jerusalem));
      final location = Zmanim.timeZone(jerusalem.timeZone)!;
      final (fake, service) = await platform();
      fakeAsync((async) {
        final c = containerFor(service, overrides: [
          timeZoneDatabaseProvider.overrideWith((ref) async {}),
          // A device in Jerusalem, on its clock: tests run on UTC.
          deviceClockProvider
              .overrideWithValue((d) => tz.TZDateTime(location, d.year, d.month, d.day, 12).timeZoneOffset),
        ]);
        async.elapse(const Duration(seconds: 2));
        final friday = LocalDate(2026, 10, 30), shabbat = friday.addDays(1);
        // When the last entry of [day] ends.
        DateTime? until(LocalDate day) {
          final entries = (fake.lastTimeline['days'] as List).cast<Map<String, dynamic>>();
          final ms = entries.lastWhere((d) => d['date'] == day.toIso())['until'] as int?;
          return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
        }

        DateTime at(Zmanim z, tz.TZDateTime? time) =>
            DateTime(z.date.year, z.date.month, z.date.day, 0, z.minutesOf(time)!);
        final cityFriday = Zmanim.of(jerusalem, friday), cityShabbat = Zmanim.of(jerusalem, shabbat);
        expect(until(friday), at(cityFriday, cityFriday.candleLighting));
        expect(until(shabbat), at(cityShabbat, cityShabbat.havdalah));

        c
            .read(settingsProvider.notifier)
            .update((s) => s.copyWith(candleMinutesOverride: 30, havdalah: HavdalahRule.min72));
        async.elapse(const Duration(seconds: 2));
        expect(fake.saved, hasLength(2));
        final luachFriday = Zmanim.of(jerusalem, friday, candleMinutes: 30);
        final luachShabbat = Zmanim.of(jerusalem, shabbat, havdalah: HavdalahRule.min72);
        expect(until(friday), at(luachFriday, luachFriday.candleLighting));
        expect(until(shabbat), at(luachShabbat, luachShabbat.havdalah));
        // Ten minutes after the city's own forty.
        expect(until(friday)!.difference(at(cityFriday, cityFriday.candleLighting)), const Duration(minutes: 10));
      });
    });

    test('nothing unchanged is sent again, but on resuming it is', () async {
      final (fake, service) = await platform();
      fakeAsync((async) {
        final c = containerFor(service);
        async.elapse(const Duration(seconds: 2));
        // A setting the widget doesn't show, and a place saved in the reader
        // of a week already begun.
        c.read(settingsProvider.notifier).update((s) => s.copyWith(theme: AppThemeMode.dark));
        async.elapse(const Duration(seconds: 2));
        expect(fake.saved, hasLength(1));

        final binding = TestWidgetsFlutterBinding.instance;
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        async.elapse(const Duration(seconds: 2));
        expect(fake.saved, hasLength(2));
        expect(fake.saved[1], fake.saved[0]);
      });
    });

    test("turns Today's Start to Continue once the week is begun", () async {
      final (fake, service) = await platform();
      fakeAsync((async) {
        final c = containerFor(service);
        async.elapse(const Duration(seconds: 2));
        expect(((fake.lastTimeline['weeks'] as List).first as Map)['next'], 'Start · Rishon');
        // A place saved partway through Rishon's first reading.
        c.read(progressProvider.notifier).savePosition('5787:4', 0, [3, 0, 0]);
        async.elapse(const Duration(seconds: 2));
        expect(((fake.lastTimeline['weeks'] as List).first as Map)['next'], 'Continue · Rishon');
      });
    });

    test('before onboarding, the widget is cleared', () async {
      await store(const AppSettings());
      final (fake, service) = await platform();
      fakeAsync((async) {
        final c = containerFor(service);
        async.elapse(const Duration(seconds: 2));
        expect(fake.saved, [null]);
        c.read(settingsProvider.notifier).update((s) => s.copyWith(onboardingComplete: true, joinDate: captureJoinDate));
        async.elapse(const Duration(seconds: 2));
        expect(fake.saved, hasLength(2));
        expect(fake.saved.last, isNotNull);
      });
    });

    test('a timeline that could not be sent is sent again', () async {
      final (fake, service) = await platform();
      fake.failSaves = true;
      fakeAsync((async) {
        final c = containerFor(service);
        async.elapse(const Duration(seconds: 2));
        expect(fake.saved, isEmpty);
        fake.failSaves = false;
        c.invalidate(homeWidgetSyncProvider);
        c.read(homeWidgetSyncProvider);
        async.elapse(const Duration(seconds: 2));
        expect(fake.saved, hasLength(1));
      });
    });
  });
  // The app's own wiring (lib/app/app.dart): the links it opens, and the
  // timeline it sends again when the device's language changes.
  group('in the app', () {
    // Monday 12 October 2026, in the week of Noach.
    final monday = DateTime(2026, 10, 12, 10);
    const noach = '5787:2';
    const lechLecha = '5787:3';
    final mondayDate = LocalDate.fromDateTime(monday);

    /// Rishon and Sheni of Noach read: Continue leads to Shlishi.
    ProgressState twoRead() => ProgressState(weeks: {
          noach: WeekProgress(weekId: noach).withAliyah(0, mondayDate).withAliyah(1, mondayDate),
        });

    /// The app on the fake platform, launched by [launchedWith] if given.
    /// Taps are told apart by [now], which stands still unless a test moves
    /// it.
    Future<(GoRouter, FakeHomeWidget)> pump(
      WidgetTester tester, {
      AppSettings settings = const AppSettings(onboardingComplete: true, notificationPromptShown: true),
      ProgressState? progress,
      String? launchedWith,
      DateTime Function()? now,
    }) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fake = FakeHomeWidget()..launchedWith = launchedWith;
      final service = await HomeWidgetService.create(now: now ?? () => monday);
      final container = await pumpApp(
        tester,
        settings: settings,
        now: monday,
        progress: progress,
        overrides: [homeWidgetServiceProvider.overrideWithValue(service)],
      );
      return (container.read(routerProvider), fake);
    }

    /// Lets a page open and the reader load its text, whose spinner never
    /// settles, and the timeline be sent.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty && !tester.binding.hasScheduledFrame) break;
      }
      await tester.pumpAndSettle();
      await tester.pump(HomeWidgetService.throttle * 2);
    }

    String location(GoRouter router) => router.state.uri.toString();

    /// Goes back from the page on top, as its back button does, to Today.
    Future<void> expectBackToToday(WidgetTester tester, GoRouter router) async {
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(location(router), '/today');
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.byType(ReaderScreen), findsNothing);
    }

    testWidgets("the link that launched the app opens Continue's page over Today, once", (tester) async {
      final (router, fake) = await pump(tester, progress: twoRead(), launchedWith: WidgetLink.continueReading.uri.toString());
      await settle(tester);
      expect(location(router), '/read/$noach/2');
      expect(find.byType(ReaderScreen), findsOneWidget);

      // The same tap reported again as the app resumes opens nothing more.
      fake.tap(WidgetLink.continueReading.uri.toString());
      await settle(tester);
      await expectBackToToday(tester, router);
    });

    testWidgets('a tap while the app runs opens its page over Today, from wherever the app was', (tester) async {
      var now = monday;
      final (router, fake) = await pump(tester, progress: twoRead(), now: () => now);
      router.go('/settings/display');
      await settle(tester);

      fake.tap(WidgetLink.continueReading.uri.toString());
      await settle(tester);
      expect(location(router), '/read/$noach/2');
      await expectBackToToday(tester, router);

      router.go('/settings/display');
      await settle(tester);
      now = now.add(const Duration(minutes: 1));
      fake.tap(WidgetLink.today.uri.toString());
      await settle(tester);
      expect(location(router), '/today');
    });

    // A week later the app is still suspended, and hears of the tap before
    // it hears it has resumed: Continue opens the new week.
    testWidgets('a tap opens the week of the day it is tapped, without waiting for a resume', (tester) async {
      final (router, fake) = await pump(tester, progress: twoRead());
      TodayController.now = () => monday.add(const Duration(days: 7));
      fake.tap(WidgetLink.continueReading.uri.toString());
      await settle(tester);
      expect(location(router), '/read/$lechLecha/0');
      expect(tester.widget<ReaderScreen>(find.byType(ReaderScreen)).weekId, lechLecha);
    });

    testWidgets('before onboarding, taps open nothing', (tester) async {
      final (router, fake) = await pump(
        tester,
        settings: const AppSettings(),
        launchedWith: WidgetLink.continueReading.uri.toString(),
      );
      await settle(tester);
      expect(location(router), '/welcome');
      fake.tap(WidgetLink.today.uri.toString());
      await settle(tester);
      expect(location(router), '/welcome');
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(fake.saved, [null], reason: 'the widget is cleared');
    });

    // The app invalidates the sync when the device's language changes.
    testWidgets("sends the timeline again in the device's language when the app follows it", (tester) async {
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final (_, fake) = await pump(
        tester,
        settings: const AppSettings(onboardingComplete: true, notificationPromptShown: true, language: AppLanguage.system),
      );
      await settle(tester);
      expect(fake.lastTimeline['rtl'], isFalse);
      final sent = fake.saved.length;

      tester.platformDispatcher.localesTestValue = const [Locale('he', 'IL')];
      await settle(tester);
      expect(fake.saved, hasLength(sent + 1));
      expect(fake.lastTimeline['rtl'], isTrue);
      expect(((fake.lastTimeline['days'] as List).first as Map)['eyebrow'], 'פרשת השבוע');

      tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
      await settle(tester);
      expect(fake.lastTimeline['rtl'], isFalse);
    });
  });
}
