import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/l10n/app_localizations.dart';
import 'package:shnayim_mikra/services/notifications.dart';
import 'package:shnayim_mikra/services/reminder_planner.dart';
import 'package:timezone/timezone.dart' as tz;

import '../helpers.dart';

/// The notifications plugin, recording what it is asked to do.
class _FakePlugin implements FlutterLocalNotificationsPlugin {
  final calls = <String>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation.memberName.toString().replaceAll(RegExp(r'Symbol\("|"\)'), ''));
    return Future<void>.value();
  }

  int count(String name) => calls.where((c) => c == name).length;
}

/// A service that counts how often reminders are handed to it.
class _CountingService extends NotificationService {
  _CountingService() : super.forTesting(_FakePlugin(), loadTimeZones: () async => tz.setLocalLocation(tz.UTC));

  int reschedules = 0;

  @override
  Future<void> reschedule(List<PlannedReminder> reminders, AppLocalizations l, String Function(PlannedReminder) describe) {
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

  group('reschedule', () {
    late List<PlannedReminder> reminders;
    final l = lookupAppLocalizations(const Locale('en'));
    String describe(PlannedReminder r) => 'Reminder ${r.id}';

    setUpAll(() async {
      final c = await container(const AppSettings(onboardingComplete: true));
      final plan = c.read(currentPlanProvider);
      reminders = [
        for (var d = 0; d < 3; d++)
          PlannedReminder(kind: ReminderKind.daily, date: _monday.addDays(d + 1), minutes: 20 * 60, plan: plan, aliyot: [d]),
      ];
    });

    test('never loads the time zones without a reminder to schedule', () async {
      var loads = 0;
      final plugin = _FakePlugin();
      final service = NotificationService.forTesting(plugin, loadTimeZones: () async => loads++);
      await service.reschedule(reminders, l, describe);
      await service.reschedule(const [], l, describe);
      expect(loads, 1, reason: 'once, for the first reminders');
      expect(plugin.count('cancelAll'), 2, reason: 'clearing the reminders needs no time zones');

      final none = NotificationService.forTesting(_FakePlugin(), loadTimeZones: () async => loads++);
      await none.reschedule(const [], l, describe);
      expect(loads, 1);
    });

    test('waits for the time zones before scheduling', () async {
      final loaded = Completer<void>();
      final plugin = _FakePlugin();
      final service = NotificationService.forTesting(plugin, loadTimeZones: () => loaded.future);
      final done = service.reschedule(reminders, l, describe);
      await Future<void>.delayed(Duration.zero);
      expect(plugin.calls, isEmpty);
      tz.setLocalLocation(tz.UTC);
      loaded.complete();
      await done;
      expect(plugin.count('cancelAll'), 1);
      expect(plugin.count('zonedSchedule'), reminders.length);
    });

    test('a call taken over while it waited schedules nothing', () async {
      final loaded = Completer<void>();
      final plugin = _FakePlugin();
      final service = NotificationService.forTesting(plugin, loadTimeZones: () => loaded.future);
      final first = service.reschedule(reminders, l, describe);
      final second = service.reschedule(reminders.sublist(0, 1), l, describe);
      tz.setLocalLocation(tz.UTC);
      loaded.complete();
      await Future.wait([first, second]);
      expect(plugin.count('cancelAll'), 1);
      expect(plugin.count('zonedSchedule'), 1, reason: 'only the later call’s one reminder');
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
}
