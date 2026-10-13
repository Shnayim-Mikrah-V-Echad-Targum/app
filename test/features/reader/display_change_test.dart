import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/app/providers.dart';
import 'package:shnayim_mikrah/app/router.dart';
import 'package:shnayim_mikrah/data/models/verse_ref.dart';
import 'package:shnayim_mikrah/features/reader/reader_screen.dart';
import 'package:shnayim_mikrah/features/reader/scripture_text.dart' show VerseGroup;
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/features/settings/widgets/settings_widgets.dart' show SwitchRow;
import 'package:shnayim_mikrah/ui/widgets/common.dart';

import '../../helpers.dart';

/// A change of display in the reader (the display sheet's switches, the text's
/// size and font) keeps the reader's place, and the sheet keeps the keyboard
/// focus, so that Esc closes it: as found on a Windows PC, where turning Rashi
/// on in the full text opened at Genesis 8:11 jumped back to the aliyah's
/// start (7:17), and Esc then left the sheet open.
void main() {
  setUpAll(loadBundledFonts);

  /// A desktop window, 1700 × 980 at 125%, as on the PC.
  const window = Size(1700, 980);

  /// Monday of Noach 5787, whose Shlishi is Genesis 7:17–8:14.
  final monday = DateTime(2026, 10, 19, 10);

  const settings = AppSettings(onboardingComplete: true, notificationPromptShown: true);

  /// Settles a page that loads its texts from assets, which takes real time.
  Future<void> loadTexts(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    // Rashi and the translation load behind the text that stays.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<ProviderContainer> open(WidgetTester tester, String path, {AppSettings settings = settings}) async {
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1.25;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: settings, now: monday);
    c.read(routerProvider).go(path);
    await loadTexts(tester);
    return c;
  }

  Finder verse(int chapter, int verse) => find.byWidgetPredicate(
        (w) => w is VerseGroup && w.verse == VerseRef(chapter, verse),
        description: 'verse $chapter:$verse',
      );

  /// Where the top of [chapter]:[v] stands on the screen.
  double topOf(WidgetTester tester, int chapter, int v) => tester.getTopLeft(verse(chapter, v)).dy;

  final sheet = find.byType(BottomSheet);

  /// The display sheet's row [title].
  Finder row(String title) => find.ancestor(of: find.text(title), matching: find.byType(SwitchRow));

  /// Whether the display sheet's switch [title] is on.
  bool isOn(WidgetTester tester, String title) =>
      tester.widget<Switch>(find.descendant(of: row(title), matching: find.byType(Switch))).value;

  /// Whether the keyboard focus is within [finder].
  bool focusIn(Finder finder) {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) return false;
    final within = finder.evaluate().toSet();
    var found = within.contains(focused);
    focused.visitAncestorElements((e) => !(found = found || within.contains(e)));
    return found;
  }

  Future<void> openSheet(WidgetTester tester, {PointerDeviceKind kind = PointerDeviceKind.touch}) async {
    await tester.tap(find.byTooltip('Display settings'), kind: kind);
    await tester.pumpAndSettle();
    expect(sheet, findsOneWidget);
  }

  /// The sheet's switch [title], scrolled into view.
  Future<Finder> sheetSwitch(WidgetTester tester, String title) async {
    final row = find.descendant(of: sheet, matching: find.text(title));
    await tester.scrollUntilVisible(row, 200,
        scrollable: find.descendant(of: sheet, matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    return row;
  }

  group('Esc closes the display sheet', () {
    for (final (mode, path) in [('full text', '/read/5787:2/2?mode=full'), ('guided reader', '/read/5787:2/2')]) {
      for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
        testWidgets('in the $mode, after Rashi is turned on in it by ${kind.name}', (tester) async {
          await open(tester, path);
          await openSheet(tester, kind: kind);
          await tester.tap(await sheetSwitch(tester, 'Show Rashi alongside'), kind: kind);
          await loadTexts(tester);
          expect(isOn(tester, 'Show Rashi alongside'), isTrue);
          // The focus is still the sheet's, not the reader's beneath it.
          expect(focusIn(find.byType(ReaderScreen)), isFalse);

          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(sheet, findsNothing);
        });
      }
    }

    testWidgets('after a switch in it is focused with Tab and turned on with Space', (tester) async {
      await open(tester, '/read/5787:2/2?mode=full');
      await openSheet(tester);
      await sheetSwitch(tester, 'Show Rashi alongside');
      for (var i = 0; i < 40 && !focusIn(row('Show Rashi alongside')); i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(focusIn(row('Show Rashi alongside')), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await loadTexts(tester);
      expect(isOn(tester, 'Show Rashi alongside'), isTrue);
      expect(focusIn(row('Show Rashi alongside')), isTrue, reason: 'the row keeps the focus');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
    });

    testWidgets('and any sheet or dialog, when the page beneath it has taken the focus', (tester) async {
      await open(tester, '/read/5787:2/2?mode=full');
      await openSheet(tester);
      // The reader's own focus, beneath the sheet, as a reader built anew
      // would take it.
      final reader = find.byWidgetPredicate((w) => w is Focus && w.autofocus);
      Focus.of(tester.element(find.descendant(of: reader.first, matching: find.byType(Scaffold)).first)).requestFocus();
      await tester.pump();
      expect(focusIn(sheet), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);

      // A dialog too, over the reader.
      showAppDialog<void>(
        context: tester.element(find.byType(Scaffold).first),
        builder: (_) => const AlertDialog(content: Text('A dialog')),
      );
      await tester.pumpAndSettle();
      Focus.of(tester.element(find.descendant(of: reader.first, matching: find.byType(Scaffold)).first)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('A dialog'), findsNothing);
    });
  });

  group('the full text keeps its place', () {
    testWidgets('as Rashi is turned on: the verse opened at stays where it is', (tester) async {
      await open(tester, '/read/5787:2/2?verse=8:11');
      final before = topOf(tester, 8, 11);
      expect(before, inInclusiveRange(0, 784), reason: 'opened at 8:11, in view');

      await openSheet(tester, kind: PointerDeviceKind.mouse);
      await tester.tap(await sheetSwitch(tester, 'Show Rashi alongside'), kind: PointerDeviceKind.mouse);
      await loadTexts(tester);
      expect(find.text('רש״י'), findsWidgets, reason: 'Rashi is shown');
      expect(topOf(tester, 8, 11), moreOrLessEquals(before, epsilon: 1));
      // Not back at the aliyah's start.
      expect(tester.getTopLeft(verse(7, 17)).dy, lessThan(0));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(topOf(tester, 8, 11), moreOrLessEquals(before, epsilon: 1));
    });

    testWidgets('as the reader changes how the text is shown: the verse at the top stays there', (tester) async {
      final c = await open(tester, '/read/5787:2/2?mode=full');
      // Scrolled by the reader to 8:5, at the top of the view.
      await tester.dragUntilVisible(verse(8, 5), find.byType(Scrollable).last, const Offset(0, -200));
      await tester.pumpAndSettle();
      final scrollable = find.ancestor(of: verse(8, 5), matching: find.byType(Scrollable)).first;
      final position = tester.state<ScrollableState>(scrollable).position;
      final viewTop = tester.getTopLeft(scrollable).dy;
      position.jumpTo(position.pixels + topOf(tester, 8, 5) - viewTop - 12);
      await tester.pumpAndSettle();
      final before = topOf(tester, 8, 5);
      expect(before, moreOrLessEquals(viewTop + 12));

      final changes = <String, AppSettings Function(AppSettings)>{
        'the translation': (s) => s.copyWith(showTranslation: true),
        'the vowels': (s) => s.copyWith(showNikud: false),
        'the size': (s) => s.copyWith(readingScale: s.readingScale + 0.3),
        'the font': (s) => s.copyWith(scriptureFont: ScriptureFont.ezra),
        'the columns': (s) => s.copyWith(parallelColumns: false),
        'Rashi': (s) => s.copyWith(showRashi: true),
      };
      for (final MapEntry(key: what, value: change) in changes.entries) {
        c.read(settingsProvider.notifier).update(change);
        await loadTexts(tester);
        expect(topOf(tester, 8, 5), moreOrLessEquals(before, epsilon: 1), reason: what);
      }
    });

    testWidgets('in the whole parsha, as Rashi is turned on', (tester) async {
      await open(tester, '/read/5787:2/2?verse=8:11', settings: settings.copyWith(fullTextWholeParsha: true));
      final before = topOf(tester, 8, 11);
      expect(before, inInclusiveRange(0, 784));
      await openSheet(tester);
      await tester.tap(await sheetSwitch(tester, 'Show Rashi alongside'));
      await loadTexts(tester);
      expect(topOf(tester, 8, 11), moreOrLessEquals(before, epsilon: 1));
    });
  });

  testWidgets('the guided reader stays at its step as Rashi is turned on', (tester) async {
    await open(tester, '/read/5787:2/2');
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    String shown() => tester.widget<Text>(find.descendant(of: find.byType(AppBar), matching: find.byType(Text)).first).data!;
    final title = shown();
    final step = find.textContaining(RegExp(r'^Step \d+ of \d+'));
    final stepBefore = step.evaluate().isEmpty ? null : tester.widget<Text>(step.first).data;
    final verses = [for (final w in tester.widgetList<VerseGroup>(find.byType(VerseGroup))) w.verse];

    await openSheet(tester);
    await tester.tap(await sheetSwitch(tester, 'Show Rashi alongside'));
    await loadTexts(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(shown(), title);
    if (stepBefore != null) expect(tester.widget<Text>(step.first).data, stepBefore);
    expect([for (final w in tester.widgetList<VerseGroup>(find.byType(VerseGroup))) w.verse], verses);
  });
}
