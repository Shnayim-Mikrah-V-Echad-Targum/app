import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/app_theme.dart';
import 'package:shnayim_mikra/ui/theme/palette.dart';
import 'package:shnayim_mikra/ui/widgets/progress_widgets.dart';

import '../helpers.dart';

/// docs/DESIGN_SYSTEM.md §6.11: the parsha rings and their legend.
void main() {
  const weights = [34, 31, 26, 25, 22, 22, 6];
  final day = LocalDate(2026, 10, 5);

  /// [aliyot] read in full, then [passes] readings of the next.
  WeekProgress week(int aliyot, {int passes = 0, String id = '5787:1'}) {
    var w = WeekProgress(weekId: id);
    for (var a = 0; a < aliyot; a++) {
      w = w.withAliyah(a, day);
    }
    for (var p = 0; p < passes; p++) {
      w = w.withUnit(aliyot, ReadingPass.values[p], day);
    }
    return w;
  }

  int bit(ReadingPass pass, int aliyah) => 1 << (pass.index * kAliyot + aliyah);

  // The legend's layout depends on real text widths.
  setUpAll(loadBundledFonts);
  setUp(ParshaRings.forgetShown);

  group('geometry', () {
    test('a stroke of 0.055 × size, rings 1.6 strokes apart and a 56 px hole at 104', () {
      final g = RingGeometry(104);
      expect(g.stroke, closeTo(5.72, 1e-9));
      expect(g.radii[0], closeTo(52 - 2.86, 1e-9));
      expect(g.radii[1], closeTo(g.radii[0] - 1.6 * g.stroke, 1e-9));
      expect(g.radii[2], closeTo(g.radii[1] - 1.6 * g.stroke, 1e-9));
      expect(g.hole, closeTo(56, 0.1));
      expect(RingGeometry(88).hole, closeTo(56 * 88 / 104, 0.1));
    });

    test('nothing done draws no arcs; everything done draws seven per ring, clockwise from 12', () {
      expect(ringArcs(weights: weights, from: 0, to: 0), isEmpty);

      const all = (1 << (3 * kAliyot)) - 1;
      final arcs = ringArcs(weights: weights, from: all, to: all);
      expect(arcs, hasLength(21));
      final total = weights.reduce((a, b) => a + b);
      for (var ring = 0; ring < 3; ring++) {
        final mine = arcs.where((a) => a.ring == ring).toList();
        expect(mine.first.start, closeTo(-math.pi / 2 + kRingGap / 2, 1e-9));
        for (var a = 0; a < kAliyot; a++) {
          // Positive sweeps are clockwise on screen, and sized by verses.
          expect(mine[a].sweep, closeTo(2 * math.pi * weights[a] / total - kRingGap, 1e-9));
          if (a > 0) expect(mine[a].start, closeTo(mine[a - 1].start + mine[a - 1].sweep + kRingGap, 1e-9));
        }
      }
    });

    test('a sweep fills the new arcs behind a head that travels clockwise', () {
      const equal = [1, 1, 1, 1, 1, 1, 1];
      final finished = bit(ReadingPass.mikra2, 0) | bit(ReadingPass.mikra2, 1);
      final kept = bit(ReadingPass.mikra1, 0);
      final full = ringArcs(weights: equal, from: kept | finished, to: kept | finished);
      final keptArc = full.singleWhere((a) => a.ring == 0);
      final first = full.firstWhere((a) => a.ring == 1);

      // At the start only what was already done shows, whatever the head.
      expect(ringArcs(weights: equal, from: kept, to: kept | finished, t: 0), [keptArc]);
      // Halfway, the head is in the gap between the two new arcs.
      expect(ringArcs(weights: equal, from: kept, to: kept | finished, t: 0.5), [keptArc, first]);
      // A quarter of the way, the first new arc is half filled from its start.
      final quarter = ringArcs(weights: equal, from: kept, to: kept | finished, t: 0.25);
      expect(quarter.last.ring, 1);
      expect(quarter.last.start, first.start);
      expect(quarter.last.sweep, closeTo((2 * first.sweep + kRingGap) / 4, 1e-9));
      expect(ringArcs(weights: equal, from: kept, to: kept | finished), full);

      // Clearing a unit empties its arc from the start as the head passes.
      final cleared = ringArcs(weights: equal, from: kept, to: 0, t: 0.5);
      expect(cleared.single.start, closeTo(keptArc.start + keptArc.sweep / 2, 1e-9));
      expect(ringArcs(weights: equal, from: kept, to: 0), isEmpty);
    });
  });

  group('rings', () {
    Future<void> pumpRings(
      WidgetTester tester,
      WeekProgress progress, {
      double size = ParshaRings.hero,
      bool hebrew = false,
      TextDirection? direction,
      bool visible = true,
      bool reduceMotion = false,
      String? thirdLabel,
    }) async {
      Widget rings = ParshaRings(progress: progress, aliyahWeights: weights, size: size, thirdLabel: thirdLabel);
      if (direction != null) rings = Directionality(textDirection: direction, child: rings);
      await pumpThemed(
        tester,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
            child: TickerMode(enabled: visible, child: Center(child: rings)),
          ),
        ),
        hebrew: hebrew,
      );
    }

    Future<List<int>> snapshot(WidgetTester tester) async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.descendant(of: find.byType(ParshaRings), matching: find.byType(RepaintBoundary)).first,
      );
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        return data!.buffer.asUint8List();
      });
      return bytes!;
    }

    testWidgets('say every count to screen readers, in words', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRings(tester, week(2, passes: 1));
      expect(
        tester.getSemantics(find.byType(ParshaRings)),
        isSemantics(
          label: '2 of 7 aliyot. First reading: 3 of 7. Second reading: 2 of 7. Targum: 2 of 7',
          isImage: true,
        ),
      );
      await pumpRings(tester, week(2, passes: 1), thirdLabel: 'Rashi');
      expect(
        tester.getSemantics(find.byType(ParshaRings)),
        isSemantics(label: '2 of 7 aliyot. First reading: 3 of 7. Second reading: 2 of 7. Rashi: 2 of 7'),
      );
      handle.dispose();
    });

    testWidgets('count finished aliyot in the centre, except when compact', (tester) async {
      await pumpRings(tester, week(2, passes: 2));
      final context = tester.element(find.byType(ParshaRings));
      expect(tester.widget<Text>(find.text('2/7')).style, SeferType.of(context).ringNumeral);
      expect(find.text('aliyot'), findsOneWidget);
      expect(tester.getSize(find.byType(ParshaRings)), const Size.square(104));

      await pumpRings(tester, week(2, passes: 2), size: ParshaRings.compact);
      expect(find.text('2/7'), findsNothing);
      expect(find.text('aliyot'), findsNothing);
    });

    testWidgets('are drawn the same in both directions of text', (tester) async {
      await pumpRings(tester, week(3, passes: 2), direction: TextDirection.ltr);
      final ltr = await snapshot(tester);
      await pumpRings(tester, week(3, passes: 2), direction: TextDirection.rtl);
      expect(await snapshot(tester), ltr);

      // Compact rings have no words in them, so they match across languages.
      await pumpRings(tester, week(3, passes: 2), size: ParshaRings.compact);
      final english = await snapshot(tester);
      await pumpRings(tester, week(3, passes: 2), size: ParshaRings.compact, hebrew: true);
      expect(await snapshot(tester), english);
    });

    testWidgets('a week shown for the first time does not sweep', (tester) async {
      await pumpRings(tester, week(2));
      expect(tester.binding.transientCallbackCount, 0);
      expect(find.text('2/7'), findsOneWidget);
    });

    testWidgets('sweep once to a unit finished since they were last shown', (tester) async {
      await pumpRings(tester, week(2, passes: 2));
      // Away (another page), then back after finishing Shlishi.
      await pumpThemed(tester, const SizedBox());
      await pumpRings(tester, week(3));

      // The first frame still shows the old progress, then the sweep runs.
      expect(find.text('2/7'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 16));
      // The count cross-fades.
      expect(find.text('2/7'), findsOneWidget);
      expect(find.text('3/7'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('2/7'), findsNothing);
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      // Nothing loops.
      expect(tester.binding.transientCallbackCount, 0);
      expect(find.text('3/7'), findsOneWidget);

      // Shown again with nothing new: no sweep.
      await pumpThemed(tester, const SizedBox());
      await pumpRings(tester, week(3));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('sweep when a unit is finished while they are on screen', (tester) async {
      await pumpRings(tester, week(1));
      await pumpRings(tester, week(1, passes: 1));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('wait until they can be seen', (tester) async {
      await pumpRings(tester, week(2));
      // Covered by the reader while Shlishi is finished.
      await pumpRings(tester, week(3), visible: false);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('2/7'), findsOneWidget);
      expect(find.text('3/7'), findsNothing);

      await pumpRings(tester, week(3));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpAndSettle();
      expect(find.text('3/7'), findsOneWidget);
    });

    testWidgets('sweep from what was last seen over every change made while hidden', (tester) async {
      await pumpRings(tester, week(2));
      final seen = await snapshot(tester);
      await pumpRings(tester, week(2, passes: 1), visible: false);
      await pumpRings(tester, week(3), visible: false);

      await pumpRings(tester, week(3));
      expect(await snapshot(tester), seen);
      await tester.pumpAndSettle();
      final now = await snapshot(tester);
      expect(now, isNot(seen));
      // The end of the sweep is the progress as it is.
      ParshaRings.forgetShown();
      await pumpThemed(tester, const SizedBox());
      await pumpRings(tester, week(3));
      expect(await snapshot(tester), now);
    });

    testWidgets('on Today, sweep when it is shown again after a unit is finished', (tester) async {
      final c = await pumpApp(
        tester,
        settings: AppSettings(onboardingComplete: true, joinDate: LocalDate(2026, 10, 4)),
        now: DateTime(2026, 10, 9, 11),
        progress: ProgressState(weeks: {'5787:1': week(2)}),
      );
      await tester.pumpAndSettle();
      expect(find.text('2/7'), findsOneWidget);

      // Shlishi is finished while another page covers Today.
      c.read(routerProvider).push('/week/5787:1');
      await tester.pumpAndSettle();
      c.read(progressProvider.notifier).markAliyah('5787:1', 2, LocalDate(2026, 10, 9));
      await tester.pumpAndSettle();
      expect(find.text('2/7', skipOffstage: false), findsOneWidget);
      expect(find.text('3/7', skipOffstage: false), findsNothing);

      c.read(routerProvider).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('2/7'), findsOneWidget);
      expect(find.text('3/7'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('2/7'), findsNothing);
      expect(find.text('3/7'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('jump straight to new progress under Reduce Motion', (tester) async {
      await pumpRings(tester, week(2));
      await pumpThemed(tester, const SizedBox());
      await pumpRings(tester, week(3), reduceMotion: true);
      expect(tester.binding.transientCallbackCount, 0);
      expect(find.text('3/7'), findsOneWidget);
      expect(find.text('2/7'), findsNothing);
    });

    testWidgets('another week in the same place does not sweep from this one', (tester) async {
      await pumpRings(tester, week(2));
      await pumpRings(tester, week(5, id: '5787:2'));
      expect(tester.binding.transientCallbackCount, 0);
      expect(find.text('5/7'), findsOneWidget);
    });
  });

  group('legend', () {
    Future<void> pumpLegend(WidgetTester tester, Widget legend, {bool hebrew = false, double width = 360}) =>
        pumpThemed(
          tester,
          Align(alignment: Alignment.topCenter, child: SizedBox(width: width, child: legend)),
          hebrew: hebrew,
        );

    testWidgets('names each ring in its colour with its count, hidden from screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpLegend(tester, RingLegend(progress: week(2, passes: 1)));
      for (final (label, count) in [('First reading', '3 of 7'), ('Second reading', '2 of 7'), ('Targum', '2 of 7')]) {
        expect(find.text(label), findsOneWidget);
        // The count ends the label's row.
        final row = find.ancestor(of: find.text(label), matching: find.byType(Row)).first;
        expect(find.descendant(of: row, matching: find.text(count)), findsOneWidget);
        final box = find.ancestor(of: row, matching: find.byType(Container)).first;
        expect(tester.getSize(box).height, 24);
        expect(find.bySemanticsLabel(label), findsNothing);
      }
      final dots = tester
          .widgetList<DecoratedBox>(find.descendant(of: find.byType(RingLegend), matching: find.byType(DecoratedBox)))
          .map((d) => (d.decoration as BoxDecoration).color)
          .toList();
      expect(dots, [Palettes.seferLight.ringMikra1, Palettes.seferLight.ringMikra2, Palettes.seferLight.ringTargum]);
      final count = tester.widget<Text>(find.text('3 of 7'));
      expect(count.style?.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(count.style?.color, Palettes.light.onSurfaceVariant);
      expect(tester.getTopRight(find.text('3 of 7')).dx, tester.getTopRight(find.byType(RingLegend)).dx);
      handle.dispose();
    });

    testWidgets('names Rashi when Rashi is the third reading, and reads right to left in Hebrew', (tester) async {
      await pumpLegend(tester, RingLegend(progress: week(1), thirdLabel: 'רש״י'), hebrew: true);
      expect(find.text('רש״י'), findsOneWidget);
      expect(find.text('1 מתוך 7'), findsNWidgets(3));
      expect(
        tester.getCenter(find.text('קריאה ראשונה')).dx,
        greaterThan(tester.getCenter(find.text('1 מתוך 7').first).dx),
      );
    });

    testWidgets('puts each count under its name when they cannot share a line', (tester) async {
      await pumpLegend(tester, RingLegend(progress: week(1)), width: 120);
      expect(tester.takeException(), isNull);
      expect(tester.getTopLeft(find.text('1 of 7').first).dy, greaterThan(tester.getTopLeft(find.text('First reading')).dy));
    });
  });

  group('rings with legend', () {
    Future<void> pumpBoth(WidgetTester tester, double width, {bool hebrew = false, double textScale = 1}) =>
        pumpThemed(
          tester,
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(width: width, child: RingsWithLegend(progress: week(2), aliyahWeights: weights)),
          ),
          hebrew: hebrew,
          textScale: textScale,
        );

    testWidgets('side by side when the legend fits, otherwise the rings above it', (tester) async {
      await pumpBoth(tester, 332);
      final rings = tester.getRect(find.byType(ParshaRings));
      expect(tester.getRect(find.byType(RingLegend)).left, rings.right + RingsWithLegend.gap);

      await pumpBoth(tester, 232);
      final stacked = tester.getRect(find.byType(ParshaRings));
      expect(stacked.center.dx, 400);
      expect(tester.getRect(find.byType(RingLegend)).top, stacked.bottom + RingsWithLegend.stackedGap);

      // Large text needs more room beside the rings.
      await pumpBoth(tester, 332, textScale: 2);
      expect(tester.getRect(find.byType(RingLegend)).top, greaterThan(tester.getRect(find.byType(ParshaRings)).bottom));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the rings lead in Hebrew too, on the right', (tester) async {
      await pumpBoth(tester, 332, hebrew: true);
      expect(tester.getRect(find.byType(ParshaRings)).left, greaterThan(tester.getRect(find.byType(RingLegend)).right));
    });

    testWidgets('a wide card keeps the counts near their names', (tester) async {
      await pumpBoth(tester, 800);
      final legend = tester.getRect(find.byType(RingLegend));
      expect(legend.width, lessThan(400));
    });
  });
}
