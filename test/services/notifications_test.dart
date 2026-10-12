import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/core/calendar/city.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/core/calendar/zmanim.dart';
import 'package:shnayim_mikra/data/parsha_repository.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/l10n/app_localizations.dart';
import 'package:shnayim_mikra/services/notifications.dart';
import 'package:shnayim_mikra/services/reminder_planner.dart';
import 'package:timezone/timezone.dart' as tz;

import '../helpers.dart';

typedef _Scheduled = ({
  tz.TZDateTime date,
  String? title,
  String? body,
  NotificationDetails details,
  String? payload,
  AndroidScheduleMode mode,
});

/// Records what is scheduled. Every call yields to the event loop first, as
/// a platform channel does, so overlapping calls interleave.
class _FakePlugin extends Fake implements FlutterLocalNotificationsPlugin {
  final scheduled = <int, _Scheduled>{};
  final android = _FakeAndroid();
  int cancels = 0;
  int schedules = 0;

  /// The ids of reminders the platform refuses.
  final throwFor = <int>{};

  /// Whether the next [cancelAll] fails, as a platform channel can.
  bool failNextCancel = false;

  @override
  Future<void> cancelAll() async {
    await Future<void>.delayed(Duration.zero);
    if (failNextCancel) {
      failNextCancel = false;
      throw PlatformException(code: 'error');
    }
    cancels++;
    scheduled.clear();
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title,
    String? body,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    await Future<void>.delayed(Duration.zero);
    if (throwFor.contains(id)) throw ArgumentError.value(id, 'id', 'refused');
    schedules++;
    scheduled[id] = (
      date: scheduledDate,
      title: title,
      body: body,
      details: notificationDetails,
      payload: payload,
      mode: androidScheduleMode,
    );
  }

  @override
  T? resolvePlatformSpecificImplementation<T extends FlutterLocalNotificationsPlatform>() =>
      android is T ? android as T : null;
}

class _FakeAndroid extends Fake implements AndroidFlutterLocalNotificationsPlugin {
  final channels = <String, AndroidNotificationChannel>{};

  /// What the device answers when asked whether exact alarms are allowed:
  /// yes before Android 12, and from it no, the permission not being
  /// declared. Null throws, as a platform that can't say.
  bool? exact = false;
  int exactAsked = 0;

  @override
  Future<bool?> canScheduleExactNotifications() async {
    exactAsked++;
    return exact ?? (throw PlatformException(code: 'unavailable'));
  }

  @override
  Future<void> createNotificationChannel(AndroidNotificationChannel notificationChannel) async {
    channels[notificationChannel.id] = notificationChannel;
  }
}

/// Midnight before the plans the tests schedule, which begin on 11 October
/// 2026: the time it is for a service, unless a test says otherwise.
DateTime _beforePlans() => DateTime(2026, 10, 11);

/// A service scheduling through [plugin], whose time zones (UTC, set in
/// setUpAll) need no loading, and for which it is [now].
NotificationService _service(_FakePlugin plugin, {DateTime Function() now = _beforePlans}) =>
    NotificationService.forTesting(plugin, loadTimeZones: () async {}, now: now);

/// A service that counts how often reminders are handed to it, and keeps
/// the last of them, how they were worded and what it scheduled.
class _CountingService extends NotificationService {
  _CountingService._(this.plugin) : super.forTesting(plugin, loadTimeZones: () async => tz.setLocalLocation(tz.UTC));
  _CountingService() : this._(_FakePlugin());

  final _FakePlugin plugin;
  int reschedules = 0;
  List<PlannedReminder> reminders = const [];
  ReminderCopy Function(PlannedReminder)? describe;
  Future<void> done = Future.value();

  @override
  Future<void> reschedule(
      List<PlannedReminder> reminders, AppLocalizations l, ReminderCopy Function(PlannedReminder) describe) {
    reschedules++;
    this.reminders = reminders;
    this.describe = describe;
    return done = super.reschedule(reminders, l, describe);
  }
}

