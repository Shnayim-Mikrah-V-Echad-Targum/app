import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/text/hebrew_text.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../../helpers.dart';

void main() {
  for (final (language, written, spoken) in [
    (AppLanguage.hebrew, 'א-דני', 'שם אדנות'),
    (AppLanguage.english, 'Ado-nai', 'Adonai'),
  ]) {
    testWidgets('the Divine Name option is written with a hyphen and spoken as a word (${language.name})',
        (tester) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await pumpApp(tester, settings: AppSettings(onboardingComplete: true, language: language));
      c.read(routerProvider).go('/settings/accessibility');
      await tester.pumpAndSettle();
      final option = find.byWidgetPredicate(
        (w) => w is RadioListTile<DivineNameSpeech> && w.value == DivineNameSpeech.adonai,
      );
      await tester.ensureVisible(option);
      await tester.pumpAndSettle();

      expect(find.descendant(of: option, matching: find.text(written)), findsOneWidget);
      final label = tester.getSemantics(option).label;
      expect(label, contains(spoken));
      expect(label, isNot(contains(written)), reason: 'a screen reader would spell out the hyphenated letters');
      handle.dispose();
    });
  }
}
