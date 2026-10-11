import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/l10n/app_localizations.dart';

import '../../helpers.dart';

/// Today's streak counts keep each word whole at any text size: a word too
/// wide for its card is set a little smaller rather than broken.
void main() {
  setUpAll(loadBundledFonts);

  for (final hebrew in [false, true]) {
    testWidgets('a streak count never breaks inside a word at 200% text${hebrew ? ', in Hebrew' : ''}',
        (tester) async {
      final l = lookupAppLocalizations(Locale(hebrew ? 'he' : 'en'));
      await openRoute(
        tester,
        '/today',
        size: const Size(412, 2600),
        textScale: 2,
        settings: AppSettings(onboardingComplete: true, language: hebrew ? AppLanguage.hebrew : AppLanguage.english),
      );
      final value = l.weeksCount(0);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: find.text(value), matching: find.byType(RichText)),
      );
      var start = 0;
      for (final word in value.split(' ')) {
        final boxes = paragraph.getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: start + word.length));
        expect({for (final b in boxes) b.top}, hasLength(1), reason: word);
        start += word.length + 1;
      }
      expect(tester.takeException(), isNull);
    });
  }
}
