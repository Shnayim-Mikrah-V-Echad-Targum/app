import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/settings/app_settings.dart';
import '../../features/settings/widgets/settings_widgets.dart';
import '../l10n.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'paper_group.dart';

/// The themes as swatches (docs/DESIGN_SYSTEM.md §6.24), under a switch to
/// match the device: Settings → Display, and in [compact] form the reader's
/// display sheet.
///
/// Each swatch is a card painted in its own theme: its surface, "אָ" in its
/// ink, a bar of its techelet and a rule of its gold leaf, with the theme's
/// name under it. The chosen one has a 2 px primary border (3 px in high
/// contrast, where every border is 2) and a check at its top end corner.
/// Matching the device, the two themes it chooses between are marked: light
/// and dark, or high contrast's two when the device asks for high contrast.
///
/// The swatches are radio buttons to assistive technology, in one group
/// named for the theme, each one node: the theme's name, whether it is
/// chosen, and its tap. Matching the device, none is chosen (the switch says
/// the device is followed); the pair it switches between say so in a hint.
/// The arrow keys move between them, as between radio buttons.
class ThemeSwatchPicker extends StatelessWidget {
  const ThemeSwatchPicker({super.key, required this.value, required this.onChanged, this.compact = false});

  final AppThemeMode value;
  final ValueChanged<AppThemeMode> onChanged;

  /// Shorter swatches, for the reader's display sheet.
  final bool compact;

  /// The themes in the order they are offered.
  static const themes = [
    AppThemeMode.light,
    AppThemeMode.sepia,
    AppThemeMode.dark,
    AppThemeMode.highContrastLight,
    AppThemeMode.highContrastDark,
  ];

