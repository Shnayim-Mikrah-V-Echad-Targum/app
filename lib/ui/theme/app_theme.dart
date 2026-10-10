import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/settings/app_settings.dart';
import 'focus.dart';
import 'motion.dart';
import 'palette.dart';
import 'typography.dart';

export 'focus.dart';
export 'motion.dart';
export 'sefer_colors.dart';
export 'status_colors.dart';
export 'typography.dart';

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

/// A segment's ink: onPrimaryContainer on the selected segment's fill,
/// onSurface on the others.
Color _segmentInkFor(ColorScheme scheme, Set<WidgetState> states) =>
    states.contains(WidgetState.selected) ? scheme.onPrimaryContainer : scheme.onSurface;

WidgetStateProperty<Color?> _segmentInk(ColorScheme scheme) => WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return null;
      return _segmentInkFor(scheme, states);
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
  /// is shown in. [web] is whether the app runs in a browser.
  static ThemeData build({
    required AppThemeMode mode,
    required UiFont uiFont,
    required bool hebrewUi,
    required bool reduceMotion,
    bool web = kIsWeb,
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
    const fabRadius = BorderRadius.all(Radius.circular(12));
    const chipShape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8)));
    final chipFocusRing = focusRing.copyWith(borderRadius: chipShape.borderRadius);
    WidgetStateProperty<OutlinedBorder?> ringed(OutlinedBorder? normal, OutlinedBorder ring) =>
        WidgetStateProperty.resolveWith((states) => showsFocusRing(states) ? ring : normal);
    final outlineWidth = highContrast ? 2.0 : 1.0;
    final focusedFieldWidth = highContrast ? 3.0 : 2.0;

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
      cardColor: sefer.paper,
      shadowColor: scheme.shadow,
      extensions: [status, sefer, seferType, Motion(reduced: reduceMotion)],
      // §8: each platform's transition, or none while motion is reduced, when
      // ink doesn't spread either (pressed controls still show their wash).
      pageTransitionsTheme: AppPageTransitions.theme(reduced: reduceMotion),
      splashFactory: reduceMotion ? NoSplash.splashFactory : null,
    );

    // ThemeData has filled in what the text theme leaves to the platform (the
    // device font's family), so component styles start from its copy.
    final text = base.textTheme;
    final labelLarge = text.labelLarge!;
    final onSurfaceVariantIcons = IconThemeData(color: scheme.onSurfaceVariant, size: 24);
    // Paper surfaces (§3.1, §5): no elevation and no tint. Cards and menus
    // keep their hairline (a 2 px outline in high contrast). Sheets and
    // dialogs are set off by their scrim, and in high contrast by a 2 px
    // outline as well, since there paper and surface are the same colour.
    final hairline = BorderSide(color: sefer.hairline, width: sefer.hairlineWidth);
    final floatingEdge = highContrast ? BorderSide(color: scheme.outline, width: 2) : BorderSide.none;
    // The navigation indicator's pale fill barely shows on a high-contrast
    // bar or rail, so there it is outlined too, as tonal buttons are.
    final indicatorEdge = floatingEdge;
    // Navigation labels: labelSmall, at its own weight when unselected (500,
    // or 400 in an accessibility font in the English UI, which has no 500),
    // and without tracking, so the longest, "Community", fits a 360 dp
    // phone's 72 px slot in bold.
    final navLabel = text.labelSmall!.copyWith(letterSpacing: 0);
    return base.copyWith(
      // §6.2. Scrolled content slips under a hairline-thin shadow in
      // outlineVariant; in high contrast the bar has a 2 px rule instead.
      appBarTheme: AppBarTheme(
        toolbarHeight: 64,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: highContrast ? 0 : 1,
        shadowColor: scheme.outlineVariant,
        shape: highContrast ? Border(bottom: BorderSide(color: scheme.outline, width: 2)) : null,
        centerTitle: false,
        titleTextStyle: text.titleLarge!.copyWith(color: scheme.onSurface),
        iconTheme: onSurfaceVariantIcons,
        actionsIconTheme: onSurfaceVariantIcons,
        // On the web the status bar's colour is the page's theme-color (the
        // browser's toolbar, or the installed app's title bar): the bar's own
        // surface, where Material's transparent one would turn it black.
        systemOverlayStyle: web ? SystemUiOverlayStyle(statusBarColor: scheme.surface) : null,
      ),
      // §6.3: paper with a full-strength hairline (2 px outline in high
      // contrast). Cards clip, so a list tile's ink stays inside the corners.
      cardTheme: CardThemeData(
        elevation: 0,
        color: sefer.paper,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: const BorderRadius.all(Radius.circular(12)), side: hairline),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
      // Menus and the FAB are the only things that float on a shadow (§5).
      // The FAB (§9 Community: radius 12) takes the buttons' focus ring; its
      // RawMaterialButton resolves a state-dependent shape.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 2,
        highlightElevation: 2,
        disabledElevation: 0,
        // The pale fill alone barely shows on a high-contrast surface.
        shape: WidgetStateOutlinedBorder.resolveWith((states) => showsFocusRing(states)
            ? focusRing.copyWith(borderRadius: fabRadius, side: floatingEdge)
            : RoundedRectangleBorder(borderRadius: fabRadius, side: floatingEdge)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: sefer.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shadowColor: scheme.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          side: hairline,
        ),
        // Material 3 shows a disabled item only through this style.
        labelTextStyle: WidgetStateProperty.resolveWith((states) => text.bodyLarge!.copyWith(
              color: scheme.onSurface.withValues(alpha: states.contains(WidgetState.disabled) ? 0.38 : 1),
            )),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(sefer.paper),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(2),
          shadowColor: WidgetStatePropertyAll(scheme.shadow),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            side: hairline,
          )),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary, linearTrackColor: sefer.ringTrack),
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
          // SegmentedButton draws its ring around the whole group (it gives
          // segments a plain shape of their own), so the focused segment is
          // marked as well: a wash of its ink, and its label underlined,
          // which shows on the selected segment's fill too.
          overlayColor: WidgetStateProperty.resolveWith((states) {
            final ink = _segmentInkFor(scheme, states);
            if (!states.contains(WidgetState.pressed) && showsFocusRing(states)) return ink.withValues(alpha: 0.24);
            return _overlay(ink).resolve(states);
          }),
          textStyle: WidgetStateProperty.resolveWith((states) {
            final style =
                states.contains(WidgetState.selected) ? labelLarge.copyWith(fontWeight: FontWeight.w700) : labelLarge;
            return showsFocusRing(states)
                ? style.copyWith(decoration: TextDecoration.underline, decorationThickness: 2)
                : style;
          }),
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
      // when focused. In high contrast the enabled border is already 2 px,
      // and primary is barely apart from outline there (about 1.5:1), so
      // focus widens the border to 3 px as well.
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: r10,
          borderSide: BorderSide(color: scheme.outline, width: outlineWidth),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: r10,
          borderSide: BorderSide(color: scheme.outline, width: outlineWidth),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: r10,
          borderSide: BorderSide(color: scheme.primary, width: focusedFieldWidth),
        ),
        errorBorder: OutlineInputBorder(borderRadius: r10, borderSide: BorderSide(color: scheme.error, width: 2)),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: r10,
          borderSide: BorderSide(color: scheme.error, width: focusedFieldWidth),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: r10,
          borderSide: BorderSide(color: scheme.onSurface.withValues(alpha: 0.12)),
        ),
        helperStyle: _tabular(text.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
        counterStyle: _tabular(text.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
      ),
      dividerTheme: DividerThemeData(color: highContrast ? scheme.outline : scheme.outlineVariant),
      // §6.9: a cool bar under a hairline (AppShell draws it). The selected
      // tab is marked three ways: the stadium, a filled icon and a bold label.
      // Its icon is in the indicator's own ink: Material's default,
      // onSecondaryContainer, is gold here.
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: StadiumBorder(side: indicatorEdge),
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              size: 24,
              color: states.contains(WidgetState.selected) ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected)
            ? navLabel.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w700)
            : navLabel.copyWith(color: scheme.onSurfaceVariant)),
        // The bar draws no focus ring, so keyboard focus is a strong wash over
        // the indicator's stadium.
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return scheme.onSurface.withValues(alpha: 0.10);
          if (states.contains(WidgetState.focused)) return scheme.onSurface.withValues(alpha: 0.32);
          if (states.contains(WidgetState.hovered)) return scheme.onSurface.withValues(alpha: 0.06);
          return null;
        }),
      ),
      // §6.10: the rail lies on the page's own surface, set off by a hairline
      // (AppShell draws it), with a rounded indicator. Icons and labels are
      // the bar's; beside the icons, AppShell sets the labels larger.
      navigationRailTheme: NavigationRailThemeData(
        labelType: NavigationRailLabelType.all,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          side: indicatorEdge,
        ),
        backgroundColor: scheme.surface,
        elevation: 0,
        selectedIconTheme: IconThemeData(size: 24, color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(size: 24, color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: navLabel.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: navLabel.copyWith(color: scheme.onSurfaceVariant),
      ),
      // §6.19: sheets are paper with 20 px top corners and a drag handle, at
      // most 640 wide (centred on wider screens).
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: sefer.paper,
        modalBackgroundColor: sefer.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          side: floatingEdge,
        ),
        clipBehavior: Clip.antiAlias,
        showDragHandle: true,
        // The handle is also a dismiss button, so high contrast draws it in
        // full.
        dragHandleColor: highContrast ? scheme.outline : scheme.outline.withValues(alpha: 0.4),
        dragHandleSize: const Size(36, 4),
        constraints: const BoxConstraints(maxWidth: 640),
      ),
      // Dialogs: paper, radius 16, a serif title over quieter body text.
      // AlertDialog already pads 24 and ends its actions.
      dialogTheme: DialogThemeData(
        backgroundColor: sefer.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: const BorderRadius.all(Radius.circular(16)), side: floatingEdge),
        titleTextStyle: text.titleLarge!.copyWith(color: scheme.onSurface),
        contentTextStyle: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
      ),
      // The date and time pickers are dialogs too.
      datePickerTheme: DatePickerThemeData(
        backgroundColor: sefer.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: const BorderRadius.all(Radius.circular(16)), side: floatingEdge),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: sefer.paper,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: const BorderRadius.all(Radius.circular(16)), side: floatingEdge),
      ),
      // Status messages float in the inverse colours (12.55:1 in light), the
      // action in inversePrimary. showStatus sets the timing.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium!.copyWith(color: scheme.onInverseSurface),
        actionTextColor: scheme.inversePrimary,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
        insetPadding: const EdgeInsets.all(16),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: const BorderRadius.all(Radius.circular(6)),
        ),
        textStyle: text.bodySmall!.copyWith(color: scheme.onInverseSurface),
      ),
    );
  }
}
