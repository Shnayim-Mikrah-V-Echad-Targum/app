import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../app/providers.dart';
import '../core/text/hebrew_text.dart';
import '../features/settings/app_settings.dart';
import '../l10n/app_localizations.dart';
import 'reminder_planner.dart';

/// Local notifications on Android, iOS, macOS and Windows. Scheduled
/// notifications aren't available in browsers, so the web build has none.
class NotificationService {
  NotificationService._(this._plugin, {required this.supported});

  /// For tests and unsupported platforms.
  NotificationService.disabled()
      : _plugin = null,
        supported = false;

  static Future<NotificationService> create() async {
    final supported = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows);
    if (!supported) return NotificationService.disabled();

    try {
      tzdata.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (_) {
        // Falls back to UTC offsets; reminders may be off by DST at worst.
      }
      final plugin = FlutterLocalNotificationsPlugin();
      final service = NotificationService._(plugin, supported: true);
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Permission is requested later, after the user opts in.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          macOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          windows: WindowsInitializationSettings(
            appName: 'Shnayim Mikra',
            appUserModelId: 'ShnayimMikra.App',
            guid: '7c1d6a3e-5b2f-4d8e-9a61-3f0c2e8b4d57',
          ),
        ),
        onDidReceiveNotificationResponse: (r) => service.handleTap(r.payload),
      );
      final launch = await plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) service.launchRoute = launch?.notificationResponse?.payload;
      return service;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
      return NotificationService.disabled();
    }
  }

  final FlutterLocalNotificationsPlugin? _plugin;
  final bool supported;

  /// The route to open if the app was launched from a notification.
  String? launchRoute;

  final _taps = StreamController<String>.broadcast();

  /// Routes to open when the user taps a notification.
  Stream<String> get taps => _taps.stream;

  /// Reports a tap on a notification carrying [payload], its route.
  @visibleForTesting
  void handleTap(String? payload) => _taps.add(payload ?? '/today');

  /// Asks the OS for permission. Call only after the user has said yes in
  /// the app's own explanation screen.
  Future<bool> requestPermission() async {
    final p = _plugin;
    if (p == null) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await p
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await p
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, sound: true) ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return await p
              .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, sound: true) ??
          false;
    }
    return true;
  }

  String _lastSignature = '';

  /// Replaces all scheduled reminders.
  Future<void> reschedule(List<PlannedReminder> reminders, AppLocalizations l, String Function(PlannedReminder) describe) async {
    final p = _plugin;
    if (p == null) return;
    final signature = reminders.map((r) => '${r.id}@${r.localDateTime}:${describe(r)}').join('|');
    if (signature == _lastSignature) return;
    _lastSignature = signature;
    try {
      await p.cancelAll();
      for (final r in reminders) {
        final (title, body, channel, channelName) = switch (r.kind) {
          ReminderKind.daily => (describe(r), null, 'daily', l.notifChannelDaily),
          ReminderKind.erevShabbat => (describe(r), l.notifFridayBody, 'erev_shabbat', l.notifChannelFriday),
          ReminderKind.checkIn => (l.notifCheckInTitle, l.notifCheckInBody, 'check_in', l.notifChannelCheckIn),
        };
        await p.zonedSchedule(
          id: r.id,
          title: title,
          body: body,
          scheduledDate: tz.TZDateTime.from(r.localDateTime, tz.local),
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(channel, channelName, importance: Importance.defaultImportance),
            iOS: const DarwinNotificationDetails(),
            macOS: const DarwinNotificationDetails(),
            windows: const WindowsNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: reminderRoute(r),
        );
      }
    } catch (e) {
      debugPrint('Could not schedule reminders: $e');
    }
  }

  Future<void> cancelAll() async => _plugin?.cancelAll();
}

/// The page a reminder opens: the week, for Erev Shabbat, to finish it; Today
/// for the others, where the day's reading and the check-in card are.
String reminderRoute(PlannedReminder r) => switch (r.kind) {
      ReminderKind.erevShabbat => '/week/${r.plan.weekId}',
      ReminderKind.daily || ReminderKind.checkIn => '/today',
    };

final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService.disabled());

/// Recomputes and reschedules reminders whenever settings, progress or the
/// date change.
final reminderSchedulerProvider = Provider<void>((ref) {
  final service = ref.watch(notificationServiceProvider);
  if (!service.supported) return;
  final settings = ref.watch(settingsProvider);
  final progress = ref.watch(progressProvider);
  final today = ref.watch(todayProvider);
  final planner = ref.watch(plannerProvider);
  final repo = ref.watch(parshaRepositoryProvider);

  final prefs = ReminderPrefs(
    daily: settings.dailyReminder,
    dailyMinutes: settings.dailyReminderMinutes,
    erevShabbat: settings.fridayReminder,
    erevShabbatMinutes: settings.fridayReminderMinutes,
    checkIn: settings.checkInReminder,
  );
  final reminders = (prefs.daily || prefs.erevShabbat || prefs.checkIn)
      ? planReminders(
          prefs: prefs,
          planner: planner,
          progressOf: progress.week,
          now: DateTime.now(),
          today: today,
          pauses: progress.pauses,
        )
      : const <PlannedReminder>[];

  final locale = switch (settings.language) {
    AppLanguage.english => const Locale('en'),
    AppLanguage.hebrew => const Locale('he'),
    AppLanguage.system => PlatformDispatcher.instance.locale,
  };
  final l = lookupAppLocalizations(
    AppLocalizations.supportedLocales.any((s) => s.languageCode == locale.languageCode) ? locale : const Locale('en'),
  );
  final he = l.localeName.startsWith('he');

  String parshaName(PlannedReminder r) {
    final info = repo.portion(r.plan.portion);
    return he ? HebrewText.stripNikud(info.nameHe) : info.displayName(ashkenazi: settings.ashkenaziNames);
  }

  String describe(PlannedReminder r) {
    switch (r.kind) {
      case ReminderKind.daily:
        final names = [l.aliyah1, l.aliyah2, l.aliyah3, l.aliyah4, l.aliyah5, l.aliyah6, l.aliyah7];
        final aliyot = r.aliyot.length == 7 ? l.parshaLabel(parshaName(r)) : r.aliyot.map((a) => names[a]).join(', ');
        final info = repo.portion(r.plan.portion);
        final verses = r.aliyot.fold<int>(0, (n, a) => n + repo.aliyahVerseCount(info, a));
        return '${l.notifDailyTitle(aliyot)} · ${l.notifDailyBody(parshaName(r), l.versesCount(verses))}';
      case ReminderKind.erevShabbat:
        return l.notifFridayTitle(parshaName(r));
      case ReminderKind.checkIn:
        return l.notifCheckInTitle;
    }
  }

  service.reschedule(reminders, l, describe);
});
