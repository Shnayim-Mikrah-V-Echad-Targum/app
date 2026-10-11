import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/calendar/local_date.dart';
import '../../../services/feedback.dart';
import '../../../ui/l10n.dart';
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

/// While a pause lasts until [pause]'s end: lengthen it from the day after,
/// as far as [kMaxPauseDays] in all, or resume now.
Future<void> showPauseOptions(BuildContext context, WidgetRef ref, ({LocalDate start, LocalDate end}) pause) async {
  final l = context.l10n;
  final names = Names(context);
  final length = pause.end.differenceInDays(pause.start) + 1;
  final choices = [for (final d in const [1, 3, 7, 14, 30]) if (length + d <= kMaxPauseDays) d];
  var days = choices.contains(7) ? 7 : choices.lastOrNull;
  final action = await showAppDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(l.pauseManageTitle(names.dateInText(pause.end))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(choices.isEmpty ? l.pauseAtMost : l.pauseManageBody),
              if (choices.isNotEmpty) ...[
                const Gap(16),
                Text(l.pauseExtendBy, style: Theme.of(context).textTheme.titleSmall),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final d in choices)
                      SeferChoiceChip(
                        label: Text(l.daysCount(d)),
                        selected: days == d,
                        onSelected: (_) => setState(() => days = d),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'resume'), child: Text(l.resume)),
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.actionCancel)),
          if (choices.isNotEmpty)
            FilledButton(onPressed: () => Navigator.pop(context, 'extend'), child: Text(l.pauseExtend)),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  switch (action) {
    case 'resume':
      resumePause(context, ref);
    case 'extend' when days != null:
      final end = pause.end.addDays(days!);
      // From the day after, so that the two run on as one.
      ref.read(progressProvider.notifier).addPause(pause.end.addDays(1), end);
      showStatus(context, l.pauseStarted(names.dateLong(end)));
  }
}
