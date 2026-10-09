import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../services/feedback.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/fallbacks.dart';
import '../../ui/widgets/progress_widgets.dart';
import '../../ui/widgets/read_date_sheet.dart';
import '../progress/domain/progress_models.dart';
import 'week_context.dart';

/// One week's portion: its aliyot, the plan, and progress. Used for any
/// week (current, past or future).
class WeekOverviewScreen extends ConsumerWidget {
  const WeekOverviewScreen({super.key, required this.weekId});

  final String weekId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(weekContextProvider(weekId));
    if (ctx == null) {
      return Scaffold(appBar: AppBar(leading: homeLeading(context)), body: Center(child: Text(context.l10n.errorGeneric)));
    }
    return WeekOverview(ctx: ctx, leading: homeLeading(context));
  }
}

class WeekOverview extends ConsumerWidget {
  const WeekOverview({super.key, required this.ctx, this.leading, this.actions = const []});

  final WeekContext ctx;

  /// The app bar's leading button, if not the usual one.
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final names = Names(context);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final repo = ref.watch(parshaRepositoryProvider);
    final portion = ctx.portion;
    final name = names.portion(portion, ashkenazi: settings.ashkenaziNames);
    final range = portion.range;

    Future<void> markWeek() async {
      final date = await pickReadDate(context, week: ctx.week, today: ctx.today);
      if (date == null || !context.mounted) return;
      ref.read(progressProvider.notifier).markWeek(ctx.id, date);
      hapticSuccess(ref);
      showStatus(context, l.parshaComplete(name));
    }

    Future<void> clearWeek() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(l.clearWeekConfirm(name)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.actionCancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.clearWeek)),
          ],
        ),
      );
      if (ok == true) {
        final before = ref.read(progressProvider).week(ctx.id);
        ref.read(progressProvider.notifier).clearWeek(ctx.id);
        if (context.mounted) {
          showStatus(
            context,
            l.markedUnread,
            action: SnackBarAction(
              label: l.actionUndo,
              onPressed: () => ref.read(progressProvider.notifier).restoreWeek(ctx.id, before),
            ),
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: leading,
        title: Text(l.parshaLabel(name)),
        actions: [
          ...actions,
          PopupMenuButton<String>(
            tooltip: l.actionMore,
            onSelected: (v) => switch (v) {
              'all' => markWeek(),
              'clear' => clearWeek(),
              'full' => context.push('/read/${ctx.id}/0?mode=full'),
              _ => null,
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'full', child: Text(l.fullTextMode)),
              if (ctx.isOpen && !ctx.progress.isComplete) PopupMenuItem(value: 'all', child: Text(l.markWholeWeek)),
              if (ctx.progress.completedUnits > 0) PopupMenuItem(value: 'clear', child: Text(l.clearWeek)),
            ],
          ),
        ],
      ),
      body: PageBody(
        children: [
          Text(names.portionAlt(portion, ashkenazi: settings.ashkenaziNames),
              style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(names.range(portion.book, range.start.chapter, range.start.verse, range.end.chapter, range.end.verse)),
          Text(
            ctx.week.portion.isVezotHaberakhah
                ? l.readOnSimchatTorah(names.dateLong(ctx.week.occasion))
                : l.readOnShabbat(names.dateMonthDay(ctx.week.occasion)),
          ),
          Text('${l.versesCount(repo.verseCount(portion))} · ${names.hebrewDate(ctx.week.occasion)}',
              style: theme.textTheme.bodySmall),
          if (ctx.status != null) ...[const Gap(8), WeekStatusBadge(ctx.status!)],
          if (!ctx.isOpen) ...[
            const Gap(12),
            NoticeBanner(icon: Icons.visibility_outlined, text: l.previewNotOpen(names.dateLong(ctx.week.start))),
          ],
          SectionHeader(l.aliyotProgress(ctx.progress.completedAliyot, kAliyot)),
          for (var a = 0; a < kAliyot; a++) _AliyahTile(ctx: ctx, aliyah: a),
          if (settings.haftarahEnabled || ctx.haftarahRequired) ...[
            const Gap(8),
            ListTile(
              leading: Icon(ctx.progress.haftarah != null ? Icons.check_circle : Icons.auto_stories_outlined,
                  color: ctx.progress.haftarah != null ? theme.colorScheme.primary : null),
              title: Text(l.haftarahTitle),
              subtitle: Text([
                ctx.haftarah.parts
                    .map((p) => names.range(p.book, p.start.chapter, p.start.verse, p.end.chapter, p.end.verse))
                    .join(' · '),
                if (ctx.haftarah.specialKey != null) l.specialHaftarah(names.specialHaftarah(ctx.haftarah.specialKey!)),
              ].join('\n')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/haftarah/${ctx.id}'),
            ),
          ],
          const Gap(16),
          if (ctx.isOpen && !ctx.progress.isComplete)
            OutlinedButton.icon(
              icon: const Icon(Icons.import_contacts),
              label: Text(l.markWholeWeek),
              onPressed: markWeek,
            ),
          const Gap(8),
          OutlinedButton.icon(
            icon: const Icon(Icons.forum_outlined),
            label: Text(l.discussThisWeek),
            onPressed: () => context.push('/community/new?parsha=${Uri.encodeComponent(portion.key)}'),
          ),
        ],
      ),
    );
  }
}

