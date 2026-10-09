import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/services/optional_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only the lazily loaded families are optional', () {
    expect(OptionalFonts.isOptional('NotoRashiHebrew'), isTrue);
    expect(OptionalFonts.isOptional('EBGaramond'), isFalse);
    expect(OptionalFonts.isOptional(null), isFalse);
  });

  test('bundled and missing families need no loading', () async {
    await OptionalFonts.ensure(null);
    await OptionalFonts.ensure('EBGaramond');
  });

  test('a failed load is not cached, so the next call tries again', () async {
    // Keep this before the test that loads the font for real.
    var requests = 0;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (_) async {
      requests++;
      return null; // asset not found
    });
    addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));

    final first = OptionalFonts.ensure('NotoRashiHebrew');
    await expectLater(first, throwsA(isA<FlutterError>()));
    final second = OptionalFonts.ensure('NotoRashiHebrew');
    expect(second, isNot(same(first)));
    await expectLater(second, throwsA(isA<FlutterError>()));
    expect(requests, 2);
  });

  testWidgets('the Rashi script loads once, on demand, and text already shown picks it up', (tester) async {
    const text = 'רש״י';
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.rtl,
      child: Center(child: Text(text, style: TextStyle(fontFamily: 'NotoRashiHebrew', fontSize: 24))),
    ));
    // Not registered yet, so the test font (one em per letter) stands in.
    final before = tester.getSize(find.text(text)).width;
    expect(before, 24.0 * text.length);

    // Asset I/O is real, so it has to run outside the test's fake clock.
    await tester.runAsync(() async {
      final first = OptionalFonts.ensure('NotoRashiHebrew');
      expect(OptionalFonts.ensure('NotoRashiHebrew'), same(first));
      await first;
    });
    await tester.pump();

    expect(tester.getSize(find.text(text)).width, lessThan(before));
  });
}
