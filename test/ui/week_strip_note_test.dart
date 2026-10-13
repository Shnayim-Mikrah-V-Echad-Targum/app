import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/core/calendar/local_date.dart';
import 'package:shnayim_mikrah/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikrah/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikrah/ui/widgets/progress_widgets.dart';

import '../helpers.dart';

/// docs/DESIGN_SYSTEM.md §6.13: the note under a day of Yom Tov or of a
/// quiet Tisha B'Av, with the app's fonts, whose widths decide it.
void main() {
  setUpAll(loadBundledFonts);

  // The week of Bereshit 5787 in the Diaspora: Sunday 4 October is Simchat
  // Torah.
  const planner = ReadingPlanner(schedule: ParshaSchedule(israel: false));
  final plan = planner.planFor(planner.schedule.weekFor(LocalDate(2026, 10, 7)));

  Future<void> pump(WidgetTester tester, {required double width, double textScale = 1, bool hebrew = false}) =>
      pumpThemed(
        tester,
        Center(
          child: SizedBox(
            width: width,
            child: WeekStrip(
              plan: plan,
              today: LocalDate(2026, 10, 9),
              statuses: const {},
              oneDayYomTov: false,
              onDayTap: (_) {},
            ),
          ),
        ),
        textScale: textScale,
        hebrew: hebrew,
      );

  /// The note's paragraph, and the size it is drawn at, its scale and any
  /// shrinking applied.
  (RenderParagraph, double) drawn(WidgetTester tester, String text) {
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.text(text), matching: find.byType(RichText)).first,
    );
    final strip = tester.renderObject(find.byType(WeekStrip));
    final transform = paragraph.getTransformTo(strip);
    final size = paragraph.textScaler.scale(paragraph.text.style!.fontSize!) *
        Offset(transform.entry(0, 0), transform.entry(1, 0)).distance;
    return (paragraph, size);
  }

  int linesOf(RenderParagraph paragraph, String text) => {
        for (final box in paragraph.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: text.length)))
          box.top.round(),
      }.length;

  // The strip of a 412 dp phone is 364 wide, a day 52 and its content 44;
  // "Yom Tov" at 12 is about 48.
  testWidgets('on a phone, "Yom Tov" wraps between its words at its size, rather than shrink under 12',
      (tester) async {
    await pump(tester, width: 364);
    final (paragraph, size) = drawn(tester, 'Yom Tov');
    expect(size, moreOrLessEquals(12));
    expect(linesOf(paragraph, 'Yom Tov'), 2);
    expectWordsWhole(tester, 'Yom Tov');
    // "יו״ט" fits.
    await pump(tester, width: 364, hebrew: true);
    final (hebrew, hebrewSize) = drawn(tester, 'יו״ט');
    expect(hebrewSize, moreOrLessEquals(12));
    expect(linesOf(hebrew, 'יו״ט'), 1);
  });

  testWidgets('where a day has room, it keeps to one line', (tester) async {
    await pump(tester, width: 600);
    final (paragraph, size) = drawn(tester, 'Yom Tov');
    expect(size, moreOrLessEquals(12));
    expect(linesOf(paragraph, 'Yom Tov'), 1);
  });

  // Android's 115% and 130%, iOS's larger sizes, and 200%.
  for (final scale in [1.0, 1.15, 1.3, 2.0]) {
    testWidgets('at ${scale}x it is drawn at its full size wherever it is', (tester) async {
      for (final width in [320.0, 345.0, 364.0, 500.0, 700.0]) {
        await pump(tester, width: width, textScale: scale);
        expect(tester.takeException(), isNull, reason: '$width');
        expect(drawn(tester, 'Yom Tov').$2, moreOrLessEquals(12 * scale), reason: '$width');
        expectWordsWhole(tester, 'Yom Tov');
      }
    });
  }

  testWidgets("a quiet Tisha B'Av's date keeps to one line on a phone", (tester) async {
    final tuesday = LocalDate(2027, 8, 10);
    final quiet = ReadingPlanner(
      schedule: const ParshaSchedule(israel: false),
      settingsAt: (_) => const PlanSettingsEntry(tishaBavQuiet: true),
    );
    final week = quiet.planFor(quiet.schedule.weekFor(tuesday));
    for (final (hebrew, text) in [(false, '9 Av'), (true, 'ט׳ באב')]) {
      await pumpThemed(
        tester,
        Center(
          child: SizedBox(
            width: 364,
            child: WeekStrip(plan: week, today: tuesday, statuses: const {}, oneDayYomTov: false, onDayTap: (_) {}),
          ),
        ),
        hebrew: hebrew,
      );
      final (paragraph, size) = drawn(tester, text);
      expect(size, moreOrLessEquals(12), reason: text);
      expect(linesOf(paragraph, text), 1, reason: text);
    }
  });
}
