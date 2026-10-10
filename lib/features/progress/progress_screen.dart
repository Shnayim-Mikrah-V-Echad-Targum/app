import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/calendar/local_date.dart';
import '../../core/calendar/parsha_schedule.dart';
import '../../core/text/hebrew_text.dart';
import '../../data/models/parsha.dart';
import '../../data/parsha_repository.dart';
import '../../services/feedback.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/fonts_change_scope.dart';
import '../../ui/widgets/lang.dart';
import '../../ui/widgets/ledger.dart';
import '../../ui/widgets/ornaments.dart';
import '../../ui/widgets/paper_group.dart';
import '../../ui/widgets/progress_widgets.dart';
import '../../ui/widgets/sefer_choice_chip.dart';
import '../../ui/widgets/year_bar.dart';
import '../parsha/week_context.dart';
import '../reader/sefer_complete_screen.dart';
import 'domain/milestones.dart';
import 'domain/parsha_standing.dart';
import 'domain/progress_models.dart';
import 'domain/reading_plan.dart' show LateWindow;
import 'domain/streak_engine.dart';

/// Progress (docs/DESIGN_SYSTEM.md §9): the streaks, the year, this week's
/// plan, the Torah map, the weeks gone by, a pause, and what the reader has
/// finished so far.
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  /// The cycle chosen to look back on, or null for this year's.
  int? _chosenCycle;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final names = Names(context);
    final summary = ref.watch(streakSummaryProvider);
    final settings = ref.watch(settingsProvider);
    final progress = ref.watch(progressProvider);
    final current = ref.watch(currentWeekContextProvider);
    final repo = ref.watch(parshaRepositoryProvider);
    String name(PortionId id) => names.portion(repo.portion(id), ashkenazi: settings.ashkenaziNames);
    final theme = Theme.of(context);
    TextStyle? muted(TextStyle? style) => style?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    final live = cycleYearOf(current.week.portion, current.week.occasion);
    final doneByCycle = parshiyotDoneByCycle(progress.weeks);
    final cycles = {...doneByCycle.keys, live}.toList()..sort();
    final cycle = cycles.contains(_chosenCycle) ? _chosenCycle! : live;
    final done = doneByCycle[cycle] ?? const <int>{};

    // Make-ups are offered for this year's weeks only.
    final missedThisCycle = summary.weeks
        .where((e) => e.status == WeekStatus.missed && cycleYearOf(e.plan.portion, e.plan.week.occasion) == live)
        .toList();

    // A week before the reader joined, with nothing read in it, is no part of
    // their history (the Vezot HaBerakhah of a reader who joined on Simchat
    // Torah, say).
    final joinDate = settings.joinDate ?? current.today;
    final recent = [
      for (final e in summary.weeks.reversed)
        if (!(e.status == WeekStatus.transparent &&
            e.plan.week.start < joinDate &&
            (progress.weeks[e.plan.weekId]?.completedUnits ?? 0) == 0))
          e,
    ];

    final record = [
      for (final m in computeMilestones(
        summary: summary,
        progress: progress.weeks,
        doneByCycle: doneByCycle,
        joinDate: settings.joinDate,
      ))
        // While streak numbers are hidden, so are the milestones that count them.
        if (m.achieved &&
            (settings.showStreaks || (m.kind != MilestoneKind.parshaStreak && m.kind != MilestoneKind.daysOnTrack)))
          m,
    ]..sort((a, b) => switch ((b.achievedOn?.rd ?? 0).compareTo(a.achievedOn?.rd ?? 0)) {
        0 => _recordRank(b.kind).compareTo(_recordRank(a.kind)),
        final order => order,
      });

    return PageScaffold(
      titleText: l.progressTitle,
      body: PageBody(
        children: [
          if (settings.showStreaks) ...[
            LedgerCard(
              parshaStreak: summary.parshaStreak,
              daysOnTrack: summary.daysOnTrack,
              beginsWith: name(current.week.portion),
              longestParshaStreak: summary.longestParshaStreak,
              longestDaysOnTrack: summary.longestDaysOnTrack,
            ),
            const Gap(Rhythm.cardGap),
            PaperGroup(
              children: [
                PaperRow(
                  icon: Icons.shield_outlined,
                  iconColor: StatusColors.of(context).grace,
                  title: l.graceAvailable(summary.graceBalance),
                  trailing: TextButton(
                    onPressed: () => _showAboutStreaks(context, settings.lateWindow),
                    child: Text(l.aboutStreaks),
                  ),
                ),
              ],
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
          const Gap(Rhythm.sectionGap),
          _ThisYear(
            cycle: cycle,
            live: live,
            cycles: cycles,
            onCycle: (c) => setState(() => _chosenCycle = c),
            done: done,
            segments: YearBar.segmentsFor(
              weeks: summary.weeks,
              cycle: cycle,
              done: done,
              current: cycle == live ? current.week.portion : null,
            ),
            currentName: name(current.week.portion),
            verses: _versesRead(repo, progress.weeks, cycle),
          ),
          SectionHeader(l.weekStripLabel, trailing: const WeekStripLegendButton()),
          InfoCard(
            padding: WeekStrip.cardPadding,
            child: WeekStrip(
              plan: current.plan,
              today: current.today,
              statuses: summary.days,
              oneDayYomTov: settings.oneDayYomTov,
              joinDate: settings.joinDate,
              onDayTap: (d) => context.push('/read/${current.id}/${d.aliyot.first}'),
            ),
          ),
          // An earlier year's map is named for its year, which in English
          // has digits: no eyebrow holds those (§4.5).
          if (cycle == live)
            SectionHeader(l.torahMap, trailing: const _TorahMapHelpButton())
          else if (context.isHebrewUi)
            SectionHeader(l.torahMapOfYear(names.hebrewYear(cycle)), trailing: const _TorahMapHelpButton())
          else
            SectionHeader.plain(l.torahMapOfYear(names.hebrewYear(cycle)), trailing: const _TorahMapHelpButton()),
          _TorahMap(cycle: cycle, summary: summary, done: done, current: current, live: cycle == live),
          if (missedThisCycle.isNotEmpty) ...[
            GroupHeader(l.makeUpTitle),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4, bottom: Space.sm),
              child: Text(l.makeUpBody, style: muted(theme.textTheme.bodySmall)),
            ),
            PaperGroup(
              children: [
                for (final e in missedThisCycle)
                  PaperRow(
                    icon: Icons.history,
                    title: name(e.plan.portion),
                    subtitle: names.dateLong(e.plan.week.occasion),
                    onTap: () => context.push('/progress/week/${e.plan.weekId}'),
                  ),
              ],
            ),
          ],
          GroupHeader(l.recentWeeks),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4),
              child: Text(l.noHistory, style: muted(theme.textTheme.bodyMedium)),
            )
          else
            _RecentWeeks(weeks: recent, today: current.today, name: name),
          const Gap(Rhythm.sectionGap),
          const _LifeHappens(),
          if (record.isNotEmpty) ...[
            GroupHeader(l.recordTitle),
            _Record(milestones: record, name: name),
          ],
        ],
      ),
    );
  }

  /// The verses of [cycle] read in all three readings.
  static int _versesRead(ParshaRepository repo, Map<String, WeekProgress> weeks, int cycle) {
    var verses = 0;
    for (final e in weeks.entries) {
      final colon = e.key.indexOf(':');
      if (colon < 0 || e.key.substring(0, colon) != '$cycle') continue;
      final PortionInfo info;
      try {
        info = repo.portion(PortionId.parse(e.key.substring(colon + 1)));
      } catch (_) {
        continue;
      }
      for (var a = 0; a < kAliyot; a++) {
        if (e.value.isAliyahDone(a)) verses += repo.aliyahVerseCount(info, a);
      }
    }
    return verses;
  }
}

