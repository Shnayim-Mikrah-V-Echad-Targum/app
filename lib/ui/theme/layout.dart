import 'package:flutter/widgets.dart';

// The layout tokens of docs/DESIGN_SYSTEM.md §5: a 4 pt grid, three window
// sizes, the page gutters and content widths that follow from them, and the
// rhythm of cards and sections.

/// The spacing scale, on a 4 pt grid.
abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double s28 = 28;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;
}

/// Window widths at which the layout changes: compact below [medium] (a
/// phone, with the navigation bar), medium up to [expanded] (the compact
/// rail), and expanded from there (the rail with its labels).
abstract final class Breakpoints {
  static const medium = 600.0;
  static const expanded = 1200.0;

  /// Below this, cards and sheets pad 16 rather than 20 or 24.
  static const narrow = 360.0;
}

/// The page's side margins: 20 on a phone, 24 on a tablet and 32 from
/// [Breakpoints.expanded], by the window's width, so that every page of one
/// window shares them.
abstract final class Gutter {
  static const double compact = 20;
  static const double medium = 24;
  static const double expanded = 32;

  static double of(BuildContext context) => forWidth(MediaQuery.sizeOf(context).width);

  static double forWidth(double windowWidth) => windowWidth >= Breakpoints.expanded
      ? expanded
      : windowWidth >= Breakpoints.medium
          ? medium
          : compact;
}

/// How wide a page's column grows, gutters included, before it is centred.
/// The reading column has widths of its own (LineWidth).
abstract final class ContentWidth {
  /// Lists and dashboards: most pages.
  static const double list = 720;

  /// Running text: the Guide, Sources and the policies.
  static const double longform = 620;

  /// Signing in and the account.
  static const double account = 440;

  /// Today's two columns, from [Breakpoints.expanded].
  static const double todayWide = 1040;
}

/// The vertical rhythm of a page.
abstract final class Rhythm {
  /// Inside a card: 20, or 16 below [Breakpoints.narrow].
  static const double cardPadding = 20;
  static const double cardPaddingNarrow = 16;

  /// Between one card and the next.
  static const double cardGap = 12;

  /// Between one section of a page and the next.
  static const double sectionGap = 28;

  /// Between the parts of a card.
  static const double inCardGap = 12;
}
