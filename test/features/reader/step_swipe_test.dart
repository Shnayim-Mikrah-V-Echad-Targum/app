import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/features/reader/step_swipe.dart';

void main() {
  Future<({List<String> log})> pumpSwipe(WidgetTester tester, TextDirection direction) async {
    final log = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: StepSwipe(
          onNext: () => log.add('next'),
          onBack: () => log.add('back'),
          child: const SizedBox.expand(key: ValueKey('step')),
        ),
      ),
    ));
    return (log: log);
  }

  testWidgets('in a left-to-right text, a swipe to the left goes on and a swipe to the right goes back', (tester) async {
    final swipe = await pumpSwipe(tester, TextDirection.ltr);
    await tester.fling(find.byKey(const ValueKey('step')), const Offset(-300, 0), 1000);
    await tester.fling(find.byKey(const ValueKey('step')), const Offset(300, 0), 1000);
    expect(swipe.log, ['next', 'back']);
  });

  testWidgets('in Hebrew, the next page lies to the left, so a swipe to the right goes on', (tester) async {
    final swipe = await pumpSwipe(tester, TextDirection.rtl);
    await tester.fling(find.byKey(const ValueKey('step')), const Offset(300, 0), 1000);
    await tester.fling(find.byKey(const ValueKey('step')), const Offset(-300, 0), 1000);
    expect(swipe.log, ['next', 'back']);
  });

  testWidgets('a slow drag is a scroll, not a page turn', (tester) async {
    final swipe = await pumpSwipe(tester, TextDirection.ltr);
    await tester.fling(find.byKey(const ValueKey('step')), const Offset(-300, 0), 100);
    expect(swipe.log, isEmpty);
  });
}
