import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/services/feedback.dart';
import 'package:shnayim_mikra/ui/theme/app_theme.dart';

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

  group('haptics', () {
    /// Plays each of the three levels, with Haptic feedback [on], and returns
    /// what each sent to the platform, by the type HapticFeedback sends
    /// ('vibrate' for HapticFeedback.vibrate()).
    Future<Map<String, List<String>>> play(WidgetTester tester, {bool on = true}) async {
      SharedPreferences.setMockInitialValues({'flutter.settings.v1': jsonEncode(AppSettings(haptics: on).toJson())});
      final prefs = await SharedPreferences.getInstance();
      final sent = <String>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') sent.add(call.arguments as String? ?? 'vibrate');
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
      const levels = {'step': hapticStep, 'success': hapticSuccess, 'celebrate': hapticCelebrate};
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Column(children: [
              for (final MapEntry(key: name, value: haptic) in levels.entries)
                TextButton(onPressed: () => haptic(ref), child: Text(name)),
            ]),
          ),
        ),
      ));
      final played = <String, List<String>>{};
      for (final name in levels.keys) {
        sent.clear();
        await tester.tap(find.text(name));
        await tester.pump();
        played[name] = [...sent];
      }
      return played;
    }

    final nothing = {'step': isEmpty, 'success': isEmpty, 'celebrate': isEmpty};

    testWidgets(
      'on Android are a tick, a click and a heavy click, each played once',
      (tester) async => expect(await play(tester), {
        'step': ['HapticFeedbackType.selectionClick'],
        // Not mediumImpact, the same click there, nor heavyImpact, a tick.
        'success': ['HapticFeedbackType.lightImpact'],
        'celebrate': ['vibrate'],
      }),
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'on iOS are a selection, a medium impact and a success notification',
      (tester) async => expect(await play(tester), {
        'step': ['HapticFeedbackType.selectionClick'],
        'success': ['HapticFeedbackType.mediumImpact'],
        'celebrate': ['HapticFeedbackType.successNotification'],
      }),
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'play nothing on a desktop',
      (tester) async => expect(await play(tester), nothing),
      variant: const TargetPlatformVariant({TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux}),
    );

    testWidgets(
      'play nothing with Haptic feedback off',
      (tester) async => expect(await play(tester, on: false), nothing),
      variant: const TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}),
    );

    testWidgets('a celebrate haptic played is counted, and known for a second as just played', (tester) async {
      expect(celebrationsPlayed, 0);
      expect(celebratedWithin(celebrateQuiet), isFalse);
      await play(tester);
      expect(celebrationsPlayed, 1, reason: 'the celebrate alone, not the step or the success');
      expect(celebratedWithin(celebrateQuiet), isTrue);
      await tester.pump(celebrateQuiet - const Duration(milliseconds: 50));
      expect(celebratedWithin(celebrateQuiet), isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      expect(celebratedWithin(celebrateQuiet), isFalse);
      expect(celebrationsPlayed, 1);
    });

    testWidgets('a celebrate haptic that plays nothing is not counted', (tester) async {
      await play(tester, on: false);
      expect(celebrationsPlayed, 0);
      expect(celebratedWithin(celebrateQuiet), isFalse);
    });
  });

  testWidgets(
    'haptics are available on a phone or a tablet alone',
    (tester) async {
      final phone = {TargetPlatform.android, TargetPlatform.iOS}.contains(defaultTargetPlatform);
      expect(hapticsAvailable, phone);
    },
    variant: TargetPlatformVariant.all(),
  );
}
