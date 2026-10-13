import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/core/calendar/local_date.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/ui/widgets/ledger.dart';
import 'package:shnayim_mikrah/ui/widgets/lines.dart';

import '../../helpers.dart';

/// Today at 200% text, in the app's own fonts: the parsha's names keep each
/// word whole, a word too wide for the title page set a little smaller
/// rather than broken, and nothing overflows.
void main() {
  setUpAll(loadBundledFonts);

  for (final hebrew in [false, true]) {
    testWidgets('the parsha\'s names never break inside a word${hebrew ? ', in Hebrew' : ''}', (tester) async {
      // Tuesday of Matot-Masei 5787: a long name, joined by a hyphen, on a
      // 360 dp phone.
      await openRoute(
        tester,
        '/today',
        size: const Size(360, 2600),
        textScale: 2,
        now: DateTime(2027, 7, 27, 10),
        settings: AppSettings(
          onboardingComplete: true,
          joinDate: LocalDate(2027, 7, 25),
          language: hebrew ? AppLanguage.hebrew : AppLanguage.english,
        ),
      );
      // Each set with a word joiner after its hyphen or maqaf, so that no
      // line ends there; the English UI names it in English beneath, and the
      // Hebrew UI in Hebrew alone.
      for (final name in [if (!hebrew) 'Matot-Masei', 'מַטּוֹת־מַסְעֵי']) {
        final shown = WholeWords.unbroken(name);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: find.text(shown), matching: find.byType(RichText)),
        );
        final boxes = paragraph.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: shown.length));
        expect({for (final b in boxes) b.top}, hasLength(1), reason: name);
      }
      expect(find.byType(LedgerCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  // The catch-up card's run of aliyot, at the largest text on the smallest
  // phone: "Shlishi –" over "Shevi'i", never a line that starts with the
  // dash. Too wide for the line, "Shlishi –" is set a little smaller.
  for (final hebrew in [false, true]) {
    testWidgets('a run of aliyot to catch up on starts no line with its dash${hebrew ? ', in Hebrew' : ''}',
        (tester) async {
      tester.view.physicalSize = const Size(320, 3600);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await pumpApp(
        tester,
        settings: AppSettings(
          onboardingComplete: true,
          joinDate: captureJoinDate,
          language: hebrew ? AppLanguage.hebrew : AppLanguage.english,
        ),
        now: captureNow,
        progress: captureProgress(),
      );
      final run = hebrew ? 'שלישי\u00A0– שביעי' : 'Shlishi\u00A0– Shevi’i';
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: find.text(run), matching: find.byType(RichText)),
      );
      double lineOf(int offset) => paragraph
          .getBoxesForSelection(TextSelection(baseOffset: offset, extentOffset: offset + 1))
          .single
          .top;
      final dash = run.indexOf('–');
      expect(lineOf(dash), lineOf(0), reason: 'the dash ends the first line');
      expect(lineOf(run.length - 1), greaterThan(lineOf(0)), reason: 'on two lines at this size');
      expect(tester.takeException(), isNull);
      expectWholeWords(tester);
    });
  }

  // The catch-up card's facts at the largest text on the smallest phone:
  // each on a line of its own, whole where it fits ("96 verses", never "96 /
  // verses") and otherwise with its number held to what it counts ("about /
  // 33 min"), and no line that starts or ends with a middle dot.
  for (final hebrew in [false, true]) {
    testWidgets('the catch-up card keeps each number with what it counts${hebrew ? ', in Hebrew' : ''}',
        (tester) async {
      tester.view.physicalSize = const Size(320, 3600);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await pumpApp(
        tester,
        settings: AppSettings(
          onboardingComplete: true,
          joinDate: captureJoinDate,
          language: hebrew ? AppLanguage.hebrew : AppLanguage.english,
        ),
        now: captureNow,
        progress: captureProgress(),
      );
      final facts = findDotLine(
        hebrew ? '5 עליות · 96 פסוקים · כ־33 דק׳' : '5 aliyot · 96 verses · about 33 min',
      );
      expect(facts, findsOneWidget);
      expect(_lines(tester, facts), hebrew ? ['5 עליות', '96 פסוקים', 'כ־33 דק׳'] : ['5 aliyot', '96 verses', 'about', '33 min']);
      expect(tester.takeException(), isNull);
    });
  }

  // The check-in's sheet at 200% on a 412 dp phone, in Hebrew, whose spaced
  // ranges are the longest: an aliyah's reference and its verses each whole,
  // and the day it was read broken after its comma, not inside the date.
  testWidgets('the check-in sheet keeps a reference, its verses and the day whole, in Hebrew', (tester) async {
    tester.view.physicalSize = const Size(412, 2600);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await pumpApp(
      tester,
      settings: AppSettings(onboardingComplete: true, joinDate: captureJoinDate, language: AppLanguage.hebrew),
      now: DateTime(2026, 10, 12, 11),
      progress: captureProgress(),
    );
    await tester.tap(find.text('בחירת עליות'));
    await tester.pumpAndSettle();
    // Revi'i, Genesis 3:22–4:18: too long for one line with its verses.
    final revii = find.byWidgetPredicate((w) => w is DotLine && w.parts.length == 2 && w.parts.last == '21 פסוקים');
    expect(revii, findsOneWidget);
    expect(_lines(tester, revii), ['בראשית ג, כב – ד, יח', '21 פסוקים']);
    final day = findDotLine('תאריך הקריאה: שבת, כ״ט בתשרי');
    expect(day, findsOneWidget);
    expect(_lines(tester, day), ['תאריך הקריאה: שבת,', 'כ״ט בתשרי']);
    expect(tester.takeException(), isNull);
  });
}

/// The lines of [line], a line of parts ([DotLine]) or a text, as drawn, no-break
/// spaces read as spaces: a part kept whole on a line of its own is one.
List<String> _lines(WidgetTester tester, Finder line) {
  final lines = <String>[];
  for (final element in find.descendant(of: line, matching: find.byType(RichText)).evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
    // Where each line starts, by the top of each character's box.
    var top = double.nan;
    var start = 0;
    for (var i = 0; i < text.length; i++) {
      final boxes = paragraph.getBoxesForSelection(TextSelection(baseOffset: i, extentOffset: i + 1));
      if (boxes.isEmpty) continue;
      if (!top.isNaN && boxes.first.top > top + 1) {
        lines.add(text.substring(start, i).trim());
        start = i;
      }
      top = boxes.first.top;
    }
    lines.add(text.substring(start).trim());
  }
  return [for (final l in lines) l.replaceAll('\u00A0', ' ').replaceAll('\u2060', '')];
}
