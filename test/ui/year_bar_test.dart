import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/features/progress/domain/streak_engine.dart';
import 'package:shnayim_mikra/ui/theme/palette.dart';
import 'package:shnayim_mikra/ui/widgets/year_bar.dart';

import '../helpers.dart';

/// docs/DESIGN_SYSTEM.md §6.15: the year's 54 parshiyot in one bar.
void main() {
  setUpAll(loadBundledFonts);

  const open = YearSegment.open;
  List<YearSegment> year(Map<int, YearSegment> states) => [
        for (var n = 1; n <= kParshaCount; n++) states[n] ?? open,
      ];

  group('segments', () {
    WeekEvaluation evaluation(int number, LocalDate occasion, WeekStatus status, {bool combined = false}) {
      final portion = PortionId(number, combined: combined);
      final week = ReadingWeek(
        portion: portion,
        occasion: occasion,
        start: occasion.addDays(-6),
        plan: const [],
        israel: false,
      );
      return WeekEvaluation(
        WeekPlan(week: week, weekId: weekIdFor(portion, occasion), days: const [], shabbatAliyot: const []),
        status,
        null,
      );
    }

    // Shabbatot of 5787, from Bereshit on 10 October 2026.
    LocalDate shabbat(int n) => LocalDate(2026, 10, 10).addDays(7 * (n - 1));

    test('show how each week of this year ended', () {
      final segments = YearBar.segmentsFor(
        weeks: [
          evaluation(1, shabbat(1), WeekStatus.onTime),
          evaluation(2, shabbat(2), WeekStatus.late),
          evaluation(3, shabbat(3), WeekStatus.restored),
          evaluation(4, shabbat(4), WeekStatus.madeUp),
          // Missed, then finished later in the year.
          evaluation(5, shabbat(5), WeekStatus.missed),
          evaluation(6, shabbat(6), WeekStatus.missed),
          // A week of last year's cycle is not this year's.
          evaluation(7, LocalDate(2025, 11, 22), WeekStatus.onTime),
        ],
        cycle: 5787,
        done: {1, 2, 3, 4, 5},
        current: const PortionId(8),
      );
      expect(segments, hasLength(kParshaCount));
      expect(segments.sublist(0, 9), [
        YearSegment.onTime,
        YearSegment.late,
        YearSegment.late,
        YearSegment.madeUp,
        YearSegment.madeUp,
        open,
        open,
        YearSegment.current,
        open,
      ]);
      expect(segments.skip(8), everyElement(open));
    });

    test('a double portion is current in both its segments, and on time once done', () {
      const vayakhelPekudei = PortionId(22, combined: true);
      expect(
        YearBar.segmentsFor(weeks: const [], cycle: 5787, done: const {}, current: vayakhelPekudei).sublist(20, 24),
        [open, YearSegment.current, YearSegment.current, open],
      );
      expect(
        YearBar.segmentsFor(weeks: const [], cycle: 5787, done: const {22, 23}, current: vayakhelPekudei).sublist(21, 23),
        [YearSegment.onTime, YearSegment.onTime],
      );
    });
  });

  group('bar', () {
    // At 392 wide, 53 gaps of 2 and 4 extra between each two books leave 54
    // segments of 5, so every edge falls on a whole pixel.
    const barWidth = 392.0;
    const segment = 5.0;

    Future<void> pumpBar(
      WidgetTester tester,
      YearBar bar, {
      double width = barWidth,
      bool hebrew = false,
      double textScale = 1,
    }) =>
        pumpThemed(
          tester,
          Align(alignment: Alignment.topLeft, child: SizedBox(width: width, child: bar)),
          hebrew: hebrew,
          textScale: textScale,
        );

    Future<ui.Image> snapshot(WidgetTester tester) async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.descendant(of: find.byType(YearBar), matching: find.byType(RepaintBoundary)).first,
      );
      return (await tester.runAsync(() => boundary.toImage()))!;
    }

    Future<Color> pixel(WidgetTester tester, ui.Image image, double x, double y) async {
      final data = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
      final i = (y.floor() * image.width + x.floor()) * 4;
      return Color.fromARGB(data.getUint8(i + 3), data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
    }

    testWidgets('is one sentence for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpBar(
        tester,
        YearBar(
          segments: year({1: YearSegment.onTime, 2: YearSegment.late, 3: YearSegment.madeUp, 4: YearSegment.current}),
          currentName: 'Vayera',
        ),
      );
      expect(
        tester.getSemantics(find.byType(YearBar)),
        isSemantics(label: 'This year: 3 of 54 parshiyot complete; Vayera in progress'),
      );
      expect(find.bySemanticsLabel('Gen'), findsNothing);

      // Nothing is in progress once this week's parsha is finished.
      await pumpBar(tester, YearBar(segments: year({1: YearSegment.onTime}), currentName: 'Bereshit'));
      expect(tester.getSemantics(find.byType(YearBar)), isSemantics(label: 'This year: 1 of 54 parshiyot complete'));

      await pumpBar(
        tester,
        YearBar(segments: year({1: YearSegment.current}), currentName: 'בראשית'),
        hebrew: true,
      );
      expect(
        tester.getSemantics(find.byType(YearBar)),
        isSemantics(label: 'השנה: הושלמו 0 מתוך 54 פרשות; פרשת בראשית בתהליך'),
      );
      handle.dispose();
    });

    testWidgets('names each book under its first segment', (tester) async {
      await pumpBar(tester, YearBar(segments: year(const {})));
      final paint = find.descendant(of: find.byType(YearBar), matching: find.byType(CustomPaint));
      expect(tester.getSize(paint), const Size(barWidth, YearBar.height));
      expect(tester.getTopLeft(find.text('Gen')).dx, 0);
      // Exodus starts after Genesis's 12 segments, 12 gaps and a book gap.
      expect(tester.getTopLeft(find.text('Exo')).dx, 12 * segment + 12 * 2 + 4);
      for (final name in ['Gen', 'Exo', 'Lev', 'Num', 'Deu']) {
        final text = tester.widget<Text>(find.text(name));
        expect(text.style?.color, Palettes.light.onSurfaceVariant);
      }
    });

    testWidgets('colours each state, and runs right to left in Hebrew', (tester) async {
      final states = year({1: YearSegment.onTime, 2: YearSegment.late, 3: YearSegment.madeUp, 54: YearSegment.current});
      Future<List<Color>> colours({required bool hebrew}) async {
        await pumpBar(tester, YearBar(segments: states), hebrew: hebrew);
        final image = await snapshot(tester);
        // The left edge of parsha n's segment.
        double left(int n) {
          final start = (n - 1) * (segment + 2) + 4 * bookIndexOfParsha(n);
          return hebrew ? barWidth - start - segment : start;
        }

        Future<Color> at(double x) => pixel(tester, image, x, YearBar.height / 2);
        final out = [
          for (final n in [1, 2, 3, 5, 54]) await at(left(n) + segment / 2),
          // The 1 px borders.
          await at(left(3) + 0.5),
          await at(left(54) + 0.5),
        ];
        image.dispose();
        return out;
      }

      final expected = [
        Palettes.statusLight.done,
        Palettes.statusLight.late,
        Palettes.seferLight.paper,
        Palettes.seferLight.ringTrack,
        Palettes.light.primaryContainer,
        Palettes.statusLight.late,
        Palettes.light.primary,
      ];
      expect(await colours(hebrew: false), expected);
      expect(await colours(hebrew: true), expected);
      expect(tester.getTopRight(find.text('בר׳')).dx, barWidth);
      expect(tester.getCenter(find.text('בר׳')).dx, greaterThan(tester.getCenter(find.text('דב׳')).dx));
    });

    testWidgets('fits a 360 dp phone, even with 200% text', (tester) async {
      // 360 less two 20 dp gutters and a card's 20 dp padding each side.
      for (final scale in [1.0, 2.0]) {
        await pumpBar(tester, YearBar(segments: year(const {1: YearSegment.current})), width: 280, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(YearBar)).width, 280);
        for (final name in ['Gen', 'Exo', 'Lev', 'Num', 'Deu']) {
          expect(tester.getRect(find.text(name)).right, lessThanOrEqualTo(280));
        }
        // The names never touch.
        expect(tester.getRect(find.text('Num')).right, lessThan(tester.getRect(find.text('Deu')).left));
        // When the tightest has to shrink, they all shrink with it.
        final names = ['Gen', 'Exo', 'Lev', 'Num', 'Deu'];
        expect({for (final name in names) tester.getRect(find.text(name)).height}, hasLength(1), reason: '${scale}x');
      }
    });

    testWidgets('Hebrew: the names shrink together too', (tester) async {
      await pumpBar(tester, YearBar(segments: year(const {})), width: 280, textScale: 2, hebrew: true);
      expect(tester.takeException(), isNull);
      final names = ['בר׳', 'שמ׳', 'וי׳', 'במ׳', 'דב׳'];
      expect({for (final name in names) tester.getRect(find.text(name)).height}, hasLength(1));
      for (var i = 0; i + 1 < names.length; i++) {
        // Right to left: each book's name ends before the next one's begins.
        expect(tester.getRect(find.text(names[i])).left, greaterThan(tester.getRect(find.text(names[i + 1])).right));
      }
    });
  });
}
