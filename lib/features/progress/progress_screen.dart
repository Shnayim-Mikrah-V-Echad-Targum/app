import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/calendar/parsha_schedule.dart';
import '../../data/models/parsha.dart';
import '../../services/feedback.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/progress_widgets.dart';
import '../parsha/week_context.dart';
import 'domain/milestones.dart';
import 'domain/progress_models.dart';
import 'domain/streak_engine.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final names = Names(context);
    final summary = ref.watch(streakSummaryProvider);
    final settings = ref.watch(settingsProvider);
    final progress = ref.watch(progressProvider);
    final current = ref.watch(currentWeekContextProvider);
    final repo = ref.watch(parshaRepositoryProvider);
    final cycle = cycleYearOf(current.week.portion, current.week.occasion);
    final doneThisCycle = parshiyotDoneInCycle(progress.weeks, cycle);
    final milestones = computeMilestones(summary: summary, progress: progress.weeks, parshiyotDoneThisCycle: doneThisCycle);

    var versesRead = 0;
    for (final e in progress.weeks.entries) {
      final colon = e.key.indexOf(':');
      if (colon < 0) continue;
      final PortionInfo info;
      try {
        info = repo.portion(PortionId.parse(e.key.substring(colon + 1)));
      } catch (_) {
        continue;
      }
      for (var a = 0; a < kAliyot; a++) {
        if (e.value.isAliyahDone(a)) versesRead += repo.aliyahVerseCount(info, a);
      }
    }

    final missedThisCycle = summary.weeks
        .where((e) => e.status == WeekStatus.missed && cycleYearOf(e.plan.portion, e.plan.week.occasion) == cycle)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(l.progressTitle)),
      body: PageBody(
        children: [
          if (settings.showStreaks) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _BigStat(
                    icon: Icons.auto_stories_outlined,
                    label: l.streakParsha,
                    value: l.weeksCount(summary.parshaStreak),
                    detail: l.longest(l.weeksCount(summary.longestParshaStreak)),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: _BigStat(
                    icon: Icons.event_available_outlined,
                    label: l.streakDays,
                    value: l.daysCount(summary.daysOnTrack),
                    detail: l.longest(l.daysCount(summary.longestDaysOnTrack)),
                  ),
                ),
              ],
            ),
            const Gap(12),
            InfoCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: StatusColors.of(context).grace),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${l.graceDays}: ${l.graceDaysAvailable(summary.graceBalance)}',
                            style: Theme.of(context).textTheme.titleSmall),
                        const Gap(4),
                        Text(l.graceExplainer, style: Theme.of(context).textTheme.bodySmall),
                        const Gap(4),
                        Text(l.streakExplainer, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else
            NoticeBanner(
              icon: Icons.visibility_off_outlined,
              text: l.streaksHidden,
              action: TextButton(
                onPressed: () => ref.read(settingsProvider.notifier).update((s) => s.copyWith(showStreaks: true)),
                child: Text(l.showStreaks),
              ),
            ),
          const Gap(12),
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.thisCycle(doneThisCycle.length), style: Theme.of(context).textTheme.titleMedium),
                Text(l.versesRead(NumberFormat.decimalPattern(context.localeName).format(versesRead))),
              ],
            ),
          ),
          SectionHeader(l.weekStripLabel),
          InfoCard(
            child: WeekStrip(
              plan: current.plan,
              today: current.today,
              statuses: summary.days,
              israel: settings.israel,
              joinDate: settings.joinDate,
              onDayTap: (d) => context.push('/read/${current.id}/${d.aliyot.first}'),
            ),
          ),
          SectionHeader(l.torahMap, trailing: Tooltip(message: l.torahMapHelp, child: const Icon(Icons.info_outline, size: 20))),
          _TorahMap(cycle: cycle, summary: summary, done: doneThisCycle, current: current),
          if (missedThisCycle.isNotEmpty) ...[
            SectionHeader(l.makeUpTitle),
            Text(l.makeUpBody, style: Theme.of(context).textTheme.bodySmall),
            const Gap(8),
            for (final e in missedThisCycle)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(names.portion(repo.portion(e.plan.portion), ashkenazi: settings.ashkenaziNames)),
                  subtitle: Text(names.dateLong(e.plan.week.occasion)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/week/${e.plan.weekId}'),
                ),
              ),
          ],
          SectionHeader(l.recentWeeks),
          if (summary.weeks.isEmpty)
            Text(l.noHistory)
          else
            for (final e in summary.weeks.reversed.take(10))
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  title: Text(names.portion(repo.portion(e.plan.portion), ashkenazi: settings.ashkenaziNames)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Align(alignment: AlignmentDirectional.centerStart, child: WeekStatusBadge(e.status, dense: true)),
                  ),
                  trailing: Text(names.dateShort(e.plan.week.occasion)),
                  onTap: () => context.push('/week/${e.plan.weekId}'),
                ),
              ),
          SectionHeader(l.pauseTitle),
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.pauseBody),
                const Gap(12),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.pause_circle_outline),
                    label: Text(l.pauseAction),
                    onPressed: () => showPauseDialog(context, ref),
                  ),
                ),
              ],
            ),
          ),
          SectionHeader(l.milestonesTitle),
          _Milestones(milestones: milestones),
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({required this.icon, required this.label, required this.value, required this.detail});

  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InfoCard(
      child: Semantics(
        label: '$label: $value. $detail',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const Gap(8),
            Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: theme.textTheme.titleSmall),
            Text(detail, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

enum _TileState { done, late, madeUp, missed, current, upcoming, untracked }

class _TorahMap extends ConsumerWidget {
  const _TorahMap({required this.cycle, required this.summary, required this.done, required this.current});

  final int cycle;
  final StreakSummary summary;
  final Set<int> done;
  final WeekContext current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final names = Names(context);
    final repo = ref.watch(parshaRepositoryProvider);
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final colors = StatusColors.of(context);

    _TileState stateOf(PortionInfo p) {
      final n = p.id.number;
      WeekStatus? status;
      for (final e in summary.weeks) {
        if (e.plan.portion.parshiyot.contains(n) && cycleYearOf(e.plan.portion, e.plan.week.occasion) == cycle) {
          status = e.status;
        }
      }
      if (status == WeekStatus.onTime) return _TileState.done;
      if (status == WeekStatus.late || status == WeekStatus.restored) return _TileState.late;
      if (current.week.portion.parshiyot.contains(n)) return done.contains(n) ? _TileState.done : _TileState.current;
      if (done.contains(n)) return _TileState.madeUp;
      if (status == WeekStatus.missed || status == WeekStatus.overdue) return _TileState.missed;
      if (n > current.week.portion.number) return _TileState.upcoming;
      return _TileState.untracked;
    }

    String label(_TileState s) => switch (s) {
          _TileState.done => l.weekOnTime,
          _TileState.late => l.weekLate,
          _TileState.madeUp => l.weekMadeUp,
          _TileState.missed => l.weekMissed,
          _TileState.current => l.weekInProgress,
          _TileState.upcoming => l.dayUpcoming,
          _TileState.untracked => l.weekTransparent,
        };

    Widget tile(PortionInfo p) {
      final s = stateOf(p);
      final name = names.portion(p, ashkenazi: settings.ashkenaziNames);
      final (Color? fill, Color border, IconData? icon) = switch (s) {
        _TileState.done => (colors.done, colors.done, Icons.check),
        _TileState.late => (colors.done.withValues(alpha: 0.7), colors.done, Icons.check),
        _TileState.madeUp => (colors.late.withValues(alpha: 0.25), colors.late, Icons.history),
        _TileState.missed => (null, theme.colorScheme.outline, null),
        _TileState.current => (theme.colorScheme.primaryContainer, theme.colorScheme.primary, Icons.timelapse),
        _TileState.upcoming => (null, theme.colorScheme.outlineVariant, null),
        _TileState.untracked => (null, theme.colorScheme.outlineVariant, null),
      };
      final onFill = s == _TileState.done || s == _TileState.late ? colors.onDone : theme.colorScheme.onSurface;
      return Semantics(
        label: '$name: ${label(s)}',
        button: true,
        excludeSemantics: true,
        child: Tooltip(
          message: '$name — ${label(s)}',
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => context.push('/week/$cycle:${p.id.number}'),
            child: Container(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: fill,
                border: Border.all(color: border, width: s == _TileState.current ? 2 : 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 14, color: onFill), const SizedBox(width: 4)],
                  Flexible(child: Text(name, style: theme.textTheme.labelMedium?.copyWith(color: onFill))),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var b = 0; b < kTorahBooks.length; b++) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Semantics(
              header: true,
              headingLevel: 3,
              child: Text(names.book(kTorahBooks[b]), style: theme.textTheme.titleSmall),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final p in repo.all.where((p) => p.bookIndex == b)) tile(p)],
          ),
        ],
      ],
    );
  }
}

