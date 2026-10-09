import 'package:flutter/material.dart';

import '../../features/settings/app_settings.dart';
import 'palette.dart';
import 'typography.dart';

export 'sefer_colors.dart';
export 'status_colors.dart';
export 'typography.dart';

/// Brand colors: techelet blue and gold ink (the light theme's primary and
/// secondary).
abstract final class Brand {
  static const techelet = Color(0xFF1D3F75);
  static const gold = Color(0xFF7A5712);
}

/// The colour tokens of one theme.
typedef _Tokens = ({ColorScheme scheme, SeferColors sefer, StatusColors status});

/// A page transition that does nothing, for Reduce Motion.
class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation, Widget child) =>
      child;
}

abstract final class AppTheme {
  /// The concrete theme to paint: `system` follows the platform brightness.
  static AppThemeMode resolve(AppThemeMode mode, Brightness platformBrightness) => switch (mode) {
        AppThemeMode.system => platformBrightness == Brightness.dark ? AppThemeMode.dark : AppThemeMode.light,
        _ => mode,
      };

  static ColorScheme scheme(AppThemeMode mode, Brightness platformBrightness) =>
      _tokens(resolve(mode, platformBrightness)).scheme;

  static _Tokens _tokens(AppThemeMode resolved) => switch (resolved) {
        AppThemeMode.system || AppThemeMode.light =>
          (scheme: Palettes.light, sefer: Palettes.seferLight, status: Palettes.statusLight),
        AppThemeMode.dark => (scheme: Palettes.dark, sefer: Palettes.seferDark, status: Palettes.statusDark),
        AppThemeMode.sepia => (scheme: Palettes.sepia, sefer: Palettes.seferSepia, status: Palettes.statusSepia),
        AppThemeMode.highContrastLight =>
          (scheme: Palettes.hcLight, sefer: Palettes.seferHcLight, status: Palettes.statusHcLight),
        AppThemeMode.highContrastDark =>
          (scheme: Palettes.hcDark, sefer: Palettes.seferHcDark, status: Palettes.statusHcDark),
      };

  static bool isHighContrast(AppThemeMode m) =>
      m == AppThemeMode.highContrastLight || m == AppThemeMode.highContrastDark;

  /// The theme for [mode], which must already be resolved (see [resolve]).
  /// [hebrewUi] picks the Hebrew text theme; it must match the locale the app
  /// is shown in.
  static ThemeData build({
    required AppThemeMode mode,
    required UiFont uiFont,
    required bool hebrewUi,
    required bool reduceMotion,
  }) {
    assert(mode != AppThemeMode.system, 'Resolve the system theme first (AppTheme.resolve).');
    final (:scheme, :sefer, :status) = _tokens(mode);
    final highContrast = sefer.isHighContrast;
    final textTheme =
        AppTypography.textTheme(scheme: scheme, uiFont: uiFont, hebrewUi: hebrewUi, highContrast: highContrast);
    final seferType =
        AppTypography.sefer(scheme: scheme, uiFont: uiFont, hebrewUi: hebrewUi, highContrast: highContrast);

    // A strong, visible focus ring for keyboard and switch users (WCAG 2.4.7,
    // 2.4.13): 3 px in a color that contrasts with the surface.
    final focusSide = BorderSide(color: sefer.focus, width: 3);
    WidgetStateProperty<BorderSide?> focusOutline(BorderSide? normal) => WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused) ? focusSide : normal,
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // Every role names its own family and fallbacks, so none is set here.
      textTheme: textTheme,
      primaryTextTheme: textTheme.apply(bodyColor: scheme.onPrimary, displayColor: scheme.onPrimary),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      focusColor: scheme.primary.withValues(alpha: 0.24),
      scaffoldBackgroundColor: scheme.surface,
      extensions: [status, sefer, seferType],
      pageTransitionsTheme: reduceMotion
          ? const PageTransitionsTheme(builders: {
              TargetPlatform.android: _NoTransitionsBuilder(),
              TargetPlatform.iOS: _NoTransitionsBuilder(),
              TargetPlatform.windows: _NoTransitionsBuilder(),
              TargetPlatform.macOS: _NoTransitionsBuilder(),
              TargetPlatform.linux: _NoTransitionsBuilder(),
              TargetPlatform.fuchsia: _NoTransitionsBuilder(),
            })
          : const PageTransitionsTheme(),
    );

    final outlineSide = highContrast ? BorderSide(color: scheme.outline, width: 2) : null;
    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: highContrast ? 0 : 2,
        shape: highContrast ? Border(bottom: BorderSide(color: scheme.outline)) : null,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: highContrast ? BorderSide(color: scheme.outline, width: 2) : BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
          side: focusOutline(outlineSide),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
          side: focusOutline(BorderSide(color: highContrast ? scheme.outline : scheme.outline, width: highContrast ? 2 : 1)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          side: focusOutline(null),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          side: focusOutline(null),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          side: focusOutline(BorderSide(color: scheme.outline, width: highContrast ? 2 : 1)),
        ),
      ),
      chipTheme: ChipThemeData(
        side: highContrast ? BorderSide(color: scheme.outline, width: 1.5) : null,
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 12,
        iconColor: scheme.onSurfaceVariant,
      ),
      switchTheme: SwitchThemeData(
        // Show a check/close icon inside the thumb so state isn't conveyed by
        // color alone.
        thumbIcon: WidgetStateProperty.resolveWith(
          (states) => Icon(states.contains(WidgetState.selected) ? Icons.check : Icons.close, size: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 3),
        ),
        enabledBorder: highContrast
            ? OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.outline, width: 2))
            : null,
      ),
      dividerTheme: DividerThemeData(color: highContrast ? scheme.outline : scheme.outlineVariant),
      navigationBarTheme: NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: scheme.primaryContainer,
        backgroundColor: scheme.surfaceContainer,
      ),
      navigationRailTheme: NavigationRailThemeData(
        labelType: NavigationRailLabelType.all,
        indicatorColor: scheme.primaryContainer,
        backgroundColor: scheme.surfaceContainer,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      tooltipTheme: const TooltipThemeData(waitDuration: Duration(milliseconds: 400)),
    );
  }
}