/// The order of milestones reached on the same day, the last reached first:
/// the siyum above the book that completed it, and a book above the parsha.
int _recordRank(MilestoneKind kind) => switch (kind) {
      MilestoneKind.siyum => 7,
      MilestoneKind.sefer => 6,
      MilestoneKind.parshaStreak => 5,
      MilestoneKind.perfectWeek => 4,
      MilestoneKind.firstParsha => 3,
      MilestoneKind.daysOnTrack => 2,
      MilestoneKind.firstAliyah => 1,
      MilestoneKind.comeback => 0,
    };

/// The two paragraphs on how grace days and the parsha streak work, behind
/// the grace row's "About streaks": the streak's by the reader's [window]
/// after Shabbat.
Future<void> _showAboutStreaks(BuildContext context, LateWindow window) => showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final l = context.l10n;
        final theme = Theme.of(context);
        final padding = sheetPadding(context);
        final body = theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: Space.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SheetTitle(l.aboutStreaks),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l.graceExplainer, style: body),
                      const Gap(Space.md),
                      Text(
                        switch (window) {
                          LateWindow.tuesday => l.streakExplainer,
                          LateWindow.wednesday => l.streakExplainerWednesday,
                          LateWindow.none => l.streakExplainerNoWindow,
                        },
                        style: body,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

/// "This year": how many of the year's parshiyot are finished, the verses
/// read, and the year bar. With more than one year in the log, chips choose
/// which year it shows, and the Torah map below follows.
class _ThisYear extends StatelessWidget {
  const _ThisYear({
    required this.cycle,
    required this.live,
    required this.cycles,
    required this.onCycle,
    required this.done,
    required this.segments,
    required this.currentName,
    required this.verses,
  });

  final int cycle;
  final int live;
  final List<int> cycles;
  final ValueChanged<int> onCycle;
  final Set<int> done;
  final List<YearSegment> segments;
  final String currentName;
  final int verses;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final names = Names(context);
    final theme = Theme.of(context);
    final isLive = cycle == live;
    final versesCount = NumberFormat.decimalPattern(context.localeName).format(verses);
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, headingLevel: 2, child: Eyebrow(isLive ? l.thisYear : l.earlierYear)),
          if (cycles.length > 1) ...[
            const Gap(Space.sm),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final c in cycles)
                  SeferChoiceChip(
                    label: Text(names.hebrewYear(c)),
                    selected: c == cycle,
                    onSelected: (_) => onCycle(c),
                  ),
              ],
            ),
            const Gap(Space.xs),
          ],
          const Gap(Space.sm),
          Text(l.parshiyotOfYear(done.length, kParshaCount), style: theme.textTheme.headlineSmall),
          const Gap(2),
          Text(
            '${names.hebrewYear(cycle)} · ${l.versesRead(versesCount)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const Gap(Space.lg),
          YearBar(
            segments: segments,
            currentName: isLive ? currentName : null,
            year: isLive ? null : names.hebrewYear(cycle),
          ),
        ],
      ),
    );
  }
}

