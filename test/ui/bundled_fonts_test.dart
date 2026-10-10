import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/services/optional_fonts.dart';

import '../helpers.dart';

/// The display fonts of docs/DESIGN_SYSTEM.md §4.1: declared with exactly the
/// weights the type system asks for, and real enough to change text metrics.
void main() {
  setUpAll(loadBundledFonts);

  Future<List<Map<String, dynamic>>> manifest() async =>
      (jsonDecode(await rootBundle.loadString('FontManifest.json')) as List).cast<Map<String, dynamic>>();

  /// `weight style` for each file of [family], e.g. `{'500 normal', '500 italic'}`.
  Future<Set<String>> faces(String family) async {
    final entry = (await manifest()).firstWhere((f) => f['family'] == family);
    return {
      for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>())
        '${font['weight'] ?? 400} ${font['style'] ?? 'normal'}',
    };
  }

  test('EB Garamond and Frank Ruhl Libre bundle 500, 600 and 700, and no 400', () async {
    expect(await faces('EBGaramond'), {'500 normal', '600 normal', '700 normal', '500 italic'});
    expect(await faces('FrankRuhlLibre'), {'500 normal', '600 normal', '700 normal'});
  });

  test('the Rashi script is not in the font manifest, so the web never preloads it', () async {
    final assets = [
      for (final family in await manifest())
        for (final font in (family['fonts'] as List).cast<Map<String, dynamic>>()) font['asset'] as String,
    ];
    expect(assets, isNot(contains(contains('Rashi'))));
    expect((await manifest()).map((f) => f['family']), isNot(contains('NotoRashiHebrew')));
    // It still ships, as a plain asset.
    final bytes = await rootBundle.load('assets/fonts/rashi/NotoRashiHebrew-Regular.ttf');
    expect(bytes.lengthInBytes, greaterThan(10000));
  });

  test('the opt-in fonts are not in the font manifest either, but ship as plain assets', () async {
    final declared = {for (final family in await manifest()) family['family'] as String};
    for (final family in OptionalFonts.families) {
      expect(declared, isNot(contains(family)));
      for (final file in OptionalFonts.filesOf(family)) {
        expect(file, startsWith(family == 'NotoRashiHebrew' ? 'assets/fonts/rashi/' : 'assets/fonts/optional/'));
        expect((await rootBundle.load(file)).lengthInBytes, greaterThan(10000), reason: file);
      }
    }
  });

  test('every font a setting can choose is bundled or loaded on demand', () async {
    final declared = {for (final family in await manifest()) family['family'] as String};
    final families = {
      for (final f in ScriptureFont.values) f.family,
      for (final f in UiFont.values) ?f.family,
    };
    for (final family in families) {
      expect(declared.contains(family) || OptionalFonts.families.contains(family), isTrue, reason: family);
    }
    // The defaults never wait for a download.
    expect(declared, containsAll(['NotoSerifHebrew', 'NotoSans', 'NotoSansHebrew']));
  });

  group('text metrics', () {
    Future<double> width(WidgetTester tester, String text, TextStyle style) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: Text(text, style: style.copyWith(fontSize: 24))),
      ));
      return tester.getSize(find.text(text)).width;
    }

    // Unregistered families render in the test font, whose glyphs are all
    // one em wide.
    const testFont = TextStyle(fontFamily: 'NoSuchFamily');

    testWidgets('EB Garamond replaces the test font', (tester) async {
      const text = 'Shnayim Mikra';
      final garamond = await width(tester, text, const TextStyle(fontFamily: 'EBGaramond', fontWeight: FontWeight.w500));
      expect(await width(tester, text, testFont), 24.0 * text.length);
      expect(garamond, lessThan(24.0 * text.length * 0.7));
    });

    testWidgets('each EB Garamond weight and the italic is a separate face', (tester) async {
      // A missing weight would snap to its neighbour and measure the same:
      // w600 used to come out as Bold.
      const text = 'Revi’i, the fourth aliyah';
      Future<double> garamond(FontWeight weight, [FontStyle style = FontStyle.normal]) =>
          width(tester, text, TextStyle(fontFamily: 'EBGaramond', fontWeight: weight, fontStyle: style));
      final widths = [
        await garamond(FontWeight.w500),
        await garamond(FontWeight.w600),
        await garamond(FontWeight.w700),
        await garamond(FontWeight.w500, FontStyle.italic),
      ];
      expect(widths.toSet(), hasLength(4), reason: '$widths');
    });

    testWidgets('Frank Ruhl Libre covers Hebrew with nikud', (tester) async {
      const text = 'בְּרֵאשִׁית';
      final frank = await width(tester, text, const TextStyle(fontFamily: 'FrankRuhlLibre', fontWeight: FontWeight.w500));
      expect(frank, isNot(await width(tester, text, testFont)));
      expect(frank, lessThan(24.0 * 6));
    });
  });
}
