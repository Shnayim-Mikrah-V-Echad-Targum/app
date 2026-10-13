import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/app/app.dart';
import 'package:shnayim_mikrah/app/providers.dart';
import 'package:shnayim_mikrah/app/router.dart';
import 'package:shnayim_mikrah/features/community/data/demo_forum_repository.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/features/today/today_screen.dart';

import '../helpers.dart';
import 'tolerant_comparator.dart';

/// The main screens on a 412 dp phone in each of the five themes, in English
/// and in Hebrew, set in the bundled fonts: the redesign as it stands
/// (docs/DESIGN_SYSTEM.md §11.4). They show the capture harness's Friday of
/// Bereshit, with Shlishi under way (test/helpers.dart), so they are the
/// phone_*, he_*, dark_* and hc_* captures of test/screens/capture_test.dart.
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

  for (final hebrew in [false, true]) {
    final language = hebrew ? 'he' : 'en';
    for (final MapEntry(key: name, value: route) in screens.entries) {
      // Opened once, then shown in each theme in turn.
      testWidgets('$name, $language, in every theme', (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        TodayScreen.forgetCompletions();
        // Soft shadows, as a device draws them; restored before the test
        // ends, as the binding checks.
        debugDisableShadows = false;
        try {
          final c = await pumpApp(
            tester,
            settings: AppSettings(
              onboardingComplete: true,
              joinDate: captureJoinDate,
              language: hebrew ? AppLanguage.hebrew : AppLanguage.system,
            ),
            now: captureNow,
            progress: captureProgress(),
            // The sample discussions dated back from the same day: older than
            // a day by any real clock now, so their times are dates.
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
          for (final MapEntry(key: theme, value: tag) in themes.entries) {
            c.read(settingsProvider.notifier).update((s) => s.copyWith(theme: theme));
            await tester.pumpAndSettle();
            await expectLater(find.byType(ShnayimMikrahApp), matchesGoldenFile('screens/${name}_${language}_$tag.png'));
          }
        } finally {
          debugDisableShadows = true;
        }
      }, skip: goldensSkipped);
    }
  }
}
