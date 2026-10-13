import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/data/models/scripture.dart';
import 'package:shnayim_mikra/data/models/verse_ref.dart';
import 'package:shnayim_mikra/features/reader/scripture_text.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../../helpers.dart';

/// The words of [text] (what stands between spaces, no-break or not), line
/// by line, as [boxes] lays them out, each box as tall as its line.
List<List<String>> wordsByLine(
  String text,
  List<TextBox> Function(TextSelection selection, {BoxHeightStyle boxHeightStyle}) boxes,
) {
  final lines = <int, List<String>>{};
  for (final word in RegExp('[^ \u00A0]+').allMatches(text)) {
    final selection = TextSelection(baseOffset: word.start, extentOffset: word.end);
    final top = boxes(selection, boxHeightStyle: BoxHeightStyle.max).first.top.round();
    (lines[top] ??= []).add(word[0]!);
  }
  return [for (final top in lines.keys.toList()..sort()) lines[top]!];
}

/// [text]'s words line by line, laid out right to left [width] wide.
List<List<String>> linesOf(InlineSpan text, double width) {
  final painter = TextPainter(text: text, textDirection: TextDirection.rtl)..layout(maxWidth: width);
  final lines = wordsByLine(text.toPlainText(includeSemanticsLabels: false), painter.getBoxesForSelection);
  painter.dispose();
  return lines;
}

/// The words of the paragraph [finder] finds, line by line, as it is laid
/// out.
List<List<String>> linesIn(WidgetTester tester, Finder finder) {
  final paragraph = tester.renderObject<RenderParagraph>(find.descendant(of: finder, matching: find.byType(RichText)));
  return wordsByLine(
    paragraph.text.toPlainText(includeSemanticsLabels: false),
    paragraph.getBoxesForSelection,
  );
}

