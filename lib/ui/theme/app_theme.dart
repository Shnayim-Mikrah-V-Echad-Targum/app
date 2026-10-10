import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../features/settings/app_settings.dart';

/// Brand colors: techelet blue and a muted gold.
abstract final class Brand {
  static const techelet = Color(0xFF1E4B8F);
  static const gold = Color(0xFF8A5A00);
}

/// Semantic colors for progress states. Never red: missed days are shown in
/// neutral grey, and every state also has its own icon and label so color is
/// never the only signal (WCAG 1.4.1).
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.done,
    required this.onDone,
    required this.late,
    required this.onLate,
    required this.grace,
    required this.neutral,
    required this.rest,
  });

  final Color done;
  final Color onDone;
  final Color late;
  final Color onLate;
  final Color grace;
  final Color neutral;
  final Color rest;

  static StatusColors of(BuildContext context) => Theme.of(context).extension<StatusColors>()!;

  @override
  StatusColors copyWith({Color? done, Color? onDone, Color? late, Color? onLate, Color? grace, Color? neutral, Color? rest}) =>
      StatusColors(
        done: done ?? this.done,
        onDone: onDone ?? this.onDone,
        late: late ?? this.late,
        onLate: onLate ?? this.onLate,
        grace: grace ?? this.grace,
        neutral: neutral ?? this.neutral,
        rest: rest ?? this.rest,
      );

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    return StatusColors(
      done: Color.lerp(done, other.done, t)!,
      onDone: Color.lerp(onDone, other.onDone, t)!,
      late: Color.lerp(late, other.late, t)!,
      onLate: Color.lerp(onLate, other.onLate, t)!,
      grace: Color.lerp(grace, other.grace, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      rest: Color.lerp(rest, other.rest, t)!,
    );
  }
}

/// A page transition that does nothing, for Reduce Motion.
class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation, Widget child) =>
      child;
}

abstract final class AppTheme {
  static ColorScheme scheme(AppThemeMode mode, Brightness systemBrightness) {
    switch (mode) {
      case AppThemeMode.system:
        return systemBrightness == Brightness.dark ? _dark : _light;
      case AppThemeMode.light:
        return _light;
      case AppThemeMode.dark:
        return _dark;
      case AppThemeMode.sepia:
        return _sepia;
      case AppThemeMode.highContrastLight:
        return _highContrastLight;
      case AppThemeMode.highContrastDark:
        return _highContrastDark;
    }
  }

  static final _light = ColorScheme.fromSeed(seedColor: Brand.techelet, secondary: Brand.gold).copyWith(
    surface: const Color(0xFFFBF9F5),
  );

  static final _dark = ColorScheme.fromSeed(seedColor: Brand.techelet, brightness: Brightness.dark);

  static final _sepia = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7A5A2B),
    secondary: const Color(0xFF6B4A12),
  ).copyWith(
    surface: const Color(0xFFF4ECD8),
    onSurface: const Color(0xFF33281A),
    onSurfaceVariant: const Color(0xFF4E4130),
    surfaceContainerLowest: const Color(0xFFFAF4E6),
    surfaceContainerLow: const Color(0xFFEFE5CD),
    surfaceContainer: const Color(0xFFEADFC4),
    surfaceContainerHigh: const Color(0xFFE4D8BC),
    surfaceContainerHighest: const Color(0xFFDDD0B2),
  );

  static final _highContrastLight = ColorScheme.fromSeed(
    seedColor: Brand.techelet,
    contrastLevel: 1.0,
  ).copyWith(
    primary: const Color(0xFF002B66),
    onPrimary: Colors.white,
    surface: Colors.white,
    onSurface: Colors.black,
    onSurfaceVariant: Colors.black,
    outline: Colors.black,
    outlineVariant: const Color(0xFF3D3D3D),
  );

  static final _highContrastDark = ColorScheme.fromSeed(
    seedColor: Brand.techelet,
    brightness: Brightness.dark,
    contrastLevel: 1.0,
  ).copyWith(
    primary: const Color(0xFFFFE066),
    onPrimary: Colors.black,
    primaryContainer: const Color(0xFF3A3000),
    onPrimaryContainer: const Color(0xFFFFF2B8),
    secondary: const Color(0xFF9CD8FF),
    onSecondary: Colors.black,
    surface: Colors.black,
    onSurface: Colors.white,
    onSurfaceVariant: Colors.white,
    surfaceContainerLowest: Colors.black,
    surfaceContainerLow: const Color(0xFF0D0D0D),
    surfaceContainer: const Color(0xFF141414),
    surfaceContainerHigh: const Color(0xFF1C1C1C),
    surfaceContainerHighest: const Color(0xFF262626),
    outline: Colors.white,
    outlineVariant: const Color(0xFFBDBDBD),
  );

  static bool isHighContrast(AppThemeMode m) =>
      m == AppThemeMode.highContrastLight || m == AppThemeMode.highContrastDark;

  static ThemeData build({
    required ColorScheme scheme,
    required UiFont uiFont,
    required bool highContrast,
    required bool reduceMotion,
  }) {
    final dark = scheme.brightness == Brightness.dark;
    final family = uiFont.family ?? (kIsWeb ? 'NotoSans' : null);
    final status = StatusColors(
      done: scheme.primary,
      onDone: scheme.onPrimary,
      late: dark ? const Color(0xFFFFB866) : const Color(0xFF9A5B00),
      onLate: dark ? Colors.black : Colors.white,
      grace: dark ? const Color(0xFF7FD6C2) : const Color(0xFF00695C),
      neutral: scheme.outline,
      rest: scheme.secondary,
    );

    // A strong, visible focus ring for keyboard and switch users (WCAG 2.4.7,
    // 2.4.13): 3 px in a color that contrasts with the surface.
    final focusSide = BorderSide(color: highContrast ? scheme.onSurface : scheme.primary, width: 3);
    WidgetStateProperty<BorderSide?> focusOutline(BorderSide? normal) => WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused) ? focusSide : normal,
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: family,
      fontFamilyFallback: const ['NotoSansHebrew', 'NotoSerifHebrew'],
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      focusColor: scheme.primary.withValues(alpha: 0.24),
      scaffoldBackgroundColor: scheme.surface,
      extensions: [status],
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
          textStyle: WidgetStatePropertyAll(base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
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
        // The focus ring of every other control. A selected chip has a
        // wider border than one that isn't, in every theme: the width, not
        // only the colour, says which is chosen (DESIGN_SYSTEM.md §6.6).
        side: WidgetStateBorderSide.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return null;
          if (states.contains(WidgetState.focused)) {
            return focusSide.copyWith(strokeAlign: BorderSide.strokeAlignOutside);
          }
          if (states.contains(WidgetState.selected)) {
            return BorderSide(color: scheme.primary, width: highContrast ? 2.5 : 1.5);
          }
          return BorderSide(color: scheme.outline, width: highContrast ? 1.5 : 1);
        }),
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
