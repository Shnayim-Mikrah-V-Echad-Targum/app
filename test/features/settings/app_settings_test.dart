import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/core/calendar/city.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/data/models/parsha.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/features/progress/domain/streak_engine.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

class _FixedToday extends TodayController {
  _FixedToday(this.day);
  final LocalDate day;

  @override
  LocalDate build() => day;
}

void main() {
  test('settings round-trip through JSON', () {
    final s = const AppSettings().copyWith(
      readingSchedule: ReadingSchedule.israel,
      oneDayYomTov: false,
      theme: AppThemeMode.highContrastDark,
      readingScale: 2.5,
      secondReading: SecondReading.onkelosAndRashi,
      joinDate: LocalDate(2026, 10, 9),
      starterCatchUp: false,
      habitAnchor: HabitAnchor.shacharit,
      singleKeyShortcuts: false,
      cityOfferAnswered: true,
    );
    final back = AppSettings.fromJson(s.toJson());
    expect(back.toJson(), s.toJson());
    expect(back.starterCatchUp, isFalse);
    expect(back.singleKeyShortcuts, isFalse);
    expect(AppSettings.fromJson({}).singleKeyShortcuts, isTrue, reason: 'on unless turned off');
    expect(back.readingSchedule, ReadingSchedule.israel);
    expect(back.oneDayYomTov, isFalse);
    expect(back.habitAnchor, HabitAnchor.shacharit);
    expect(back.cityOfferAnswered, isTrue);
    expect(AppSettings.fromJson({}).cityOfferAnswered, isFalse, reason: 'offered until answered');
  });

  group('habit anchor', () {
    test('is saved by name, so it stays chosen whatever the language', () {
      for (final a in HabitAnchor.values) {
        final json = const AppSettings().copyWith(habitAnchor: a).toJson();
        expect(json['habitAnchor'], a.name);
        expect(AppSettings.fromJson(json).habitAnchor, a);
      }
      expect(const AppSettings().toJson()['habitAnchor'], isNull);
      expect(AppSettings.fromJson(const AppSettings().toJson()).habitAnchor, isNull);
    });

    test("saved as the chip's label by earlier versions, in English or Hebrew, is read as its anchor", () {
      AppSettings read(String label) => AppSettings.fromJson({'habitAnchor': label});
      expect(read('finish Shacharit').habitAnchor, HabitAnchor.shacharit);
      expect(read('eat breakfast').habitAnchor, HabitAnchor.breakfast);
      expect(read('start my commute').habitAnchor, HabitAnchor.commute);
      expect(read('finish dinner').habitAnchor, HabitAnchor.dinner);
      expect(read('get ready for bed').habitAnchor, HabitAnchor.bed);
      expect(read('אסיים שחרית').habitAnchor, HabitAnchor.shacharit);
      expect(read('אאכל ארוחת בוקר').habitAnchor, HabitAnchor.breakfast);
      expect(read('אצא לדרך').habitAnchor, HabitAnchor.commute);
      expect(read('אסיים ארוחת ערב').habitAnchor, HabitAnchor.dinner);
      expect(read('אתכונן לשינה').habitAnchor, HabitAnchor.bed);
      // And saved again by name.
      expect(read('finish Shacharit').toJson()['habitAnchor'], 'shacharit');
    });

    test('suggests a time of day that fits it', () {
      expect({for (final a in HabitAnchor.values) a: a.usualMinutes}, {
        HabitAnchor.shacharit: 7 * 60 + 30,
        HabitAnchor.breakfast: 7 * 60 + 30,
        HabitAnchor.commute: 8 * 60,
        HabitAnchor.dinner: 20 * 60,
        HabitAnchor.bed: 21 * 60 + 30,
      });
    });

    test("moves the daily reminder's time only while that is a suggestion", () {
      int move(int minutes, HabitAnchor? previous, HabitAnchor? next) =>
          HabitAnchor.reminderMinutes(minutes, previous: previous, next: next);
      const byDefault = 20 * 60;
      expect(const AppSettings().dailyReminderMinutes, byDefault);
      // The default, or the routine's own time, follows the routine chosen.
      expect(move(byDefault, null, HabitAnchor.shacharit), 7 * 60 + 30);
      expect(move(7 * 60 + 30, HabitAnchor.shacharit, HabitAnchor.bed), 21 * 60 + 30);
      expect(move(byDefault, HabitAnchor.bed, HabitAnchor.commute), 8 * 60);
      // A time of the reader's own stays.
      expect(move(6 * 60, null, HabitAnchor.dinner), 6 * 60);
      expect(move(6 * 60, HabitAnchor.shacharit, HabitAnchor.dinner), 6 * 60);
      expect(move(7 * 60 + 30, HabitAnchor.commute, HabitAnchor.bed), 7 * 60 + 30);
      // Cleared, the time stays.
      expect(move(7 * 60 + 30, HabitAnchor.shacharit, null), 7 * 60 + 30);
    });

    test('anything else is no anchor', () {
      for (final raw in ['after lunch', 'Shacharit', '', 3, true, <String, dynamic>{}]) {
        expect(AppSettings.fromJson({'habitAnchor': raw}).habitAnchor, isNull, reason: '$raw');
      }
    });
  });

  group('reading schedule and days of Yom Tov', () {
    test('settings saved with one Israel setting set both from it', () {
      final israel = AppSettings.fromJson({'israel': true});
      expect(israel.readingSchedule, ReadingSchedule.israel);
      expect(israel.oneDayYomTov, isTrue);
      final diaspora = AppSettings.fromJson({'israel': false});
      expect(diaspora.readingSchedule, ReadingSchedule.diaspora);
      expect(diaspora.oneDayYomTov, isFalse);
      final neither = AppSettings.fromJson({});
      expect(neither.readingSchedule, ReadingSchedule.diaspora);
      expect(neither.oneDayYomTov, isFalse);
    });

    test('the two settings take precedence over the old one', () {
      final s = AppSettings.fromJson({'readingSchedule': 'israel', 'oneDayYomTov': false, 'israel': false});
      expect(s.readingSchedule, ReadingSchedule.israel);
      expect(s.oneDayYomTov, isFalse);
      final unknown = AppSettings.fromJson({'readingSchedule': 'mars', 'oneDayYomTov': 'yes', 'israel': true});
      expect(unknown.readingSchedule, ReadingSchedule.israel, reason: 'an unknown value falls back to the old setting');
      expect(unknown.oneDayYomTov, isTrue);
    });

    test('older versions still find the reading schedule', () {
      final json = const AppSettings(readingSchedule: ReadingSchedule.israel).toJson();
      expect(json['israel'], isTrue);
      expect(const AppSettings(oneDayYomTov: true).toJson()['israel'], isFalse);
    });

    test('a location sets both; a visitor keeps them apart', () {
      const s = AppSettings();
      final israel = s.locatedIn(ReadingSchedule.israel);
      expect((israel.readingSchedule, israel.oneDayYomTov), (ReadingSchedule.israel, true));
      expect(israel.readingAndYomTovDiffer, isFalse);
      final diaspora = israel.locatedIn(ReadingSchedule.diaspora);
      expect((diaspora.readingSchedule, diaspora.oneDayYomTov), (ReadingSchedule.diaspora, false));
      expect(diaspora.readingAndYomTovDiffer, isFalse);
      expect(s.copyWith(readingSchedule: ReadingSchedule.israel).readingAndYomTovDiffer, isTrue);
      expect(s.copyWith(oneDayYomTov: true).readingAndYomTovDiffer, isTrue);
    });
  });

  test('settings saved before the starter plan existed turn it on', () {
    final s = AppSettings.fromJson({'joinDate': LocalDate(2026, 10, 9).rd});
    expect(s.starterCatchUp, isTrue);
    expect(s.joinDate, LocalDate(2026, 10, 9));
  });

  test('unknown or out-of-range values fall back safely', () {
    final s = AppSettings.fromJson({
      'theme': 'neon',
      'readingScale': 99,
      'israel': 'yes',
      'method': null,
    });
    expect(s.theme, AppThemeMode.system);
    expect(s.readingScale, kMaxReadingScale);
    expect(s.readingSchedule, ReadingSchedule.diaspora);
    expect(s.oneDayYomTov, isFalse);
    expect(s.method, ReadingMethod.verseByVerse);
  });

  group('repeating the last verse', () {
    test('follows the custom until the reader sets it: Chabad does not repeat it', () {
      const s = AppSettings();
      expect(s.repeatLastVerse, isTrue);
      final chabad = s.withNusach(HaftarahNusach.chabad);
      expect((chabad.nusach, chabad.repeatLastVerse), (HaftarahNusach.chabad, false));
      expect(chabad.repeatLastVerseTouched, isFalse);
      expect(chabad.withNusach(HaftarahNusach.sephardi).repeatLastVerse, isTrue);
      expect(s.withNusach(HaftarahNusach.sephardi).repeatLastVerse, isTrue);
    });

    test("once the reader sets it, keeps the reader's choice whatever the custom", () {
      final on = const AppSettings().withNusach(HaftarahNusach.chabad).withRepeatLastVerse(true);
      expect((on.repeatLastVerse, on.repeatLastVerseTouched), (true, true));
      expect(on.withNusach(HaftarahNusach.ashkenazi).withNusach(HaftarahNusach.chabad).repeatLastVerse, isTrue);
      final off = const AppSettings().withRepeatLastVerse(false);
      expect(off.withNusach(HaftarahNusach.chabad).withNusach(HaftarahNusach.ashkenazi).repeatLastVerse, isFalse);
    });

    test('remembers whether the reader set it', () {
      final touched = const AppSettings().withRepeatLastVerse(true);
      expect(AppSettings.fromJson(touched.toJson()).repeatLastVerseTouched, isTrue);
      expect(AppSettings.fromJson(const AppSettings().toJson()).repeatLastVerseTouched, isFalse);
      // Saved before this was kept: off was the reader's doing, on the default.
      expect(AppSettings.fromJson({'repeatLastVerse': false}).repeatLastVerseTouched, isTrue);
      expect(AppSettings.fromJson({'repeatLastVerse': true}).repeatLastVerseTouched, isFalse);
      expect(AppSettings.fromJson({}).repeatLastVerseTouched, isFalse);
    });

    test('saved for Chabad before it was kept, follows the custom', () {
      // On only because that was the default: Chabad's custom is not to.
      final chabad = AppSettings.fromJson({'nusach': 'chabad', 'repeatLastVerse': true});
      expect(chabad.repeatLastVerse, isFalse);
      expect(chabad.repeatLastVerseTouched, isFalse);
      // Set by the reader, it stays as set.
      final set = AppSettings.fromJson({'nusach': 'chabad', 'repeatLastVerse': true, 'repeatLastVerseTouched': true});
      expect(set.repeatLastVerse, isTrue);
      final off = AppSettings.fromJson({'nusach': 'ashkenazi', 'repeatLastVerse': false});
      expect((off.repeatLastVerse, off.repeatLastVerseTouched), (false, true));
      // And the round trip keeps either.
      for (final s in [const AppSettings().withNusach(HaftarahNusach.chabad), set, off]) {
        expect(AppSettings.fromJson(s.toJson()).repeatLastVerse, s.repeatLastVerse);
      }
    });
  });

  test('copyWith can clear nullable fields', () {
    final s = const AppSettings(habitAnchor: HabitAnchor.bed, city: _jerusalem).copyWith(habitAnchor: null, city: null);
    expect(s.habitAnchor, isNull);
    expect(s.city, isNull);
  });

  group('city', () {
    test('none until one is chosen, also in settings saved before it existed', () {
      expect(const AppSettings().city, isNull);
      expect(AppSettings.fromJson(const AppSettings().toJson()..remove('city')).city, isNull);
    });

    test('round-trips through JSON, whole, so its times need no list', () {
      final back = AppSettings.fromJson(
        jsonDecode(jsonEncode(const AppSettings(city: _jerusalem).toJson())) as Map<String, dynamic>,
      );
      expect(back.city, _jerusalem);
      expect(back.city!.candleMinutes, 40);
      expect(back.city!.name(hebrew: true), 'ירושלים');
    });

    test('a city that can\'t be read is forgotten, and the rest of the settings kept', () {
      for (final city in [
        'Jerusalem',
        {..._jerusalem.toJson(), 'lat': 'north'},
        {..._jerusalem.toJson(), 'tz': null},
        {..._jerusalem.toJson(), 'candleMinutes': 400},
        {..._jerusalem.toJson()}..remove('name_en'),
      ]) {
        final s = AppSettings.fromJson({...const AppSettings(theme: AppThemeMode.dark).toJson(), 'city': city});
        expect(s.city, isNull, reason: '$city');
        expect(s.theme, AppThemeMode.dark);
      }
    });

    test('isn\'t part of how weeks are planned', () {
      const before = AppSettings();
      expect(before.copyWith(city: _jerusalem).planSettings.sameSettingsAs(before.planSettings), isTrue);
    });
  });

  group('plan history', () {
    final joined = LocalDate(2026, 9, 1);
    final wed = LocalDate(2026, 10, 14);
    final thu = LocalDate(2026, 10, 15);
    List<(LocalDate, ReadingPlanType)> plans(AppSettings s) => [for (final e in s.planHistory) (e.from, e.plan)];
    AppSettings change(AppSettings before, LocalDate on, AppSettings Function(AppSettings) f) =>
        f(before).recordingPlanChange(before, on);

    test('settings saved before it existed apply to every day', () {
      final s = AppSettings.fromJson({'plan': 'erevShabbat', 'lateWindow': 'wednesday', 'joinDate': joined.rd});
      expect(s.planHistory, isEmpty);
      for (final day in [PlanSettingsEntry.earliest, joined, wed]) {
        expect(s.settingsAt(day).plan, ReadingPlanType.erevShabbat);
        expect(s.settingsAt(day).lateWindow, LateWindow.wednesday);
      }
    });

    test('the first change keeps the settings before it for the days before', () {
      final before = AppSettings(joinDate: joined, plan: ReadingPlanType.erevShabbat);
      final after = change(before, wed, (s) => s.copyWith(plan: ReadingPlanType.aliyahPerDay));
      expect(plans(after), [(joined, ReadingPlanType.erevShabbat), (wed, ReadingPlanType.aliyahPerDay)]);
      expect(after.settingsAt(wed.addDays(-1)).plan, ReadingPlanType.erevShabbat);
      expect(after.settingsAt(LocalDate(2026, 1, 1)).plan, ReadingPlanType.erevShabbat,
          reason: 'the earliest entry also covers the days before it');
      expect(after.settingsAt(wed).plan, ReadingPlanType.aliyahPerDay);
      expect(after.settingsAt(wed.addDays(100)).plan, ReadingPlanType.aliyahPerDay);
    });

    test('a later change adds an entry; another the same day replaces it', () {
      var s = AppSettings(joinDate: joined);
      s = change(s, wed, (s) => s.copyWith(plan: ReadingPlanType.erevShabbat));
      s = change(s, thu, (s) => s.copyWith(plan: ReadingPlanType.sheviiOnShabbat));
      s = change(s, thu, (s) => s.copyWith(lateWindow: LateWindow.none));
      expect(plans(s), [
        (joined, ReadingPlanType.aliyahPerDay),
        (wed, ReadingPlanType.erevShabbat),
        (thu, ReadingPlanType.sheviiOnShabbat),
      ]);
      expect(s.settingsAt(thu).lateWindow, LateWindow.none);
      expect(s.settingsAt(wed).lateWindow, LateWindow.tuesday);
    });

    test('changing back the same day undoes the change', () {
      final before = AppSettings(joinDate: joined, haftarahRequired: true);
      var s = change(before, wed, (s) => s.copyWith(cholHamoedQuiet: true));
      s = change(s, wed, (s) => s.copyWith(cholHamoedQuiet: false));
      expect(s.planHistory, hasLength(1));
      expect(s.settingsAt(wed).sameSettingsAs(before.planSettings), isTrue);
    });

    test('a change on the day of joining applies from the start', () {
      final s = change(AppSettings(joinDate: wed), wed, (s) => s.copyWith(plan: ReadingPlanType.erevShabbat));
      expect(plans(s), [(wed, ReadingPlanType.erevShabbat)]);
      expect(s.settingsAt(joined).plan, ReadingPlanType.erevShabbat);
    });

    test('before joining, nothing is recorded', () {
      final s = change(const AppSettings(), wed, (s) => s.copyWith(plan: ReadingPlanType.erevShabbat));
      expect(s.planHistory, isEmpty);
      expect(s.settingsAt(joined).plan, ReadingPlanType.erevShabbat);
    });

    test('the haftarah counts only while it is shown', () {
      const s = AppSettings(haftarahRequired: true);
      expect(s.planSettings.haftarahRequired, isTrue);
      expect(s.copyWith(haftarahEnabled: false).planSettings.haftarahRequired, isFalse);
      expect(s.copyWith(haftarahRequired: false).planSettings.haftarahRequired, isFalse);
    });

    test('round-trips through JSON, oldest first, skipping entries that cannot be read', () {
      var s = AppSettings(joinDate: joined);
      s = change(s, wed, (s) => s.copyWith(haftarahRequired: true, tishaBavQuiet: false));
      final back = AppSettings.fromJson(s.toJson());
      expect(back.toJson(), s.toJson());
      expect(back.settingsAt(wed).haftarahRequired, isTrue);
      expect(back.settingsAt(wed).tishaBavQuiet, isFalse);
      expect(back.settingsAt(joined).haftarahRequired, isFalse);

      final json = s.toJson();
      final read = AppSettings.fromJson({
        ...json,
        'planHistory': [
          (json['planHistory'] as List)[1],
          {'plan': 'erevShabbat'}, // no day
          'nonsense',
          {...(json['planHistory'] as List)[0] as Map<String, dynamic>, 'lateWindow': 'friday'},
        ],
      });
      expect(read.planHistory.map((e) => e.from), [joined, wed]);
      expect(read.planHistory.first.lateWindow, LateWindow.tuesday, reason: 'an unknown value falls back');
      expect(AppSettings.fromJson({...json, 'planHistory': 'nonsense'}).planHistory, isEmpty);
    });
  });

  group('SettingsController', () {
    final joined = LocalDate(2026, 9, 1);
    final tue = LocalDate(2026, 10, 13);

    Future<(ProviderContainer, SharedPreferences)> containerWith(AppSettings settings) async {
      SharedPreferences.setMockInitialValues({SettingsController.storageKey: jsonEncode(settings.toJson())});
      final prefs = await SharedPreferences.getInstance();
      final clock = TodayController.now;
      // Wednesday, at 2 a.m.: still Tuesday's reading day.
      TodayController.now = () => DateTime(2026, 10, 14, 2);
      final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(() {
        container.dispose();
        TodayController.now = clock;
      });
      return (container, prefs);
    }

    test('records a change to the plan settings from the reading day, and saves it', () async {
      final (c, prefs) = await containerWith(AppSettings(joinDate: joined));
      c.read(settingsProvider.notifier).update((s) => s.copyWith(plan: ReadingPlanType.erevShabbat));
      final s = c.read(settingsProvider);
      expect(s.planHistory.map((e) => (e.from, e.plan)), [
        (joined, ReadingPlanType.aliyahPerDay),
        (tue, ReadingPlanType.erevShabbat),
      ]);
      await c.read(settingsProvider.notifier).flush();
      final saved = jsonDecode(prefs.getString(SettingsController.storageKey)!) as Map<String, dynamic>;
      expect(AppSettings.fromJson(saved).toJson(), s.toJson());
    });

    test('records a change made after reading today from tomorrow, so that today keeps its plan', () async {
      final (c, _) = await containerWith(AppSettings(joinDate: joined));
      c.read(progressProvider.notifier).markAliyah('5787:2', 2, tue);
      c.read(settingsProvider.notifier).update((s) => s.copyWith(plan: ReadingPlanType.erevShabbat));
      expect(c.read(settingsProvider).planHistory.map((e) => (e.from, e.plan)), [
        (joined, ReadingPlanType.aliyahPerDay),
        (tue.addDays(1), ReadingPlanType.erevShabbat),
      ]);
    });

    test('a change made after reading today takes nothing from the days on track', () async {
      // Noach 5787, an aliyah a day from Sunday; read through Tuesday.
      final sunday = LocalDate(2026, 10, 11);
      var noach = WeekProgress(weekId: '5787:2');
      for (var a = 0; a < 3; a++) {
        noach = noach.withAliyah(a, sunday.addDays(a));
      }
      SharedPreferences.setMockInitialValues({
        SettingsController.storageKey: jsonEncode(AppSettings(joinDate: sunday).toJson()),
        ProgressController.storageKey: jsonEncode(ProgressState(weeks: {'5787:2': noach}).toJson()),
      });
      final prefs = await SharedPreferences.getInstance();
      final clock = TodayController.now;
      TodayController.now = () => DateTime(2026, 10, 13, 21);
      final c = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        todayProvider.overrideWith(() => _FixedToday(tue)),
      ]);
      addTearDown(() {
        c.dispose();
        TodayController.now = clock;
      });
      expect(c.read(streakSummaryProvider).daysOnTrack, 3);

      // On Tuesday evening, everything moves to Friday.
      c.read(settingsProvider.notifier).update((s) => s.copyWith(plan: ReadingPlanType.erevShabbat));
      final summary = c.read(streakSummaryProvider);
      expect(summary.days[tue], DayStatus.kept, reason: 'Tuesday keeps the aliyah it was read by');
      expect(summary.daysOnTrack, 3);
      expect(c.read(plannerProvider).planFor(c.read(currentWeekProvider)).days.map((p) => '${p.date} ${p.aliyot}'), [
        '2026-10-11 [0]',
        '2026-10-12 [1]',
        '2026-10-13 [2]',
        '2026-10-16 [3, 4, 5, 6]',
      ]);
    });

    test('leaves the history alone for any other change', () async {
      final (c, _) = await containerWith(AppSettings(joinDate: joined));
      c.read(settingsProvider.notifier).update((s) => s.copyWith(theme: AppThemeMode.dark, haftarahEnabled: false));
      expect(c.read(settingsProvider).planHistory, isEmpty, reason: 'the haftarah was not required');
    });

    test('restoring a backup takes its history as it is', () async {
      final (c, _) = await containerWith(AppSettings(joinDate: joined));
      final backedUp = AppSettings(joinDate: joined, plan: ReadingPlanType.erevShabbat);
      final backup = backedUp
          .copyWith(plan: ReadingPlanType.sheviiOnShabbat)
          .recordingPlanChange(backedUp, LocalDate(2026, 10, 1));
      c.read(settingsProvider.notifier).replace(backup);
      expect(c.read(settingsProvider).toJson(), backup.toJson());
      expect(c.read(settingsProvider).settingsAt(joined).plan, ReadingPlanType.erevShabbat);
    });
  });

  test('interface fonts keep their persisted names, and the device font round-trips', () {
    expect(UiFont.values.map((f) => f.name), ['standard', 'atkinson', 'lexend', 'openDyslexic', 'system']);
    expect(AppSettings.fromJson({'uiFont': 'standard'}).uiFont, UiFont.standard);
    expect(AppSettings.fromJson({'uiFont': 'lexend'}).uiFont, UiFont.lexend);
    final device = const AppSettings(uiFont: UiFont.system);
    expect(AppSettings.fromJson(device.toJson()).uiFont, UiFont.system);
  });
}

const _jerusalem = City(
  id: 281184,
  nameEn: 'Jerusalem',
  nameHe: 'ירושלים',
  countryCode: 'IL',
  latitude: 31.769,
  longitude: 35.2163,
  timeZone: 'Asia/Jerusalem',
  candleMinutes: 40,
);
