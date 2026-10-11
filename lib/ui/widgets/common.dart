import 'dart:math' as math;
import 'dart:ui' show SemanticsHitTestBehavior;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n.dart';
import '../theme/app_theme.dart';
import 'ornaments.dart';

/// Screens narrower than this pad cards and sheets 16 instead of 20 or 24
/// (docs/DESIGN_SYSTEM.md §5).
const kNarrowScreenWidth = Breakpoints.narrow;

bool _isNarrow(BuildContext context) => MediaQuery.sizeOf(context).width < kNarrowScreenWidth;

/// Constrains page content to a readable width and centers it on wide
/// screens, so lines never get uncomfortably long (WCAG 1.4.8).
///
/// The column is [maxWidth] wide at most, gutters included, and by default
/// padded with the gutters at the sides, 8 above and 40 below
/// ([defaultPadding]). Below whatever padding it has, it clears the safe area,
/// so the end of a page over the whole screen is never under the gesture bar
/// (within the tabs, the navigation bar already keeps it clear).
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.maxWidth = ContentWidth.list, this.padding, this.controller})
      : header = const [],
        itemCount = 0,
        itemBuilder = null;

  /// A page of [header] and then [itemCount] items, each built by
  /// [itemBuilder] only as it scrolls into view: for lists that may grow
  /// long, such as a forum's threads or a thread's posts.
  const PageBody.builder({
    super.key,
    required this.itemCount,
    required IndexedWidgetBuilder this.itemBuilder,
    this.header = const [],
    this.maxWidth = ContentWidth.list,
    this.padding,
    this.controller,
  }) : children = const [];

  final List<Widget> children;
  final List<Widget> header;
  final int itemCount;
  final IndexedWidgetBuilder? itemBuilder;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;

  /// A page's padding: the gutters at the sides, 8 above and 40 below.
  static EdgeInsets defaultPadding(BuildContext context) {
    final g = Gutter.of(context);
    return EdgeInsets.fromLTRB(g, Space.sm, g, Space.s40);
  }

  /// The padding of a page of list tiles, which pad themselves 16 at the
  /// sides: the rest of the gutter, so that their text starts where the app
  /// bar's title and every other page's content do.
  static EdgeInsets tilePadding(BuildContext context) {
    final side = Gutter.of(context) - _tileInset;
    return EdgeInsets.fromLTRB(side, Space.sm, side, Space.s40);
  }

  /// A list tile's own padding at its start.
  static const _tileInset = Space.lg;

  @override
  Widget build(BuildContext context) {
    final p = (padding ?? defaultPadding(context)).resolve(Directionality.of(context)) +
        EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom);
    final itemBuilder = this.itemBuilder;
    if (itemBuilder != null) {
      return ListView.builder(
        controller: controller,
        // Scrollable even when it fits, as it is without a controller of its
        // own: so that it can be pulled to refresh.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: p.top, bottom: p.bottom),
        itemCount: header.length + itemCount,
        itemBuilder: (context, i) => Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.only(left: p.left, right: p.right),
              // Full width, as in a stretched column.
              child: SizedBox(
                width: double.infinity,
                child: i < header.length ? header[i] : itemBuilder(context, i - header.length),
              ),
            ),
          ),
        ),
      );
    }
    return ListView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: p,
              // The page is one item of its list. Its headings, texts and
              // controls are each a node of their own, never merged into one.
              child: Semantics(
                explicitChildNodes: true,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A page of the app (docs/DESIGN_SYSTEM.md §5): a [Scaffold] whose app bar
/// lines up with the page's column, however wide the window. Its title starts
/// where the column's content does, and its actions end where the column
/// does, rather than at the window's edges; and the page names the browser's
/// tab ([DocumentTitle]).
///
/// [contentMaxWidth] is the width of the page's column, as given to its
/// [PageBody]. The title is the page's heading, of level 1: [titleText], or
/// [title] where it shows the same some other way. [titleText] also names
/// the tab; [showTitle] false leaves the app bar without a title.
///
/// A page whose app bar shows something other than the page's own name
/// (a thread, under its forum's) sets [titleNamesPage] false: the app bar's
/// title is then no heading, nor what names the page to a screen reader as
/// it opens, and the page's body gives its own heading of level 1, which
/// names the route.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.titleText,
    this.title,
    this.showTitle = true,
    this.actions,
    this.leading,
    required this.body,
    this.contentMaxWidth = ContentWidth.list,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.bottom,
    this.showAppBar = true,
    this.titleNamesPage = true,
  });

  final String titleText;
  final Widget? title;
  final bool showTitle;
  final bool titleNamesPage;
  final List<Widget>? actions;

  /// The app bar's leading button, if not the back button it adds itself.
  final Widget? leading;
  final Widget body;
  final double contentMaxWidth;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final PreferredSizeWidget? bottom;
  final bool showAppBar;

  /// The width of the app bar's leading button.
  static const _leadingWidth = 56.0;

  @override
  Widget build(BuildContext context) => DocumentTitle(
        title: titleText,
        // The pane's width, which leaves out the navigation rail beside it.
        child: LayoutBuilder(builder: (context, constraints) {
          final g = Gutter.of(context);
          // Where the column's content starts, from the pane's edge: as in a
          // PageBody of this width.
          final inset = math.max(g, (constraints.maxWidth - contentMaxWidth) / 2 + g);
          // A back button, where the app bar adds one: the test it makes, but
          // for local history entries, which pages don't use.
          final hasLeading = leading != null || (ModalRoute.canPopOf(context) ?? false);
          return Scaffold(
            appBar: showAppBar
                ? AppBar(
                    leading: leading,
                    // The title's inset goes before it, and a gutter after it:
                    // as the app bar's titleSpacing, the inset would be kept
                    // after it too, which leaves a narrow column's title (the
                    // account's) no room at all on a wide screen.
                    titleSpacing: 0,
                    actionsPadding: EdgeInsetsDirectional.only(end: inset - g),
                    excludeHeaderSemantics: !titleNamesPage,
                    title: showTitle
                        ? Padding(
                            padding: EdgeInsetsDirectional.only(
                              start: hasLeading ? math.max(g, inset - _leadingWidth) : inset,
                              end: g,
                            ),
                            // The app bar makes it a heading; this gives its level.
                            child: titleNamesPage
                                ? Semantics(headingLevel: 1, child: title ?? AppBarTitle(titleText))
                                : title ?? AppBarTitle(titleText),
                          )
                        : null,
                    actions: actions,
                    bottom: bottom,
                  )
                : null,
            body: body,
            floatingActionButton: floatingActionButton,
            bottomNavigationBar: bottomNavigationBar,
          );
        }),
      );
}

