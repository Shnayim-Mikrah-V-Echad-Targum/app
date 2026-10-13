import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/features/settings/widgets/settings_widgets.dart';
import 'package:shnayim_mikrah/ui/theme/palette.dart';
import 'package:shnayim_mikrah/ui/widgets/theme_swatch_picker.dart';

import '../helpers.dart';

/// docs/DESIGN_SYSTEM.md §6.24: the themes as swatches, each painted in its
/// own palette, under a switch to match the device.
void main() {
  /// The picker at [width], starting at [value]; what it chooses is recorded
  /// and shown.
  Future<List<AppThemeMode>> pump(
    WidgetTester tester, {
    AppThemeMode value = AppThemeMode.light,
    double width = 412,
    bool compact = false,
    AppThemeMode pageTheme = AppThemeMode.light,
  }) async {
    tester.view.physicalSize = Size(width, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final chosen = <AppThemeMode>[];
    var current = value;
    await pumpThemed(
      tester,
      SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: StatefulBuilder(
          builder: (context, setState) => ThemeSwatchPicker(
            value: current,
            compact: compact,
            onChanged: (v) => setState(() {
              chosen.add(v);
              current = v;
            }),
          ),
        ),
      ),
      theme: pageTheme,
    );
    return chosen;
  }

  /// The swatch named [label]: the whole of it, the card and its name.
  Finder swatch(String label) => find
      .ancestor(
        of: find.byWidgetPredicate((w) => w is Text && w.semanticsLabel == label),
        matching: find.byType(MergeSemantics),
      )
      .first;

  bool checked(WidgetTester tester, String label) {
    try {
      expect(tester.getSemantics(swatch(label)), isSemantics(isChecked: true));
      return true;
    } on TestFailure {
      return false;
    }
  }

  testWidgets('each swatch is a radio button: its name, whether it is chosen, and its tap', (tester) async {
    final handle = tester.ensureSemantics();
    final chosen = await pump(tester, value: AppThemeMode.sepia);
    expect(
      tester.getSemantics(swatch('Sepia')),
      isSemantics(
        label: 'Sepia',
        isInMutuallyExclusiveGroup: true,
        hasCheckedState: true,
        isChecked: true,
        isButton: true,
        hasTapAction: true,
        isFocusable: true,
      ),
    );
    for (final other in ['Light', 'Dark', 'High contrast — light', 'High contrast — dark']) {
      expect(
        tester.getSemantics(swatch(other)),
        isSemantics(
          label: other,
          isInMutuallyExclusiveGroup: true,
          hasCheckedState: true,
          isChecked: false,
          isButton: true,
          hasTapAction: true,
          isFocusable: true,
        ),
        reason: other,
      );
    }

    await tester.tap(swatch('High contrast — dark'));
    await tester.pumpAndSettle();
    expect(chosen, [AppThemeMode.highContrastDark]);
    expect(tester.getSemantics(swatch('High contrast — dark')), isSemantics(isChecked: true), reason: 'chosen now');
    expect(checked(tester, 'Sepia'), isFalse);
    handle.dispose();
  });

  testWidgets('the swatches are one group named for the theme, and the arrow keys move between them', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    final group = find.ancestor(of: swatch('Light'), matching: find.bySemanticsLabel('Theme')).first;
    expect(group, findsOneWidget);
    for (final label in ['Sepia', 'Dark', 'High contrast — light', 'High contrast — dark']) {
      expect(find.descendant(of: group, matching: swatch(label)), findsOneWidget, reason: label);
    }

    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
    bool focused(String label) => Focus.of(tester.element(find.descendant(of: swatch(label), matching: find.byType(Ink)))).hasFocus;
    // Past the switch, to the first swatch.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focused('Light'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(focused('Sepia'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focused('High contrast — dark'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(focused('High contrast — light'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(focused('Light'), isTrue);
    handle.dispose();
  });

  for (final compact in [false, true]) {
    testWidgets('every swatch is a target of 48 or more${compact ? ', compact too' : ''}', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, compact: compact);
      for (final label in ['Light', 'Sepia', 'Dark', 'High contrast — light', 'High contrast — dark']) {
        final size = tester.getSize(swatch(label));
        expect(size.width, greaterThanOrEqualTo(48), reason: label);
        expect(size.height, greaterThanOrEqualTo(48), reason: label);
      }
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  }

  testWidgets('a swatch is a card 96 high, 64 compact, painted in its own theme whatever the page', (tester) async {
    await pump(tester, pageTheme: AppThemeMode.dark);
    Ink card(String label) => tester.widget<Ink>(find.descendant(of: swatch(label), matching: find.byType(Ink)));
    for (final (label, scheme) in [
      ('Light', Palettes.light),
      ('Sepia', Palettes.sepia),
      ('Dark', Palettes.dark),
      ('High contrast — light', Palettes.hcLight),
      ('High contrast — dark', Palettes.hcDark),
    ]) {
      expect((card(label).decoration! as BoxDecoration).color, scheme.surface, reason: label);
      expect(
        tester.getSize(find.descendant(of: swatch(label), matching: find.byType(Ink))).height,
        96,
        reason: label,
      );
    }
    await pump(tester, compact: true);
    expect(tester.getSize(find.descendant(of: swatch('Light'), matching: find.byType(Ink))).height, 64);
  });

  for (final hebrew in [false, true]) {
    testWidgets("names high contrast's two on two lines, read as one name${hebrew ? ', in Hebrew' : ''}", (tester) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(340, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpThemed(
        tester,
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ThemeSwatchPicker(value: AppThemeMode.highContrastLight, onChanged: (_) {}),
        ),
        hebrew: hebrew,
        textScale: 2,
      );
      final names = hebrew
          ? [('ניגודיות גבוהה\nבהירה', 'ניגודיות גבוהה — בהירה'), ('ניגודיות גבוהה\nכהה', 'ניגודיות גבוהה — כהה')]
          : [('High contrast\nLight', 'High contrast — light'), ('High contrast\nDark', 'High contrast — dark')];
      for (final (shown, read) in names) {
        final text = tester.widget<Text>(find.byWidgetPredicate((w) => w is Text && w.semanticsLabel == read));
        expect(text.data, shown);
        // However the narrow swatch wraps it, no line starts with a dash.
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: find.byWidget(text), matching: find.byType(RichText)),
        );
        // The first character of each line, by where its box is drawn.
        final starts = <double, int>{};
        for (var i = 0; i < shown.length; i++) {
          final boxes = paragraph.getBoxesForSelection(TextSelection(baseOffset: i, extentOffset: i + 1));
          if (boxes.isNotEmpty) starts.putIfAbsent(boxes.first.top.roundToDouble(), () => i);
        }
        expect(starts.length, greaterThanOrEqualTo(2), reason: 'on two lines at least');
        for (final start in starts.values) {
          expect(shown.substring(start).trimLeft(), isNot(startsWith('—')), reason: shown);
        }
        expect(tester.getSemantics(swatch(read)), isSemantics(label: read), reason: read);
      }
      handle.dispose();
    });
  }

  testWidgets('three to a row, or two under 360 dp', (tester) async {
    await pump(tester);
    expect(tester.getTopLeft(swatch('Dark')).dy, tester.getTopLeft(swatch('Light')).dy);
    expect(tester.getTopLeft(swatch('High contrast — light')).dy, greaterThan(tester.getTopLeft(swatch('Light')).dy));
    await pump(tester, width: 340);
    expect(tester.getTopLeft(swatch('Sepia')).dy, tester.getTopLeft(swatch('Light')).dy);
    expect(tester.getTopLeft(swatch('Dark')).dy, greaterThan(tester.getTopLeft(swatch('Light')).dy));
  });

  testWidgets('the chosen swatch has a primary border and a check at its top end', (tester) async {
    await pump(tester, value: AppThemeMode.dark);
    expect(find.descendant(of: swatch('Dark'), matching: find.byIcon(Icons.check)), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    final check = tester.getRect(find.byIcon(Icons.check));
    final card = tester.getRect(find.descendant(of: swatch('Dark'), matching: find.byType(Ink)));
    expect(card.right - check.right, lessThan(12));
    expect(check.top - card.top, lessThan(12));
  });

  group('matching the device', () {
    testWidgets('marks the light and dark pair it chooses between, for the eye, and says when each is used',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, value: AppThemeMode.system);
      for (final (label, marked, hint) in [
        ('Light', true, 'Used while the device is light'),
        ('Sepia', false, ''),
        ('Dark', true, 'Used while the device is dark'),
        ('High contrast — light', false, ''),
        ('High contrast — dark', false, ''),
      ]) {
        expect(find.descendant(of: swatch(label), matching: find.byIcon(Icons.check)), marked ? findsOneWidget : findsNothing,
            reason: label);
        // No theme is chosen while the device is followed, as its switch
        // says: two checked radios in one group would contradict it.
        expect(checked(tester, label), isFalse, reason: label);
        expect(tester.getSemantics(swatch(label)).getSemanticsData().hint, hint, reason: label);
      }
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      handle.dispose();
    });

    testWidgets("marks high contrast's pair when the device asks for high contrast", (tester) async {
      final handle = tester.ensureSemantics();
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(highContrast: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await pump(tester, value: AppThemeMode.system);
      for (final (label, marked) in [
        ('Light', false),
        ('Dark', false),
        ('High contrast — light', true),
        ('High contrast — dark', true),
      ]) {
        expect(find.descendant(of: swatch(label), matching: find.byIcon(Icons.check)), marked ? findsOneWidget : findsNothing,
            reason: label);
        expect(checked(tester, label), isFalse, reason: label);
      }
      expect(tester.getSemantics(swatch('High contrast — dark')).getSemanticsData().hint, 'Used while the device is dark');
      handle.dispose();
    });

    testWidgets('turned on chooses the device; turned off keeps the theme the device had', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final chosen = await pump(tester, value: AppThemeMode.sepia);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      await tester.tap(find.byType(SwitchRow));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchRow));
      await tester.pumpAndSettle();
      expect(chosen, [AppThemeMode.system, AppThemeMode.dark]);
    });

    testWidgets('a swatch chosen stops matching it', (tester) async {
      final chosen = await pump(tester, value: AppThemeMode.system);
      await tester.tap(swatch('Sepia'));
      await tester.pumpAndSettle();
      expect(chosen, [AppThemeMode.sepia]);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });
  });

  testWidgets('Hebrew: the first theme is at the right, the check at the top left', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpThemed(
      tester,
      Padding(
        padding: const EdgeInsets.all(20),
        child: ThemeSwatchPicker(value: AppThemeMode.light, onChanged: (_) {}),
      ),
      hebrew: true,
    );
    final light = tester.getRect(swatch('בהירה'));
    expect(light.right, 412 - 20);
    final check = tester.getRect(find.byIcon(Icons.check));
    expect(check.left - light.left, lessThan(12));
  });

  group('with the real fonts', () {
    setUpAll(loadBundledFonts);

    for (final hebrew in [false, true]) {
      testWidgets('at 300% on a 320 dp phone, keeps every name whole${hebrew ? ', in Hebrew' : ''}', (tester) async {
        tester.view.physicalSize = const Size(320, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pumpThemed(
          tester,
          SingleChildScrollView(
            // The page's gutters there.
            padding: const EdgeInsets.all(16),
            child: ThemeSwatchPicker(value: AppThemeMode.highContrastDark, onChanged: (_) {}),
          ),
          hebrew: hebrew,
          textScale: 3,
        );
        expect(tester.takeException(), isNull);
        expectWholeWords(tester);
      });
    }
  });
}
