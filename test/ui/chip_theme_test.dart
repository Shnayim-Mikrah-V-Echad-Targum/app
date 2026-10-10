import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ThemeData theme(AppThemeMode mode) =>
      AppTheme.build(mode: mode, uiFont: UiFont.standard, hebrewUi: false, reduceMotion: false);

  // Focus is only ringed for keyboard users; resolve the styles as one.
  setUp(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional);
  tearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);

  BorderSide side(ThemeData t, Set<WidgetState> states) => WidgetStateProperty.resolveAs(t.chipTheme.side, states)!;
  OutlinedBorder shape(ThemeData t, Set<WidgetState> states) =>
      WidgetStateProperty.resolveAs<OutlinedBorder?>(t.chipTheme.shape, states)!;

  for (final mode in AppThemeMode.values.where((m) => m != AppThemeMode.system)) {
    test('a chip in the ${mode.name} theme is outlined, wider when chosen, and ringed like other controls when focused', () {
      final t = theme(mode);
      final scheme = t.colorScheme;
      final highContrast = mode == AppThemeMode.highContrastLight || mode == AppThemeMode.highContrastDark;
      final unselected = side(t, {});
      final selected = side(t, {WidgetState.selected});

      expect(unselected.color, scheme.outline);
      // The outline of every other control: 2 px in high contrast.
      expect(unselected.width, highContrast ? 2 : 1);
      expect(selected.color, scheme.primary);
      expect(selected.width, greaterThan(unselected.width));
      // The selection border stays under focus, and the ring goes around it.
      expect(side(t, {WidgetState.focused, WidgetState.selected}), selected);

      // The ring of the theme's buttons, at the chip's radius.
      final buttonRing = t.textButtonTheme.style!.shape!.resolve({WidgetState.focused})! as FocusRingBorder;
      final chipRing = shape(t, {WidgetState.focused, WidgetState.selected}) as FocusRingBorder;
      expect(chipRing.ring, buttonRing.ring);
      expect(chipRing.gap, buttonRing.gap);
      expect(chipRing.ring, highContrast ? scheme.onSurface : scheme.primary);
      expect(chipRing.borderRadius, const BorderRadius.all(Radius.circular(8)));
      expect(shape(t, {WidgetState.focused}), chipRing);
    });
  }
}
