import 'package:flutter/material.dart';

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
                    ?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
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

/// A card with consistent padding.
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.child, this.color, this.padding = const EdgeInsets.all(16), this.onTap});

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Card(
      color: color,
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
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
    final color = (a > b ? a / b : b / a) >= 4.5 ? scheme.primary : scheme.onSecondaryContainer;
    final style = TextButton.styleFrom(foregroundColor: color).copyWith(
      side: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused) ? BorderSide(color: color, width: 3) : null,
      ),
    );
    return TextButtonTheme(data: TextButtonThemeData(style: style.merge(theme.textButtonTheme.style)), child: action);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final message = Text(text, style: TextStyle(color: scheme.onSecondaryContainer));
    final action = _legible(context);
    final below = actionBelow ? action : null;
    return Card(
      color: scheme.secondaryContainer,
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
