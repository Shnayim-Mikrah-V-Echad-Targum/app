import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/motion.dart';
import 'package:shnayim_mikra/ui/widgets/ornaments.dart';

import '../../helpers.dart';

// The finished panel (DESIGN_SYSTEM.md §6.23), in the week of Bereshit 5787:
// Monday 5 October to Friday 9 October 2026, an aliyah a day and two on
// Thursday and Friday (Rishon, Sheni, Shlishi, Revi'i and Chamishi, Shishi
// and Shevi'i).

final _monday = LocalDate(2026, 10, 5);

/// Bereshit with every aliyah up to [last] read on its planned day, and the
/// Hebrew of aliyah [partly] read twice, so that one step (the Targum, read
/// aliyah by aliyah) finishes it.
ProgressState _readThrough(int last, {required int partly, required LocalDate on}) {
  var w = WeekProgress(weekId: '5787:1');
  for (var a = 0; a <= last; a++) {
    w = w.withAliyah(a, _monday.addDays(a < 3 ? a : (a < 5 ? 3 : 4)));
  }
  w = w
      .withUnit(partly, ReadingPass.mikra1, on)
      .withUnit(partly, ReadingPass.mikra2, on)
      .withPosition(partly, const [99, 99, 0]);
  return ProgressState(weeks: {'5787:1': w});
}

Future<void> _loadTexts(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Opens aliyah [aliyah] of Bereshit on [day] and reads its last step.
Future<void> _finish(
  WidgetTester tester, {
  required int aliyah,
  required DateTime day,
  required ProgressState progress,
  AppSettings settings = const AppSettings(),
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = await pumpApp(
    tester,
    settings: settings.copyWith(
      onboardingComplete: true,
      notificationPromptShown: true,
      joinDate: LocalDate(2026, 10, 4),
      method: ReadingMethod.aliyahByAliyah,
      repeatLastVerse: false,
    ),
    now: day,
    progress: progress,
  );
  c.read(routerProvider).go('/read/5787:1/$aliyah');
  await _loadTexts(tester);
  await tester.tap(find.text('Finish'));
  if (settle) await tester.pumpAndSettle();
}

bool _focused(WidgetTester tester, String label) => Focus.of(tester.element(find.text(label))).hasFocus;

void main() {
  testWidgets('finishing Shlishi with the day still ahead names Revi\'i, and how long it is', (tester) async {
    await _finish(tester, aliyah: 2, day: DateTime(2026, 10, 9, 10), progress: _readThrough(1, partly: 2, on: _monday));

    expect(find.text('Shlishi is complete'), findsOneWidget);
    expect(find.text("Revi'i is 21 verses."), findsOneWidget);
    expect(find.widgetWithText(FilledButton, "Next aliyah · Revi'i"), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Done'), findsOneWidget);
    expect(find.textContaining("That's today's reading."), findsNothing, reason: "Friday's own aliyot are still to read");
    expect(find.byIcon(Icons.celebration), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(_focused(tester, "Next aliyah · Revi'i"), isTrue);
  });

  testWidgets("once the day's reading is done, Done leads and going on is quieter", (tester) async {
    await _finish(
      tester,
      aliyah: 2,
      day: DateTime(2026, 10, 7, 10),
      progress: _readThrough(1, partly: 2, on: LocalDate(2026, 10, 7)),
    );

    expect(find.text('Shlishi is complete'), findsOneWidget);
    expect(find.text("That's today's reading. See you tomorrow."), findsOneWidget);
    expect(find.text("Revi'i is 21 verses."), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget);
    expect(find.widgetWithText(TextButton, "Keep going: Revi'i"), findsOneWidget);
    expect(find.textContaining('Next aliyah'), findsNothing);
    expect(_focused(tester, 'Done'), isTrue, reason: 'the first button takes the focus');
  });

  testWidgets("on the plan's last day, Shevi'i is left for Shabbat morning", (tester) async {
    await _finish(
      tester,
      aliyah: 5,
      day: DateTime(2026, 10, 9, 10),
      progress: _readThrough(4, partly: 5, on: LocalDate(2026, 10, 9)),
      settings: const AppSettings(plan: ReadingPlanType.sheviiOnShabbat),
    );

    expect(find.text('Shishi is complete'), findsOneWidget);
    expect(find.text('The rest is for Shabbat morning. Shabbat shalom!'), findsOneWidget);
    expect(find.widgetWithText(TextButton, "Keep going: Shevi'i"), findsOneWidget);
  });

  group('the parsha finished', () {
    testWidgets('on time says so, with the streak and the grace day it earned, and offers the haftarah', (tester) async {
      await _finish(tester, aliyah: 6, day: DateTime(2026, 10, 9, 10), progress: _readThrough(5, partly: 6, on: _monday));

      expect(find.text('Parshat Bereshit is complete'), findsOneWidget);
      expect(find.textContaining('On time · 1-week parsha streak · +1 grace day', findRichText: true), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Read the haftarah'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Done'), findsOneWidget);
      expect(find.textContaining('Next aliyah'), findsNothing);
      expect(_focused(tester, 'Read the haftarah'), isTrue);
    });

    testWidgets('on time, with streaks hidden, says only that', (tester) async {
      await _finish(
        tester,
        aliyah: 6,
        day: DateTime(2026, 10, 9, 10),
        progress: _readThrough(5, partly: 6, on: _monday),
        settings: const AppSettings(showStreaks: false, haftarahEnabled: false),
      );

      expect(find.textContaining(RegExp(r'On time$'), findRichText: true), findsOneWidget);
      expect(find.textContaining('streak', findRichText: true), findsNothing);
      expect(find.text('Read the haftarah'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget, reason: 'with nothing else to do, Done leads');
    });

    testWidgets('after Shabbat says it still counts', (tester) async {
      // Sunday of Noach: Bereshit is in its late window.
      await _finish(tester, aliyah: 6, day: DateTime(2026, 10, 11, 10), progress: _readThrough(5, partly: 6, on: _monday));

      expect(find.text('Parshat Bereshit is complete'), findsOneWidget);
      expect(
        find.textContaining('After Shabbat — and it still counts. Your streak continues.', findRichText: true),
        findsOneWidget,
      );
    });
  });

  testWidgets("the divider's hairlines draw out, then the rest fades in", (tester) async {
    await _finish(
      tester,
      aliyah: 2,
      day: DateTime(2026, 10, 9, 10),
      progress: _readThrough(1, partly: 2, on: _monday),
      settle: false,
    );
    await tester.pump();
    double drawn() => tester.widget<SeferDivider>(find.byType(SeferDivider)).progress;
    double shown() => tester
        .widget<FadeTransition>(find.ancestor(of: find.text('Shlishi is complete'), matching: find.byType(FadeTransition)).first)
        .opacity
        .value;
    expect(drawn(), lessThan(0.1));
    expect(shown(), 0);
    await tester.pump(Motion.long);
    expect(drawn(), 1);
    expect(shown(), 0);
    await tester.pump(Motion.short);
    expect(shown(), 1);
  });

  testWidgets('under Reduce Motion, the panel is simply there', (tester) async {
    await _finish(
      tester,
      aliyah: 2,
      day: DateTime(2026, 10, 9, 10),
      progress: _readThrough(1, partly: 2, on: _monday),
      settings: const AppSettings(reduceMotion: true),
      settle: false,
    );
    await tester.pump();
    expect(tester.widget<SeferDivider>(find.byType(SeferDivider)).progress, 1);
    final fade = find.ancestor(of: find.text('Shlishi is complete'), matching: find.byType(FadeTransition)).first;
    expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
  });
}
