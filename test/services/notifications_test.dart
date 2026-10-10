import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/data/parsha_repository.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/l10n/app_localizations.dart';
import 'package:shnayim_mikra/services/notifications.dart';
import 'package:shnayim_mikra/services/reminder_planner.dart';
import 'package:timezone/timezone.dart' as tz;

typedef _Scheduled = ({String? title, String? body, NotificationDetails details, String? payload});

/// Records what is scheduled. Every call yields to the event loop first, as
/// a platform channel does, so overlapping calls interleave.
class _FakePlugin extends Fake implements FlutterLocalNotificationsPlugin {
  final scheduled = <int, _Scheduled>{};
  final android = _FakeAndroid();
  int cancels = 0;
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

  group('rescheduling', () {
    test('two quick calls leave exactly the second plan scheduled', () async {
      final plugin = _FakePlugin();
      final service = NotificationService.withPlugin(plugin);
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
      final service = NotificationService.withPlugin(plugin);
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
      final service = NotificationService.withPlugin(plugin);
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
      final service = NotificationService.withPlugin(plugin);
      final plan = planFrom(DateTime(2026, 10, 11, 8));

      await service.reschedule(plan, en, copyIn(en));
      expect(plugin.scheduled, isEmpty);
      await service.reschedule(plan, en, copyIn(en));
      expect(plugin.scheduled.keys.toSet(), ids(plan));
    });

    test('channels are created with names and descriptions in the app language', () async {
      final plugin = _FakePlugin();
      await NotificationService.withPlugin(plugin).reschedule(const [], he, copyIn(he));

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
      await NotificationService.withPlugin(plugin).reschedule(plan, en, copyIn(en));

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
