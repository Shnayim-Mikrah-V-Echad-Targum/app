import 'dart:math' as math;
import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/reader/scripture_text.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../../helpers.dart';

/// The reader in the bundled fonts, as it is read: no verse, Targum,
/// translation or comment of Rashi ends on a word alone, wherever its last
/// two words take no more than half its line (holdLastPair).
void main() {
  setUpAll(loadBundledFonts);

  /// The paragraphs of scripture on the screen (and what goes with it) whose
  /// last line holds one word, though it and the word before it would fit
  /// in half a line; and how many paragraphs of more than one line there are.
  (List<String>, int) loneLastWords(WidgetTester tester) {
    final lone = <String>[];
    var checked = 0;
    final paragraphs = find.descendant(
      of: find.byWidgetPredicate((w) => w is ScriptureVerse || w is TranslationVerse || w is RashiComments),
      matching: find.byType(RichText),
    );
    for (final element in paragraphs.evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      if (!paragraph.hasSize) continue;
      final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
      List<TextBox> boxes(int start, int end) => paragraph.getBoxesForSelection(
            TextSelection(baseOffset: start, extentOffset: end),
            boxHeightStyle: BoxHeightStyle.max,
          );
      double width(int start, int end) => boxes(start, end).fold(0, (w, b) => w + b.right - b.left);
      final words = RegExp('[^ \u00A0]+').allMatches(text).toList();
      if (words.length < 2) continue;
      final lines = {for (final b in boxes(0, text.length)) b.top.round()};
      if (lines.length < 2) continue;
      checked++;
      // A word too wide for the line on its own is another matter.
      if (width(words.last.start, words.last.end) > paragraph.constraints.maxWidth) continue;
      final lastLine = boxes(words.last.start, words.last.end);
      // A word broken over two lines, as after a hyphen ("sin- / offering."),
      // leaves its end alone on the last.
      final broken = {for (final b in lastLine) b.top.round()}.length > 1;
      if (!broken &&
          boxes(words[words.length - 2].start, words[words.length - 2].end).last.top.round() ==
              lastLine.first.top.round()) {
        continue;
      }
      // Alone on its line: as holdLastPair counts words, between plain
      // spaces, were the two narrow enough to hold together?
      final runs = RegExp('[^ ]+').allMatches(text).toList();
      if (runs.length < 2) continue;
      final (before, last) = (runs[runs.length - 2], runs.last);
      // The space between them ends a line, where it takes no room: as wide
      // as another.
      final space = [
        for (var i = text.indexOf(' '); i >= 0; i = text.indexOf(' ', i + 1)) width(i, i + 1),
      ].fold(0.0, math.max);
      final pair = width(before.start, before.end) + space + width(last.start, last.end);
      if (pair <= paragraph.constraints.maxWidth / 2) lone.add('"${last[0]}" of "$text"');
    }
    return (lone, checked);
  }

  Future<void> open(WidgetTester tester, String route, {required AppSettings settings, required Size size, double textScale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final c = await pumpApp(tester, settings: settings, now: captureNow, progress: captureProgress());
    c.read(routerProvider).go(route);
    await tester.pump();
    // The texts load on real I/O, behind a spinner that never settles.
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
      if (i >= 3 && find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();
  }

  final base = AppSettings(onboardingComplete: true, notificationPromptShown: true, joinDate: captureJoinDate);
  final readings = {
    'the Targum and the translation': base.copyWith(showTranslation: true),
    'Rashi and the translation': base.copyWith(showTranslation: true, secondReading: SecondReading.rashi),
  };
  const views = [
    ('a 412 dp phone', Size(412, 2600), 1.0),
    ('a 360 dp phone', Size(360, 2600), 1.0),
    ('a tablet', Size(800, 2600), 1.0),
    ('a 412 dp phone at 200% text', Size(412, 2600), 2.0),
  ];

  for (final MapEntry(key: reading, value: settings) in readings.entries) {
    for (final (view, size, textScale) in views) {
      testWidgets('the full text with $reading, on $view, ends no paragraph on a word alone', (tester) async {
        await open(tester, '/read/5787:1/2?mode=full', settings: settings, size: size, textScale: textScale);
        final (lone, checked) = loneLastWords(tester);
        expect(checked, greaterThan(10), reason: 'paragraphs of more than one line');
        expect(lone, isEmpty);
      });
    }
  }

  // Genesis 22, whose translation ends verses on "burnt-offering?’" and
  // "Beer-sheba.", which a line could break after the hyphen of.
  for (final (view, size, textScale) in views) {
    testWidgets('the full text of Vayera\'s seventh aliyah, with the translation, on $view, ends no verse on '
        'a word alone, nor on the end of a hyphened word', (tester) async {
      await open(tester, '/read/5787:4/6?mode=full', settings: readings.values.first, size: size, textScale: textScale);
      final (lone, checked) = loneLastWords(tester);
      expect(checked, greaterThan(10), reason: 'paragraphs of more than one line');
      expect(lone, isEmpty);
    });
  }

  testWidgets('the haftarah, on a 412 dp phone, ends no verse on a word alone', (tester) async {
    await open(tester, '/haftarah/5786:51-52', settings: base.copyWith(showTranslation: true), size: const Size(412, 2600));
    final (lone, checked) = loneLastWords(tester);
    expect(checked, greaterThan(10), reason: 'paragraphs of more than one line');
    expect(lone, isEmpty);
  });

  testWidgets('the guided reader, on a 360 dp phone, ends no verse on a word alone', (tester) async {
    await open(tester, '/read/5786:29-30/4', settings: base, size: const Size(360, 2600));
    final (lone, checked) = loneLastWords(tester);
    expect(checked, greaterThan(0), reason: 'paragraphs of more than one line');
    expect(lone, isEmpty);
  });
}
