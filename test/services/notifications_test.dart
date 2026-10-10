import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/data/parsha_repository.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/l10n/app_localizations.dart';
import 'package:shnayim_mikra/services/notifications.dart';
import 'package:shnayim_mikra/services/reminder_planner.dart';
import 'package:timezone/timezone.dart' as tz;

import '../helpers.dart';

typedef _Scheduled = ({String? title, String? body, NotificationDetails details, String? payload});

/// Records what is scheduled. Every call yields to the event loop first, as
/// a platform channel does, so overlapping calls interleave.
class _FakePlugin extends Fake implements FlutterLocalNotificationsPlugin {
  final scheduled = <int, _Scheduled>{};
  final android = _FakeAndroid();
  int cancels = 0;
  int schedules = 0;
  bool failNextSchedule = false;

  @override
  Future<void> cancelAll() async {
    await Future<void>.delayed(Duration.zero);
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
    if (failNextSchedule) {
      failNextSchedule = false;
      throw Exception('platform failure');
    }
    schedules++;
    scheduled[id] = (title: title, body: body, details: notificationDetails, payload: payload);
  }

  @override
  T? resolvePlatformSpecificImplementation<T extends FlutterLocalNotificationsPlatform>() =>
      android is T ? android as T : null;
}

class _FakeAndroid extends Fake implements AndroidFlutterLocalNotificationsPlugin {
  final channels = <String, AndroidNotificationChannel>{};

  @override
  Future<void> createNotificationChannel(AndroidNotificationChannel notificationChannel) async {
    channels[notificationChannel.id] = notificationChannel;
  }
}

/// A service scheduling through [plugin], whose time zones (UTC, set in
/// setUpAll) need no loading.
NotificationService _service(_FakePlugin plugin) => NotificationService.forTesting(plugin, loadTimeZones: () async {});

/// A service that counts how often reminders are handed to it.
class _CountingService extends NotificationService {
  _CountingService() : super.forTesting(_FakePlugin(), loadTimeZones: () async => tz.setLocalLocation(tz.UTC));

  int reschedules = 0;

  @override
  Future<void> reschedule(
      List<PlannedReminder> reminders, AppLocalizations l, ReminderCopy Function(PlannedReminder) describe) {
    reschedules++;
    return super.reschedule(reminders, l, describe);
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

    test('a plan that failed to schedule is tried again', () async {
      final plugin = _FakePlugin()..failNextSchedule = true;
      final service = _service(plugin);
      final plan = planFrom(DateTime(2026, 10, 11, 8));

      await service.reschedule(plan, en, copyIn(en));
      expect(plugin.scheduled, isEmpty);
      await service.reschedule(plan, en, copyIn(en));
      expect(plugin.scheduled.keys.toSet(), ids(plan));
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

  group('the time zones', () {
    late List<PlannedReminder> reminders;

    setUpAll(() => reminders = planFrom(DateTime(2026, 10, 11, 8), prefs: const ReminderPrefs(daily: true)));

    test('are never loaded without a reminder to schedule', () async {
      var loads = 0;
      final plugin = _FakePlugin();
      final service = NotificationService.forTesting(plugin, loadTimeZones: () async => loads++);
      await service.reschedule(reminders, en, copyIn(en));
      await service.reschedule(const [], en, copyIn(en));
      expect(loads, 1, reason: 'once, for the first reminders');
      expect(plugin.cancels, 2, reason: 'clearing the reminders needs no time zones');

      final none = NotificationService.forTesting(_FakePlugin(), loadTimeZones: () async => loads++);
      await none.reschedule(const [], en, copyIn(en));
      expect(loads, 1);
    });

    test('are waited for before scheduling', () async {
      final loaded = Completer<void>();
      final plugin = _FakePlugin();
      final service = NotificationService.forTesting(plugin, loadTimeZones: () => loaded.future);
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
      final service = NotificationService.forTesting(plugin, loadTimeZones: () => loaded.future);
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

    test('plans again when a reminder setting or the language changes', () {
      change((s) => s.copyWith(dailyReminderMinutes: 7 * 60));
      expect(service.reschedules, 2);
      change((s) => s.copyWith(fridayReminder: !s.fridayReminder));
      expect(service.reschedules, 3);
      change((s) => s.copyWith(language: AppLanguage.hebrew));
      expect(service.reschedules, 4);
      change((s) => s.copyWith(nameStyle: NameStyle.ashkenazi));
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
      expect(copyIn(en)(friday), (title: "Today: Shishi, Shevi'i", body: 'Parshat Noach · $verses verses'));
      expect(copyIn(he)(friday).body, he.notifDailyBody('נח', he.versesCount(verses)));
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
      expect(copy.body, '$verses verses');
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
      final friday = copyIn(en)(plan.firstWhere((r) => r.kind == ReminderKind.erevShabbat));
      expect(friday, (title: en.notifFridayTitle('Noach'), body: en.notifFridayBody));
      final checkIn = copyIn(en)(plan.firstWhere((r) => r.kind == ReminderKind.checkIn));
      expect(checkIn, (title: en.notifCheckInTitle, body: en.notifCheckInBody));
    });
  });
}
