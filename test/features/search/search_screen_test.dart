import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/text/hebrew_text.dart';
import 'package:shnayim_mikra/data/models/scripture.dart';
import 'package:shnayim_mikra/data/text_repository.dart';
import 'package:shnayim_mikra/features/reader/reader_screen.dart';
import 'package:shnayim_mikra/features/search/marked_text.dart';
import 'package:shnayim_mikra/features/search/search_screen.dart';
import 'package:shnayim_mikra/features/search/verse_index.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../../helpers.dart';

/// Monday of Noach 5787.
final _now = DateTime(2026, 10, 12, 10);

/// The verse that "ladder" finds, in the translation.
const _ladder = 'Genesis 28:12 · Translation (JPS 1917)';

/// Texts that can't be read the first [failures] times, as when the
/// bundle's files can't be fetched.
class _Failing extends TextRepository {
  _Failing(this.failures);
  int failures;
  int reads = 0;

  @override
  Future<T> readBook<T>(TextLayer layer, String book, T Function(BookText text) read) {
    reads++;
    if (failures > 0) {
      failures--;
      return Future.error(StateError('unreadable'));
    }
    return super.readBook(layer, book, read);
  }
}

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
    AppSettings? settings,
    TextRepository? texts,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final c = await pumpApp(
      tester,
      settings: settings ??
          AppSettings(onboardingComplete: true, language: hebrew ? AppLanguage.hebrew : AppLanguage.system),
      now: _now,
      overrides: [
        if (!buildIndex && texts == null) verseIndexProvider.overrideWith(() => _Built(index)),
        if (texts != null) textRepositoryProvider.overrideWithValue(texts),
      ],
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

  testWidgets('the Parsha tab opens search, through Go to verse', (tester) async {
    await open(tester, route: '/parsha');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search the Torah'));
    await tester.pumpAndSettle();
    // The sheet takes a reference or words, and hands words over.
    await tester.enterText(find.byType(TextField), 'ladder');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.text(_ladder), findsOneWidget);
    // Ready to type more.
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
    expect(find.text(_ladder), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text(_ladder), findsNothing);
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

  /// What is announced to screen readers from now on.
  List<String> announcements(WidgetTester tester) {
    final said = <String>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (m) async {
      final data = (m as Map)['data'] as Map;
      if (data['message'] case final String message) said.add(message);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler(SystemChannels.accessibility, null));
    return said;
  }

  testWidgets('says when the text could not be prepared, and tries again', (tester) async {
    final texts = _Failing(1);
    await open(tester, texts: texts);
    for (var i = 0; i < 100 && find.text('Something went wrong. Please try again.').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    final before = texts.reads;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget, reason: 'built again from the start');
    expect(texts.reads, greaterThan(before));
    await untilIndexed(tester);
    await search(tester, 'ladder');
    expect(find.text(_ladder), findsOneWidget);
  });

  testWidgets('says how many verses were found once typing pauses', (tester) async {
    final said = announcements(tester);
    await open(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'lad');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), 'ladder');
    await tester.pump(const Duration(milliseconds: 500));
    expect(said, isEmpty, reason: 'still typing');
    await tester.pump(const Duration(milliseconds: 400));
    expect(said, ['1 verse found']);
  });

  testWidgets('says how many were found when the index arrives after the search', (tester) async {
    final said = announcements(tester);
    await open(tester, buildIndex: true);
    await tester.enterText(find.byType(TextField), 'ladder');
    await tester.pump(const Duration(seconds: 1));
    expect(said, isEmpty, reason: 'nothing is found before the index is built');
    await untilIndexed(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(said, ['1 verse found']);
  });

  testWidgets('says how many were found for a search it was handed', (tester) async {
    final said = announcements(tester);
    await open(tester, route: '/search?q=ladder');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(said, ['1 verse found']);
  });

  // Genesis 15:2, אֲדֹנָי יֱהֹוִה: the hiriq under the Name says it is read
  // Elohim, so its spoken text must keep the vowels the page leaves out.
  testWidgets('speaks a verse from its vowels when they are hidden', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester, settings: const AppSettings(onboardingComplete: true, showNikud: false));
    await tester.pumpAndSettle();
    await search(tester, 'אדני יהוה');
    final shown = snippets(tester).first;
    expect(shown, isNot(contains('ֹ')), reason: 'no vowels shown');
    final label = tester.getSemantics(find.bySemanticsLabel(RegExp(r'^Genesis 15:2\. '))).label;
    expect(label, contains('אֲדֹנָי אֱלֹהִים'));
    expect(label, isNot(contains('יהוה')));
    handle.dispose();
  });

  testWidgets('keeps words joined by a maqaf on one line', (tester) async {
    await open(tester);
    await tester.pumpAndSettle();
    // Genesis 1:7, the first verse found, has אֶת־הָרָקִיעַ.
    await search(tester, 'הרקיע');
    expect(snippets(tester).first, contains('־\u2060'));
  });

  testWidgets('labels the translation as a translation', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester);
    await tester.pumpAndSettle();
    await search(tester, 'ladder');
    expect(find.text('Genesis 28:12 · Translation (JPS 1917)'), findsOneWidget);
    final label = tester.getSemantics(find.bySemanticsLabel(RegExp(r'^Genesis 28:12\. '))).label;
    expect(label, startsWith('Genesis 28:12. Translation (JPS 1917): '));
    handle.dispose();
  });

  testWidgets('types English left to right, and Hebrew right to left, in either UI', (tester) async {
    await open(tester, hebrew: true);
    await tester.pumpAndSettle();
    TextDirection? direction() => tester.widget<TextField>(find.byType(TextField)).textDirection;
    expect(direction(), isNull, reason: "the page's own while empty");
    await search(tester, 'ladder');
    expect(direction(), TextDirection.ltr);
    await search(tester, 'סולם');
    expect(direction(), TextDirection.rtl);
    await search(tester, 'sulam סולם');
    expect(direction(), TextDirection.rtl);
  });

  testWidgets('opens each search at the top of its results', (tester) async {
    await open(tester);
    await tester.pumpAndSettle();
    await search(tester, 'אברהם');
    final list = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable));
    tester.state<ScrollableState>(list).position.jumpTo(3000);
    await tester.pump();
    expect(find.textContaining(RegExp(r'^\d+ verses$')), findsNothing, reason: 'scrolled away from the count');
    await search(tester, 'יצחק');
    expect(tester.state<ScrollableState>(list).position.pixels, 0);
    expect(find.textContaining(RegExp(r'verses$')), findsOneWidget);
  });

  group('a match', () {
    Future<MarkedText> firstMarked(WidgetTester tester, {AppSettings? settings}) async {
      await open(tester, settings: settings);
      await tester.pumpAndSettle();
      await search(tester, 'ladder');
      return tester.widget<MarkedText>(find.byType(MarkedText).first);
    }

    testWidgets('is marked by its weight and wash', (tester) async {
      expect((await firstMarked(tester)).outline, isNull);
    });

    // Then every letter is bold, or the wash is close to the paper.
    testWidgets('is outlined too with bold text', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(boldText: true);
      expect((await firstMarked(tester)).outline, isNotNull);
    });

    testWidgets('is outlined too in high contrast', (tester) async {
      final marked = await firstMarked(
        tester,
        settings: const AppSettings(onboardingComplete: true, theme: AppThemeMode.highContrastLight),
      );
      expect(marked.outline, isNotNull);
    });
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
