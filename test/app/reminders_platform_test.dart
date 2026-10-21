import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/services/reminder_planner.dart';

import 'native_source.dart';

/// The native side of reminders on Android, which no Dart test runs and this
/// machine can't build: MainActivity, which reads which reminder opened the
/// app, and ReminderBootReceiver, which arms them again after a reboot.
/// Checked here against flutter_local_notifications' own sources, whose
/// names and formats they rely on. (test/services/notifications_test.dart
/// checks what the app hands the plugin for each reminder.)
void main() {
  const kotlin = 'android/app/src/main/kotlin/org/shnayimmikrah/shnayim_mikrah';
  const plugin = 'android/src/main/java/com/dexterous/flutterlocalnotifications';
  final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  final activity = File('$kotlin/MainActivity.kt').readAsStringSync();
  final receiver = File('$kotlin/ReminderBootReceiver.kt').readAsStringSync();
  final pluginSource = packageSource('flutter_local_notifications', '$plugin/FlutterLocalNotificationsPlugin.java');
  final bootReceiver = packageSource('flutter_local_notifications', '$plugin/ScheduledNotificationBootReceiver.java');
  final details = packageSource('flutter_local_notifications', '$plugin/models/NotificationDetails.java');

  /// The string constant [name] in the plugin's Java [source].
  String constant(String source, String name) =>
      RegExp('static final String $name\\s*=\\s*"([^"]+)"').firstMatch(source)![1]!;

  /// The `<receiver>` element of the manifest whose name is [name].
  String? receiverNamed(String name) => RegExp(
        '<receiver\\b[^>]*android:name="${RegExp.escape(name)}"[^>]*?(/>|>.*?</receiver>)',
        dotAll: true,
      ).firstMatch(manifest)?[0];

  group('a recreated activity', () {
    test('forgets the reminder that started it, by the actions the plugin reads', () {
      // What the plugin asks when the app wants to know whether a reminder
      // launched it: the activity's intent, by its action.
      final launch = cppBody(pluginSource, 'private void getNotificationAppLaunchDetails');
      expect(launch, contains('Intent launchIntent = mainActivity.getIntent();'));
      expect(launch, contains('SELECT_NOTIFICATION.equals(launchIntent.getAction())'));
      expect(launch, contains('SELECT_FOREGROUND_NOTIFICATION_ACTION.equals(launchIntent.getAction())'));
      // The tapped reminder's intent carries the first.
      expect(cppBody(pluginSource, 'protected static Notification createNotification'),
          contains('intent.setAction(SELECT_NOTIFICATION);'));

      final selected = constant(pluginSource, 'SELECT_NOTIFICATION');
      final selectedAction = constant(pluginSource, 'SELECT_FOREGROUND_NOTIFICATION_ACTION');
      expect(activity, contains('const val SELECT_NOTIFICATION = "$selected"'));
      expect(activity, contains('const val SELECT_FOREGROUND_NOTIFICATION = "$selectedAction"'));

      // Whenever Android brings back the intent that first started it: with
      // a saved state, or from Recents.
      final onCreate = cppBody(activity, 'override fun onCreate');
      expect(onCreate, contains('val reopened = savedInstanceState != null ||'));
      final reopened = cppBody(onCreate, 'if (reopened)');
      const selectedEither = 'intent.action == SELECT_NOTIFICATION || intent.action == SELECT_FOREGROUND_NOTIFICATION';
      final reset = cppBody(reopened, 'if ($selectedEither)');
      expect(reset, contains('intent.action = Intent.ACTION_MAIN'));
      // Before Flutter, and the plugin with it, attach to the activity.
      expect(onCreate.indexOf('if (reopened)'), lessThan(onCreate.indexOf('super.onCreate(savedInstanceState)')));
    });

    test('keeps a reminder tapped while it is recreated, and the plain icon', () {
      // They come as a new intent, which the activity keeps as its own,
      // whatever it is: the plugin reads that one.
      final onNewIntent = cppBody(activity, 'override fun onNewIntent');
      expect(onNewIntent.trim().split('\n').where((l) => !l.trim().startsWith('//')).map((l) => l.trim()),
          ['{', 'setIntent(intent)', 'super.onNewIntent(intent)', '}']);
    });
  });

  group('after a reboot', () {
    test('ReminderBootReceiver arms the reminders again, in place of the plugin\'s receiver', () {
      final ours = receiverNamed('.ReminderBootReceiver');
      expect(ours, isNotNull);
      expect(ours, contains('android:exported="false"'));
      expect(receiverNamed('com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver'), isNull);
      // The plugin's manifest declares none of its receivers: the app's does.
      expect(packageSource('flutter_local_notifications', 'android/src/main/AndroidManifest.xml'),
          isNot(contains('<receiver')));
      // The one that posts each reminder stays.
      expect(receiverNamed('com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver'),
          contains('android:exported="false"'));

      // On each action the plugin's receiver answers.
      final actions = [for (final m in RegExp(r'<action android:name="([^"]+)"').allMatches(ours!)) m[1]!];
      expect(actions, [
        'android.intent.action.BOOT_COMPLETED',
        'android.intent.action.MY_PACKAGE_REPLACED',
        'android.intent.action.QUICKBOOT_POWERON',
        'com.htc.intent.action.QUICKBOOT_POWERON',
      ]);
      final answers = cppBody(bootReceiver, 'public void onReceive');
      expect(answers, contains('action.equals(android.content.Intent.ACTION_BOOT_COMPLETED)'));
      expect(answers, contains('action.equals(Intent.ACTION_MY_PACKAGE_REPLACED)'));
      expect(answers, contains('action.equals("android.intent.action.QUICKBOOT_POWERON")'));
      expect(answers, contains('action.equals("com.htc.intent.action.QUICKBOOT_POWERON")'));
      expect(answers, contains('FlutterLocalNotificationsPlugin.rescheduleNotifications(context);'));
      expect(bootReceiver, contains('@Keep\npublic class ScheduledNotificationBootReceiver extends BroadcastReceiver'));
    });

    test('it hands on to the plugin\'s receiver whatever happens before', () {
      final onReceive = cppBody(receiver, 'override fun onReceive').trim();
      expect(onReceive, endsWith('ScheduledNotificationBootReceiver().onReceive(context, intent)\n    }'));
      final tried = cppBody(onReceive, 'try {');
      expect(tried, contains('withoutMissed(it, System.currentTimeMillis())'));
      expect(tried, isNot(contains('ScheduledNotificationBootReceiver')));
      expect(onReceive, contains('} catch (e: Exception) {'));
      // In memory at once, before the plugin reads it in the same process.
      expect(tried, contains('prefs.edit().putString(CACHE, kept).apply()'));
    });

    test("it reads the plugin's cache, by its names", () {
      // The SharedPreferences file and key.
      final cache = constant(pluginSource, 'SCHEDULED_NOTIFICATIONS');
      expect(receiver, contains('const val CACHE = "$cache"'));
      final load = cppBody(pluginSource, 'private static ArrayList<NotificationDetails> loadScheduledNotifications');
      expect(load, contains('context.getSharedPreferences(SCHEDULED_NOTIFICATIONS, Context.MODE_PRIVATE)'));
      expect(load, contains('sharedPreferences.getString(SCHEDULED_NOTIFICATIONS, null)'));
      expect(receiver, contains('context.getSharedPreferences(CACHE, Context.MODE_PRIVATE)'));
      expect(receiver, contains('prefs.getString(CACHE, null)'));

      // NotificationDetails as Gson writes it: by its fields' own names,
      // which R8 keeps (@Keep), and only scheduleMode's is renamed.
      expect(details, contains('@Keep\npublic class NotificationDetails'));
      expect('@SerializedName'.allMatches(details), hasLength(1));
      expect(details, contains('@SerializedName(value = "scheduleMode", alternate = "allowWhileIdle")'));
      for (final field in [
        'String scheduledDateTime',
        'String timeZoneName',
        'Long millisecondsSinceEpoch',
        'RepeatInterval repeatInterval',
        'Integer repeatIntervalMilliseconds',
        'DateTimeComponents matchDateTimeComponents',
        'ScheduledNotificationRepeatFrequency scheduledNotificationRepeatFrequency',
      ]) {
        expect(details, contains('public $field;'), reason: field);
      }
      // Every field of a notification that comes again is one the receiver
      // never forgets.
      final repeats = RegExp(r'private val REPEATS = listOf\((.*?)\)', dotAll: true).firstMatch(receiver)![1]!;
      expect([for (final m in RegExp(r'"(\w+)"').allMatches(repeats)) m[1]!], [
        'repeatInterval',
        'repeatIntervalMilliseconds',
        'matchDateTimeComponents',
        'scheduledNotificationRepeatFrequency',
      ]);
      final next = cppBody(pluginSource, 'static void scheduleNextNotification');
      for (final field in [
        'scheduledNotificationRepeatFrequency',
        'matchDateTimeComponents',
        'repeatInterval',
        'repeatIntervalMilliseconds',
      ]) {
        expect(next, contains('notificationDetails.$field != null'), reason: field);
      }
      // Only a notification with none of them leaves the cache when it fires.
      expect(next, contains('removeNotificationFromCache(context, notificationDetails.id);'));
    });

    test('it dates each reminder as the plugin does when it arms it again', () {
      final reschedule = cppBody(pluginSource, 'static void rescheduleNotifications');
      expect(reschedule, contains('notificationDetails.timeZoneName != null'));
      expect(reschedule, contains('zonedScheduleNotification(context, notificationDetails, false)'));
      expect(reschedule, contains('scheduleNotification(context, notificationDetails, false)'));
      final zoned = cppBody(pluginSource, 'private static void zonedScheduleNotification');
      expect(zoned, contains('LocalDateTime.parse(notificationDetails.scheduledDateTime)'));
      expect(zoned, contains('ZoneId.of(notificationDetails.timeZoneName)'));
      expect(cppBody(pluginSource, 'private static void scheduleNotification'),
          contains('notificationDetails.millisecondsSinceEpoch'));

      expect(receiver, contains('LocalDateTime.parse(details.getString("scheduledDateTime"))'));
      expect(receiver, contains('.atZone(ZoneId.of(details.getString("timeZoneName")))'));
      expect(receiver, contains('details.getLong("millisecondsSinceEpoch")'));

      // The plugin's Java side keeps the strings the Dart side sends.
      expect(constant(details, 'SCHEDULED_DATE_TIME'), 'scheduledDateTime');
      expect(constant(details, 'TIME_ZONE_NAME'), 'timeZoneName');
      expect(details, contains('notificationDetails.scheduledDateTime = (String) arguments.get(SCHEDULED_DATE_TIME);'));
      expect(details, contains('notificationDetails.timeZoneName = (String) arguments.get(TIME_ZONE_NAME);'));
    });

    test('it forgets only reminders missed by more than they may come late', () {
      // Due at the latest that long before Shabbat or Yom Tov, a reminder
      // armed again within it still comes before them.
      expect(RegExp(r'const val MAX_DELIVERY_DELAY_MINUTES = (\d+)L').firstMatch(receiver)?[1], '$kMaxDeliveryDelay');
      expect(receiver, contains('val cutoff = now - MAX_DELIVERY_DELAY_MINUTES * 60_000'));
      expect(receiver, contains('if (due == null || due >= cutoff) kept.put(details)'));
      // Nothing is written when nothing is forgotten.
      expect(receiver, contains('return if (kept.length() == all.length()) null else kept.toString()'));
    });
  });
}
