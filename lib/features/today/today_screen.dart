import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/city_providers.dart';
import '../../app/providers.dart';
import '../../core/calendar/jewish_holidays.dart';
import '../../core/calendar/local_date.dart';
import '../../core/calendar/parsha_schedule.dart';
import '../../services/feedback.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/app_icon.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/fonts_change_scope.dart';
import '../../ui/widgets/lang.dart';
import '../../ui/widgets/ledger.dart';
import '../../ui/widgets/ornaments.dart';
import '../../ui/widgets/paper_group.dart';
import '../../ui/widgets/progress_widgets.dart';
import '../../ui/widgets/read_date_sheet.dart';
import '../community/ui/community_ui.dart';
import '../parsha/week_context.dart';
import '../progress/domain/progress_models.dart';
import '../progress/domain/streak_engine.dart';
import '../settings/app_settings.dart';
import '../settings/widgets/shabbat_times_setting.dart' show clockTime;
import 'today_clock.dart';

/// Today (docs/DESIGN_SYSTEM.md §9): a running head, the week's title page
/// with its rings and the one button that continues the reading, today's
/// reading or the aliyot to catch up, the week's days, the streaks, and the
/// week's haftarah and discussion.
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
    final g = Gutter.of(context);

    return PageScaffold(
      titleText: l.navToday,
      showAppBar: false,
      // Under the status bar, which no app bar clears here.
      body: SafeArea(
        bottom: false,
        child: PageBody(
          padding: EdgeInsets.fromLTRB(g, Space.md, g, Space.s40),
          children: [
            _TodayHeader(today: today),
            const Gap(Space.lg),
            if (paused) ...[
              NoticeBanner(
                icon: Icons.pause_circle_outline,
                text: l.pausedBanner(names.dateLong(pauses.firstWhere((p) => p.contains(today)).end)),
                // Two sentences, which beside the button would wrap into a
                // narrow column.
                actionBelow: true,
                action: TextButton(
                  onPressed: () {
                    ref.read(progressProvider.notifier).endPause(today);
                    showStatus(context, l.pauseEnded);
                  },
                  child: Text(l.resume),
                ),
              ),
              const Gap(Rhythm.cardGap),
            ],
            if (divergence != null) ...[
              _DivergenceBanner(divergence: divergence, settings: settings),
              const Gap(Rhythm.cardGap),
            ],
            if (previous != null) ...[
              _OpenPreviousNotice(previous: previous, current: ctx, today: today),
              const Gap(Rhythm.cardGap),
            ],
            _Hero(ctx: ctx, settings: settings),
            const Gap(Rhythm.cardGap),
            _TodayCard(ctx: ctx, settings: settings),
            const Gap(Rhythm.cardGap),
            InfoCard(
              padding: WeekStrip.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // On the line of the other cards' content: the card's 8,
                  // and 12 more.
                  SectionHeader(
                    l.weekStripLabel,
                    trailing: const WeekStripLegendButton(),
                    padding: const EdgeInsetsDirectional.only(start: Space.md),
                  ),
                  WeekStrip(
                    plan: ctx.plan,
                    today: today,
                    statuses: summary.days,
                    oneDayYomTov: settings.oneDayYomTov,
                    joinDate: settings.joinDate,
                    onDayTap: (day) => context.push('/read/${ctx.id}/${day.aliyot.first}'),
                  ),
                ],
              ),
            ),
            if (settings.showStreaks) ...[
              const Gap(Rhythm.cardGap),
              LedgerCard(
                parshaStreak: summary.parshaStreak,
                daysOnTrack: summary.daysOnTrack,
                beginsWith: names.portion(ctx.portion, ashkenazi: settings.ashkenaziNames),
                onTap: () => context.go('/progress'),
              ),
            ],
            GroupHeader(l.thisWeek),
            PaperGroup(
              children: [
                if (settings.haftarahEnabled || ctx.haftarahRequired) _haftarahRow(context, ctx),
                WeeklyThreadOpener(
                  portion: ctx.portion,
                  hebrewYear: cycleYearOf(ctx.week.portion, ctx.week.occasion),
                  builder: (context, progress, open) => PaperRow(
                    icon: Icons.forum_outlined,
                    title: l.discussThisWeek,
                    trailing: progress,
                    onTap: open,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The week's haftarah: its reference, and a line for a special haftarah
  /// and for the regular one its page also offers.
  PaperRow _haftarahRow(BuildContext context, WeekContext ctx) {
    final l = context.l10n;
    final names = Names(context);
    final h = ctx.haftarah;
    return PaperRow(
      icon: Icons.auto_stories_outlined,
      title: ctx.progress.haftarah != null ? l.haftarahRead : l.haftarahLabel,
      subtitle: [
        h.parts.map((p) => names.range(p.book, p.start.chapter, p.start.verse, p.end.chapter, p.end.verse)).join(' · '),
        if (h.specialKey case final key?) l.specialHaftarah(names.specialHaftarah(key)),
        if (h.regular != null) l.alsoRegularHaftarah,
      ].join('\n'),
      // A line for each fact, none cut short.
      subtitleMaxLines: null,
      onTap: () => context.push('/today/haftarah/${ctx.id}'),
    );
  }
}

/// The running head and the masthead: today's date in both calendars, the
/// app's name, and the guide a tap away.
class _TodayHeader extends StatelessWidget {
  const _TodayHeader({required this.today});

  final LocalDate today;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final names = Names(context);
    final theme = Theme.of(context);
    // Each UI's own calendar first.
    final runningHead = context.isHebrewUi
        ? ['${names.weekday(today)}, ${names.hebrewDate(today)}', names.dateMonthDay(today)]
        : [names.dateLong(today), names.hebrewDate(today)];
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DotLine(
                runningHead,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Gap(2),
              // The app's name, not a heading: the parsha's name below is
              // the page's heading.
              Text(l.appTitle, style: theme.textTheme.headlineMedium),
            ],
          ),
        ),
        IconButton(
          tooltip: l.guideTitle,
          icon: const AppIcon(Icons.help_outline),
          onPressed: () => context.push('/guide'),
        ),
      ],
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

/// The week's title page (§9 Today, 3): an eyebrow, the parsha's name in
/// Hebrew and in the UI's language, when it is read, the rings, and the one
/// filled button on the page, which names exactly where the reading
/// continues.
class _Hero extends ConsumerWidget {
  const _Hero({required this.ctx, required this.settings});

  final WeekContext ctx;
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final names = Names(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sefer = SeferType.of(context);
    final hebrewUi = context.isHebrewUi;
    final portion = ctx.portion;
    final week = ctx.week;
    final today = ctx.today;
    final vezot = week.portion.isVezotHaberakhah;
    final friday = today.weekday == _friday;

    final eyebrow = vezot
        ? l.simchatTorahEyebrow
        : friday && ref.watch(pastMiddayProvider)
            ? l.erevShabbat
            : l.parshatHashavua;
    final name = names.portion(portion, ashkenazi: settings.ashkenaziNames);
    final range = portion.range;
    final daysLeft = week.occasion.differenceInDays(today);
    // The days until the portion is read in synagogue: on Shabbat, or for
    // Vezot HaBerachah on Simchat Torah, which is seldom a Shabbat. On
    // Friday, that Shabbat begins this evening.
    final countdown = daysLeft < 0 || ctx.progress.isComplete
        ? null
        : vezot
            ? l.simchatTorahInDays(daysLeft)
            : friday
                ? l.shabbatBeginsTonight
                : week.occasion.isShabbat
                    ? l.shabbatInDays(daysLeft)
                    : null;
    // On the eve of Shabbat or Yom Tov, with a city chosen, when candles are
    // lit there tonight instead.
    final candles = ref.watch(candleLightingTodayProvider);
    final note = candles == null ? countdown : l.todayCandleLighting(clockTime(context, candles));
    final muted = scheme.onSurfaceVariant;
    final thirdLabel = settings.usesRashi && !settings.usesOnkelos ? l.passRashi : null;

    final title = Semantics(
      // Read through before the rings below it.
      container: true,
      explicitChildNodes: true,
      child: Column(
        children: [
          Eyebrow(eyebrow, textAlign: TextAlign.center),
          const Gap(Space.sm),
          // The page's heading, named as the UI names the parsha.
          Semantics(
            header: true,
            headingLevel: 1,
            label: l.parshaLabel(name),
            child: ExcludeSemantics(
              child: Lang(
                const Locale('he'),
                child: _WholeWords(
                  names.portionPointed(portion),
                  style: sefer.hebrewDisplay.copyWith(fontSize: 46, height: 60 / 46),
                  textDirection: TextDirection.rtl,
                  locale: const Locale('he'),
                ),
              ),
            ),
          ),
          if (hebrewUi)
            Lang(
              const Locale('en'),
              child: Text(
                names.portionAlt(portion, ashkenazi: settings.ashkenaziNames),
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
              ),
            )
          else
            // The heading already says it.
            ExcludeSemantics(
              child: _WholeWords(name, style: theme.textTheme.headlineLarge?.copyWith(color: scheme.onSurface)),
            ),
          const Gap(Space.xs),
          _DotLine(
            [
              names.range(portion.book, range.start.chapter, range.start.verse, range.end.chapter, range.end.verse),
              names.readOnLabel(week),
            ],
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            textAlign: TextAlign.center,
          ),
          if (note != null)
            Text(note, style: theme.textTheme.bodySmall?.copyWith(color: muted), textAlign: TextAlign.center),
        ],
      ),
    );

    return TitlePageFrame(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < Breakpoints.narrow ? Space.lg : Space.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const Gap(Space.lg),
          const SeferDivider(),
          const Gap(Space.lg),
          _HeroRings(ctx: ctx, thirdLabel: thirdLabel),
          const Gap(Space.md),
          if (ctx.progress.isComplete)
            Text(l.weekComplete, style: theme.textTheme.titleLarge, textAlign: TextAlign.center)
          else
            FilledButton.icon(
              // The hero's 52, and room around a label that large text wraps.
              style: AppButtons.roomy(context, (24, 12, 6))
                  .copyWith(minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52))),
              icon: const Icon(Icons.menu_book),
              label: Text(_continueLabel(context), textAlign: TextAlign.center),
              onPressed: () => context.push('/read/${ctx.id}/${ctx.nextAliyah}'),
            ),
        ],
      ),
    );
  }

  /// Where the button leads, exactly: "Start · Rishon" before anything of
  /// the week is read, "Continue · Shlishi, Targum" when some readings of
  /// the next aliyah are done, and otherwise "Continue · Shlishi".
  String _continueLabel(BuildContext context) {
    final l = context.l10n;
    final names = Names(context);
    final next = ctx.nextAliyah!;
    final aliyah = names.aliyah(next);
    final progress = ctx.progress;
    if (!progress.isStarted) return l.startAt(aliyah);
    if (!ReadingPass.values.any((p) => progress.isUnitDone(next, p))) return l.continueAt(aliyah);
    final pass = ReadingPass.values.firstWhere((p) => !progress.isUnitDone(next, p));
    return l.continueAtPass(aliyah, names.readingPass(pass, rashi: settings.usesRashi && !settings.usesOnkelos));
  }
}

