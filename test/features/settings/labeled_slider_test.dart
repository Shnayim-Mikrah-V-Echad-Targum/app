import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/settings/widgets/settings_widgets.dart';

import '../../helpers.dart';

/// docs/DESIGN_SYSTEM.md §6.8: a slider with its value at the end, and −/+
/// buttons for readers who can't drag precisely.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    bool hebrew = false,
    ValueChanged<double>? onChanged,
    double textScale = 1,
  }) =>
      pumpThemed(
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
        textScale: textScale,
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

  group('with the real fonts', () {
    setUpAll(loadBundledFonts);

    for (final hebrew in [false, true]) {
      // A word of the title too wide to stand beside the value at its size
      // takes the line, and the value goes under it, rather than either
      // being squeezed.
      testWidgets('at 300% on a 320 dp phone, sets the value under the whole title${hebrew ? ', in Hebrew' : ''}',
          (tester) async {
        tester.view.physicalSize = const Size(320 - 2 * 16, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pump(tester, hebrew: hebrew, textScale: 3);
        expect(tester.takeException(), isNull);
        expectWholeWords(tester);
        final titleFinder = find.text(hebrew ? 'גודל הקריאה' : 'Reading size');
        final title = tester.getRect(titleFinder);
        // At its full size, as laid out, not set smaller to fit.
        expect(title.width, moreOrLessEquals(tester.getSize(titleFinder).width, epsilon: 0.01));
        final value = tester.getRect(find.text('120%'));
        expect(value.top, greaterThanOrEqualTo(title.bottom - 0.5));
        // At the start of the line, under the title.
        expect(hebrew ? value.right : value.left, moreOrLessEquals(hebrew ? title.right : title.left, epsilon: 0.5));
      });

      testWidgets('at 100%, sets the value at the end of the title\'s line${hebrew ? ', in Hebrew' : ''}',
          (tester) async {
        tester.view.physicalSize = const Size(320 - 2 * 16, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pump(tester, hebrew: hebrew);
        final title = tester.getRect(find.text(hebrew ? 'גודל הקריאה' : 'Reading size'));
        final value = tester.getRect(find.text('120%'));
        expect(value.center.dy, moreOrLessEquals(title.center.dy, epsilon: 1));
        expect(hebrew ? value.left : value.right, moreOrLessEquals(hebrew ? 16 : 320 - 2 * 16 - 16, epsilon: 0.5));
        expect(hebrew ? title.left - value.right : value.left - title.right, greaterThanOrEqualTo(12));
      });
    }
  });
}
