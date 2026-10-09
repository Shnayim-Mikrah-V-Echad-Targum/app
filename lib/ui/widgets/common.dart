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
  const PageBody({super.key, required this.children, this.maxWidth = 760, this.padding, this.controller});

  final List<Widget> children;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: controller,
      padding: EdgeInsets.zero,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: padding ?? const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
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
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.child, this.color, this.padding, this.onTap});

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding ?? EdgeInsets.all(_isNarrow(context) ? 16 : 20), child: child);
    if (onTap == null) return Card(color: color, child: content);
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
  const NoticeBanner({super.key, required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      // The fill sets it apart; only high contrast outlines it (§6.20).
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        side: SeferColors.of(context).isHighContrast ? BorderSide(color: scheme.outline, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 12),
        child: Row(
          children: [
            Icon(icon, color: scheme.onSecondaryContainer),
            const Gap(12),
            Expanded(child: Text(text, style: TextStyle(color: scheme.onSecondaryContainer))),
            ?action,
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
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
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
