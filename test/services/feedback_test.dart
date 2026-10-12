import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/services/feedback.dart';

void main() {
  /// Shows a status message where announcements are taken, and returns
  /// those made.
  Future<List<String>> announced(WidgetTester tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(supportsAnnounce: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(onPressed: () => showStatus(context, 'Updated'), child: const Text('Refresh')),
        ),
      ),
    ));
    tester.takeAnnouncements();
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Updated'), findsOneWidget, reason: 'shown in a SnackBar');
    return [for (final a in tester.takeAnnouncements()) a.message];
  }

  testWidgets(
    'on iOS a status message is left to its SnackBar, which VoiceOver reads as a live region',
    (tester) async => expect(await announced(tester), isEmpty),
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'on Windows and macOS a status message is announced once',
    (tester) async => expect(await announced(tester), ['Updated']),
    variant: const TargetPlatformVariant({TargetPlatform.windows, TargetPlatform.macOS}),
  );

  group('a message with an action', () {
    /// A page whose button shows a message, with Undo where [undo] is set.
    Future<void> pumpPage(WidgetTester tester, {bool undo = true}) => tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showStatus(
                  context,
                  'Low vision applied',
                  action: undo ? SnackBarAction(label: 'Undo', onPressed: () {}) : null,
                ),
                child: const Text('Low vision'),
              ),
            ),
          ),
        ));

    /// Presses the button from the keyboard: Tab to it, then Enter.
    Future<void> pressByKeyboard(WidgetTester tester) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.highlightMode, FocusHighlightMode.traditional);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
    }

    final close = find.byTooltip('Close');

    testWidgets('stays, with a Close button, while the keyboard is in use', (tester) async {
      await pumpPage(tester);
      await pressByKeyboard(tester);
      expect(find.text('Low vision applied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('Low vision applied'), findsOneWidget, reason: 'held past its 8 s');
      expect(find.widgetWithText(SnackBarAction, 'Undo'), findsOneWidget);
      expect(close, findsOneWidget);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.text('Low vision applied'), findsNothing, reason: 'closed');
    });

    testWidgets('stays for a screen reader on touch too', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await pumpPage(tester);
      await tester.tap(find.text('Low vision'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('Low vision applied'), findsOneWidget);
      expect(close, findsOneWidget);
    });

    testWidgets('leaves after 8 s on touch, with no Close button', (tester) async {
      await pumpPage(tester);
      await tester.tap(find.text('Low vision'));
      await tester.pumpAndSettle();
      expect(FocusManager.instance.highlightMode, FocusHighlightMode.touch);
      expect(find.text('Low vision applied'), findsOneWidget);
      expect(close, findsNothing);
      await tester.pump(const Duration(seconds: 7));
      expect(find.text('Low vision applied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Low vision applied'), findsNothing);
    });

    testWidgets('that stays gives way to the next message, rather than holding it in a queue', (tester) async {
      var shown = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showStatus(
                context,
                'Message ${++shown}',
                action: SnackBarAction(label: 'Undo', onPressed: () {}),
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      ));
      await pressByKeyboard(tester);
      expect(find.text('Message 1'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Message 1'), findsNothing);
      expect(find.text('Message 2'), findsOneWidget);
    });
  });

  testWidgets('a message with no action leaves after 4 s while the keyboard is in use', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(onPressed: () => showStatus(context, 'Updated'), child: const Text('Refresh')),
        ),
      ),
    ));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Updated'), findsOneWidget);
    expect(find.byTooltip('Close'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Updated'), findsNothing);
  });
}
