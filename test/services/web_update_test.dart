import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikrah/app/providers.dart';
import 'package:shnayim_mikrah/app/router.dart';
import 'package:shnayim_mikrah/features/community/ui/compose_screen.dart';
import 'package:shnayim_mikrah/features/community/ui/thread_screen.dart';
import 'package:shnayim_mikrah/features/reader/reader_screen.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/services/web_update.dart';
import 'package:shnayim_mikrah/ui/widgets/common.dart';
import 'package:shnayim_mikrah/ui/widgets/ornaments.dart';

import '../helpers.dart';

/// New versions as web/flutter_bootstrap.js tells of them: [waiting] at
/// start, then [announce]d.
class FakeWebUpdates extends WebUpdates {
  FakeWebUpdates({this.waiting = false});

  @override
  bool waiting;

  final listeners = <void Function()>[];
  final takeoverListeners = <void Function()>[];

  /// What storage held at each restart: the settings saved by then.
  final restarts = <String?>[];

  SharedPreferences? prefs;

  void announce() {
    waiting = true;
    for (final listener in [...listeners]) {
      listener();
    }
  }

  /// A restart in another window, which lets the new version take this one
  /// over.
  void takeOver() {
    for (final listener in [...takeoverListeners]) {
      listener();
    }
  }

  @override
  void Function() listen(void Function() onReady) {
    listeners.add(onReady);
    return () => listeners.remove(onReady);
  }

  @override
  void Function() listenForTakeover(void Function() onTakeover) {
    takeoverListeners.add(onTakeover);
    return () => takeoverListeners.remove(onTakeover);
  }

  @override
  void restart() => restarts.add(prefs?.getString(SettingsController.storageKey));
}

