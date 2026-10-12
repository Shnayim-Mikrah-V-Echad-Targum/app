import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/palette.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';

import '../../helpers.dart';

/// The reader's app bar and the rule under it (DESIGN_SYSTEM.md §6.2): the
/// text scrolls under the aliyah ribbon, or in the whole parsha under its
/// aliyah's heading, which have rules of their own, so the app bar draws
/// none then; only in the full text's focus mode, with neither, does it.
void main() {
  final monday = DateTime(2026, 10, 12, 10); // week of Noach, 5787

  Future<void> open(WidgetTester tester, String path, AppSettings settings) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: settings, now: monday);
    c.read(routerProvider).go(path);
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 30 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  /// The rule the app bar's [ScrolledUnderRule] paints: its colour, or null
  /// for none.
  Color? rule(WidgetTester tester) {
    final paint = tester.renderObject<RenderCustomPaint>(
      find.descendant(of: find.byType(ScrolledUnderRule), matching: find.byType(CustomPaint)).first,
    );
    final canvas = TestRecordingCanvas();
    paint.foregroundPainter!.paint(canvas, paint.size);
    return [
      for (final call in canvas.invocations)
        if (call.invocation.memberName == #drawRect) (call.invocation.positionalArguments[1] as Paint).color,
    ].firstOrNull;
  }

  /// Drags the text up, and says how far it scrolled.
  Future<double> scrollText(WidgetTester tester) async {
    await tester.dragFrom(const Offset(206, 650), const Offset(0, -400));
    await tester.pumpAndSettle();
    final text = tester
        .stateList<ScrollableState>(find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down))
        .reduce((a, b) => a.position.maxScrollExtent >= b.position.maxScrollExtent ? a : b);
    return text.position.pixels;
  }

  const base = AppSettings(onboardingComplete: true, notificationPromptShown: true);

  for (final (name, path, settings, ruled) in [
    // A larger reading size, so that the guided reader's step scrolls.
    ('the guided reader', '/read/5787:2/0', base.copyWith(readingScale: 3), false),
    ('the full text, under its ribbon', '/read/5787:2/0?mode=full', base, false),
    ('the full text in focus mode, with no ribbon', '/read/5787:2/0?mode=full', base.copyWith(focusMode: true), true),
    (
      'the whole parsha in focus mode, under its aliyah\'s heading',
      '/read/5787:2/0?mode=full',
      base.copyWith(focusMode: true, fullTextWholeParsha: true),
      false,
    ),
  ]) {
    testWidgets('$name: ${ruled ? 'a hairline under the app bar' : 'no rule under the app bar'} as the text scrolls',
        (tester) async {
      await open(tester, path, settings);
      expect(rule(tester), isNull);
      expect(await scrollText(tester), greaterThan(0), reason: 'the text scrolled');
      if (ruled) {
        expect(rule(tester), isSameColorAs(Palettes.seferLight.hairline));
      } else {
        expect(rule(tester), isNull);
      }
    });
  }
}
