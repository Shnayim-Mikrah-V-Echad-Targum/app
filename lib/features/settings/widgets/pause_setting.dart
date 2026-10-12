import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/calendar/local_date.dart';
import '../../../services/feedback.dart';
import '../../../ui/l10n.dart';
import '../../../ui/theme/layout.dart';
import '../../../ui/widgets/common.dart';
import '../../../ui/widgets/sefer_choice_chip.dart';
import '../../progress/domain/progress_models.dart';

/// The longest a pause runs, as the pause dialog says.
const kMaxPauseDays = 30;

/// The days a pause covering [day] runs, through any pauses that overlap it
/// or follow it without a day between, as one: null when none covers [day].
/// A pause made while another lasts is part of the same rest, whichever was
/// made first.
({LocalDate start, LocalDate end})? pauseCovering(Iterable<Pause> pauses, LocalDate day) {
  final live = [for (final p in pauses) if (!p.deleted) p];
  final covering = live.where((p) => p.contains(day));
  if (covering.isEmpty) return null;
  var start = covering.map((p) => p.start).reduce((a, b) => a < b ? a : b);
  var end = covering.map((p) => p.end).reduce((a, b) => a > b ? a : b);
  for (var grew = true; grew;) {
    grew = false;
    for (final p in live) {
      if (p.start <= end.addDays(1) && p.end >= start.addDays(-1) && (p.start < start || p.end > end)) {
        if (p.start < start) start = p.start;
        if (p.end > end) end = p.end;
        grew = true;
      }
    }
  }
  return (start: start, end: end);
}

/// Ends the pause covering today, as of yesterday, and says so: back by
/// choice, with no welcome back on Today.
void resumePause(BuildContext context, WidgetRef ref) {
  final today = ref.read(todayProvider);
  ref.read(progressProvider.notifier).endPause(today);
  ref.read(settingsProvider.notifier).update((s) => s.copyWith(pauseEndSeen: today.addDays(-1)));
  showStatus(context, context.l10n.pauseEnded);
}

/// The days by which [pause] may be extended: as long as it then lasts
/// [kMaxPauseDays] in all, counted from its first day, as a new pause may.
/// (A pause covering today has a day already, so a month more never fits.)
List<int> pauseExtensions(({LocalDate start, LocalDate end}) pause) => [
      for (final d in const [1, 3, 7, 14])
        if (pause.end.addDays(d).differenceInDays(pause.start) + 1 <= kMaxPauseDays) d,
    ];

/// Asks how many days longer [pause] (today's, run on as [pauseCovering]
/// has it) should last, a week chosen if there is room for one and otherwise
/// the most there is, and moves its end out to then. Progress's Extend and
/// Settings' pause row both open it, with the same choices and change.
///
/// With [offerEnd], as Settings opens it, it is titled until when the pause
/// lasts and offers End pause too, alone with Cancel once the pause has no
/// room left; otherwise it opens only while there is room.
Future<void> showExtendPause(
  BuildContext context,
  WidgetRef ref,
  ({LocalDate start, LocalDate end}) pause, {
  bool offerEnd = false,
}) async {
  final l = context.l10n;
  final names = Names(context);
  final choices = pauseExtensions(pause);
  if (choices.isEmpty && !offerEnd) return;
  var days = choices.contains(7) ? 7 : choices.lastOrNull;
  final action = await showAppDialog<_PauseAction>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final theme = Theme.of(context);
        final chosen = days;
        return AlertDialog(
          title: Text(offerEnd ? l.pauseManageTitle(names.practiceDate(pause.end)) : l.extendPauseTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (offerEnd) ...[
                  Text(chosen == null ? l.pauseAtMost : l.pauseManageBody),
                  if (chosen != null) const Gap(Space.lg),
                ],
                if (chosen != null) ...[
                  Text(l.extendPauseBy, style: theme.textTheme.titleSmall),
                  const Gap(Space.sm),
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    children: [
                      for (final d in choices)
                        SeferChoiceChip(
                          label: Text(l.daysCount(d)),
                          selected: chosen == d,
                          onSelected: (_) => setState(() => days = d),
                        ),
                    ],
                  ),
                  const Gap(Space.lg),
                  // What the pause would become, said as what it will be.
                  Text(
                    l.extendPauseUntil(names.practiceDate(pause.end.addDays(chosen))),
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (offerEnd)
              TextButton(onPressed: () => Navigator.pop(context, _PauseAction.end), child: Text(l.resume)),
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l.actionCancel)),
            if (chosen != null)
              FilledButton(
                onPressed: () => Navigator.pop(context, _PauseAction.extend),
                child: Text(l.extendPause),
              ),
          ],
        );
      },
    ),
  );
  if (!context.mounted) return;
  switch (action) {
    case _PauseAction.end:
      resumePause(context, ref);
    case _PauseAction.extend:
      final end = pause.end.addDays(days!);
      ref.read(progressProvider.notifier).extendPause(ref.read(todayProvider), end);
      showStatus(context, l.pauseStarted(names.practiceDate(end)));
    case null:
    // Cancelled.
  }
}

enum _PauseAction { end, extend }