/// The weeks gone by, newest first: ten, and the rest a tap away.
class _RecentWeeks extends StatefulWidget {
  const _RecentWeeks({required this.weeks, required this.today, required this.name});

  final List<WeekEvaluation> weeks;
  final LocalDate today;
  final String Function(PortionId) name;

  /// Shown before "Show all".
  static const shown = 10;

  @override
  State<_RecentWeeks> createState() => _RecentWeeksState();
}

class _RecentWeeksState extends State<_RecentWeeks> {
  bool _all = false;
  final _showAll = FocusNode(debugLabel: 'Show all weeks');

  /// The first week "Show all" adds, which takes the focus from it.
  final _firstAdded = FocusNode(debugLabel: 'First week added');

  @override
  void dispose() {
    _showAll.dispose();
    _firstAdded.dispose();
    super.dispose();
  }

  void _expand() {
    final hadFocus = _showAll.hasFocus;
    setState(() => _all = true);
    // The button goes, so the keyboard's place goes on to what it showed.
    if (hadFocus) WidgetsBinding.instance.addPostFrameCallback((_) => _firstAdded.requestFocus());
  }

  @override
  Widget build(BuildContext context) {
    final weeks = widget.weeks;
    final more = !_all && weeks.length > _RecentWeeks.shown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaperGroup(
          children: [
            for (final (i, e) in (more ? weeks.take(_RecentWeeks.shown) : weeks).indexed)
              _WeekRow(
                name: widget.name(e.plan.portion),
                status: e.status,
                occasion: e.plan.week.occasion,
                today: widget.today,
                focusNode: i == _RecentWeeks.shown ? _firstAdded : null,
                onTap: () => context.push('/progress/week/${e.plan.weekId}'),
              ),
          ],
        ),
        if (more)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Center(
              child: TextButton(
                focusNode: _showAll,
                onPressed: _expand,
                child: Text(context.l10n.showAllWeeks(weeks.length)),
              ),
            ),
          ),
      ],
    );
  }
}

/// One week gone by: its parsha in titleMedium, how it ended (an icon and a
/// word, never colour alone), and its Shabbat at the end.
class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.name,
    required this.status,
    required this.occasion,
    required this.today,
    required this.onTap,
    this.focusNode,
  });

  final String name;
  final WeekStatus status;
  final LocalDate occasion;
  final LocalDate today;
  final VoidCallback onTap;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final names = Names(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final meta = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    // The year only for a week of another one.
    final date = occasion.year == today.year ? names.dateShort(occasion) : names.dateShortWithYear(occasion);
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 72),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.titleMedium),
                  const Gap(2),
                  Row(
                    children: [
                      Icon(WeekStatusBadge.icon(status), size: 16, color: WeekStatusBadge.color(context, status)),
                      const Gap(6),
                      Flexible(child: Text(WeekStatusBadge.label(context, status), style: meta)),
                    ],
                  ),
                ],
              ),
            ),
            const Gap(Space.md),
            Text(date, style: meta?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            const Gap(Space.xs),
            Icon(Icons.chevron_right, size: 20, color: scheme.outline),
          ],
        ),
      ),
    );
    return Semantics(
      container: true,
      button: true,
      child: SeferInkWell(
        focusNode: focusNode,
        onTap: onTap,
        borderRadius: PaperGroup.rowCorners(context),
        child: content,
      ),
    );
  }
}

/// "Life happens": a pause for illness, travel, mourning or a new baby. While
/// one covers today, it says until when, and offers to end or extend it. The
/// keyboard's focus moves on to what takes a button's place: the row, once
/// End pause has ended the pause, and End pause, once Extend has used up
/// the room there was.
class _LifeHappens extends ConsumerStatefulWidget {
  const _LifeHappens();

  @override
  ConsumerState<_LifeHappens> createState() => _LifeHappensState();
}

