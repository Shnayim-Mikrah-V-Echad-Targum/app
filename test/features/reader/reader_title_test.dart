import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/widgets/ornaments.dart';

import '../../helpers.dart';

// The reader's app bar title (DESIGN_SYSTEM.md §9 Reader), in the bundled
// fonts, whose metrics decide what fits beside the actions.
void main() {
  setUpAll(loadBundledFonts);

  final monday = DateTime(2026, 10, 12, 10); // week of Noach, 5787

  Future<void> open(WidgetTester tester, String path, {Size size = const Size(412, 915), AppSettings? settings}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(
      tester,
      settings: settings ?? const AppSettings(onboardingComplete: true, notificationPromptShown: true),
      now: monday,
    );
    c.read(routerProvider).go(path);
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  final bar = find.byType(AppBar);

  /// The title's lines: the eyebrow's text and the aliyah's.
  Finder lines() => find.descendant(
        of: find.ancestor(of: find.descendant(of: bar, matching: find.byType(Eyebrow)), matching: find.byType(Column)).first,
        matching: find.byType(RichText),
      );

  /// Every line of the title whole, within the room the actions leave it.
  void expectTitleWhole(WidgetTester tester) {
    final actions = tester.getRect(find.descendant(of: bar, matching: find.byTooltip('Listen'))).left;
    final found = lines();
    expect(found, findsNWidgets(2));
    for (final element in found.evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      expect(paragraph.didExceedMaxLines, isFalse, reason: paragraph.text.toPlainText());
      final right = paragraph.localToGlobal(Offset(paragraph.size.width, 0)).dx;
      expect(right, lessThanOrEqualTo(actions), reason: paragraph.text.toPlainText());
    }
  }

  for (final hebrew in [false, true]) {
    testWidgets('the app bar sets the parsha over the aliyah${hebrew ? ', in Hebrew alone' : ''}', (tester) async {
      final handle = tester.ensureSemantics();
      await open(
        tester,
        '/read/5787:2/3',
        settings: AppSettings(onboardingComplete: true, language: hebrew ? AppLanguage.hebrew : AppLanguage.english),
      );
      final parsha = find.descendant(of: bar, matching: find.text(hebrew ? 'נח' : 'Noach'));
      final aliyah = find.descendant(of: bar, matching: find.text(hebrew ? 'רביעי' : "Revi'i · רביעי"));
      expect(find.descendant(of: bar, matching: find.byType(Eyebrow)), findsOneWidget);
      expect(tester.getBottomLeft(parsha).dy, lessThanOrEqualTo(tester.getTopLeft(aliyah).dy));
      expect(tester.getSize(bar).height, 64);
      // Heard as the page names itself, the page's heading of level 1, as
      // every page's title is, over the chapter heads of level 2.
      final title = tester.getSemantics(aliyah);
      expect(title, isSemantics(label: hebrew ? 'נח · רביעי' : "Noach · Revi'i", isHeader: true));
      expect(title.getSemanticsData().headingLevel, 1);
      handle.dispose();
    });
  }

  for (final (label, font) in [('the standard font', UiFont.standard), ('Lexend', UiFont.lexend)]) {
    testWidgets('on a 360 dp phone, Chamishi is never cut short, in $label', (tester) async {
      await open(
        tester,
        '/read/5787:2/4',
        size: const Size(360, 780),
        settings: AppSettings(onboardingComplete: true, notificationPromptShown: true, uiFont: font),
      );
      expectTitleWhole(tester);
      // No room for its Hebrew name: the English one alone.
      expect(find.descendant(of: bar, matching: find.text('Chamishi')), findsOneWidget);
    });
  }

  testWidgets('a long double parsha is set smaller rather than cut short', (tester) async {
    // Acharei Mot-Kedoshim, read together in 5786.
    await open(tester, '/read/5786:29-30/4', size: const Size(360, 780));
    expectTitleWhole(tester);
  });

  testWidgets('with room for both, the English UI names the aliyah in Hebrew too', (tester) async {
    await open(tester, '/read/5787:2/4');
    expectTitleWhole(tester);
    expect(find.descendant(of: bar, matching: find.text('Chamishi · חמישי')), findsOneWidget);
  });

  testWidgets('on a 1920 dp desktop, the title starts where the text does, and has room', (tester) async {
    await open(tester, '/read/5787:2/4', size: const Size(1920, 1080));
    expectTitleWhole(tester);
    final column = tester.getTopLeft(find.text('Read the Hebrew')).dx;
    expect(tester.getTopLeft(find.descendant(of: bar, matching: find.text('Chamishi · חמישי'))).dx, column);
  });
}
