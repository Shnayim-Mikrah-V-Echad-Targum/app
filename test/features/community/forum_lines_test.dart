import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/app/router.dart';
import 'package:shnayim_mikrah/features/community/ui/community_ui.dart';
import 'package:shnayim_mikrah/features/community/ui/forum_screen.dart';
import 'package:shnayim_mikrah/ui/widgets/paper_group.dart';

import '../../helpers.dart';

/// The boxes of the middle dots in [line], a line of facts (see
/// [metaLine]) laid out by [paragraph].
List<TextBox> _dots(RenderParagraph paragraph) {
  final line = paragraph.text.toPlainText();
  return [
    for (var i = 0; i < line.length; i++)
      if (line[i] == '·') paragraph.getBoxesForSelection(TextSelection(baseOffset: i, extentOffset: i + 1)).first,
  ];
}

/// The facts a forum and its discussions are listed with wrap after a dot,
/// never before one, so that no line begins with a dot.
void main() {
  // Real glyphs, so that a line breaks where it does on a screen.
  setUpAll(loadBundledFonts);

  test('joins the facts with dots held to the fact before each', () {
    expect(metaLine(['Rivka', '3 hours ago', '4 replies']), 'Rivka\u00a0· 3 hours ago\u00a0· 4 replies');
    expect(metaLine(['No discussions yet']), 'No discussions yet');
  });

  testWidgets('a discussion at 200% text', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final c = await pumpApp(tester, now: DateTime(2026, 10, 9, 11));
    c.read(routerProvider).go('/community/forum/questions');
    await tester.pumpAndSettle();
    final tiles = find.byType(ThreadTile);
    var wrapped = 0;
    for (var i = 0; i < tester.widgetList(tiles).length; i++) {
      final meta = find.descendant(of: tiles.at(i), matching: find.textContaining('\u00a0· ')).last;
      final dots = _dots(tester.renderObject<RenderParagraph>(meta));
      if (dots.map((d) => d.top).toSet().length > 1) wrapped++;
      for (final dot in dots) {
        expect(dot.left, greaterThan(1), reason: 'no dot leads a line');
      }
    }
    expect(wrapped, greaterThan(0), reason: 'some take more than one line');
  });

  testWidgets("a forum's activity at 200% text", (tester) async {
    tester.view.physicalSize = const Size(360, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final c = await pumpApp(tester, now: DateTime(2026, 10, 9, 11));
    c.read(routerProvider).go('/community');
    await tester.pumpAndSettle();
    final details = find.descendant(of: find.byType(PaperRow), matching: find.textContaining(RegExp('discussions?\u00a0· ')));
    expect(details, findsWidgets);
    var wrapped = 0;
    for (final element in details.evaluate()) {
      final dots = _dots(element.findRenderObject()! as RenderParagraph);
      if (dots.single.top > 0) wrapped++;
      expect(dots.single.left, greaterThan(1), reason: 'no dot leads a line');
    }
    expect(wrapped, greaterThan(0), reason: 'some take more than one line');
  });
}
