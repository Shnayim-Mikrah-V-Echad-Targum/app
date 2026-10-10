import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/search/marked_text.dart';

import '../../helpers.dart';

/// MarkedText: a wash as tall as the letters behind each mark, where the
/// text lays them out, in either direction.
void main() {
  setUpAll(loadBundledFonts);

  const wash = Color(0xFFF2D27A);
  const ink = Color(0xFF3A2A00);
  const style = TextStyle(fontFamily: 'NotoSans', fontSize: 20, height: 2, color: Colors.black);

  Future<RenderMarkedText> pump(
    WidgetTester tester,
    String text,
    List<TextRange> marks, {
    TextDirection direction = TextDirection.ltr,
    Color? outline,
    double width = 400,
  }) async {
    await tester.pumpWidget(Directionality(
      textDirection: direction,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: MarkedText(
            TextSpan(text: text, style: style),
            marks: marks,
            color: wash,
            outline: outline,
            textDirection: direction,
          ),
        ),
      ),
    ));
    return tester.renderObject<RenderMarkedText>(find.byType(MarkedText));
  }

  /// Where [range] of [text] lies, as a TextPainter with the same text lays it out.
  List<TextBox> boxes(String text, TextRange range, TextDirection direction, double width) {
    final painter = TextPainter(text: TextSpan(text: text, style: style), textDirection: direction)
      ..layout(minWidth: width, maxWidth: width);
    final out = painter.getBoxesForSelection(TextSelection(baseOffset: range.start, extentOffset: range.end));
    painter.dispose();
    return out;
  }

  testWidgets('washes each mark, as tall as the letters rather than the line', (tester) async {
    const text = 'Jacob dreamed of a ladder set up on the earth';
    const marks = [TextRange(start: 0, end: 5), TextRange(start: 19, end: 25)];
    final box = await pump(tester, text, marks);
    expect(box, paintsExactlyCountTimes(#drawRRect, 2));
    final jacob = boxes(text, marks[0], TextDirection.ltr, 400).single;
    final ladder = boxes(text, marks[1], TextDirection.ltr, 400).single;
    // A 2 px bleed each side; the line is 40 high, the letters about half that.
    expect(
      box,
      paints
        ..rrect(
          color: wash,
          rrect: RRect.fromRectAndRadius(
            Rect.fromLTRB(jacob.left - 2, jacob.top, jacob.right + 2, jacob.bottom),
            const Radius.circular(3),
          ),
        )
        ..rrect(color: wash, rrect: RRect.fromRectAndRadius(
          Rect.fromLTRB(ladder.left - 2, ladder.top, ladder.right + 2, ladder.bottom),
          const Radius.circular(3),
        )),
    );
    expect(jacob.bottom - jacob.top, lessThan(box.size.height * 0.75));
  });

  testWidgets('lays the marks out right to left in Hebrew', (tester) async {
    const text = 'וַיֵּצֵא יַעֲקֹב מִבְּאֵר שָׁבַע';
    const first = TextRange(start: 0, end: 8);
    final box = await pump(tester, text, const [first], direction: TextDirection.rtl);
    final word = boxes(text, first, TextDirection.rtl, 400).single;
    // The first word is at the right.
    expect(word.right, closeTo(400, 1));
    expect(
      box,
      paints
        ..rrect(
          color: wash,
          rrect: RRect.fromRectAndRadius(
            Rect.fromLTRB(word.left - 2, word.top, word.right + 2, word.bottom),
            const Radius.circular(3),
          ),
        ),
    );
  });

  testWidgets('a mark that breaks across lines is washed on each', (tester) async {
    const text = 'one two three four five six seven eight';
    final box = await pump(tester, text, const [TextRange(start: 8, end: 33)], width: 120);
    final lines = boxes(text, const TextRange(start: 8, end: 33), TextDirection.ltr, 120).length;
    expect(lines, greaterThan(1));
    expect(box, paintsExactlyCountTimes(#drawRRect, lines));
  });

  testWidgets('paints again when its marks change, and outlines them when asked', (tester) async {
    const text = 'Jacob dreamed of a ladder';
    final box = await pump(tester, text, const [TextRange(start: 0, end: 5)]);
    expect(box, paintsExactlyCountTimes(#drawRRect, 1));
    await pump(tester, text, const [TextRange(start: 0, end: 5), TextRange(start: 19, end: 25)]);
    expect(box, paintsExactlyCountTimes(#drawRRect, 2));
    await pump(tester, text, const []);
    expect(box, paintsExactlyCountTimes(#drawRRect, 0));
    // Outlined: a wash and a line around it for each.
    await pump(tester, text, const [TextRange(start: 0, end: 5)], outline: ink);
    expect(box, paints..rrect(color: wash)..rrect(color: ink, style: PaintingStyle.stroke));
  });

  // A font that arrives after the first layout (on the web, or one just
  // chosen) has other metrics, so the washes must be placed again.
  testWidgets('lays its text out again when the system fonts change', (tester) async {
    final box = await pump(tester, 'Jacob', const [TextRange(start: 0, end: 5)]);
    expect(box, isA<RelayoutWhenSystemFontsChangeMixin>());
    expect(box.debugNeedsLayout, isFalse);
    // ignore: invalid_use_of_protected_member
    box.systemFontsDidChange();
    expect(box.debugNeedsLayout, isTrue);
    await tester.pump();
    expect(box, paintsExactlyCountTimes(#drawRRect, 1));
  });
}