class _LifeHappensState extends ConsumerState<_LifeHappens> {
  final _row = FocusNode(debugLabel: 'Life happens');
  final _endPause = FocusNode(debugLabel: 'End pause');
  final _extend = FocusNode(debugLabel: 'Extend');

  /// Whether Extend was built, as of the last frame.
  bool _canExtend = false;

  @override
  void dispose() {
    _row.dispose();
    _endPause.dispose();
    _extend.dispose();
    super.dispose();
  }

  /// Gives [node] the focus once the frame that builds it is done.
  void _focusAfterFrame(FocusNode node) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && node.context != null) node.requestFocus();
      });

  void _end(LocalDate today) {
    final hadFocus = _endPause.hasFocus;
    ref.read(progressProvider.notifier).endPause(today);
    showStatus(context, context.l10n.pauseEnded);
    if (hadFocus) _focusAfterFrame(_row);
  }

  Future<void> _extendPause(LocalDate end) async {
    final hadFocus = _extend.hasFocus;
    await _showExtendPauseDialog(context, ref, end);
    if (!mounted || !hadFocus) return;
    // The focus comes back to Extend from the dialog, unless Extend is gone.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_canExtend && ref.read(isPausedProvider)) _endPause.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final paused = ref.watch(isPausedProvider);
    if (!paused) {
      return PaperGroup(
        children: [
          PaperRow(
            icon: Icons.pause_circle_outline,
            title: l.pauseTitle,
            subtitle: l.pauseRowBody,
            focusNode: _row,
            onTap: () => showPauseDialog(context, ref),
          ),
        ],
      );
    }
    final names = Names(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = ref.watch(todayProvider);
    final pause = ref.watch(progressProvider.select((p) => p.pauses)).firstWhere((p) => p.contains(today));
    final canExtend = _canExtend = _extensions(today, pause.end).isNotEmpty;
    return PaperGroup(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 38,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Icon(Icons.pause_circle_outline, size: 22, color: scheme.onSurfaceVariant),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.pauseTitle, style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurface)),
                    Text(
                      l.pausedBanner(names.dateLong(pause.end)),
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const Gap(Space.md),
                    Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.sm,
                      children: [
                        FilledButton.tonal(
                          focusNode: _endPause,
                          style: AppButtons.tonal(context),
                          onPressed: () => _end(today),
                          child: Text(l.endPause),
                        ),
                        if (canExtend)
                          TextButton(
                            focusNode: _extend,
                            onPressed: () => _extendPause(pause.end),
                            child: Text(l.extendPause),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The days a pause ending on [end] may be extended by, as of [today]: a
/// pause reaches no further than 30 days ahead, as a new one may.
List<int> _extensions(LocalDate today, LocalDate end) =>
    [for (final d in const [1, 3, 7, 14]) if (end.addDays(d) <= today.addDays(_maxPauseDays - 1)) d];

/// The longest pause, counted from its first day.
const _maxPauseDays = 30;

Future<void> _showExtendPauseDialog(BuildContext context, WidgetRef ref, LocalDate end) async {
  final l = context.l10n;
  final names = Names(context);
  final today = ref.read(todayProvider);
  final choices = _extensions(today, end);
  if (choices.isEmpty) return;
  var days = choices.first;
  final ok = await showAppDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text(l.extendPauseTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.extendPauseBy, style: theme.textTheme.titleSmall),
                const Gap(Space.sm),
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    for (final d in choices)
                      SeferChoiceChip(
                        label: Text(l.daysCount(d)),
                        selected: days == d,
                        onSelected: (_) => setState(() => days = d),
                      ),
                  ],
                ),
                const Gap(Space.lg),
                Text(
                  l.extendPauseUntil(names.dateLong(end.addDays(days))),
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.actionCancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.extendPause)),
          ],
        );
      },
    ),
  );
  if (ok != true) return;
  final until = end.addDays(days);
  ref.read(progressProvider.notifier).extendPause(today, until);
  if (context.mounted) showStatus(context, l.pauseStarted(names.dateLong(until)));
}

/// What the reader has finished so far, newest first (§9 Progress): only
/// what is done, never what is left. A finished book adds the words said as
/// one is.
class _Record extends StatelessWidget {
  const _Record({required this.milestones, required this.name});