void main() {
  // The test font's letters and spaces are squares as wide as the type is
  // high; its points take no room.
  const style = TextStyle(fontSize: 10, height: 1);
  TextSpan span(String text) => TextSpan(text: text, style: style);
  InlineSpan held(
    InlineSpan text,
    double width, {
    TextStyle? style,
    List<PlaceholderDimensions> placeholders = const [],
  }) =>
      holdLastPair(text, maxWidth: width, textScaler: TextScaler.noScaling, style: style, placeholders: placeholders);
  String plain(InlineSpan text) => text.toPlainText(includeSemanticsLabels: false);

  group('holdLastPair', () {
    testWidgets('a paragraph whose last line would be one word ends with two', (tester) async {
      // Words 20 wide and spaces 10: at 105, three words to the first line.
      final text = span('אא בב גג דד');
      expect(linesOf(text, 105), [
        ['אא', 'בב', 'גג'],
        ['דד'],
      ]);
      final pair = held(text, 105);
      expect(plain(pair), 'אא בב גג\u00A0דד');
      expect(linesOf(pair, 105), [
        ['אא', 'בב'],
        ['גג', 'דד'],
      ]);
    });

    testWidgets('a pair wider than half the measure is left alone', (tester) async {
      // 90 together.
      final text = span('אאאא בבבב גגגג');
      expect(held(text, 170), same(text), reason: 'half of it is 85');
      expect(plain(held(text, 180)), 'אאאא בבבב\u00A0גגגג');
      expect(held(text, double.infinity), same(text));
    });

    testWidgets('words a maqaf joins hold together as one word', (tester) async {
      // "בב־גג" and "דד־הה" are 50 wide each, and 110 together.
      final text = span(keepLinesSound('אא בב־גג דד־הה'));
      expect(plain(held(text, 220)), 'אא בב־\u2060גג\u00A0דד־\u2060הה');
      expect(held(text, 210), same(text));
    });

    testWidgets('a hyphen or a dash in the last word is bound, so that its end never stands alone', (tester) async {
      // At 165, "aaaa bbbb cc dd-" fills the first line, and the line may
      // end after the hyphen, leaving "ee" alone.
      final hyphened = span('aaaa bbbb cc dd-ee');
      // Where the last line starts, laid out 165 wide.
      int lastLineStart(InlineSpan text) {
        final painter = TextPainter(text: text, textDirection: TextDirection.rtl)..layout(maxWidth: 165);
        final plainText = plain(text);
        final start = painter.getLineBoundary(TextPosition(offset: plainText.length - 1)).start;
        painter.dispose();
        return start;
      }

      expect(lastLineStart(hyphened), 'aaaa bbbb cc dd-'.length);
      expect(
        lastLineStart(span('aaaa bbbb cc\u00A0dd-ee')),
        'aaaa bbbb cc dd-'.length,
        reason: 'the no-break space alone leaves the break after the hyphen',
      );
      final pair = held(hyphened, 165);
      expect(plain(pair), 'aaaa bbbb cc\u00A0dd-\u2060ee');
      expect(linesOf(pair, 165), [
        ['aaaa', 'bbbb'],
        ['cc', 'dd-\u2060ee'],
      ]);
      // An en dash, a maqaf, and an em dash, before which a line may end
      // too; a hyphen at the word's end, or one bound already, takes none.
      expect(plain(held(span('aaaa bbbb cc dd–ee'), 165)), 'aaaa bbbb cc\u00A0dd–\u2060ee');
      expect(plain(held(span('aaaa bbbb cc dd־ee'), 165)), 'aaaa bbbb cc\u00A0dd־\u2060ee');
      expect(plain(held(span('aaaa bbbb cc dd—ee'), 165)), 'aaaa bbbb cc\u00A0dd\u2060—\u2060ee');
      expect(plain(held(span('aaaa bbbb cc dd-'), 165)), 'aaaa bbbb cc\u00A0dd-');
      expect(plain(held(span(keepLinesSound('אאאא בבבב גג דד־הה')), 165)), 'אאאא בבבב גג\u00A0דד־\u2060הה');
      // Where the two are too wide to hold, the word is left as it was.
      expect(held(hyphened, 155), same(hyphened));
    });

    testWidgets('a joiner bound in the last word is nothing to a screen reader, or to a copy', (tester) async {
      final pair = held(span('aa bb sin-offering'), 400);
      expect(plain(pair), 'aa bb\u00A0sin-\u2060offering');
      expect(pair.getSemanticsInformation().map((i) => i.semanticsLabel ?? i.text).join(), 'aa bb sin-offering');
      expect(asCopied(plain(pair)), 'aa bb sin-offering');
    });

    testWidgets('the words are measured where an em of their type for each letter might not fit', (tester) async {
      // "גג " is 30 wide and "דד", twice the size, 40: 70 together, though an
      // em of the larger type for each of their letters is 100.
      final text = TextSpan(style: style, children: [
        const TextSpan(text: 'אא בב גג '),
        const TextSpan(text: 'דד', style: TextStyle(fontSize: 20)),
      ]);
      expect(plain(held(text, 150)), 'אא בב גג\u00A0דד');
      expect(held(text, 130), same(text), reason: 'half of it is 65');
    });

    testWidgets('a widget among the two is measured as large as it is said to be', (tester) async {
      // "אא " is 30 wide, the widget 60 and "בב" 20: 110 together.
      final text = TextSpan(style: style, children: [
        const TextSpan(text: 'אא '),
        WidgetSpan(child: Container()),
        const TextSpan(text: 'בב'),
      ]);
      const placeholders = [PlaceholderDimensions(size: Size(60, 10), alignment: PlaceholderAlignment.middle)];
      expect(plain(held(text, 230, placeholders: placeholders)), 'אא\u00A0\uFFFCבב');
      expect(held(text, 210, placeholders: placeholders), same(text));
    });

    testWidgets('a widget before the two is not measured with them', (tester) async {
      // A widget leads the paragraph, as a verse's marks do; "בב " is 30
      // wide, and "גג", twice the size, 40.
      final text = TextSpan(style: style, children: [
        WidgetSpan(child: Container()),
        const TextSpan(text: 'אא בב '),
        const TextSpan(text: 'גג', style: TextStyle(fontSize: 20)),
      ]);
      const placeholders = [PlaceholderDimensions(size: Size(100, 10), alignment: PlaceholderAlignment.middle)];
      expect(plain(held(text, 150, placeholders: placeholders)), '\uFFFCאא בב\u00A0גג');
      expect(held(text, 130, placeholders: placeholders), same(text));
    });

    testWidgets('a paragraph of one word, or spaces before its only word, is left alone', (tester) async {
      for (final text in [span('אא'), span('  אא'), span('אא  '), span('')]) {
        expect(held(text, 400), same(text), reason: '"${text.text}"');
      }
    });

    testWidgets('spaces at the paragraph\'s end are passed over, and every space between the two is held', (tester) async {
      expect(plain(held(span('אא בב גג  '), 400)), 'אא בב\u00A0גג  ');
      expect(plain(held(span('אא בב  גג'), 400)), 'אא בב\u00A0\u00A0גג');
    });

    testWidgets('a space held is a space to a screen reader, and to a copy', (tester) async {
      final pair = held(span('אא בב גג'), 400);
      expect(pair.toPlainText(), 'אא בב גג');
      expect(pair.getSemanticsInformation().map((i) => i.semanticsLabel ?? i.text).join(), 'אא בב גג');
      expect(asCopied(plain(pair)), 'אא בב גג');
    });

    testWidgets("the span holding the space keeps its style and gestures, and the others are left as they were",
        (tester) async {
      final tap = TapGestureRecognizer();
      addTearDown(tap.dispose);
      const bold = TextStyle(fontWeight: FontWeight.bold);
      final text = TextSpan(style: style, children: [
        const TextSpan(text: 'אא '),
        TextSpan(text: 'בב גג', style: bold, recognizer: tap),
      ]);
      final pair = held(text, 400) as TextSpan;
      expect(plain(pair), 'אא בב\u00A0גג');
      expect(pair.style, style);
      expect(pair.children!.first, const TextSpan(text: 'אא '));
      final split = pair.children!.last as TextSpan;
      expect(split.style, bold);
      expect(split.text, isNull);
      final pieces = split.children!.cast<TextSpan>();
      expect([for (final p in pieces) p.text], ['בב', '\u00A0', 'גג']);
      expect([for (final p in pieces) p.recognizer], everyElement(same(tap)));
    });

    testWidgets('the space held carries the word spacing of the style it is set in', (tester) async {
      // The ambient style's spacing, and the paragraph's own letter spacing
      // over it.
      const ambient = TextStyle(fontSize: 10, letterSpacing: 1, wordSpacing: 3);
      TextSpan space(InlineSpan held) {
        late TextSpan found;
        held.visitChildren((span) {
          if (span is TextSpan && span.text == '\u00A0') found = span;
          return true;
        });
        return found;
      }

      expect(space(held(const TextSpan(text: 'אא בב'), 400, style: ambient)).style?.letterSpacing, 4);
      final own = TextSpan(style: const TextStyle(letterSpacing: 2), children: [const TextSpan(text: 'אא בב')]);
      expect(space(held(own, 400, style: ambient)).style?.letterSpacing, 5);
    });

    testWidgets('a space a label speaks for is left as it is', (tester) async {
      final text = TextSpan(style: style, children: [
        const TextSpan(text: 'אא '),
        const TextSpan(text: 'בב גג', semanticsLabel: 'בב וגג'),
      ]);
      expect(plain(held(text, 400)), 'אא בב גג');
    });

    for (final (wordSpacing, letterSpacing) in [(0.0, 0.0), (16.0, 0.0), (4.0, 2.0)]) {
      testWidgets('the space held is as wide as a space: word spacing $wordSpacing, letter spacing $letterSpacing',
          (tester) async {
        final spaced = style.copyWith(wordSpacing: wordSpacing, letterSpacing: letterSpacing);
        final text = TextSpan(text: 'אא בב גג', style: spaced);
        final pair = held(text, 400);
        expect(plain(pair), 'אא בב\u00A0גג');
        // A paragraph of one line, laid out as it was: every letter where it
        // stood, and the line as wide.
        TextPainter laidOut(InlineSpan text) => TextPainter(text: text, textDirection: TextDirection.rtl)..layout();
        final before = laidOut(text);
        final after = laidOut(pair);
        expect(after.width, closeTo(before.width, 0.01));
        expect(after.computeLineMetrics(), hasLength(1));
        for (var i = 0; i < 8; i++) {
          final selection = TextSelection(baseOffset: i, extentOffset: i + 1);
          final was = before.getBoxesForSelection(selection).single;
          final now = after.getBoxesForSelection(selection).single;
          expect(now.left, closeTo(was.left, 0.01), reason: 'at $i');
          expect(now.right, closeTo(was.right, 0.01), reason: 'at $i');
        }
        before.dispose();
        after.dispose();
      });
    }
  });

  group('in the reader', () {
    Future<void> pumpAt(WidgetTester tester, double width, Widget child) => pumpThemed(
          tester,
          Align(alignment: Alignment.topRight, child: SizedBox(width: width, child: child)),
        );

    testWidgets("a verse's last line holds two words, and its screen reader's verse node is as it was", (tester) async {
      final handle = tester.ensureSemantics();
      // At 26 a word of two letters is 52 wide, and a space 26: at 270, three
      // words to the first line.
      final verse = Verse.fromJson(const VerseRef(2, 22), ['אא בב גג דד']);
      final unheld = TextSpan(text: 'אא בב גג דד', style: const TextStyle(fontSize: 26));
      expect(linesOf(unheld, 270).last, ['דד']);
      await pumpAt(
        tester,
        270,
        ScriptureVerse(verse: verse, kind: ScriptureKind.mikra, settings: const AppSettings(), showNumber: false),
      );
      expect(linesIn(tester, find.byType(ScriptureVerse)), [
        ['אא', 'בב'],
        ['גג', 'דד'],
      ]);
      expect(find.bySemanticsLabel('Verse 22. אא בב גג דד'), findsOneWidget);
      handle.dispose();
    });

    testWidgets("the Targum's last line holds two words", (tester) async {
      // A letter or a space is 26 × 0.9 wide: three words take 8 of them,
      // four 11, and the line, within the rule and the gap after it, 10.5.
      const size = 26 * ScriptureStyles.targumScale;
      final targum = Verse.fromJson(const VerseRef(2, 22), ['אא בב גג דד']);
      const width = 10.5 * size + ScriptureVerse.ruleGap + ScriptureVerse.ruleWidth;
      await pumpAt(
        tester,
        width,
        ScriptureVerse(
          verse: targum,
          kind: ScriptureKind.targum,
          settings: const AppSettings(),
          secondary: true,
          showNumber: false,
          ruled: true,
        ),
      );
      expect(linesIn(tester, find.byType(ScriptureVerse)), [
        ['אא', 'בב'],
        ['גג', 'דד'],
      ]);
    });

    testWidgets("a translation's last line holds two words, said with plain spaces", (tester) async {
      final handle = tester.ensureSemantics();
      // At 20, "22 aa bb cc" is 220 wide, and "dd" would end it alone.
      await pumpAt(tester, 240, const TranslationVerse(text: 'aa bb cc dd', number: 22, settings: AppSettings()));
      expect(linesIn(tester, find.byType(TranslationVerse)), [
        ['22', 'aa', 'bb'],
        ['cc', 'dd'],
      ]);
      expect(find.bySemanticsLabel('22 aa bb cc dd'), findsOneWidget);
      handle.dispose();
    });

    testWidgets("a translation ending on a hyphened word ends with two words, said as written", (tester) async {
      final handle = tester.ensureSemantics();
      // At 20, "22 aa bb cc dd-" is 300 wide: at 330, the line could end
      // after the hyphen, and "ee" stand alone.
      await pumpAt(tester, 330, const TranslationVerse(text: 'aa bb cc dd-ee', number: 22, settings: AppSettings()));
      expect(linesIn(tester, find.byType(TranslationVerse)), [
        ['22', 'aa', 'bb'],
        ['cc', 'dd-\u2060ee'],
      ]);
      expect(find.bySemanticsLabel('22 aa bb cc dd-ee'), findsOneWidget);
      handle.dispose();
    });

    testWidgets("a comment of Rashi's last line holds two words", (tester) async {
      // A letter or a space is 26 × 0.78 wide: "הן אא בב גג" takes 11 of
      // them, and the line 12.5.
      const unit = 26 * ScriptureStyles.rashiScale;
      await pumpAt(
        tester,
        12.5 * unit,
        const RashiComments(comments: [Comment('הן', 'אא בב גג דד')], settings: AppSettings(), english: false),
      );
      expect(linesIn(tester, find.byType(RashiComments)), [
        ['הן', 'אא', 'בב'],
        ['גג', 'דד'],
      ]);
    });

    testWidgets('a verse of one line is laid out as it was', (tester) async {
      final verse = Verse.fromJson(const VerseRef(2, 22), ['אא בב גג דד']);
      await pumpAt(tester, 600, ScriptureVerse(verse: verse, kind: ScriptureKind.mikra, settings: const AppSettings()));
      final paragraph = tester.renderObject<RenderParagraph>(find.byType(RichText));
      final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
      expect(text, endsWith('גג\u00A0דד'));
      // Each word as far from the next as a word space is wide.
      final words = RegExp('[^ \u00A0]+').allMatches(text).toList();
      final gaps = [
        for (var i = 1; i < words.length; i++)
          paragraph.getBoxesForSelection(TextSelection(baseOffset: words[i - 1].start, extentOffset: words[i - 1].end)).single.left -
              paragraph.getBoxesForSelection(TextSelection(baseOffset: words[i].start, extentOffset: words[i].end)).single.right,
      ];
      expect(gaps.skip(1), everyElement(closeTo(26, 0.01)));
      expect(wordsByLine(text, paragraph.getBoxesForSelection), hasLength(1));
    });
  });
}
