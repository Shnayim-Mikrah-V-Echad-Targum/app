import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/app/providers.dart';
import 'package:shnayim_mikrah/app/router.dart';
import 'package:shnayim_mikrah/core/text/hebrew_text.dart';
import 'package:shnayim_mikrah/data/models/verse_ref.dart';
import 'package:shnayim_mikrah/features/reader/aliyah_ribbon.dart';
import 'package:shnayim_mikrah/features/reader/scripture_text.dart';
import 'package:shnayim_mikrah/features/reader/verse_anchor.dart';
import 'package:shnayim_mikrah/features/reader/whole_parsha.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/features/settings/widgets/settings_widgets.dart';
import 'package:shnayim_mikrah/services/tts.dart';
import 'package:shnayim_mikrah/ui/theme/focus.dart';

import '../../helpers.dart';

/// Speech that holds each utterance until the next is asked for, so that
/// Listen stays on the verse it has reached.
class _HeldTts extends RecordingTts {
  @override
  Future<bool> speak(String text, {required String language, double rate = kDefaultSpeechRate}) {
    spoken.add((text, language));
    return Completer<bool>().future;
  }

  /// The last thing asked for, as letters alone.
  String get last => HebrewText.consonantsOnly(spoken.last.$1);
}

void main() {
  final monday = DateTime(2026, 10, 12, 10); // the week of Noach, 5787
  const wide = Size(1366, 860);
  const phone = Size(412, 915);

  Future<void> loadTexts(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<ProviderContainer> open(
    WidgetTester tester,
    String path, {
    AppSettings settings = const AppSettings(onboardingComplete: true, notificationPromptShown: true),
    Size size = wide,
    double textScale = 1,
    TtsService? tts,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final c = await pumpApp(
      tester,
      settings: settings,
      now: monday,
      overrides: [if (tts != null) ttsProvider.overrideWithValue(tts)],
    );
    c.read(routerProvider).go(path);
    await loadTexts(tester);
    return c;
  }

  // The app bar's title names the aliyah shown.
  Finder titled(String aliyah) => find.descendant(
        of: find.byType(AppBar),
        matching: find.textContaining(RegExp('^${RegExp.escape(aliyah)}(\$| · )')),
      );

  Finder verses(ScriptureKind kind) => find.byWidgetPredicate((w) => w is ScriptureVerse && w.kind == kind);

  // The baseline of the first line of [verse], on the screen.
  double firstBaseline(WidgetTester tester, Finder verse) {
    final paragraph = tester.renderObject<RenderParagraph>(find.descendant(of: verse, matching: find.byType(RichText)).first);
    return paragraph.localToGlobal(Offset(0, paragraph.computeDistanceToActualBaseline(TextBaseline.alphabetic))).dy;
  }

  Finder heading(int aliyah) => find.byWidgetPredicate((w) => w is AliyahHeader && w.aliyah == aliyah, skipOffstage: false);

  Finder tab(String name) => find.ancestor(
        of: find.descendant(of: find.byType(AliyahRibbon), matching: find.text(name)),
        matching: find.byType(SeferInkWell),
      );

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
  }

  group('on a wide screen, the full text', () {
    testWidgets('sets the Targum beside each verse, their first lines on one baseline', (tester) async {
      await open(tester, '/read/5787:2/0?mode=full');
      final rows = find.byType(ParallelVerse);
      expect(rows, findsWidgets);
      // Beside the verse, neither ruled off nor numbered again.
      final targum = tester.widgetList<ScriptureVerse>(verses(ScriptureKind.targum));
      expect(targum, isNotEmpty);
      expect(targum.every((v) => !v.ruled && !v.showNumber), isTrue);

      final first = rows.first;
      final mikrah = find.descendant(of: first, matching: verses(ScriptureKind.mikrah));
      final beside = find.descendant(of: first, matching: verses(ScriptureKind.targum));
      final (right, left) = (tester.getRect(mikrah), tester.getRect(beside));
      // The Torah on the right, as it begins, in the wider column.
      expect(left.right, lessThan(right.left));
      expect(right.left - left.right, closeTo(ParallelVerse.gutter, 0.5));
      expect(right.width / left.width, closeTo(6 / 5, 0.01));
      expect(firstBaseline(tester, beside), closeTo(firstBaseline(tester, mikrah), 0.5));

      // Headed by the columns' names, each over its own.
      final heads = find.byType(ParallelHeading);
      expect(heads, findsOneWidget);
      expect(tester.getRect(heads).bottom, lessThan(right.top));
      expect(find.bySemanticsLabel('Mikrah, Targum Onkelos'), findsOneWidget);

      // The text keeps to its wider measure, centred, and the title and the
      // ribbon to it.
      final column = tester.getRect(find.byType(VerseGroup).first);
      expect(column.width, ScriptureStyles.parallelWidth);
      expect(column.center.dx, closeTo(wide.width / 2, 0.5));
      final ribbon = tester.getRect(find.byType(AliyahRibbon));
      expect(tester.getRect(tab('Rishon')).left, greaterThanOrEqualTo(column.left));
      expect(tester.getRect(tab('Shevi’i')).right, lessThanOrEqualTo(column.right + 0.01));
      expect(ribbon.width, wide.width, reason: 'its rule runs the width of the window');
      expect(tester.getTopLeft(titled('Rishon')).dx, closeTo(column.left, 0.5));
    });

    for (final translation in [false, true]) {
      testWidgets(
          'in the Hebrew interface, keeps the Torah at the right and ${translation ? 'the translation' : 'the Targum'} '
          'at the left, each under its own name', (tester) async {
        await open(
          tester,
          '/read/5787:2/0?mode=full',
          settings: AppSettings(
            onboardingComplete: true,
            language: AppLanguage.hebrew,
            showTranslation: translation,
            secondReading: translation ? SecondReading.rashi : SecondReading.onkelos,
          ),
        );
        final first = find.byType(ParallelVerse).first;
        final mikrah = tester.getRect(find.descendant(of: first, matching: verses(ScriptureKind.mikrah)));
        final beside = tester.getRect(
          find.descendant(of: first, matching: translation ? find.byType(TranslationVerse) : verses(ScriptureKind.targum)),
        );
        expect(beside.right, lessThan(mikrah.left));
        expect(mikrah.left - beside.right, closeTo(ParallelVerse.gutter, 0.5));
        expect(firstBaseline(tester, find.descendant(of: first, matching: verses(ScriptureKind.mikrah))),
            closeTo(firstBaseline(tester, find.descendant(of: first, matching: translation ? find.byType(TranslationVerse) : verses(ScriptureKind.targum))), 0.5));

        // Each name over its column, set from the edge its text begins at.
        final heading = tester.widget<ParallelHeading>(find.byType(ParallelHeading));
        final torahHead = find.descendant(of: find.byType(ParallelHeading), matching: find.text(heading.torah));
        final besideHead = find.descendant(of: find.byType(ParallelHeading), matching: find.text(heading.beside));
        expect(tester.getRect(torahHead).left, closeTo(mikrah.left, 0.5));
        expect(tester.getRect(torahHead).right, closeTo(mikrah.right, 0.5));
        expect(tester.getRect(besideHead).left, closeTo(beside.left, 0.5));
        expect(tester.getRect(besideHead).right, closeTo(beside.right, 0.5));
        expect(tester.widget<Text>(torahHead).textAlign, TextAlign.right);
        expect(tester.widget<Text>(besideHead).textAlign, translation ? TextAlign.left : TextAlign.right);
      });
    }

    // On the verse and its Targum, which are heard on their own: the row
    // has no node of its own, which would have nothing to say.
    testWidgets("in focus mode, a screen reader's tap on a verse or its Targum focuses the verse", (tester) async {
      final handle = tester.ensureSemantics();
      await open(
        tester,
        '/read/5787:2/0?mode=full',
        settings: const AppSettings(onboardingComplete: true, focusMode: true),
      );
      final rows = find.byType(VerseGroup);
      expect(find.byType(ParallelVerse), findsWidgets);
      expect(tester.widget<VerseGroup>(rows.at(0)).highlighted, isTrue);

      tester.semantics.tap(find.semantics.byLabel(RegExp(r'^Verse 10\. ')));
      await tester.pumpAndSettle();
      expect(tester.widget<VerseGroup>(rows.at(0)).highlighted, isFalse);
      expect(tester.widget<VerseGroup>(rows.at(1)).highlighted, isTrue);

      tester.semantics.tap(find.semantics.byLabel(RegExp(r'^Targum, verse 11\. ')));
      await tester.pumpAndSettle();
      expect(tester.widget<VerseGroup>(rows.at(1)).highlighted, isFalse);
      expect(tester.widget<VerseGroup>(rows.at(2)).highlighted, isTrue);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    for (final hebrew in [false, true]) {
      testWidgets('is heard verse before Targum${hebrew ? ', in the Hebrew interface' : ''}', (tester) async {
        final handle = tester.ensureSemantics();
        await open(
          tester,
          '/read/5787:2/0?mode=full',
          settings: AppSettings(
            onboardingComplete: true,
            showTranslation: true,
            language: hebrew ? AppLanguage.hebrew : AppLanguage.system,
          ),
        );
        final first = find.byType(ParallelVerse).first;
        SemanticsNode node(Finder f) => tester.getSemantics(find.descendant(of: first, matching: f).first);
        final order = tester.semantics.simulatedAccessibilityTraversal().toList();
        final mikrah = order.indexOf(node(verses(ScriptureKind.mikrah)));
        final targum = order.indexOf(node(verses(ScriptureKind.targum)));
        final translation = order.indexWhere((n) => n.label.contains('These are the generations of Noah'));
        expect(mikrah, isNonNegative);
        expect(targum, greaterThan(mikrah));
        expect(translation, greaterThan(targum), reason: 'as beneath each other: the verse, its Targum, its translation');
        handle.dispose();
      });
    }

    testWidgets('sets the translation beside the verse where the Targum is not read', (tester) async {
      await open(
        tester,
        '/read/5787:2/0?mode=full',
        settings: const AppSettings(
          onboardingComplete: true,
          secondReading: SecondReading.rashi,
          showTranslation: true,
        ),
      );
      final row = tester.widget<ParallelVerse>(find.byType(ParallelVerse).first);
      expect(row.beside, isA<TranslationVerse>());
      expect(tester.widget<ParallelHeading>(find.byType(ParallelHeading)).beside, 'Translation (JPS 1917)');
      expect(tester.widget<ParallelHeading>(find.byType(ParallelHeading)).besideDirection, TextDirection.ltr);
    });

    for (final (name, size, settings, textScale) in [
      ('a window under 960 wide', const Size(940, 860), const AppSettings(onboardingComplete: true), 1.0),
      ('the narrow measure', wide, const AppSettings(onboardingComplete: true, lineWidth: LineWidth.narrow), 1.0),
      ('the columns turned off', wide, const AppSettings(onboardingComplete: true, parallelColumns: false), 1.0),
      ('a reading size too large', wide, const AppSettings(onboardingComplete: true, readingScale: 1.4), 1.0),
      ('system text too large', wide, const AppSettings(onboardingComplete: true), 1.4),
      (
        'nothing to set beside the verse',
        wide,
        const AppSettings(onboardingComplete: true, secondReading: SecondReading.rashi),
        1.0,
      ),
    ]) {
      testWidgets('keeps one column with $name', (tester) async {
        await open(tester, '/read/5787:2/0?mode=full', settings: settings, size: size, textScale: textScale);
        expect(find.byType(ParallelVerse), findsNothing);
        expect(find.byType(ParallelHeading), findsNothing);
        expect(find.byType(VerseGroup), findsWidgets);
      });
    }

    testWidgets('in focus mode, a tap moves the highlight from row to row, and no line of the text', (tester) async {
      await open(
        tester,
        '/read/5787:2/0?mode=full',
        settings: const AppSettings(onboardingComplete: true, focusMode: true, showTranslation: true, readingScale: 0.8),
      );
      List<(Rect, double)> layout() => [
            for (final p in tester.renderObjectList<RenderParagraph>(
              find.descendant(of: find.byType(VerseGroup), matching: find.byType(RichText)),
            ))
              (p.localToGlobal(Offset.zero) & p.size, p.getMaxIntrinsicWidth(double.infinity)),
          ];
      final before = layout();
      final rows = find.byType(VerseGroup);
      bool highlighted(int i) => tester.widget<VerseGroup>(rows.at(i)).highlighted;
      expect(highlighted(0), isTrue);
      // A tap on the Targum, beside the verse, is a tap on its verse.
      final targum = find.descendant(of: rows.at(1), matching: verses(ScriptureKind.targum));
      await tester.tapAt(tester.getRect(targum).topCenter + const Offset(0, 12));
      await tester.pumpAndSettle();
      expect([highlighted(0), highlighted(1)], [false, true]);
      expect(layout(), before);
      // The highlight spans the row, the rule at the Torah's edge.
      expect(tester.getRect(rows.at(1)).width, ScriptureStyles.parallelWidth);
    });

    testWidgets('the guided reader keeps its column', (tester) async {
      await open(tester, '/read/5787:2/0');
      expect(find.byType(ParallelVerse), findsNothing);
      expect(tester.getRect(find.byType(ScriptureVerse).first).width, lessThanOrEqualTo(680));
    });

    for (final (name, path, size, padding, settings) in [
      ('in the guided reader', '/read/5787:2/0', wide, EdgeInsets.zero, const AppSettings(onboardingComplete: true)),
      (
        'beside insets that leave a pane under 960',
        '/read/5787:2/0?mode=full',
        const Size(1000, 700),
        const EdgeInsets.symmetric(horizontal: 44),
        const AppSettings(onboardingComplete: true),
      ),
      (
        'at the narrow measure',
        '/read/5787:2/0?mode=full',
        wide,
        EdgeInsets.zero,
        const AppSettings(onboardingComplete: true, lineWidth: LineWidth.narrow),
      ),
      (
        'with nothing to set beside the verse',
        '/read/5787:2/0?mode=full',
        wide,
        EdgeInsets.zero,
        const AppSettings(onboardingComplete: true, secondReading: SecondReading.rashi),
      ),
    ]) {
      testWidgets('the display sheet doesn\'t offer the columns $name, where they wouldn\'t show', (tester) async {
        tester.view.padding = FakeViewPadding(left: padding.left, right: padding.right);
        await open(tester, path, settings: settings, size: size);
        expect(find.byType(ParallelVerse), findsNothing);
        await tester.tap(find.byTooltip('Display settings'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.widgetWithText(SwitchRow, 'Focus mode'), 200,
            scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)));
        expect(find.widgetWithText(SwitchRow, 'Side by side'), findsNothing);
      });
    }

    testWidgets('the display sheet turns the columns off, and offers them only on a wide screen', (tester) async {
      final c = await open(tester, '/read/5787:2/0?mode=full');
      await tester.tap(find.byTooltip('Display settings'));
      await tester.pumpAndSettle();
      final side = find.widgetWithText(SwitchRow, 'Side by side');
      await tester.scrollUntilVisible(side, 200,
          scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)));
      // Within the sheet, which opens on the lower part of the screen.
      await tester.ensureVisible(side);
      await tester.pumpAndSettle();
      await tester.tap(side);
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).parallelColumns, isFalse);
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(ParallelVerse), findsNothing);

      // A phone has no room for them, and its sheet doesn't offer them.
      tester.view.physicalSize = phone;
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Display settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.widgetWithText(SwitchRow, 'Focus mode'), 200,
          scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)));
      expect(side, findsNothing);
    });
  });

  group('the whole parsha', () {
    const whole = AppSettings(onboardingComplete: true, notificationPromptShown: true, fullTextWholeParsha: true);

    test('numbers every verse of the parsha, and knows each one\'s aliyah', () {
      const a = VerseRef(1, 1), b = VerseRef(1, 2), c = VerseRef(2, 1);
      final parsha = ParshaVerses([
        [a, b],
        [c],
        [const VerseRef(2, 2), const VerseRef(2, 3)],
      ]);
      expect(parsha.verses, [a, b, c, const VerseRef(2, 2), const VerseRef(2, 3)]);
      expect(parsha.starts, [0, 2, 3]);
      expect([for (var i = 0; i < 5; i++) parsha.aliyahOf(i)], [0, 0, 1, 2, 2]);
    });

    testWidgets('is chosen from the full text\'s menu, opens at the aliyah, and is kept', (tester) async {
      final c = await open(tester, '/read/5787:2/2', size: phone);
      await openMenu(tester);
      expect(find.text('Whole parsha'), findsNothing, reason: 'the guided reader reads one aliyah');
      await tester.tap(find.text('Full text'));
      await tester.pumpAndSettle();

      await openMenu(tester);
      await tester.tap(find.text('Whole parsha'));
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).fullTextWholeParsha, isTrue);
      expect(find.byType(AliyahHeader, skipOffstage: false), findsNWidgets(7));
      // Shlishi's heading at the top of the text, beneath the ribbon.
      expect(tester.getRect(heading(2)).top, closeTo(tester.getRect(find.byType(AliyahRibbon)).bottom, 1));
      expect(titled('Shlishi'), findsOneWidget);

      // And back to the one aliyah, at its top.
      await openMenu(tester);
      await tester.tap(find.text('One aliyah at a time'));
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).fullTextWholeParsha, isFalse);
      expect(find.byType(AliyahHeader, skipOffstage: false), findsNothing);
      expect(titled('Shlishi'), findsOneWidget);
      expect(find.text('פרק ז'), findsOneWidget, reason: 'Shlishi begins at Genesis 7:17');
    });

    testWidgets('a tab scrolls to its aliyah, and the aliyah shown follows the text', (tester) async {
      await open(tester, '/read/5787:2/0?mode=full', settings: whole);
      expect(titled('Rishon'), findsOneWidget);
      expect(tester.getRect(heading(0)).top, closeTo(tester.getRect(find.byType(AliyahRibbon)).bottom, 1));

      await tester.tap(tab('Shishi'));
      await tester.pumpAndSettle();
      expect(titled('Shishi'), findsOneWidget);
      expect(tester.getRect(heading(5)).top, closeTo(tester.getRect(find.byType(AliyahRibbon)).bottom, 1));
      expect(find.text('פרק ט'), findsOneWidget, reason: 'Shishi begins at Genesis 9:18');

      // Scrolled back by hand into Chamishi, the title and the ribbon follow.
      for (var i = 0; i < 20 && titled('Shishi').evaluate().isNotEmpty; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 200));
        await tester.pumpAndSettle();
      }
      expect(titled('Chamishi'), findsOneWidget);
      final chamishi = find.descendant(of: find.byType(AliyahRibbon), matching: find.bySemanticsLabel(RegExp('^Chamishi, aliyah 5')));
      expect(tester.getSemantics(chamishi), isSemantics(isSelected: true, hasSelectedState: true));
    });

    testWidgets('each aliyah ends with a button that marks it read, and its heading says so', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await open(tester, '/read/5787:2/0?mode=full', settings: whole);
      final rishon = tester.getSemantics(find.bySemanticsLabel('Rishon, aliyah 1 of 7, Genesis 6:9–22'));
      expect(rishon, isSemantics(isHeader: true));
      expect(rishon.getSemanticsData().headingLevel, 2);
      // Sheni's button, below Rishon's, reached by the keyboard: it is
      // brought into view, far as it is.
      final buttons = find.text('Mark this aliyah as read', skipOffstage: false);
      bool focused(int i) => Focus.of(tester.element(buttons.at(i))).hasPrimaryFocus;
      for (var i = 0; i < 40 && !focused(1); i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
      }
      expect(focused(1), isTrue);
      final button = tester.getRect(buttons.at(1));
      expect(button.top, greaterThanOrEqualTo(tester.getRect(heading(1)).bottom));
      expect(button.bottom, lessThanOrEqualTo(wide.height));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final week = c.read(progressProvider).week('5787:2');
      expect(week.isAliyahDone(1), isTrue);
      expect(week.isAliyahDone(0), isFalse);
      expect(tester.widget<AliyahHeader>(heading(1)).done, isTrue);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Sheni, aliyah 2 of 7, Genesis 7:1–16, read')),
        isSemantics(isHeader: true),
      );
      expect(buttons, findsNWidgets(6), reason: "Sheni's button is gone");
      // Its chapters are headed beneath it.
      final chapter = tester.getSemantics(find.byType(ChapterHeading).first);
      expect(chapter.getSemanticsData().headingLevel, 3);
      handle.dispose();
    });

    testWidgets('in focus mode, ↓ and ↑ go on from one aliyah into the next', (tester) async {
      await open(tester, '/read/5787:2/0?mode=full', settings: whole.copyWith(focusMode: true));
      VerseRef focused() => tester.widgetList<VerseGroup>(find.byType(VerseGroup)).singleWhere((g) => g.highlighted).verse;
      expect(focused(), const VerseRef(6, 9));
      // Rishon's fourteen verses, and on to Sheni's first.
      for (var i = 0; i < 14; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      expect(focused(), const VerseRef(7, 1));
      expect(titled('Sheni'), findsOneWidget);
      final verse = tester.getRect(find.byWidgetPredicate((w) => w is VerseGroup && w.highlighted));
      expect(verse.top, greaterThan(tester.getRect(heading(1)).bottom - 1), reason: 'in view, below the heading');
      expect(verse.bottom, lessThan(phone.height));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(focused(), const VerseRef(6, 22));
      expect(titled('Rishon'), findsOneWidget);
    });

    testWidgets('in focus mode, keeps its verse as the whole parsha is turned on and off', (tester) async {
      final c = await open(tester, '/read/5787:2/1?mode=full', settings: const AppSettings(onboardingComplete: true, focusMode: true), size: phone);
      VerseRef? focused() =>
          tester.widgetList<VerseGroup>(find.byType(VerseGroup)).where((g) => g.highlighted).singleOrNull?.verse;
      expect(focused(), const VerseRef(7, 1));
      for (var i = 0; i < 2; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      expect(focused(), const VerseRef(7, 3));

      await openMenu(tester);
      await tester.tap(find.text('Whole parsha'));
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).fullTextWholeParsha, isTrue);
      expect(focused(), const VerseRef(7, 3), reason: 'the parsha\'s numbering of the same verse');
      expect(titled('Sheni'), findsOneWidget);

      await openMenu(tester);
      await tester.tap(find.text('One aliyah at a time'));
      await tester.pumpAndSettle();
      expect(focused(), const VerseRef(7, 3));
      expect(titled('Sheni'), findsOneWidget);

      // Scrolled on into another aliyah, which the title follows, focus
      // mode's verse is none of the aliyah shown alone.
      await openMenu(tester);
      await tester.tap(find.text('Whole parsha'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 30 && titled('Sheni').evaluate().isNotEmpty; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
        await tester.pumpAndSettle();
      }
      expect(titled('Shlishi'), findsOneWidget);
      await openMenu(tester);
      await tester.tap(find.text('One aliyah at a time'));
      await tester.pumpAndSettle();
      expect(titled('Shlishi'), findsOneWidget);
      expect(focused(), isNull);
    });

    for (final finish in ['Mark this aliyah as read', 'at its end']) {
      testWidgets('in focus mode, from a guided aliyah finished ($finish), the full text keeps to it', (tester) async {
        await open(
          tester,
          '/read/5787:2/3',
          settings: whole.copyWith(focusMode: true, method: ReadingMethod.aliyahByAliyah),
          size: phone,
        );
        expect(titled('Revi’i'), findsOneWidget);
        if (finish == 'at its end') {
          for (var i = 0; i < 6 && find.text('Finish').evaluate().isEmpty; i++) {
            await tester.tap(find.text('Next'));
            await tester.pumpAndSettle();
          }
          await tester.tap(find.text('Finish'));
        } else {
          await openMenu(tester);
          await tester.tap(find.text(finish));
        }
        await tester.pumpAndSettle();

        await openMenu(tester);
        await tester.tap(find.text('Full text'));
        await tester.pumpAndSettle();
        expect(titled('Revi’i'), findsOneWidget);
        // Revi'i begins at Genesis 8:15.
        final highlighted = find.byWidgetPredicate((w) => w is VerseGroup && w.highlighted);
        expect(tester.widget<VerseGroup>(highlighted).verse, const VerseRef(8, 15));
        expect(tester.getRect(highlighted).top, greaterThan(tester.getRect(heading(3)).bottom - 1));
        expect(tester.getRect(highlighted).top, lessThan(phone.height / 2));
      });
    }

    testWidgets('Shift+F10 opens the options of the first verse below the heading held at the top', (tester) async {
      await open(tester, '/read/5787:2/0?mode=full', settings: whole, size: phone);
      // Scrolled so that a verse begins just above the heading's foot.
      final text = find.byType(CustomScrollView);
      final verse = find.byWidgetPredicate((w) => w is VerseGroup && w.verse == const VerseRef(6, 12));
      await tester.dragUntilVisible(verse, text, const Offset(0, -100));
      await tester.pumpAndSettle();
      final top = tester.getRect(heading(0)).bottom;
      await tester.drag(text, Offset(0, -(tester.getRect(verse).top - top + 60)));
      await tester.pumpAndSettle();
      expect(tester.getRect(verse).top, lessThan(tester.getRect(heading(0)).bottom), reason: 'begun beneath the heading');
      expect(tester.getRect(verse).bottom, greaterThan(tester.getRect(heading(0)).bottom));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Genesis 6:13')), findsOneWidget);
    });

    testWidgets('opens at the verse it was opened at, marked, far into the parsha', (tester) async {
      await open(tester, '/read/5787:2/5?verse=10:20', settings: whole, size: phone);
      final mark = find.byWidgetPredicate((w) => w is TargetVerseMark && w.active);
      expect(mark, findsOneWidget);
      final rect = tester.getRect(mark);
      expect(rect.top, greaterThan(tester.getRect(find.byType(AliyahRibbon)).bottom));
      expect(rect.top, lessThan(phone.height / 2));
      expect(titled('Shishi'), findsOneWidget);
    });

    testWidgets('Listen reads on from one aliyah into the next', (tester) async {
      final tts = _HeldTts();
      await open(tester, '/read/5787:2/0?mode=full', settings: whole, size: phone, tts: tts);
      await tester.tap(find.byTooltip('Listen'));
      await tester.pumpAndSettle();
      expect(tts.last, startsWith('אלה תולדת נח'));
      final next = find.byTooltip('Next verse');
      for (var i = 0; i < 14; i++) {
        await tester.tap(next);
        await tester.pumpAndSettle();
      }
      // Genesis 7:1, the first verse of Sheni, read and in view.
      expect(tts.last, startsWith('ויאמר אדני לנח'));
      final reading = find.byWidgetPredicate((w) => w is VerseGroup && w.highlighted);
      expect(tester.widget<VerseGroup>(reading).verse, const VerseRef(7, 1));
      expect(tester.getRect(reading).top, lessThan(phone.height / 2));
      expect(titled('Sheni'), findsOneWidget);
    });

    testWidgets('sets each aliyah in parallel columns on a wide screen', (tester) async {
      await open(tester, '/read/5787:2/0?mode=full', settings: whole);
      expect(find.byType(ParallelVerse), findsWidgets);
      expect(find.byType(ParallelHeading), findsOneWidget, reason: "at Rishon's start");
      await tester.tap(tab('Revi’i'));
      await tester.pumpAndSettle();
      expect(find.byType(ParallelHeading), findsWidgets, reason: "at Revi'i's start too");
      expect(tester.getRect(find.byType(ParallelHeading).last).top, greaterThan(tester.getRect(heading(3)).bottom));
    });
  });
}