/// An app bar's title, in the app bar's style: set a little smaller where
/// the line has no room for it (a wider interface font, or enlarged text,
/// beside the Demo tag and a button), as the reader's title is, and cut short
/// only once it would have to be smaller still. [PageScaffold] sets its
/// [PageScaffold.titleText] so; a page whose app bar shows another name (a
/// thread, its forum's) gives it as its [PageScaffold.title].
class AppBarTitle extends StatelessWidget {
  const AppBarTitle(this.text, {super.key});

  final String text;

  /// The smallest the title is set, of its size, before it is cut short.
  static const double minScale = 0.75;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        // As the app bar sets it: its style, and its text size, which it
        // keeps from growing past 1.34 times.
        final style = DefaultTextStyle.of(context).style;
        final size = MediaQuery.textScalerOf(context).scale(style.fontSize ?? 22);
        final painter = TextPainter(
          text: TextSpan(text: text, style: style.copyWith(fontSize: size)),
          textDirection: Directionality.of(context),
          locale: Localizations.maybeLocaleOf(context),
          maxLines: 1,
        )..layout();
        final width = painter.width;
        painter.dispose();
        if (width <= constraints.maxWidth) return Text(text, maxLines: 1, softWrap: false);
        final scale = math.max(minScale, constraints.maxWidth / width);
        return Text(
          text,
          style: TextStyle(fontSize: size * scale),
          textScaler: TextScaler.noScaling,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        );
      });
}

/// Names the page in the browser: its tab, history and bookmarks ("Settings
/// · Shnayim Mikra"). Only the page on show names it, the one on top in the
/// tab on show, and it names it again whenever it is shown again: when the
/// page over it closes, or its tab is chosen.
class DocumentTitle extends StatefulWidget {
  const DocumentTitle({super.key, required this.title, required this.child});

  /// The page's own title, before the app's name; empty for the app's name
  /// alone.
  final String title;
  final Widget child;

  /// Whether pages name the document: on the web, where it is the tab's
  /// title. Elsewhere the platform keeps the app's name, where it shows one
  /// (Android's recent apps, for one).
  @visibleForTesting
  static bool enabled = kIsWeb;

  @override
  State<DocumentTitle> createState() => _DocumentTitleState();
}

class _DocumentTitleState extends State<DocumentTitle> {
  /// What this page last gave the document while on show, or null while it
  /// isn't.
  ({String label, Color color})? _given;

