import 'dart:async';
import 'dart:io' show File, Platform;
import 'dart:ui';

import 'package:app_settings/app_settings.dart' as system;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding, Priority;
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart' hide Priority;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../app/city_providers.dart';
import '../app/providers.dart';
import '../core/text/hebrew_text.dart';
import '../data/parsha_repository.dart';
import '../features/progress/domain/reading_plan.dart' show kSecondsPerVerse;
import '../features/settings/app_settings.dart';
import '../l10n/app_localizations.dart';
import '../ui/theme/palette.dart';
import 'reminder_planner.dart';

/// What a reminder says.
typedef ReminderCopy = ({String title, String body});

/// Local notifications on Android, iOS, macOS and Windows. Scheduled
/// notifications aren't available in browsers, so the web build has none.
class NotificationService {
  NotificationService._(this._plugin, {required this.supported, Future<void> Function()? loadTimeZones})
      : _loadTimeZones = loadTimeZones ?? _loadTimeZoneDatabase;

  /// For tests and unsupported platforms.
  NotificationService.disabled()
      : _plugin = null,
        supported = false,
        _loadTimeZones = _loadTimeZoneDatabase;

  /// A service that schedules through [plugin], with [loadTimeZones] in place
  /// of loading the time-zone database.
  @visibleForTesting
  NotificationService.forTesting(FlutterLocalNotificationsPlugin plugin, {required Future<void> Function() loadTimeZones})
      : this._(plugin, supported: true, loadTimeZones: loadTimeZones);

  static Future<NotificationService> create() async {
    final supported = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows);
    if (!supported) return NotificationService.disabled();