/// The hero's rings and their legend, centred in the frame, and under the
/// legend's end the way to all seven aliyot.
class _HeroRings extends StatelessWidget {
  const _HeroRings({required this.ctx, required this.thirdLabel});

  final WeekContext ctx;
  final String? thirdLabel;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // As wide as the rings and their legend side by side can use (§6.11),
    // so that they sit in the middle of a wide frame.
    final width = ParshaRings.hero +
        RingsWithLegend.gap +
        RingLegend.naturalWidth(context, ctx.progress, thirdLabel: thirdLabel) +
        RingsWithLegend.maxSlack;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RingsWithLegend(progress: ctx.progress, aliyahWeights: ctx.aliyahVerses, thirdLabel: thirdLabel),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: _FlushTextButton(
                end: true,
                icon: Icons.chevron_right,
                label: l.allAliyot,
                onPressed: () => context.push('/today/week/${ctx.id}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [LocalDate.weekday]s, from Sunday's 0.
const _thursday = 4;
const _friday = 5;

/// Which day of the week Today's catch-up line speaks for: the line never
/// calls a day "midweek" that isn't one.
enum CatchUpDay {
  /// Sunday to Wednesday.
  midweek,

  /// Thursday, with Friday still to read on.
  thursday,

  /// The last reading day before Shabbat.
  erevShabbat,

  /// The last reading day before a Yom Tov that is not Shabbat.
  erevYomTov,
}

/// The [CatchUpDay] of [today], a reading day, by the reader's custom for
/// the days of Yom Tov.
CatchUpDay catchUpDayFor(LocalDate today, {required bool oneDayYomTov}) {
  final tomorrow = today.addDays(1);
  if (JewishHolidays.isRestDay(tomorrow, israel: oneDayYomTov)) {
    return tomorrow.isShabbat ? CatchUpDay.erevShabbat : CatchUpDay.erevYomTov;
  }
  return today.weekday == _thursday ? CatchUpDay.thursday : CatchUpDay.midweek;
}

/// Today's reading (§9 Today, 4), or while aliyot planned for earlier days
/// are still to read, those aliyot and today's together, with an honest
/// estimate and a calm word about the day. Reading from a printed Chumash
/// can always be logged here.
class _TodayCard extends ConsumerWidget {
  const _TodayCard({required this.ctx, required this.settings});

  final WeekContext ctx;
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final names = Names(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final paused = ref.watch(isPausedProvider);
    final day = ctx.plan.dayFor(ctx.today);
    final due = ctx.dueAliyot();
    final behind = ctx.behindBy();
    final next = ctx.nextAliyah;
    int versesOf(List<int> aliyot) => aliyot.fold(0, (n, a) => n + ctx.aliyahVerses[a]);

    /// Reading [target] when the hero's button doesn't already lead there,
    /// and logging [due] from a Chumash.
    Widget actions(int target) => Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (target != next)
              FilledButton.tonal(
                style: AppButtons.tonal(context).merge(AppButtons.roomy(context, (24, 12, 6))),
                onPressed: () => context.push('/read/${ctx.id}/$target'),
                child: Text(l.readAliyah(names.aliyah(target)), textAlign: TextAlign.center),
              ),
            _FlushTextButton(
              // At the start of the line, its icon on the text's edge.
              flush: target == next,
              icon: Icons.import_contacts,
              label: l.readFromBook,
              onPressed: () => _logFromBook(context, ref, due),
            ),
          ],
        );

    final List<Widget> children;
    if (behind > 0 && !paused && due.isNotEmpty) {
      // Everything due, from the first aliyah not read: where the hero's
      // button starts too.
      final line = switch (catchUpDayFor(ctx.today, oneDayYomTov: settings.oneDayYomTov)) {
        CatchUpDay.midweek => l.todayBehind(behind),
        CatchUpDay.thursday => l.todayBehindThursday(behind),
        CatchUpDay.erevShabbat => l.todayLastDayShabbat(due.length),
        CatchUpDay.erevYomTov => l.todayLastDayYomTov(due.length),
      };
      children = [
        _CardHeader(l.todayCatchUpTitle),
        Text(names.aliyotSpan(due), style: theme.textTheme.headlineSmall),
        Text(
          [l.aliyotCount(due.length), l.versesCount(versesOf(due)), l.minutesEstimate(ctx.remainingMinutes(due))]
              .join(' · '),
          style: muted,
        ),
        const Gap(Space.sm),
        Text(line, style: SeferType.of(context).marginalia),
        const Gap(Space.lg),
        actions(due.first),
      ];
    } else if (day == null) {
      children = [_CardHeader(l.todayReadingTitle), Text(l.todayNothingPlanned, style: muted)];
    } else {
      final unread = day.aliyot.where((a) => !ctx.progress.isAliyahDone(a)).toList();
      children = [
        _CardHeader(l.todayReadingTitle),
        Text(names.aliyot(day.aliyot), style: theme.textTheme.headlineSmall),
        Text(
          '${l.versesCount(versesOf(day.aliyot))} · ${l.minutesEstimate(ctx.remainingMinutes(day.aliyot))}',
          style: muted,
        ),
        const Gap(Space.lg),
        if (unread.isEmpty)
          Row(
            children: [
              Icon(Icons.check_circle, size: 20, color: theme.colorScheme.primary),
              const Gap(Space.sm),
              Expanded(child: Text(l.todayDone, style: theme.textTheme.titleSmall)),
            ],
          )
        else
          actions(unread.first),
      ];
    }
    return InfoCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  /// Logs reading done from a printed Chumash: which of [aliyot] (each
  /// checked to begin with), then when, then all of them at once.
  Future<void> _logFromBook(BuildContext context, WidgetRef ref, List<int> aliyot) async {
    final l = context.l10n;
    final chosen = await showAppSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _BookSheet(ctx: ctx, aliyot: aliyot),
    );
    if (chosen == null || chosen.isEmpty || !context.mounted) return;
    final date = await pickReadDate(context, week: ctx.week, today: ctx.today);
    if (date == null || !context.mounted) return;
    ref.read(progressProvider.notifier).markAliyot(ctx.id, chosen, date);
    hapticSuccess(ref);
    showStatus(context, l.markedRead);
  }
}

/// A card's eyebrow, a heading for screen readers, 4 above its title.
class _CardHeader extends StatelessWidget {
  const _CardHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      SectionHeader(text, padding: const EdgeInsetsDirectional.only(bottom: Space.xs));
}

/// The aliyot to log as read from a Chumash, each checked to begin with.
/// Returns those still checked.
class _BookSheet extends StatefulWidget {
  const _BookSheet({required this.ctx, required this.aliyot});