  static const _gap = Space.md;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final matching = value == AppThemeMode.system;
    // Within the app it says so for a high contrast theme too; while the
    // device is matched, it is the device's own request.
    final deviceHighContrast = MediaQuery.highContrastOf(context);
    final deviceDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    bool marked(AppThemeMode mode) =>
        matching ? mode != AppThemeMode.sepia && AppTheme.isHighContrast(mode) == deviceHighContrast : mode == value;
    // Matching, when each of the device's pair is used.
    String? hint(AppThemeMode mode) => !matching || !marked(mode)
        ? null
        : (mode == AppThemeMode.dark || mode == AppThemeMode.highContrastDark)
            ? l.themeUsedWhenDark
            : l.themeUsedWhenLight;
    // Turned off, the page keeps the theme the device had it in.
    final shown = switch ((deviceHighContrast, deviceDark)) {
      (true, true) => AppThemeMode.highContrastDark,
      (true, false) => AppThemeMode.highContrastLight,
      (false, true) => AppThemeMode.dark,
      (false, false) => AppThemeMode.light,
    };
    final columns = MediaQuery.sizeOf(context).width < kNarrowScreenWidth ? 2 : 3;
    final label = {
      AppThemeMode.light: l.themeLight,
      AppThemeMode.sepia: l.themeSepia,
      AppThemeMode.dark: l.themeDark,
      AppThemeMode.highContrastLight: l.themeHcLight,
      AppThemeMode.highContrastDark: l.themeHcDark,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaperGroup(
          children: [
            SwitchRow(
              icon: Icons.brightness_auto_outlined,
              title: l.themeSystem,
              subtitle: l.themeSystemDesc,
              value: matching,
              onChanged: (on) => onChanged(on ? AppThemeMode.system : shown),
            ),
          ],
        ),
        const Gap(Space.lg),
        Semantics(
          // One group of radio buttons, named.
          container: true,
          explicitChildNodes: true,
          label: l.themeLabel,
          child: FocusTraversalGroup(
            child: Shortcuts(
              // From swatch to swatch, as between radio buttons, on the web
              // too, where the arrow keys would otherwise scroll the page.
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.arrowLeft): DirectionalFocusIntent(TraversalDirection.left),
                SingleActivator(LogicalKeyboardKey.arrowRight): DirectionalFocusIntent(TraversalDirection.right),
                SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(TraversalDirection.up),
                SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(TraversalDirection.down),
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var row = 0; row < themes.length; row += columns) ...[
                    if (row > 0) const Gap(_gap),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = row; i < row + columns; i++) ...[
                          if (i > row) const SizedBox(width: _gap),
                          Expanded(
                            child: i < themes.length
                                ? _Swatch(
                                    mode: themes[i],
                                    label: label[themes[i]]!,
                                    selected: marked(themes[i]),
                                    checked: !matching && themes[i] == value,
                                    hint: hint(themes[i]),
                                    height: compact ? 64 : 96,
                                    onTap: () => onChanged(themes[i]),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.mode,
    required this.label,
    required this.selected,
    required this.checked,
    required this.hint,
    required this.height,
    required this.onTap,
  });

  final AppThemeMode mode;
  final String label;

  /// Marked for the eye: the theme chosen, or one of the pair the device
  /// switches between.
  final bool selected;

  /// The theme chosen, to assistive technology: never while matching.
  final bool checked;
  final String? hint;
  final double height;
  final VoidCallback onTap;

  static const _radius = BorderRadius.all(Radius.circular(12));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final page = theme.colorScheme;
    final sefer = SeferColors.of(context);
    // The swatch's own theme, whatever the page's.
    final own = AppTheme.scheme(mode, Brightness.light);
    final ownSefer = AppTheme.seferColors(mode, Brightness.light);
    final compact = height < 96;

    final card = DecoratedBox(
      // Drawn over the swatch, so that its width never moves what is inside.
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: _radius,
        border: Border.all(
          color: selected ? page.primary : sefer.hairline,
          width: selected ? sefer.hairlineWidth + 1 : sefer.hairlineWidth,
        ),
      ),
      child: Ink(
        height: height,
        decoration: BoxDecoration(color: own.surface, borderRadius: _radius),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'אָ',
                    // A picture of the theme: it keeps its size as the text grows.
                    textScaler: TextScaler.noScaling,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'NotoSerifHebrew',
                      fontSize: compact ? 20 : 24,
                      height: 1.4,
                      leadingDistribution: TextLeadingDistribution.even,
                      fontWeight: FontWeight.w400,
                      color: own.onSurface,
                    ),
                  ),
                  SizedBox(height: compact ? 4 : 6),
                  _Bar(color: own.primary, height: 4),
                  const SizedBox(height: 4),
                  _Bar(color: ownSefer.goldLeaf, height: 1),
                ],
              ),
            ),
            if (selected)
              PositionedDirectional(
                top: 6,
                end: 6,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: page.primary,
                    // Set off from any swatch it sits on, light or dark.
                    border: Border.all(color: page.onPrimary, width: 1.5, strokeAlign: BorderSide.strokeAlignOutside),
                  ),
                  child: Icon(Icons.check, size: 14, color: page.onPrimary),
                ),
              ),
          ],
        ),
      ),
    );

    final text = theme.textTheme.labelMedium!;
    return MergeSemantics(
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        checked: checked,
        hint: hint,
        button: true,
        // The swatch's fill and the ink over it are painted on this, which
        // moves with the page as it scrolls.
        child: Material(
          type: MaterialType.transparency,
          child: SeferInkWell(
            onTap: onTap,
            borderRadius: _radius,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExcludeSemantics(child: card),
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 6, 2, 4),
                  child: Text(
                    // "High contrast — light" breaks before its dash, if at all.
                    label.replaceAll('— ', '—\u00A0'),
                    semanticsLabel: label,
                    textAlign: TextAlign.center,
                    // The chosen one's name in bold, as a chosen chip's is.
                    style: selected
                        ? text.copyWith(color: page.onSurface, fontWeight: FontWeight.w700)
                        : text.copyWith(color: page.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.color, required this.height});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 24,
    height: height,
    child: ColoredBox(color: color),
  );
}