  final List<Milestone> milestones;
  final String Function(PortionId) name;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final names = Names(context);
    String title(Milestone m) => switch (m.kind) {
          MilestoneKind.firstAliyah => l.milestoneFirstAliyah,
          MilestoneKind.firstParsha => l.milestoneFirstParsha,
          MilestoneKind.perfectWeek => l.milestonePerfectWeek,
          MilestoneKind.parshaStreak => l.milestoneParshaStreak(m.value),
          MilestoneKind.daysOnTrack => l.milestoneDaysOnTrack(m.value),
          MilestoneKind.sefer => l.seferDoneTitle(names.book(kTorahBooks[m.value])),
          MilestoneKind.siyum => switch (m.fromParsha) {
              final from? => l.milestoneSiyumFrom(name(PortionId(from))),
              null => l.milestoneSiyum,
            },
          MilestoneKind.comeback => l.milestoneComeback,
        };
    return PaperGroup(
      ruleInset: PaperGroup.iconInset,
      children: [
        for (final m in milestones)
          _RecordRow(
            title: title(m),
            date: m.achievedOn == null ? null : names.dateShortWithYear(m.achievedOn!),
            chazak: m.kind == MilestoneKind.sefer,
          ),
      ],
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.title, required this.date, required this.chazak});

  final String title;
  final String? date;

  /// Whether the row is a finished book, which "חֲזַק חֲזַק וְנִתְחַזֵּק" follows.
  final bool chazak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sefer = SeferColors.of(context);
    final titleStyle = theme.textTheme.bodyLarge!.copyWith(color: scheme.onSurface);
    final titleLine = MediaQuery.textScalerOf(context).scale(titleStyle.fontSize!) * titleStyle.height!;
    return Semantics(
      container: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: date == null ? 56 : 72),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The lozenge sits where a row's icon would, on the title's line.
              SizedBox(
                width: PaperGroup.iconInset - 16,
                height: titleLine,
                child: const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(start: 7),
                    child: Lozenge(),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: titleStyle),
                    if (date case final date?)
                      Text(
                        date,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    if (chazak)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.xs),
                        child: Lang(
                          const Locale('he'),
                          child: Text(
                            SeferCompleteScreen.chazak,
                            // Read from its letters, as screen readers read verses.
                            semanticsLabel: HebrewText.stripNikud(SeferCompleteScreen.chazak),
                            locale: const Locale('he'),
                            style: SeferType.of(context).hebrewDisplay.copyWith(
                                  fontSize: 17,
                                  height: 26 / 17,
                                  // Frank Ruhl Libre is set heavier in high contrast.
                                  fontWeight: sefer.isHighContrast ? FontWeight.w700 : FontWeight.w500,
                                  color: scheme.secondary,
                                ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A parsha's state on the Torah map (docs/DESIGN_SYSTEM.md §6.14).
enum _TileState { onTime, late, madeUp, missed, current, upcoming, untracked }

/// How a tile in a [_TileState] is drawn. Text is only ever set on a solid
/// fill, never a translucent one.
typedef _TileLook = ({Color fill, BorderSide border, Color text, bool bold, IconData? icon, Color iconColor});

_TileLook _lookOf(BuildContext context, _TileState state) {
  final scheme = Theme.of(context).colorScheme;
  final sefer = SeferColors.of(context);
  final status = StatusColors.of(context);
  final muted = scheme.onSurfaceVariant;
  final hairline = BorderSide(color: sefer.hairline, width: sefer.hairlineWidth);
  return switch (state) {
    _TileState.onTime => (
        fill: status.done,
        border: BorderSide.none,
        text: status.onDone,
        bold: false,
        icon: Icons.check,
        iconColor: status.onDone,
      ),
    _TileState.late => (
        fill: status.late,
        border: BorderSide.none,
        text: status.onLate,
        bold: false,
        icon: Icons.check_circle_outline,
        iconColor: status.onLate,
      ),
    _TileState.madeUp => (
        fill: sefer.paper,
        border: BorderSide(color: status.late, width: 1.5),
        text: scheme.onSurface,
        bold: false,
        icon: Icons.history,
        iconColor: status.late,
      ),
    // The dash, not the colour, is what sets a missed parsha apart from one
    // still to come.
    _TileState.missed => (
        fill: sefer.paper,
        border: BorderSide(color: scheme.outline, width: sefer.isHighContrast ? 2 : 1),
        text: muted,
        bold: false,
        icon: Icons.remove,
        iconColor: status.neutral,
      ),
    _TileState.current => (
        fill: scheme.primaryContainer,
        border: BorderSide(color: scheme.primary, width: 2),
        text: scheme.onPrimaryContainer,
        bold: true,
        icon: Icons.timelapse,
        iconColor: scheme.onPrimaryContainer,
      ),
    _TileState.upcoming =>
      (fill: sefer.paper, border: hairline, text: muted, bold: false, icon: null, iconColor: muted),
    _TileState.untracked => (
        fill: sefer.paper,
        border: hairline,
        text: muted,
        bold: false,
        icon: Icons.pause_circle_outline,
        iconColor: muted,
      ),
  };
}

const _tileRadius = BorderRadius.all(Radius.circular(6));
const _headerRadius = BorderRadius.all(Radius.circular(8));

/// Between tiles, across and down.
const double _tileGap = 6;
const double _tilePadding = 8;
const double _tileIcon = 14;
const double _tileIconGap = 4;

/// Every parsha of one year's cycle as a tile, book by book
/// (docs/DESIGN_SYSTEM.md §6.14). Each book has a header that folds it away;
/// only the book being read starts open.
class _TorahMap extends ConsumerStatefulWidget {
  const _TorahMap({
    required this.cycle,
    required this.summary,
    required this.done,
    required this.current,
    required this.live,
  });

  final int cycle;
  final StreakSummary summary;
  final Set<int> done;
  final WeekContext current;

  /// Whether [cycle] is this year's, whose current week is in progress. A
  /// year gone by has none.
  final bool live;

  @override
  ConsumerState<_TorahMap> createState() => _TorahMapState();
}

class _TorahMapState extends ConsumerState<_TorahMap> {
  /// The books shown open, by index in [kTorahBooks].
  late final Set<int> _open = {widget.current.portion.bookIndex};

  @override
  void didUpdateWidget(_TorahMap old) {
    super.didUpdateWidget(old);
    // A new week in another book opens that book too.
    if (old.current.week.portion != widget.current.week.portion) _open.add(widget.current.portion.bookIndex);
  }

  /// Each parsha's standing, as the year bar reads it too.
  late List<ParshaStanding> _standings;

  /// The tile's state, and the words for it.
  (_TileState, String) _stateOf(BuildContext context, PortionInfo p) {
    final l = context.l10n;
    return switch (_standings[p.id.number - 1]) {
      ParshaStanding.onTime => (_TileState.onTime, l.weekOnTime),
      ParshaStanding.late => (_TileState.late, l.weekLate),
      ParshaStanding.restored => (_TileState.late, l.weekRestored),
      ParshaStanding.inProgress => (_TileState.current, l.weekInProgress),
      ParshaStanding.madeUp => (_TileState.madeUp, l.weekMadeUp),
      ParshaStanding.missed => (_TileState.missed, l.weekMissed),
      ParshaStanding.overdue => (_TileState.missed, l.weekOverdue),
      ParshaStanding.upcoming => (_TileState.upcoming, l.dayUpcoming),
      ParshaStanding.untracked => (_TileState.untracked, l.weekTransparent),
    };
  }

  /// A book's columns: the window's (3, 4 or 6), unless large text would
  /// have to shrink a name of the book below [_minNameScale] to fit a tile:
  /// [leastShare] is the smallest share any of its names would be set at in
  /// a tile of a given room. A name wraps between words, never inside one: a
  /// word a little too long for its tile is set just small enough instead
  /// (see [_tile]).
  static int _columns(BuildContext context, double width, double Function(double room) leastShare) {
    final window = MediaQuery.sizeOf(context).width;
    final most = window >= Breakpoints.expanded ? 6 : (window >= Breakpoints.medium ? 4 : 3);
    for (var c = most; c > 1; c--) {
      if (leastShare(_room(width, c)) >= _minNameScale) return c;
    }
    return 1;
  }

  /// The least a name is shrunk to keep its longest word whole.
  static const _minNameScale = 0.8;

  static double _tileWidth(double width, int columns) => (width - _tileGap * (columns - 1)) / columns;

  /// The width a tile has for its name.
  static double _room(double width, int columns) => _tileWidth(width, columns) - 2 * _tilePadding;

  @override
  Widget build(BuildContext context) {
    final names = Names(context);
    final repo = ref.watch(parshaRepositoryProvider);
    final settings = ref.watch(settingsProvider);
    String name(PortionInfo p) => names.portion(p, ashkenazi: settings.ashkenaziNames);
    final books = [for (var b = 0; b < kTorahBooks.length; b++) repo.all.where((p) => p.bookIndex == b).toList()];
    _standings = parshaStandings(
      weeks: widget.summary.weeks,
      cycle: widget.cycle,
      done: widget.done,
      current: widget.live ? widget.current.week.portion : null,
    );

    // Tiles paint their fills as ink, so a press shows on them; this keeps
    // the ink moving with them as the page scrolls.
    return Material(
      type: MaterialType.transparency,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final words = _WordWidths(context);
          final width = constraints.maxWidth;
          // Each book its own columns, so a long word in one book never
          // changes another's. Any parsha may be the current one, which is
          // set in bold.
          final columns = [
            for (final book in books)
              _columns(
                context,
                width,
                (room) => book.map((p) => words.fit(name(p), bold: true, room: room)).reduce(math.min),
              ),
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var b = 0; b < books.length; b++) ...[
                _BookHeader(
                  book: b,
                  done: books[b].where((p) => widget.done.contains(p.id.number)).length,
                  total: books[b].length,
                  open: _open.contains(b),
                  onTap: () => setState(() => _open.contains(b) ? _open.remove(b) : _open.add(b)),
                ),
                if (_open.contains(b))
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    child: _grid(
                      context,
                      [for (final p in books[b]) _tile(context, p, name(p), words, _room(width, columns[b]))],
                      columns[b],
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// [tiles] in rows of [columns], each row as tall as its tallest tile, so
  /// tiles grow with the text instead of clipping it.
  static Widget _grid(BuildContext context, List<Widget> tiles, int columns) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i += columns) ...[
            if (i > 0) const SizedBox(height: _tileGap),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var c = 0; c < columns; c++) ...[
                    if (c > 0) const SizedBox(width: _tileGap),
                    Expanded(child: i + c < tiles.length ? tiles[i + c] : const SizedBox.shrink()),
                  ],
                ],
              ),
            ),
          ],
        ],
      );

  /// [room] is the tile's width for its name. A name with a word too long to
  /// sit beside the icon goes under it, and one with a word too long for the
  /// tile at all is set just small enough for it, so no word ever breaks.
  Widget _tile(BuildContext context, PortionInfo p, String name, _WordWidths words, double room) {
    final (state, label) = _stateOf(context, p);
    final semantic = '$name: $label';
    final look = _lookOf(context, state);
    final word = words.longest(name, bold: look.bold);
    // One node per tile, carrying the ink well's tap and focus.
    return Semantics(
      container: true,
      button: true,
      label: semantic,
      child: Tooltip(
        message: '$name — $label',
        excludeFromSemantics: true,
        child: _TileFace(
          state: state,
          onTap: () => context.push('/progress/week/${widget.cycle}:${p.id.number}'),
          name: name,
          stacked: look.icon != null && word > room - _tileIcon - _tileIconGap,
          nameScale: words.fit(name, bold: look.bold, room: room),
        ),
      ),
    );
  }
}

