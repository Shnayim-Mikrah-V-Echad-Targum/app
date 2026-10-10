import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../helpers.dart';
import 'routes.dart';

/// Automated accessibility checks for every main screen: tap targets
/// (48dp Android / 44pt iOS) and labeled controls, in English and Hebrew, at
/// phone and tablet sizes and at 200% text size. Text is laid out in the
/// bundled fonts, so sizes and overflow are the real ones. Text contrast is
/// checked in text_contrast_test.dart.
void main() {
  setUpAll(loadBundledFonts);

  Future<void> open(WidgetTester tester, String route, {AppSettings? settings, Size size = const Size(412, 915), double textScale = 1}) =>
      openRoute(tester, route, settings: settings ?? a11ySettings, now: a11yMonday, size: size, textScale: textScale);

  for (final route in a11yRoutes) {
    testWidgets('a11y guidelines: $route', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, route);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  }

  for (final route in ['/today', '/parsha', '/progress', '/settings/display']) {
    testWidgets('no overflow at 200% text size: $route', (tester) async {
      await open(tester, route, textScale: 2);
      expect(tester.takeException(), isNull);
    });
  }

  // The reader, the most text-dense screen, in the real fonts: guided and
  // full text, in English and Hebrew. Its text contrast and focus-mode ink
  // are checked on the test font in test/app/reader_widget_test.dart.
  group('reader', () {
    /// Opens Noach's Rishon and waits for its texts to load.
    Future<void> openReader(WidgetTester tester, {String mode = '', bool hebrew = false, double textScale = 1}) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final c = await pumpApp(
        tester,
        settings: AppSettings(onboardingComplete: true, language: hebrew ? AppLanguage.hebrew : AppLanguage.system),
        now: a11yMonday,
      );
      // Not openRoute: its settling would wait on the loading spinner.
      c.read(routerProvider).go('/read/5787:2/0$mode');
      await tester.pump();
      await tester.pump();
      for (var i = 0; i < 30 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    }

    for (final (mode, name) in [('', 'guided'), ('?mode=full', 'full text')]) {
      for (final hebrew in [false, true]) {
        testWidgets('a11y guidelines: $name${hebrew ? ', Hebrew' : ''}', (tester) async {
          final handle = tester.ensureSemantics();
          await openReader(tester, mode: mode, hebrew: hebrew);
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          handle.dispose();
        });
      }
    }

    for (final hebrew in [false, true]) {
      testWidgets('no overflow at 200% text size${hebrew ? ', Hebrew' : ''}', (tester) async {
        await openReader(tester, hebrew: hebrew, textScale: 2);
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('Hebrew interface is right-to-left and passes the guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester, '/today', settings: const AppSettings(onboardingComplete: true, language: AppLanguage.hebrew));
    expect(find.text('היום'), findsWidgets);
    final dir = Directionality.of(tester.element(find.byType(Scaffold).first));
    expect(dir, TextDirection.rtl);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('desktop width uses a navigation rail', (tester) async {
    await open(tester, '/today', size: const Size(1366, 900));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
