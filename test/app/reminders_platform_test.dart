import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'native_source.dart';

/// The native side of reminders on Android, which no Dart test runs and this
/// machine can't build: MainActivity, which reads which reminder opened the
/// app. Checked here against flutter_local_notifications' own sources, whose
/// names it relies on.
void main() {
  const kotlin = 'android/app/src/main/kotlin/org/shnayimmikrah/shnayim_mikrah';
  const plugin = 'android/src/main/java/com/dexterous/flutterlocalnotifications';
  final activity = File('$kotlin/MainActivity.kt').readAsStringSync();
  final pluginSource = packageSource('flutter_local_notifications', '$plugin/FlutterLocalNotificationsPlugin.java');

  /// The string constant [name] in the plugin's Java [source].
  String constant(String source, String name) =>
      RegExp('static final String $name\\s*=\\s*"([^"]+)"').firstMatch(source)![1]!;

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
}
