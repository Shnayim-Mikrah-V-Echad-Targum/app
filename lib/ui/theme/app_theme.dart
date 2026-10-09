import 'package:flutter/material.dart';

import '../../features/settings/app_settings.dart';
import 'focus.dart';
import 'palette.dart';
import 'typography.dart';

export 'focus.dart';
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

/// [value] while the control is enabled; disabled controls keep Material's
/// defaults (onSurface at 12% for fills, 38% for labels).
WidgetStateProperty<T?> _enabled<T>(T value) =>
    WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.disabled) ? null : value);

/// The press and hover washes of §6.5, in the control's foreground [ink].
/// Focus keeps Material's 10% under the ring.
WidgetStateProperty<Color?> _overlay(Color ink) => WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) return ink.withValues(alpha: 0.10);
      if (states.contains(WidgetState.hovered)) return ink.withValues(alpha: 0.06);
      return null;
    });

WidgetStateProperty<Color?> _segmentInk(ColorScheme scheme) => WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return null;
      return states.contains(WidgetState.selected) ? scheme.onPrimaryContainer : scheme.onSurface;
    });

/// Counts line up when they change ("12/500").
TextStyle _tabular(TextStyle style) => style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

/// Button styles that a theme can't express, because ThemeData has a single
/// FilledButton theme for both FilledButton and FilledButton.tonal.
abstract final class AppButtons {
  /// For every FilledButton.tonal (§6.5): primaryContainer and
  /// onPrimaryContainer instead of Material's secondaryContainer, which is
  /// gold here, and gold is never a button.
  static ButtonStyle tonal(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ButtonStyle(
      backgroundColor: _enabled(scheme.primaryContainer),
      foregroundColor: _enabled(scheme.onPrimaryContainer),
      iconColor: _enabled(scheme.onPrimaryContainer),
      overlayColor: _overlay(scheme.onPrimaryContainer),
      // The pale fill alone barely shows on a high-contrast surface.
      side: SeferColors.of(context).isHighContrast ? _enabled(BorderSide(color: scheme.outline, width: 2)) : null,
    );
  }

