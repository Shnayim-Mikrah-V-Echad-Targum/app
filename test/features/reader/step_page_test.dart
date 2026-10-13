import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/features/reader/step_page.dart';

void main() {
  /// A box [height] tall, heard as [label].
  Widget box(String label, double height) => Semantics(
        container: true,
        label: label,
        child: SizedBox(height: height),
      );

  /// [child] in a column 400 wide, at least [page] tall.
  Future<void> pump(WidgetTester tester, Widget child, {double page = 300}) => tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              child: ConstrainedBox(constraints: BoxConstraints(minHeight: page), child: child),
            ),
          ),
        ),
      );

  FitsWhole step({double main = 100, List<double> after = const [60, 60, 60], bool before = true}) => FitsWhole(
        lead: box('lead', 20),
        before: before ? box('before', 50) : null,
        main: box('main', main),
        after: [for (final (i, h) in after.indexed) box('after ${i + 1}', h)],
        beforeGap: 28,
        firstGap: 28,
        gap: 20,
      );

  RenderFitsWhole page(WidgetTester tester) => tester.renderObject(find.byType(FitsWhole));
  List<String> shown(WidgetTester tester) => [
        for (final child in page(tester).shown) (child as RenderSemanticsAnnotations).properties.label!,
      ];
  double top(WidgetTester tester, String label) => tester.getTopLeft(find.bySemanticsLabel(label)).dy;

  group('FitsWhole', () {
    testWidgets('shows the verse before and those after that fit whole on the page', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, step());
      // 20 + 50 + 28 + 100 = 198; then 28 + 60 = 286, and 20 + 60 more
      // would pass 300.
      expect(shown(tester), ['lead', 'before', 'main', 'after 1']);
      expect((top(tester, 'before'), top(tester, 'main'), top(tester, 'after 1')), (20.0, 98.0, 226.0));
      expect(tester.getSize(find.byType(FitsWhole)), const Size(400, 300));
      // What is left out is neither painted nor heard.
      expect(find.bySemanticsLabel('after 2'), findsNothing);
      expect(find.bySemanticsLabel('after 3'), findsNothing);
      handle.dispose();
    });

    testWidgets('leaves out the verse before where the main text would not fit beneath it', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, step(main: 250));
      expect(shown(tester), ['lead', 'main']);
      expect(top(tester, 'main'), 20);
      expect(find.bySemanticsLabel('before'), findsNothing);
      handle.dispose();
    });

    testWidgets('leaves out every neighbour after one that does not fit, and scrolls for none', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, step(before: false, after: [40, 200, 10]));
      // A short third would fit, but not after the second, left out.
      expect(shown(tester), ['lead', 'main', 'after 1']);
      expect(tester.getSize(find.byType(FitsWhole)).height, 300);
      handle.dispose();
    });

    testWidgets('a main text taller than the page is shown whole, alone', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, step(main: 400));
      expect(shown(tester), ['lead', 'main']);
      expect(tester.getSize(find.byType(FitsWhole)).height, 420);
      handle.dispose();
    });

    testWidgets('with no page, is its lead and main text, as a column of them', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, step(), page: 0);
      expect(shown(tester), ['lead', 'main']);
      expect(tester.getSize(find.byType(FitsWhole)), const Size(400, 120));
      handle.dispose();
    });

    testWidgets('a neighbour left out waits below the page, unpainted and untouched', (tester) async {
      var tapped = 0;
      final left = GestureDetector(
        onTap: () => tapped++,
        child: const ColoredBox(color: Color(0xFF000000), child: SizedBox(height: 60)),
      );
      await pump(
        tester,
        FitsWhole(lead: const SizedBox(height: 20), main: const SizedBox(height: 250), after: [left], firstGap: 28),
      );
      expect(page(tester).shown, hasLength(2));
      expect(tester.getTopLeft(find.byType(ColoredBox)).dy, 300);
      expect(find.byType(FitsWhole), isNot(paints..rect()));
      expect(find.byType(GestureDetector).hitTestable(), findsNothing);
      await tester.tapAt(const Offset(200, 310));
      expect(tapped, 0);
    });
  });

  group('ColumnToPage', () {
    testWidgets('gives its last child the room the others leave of the page', (tester) async {
      late BoxConstraints last;
      Widget child() => ColumnToPage(
            children: [
              const SizedBox(height: 40),
              const SizedBox(height: 60),
              LayoutBuilder(builder: (context, constraints) {
                last = constraints;
                return const SizedBox(height: 10);
              }),
            ],
          );
      await pump(tester, child());
      expect((last.minWidth, last.maxWidth, last.minHeight, last.maxHeight), (400.0, 400.0, 200.0, double.infinity));
      expect(tester.getSize(find.byType(ColumnToPage)), const Size(400, 300));
      expect(tester.getTopLeft(find.byType(LayoutBuilder)).dy, 100);

      await pump(tester, child(), page: 0);
      expect(last.minHeight, 0);
      expect(tester.getSize(find.byType(ColumnToPage)), const Size(400, 110));
    });
  });
}
