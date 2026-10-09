import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/reader/scripture_text.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../helpers.dart';

void main() {
  final monday = DateTime(2026, 10, 12, 10); // week of Noach, 5787

  Future<void> loadTexts(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('guided verse-by-verse reading records progress', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: const AppSettings(onboardingComplete: true), now: monday);
    c.read(routerProvider).go('/read/5787:2/0');
    await loadTexts(tester);

    expect(find.text('Read the Hebrew'), findsOneWidget);
    expect(find.text('Verse 1 of 14'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Read the Hebrew again'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Read the Targum'), findsOneWidget);
    expect(find.text('Targum Onkelos'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Verse 2 of 14'), findsOneWidget);

    final week = c.read(progressProvider).week('5787:2');
    expect(week.positions[0], [1, 1, 1]);
    expect(week.isAliyahDone(0), isFalse);

    // Mark the rest as read from the menu.
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark this aliyah as read'));
    await tester.pumpAndSettle();
    expect(c.read(progressProvider).week('5787:2').isAliyahDone(0), isTrue);
    expect(find.textContaining('Rishon is complete'), findsWidgets);
  });

  testWidgets('reader meets accessibility guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: const AppSettings(onboardingComplete: true), now: monday);
    c.read(routerProvider).go('/read/5787:2/0');
    await loadTexts(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    // Each verse has a spoken label: "Verse 9." (Noach begins at 6:9) followed by the Hebrew.
    expect(find.bySemanticsLabel(RegExp(r'^Verse 9\. ')), findsWidgets);
    handle.dispose();
  });

  testWidgets('full-text mode shows Torah and Targum together', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: const AppSettings(onboardingComplete: true), now: monday);
    c.read(routerProvider).go('/read/5787:2/0?mode=full');
    await loadTexts(tester);
    expect(find.text('Chapter 6'), findsOneWidget);
    expect(find.text('Mark this aliyah as read'), findsNothing, reason: 'the button is at the end of the list');
  });

  // Focus mode dims every verse but the one tapped. The dimmed ink must still
  // be readable (4.5:1), not a 55% alpha fade of the normal ink.
  for (final theme in AppThemeMode.values.where((m) => m != AppThemeMode.system)) {
    testWidgets('focus mode dims verses with readable ink: ${theme.name}', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await pumpApp(
        tester,
        settings: AppSettings(onboardingComplete: true, theme: theme, focusMode: true, showTranslation: true),
        now: monday,
      );
      c.read(routerProvider).go('/read/5787:2/0?mode=full');
      await loadTexts(tester);
      await tester.tap(find.byType(ScriptureVerse).first);
      await tester.pumpAndSettle();

      final dimmed = find.byWidgetPredicate(
        (w) => (w is ScriptureVerse && w.dimmed) || (w is TranslationVerse && w.dimmed),
      );
      expect(dimmed, findsWidgets);
      await expectLater(
        tester,
        meetsGuideline(CustomMinimumContrastGuideline(finder: dimmed, minimumRatio: 4.5)),
      );
    });
  }

  testWidgets('onboarding sets the join date and opens the reader', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: const AppSettings(), now: monday);
    await tester.pumpAndSettle();
    await tester.tap(find.text("Start this week's parsha"));
    await tester.pumpAndSettle();
    expect(find.text('Where will you be this Shabbat?'), findsOneWidget);
    await tester.tap(find.text('In Israel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Your plan this week'), findsOneWidget);
    await tester.tap(find.text('Start reading'));
    await loadTexts(tester);
    final s = c.read(settingsProvider);
    expect(s.onboardingComplete, isTrue);
    expect(s.israel, isTrue);
    expect(s.joinDate, isNotNull);
    expect(find.text('Read the Hebrew'), findsOneWidget);
    expect(kAliyot, 7);
  });
}
