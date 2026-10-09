import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/palette.dart';
import 'package:shnayim_mikra/ui/widgets/progress_widgets.dart';

import '../helpers.dart';

/// docs/DESIGN_SYSTEM.md §7.6: the Shabbat candles, on a 24 grid.
void main() {
  RenderObject painter(WidgetTester tester) =>
      tester.renderObject(find.descendant(of: find.byType(ShabbatCandlesIcon), matching: find.byType(CustomPaint)));

  testWidgets('two bodies, each under its flame, in the rest colour', (tester) async {
    await pumpThemed(tester, const Center(child: ShabbatCandlesIcon()));
    expect(tester.getSize(find.byType(ShabbatCandlesIcon)), const Size(24, 24));
    final rest = Palettes.statusLight.rest;
    PaintPattern flame(double cx) => paints
      ..path(
        color: rest,
        // M cx,3 C cx+2.6,5.6 cx+2.2,9.5 cx,9.5 C …: widest a little below
        // the middle, a point at the top.
        includes: [Offset(cx, 4), Offset(cx, 9), Offset(cx + 1.5, 7), Offset(cx - 1.5, 7)],
        excludes: [Offset(cx, 2.5), Offset(cx, 10), Offset(cx + 1, 3.5), Offset(cx + 2.5, 7)],
      );
    expect(
      painter(tester),
      paints
        ..rrect(rrect: RRect.fromRectAndRadius(const Rect.fromLTWH(6.5, 11, 3.5, 10), const Radius.circular(0.8)), color: rest)
        ..path(color: rest)
        ..rrect(rrect: RRect.fromRectAndRadius(const Rect.fromLTWH(14, 11, 3.5, 10), const Radius.circular(0.8)), color: rest)
        ..path(color: rest),
    );
    expect(painter(tester), flame(8.25));
    // The second flame comes after the second body.
    expect(
      painter(tester),
      paints
        ..rrect()
        ..path()
        ..rrect()
        ..path(
          includes: const [Offset(15.75, 4), Offset(15.75, 9)],
          excludes: const [Offset(8.25, 7), Offset(15.75, 2.5)],
        ),
    );
  });

  testWidgets('scales the grid to its size', (tester) async {
    await pumpThemed(tester, const Center(child: ShabbatCandlesIcon(size: 48)));
    expect(tester.getSize(find.byType(ShabbatCandlesIcon)), const Size(48, 48));
    expect(painter(tester), paints..scale(x: 2, y: 2));
  });

  for (final (mode, status) in [
    (AppThemeMode.dark, Palettes.statusDark),
    (AppThemeMode.highContrastLight, Palettes.statusHcLight),
  ]) {
    testWidgets('${mode.name}: drawn in its rest colour unless given another', (tester) async {
      await pumpThemed(tester, const Center(child: ShabbatCandlesIcon()), theme: mode);
      expect(painter(tester), paints..rrect(color: status.rest));
      await pumpThemed(tester, Center(child: ShabbatCandlesIcon(color: status.grace)), theme: mode);
      expect(painter(tester), paints..rrect(color: status.grace));
    });
  }
}
