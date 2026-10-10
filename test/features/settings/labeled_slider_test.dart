import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/settings/widgets/settings_widgets.dart';

import '../../helpers.dart';

/// docs/DESIGN_SYSTEM.md §6.8: a slider with its value at the end, and −/+
/// buttons for readers who can't drag precisely.
void main() {
  Future<void> pump(WidgetTester tester, {bool hebrew = false, ValueChanged<double>? onChanged}) => pumpThemed(
        tester,
        LabeledSlider(
          title: hebrew ? 'גודל הקריאה' : 'Reading size',
          value: 1.2,
          min: 1,
          max: 2,
          step: 0.1,
          format: (v) => '${(v * 100).round()}%',
          onChanged: onChanged ?? (_) {},
        ),
        hebrew: hebrew,
      );

  testWidgets('the value is set in tabular figures, so it holds still as it changes', (tester) async {
    await pump(tester);
    final value = tester.widget<Text>(find.text('120%'));
    expect(value.style!.fontFeatures, contains(const FontFeature.tabularFigures()));
    expect(value.style!.fontSize, Theme.of(tester.element(find.text('120%'))).textTheme.labelLarge!.fontSize);
  });

  testWidgets('the − and + buttons say what they do to the slider, and step it', (tester) async {
    final values = <double>[];
    await pump(tester, onChanged: values.add);
    await tester.tap(find.byTooltip('Decrease Reading size'));
    await tester.tap(find.byTooltip('Increase Reading size'));
    expect(values.map((v) => v.toStringAsFixed(1)), ['1.1', '1.3']);

    final handle = tester.ensureSemantics();
    expect(tester.getSemantics(find.byIcon(Icons.add)), isSemantics(tooltip: 'Increase Reading size', isButton: true));
    handle.dispose();
  });

  testWidgets('Hebrew: the buttons are named in Hebrew', (tester) async {
    await pump(tester, hebrew: true);
    expect(find.byTooltip('הקטנת גודל הקריאה'), findsOneWidget);
    expect(find.byTooltip('הגדלת גודל הקריאה'), findsOneWidget);
  });
}
