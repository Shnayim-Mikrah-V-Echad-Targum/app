import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/data/models/verse_ref.dart';
import 'package:shnayim_mikra/features/reader/reader_screen.dart';
import 'package:shnayim_mikra/features/reader/scripture_text.dart';
import 'package:shnayim_mikra/features/reader/verse_anchor.dart';
import 'package:shnayim_mikra/features/search/go_to_verse_sheet.dart';
import 'package:shnayim_mikra/features/search/search_screen.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/widgets/paper_group.dart';

import '../../helpers.dart';

/// Monday of Noach 5787: this week's book is Genesis.
final _now = DateTime(2026, 10, 12, 10);

void main() {
  /// Opens [route] (a tab) in a phone, in English or Hebrew.
  Future<ProviderContainer> open(
    WidgetTester tester, {
    String route = '/parsha',
    bool hebrew = false,
    bool ashkenazi = false,
    double textScale = 1,
    Size size = const Size(412, 915),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final c = await pumpApp(
      tester,
      settings: AppSettings(
        onboardingComplete: true,
        language: hebrew ? AppLanguage.hebrew : AppLanguage.system,
        nameStyle: ashkenazi ? NameStyle.ashkenazi : NameStyle.sephardi,
      ),
      now: _now,
    );
    c.read(routerProvider).go(route);
    await tester.pumpAndSettle();
    return c;
  }

  bool hebrewUi(WidgetTester tester) =>
      Localizations.localeOf(tester.element(find.byType(Scaffold).first)).languageCode == 'he';

  /// Opens the sheet from the Parsha tab's search button, unless it is open,
  /// and types [query].
  Future<void> goTo(WidgetTester tester, String query) async {
    if (find.byType(GoToVerseSheet).evaluate().isEmpty) {
      await tester.tap(find.byTooltip(hebrewUi(tester) ? 'חיפוש בתורה' : 'Search the Torah'));
      await tester.pumpAndSettle();
    }
    await tester.enterText(find.byType(TextField), query);
    await tester.pumpAndSettle();
  }

  /// A row the sheet offers, by its text.
  Finder row(String text) => find.descendant(of: find.byType(PaperGroup), matching: find.text(text));

  /// Waits for the reader's texts.
  Future<void> untilRead(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 40 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  String location(WidgetTester tester, Type page) => GoRouterState.of(tester.element(find.byType(page))).uri.toString();

  Finder marked() => find.byWidgetPredicate((w) => w is TargetVerseMark && w.active);

  testWidgets('the Parsha tab’s search button opens it, ready to type', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Search the Torah'));
    await tester.pumpAndSettle();
    expect(find.byType(GoToVerseSheet), findsOneWidget);
    expect(find.text('A verse, word or phrase'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode?.hasFocus, isTrue);
    expect(field.decoration?.hintText, 'Bereshit 28:12');
  });

  testWidgets('the example follows the reader’s spelling of parsha names', (tester) async {
    await open(tester, ashkenazi: true);
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).decoration?.hintText, 'Bereishis 28:12');
  });

  testWidgets('a reference in Hebrew opens the reader at that verse', (tester) async {
    await open(tester);
    await goTo(tester, 'בראשית כח יב');
    expect(find.text('Genesis 28:12'), findsOneWidget);
    expect(find.text('Vayetzei · Rishon'), findsOneWidget);
    expect(find.textContaining('Search for'), findsNothing, reason: 'the text has no numbers to search for');

    await tester.tap(find.text('Genesis 28:12'));
    await untilRead(tester);
    expect(find.byType(GoToVerseSheet), findsNothing);
    expect(location(tester, ReaderScreen), '/read/5787:7/0?verse=28:12');
    final marks = find.descendant(of: marked(), matching: find.byType(ScriptureVerse));
    expect(tester.widget<ScriptureVerse>(marks.first).verse.ref, const VerseRef(28, 12));
  });

  testWidgets('Enter opens the verse', (tester) async {
    await open(tester);
    await goTo(tester, 'Gen 28:12');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await untilRead(tester);
    expect(location(tester, ReaderScreen), '/read/5787:7/0?verse=28:12');
  });

  testWidgets('a chapter and verse alone are in this week’s book', (tester) async {
    await open(tester);
    await goTo(tester, '3:22');
    expect(find.text('Genesis 3:22'), findsOneWidget);
    expect(find.text('Bereshit · Revi\'i'), findsOneWidget);
  });

  testWidgets('a verse of a week read with the next opens in that week, at its aliyah', (tester) async {
    await open(tester);
    // Numbers 22:2 begins Balak, read with Chukat in the Diaspora in 5787.
    await goTo(tester, 'Balak 22:2');
    expect(find.text('Chukat-Balak · Revi\'i'), findsOneWidget);
    await tester.tap(find.text('Numbers 22:2'));
    await untilRead(tester);
    expect(location(tester, ReaderScreen), '/read/5787:39-40/3?verse=22:2');
  });

  testWidgets('words are handed to search, with Enter or a tap', (tester) async {
    await open(tester);
    await goTo(tester, 'ladder');
    expect(find.text('Search for “\u2068ladder\u2069”'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(location(tester, SearchScreen), '/search?q=ladder');
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, 'ladder');
  });

  testWidgets('a parsha’s name may be a word: both are offered', (tester) async {
    await open(tester);
    await goTo(tester, 'ויצא');
    expect(find.text('Genesis 28:10'), findsOneWidget);
    expect(find.text('Search for “\u2068ויצא\u2069”'), findsOneWidget);
  });

  testWidgets('says when the book or chapter is shorter', (tester) async {
    await open(tester);
    await goTo(tester, 'Gen 51:1');
    expect(find.text('Genesis has 50 chapters.'), findsOneWidget);
    await goTo(tester, 'Gen 28:30');
    expect(find.text('Genesis 28 has 22 verses.'), findsOneWidget);
    // Enter leads nowhere, and the field keeps the focus.
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();
    expect(find.byType(GoToVerseSheet), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus, isTrue);
  });

  testWidgets('clears the field', (tester) async {
    await open(tester);
    await goTo(tester, 'Gen 28:12');
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Genesis 28:12'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, isEmpty);
  });

  testWidgets('in Hebrew', (tester) async {
    await open(tester, hebrew: true);
    await goTo(tester, '');
    expect(find.descendant(of: find.byType(GoToVerseSheet), matching: find.text('חיפוש בתורה')), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).decoration?.hintText, 'בראשית כח, יב');
    await goTo(tester, 'בראשית כ״ח:י״ב');
    expect(row('בראשית כח, יב'), findsOneWidget);
    expect(row('ויצא · ראשון'), findsOneWidget);
    await goTo(tester, 'בראשית כח, ל');
    expect(row('בפרק כח בספר בראשית 22 פסוקים.'), findsOneWidget);
    await goTo(tester, 'דברים לה');
    expect(row('בספר דברים 34 פרקים.'), findsOneWidget);
  });

  testWidgets('says what it found, once typing pauses', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(supportsAnnounce: true);
    await open(tester);
    await goTo(tester, 'Gen 28:12');
    tester.takeAnnouncements();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeAnnouncements().map((a) => a.message), ['Genesis 28:12, Vayetzei · Rishon']);
  });

  group('Ctrl+K', () {
    Future<void> press(WidgetTester tester) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    }

    testWidgets('opens it from any tab, before anything has the focus', (tester) async {
      for (final tab in ['/today', '/progress', '/settings']) {
        await open(tester, route: tab);
        await press(tester);
        expect(find.byType(GoToVerseSheet), findsOneWidget, reason: tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(GoToVerseSheet), findsNothing, reason: tab);
      }
    });

    testWidgets('opens it on a desktop, beside the rail', (tester) async {
      await open(tester, route: '/today', size: const Size(1366, 860));
      await press(tester);
      expect(find.byType(GoToVerseSheet), findsOneWidget);
    });

    testWidgets('is the reader’s own business in the reader', (tester) async {
      await open(tester, route: '/today');
      GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/read/5787:2/0');
      await untilRead(tester);
      await press(tester);
      expect(find.byType(GoToVerseSheet), findsNothing);
    });

    testWidgets('opens one sheet, not one over another', (tester) async {
      await open(tester, route: '/today');
      await press(tester);
      await press(tester);
      expect(find.byType(GoToVerseSheet), findsOneWidget);
    });
  });

  group('accessibility', () {
    for (final hebrew in [false, true]) {
      testWidgets('tap targets and labels${hebrew ? ', Hebrew' : ''}', (tester) async {
        final handle = tester.ensureSemantics();
        await open(tester, hebrew: hebrew);
        await goTo(tester, 'ויצא');
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });

      testWidgets('no overflow at 200% text size${hebrew ? ', Hebrew' : ''}', (tester) async {
        await open(tester, hebrew: hebrew, textScale: 2);
        await goTo(tester, 'ויצא');
        expect(tester.takeException(), isNull);
        await goTo(tester, 'Gen 28:30');
        expect(tester.takeException(), isNull);
      });
    }
  });
}
