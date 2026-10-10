import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/text/hebrew_text.dart';
import 'package:shnayim_mikra/data/text_repository.dart';
import 'package:shnayim_mikra/features/reader/reader_screen.dart';
import 'package:shnayim_mikra/features/search/marked_text.dart';
import 'package:shnayim_mikra/features/search/search_screen.dart';
import 'package:shnayim_mikra/features/search/verse_index.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../../helpers.dart';

/// Monday of Noach 5787.
final _now = DateTime(2026, 10, 12, 10);

/// The index, built once for the file: as the app builds it on first use.
class _Built extends VerseIndexLoader {
  _Built(this.index);
  final VerseIndex index;

  @override
  VerseIndexState build() => VerseIndexState(progress: 1, index: index);
}

void main() {
  late VerseIndex index;
  setUpAll(() async {
    await loadBundledFonts();
    index = await VerseIndex.build(TextRepository());
  });

  /// Opens [route] with the index already built, or with [buildIndex], as
  /// the app first opens search, building it.
  Future<ProviderContainer> open(
    WidgetTester tester, {
    String route = '/search',
    bool hebrew = false,
    double textScale = 1,
    bool buildIndex = false,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final c = await pumpApp(
      tester,
      settings: AppSettings(onboardingComplete: true, language: hebrew ? AppLanguage.hebrew : AppLanguage.system),
      now: _now,
      overrides: [if (!buildIndex) verseIndexProvider.overrideWith(() => _Built(index))],
    );
    c.read(routerProvider).go(route);
    await tester.pump();
    await tester.pump();
    return c;
  }

  /// Waits while the verse index is built from the bundled texts.
  Future<void> untilIndexed(WidgetTester tester) async {
    for (var i = 0; i < 200 && find.byType(LinearProgressIndicator).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
  }

  /// Opens the verse found at [reference], and waits for the reader's texts.
  Future<void> openVerse(WidgetTester tester, String reference) async {
    await tester.tap(find.text(reference));
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 100 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pumpAndSettle();
  }

  /// The plain text of each verse layer shown.
  List<String> snippets(WidgetTester tester) =>
      [for (final m in tester.widgetList<MarkedText>(find.byType(MarkedText))) m.text.toPlainText()];

  /// Where the reader on top was opened.
  String readerLocation(WidgetTester tester) => GoRouterState.of(tester.element(find.byType(ReaderScreen))).uri.toString();

  testWidgets('the Parsha tab opens search', (tester) async {
    await open(tester, route: '/parsha');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search the Torah'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
    // Ready to type.
    expect(tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus, isTrue);
  });

  testWidgets('shows the index being built, then invites a search', (tester) async {
    await open(tester, buildIndex: true);
    final bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(bar.value, isNotNull, reason: 'the progress is determinate');
    expect(find.text('Preparing the text for search…'), findsOneWidget);
    await untilIndexed(tester);
    expect(find.textContaining('Find a word or phrase'), findsOneWidget);
  });

  testWidgets('finds a phrase, under its parsha, and opens the verse in the reader', (tester) async {
    final c = await open(tester);
    await untilIndexed(tester);
    await search(tester, 'ויצא יעקב');
    expect(find.text('1 verse'), findsOneWidget);
    expect(find.text('Vayetzei'), findsOneWidget);
    expect(find.text('Genesis 28:10'), findsOneWidget);
    expect(snippets(tester).single, contains('חָרָנָה'));

    await openVerse(tester, 'Genesis 28:10');
    expect(readerLocation(tester), '/read/5787:7/0?mode=full&verse=28:10');
    final reader = tester.widget<ReaderScreen>(find.byType(ReaderScreen));
    expect((reader.weekId, reader.aliyah, reader.fullText), ('5787:7', 0, true));

    // Back to the results as they were.
    c.read(routerProvider).pop();
    await tester.pumpAndSettle();
    expect(find.text('Genesis 28:10'), findsOneWidget);
  });

  testWidgets('opens a verse at the aliyah of a week that reads two parshiyot together', (tester) async {
    await open(tester);
    await untilIndexed(tester);
    // Numbers 22:2 begins Balak, read with Chukat in the Diaspora in 5787.
    await search(tester, 'וירא בלק בן צפור');
    await openVerse(tester, 'Numbers 22:2');
    expect(readerLocation(tester), '/read/5787:39-40/3?mode=full&verse=22:2');
  });

  testWidgets('a verse found only in its Targum says so', (tester) async {
    await open(tester, route: '/search?q=${Uri.encodeQueryComponent('בקדמין')}');
    await untilIndexed(tester);
    expect(find.text('Genesis 1:1 · Targum'), findsOneWidget);
    final shown = snippets(tester);
    expect(shown, hasLength(2));
    expect(HebrewText.consonantsOnly(shown.last), startsWith('בקדמין'));
  });

  testWidgets('lists 200 verses of a common word, and says how many there are', (tester) async {
    await open(tester);
    await untilIndexed(tester);
    await search(tester, 'יהוה');
    expect(find.textContaining(RegExp(r'^The first 200 of \d+ verses$')), findsOneWidget);
    // A lazily built list learns its full length only as it scrolls.
    final list = tester.state<ScrollableState>(
      find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)),
    );
    for (var i = 0; i < 20 && find.text('Add a word to narrow the search.').evaluate().isEmpty; i++) {
      list.position.jumpTo(list.position.maxScrollExtent);
      await tester.pump();
    }
    expect(find.text('Add a word to narrow the search.'), findsOneWidget);
  });

  testWidgets('says when nothing is found, and how a search in Hebrew might find it', (tester) async {
    await open(tester);
    await untilIndexed(tester);
    await search(tester, 'אהרון');
    expect(find.text('No verse matches “\u2068אהרון\u2069”.'), findsOneWidget);
    expect(find.textContaining('leaves out ו\u00a0and\u00a0י'), findsOneWidget);

    await search(tester, 'smartphone');
    expect(find.textContaining('“hath” for “has”'), findsOneWidget);
  });

  testWidgets('clears the search', (tester) async {
    await open(tester);
    await untilIndexed(tester);
    await search(tester, 'ladder');
    expect(find.text('Genesis 28:12'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Genesis 28:12'), findsNothing);
    expect(find.textContaining('Find a word or phrase'), findsOneWidget);
  });

  testWidgets('keeps the index for the rest of the session', (tester) async {
    final c = await open(tester, buildIndex: true);
    await untilIndexed(tester);
    c.read(routerProvider).go('/today');
    await tester.pumpAndSettle();
    c.read(routerProvider).push('/search');
    await tester.pump();
    await tester.pump();
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('Find a word or phrase'), findsOneWidget);
  });

  testWidgets('a verse reads as one item, its reference and then its Hebrew, tagged as Hebrew', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester);
    await untilIndexed(tester);
    await search(tester, 'בקדמין');
    final node = tester.getSemantics(find.bySemanticsLabel(RegExp('^Genesis 1:1\\. ')));
    final label = node.attributedLabel;
    final plain = HebrewText.consonantsOnly(label.string);
    expect(plain, startsWith('Genesis 1:1. בראשית ברא'));
    expect(plain, contains('הארץ. Targum Onkelos: בקדמין'));
    final languages = label.attributes.whereType<LocaleStringAttribute>().toList();
    expect(languages, hasLength(2));
    for (final a in languages) {
      expect(a.locale, const Locale('he'));
      expect(label.string.substring(a.range.start, a.range.end), isNot(contains('Targum')));
    }
    expect(node, isSemantics(isButton: true, hasTapAction: true, isFocusable: true));
    handle.dispose();
  });

  testWidgets('in Hebrew, with Hebrew references', (tester) async {
    await open(tester, hebrew: true);
    await untilIndexed(tester);
    await search(tester, 'ויצא יעקב');
    expect(find.text('בראשית כח, י'), findsOneWidget);
    expect(find.text('פסוק אחד'), findsOneWidget);
  });

  group('accessibility', () {
    for (final hebrew in [false, true]) {
      testWidgets('tap targets and labels${hebrew ? ', Hebrew' : ''}', (tester) async {
        final handle = tester.ensureSemantics();
        await open(tester, hebrew: hebrew);
        await untilIndexed(tester);
        await search(tester, 'אברהם');
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });

      testWidgets('no overflow at 200% text size${hebrew ? ', Hebrew' : ''}', (tester) async {
        await open(tester, hebrew: hebrew, textScale: 2);
        await untilIndexed(tester);
        await search(tester, 'אברהם');
        expect(tester.takeException(), isNull);
        await search(tester, 'אהרון');
        expect(tester.takeException(), isNull);
      });
    }
  });
}
