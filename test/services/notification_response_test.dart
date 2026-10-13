import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/services/notifications.dart';

/// A tap on one of the app's notifications opens its page: through [NotificationService.taps]
/// once the app listens, and before that as the route the app opens after its first frame.
void main() {
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
