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

/// Bereshit with each aliyah in [read] read on its day, and the Hebrew of
/// aliyah [partly] read twice on [on], so that one step finishes it.
ProgressState _bereshit(Map<int, LocalDate> read, {required int partly, required LocalDate on}) {
  var w = WeekProgress(weekId: '5787:1');
  for (final MapEntry(key: a, value: day) in read.entries) {
    w = w.withAliyah(a, day);
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

/// Opens aliyah [aliyah] of Bereshit (or of [week]) on [day] and reads on
/// to its end.
Future<void> _finish(
  WidgetTester tester, {
  required int aliyah,
  required DateTime day,
  required ProgressState progress,
  AppSettings settings = const AppSettings(),
  String week = '5787:1',
  bool settle = true,
  bool repeat = false,
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = await pumpApp(
    tester,
    // The repeat set as the reader sets it, off unless [repeat]: untouched,
    // it follows the haftarah custom, and is read back on.
    settings: settings
        .copyWith(
          onboardingComplete: true,
          notificationPromptShown: true,
          joinDate: LocalDate(2026, 10, 4),
          method: ReadingMethod.aliyahByAliyah,
        )
        .withRepeatLastVerse(repeat),
    now: day,
    progress: progress,
  );
  c.read(routerProvider).go('/read/$week/$aliyah');
  await _loadTexts(tester);
  // Read whole already, an aliyah starts again from its first step.
  for (var i = 0; i < 3 && find.text('Finish').evaluate().isEmpty; i++) {
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
  }
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

  testWidgets("with the days ahead read ahead, the next reading is the next day that has some", (tester) async {
    // Tuesday: Rishon and Sheni read on their days, then Shlishi and Revi'i
    // read ahead, and Chamishi finished. Wednesday's and Thursday's are read.
    final tuesday = LocalDate(2026, 10, 6);
    await _finish(
      tester,
      aliyah: 4,
      day: DateTime(2026, 10, 6, 10),
      progress: _bereshit({0: _monday, 1: tuesday, 2: tuesday, 3: tuesday}, partly: 4, on: tuesday),
    );

    expect(find.text('Chamishi is complete'), findsOneWidget);
    expect(find.text("That's today's reading. See\u00A0you\u00A0on\u00A0Friday."), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Keep going: Shishi'), findsOneWidget);
  });

  testWidgets('with an earlier aliyah still due, the panel offers the next as on any day', (tester) async {
    // Wednesday: Rishon read, but not Sheni, which was Tuesday's.
    final wednesday = LocalDate(2026, 10, 7);
    await _finish(
      tester,
      aliyah: 2,
      day: DateTime(2026, 10, 7, 10),
      progress: _bereshit({0: _monday}, partly: 2, on: wednesday),
    );

    expect(find.text('Shlishi is complete'), findsOneWidget);
    expect(find.textContaining("That's today's reading."), findsNothing);
    expect(find.widgetWithText(FilledButton, "Next aliyah · Revi'i"), findsOneWidget);
  });

  testWidgets('on the eve of Yom Tov, the greeting is for the chag', (tester) async {
    // Ha'azinu 5788, read on the Shabbat after Rosh Hashanah 5789 (Thursday
    // and Friday, 21 and 22 September 2028): Shishi finished on Wednesday,
    // and Shevi'i left for Shabbat morning.
    final wednesday = LocalDate(2028, 9, 20);
    var w = WeekProgress(weekId: '5788:53');
    for (var a = 0; a < 5; a++) {
      w = w.withAliyah(a, LocalDate(2028, 9, 17 + a ~/ 2));
    }
    w = w.withUnit(5, ReadingPass.mikra1, wednesday).withUnit(5, ReadingPass.mikra2, wednesday).withPosition(5, const [99, 99, 0]);
    await _finish(
      tester,
      week: '5788:53',
      aliyah: 5,
      day: DateTime(2028, 9, 20, 10),
      progress: ProgressState(weeks: {'5788:53': w}),
      settings: const AppSettings(plan: ReadingPlanType.sheviiOnShabbat),
    );

    expect(find.text('Shishi is complete'), findsOneWidget);
    expect(find.text('The rest is for Shabbat morning. Chag\u00A0sameach!'), findsOneWidget);
  });

  group('the parsha finished', () {
    testWidgets('on time says so, with the streak and the grace day it earned, and offers the haftarah', (tester) async {
      await _finish(tester, aliyah: 6, day: DateTime(2026, 10, 9, 10), progress: _readThrough(5, partly: 6, on: _monday));

      expect(find.text('Parshat Bereshit is complete'), findsOneWidget);
      // The grace day held together, so that "day" is never left alone on a
      // line.
      expect(find.textContaining('On time · 1-week parsha streak · +1\u00A0grace\u00A0day', findRichText: true), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Read the haftarah'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Done'), findsOneWidget);
      expect(find.textContaining('Next aliyah'), findsNothing);
      expect(_focused(tester, 'Read the haftarah'), isTrue);
    });

    testWidgets('on time, with the last verse repeated after its Targum, still tells of the streak', (tester) async {
      // The Targum completes the parsha, and the repeat of its last verse,
      // as the custom has it, finishes the aliyah after it.
      await _finish(
        tester,
        aliyah: 6,
        day: DateTime(2026, 10, 9, 10),
        progress: _readThrough(5, partly: 6, on: _monday),
        repeat: true,
      );

      expect(find.text('Parshat Bereshit is complete'), findsOneWidget);
      expect(find.textContaining('On time · 1-week parsha streak · +1\u00A0grace\u00A0day', findRichText: true), findsOneWidget);
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

    testWidgets('together with the next, says the streak continues', (tester) async {
      // Thursday of Noach, with Noach read: Bereshit, past its late window,
      // is finished in time to be doubled up.
      final thursday = LocalDate(2026, 10, 15);
      var noach = WeekProgress(weekId: '5787:2');
      for (var a = 0; a < 7; a++) {
        noach = noach.withAliyah(a, LocalDate(2026, 10, 12 + a ~/ 3));
      }
      final bereshit = _readThrough(5, partly: 6, on: thursday);
      await _finish(
        tester,
        aliyah: 6,
        day: DateTime(2026, 10, 15, 10),
        progress: bereshit.copyWith(weeks: {...bereshit.weeks, '5787:2': noach}),
      );

      expect(find.text('Parshat Bereshit is complete'), findsOneWidget);
      expect(
        find.textContaining('Finished together with the next parsha — your streak continues.', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('read again weeks later, says only how it stands, with no streak or grace day', (tester) async {
      // Wednesday of Noach: Bereshit was finished on time, and its Shevi'i
      // is read through once more.
      var bereshit = WeekProgress(weekId: '5787:1');
      for (var a = 0; a < 7; a++) {
        bereshit = bereshit.withAliyah(a, _monday.addDays(a < 3 ? a : (a < 5 ? 3 : 4)));
      }
      await _finish(
        tester,
        aliyah: 6,
        day: DateTime(2026, 10, 14, 10),
        progress: ProgressState(weeks: {'5787:1': bereshit}),
      );

      expect(find.text('Parshat Bereshit is complete'), findsOneWidget);
      expect(find.textContaining(RegExp(r'On time$'), findRichText: true), findsOneWidget);
      expect(find.textContaining('streak', findRichText: true), findsNothing);
      expect(find.textContaining('grace', findRichText: true), findsNothing);
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
