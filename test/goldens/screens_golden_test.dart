import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
/// So is the full text on an 800 dp tablet, its tablet_reader_full, where
/// scripture's lines are set to the reading column's measure.
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
  // The install dialog's screenshots (web/manifest.json): these screens on
  // a phone, in the light theme in English, and [webWide] on a computer.
  const webNarrow = {'today', 'reader'};
  const webWide = 'today';
  const themes = {
    AppThemeMode.light: 'light',
    AppThemeMode.dark: 'dark',
    AppThemeMode.sepia: 'sepia',
    AppThemeMode.highContrastLight: 'hcl',
    AppThemeMode.highContrastDark: 'hcd',
  };

  /// Opens [route] in a [size] view, in English or Hebrew, once the texts
  /// have loaded; then runs [check], with soft shadows, as a device draws
  /// them (restored before the test ends, as the binding checks).
  Future<void> show(
    WidgetTester tester,
    String route, {
    required bool hebrew,
    Size size = const Size(412, 915),
    required Future<void> Function(ProviderContainer c) check,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    TodayScreen.forgetCompletions();
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
      await check(c);
    } finally {
      debugDisableShadows = true;
    }
  }

  for (final hebrew in [false, true]) {
    final language = hebrew ? 'he' : 'en';
    for (final MapEntry(key: name, value: route) in screens.entries) {
      // Opened once, then shown in each theme in turn.
      testWidgets('$name, $language, in every theme', (tester) async {
        await show(tester, route, hebrew: hebrew, check: (c) async {
          for (final MapEntry(key: theme, value: tag) in themes.entries) {
            c.read(settingsProvider.notifier).update((s) => s.copyWith(theme: theme));
            await tester.pumpAndSettle();
            await expectLater(find.byType(ShnayimMikrahApp), matchesGoldenFile('screens/${name}_${language}_$tag.png'));
            if (!hebrew && theme == AppThemeMode.light && webNarrow.contains(name)) {
              await expectLater(
                find.byType(ShnayimMikrahApp),
                matchesGoldenFile('../../web/screenshots/$name-narrow.png'),
              );
            }
          }
        });
      }, skip: goldensSkipped);
    }
  }

  // The install dialog's wide screenshot: the capture harness's desktop
  // mode, at the size web/manifest.json gives.
  testWidgets('Today on a computer, for the web manifest', (tester) async {
    await show(tester, screens[webWide]!, hebrew: false, size: const Size(1366, 860), check: (c) async {
      await expectLater(find.byType(ShnayimMikrahApp), matchesGoldenFile('../../web/screenshots/$webWide-wide.png'));
    });
  }, skip: goldensSkipped);

  // On every platform, unlike the goldens: so that the dialog never shows a
  // screenshot these tests no longer write, gone stale.
  test('web/manifest.json shows the screenshots these tests write', () {
    expect(screens.keys, containsAll({...webNarrow, webWide}));
    final manifest = jsonDecode(File('web/manifest.json').readAsStringSync()) as Map<String, dynamic>;
    expect(
      [for (final shot in (manifest['screenshots'] as List).cast<Map<String, dynamic>>()) shot['src']],
      [for (final name in webNarrow) 'screenshots/$name-narrow.png', 'screenshots/$webWide-wide.png'],
    );
  });

  // The full text on a tablet, as the tablet_reader_full capture shows it:
  // the Torah's and the Targum's verses set to the column's measure,
  // justified, as its measure is wide enough (§4.7), none ending on a word
  // alone.
  testWidgets('reader_full, en, on a tablet', (tester) async {
    await show(tester, '/read/5787:1/2?mode=full', hebrew: false, size: const Size(800, 1180), check: (c) async {
      await expectLater(find.byType(ShnayimMikrahApp), matchesGoldenFile('screens/reader_full_tablet_en_light.png'));
    });
  }, skip: goldensSkipped);
}
