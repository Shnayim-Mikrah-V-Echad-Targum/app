import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/about/about_screen.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/l10n/app_localizations.dart';
import 'package:shnayim_mikra/ui/l10n.dart';

import '../helpers.dart';

/// Latin runs inside Hebrew text keep their own order (docs/DESIGN_SYSTEM.md
/// §4.6): ranges of numbers, package names, addresses.
void main() {
  test('ltr isolates a run left to right', () {
    expect(ltr('3:22–4:18'), '\u20663:22–4:18\u2069');
  });

  for (final (locale, run) in [(const Locale('he'), '\u2066a@b.org\u2069'), (const Locale('en'), 'a@b.org')]) {
    testWidgets('a Latin run is isolated in the Hebrew UI only (${locale.languageCode})', (tester) async {
      String? got;
      await tester.pumpWidget(Localizations(
        locale: locale,
        delegates: AppLocalizations.localizationsDelegates,
        child: Builder(builder: (context) {
          got = context.ltrRun('a@b.org');
          return const SizedBox();
        }),
      ));
      await tester.pump();
      expect(got, run);
    });
  }

  Future<void> open(WidgetTester tester, String route, AppLanguage language) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: AppSettings(onboardingComplete: true, language: language));
    c.read(routerProvider).go(route);
    await tester.pumpAndSettle();
  }

  /// The left edge of [part] where the text of [text] draws it.
  double leftOf(WidgetTester tester, Finder text, String part) {
    final paragraph = tester.renderObject<RenderParagraph>(text);
    final plain = paragraph.text.toPlainText();
    final start = plain.indexOf(part);
    expect(start, isNonNegative, reason: '"$part" in "$plain"');
    final boxes = paragraph.getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: start + part.length));
    return boxes.map((b) => b.left).reduce(math.min);
  }

  testWidgets('Sources in Hebrew: a range of years reads 1929–1934, and @hebcal/leyning keeps its @ in front',
      (tester) async {
    await open(tester, '/sources', AppLanguage.hebrew);
    final rashi = find.textContaining('1929');
    await tester.ensureVisible(rashi);
    expect(leftOf(tester, rashi, '1929'), lessThan(leftOf(tester, rashi, '1934')));

    final hebcal = find.textContaining('hebcal/leyning');
    await tester.ensureVisible(hebcal);
    await tester.pumpAndSettle();
    expect(leftOf(tester, hebcal, '@'), lessThan(leftOf(tester, hebcal, 'hebcal')));
  });

  testWidgets('a range of aliyot in a Hebrew setting reads 1–6', (tester) async {
    await open(tester, '/settings/reading', AppLanguage.hebrew);
    final shevii = find.textContaining('בימים א׳–ו׳');
    await tester.ensureVisible(shevii);
    expect(leftOf(tester, shevii, '1'), lessThan(leftOf(tester, shevii, '6')));
  });

  for (final doc in ['privacy', 'accessibility']) {
    testWidgets('$doc: the contact address is isolated on a line of its own in Hebrew', (tester) async {
      await open(tester, '/legal/$doc', AppLanguage.hebrew);
      final line = find.textContaining('\n${ltr('$issueTrackerUri')}');
      await tester.ensureVisible(line);
      expect(line, findsOneWidget);
    });

    testWidgets('$doc: the contact address is as it is in English', (tester) async {
      await open(tester, '/legal/$doc', AppLanguage.english);
      final line = find.textContaining('$issueTrackerUri');
      await tester.ensureVisible(line);
      expect(line, findsOneWidget);
      expect(find.textContaining('\u2066'), findsNothing);
    });
  }
}
