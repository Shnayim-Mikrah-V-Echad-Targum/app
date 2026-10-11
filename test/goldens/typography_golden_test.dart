import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/app_theme.dart';

import '../helpers.dart';
import 'tolerant_comparator.dart';

/// Headings that mix Latin and Hebrew, or carry points, in titleLarge and
/// hebrewDisplay, for each interface font in each language of the app
/// (docs/DESIGN_SYSTEM.md §11.4). A letter or point missing from a style's
/// font is drawn by its fallbacks (§4.2), or as a box ("tofu"), which the
/// golden would show.
///
///   flutter test --update-goldens test/goldens/typography_golden_test.dart
void main() {
  setUpAll(() async {
    await loadBundledFonts();
    useTolerantGoldens();
  });

  const samples = ["Revi'i · רביעי", 'בְּרֵאשִׁית'];
  // The system font is the platform's: not the same from one machine to
  // the next.
  final fonts = UiFont.values.where((f) => f != UiFont.system);

  /// The samples in [uiFont]'s titleLarge, and then in hebrewDisplay (a
  /// serif that is never the interface font's), under the font's name.
  Widget samplesIn(UiFont uiFont, {required bool hebrew}) => Theme(
        data: AppTheme.build(mode: AppThemeMode.light, uiFont: uiFont, hebrewUi: hebrew, reduceMotion: false),
        child: Builder(builder: (context) {
          final theme = Theme.of(context);
          final display = SeferType.of(context).hebrewDisplay.copyWith(fontSize: 28);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(uiFont.name, style: theme.textTheme.labelSmall),
                for (final style in [theme.textTheme.titleLarge, display])
                  Wrap(spacing: 24, children: [for (final s in samples) Text(s, style: style)]),
              ],
            ),
          );
        }),
      );

  for (final hebrew in [false, true]) {
    final language = hebrew ? 'he' : 'en';
    testWidgets('mixed headings, $language', (tester) async {
      tester.view.physicalSize = const Size(412, 440);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpThemed(
        tester,
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final f in fonts) samplesIn(f, hebrew: hebrew)],
          ),
        ),
        hebrew: hebrew,
      );
      await expectLater(find.byType(Scaffold), matchesGoldenFile('typography/mixed_headings_$language.png'));
    }, skip: goldensSkipped);
  }
}
