import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../helpers.dart';
import 'routes.dart';

/// Text contrast (WCAG 1.4.3) on every main screen and in every theme.
///
/// textContrastGuideline reads the colours from the rendered pixels around
/// each text and takes the most common dark and light ones. That only works
/// with the test font, whose glyphs are solid blocks of the text colour: the
/// thin strokes of the bundled fonts are mostly anti-aliased edge pixels, which
/// can outnumber the true text colour (a 16px "Wide" in 16:1 ink measured
/// 3.9:1). So, unlike screens_a11y_test.dart, this file never loads them. The
/// colour pairs themselves are checked in test/ui/palette_contrast_test.dart.
void main() {
  Future<void> expectReadableText(WidgetTester tester, String route, {AppSettings settings = a11ySettings}) async {
    final handle = tester.ensureSemantics();
    await openRoute(tester, route, settings: settings, now: a11yMonday);
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  }

  for (final route in a11yRoutes) {
    testWidgets('text contrast: $route', (tester) => expectReadableText(tester, route));
  }

  for (final theme in [AppThemeMode.dark, AppThemeMode.sepia, AppThemeMode.highContrastLight, AppThemeMode.highContrastDark]) {
    testWidgets('text contrast in the ${theme.name} theme', (tester) async {
      await expectReadableText(tester, '/today', settings: AppSettings(onboardingComplete: true, theme: theme));
    });
  }
}
