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
///   page's surface.
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
    return Theme(
      data: theme.copyWith(focusColor: Colors.transparent, canvasColor: Colors.transparent),
      child: ChoiceChip(
        avatar: avatar,
        label: label,
        labelStyle: selected ? const TextStyle(fontWeight: FontWeight.w700) : null,
        selected: selected,
        onSelected: onSelected,
      ),
    );
  }
}
