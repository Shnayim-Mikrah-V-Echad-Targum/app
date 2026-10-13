import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/features/reader/listen_along.dart';
import 'package:shnayim_mikrah/features/reader/listen_bar.dart';
import 'package:shnayim_mikrah/services/tts.dart';

import '../../helpers.dart';

/// docs/DESIGN_SYSTEM.md §6.28: the player's speech rate, with real glyph
/// metrics.
void main() {
  setUpAll(loadBundledFonts);

  Future<void> pump(
    WidgetTester tester,
    double width, {
    double rate = kDefaultSpeechRate,
    double textScale = 1,
    bool hebrew = false,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpThemed(
      tester,
      Align(
        alignment: Alignment.bottomCenter,
        child: ListenBar(
          paused: false,
          onPlayPause: () {},
          onPrevious: () {},
          onNext: () {},
          rate: rate,
          onRate: (_) {},
          onStop: () {},
          // The reading column, within the page's 16 either side.
          maxWidth: width - 32,
        ),
      ),
      textScale: textScale,
      hebrew: hebrew,
    );
  }

  final speed = find.byIcon(Icons.speed_rounded);

  /// The scale the rate's label is set at, to fit.
  double labelScale(WidgetTester tester, String label) =>
      tester.getSize(find.byType(FittedBox)).width / tester.getSize(find.text(label)).width;

  // Wherever it shows: in the reader, and on the haftarah's page.
  testWidgets('grows with the text to 200%, and no more', (tester) async {
    await pump(tester, 412);
    final normal = tester.getSize(find.byType(ListenBar));
    final label = tester.getSize(find.text('Normal'));
    await pump(tester, 412, textScale: 2);
    final double = tester.getSize(find.byType(ListenBar));
    expect(tester.getSize(find.text('Normal')).height, greaterThanOrEqualTo(label.height * 1.8));
    await pump(tester, 412, textScale: 3);
    expect(tester.getSize(find.byType(ListenBar)), double);
    expect(double.height, greaterThanOrEqualTo(normal.height));
  });

  group("The player's speech rate", () {
    testWidgets('keeps its icon beside "Normal" on a 360 dp phone, at the column\'s edge', (tester) async {
      await pump(tester, 360);
      expect(speed, findsOneWidget);
      expect(tester.getRect(speed).left, 16);
      expect(labelScale(tester, 'Normal'), greaterThanOrEqualTo(0.9), reason: 'set a little smaller at most');
      // From 375 dp, at its full size.
      for (final width in [375.0, 412.0]) {
        await pump(tester, width);
        expect(speed, findsOneWidget);
        expect(labelScale(tester, 'Normal'), 1, reason: '$width');
      }
    });

    testWidgets('keeps its icon at any rate the menu offers', (tester) async {
      for (final rate in speechRatesWith(kDefaultSpeechRate)) {
        await pump(tester, 360, rate: rate);
        expect(speed, findsOneWidget, reason: '$rate');
      }
      await pump(tester, 360, hebrew: true);
      expect(speed, findsOneWidget);
      expect(tester.getRect(speed).right, 360 - 16);
    });

    testWidgets('lets its icon go where the rate has no room beside it, and never cuts the rate short',
        (tester) async {
      // A phone narrower than 356 dp, and 200% text on a 412 dp one.
      for (final (width, scale) in [(320.0, 1.0), (412.0, 2.0)]) {
        await pump(tester, width, textScale: scale);
        expect(speed, findsNothing, reason: '$width at $scale');
        final fitted = tester.getRect(find.byType(FittedBox));
        expect(fitted.width, lessThanOrEqualTo(tester.getRect(find.byType(TextButton)).width));
        expect(tester.takeException(), isNull);
      }
    });
  });
}
