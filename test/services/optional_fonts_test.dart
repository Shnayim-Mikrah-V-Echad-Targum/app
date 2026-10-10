import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/services/optional_fonts.dart';

import '../helpers.dart';

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

  test('loading several never fails, even when a family cannot be loaded', () async {
    final reported = <String?>[];
    final print = debugPrint;
    debugPrint = (message, {wrapWidth}) => reported.add(message);
    addTearDown(() => debugPrint = print);

    final assets = _MissingAssets();
    await OptionalFonts.ensureAll(['Lexend', 'Lexend', null, 'EBGaramond', 'TaameyFrank'], bundle: assets);
    expect(assets.requests, 2, reason: 'each family the bundle lacks is asked for once');
    expect(reported, [startsWith('Font Lexend unavailable'), startsWith('Font TaameyFrank unavailable')]);
    expect(OptionalFonts.isRequested('Lexend'), isFalse, reason: 'and can be tried again');
  });

  testWidgets('the interface fonts load on demand, each weight a face of its own', (tester) async {
    const text = 'Shnayim Mikra';
    Future<double> width(String family, FontWeight weight) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: Text(text, style: TextStyle(fontFamily: family, fontWeight: weight, fontSize: 24))),
      ));
      return tester.getSize(find.text(text)).width;
    }

    const families = ['AtkinsonHyperlegibleNext', 'Lexend', 'OpenDyslexic'];
    await tester.runAsync(() => OptionalFonts.ensureAll(families));
    await tester.pump();
    for (final family in families) {
      final regular = await width(family, FontWeight.w400);
      // The test font, which stands in for a family not registered, draws
      // every letter one em wide.
      expect(regular, lessThan(24.0 * text.length), reason: family);
      expect(await width(family, FontWeight.w700), isNot(regular), reason: '$family: Bold is its own face');
    }
  });

  testWidgets('the app loads an opt-in font as soon as it is chosen', (tester) async {
    final c = await pumpApp(tester);
    expect(OptionalFonts.isRequested('Lexend'), isFalse);
    expect(OptionalFonts.isRequested('TaameyFrank'), isFalse);

    c.read(settingsProvider.notifier).update((s) => s.copyWith(uiFont: UiFont.lexend));
    await tester.pump();
    expect(OptionalFonts.isRequested('Lexend'), isTrue);

    c.read(settingsProvider.notifier).update((s) => s.copyWith(scriptureFont: ScriptureFont.taameyFrank));
    await tester.pump();
    expect(OptionalFonts.isRequested('TaameyFrank'), isTrue);
    expect(OptionalFonts.isRequested('EzraSIL'), isFalse, reason: 'only what is chosen');
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