/// The widths of the words of parsha names in the map's tile style, at the
/// current text size.
class _WordWidths {
  /// Measures in [context], which is built again when a font arrives.
  _WordWidths(this.context) {
    FontsChangeScope.watch(context);
  }

  final BuildContext context;
  final _widths = <(String, bool), double>{};

  /// Where a name may wrap: at a space, or after a hyphen ("Lech-Lecha").
  static final _breaks = RegExp(r'(?<=-)|\s+');

  /// The width of the longest word in [name].
  double longest(String name, {required bool bold}) => _longestWord(name, bold).$2;

  /// The longest word in [name], and its width.
  (String, double) _longestWord(String name, bool bold) {
    var longest = ('', 0.0);
    for (final word in name.split(_breaks)) {
      final width = _widths[(word, bold)] ??= _measure(word, bold);
      if (width > longest.$2) longest = (word, width);
    }
    return longest;
  }

  /// The share of the reader's text size [name] is set at so that its
  /// longest word fits [room]: 1 where it fits already, and otherwise a hair
  /// under, so rounding never wraps the word after all. The word is measured
  /// again at the size it is set: letter spacing doesn't shrink with the
  /// text, nor quite does each glyph's advance.
  double fit(String name, {required bool bold, required double room}) {
    final (word, width) = _longestWord(name, bold);
    if (width <= room) return 1;
    final target = room - 0.5;
    var share = target / width;
    for (var i = 0; i < 3; i++) {
      final set = _measure(word, bold, share: share);
      if (set <= target) break;
      share *= target / set;
    }
    return share;
  }

