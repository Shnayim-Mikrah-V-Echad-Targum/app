import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import 'reader_flow.dart';

/// Where the reader is among the three readings of the verses on screen
/// (docs/DESIGN_SYSTEM.md §6.17): "1 · Mikra", "2 · Mikra" and "3 · Targum"
/// side by side, each over a bar in its ring colour once reached. A reading
/// done is checked, and the one under way is set in bold.
///
/// It only shows what the instruction under it says ("Read the Hebrew
/// again", spoken with "Reading 2 of 3"), so screen readers skip it.
class PassTrack extends StatelessWidget {
  const PassTrack({super.key, required this.steps, required this.step});

  /// The steps of the verses on screen, and the one under way.
  final List<StepKind> steps;
  final int step;

  static const int _segments = 3;

  /// The segment [kind] belongs to: the Hebrew read once, then again, then
  /// everything that makes up the third reading (the Targum or Rashi, or
  /// both, and a verse's Hebrew read a third time with them). Ending with the
  /// last verse once more comes after all three.
  static int segmentOf(StepKind kind) => switch (kind) {
        StepKind.mikra1 => 0,
        StepKind.mikra2 => 1,
        StepKind.repeatLast => _segments,
        StepKind.targum || StepKind.rashi || StepKind.thirdHebrew => 2,
      };

  /// What the third segment is named for: the step under way while it is in
  /// that segment, otherwise its first step, or once past it, its last.
  StepKind get _thirdKind {
    final kind = steps[step];
    final current = segmentOf(kind);
    if (current == 2) return kind;
    final third = steps.where((k) => segmentOf(k) == 2);
    return current < 2 ? third.first : third.last;
  }

  String _name(AppLocalizations l, StepKind kind) => switch (kind) {
        StepKind.targum => l.passTargum,
        StepKind.rashi => l.passRashi,
        StepKind.mikra1 || StepKind.mikra2 || StepKind.thirdHebrew || StepKind.repeatLast => l.passTrackMikra,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final current = segmentOf(steps[step]);
    final names = [l.passTrackMikra, l.passTrackMikra, _name(l, _thirdKind)];
    return ExcludeSemantics(
      child: Row(
        // The bars on one line, should a label be set smaller to fit.
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < _segments; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _Segment(
                index: i,
                label: l.passTrackLabel(i + 1, names[i]),
                state: i < current
                    ? _SegmentState.done
                    : (i == current ? _SegmentState.current : _SegmentState.upcoming),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _SegmentState { done, current, upcoming }

class _Segment extends StatelessWidget {
  const _Segment({required this.index, required this.label, required this.state});

  final int index;
  final String label;
  final _SegmentState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sefer = SeferColors.of(context);
    final current = state == _SegmentState.current;
    final style = theme.textTheme.labelMedium?.copyWith(
      color: current ? scheme.onSurface : scheme.onSurfaceVariant,
      fontWeight: current ? FontWeight.w700 : null,
    );
    final bar = state == _SegmentState.upcoming
        ? sefer.ringTrack
        : [sefer.ringMikra1, sefer.ringMikra2, sefer.ringTargum][index];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // On one line, made a little smaller should large text need it:
        // "3 ·" over "Targum" would read as two labels.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state == _SegmentState.done) ...[
                // As large as the text it marks.
                Icon(Icons.check, size: MediaQuery.textScalerOf(context).scale(14), color: scheme.primary),
                const SizedBox(width: 4),
              ],
              Text(label, style: style),
            ],
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: Motion.of(context).d(Motion.short),
          height: 4,
          decoration: BoxDecoration(color: bar, borderRadius: const BorderRadius.all(Radius.circular(2))),
        ),
      ],
    );
  }
}
