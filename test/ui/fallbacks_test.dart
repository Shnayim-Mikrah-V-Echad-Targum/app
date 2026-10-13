import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/ui/widgets/fallbacks.dart';
import 'package:shnayim_mikra/ui/widgets/ornaments.dart';

import '../helpers.dart';

void main() {
  const message = 'Couldn’t reach the server. Check your connection and try again.';
  final retry = find.widgetWithText(FilledButton, 'Try again');

  group('ErrorMessage', () {
    testWidgets('says why under a divider, and tries again when asked', (tester) async {
      var retries = 0;
      await pumpThemed(tester, ErrorMessage(message: message, onRetry: () => retries++));
      expect(find.byType(SeferDivider), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      expect(find.descendant(of: retry, matching: find.byIcon(Icons.refresh)), findsOneWidget);
      expect(find.byType(Scrollable), findsNothing, reason: 'it sits in the page that shows it');
      await tester.tap(retry);
      expect(retries, 1);
    });

    testWidgets('while it retries, spins in place of its icon, and stays enabled but does nothing', (tester) async {
      var retries = 0;
      await pumpThemed(tester, ErrorMessage(message: message, onRetry: () => retries++, retrying: true));
      expect(find.descendant(of: retry, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
      expect(find.descendant(of: retry, matching: find.byIcon(Icons.refresh)), findsNothing);
      expect(tester.widget<FilledButton>(retry).enabled, isTrue, reason: 'so that it keeps the keyboard focus');
      await tester.tap(retry);
      expect(retries, 0);
    });
  });

  group('tried again and failing again', () {
    for (final announces in [true, false]) {
      testWidgets(
          'says why again, ${announces ? 'announced' : 'a new live region each time, where nothing is announced'}',
          (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(supportsAnnounce: announces);
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        final semantics = tester.ensureSemantics();
        Future<void> pump({required bool retrying}) =>
            pumpThemed(tester, ErrorMessage(message: message, onRetry: () {}, retrying: retrying));
        int? liveRegion() {
          final node = tester.getSemantics(find.text(message));
          return node.flagsCollection.isLiveRegion ? node.id : null;
        }

        await pump(retrying: false);
        await pump(retrying: true);
        expect(tester.takeAnnouncements(), isEmpty, reason: 'nothing said until the outcome');
        expect(liveRegion(), isNull);

        // Failed again: the page looks just as it did, and the button keeps
        // the focus, so the message is said again.
        await pump(retrying: false);
        expect([for (final a in tester.takeAnnouncements()) a.message], announces ? [message] : isEmpty);
        final first = liveRegion();
        expect(first, announces ? isNull : isNotNull);

        await pump(retrying: true);
        await pump(retrying: false);
        expect([for (final a in tester.takeAnnouncements()) a.message], announces ? [message] : isEmpty);
        if (!announces) expect(liveRegion(), allOf(isNotNull, isNot(first)), reason: 'a live region new to the screen reader');
        semantics.dispose();
      });
    }

    testWidgets('as a whole page says why again too', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(supportsAnnounce: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      Future<void> pump({required bool retrying}) =>
          pumpThemed(tester, ErrorState(message: message, onRetry: () {}, retrying: retrying));
      await pump(retrying: true);
      await pump(retrying: false);
      expect([for (final a in tester.takeAnnouncements()) a.message], [message]);
    });
  });

  group('ErrorState', () {
    testWidgets('can be pulled to refresh, and offers Try again before any other action', (tester) async {
      var retries = 0;
      await pumpThemed(
        tester,
        ErrorState(
          message: message,
          onRetry: () => retries++,
          actions: [TextButton(onPressed: () {}, child: const Text('All forums'))],
        ),
      );
      final scrollable = tester.widget<Scrollable>(find.byType(Scrollable));
      expect(scrollable.physics, isA<AlwaysScrollableScrollPhysics>());
      expect(tester.getTopLeft(retry).dx, lessThan(tester.getTopLeft(find.text('All forums')).dx));
      await tester.tap(retry);
      expect(retries, 1);
    });
  });
}
