import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/app/providers.dart';
import 'package:shnayim_mikrah/app/router.dart';
import 'package:shnayim_mikrah/core/calendar/local_date.dart';
import 'package:shnayim_mikrah/data/models/parsha.dart';
import 'package:shnayim_mikrah/data/models/verse_ref.dart';
import 'package:shnayim_mikrah/features/reader/haftarah_screen.dart';
import 'package:shnayim_mikrah/features/reader/scripture_text.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/ui/widgets/ornaments.dart';

import '../../helpers.dart';

/// Friday of Bereshit 5787, which is read on Shabbat Machar Chodesh
/// (10 October 2026), I Samuel 20:18–42: its own haftarah, Isaiah 42:5,
/// gives way.
final _friday = DateTime(2026, 10, 9, 10);
final _settings = AppSettings(onboardingComplete: true, joinDate: LocalDate(2026, 10, 4));

const _regularTitle = 'Also: the regular haftarah of Bereshit';
const _fallbackNote = 'Chabad haftarot are being verified; showing the Ashkenazi reading.';

/// The head of the regular haftarah's chapter 43, there only once it is open.
final _regularChapter = find.byWidgetPredicate((w) => w is ChapterHeading && w.chapter == 43, skipOffstage: false);

/// Waits for texts to load from the bundle (spinners never settle).
Future<void> _loadTexts(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  for (var i = 0; i < 40 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<ProviderContainer> _open(WidgetTester tester, String weekId, {AppSettings? settings, DateTime? now}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = await pumpApp(tester, settings: settings ?? _settings, now: now ?? _friday);
  c.read(routerProvider).go('/today/haftarah/$weekId');
  await tester.pump();
  for (var i = 0; i < 30 && find.byType(ScriptureVerse).evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
  await _loadTexts(tester);
  expect(find.byType(HaftarahScreen), findsOneWidget);
  return c;
}

Future<void> _toEnd(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.byType(SeferDivider), 600, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('names its book once, at its head, as the page heading', (tester) async {
    final handle = tester.ensureSemantics();
    await _open(tester, '5787:1');

    expect(find.text('Haftarah · Bereshit'), findsOneWidget);
    // Its range held together by a word joiner after the dash.
    expect(
      tester.getSemantics(find.text('I\u00A0Samuel 20:18–\u206042')),
      isSemantics(label: 'I\u00A0Samuel 20:18–\u206042', isHeader: true),
    );
    expect(find.text('Shabbat Machar Chodesh'), findsOneWidget);
    expect(find.text('I Samuel'), findsNothing, reason: 'no label for the one book it is drawn from');
    expect(find.byType(ChapterHeading), findsNothing, reason: 'all in one chapter, and the regular haftarah folded');
    handle.dispose();
  });

  testWidgets('meets the tap target and contrast guidelines, read or not', (tester) async {
    final handle = tester.ensureSemantics();
    final c = await _open(tester, '5787:1');
    for (final read in [null, LocalDate(2026, 10, 8)]) {
      c.read(progressProvider.notifier).markHaftarah('5787:1', read);
      await tester.pumpAndSettle();
      await _toEnd(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }
    handle.dispose();
  });

  testWidgets('heads a chapter where one begins', (tester) async {
    // Nitzavim-Vayeilech 5786: Isaiah 61:10–63:9.
    await _open(tester, '5786:51-52');
    final chapters = tester.widgetList<ChapterHeading>(find.byType(ChapterHeading, skipOffstage: false));
    expect([for (final h in chapters) h.chapter], [62, 63]);
  });

  testWidgets('drawn from two books, heads each with its name', (tester) async {
    // Shabbat Shuva with Ha'azinu 5786: Hosea 14:2–10, then Joel 2:15–27.
    await _open(tester, '5786:53');
    expect(findDotLine('Hosea 14:2–\u206010 · Joel 2:15–\u206027'), findsOneWidget);
    final books = tester.widgetList<ChapterHeading>(find.byType(ChapterHeading, skipOffstage: false));
    expect([for (final h in books) (h.hebrewName, h.name, h.chapter)], [('הושע', 'Hosea', null), ('יואל', 'Joel', null)]);
  });

  testWidgets("on Shabbat Rosh Chodesh on the 30th, adds Machar Chodesh's first and last verses", (tester) async {
    // Korach 5788, on 30 Sivan: Isaiah 66, then I Samuel 20:18 and 20:42 for
    // Sunday, Rosh Chodesh too.
    final handle = tester.ensureSemantics();
    final c = await _open(tester, '5788:38', now: DateTime(2028, 6, 20, 11));
    // Its passages, a book's name of two words held on one line, break
    // between them, and read as one heading.
    final heading = findDotLine('Isaiah 66:1–\u206024 · I\u00A0Samuel 20:18 · I\u00A0Samuel 20:42');
    expect(heading, findsOneWidget);
    expect(
      tester.getSemantics(heading),
      isSemantics(label: 'Isaiah 66:1–\u206024\u00A0· I\u00A0Samuel 20:18\u00A0· I\u00A0Samuel 20:42', isHeader: true),
    );
    handle.dispose();
    expect(find.text('Shabbat Rosh Chodesh, with verses for Sunday’s Rosh Chodesh'), findsOneWidget);
    final books = tester.widgetList<ChapterHeading>(find.byType(ChapterHeading, skipOffstage: false));
    expect([for (final h in books) h.name], ['Isaiah', 'I Samuel']);
    final verses = c.read(haftarahTextProvider('5788:38')).requireValue;
    expect(verses, hasLength(26));
    expect([for (final v in verses.skip(23)) (v.book, v.hebrew.ref)], [
      ('Isaiah', const VerseRef(66, 24)),
      ('I Samuel', const VerseRef(20, 18)),
      ('I Samuel', const VerseRef(20, 42)),
    ]);
  });

  testWidgets('is marked read at its end, and marked not read only explicitly, which can be undone', (tester) async {
    final c = await _open(tester, '5787:1');
    LocalDate? read() => c.read(progressProvider).week('5787:1').haftarah;
    await _toEnd(tester);

    final mark = find.widgetWithText(FilledButton, 'Mark the haftarah as read');
    await tester.ensureVisible(mark);
    await tester.tap(mark);
    await tester.pumpAndSettle();
    expect(read(), LocalDate(2026, 10, 9));
    expect(find.textContaining(wordsRegExp('Read on Friday, October 9'), findRichText: true), findsOneWidget);
    expect(find.text('Mark the haftarah as read'), findsNothing);

    // Let the confirmation go.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Mark as not read'));
    await tester.pumpAndSettle();
    expect(read(), isNull);
    expect(find.text('Marked as not read'), findsOneWidget);
    expect(find.text('Mark the haftarah as read'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(read(), LocalDate(2026, 10, 9), reason: 'the day it was read, restored');
    expect(find.textContaining(wordsRegExp('Read on Friday, October 9'), findRichText: true), findsOneWidget);
  });

  testWidgets('keeps the focus on whichever of its buttons takes the place of the one pressed', (tester) async {
    await _open(tester, '5787:1');
    await _toEnd(tester);
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
    bool focused(String label) => Focus.of(tester.element(find.text(label))).hasFocus;

    Focus.of(tester.element(find.text('Mark the haftarah as read'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(focused('Mark as not read'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(focused('Mark the haftarah as read'), isTrue);
  });

  group('the regular haftarah', () {
    testWidgets("opens Bereshit's own haftarah, folded, after Machar Chodesh's", (tester) async {
      final c = await _open(tester, '5787:1');
      expect(find.text('Shabbat Machar Chodesh'), findsOneWidget);
      expect(find.text(_regularTitle), findsOneWidget);
      expect(find.text('Isaiah 42:5–\u206043:10'), findsOneWidget);
      expect(_regularChapter, findsNothing, reason: 'folded');
      expect(find.text(_fallbackNote), findsNothing);

      await tester.ensureVisible(find.text(_regularTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_regularTitle));
      await _loadTexts(tester);
      expect(_regularChapter, findsOneWidget);
      expect(tester.widget<ChapterHeading>(_regularChapter).headingLevel, 3, reason: 'beneath its own heading');
      final verses = c.read(regularHaftarahTextProvider('5787:1')).requireValue;
      expect((verses.first.book, verses.first.hebrew.ref), ('Isaiah', const VerseRef(42, 5)));
      expect(verses.last.hebrew.ref, const VerseRef(43, 10));
    });

    testWidgets('comes before the haftarah ends and is marked read', (tester) async {
      await _open(tester, '5787:1');
      await _toEnd(tester);
      expect(
        tester.getTopLeft(find.text(_regularTitle)).dy,
        lessThan(tester.getTopLeft(find.byType(SeferDivider)).dy),
      );
    });

    // ExpansionTile tells screen readers its state in its hint, and announces
    // each change, in each platform's own way.
    testWidgets('is a heading that says whether it is open, and every target is big enough', (tester) async {
      final handle = tester.ensureSemantics();
      await _open(tester, '5787:1');
      await tester.ensureVisible(find.text(_regularTitle));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text(_regularTitle)),
        isSemantics(label: '$_regularTitle\nIsaiah 42:5–\u206043:10', isHeader: true, hint: 'Collapsed'),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await tester.tap(find.text(_regularTitle));
      await _loadTexts(tester);
      expect(tester.getSemantics(find.text(_regularTitle)), isSemantics(hint: 'Expanded'));
      handle.dispose();
    });

    testWidgets("opens unfolded for Chabad, saying above its verses that it is the Ashkenazi reading", (tester) async {
      await _open(tester, '5787:1', settings: _settings.withNusach(HaftarahNusach.chabad));
      expect(find.text(_regularTitle), findsOneWidget);
      expect(_regularChapter, findsOneWidget, reason: 'unfolded');
      // Machar Chodesh's haftarah is the same in every custom, so the note
      // is only the regular one's: under its heading, above its verses.
      final note = find.text(_fallbackNote, skipOffstage: false);
      expect(note, findsOneWidget);
      final regular = find.byType(ExpansionTile);
      expect(find.descendant(of: regular, matching: note), findsOneWidget);
      await tester.ensureVisible(note);
      await tester.pumpAndSettle();
      final firstRegularVerse = find.descendant(of: regular, matching: find.byType(ScriptureVerse)).first;
      expect(tester.getTopLeft(note).dy, greaterThan(tester.getBottomLeft(find.text(_regularTitle)).dy));
      expect(tester.getBottomLeft(note).dy, lessThan(tester.getTopLeft(firstRegularVerse).dy));
    });

    testWidgets("says under the page's heading, for Chabad, that a week's own haftarah is the Ashkenazi reading",
        (tester) async {
      // Noach 5787, with no special haftarah: Isaiah 54:1–55:5 for
      // Ashkenazim, 54:1–10 for Sephardim, and none yet sourced for Chabad.
      final chabad = _settings.withNusach(HaftarahNusach.chabad);
      await _open(tester, '5787:2', settings: chabad, now: DateTime(2026, 10, 13, 11));
      final heading = find.text('Haftarah · Noach');
      expect(heading, findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing, reason: 'no regular haftarah gives way');
      final note = find.text(_fallbackNote, skipOffstage: false);
      expect(note, findsOneWidget);
      final firstVerse = find.byType(ScriptureVerse).first;
      expect(tester.getTopLeft(note).dy, greaterThan(tester.getBottomLeft(heading).dy));
      expect(tester.getBottomLeft(note).dy, lessThan(tester.getTopLeft(firstVerse).dy));
    });

    testWidgets("says nothing for Chabad in a week whose haftarah every custom reads the same", (tester) async {
      // Lech Lecha 5787: Isaiah 40:27–41:16.
      await _open(tester, '5787:3', settings: _settings.withNusach(HaftarahNusach.chabad), now: DateTime(2026, 10, 20, 11));
      expect(find.text('Haftarah · Lech Lecha'), findsOneWidget);
      expect(find.text(_fallbackNote, skipOffstage: false), findsNothing);
    });

    testWidgets('is not shown, nor the note, in a week without a special one', (tester) async {
      await _open(tester, '5787:2', now: DateTime(2026, 10, 13, 11));
      expect(find.text('Haftarah · Noach'), findsOneWidget);
      expect(find.byType(ScriptureVerse), findsWidgets, reason: "Noach's haftarah");
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.text(_fallbackNote), findsNothing);
    });
  });

  group('Today', () {
    Future<void> openToday(WidgetTester tester, DateTime now) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpApp(tester, settings: _settings, now: now);
      await tester.pumpAndSettle();
    }

    testWidgets("says the haftarah page has the regular haftarah too, in a week it gives way", (tester) async {
      await openToday(tester, _friday);
      // Lines of the haftarah row's subtitle, under its reference.
      expect(find.textContaining('\nSpecial haftarah: Shabbat Machar Chodesh'), findsOneWidget);
      expect(find.textContaining('\nAlso the regular haftarah'), findsOneWidget);
    });

    testWidgets('says nothing of it in other weeks', (tester) async {
      await openToday(tester, DateTime(2026, 10, 13, 11));
      expect(find.text('Haftarah'), findsOneWidget);
      expect(find.textContaining('Also the regular haftarah'), findsNothing);
    });
  });
}
