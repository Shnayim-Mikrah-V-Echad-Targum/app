import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/app/router.dart';
import 'package:shnayim_mikrah/features/reader/reader_screen.dart';
import 'package:shnayim_mikrah/features/reader/scripture_text.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/ui/widgets/ornaments.dart';

import '../../helpers.dart';

// The reader's app bar title (DESIGN_SYSTEM.md §9 Reader), in the bundled
// fonts, whose metrics decide what fits beside the actions.
void main() {
  setUpAll(loadBundledFonts);

  final monday = DateTime(2026, 10, 12, 10); // week of Noach, 5787

  Future<ProviderContainer> open(WidgetTester tester, String path, {Size size = const Size(412, 915), AppSettings? settings}) async {
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
    return c;
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
      final aliyah = find.descendant(of: bar, matching: find.text(hebrew ? 'רביעי' : 'Revi’i · רביעי'));
      expect(find.descendant(of: bar, matching: find.byType(Eyebrow)), findsOneWidget);
      expect(tester.getBottomLeft(parsha).dy, lessThanOrEqualTo(tester.getTopLeft(aliyah).dy));
      expect(tester.getSize(bar).height, 64);
      // Heard as the page names itself, the page's heading of level 1, as
      // every page's title is, over the chapter heads of level 2.
      final title = tester.getSemantics(aliyah);
      expect(title, isSemantics(label: hebrew ? 'נח · רביעי' : 'Noach · Revi’i', isHeader: true));
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

  group('the title after the home or back button', () {
    test('starts where the text does wherever the button leaves room', () {
      // A phone's text starts under the button: the usual 16 after it.
      expect(ReaderScreen.titleInset(20, hasLeading: true), (null, 16.0));
      expect(ReaderScreen.titleInset(52, hasLeading: true), (null, 16.0), reason: 'no room for the button and 8');
      // A tablet's starts just past it: a narrower slot, and a smaller space.
      expect(ReaderScreen.titleInset(56, hasLeading: true), (48.0, 8.0));
      expect(ReaderScreen.titleInset(60, hasLeading: true), (52.0, 8.0), reason: '800 dp');
      expect(ReaderScreen.titleInset(68, hasLeading: true), (56.0, 12.0), reason: 'the slot no wider than 56');
      // A wide window's: the usual 56, and the rest of the way.
      expect(ReaderScreen.titleInset(72, hasLeading: true), (null, 16.0));
      expect(ReaderScreen.titleInset(343, hasLeading: true), (null, 287.0), reason: '1366 dp');
      // With no button, the title alone.
      expect(ReaderScreen.titleInset(20, hasLeading: false), (null, 20.0));
      expect(ReaderScreen.titleInset(60, hasLeading: false), (null, 60.0));
    });

    for (final hebrew in [false, true]) {
      testWidgets('on an 800 dp tablet, starts where the text does${hebrew ? ', in Hebrew' : ''}', (tester) async {
        await open(
          tester,
          '/read/5787:2/4',
          size: const Size(800, 1180),
          settings: AppSettings(
            onboardingComplete: true,
            notificationPromptShown: true,
            language: hebrew ? AppLanguage.hebrew : AppLanguage.english,
          ),
        );
        final step = find.text(hebrew ? 'קריאת המקרא' : 'Read the Hebrew');
        final aliyah = find.descendant(of: bar, matching: find.text(hebrew ? 'חמישי' : 'Chamishi · חמישי'));
        final parsha = find.descendant(of: bar, matching: find.text(hebrew ? 'נח' : 'Noach'));
        final home = tester.getRect(find.descendant(of: bar, matching: find.byTooltip(hebrew ? 'היום' : 'Today')));
        if (hebrew) {
          final column = tester.getTopRight(step).dx;
          expect(column, 740, reason: 'the 680 column, centred');
          expect(tester.getTopRight(aliyah).dx, column);
          expect(tester.getTopRight(parsha).dx, column);
          expect(home.left, greaterThanOrEqualTo(column), reason: 'the button clear of the title');
        } else {
          final column = tester.getTopLeft(step).dx;
          expect(column, 60, reason: 'the 680 column, centred');
          expect(tester.getTopLeft(aliyah).dx, column);
          expect(tester.getTopLeft(parsha).dx, column);
          expect(home.right, lessThanOrEqualTo(column), reason: 'the button clear of the title');
          expectTitleWhole(tester);
        }
        // The button keeps its whole target.
        expect(home.width, greaterThanOrEqualTo(48));
        expect(home.height, greaterThanOrEqualTo(48));
      });
    }

    for (final hebrew in [false, true]) {
      testWidgets('on an 800 dp tablet, opened over another page, starts after the whole back button'
          '${hebrew ? ', in Hebrew' : ''}', (tester) async {
        // Opened from Today or the week's page, as most often: the app bar
        // has a back button rather than the home button.
        final c = await open(
          tester,
          '/today',
          size: const Size(800, 1180),
          settings: AppSettings(
            onboardingComplete: true,
            notificationPromptShown: true,
            language: hebrew ? AppLanguage.hebrew : AppLanguage.english,
          ),
        );
        unawaited(c.read(routerProvider).push('/read/5787:2/4'));
        await tester.pump();
        await tester.pump();
        for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
          await tester.pump();
        }
        await tester.pumpAndSettle();
        final back = find.descendant(of: bar, matching: find.byType(BackButton));
        expect(back, findsOneWidget);
        final button = tester.getRect(find.descendant(of: back, matching: find.byType(IconButton)));
        expect(button.width, greaterThanOrEqualTo(48));
        expect(button.height, greaterThanOrEqualTo(48));
        final aliyah = find.descendant(of: bar, matching: find.text(hebrew ? 'חמישי' : 'Chamishi · חמישי'));
        if (hebrew) {
          expect(tester.getTopRight(aliyah).dx, 740);
          expect(button.left, greaterThanOrEqualTo(740), reason: 'the button clear of the title');
        } else {
          expect(tester.getTopLeft(aliyah).dx, 60);
          expect(button.right, lessThanOrEqualTo(60), reason: 'the button clear of the title');
          expectTitleWhole(tester);
        }
      });

      testWidgets('on an 800 dp tablet, in the full text, starts where its verses do${hebrew ? ', in Hebrew' : ''}',
          (tester) async {
        await open(
          tester,
          '/read/5787:2/4?mode=full',
          size: const Size(800, 1180),
          settings: AppSettings(
            onboardingComplete: true,
            notificationPromptShown: true,
            language: hebrew ? AppLanguage.hebrew : AppLanguage.english,
          ),
        );
        // The verses stand within their blocks, 12 inside the column.
        final verse = find.byType(ScriptureVerse).first;
        final aliyah = find.descendant(of: bar, matching: find.text(hebrew ? 'חמישי' : 'Chamishi · חמישי'));
        final home = tester.getRect(find.descendant(of: bar, matching: find.byTooltip(hebrew ? 'היום' : 'Today')));
        if (hebrew) {
          // The text starts at the right in either language: its block's
          // inset is the same at the left.
          final edge = tester.getTopLeft(verse).dx;
          expect(edge, 72);
          expect(tester.getTopRight(aliyah).dx, 800 - edge);
          expect(home.left, greaterThanOrEqualTo(800 - edge));
        } else {
          final edge = tester.getTopLeft(verse).dx;
          expect(edge, 72);
          expect(tester.getTopLeft(aliyah).dx, edge);
          expect(home.right, lessThanOrEqualTo(edge));
          expectTitleWhole(tester);
        }
        expect(home.width, greaterThanOrEqualTo(48));
      });
    }
  });

  testWidgets('on a 1920 dp desktop, the title starts where the text does, and has room', (tester) async {
    await open(tester, '/read/5787:2/4', size: const Size(1920, 1080));
    expectTitleWhole(tester);
    final column = tester.getTopLeft(find.text('Read the Hebrew')).dx;
    expect(tester.getTopLeft(find.descendant(of: bar, matching: find.text('Chamishi · חמישי'))).dx, column);
  });
}