    try {
      final plugin = FlutterLocalNotificationsPlugin();
      final service = NotificationService._(plugin, supported: true);
      await plugin.initialize(
        settings: InitializationSettings(
          android: const AndroidInitializationSettings(_statusBarIcon),
          // Permission is requested later, after the user opts in.
          iOS: const DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          macOS: const DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          windows: WindowsInitializationSettings(
            appName: 'Shnayim Mikra',
            appUserModelId: 'ShnayimMikra.App',
            guid: '7c1d6a3e-5b2f-4d8e-9a61-3f0c2e8b4d57',
            iconPath: defaultTargetPlatform == TargetPlatform.windows ? _windowsIconPath() : null,
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

  /// Loads the time-zone database and finds the device's zone, which only
  /// scheduling a reminder needs. Decoding the database blocks the UI for a
  /// while, so it waits for the first frame and then for a moment when
  /// nothing is animating.
  static Future<void> _loadTimeZoneDatabase() async {
    await WidgetsBinding.instance.waitUntilFirstFrameRasterized;
    try {
      // Zmanim may have loaded it already.
      if (!tz.timeZoneDatabase.isInitialized) {
        await SchedulerBinding.instance.scheduleTask(tzdata.initializeTimeZones, Priority.idle);
      }
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Falls back to UTC offsets; reminders may be off by DST at worst.
    }
  }

  final FlutterLocalNotificationsPlugin? _plugin;
  final bool supported;

  final Future<void> Function() _loadTimeZones;

  /// The time-zone database loading, from the first reminder to schedule:
  /// most readers have none, and never load it.
  Future<void>? _timeZones;

  /// The route to open if the app was launched from a notification.
  String? launchRoute;

  final _taps = StreamController<String>.broadcast();

  /// Routes to open when the user taps a notification.
  Stream<String> get taps => _taps.stream;

  /// Reports a tap on a notification carrying [payload], its route.
  @visibleForTesting
  void handleTap(String? payload) => _taps.add(payload ?? '/today');

  /// Asks the OS for permission. Call only after the user has said yes in
  /// the app's own explanation screen, or turned reminders on themselves
  /// (in a backup they restore, say). A platform that fails to answer counts
  /// as refusing.
  Future<bool> requestPermission() async {
    try {
      return await _requestPermission();
    } catch (e) {
      debugPrint('Could not ask for notification permission: $e');
      return false;
    }
  }

  Future<bool> _requestPermission() async {
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

  /// Whether [openSystemSettings] can take the reader to the device's
  /// notification settings: the app's own on Android and iOS, and on macOS
  /// (which has no build yet) the system's Notifications settings, where
  /// the app is listed. Windows never refuses permission.
  bool get canOpenSystemSettings =>
      supported &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Opens the device's notification settings (see [canOpenSystemSettings]),
  /// where notifications once refused can be allowed again.
  Future<void> openSystemSettings() async {
    try {
      await system.AppSettings.openAppSettings(type: system.AppSettingsType.notification);
    } catch (e) {
      debugPrint('Could not open the notification settings: $e');
    }
  }

  String _lastSignature = '';
  Future<void> _queue = Future.value();
  int _latest = 0;

  /// Whether Android lets the app schedule exact alarms, asked once.
  bool? _exact;

  /// How reminders are scheduled on Android. Before Android 12 an inexact
  /// alarm may come as late as three quarters of the time until it is due,
  /// so one planned days ahead could come on Shabbat; exact alarms there need
  /// no permission. From Android 12 they need one the app doesn't ask for,
  /// and inexact alarms come within the hour, which the planner allows for
  /// ([kMaxDeliveryDelay]).
  Future<AndroidScheduleMode> _scheduleMode(AndroidFlutterLocalNotificationsPlugin? android) async {
    if (android == null) return AndroidScheduleMode.inexactAllowWhileIdle;
    try {
      _exact ??= await android.canScheduleExactNotifications() ?? false;
    } catch (_) {
      _exact = false;
    }
    return _exact! ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// Replaces all scheduled reminders with [reminders], worded by [describe].
  ///
  /// Each call waits for the one before it to finish, and a call that a
  /// newer one has already superseded is skipped, so a quick succession of
  /// changes leaves exactly the last plan scheduled. Scheduling first waits
  /// for the time-zone database, loaded for the first reminders (clearing
  /// them never loads it); a call superseded while it waited schedules
  /// nothing.
  Future<void> reschedule(
      List<PlannedReminder> reminders, AppLocalizations l, ReminderCopy Function(PlannedReminder) describe) {
    final call = ++_latest;
    return _queue = _queue.then((_) async {
      if (call == _latest) await _reschedule(call, reminders, l, describe);
    }).catchError((Object _) {});
  }

  Future<void> _reschedule(int call, List<PlannedReminder> reminders, AppLocalizations l,
      ReminderCopy Function(PlannedReminder) describe) async {
    final p = _plugin;
    if (p == null) return;
    final copy = [for (final r in reminders) describe(r)];
    // The language is part of it so that a change renames the channels.
    final signature = [
      l.localeName,
      for (final (i, r) in reminders.indexed) '${r.id}@${r.localDateTime}:${copy[i].title}|${copy[i].body}',
    ].join('\n');
    if (signature == _lastSignature) return;
    if (reminders.isNotEmpty) {
      await (_timeZones ??= _loadTimeZones());
      // A later call has taken over while this one waited.
      if (call != _latest) return;
    }
    try {
      final android = p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final mode = await _scheduleMode(android);
      if (android != null) {
        // Creating a channel that exists updates its name and description,
        // so they follow the app's language.
        for (final kind in [ReminderKind.daily, ReminderKind.erevShabbat, ReminderKind.checkIn]) {
          final (id, name, description) = _channel(kind, l);
          await android.createNotificationChannel(AndroidNotificationChannel(id, name, description: description));
        }
      }
      await p.cancelAll();
      for (final (i, r) in reminders.indexed) {
        final (:title, :body) = copy[i];
        final (channelId, channelName, channelDescription) = _channel(r.kind, l);
        await p.zonedSchedule(
          id: r.id,
          title: title,
          body: body,
          scheduledDate: tz.TZDateTime.from(r.localDateTime, tz.local),
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              channelId,
              channelName,
              channelDescription: channelDescription,
              importance: Importance.defaultImportance,
              category: AndroidNotificationCategory.reminder,
              icon: _statusBarIcon,
              // Techelet, the brand colour (DESIGN_SYSTEM.md §3.6).
              color: Palettes.light.primary,
              // Shows the whole message when expanded, not one truncated line.
              styleInformation: BigTextStyleInformation(body),
            ),
            iOS: const DarwinNotificationDetails(threadIdentifier: _thread),
            macOS: const DarwinNotificationDetails(threadIdentifier: _thread),
            windows: const WindowsNotificationDetails(),
          ),
          androidScheduleMode: mode,
          payload: reminderRoute(r),
        );
      }
      _lastSignature = signature;
    } catch (e) {
      debugPrint('Could not schedule reminders: $e');
    }
  }

  /// The id, name and description of the Android channel a reminder of
  /// [kind] is posted to. The final "reminders paused" message shares the
  /// check-in's.
  static (String, String, String) _channel(ReminderKind kind, AppLocalizations l) => switch (kind) {
        ReminderKind.daily => ('daily', l.notifChannelDaily, l.notifChannelDailyDesc),
        ReminderKind.erevShabbat => ('erev_shabbat', l.notifChannelFriday, l.notifChannelErevShabbatDesc),
        ReminderKind.checkIn || ReminderKind.paused => ('check_in', l.notifChannelCheckIn, l.notifChannelCheckInDesc),
      };

  Future<void> cancelAll() async => _plugin?.cancelAll();
}

/// The white glyph in android/app/src/main/res/drawable, kept from resource
/// shrinking by res/raw/keep.xml.
const _statusBarIcon = 'ic_stat_reminder';

/// Groups the app's reminders together in the iOS and macOS Notification
/// Center.
const _thread = 'reminders';

/// The toast icon that windows/CMakeLists.txt installs beside the executable,
/// or null (the default icon) if it is missing.
String? _windowsIconPath() {
  final path = [File(Platform.resolvedExecutable).parent.path, 'data', 'notification.png'].join(Platform.pathSeparator);
  return File(path).existsSync() ? path : null;
}

/// The page a reminder opens: the week, for Erev Shabbat, to finish it; Today
/// for the others, where the day's reading and the check-in card are. The
/// week opens within Today, with the navigation bar and a way back.
String reminderRoute(PlannedReminder r) => switch (r.kind) {
      ReminderKind.erevShabbat => '/today/week/${r.plan.weekId}',
      ReminderKind.daily || ReminderKind.checkIn || ReminderKind.paused => '/today',
    };

/// The words of reminder [r] in [l]'s language: for the daily reading, the
/// aliyot due as the title, and the portion and length as the body, ending
/// with the routine the reader tied the reading to, [anchor], if any.
ReminderCopy reminderCopy(
  PlannedReminder r, {
  required AppLocalizations l,
  required ParshaRepository repo,
  required bool ashkenaziNames,
  HabitAnchor? anchor,
}) {
  final info = repo.portion(r.plan.portion);
  final parsha =
      l.localeName.startsWith('he') ? HebrewText.stripNikud(info.nameHe) : info.displayName(ashkenazi: ashkenaziNames);
  switch (r.kind) {
    case ReminderKind.daily:
      final count = r.aliyot.fold<int>(0, (n, a) => n + repo.aliyahVerseCount(info, a));
      final verses = l.versesCount(count);
      // All three readings of each verse, as Today estimates them.
      final minutes = (count * kSecondsPerVerse / 60).ceil();
      final cue = anchor == null ? '' : ' · ${l.notifDailyAnchor(anchorCue(anchor, l))}';
      // The whole portion in one day: named once, in the title.
      if (r.aliyot.length == 7) {
        return (title: l.notifDailyTitle(l.parshaLabel(parsha)), body: '$verses · ${l.minutesEstimate(minutes)}$cue');
      }
      final names = [l.aliyah1, l.aliyah2, l.aliyah3, l.aliyah4, l.aliyah5, l.aliyah6, l.aliyah7];
      return (
        title: l.notifDailyTitle(r.aliyot.map((a) => names[a]).join(', ')),
        body: '${l.notifDailyBody(parsha, verses, minutes)}$cue',
      );
    case ReminderKind.erevShabbat:
      return (title: l.notifFridayTitle(parsha), body: l.notifFridayBody);
    case ReminderKind.checkIn:
      return (title: l.notifCheckInTitle, body: l.notifCheckInBody);
    case ReminderKind.paused:
      return (title: l.notifPausedTitle, body: l.notifPausedBody(parsha));
  }
}

/// How the daily reminder names [anchor]: "After Shacharit".
String anchorCue(HabitAnchor anchor, AppLocalizations l) => switch (anchor) {
      HabitAnchor.shacharit => l.anchorCueShacharit,
      HabitAnchor.breakfast => l.anchorCueBreakfast,
      HabitAnchor.commute => l.anchorCueCommute,
      HabitAnchor.dinner => l.anchorCueDinner,
      HabitAnchor.bed => l.anchorCueBed,
    };

final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService.disabled());

/// Whether any reminder is on in [s].
bool anyReminderOn(AppSettings s) => s.dailyReminder || s.fridayReminder || s.checkInReminder;

/// Recomputes and reschedules reminders whenever settings, progress or the
/// date change.
final reminderSchedulerProvider = Provider<void>((ref) {
  final service = ref.watch(notificationServiceProvider);
  if (!service.supported) return;
  final settings = ref.watch(settingsProvider.select((s) => (
        dailyReminder: s.dailyReminder,
        dailyReminderMinutes: s.dailyReminderMinutes,
        fridayReminder: s.fridayReminder,
        fridayReminderMinutes: s.fridayReminderMinutes,
        checkInReminder: s.checkInReminder,
        habitAnchor: s.habitAnchor,
        city: s.city,
        language: s.language,
        ashkenaziNames: s.ashkenaziNames,
      )));
  // The reading log, not the place saved in it (see ProgressState.logRevision).
  ref.watch(progressProvider.select((p) => p.logRevision));
  final progress = ref.read(progressProvider);
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
  final on = prefs.daily || prefs.erevShabbat || prefs.checkIn;
  // With a city, reminders follow its Shabbat times, worked out once the
  // time-zone database is in; scheduling them waits for it anyway.
  final city = settings.city;
  if (on && city != null && !timeZonesReady(ref)) return;
  final reminders = on
      ? planReminders(
          prefs: prefs,
          planner: planner,
          progressOf: progress.week,
          now: DateTime.now(),
          today: today,
          pauses: progress.pauses,
          zmanim: city == null ? null : reminderZmanim(city, deviceOffset: ref.watch(deviceClockProvider)),
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

  unawaited(service.reschedule(
    reminders,
    l,
    (r) => reminderCopy(r, l: l, repo: repo, ashkenaziNames: settings.ashkenaziNames, anchor: settings.habitAnchor),
  ));
});
