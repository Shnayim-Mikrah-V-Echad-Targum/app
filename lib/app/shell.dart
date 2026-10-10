import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/search/go_to_verse_sheet.dart';
import '../ui/l10n.dart';
import '../ui/theme/app_theme.dart';
import '../ui/widgets/app_mark.dart';
import 'system_bars.dart';

/// Breakpoints follow Material 3 window size classes.
abstract final class Breakpoints {
  static const medium = 600.0;
  static const expanded = 1200.0;
}

/// Bottom navigation on phones; a navigation rail on tablets and desktops
/// (docs/DESIGN_SYSTEM.md §6.9 and §6.10).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  /// The rail's width from [Breakpoints.medium], and from
  /// [Breakpoints.expanded], where its labels sit beside the icons. Its
  /// hairline lies outside these widths. Large text, or a wide accessibility
  /// font, can widen the compact rail to fit its labels.
  static const railWidth = 80.0;
  static const extendedRailWidth = 256.0;

  /// The rail's keyboard focus wash, in onSurface at this opacity: the bar's
  /// (see AppTheme's navigationBarTheme), as neither draws a ring.
  static const _focusWash = 0.32;

  void _go(int index) => shell.goBranch(index, initialLocation: index == shell.currentIndex);

  // Ctrl+K (⌘K) goes to a verse, or searches, from any tab.
  @override
  Widget build(BuildContext context) => GoToVerseShortcut(child: _layout(context));

  Widget _layout(BuildContext context) {
    final l = context.l10n;
    final sefer = SeferColors.of(context);
    // 1 px, or a 2 px outline in high contrast.
    final hairline = BorderSide(color: sefer.hairline, width: sefer.hairlineWidth);
    final items = [
      (Icons.today_outlined, Icons.today, l.navToday),
      (Icons.menu_book_outlined, Icons.menu_book, l.navParsha),
      // Echoes the parsha rings.
      (Icons.donut_large_outlined, Icons.donut_large, l.navProgress),
      (Icons.forum_outlined, Icons.forum, l.navCommunity),
      (Icons.settings_outlined, Icons.settings, l.navSettings),
    ];
    final width = MediaQuery.sizeOf(context).width;

    if (width < Breakpoints.medium) {
      return Scaffold(
        body: shell,
        // Where Android's navigation bar can't be see-through, it takes the
        // colour of this bar rather than the page's.
        bottomNavigationBar: SystemBars(
          navigationBarColor: NavigationBarTheme.of(context).backgroundColor,
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border(top: hairline)),
            child: Padding(
              padding: EdgeInsets.only(top: hairline.width),
              child: _NavBar(
                selectedIndex: shell.currentIndex,
                onSelected: _go,
                destinations: [
                  for (final (icon, selected, label) in items)
                    NavigationDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: label),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final extended = width >= Breakpoints.expanded;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // Keyboard users reach the rail first, then the page.
            FocusTraversalGroup(
              // The rail draws no ring either, so keyboard focus is the bar's
              // strong wash rather than the theme's 24% tint.
              child: Theme(
                data: theme.copyWith(focusColor: theme.colorScheme.onSurface.withValues(alpha: _focusWash)),
                child: DecoratedBox(
                  decoration: BoxDecoration(border: BorderDirectional(end: hairline)),
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(end: hairline.width),
                    child: NavigationRail(
                      extended: extended,
                      minWidth: railWidth,
                      minExtendedWidth: extendedRailWidth,
                      // A phone held sideways, or large text, can need more
                      // height than the window has.
                      scrollable: true,
                      selectedIndex: shell.currentIndex,
                      onDestinationSelected: _go,
                      labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                      leading: _RailHeader(extended: extended),
                      destinations: [
                        for (final (icon, selected, label) in items)
                          NavigationRailDestination(
                            icon: Icon(icon),
                            selectedIcon: Icon(selected),
                            label: _RailLabel(label, extended: extended),
                            // Beside their labels, destinations are 56 high
                            // (Material's 44 is short of a tap target). Under
                            // them, they keep Material's 64, whose spacing the
                            // framework fixes (§6.10), and leave the labels 76
                            // of the rail's 80, which the longest needs in bold.
                            padding: extended
                                ? const EdgeInsets.symmetric(vertical: 6)
                                : const EdgeInsets.symmetric(horizontal: 2),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: FocusTraversalGroup(child: shell)),
          ],
        ),
      ),
    );
  }
}

/// The phone's navigation bar (§6.9): 72 high, and taller only as far as its
/// labels need when the system text is large.
///
/// NavigationBar scales its labels up to 1.3× and wraps them within their
/// fifth of the width, so a long one ("Community") would break inside the
/// word and spill out of a fixed height. Here the labels grow with the text
/// size only while the widest of them, in bold, still fits its slot on one
/// line. A font too wide for that at its normal size shrinks them, to 70% at
/// most, rather than break a word; past that they wrap. The bar is as tall as
/// the tallest label needs.
class _NavBar extends StatelessWidget {
  const _NavBar({required this.selectedIndex, required this.onSelected, required this.destinations});

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<NavigationDestination> destinations;

  static const _minHeight = 72.0;

  /// Everything but the label: the icon's 32, the label's 4 px gap above it,
  /// and 10 above and below (72 = 32 + 4 + 16 + 20).
  static const _chrome = 32 + 4 + 20.0;

  /// The most Material scales a label, and the least this bar shrinks one.
  static const _maxScale = 1.3;
  static const _minScale = 0.7;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Selected labels are bold, so every label is measured that way.
    final style = NavigationBarTheme.of(context).labelTextStyle!.resolve({WidgetState.selected})!;
    final direction = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    return LayoutBuilder(builder: (context, constraints) {
      final slot = (constraints.maxWidth - mq.padding.horizontal) / destinations.length;
      double measure(double Function(TextPainter) value, TextScaler scaler, {double maxWidth = double.infinity}) {
        var most = 0.0;
        for (final d in destinations) {
          final painter = TextPainter(
            text: TextSpan(text: d.label, style: style),
            textDirection: direction,
            locale: locale,
            textScaler: scaler,
          )..layout(maxWidth: maxWidth);
          most = math.max(most, value(painter));
          painter.dispose();
        }
        return most;
      }

      final fontSize = style.fontSize!;
      final fits = slot / measure((p) => p.width, TextScaler.noScaling);
      final scale = math.min(math.min(mq.textScaler.scale(fontSize) / fontSize, _maxScale), math.max(fits, _minScale));
      final scaler = TextScaler.linear(scale);
      final height = _chrome + measure((p) => p.height, scaler, maxWidth: slot);
      return MediaQuery(
        data: mq.copyWith(textScaler: scaler),
        child: NavigationBar(
          height: math.max(height, _minHeight),
          // Material's own 500 ms, or none while motion is reduced.
          animationDuration: Motion.of(context).d(const Duration(milliseconds: 500)),
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelected,
          destinations: destinations,
        ),
      );
    });
  }
}

/// The head of the rail: the app's mark, joined by the app's name as the
/// rail extends.
class _RailHeader extends StatelessWidget {
  const _RailHeader({required this.extended});

  /// Whether the destinations show their labels beside the icons. They widen
  /// into it with the rail's animation, and fold back at once.
  final bool extended;

  static const _markSize = 40.0;
  static const _iconSize = 24.0;

  /// Under the rail's own 8 px, this centres the mark on the app bar (64).
  static const _padding = EdgeInsets.only(top: 4, bottom: 12);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final animation = NavigationRail.extendedAnimation(context);
    final reduced = Motion.of(context).reduced;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        // With motion reduced, the name is simply there or not.
        final t = extended ? (reduced ? 1.0 : animation.value) : 0.0;
        // Compact: the mark alone, centred, announced as the app's name.
        if (t == 0) {
          return Padding(padding: _padding, child: AppMark(size: _markSize, semanticLabel: l.appTitle));
        }

        // Extended: the mark moves to the icons' start edge, so that the name,
        // after a 12 px gap, starts where the labels do. The name is
        // announced, as a heading, and the mark is not. The header widens
        // with the destinations and fades the name in with their labels.
        final width = lerpDouble(AppShell.railWidth, AppShell.extendedRailWidth, t)!;
        final markStart = lerpDouble(
          (AppShell.railWidth - _markSize) / 2,
          (AppShell.railWidth - _iconSize) / 2,
          t,
        )!;
        return ClipRect(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: width / AppShell.extendedRailWidth,
            child: SizedBox(
              width: AppShell.extendedRailWidth,
              child: Padding(
                padding: _padding.add(EdgeInsetsDirectional.only(start: markStart, end: 16)),
                child: Row(
                  children: [
                    const AppMark(size: _markSize),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Opacity(
                        opacity: const Interval(0, 0.25).transform(t),
                        child: Semantics(
                          header: true,
                          child: Text(l.appTitle, style: SeferType.of(context).wordmark),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A destination's label. Under the icon it keeps one width in either state,
/// its bold selected weight laid out unseen beneath it, so selecting a tab
/// never widens the rail. Beside the icon it takes labelLarge's size.
class _RailLabel extends StatelessWidget {
  const _RailLabel(this.text, {required this.extended});

  final String text;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    // The rail sets the colour and weight for the state; these merge with it.
    if (extended) {
      final large = Theme.of(context).textTheme.labelLarge!;
      return Text(
        text,
        style: TextStyle(fontSize: large.fontSize, height: large.height, letterSpacing: large.letterSpacing),
      );
    }
    final bold = NavigationRailTheme.of(context).selectedLabelTextStyle?.fontWeight;
    return Stack(
      alignment: Alignment.center,
      children: [
        Visibility(
          visible: false,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: Text(text, style: TextStyle(fontWeight: bold)),
        ),
        Text(text),
      ],
    );
  }
}
