import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/ui/theme/app_theme.dart';
import 'package:shnayim_mikrah/ui/theme/palette.dart';

/// The press feedback where ink doesn't spread (§8): on Apple platforms, and
/// with motion reduced. A quick tap in a scroll view is pressed and released
/// in one frame, before the ink well's highlight has faded in, so only a
/// feature that shows at once and holds can be seen at all.
void main() {
  final wash = Palettes.light.onSurface.withValues(alpha: 0.10);

  Future<Finder> pumpRow(WidgetTester tester, {bool reduceMotion = false}) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(
        mode: AppThemeMode.light,
        uiFont: UiFont.standard,
        hebrewUi: false,
        reduceMotion: reduceMotion,
      ),
      home: Scaffold(
        body: ListView(
          children: [
            SizedBox(height: 72, child: SeferInkWell(onTap: () {}, child: const Text('Row'))),
          ],
        ),
      ),
    ));
    // The ink is painted on the Material the list lies on.
    return find.ancestor(of: find.byType(ListView), matching: find.byType(Material)).first;
  }

  testWidgets('on iOS, a quick tap on a row in a list washes it on the next frame, then fades', (tester) async {
    final material = await pumpRow(tester);
    await tester.tap(find.text('Row'));
    await tester.pump();
    // The whole row, clipped to its corners, in 10% of the ink.
    expect(material, paints..clipRRect()..circle(color: wash));
    await tester.pump(PressWash.hold);
    expect(material, paints..circle(), reason: 'still there, fading');
    await tester.pump(Motion.short + const Duration(milliseconds: 20));
    expect(material, isNot(paints..circle()));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('with motion reduced, the wash holds a moment and goes at once', (tester) async {
    final material = await pumpRow(tester, reduceMotion: true);
    await tester.tap(find.text('Row'));
    await tester.pump();
    expect(material, paints..circle(color: wash));
    await tester.pump(PressWash.reducedHold - const Duration(milliseconds: 20));
    expect(material, paints..circle(color: wash), reason: 'at full strength, without fading');
    await tester.pump(const Duration(milliseconds: 40));
    expect(material, isNot(paints..circle()));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a row held down stays washed until it is let go', (tester) async {
    final material = await pumpRow(tester);
    final press = await tester.startGesture(tester.getCenter(find.text('Row')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(material, paints..circle(color: wash));
    await press.up();
    await tester.pump();
    expect(material, paints..circle(color: wash), reason: 'held a moment after it is let go');
    await tester.pump(PressWash.hold + Motion.short + const Duration(milliseconds: 20));
    expect(material, isNot(paints..circle()));
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