  final WeekContext ctx;
  final List<int> aliyot;

  @override
  State<_BookSheet> createState() => _BookSheetState();
}

class _BookSheetState extends State<_BookSheet> {
  late final Set<int> _checked = {...widget.aliyot};

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final names = Names(context);
    final padding = sheetPadding(context);
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle(l.readFromBookTitle),
            for (final a in widget.aliyot)
              CheckboxListTile(
                controlAffinity: ListTileControlAffinity.leading,
                value: _checked.contains(a),
                onChanged: (on) => setState(() => on! ? _checked.add(a) : _checked.remove(a)),
                title: Text(names.aliyah(a)),
                subtitle: Text(_reference(names, a)),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(padding, Space.sm, padding, Space.lg),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton(
                  style: AppButtons.roomy(context, (24, 12, 6)),
                  onPressed: _checked.isEmpty
                      ? null
                      : () => Navigator.pop(context, widget.aliyot.where(_checked.contains).toList()),
                  child: Text(l.actionContinue),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Genesis 2:20–3:21 · 23 verses".
  String _reference(Names names, int aliyah) {
    final r = widget.ctx.portion.aliyot[aliyah];
    return '${names.range(r.book, r.start.chapter, r.start.verse, r.end.chapter, r.end.verse)}'
        ' · ${context.l10n.versesCount(widget.ctx.aliyahVerses[aliyah])}';
  }
}

/// [parts] on one line, between middle dots, where they fit; otherwise each
/// on a line of its own, so that a line breaks between them rather than
/// inside one ("Read on Shabbat, October / 10").
class _DotLine extends StatelessWidget {
  const _DotLine(this.parts, {required this.style, this.textAlign = TextAlign.start});

  final List<String> parts;
  final TextStyle? style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    // Measured again when a font arrives.
    FontsChangeScope.watch(context);
    final joined = parts.join(' · ');
    return LayoutBuilder(builder: (context, constraints) {
      final bold = MediaQuery.boldTextOf(context) ? const TextStyle(fontWeight: FontWeight.bold) : null;
      final painter = TextPainter(
        text: TextSpan(text: joined, style: style?.merge(bold) ?? bold),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
        maxLines: 1,
      )..layout(maxWidth: constraints.maxWidth);
      final fits = !painter.didExceedMaxLines;
      painter.dispose();
      if (fits) return Text(joined, style: style, textAlign: textAlign);
      return Column(
        crossAxisAlignment: textAlign == TextAlign.center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [for (final p in parts) Text(p, style: style, textAlign: textAlign)],
      );
    });
  }
}

/// A text button with an icon, its padding roomy around a label that large
/// text wraps. At the edge of a line ([flush]), it is moved by its padding
/// toward that edge, so that its icon, not its padding, lines up with the
/// text above it; its ink and focus ring reach into the card's margin.
class _FlushTextButton extends StatelessWidget {
  const _FlushTextButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.flush = true,
    this.end = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool flush;

