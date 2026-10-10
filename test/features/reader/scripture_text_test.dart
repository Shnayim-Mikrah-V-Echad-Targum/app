import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/data/models/scripture.dart';
import 'package:shnayim_mikra/data/models/verse_ref.dart';
import 'package:shnayim_mikra/features/reader/scripture_text.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/sefer_colors.dart';

import '../../helpers.dart';

void main() {
  // Exodus 20:13, unpointed: three commandments with setumah gaps between.
  final decalogue = Verse.fromJson(const VerseRef(20, 13), [
    'לא תרצח׃',
    {'gap': 'S'},
    'לא תנאף׃',
    {'gap': 'S'},
    'לא תגנב׃',
    {'gap': 'S'},
    'לא־תענה ברעך עד שקר׃',
  ]);

  Future<void> pumpVerse(
    WidgetTester tester,
    Verse verse, {
    AppSettings settings = const AppSettings(),
    bool dimmed = false,
  }) =>
      pumpThemed(
        tester,
        ScriptureVerse(verse: verse, kind: ScriptureKind.mikra, settings: settings, dimmed: dimmed),
      );

  List<TextSpan> marksIn(WidgetTester tester) {
    final marks = <TextSpan>[];
    tester.widget<RichText>(find.byType(RichText)).text.visitChildren((span) {
      if (span is TextSpan && span.text == 'ס') marks.add(span);
      return true;
    });
    return marks;
  }

  testWidgets('a section gap inside a verse shows a small mark between word spaces', (tester) async {
    await pumpVerse(tester, decalogue);
    final text = tester.widget<RichText>(find.byType(RichText)).text;
    // The no-break space binds each mark to the words before it (and a word
    // joiner keeps the maqaf phrase on one line).
    expect(text.toPlainText(), endsWith('לא תרצח׃\u00A0ס לא תנאף׃\u00A0ס לא תגנב׃\u00A0ס לא־\u2060תענה ברעך עד שקר׃'));

    final marks = marksIn(tester);
    expect(marks, hasLength(3));
    // A rubric, like the section marks between verses (SectionBreakMark).
    final colors = Theme.of(tester.element(find.byType(ScriptureVerse))).colorScheme;
    expect(marks.first.style?.fontSize, closeTo(ScriptureStyles.baseHebrewSize * 0.55, 0.001));
    expect(marks.first.style?.fontWeight, FontWeight.w600);
    expect(marks.first.style?.color, colors.secondary);

    // Dimmed in focus mode in the dimmed text's own ink, never a fade.
    await pumpVerse(tester, decalogue, dimmed: true);
    final dimInk = SeferColors.of(tester.element(find.byType(ScriptureVerse))).dimInk;
    expect(marksIn(tester).first.style?.color, dimInk, reason: 'dimmed in focus mode');
  });

  for (final (wordSpacing, letterSpacing) in [(16.0, 0.0), (4.0, 2.0)]) {
    testWidgets('the spaces around a section mark are even with word spacing $wordSpacing, letter spacing $letterSpacing',
        (tester) async {
      await pumpVerse(
        tester,
        decalogue,
        settings: AppSettings(wordSpacing: wordSpacing, letterSpacing: letterSpacing),
      );
      final paragraph = tester.renderObject<RenderParagraph>(find.byType(RichText));
      final text = paragraph.text.toPlainText();
      double widthAt(int i) => paragraph
          .getBoxesForSelection(TextSelection(baseOffset: i, extentOffset: i + 1))
          .fold(0, (w, box) => w + box.right - box.left);
      final mark = text.indexOf('ס');
      expect(text[mark - 1], '\u00A0');
      expect(text[mark + 1], ' ');
      final ordinary = text.indexOf(' ');
      expect(widthAt(mark - 1), closeTo(widthAt(ordinary), 0.01), reason: 'before the mark, like any word space');
      expect(widthAt(mark + 1), closeTo(widthAt(ordinary), 0.01), reason: 'after the mark');
    });
  }

  testWidgets('a section mark never begins a line', (tester) async {
    await pumpVerse(tester, decalogue, settings: const AppSettings(wordSpacing: 16));
    final span = tester.widget<RichText>(find.byType(RichText)).text;
    final text = span.toPlainText();
    final marks = [for (var i = 0; i < text.length; i++) if (text[i] == 'ס') i];
    var wrapped = 0;
    // From the width of the longest run that can't be broken ("תרצח׃ ס").
    for (var width = 200.0; width <= 900; width += 7) {
      final painter = TextPainter(text: span, textDirection: TextDirection.rtl)..layout(maxWidth: width);
      for (final mark in marks) {
        final line = painter.getLineBoundary(TextPosition(offset: mark));
        expect(line.start, isNot(mark), reason: 'at width $width');
        if (painter.getLineBoundary(TextPosition(offset: mark - 1)).start != line.start) wrapped++;
      }
      painter.dispose();
    }
    expect(wrapped, 0, reason: 'the space before a mark never ends a line');
  });

  testWidgets('a section gap is a plain word space to a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpVerse(tester, decalogue);
    expect(find.bySemanticsLabel('Verse 13. לא תרצח. לא תנאף. לא תגנב. לא תענה ברעך עד שקר.'), findsOneWidget);
    handle.dispose();
  });
}