void main() {
  setUpAll(loadBundledFonts);

  group('WebUpdateReady', () {
    test('follows the new versions the bootstrap tells of, and stops listening when disposed', () {
      final updates = FakeWebUpdates();
      final container = ProviderContainer(overrides: [webUpdatesProvider.overrideWithValue(updates)]);
      expect(container.read(webUpdateReadyProvider), isFalse);
      updates.announce();
      expect(container.read(webUpdateReadyProvider), isTrue);
      container.dispose();
      expect(updates.listeners, isEmpty);

      // One already waiting as the app starts.
      final waiting = ProviderContainer(overrides: [webUpdatesProvider.overrideWithValue(FakeWebUpdates(waiting: true))]);
      addTearDown(waiting.dispose);
      expect(waiting.read(webUpdateReadyProvider), isTrue);
    });

    test('is never ready off the web', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(const WebUpdates().waiting, isFalse);
      expect(container.read(webUpdateReadyProvider), isFalse);
    });

    test('restarts only once the settings and progress held back are saved', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final updates = FakeWebUpdates(waiting: true)..prefs = prefs;
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        webUpdatesProvider.overrideWithValue(updates),
      ]);
      addTearDown(container.dispose);
      container.read(settingsProvider.notifier).update((s) => s.copyWith(showStreaks: false));
      // Held back for a moment, as a burst of changes is.
      expect(prefs.getString(SettingsController.storageKey), isNull);
      await container.read(webUpdateReadyProvider.notifier).restart();
      expect(updates.restarts, hasLength(1));
      final saved = AppSettings.fromJson(jsonDecode(updates.restarts.single!) as Map<String, dynamic>);
      expect(saved.showStreaks, isFalse);
    });

    test('restarts all the same when storage fails', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final updates = FakeWebUpdates(waiting: true);
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith(_FailingSettings.new),
        webUpdatesProvider.overrideWithValue(updates),
      ]);
      addTearDown(container.dispose);
      final printed = <String?>[];
      final print = debugPrint;
      debugPrint = (message, {wrapWidth}) => printed.add(message);
      addTearDown(() => debugPrint = print);

      await container.read(webUpdateReadyProvider.notifier).restart();
      expect(updates.restarts, hasLength(1));
      expect(printed, [contains('Could not save before restarting')]);
    });
  });

  testWidgets('a restart in another window restarts this one too, once what it holds back is saved', (tester) async {
    final updates = FakeWebUpdates(waiting: true);
    final c = await pumpApp(tester, overrides: [webUpdatesProvider.overrideWithValue(updates)]);
    await tester.pumpAndSettle();
    updates.prefs = c.read(sharedPreferencesProvider);
    // On another page than Today and About, which offer the restart.
    c.read(routerProvider).go('/progress');
    await tester.pumpAndSettle();
    c.read(settingsProvider.notifier).update((s) => s.copyWith(showStreaks: false));

    updates.takeOver();
    await tester.pump();
    expect(updates.restarts, hasLength(1));
    final saved = AppSettings.fromJson(jsonDecode(updates.restarts.single!) as Map<String, dynamic>);
    expect(saved.showStreaks, isFalse);

    // The app stops listening as it goes.
    await tester.pumpWidget(const SizedBox());
    expect(updates.takeoverListeners, isEmpty);
  });

  group('the offer of a new version', () {
    Future<ProviderContainer> open(
      WidgetTester tester,
      String route, {
      required List<Override> overrides,
      AppLanguage language = AppLanguage.english,
      double width = 412,
      double textScale = 1,
    }) async {
      tester.view.physicalSize = Size(width, 915);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final c = await pumpApp(
        tester,
        settings: AppSettings(onboardingComplete: true, language: language),
        // A reading day in the week of Bereshit.
        now: captureNow,
        overrides: overrides,
      );
      await go(tester, c, route);
      return c;
    }

    final ready = find.text('A new version is ready.');
    final restart = find.widgetWithText(TextButton, 'Restart');

    testWidgets('is made at the top of Today and in About, and never in the reader, a discussion or a new post',
        (tester) async {
      final c = await open(tester, '/today', overrides: [webUpdateReadyProvider.overrideWithBuild((ref, _) => true)]);
      expect(ready, findsOneWidget);
      expect(restart, findsOneWidget);
      expect(
        tester.widget<NoticeBanner>(find.ancestor(of: ready, matching: find.byType(NoticeBanner))).icon,
        Icons.system_update_alt_outlined,
      );
      // Above the week's title page.
      expect(tester.getTopLeft(ready).dy, lessThan(tester.getTopLeft(find.text('Bereshit').first).dy));

      await go(tester, c, '/settings/about');
      expect(ready, findsOneWidget);
      expect(restart, findsOneWidget);
      // Under the title page, with the version open.
      expect(tester.getTopLeft(ready).dy, greaterThan(tester.getBottomLeft(find.byType(SeferDivider)).dy));

      for (final (route, page) in [
        ('/read/5787:1/2', ReaderScreen),
        ('/community/thread/1', ThreadScreen),
        ('/community/new', ComposeScreen),
      ]) {
        await go(tester, c, route);
        expect(find.byType(page), findsOneWidget, reason: route);
        expect(find.byType(CircularProgressIndicator), findsNothing, reason: route);
        expect(ready, findsNothing, reason: route);
      }
    });

    testWidgets('is made in Hebrew', (tester) async {
      await open(
        tester,
        '/today',
        language: AppLanguage.hebrew,
        overrides: [webUpdateReadyProvider.overrideWithBuild((ref, _) => true)],
      );
      expect(find.text('גרסה חדשה מוכנה.'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'הפעלה מחדש'), findsOneWidget);
    });

    testWidgets('appears once a new version has installed, and Restart restarts into it', (tester) async {
      final updates = FakeWebUpdates();
      await open(tester, '/today', overrides: [webUpdatesProvider.overrideWithValue(updates)]);
      expect(ready, findsNothing);
      updates.announce();
      await tester.pumpAndSettle();
      expect(ready, findsOneWidget);
      await tester.tap(restart);
      await tester.pumpAndSettle();
      expect(updates.restarts, hasLength(1));
    });

    testWidgets('is put away on Today for the session, and About still offers it', (tester) async {
      final c = await open(tester, '/today', overrides: [webUpdatesProvider.overrideWithValue(FakeWebUpdates(waiting: true))]);
      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pumpAndSettle();
      expect(ready, findsNothing);

      await go(tester, c, '/settings/about');
      expect(ready, findsOneWidget);
      // About's stays while the new version waits: it has no close button.
      expect(
        find.descendant(of: find.byType(NoticeBanner), matching: find.byTooltip('Dismiss')),
        findsNothing,
      );

      await go(tester, c, '/today');
      expect(ready, findsNothing);
    });

    testWidgets('sets Restart beside the sentence where both fit on a line, and under it otherwise', (tester) async {
      final overrides = [webUpdateReadyProvider.overrideWithBuild((ref, _) => true)];
      Future<void> expectBeside(bool beside, {double width = 412, double textScale = 1}) async {
        await open(tester, '/today', overrides: overrides, width: width, textScale: textScale);
        final text = tester.getRect(ready);
        final button = tester.getRect(restart);
        final reason = 'at ${width}dp, ${textScale}x';
        if (beside) {
          // In a line, the close button after it.
          expect(button.center.dy, moreOrLessEquals(text.center.dy, epsilon: 2), reason: reason);
          expect(button.left, greaterThanOrEqualTo(text.right), reason: reason);
          final close = tester.getRect(find.byTooltip('Dismiss'));
          expect(close.center.dy, moreOrLessEquals(text.center.dy, epsilon: 2), reason: reason);
          expect(close.left, greaterThanOrEqualTo(button.right), reason: reason);
        } else {
          expect(button.top, greaterThanOrEqualTo(text.bottom), reason: reason);
        }
      }

      await expectBeside(true);
      await expectBeside(true, width: 1366);
      await expectBeside(false, width: 360);
      await expectBeside(false, textScale: 2);
      await expectBeside(false, width: 320, textScale: 3);
    });
  });
}

/// Opens [route] and waits for it to settle, once what it reads from the
/// app's assets (the reader's text) has loaded.
Future<void> go(WidgetTester tester, ProviderContainer c, String route) async {
  c.read(routerProvider).go(route);
  await tester.pump();
  await tester.pump();
  for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Settings whose save to storage fails, as localStorage's does when full.
class _FailingSettings extends SettingsController {
  @override
  Future<void> flush() async => throw Exception('QuotaExceededError');
}
