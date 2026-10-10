// Every character of the interface's text is drawn by the bundled interface
// fonts. A character they lack shows in whatever font the device falls back
// to, or as a blank where it has none, and on the web makes the engine fetch
// a font from Google Fonts, a request the app otherwise never makes
// (DESIGN.md §9). Arrows (→ ←), ⌘ and ⌥ are among those the fonts lack.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../helpers.dart';

/// The characters the font at [path] has glyphs for, from its cmap table's
/// format 4 (BMP) and format 12 (full Unicode) subtables.
Set<int> _charactersOf(String path) {
  final b = ByteData.sublistView(File(path).readAsBytesSync());
  var cmap = -1;
  for (var i = 0; i < b.getUint16(4); i++) {
    final record = 12 + 16 * i;
    if (String.fromCharCodes(Uint8List.sublistView(b, record, record + 4)) == 'cmap') cmap = b.getUint32(record + 8);
  }
  final chars = <int>{};
  for (var i = 0; i < b.getUint16(cmap + 2); i++) {
    final sub = cmap + b.getUint32(cmap + 4 + 8 * i + 4);
    switch (b.getUint16(sub)) {
      case 4:
        final segments = b.getUint16(sub + 6) ~/ 2;
        final ends = sub + 14, starts = ends + 2 * segments + 2, deltas = starts + 2 * segments;
        final rangeOffsets = deltas + 2 * segments;
        for (var s = 0; s < segments; s++) {
          final start = b.getUint16(starts + 2 * s), end = b.getUint16(ends + 2 * s);
          final delta = b.getUint16(deltas + 2 * s), rangeOffset = b.getUint16(rangeOffsets + 2 * s);
          for (var c = start; c <= end && c != 0xFFFF; c++) {
            final glyph = rangeOffset == 0 ? c : b.getUint16(rangeOffsets + 2 * s + rangeOffset + 2 * (c - start));
            if (glyph != 0 && (glyph + delta) & 0xFFFF != 0) chars.add(c);
          }
        }
      case 12:
        for (var g = 0; g < b.getUint32(sub + 12); g++) {
          final group = sub + 16 + 12 * g;
          final start = b.getUint32(group), end = b.getUint32(group + 4), glyph = b.getUint32(group + 8);
          for (var c = start; c <= end; c++) {
            if (glyph + c - start != 0) chars.add(c);
          }
        }
    }
  }
  return chars;
}

/// Characters no font draws anyway: controls, directional marks and
/// isolates, joiners and soft hyphens; and the private-use characters that
/// Material icons are drawn with, in their own font.
bool _drawnByNoFont(int c) =>
    c < 0x20 ||
    (c >= 0x200B && c <= 0x200F) ||
    (c >= 0x202A && c <= 0x202E) ||
    (c >= 0x2060 && c <= 0x2069) ||
    c == 0xFEFF ||
    c == 0xAD ||
    (c >= 0xE000 && c <= 0xF8FF);

void main() {
  // The English and Hebrew interface fonts, each the other's fallback.
  final drawn = {
    for (final font in ['NotoSans-Regular.ttf', 'NotoSansHebrew-Regular.ttf']) ..._charactersOf('assets/fonts/$font'),
  };
  String missing(String text) => String.fromCharCodes(
      text.runes.toSet().where((c) => !_drawnByNoFont(c) && !drawn.contains(c)));

  test('the interface strings, in English and Hebrew', () {
    for (final arb in ['lib/l10n/app_en.arb', 'lib/l10n/app_he.arb']) {
      final strings = jsonDecode(File(arb).readAsStringSync()) as Map<String, dynamic>;
      strings.forEach((key, value) {
        if (value is String) expect(missing(value), isEmpty, reason: '$arb: $key');
      });
    }
  });

  for (final language in [AppLanguage.english, AppLanguage.hebrew]) {
    testWidgets('the policies and the sources, in ${language.name}', (tester) async {
      // Tall enough that every section of the longest is built.
      tester.view.physicalSize = const Size(800, 40000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await pumpApp(tester, settings: AppSettings(onboardingComplete: true, language: language));
      for (final page in ['/legal/privacy', '/legal/terms', '/legal/guidelines', '/legal/accessibility', '/sources']) {
        c.read(routerProvider).go(page);
        await tester.pumpAndSettle();
        final texts = [
          for (final t in tester.widgetList<RichText>(find.byType(RichText))) t.text.toPlainText(),
          for (final t in tester.widgetList<SelectableText>(find.byType(SelectableText)))
            t.data ?? t.textSpan!.toPlainText(),
        ];
        expect(texts, isNotEmpty);
        for (final text in texts) {
          expect(missing(text), isEmpty, reason: '$page: $text');
        }
      }
    });
  }
}
