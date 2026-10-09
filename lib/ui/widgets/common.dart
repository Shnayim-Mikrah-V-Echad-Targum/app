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
  const NoticeBanner({super.key, required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
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
