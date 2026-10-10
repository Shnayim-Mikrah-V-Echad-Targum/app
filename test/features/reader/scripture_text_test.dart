import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/data/models/scripture.dart';
import 'package:shnayim_mikra/data/models/verse_ref.dart';
import 'package:shnayim_mikra/features/reader/scripture_text.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/motion.dart';
import 'package:shnayim_mikra/ui/theme/sefer_colors.dart';
import 'package:shnayim_mikra/ui/widgets/ornaments.dart' show SectionBreakMark;

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

  // Genesis 3:22, pointed: a verse whose number has two letters.
  final serpent = Verse.fromJson(const VerseRef(3, 22), ['וַיֹּאמֶר יְהוָה אֱלֹהִים הֵן הָאָדָם הָיָה כְּאַחַד מִמֶּנּוּ']);

  /// The style the verse's paragraph is set in: its own span's, within the
  /// one Text gives it.
  TextStyle? verseStyle(WidgetTester tester) =>
      (tester.widget<RichText>(find.byType(RichText)).text as TextSpan).children!.whereType<TextSpan>().first.style;

  TextSpan? spanOf(WidgetTester tester, String text) {
    TextSpan? found;
    for (final paragraph in tester.widgetList<RichText>(find.byType(RichText))) {
      paragraph.text.visitChildren((span) {
        if (span is TextSpan && span.text == text) found = span;
        return found == null;
      });
    }
    return found;
  }

  /// The verse number leading the paragraph, joined to its first word by a
  /// no-break space: null where it hangs in a gutter, or isn't shown.
  TextSpan? numberSpan(WidgetTester tester) {
    for (final paragraph in tester.widgetList<RichText>(find.byType(RichText))) {
      final root = paragraph.text;
      if (root is! TextSpan || !root.toPlainText().startsWith('כב\u00A0')) continue;
      return spanOf(tester, 'כב');
    }
    return null;
  }

  group('typesetting (DESIGN_SYSTEM.md §4.7)', () {
    testWidgets('a verse number is gold Frank Ruhl Libre at 0.55 of the verse, joined to its first word', (tester) async {
      await pumpVerse(tester, serpent);
      final number = numberSpan(tester);
      expect(number, isNotNull, reason: 'a no-break space, so the number never ends a line alone');
      final colors = Theme.of(tester.element(find.byType(ScriptureVerse))).colorScheme;
      expect(number!.style?.fontFamily, 'FrankRuhlLibre');
      expect(number.style?.fontSize, closeTo(26 * 0.55, 0.001));
      expect(number.style?.fontWeight, FontWeight.w600);
      expect(number.style?.color, colors.secondary, reason: 'gold ink, never techelet');
      expect(verseStyle(tester)?.color, colors.onSurface);

      await pumpVerse(tester, serpent, dimmed: true);
      final dimInk = SeferColors.of(tester.element(find.byType(ScriptureVerse))).dimInk;
      expect(numberSpan(tester)!.style?.color, dimInk, reason: 'dimmed with its verse');
      expect(verseStyle(tester)?.color, dimInk);
    });

    testWidgets('a strut keeps every line of a verse at its pitch', (tester) async {
      await pumpVerse(tester, serpent, settings: const AppSettings(lineHeight: 2.2, readingScale: 1.5));
      final strut = tester.widget<RichText>(find.byType(RichText)).strutStyle!;
      expect(strut.fontFamily, 'NotoSerifHebrew');
      expect(strut.fontSize, closeTo(26 * 1.5, 0.001));
      expect(strut.height, 2.2);
      expect(strut.leadingDistribution, TextLeadingDistribution.even);
      expect(strut.forceStrutHeight, isFalse);
    });

    testWidgets('the guided reader hangs the number in a gutter at the verse\'s start', (tester) async {
      await pumpThemed(
        tester,
        ScriptureVerse(verse: serpent, kind: ScriptureKind.mikra, settings: const AppSettings(), hangingNumber: true),
      );
      final verse = tester.getRect(find.byType(ScriptureVerse));
      final number = find.text('כב');
      expect(number, findsOneWidget);
      expect(numberSpan(tester), isNull, reason: 'not in the paragraph too');
      // The gutter is on the right, the verse's start, 1.4 times its size.
      final gutter = tester.getRect(find.ancestor(of: number, matching: find.byType(SizedBox)).first);
      expect(gutter.right, verse.right);
      expect(gutter.width, closeTo(1.4 * 26, 0.001));
      final paragraph = tester.getRect(find.byType(RichText).last);
      expect(paragraph.right, closeTo(verse.right - 1.4 * 26, 0.001));
      final row = tester.widget<Row>(find.byType(Row));
      expect(row.crossAxisAlignment, CrossAxisAlignment.baseline, reason: 'on the first line\'s baseline');
    });

    testWidgets('at a very large size, the number leads the first line rather than take a quarter of it', (tester) async {
      await pumpThemed(
        tester,
        Center(
          child: SizedBox(
            width: 400,
            child: ScriptureVerse(
              verse: serpent,
              kind: ScriptureKind.mikra,
              settings: const AppSettings(readingScale: 4),
              hangingNumber: true,
            ),
          ),
        ),
      );
      expect(find.byType(Row), findsNothing);
      expect(numberSpan(tester), isNotNull);
    });

    for (final theme in [AppThemeMode.light, AppThemeMode.highContrastDark]) {
      testWidgets('the full text\'s Targum is set in from a gold-leaf rule: ${theme.name}', (tester) async {
        final targum = Verse.fromJson(const VerseRef(3, 22), ['וַאֲמַר יְיָ אֱלֹהִים הָא אָדָם הֲוָה יְחִידַי בְּעָלְמָא']);
        await pumpThemed(
          tester,
          ScriptureVerse(
            verse: targum,
            kind: ScriptureKind.targum,
            settings: const AppSettings(),
            secondary: true,
            showNumber: false,
            ruled: true,
          ),
          theme: theme,
        );
        final context = tester.element(find.byType(ScriptureVerse));
        final sefer = SeferColors.of(context);
        expect(numberSpan(tester), isNull, reason: 'its verse has the number');
        final box = tester.widget<Container>(find.descendant(of: find.byType(ScriptureVerse), matching: find.byType(Container)));
        final rule = ((box.decoration! as BoxDecoration).border! as Border).right;
        expect(rule.color, sefer.goldLeaf);
        expect(rule.width, 2);
        // A decoration, which high contrast leaves out (§3.1), but not its
        // inset.
        expect(rule.style, theme == AppThemeMode.light ? BorderStyle.solid : BorderStyle.none);
        final text = tester.getRect(find.byType(RichText));
        expect(text.right, tester.getRect(find.byType(ScriptureVerse)).right - 14);
      });
    }

    for (final (wordSpacing, letterSpacing) in [(0.0, 0.0), (4.0, 0.0), (16.0, 2.0)]) {
      testWidgets('a verse number stands a word space from its word: word spacing $wordSpacing, letter spacing $letterSpacing',
          (tester) async {
        await pumpVerse(tester, serpent, settings: AppSettings(wordSpacing: wordSpacing, letterSpacing: letterSpacing));
        final paragraph = tester.renderObject<RenderParagraph>(find.byType(RichText));
        final text = paragraph.text.toPlainText();
        double widthAt(int i) => paragraph
            .getBoxesForSelection(TextSelection(baseOffset: i, extentOffset: i + 1))
            .fold(0, (w, box) => w + box.right - box.left);
        expect(text.substring(0, 3), 'כב\u00A0', reason: 'a no-break space, so the number never ends a line alone');
        // The text engine widens only spaces a line may break at: the no-break
        // space carries the reader's word spacing itself.
        expect(widthAt(2), closeTo(widthAt(text.indexOf(' ')), 0.01));
      });
    }

    testWidgets('a large letter stands above the line, and moves no line apart', (tester) async {
      // Genesis 1:1, whose first letter the Masorah writes large.
      const words = 'רֵאשִׁית בָּרָא אֱלֹהִים';
      final large = Verse.fromJson(const VerseRef(1, 1), [{'big': 'בְּ'}, words]);
      final plain = Verse.fromJson(const VerseRef(1, 1), ['בְּ$words']);
      for (final lineHeight in [kMinLineHeight, 1.9, 2.6]) {
        final settings = AppSettings(lineHeight: lineHeight);
        await pumpVerse(tester, plain, settings: settings);
        final line = tester.getSize(find.byType(RichText)).height;
        await pumpVerse(tester, large, settings: settings);
        expect(tester.getSize(find.byType(RichText)).height, closeTo(line, 0.01), reason: 'at line height $lineHeight');
        expect(spanOf(tester, 'בְּ')!.style!.fontSize, closeTo(26 * 1.45, 0.001));
      }
    });

    testWidgets("dimmed, the Targum's rule recedes to a hairline, and Rashi's eyebrow to the dimmed ink", (tester) async {
      final targum = Verse.fromJson(const VerseRef(3, 22), ['וַאֲמַר יְיָ אֱלֹהִים']);
      await pumpThemed(
        tester,
        Column(
          children: [
            ScriptureVerse(
              verse: targum,
              kind: ScriptureKind.targum,
              settings: const AppSettings(),
              secondary: true,
              showNumber: false,
              ruled: true,
              dimmed: true,
            ),
            const RashiEyebrow(english: false, dimmed: true),
            const RashiEyebrow(english: false),
          ],
        ),
      );
      final sefer = SeferColors.of(tester.element(find.byType(ScriptureVerse)));
      final box = tester.widget<Container>(find.descendant(of: find.byType(ScriptureVerse), matching: find.byType(Container)));
      expect(((box.decoration! as BoxDecoration).border! as Border).right.color, sefer.hairline);
      final eyebrows = tester.widgetList<Text>(find.descendant(of: find.byType(RashiEyebrow), matching: find.byType(Text))).toList();
      expect(eyebrows.first.style?.color, sefer.dimInk);
      expect(eyebrows.last.style?.color, Theme.of(tester.element(find.byType(ScriptureVerse))).colorScheme.secondary);
    });

    testWidgets('what goes with a hanging verse shares its edge, past the gutter', (tester) async {
      await pumpThemed(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScriptureVerse(verse: serpent, kind: ScriptureKind.mikra, settings: const AppSettings(), hangingNumber: true),
            const HangingIndent(
              settings: AppSettings(),
              child: RashiComments(comments: [Comment('הן האדם', 'הֲרֵי הוּא יָחִיד')], settings: AppSettings(), english: false),
            ),
            const HangingIndent(settings: AppSettings(showVerseNumbers: false), child: SizedBox(height: 10, key: Key('bare'))),
          ],
        ),
      );
      final verseText = tester.getRect(find.byType(RichText).at(1));
      final rashi = tester.getRect(find.byType(RashiComments));
      expect(rashi.right, closeTo(verseText.right, 0.001));
      // With no numbers to hang, there is no gutter.
      expect(tester.getRect(find.byKey(const Key('bare'))).right, tester.getRect(find.byType(ScriptureVerse)).right);
    });

    testWidgets('the styles of each layer', (tester) async {
      await pumpThemed(tester, const SizedBox());
      final context = tester.element(find.byType(SizedBox));
      final scheme = Theme.of(context).colorScheme;
      ScriptureStyles styles([AppSettings settings = const AppSettings()]) => ScriptureStyles(context, settings);

      final targum = styles().style(ScriptureKind.targum);
      expect(targum.fontSize, closeTo(26 * 0.90, 0.001));
      expect(targum.color, scheme.onSurfaceVariant);
      expect(styles().heightFor(ScriptureKind.targum), closeTo(1.8, 1e-9));
      expect(styles(const AppSettings(lineHeight: 1.6)).heightFor(ScriptureKind.targum), 1.6);

      final rashi = styles().style(ScriptureKind.rashi);
      expect((rashi.fontFamily, rashi.height, rashi.color), ('NotoSerifHebrew', 1.7, scheme.onSurfaceVariant));
      expect(rashi.fontSize, closeTo(26 * 0.78, 0.001));
      final dibbur = styles().dibburStyle();
      expect((dibbur.fontFamily, dibbur.fontWeight, dibbur.color), ('FrankRuhlLibre', FontWeight.w700, scheme.onSurface));

      final script = styles(const AppSettings(rashiScript: true)).style(ScriptureKind.rashi);
      expect((script.fontFamily, script.height, script.fontWeight), ('NotoRashiHebrew', 1.75, FontWeight.w400));
      expect(script.fontSize, closeTo(26 * 0.80, 0.001));
      expect(script.fontFamilyFallback, ['NotoSerifHebrew'], reason: 'until the script has loaded');

      final english = styles(const AppSettings(readingScale: 1.2)).style(ScriptureKind.translation);
      expect((english.fontFamily, english.height, english.fontWeight), ('EBGaramond', 1.5, FontWeight.w500));
      expect(english.fontSize, closeTo(24, 0.001), reason: '20 times the reading size');
      expect(english.color, scheme.onSurfaceVariant);
      final lexend = styles(const AppSettings(uiFont: UiFont.lexend)).style(ScriptureKind.translation);
      expect((lexend.fontFamily, lexend.fontSize, lexend.fontWeight), ('Lexend', 17.0, FontWeight.w400));
      expect(lexend.height, closeTo(26 / 17, 1e-9));

      // The reading column's measure.
      expect(styles(const AppSettings(lineWidth: LineWidth.narrow)).maxLineWidth, 560);
      expect(styles().maxLineWidth, 680);
      expect(styles(const AppSettings(lineWidth: LineWidth.wide)).maxLineWidth, 880);
      // Spacing from an older version, below the minimum, is raised to it.
      expect(styles(const AppSettings(lineHeight: 1.5)).lineHeight, kMinLineHeight);
    });

    testWidgets('a translation\'s number is gold, with lining figures', (tester) async {
      await pumpThemed(tester, const TranslationVerse(text: 'And the LORD God said', number: 22, settings: AppSettings()));
      final scheme = Theme.of(tester.element(find.byType(TranslationVerse))).colorScheme;
      final number = spanOf(tester, '22 ')!;
      expect(number.style?.fontWeight, FontWeight.w600);
      expect(number.style?.color, scheme.secondary);
      expect(number.style?.fontFeatures, contains(const FontFeature.liningFigures()));
    });

    testWidgets('a comment\'s opening words are in bold full ink, never techelet', (tester) async {
      await pumpThemed(
        tester,
        const RashiComments(comments: [Comment('הן האדם', 'הֲרֵי הוּא יָחִיד')], settings: AppSettings(), english: false),
      );
      final scheme = Theme.of(tester.element(find.byType(RashiComments))).colorScheme;
      final heading = spanOf(tester, 'הן האדם ')!;
      expect(heading.style?.fontFamily, 'FrankRuhlLibre');
      expect(heading.style?.color, scheme.onSurface);
      expect(heading.style?.color, isNot(scheme.primary));
    });

    for (final hebrew in [false, true]) {
      testWidgets('a chapter is headed at the centre, in Hebrew${hebrew ? ' alone' : ', and in English beneath'}',
          (tester) async {
        final handle = tester.ensureSemantics();
        await pumpThemed(tester, const ChapterHeading(chapter: 3, settings: AppSettings(readingScale: 2.25)), hebrew: hebrew);
        final head = find.text('פרק ג');
        expect(head, findsOneWidget);
        final style = tester.widget<Text>(head).style!;
        final scheme = Theme.of(tester.element(head)).colorScheme;
        expect((style.fontFamily, style.fontWeight, style.color), ('FrankRuhlLibre', FontWeight.w600, scheme.secondary));
        expect(style.fontSize, closeTo(20 * math.sqrt(2.25), 0.001), reason: 'it grows more slowly than the text');
        expect(tester.getCenter(head).dx, closeTo(tester.getCenter(find.byType(ChapterHeading)).dx, 0.5));
        // Between two 32 px hairlines, 12 from it.
        final rules = find.descendant(of: find.byType(ChapterHeading), matching: find.byType(ColoredBox));
        expect(rules, findsNWidgets(2));
        expect(tester.getSize(rules.first).width, 32);
        expect(tester.getRect(head).left - tester.getRect(rules.last).right, closeTo(12, 0.5));
        expect(find.text('Chapter 3'), hebrew ? findsNothing : findsOneWidget);
        expect(
          tester.getSemantics(find.byType(ChapterHeading)),
          isSemantics(label: hebrew ? 'פרק ג' : 'Chapter 3', isHeader: true),
        );
        handle.dispose();
      });
    }

    for (final (kind, space) in [(SectionBreak.open, 20.0), (SectionBreak.closed, 10.0)]) {
      testWidgets('a ${kind.name} section is marked with $space px above and below', (tester) async {
        await pumpThemed(tester, Column(children: [SectionGap(kind: kind, settings: const AppSettings())]));
        final gap = tester.getRect(find.byType(SectionGap));
        final mark = tester.getRect(find.byType(SectionBreakMark));
        expect(mark.top - gap.top, space);
        expect(gap.bottom - mark.bottom, space);
        expect(find.text(kind == SectionBreak.open ? 'פ' : 'ס'), findsOneWidget);
      });
    }
  });

  group('focus mode', () {
    Widget group({required bool highlighted}) => VerseGroup(
          verse: serpent.ref,
          highlighted: highlighted,
          child: ScriptureVerse(verse: serpent, kind: ScriptureKind.mikra, settings: const AppSettings()),
        );

    testWidgets('highlights the verse on the paper, with a rule at its start, and moves nothing', (tester) async {
      await pumpThemed(tester, group(highlighted: false));
      final before = tester.getRect(find.byType(RichText));
      await pumpThemed(tester, group(highlighted: true));
      // Half way through its fade, and at its end.
      await tester.pump(Motion.short ~/ 2);
      expect(tester.getRect(find.byType(RichText)), before);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(RichText)), before);

      final context = tester.element(find.byType(VerseGroup));
      final box = tester.widget<Container>(
        find.descendant(of: find.byType(VerseGroup), matching: find.byType(Container)).first,
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, SeferColors.of(context).verseHighlight);
      final rule = (decoration.border! as Border).right;
      expect((rule.color, rule.width, rule.style), (Theme.of(context).colorScheme.primary, 3.0, BorderStyle.solid));
      expect(decoration.borderRadius, isNull, reason: 'Flutter draws no radius on a border of one side');
      // Inset alike either way: 12 at the start and end, 4 above and below.
      expect(tester.getRect(find.byType(VerseGroup)).right - before.right, 12);
      expect(before.top - tester.getRect(find.byType(VerseGroup)).top, 4);
    });

    testWidgets('fades the highlight in over a short beat', (tester) async {
      await pumpThemed(tester, group(highlighted: false));
      await pumpThemed(tester, group(highlighted: true));
      final container = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      expect(container.duration, Motion.short);
    });
  });
}
