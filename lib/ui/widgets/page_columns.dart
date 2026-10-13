import 'package:flutter/widgets.dart';

import '../theme/layout.dart';

/// A page's two columns on a desktop (docs/DESIGN_SYSTEM.md §9: Today 9,
/// Progress 10, Parsha tab 6): [startFlex] parts of the width for [start]
/// and [endFlex] for [end], 24 apart and level at the top. Each column is a
/// group of its own, for keyboard focus and for screen readers, so that both
/// go down the one before the other, rather than across from one to the
/// other by what stands level on the page.
///
/// Until [wide], the two stand one above the other, [stackedGap] apart, as
/// one column. Either way they are the same widgets in the same places, so
/// that a window widened or narrowed across [Breakpoints.expanded] keeps
/// what they hold: the keyboard's focus, a title page's drawn frame, a
/// discussion opening, a book of the Torah map opened.
class PageColumns extends StatelessWidget {
  const PageColumns({
    super.key,
    required this.start,
    required this.end,
    required this.wide,
    this.startFlex = 7,
    this.endFlex = 5,
    this.stackedGap = Rhythm.cardGap,
  });

  /// The first column: at the start (the left, or in Hebrew the right), and
  /// above [end] while not [wide].
  final List<Widget> start;
  final List<Widget> end;

  /// Whether the two stand side by side.
  final bool wide;
  final int startFlex;
  final int endFlex;

  /// Between [start] and [end] as they stand one above the other: a card's
  /// gap, or a section's where [end] begins a section of its own, its header
  /// then set with nothing above it, so that side by side it starts level
  /// with [start].
  final double stackedGap;

  static const _gap = Space.xxl;

  @override
  Widget build(BuildContext context) {
    Widget column(List<Widget> children) => FocusTraversalGroup(
          child: Semantics(
            // As one column, its parts are the page's own, as before.
            container: wide,
            // Its headings, texts and controls each a node of their own, as
            // in the page's single column.
            explicitChildNodes: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        );
    // A Flex in either direction, rather than a Row or a Column, which as
    // widgets of different kinds would build both columns anew.
    return Flex(
      direction: wide ? Axis.horizontal : Axis.vertical,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.stretch,
      children: [
        Flexible(flex: wide ? startFlex : 0, fit: FlexFit.tight, child: column(start)),
        SizedBox(width: wide ? _gap : 0, height: wide ? 0 : stackedGap),
        Flexible(flex: wide ? endFlex : 0, fit: FlexFit.tight, child: column(end)),
      ],
    );
  }
}
