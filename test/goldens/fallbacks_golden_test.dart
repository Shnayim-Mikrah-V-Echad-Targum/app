import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/ui/widgets/fallbacks.dart';

import '../helpers.dart';
import 'tolerant_comparator.dart';

/// What can't load, said with Try again (docs/DESIGN_SYSTEM.md §6.22, Error
/// state): an [ErrorMessage] in the midst of a page, under its other content,
/// and an [ErrorState] standing for a whole page, in light and in high
/// contrast dark, set in the bundled fonts.
///
///   flutter test --update-goldens test/goldens/fallbacks_golden_test.dart
void main() {
  setUpAll(() async {
    await loadBundledFonts();
    useTolerantGoldens();
  });

  const themes = {AppThemeMode.light: 'light', AppThemeMode.highContrastDark: 'hcd'};
  const message = 'Couldn’t reach the server. Check your connection and try again.';

  final widgets = <String, Widget Function(BuildContext)>{
    'error_message': (context) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Forums', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              ErrorMessage(message: message, onRetry: () {}),
            ],
          ),
        ),
    'error_state': (context) => ErrorState(message: message, onRetry: () {}),
  };

  for (final MapEntry(key: name, value: build) in widgets.entries) {
    for (final MapEntry(key: theme, value: tag) in themes.entries) {
      testWidgets('$name, $tag', (tester) async {
        tester.view.physicalSize = const Size(412, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pumpThemed(tester, Builder(builder: build), theme: theme);
        await expectLater(find.byType(Scaffold), matchesGoldenFile('widgets/${name}_$tag.png'));
      }, skip: goldensSkipped);
    }
  }
}
