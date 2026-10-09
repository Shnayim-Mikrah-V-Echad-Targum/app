import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
