import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/app.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/community/data/demo_forum_repository.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/today/today_screen.dart';

import '../helpers.dart';
import 'tolerant_comparator.dart';

/// The main screens on a 412 dp phone in each of the five themes, in English
/// and in Hebrew, set in the bundled fonts: the redesign as it stands
/// (docs/DESIGN_SYSTEM.md §11.4). They show the capture harness's Friday of
/// Bereshit, with Shlishi under way (test/helpers.dart), so they are the
/// phone_*, he_*, dark_* and hc_* captures of test/screens/capture_test.dart.
///
/// The same test writes the screenshots of Chrome's install dialog
/// (web/manifest.json) to web/screenshots/, so that the dialog shows the app
/// as it is: Today and the reader in the light theme in English, and Today
/// on a computer.
///
/// After a deliberate visual change, review the captures and then run
///
///   flutter test --update-goldens test/goldens/screens_golden_test.dart
///
/// The images are drawn at a device pixel ratio of 1, to keep them small.
void main() {
  setUpAll(() async {
    await loadBundledFonts();
    useTolerantGoldens();
  });

  const screens = {
    'today': '/today',
    'reader': '/read/5787:1/2',
    'parsha': '/parsha',
    'progress': '/progress',
    'community': '/community',
  };
  const themes = {
    AppThemeMode.light: 'light',
    AppThemeMode.dark: 'dark',
    AppThemeMode.sepia: 'sepia',
    AppThemeMode.highContrastLight: 'hcl',
    AppThemeMode.highContrastDark: 'hcd',
  };

  /// Opens the app on [route] in a [size] view, as the capture harness
  /// does, once its texts have loaded.
  Future<ProviderContainer> open(
    WidgetTester tester,
    String route, {
    Size size = const Size(412, 915),
    bool hebrew = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    TodayScreen.forgetCompletions();
    final c = await pumpApp(
      tester,
      settings: AppSettings(
        onboardingComplete: true,
        joinDate: captureJoinDate,
        language: hebrew ? AppLanguage.hebrew : AppLanguage.system,
      ),
      now: captureNow,
      progress: captureProgress(),
      // The sample discussions dated back from the same day: older than a
      // day by any real clock now, so their times are dates.
      forums: DemoForumRepository(clock: () => captureNow),
    );
    c.read(routerProvider).go(route);
    await tester.pump();
    // The texts load on real I/O, behind a spinner that never settles.
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
      if (i >= 3 && find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();
    return c;
  }

  for (final hebrew in [false, true]) {
    final language = hebrew ? 'he' : 'en';
    for (final MapEntry(key: name, value: route) in screens.entries) {
      // Opened once, then shown in each theme in turn.
      testWidgets('$name, $language, in every theme', (tester) async {
        // Soft shadows, as a device draws them; restored before the test
        // ends, as the binding checks.
        debugDisableShadows = false;
        try {
          final c = await open(tester, route, hebrew: hebrew);
          for (final MapEntry(key: theme, value: tag) in themes.entries) {
            c.read(settingsProvider.notifier).update((s) => s.copyWith(theme: theme));
            await tester.pumpAndSettle();
            await expectLater(find.byType(ShnayimMikraApp), matchesGoldenFile('screens/${name}_${language}_$tag.png'));
            if (!hebrew && theme == AppThemeMode.light && (name == 'today' || name == 'reader')) {
              await expectLater(
                find.byType(ShnayimMikraApp),
                matchesGoldenFile('../../web/screenshots/$name-narrow.png'),
              );
            }
          }
        } finally {
          debugDisableShadows = true;
        }
      }, skip: goldensSkipped);
    }
  }

  // The install dialog's wide screenshot: the capture harness's desktop
  // mode, at the size web/manifest.json gives.
  testWidgets('Today on a computer, for the web manifest', (tester) async {
    debugDisableShadows = false;
    try {
      await open(tester, '/today', size: const Size(1366, 860));
      await expectLater(find.byType(ShnayimMikraApp), matchesGoldenFile('../../web/screenshots/today-wide.png'));
    } finally {
      debugDisableShadows = true;
    }
  }, skip: goldensSkipped);
}
