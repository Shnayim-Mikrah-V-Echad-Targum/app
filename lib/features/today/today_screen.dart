import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/calendar/jewish_holidays.dart';
import '../../core/calendar/local_date.dart';
import '../../core/calendar/parsha_schedule.dart';
import '../../services/feedback.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/app_icon.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/progress_widgets.dart';
import '../../ui/widgets/read_date_sheet.dart';
import '../community/ui/community_ui.dart';
import '../parsha/week_context.dart';
import '../progress/domain/progress_models.dart';
import '../progress/domain/reading_plan.dart';
import '../progress/domain/streak_engine.dart';
import '../settings/app_settings.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final names = Names(context);
    final today = ref.watch(todayProvider);
    final ctx = ref.watch(currentWeekContextProvider);
    final previous = ref.watch(openPreviousWeekProvider);
    final settings = ref.watch(settingsProvider);
    final summary = ref.watch(streakSummaryProvider);
    final paused = ref.watch(isPausedProvider);
    final pauses = ref.watch(progressProvider.select((p) => p.pauses));
    final divergence = ref.watch(readingDivergenceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.appTitle),
            Text(
              '${names.dateLong(today)} · ${names.hebrewDate(today)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l.guideTitle,
            icon: const AppIcon(Icons.help_outline),
            onPressed: () => context.push('/guide'),
          ),
        ],
      ),
      body: PageBody(
        children: [
          if (paused) ...[
            NoticeBanner(
              icon: Icons.pause_circle_outline,
              text: l.pausedBanner(names.dateLong(pauses.firstWhere((p) => p.contains(today)).end)),
              action: TextButton(
                onPressed: () {
                  ref.read(progressProvider.notifier).endPause(today);
                  showStatus(context, l.pauseEnded);
                },
                child: Text(l.resume),
              ),
            ),
            const Gap(12),
          ],
          if (divergence != null) ...[
            _DivergenceBanner(divergence: divergence, settings: settings),
            const Gap(12),
          ],
          if (previous != null) ...[
            _OpenPreviousCard(previous: previous, current: ctx, today: today, summary: summary),
            const Gap(12),
          ],
          _ParshaCard(ctx: ctx, settings: settings),
          const Gap(12),
          _TodayCard(ctx: ctx, settings: settings),
          const Gap(12),
          InfoCard(
            padding: WeekStrip.cardPadding,
            child: WeekStrip(
              plan: ctx.plan,
              today: today,
              statuses: summary.days,
              oneDayYomTov: settings.oneDayYomTov,
              joinDate: settings.joinDate,
              onDayTap: (day) => context.push('/read/${ctx.id}/${day.aliyot.first}'),
            ),
          ),
          if (settings.showStreaks) ...[
            const Gap(12),
            _StreakRow(summary: summary),
          ],
          if (settings.haftarahEnabled) ...[
            const Gap(12),
            _HaftarahTile(ctx: ctx),
          ],
          const Gap(12),
          WeeklyThreadOpener(
            portion: ctx.portion,
            hebrewYear: cycleYearOf(ctx.week.portion, ctx.week.occasion),
            builder: (context, progress, open) => InfoCard(
              onTap: open,
              child: Row(
                children: [
                  SizedBox.square(dimension: 24, child: Center(child: progress ?? const Icon(Icons.forum_outlined))),
                  const Gap(12),
                  Expanded(child: Text(l.discussThisWeek)),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Names both portions in a week when Israel and the Diaspora read
/// different ones, for a reader who hears one place's reading but keeps the
/// other's days of Yom Tov. A visitor to Israel can open last week's portion
/// in Israel, their home portion this week.
class _DivergenceBanner extends ConsumerWidget {
  const _DivergenceBanner({required this.divergence, required this.settings});

  final ReadingDivergence divergence;
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final names = Names(context);
    final repo = ref.watch(parshaRepositoryProvider);
    String name(PortionId p) => names.portion(repo.portion(p), ashkenazi: settings.ashkenaziNames);
    final (israel, diaspora) = (name(divergence.israel), name(divergence.diaspora));
    final previous = divergence.previous;
    return NoticeBanner(
      icon: Icons.info_outline,
      text: divergence.hearsIsrael
          ? l.readingDivergence(israel, diaspora)
          : l.readingDivergenceAhead(israel, diaspora),
      actionBelow: true,
      action: previous == null
          ? null
          : TextButton(
              onPressed: () => context.push('/today/week/${weekIdFor(previous.portion, previous.occasion)}'),
              child: Text(l.readingDivergenceOpen(name(previous.portion))),
            ),
    );
  }
}

class _ParshaCard extends ConsumerWidget {
  const _ParshaCard({required this.ctx, required this.settings});

  final WeekContext ctx;
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final names = Names(context);
    final theme = Theme.of(context);
    final repo = ref.watch(parshaRepositoryProvider);
    final weights = [for (var a = 0; a < kAliyot; a++) repo.aliyahVerseCount(ctx.portion, a)];
    final occasion = ctx.week.occasion;
    final readOn = names.readOnLabel(ctx.week);
    final next = ctx.nextAliyah;
    final started = ctx.progress.isStarted;
    final daysLeft = occasion.differenceInDays(ctx.today);
    // The days until the portion is read in synagogue: on Shabbat, or for
    // Vezot HaBerakhah on Simchat Torah, which is seldom a Shabbat.
    final countdown = daysLeft < 0 || ctx.progress.isComplete
        ? null
        : ctx.week.portion.isVezotHaberakhah
            ? l.simchatTorahInDays(daysLeft)
            : occasion.isShabbat
                ? l.shabbatInDays(daysLeft)
                : null;

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Read through before the rings below it.
          Semantics(
            container: true,
            explicitChildNodes: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  headingLevel: 1,
                  child: Text(
                    l.parshaLabel(names.portion(ctx.portion, ashkenazi: settings.ashkenaziNames)),
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                Text(
                  names.portionAlt(ctx.portion, ashkenazi: settings.ashkenaziNames),
                  style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const Gap(8),
                Text(readOn, style: theme.textTheme.bodyMedium),
                if (countdown != null) Text(countdown, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const Gap(20),
          RingsWithLegend(
            progress: ctx.progress,
            aliyahWeights: weights,
            thirdLabel: settings.usesRashi && !settings.usesOnkelos ? l.passRashi : null,
          ),
          const Gap(20),
          if (ctx.progress.isComplete)
            Row(
              children: [
                Icon(Icons.celebration_outlined, color: theme.colorScheme.primary),
                const Gap(8),
                Expanded(child: Text(l.weekComplete, style: theme.textTheme.titleSmall)),
              ],
            )
          else
            FilledButton.icon(
              icon: const Icon(Icons.menu_book),
              label: Text(started ? l.continueReading : l.startReading),
              onPressed: () => context.push('/read/${ctx.id}/${next ?? 0}'),
            ),
          const Gap(8),
          OutlinedButton(
            onPressed: () => context.push('/today/week/${ctx.id}'),
            child: Text(l.aliyotProgress(ctx.progress.completedAliyot, kAliyot)),
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends ConsumerWidget {
  const _TodayCard({required this.ctx, required this.settings});

  final WeekContext ctx;
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final names = Names(context);
    final theme = Theme.of(context);
    final repo = ref.watch(parshaRepositoryProvider);
    final day = ctx.plan.dayFor(ctx.today);
    final behind = ctx.behindBy();

    Widget body;
    if (day == null) {
      body = Text(l.todayNothingPlanned);
    } else {
      final verses = day.aliyot.fold<int>(0, (n, a) => n + repo.aliyahVerseCount(ctx.portion, a));
      final done = day.aliyot.every(ctx.progress.isAliyahDone);
      final first = day.aliyot.firstWhere((a) => !ctx.progress.isAliyahDone(a), orElse: () => day.aliyot.first);
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(names.aliyot(day.aliyot), style: theme.textTheme.titleLarge),
          Text(
            '${l.versesCount(verses)} · ${l.minutesEstimate((verses * kSecondsPerVerse / 60).ceil())}',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (behind > 0 && !done) ...[
            const Gap(8),
            Text(l.todayBehind(behind), style: theme.textTheme.bodyMedium),
          ],
          const Gap(12),
          if (done)
            Row(
              children: [
                Icon(Icons.check_circle, color: theme.colorScheme.primary),
                const Gap(8),
                Expanded(child: Text(l.todayDone, style: theme.textTheme.titleSmall)),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  style: AppButtons.tonal(context),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(l.readTodaysAliyah),
                  onPressed: () => context.push('/read/${ctx.id}/$first'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.import_contacts),
                  label: Text(l.readFromBook),
                  onPressed: () async {
                    final date = await pickReadDate(context, week: ctx.week, today: ctx.today);
                    if (date == null || !context.mounted) return;
                    ref.read(progressProvider.notifier).markAliyot(ctx.id, day.aliyot, date);
                    hapticSuccess(ref);
                    showStatus(context, l.markedRead);
                  },
                ),
              ],
            ),
        ],
      );
    }

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(l.todayReadingTitle, padding: const EdgeInsets.only(bottom: 8)),
          body,
        ],
      ),
    );
  }
}

class _StreakRow extends StatelessWidget {
  const _StreakRow({required this.summary});
  final StreakSummary summary;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget tile(IconData icon, String label, String value) => Expanded(
          child: InfoCard(
            onTap: () => context.go('/progress'),
            child: Semantics(
              label: '$label: $value',
              button: true,
              excludeSemantics: true,
              child: Row(
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const Gap(10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        Text(label, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    return Row(
      children: [
        tile(Icons.auto_stories_outlined, l.streakParsha, l.weeksCount(summary.parshaStreak)),
        const Gap(12),
        tile(Icons.event_available_outlined, l.streakDays, l.daysCount(summary.daysOnTrack)),
      ],
    );
  }
}

class _HaftarahTile extends ConsumerWidget {
  const _HaftarahTile({required this.ctx});
  final WeekContext ctx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final names = Names(context);
    final h = ctx.haftarah;
    final refs = h.parts
        .map((p) => names.range(p.book, p.start.chapter, p.start.verse, p.end.chapter, p.end.verse))
        .join(' · ');
    final done = ctx.progress.haftarah != null;
    return InfoCard(
      onTap: () => context.push('/today/haftarah/${ctx.id}'),
      child: Row(
        children: [
          Icon(done ? Icons.check_circle : Icons.auto_stories_outlined,
              color: done ? Theme.of(context).colorScheme.primary : null),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(done ? l.haftarahRead : l.haftarahLabel, style: Theme.of(context).textTheme.titleSmall),
                Text(refs),
                if (h.specialKey != null) Text(l.specialHaftarah(names.specialHaftarah(h.specialKey!))),
                if (h.regular != null) Text(l.alsoRegularHaftarah),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class _OpenPreviousCard extends ConsumerWidget {
  const _OpenPreviousCard({required this.previous, required this.current, required this.today, required this.summary});

  final WeekContext previous;
  final WeekContext current;
  final LocalDate today;
  final StreakSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final names = Names(context);
    final settings = ref.watch(settingsProvider);
    final name = names.portion(previous.portion, ashkenazi: settings.ashkenaziNames);
    final engine = ref.watch(streakEngineProvider);
    // On the first reading day after Shabbat, ask about reading done on Shabbat.
    var firstDayAfter = previous.week.occasion.addDays(1);
    while (JewishHolidays.isRestDay(firstDayAfter, israel: settings.oneDayYomTov)) {
      firstDayAfter = firstDayAfter.addDays(1);
    }
    if (today == firstDayAfter && previous.week.occasion.isShabbat) {
      return InfoCard(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(l.checkInTitle, padding: EdgeInsets.zero),
            const Gap(4),
            Text(l.checkInBody),
            const Gap(12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () {
                    final progress = ref.read(progressProvider.notifier);
                    progress.markWeek(previous.id, previous.week.occasion);
                    // Finishing it includes the haftarah, where that counts.
                    if (previous.haftarahDue) progress.markHaftarah(previous.id, previous.week.occasion);
                    hapticSuccess(ref);
                    showStatus(context, l.parshaComplete(name));
                  },
                  child: Text(l.checkInFinished),
                ),
                OutlinedButton(
                  onPressed: () => context.push('/today/week/${previous.id}'),
                  child: Text(l.checkInPick),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final overdue = previous.status == WeekStatus.overdue;
    final nextName = names.portion(current.portion, ashkenazi: settings.ashkenaziNames);
    final onlyHaftarah = previous.progress.isComplete;
    return InfoCard(
      color: Theme.of(context).colorScheme.secondaryContainer,
      onTap: () => context.push(onlyHaftarah ? '/today/haftarah/${previous.id}' : '/today/week/${previous.id}'),
      child: Row(
        children: [
          const Icon(Icons.schedule),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.openWeekTitle(name), style: Theme.of(context).textTheme.titleSmall),
                if (onlyHaftarah) Text(l.openWeekHaftarahLeft),
                Text(overdue
                    ? l.openWeekRestore(name, nextName)
                    : l.openWeekLate(names.dateLong(engine.lateDeadlineOf(previous.week)))),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