  @override
  Widget build(BuildContext context) {
    if (!DocumentTitle.enabled) return widget.child;
    // Each depends on what it reads, so the page builds this again when it
    // comes into view or leaves it. A page beneath an opaque route has its
    // tickers off, as does every page of a tab not on show.
    final shown = (ModalRoute.isCurrentOf(context) ?? true) && TickerMode.valuesOf(context).enabled;
    if (!shown) {
      _given = null;
      return widget.child;
    }
    final app = context.l10n.appTitle;
    final label = widget.title.isEmpty || widget.title == app ? app : '${widget.title} · $app';
    // The colour the app gives the platform (MaterialApp.color): on the web
    // the browser's theme-color, which the app's own title sets again when
    // the theme changes.
    final color = Theme.of(context).colorScheme.surface;
    final given = (label: label, color: color);
    if (given != _given) {
      _given = given;
      SystemChrome.setApplicationSwitcherDescription(
        ApplicationSwitcherDescription(label: label, primaryColor: color.toARGB32()),
      );
    }
    return widget.child;
  }
}

/// A heading for a group of content, exposed to assistive technology as a
/// heading so screen reader users can jump between sections: an [Eyebrow] in
/// gold ink (§6.4), with an optional [trailing] control, such as an info
/// button, at the end.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.level = 2, this.trailing, this.padding}) : _plain = false;

  /// A heading in plain type, titleSmall in onSurfaceVariant, for a heading
  /// with digits in it ("2 of 7 aliyot"): an eyebrow's old-style small-cap
  /// figures make "1" read as "I".
  const SectionHeader.plain(this.text, {super.key, this.level = 2, this.trailing, this.padding}) : _plain = true;

  final String text;
  final int level;
  final Widget? trailing;

  /// 28 above, a section's gap, and 8 below, unless given.
  final EdgeInsetsGeometry? padding;
  final bool _plain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding ?? const EdgeInsetsDirectional.only(top: Rhythm.sectionGap, bottom: Space.sm),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              headingLevel: level,
              header: true,
              child: _plain
                  ? Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))
                  : Eyebrow(text),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Visual gap.
class Gap extends StatelessWidget {
  const Gap(this.size, {super.key});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size);
}

/// A card with consistent padding: 20, or 16 on a narrow screen (§6.3).
/// A card with [onTap] is one node for assistive technology, read out as a
/// whole; any other keeps its heading, text and controls apart, so that each
/// can be found and used on its own.
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.child, this.color, this.padding, this.onTap});

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding ?? EdgeInsets.all(_isNarrow(context) ? 16 : 20), child: child);
    if (onTap == null) return Card(color: color, semanticContainer: false, child: content);
    // The focus ring is drawn just outside the card, so this card mustn't clip
    // it as cards do. The ink stays inside: the ink well clips it to the same
    // corners.
    final radius = switch (Theme.of(context).cardTheme.shape) {
      RoundedRectangleBorder(:final borderRadius) => borderRadius.resolve(Directionality.of(context)),
      _ => const BorderRadius.all(Radius.circular(12)),
    };
    return Card(
      color: color,
      clipBehavior: Clip.none,
      child: SeferInkWell(onTap: onTap, borderRadius: radius, child: content),
    );
  }
}

/// A banner for important, non-blocking information (§6.20): bodyMedium on
/// a secondaryContainer wash, radius 12, with no border but high contrast's
/// 2 px outline. Place it within the page's gutters, never full-bleed.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.icon,
    required this.text,
    this.action,
    this.actionBelow = false,
    this.liveRegion = false,
  });

  final IconData icon;
  final String text;
  final Widget? action;

  /// Whether the banner is read out as it appears or its text changes: a
  /// live region, on the node that holds the text.
  final bool liveRegion;

  /// Puts [action] beneath the text, at the end, rather than beside it: for
  /// a text of more than a line or two, which would otherwise be squeezed.
  final bool actionBelow;

  /// [action] in the colour of interaction where that reads clearly on the
  /// banner (WCAG AA), and otherwise, as in the high-contrast themes, in the
  /// banner's own ink, with a focus ring to match.
  Widget? _legible(BuildContext context) {
    final action = this.action;
    if (action == null) return null;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    double luminance(Color c) => c.computeLuminance() + 0.05;
    final a = luminance(scheme.primary), b = luminance(scheme.secondaryContainer);
    final legible = (a > b ? a / b : b / a) >= 4.5;
    final color = legible ? scheme.primary : scheme.onSecondaryContainer;
    final themed = theme.textButtonTheme.style;
    var style = TextButton.styleFrom(foregroundColor: color);
    if (!legible) {
      // The theme's keyboard focus ring (§6.1), drawn in the banner's ink.
      style = style.copyWith(
        shape: WidgetStateProperty.resolveWith(
          (states) => switch (themed?.shape?.resolve(states)) {
            final FocusRingBorder focused =>
              FocusRingBorder(side: focused.side, borderRadius: focused.borderRadius, ring: color, gap: focused.gap),
            final shape => shape,
          },
        ),
      );
    }
    return TextButtonTheme(data: TextButtonThemeData(style: style.merge(themed)), child: action);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget message = Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSecondaryContainer));
    if (liveRegion) message = Semantics(liveRegion: true, child: message);
    final action = _legible(context);
    final below = actionBelow ? action : null;
    return Card(
      color: scheme.secondaryContainer,
      // The fill sets it apart; only high contrast outlines it (§6.20).
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        side: SeferColors.of(context).isHighContrast ? BorderSide(color: scheme.outline, width: 2) : BorderSide.none,
      ),
      child: Padding(
        // A trailing button's own padding makes up the end padding beside it.
        padding: EdgeInsetsDirectional.fromSTEB(16, 12, action == null ? 16 : 8, below == null ? 12 : 4),
        child: Row(
          crossAxisAlignment: below == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: scheme.onSecondaryContainer),
            const Gap(12),
            Expanded(
              child: below == null
                  ? message
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: message),
                        Align(alignment: AlignmentDirectional.centerEnd, child: below),
                      ],
                    ),
            ),
            if (below == null) ?action,
          ],
        ),
      ),
    );
  }
}