  /// At the end of the line, with the icon after the label (a chevron);
  /// otherwise at its start, with the icon before it.
  final bool end;

  @override
  Widget build(BuildContext context) {
    final padding = AppButtons.roomyPadding(context, (12, 8, 4), vertical: 8);
    final button = TextButton.icon(
      style: ButtonStyle(padding: WidgetStatePropertyAll(padding)),
      iconAlignment: end ? IconAlignment.end : IconAlignment.start,
      icon: Icon(icon),
      label: Text(label),
      onPressed: onPressed,
    );
    if (!flush) return button;
    final shift = (end ? 1 : -1) * padding.left * (Directionality.of(context) == TextDirection.rtl ? -1 : 1);
    return Transform.translate(offset: Offset(shift, 0), child: button);
  }
}

/// [text] wrapped between its words, never inside one: a word too wide for
/// the line on its own, as with large text, is set just small enough to fit.
/// Centred.
class _WholeWords extends StatelessWidget {
  const _WholeWords(this.text, {required this.style, this.textDirection, this.locale});

  final String text;
  final TextStyle? style;
  final TextDirection? textDirection;
  final Locale? locale;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final bold = MediaQuery.boldTextOf(context) ? const TextStyle(fontWeight: FontWeight.bold) : null;
        var widest = 0.0;
        for (final word in text.split(' ')) {
          final painter = TextPainter(
            text: TextSpan(text: word, style: style?.merge(bold) ?? bold),
            textDirection: textDirection ?? Directionality.of(context),
            textScaler: scaler,
            locale: locale,
            maxLines: 1,
          )..layout();
          widest = math.max(widest, painter.width);
          painter.dispose();
        }
        final size = style?.fontSize ?? 14;
        // A hair under, so rounding never breaks the word after all.
        final share = widest > constraints.maxWidth ? (constraints.maxWidth - 1) / widest : 1.0;
        return Text(
          text,
          style: style,
          textAlign: TextAlign.center,
          textDirection: textDirection,
          locale: locale,
          textScaler: share < 1 ? TextScaler.linear(scaler.scale(size) / size * share) : null,
        );
      });
}

