import 'package:flutter/material.dart';

import '../theme/sefer_colors.dart';

/// A small static tag (docs/DESIGN_SYSTEM.md §6.21, §9): a word beside a
/// name, such as "Question" or "Author" on a post, a source's license or
/// "Moderator" on the account card. labelSmall in onSecondaryContainer on
/// secondaryContainer, radius 6, padding 6/1, with an optional leading
/// [icon] at 14, 4 before the word.
///
/// It is a label, never a control: no outline but high contrast's 2 px one
/// (the pale fill alone barely shows there), which is drawn outside the
/// padding, and no ink, so it isn't taken for a button. The Demo tag, which
/// opens an explanation, is a button of its own (`DemoTag`).
class SeferTag extends StatelessWidget {
  const SeferTag(this.label, {super.key, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ink = scheme.onSecondaryContainer;
    final icon = this.icon;
    final text = Text(label, style: theme.textTheme.labelSmall?.copyWith(color: ink));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        border: SeferColors.of(context).isHighContrast ? Border.all(color: scheme.outline, width: 2) : null,
      ),
      child: icon == null
          ? text
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: ink),
                const SizedBox(width: 4),
                Flexible(child: text),
              ],
            ),
    );
  }
}
