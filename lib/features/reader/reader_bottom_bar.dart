import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/lines.dart';
import '../progress/domain/progress_models.dart' show kAliyot;
import '../settings/app_settings.dart';
import 'reader_flow.dart';

/// The guided reader's bar (docs/DESIGN_SYSTEM.md §6.18): a thin bar of
/// progress through the aliyah, then Back, where the reader is ("Verse 1 of
/// 21") and Next, which says Finish on the aliyah's last step.
///
/// It runs under the gesture bar, in the page's own colour, so nothing shows
/// beneath it; its content keeps to the reading column, so on a wide screen
/// Back and Next stay near the text.
class ReaderBottomBar extends StatelessWidget {
  const ReaderBottomBar({
    super.key,
    required this.flow,
    required this.chunk,
    required this.step,
    this.aliyah = 0,
    this.order,
    required this.onBack,
    required this.onNext,
    required this.backFocus,
    required this.nextFocus,
    required this.maxWidth,
  });

  final ReaderFlow flow;
  final int chunk;
  final int step;

  /// The aliyah shown, and in the whole parsha the order of its steps
  /// ([ReadingMethod.wholeParsha]): the bar then tells of the parsha, not of
  /// the aliyah alone.
  final int aliyah;
  final ParshaOrder? order;

  /// Null at the first step, where there is nothing to go back to.
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final FocusNode backFocus;
  final FocusNode nextFocus;

  /// The reading column's width.
  final double maxWidth;

  /// The side padding: [maxWidth] is the width of the bar's content.
  static const double _side = 16;

  /// Below this width, or with large text, the position goes beside the
  /// progress bar, and the buttons below share the width.
  static const double _stackBelow = 400;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sefer = SeferColors.of(context);
    final motion = Motion.of(context);
    final c = flow.chunks[chunk];
    final position = switch (flow.method) {
      ReadingMethod.verseByVerse => l.verseOf(c.start + 1, flow.verses.length),
      ReadingMethod.wholeParsha => l.aliyahOf(aliyah + 1, kAliyot),
      _ => l.sectionOf(chunk + 1, flow.chunks.length),
    };
    final double fraction;
    final bool last;
    if (order case final order?) {
      // Progress through the whole parsha, in steps.
      final at = math.max(0, order.indexOf(aliyah, step));
      fraction = at / order.sequence.length;
      last = at == order.sequence.length - 1;
    } else {
      // Progress through the whole aliyah, in steps.
      var done = 0;
      for (var i = 0; i < chunk; i++) {
        done += flow.stepsFor(i).length;
      }
      done += step;
      fraction = done / flow.totalSteps;
      last = chunk == flow.chunks.length - 1 && step == flow.stepsFor(chunk).length - 1;
    }

    final progress = Semantics(
      label: position,
      value: '${(fraction * 100).round()}%',
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: fraction),
          duration: motion.d(Motion.medium),
          curve: Motion.standard,
          builder: (context, value, _) => LinearProgressIndicator(
            value: value,
            minHeight: 3,
            borderRadius: const BorderRadius.all(Radius.circular(2)),
            color: scheme.primary,
            backgroundColor: sefer.ringTrack,
          ),
        ),
      ),
    );
    Text where(TextAlign align) => Text(
          position,
          textAlign: align,
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
    final back = TextButton.icon(
      focusNode: backFocus,
      onPressed: onBack,
      style: TextButton.styleFrom(foregroundColor: scheme.onSurfaceVariant, iconColor: scheme.onSurfaceVariant),
      icon: const Icon(Icons.chevron_left),
      // Never broken inside its word, as two labels side by side at a very
      // large text size would be.
      label: WholeWords(l.actionBack),
    );
    // Next points the way the text runs; only Finish, which ends the aliyah,
    // has a check (DESIGN_SYSTEM.md §0, correction 5).
    final next = FilledButton.icon(
      focusNode: nextFocus,
      onPressed: onNext,
      style: FilledButton.styleFrom(minimumSize: const Size(128, 52)),
      icon: Icon(last ? Icons.check : Icons.chevron_right),
      iconAlignment: last ? IconAlignment.start : IconAlignment.end,
      label: WholeWords(last ? l.finishStep : l.actionNext),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: sefer.hairline, width: sefer.hairlineWidth),
        ),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 8),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth + 2 * _side),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < _stackBelow || MediaQuery.textScalerOf(context).scale(14) > 24;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(_side, 12, _side, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (stacked) ...[
                        // The position ends the progress bar's line rather
                        // than taking a line of its own, so that with large
                        // text on a phone the bar is two rows, not three.
                        Row(
                          children: [
                            Expanded(child: progress),
                            const SizedBox(width: 12),
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: constraints.maxWidth * 2 / 3),
                              child: where(TextAlign.end),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: back),
                            const SizedBox(width: 12),
                            Expanded(child: next),
                          ],
                        ),
                      ] else ...[
                        progress,
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            back,
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: where(TextAlign.center),
                              ),
                            ),
                            next,
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
