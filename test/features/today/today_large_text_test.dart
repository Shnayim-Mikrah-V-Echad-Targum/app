import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/widgets/ledger.dart';
import 'package:shnayim_mikra/ui/widgets/lines.dart';

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
      // line ends there; the Hebrew UI names it in English beneath.
      for (final name in ['Matot-Masei', 'מַטּוֹת־מַסְעֵי']) {
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
      final run = hebrew ? 'שלישי\u00A0– שביעי' : "Shlishi\u00A0– Shevi'i";
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
}
