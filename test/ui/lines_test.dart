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
}
