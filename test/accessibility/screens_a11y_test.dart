import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../helpers.dart';

/// Automated accessibility checks for every main screen: tap targets
/// (48dp Android / 44pt iOS), labeled controls, and text contrast — in
/// English and Hebrew, phone and tablet sizes, and at 200% text size.
void main() {
  final monday = DateTime(2026, 10, 12, 10);
  const routes = [
    '/today',
    '/parsha',
    '/parsha/browse',
    '/progress',
    '/community',
    '/settings',
    '/settings/reading',
    '/settings/display',
    '/settings/accessibility',
    '/settings/reminders',
    '/settings/about',
    '/guide',
  ];

  Future<void> open(WidgetTester tester, String route, {AppSettings? settings, Size size = const Size(412, 915), double textScale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final container = await pumpApp(
      tester,
      settings: settings ?? AppSettings(onboardingComplete: true, joinDate: null),
      now: monday,
    );
    container.read(routerProvider).go(route);
    await tester.pumpAndSettle();
    // Let asset-backed previews (e.g. display settings) load.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
  }

  for (final route in routes) {
    testWidgets('a11y guidelines: $route', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, route);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }

  for (final theme in [AppThemeMode.dark, AppThemeMode.sepia, AppThemeMode.highContrastLight, AppThemeMode.highContrastDark]) {
    testWidgets('text contrast in the ${theme.name} theme', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, '/today', settings: AppSettings(onboardingComplete: true, theme: theme));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }

  for (final route in ['/today', '/parsha', '/progress', '/settings/display']) {
    testWidgets('no overflow at 200% text size: $route', (tester) async {
      await open(tester, route, textScale: 2);
      expect(tester.takeException(), isNull);
    });
  }

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
