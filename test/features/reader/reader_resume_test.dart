import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../../helpers.dart';

/// Friday 9 October 2026, in the week of Bereshit 5787.
final _friday = DateTime(2026, 10, 9, 11);

void main() {
  Future<void> loadTexts(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, {ProgressState? progress}) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(
      tester,
      settings: AppSettings(onboardingComplete: true, notificationPromptShown: true, joinDate: LocalDate(2026, 10, 4)),
      now: _friday,
      progress: progress,
    );
    c.read(routerProvider).go('/read/5787:1/2');
    await loadTexts(tester);
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  void expectStep(String step, int verse) {
    expect(find.text(step), findsOneWidget);
    expect(find.text('Verse $verse of 27'), findsOneWidget);
  }

  testWidgets('read twice from a Chumash, Shlishi goes on from Targum to Targum, verse by verse', (tester) async {
    // Shlishi read twice in Hebrew, marked from a Chumash: no saved place.
    final mon = LocalDate(2026, 10, 5);
    final week = WeekProgress(weekId: '5787:1')
        .withUnit(2, ReadingPass.mikra1, mon.addDays(2))
        .withUnit(2, ReadingPass.mikra2, mon.addDays(2));
    await open(tester, progress: ProgressState(weeks: {'5787:1': week}));

    expectStep('Read the Targum', 1);
    await tap(tester, 'Next');
    expectStep('Read the Targum', 2);
    await tap(tester, 'Next');
    expectStep('Read the Targum', 3);

    // Back retraces the way it came, Targum to Targum.
    await tap(tester, 'Back');
    expectStep('Read the Targum', 2);
    await tap(tester, 'Back');
    expectStep('Read the Targum', 1);
    // Where it began, the Hebrew read from the Chumash is still there to see.
    await tap(tester, 'Back');
    expectStep('Read the Hebrew again', 1);
  });

  testWidgets('read in the app, every verse is read three times, and Back returns to each reading', (tester) async {
    await open(tester);
    expectStep('Read the Hebrew', 1);
    await tap(tester, 'Next');
    await tap(tester, 'Next');
    await tap(tester, 'Next');
    expectStep('Read the Hebrew', 2);
    await tap(tester, 'Next');
    expectStep('Read the Hebrew again', 2);
    await tap(tester, 'Back');
    expectStep('Read the Hebrew', 2);
    await tap(tester, 'Back');
    expectStep('Read the Targum', 1);
  });
}
