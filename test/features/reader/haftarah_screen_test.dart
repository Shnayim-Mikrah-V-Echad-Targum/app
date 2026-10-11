import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/data/models/parsha.dart';
import 'package:shnayim_mikra/data/models/verse_ref.dart';
import 'package:shnayim_mikra/features/reader/haftarah_screen.dart';
import 'package:shnayim_mikra/features/reader/scripture_text.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/widgets/ornaments.dart';

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
    expect(tester.getSemantics(find.text('I Samuel 20:18–42')), isSemantics(label: 'I Samuel 20:18–42', isHeader: true));
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
    expect(find.text('Hosea 14:2–10 · Joel 2:15–27'), findsOneWidget);
    final books = tester.widgetList<ChapterHeading>(find.byType(ChapterHeading, skipOffstage: false));
    expect([for (final h in books) (h.hebrewName, h.name, h.chapter)], [('הושע', 'Hosea', null), ('יואל', 'Joel', null)]);
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
    expect(find.textContaining('Read on Friday, October 9', findRichText: true), findsOneWidget);
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
    expect(find.textContaining('Read on Friday, October 9', findRichText: true), findsOneWidget);
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
      expect(find.text('Isaiah 42:5–43:10'), findsOneWidget);
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
        isSemantics(label: '$_regularTitle\nIsaiah 42:5–43:10', isHeader: true, hint: 'Collapsed'),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await tester.tap(find.text(_regularTitle));
      await _loadTexts(tester);
      expect(tester.getSemantics(find.text(_regularTitle)), isSemantics(hint: 'Expanded'));
      handle.dispose();
    });

    testWidgets("opens unfolded for Chabad, whose haftarot are the Ashkenazi ones for now, as it says", (tester) async {
      await _open(tester, '5787:1', settings: _settings.withNusach(HaftarahNusach.chabad));
      expect(find.text(_fallbackNote), findsOneWidget);
      expect(find.text(_regularTitle), findsOneWidget);
      expect(_regularChapter, findsOneWidget, reason: 'unfolded');
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
      expect(find.text('Special haftarah: Shabbat Machar Chodesh'), findsOneWidget);
      expect(find.text('Also the regular haftarah'), findsOneWidget);
    });

    testWidgets('says nothing of it in other weeks', (tester) async {
      await openToday(tester, DateTime(2026, 10, 13, 11));
      expect(find.text('Haftarah'), findsOneWidget);
      expect(find.text('Also the regular haftarah'), findsNothing);
    });
  });
}