  /// [word]'s width at [share] of the reader's text size, scaled as the
  /// tile scales its name (see [_TileFace.nameScale]).
  double _measure(String word, bool bold, {double share = 1}) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: bold ? FontWeight.w700 : null);
    final scaler = MediaQuery.textScalerOf(context);
    final fontSize = style?.fontSize ?? 13;
    final painter = TextPainter(
      text: TextSpan(text: word, style: style),
      textDirection: Directionality.of(context),
      textScaler: share == 1 ? scaler : TextScaler.linear(scaler.scale(fontSize) / fontSize * share),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}

/// A tile's fill, border and icon around its [name] (none in a legend
/// swatch). The fill is ink, so a press shows on it, and the border is drawn
/// over the tile, so every tile's content sits in the same place whatever its
/// border.
class _TileFace extends StatelessWidget {
  const _TileFace({
    required this.state,
    this.onTap,
    this.name,
    this.stacked = false,
    this.nameScale = 1,
    this.minHeight = 52,
  });

  final _TileState state;
  final VoidCallback? onTap;
  final String? name;

  /// Whether the icon sits above the name rather than beside it, for a name
  /// with a word too long to share the line. Within the minimum height, so
  /// the tile is no taller for it.
  final bool stacked;

  /// Below 1 for a name whose longest word would not fit the tile at the
  /// reader's text size: the size it is set at, as a share of that.
  final double nameScale;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final look = _lookOf(context, state);
    final scaler = MediaQuery.textScalerOf(context);
    final enlarged = scaler.scale(1) > 1;
    final name = this.name;
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: look.text,
          fontWeight: look.bold ? FontWeight.w700 : null,
        );
    final fontSize = style?.fontSize ?? 13;
    final content = Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.symmetric(horizontal: _tilePadding, vertical: 6),
      foregroundDecoration: look.border == BorderSide.none
          ? null
          : BoxDecoration(border: Border.fromBorderSide(look.border), borderRadius: _tileRadius),
      child: Flex(
        direction: stacked ? Axis.vertical : Axis.horizontal,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (look.icon != null) Icon(look.icon, size: _tileIcon, color: look.iconColor),
          if (look.icon != null && name != null)
            stacked ? const SizedBox(height: 2) : const SizedBox(width: _tileIconGap),
          if (name != null)
            Flexible(
              child: Text(
                name,
                textAlign: TextAlign.center,
                // Two lines at most, unless the text is enlarged: then a
                // name is never cut short (WCAG 1.4.4).
                maxLines: enlarged ? null : 2,
                overflow: enlarged ? null : TextOverflow.ellipsis,
                textScaler: nameScale < 1 ? TextScaler.linear(scaler.scale(fontSize) / fontSize * nameScale) : null,
                style: style,
              ),
            ),
        ],
      ),
    );
    final tap = onTap;
    return Ink(
      decoration: BoxDecoration(color: look.fill, borderRadius: _tileRadius),
      child: tap == null
          ? content
          : SeferInkWell(borderRadius: _tileRadius, onTap: tap, child: ExcludeSemantics(child: content)),
    );
  }
}

