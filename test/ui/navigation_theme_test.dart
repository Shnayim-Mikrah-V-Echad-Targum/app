import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/app_theme.dart';

/// docs/DESIGN_SYSTEM.md §6.9 and §6.10: the navigation bar and rail themes.
/// AppShell draws their hairlines (test/app/shell_test.dart).
const _modes = [
  AppThemeMode.light,
  AppThemeMode.dark,
  AppThemeMode.sepia,
  AppThemeMode.highContrastLight,
  AppThemeMode.highContrastDark,
];

const _selected = {WidgetState.selected};
const _unselected = <WidgetState>{};

ThemeData _theme(AppThemeMode mode, {bool hebrewUi = false, UiFont uiFont = UiFont.standard}) =>
    AppTheme.build(mode: mode, uiFont: uiFont, hebrewUi: hebrewUi, reduceMotion: false);

/// Size, line height and family of [style], which navigation labels take from
/// labelSmall.
(double?, double?, String?) _metrics(TextStyle style) => (style.fontSize, style.height, style.fontFamily);

void main() {
  for (final mode in _modes) {
    for (final hebrewUi in [false, true]) {
      group('${mode.name} ${hebrewUi ? 'he' : 'en'}', () {
        final theme = _theme(mode, hebrewUi: hebrewUi);
        final scheme = theme.colorScheme;
        final hc = theme.extension<SeferColors>()!.isHighContrast;
        final labelSmall = theme.textTheme.labelSmall!;
        // The pale indicator is outlined where it would vanish.
        final indicatorEdge = hc ? BorderSide(color: scheme.outline, width: 2) : BorderSide.none;
        final bar = theme.navigationBarTheme;
        final rail = theme.navigationRailTheme;

        test('bar: 72 high and flat on surfaceContainer, every label shown', () {
          expect(bar.height, 72);
          expect(bar.backgroundColor, scheme.surfaceContainer);
          expect(bar.elevation, 0);
          expect(bar.surfaceTintColor, Colors.transparent);
          expect(bar.shadowColor, Colors.transparent);
          expect(bar.labelBehavior, NavigationDestinationLabelBehavior.alwaysShow);
        });

        test('bar: the indicator is a primaryContainer stadium', () {
          expect(bar.indicatorColor, scheme.primaryContainer);
          expect(bar.indicatorShape, StadiumBorder(side: indicatorEdge));
        });

        test("bar: 24 px icons, the selected one in the indicator's ink", () {
          expect(bar.iconTheme!.resolve(_selected), IconThemeData(size: 24, color: scheme.onPrimaryContainer));
          expect(bar.iconTheme!.resolve(_unselected), IconThemeData(size: 24, color: scheme.onSurfaceVariant));
        });

        test('bar: labelSmall, the selected label bold in onSurface', () {
          final selected = bar.labelTextStyle!.resolve(_selected)!;
          final unselected = bar.labelTextStyle!.resolve(_unselected)!;
          expect(_metrics(selected), _metrics(labelSmall));
          expect(_metrics(unselected), _metrics(labelSmall));
          expect((selected.color, selected.fontWeight), (scheme.onSurface, FontWeight.w700));
          expect((unselected.color, unselected.fontWeight), (scheme.onSurfaceVariant, FontWeight.w500));
        });

        test('bar: keyboard focus is a strong wash; press and hover the usual ones', () {
          final overlay = bar.overlayColor!;
          expect(overlay.resolve({WidgetState.focused}), scheme.onSurface.withValues(alpha: 0.32));
          expect(overlay.resolve({WidgetState.pressed}), scheme.onSurface.withValues(alpha: 0.10));
          expect(overlay.resolve({WidgetState.hovered}), scheme.onSurface.withValues(alpha: 0.06));
          expect(overlay.resolve(_unselected), isNull);
        });

        test("rail: flat on surface, a radius-12 indicator, the bar's icons and labels", () {
          expect(rail.backgroundColor, scheme.surface);
          expect(rail.elevation, 0);
          expect(rail.labelType, NavigationRailLabelType.all);
          expect(rail.indicatorColor, scheme.primaryContainer);
          expect(
            rail.indicatorShape,
            RoundedRectangleBorder(borderRadius: const BorderRadius.all(Radius.circular(12)), side: indicatorEdge),
          );
          expect(rail.selectedIconTheme, bar.iconTheme!.resolve(_selected));
          expect(rail.unselectedIconTheme, bar.iconTheme!.resolve(_unselected));
          expect(rail.selectedLabelTextStyle, bar.labelTextStyle!.resolve(_selected));
          expect(rail.unselectedLabelTextStyle, bar.labelTextStyle!.resolve(_unselected));
        });
      });
    }
  }

  test('in an accessibility font, unselected labels keep its regular weight, as it has no 500', () {
    final bar = _theme(AppThemeMode.light, uiFont: UiFont.lexend).navigationBarTheme;
    expect(bar.labelTextStyle!.resolve(_unselected)!.fontWeight, FontWeight.w400);
    expect(bar.labelTextStyle!.resolve(_selected)!.fontWeight, FontWeight.w700);
  });
}