/// Last week's parsha while it still needs attention: on the first reading
/// day after its Shabbat, whether it was read then; otherwise, that it is
/// still open, and how it can still count.
class _OpenPreviousNotice extends ConsumerWidget {
  const _OpenPreviousNotice({required this.previous, required this.current, required this.today});

  final WeekContext previous;
  final WeekContext current;
  final LocalDate today;

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
      return NoticeBanner(
        icon: Icons.import_contacts,
        title: l.checkInTitle,
        text: l.checkInBody,
        actionBelow: true,
        action: Wrap(
          alignment: WrapAlignment.end,
          spacing: Space.sm,
          runSpacing: Space.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: () => context.push('/today/week/${previous.id}'),
              child: Text(l.checkInPick),
            ),
            // Tonal: the hero's is the page's one filled button.
            FilledButton.tonal(
              style: AppButtons.tonal(context),
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
          ],
        ),
      );
    }

    final overdue = previous.status == WeekStatus.overdue;
    final nextName = names.portion(current.portion, ashkenazi: settings.ashkenaziNames);
    final onlyHaftarah = previous.progress.isComplete;
    return NoticeBanner(
      icon: Icons.schedule,
      title: l.openWeekTitle(name),
      text: [
        if (onlyHaftarah) l.openWeekHaftarahLeft,
        overdue ? l.openWeekRestore(name, nextName) : l.openWeekLate(names.dateLong(engine.lateDeadlineOf(previous.week))),
      ].join(' '),
      actionBelow: true,
      action: TextButton(
        onPressed: () => context.push(onlyHaftarah ? '/today/haftarah/${previous.id}' : '/today/week/${previous.id}'),
        child: Text(onlyHaftarah ? l.readTheHaftarah : l.openWeekOpen(name)),
      ),
    );
  }
}