/// What a list shows while it has nothing in it (docs/DESIGN_SYSTEM.md
/// §6.22): a divider, one gentle sentence, and the action that would fill it.
/// Centred, at most 320 wide, 40 below whatever is above it.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.actionLabel, this.onAction});

  final String message;

  /// A tonal button under the message, shown when both are given.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SeferDivider(),
              const Gap(12),
              Text(message, style: SeferType.of(context).marginalia, textAlign: TextAlign.center),
              if (actionLabel != null && onAction != null) ...[
                const Gap(16),
                FilledButton.tonal(style: AppButtons.tonal(context), onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows a dialog in the app's style (docs/DESIGN_SYSTEM.md §6.19): it fades
/// in while growing from 98% over [Motion.short], or is simply there while
/// motion is reduced. Use it instead of [showDialog], which it otherwise
/// matches: the barrier dismisses it, it keeps the caller's theme, stays in
/// the safe area, and keeps keyboard focus inside until it closes.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  // The route showGeneralDialog pushes, plus showDialog's focus trap.
  return navigator.push<T>(RawDialogRoute<T>(
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: DialogTheme.of(context).barrierColor ?? Colors.black54,
    transitionDuration: Motion.of(context).d(Motion.short),
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    pageBuilder: (context, animation, secondaryAnimation) => Semantics(
      // Taps on the dialog never reach the barrier behind it.
      hitTestBehavior: SemanticsHitTestBehavior.opaque,
      child: SafeArea(child: themes.wrap(Builder(builder: builder))),
    ),
    transitionBuilder: _dialogTransition,
  ));
}

final _dialogCurve = CurveTween(curve: Motion.decelerate);
final _dialogScale = Tween<double>(begin: 0.98, end: 1).chain(_dialogCurve);

Widget _dialogTransition(
        BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) =>
    FadeTransition(
      opacity: animation.drive(_dialogCurve),
      child: ScaleTransition(scale: animation.drive(_dialogScale), child: child),
    );

/// The padding inside a sheet: 24, or 16 on a narrow screen (§6.19).
double sheetPadding(BuildContext context) => _isNarrow(context) ? 16 : 24;

/// Shows a modal bottom sheet in the app's style (docs/DESIGN_SYSTEM.md
/// §6.19): paper with a drag handle, at most 640 wide, in the safe area, and
/// with no slide while motion is reduced. Use it instead of
/// [showModalBottomSheet]. List tiles in the sheet line up with its
/// [SheetTitle].
///
/// [useRootNavigator] puts the sheet and its scrim over the whole screen,
/// the navigation bar too, when the page that opens it is shown within a
/// tab.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useRootNavigator = false,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useRootNavigator: useRootNavigator,
      useSafeArea: true,
      sheetAnimationStyle: Motion.of(context).style,
      builder: (context) {
        final padding = sheetPadding(context);
        return ListTileTheme.merge(
          contentPadding: EdgeInsetsDirectional.symmetric(horizontal: padding),
          child: Builder(builder: builder),
        );
      },
    );

/// A sheet's title, under its drag handle: titleLarge, and a heading for
/// screen readers.
class SheetTitle extends StatelessWidget {
  const SheetTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final padding = sheetPadding(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(padding, 0, padding, 8),
      child: Semantics(
        header: true,
        headingLevel: 2,
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}
