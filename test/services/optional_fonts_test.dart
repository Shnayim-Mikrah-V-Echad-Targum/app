import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/services/optional_fonts.dart';

/// An asset bundle that has none of the files asked for.
class _MissingAssets extends CachingAssetBundle {
  int requests = 0;

  @override
  Future<ByteData> load(String key) async {
    requests++;
    throw FlutterError('Unable to load asset: "$key".');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Each test starts as if the app had just launched, whatever ran before.
  setUp(OptionalFonts.reset);

  test('bundled and missing families need no loading', () async {
    final assets = _MissingAssets();
    await OptionalFonts.ensure(null, bundle: assets);
    await OptionalFonts.ensure('EBGaramond', bundle: assets);
    expect(assets.requests, 0);
  });

  test('a failed load is not cached, so the next call tries again', () async {
    final assets = _MissingAssets();
    final first = OptionalFonts.ensure('NotoRashiHebrew', bundle: assets);
    await expectLater(first, throwsA(isA<FlutterError>()));
    final second = OptionalFonts.ensure('NotoRashiHebrew', bundle: assets);
    expect(second, isNot(same(first)));
    await expectLater(second, throwsA(isA<FlutterError>()));
    expect(assets.requests, 2);
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
