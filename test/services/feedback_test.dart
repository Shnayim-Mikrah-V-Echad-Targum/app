import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/services/feedback.dart';
import 'package:shnayim_mikrah/ui/theme/app_theme.dart';

import '../helpers.dart';

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

    group('that stays', () {
      final navigator = GlobalKey<NavigatorState>();

      /// A second page, over the first, whose button shows a held message,
      /// with [outlivesPage] as given, and closes the page if [thenClose].
      Future<void> pumpPages(WidgetTester tester, {bool outlivesPage = false, bool thenClose = false}) async {
        await tester.pumpWidget(MaterialApp(navigatorKey: navigator, home: const Scaffold(body: Text('First'))));
        unawaited(navigator.currentState!.push(MaterialPageRoute<void>(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                showStatus(
                  context,
                  'Low vision applied',
                  action: SnackBarAction(label: 'Undo', onPressed: () {}),
                  outlivesPage: outlivesPage,
                );
                if (thenClose) Navigator.pop(context);
              },
              child: const Text('Low vision'),
            ),
          ),
        )));
        await tester.pumpAndSettle();
        await pressByKeyboard(tester);
      }

      testWidgets('leaves as its page is closed', (tester) async {
        await pumpPages(tester);
        expect(find.text('Low vision applied'), findsOneWidget);
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.text('First'), findsOneWidget);
        expect(find.text('Low vision applied'), findsNothing);
      });

      testWidgets('leaves as another page covers its own', (tester) async {
        await pumpPages(tester);
        unawaited(navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Next')))));
        await tester.pumpAndSettle();
        expect(find.text('Next'), findsOneWidget);
        expect(find.text('Low vision applied'), findsNothing);
      });

      testWidgets('leaves as its page is hidden, with its tab', (tester) async {
        final hidden = ValueNotifier(false);
        addTearDown(hidden.dispose);
        await tester.pumpWidget(MaterialApp(
          home: ValueListenableBuilder(
            valueListenable: hidden,
            // As the router hides a tab other than the one shown.
            builder: (context, off, child) => TickerMode(enabled: !off, child: child!),
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      showStatus(context, 'Low vision applied', action: SnackBarAction(label: 'Undo', onPressed: () {})),
                  child: const Text('Low vision'),
                ),
              ),
            ),
          ),
        ));
        await pressByKeyboard(tester);
        expect(find.text('Low vision applied'), findsOneWidget);
        hidden.value = true;
        await tester.pumpAndSettle();
        expect(find.text('Low vision applied'), findsNothing);
      });

      testWidgets('outlives a page that shows it as it closes, if it says so', (tester) async {
        await pumpPages(tester, outlivesPage: true, thenClose: true);
        expect(find.text('First'), findsOneWidget);
        await tester.pump(const Duration(seconds: 10));
        await tester.pumpAndSettle();
        expect(find.text('Low vision applied'), findsOneWidget, reason: 'on the page beneath, held');
      });
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

  group('a held message in Hebrew, its Undo and Close', () {
    setUpAll(loadBundledFonts);

    Future<void> show(WidgetTester tester, {required double width, double textScale = 1}) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(mode: AppThemeMode.light, uiFont: UiFont.standard, hebrewUi: true, reduceMotion: false),
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: StatusMessageArea.window(child: child!),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showStatus(
                context,
                'הוחל: ראייה ירודה',
                action: SnackBarAction(label: 'ביטול פעולה', onPressed: () {}),
              ),
              child: const Text('ראייה ירודה'),
            ),
          ),
        ),
      ));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Close'), findsOneWidget, reason: 'held, for the keyboard');
    }

    double middle(WidgetTester tester, Finder f) => tester.getCenter(f).dy;

    testWidgets('stay on its line on a 320 dp phone', (tester) async {
      await show(tester, width: 320);
      final line = middle(tester, find.text('הוחל: ראייה ירודה'));
      expect(middle(tester, find.text('ביטול פעולה')), moreOrLessEquals(line, epsilon: 2));
      expect(middle(tester, find.byTooltip('Close')), moreOrLessEquals(line, epsilon: 2));
    });

    testWidgets('go under it at twice the text size, where they would leave it no room', (tester) async {
      await show(tester, width: 412, textScale: 2);
      expect(middle(tester, find.text('ביטול פעולה')), greaterThan(tester.getBottomLeft(find.text('הוחל: ראייה ירודה')).dy));
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
