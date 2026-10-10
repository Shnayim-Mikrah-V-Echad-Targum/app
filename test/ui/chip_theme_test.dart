import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/app_theme.dart';

void main() {
  ThemeData theme(AppThemeMode mode) => AppTheme.build(
        scheme: AppTheme.scheme(mode, Brightness.light),
        uiFont: UiFont.standard,
        highContrast: mode == AppThemeMode.highContrastLight || mode == AppThemeMode.highContrastDark,
        reduceMotion: false,
      );

  BorderSide side(ThemeData t, Set<WidgetState> states) => WidgetStateProperty.resolveAs(t.chipTheme.side, states)!;

  for (final mode in AppThemeMode.values.where((m) => m != AppThemeMode.system)) {
    test('a chip in the ${mode.name} theme is outlined, wider when chosen, and ringed like other controls when focused', () {
      final t = theme(mode);
      final scheme = t.colorScheme;
      final highContrast = mode == AppThemeMode.highContrastLight || mode == AppThemeMode.highContrastDark;
      final unselected = side(t, {});
      final selected = side(t, {WidgetState.selected});
      final focused = side(t, {WidgetState.focused, WidgetState.selected});

      expect(unselected.color, scheme.outline);
      expect(unselected.width, highContrast ? 1.5 : 1);
      expect(selected.color, scheme.primary);
      expect(selected.width, greaterThan(unselected.width));
      // The ring of the theme's buttons.
      final ring = t.textButtonTheme.style!.side!.resolve({WidgetState.focused})!;
      expect(focused.color, ring.color);
      expect(focused.color, highContrast ? scheme.onSurface : scheme.primary);
      expect(focused.width, 3);
      expect(focused.strokeAlign, BorderSide.strokeAlignOutside);
    });
  }
}
