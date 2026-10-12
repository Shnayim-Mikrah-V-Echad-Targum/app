import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/reader/scripture_text.dart' show ScriptureVerse, TranslationVerse;
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../helpers.dart';
import 'every_theme.dart';
import 'routes.dart';
import 'semantics_invariants.dart';

/// The [SemanticsInvariants], text contrast (WCAG 1.4.3), tap targets and
/// labels on every route, in each of the five themes: here the second half of
/// the routes, the pages whose texts load, onboarding, focus mode and
/// Progress with every past state, and in semantics_invariants_test.dart the
/// rest, so that the two files run in parallel.
///
/// Each route is opened once and then shown in each theme in turn, as a
/// reader who changes the theme sees it, so a colour a page keeps from the
/// theme it was built in fails too. It keeps the test font, as
/// text_contrast_test.dart explains: textContrastGuideline reads colours from
/// the pixels, which the bundled fonts' thin strokes blur. Tap targets in the
/// bundled fonts' real metrics are checked in screens_a11y_test.dart.
void main() {
  for (final route in a11yRoutesSecondHalf) {
    testWidgets('every theme: $route', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await open(tester, route);
      await expectInEveryTheme(tester, c);
      handle.dispose();
    });
  }

  for (final route in a11yLoadingRoutes) {
    testWidgets('every theme: $route', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await open(tester, route);
      // A page whose texts load shows them, not an error or an empty page on
      // which every rule would pass: its verses, which rule 4 checks.
      expect(find.bySemanticsLabel(SemanticsInvariants.verseLabel), findsWidgets);
      await expectInEveryTheme(tester, c);
      handle.dispose();
    });
  }

  for (final route in a11yOnboardingRoutes) {
    testWidgets('every theme: $route', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await open(tester, route, settings: const AppSettings());
      await expectInEveryTheme(tester, c);
      handle.dispose();
    });
  }

  // Focus mode dims every verse but the reader's, in its own ink: the light
  // themes, where a dim ink comes nearest the paper, read as a whole. (The
  // dimmed verses alone are checked in every theme in
  // test/app/reader_widget_test.dart.)
  testWidgets('focus mode, in the light and sepia themes', (tester) async {
    final handle = tester.ensureSemantics();
    final c = await open(
      tester,
      '/read/5787:2/0?mode=full',
      settings: const AppSettings(onboardingComplete: true, focusMode: true, showTranslation: true),
    );
    // The verses, the reader's in its ink and the rest dimmed, whose
    // contrast this is for.
    expect(find.bySemanticsLabel(SemanticsInvariants.verseLabel), findsWidgets);
    bool dimmed(Widget w) => w is ScriptureVerse && w.dimmed;
    expect(find.byWidgetPredicate(dimmed), findsWidgets);
    expect(find.byWidgetPredicate((w) => w is ScriptureVerse && !w.dimmed), findsWidgets);
    expect(find.byWidgetPredicate((w) => w is TranslationVerse && w.dimmed), findsWidgets);
    await expectInEveryTheme(tester, c, themes: const [AppThemeMode.light, AppThemeMode.sepia]);
    handle.dispose();
  });

  // The Torah map with a parsha read on time, one finished after its
  // Shabbat, one missed and one made up, all in view.
  testWidgets('every theme: /progress with every past state', (tester) async {
    final handle = tester.ensureSemantics();
    final c = await open(
      tester,
      '/progress',
      settings: AppSettings(onboardingComplete: true, joinDate: historyJoinDate),
      now: historyNow,
      progress: historyProgress(),
      size: const Size(412, 2600),
    );
    for (final state in ['On time', 'After Shabbat — still counts', 'Not completed', 'Made up']) {
      expect(find.bySemanticsLabel(RegExp(': ${RegExp.escape(state)}')), findsWidgets, reason: state);
    }
    await expectInEveryTheme(tester, c);
    handle.dispose();
  });
}
