import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/data/models/verse_ref.dart';
import 'package:shnayim_mikra/features/community/ui/compose_screen.dart';
import 'package:shnayim_mikra/features/notes/domain/annotations.dart';
import 'package:shnayim_mikra/features/notes/note_dialog.dart';
import 'package:shnayim_mikra/features/notes/notes_screen.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/reader/reader_screen.dart';
import 'package:shnayim_mikra/features/reader/scripture_text.dart';
import 'package:shnayim_mikra/features/reader/verse_actions_sheet.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/settings/backup.dart';
import 'package:shnayim_mikra/features/settings/screens/data_settings_screen.dart';
import 'package:shnayim_mikra/services/backup_files.dart';

import '../../fake_backup_files.dart';
import '../../helpers.dart';

const _genesis3_22 = BookVerse('Genesis', VerseRef(3, 22));
const _genesis1_1 = BookVerse('Genesis', VerseRef(1, 1));

/// A note on Genesis 1:1, Genesis 3:22 bookmarked with a note, Genesis 12:1
/// and Exodus 3:14 bookmarked, and a bookmark on Genesis 2:3 taken away.
final _stored = jsonEncode({
  'Exodus 3:14': {'b': true, 'n': null, 'u': 1},
  'Genesis 12:1': {'b': true, 'n': null, 'u': 2},
  'Genesis 3:22': {'b': true, 'n': 'Why “like one of us”?', 'u': 3},
  'Genesis 1:1': {'b': false, 'n': 'In the beginning', 'u': 4},
  'Genesis 2:3': {'b': false, 'n': null, 'u': 5},
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Friday of Bereshit 5787, whose Revi'i begins at Genesis 3:22.
  final friday = DateTime(2026, 10, 9, 11);

  /// Waits for a page to settle, its texts loading on real I/O.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 30 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<ProviderContainer> open(
    WidgetTester tester,
    String route, {
    bool marked = true,
    String? annotations,
    AppSettings settings = const AppSettings(onboardingComplete: true),
    double textScale = 1,
    Size size = const Size(412, 915),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final c = await pumpApp(
      tester,
      settings: settings,
      now: friday,
      stored: {if (marked) AnnotationsController.storageKey: annotations ?? _stored},
    );
    c.read(routerProvider).go(route);
    await settle(tester);
    return c;
  }

  /// The page on top, which a page pushed over another is.
  String location(ProviderContainer c) =>
      c.read(routerProvider).routerDelegate.currentConfiguration.last.matchedLocation;
  Finder inSheet(Finder finder) => find.descendant(of: find.byType(BottomSheet), matching: finder);
  Finder inDialog(Finder finder) => find.descendant(of: find.byType(NoteDialog), matching: finder);

  group('in the reader', () {
    testWidgets('a verse is bookmarked from its options, and its number marks it', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await open(tester, '/read/5787:1/3', marked: false);
      expect(find.byType(VerseMarks), findsNothing);
      await tester.longPress(find.byType(ScriptureVerse).first);
      await tester.pumpAndSettle();
      expect(inSheet(find.text('Bookmark')), findsOneWidget);
      expect(tester.widget<Switch>(inSheet(find.byType(Switch))).value, isFalse);

      await tester.tap(inSheet(find.text('Bookmark')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget, reason: 'the sheet stays, its switch showing the change');
      expect(tester.widget<Switch>(inSheet(find.byType(Switch))).value, isTrue);
      expect(c.read(annotationsProvider)[_genesis3_22]!.bookmarked, isTrue);
      final stored = c.read(sharedPreferencesProvider).getString(AnnotationsController.storageKey)!;
      expect(Annotations.fromJson(jsonDecode(stored))[_genesis3_22]!.bookmarked, isTrue, reason: 'saved at once');

      Navigator.pop(tester.element(find.byType(BottomSheet)));
      await tester.pumpAndSettle();
      final marks = tester.widget<VerseMarks>(find.byType(VerseMarks));
      expect((marks.bookmarked, marks.hasNote), (true, false));
      expect(tester.getSemantics(find.byType(ScriptureVerse).first).label, endsWith('. Bookmarked'));

      // Taken away, it leaves a tombstone, and no mark.
      await tester.longPress(find.byType(ScriptureVerse).first);
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.byType(Switch)));
      await tester.pumpAndSettle();
      expect(c.read(annotationsProvider)[_genesis3_22], isNull);
      expect(c.read(annotationsProvider).entries['Genesis 3:22']!.isRemoved, isTrue);
      Navigator.pop(tester.element(find.byType(BottomSheet)));
      await tester.pumpAndSettle();
      expect(find.byType(VerseMarks), findsNothing);
      handle.dispose();
    });

    testWidgets('the bookmark reads as one switch to screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, '/read/5787:1/3', marked: false);
      await tester.longPress(find.byType(ScriptureVerse).first);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.ancestor(of: inSheet(find.text('Bookmark')), matching: find.byType(Semantics)).first),
        isSemantics(label: 'Bookmark', isButton: true, hasToggledState: true, isToggled: false, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('a note is written, saved, deleted and brought back', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await open(tester, '/read/5787:1/3', marked: false);
      await tester.longPress(find.byType(ScriptureVerse).first);
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.text('Add a note')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(inDialog(find.text('Note on Genesis 3:22')), findsOneWidget);
      final save = find.widgetWithText(FilledButton, 'Save');
      expect(tester.widget<FilledButton>(save).onPressed, isNull, reason: 'nothing written yet');
      expect(inDialog(find.text('Delete')), findsNothing, reason: 'no note to delete');
      expect(tester.widget<EditableText>(inDialog(find.byType(EditableText))).focusNode.hasFocus, isTrue);

      await tester.enterText(inDialog(find.byType(TextField)), 'A question for the table');
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Note saved'), findsOneWidget);
      expect(c.read(annotationsProvider)[_genesis3_22]!.note, 'A question for the table');
      expect(tester.widget<VerseMarks>(find.byType(VerseMarks)).hasNote, isTrue);
      expect(tester.getSemantics(find.byType(ScriptureVerse).first).label, endsWith('. With your note'));

      // The sheet shows it, and opens it again.
      await tester.longPress(find.byType(ScriptureVerse).first);
      await tester.pumpAndSettle();
      expect(inSheet(find.text('Your note')), findsOneWidget);
      expect(inSheet(find.textContaining('A question for the table')), findsOneWidget);
      await tester.tap(inSheet(find.text('Your note')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(inDialog(find.byType(TextField))).controller!.text, 'A question for the table');
      // Delete is in error's ink, and asks nothing more: Undo brings it back.
      final delete = inDialog(find.text('Delete'));
      expect(tester.renderObject<RenderParagraph>(delete).text.style?.color, Theme.of(tester.element(delete)).colorScheme.error);
      await tester.tap(delete);
      await tester.pumpAndSettle();
      expect(find.text('Note deleted'), findsOneWidget);
      expect(c.read(annotationsProvider)[_genesis3_22], isNull);
      expect(find.byType(VerseMarks), findsNothing);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(c.read(annotationsProvider)[_genesis3_22]!.note, 'A question for the table');
      handle.dispose();
    });

    testWidgets('Ctrl+Enter saves the note, and Enter alone does not', (tester) async {
      final c = await open(tester, '/read/5787:1/3', marked: false);
      await tester.longPress(find.byType(ScriptureVerse).first);
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.text('Add a note')));
      await tester.pumpAndSettle();
      await tester.enterText(inDialog(find.byType(TextField)), 'A question for the table');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(NoteDialog), findsOneWidget, reason: 'Enter is a new line in a note');
      expect(c.read(annotationsProvider)[_genesis3_22], isNull);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byType(NoteDialog), findsNothing);
      expect(find.text('Note saved'), findsOneWidget);
      expect(c.read(annotationsProvider)[_genesis3_22]!.note, 'A question for the table');
    });

    testWidgets('a note emptied is deleted; one unchanged waits for a change', (tester) async {
      final c = await open(tester, '/read/5787:1/3');
      await tester.longPress(find.byType(ScriptureVerse).first);
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.text('Your note')));
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Save');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tester.enterText(inDialog(find.byType(TextField)), '  ');
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Note deleted'), findsOneWidget);
      expect(c.read(annotationsProvider)[_genesis3_22]!.note, isNull);
      expect(c.read(annotationsProvider)[_genesis3_22]!.bookmarked, isTrue, reason: 'the bookmark stays');
    });

    testWidgets('the full text marks its verses too, and not their Targum', (tester) async {
      await open(tester, '/read/5787:1/3?mode=full');
      final marks = tester.widgetList<VerseMarks>(find.byType(VerseMarks)).toList();
      expect(marks, isNotEmpty);
      expect((marks.first.bookmarked, marks.first.hasNote), (true, true));
      final targum = tester.widget<ScriptureVerse>(find.byType(ScriptureVerse).at(1));
      expect(targum.kind, ScriptureKind.targum);
      expect(find.descendant(of: find.byWidget(targum), matching: find.byType(VerseMarks)), findsNothing);
    });

    for (final scale in [1.0, 1.3, 2.0]) {
      for (final full in [false, true]) {
        testWidgets('the marks keep to the number\'s size at ${(scale * 100).round()}% text, '
            '${full ? 'in the full text' : 'at the inner edge of the guided reader\'s margin'}', (tester) async {
          await open(tester, '/read/5787:1/3${full ? '?mode=full' : ''}', textScale: scale, size: const Size(412, 1400));
          final marks = find.byType(VerseMarks).first;
          final context = tester.element(marks);
          final styles = ScriptureStyles(context, const AppSettings(onboardingComplete: true));
          final number = MediaQuery.textScalerOf(context).scale(styles.numberStyle(ScriptureKind.mikra).fontSize!);
          // The ribbon stands 0.72 of the number's size, scaled once with it.
          expect(tester.getRect(marks).height, closeTo(0.72 * number, 0.5));
          if (!full) {
            // In the margin, after the number or beneath it, at its inner
            // edge: as far from the verse as the number stands.
            final gutter = tester.getRect(find.ancestor(of: marks, matching: find.byType(SizedBox)).first);
            final gap = MediaQuery.textScalerOf(context).scale(
              ScriptureStyles.numberGap * styles.sizeFor(ScriptureKind.mikra),
            );
            expect(tester.getRect(marks).left - gutter.left, closeTo(gap, 0.5));
          }
        });
      }
    }

    testWidgets('a verse of the haftarah has no bookmark or note', (tester) async {
      await open(tester, '/haftarah/5787:1');
      await tester.longPress(find.byType(ScriptureVerse).first);
      await tester.pumpAndSettle();
      expect(inSheet(find.text('I Samuel 20:18')), findsOneWidget);
      expect(inSheet(find.text('Bookmark')), findsNothing);
      expect(inSheet(find.text('Add a note')), findsNothing);
      expect(inSheet(find.text('Copy')), findsOneWidget);
    });
  });

  group('the list', () {
    testWidgets('lists the verses by book and chapter in the Torah\'s order', (tester) async {
      tester.view.physicalSize = const Size(412, 3000);
      await open(tester, '/notes');
      expect(find.text('Bookmarks & notes'), findsOneWidget);
      final rows = ['Genesis 1:1', 'Genesis 3:22', 'Genesis 12:1', 'Exodus 3:14'];
      final tops = [for (final r in rows) tester.getTopLeft(find.text(r)).dy];
      expect(tops, orderedEquals([...tops]..sort()));
      expect(find.text('Genesis 2:3'), findsNothing, reason: 'its bookmark was taken away');
      expect(find.text('Chapter 1'), findsOneWidget);
      expect(find.text('Chapter 3'), findsNWidgets(2), reason: "Genesis 3's, and Exodus 3's");
      expect(find.text('Chapter 12'), findsOneWidget);
      // Each book under its own heading.
      expect(find.bySemanticsLabel('Genesis'), findsOneWidget);
      expect(find.bySemanticsLabel('Exodus'), findsOneWidget);
      expect(find.text('In the beginning'), findsOneWidget);
      expect(find.text('Why “like one of us”?'), findsOneWidget);
    });

    testWidgets('a row opens the reader\'s full text at its verse', (tester) async {
      final c = await open(tester, '/notes');
      await tester.tap(find.text('Genesis 3:22'));
      await settle(tester);
      expect(location(c), '/read/5787:1/3');
      final reader = tester.widget<ReaderScreen>(find.byType(ReaderScreen));
      expect((reader.fullText, reader.targetVerse), (true, const VerseRef(3, 22)));
    });

    testWidgets('a row reads as one item, with the verse\'s options among its actions', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, '/notes');
      final node = tester.getSemantics(find.bySemanticsLabel(RegExp(r'^Genesis 3:22\. ')));
      expect(node.label, startsWith('Genesis 3:22. Bookmarked. '));
      expect(node.label, endsWith('. Your note: Why “like one of us”?'));
      const options = CustomSemanticsAction(label: 'Verse options');
      expect(node, isSemantics(isButton: true, hasTapAction: true, hasLongPressAction: true, customActions: [options]));
      handle.dispose();
    });

    testWidgets('its menu opens the verse\'s options, where the bookmark is taken away', (tester) async {
      final c = await open(tester, '/notes');
      await tester.tap(find.byTooltip('Verse options').at(1));
      await tester.pumpAndSettle();
      expect(inSheet(find.text('Genesis 3:22')), findsOneWidget);
      await tester.tap(inSheet(find.byType(Switch)));
      await tester.pumpAndSettle();
      Navigator.pop(tester.element(find.byType(BottomSheet)));
      await tester.pumpAndSettle();
      expect(c.read(annotationsProvider)[_genesis3_22]!.bookmarked, isFalse);
      expect(find.text('Genesis 3:22'), findsOneWidget, reason: 'its note keeps it on the list');

      // A long press opens them too.
      await tester.longPress(find.text('Genesis 1:1'));
      await tester.pumpAndSettle();
      expect(inSheet(find.text('Genesis 1:1')), findsOneWidget);
    });

    testWidgets('a bookmark taken away in the sheet leaves its options whole: the note, a copy, a question',
        (tester) async {
      tester.view.physicalSize = const Size(412, 3000);
      final c = await open(tester, '/notes', size: const Size(412, 3000));
      expect(OwnContextMenu.browserMenuAway, isTrue, reason: 'a right-click on a row opens its options');
      Finder menuOf(String reference) => find.descendant(
            of: find.ancestor(of: find.text(reference), matching: find.byType(CallbackShortcuts)).first,
            matching: find.byTooltip('Verse options'),
          );

      // Genesis 12:1, a bookmark alone, the only verse of its chapter: its
      // row goes as the bookmark does, and the sheet stays.
      await tester.tap(menuOf('Genesis 12:1'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.byType(Switch)));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.descendant(of: find.byType(NotesScreen), matching: find.text('Genesis 12:1')), findsNothing);
      await tester.tap(inSheet(find.text('Add a note')));
      await tester.pumpAndSettle();
      expect(inDialog(find.text('Note on Genesis 12:1')), findsOneWidget);
      await tester.enterText(inDialog(find.byType(TextField)), 'Lech lecha');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Note saved'), findsOneWidget);
      expect(c.read(annotationsProvider)[const BookVerse('Genesis', VerseRef(12, 1))]!.note, 'Lech lecha');
      expect(find.text('Genesis 12:1'), findsOneWidget, reason: 'back, with its note');

      // Exodus 3:14 likewise: copied, the page says so; asked about, the
      // question opens.
      await tester.tap(menuOf('Exodus 3:14'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.byType(Switch)));
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.text('Copy')));
      await tester.pumpAndSettle();
      expect(find.text('Verse copied'), findsOneWidget);
      c.read(annotationsProvider.notifier).setBookmark(const BookVerse('Exodus', VerseRef(3, 14)), true);
      await tester.pumpAndSettle();
      await tester.tap(menuOf('Exodus 3:14'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.byType(Switch)));
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.text('Ask about this verse')));
      await tester.pumpAndSettle();
      expect(find.byType(ComposeScreen), findsOneWidget);
    });

    testWidgets('Shift+F10 on a row with the keyboard focus opens its options', (tester) async {
      await open(tester, '/notes');
      final row = find.ancestor(of: find.text('Genesis 3:22'), matching: find.byType(CallbackShortcuts)).first;
      bool focusedInRow() {
        final focused = FocusManager.instance.primaryFocus?.context;
        if (focused == null) return false;
        var inside = false;
        focused.visitAncestorElements((e) => !(inside = e == tester.element(row)));
        return inside;
      }

      for (var i = 0; i < 20 && !focusedInRow(); i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
      }
      expect(focusedInRow(), isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pumpAndSettle();
      expect(inSheet(find.text('Genesis 3:22')), findsOneWidget);
    });

    for (final hebrew in [false, true]) {
      testWidgets('a note in the other language is read in its own${hebrew ? ', in the Hebrew UI' : ''}', (tester) async {
        final handle = tester.ensureSemantics();
        const other = 'למה דווקא לך לך?';
        const english = 'Why “like one of us”?';
        await open(
          tester,
          '/notes',
          settings: AppSettings(onboardingComplete: true, language: hebrew ? AppLanguage.hebrew : AppLanguage.system),
          annotations: jsonEncode({
            'Genesis 3:22': {'b': false, 'n': hebrew ? english : other, 'u': 3},
          }),
        );
        final note = hebrew ? english : other;
        final locale = Locale(hebrew ? 'en' : 'he');
        bool tagged(AttributedString label) {
          final start = label.string.indexOf(note);
          return start >= 0 &&
              label.attributes.any((a) =>
                  a is LocaleStringAttribute &&
                  a.locale == locale &&
                  a.range.start <= start &&
                  a.range.end >= start + note.length);
        }

        final row = tester.getSemantics(find.bySemanticsLabel(RegExp(hebrew ? '^בראשית ג,\u00A0כב\\. ' : r'^Genesis 3:22\. ')));
        expect(tagged(row.attributedLabel), isTrue, reason: row.attributedLabel.toString());

        // And under Your note in the verse's options.
        await tester.tap(find.byTooltip(hebrew ? 'אפשרויות לפסוק' : 'Verse options').first);
        await tester.pumpAndSettle();
        final yourNote = tester.getSemantics(
          find.ancestor(of: inSheet(find.text(hebrew ? 'ההערה שלך' : 'Your note')), matching: find.byType(Semantics)).first,
        );
        expect(tagged(yourNote.attributedLabel), isTrue, reason: yourNote.attributedLabel.toString());
        handle.dispose();
      });
    }

    testWidgets('of one parsha, lists its verses alone, which open in its week', (tester) async {
      final c = await open(tester, '/notes?week=5787:1');
      expect(find.text('Genesis 1:1'), findsOneWidget);
      expect(find.text('Genesis 3:22'), findsOneWidget);
      expect(find.text('Genesis 12:1'), findsNothing);
      expect(find.text('Exodus 3:14'), findsNothing);
      expect(find.bySemanticsLabel('Parshat Bereshit'), findsOneWidget);

      // In its week, where the reader opens.
      await tester.tap(find.text('Genesis 1:1'));
      await settle(tester);
      expect(location(c), '/read/5787:1/0');
      Navigator.pop(tester.element(find.byType(ReaderScreen)));
      await tester.pumpAndSettle();

      final all = find.text('All bookmarks & notes');
      await tester.scrollUntilVisible(all, 200, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(all);
      await tester.pumpAndSettle();
      await tester.tap(all);
      await settle(tester);
      expect(tester.widget<NotesScreen>(find.byType(NotesScreen)).weekId, isNull);
      await tester.scrollUntilVisible(find.text('Exodus 3:14'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Exodus 3:14'), findsOneWidget);
    });

    testWidgets('says how to begin while there is nothing on it', (tester) async {
      await open(tester, '/notes', marked: false);
      expect(
        find.text('To bookmark a verse or keep a question for the Shabbat table, press and hold the verse as you read.'),
        findsOneWidget,
      );
    });

    testWidgets('in the Hebrew UI, names each verse and chapter in Hebrew', (tester) async {
      await open(tester, '/notes', settings: const AppSettings(onboardingComplete: true, language: AppLanguage.hebrew));
      expect(find.text('סימניות והערות'), findsOneWidget);
      expect(find.text('בראשית ג,\u00A0כב'), findsOneWidget);
      expect(find.text('פרק ג'), findsNWidgets(2));
    });
  });

  group('accessibility', () {
    setUpAll(loadBundledFonts);

    for (final hebrew in [false, true]) {
      final settings = AppSettings(onboardingComplete: true, language: hebrew ? AppLanguage.hebrew : AppLanguage.system);
      testWidgets('the list and a verse\'s options meet the guidelines${hebrew ? ', in Hebrew' : ''}', (tester) async {
        final handle = tester.ensureSemantics();
        await open(tester, '/notes', settings: settings);
        Future<void> check() async {
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        }

        await check();
        await tester.tap(find.byTooltip(hebrew ? 'אפשרויות לפסוק' : 'Verse options').first);
        await tester.pumpAndSettle();
        await check();
        handle.dispose();
      });

      testWidgets('nothing overflows at 200% text size${hebrew ? ', in Hebrew' : ''}', (tester) async {
        // Tall, as the capture harness's large-text phone is.
        const tall = Size(412, 2600);
        await open(tester, '/notes', settings: settings, textScale: 2, size: tall);
        expect(tester.takeException(), isNull);
        await open(tester, '/read/5787:1/3', settings: settings, textScale: 2, size: tall);
        await tester.longPress(find.byType(ScriptureVerse).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(inSheet(find.text(hebrew ? 'ההערה שלך' : 'Your note')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('the way there', () {
    testWidgets('a week\'s page counts its parsha\'s notes and bookmarks, and opens them', (tester) async {
      final c = await open(tester, '/week/5787:1');
      final row = find.text('Your notes on this parsha');
      await tester.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      expect(find.text('2 notes · 1 bookmark'), findsOneWidget);
      await tester.tap(row);
      await settle(tester);
      expect(location(c), '/notes');
      expect(tester.widget<NotesScreen>(find.byType(NotesScreen)).weekId, '5787:1');
    });

    testWidgets('a week with none shows no row', (tester) async {
      await open(tester, '/week/5787:2');
      await tester.scrollUntilVisible(find.text('Discuss this week’s parsha'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Your notes on this parsha'), findsNothing);
    });

    testWidgets('the Parsha tab\'s menu opens them all', (tester) async {
      await open(tester, '/parsha');
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bookmarks & notes'));
      await settle(tester);
      expect(tester.widget<NotesScreen>(find.byType(NotesScreen)).weekId, isNull);
    });
  });

  testWidgets('a backup exported holds them, and imported restores them, even replacing the progress', (tester) async {
    var c = await open(tester, '/settings/data');
    WidgetRef ref() => tester.element(find.byType(DataSettingsScreen)) as WidgetRef;
    final file = exportBackup(ref());
    expect(parseBackup(file)!.annotations, c.read(annotationsProvider));

    // Since the backup was made, Genesis 1:1's note was deleted here, and
    // Genesis 3:22's bookmark taken away and its note rewritten.
    final here = jsonEncode({
      'Genesis 1:1': {'b': false, 'n': null, 'u': 10},
      'Genesis 3:22': {'b': false, 'n': 'Rewritten', 'u': 11},
    });
    tester.view.physicalSize = const Size(412, 915);
    c = await pumpApp(tester, now: friday, stored: {AnnotationsController.storageKey: here});
    c.read(routerProvider).go('/settings/data');
    await tester.pumpAndSettle();
    expect(await importBackup(ref(), parseBackup(file)!, replace: true), BackupImport.restored);
    final restored = c.read(annotationsProvider);
    expect(restored[_genesis1_1]?.note, 'In the beginning', reason: 'deleted here since, and brought back');
    expect(restored[_genesis3_22]!.note, 'Rewritten', reason: 'changed here since');
    expect(restored[_genesis3_22]!.bookmarked, isTrue, reason: 'taken away here since, and brought back');
    expect(restored[const BookVerse('Exodus', VerseRef(3, 14))]!.bookmarked, isTrue, reason: 'restored from the backup');
  });

  testWidgets('a backup merged in restores them too, verse by verse', (tester) async {
    var c = await open(tester, '/settings/data');
    WidgetRef ref() => tester.element(find.byType(DataSettingsScreen)) as WidgetRef;
    final file = exportBackup(ref());
    final here = jsonEncode({
      'Genesis 1:1': {'b': false, 'n': null, 'u': 10},
      'Genesis 2:3': {'b': true, 'n': null, 'u': 2},
      'Leviticus 19:18': {'b': true, 'n': 'Love your neighbour', 'u': 12},
    });
    c = await pumpApp(tester, now: friday, stored: {AnnotationsController.storageKey: here});
    c.read(routerProvider).go('/settings/data');
    await tester.pumpAndSettle();
    expect(await importBackup(ref(), parseBackup(file)!), BackupImport.restored);
    final merged = c.read(annotationsProvider);
    expect(merged[_genesis1_1]?.note, 'In the beginning', reason: 'deleted here since, and brought back');
    expect(merged[_genesis3_22]!.note, 'Why “like one of us”?', reason: 'from the backup');
    expect(merged[const BookVerse('Genesis', VerseRef(2, 3))], isNull, reason: 'taken away in the backup, later');
    expect(merged[const BookVerse('Leviticus', VerseRef(19, 18))]!.note, 'Love your neighbour', reason: 'kept from here');
  });

  testWidgets('a note deleted after a backup was exported is listed again once it is imported', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final file = encodeBackup(
      const ProgressState(),
      const AppSettings(onboardingComplete: true),
      annotations: Annotations.fromJson(jsonDecode(_stored)),
      now: DateTime(2026, 10, 8),
    );
    final c = await pumpApp(
      tester,
      now: friday,
      // Rishon read here, so that the backup is merged in.
      progress: ProgressState(weeks: {'5787:1': WeekProgress(weekId: '5787:1').withAliyah(0, LocalDate(2026, 10, 9))}),
      stored: {AnnotationsController.storageKey: _stored},
      overrides: [backupFilesProvider.overrideWithValue(FakeBackupFiles(file: file))],
    );
    c.read(annotationsProvider.notifier).setNote(_genesis1_1, null);
    c.read(routerProvider).go('/notes');
    await settle(tester);
    expect(find.text('In the beginning'), findsNothing);

    c.read(routerProvider).go('/settings/data');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import progress'));
    await tester.pumpAndSettle();
    expect(find.text('Merge this backup with the progress on this device? Merging keeps everything from both.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Merge'));
    await tester.pumpAndSettle();
    expect(find.text('Progress imported.'), findsOneWidget);

    c.read(routerProvider).go('/notes');
    await settle(tester);
    expect(find.text('In the beginning'), findsOneWidget);
  });

  for (final everywhere in [false, true]) {
    testWidgets('resetting the progress${everywhere ? ' everywhere' : ''} leaves them alone', (tester) async {
      final c = await open(tester, '/settings/data');
      final before = c.read(annotationsProvider);
      expect(before.inTorah, isNotEmpty);
      c.read(progressProvider.notifier).resetAll(c.read(todayProvider), everywhere: everywhere);
      await tester.pumpAndSettle();
      expect(c.read(annotationsProvider), before);
      expect(
        c.read(sharedPreferencesProvider).getString(AnnotationsController.storageKey),
        isNotNull,
        reason: 'still stored',
      );
    });
  }
}
