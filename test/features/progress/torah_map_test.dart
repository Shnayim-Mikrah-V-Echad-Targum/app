import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/palette.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';

import '../../helpers.dart';

/// docs/DESIGN_SYSTEM.md §6.14: the Torah map on Progress, laid out in the
/// bundled fonts. Its text contrast is checked in
/// test/accessibility/text_contrast_test.dart.
void main() {
  setUpAll(loadBundledFonts);

  Future<void> openProgress(
    WidgetTester tester, {
    Size size = const Size(412, 2600),
    double textScale = 1,
    DateTime? now,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final c = await pumpApp(
      tester,
      settings: AppSettings(onboardingComplete: true, joinDate: historyJoinDate),
      now: now ?? historyNow,
      progress: historyProgress(),
    );
    c.read(routerProvider).go('/progress');
    await tester.pumpAndSettle();
  }

  /// The tile whose screen-reader label starts with [name].
  Finder tileOf(String name) => find.bySemanticsLabel(RegExp('^$name: '));

  /// A book's header, by its screen-reader label.
  Finder headerOf(String book) => find.bySemanticsLabel(RegExp('^$book: '));

  /// Presses Tab until keyboard focus is inside [target].
  Future<void> tabInto(WidgetTester tester, Finder target) async {
    final element = target.evaluate().single;
    for (var i = 0; i < 200; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus?.context;
      if (focused == null) continue;
      var inside = focused == element;
      focused.visitAncestorElements((a) => !(inside = inside || a == element));
      if (inside) return;
    }
    fail('Tab never reached $target');
  }

  testWidgets('every past state has its own fill, border and icon', (tester) async {
    await openProgress(tester);
    const scheme = Palettes.light;
    final status = Palettes.statusLight;
    final sefer = Palettes.seferLight;

    for (final (label, fill, border, icon, iconColor) in [
      ('Bereshit: On time', status.done, null, Icons.check, status.onDone),
      ('Noach: After Shabbat — still counts', status.late, null, Icons.check_circle_outline, status.onLate),
      ('Lech-Lecha: Not completed', sefer.paper, BorderSide(color: scheme.outline), Icons.remove, status.neutral),
      ('Vayera: Made up', sefer.paper, BorderSide(color: status.late, width: 1.5), Icons.history, status.late),
      ('Chayei Sara: On time', status.done, null, Icons.check, status.onDone),
      ('Toldot: In progress', scheme.primaryContainer, BorderSide(color: scheme.primary, width: 2), Icons.timelapse,
          scheme.onPrimaryContainer),
      ('Vayetzei: Upcoming', sefer.paper, BorderSide(color: sefer.hairline), null, null),
    ]) {
      final tile = find.bySemanticsLabel(label);
      expect(tile, findsOneWidget, reason: label);
      final ink = tester.widget<Ink>(find.descendant(of: tile, matching: find.byType(Ink)));
      expect((ink.decoration! as BoxDecoration).color, fill, reason: label);
      final drawn = find.descendant(
        of: tile,
        matching: find.byWidgetPredicate((w) => w is Container && w.foregroundDecoration != null),
      );
      if (border == null) {
        expect(drawn, findsNothing, reason: label);
      } else {
        final box = tester.widget<Container>(drawn).foregroundDecoration! as BoxDecoration;
        expect((box.border! as Border).top, border, reason: label);
      }
      final icons = tester.widgetList<Icon>(find.descendant(of: tile, matching: find.byType(Icon)));
      expect(icons.map((i) => (i.icon, i.color, i.size)), [if (icon != null) (icon, iconColor, 14)], reason: label);
    }
    // The current parsha is the one in bold.
    final toldot = tester.widget<Text>(find.descendant(of: tileOf('Toldot'), matching: find.text('Toldot')));
    expect(toldot.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('only the book being read starts open; its header folds it', (tester) async {
    final handle = tester.ensureSemantics();
    await openProgress(tester);
    expect(tileOf('Noach'), findsOneWidget);
    expect(tileOf('Shemot'), findsNothing);
    expect(tileOf('Vezot Haberakhah'), findsNothing);
    expect(
      tester.getSemantics(headerOf('Genesis')),
      isSemantics(
        label: 'Genesis: 4 of 12 parshiyot',
        isHeader: true,
        isButton: true,
        hasTapAction: true,
        hasExpandedState: true,
        isExpanded: true,
      ),
    );
    expect(tester.getSemantics(headerOf('Exodus')), isSemantics(hasExpandedState: true, isExpanded: false));
    // The header row: Hebrew name, English name, the count and a chevron.
    for (final text in ['בראשית', 'Genesis', '4 of 12']) {
      final found = find.descendant(of: headerOf('Genesis'), matching: find.textContaining(text, findRichText: true));
      expect(found, findsWidgets, reason: text);
    }

    await tester.tap(headerOf('Exodus'));
    await tester.pumpAndSettle();
    expect(tileOf('Shemot'), findsOneWidget);
    expect(tester.getSemantics(headerOf('Exodus')), isSemantics(isExpanded: true));
    await tester.tap(headerOf('Genesis'));
    await tester.pumpAndSettle();
    expect(tileOf('Noach'), findsNothing);
    handle.dispose();
  });

  testWidgets('a header opens its book from the keyboard', (tester) async {
    await openProgress(tester);
    await tabInto(tester, headerOf('Leviticus'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(tileOf('Vayikra'), findsOneWidget);
  });

  testWidgets('the Hebrew header drops the English name', (tester) async {
    tester.view.physicalSize = const Size(412, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(
      tester,
      settings: AppSettings(onboardingComplete: true, joinDate: historyJoinDate, language: AppLanguage.hebrew),
      now: historyNow,
      progress: historyProgress(),
    );
    c.read(routerProvider).go('/progress');
    await tester.pumpAndSettle();
    final header = headerOf('בראשית');
    expect(find.descendant(of: header, matching: find.textContaining('Genesis', findRichText: true)), findsNothing);
    expect(find.descendant(of: header, matching: find.text('4 מתוך 12')), findsOneWidget);
  });

  group('grid', () {
    /// The tiles in the first row of the open book.
    int firstRow(WidgetTester tester, List<String> names) {
      final top = tester.getRect(tileOf(names.first)).top;
      return names.takeWhile((n) => tester.getRect(tileOf(n)).top == top).length;
    }

    const genesis = ['Bereshit', 'Noach', 'Lech-Lecha', 'Vayera', 'Chayei Sara', 'Toldot', 'Vayetzei'];

    testWidgets('three columns on a phone, each row as tall as its tallest tile', (tester) async {
      await openProgress(tester);
      expect(firstRow(tester, genesis), 3);
      final rects = [for (final n in genesis.take(6)) tester.getRect(tileOf(n))];
      for (final r in rects) {
        expect(r.height, greaterThanOrEqualTo(52));
        expect(r.width, rects.first.width);
      }
      // 6 between tiles, across and down.
      expect(rects[1].left - rects[0].right, moreOrLessEquals(6));
      expect(rects[3].top - rects[0].bottom, moreOrLessEquals(6));
    });

    testWidgets('four columns from 600 dp', (tester) async {
      await openProgress(tester, size: const Size(800, 1600));
      expect(firstRow(tester, genesis), 4);
    });

    // A one-word name is never broken inside the word. A tile whose name
    // has a word too long to sit beside its icon puts the icon above it;
    // only large text takes fewer columns. In the week of Beha'alotcha
    // (the longest word), its tile has the bold and the icon of the current
    // parsha, and the unread parshiyot before it have icons too.
    const numbers = ['Bamidbar', 'Nasso', "Beha'alotcha", "Sh'lach", 'Korach', 'Chukat', 'Balak', 'Pinchas'];
    for (final (size, scale, columns, stacked) in [
      (const Size(360, 2600), 1.0, 3, true),
      (const Size(412, 2600), 1.0, 3, false),
      (const Size(1366, 1600), 1.0, 6, true),
      (const Size(412, 4000), 2.0, 1, false),
    ]) {
      testWidgets('one-word names stay whole at ${size.width.round()} dp and ${scale}x', (tester) async {
        await openProgress(tester, size: size, textScale: scale, now: DateTime(2027, 6, 23, 10));
        expect(firstRow(tester, numbers), columns);
        final icon = tester.getCenter(find.descendant(of: tileOf("Beha'alotcha"), matching: find.byIcon(Icons.timelapse)));
        final text = tester.getCenter(find.descendant(of: tileOf("Beha'alotcha"), matching: find.text("Beha'alotcha")));
        expect(icon.dy < text.dy, stacked, reason: 'the icon above the name');

        for (final book in ['Genesis', 'Exodus', 'Leviticus', 'Deuteronomy']) {
          await tester.ensureVisible(headerOf(book));
          await tester.pumpAndSettle();
          await tester.tap(headerOf(book));
          await tester.pumpAndSettle();
        }
        for (final name in ["Beha'alotcha", 'Vayishlach', 'Mishpatim', 'Bechukotai', 'Vaetchanan', 'Nitzavim']) {
          final text = find.descendant(
            of: find.descendant(of: tileOf(name), matching: find.text(name)),
            matching: find.byType(RichText),
          );
          final paragraph = tester.renderObject<RenderParagraph>(text);
          final boxes = paragraph.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: name.length));
          expect({for (final b in boxes) b.top}, hasLength(1), reason: name);
        }
        // Its icon above it, a one-line name still fits the 52 dp tile.
        if (scale == 1) expect(tester.getSize(tileOf("Beha'alotcha")).height, 52);
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('the info button opens, by keyboard, a sheet of every tile state', (tester) async {
    await openProgress(tester);
    final help = find.byTooltip("Each tile is one parsha of this year's cycle.");
    expect(help, findsOneWidget);
    await tabInto(tester, help);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(SheetTitle, 'Torah map'), findsOneWidget);
    final sheet = find.byType(BottomSheet);
    for (final label in [
      'On time',
      'After Shabbat — still counts',
      'Doubled up',
      'Made up',
      'Not completed',
      'In progress',
      'Upcoming',
      'Not counted',
    ]) {
      expect(find.descendant(of: sheet, matching: find.text(label)), findsOneWidget, reason: label);
    }
    // Each label beside a swatch of its tile.
    expect(find.descendant(of: sheet, matching: find.byType(Ink)), findsNWidgets(8));
    final colours = tester
        .widgetList<Ink>(find.descendant(of: sheet, matching: find.byType(Ink)))
        .map((i) => (i.decoration! as BoxDecoration).color)
        .toSet();
    expect(
      colours,
      containsAll([Palettes.statusLight.done, Palettes.statusLight.late, Palettes.light.primaryContainer]),
    );
    expect(SeferColors.of(tester.element(sheet)).paper, Palettes.seferLight.paper);
  });
}
