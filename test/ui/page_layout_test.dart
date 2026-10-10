import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/ui/theme/layout.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';

import '../helpers.dart';

void main() {
  group('layout tokens', () {
    test('the gutters follow the window: 20, 24 from 600 and 32 from 1200', () {
      expect(Gutter.forWidth(360), 20);
      expect(Gutter.forWidth(599), 20);
      expect(Gutter.forWidth(600), 24);
      expect(Gutter.forWidth(1199), 24);
      expect(Gutter.forWidth(1200), 32);
      expect(Gutter.forWidth(1366), 32);
    });

    test('the spacing scale is on the 4 pt grid', () {
      for (final step in [Space.xs, Space.sm, Space.md, Space.lg, Space.xl, Space.xxl, Space.s28, Space.s32, Space.s40, Space.s48]) {
        expect(step % 4, 0, reason: '$step');
      }
      expect([ContentWidth.list, ContentWidth.longform, ContentWidth.account, ContentWidth.todayWide], [720, 620, 440, 1040]);
    });
  });

  group('PageBody', () {
    Future<void> pumpBody(WidgetTester tester, Size size, {EdgeInsets safeArea = EdgeInsets.zero}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding(bottom: safeArea.bottom);
      addTearDown(tester.view.reset);
      await pumpThemed(tester, const PageBody(children: [SizedBox(height: 10, key: Key('first'))]));
    }

    for (final (width, gutter) in [(412.0, 20.0), (800.0, 24.0), (1366.0, 32.0)]) {
      testWidgets('lays a ${width.round()} dp window out in a column of 720 at most, with $gutter dp gutters',
          (tester) async {
        await pumpBody(tester, Size(width, 900));
        final first = tester.getRect(find.byKey(const Key('first')));
        final column = width < 720 ? width : 720.0;
        expect(first.left, (width - column) / 2 + gutter);
        expect(first.width, column - 2 * gutter);
        expect(first.top, 8);
      });
    }

    testWidgets('ends 40 below its content, and clears the gesture bar of a page over the whole screen',
        (tester) async {
      await pumpBody(tester, const Size(412, 50), safeArea: const EdgeInsets.only(bottom: 24));
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      // 8 above, 10 of content, then 40 and the 24 of the gesture bar.
      expect(scrollable.position.maxScrollExtent + scrollable.position.viewportDimension, 8 + 10 + 40 + 24);
    });
  });
}