class _AliyahTile extends ConsumerWidget {
  const _AliyahTile({required this.ctx, required this.aliyah});

  final WeekContext ctx;
  final int aliyah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final names = Names(context);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final repo = ref.watch(parshaRepositoryProvider);
    final r = ctx.portion.aliyot[aliyah];
    final verses = repo.aliyahVerseCount(ctx.portion, aliyah);
    final planned = ctx.plan.days.where((d) => d.aliyot.contains(aliyah)).firstOrNull;
    final onShabbat = ctx.plan.shabbatAliyot.contains(aliyah);
    final done = ctx.progress.isAliyahDone(aliyah);
    final secondName = settings.usesRashi && !settings.usesOnkelos ? l.passRashi : l.passTargum;
    final passNames = [l.passMikra1, l.passMikra2, secondName];
    final passStates = [
      for (final p in ReadingPass.values)
        l.passSemantics(passNames[p.index], ctx.progress.isUnitDone(aliyah, p) ? l.stateDone : l.stateNotDone),
    ];
    final note = ctx.portion.aliyahNotes[aliyah];

    final subtitle = [
      names.range(r.book, r.start.chapter, r.start.verse, r.end.chapter, r.end.verse),
      '${l.versesCount(verses)} · ${l.minutesEstimate((verses * 25 / 60).ceil())}',
      if (planned != null) l.plannedFor(names.weekday(planned.date)),
      if (onShabbat) l.plannedForShabbat,
      if (note != null && !context.isHebrewUi) l.aliyahNote(note),
    ].join('\n');

    Future<void> markRead() async {
      final date = await pickReadDate(context, week: ctx.week, today: ctx.today);
      if (date == null || !context.mounted) return;
      ref.read(progressProvider.notifier).markAliyah(ctx.id, aliyah, date);
      hapticSuccess(ref);
      showStatus(context, l.markedRead);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        // Expose the reading state of all three passes in the tile's label.
        value: passStates.join(', '),
        child: ListTile(
          contentPadding: const EdgeInsetsDirectional.only(start: 12, end: 4),
          leading: CircleAvatar(
            backgroundColor: done ? StatusColors.of(context).done : theme.colorScheme.surfaceContainerHighest,
            foregroundColor: done ? StatusColors.of(context).onDone : theme.colorScheme.onSurface,
            child: done ? const Icon(Icons.check) : Text('${aliyah + 1}'),
          ),
          title: Text(l.aliyahWithName(names.aliyah(aliyah), aliyah + 1)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subtitle),
              const Gap(6),
              ExcludeSemantics(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final p in ReadingPass.values)
                      _PassDot(done: ctx.progress.isUnitDone(aliyah, p), label: p == ReadingPass.targum ? secondName : l.passShortMikra),
                  ],
                ),
              ),
            ],
          ),
          isThreeLine: true,
          onTap: () => context.push('/read/${ctx.id}/$aliyah'),
          trailing: PopupMenuButton<String>(
            tooltip: l.actionMore,
            onSelected: (v) {
              if (v == 'read') markRead();
              if (v == 'unread') {
                ref.read(progressProvider.notifier).markAliyah(ctx.id, aliyah, null);
                showStatus(context, l.markedUnread);
              }
              if (v == 'full') context.push('/read/${ctx.id}/$aliyah?mode=full');
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'full', child: Text(l.fullTextMode)),
              if (!done && ctx.isOpen) PopupMenuItem(value: 'read', child: Text(l.actionMarkRead)),
              if (ctx.progress.units[aliyah].any((d) => d != null))
                PopupMenuItem(value: 'unread', child: Text(l.actionMarkUnread)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PassDot extends StatelessWidget {
  const _PassDot({required this.done, required this.label});
  final bool done;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = done ? StatusColors.of(context).done : theme.colorScheme.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: done ? color.withValues(alpha: 0.12) : null,
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(done ? Icons.check : Icons.circle_outlined, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(child: Text(label, style: theme.textTheme.labelSmall)),
        ],
      ),
    );
  }
}