  /// A FilledButton in error / onError, for the confirming action of a
  /// destructive dialog only (§6.5). Never for anything else: error is
  /// reserved for validation and destruction.
  static ButtonStyle destructive(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ButtonStyle(
      backgroundColor: _enabled(scheme.error),
      foregroundColor: _enabled(scheme.onError),
      iconColor: _enabled(scheme.onError),
      overlayColor: _overlay(scheme.onError),
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
    // 2.4.13; §6.1): 3 px, outside the control, with a band of surface
    // between, so it shows on a filled button as well as on a text button.
    const r10 = BorderRadius.all(Radius.circular(10));
    const buttonShape = RoundedRectangleBorder(borderRadius: r10);
    final focusRing = FocusRingBorder(borderRadius: r10, ring: sefer.focus, gap: sefer.focusGap);
    // Icon buttons keep Material's circle, so their ring is round too.
    final roundFocusRing = focusRing.copyWith(borderRadius: const BorderRadius.all(Radius.circular(24)));
    const chipShape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8)));
    final chipFocusRing = focusRing.copyWith(borderRadius: chipShape.borderRadius);
    WidgetStateProperty<OutlinedBorder?> ringed(OutlinedBorder? normal, OutlinedBorder ring) =>
        WidgetStateProperty.resolveWith((states) => showsFocusRing(states) ? ring : normal);
    final outlineWidth = highContrast ? 2.0 : 1.0;

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // Every role names its own family and fallbacks, so none is set here.
      textTheme: textTheme,
      primaryTextTheme: textTheme.apply(bodyColor: scheme.onPrimary, displayColor: scheme.onPrimary),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      // The tint that marks focus on list tiles, rail destinations and menu
      // items. Controls draw the ring instead.
      focusColor: scheme.onSurface.withValues(alpha: 0.24),
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

    // ThemeData has filled in what the text theme leaves to the platform (the
    // device font's family), so component styles start from its copy.
    final text = base.textTheme;
    final labelLarge = text.labelLarge!;
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
      // Buttons (§6.5): radius 10, never a stadium. Each switches to the
      // focus ring shape while keyboard focus is shown, with no animation:
      // Material's shape tween would blend the ring away.
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          // Material's defaults are already right: primary on onPrimary,
          // labelLarge, and 24 px of side padding that narrows for large
          // text. Colours couldn't be set here anyway: this theme also styles
          // FilledButton.tonal, which takes its own from AppButtons.tonal
          // (including this overlay, in its own ink).
          overlayColor: _overlay(scheme.onPrimary),
          minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
          iconSize: const WidgetStatePropertyAll(20),
          shape: ringed(buttonShape, focusRing),
          animationDuration: Duration.zero,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: _enabled(scheme.primary),
          iconColor: _enabled(scheme.primary),
          overlayColor: _overlay(scheme.primary),
          minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
          side: _enabled(BorderSide(color: scheme.outline, width: outlineWidth)),
          shape: ringed(buttonShape, focusRing),
          animationDuration: Duration.zero,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: _enabled(scheme.primary),
          iconColor: _enabled(scheme.primary),
          overlayColor: _overlay(scheme.primary),
          // In high contrast a link-like button doesn't rely on colour alone.
          textStyle: highContrast
              ? WidgetStatePropertyAll(labelLarge.copyWith(decoration: TextDecoration.underline))
              : null,
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          shape: ringed(buttonShape, focusRing),
          animationDuration: Duration.zero,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          shape: ringed(null, roundFocusRing),
          animationDuration: Duration.zero,
        ),
      ),
      // §6.8: selected segments are primaryContainer, bold and checked (the
      // check is the non-colour cue); the others transparent with an outline.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return null;
            return states.contains(WidgetState.selected) ? scheme.primaryContainer : Colors.transparent;
          }),
          foregroundColor: _segmentInk(scheme),
          iconColor: _segmentInk(scheme),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            final ink = states.contains(WidgetState.selected) ? scheme.onPrimaryContainer : scheme.onSurface;
            return _overlay(ink).resolve(states);
          }),
          textStyle: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? labelLarge.copyWith(fontWeight: FontWeight.w700) : labelLarge),
          side: _enabled(BorderSide(color: scheme.outline, width: outlineWidth)),
          shape: ringed(buttonShape, focusRing),
          // SegmentedButton passes neither minimumSize nor fixedSize on to its
          // segments, so the padding makes them 48 high (14 + 20 + 14), and the
          // button itself is the tap target. (A checked segment brings its own
          // 8 px padding; its unchecked neighbours set the row's height.)
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          animationDuration: Duration.zero,
        ),
      ),
      // §6.6: 36 high (padded to 48 for touch), radius 8. Selection is shown
      // by fill, a heavier border and a bold label (SeferChoiceChip), not by a
      // checkmark: a leading check means "done" elsewhere in the app. Focus
      // is the buttons' ring, outside the border, which it leaves in place.
      chipTheme: ChipThemeData(
        shape: WidgetStateOutlinedBorder.resolveWith((states) => showsFocusRing(states) ? chipFocusRing : chipShape),
        showCheckmark: false,
        backgroundColor: Colors.transparent,
        selectedColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        // max(32 + 4, label + 4 + 12): 36 for a one-line label in either UI.
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        labelStyle: text.labelMedium!.copyWith(
          color: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return scheme.onSurface.withValues(alpha: 0.38);
            return states.contains(WidgetState.selected) ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
          }),
        ),
        // Every side is drawn outside the chip: an inside border would pad
        // the chip by its width, so selecting a chip would resize it and
        // reflow its neighbours.
        side: WidgetStateBorderSide.resolveWith((states) {
          const outside = BorderSide.strokeAlignOutside;
          if (states.contains(WidgetState.disabled)) {
            return BorderSide(color: scheme.onSurface.withValues(alpha: 0.12), strokeAlign: outside);
          }
          return states.contains(WidgetState.selected)
              ? BorderSide(color: scheme.primary, width: outlineWidth + 0.5, strokeAlign: outside)
              : BorderSide(color: scheme.outline, width: outlineWidth, strokeAlign: outside);
        }),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 12,
        iconColor: scheme.onSurfaceVariant,
      ),
      // §6.8. Thumb size and position carry the state without colour: a
      // small outline thumb when off, a large checked one when on. High
      // contrast adds an icon to the off thumb as well.
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return null;
          return states.contains(WidgetState.selected) ? scheme.primary : scheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.transparent;
          return states.contains(WidgetState.disabled) ? null : scheme.outline;
        }),
        trackOutlineWidth: const WidgetStatePropertyAll(2),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return null;
          return states.contains(WidgetState.selected) ? scheme.onPrimary : scheme.outline;
        }),
        thumbIcon: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return const Icon(Icons.check, size: 16);
          return highContrast ? const Icon(Icons.close, size: 16) : null;
        }),
      ),
      // §6.8: a 4 px track with a round 20 px thumb, and no tick marks. Every
      // shape is named, so neither of Material's slider generations (the
      // deprecated year2023 flag picks between them) shows through.
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
        trackShape: const RoundedRectSliderTrackShape(),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 0, pressedElevation: 0),
        tickMarkShape: SliderTickMarkShape.noTickMark,
        overlayShape: FocusRingSliderOverlay(ring: sefer.focus, gap: sefer.focusGap),
        overlayColor: WidgetStateColor.resolveWith((states) {
          // The slider reports focus only while it should be shown, and the
          // overlay shape draws the ring for exactly this colour.
          if (states.contains(WidgetState.focused)) return sefer.focus;
          if (states.contains(WidgetState.dragged)) return scheme.primary.withValues(alpha: 0.10);
          if (states.contains(WidgetState.hovered)) return scheme.primary.withValues(alpha: 0.06);
          return Colors.transparent;
        }),
        valueIndicatorShape: const RoundedRectSliderValueIndicatorShape(),
        valueIndicatorColor: scheme.inverseSurface,
        valueIndicatorTextStyle: _tabular(labelLarge.copyWith(color: scheme.onInverseSurface)),
      ),
      // §6.7. The label is Material's: bodyLarge in onSurfaceVariant, primary
      // when focused.
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: r10,
          borderSide: BorderSide(color: scheme.outline, width: outlineWidth),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: r10,
          borderSide: BorderSide(color: scheme.outline, width: outlineWidth),
        ),
        focusedBorder: OutlineInputBorder(borderRadius: r10, borderSide: BorderSide(color: scheme.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: r10, borderSide: BorderSide(color: scheme.error, width: 2)),
        focusedErrorBorder:
            OutlineInputBorder(borderRadius: r10, borderSide: BorderSide(color: scheme.error, width: 2)),
        disabledBorder: OutlineInputBorder(
          borderRadius: r10,
          borderSide: BorderSide(color: scheme.onSurface.withValues(alpha: 0.12)),
        ),
        helperStyle: _tabular(text.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
        counterStyle: _tabular(text.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
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
