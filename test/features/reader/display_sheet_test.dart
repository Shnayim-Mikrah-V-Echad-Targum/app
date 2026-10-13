import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/features/reader/display_sheet.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';

import '../../helpers.dart';

/// The reader's display sheet (docs/DESIGN_SYSTEM.md §9 Settings, "Reader
/// display sheet"): its scripture fonts as chips that share the width.
void main() {
  Future<void> openSheet(WidgetTester tester, {double width = 412, double textScale = 1}) async {
    // Tall, so that the sheet, opened at 42% of it, lays out every chip.
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await pumpApp(tester, settings: const AppSettings(onboardingComplete: true, scriptureFont: ScriptureFont.ezra));
    await tester.pumpAndSettle();
    showDisplaySheet(tester.element(find.byType(Scaffold).first));
    await tester.pumpAndSettle();
  }

  /// The chips, by the top of each, in order.
  List<double> chipTops(WidgetTester tester) => [
        for (final chip in find.byType(ChoiceChip).evaluate()) tester.getTopLeft(find.byWidget(chip.widget)).dy,
      ];

  testWidgets('four fonts across where the word fits so, as on a tablet', (tester) async {
    await openSheet(tester, width: 600);
    final tops = chipTops(tester);
    expect(tops, hasLength(4));
    expect(tops.toSet(), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('two across on a phone', (tester) async {
    await openSheet(tester);
    final tops = chipTops(tester);
    expect(tops[0], tops[1]);
    expect(tops[2], tops[3]);
    expect(tops[2], greaterThan(tops[0]));
  });

  for (final width in [412.0, 320.0]) {
    testWidgets('one under another with very large text, ${width.round()} dp wide', (tester) async {
      await openSheet(tester, width: width, textScale: 2);
      final tops = chipTops(tester);
      for (var i = 1; i < tops.length; i++) {
        expect(tops[i], greaterThan(tops[i - 1]), reason: 'chip ${i + 1}');
      }
      expect(tester.takeException(), isNull, reason: 'nothing overflows');
    });
  }

  testWidgets("the chosen font's sample is underlined, a mark that doesn't rest on colour", (tester) async {
    await openSheet(tester);
    final primary = Theme.of(tester.element(find.byType(BottomSheet))).colorScheme.primary;
    Iterable<Color> marks(String name) => [
          for (final box in tester.widgetList<ColoredBox>(find.descendant(
            of: find.ancestor(
              of: find.byWidgetPredicate((w) => w is Text && w.semanticsLabel == name),
              matching: find.byType(ChoiceChip),
            ),
            matching: find.byType(ColoredBox),
          )))
            box.color,
        ];
    expect(marks('Ezra SIL'), contains(primary));
    for (final other in ['Noto Serif Hebrew', 'Taamey Frank (classic Chumash)']) {
      expect(marks(other), isNot(contains(primary)), reason: other);
    }
  });
}
