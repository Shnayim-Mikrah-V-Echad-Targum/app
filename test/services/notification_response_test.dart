import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/app/window_title_bar.dart';
import 'package:shnayim_mikrah/services/notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// The Windows plugin, as far as NotificationService.create uses it: it
/// keeps the callback the service gives it, to click a notification with.
class _FakeWindowsPlugin extends FlutterLocalNotificationsPlatform implements FlutterLocalNotificationsWindows {
  DidReceiveNotificationResponseCallback? click;

  @override
  Future<bool> initialize({
    required WindowsInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  }) async {
    click = onDidReceiveNotificationResponse;
    return true;
  }

  @override
  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails() async => null;

  // The platform interface's own, which take less than the plugin's.
  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    String? payload,
    WindowsNotificationDetails? notificationDetails,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> periodicallyShow({
    required int id,
    String? title,
    String? body,
    String? payload,
    required RepeatInterval repeatInterval,
    WindowsNotificationDetails? notificationDetails,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime scheduledDate,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
    WindowsNotificationDetails? notificationDetails,
  }) =>
      throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

/// A click on a reminder's notification, which carries its page.
NotificationResponse _clickOn(String payload) =>
    NotificationResponse(notificationResponseType: NotificationResponseType.selectedNotification, payload: payload);

/// On Windows, a click on one of the app's notifications brings its window
/// forward as well as opening the notification's page: Windows lets the app
/// take the foreground then, but leaves it to the app to do so.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeWindowsPlugin plugin;
  late List<String> calls;

  setUp(() {
    plugin = _FakeWindowsPlugin();
    FlutterLocalNotificationsPlatform.instance = plugin;
    calls = [];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(windowChannel, (call) async {
      calls.add(call.method);
      return null;
    });
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(windowChannel, null);
  });

  test('a click brings the window forward and opens its page', () async {
    final service = await NotificationService.create();
    expect(service.supported, isTrue);
    final taps = <String>[];
    final subscription = service.taps.listen(taps.add);
    addTearDown(subscription.cancel);

    plugin.click!(_clickOn('/today/week/5787:1'));
    await pumpEventQueue();
    expect(calls, ['activate']);
    expect(taps, ['/today/week/5787:1']);
  });

  // Whatever becomes of the page (the app may not open it yet, or at all),
  // the window comes forward at once, before the user's next input takes the
  // chance away.
  test('a click that launched the app, before it listens, brings the window forward and keeps its page', () async {
    final service = await NotificationService.create();
    plugin.click!(_clickOn('/today/week/5787:1'));
    await pumpEventQueue();
    expect(calls, ['activate']);
    expect(service.launchRoute, '/today/week/5787:1');
  });

  test('a notification with no page opens Today', () async {
    final service = await NotificationService.create();
    final taps = <String>[];
    final subscription = service.taps.listen(taps.add);
    addTearDown(subscription.cancel);

    plugin.click!(const NotificationResponse(notificationResponseType: NotificationResponseType.selectedNotification));
    await pumpEventQueue();
    expect(calls, ['activate']);
    expect(taps, ['/today']);
  });

  test('a runner without the channel is no error', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(windowChannel, null);
    final service = await NotificationService.create();
    final taps = <String>[];
    final subscription = service.taps.listen(taps.add);
    addTearDown(subscription.cancel);

    plugin.click!(_clickOn('/today'));
    await pumpEventQueue();
    expect(taps, ['/today']);
  });

  // Android, iOS and macOS bring the app forward themselves.
  test('elsewhere, a tap opens its page alone', () async {
    final service = await NotificationService.create();
    final taps = <String>[];
    final subscription = service.taps.listen(taps.add);
    addTearDown(subscription.cancel);

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS]) {
      debugDefaultTargetPlatformOverride = platform;
      plugin.click!(_clickOn('/today'));
    }
    await pumpEventQueue();
    expect(calls, isEmpty);
    expect(taps, ['/today', '/today', '/today']);
  });

  group('a tap', () {
    test('once the app listens goes to it alone', () async {
      final service = NotificationService.disabled();
      final taps = <String>[];
      final subscription = service.taps.listen(taps.add);
      addTearDown(subscription.cancel);

      service.handleTap('/today/week/5787:1');
      await pumpEventQueue();
      expect(taps, ['/today/week/5787:1']);
      expect(service.launchRoute, isNull);
    });

    test('before the app listens is kept for it to open, the latest of them', () async {
      final service = NotificationService.disabled();
      service.handleTap('/today/week/5787:1');
      service.handleTap(null);
      expect(service.launchRoute, '/today');

      final taps = <String>[];
      final subscription = service.taps.listen(taps.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      expect(taps, isEmpty, reason: 'the app opens the launch route itself, after its first frame');
    });
  });
}
