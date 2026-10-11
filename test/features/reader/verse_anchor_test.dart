import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/data/models/verse_ref.dart';
import 'package:shnayim_mikra/features/reader/reader_screen.dart';
import 'package:shnayim_mikra/features/reader/scripture_text.dart';
import 'package:shnayim_mikra/features/reader/verse_anchor.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../../helpers.dart';

/// Wednesday of Bereshit 5787.
final _now = DateTime(2026, 10, 7, 10);

/// Shlishi of Bereshit runs from Genesis 2:20 to 3:21: 3:8 is half way.
const _shlishi = '/read/5787:1/2';

void main() {
  /// Opens [route] in the reader, and waits for its texts and then, unless
  /// [settle] is false, for it to come to rest.
  Future<ProviderContainer> open(
    WidgetTester tester,
    String route, {
    AppSettings settings = const AppSettings(onboardingComplete: true),
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: settings, now: _now);
    c.read(routerProvider).go(route);
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 40 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    if (settle) await tester.pumpAndSettle();
    return c;
  }

  Finder marked() => find.byWidgetPredicate((w) => w is TargetVerseMark && w.active);

  /// The verse inside the mark.
  VerseRef markedVerse(WidgetTester tester) =>
      tester.widget<ScriptureVerse>(find.descendant(of: marked(), matching: find.byType(ScriptureVerse)).first).verse.ref;

  /// The scroll view of the text.
  Finder text() => find.descendant(
        of: find.byType(ReaderScreen),
        matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );

  ScrollPosition textScroll(WidgetTester tester) => tester.state<ScrollableState>(text()).position;

  testWidgets('opens the full text scrolled to the verse, and marks it', (tester) async {
    await open(tester, '$_shlishi?verse=3:8');
    final reader = tester.widget<ReaderScreen>(find.byType(ReaderScreen));
    expect(reader.targetVerse, const VerseRef(3, 8));
    expect(find.text('Mark this aliyah as read'), findsOneWidget, reason: 'the full text, whose end has the button');

    expect(marked(), findsOneWidget);
    expect(markedVerse(tester), const VerseRef(3, 8));

    // The verse's block a fifth of the way down what the text can show.
    final viewport = tester.getRect(text());
    final block = tester.getRect(find.ancestor(of: marked(), matching: find.byType(Center)).first);
    expect(textScroll(tester).pixels, greaterThan(0));
    expect(block.top, closeTo(viewport.top + (viewport.height - block.height) * 0.2, 1));
    // The mark is painted around the verse's text, within its block's inset.
    expect(tester.getRect(marked()).top, block.top + VerseGroup.padding.top);
  });

  testWidgets('the mark covers the Targum and translation, and nothing moves when it goes', (tester) async {
    await open(tester, '$_shlishi?verse=3:8', settings: const AppSettings(onboardingComplete: true, showTranslation: true));
    expect(find.descendant(of: marked(), matching: find.byType(ScriptureVerse)), findsNWidgets(2));
    expect(find.descendant(of: marked(), matching: find.byType(TranslationVerse)), findsOneWidget);

    final verse = find.byWidgetPredicate((w) => w is ScriptureVerse && w.verse.ref == const VerseRef(3, 8)).first;
    final before = tester.getRect(verse);
    // A tap on the text, away from the verse: at the foot of the screen.
    await tester.tapAt(tester.getRect(text()).bottomCenter - const Offset(0, 24));
    await tester.pump();
    expect(marked(), findsNothing);
    expect(tester.getRect(verse), before);
  });

  // Focus mode reads around the verse opened at, and its own highlight (a
  // fill and padding) stays off once the mark goes, until focus moves.
  testWidgets('in focus mode too, nothing moves when the mark goes', (tester) async {
    await open(tester, '$_shlishi?verse=3:8', settings: const AppSettings(onboardingComplete: true, focusMode: true));
    ScriptureVerse mikra(int verse) => tester.widget<ScriptureVerse>(
          find.byWidgetPredicate((w) => w is ScriptureVerse && w.verse.ref == VerseRef(3, verse) && !w.secondary).first,
        );
    // Focus mode highlights the verse's whole block.
    VerseGroup group(int verse) =>
        tester.widget<VerseGroup>(find.byWidgetPredicate((w) => w is VerseGroup && w.verse == VerseRef(3, verse)));
    final verse = find.byWidgetPredicate((w) => w is ScriptureVerse && w.verse.ref == const VerseRef(3, 8)).first;
    expect(mikra(8).dimmed, isFalse);
    expect(mikra(9).dimmed, isTrue, reason: 'focus mode reads around the verse opened at');
    final before = tester.getRect(verse);

    // A tap on the text that lands on no verse (whose tap would move the
    // focus): in the margin beside them.
    await tester.tapAt(tester.getRect(text()).centerLeft + const Offset(6, 0));
    await tester.pump();
    expect(marked(), findsNothing);
    expect(tester.getRect(verse), before);
    expect(group(8).highlighted, isFalse);
    expect(mikra(9).dimmed, isTrue, reason: 'still focused');

    // Focus that moves shows its highlight as ever.
    final nine = find.byWidgetPredicate((w) => w is ScriptureVerse && w.verse.ref == const VerseRef(3, 9)).first;
    await tester.ensureVisible(nine);
    await tester.pumpAndSettle();
    await tester.tap(nine);
    await tester.pump();
    expect(group(9).highlighted, isTrue);
    expect(mikra(8).dimmed, isTrue);
  });

  // ↓ and ↑ move focus mode's verse as a tap does, so they clear the mark:
  // left in place, the verse opened at would show dimmed on its wash.
  testWidgets('in focus mode, ↓ and ↑ move on from the verse and clear its mark', (tester) async {
    await open(tester, '$_shlishi?verse=3:8', settings: const AppSettings(onboardingComplete: true, focusMode: true));
    ScriptureVerse mikra(int verse) => tester.widget<ScriptureVerse>(
          find.byWidgetPredicate((w) => w is ScriptureVerse && w.verse.ref == VerseRef(3, verse) && !w.secondary).first,
        );
    // Focus mode highlights the verse's whole block.
    VerseGroup group(int verse) =>
        tester.widget<VerseGroup>(find.byWidgetPredicate((w) => w is VerseGroup && w.verse == VerseRef(3, verse)));
    expect(marked(), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(marked(), findsNothing);
    expect(group(9).highlighted, isTrue);
    expect(mikra(8).dimmed, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(marked(), findsNothing);
    expect(group(8).highlighted, isTrue, reason: 'focus has moved, so its own highlight shows');
    expect(mikra(9).dimmed, isTrue);
  });

  testWidgets('a scroll keeps the mark, the next tap clears it', (tester) async {
    await open(tester, '$_shlishi?verse=3:8');
    await tester.drag(text(), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(marked(), findsOneWidget, reason: 'a drag is not a tap');

    // On the part of the verse still in view, below the aliyah ribbon.
    final verse = find.byWidgetPredicate((w) => w is ScriptureVerse && w.verse.ref == const VerseRef(3, 8)).first;
    await tester.tapAt(tester.getRect(verse).intersect(tester.getRect(text())).center);
    await tester.pump();
    expect(marked(), findsNothing);
  });

  testWidgets('another aliyah clears the mark', (tester) async {
    await open(tester, '$_shlishi?verse=3:8');
    await tester.tap(find.text('Sheni'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shlishi'));
    await tester.pumpAndSettle();
    expect(marked(), findsNothing);
    expect(find.text('Mark this aliyah as read'), findsOneWidget, reason: 'still the full text');
  });

  testWidgets('says which verse it is, where the platform takes announcements', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(supportsAnnounce: true);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await open(tester, '$_shlishi?verse=3:8');
    expect(tester.takeAnnouncements().map((a) => a.message), contains('Genesis 3:8'));
  });

  group('the scroll', () {
    testWidgets('moves to the verse over 300 ms', (tester) async {
      await open(tester, '$_shlishi?verse=3:8', settle: false);
      expect(textScroll(tester).pixels, 0, reason: 'it starts from the top');
      // The frame that starts it, and half its time.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final halfway = textScroll(tester).pixels;
      await tester.pumpAndSettle();
      expect(halfway, inExclusiveRange(0, textScroll(tester).pixels));
    });

    testWidgets('is there at once with Reduce Motion', (tester) async {
      await open(
        tester,
        '$_shlishi?verse=3:8',
        settings: const AppSettings(onboardingComplete: true, reduceMotion: true),
        settle: false,
      );
      await tester.pump();
      final at = textScroll(tester).pixels;
      expect(at, greaterThan(0));
      await tester.pumpAndSettle();
      expect(textScroll(tester).pixels, at);
    });
  });

  testWidgets('in focus mode, the other verses dim around it', (tester) async {
    await open(tester, '$_shlishi?verse=3:8', settings: const AppSettings(onboardingComplete: true, focusMode: true));
    final verses = tester.widgetList<ScriptureVerse>(find.byType(ScriptureVerse)).toList();
    for (final v in verses) {
      expect(v.dimmed, v.verse.ref != const VerseRef(3, 8), reason: '${v.verse.ref}');
    }
    // The mark stands in for focus mode's own highlight.
    for (final g in tester.widgetList<VerseGroup>(find.byType(VerseGroup))) {
      expect(g.highlighted, isFalse, reason: '${g.verse}');
    }
  });

  testWidgets('a verse not in the aliyah opens it as usual, in full text', (tester) async {
    await open(tester, '$_shlishi?verse=40:1');
    expect(marked(), findsNothing);
    expect(find.text('Mark this aliyah as read'), findsOneWidget);
    expect(textScroll(tester).pixels, 0);
  });

  test('a link names a verse as chapter:verse, and nothing else', () {
    expect(VerseRef.tryParse('28:12'), const VerseRef(28, 12));
    expect(VerseRef.tryParse('1:1'), const VerseRef(1, 1));
    for (final s in [null, '', '28', '28:', ':12', '28-12', '28:12:1', ' 28:12', 'a:b', '0:1', '1:0', '1234:1']) {
      expect(VerseRef.tryParse(s), isNull, reason: '$s');
    }
  });

  testWidgets('a verse that is not a reference is no anchor', (tester) async {
    await open(tester, '$_shlishi?verse=chapter');
    expect(tester.widget<ReaderScreen>(find.byType(ReaderScreen)).targetVerse, isNull);
    expect(find.text('Read the Hebrew'), findsOneWidget, reason: 'the guided reader, as without it');
  });
}
