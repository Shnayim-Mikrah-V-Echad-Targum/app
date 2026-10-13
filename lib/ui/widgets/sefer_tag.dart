import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/sefer_colors.dart';
import 'lines.dart';

/// A small static tag (docs/DESIGN_SYSTEM.md §6.20): a word beside a name,
/// such as "Question" or "Author" on a post, a source's license or
/// "Moderator" on the account card. labelSmall in onSecondaryContainer on
/// secondaryContainer, radius 6, padding 6/1, with an optional leading
/// [icon] at 14, 4 before the word and level with its first line.
///
/// Its words stay whole, as any word of the interface does: one too wide
/// for the room it is given, as at the largest text sizes beside the
/// account card's initial, is set just small enough to fit ([WholeWords]),
/// though never below 12.
///
/// It is a label, never a control: no outline but high contrast's 2 px one
/// (the pale fill alone barely shows there), which is drawn outside the
/// padding, and no ink, so it isn't taken for a button. The Demo tag, which
/// opens an explanation, is a button of its own (`DemoTag`).
class SeferTag extends StatelessWidget {
  const SeferTag(this.label, {super.key, this.icon});

  final String label;
  final IconData? icon;

  static const double _iconSize = 14;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ink = scheme.onSecondaryContainer;
    final icon = this.icon;
    final style = theme.textTheme.labelSmall!.copyWith(color: ink);
    final text = WholeWords(label, style: style, textAlign: TextAlign.start, minFontSize: WholeWords.smallestSize);
    final outline = SeferColors.of(context).isHighContrast ? 2.0 : 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _padding, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        border: outline > 0 ? Border.all(color: scheme.outline, width: outline) : null,
      ),
      child: icon == null
          ? text
          : LayoutBuilder(
              builder: (context, constraints) {
                // The word's first line as it is set: at the text's size, or
                // smaller where the word is too wide for what the icon leaves
                // it (as WholeWords sets it, no smaller than its floor).
                final scaler = MediaQuery.textScalerOf(context);
                final size = scaler.scale(style.fontSize!);
                final room = constraints.maxWidth - _iconSize - _iconGap;
                final fit = WholeWords.scaleIn(context, label, width: room, style: style);
                final scale = math.max(fit, math.min(1.0, WholeWords.smallestSize / size));
                final line = size * (style.height ?? 1) * scale;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: math.max(0, (line - _iconSize) / 2)),
                      child: Icon(icon, size: _iconSize, color: ink),
                    ),
                    const SizedBox(width: _iconGap),
                    Flexible(child: text),
                  ],
                );
              },
            ),
    );
  }

  static const double _padding = 6;
  static const double _iconGap = 4;
}
