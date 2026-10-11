import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/ui/widgets/lines.dart';

import '../helpers.dart';

void main() {
  // The test font's letters are squares as wide as the type is high: each
  // letter here is 10 wide.
  const style = TextStyle(fontSize: 10, height: 1);

  Future<List<String>> lines(WidgetTester tester, List<String> parts, {required double width}) async {
    await pumpThemed(
      tester,
      Align(
        alignment: AlignmentDirectional.topStart,
        child: SizedBox(width: width, child: DotLine(parts, style: style)),
      ),
    );
    return [for (final t in tester.widgetList<Text>(find.byType(Text))) t.data!];
  }

  group('DotLine', () {
    testWidgets('sets its parts on one line between middle dots, where they fit', (tester) async {
      expect(await lines(tester, ['aaaa', 'bbbb', 'cccc'], width: 180), ['aaaa · bbbb · cccc']);
    });

    testWidgets('breaks between parts, as many to a line as fit, and starts no line with a dot', (tester) async {
      expect(await lines(tester, ['aaaa', 'bbbb', 'cccc'], width: 130), ['aaaa · bbbb', 'cccc']);
      expect(await lines(tester, ['aaaa', 'bbbb', 'cccc'], width: 60), ['aaaa', 'bbbb', 'cccc']);
    });

    testWidgets('lets a part too long for a line wrap within it', (tester) async {
      expect(await lines(tester, ['aaaa aaaa', 'bb'], width: 50), ['aaaa aaaa', 'bb']);
      expect(tester.getSize(find.text('aaaa aaaa')).height, 20, reason: 'two lines');
    });

    testWidgets('wraps such a part after a comma, keeping each clause that fits whole', (tester) async {
      // "Read on Shabbat, / October 10", not "Read on Shabbat, October / 10".
      expect(await lines(tester, ['aa bb, cc dd', 'ee'], width: 100), ['aa\u00A0bb, cc\u00A0dd', 'ee']);
      expect(tester.getSize(find.textContaining('aa')).height, 20, reason: 'two lines, which break at the comma');
    });
  });

  group('BalancedText', () {
    Future<void> pump(WidgetTester tester, String text, {required double width, bool bySentence = false}) =>
        pumpThemed(
          tester,
          Align(
            alignment: AlignmentDirectional.topStart,
            child: SizedBox(width: width, child: BalancedText(text, style: style, bySentence: bySentence)),
          ),
        );

    testWidgets('sets its lines evenly, leaving no word alone on the last', (tester) async {
      // At the full 100, "aa bb cc / dd"; evenly, "aa bb / cc dd".
      await pump(tester, 'aa bb cc dd', width: 100);
      final text = tester.getRect(find.text('aa bb cc dd'));
      expect(text.height, 20, reason: 'as few lines as the full width takes');
      expect(text.width, inInclusiveRange(50, 52));
      // Centred in the column.
      expect(text.center.dx, closeTo(50, 1));
    });

    testWidgets('keeps a text that fits on one line whole', (tester) async {
      await pump(tester, 'aa bb', width: 100);
      expect(tester.getSize(find.text('aa bb')).height, 10);
    });

    testWidgets('by sentence, sets each on lines of its own, read as one text', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, 'Aa bb. Cc dd ee.', width: 100, bySentence: true);
      expect(find.text('Aa bb.'), findsOneWidget);
      expect(find.text('Cc dd ee.'), findsOneWidget);
      expect(find.bySemanticsLabel('Aa bb. Cc dd ee.'), findsOneWidget);
      handle.dispose();
    });
  });
}
