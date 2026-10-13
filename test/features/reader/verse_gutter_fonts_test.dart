import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/data/models/scripture.dart';
import 'package:shnayim_mikra/data/models/verse_ref.dart';
import 'package:shnayim_mikra/features/reader/scripture_text.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/widgets/fonts_change_scope.dart';

import '../../helpers.dart';

/// The guided reader's verse-number gutter as a font arrives: measured
/// first in the test font, whose letters are an em wide, and then in Frank
/// Ruhl Libre as it loads. The bundled fonts are loaded within the test, so
/// this file keeps to it.
void main() {
  // Genesis 41:49: מט, among the widest of the numbers.
  final grain = Verse.fromJson(const VerseRef(41, 49), ['וַיִּצְבֹּר יוֹסֵף בָּר כְּחוֹל הַיָּם הַרְבֵּה מְאֹד']);

  /// The gutter's width, having checked that the number is set on one line
  /// within it.
  double gutterOf(WidgetTester tester, String reason) {
    final number = find.text('מט');
    final gutter = tester.getRect(find.ancestor(of: number, matching: find.byType(SizedBox)).first);
    final paragraph = tester.renderObject<RenderParagraph>(find.descendant(of: number, matching: find.byType(RichText)));
    final glyphs = paragraph.getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 2));
    expect({for (final b in glyphs) b.top.round()}, hasLength(1), reason: '$reason: on one line');
    final origin = tester.getTopLeft(number).dx;
    expect(origin + glyphs.map((b) => b.right).reduce(math.max), lessThanOrEqualTo(gutter.right + 0.01), reason: reason);
    return gutter.width;
  }

  testWidgets('the gutter is measured again when a font arrives', (tester) async {
    Future<void> pump({double textScale = 1}) => pumpThemed(
          tester,
          FontsChangeScope(
            child: ScriptureVerse(verse: grain, kind: ScriptureKind.mikra, settings: const AppSettings(), hangingNumber: true),
          ),
          textScale: textScale,
        );
    await pump();
    final stand = gutterOf(tester, 'in the test font');
    final styles = ScriptureStyles(tester.element(find.byType(ScriptureVerse)), const AppSettings());
    // The test font's letters are an em wide: מט is two.
    expect(stand, closeTo((2 * 26 * 0.55).ceilToDouble() + styles.numberGapWidth, 0.01));

    // Loading a font announces its arrival to the framework, as the web's
    // fonts and the Rashi script do as they load.
    await tester.runAsync(loadBundledFonts);
    await tester.pump();
    final loaded = gutterOf(tester, 'in Frank Ruhl Libre');
    expect(loaded, lessThan(stand - 5), reason: "not the stand-in's widths");

    // The real font's numbers keep to one line at large text and in bold.
    await pump(textScale: 2);
    gutterOf(tester, 'at 200%');
    await pumpThemed(
      tester,
      ScriptureVerse(verse: grain, kind: ScriptureKind.mikra, settings: const AppSettings(), hangingNumber: true),
      textScale: 2,
      boldText: true,
    );
    gutterOf(tester, 'at 200%, bold');
  });
}
