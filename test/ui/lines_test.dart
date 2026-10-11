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

  group('WholeWords', () {
    Future<void> pump(WidgetTester tester, Widget child, {required double width}) => pumpThemed(
          tester,
          Align(alignment: AlignmentDirectional.topStart, child: SizedBox(width: width, child: child)),
        );

    testWidgets('sets a text whose words fit as it is', (tester) async {
      await pump(tester, const WholeWords('aa bb', style: style), width: 100);
      expect(tester.getSize(find.byType(WholeWords)), const Size(100, 10));
      expect(tester.getSize(find.text('aa bb')), const Size(100, 10));
    });

    // A text of words of four letters or fewer, 40 wide at most, set where
    // the line is 35: smaller, on as many lines as it takes at the full size.
    testWidgets('wraps between words, and sets a word too wide for the line just small enough', (tester) async {
      await pump(tester, const WholeWords('aaaa bb', style: style, textAlign: TextAlign.start), width: 35);
      final box = tester.getRect(find.byType(WholeWords));
      expect(box.width, 35);
      expect(tester.getSize(find.text('aaaa bb')).height, 20, reason: 'two lines, before it is scaled');
      expect(box.height, inExclusiveRange(15, 20), reason: 'two smaller lines');
      expect(tester.getRect(find.text('aaaa bb')).width, lessThanOrEqualTo(35));
      expectWordsWhole(tester, 'aaaa bb');
      expect(tester.takeException(), isNull);
    });

    testWidgets("measures in the style around it, as a button's label", (tester) async {
      await pump(
        tester,
        const DefaultTextStyle(style: TextStyle(fontSize: 20, height: 1), child: WholeWords('aaaa')),
        width: 50,
      );
      // 80 wide at 20: set at 49/80 of it.
      expect(tester.getSize(find.byType(WholeWords)).height, moreOrLessEquals(20 * 49 / 80));
      expect(tester.getRect(find.text('aaaa')).width, lessThanOrEqualTo(50));
      expectWordsWhole(tester, 'aaaa');
    });

    testWidgets('keeps a hyphenated name whole, or breaks it after the hyphen', (tester) async {
      await pump(tester, const WholeWords('aaa-bbb', style: style), width: 50);
      expect(tester.getSize(find.byType(WholeWords)).height, lessThan(10), reason: 'one smaller line');
      await pump(tester, const WholeWords('aaa-bbb', style: style, breakAtHyphens: true), width: 50);
      expect(tester.getSize(find.byType(WholeWords)).height, 20, reason: 'two lines, at the full size');
    });

    testWidgets('can stand in a row as tall as its tallest cell', (tester) async {
      const cell = Key('cell');
      await pump(
        tester,
        const IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: WholeWords('aaaa aaaa', style: style)),
              Expanded(child: SizedBox(key: cell)),
            ],
          ),
        ),
        width: 70,
      );
      expect(tester.takeException(), isNull);
      // Two lines of "aaaa", set smaller to fit a cell 35 wide.
      expect(tester.getSize(find.byKey(cell)).height, tester.getSize(find.byType(WholeWords)).height);
      expect(tester.getSize(find.byKey(cell)).height, inExclusiveRange(15, 20));
    });

    testWidgets('a screen reader hears its label, where it has one', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const WholeWords('THIS WEEK', style: style, semanticsLabel: 'This week'), width: 200);
      expect(tester.getSemantics(find.text('THIS WEEK')), isSemantics(label: 'This week'));
      handle.dispose();
    });
  });

  test('dashHeldToWord holds each spaced em dash to the word before it', () {
    expect(dashHeldToWord('Two aliyot — very normal — midweek.'), 'Two aliyot\u00A0— very normal\u00A0— midweek.');
    expect(dashHeldToWord('עוד 3 עליות להשלים — רגיל'), 'עוד 3 עליות להשלים\u00A0— רגיל');
    expect(dashHeldToWord('1–2 and a—b'), '1–2 and a—b', reason: 'only a dash set between spaces');
  });
}
