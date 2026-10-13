import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/app/providers.dart';
import 'package:shnayim_mikrah/features/reader/scripture_text.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/features/settings/screens/display_settings_screen.dart';
import 'package:shnayim_mikrah/features/settings/widgets/settings_widgets.dart';
import 'package:shnayim_mikrah/services/optional_fonts.dart';
import 'package:shnayim_mikrah/ui/widgets/paper_group.dart';
import 'package:shnayim_mikrah/ui/widgets/theme_swatch_picker.dart';

import '../../helpers.dart';

/// Settings → Display (docs/DESIGN_SYSTEM.md §9): a page of the text held at
/// the top while the settings scroll, the theme swatches, and the settings
/// in paper groups.
void main() {
  Future<ProviderContainer> open(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(onboardingComplete: true),
    Size size = const Size(412, 915),
    double textScale = 1,
  }) =>
      openRoute(tester, '/settings/display', settings: settings, size: size, textScale: textScale).then((c) async {
        // The preview's verses, from a book loaded as the page opens.
        for (var i = 0; i < 50 && find.byType(ScriptureVerse).evaluate().length < 4; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
          await tester.pump();
        }
        await tester.pumpAndSettle();
        return c;
      });

  Finder preview() => find.bySemanticsLabel('Preview');
  Finder previewCard() => find.ancestor(of: find.text('Chapter 14'), matching: find.byType(ClipRRect)).first;

  ScrollableState page(WidgetTester tester) =>
      tester.state<ScrollableState>(find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)));

  Future<void> scrollTo(WidgetTester tester, double offset) async {
    page(tester).position.jumpTo(offset);
    await tester.pumpAndSettle();
  }

  testWidgets('the preview is a page of Deuteronomy 14, its head, verses, Targum and setumah', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester, settings: const AppSettings(onboardingComplete: true, readingScale: 0.5));
    expect(preview(), findsOneWidget);
    expect(find.text('פרק יד'), findsOneWidget);
    expect(find.text('Chapter 14'), findsOneWidget);
    // Its text is a picture of the settings, read as one: the preview.
    expect(find.bySemanticsLabel(RegExp('^Verse 1')), findsNothing);
    expect(find.text('ס'), findsOneWidget, reason: 'the setumah after 14:2');
    handle.dispose();
  });

  testWidgets('the preview stays at the top, shrunk to 140, while the settings scroll under it', (tester) async {
    await open(tester);
    final top = tester.getRect(previewCard());
    expect(top.height, SettingsPage.previewMaxHeight);
    await scrollTo(tester, 900);
    final held = tester.getRect(previewCard());
    expect(held.top, top.top);
    expect(held.height, SettingsPage.previewMinHeight);
    // A slider moved down there changes the page held up here.
    final before = tester.getSize(find.text('פרק יד'));
    final slider = find.byTooltip('Increase Reading size');
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    expect(tester.getRect(previewCard()).top, top.top);
    await tester.tap(slider);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.text('פרק יד')).height, greaterThan(before.height));
  });

  testWidgets('keyboard focus moved onto a row under the preview brings the row out from under it', (tester) async {
    await open(tester);
    final keep = find.widgetWithText(SwitchRow, 'Keep the screen on while reading');
    final bold = find.widgetWithText(SwitchRow, 'Bold text');
    await tester.ensureVisible(keep);
    await tester.pumpAndSettle();
    // Bold text just under the preview's lower edge, hidden.
    final under = tester.getRect(bold).top - tester.getRect(previewCard()).bottom + 20;
    await scrollTo(tester, page(tester).position.pixels + under);
    expect(tester.getRect(bold).top, lessThan(tester.getRect(previewCard()).bottom));

    // The row's own focus node, as Tab reaches it.
    final focus = find.descendant(of: keep, matching: find.byType(Focus)).first;
    Focus.of(tester.element(find.descendant(of: focus, matching: find.byWidgetPredicate((_) => true)).first),
            createDependency: false)
        .requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(find.descendant(of: bold, matching: find.byElementPredicate((e) => e == focused)), findsOneWidget);
    expect(tester.getRect(bold).top, greaterThanOrEqualTo(tester.getRect(previewCard()).bottom));
  });

  for (final (why, size, textScale) in [
    ('a short window', const Size(800, 600), 1.0),
    ('large text', const Size(412, 915), 2.0),
  ]) {
    testWidgets('with $why, the preview scrolls away with the settings, whole', (tester) async {
      await open(tester, size: size, textScale: textScale);
      expect(tester.getRect(previewCard()).height, SettingsPage.previewMaxHeight);
      await scrollTo(tester, 600);
      expect(find.text('Chapter 14').hitTestable(), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets("on a desktop, the preview stands in the page's column, as its paper does", (tester) async {
    await open(tester, size: const Size(1366, 860));
    final paper = tester.getRect(find.byType(PaperGroup).first);
    expect(tester.getRect(previewCard()).left, paper.left);
    expect(tester.getRect(previewCard()).right, paper.right);
  });

  testWidgets('the theme is chosen by swatch, under the switch to match the device', (tester) async {
    final c = await open(tester);
    expect(find.byType(ThemeSwatchPicker), findsOneWidget);
    expect(find.widgetWithText(SwitchRow, 'Match device'), findsOneWidget);
    final sepia = find.byWidgetPredicate((w) => w is Text && w.semanticsLabel == 'Sepia');
    await tester.ensureVisible(sepia);
    await tester.tap(sepia);
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).theme, AppThemeMode.sepia);
  });

  testWidgets('its switches are paper rows in groups: text, study aids and reading', (tester) async {
    final c = await open(tester);
    for (final (heading, rows) in [
      ('Text', ['Vowels (nikud)', 'Cantillation (ta’amim)', 'Show ketiv (as written)', 'Verse numbers', 'Write Divine Names as ה׳ and אלקים', 'Justify text']),
      ('Study aids', ['English translation (study aid)', 'Show Rashi alongside']),
      ('Reading', ['Focus mode', 'Bold text', 'Keep the screen on while reading']),
    ]) {
      final eyebrow = find.text(heading.toUpperCase()).evaluate().isEmpty ? find.text(heading) : find.text(heading.toUpperCase());
      expect(eyebrow, findsOneWidget, reason: heading);
      final group = find.ancestor(of: find.text(rows.first), matching: find.byType(PaperGroup));
      for (final row in rows) {
        expect(find.descendant(of: group, matching: find.widgetWithText(SwitchRow, row)), findsOneWidget, reason: row);
      }
    }
    // The Rashi script only while Rashi is shown.
    final rashiScript = find.widgetWithText(SwitchRow, 'Rashi script');
    expect(rashiScript, findsNothing);
    final rashi = find.widgetWithText(SwitchRow, 'Show Rashi alongside');
    await tester.ensureVisible(rashi);
    await tester.pumpAndSettle();
    await tester.tap(rashi);
    await tester.pumpAndSettle();
    await tester.ensureVisible(rashiScript);
    await tester.pumpAndSettle();
    await tester.tap(rashiScript);
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).rashiScript, isTrue);
  });

  testWidgets("Bold text, while the device's is on, is shown on and disabled, saying so", (tester) async {
    final handle = tester.ensureSemantics();
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(boldText: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final c = await open(tester);
    final row = find.widgetWithText(SwitchRow, 'Bold text');
    Switch toggle() => tester.widget<Switch>(find.descendant(of: row, matching: find.byType(Switch)));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    expect(toggle().value, isTrue, reason: 'in force, though the app’s own is off');
    expect(toggle().onChanged, isNull);
    expect(find.descendant(of: row, matching: find.text('On in your device’s settings')), findsOneWidget);
    expect(
      tester.getSemantics(row),
      isSemantics(
        label: 'Bold text\nOn in your device’s settings',
        hasToggledState: true,
        isToggled: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).boldText, isFalse);

    // The device's turned off: the app's own setting again, with no
    // description, to change.
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures();
    await tester.pumpAndSettle();
    expect(toggle().value, isFalse);
    expect(toggle().onChanged, isNotNull);
    expect(find.text('On in your device’s settings'), findsNothing);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).boldText, isTrue);
    handle.dispose();
  });

  testWidgets("Bold text is shown disabled as the device's turns on with the app's own already on", (tester) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await open(tester, settings: const AppSettings(onboardingComplete: true, boldText: true));
    final row = find.widgetWithText(SwitchRow, 'Bold text');
    Switch toggle() => tester.widget<Switch>(find.descendant(of: row, matching: find.byType(Switch)));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    expect(toggle().value, isTrue);
    expect(toggle().onChanged, isNotNull);

    // The text is bold already, so the app's MediaQuery doesn't change:
    // the switch hears of the device's alone.
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(boldText: true);
    await tester.pumpAndSettle();
    expect(toggle().value, isTrue);
    expect(toggle().onChanged, isNull);
    expect(find.descendant(of: row, matching: find.text('On in your device’s settings')), findsOneWidget);
  });

  testWidgets('line width is a segmented control, and line spacing starts at 1.6', (tester) async {
    final handle = tester.ensureSemantics();
    final c = await open(tester, settings: const AppSettings(onboardingComplete: true, lineHeight: 1.7));
    expect(find.byType(SegmentedButton<LineWidth>), findsOneWidget);
    final decrease = find.byTooltip('Decrease Line spacing');
    await tester.ensureVisible(decrease);
    await tester.pumpAndSettle();
    await tester.tap(decrease);
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).lineHeight, closeTo(1.6, 1e-9));
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove).at(1)).onPressed, isNull,
        reason: 'no lower');
    handle.dispose();
  });

  testWidgets("each font is named, and shown in its own letters, which screen readers don't read", (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester);
    final taamey = find.byWidgetPredicate(
      (w) => w is RadioListTile<ScriptureFont> && w.value == ScriptureFont.taameyFrank,
    );
    await tester.ensureVisible(taamey);
    await tester.pumpAndSettle();
    final sample = find.descendant(of: taamey, matching: find.text(scriptureFontSample));
    expect(tester.widget<Text>(sample).style!.fontFamily, 'TaameyFrank');
    expect(tester.widget<Text>(sample).style!.fontSize, 22);
    final label = tester.getSemantics(taamey).label;
    expect(label, contains('Taamey Frank (classic Chumash)'));
    expect(label, isNot(contains('בְּרֵאשִׁית')));

    final lexend = find.byWidgetPredicate((w) => w is RadioListTile<UiFont> && w.value == UiFont.lexend);
    await tester.ensureVisible(lexend);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.descendant(of: lexend, matching: find.text('Aa Bb אב'))).style!.fontFamily, 'Lexend');
    expect(tester.getSemantics(lexend).label, contains('Lexend'));
    handle.dispose();
  });

  testWidgets('Hebrew: the page and its preview are mirrored, the chapter head in Hebrew alone', (tester) async {
    await open(tester, settings: const AppSettings(onboardingComplete: true, language: AppLanguage.hebrew));
    expect(find.text('פרק יד'), findsOneWidget);
    expect(find.text('Chapter 14'), findsNothing);
    expect(tester.takeException(), isNull);

    // The preview's verses start at its right, as scripture does.
    final card = tester.getRect(find.ancestor(of: find.text('פרק יד'), matching: find.byType(ClipRRect)).first);
    final verse = tester.getRect(find.byType(ScriptureVerse).first);
    expect(card.right - verse.right, lessThan(verse.left - card.left));
    // The first swatch, Light, at the right of its row, Dark at the left.
    Rect swatch(String label) => tester.getRect(find.byWidgetPredicate((w) => w is Text && w.semanticsLabel == label));
    await tester.ensureVisible(find.byType(ThemeSwatchPicker));
    await tester.pumpAndSettle();
    expect(swatch('בהירה').center.dx, greaterThan(swatch('ספיה').center.dx));
    expect(swatch('ספיה').center.dx, greaterThan(swatch('כהה').center.dx));
    // A switch row's switch at its end, the left, and its words at the right.
    final row = find.byType(SwitchRow).first;
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    final toggle = tester.getRect(find.descendant(of: row, matching: find.byType(Switch)));
    final title = tester.getRect(find.descendant(of: row, matching: find.byType(Text)).first);
    expect(toggle.right, lessThan(title.left));
  });

  testWidgets("each font's sample loads its regular face alone, the bold waiting until it is chosen", (tester) async {
    OptionalFonts.reset();
    addTearDown(OptionalFonts.reset);
    await open(tester);
    for (final family in ['Lexend', 'AtkinsonHyperlegibleNext', 'OpenDyslexic', 'TaameyFrank', 'EzraSIL']) {
      expect(OptionalFonts.isSampled(family), isTrue, reason: family);
      expect(OptionalFonts.isRequested(family), isFalse, reason: '$family: not in full');
    }
  });
}
