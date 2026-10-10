import 'dart:ui' show SemanticsHitTestBehavior;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ornaments.dart';

/// Screens narrower than this pad cards and sheets 16 instead of 20 or 24
/// (docs/DESIGN_SYSTEM.md §5).
const kNarrowScreenWidth = 360.0;

bool _isNarrow(BuildContext context) => MediaQuery.sizeOf(context).width < kNarrowScreenWidth;

/// Constrains page content to a readable width and centers it on wide
/// screens, so lines never get uncomfortably long (WCAG 1.4.8).
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.maxWidth = 760, this.padding, this.controller})
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
    this.maxWidth = 760,
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

  static const _defaultPadding = EdgeInsets.fromLTRB(16, 8, 16, 32);

  @override
  Widget build(BuildContext context) {
    final itemBuilder = this.itemBuilder;
    if (itemBuilder != null) {
      final p = (padding ?? _defaultPadding).resolve(Directionality.of(context));
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
              padding: padding ?? _defaultPadding,
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

/// A heading for a group of content, exposed to assistive technology as a
/// heading so screen reader users can jump between sections.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.level = 2, this.trailing, this.padding});

  final String text;
  final int level;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding ?? const EdgeInsetsDirectional.only(top: 24, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              headingLevel: level,
              header: true,
              child: Text(
                text,
                style: (level <= 2 ? theme.textTheme.titleMedium : theme.textTheme.titleSmall)
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
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

/// A banner for important, non-blocking information.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({super.key, required this.icon, required this.text, this.action, this.actionBelow = false});

  final IconData icon;
  final String text;
  final Widget? action;

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
    final scheme = Theme.of(context).colorScheme;
    final message = Text(text, style: TextStyle(color: scheme.onSecondaryContainer));
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
