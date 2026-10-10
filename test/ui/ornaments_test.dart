import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/palette.dart';
import 'package:shnayim_mikra/ui/theme/typography.dart';
import 'package:shnayim_mikra/ui/widgets/ornaments.dart';

import '../helpers.dart';

/// docs/DESIGN_SYSTEM.md §7: the ornaments' sizes, colours and order, without
/// goldens.
void main() {
  const light = Palettes.seferLight;
  const done = PipState.done;
  const pending = PipState.pending;

  /// The render object of the painter inside [of].
  RenderObject painterOf(WidgetTester tester, Finder of) =>
      tester.renderObject(find.descendant(of: of, matching: find.byType(CustomPaint)).first);

  group('Lozenge', () {
    testWidgets('comes in 8 and 12, a diamond filled in gold leaf', (tester) async {
      await pumpThemed(tester, const Center(child: Lozenge()));
      expect(tester.getSize(find.byType(Lozenge)), const Size(8, 8));
      expect(
        painterOf(tester, find.byType(Lozenge)),
        paints
          ..path(
            color: light.goldLeaf,
            style: PaintingStyle.fill,
            // M4,0 L8,4 L4,8 L0,4: the middle of each side, not the corners.
            includes: const [Offset(4, 4), Offset(4, 0.5), Offset(7.5, 4), Offset(4, 7.5), Offset(0.5, 4)],
            excludes: const [Offset(0.5, 0.5), Offset(7.5, 0.5), Offset(0.5, 7.5), Offset(7.5, 7.5)],
          ),
      );

      await pumpThemed(tester, const Center(child: Lozenge(size: Lozenge.large)));
      expect(tester.getSize(find.byType(Lozenge)), const Size(12, 12));
      expect(
        painterOf(tester, find.byType(Lozenge)),
        paints..path(includes: const [Offset(6, 0.5), Offset(11.5, 6)], excludes: const [Offset(1, 1)]),
      );
    });

    testWidgets('high contrast draws it in onSurface', (tester) async {
      await pumpThemed(tester, const Center(child: Lozenge()), theme: AppThemeMode.highContrastDark);
      expect(painterOf(tester, find.byType(Lozenge)), paints..path(color: Palettes.hcDark.onSurface));
    });

    testWidgets('outlined, it is stroked inside the box', (tester) async {
      await pumpThemed(tester, const Center(child: Lozenge(size: Lozenge.large, outlined: true)));
      expect(
        painterOf(tester, find.byType(Lozenge)),
        paints
          ..path(
            style: PaintingStyle.stroke,
            strokeWidth: 1.5,
            // The stroke's centre line runs 0.75 inside the edges.
            includes: const [Offset(6, 1.5)],
            excludes: const [Offset(6, 0.5)],
          ),
      );
    });
  });

  group('SeferDivider', () {
    final painted = find.descendant(of: find.byType(SeferDivider), matching: find.byType(CustomPaint));
    Future<void> pumpIn(WidgetTester tester, double column, Widget divider, {AppThemeMode theme = AppThemeMode.light}) =>
        pumpThemed(tester, Center(child: SizedBox(width: column, child: divider)), theme: theme);

    testWidgets('is 45% of the column, at most 200, by 16', (tester) async {
      await pumpIn(tester, 300, const SeferDivider());
      expect(tester.getSize(painted), const Size(135, 16));
      await pumpIn(tester, 600, const SeferDivider());
      expect(tester.getSize(painted), const Size(200, 16));
      await pumpIn(tester, 600, const SeferDivider(width: 120));
      expect(tester.getSize(painted), const Size(120, 16));
      // Centred in the column.
      expect(tester.getCenter(painted).dx, tester.getCenter(find.byType(SeferDivider)).dx);
    });

    testWidgets('draws hairlines to 10 short of a gold-leaf lozenge', (tester) async {
      await pumpIn(tester, 300, const SeferDivider());
      // 135 wide: the centre is at 67.5, and the hairline sits on a whole pixel.
      expect(
        painterOf(tester, find.byType(SeferDivider)),
        paints
          ..rect(rect: const Rect.fromLTWH(0, 7, 57.5, 1), color: light.hairline)
          ..rect(rect: const Rect.fromLTWH(77.5, 7, 57.5, 1), color: light.hairline)
          ..path(
            color: light.goldLeaf,
            includes: const [Offset(67.5, 7.5), Offset(67.5, 4)],
            excludes: const [Offset(67.5, 2.5), Offset(62, 7.5)],
          ),
      );
    });

    testWidgets('draws its hairlines outward from the lozenge as it progresses', (tester) async {
      await pumpIn(tester, 300, const SeferDivider(progress: 0.5));
      expect(
        painterOf(tester, find.byType(SeferDivider)),
        paints
          ..rect(rect: const Rect.fromLTWH(28.75, 7, 28.75, 1))
          ..rect(rect: const Rect.fromLTWH(77.5, 7, 28.75, 1))
          ..path(color: light.goldLeaf),
      );
      await pumpIn(tester, 300, const SeferDivider(progress: 0));
      expect(painterOf(tester, find.byType(SeferDivider)), isNot(paints..rect()));
      expect(painterOf(tester, find.byType(SeferDivider)), paints..path(color: light.goldLeaf));
    });

    testWidgets('high contrast: 2 px rules and a lozenge in onSurface', (tester) async {
      await pumpIn(tester, 300, const SeferDivider(), theme: AppThemeMode.highContrastDark);
      final ink = Palettes.hcDark.onSurface;
      expect(
        painterOf(tester, find.byType(SeferDivider)),
        paints
          ..rect(rect: const Rect.fromLTWH(0, 7, 57.5, 2), color: ink)
          ..rect(rect: const Rect.fromLTWH(77.5, 7, 57.5, 2), color: ink)
          ..path(color: ink, includes: const [Offset(67.5, 8)]),
      );
    });

    testWidgets('can be sized by its intrinsic width, in a dialog or a row', (tester) async {
      await pumpThemed(
        tester,
        const Center(
          child: IntrinsicWidth(
            child: Column(mainAxisSize: MainAxisSize.min, children: [SeferDivider(), SizedBox(width: 300)]),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(painted), const Size(135, 16));

      await pumpThemed(tester, const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [SeferDivider()])));
      expect(tester.getSize(painted), const Size(200, 16));
    });
  });

  group('SectionBreakMark', () {
    testWidgets('sets פ or ס in gold ink at 0.55 of the verse, between 40 px hairlines', (tester) async {
      await pumpThemed(tester, const SectionBreakMark(SectionBreak.petuchah, verseSize: 26));
      final style = tester.widget<Text>(find.text('פ')).style!;
      expect(style.fontFamily, 'FrankRuhlLibre');
      expect(style.fontSize, closeTo(14.3, 1e-9));
      expect(style.fontWeight, FontWeight.w600);
      expect(style.color, Palettes.light.secondary);

      final rules = find.descendant(of: find.byType(SectionBreakMark), matching: find.byType(ColoredBox));
      expect(rules, findsNWidgets(2));
      for (var i = 0; i < 2; i++) {
        expect(tester.widget<ColoredBox>(rules.at(i)).color, light.hairline);
        expect(tester.getSize(rules.at(i)), const Size(40, 1));
      }
      // Centred: an 8 gap either side of the letter.
      final letter = tester.getRect(find.text('פ'));
      expect(letter.left - tester.getRect(rules.first).right, 8);
      expect(tester.getRect(rules.last).left - letter.right, 8);
      expect(letter.center.dx, closeTo(tester.getCenter(find.byType(SectionBreakMark)).dx, 0.01));

      await pumpThemed(tester, const SectionBreakMark(SectionBreak.setumah, verseSize: 40));
      expect(tester.widget<Text>(find.text('ס')).style!.fontSize, closeTo(22, 1e-9));
    });

    testWidgets('high contrast: bold, in onSurface, with 2 px rules', (tester) async {
      await pumpThemed(
        tester,
        const SectionBreakMark(SectionBreak.setumah, verseSize: 26),
        theme: AppThemeMode.highContrastDark,
      );
      final style = tester.widget<Text>(find.text('ס')).style!;
      expect(style.fontWeight, FontWeight.w700);
      expect(style.color, Palettes.hcDark.onSurface);
      final rule = find.descendant(of: find.byType(SectionBreakMark), matching: find.byType(ColoredBox)).first;
      expect(tester.widget<ColoredBox>(rule).color, Palettes.hcDark.onSurface);
      expect(tester.getSize(rule), const Size(40, 2));
    });
  });

  group('TitlePageFrame', () {
    Finder ruleFinder() => find.byWidgetPredicate((w) => w is CustomPaint && w.child is Padding);
    Material frameMaterial(WidgetTester tester) =>
        tester.widget<Material>(find.descendant(of: find.byType(TitlePageFrame), matching: find.byType(Material)));

    testWidgets('a hairline at radius 12 round paper, and a gold rule inset 6 at radius 8', (tester) async {
      await pumpThemed(
        tester,
        const Center(child: TitlePageFrame(child: SizedBox(width: 200, height: 100))),
      );
      // The default padding is 24.
      expect(tester.getSize(find.byType(TitlePageFrame)), const Size(248, 148));
      final material = frameMaterial(tester);
      expect(material.color, light.paper);
      expect(
        material.shape,
        RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: light.hairline),
        ),
      );
      // The 1 px stroke's outer edge on the inset and the radius.
      expect(
        tester.renderObject(ruleFinder()),
        paints
          ..rrect(
            rrect: RRect.fromRectAndRadius(const Rect.fromLTRB(6.5, 6.5, 241.5, 141.5), const Radius.circular(7.5)),
            color: light.goldLeaf,
            strokeWidth: 1,
            style: PaintingStyle.stroke,
          ),
      );
    });

    testWidgets('draws its rule clockwise from the top centre as it progresses', (tester) async {
      Future<void> pumpAt(double? progress, {TextDirection direction = TextDirection.ltr}) => pumpThemed(
            tester,
            Directionality(
              textDirection: direction,
              child: Center(
                child: TitlePageFrame(
                  drawProgress: progress,
                  padding: EdgeInsets.zero,
                  child: const SizedBox(width: 200, height: 100),
                ),
              ),
            ),
          );

      for (final direction in TextDirection.values) {
        // Half way round is the bottom centre, by the right-hand side, in
        // both directions: a frame is not text.
        await pumpAt(0.5, direction: direction);
        expect(
          tester.renderObject(ruleFinder()),
          paints
            ..path(
              color: light.goldLeaf,
              style: PaintingStyle.stroke,
              includes: const [Offset(150, 50)],
              excludes: const [Offset(50, 50)],
            ),
          reason: '$direction',
        );
      }
      await pumpAt(0);
      expect(tester.renderObject(ruleFinder()), paintsNothing);
      await pumpAt(1);
      expect(tester.renderObject(ruleFinder()), paints..rrect(color: light.goldLeaf));
    });

    testWidgets('high contrast: one 2 px outline, no inner rule', (tester) async {
      await pumpThemed(
        tester,
        const Center(child: TitlePageFrame(child: SizedBox(width: 200, height: 100))),
        theme: AppThemeMode.highContrastDark,
      );
      final side = (frameMaterial(tester).shape! as RoundedRectangleBorder).side;
      expect((side.color, side.width), (Palettes.hcDark.onSurface, 2));
      expect(tester.widget<CustomPaint>(ruleFinder()).painter, isNull);
    });

    testWidgets('keeps its content in the semantics tree', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(tester, const TitlePageFrame(child: Text('Bereshit')));
      expect(find.bySemanticsLabel('Bereshit'), findsOneWidget);
      handle.dispose();
    });
  });

  group('PassPips', () {
    List<Lozenge> pips(WidgetTester tester) =>
        tester.widgetList<Lozenge>(find.descendant(of: find.byType(PassPips), matching: find.byType(Lozenge))).toList();

    testWidgets('three 12 px lozenges 8 apart, or mini ones 3 apart', (tester) async {
      await pumpThemed(tester, const Center(child: PassPips(states: [done, done, pending])));
      expect(tester.getSize(find.byType(PassPips)), const Size(3 * 12 + 2 * 8, 12));
      expect(pips(tester).map((p) => p.size), everyElement(12));

      await pumpThemed(tester, const Center(child: PassPips(states: [done, pending, pending], size: PassPips.mini)));
      expect(tester.getSize(find.byType(PassPips)), const Size(3 * 6 + 2 * 3, 6));
    });

    testWidgets('done is filled in its ring colour, pending outlined, current ringed', (tester) async {
      await pumpThemed(tester, const Center(child: PassPips(states: [done, done, pending], current: 2)));
      final p = pips(tester);
      expect([for (final pip in p) pip.color], [light.ringMikra1, light.ringMikra2, light.ringTargum]);
      expect([for (final pip in p) pip.outlined], [false, false, true]);
      expect([for (final pip in p) pip.ringed], [false, false, true]);

      final painters = find.descendant(of: find.byType(PassPips), matching: find.byType(CustomPaint));
      expect(tester.renderObject(painters.at(0)), paints..path(color: light.ringMikra1, style: PaintingStyle.fill));
      expect(
        tester.renderObject(painters.at(2)),
        paints
          ..path(color: light.ringTargum, style: PaintingStyle.stroke, strokeWidth: 1.5)
          // The ring, 1.5 clear of the lozenge, reaches outside its box.
          ..path(
            color: light.ringTargum,
            style: PaintingStyle.stroke,
            strokeWidth: 2,
            includes: const [Offset(6, -2)],
            excludes: const [Offset(6, -4.5)],
          ),
      );
    });

    testWidgets('run in reading order: the first reading is rightmost in Hebrew', (tester) async {
      for (final hebrew in [false, true]) {
        await pumpThemed(tester, const Center(child: PassPips(states: [done, pending, pending])), hebrew: hebrew);
        final xs = [
          for (final pip in find.descendant(of: find.byType(PassPips), matching: find.byType(Lozenge)).evaluate())
            tester.getCenter(find.byWidget(pip.widget)).dx,
        ];
        final colors = pips(tester).map((p) => p.color).toList();
        expect(colors.first, light.ringMikra1);
        expect(xs[0] < xs[1] && xs[1] < xs[2], !hebrew, reason: 'hebrew: $hebrew, $xs');
        expect(xs[0] > xs[1] && xs[1] > xs[2], hebrew, reason: 'hebrew: $hebrew, $xs');
      }
    });

    testWidgets('high contrast draws every pip in onSurface', (tester) async {
      await pumpThemed(
        tester,
        const Center(child: PassPips(states: [done, pending, pending])),
        theme: AppThemeMode.highContrastDark,
      );
      expect(pips(tester).map((p) => p.color), everyElement(Palettes.hcDark.onSurface));
    });
  });

  testWidgets('ornaments are hidden from screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpThemed(
      tester,
      const Column(
        children: [
          Lozenge(),
          SeferDivider(),
          SectionBreakMark(SectionBreak.petuchah, verseSize: 26),
          PassPips(states: [PipState.done, PipState.pending, PipState.pending]),
        ],
      ),
    );
    expect(find.bySemanticsLabel('פ'), findsNothing);
    for (final type in [Lozenge, SeferDivider, SectionBreakMark, PassPips]) {
      expect(
        find.descendant(of: find.byType(type), matching: find.byType(ExcludeSemantics)),
        findsAtLeastNWidgets(1),
        reason: '$type',
      );
    }
    handle.dispose();
  });

  group('Eyebrow', () {
    testWidgets('sets its text in the eyebrow style', (tester) async {
      await pumpThemed(tester, const Eyebrow('This week'));
      final context = tester.element(find.byType(Eyebrow));
      expect(tester.widget<Text>(find.text('This week')).style, SeferType.of(context).eyebrow);
    });

    testWidgets('uppercases English for a font without small caps', (tester) async {
      await pumpThemed(tester, const Eyebrow('This week'), uiFont: UiFont.atkinson);
      expect(find.text('THIS WEEK'), findsOneWidget);
    });
  });
}