class _Milestones extends StatelessWidget {
  const _Milestones({required this.milestones});
  final List<Milestone> milestones;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final names = Names(context);
    final theme = Theme.of(context);
    String title(Milestone m) => switch (m.kind) {
          MilestoneKind.firstAliyah => l.milestoneFirstAliyah,
          MilestoneKind.firstParsha => l.milestoneFirstParsha,
          MilestoneKind.perfectWeek => l.milestonePerfectWeek,
          MilestoneKind.parshaStreak => l.milestoneParshaStreak(m.value),
          MilestoneKind.daysOnTrack => l.milestoneDaysOnTrack(m.value),
          MilestoneKind.sefer => l.milestoneSefer(names.book(kTorahBooks[m.value])),
          MilestoneKind.siyum => l.milestoneSiyum,
          MilestoneKind.comeback => l.milestoneComeback,
        };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final m in milestones)
          Semantics(
            label: '${title(m)}: ${m.achieved ? l.stateDone : l.milestoneLocked}',
            excludeSemantics: true,
            child: Chip(
              avatar: Icon(
                m.achieved ? Icons.emoji_events : Icons.lock_outline,
                size: 18,
                color: m.achieved ? theme.colorScheme.primary : theme.colorScheme.outline,
              ),
              label: Text(title(m)),
              backgroundColor: m.achieved ? theme.colorScheme.primaryContainer : null,
            ),
          ),
      ],
    );
  }
}