/// A book's row on the Torah map: its Hebrew name, its English name (in the
/// English UI), how many of its parshiyot are done, and a chevron. Tapping it
/// opens or folds the book.
class _BookHeader extends StatelessWidget {
  const _BookHeader({
    required this.book,
    required this.done,
    required this.total,
    required this.open,
    required this.onTap,
  });

  final int book;
  final int done;
  final int total;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sefer = SeferColors.of(context);
    final latin = kTorahBooks[book];
    final hebrew = SeferType.of(context).hebrewDisplay.copyWith(
          fontSize: 18,
          // Frank Ruhl Libre is set heavier in high contrast.
          fontWeight: sefer.isHighContrast ? FontWeight.w700 : FontWeight.w600,
          color: scheme.onSurface,
        );
    return Semantics(
      container: true,
      header: true,
      headingLevel: 3,
      button: true,
      expanded: open,
      label: l.torahMapBook(Names(context).book(latin), done, total),
      child: SeferInkWell(
        borderRadius: _headerRadius,
        onTap: onTap,
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        // One paragraph, so with large text the English
                        // name wraps under the Hebrew one.
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: kTorahBooksHe[book], style: hebrew),
                                if (!context.isHebrewUi) ...[
                                  const WidgetSpan(child: SizedBox(width: 8)),
                                  TextSpan(text: latin, style: theme.textTheme.titleSmall),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          l.countOfTotal(done, total),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: Motion.of(context).d(Motion.short),
                    child: Icon(Icons.expand_more, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Torah map's info button: it opens a sheet showing each tile state's
/// look beside its name.
class _TorahMapHelpButton extends StatelessWidget {
  const _TorahMapHelpButton();

  @override
  Widget build(BuildContext context) => IconButton(
        icon: const Icon(Icons.info_outline),
        tooltip: context.l10n.torahMapHelp,
        onPressed: () => _showTorahMapLegend(context),
      );
}

Future<void> _showTorahMapLegend(BuildContext context) => showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final l = context.l10n;
        final theme = Theme.of(context);
        final padding = sheetPadding(context);
        final entries = [
          (_TileState.onTime, l.weekOnTime),
          (_TileState.late, l.weekLate),
          (_TileState.late, l.weekRestored),
          (_TileState.madeUp, l.weekMadeUp),
          (_TileState.missed, l.weekMissed),
          // A tile's tooltip names it, so the legend names it too.
          (_TileState.missed, l.weekOverdue),
          (_TileState.current, l.weekInProgress),
          (_TileState.upcoming, l.dayUpcoming),
          (_TileState.untracked, l.weekTransparent),
        ];
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SheetTitle(l.torahMap),
                Padding(
                  padding: EdgeInsets.fromLTRB(padding, 0, padding, 8),
                  child: Text(
                    l.torahMapHelp,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                for (final (state, label) in entries)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: padding, vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(width: 56, child: _TileFace(state: state, minHeight: 32)),
                        const SizedBox(width: 16),
                        Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

/// "Life happens": pause streaks for up to 30 days, backdated up to 3 days.
Future<void> showPauseDialog(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final names = Names(context);
  final today = ref.read(todayProvider);
  var days = 7;
  var backdate = 0;
  final ok = await showAppDialog<bool>(
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
                runSpacing: 8,
                children: [
                  for (final d in const [1, 3, 7, 14, 30])
                    SeferChoiceChip(
                      label: Text(l.daysCount(d)),
                      selected: days == d,
                      onSelected: (_) => setState(() => days = d),
                    ),
                ],
              ),
              const Gap(12),
              Text(l.pauseStarting, style: Theme.of(context).textTheme.titleSmall),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final b in const [0, 1, 2, 3])
                    SeferChoiceChip(
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
  ref.read(progressProvider.notifier).addPause(start, end);
  if (context.mounted) showStatus(context, l.pauseStarted(names.dateLong(end)));
}
