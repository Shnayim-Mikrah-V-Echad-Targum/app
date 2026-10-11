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
}
