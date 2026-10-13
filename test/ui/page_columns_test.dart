import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/ui/theme/layout.dart';
import 'package:shnayim_mikra/ui/widgets/page_columns.dart';

import '../helpers.dart';

/// docs/DESIGN_SYSTEM.md §9 (Today 9, Progress 10, Parsha tab 6): a page's
/// two columns on a desktop, and the one column they make below it.
void main() {
  /// Columns 976 wide, as in a container of 1040 within its gutters: two
  /// boxes and a button at the start, and a box 300 high, or [endChild], at
  /// the end.
  Future<void> pump(
    WidgetTester tester, {
    required bool wide,
    int? startFlex,
    int? endFlex,
    double? stackedGap,
    bool hebrew = false,
    Widget? endChild,
  }) {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return pumpThemed(
      tester,
      hebrew: hebrew,
      Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 976,
          child: PageColumns(
            wide: wide,
            startFlex: startFlex ?? 7,
            endFlex: endFlex ?? 5,
            stackedGap: stackedGap ?? Rhythm.cardGap,
            start: [
              const SizedBox(key: Key('a'), height: 60),
              const SizedBox(key: Key('b'), height: 40),
              ElevatedButton(onPressed: () {}, child: const Text('Start')),
            ],
            end: [endChild ?? const SizedBox(key: Key('end'), height: 300)],
          ),
        ),
      ),
    );
  }

  Rect rect(WidgetTester tester, String key) => tester.getRect(find.byKey(Key(key)));

  testWidgets('sets seven parts and five side by side, 24 apart and level at the top', (tester) async {
    await pump(tester, wide: true);
    final start = rect(tester, 'a');
    final end = rect(tester, 'end');
    expect(start.width, moreOrLessEquals((976 - 24) * 7 / 12));
    expect(end.width, moreOrLessEquals((976 - 24) * 5 / 12));
    expect(end.left - start.right, moreOrLessEquals(24));
    expect(end.top, start.top);
  });

  testWidgets('takes the shares it is given: five and seven for Progress and a week', (tester) async {
    await pump(tester, wide: true, startFlex: 5, endFlex: 7);
    expect(rect(tester, 'a').width, moreOrLessEquals((976 - 24) * 5 / 12));
    expect(rect(tester, 'end').width, moreOrLessEquals((976 - 24) * 7 / 12));
  });

  testWidgets('mirrors in Hebrew, the first column at the right', (tester) async {
    await pump(tester, wide: true, hebrew: true);
    expect(rect(tester, 'a').left, greaterThan(rect(tester, 'end').right));
  });

  testWidgets("until wide, stands the first over the second, a card's gap apart, or the gap it is given",
      (tester) async {
    await pump(tester, wide: false);
    final button = tester.getRect(find.byType(ElevatedButton));
    expect(rect(tester, 'a').width, 976);
    expect(rect(tester, 'end').width, 976);
    expect(rect(tester, 'end').top - button.bottom, Rhythm.cardGap);

    await pump(tester, wide: false, stackedGap: Rhythm.sectionGap);
    expect(rect(tester, 'end').top - tester.getRect(find.byType(ElevatedButton)).bottom, Rhythm.sectionGap);
  });

  testWidgets('keeps what its columns hold as it widens and narrows', (tester) async {
    final field = TextField(key: const Key('field'), controller: TextEditingController());
    await pump(tester, wide: true, endChild: field);
    await tester.tap(find.byKey(const Key('field')));
    await tester.enterText(find.byKey(const Key('field')), 'Bereshit');
    final state = tester.state(find.byType(EditableText));
    final focus = FocusManager.instance.primaryFocus;
    for (final wide in [false, true]) {
      await pump(tester, wide: wide, endChild: field);
      expect(tester.state(find.byType(EditableText)), same(state), reason: 'wide: $wide');
      expect(FocusManager.instance.primaryFocus, same(focus), reason: 'wide: $wide');
      expect(find.text('Bereshit'), findsOneWidget);
    }
  });

  /// Side by side: a control at the top of the start column, one 200 below
  /// it, and between the two, on the screen, one in the end column.
  Future<void> pumpStaggered(WidgetTester tester, Widget Function(String label) control) {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return pumpThemed(
      tester,
      Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 976,
          child: PageColumns(
            wide: true,
            start: [control('Start 1'), const SizedBox(height: 200), control('Start 2')],
            end: [const SizedBox(height: 100), control('End')],
          ),
        ),
      ),
    );
  }

  testWidgets('side by side, Tab goes down the first column before the second', (tester) async {
    await pumpStaggered(tester, (label) => TextButton(onPressed: () {}, child: Text(label)));
    Future<String> tabFrom(String label) async {
      Focus.of(tester.element(find.text(label))).requestFocus();
      await tester.pump();
      FocusManager.instance.primaryFocus!.nextFocus();
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus!.rect.center;
      return ['Start 1', 'Start 2', 'End']
          .firstWhere((l) => tester.getRect(find.text(l)).inflate(16).contains(focused));
    }

    // Not across to the end column's, though it stands higher.
    expect(await tabFrom('Start 1'), 'Start 2');
    expect(await tabFrom('Start 2'), 'End');
  });

  testWidgets('side by side, a screen reader reads the first column before the second', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpStaggered(tester, Text.new);
    final order = [
      for (final node in tester.semantics.simulatedAccessibilityTraversal())
        if (node.label.isNotEmpty) node.label,
    ];
    expect(order, ['Start 1', 'Start 2', 'End']);
    handle.dispose();
  });
}
