import 'package:flutter/material.dart';

/// A [ChoiceChip] as docs/DESIGN_SYSTEM.md §6.6 draws it. The theme sets the
/// colours, border and size; this adds what ChipThemeData can't express:
///
/// - the label is bold when [selected], which with the heavier border tells
///   the selected chip apart without relying on colour;
/// - keyboard focus is shown by the theme's ring alone. A chip would otherwise
///   also fill with ThemeData.focusColor, which reads as a selection;
/// - an unselected chip is transparent on paper too (in a dialog or a card).
///   The chip's Material would otherwise take ThemeData.canvasColor, the
///   page's surface;
/// - a label too long for the line, as at the largest text sizes, wraps
///   between its words, the chip growing as tall as it needs, rather than
///   fading out mid-word. (Not beside an [avatar], whose chip keeps one line.)
class SeferChoiceChip extends StatelessWidget {
  const SeferChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.avatar,
  });

  final Widget label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipTheme = ChipTheme.of(context);
    final direction = Directionality.of(context);
    final padding = chipTheme.padding?.resolve(direction);
    final labelPadding = chipTheme.labelPadding?.resolve(direction);
    // A chip measures its label's height at the chip's whole width, then
    // sets it in what is left beside the chip's padding and the label's: a
    // label that wraps there would need more lines than it was given room
    // for. So the label carries that padding itself, and is set as wide as
    // it was measured. The chip comes out the same size either way.
    final wraps = avatar == null && padding != null && labelPadding != null;
    return Theme(
      data: theme.copyWith(focusColor: Colors.transparent, canvasColor: Colors.transparent),
      child: ChoiceChip(
        avatar: avatar,
        padding: wraps ? EdgeInsets.only(top: padding.top, bottom: padding.bottom) : null,
        labelPadding: wraps ? EdgeInsets.only(top: labelPadding.top, bottom: labelPadding.bottom) : null,
        label: wraps
            ? Padding(
                padding: EdgeInsets.only(
                  left: padding.left + labelPadding.left,
                  right: padding.right + labelPadding.right,
                ),
                child: Builder(builder: (context) {
                  final ambient = DefaultTextStyle.of(context);
                  return DefaultTextStyle(
                    style: ambient.style,
                    textAlign: ambient.textAlign,
                    textWidthBasis: ambient.textWidthBasis,
                    textHeightBehavior: ambient.textHeightBehavior,
                    child: label,
                  );
                }),
              )
            : label,
        labelStyle: selected ? const TextStyle(fontWeight: FontWeight.w700) : null,
        selected: selected,
        onSelected: onSelected,
      ),
    );
  }
}