/// "Life happens": pause streaks for up to 30 days, backdated up to 3 days.
Future<void> showPauseDialog(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final names = Names(context);
  final today = ref.read(todayProvider);
  var days = 7;
  var backdate = 0;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(l.pauseTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.pauseBody),
              const Gap(16),
              Text(l.pauseFor, style: Theme.of(context).textTheme.titleSmall),
              Wrap(
                spacing: 8,
                children: [
                  for (final d in const [1, 3, 7, 14, 30])
                    ChoiceChip(label: Text(l.daysCount(d)), selected: days == d, onSelected: (_) => setState(() => days = d)),
                ],
              ),
              const Gap(12),
              Text(l.pauseStarting, style: Theme.of(context).textTheme.titleSmall),
              Wrap(
                spacing: 8,
                children: [
                  for (final b in const [0, 1, 2, 3])
                    ChoiceChip(
                      label: Text(b == 0 ? l.whenToday : (b == 1 ? l.whenYesterday : names.dateShort(today.addDays(-b)))),
                      selected: backdate == b,
                      onSelected: (_) => setState(() => backdate = b),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.actionCancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.pauseAction)),
        ],
      ),
    ),
  );
  if (ok != true) return;
  final start = today.addDays(-backdate);
  final end = start.addDays(days - 1);
  ref.read(progressProvider.notifier).addPause(Pause(start, end));
  if (context.mounted) showStatus(context, l.pauseStarted(names.dateLong(end)));
}