/// Monday of Noach 5787.
final _monday = LocalDate(2026, 10, 12);

class _Monday extends TodayController {
  @override
  LocalDate build() => _monday;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ParshaRepository repo;
  setUpAll(() async {
    tz.setLocalLocation(tz.UTC);
    repo = await ParshaRepository.load();
  });

  const planner = ReadingPlanner(schedule: ParshaSchedule(israel: false));
  const all = ReminderPrefs(daily: true, erevShabbat: true, checkIn: true);
  final en = lookupAppLocalizations(const Locale('en'));
  final he = lookupAppLocalizations(const Locale('he'));

  List<PlannedReminder> planFrom(DateTime now, {ReminderPrefs prefs = all}) => planReminders(
        prefs: prefs,
        planner: planner,
        progressOf: (id) => WeekProgress(weekId: id),
        now: now,
        today: LocalDate.fromDateTime(now),
      );

  ReminderCopy Function(PlannedReminder) copyIn(AppLocalizations l) =>
      (r) => reminderCopy(r, l: l, repo: repo, ashkenaziNames: false);

  Set<int> ids(List<PlannedReminder> plan) => {for (final r in plan) r.id};

  Future<ProviderContainer> container(AppSettings settings, {NotificationService? service}) async {
    SharedPreferences.setMockInitialValues({SettingsController.storageKey: jsonEncode(settings.toJson())});
    final prefs = await SharedPreferences.getInstance();
    final repo = await loadRepo();
    final c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      parshaRepositoryProvider.overrideWithValue(repo),
      todayProvider.overrideWith(_Monday.new),
      if (service != null) notificationServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  group('rescheduling', () {
    test('two quick calls leave exactly the second plan scheduled', () async {
      final plugin = _FakePlugin();
      final service = _service(plugin);
      final first = planFrom(DateTime(2026, 10, 11, 8), prefs: const ReminderPrefs(daily: true));
      final second = planFrom(DateTime(2026, 10, 12, 8), prefs: const ReminderPrefs(erevShabbat: true));
      expect(ids(second).containsAll(ids(first)), isFalse);

      final a = service.reschedule(first, en, copyIn(en));
      final b = service.reschedule(second, en, copyIn(en));
      await Future.wait([a, b]);

      expect(plugin.scheduled.keys.toSet(), ids(second));
    });

    test('a call made while another is scheduling waits for it to finish', () async {
      final plugin = _FakePlugin();
      final service = _service(plugin);
      final first = planFrom(DateTime(2026, 10, 11, 8), prefs: const ReminderPrefs(daily: true));
      final second = planFrom(DateTime(2026, 10, 12, 8), prefs: const ReminderPrefs(erevShabbat: true));

      final a = service.reschedule(first, en, copyIn(en));
      // Let the first get partway through scheduling.
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(plugin.cancels, 1);
      expect(plugin.scheduled.length, inExclusiveRange(0, first.length));
      final b = service.reschedule(second, en, copyIn(en));
      await Future.wait([a, b]);

      expect(plugin.cancels, 2);
      expect(plugin.scheduled.keys.toSet(), ids(second));
    });

    test('an unchanged plan is not scheduled again, but a change of language is', () async {
      final plugin = _FakePlugin();
      final service = _service(plugin);
      final plan = planFrom(DateTime(2026, 10, 11, 8));

      await service.reschedule(plan, en, copyIn(en));
      await service.reschedule(plan, en, copyIn(en));
      expect(plugin.cancels, 1);

      await service.reschedule(plan, he, copyIn(he));
      expect(plugin.cancels, 2);
      expect(plugin.android.channels['daily']!.name, he.notifChannelDaily);
    });

    test('a reminder the platform refuses costs only itself, and the plan is tried again', () async {
      final plan = planFrom(DateTime(2026, 10, 11, 8));
      final plugin = _FakePlugin()..throwFor.add(plan.first.id);
      final service = _service(plugin);

      await service.reschedule(plan, en, copyIn(en));
      expect(plugin.scheduled.keys.toSet(), ids(plan.sublist(1)), reason: 'the rest are still scheduled');

      plugin.throwFor.clear();
      await service.reschedule(plan, en, copyIn(en));
      expect(plugin.cancels, 2, reason: 'the same plan, once it failed, is scheduled again');
      expect(plugin.scheduled.keys.toSet(), ids(plan));
    });

    test('a plan refused in part, then the plan before it again, schedules that plan whole', () async {
      final at20 = planFrom(DateTime(2026, 10, 11, 8), prefs: const ReminderPrefs(daily: true));
      final at21 = planFrom(DateTime(2026, 10, 11, 8), prefs: const ReminderPrefs(daily: true, dailyMinutes: 21 * 60));
      expect(ids(at21), ids(at20), reason: 'the same days, at other times');
      final plugin = _FakePlugin();
      final service = _service(plugin);
      await service.reschedule(at20, en, copyIn(en));

      // The reader moves the time to 21:00, and the platform refuses one.
      plugin.throwFor.add(at21.first.id);
      await service.reschedule(at21, en, copyIn(en));
      expect(plugin.scheduled.keys.toSet(), ids(at21.sublist(1)));

      // Then back to 20:00: the plan scheduled before, but no longer what
      // the platform holds.
      plugin.throwFor.clear();
      await service.reschedule(at20, en, copyIn(en));
      expect(plugin.scheduled.keys.toSet(), ids(at20));
      for (final r in at20) {
        expect(plugin.scheduled[r.id]!.date, tz.TZDateTime.from(r.localDateTime, tz.local), reason: '${r.id}');
      }
    });

    test('a plan that could not be scheduled at all is scheduled on the next call', () async {
      final plan = planFrom(DateTime(2026, 10, 11, 8));
      final plugin = _FakePlugin()..failNextCancel = true;
      final service = _service(plugin);

      await service.reschedule(plan, en, copyIn(en));
      expect(plugin.scheduled, isEmpty);
      await service.reschedule(plan, en, copyIn(en));
      expect(plugin.scheduled.keys.toSet(), ids(plan));
    });

    test('a reminder refused in the middle of the plan leaves those after it scheduled', () async {
      final plan = planFrom(DateTime(2026, 10, 11, 8));
      final refused = plan[plan.length ~/ 2];
      final plugin = _FakePlugin()..throwFor.add(refused.id);

      await _service(plugin).reschedule(plan, en, copyIn(en));
      expect(plugin.scheduled.keys.toSet(), ids(plan)..remove(refused.id));
    });

    test('a reminder that comes due while it is scheduled is passed over, and the rest are scheduled', () async {
      final plan = planFrom(DateTime(2026, 10, 11, 8));
      final plugin = _FakePlugin();
      // Two seconds before the first: too late to schedule it.
      final service = _service(plugin, now: () => plan.first.localDateTime.subtract(const Duration(seconds: 2)));

      await service.reschedule(plan, en, copyIn(en));
      expect(plugin.scheduled.keys.toSet(), ids(plan.sublist(1)));

      // Passed over, it is no failure: the plan isn't scheduled again.
      await service.reschedule(plan, en, copyIn(en));
      expect(plugin.cancels, 1);
    });

    test('channels are created with names and descriptions in the app language', () async {
      final plugin = _FakePlugin();
      await _service(plugin).reschedule(const [], he, copyIn(he));

      final channels = plugin.android.channels;
      expect(channels.keys, unorderedEquals(['daily', 'erev_shabbat', 'check_in']));
      expect(
        (channels['daily']!.name, channels['daily']!.description),
        (he.notifChannelDaily, he.notifChannelDailyDesc),
      );
      expect(
        (channels['erev_shabbat']!.name, channels['erev_shabbat']!.description),
        (he.notifChannelFriday, he.notifChannelErevShabbatDesc),
      );
      expect(
        (channels['check_in']!.name, channels['check_in']!.description),
        (he.notifChannelCheckIn, he.notifChannelCheckInDesc),
      );
    });

    test('each reminder has the status-bar glyph, brand colour, reminder category and expandable text', () async {
      final plugin = _FakePlugin();
      final plan = planFrom(DateTime(2026, 10, 11, 8));
      await _service(plugin).reschedule(plan, en, copyIn(en));

      expect(plugin.scheduled, hasLength(plan.length));
      for (final r in plan) {
        final s = plugin.scheduled[r.id]!;
        final android = s.details.android!;
        expect(android.icon, 'ic_stat_reminder', reason: '$r');
        expect(android.color, const Color(0xFF1D3F75));
        expect(android.category, AndroidNotificationCategory.reminder);
        expect(android.channelDescription, isNotEmpty);
        expect((android.styleInformation! as BigTextStyleInformation).bigText, s.body);
        expect(s.details.iOS!.threadIdentifier, 'reminders');
        expect(s.payload, reminderRoute(r));
        final channel = switch (r.kind) {
          ReminderKind.daily => 'daily',
          ReminderKind.erevShabbat => 'erev_shabbat',
          ReminderKind.checkIn || ReminderKind.paused => 'check_in',
        };
        expect(android.channelId, channel);
      }
    });
  });

  group('on Android, reminders are scheduled', () {
    test('exactly where exact alarms need no permission, before Android 12', () async {
      final plugin = _FakePlugin()..android.exact = true;
      final plan = planFrom(DateTime(2026, 10, 11, 8));
      await _service(plugin).reschedule(plan, en, copyIn(en));
      expect({for (final s in plugin.scheduled.values) s.mode}, {AndroidScheduleMode.exactAllowWhileIdle});
    });

    test('inexactly from Android 12, where they need one, and the planner allows for an hour late', () async {
      final plugin = _FakePlugin()..android.exact = false;
      final service = _service(plugin);
      final plan = planFrom(DateTime(2026, 10, 11, 8));
      await service.reschedule(plan, en, copyIn(en));
      expect({for (final s in plugin.scheduled.values) s.mode}, {AndroidScheduleMode.inexactAllowWhileIdle});

      // Asked once.
      await service.reschedule(plan, he, copyIn(he));
      expect(plugin.android.exactAsked, 1);
    });

    test('inexactly where the device can\'t say', () async {
      final plugin = _FakePlugin()..android.exact = null;
      final plan = planFrom(DateTime(2026, 10, 11, 8));
      await _service(plugin).reschedule(plan, en, copyIn(en));
      expect(plugin.scheduled, hasLength(plan.length));
      expect({for (final s in plugin.scheduled.values) s.mode}, {AndroidScheduleMode.inexactAllowWhileIdle});
    });
  });

  group("the device's notification settings", () {
    const channel = MethodChannel('com.spencerccf.app_settings/methods');
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    test('can be opened on Android, iOS and macOS, where notifications can be refused', () {
      for (final platform in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          _service(_FakePlugin()).canOpenSystemSettings,
          {TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS}.contains(platform),
          reason: '$platform',
        );
      }
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(NotificationService.disabled().canOpenSystemSettings, isFalse, reason: 'nothing to allow there');
    });

    test("open at the app's notifications, and a platform that can't open them is no error", () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      await _service(_FakePlugin()).openSystemSettings();
      expect(calls.single.method, 'openSettings');
      expect((calls.single.arguments as Map)['type'], 'notification');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      await _service(_FakePlugin()).openSystemSettings();
    });
  });

  group('the time zones', () {
    late List<PlannedReminder> reminders;

    setUpAll(() => reminders = planFrom(DateTime(2026, 10, 11, 8), prefs: const ReminderPrefs(daily: true)));

    test('are never loaded without a reminder to schedule', () async {
      var loads = 0;
      final plugin = _FakePlugin();
      final service = NotificationService.forTesting(plugin, loadTimeZones: () async => loads++, now: _beforePlans);
      await service.reschedule(reminders, en, copyIn(en));
      await service.reschedule(const [], en, copyIn(en));
      expect(loads, 1, reason: 'once, for the first reminders');
      expect(plugin.cancels, 2, reason: 'clearing the reminders needs no time zones');

      final none = NotificationService.forTesting(_FakePlugin(), loadTimeZones: () async => loads++, now: _beforePlans);
      await none.reschedule(const [], en, copyIn(en));
      expect(loads, 1);
    });

    test('are waited for before scheduling', () async {
      final loaded = Completer<void>();
      final plugin = _FakePlugin();
      final service = NotificationService.forTesting(plugin, loadTimeZones: () => loaded.future, now: _beforePlans);
      final done = service.reschedule(reminders, en, copyIn(en));
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect((plugin.cancels, plugin.schedules), (0, 0));
      loaded.complete();
      await done;
      expect(plugin.cancels, 1);
      expect(plugin.scheduled.keys.toSet(), ids(reminders));
    });

    test('a call taken over while it waited for them schedules nothing', () async {
      final loaded = Completer<void>();
      final plugin = _FakePlugin();
      final service = NotificationService.forTesting(plugin, loadTimeZones: () => loaded.future, now: _beforePlans);
      final first = service.reschedule(reminders, en, copyIn(en));
      // Let the first start waiting for the time zones.
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      final second = service.reschedule(reminders.sublist(0, 1), en, copyIn(en));
      loaded.complete();
      await Future.wait([first, second]);
      expect(plugin.cancels, 1);
      expect(plugin.schedules, 1, reason: 'only the later call’s one reminder');
      expect(plugin.scheduled.keys.toSet(), ids(reminders.sublist(0, 1)));
    });
  });

  group('the scheduler', () {
    late ProviderContainer c;
    late _CountingService service;

    setUp(() async {
      service = _CountingService();
      c = await container(
        AppSettings(onboardingComplete: true, dailyReminder: true, joinDate: LocalDate(2026, 9, 1)),
        service: service,
      );
      c.listen(reminderSchedulerProvider, (_, _) {});
      expect(service.reschedules, 1);
    });

    void change(AppSettings Function(AppSettings s) update) {
      c.read(settingsProvider.notifier).update(update);
      c.read(reminderSchedulerProvider);
    }

    test('passes over a saved place, and settings that reminders don’t use', () {
      final progress = c.read(progressProvider.notifier);
      for (var verse = 1; verse <= 5; verse++) {
        progress.savePosition('5787:2', 0, [verse, verse, verse]);
        c.read(reminderSchedulerProvider);
      }
      change((s) => s.copyWith(theme: AppThemeMode.dark));
      change((s) => s.copyWith(readingScale: 1.4, uiFont: UiFont.lexend, showTranslation: true));
      expect(service.reschedules, 1);
    });

    test('plans again when the reading log changes', () {
      c.read(progressProvider.notifier).markUnit('5787:2', 0, ReadingPass.mikra1, _monday);
      c.read(reminderSchedulerProvider);
      expect(service.reschedules, 2);
    });

    test("names the reader's routine in the daily reminders it schedules, and leaves it out once cleared", () async {
      /// The bodies of the daily reminders scheduled, and of [day]'s worded
      /// as the scheduler words them, whatever the clock says is past.
      Future<List<String?>> bodies() async {
        await service.done;
        final scheduled = [
          for (final r in service.reminders)
            if (r.kind == ReminderKind.daily) service.plugin.scheduled[r.id]!.body,
        ];
        final week = planner.planFor(planner.schedule.weekFor(_monday));
        final day = PlannedReminder(kind: ReminderKind.daily, date: _monday, minutes: 20 * 60, plan: week, aliyot: [0]);
        return [...scheduled, service.describe!(day).body];
      }

      change((s) => s.copyWith(habitAnchor: HabitAnchor.dinner));
      expect(await bodies(), everyElement(endsWith(' · After dinner — your time for the parsha.')));

      change((s) => s.copyWith(language: AppLanguage.hebrew));
      expect(await bodies(), everyElement(endsWith(' · אחרי ארוחת הערב — זה הזמן שלך.')));

      change((s) => s.copyWith(habitAnchor: null, language: AppLanguage.english));
      final cleared = await bodies();
      expect(cleared, everyElement(isNot(contains('After dinner'))));
      expect(cleared.last, endsWith(' min'));
    });

    test('plans again when a reminder setting or the language changes', () {
      change((s) => s.copyWith(dailyReminderMinutes: 7 * 60));
      expect(service.reschedules, 2);
      change((s) => s.copyWith(fridayReminder: !s.fridayReminder));
      expect(service.reschedules, 3);
      change((s) => s.copyWith(language: AppLanguage.hebrew));
      expect(service.reschedules, 4);
      change((s) => s.copyWith(nameStyle: NameStyle.ashkenazi));
      expect(service.reschedules, 5);
      // The daily reminder names it.
      change((s) => s.copyWith(habitAnchor: HabitAnchor.dinner));
      expect(service.reschedules, 6);
    });

    test('plans again when the city for Shabbat times, or the reader\'s times there, change', () {
      // As the app loads the time zones after its first frame.
      Zmanim.timeZone('UTC');
      const london = City(
        id: 2643743,
        nameEn: 'London',
        countryCode: 'GB',
        latitude: 51.5085,
        longitude: -0.1257,
        timeZone: 'Europe/London',
      );
      change((s) => s.copyWith(city: london));
      expect(service.reschedules, 2);
      // The reader's luach: candles lit 30 minutes before sunset, and
      // Shabbat ending 72 minutes after it.
      change((s) => s.copyWith(candleMinutesOverride: 30));
      expect(service.reschedules, 3);
      change((s) => s.copyWith(havdalah: HavdalahRule.min72));
      expect(service.reschedules, 4);
      change((s) => s.copyWith(city: null));
      expect(service.reschedules, 5);
    });
  });

  group('copy', () {
    test('the daily reminder names the aliyot in the title and the portion and length in the body', () {
      // Friday of Noach 5787, at 9:00, before the Erev Shabbat cutoff.
      final plan = planFrom(DateTime(2026, 10, 11, 8), prefs: const ReminderPrefs(daily: true, dailyMinutes: 9 * 60));
      final friday = plan.singleWhere((r) => r.date == LocalDate(2026, 10, 16));
      expect(friday.aliyot, [5, 6]);
      final info = repo.portion(friday.plan.portion);
      final verses = repo.aliyahVerseCount(info, 5) + repo.aliyahVerseCount(info, 6);
      final minutes = (verses * 25 / 60).ceil();
      expect(
        copyIn(en)(friday),
        (title: 'Today: Shishi and Shevi’i', body: 'Parshat Noach · $verses verses · about $minutes min'),
      );
      expect(copyIn(he)(friday).title, 'היום: שישי ושביעי');
      expect(copyIn(he)(friday).body, he.notifDailyBody('נח', he.versesCount(verses), minutes));
    });

    group("the reader's routine", () {
      // Revi'i of Bereshit 5787 (Genesis 3:22–4:18), on its Thursday.
      late PlannedReminder revii;
      setUpAll(() {
        final plan = planner.planFor(planner.schedule.weekFor(LocalDate(2026, 10, 8)));
        revii = PlannedReminder(
          kind: ReminderKind.daily,
          date: LocalDate(2026, 10, 8),
          minutes: 7 * 60,
          plan: plan,
          aliyot: const [3],
        );
      });

      ReminderCopy describe(PlannedReminder r, AppLocalizations l, HabitAnchor? anchor) =>
          reminderCopy(r, l: l, repo: repo, ashkenaziNames: false, anchor: anchor);

      test('ends the daily reminder, after its length', () {
        final copy = describe(revii, en, HabitAnchor.shacharit);
        expect(copy.title, 'Today: Revi’i');
        expect(copy.body, contains('After Shacharit'));
        expect(copy.body, contains('about 9 min'));
        expect(
          copy.body,
          'Parshat Bereshit · 21 verses · about 9 min · After Shacharit — your time for the parsha.',
        );
        expect(describe(revii, he, HabitAnchor.shacharit).body, 'פרשת בראשית · 21 פסוקים · כ־9 דק׳ · אחרי שחרית — זה הזמן שלך.');
      });

      test('is left out when none is chosen', () {
        expect(describe(revii, en, null).body, 'Parshat Bereshit · 21 verses · about 9 min');
      });

      test('ends a day of the whole portion too', () {
        final r = PlannedReminder(
          kind: ReminderKind.daily,
          date: revii.date,
          minutes: 21 * 60,
          plan: revii.plan,
          aliyot: const [0, 1, 2, 3, 4, 5, 6],
        );
        expect(describe(r, en, HabitAnchor.bed).body, endsWith(' · Before bed — your time for the parsha.'));
      });

      test('is left out of a reminder far from its usual time: no Shacharit at 8 PM', () {
        final evening = PlannedReminder(
          kind: ReminderKind.daily,
          date: revii.date,
          minutes: 20 * 60,
          plan: revii.plan,
          aliyot: revii.aliyot,
        );
        expect(describe(evening, en, HabitAnchor.shacharit).body, 'Parshat Bereshit · 21 verses · about 9 min');
        expect(describe(evening, he, HabitAnchor.shacharit).body, 'פרשת בראשית · 21 פסוקים · כ־9 דק׳');
        // Four hours on is still near.
        final late = PlannedReminder(
          kind: ReminderKind.daily,
          date: revii.date,
          minutes: 11 * 60 + 30,
          plan: revii.plan,
          aliyot: revii.aliyot,
        );
        expect(
          describe(late, en, HabitAnchor.shacharit).body,
          endsWith(' · After Shacharit — your time for the parsha.'),
        );
      });

      test('is named in every language, each routine its own way', () {
        for (final l in [en, he]) {
          final cues = {for (final a in HabitAnchor.values) anchorCue(a, l)};
          expect(cues, hasLength(HabitAnchor.values.length), reason: l.localeName);
        }
        expect(anchorCue(HabitAnchor.commute, en), 'On your commute');
      });

      test('is only in the daily reminder', () {
        final plan = planFrom(DateTime(2026, 10, 11, 8));
        for (final r in plan.where((r) => r.kind != ReminderKind.daily)) {
          expect(describe(r, en, HabitAnchor.shacharit), copyIn(en)(r), reason: '$r');
        }
      });
    });

    test('a day that holds the whole portion names it once', () {
      final week = planner.schedule.weekFor(LocalDate(2026, 10, 18));
      final plan = planner.planFor(week);
      final r = PlannedReminder(
        kind: ReminderKind.daily,
        date: plan.days.first.date,
        minutes: 20 * 60,
        plan: plan,
        aliyot: const [0, 1, 2, 3, 4, 5, 6],
      );
      final info = repo.portion(plan.portion);
      final verses = [for (var a = 0; a < 7; a++) repo.aliyahVerseCount(info, a)].reduce((a, b) => a + b);
      final copy = copyIn(en)(r);
      expect(copy.title, 'Today: Parshat ${info.displayName(ashkenazi: false)}');
      expect(copy.body, '$verses verses · about ${(verses * 25 / 60).ceil()} min');
    });

    test("the paused message keeps the reader's place, in Hebrew without nikud", () {
      // Planned in the week of Noach 5787.
      final paused = planFrom(DateTime(2026, 10, 11, 8)).last;
      expect(paused.kind, ReminderKind.paused);
      expect(copyIn(en)(paused), (title: 'Reminders paused', body: en.notifPausedBody('Noach')));
      final hebrew = copyIn(he)(paused);
      expect(hebrew.title, he.notifPausedTitle);
      expect(hebrew.body, contains('פרשת נח'));
    });

    test('the Erev Shabbat and check-in reminders have a title and a body', () {
      final plan = planFrom(DateTime(2026, 10, 11, 8));
      final erevShabbat = plan.firstWhere((r) => r.kind == ReminderKind.erevShabbat);
      final checkIn = plan.firstWhere((r) => r.kind == ReminderKind.checkIn);
      expect(copyIn(en)(erevShabbat), (
        title: 'Erev Shabbat · Parshat Noach',
        body: 'There’s still time — or finish Shabbat morning from your Chumash and log it after Shabbat.',
      ));
      expect(copyIn(he)(erevShabbat), (
        title: 'ערב שבת · פרשת נח',
        body: 'יש עוד זמן — אפשר גם לסיים בשבת בבוקר מתוך חומש ולרשום אחרי שבת.',
      ));
      expect(copyIn(en)(checkIn), (title: 'Shavua tov!', body: 'Did you read on Shabbat? Tap to log it.'));
      expect(copyIn(he)(checkIn), (title: 'שבוע טוב!', body: 'קראת בשבת? אפשר לרשום זאת באפליקציה.'));
    });

    test('the check-in after Shabbat and the Yom Tov straight after it asks about both', () {
      // Shabbat Bamidbar 5789, then Shavuot on Sunday and Monday.
      final checkIn = planFrom(DateTime(2029, 5, 14, 8), prefs: const ReminderPrefs(checkIn: true))
          .firstWhere((r) => r.kind == ReminderKind.checkIn);
      expect(checkIn.date, LocalDate(2029, 5, 22));
      expect(copyIn(en)(checkIn), (title: 'Shavua tov!', body: 'Did you read on Shabbat and Yom Tov? Tap to log it.'));
      expect(copyIn(he)(checkIn), (title: 'שבוע טוב!', body: 'קראת בשבת וביום טוב? אפשר לרשום זאת באפליקציה.'));
    });

    test('the check-in after Simchat Torah names Vezot HaBerachah, in the reader’s style', () {
      final checkIn = planFrom(DateTime(2026, 9, 30, 8), prefs: const ReminderPrefs(checkIn: true))
          .firstWhere((r) => r.kind == ReminderKind.checkIn);
      expect((checkIn.date, checkIn.plan.weekId), (LocalDate(2026, 10, 5), '5786:54'));
      expect(copyIn(en)(checkIn), (title: 'Vezot HaBerachah', body: 'Did you read it on Yom Tov? Tap to log it.'));
      expect(copyIn(he)(checkIn), (title: 'וזאת הברכה', body: 'קראת אותה ביום טוב? אפשר לרשום זאת באפליקציה.'));
      expect(reminderCopy(checkIn, l: en, repo: repo, ashkenaziNames: true).title, 'Vezos HaBerachah');
    });

    test('names Simchat Torah where that day was no Yom Tov for the reader', () {
      // One day of Yom Tov, and the reading outside Israel.
      final checkIn = planReminders(
        prefs: const ReminderPrefs(checkIn: true),
        planner: const ReadingPlanner(schedule: ParshaSchedule(israel: false), oneDayYomTov: true),
        progressOf: (id) => WeekProgress(weekId: id),
        now: DateTime(2026, 9, 30, 8),
        today: LocalDate(2026, 9, 30),
      ).firstWhere((r) => r.kind == ReminderKind.checkIn);
      expect(checkIn.plan.weekId, '5786:54');
      expect(
        copyIn(en)(checkIn),
        (title: 'Vezot HaBerachah', body: 'Did you read it on Simchat Torah? Tap to log it.'),
      );
      expect(copyIn(he)(checkIn), (title: 'וזאת הברכה', body: 'קראת אותה בשמחת תורה? אפשר לרשום זאת באפליקציה.'));
    });
  });
}
