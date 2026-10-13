import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/city_providers.dart';
import '../../app/providers.dart';
import '../../core/calendar/hebrew_date.dart';
import '../../core/calendar/jewish_holidays.dart';
import '../../core/calendar/local_date.dart';
import '../../core/calendar/parsha_schedule.dart';
import '../../data/models/parsha.dart';
import '../../services/feedback.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/app_icon.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/lang.dart';
import '../../ui/widgets/ledger.dart';
import '../../ui/widgets/lines.dart';
import '../../ui/widgets/ornaments.dart';
import '../../ui/widgets/paper_group.dart';
import '../../ui/widgets/progress_widgets.dart';
import '../../ui/widgets/read_date_sheet.dart';
import '../community/ui/community_ui.dart';
import '../parsha/week_context.dart';
import '../parsha/week_rows.dart';
import '../progress/domain/progress_models.dart';
import '../progress/domain/streak_engine.dart';
import '../settings/app_settings.dart';
import '../settings/widgets/pause_setting.dart';
import '../settings/widgets/shabbat_times_setting.dart' show clockTime;
import 'check_in.dart';
import 'today_clock.dart';

/// Today (docs/DESIGN_SYSTEM.md §9): a running head, the week's title page
/// with its rings and the one button that continues the reading, today's
/// reading or the aliyot to catch up, the week's days, the streaks, and the
/// week's haftarah and discussion. On Shabbat and Yom Tov, the day's title
/// page alone.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  /// Forgets which weeks' completions have been drawn, as if the app had
  /// restarted.
  @visibleForTesting
  static void forgetCompletions() => _HeroState.forgetCompletions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final g = Gutter.of(context);
    final rest = ref.watch(restDayProvider);
    // A desktop's reading day is set in two columns; the day of rest's one
    // title page keeps the single column.
    final wide = rest == null && MediaQuery.sizeOf(context).width >= Breakpoints.expanded;
    return PageScaffold(
      titleText: l.navToday,
      showAppBar: false,
      // Under the status bar, which no app bar clears here.
      body: SafeArea(
        bottom: false,
        child: rest != null
            ? _RestDay(rest: rest, civil: ref.watch(civilDateProvider))
            : PageBody(
                maxWidth: wide ? ContentWidth.todayWide : ContentWidth.list,
                padding: EdgeInsets.fromLTRB(g, Space.md, g, Space.s40),
                children: _readingDay(context, ref, wide: wide),
              ),
      ),
    );
  }

  /// Today on a reading day: any notice, the week's title page, today's
  /// reading, the week's days, the streaks, and the week's haftarah and
  /// discussion. In one column, or when [wide] in two under the header
  /// (§9 Today, 9): the title page and today's reading beside the week.
  List<Widget> _readingDay(BuildContext context, WidgetRef ref, {required bool wide}) {
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
    final pauseEnd = ref.watch(
      progressProvider.select((p) => pauseEndToWelcome(p, today, oneDayYomTov: settings.oneDayYomTov)),
    );
    // Tisha B'Av, with no reading planned on it, or its eve from sunset in
    // the reader's city: nothing on the page invites any, so the welcome
    // back, which offers this week's parsha and last week's, waits for the
    // day after.
    final quietFast = ref.watch(plannerProvider).isQuietTishaBav(today) || ref.watch(fastBegunProvider);
    final welcome = pauseEnd != null && pauseEnd != settings.pauseEndSeen && !quietFast ? pauseEnd : null;
    // The welcome back offers last week while it can still count: within
    // its late window, or restorable by doubling up. Vezot HaBerachah, asked
    // about after Simchat Torah though it can no longer count late, is not.
    final catchUp = previous?.status == WeekStatus.inProgress || previous?.status == WeekStatus.overdue
        ? previous
        : null;
    // Last week's notice, unless the welcome back offers that week itself.
    // On a quiet fast it waits too, and so it does while the check-in, which
    // is never asked on the fast, is still to come the day after it.
    final shownPrevious = previous != null &&
            (welcome == null || catchUp == null) &&
            !quietFast &&
            !awaitsCheckIn(previous, today: today, settings: settings)
        ? previous
        : null;

    final reading = [
      if (paused) ...[
        NoticeBanner(
          icon: Icons.pause_circle_outline,
          // Until the last day of the pauses that run on from today's.
          text: l.pausedBanner(names.practiceDate(pauseCovering(pauses, today)!.end)),
          // Two sentences, which beside the button would wrap into a
          // narrow column.
          actionBelow: true,
          action: TextButton(
            // Back by choice, and told so here: no welcome back.
            onPressed: () => resumePause(context, ref),
            child: Text(l.resume),
          ),
        ),
        const Gap(Rhythm.cardGap),
      ],
      if (welcome != null) ...[
        _PauseEndedNotice(end: welcome, ctx: ctx, previous: catchUp),
        const Gap(Rhythm.cardGap),
      ],
      // Until put away for this week: next week's, if the two still differ,
      // is told again.
      if (divergence != null && settings.divergenceDismissedFor != ctx.id) ...[
        _DivergenceBanner(divergence: divergence, settings: settings, weekId: ctx.id),
        const Gap(Rhythm.cardGap),
      ],
      if (shownPrevious != null) ...[
        PreviousWeekNotice(previous: shownPrevious, current: ctx, today: today),
        const Gap(Rhythm.cardGap),
      ],
      _Hero(ctx: ctx, settings: settings, quietFast: quietFast),
      const Gap(Rhythm.cardGap),
      _TodayCard(ctx: ctx, settings: settings, quietFast: quietFast),
    ];
    final week = [
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
            _StripNote(ctx: ctx, summary: summary, settings: settings),
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
        ruleInset: PaperGroup.iconInset,
        children: [
          if (settings.haftarahEnabled || ctx.haftarahRequired) HaftarahRow(ctx: ctx),
          DiscussRow(ctx: ctx),
        ],
      ),
    ];
    return [
      // The reading day in both calendars: on Motzaei Shabbat after
      // nightfall it is already Sunday, as the rest of the page counts it.
      _TodayHeader(today: today, civil: today),
      const Gap(Space.lg),
      _Columns(main: reading, side: week, wide: wide),
    ];
  }
}

/// Today's two columns on a desktop (§9 Today, 9): seven parts of the width
/// for [main], the title page and today's reading, and five for [side], the
/// week, 24 apart and level at the top. Each column is a group of its own,
/// for keyboard focus and for screen readers, so that both go down the one
/// before the other, rather than across from one to the other by what stands
/// level on the page.
///
/// Until [wide], the two stand one above the other, a card's gap apart, as
/// one column. Either way they are the same widgets in the same places, so
/// that a window widened or narrowed across [Breakpoints.expanded] keeps
/// what they hold: the keyboard's focus, the title page's drawn frame, a
/// discussion opening.
class _Columns extends StatelessWidget {
  const _Columns({required this.main, required this.side, required this.wide});

  final List<Widget> main;
  final List<Widget> side;
  final bool wide;

  static const _gap = Space.xxl;

  @override
  Widget build(BuildContext context) {
    Widget column(List<Widget> children) => FocusTraversalGroup(
          child: Semantics(
            // As one column, its parts are the page's own, as before.
            container: wide,
            // Its headings, texts and controls each a node of their own, as
            // in the page's single column.
            explicitChildNodes: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        );
    // A Flex in either direction, rather than a Row or a Column, which as
    // widgets of different kinds would build both columns anew.
    return Flex(
      direction: wide ? Axis.horizontal : Axis.vertical,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.stretch,
      children: [
        Flexible(flex: wide ? 7 : 0, fit: FlexFit.tight, child: column(main)),
        SizedBox(width: wide ? _gap : 0, height: wide ? 0 : Rhythm.cardGap),
        Flexible(flex: wide ? 5 : 0, fit: FlexFit.tight, child: column(side)),
      ],
    );
  }
}

/// The running head and the masthead: today's date in both calendars; the
/// app's name, or from [Breakpoints.expanded], where the extended rail
/// beside the page already carries it, the tab's, as every other tab titles
/// its page; and the guide a tap away.
class _TodayHeader extends StatelessWidget {
  const _TodayHeader({required this.today, required this.civil});

  /// The reading day, or the day of rest: the Hebrew date and its weekday.
  final LocalDate today;

  /// The Gregorian date. On a day of rest it is the device's date
  /// ([civilDateProvider]), which differs from [today] only on its eve
  /// from candle-lighting, already Shabbat or Yom Tov by the Hebrew
  /// reckoning; on a reading day it is [today] itself.
  final LocalDate civil;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final names = Names(context);
    final theme = Theme.of(context);
    // Each UI's own calendar first, with its weekday: on Friday night,
    // "Friday, October 9 · 29 Tishrei 5787", and in Hebrew Shabbat's.
    final runningHead = context.isHebrewUi
        ? ['${names.weekday(today)}, ${names.hebrewDate(today)}', names.dateMonthDay(civil)]
        : [names.dateLong(civil), names.hebrewDate(today)];
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DotLine(
                runningHead,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Gap(2),
              // Not a heading: the parsha's name below is the page's heading.
              WholeWords(
                MediaQuery.sizeOf(context).width >= Breakpoints.expanded ? l.navToday : l.appTitle,
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.start,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: l.guideTitle,
          icon: const AppIcon(Icons.help_outline),
          onPressed: () => context.push('/today/guide'),
        ),
      ],
    );
  }
}

/// Names both portions in a week when Israel and the Diaspora read
/// different ones, for a reader who hears one place's reading but keeps the
/// other's days of Yom Tov. A visitor to Israel can open last week's portion
/// in Israel, their home portion this week, or change the reading they hear
/// in Settings. Either reader can put it away for the week [weekId].
class _DivergenceBanner extends ConsumerWidget {
  const _DivergenceBanner({required this.divergence, required this.settings, required this.weekId});

  final ReadingDivergence divergence;
  final AppSettings settings;
  final String weekId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final names = Names(context);
    final repo = ref.watch(parshaRepositoryProvider);
    // Each name whole, as a name of two parshiyot is kept ("Acharei" over
    // "Mot-Kedoshim"), though the sentences around them may break after a
    // hyphen.
    String name(PortionId p) => WholeWords.unbroken(names.portion(repo.portion(p), ashkenazi: settings.ashkenaziNames));
    final (israel, diaspora) = (name(divergence.israel), name(divergence.diaspora));
    final previous = divergence.previous;
    return NoticeBanner(
      icon: Icons.info_outline,
      text: divergence.hearsIsrael
          ? l.readingDivergence(israel, diaspora)
          : l.readingDivergenceAhead(israel, diaspora),
      actionBelow: true,
      // In the order the notice speaks of them: reading both portions, or
      // only the one heard, once Settings says which that is.
      action: divergence.hearsIsrael
          ? Wrap(
              alignment: WrapAlignment.end,
              spacing: Space.sm,
              runSpacing: Space.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (previous != null)
                  TextButton(
                    // Room around a label that large text wraps.
                    style: AppButtons.roomy(context, (12, 8, 4), vertical: 8),
                    onPressed: () => context.push('/today/week/${weekIdFor(previous.portion, previous.occasion)}'),
                    child: Text(l.readingDivergenceOpen(name(previous.portion)), textAlign: TextAlign.center),
                  ),
                TextButton(
                  style: AppButtons.roomy(context, (12, 8, 4), vertical: 8),
                  onPressed: () => context.push('/settings/reading'),
                  child: Text(l.readingDivergenceChange, textAlign: TextAlign.center),
                ),
              ],
            )
          : null,
      onDismiss: () => ref.read(settingsProvider.notifier).update((s) => s.copyWith(divergenceDismissedFor: weekId)),
      dismissLabel: l.actionDismiss,
    );
  }
}

/// The week's title page (§9 Today, 3): an eyebrow, the parsha's name in
/// Hebrew and in the UI's language, when it is read, the rings, and the one
/// filled button on the page, which names exactly where the reading
/// continues.
///
/// Once every aliyah is read, the rings and the button give way to a word
/// that the parsha is complete, the haftarah if it is still to read, and the
/// week's discussion. When that happens while the app is open, the frame's
/// gold rule draws itself around the page once (§8), and is still after;
/// a restarted app shows it still, as the rings show progress without a
/// sweep.
///
/// On a quiet Tisha B'Av ([quietFast]) the page is headed by the fast, and
/// has no button: nothing on it invites reading.
class _Hero extends ConsumerStatefulWidget {
  const _Hero({required this.ctx, required this.settings, required this.quietFast});

  final WeekContext ctx;
  final AppSettings settings;

  /// Tisha B'Av, with no reading planned on it
  /// ([ReadingPlanner.isQuietTishaBav]), or its eve from sunset in the
  /// reader's city ([fastBegunProvider]).
  final bool quietFast;

  @override
  ConsumerState<_Hero> createState() => _HeroState();
}

class _HeroState extends ConsumerState<_Hero> with SingleTickerProviderStateMixin {
  /// The weeks this run of the app has shown unfinished, and those whose
  /// frame has since drawn itself, by week id. In memory only.
  static final _seenOpen = <String>{};
  static final _framed = <String>{};

  /// How wide the button may grow in a wide frame, where the rings' group
  /// is narrower than this (§9 Today, 3).
  static const _buttonWidth = 360.0;

  static void forgetCompletions() {
    _seenOpen.clear();
    _framed.clear();
  }

  late final AnimationController _frame = AnimationController(vsync: this, value: 1);
  late final Animation<double> _draw = CurvedAnimation(parent: _frame, curve: Motion.standard);

  /// Whether the frame has yet to draw itself: set while the hero is hidden
  /// (a route covers it, or its tab is in the background), so that it waits
  /// until it can be seen.
  bool _pending = false;

  WeekContext get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _track();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _drawIfVisible();
  }

  @override
  void didUpdateWidget(_Hero old) {
    super.didUpdateWidget(old);
    if (old.ctx.id != ctx.id || old.ctx.progress.isComplete != ctx.progress.isComplete) {
      _track();
      _drawIfVisible();
    }
  }

  /// Notes a week shown unfinished, and readies the frame of one finished
  /// since.
  void _track() {
    final id = ctx.id;
    if (!ctx.progress.isComplete) {
      _seenOpen.add(id);
      _pending = false;
      _frame.value = 1;
    } else if (_seenOpen.contains(id) && !_framed.contains(id)) {
      _pending = true;
      _frame.value = 0;
    }
  }

  void _drawIfVisible() {
    if (!_pending || !TickerMode.valuesOf(context).enabled) return;
    _pending = false;
    _framed.add(ctx.id);
    final duration = Motion.of(context).d(Motion.frame);
    if (duration == Duration.zero) {
      _frame.value = 1;
    } else {
      _frame
        ..duration = duration
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final names = Names(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sefer = SeferType.of(context);
    final settings = widget.settings;
    final portion = ctx.portion;
    final week = ctx.week;
    final today = ctx.today;
    final vezot = week.portion.isVezotHaberakhah;
    final friday = today.weekday == _friday;
    final complete = ctx.progress.isComplete;
    // The eve of a Yom Tov that is not Shabbat, by the reader's days of Yom
    // Tov: reading stops this evening, however far off Shabbat is.
    final erevYomTov = JewishHolidays.erevYomTov(today, israel: settings.oneDayYomTov);

    final quietFast = widget.quietFast;
    // Watched only on an eve, which it turns at midday.
    final pastMidday = (friday || erevYomTov != null) && ref.watch(pastMiddayProvider);
    final eyebrow = vezot
        ? l.simchatTorahEyebrow
        : quietFast
            ? l.tishaBavTitle
            : friday && pastMidday
                ? l.erevShabbat
                : erevYomTov != null && pastMidday
                    ? l.erevYomTov(erevYomTov.name)
                    : l.parshatHashavua;
    final name = names.portion(portion, ashkenazi: settings.ashkenaziNames);
    final range = portion.range;
    final daysLeft = week.occasion.differenceInDays(today);
    // The days until the portion is read in synagogue: on Shabbat, or for
    // Vezot HaBerachah on Simchat Torah, which is seldom a Shabbat. On
    // Friday, that Shabbat begins this evening, and on the eve of Yom Tov,
    // that Yom Tov does: in the long week of Vezot HaBerachah too (Erev
    // Sukkot, say, or a Friday Hoshana Rabbah), unless Simchat Torah is
    // itself tomorrow, or today.
    final countdown = daysLeft < 0 || complete
        ? null
        : vezot && (!(friday || erevYomTov != null) || daysLeft <= 1)
            ? l.simchatTorahInDays(daysLeft)
            : friday
                ? l.shabbatBeginsTonight
                : erevYomTov != null
                    ? l.yomTovBeginsTonight(erevYomTov.name)
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
          _ParshaHeading(
            portion: portion,
            label: l.parshaLabel(name),
            style: sefer.hebrewDisplay.copyWith(fontSize: 46, height: 60 / 46),
          ),
          _LatinName(portion: portion, ashkenazi: settings.ashkenaziNames, style: theme.textTheme.headlineLarge),
          const Gap(Space.xs),
          DotLine(
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

    final padding = EdgeInsets.all(MediaQuery.sizeOf(context).width < Breakpoints.narrow ? Space.lg : Space.xxl);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title,
        const Gap(Space.lg),
        const SeferDivider(),
        const Gap(Space.lg),
        if (complete)
          ..._complete(context)
        else ...[
          _HeroRings(ctx: ctx, thirdLabel: thirdLabel),
          // On the fast, the rings and the way to the aliyot alone.
          if (!quietFast) ...[
            const Gap(Space.md),
            // As wide as the rings' group, or _buttonWidth if that is
            // wider, centred under the rings: the whole frame where that is
            // narrower, as on a phone, in a compact window or at large text.
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: math.max(_buttonWidth, _HeroRings.widthFor(context, ctx, thirdLabel)),
                ),
                child: FilledButton.icon(
                  // The hero's 52, as wide as it may be, and room around a
                  // label that large text wraps.
                  style: AppButtons.roomy(context, (24, 12, 6))
                      .copyWith(minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52))),
                  icon: const Icon(Icons.menu_book),
                  label: Text(_continueLabel(context), textAlign: TextAlign.center),
                  onPressed: () => context.push('/read/${ctx.id}/${ctx.nextAliyah}'),
                ),
              ),
            ),
          ],
        ],
      ],
    );
    if (!complete) return TitlePageFrame(padding: padding, child: body);
    return AnimatedBuilder(
      animation: _draw,
      builder: (context, child) => TitlePageFrame(padding: padding, drawProgress: _draw.value, child: child!),
      child: body,
    );
  }

  /// The complete week: a word that it is, a gentle line, and what is left
  /// to do with it, the haftarah and the discussion (on a quiet fast, which
  /// invites no study, nothing).
  List<Widget> _complete(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final settings = widget.settings;
    final haftarah = (settings.haftarahEnabled || ctx.haftarahRequired) && ctx.progress.haftarah == null;
    return [
      BalancedText(l.weekComplete, style: theme.textTheme.titleLarge, bySentence: true),
      const Gap(Space.xs),
      BalancedText(
        ctx.week.portion.isVezotHaberakhah ? l.weekCompleteNoteSimchatTorah : l.weekCompleteNote,
        style: SeferType.of(context).marginalia,
      ),
      if (!widget.quietFast) ...[
        const Gap(Space.lg),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: Space.sm,
          runSpacing: Space.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (haftarah)
              FilledButton.tonal(
                style: AppButtons.tonal(context).merge(AppButtons.roomy(context, (24, 12, 6))),
                onPressed: () => context.push('/today/haftarah/${ctx.id}'),
                child: Text(l.readTheHaftarah, textAlign: TextAlign.center),
              ),
            WeeklyThreadOpener(
              portion: ctx.portion,
              hebrewYear: cycleYearOf(ctx.week.portion, ctx.week.occasion),
              builder: (context, progress, open) => TextButton.icon(
                style: AppButtons.roomy(context, (12, 8, 4), vertical: 8),
                icon: progress ?? const Icon(Icons.forum_outlined),
                label: Text(l.discussTheParsha, textAlign: TextAlign.center),
                onPressed: open,
              ),
            ),
          ],
        ),
      ],
    ];
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
    final settings = widget.settings;
    return l.continueAtPass(aliyah, names.readingPass(pass, rashi: settings.usesRashi && !settings.usesOnkelos));
  }
}

/// The parsha's name, pointed, as the page's heading: its label names the
/// parsha as the UI does.
class _ParshaHeading extends StatelessWidget {
  const _ParshaHeading({required this.portion, required this.label, required this.style});

  final PortionInfo portion;
  final String label;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        headingLevel: 1,
        label: label,
        child: ExcludeSemantics(
          child: Lang(
            const Locale('he'),
            child: WholeWords(
              Names(context).portionPointed(portion),
              style: style,
              textDirection: TextDirection.rtl,
              locale: const Locale('he'),
            ),
          ),
        ),
      );
}

/// The parsha's name in Latin letters, under its pointed name: in the
/// English UI as the UI names it, in [style] and onSurface, for the eye
/// alone, as the heading's label already says it; in the Hebrew UI its
/// English name, small and muted, tagged as English.
class _LatinName extends StatelessWidget {
  const _LatinName({required this.portion, required this.ashkenazi, required this.style});

  final PortionInfo portion;
  final bool ashkenazi;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final names = Names(context);
    final theme = Theme.of(context);
    if (!context.isHebrewUi) {
      return ExcludeSemantics(
        child: WholeWords(
          names.portion(portion, ashkenazi: ashkenazi),
          style: style?.copyWith(color: theme.colorScheme.onSurface),
        ),
      );
    }
    return Lang(
      const Locale('en'),
      // Whole, as the name above it is: "Acharei" over "Mot-Kedoshim".
      child: WholeWords(
        names.portionAlt(portion, ashkenazi: ashkenazi),
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        textDirection: TextDirection.ltr,
      ),
    );
  }
}

/// The hero's rings and their legend, centred in the frame, and under the
/// legend's end the way to all seven aliyot.
class _HeroRings extends StatelessWidget {
  const _HeroRings({required this.ctx, required this.thirdLabel});

  final WeekContext ctx;
  final String? thirdLabel;

  /// As wide as the rings and their legend side by side can use (§6.11),
  /// so that they sit in the middle of a wide frame.
  static double widthFor(BuildContext context, WeekContext ctx, String? thirdLabel) =>
      ParshaRings.hero +
      RingsWithLegend.gap +
      RingLegend.naturalWidth(context, ctx.progress, thirdLabel: thirdLabel) +
      RingsWithLegend.maxSlack;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widthFor(context, ctx, thirdLabel)),
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

  /// The last reading day before a Shabbat that runs straight into Yom Tov:
  /// what is read then is logged after Yom Tov.
  erevShabbatThenYomTov,

  /// The last reading day before a Yom Tov that is not Shabbat.
  erevYomTov,

  /// The last reading day before a Yom Tov that runs straight into Shabbat
  /// (Rosh Hashanah on Thursday and Friday, say): what is read then is
  /// logged after Shabbat.
  erevYomTovThenShabbat,

  /// The day before Yom Kippur, whatever day of the week it is: neither
  /// called Yom Tov nor the end of the week, which always has a reading day
  /// after it.
  erevYomKippur,
}

/// The [CatchUpDay] of [today], a reading day, by the reader's custom for
/// the days of Yom Tov.
CatchUpDay catchUpDayFor(LocalDate today, {required bool oneDayYomTov}) {
  final tomorrow = today.addDays(1);
  if (JewishHolidays.isYomKippur(HebrewDate.fromLocalDate(tomorrow))) return CatchUpDay.erevYomKippur;
  if (JewishHolidays.isRestDay(tomorrow, israel: oneDayYomTov)) {
    // Logged once the days of rest are over, after whichever ends them.
    final endsWithShabbat = JewishHolidays.lastRestDay(tomorrow, israel: oneDayYomTov).isShabbat;
    if (tomorrow.isShabbat) return endsWithShabbat ? CatchUpDay.erevShabbat : CatchUpDay.erevShabbatThenYomTov;
    return endsWithShabbat ? CatchUpDay.erevYomTovThenShabbat : CatchUpDay.erevYomTov;
  }
  return today.weekday == _thursday ? CatchUpDay.thursday : CatchUpDay.midweek;
}

/// Today's reading (§9 Today, 4), or while aliyot planned for earlier days
/// are still to read, those aliyot and today's together, with an honest
/// estimate and a calm word about the day. Reading from a printed Chumash
/// can be logged here, on any day but a quiet Tisha B'Av, when the card
/// only says that Torah study is set aside.
class _TodayCard extends ConsumerWidget {
  const _TodayCard({required this.ctx, required this.settings, required this.quietFast});

  final WeekContext ctx;
  final AppSettings settings;

  /// Tisha B'Av, with no reading planned on it
  /// ([ReadingPlanner.isQuietTishaBav]), or its eve from sunset in the
  /// reader's city ([fastBegunProvider]).
  final bool quietFast;

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
    int versesOf(List<int> aliyot) => aliyot.fold(0, (n, a) => n + ctx.aliyahVerses[a]);
    // Calm words about the day: while paused, that nothing counts; on the
    // eve of Tisha B'Av, when many stop learning.
    final notes = [
      if (paused) l.pausedTodayNote,
      if (JewishHolidays.isTishaBav(ctx.today.addDays(1))) l.erevTishaBavNote,
    ];
    // Set evenly, as the note under the week strip is, so that no word is
    // left alone on a last line and no line starts with a dash.
    List<Widget> marginalia(List<String> lines) => [
          for (final (i, line) in lines.indexed) ...[
            Gap(i == 0 ? Space.sm : Space.xs),
            BalancedText(dashHeldToWord(line), style: SeferType.of(context).marginalia, textAlign: TextAlign.start),
          ],
        ];

    /// Reading [target], if given, and logging [shown], the aliyot the card
    /// names and has not seen read, from a Chumash.
    Widget actions(List<int> shown, {int? target}) => Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (target != null)
              FilledButton.tonal(
                style: AppButtons.tonal(context).merge(AppButtons.roomy(context, (24, 12, 6))),
                onPressed: () => context.push('/read/${ctx.id}/$target'),
                child: Text(l.readAliyah(names.aliyah(target)), textAlign: TextAlign.center),
              ),
            _FlushTextButton(
              // At the start of the line, its icon on the text's edge.
              flush: target == null,
              icon: Icons.import_contacts,
              label: l.readFromBook,
              onPressed: () => _logFromBook(context, ref, shown),
            ),
          ],
        );

    final List<Widget> children;
    if (quietFast) {
      // Nothing to read, catch up on or log: only the passages of mourning
      // are studied. The title page above is headed by the fast. The day
      // after it is always a reading day, but the reader's plan may have
      // nothing on it (the whole parsha on Erev Shabbat), or a pause may
      // run past it: the card names the day the parsha goes on, if any.
      final name = names.portion(ctx.portion, ashkenazi: settings.ashkenaziNames);
      final pauses = ref.watch(progressProvider.select((p) => p.pauses));
      final planner = ref.watch(plannerProvider);
      final tomorrow = ctx.today.addDays(1);
      LocalDate? resumes;
      if (!ctx.progress.isComplete) {
        // From sunset on its eve, tomorrow is the fast itself.
        for (var d = tomorrow; d < ctx.week.occasion; d = d.addDays(1)) {
          if (!planner.isQuietTishaBav(d) && !pauses.any((p) => p.contains(d)) && ctx.readsOn(d)) {
            resumes = d;
            break;
          }
        }
      }
      children = [
        _CardHeader(l.todayReadingTitle),
        Text(
          [
            l.todayTishaBav,
            if (resumes == tomorrow)
              l.todayTishaBavTomorrow(name)
            else if (resumes != null)
              l.todayTishaBavOn(name, names.weekday(resumes)),
          ].join(' '),
          style: muted,
        ),
      ];
    } else if (behind > 0 && !paused && due.isNotEmpty) {
      // Everything due, from the first aliyah not read, where the hero's
      // button starts too, so no other button leads to one. The line counts
      // what the card names.
      final count = due.length;
      final line = switch (catchUpDayFor(ctx.today, oneDayYomTov: settings.oneDayYomTov)) {
        CatchUpDay.midweek => l.todayBehind(count),
        CatchUpDay.thursday => l.todayBehindThursday(count),
        CatchUpDay.erevShabbat => l.todayLastDayShabbat(count),
        CatchUpDay.erevShabbatThenYomTov => l.todayLastDayShabbatThenYomTov(count),
        CatchUpDay.erevYomTov => l.todayLastDayYomTov(count),
        CatchUpDay.erevYomTovThenShabbat => l.todayLastDayYomTovThenShabbat(count),
        CatchUpDay.erevYomKippur => l.todayLastDayYomKippur(count),
      };
      children = [
        _CardHeader(l.todayCatchUpTitle),
        // Whole words: a name, and a run's dash with the name before it
        // ("Shlishi –"), set smaller where too wide for the line rather
        // than broken, so that no line starts with the dash.
        WholeWords(
          names.aliyotSpan(due),
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.start,
          breakAtHyphens: true,
        ),
        // Each fact whole, on a line of its own where they don't fit on one.
        DotLine(
          [l.aliyotCount(due.length), l.versesCount(versesOf(due)), l.minutesEstimate(ctx.remainingMinutes(due))],
          style: muted,
        ),
        ...marginalia([line, ...notes]),
        const Gap(Space.lg),
        actions(due),
      ];
    } else if (day == null) {
      children = [_CardHeader(l.todayReadingTitle), Text(l.todayNothingPlanned, style: muted), ...marginalia(notes)];
    } else {
      // While paused too, only today's aliyot, whatever was planned before.
      final unread = day.aliyot.where((a) => !ctx.progress.isAliyahDone(a)).toList();
      children = [
        _CardHeader(l.todayReadingTitle),
        WholeWords(names.aliyot(day.aliyot), style: theme.textTheme.headlineSmall, textAlign: TextAlign.start),
        DotLine(
          [
            // What is left to read, and once it is read, what was.
            if (unread.isEmpty)
              l.versesCount(versesOf(day.aliyot))
            else ...[
              l.versesCount(versesOf(unread)),
              l.minutesEstimate(ctx.remainingMinutes(unread)),
            ],
          ],
          style: muted,
        ),
        ...marginalia(notes),
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
          // Today's first aliyah, where the hero's button leads elsewhere
          // (while paused, to an aliyah planned before).
          actions(unread, target: unread.first == ctx.nextAliyah ? null : unread.first),
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
    final date = await pickReadDate(context, week: ctx.week, today: ctx.today, oneDayYomTov: settings.oneDayYomTov);
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
              TileFocusRing(
                child: CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _checked.contains(a),
                  onChanged: (on) => setState(() => on! ? _checked.add(a) : _checked.remove(a)),
                  title: Text(names.aliyah(a)),
                  subtitle: aliyahReference(context, widget.ctx, a),
                ),
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

/// Today on Shabbat or Yom Tov (§9 Today, 8): the header, and the day's
/// title page in the space under it, two fifths of the way down what it
/// leaves free, as a book's title stands a little above the middle of its
/// page. Where large text makes the page taller than the screen, it
/// scrolls.
class _RestDay extends StatelessWidget {
  const _RestDay({required this.rest, required this.civil});

  /// The day of rest, and the device's date ([_TodayHeader]).
  final LocalDate rest;
  final LocalDate civil;

  /// Two fifths of the free space above the title page, three below.
  static const _place = Alignment(0, -0.2);

  @override
  Widget build(BuildContext context) {
    final g = Gutter.of(context);
    // In the page's column, gutters included, as a PageBody's; each heading,
    // text and control a node of its own.
    Widget column(Widget child) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: ContentWidth.list),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: g),
              child: Semantics(explicitChildNodes: true, child: child),
            ),
          ),
        );
    // Built once, so that laying the page out again as it scrolls leaves it be.
    final titlePage = Padding(
      padding: EdgeInsets.only(top: Space.lg, bottom: Space.s40 + MediaQuery.paddingOf(context).bottom),
      child: Align(alignment: _place, child: column(_RestHero(date: rest))),
    );
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(top: Space.md),
          sliver: SliverToBoxAdapter(child: column(_TodayHeader(today: rest, civil: civil))),
        ),
        // As tall as the screen leaves under the header, or as the title page
        // with its margins where that is taller. A [SliverFillRemaining]
        // would ask the page its intrinsic height, which its balanced lines,
        // laid out by width, can't give.
        SliverLayoutBuilder(
          builder: (context, constraints) => SliverToBoxAdapter(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(0, constraints.viewportMainAxisExtent - constraints.precedingScrollExtent),
              ),
              child: titlePage,
            ),
          ),
        ),
      ],
    );
  }
}

/// The day of rest's title page ([restDayProvider], §9 Today, 8): candles, a
/// greeting, the parsha's name, a word that reading from a printed Chumash
/// is logged afterwards, and the way to the parsha. Nothing else, and
/// nothing moves.
class _RestHero extends ConsumerWidget {
  const _RestHero({required this.date});

  /// The day of rest, by the device's date.
  final LocalDate date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final names = Names(context);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    // The parsha read today, or on the Shabbat this Yom Tov comes before.
    final week = ref.watch(scheduleProvider).weekFor(date);
    final portion = ref.watch(parshaRepositoryProvider).portion(week.portion);
    final name = names.portion(portion, ashkenazi: settings.ashkenaziNames);
    bool yomTov(LocalDate d) => JewishHolidays.isYomTov(HebrewDate.fromLocalDate(d), israel: settings.oneDayYomTov);
    bool yomKippur(LocalDate d) => JewishHolidays.isYomKippur(HebrewDate.fromLocalDate(d));
    final last = JewishHolidays.lastRestDay(date, israel: settings.oneDayYomTov);
    // The day's own greeting, on Shabbat too: Yom Kippur is a fast, and Rosh
    // Hashanah has its wish for the year.
    final greeting = yomKippur(date)
        ? l.gmarChatimaTova
        : JewishHolidays.isRoshHashanah(HebrewDate.fromLocalDate(date))
            ? l.shanaTova
            : yomTov(date)
                ? l.chagSameach
                : l.shabbatShalom;
    final narrow = MediaQuery.sizeOf(context).width < Breakpoints.narrow;
    return TitlePageFrame(
      // A little more air above and below than a reading day's.
      padding: narrow
          ? const EdgeInsets.fromLTRB(Space.lg, Space.s28, Space.lg, Space.lg)
          : const EdgeInsets.fromLTRB(Space.xxl, Space.s40, Space.xxl, Space.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: ShabbatCandlesIcon(size: 48)),
          const Gap(Space.lg),
          BalancedText(greeting, style: theme.textTheme.displaySmall),
          const Gap(Space.xl),
          Semantics(
            container: true,
            explicitChildNodes: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Eyebrow(
                  week.portion.isVezotHaberakhah ? l.simchatTorahEyebrow : l.parshatHashavua,
                  textAlign: TextAlign.center,
                ),
                const Gap(Space.xs),
                _ParshaHeading(
                  portion: portion,
                  label: l.parshaLabel(name),
                  style: SeferType.of(context).hebrewDisplay.copyWith(fontSize: 40, height: 52 / 40),
                ),
                // Smaller than the reading day's, as the name above it is.
                _LatinName(portion: portion, ashkenazi: settings.ashkenaziNames, style: theme.textTheme.headlineSmall),
              ],
            ),
          ),
          const Gap(Space.lg),
          // Logged once the days of rest are over, after Yom Tov (or Yom
          // Kippur) where they end with one.
          BalancedText(
            yomKippur(last)
                ? l.restDayBodyYomKippur
                : yomTov(last)
                    ? l.restDayBodyChag
                    : l.restDayBody,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            bySentence: true,
          ),
          const Gap(Space.sm),
          Center(
            child: TextButton(
              style: AppButtons.roomy(context, (12, 8, 4), vertical: 8),
              onPressed: () => context.push('/today/week/${weekIdFor(week.portion, week.occasion)}'),
              child: Text(l.openTheParsha, textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }
}

/// The last day of the latest pause, once it has ended, for Today to
/// welcome the reader back from: until they read again, or put the welcome
/// away ([AppSettings.pauseEndSeen]). Null while paused, before any pause
/// has ended, and once reading has been logged for a day after it.
///
/// Null too for a pause made, or last changed, once it was over (by the
/// reading day of its stamp, by the reader's days of Yom Tov): one entered
/// after the fact, say, a few days back, or one ended early. Only a pause
/// that ended while the app was closed is welcomed.
LocalDate? pauseEndToWelcome(ProgressState progress, LocalDate today, {bool oneDayYomTov = false}) {
  Pause? latest;
  for (final p in progress.pauses) {
    if (p.deleted) continue;
    if (latest == null || p.end > latest.end) latest = p;
  }
  final end = latest?.end;
  if (latest == null || end == null || end >= today) return null;
  if (latest.updatedAt > 0) {
    final changed = DateTime.fromMillisecondsSinceEpoch(latest.updatedAt);
    if (effectiveReadingDay(changed, oneDayYomTov: oneDayYomTov) > end) return null;
  }
  for (final w in progress.weeks.values) {
    for (final row in w.units) {
      if (row.any((d) => d != null && d > end)) return null;
    }
  }
  return end;
}

/// Back after a pause that ended while the app was closed: welcomed, told
/// that nothing in it counted, and offered this week's parsha and last
/// week's while it can still count.
class _PauseEndedNotice extends ConsumerWidget {
  const _PauseEndedNotice({required this.end, required this.ctx, required this.previous});

  /// The pause's last day.
  final LocalDate end;
  final WeekContext ctx;

  /// Last week, unfinished, while it can still count: within its late
  /// window ([WeekStatus.inProgress]) or restorable by doubling up
  /// ([WeekStatus.overdue]).
  final WeekContext? previous;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final names = Names(context);
    final ashkenazi = ref.watch(settingsProvider.select((s) => s.ashkenaziNames));
    final previous = this.previous;
    final next = ctx.nextAliyah;
    final actions = [
      if (previous != null)
        TextButton(
          onPressed: () => context.push('/today/week/${previous.id}'),
          child: Text(l.catchUpOn(names.portion(previous.portion, ashkenazi: ashkenazi)), textAlign: TextAlign.center),
        ),
      // Tonal: the hero's is the page's one filled button.
      if (next != null)
        FilledButton.tonal(
          // Room around a label that large text wraps.
          style: AppButtons.tonal(context).merge(AppButtons.roomy(context, (24, 12, 6))),
          onPressed: () => context.push('/read/${ctx.id}/$next'),
          child: Text(ctx.progress.isStarted ? l.pauseEndedContinue : l.pauseEndedStart, textAlign: TextAlign.center),
        ),
    ];
    return NoticeBanner(
      icon: Icons.play_circle_outline,
      title: l.pauseEnded,
      text: l.pauseEndedOn(names.practiceDate(end)),
      actionBelow: true,
      action: actions.isEmpty
          ? null
          : Padding(
              // Clear of the corner, where the tonal button ends the row.
              padding: next != null ? NoticeBanner.tonalActionInset : EdgeInsets.zero,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: Space.sm,
                runSpacing: Space.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: actions,
              ),
            ),
      onDismiss: () => ref.read(settingsProvider.notifier).update((s) => s.copyWith(pauseEndSeen: end)),
      dismissLabel: l.actionDismiss,
    );
  }
}

/// What the note under Today's week strip tells.
enum StripNoteKind {
  /// A grace day covered a planned day.
  grace,

  /// Today's reading was read ahead.
  ahead,

  /// Doubling up today made up for yesterday.
  caughtUp,
}

/// What the note under Today's week strip tells, and of which days: each
/// grace day spent, in order, or today, or yesterday.
@immutable
class StripNote {
  const StripNote(this.kind, this.days);

  final StripNoteKind kind;
  final List<LocalDate> days;

  @override
  bool operator ==(Object other) => other is StripNote && other.kind == kind && const ListEquality<LocalDate>().equals(other.days, days);

  @override
  int get hashCode => Object.hash(kind, Object.hashAll(days));

  @override
  String toString() => 'StripNote(${kind.name}, $days)';
}

/// The one note under Today's week strip, if any (§9 Today, 5), from the
/// week's [days]: first the grace days that covered planned days, all of
/// them in one line, then today's reading read ahead, then yesterday made
/// up today.
///
/// A note tells of what was decided after [acknowledged], the last day the
/// reader put the notes away or saw them (see [AppSettings.lastStripAck]).
/// A grace day is decided once the planned day after it is over without the
/// reading made up, and is told within a week of that: every grace day not
/// yet told is told together, so that none is spent without a word.
StripNote? stripNoteFor(
  Map<LocalDate, DayStatus> days, {
  required LocalDate today,
  LocalDate? acknowledged,
}) {
  bool unacknowledged(LocalDate decided) => acknowledged == null || decided > acknowledged;
  final planned = days.keys.toList()..sort();
  final grace = <LocalDate>[];
  for (var i = planned.length - 1; i >= 0; i--) {
    final day = planned[i];
    if (days[day] != DayStatus.grace) continue;
    final decided = (i + 1 < planned.length ? planned[i + 1] : day).addDays(1);
    if (decided <= today.addDays(-7)) break;
    if (unacknowledged(decided)) grace.insert(0, day);
  }
  if (grace.isNotEmpty) return StripNote(StripNoteKind.grace, grace);
  if (!unacknowledged(today)) return null;
  if (days[today] == DayStatus.ahead) return StripNote(StripNoteKind.ahead, [today]);
  final yesterday = today.addDays(-1);
  if (days[yesterday] == DayStatus.caughtUp) return StripNote(StripNoteKind.caughtUp, [yesterday]);
  return null;
}

/// The note under the week strip ([stripNoteFor]), in the margin's voice,
/// with a button to put it away. Once seen, it is told for the rest of the
/// day.
class _StripNote extends ConsumerWidget {
  const _StripNote({required this.ctx, required this.summary, required this.settings});

  final WeekContext ctx;
  final StreakSummary summary;
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final names = Names(context);
    final today = ctx.today;
    final shown = settings.stripNoteShownOn;
    final acknowledged = [settings.lastStripAck, if (shown != null && shown < today) shown].nonNulls.maxOrNull;
    final note = stripNoteFor(summary.days, today: today, acknowledged: acknowledged);
    if (note == null) return const SizedBox.shrink();

    // Seen today, unless the page is out of sight (behind a route, or on
    // a tab in the background).
    if (shown != today && TickerMode.valuesOf(context).enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted || ref.read(settingsProvider).stripNoteShownOn == today) return;
        ref.read(settingsProvider.notifier).update((s) => s.copyWith(stripNoteShownOn: today));
      });
    }
    // A grace day spent is earned back by finishing this parsha by its
    // Shabbat, while there is room for one more.
    final earnsBack = ctx.week.occasion.isShabbat &&
        !ctx.week.portion.isVezotHaberakhah &&
        !ctx.isFinished &&
        summary.graceBalance < GraceRules.maxBalance;
    final weekdays = names.andList([for (final d in note.days) names.weekday(d)]);
    final text = switch (note.kind) {
      StripNoteKind.grace => earnsBack
          ? l.graceUsedNote(
              note.days.length,
              weekdays,
              names.portion(ctx.portion, ashkenazi: settings.ashkenaziNames),
            )
          : l.graceUsedNoteShort(note.days.length, weekdays),
      StripNoteKind.ahead => l.todayAhead,
      StripNoteKind.caughtUp => l.caughtUpNote,
    };
    return Padding(
      // On the line of the header above, and clear of the card's foot.
      padding: const EdgeInsetsDirectional.only(start: Space.md, bottom: Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The first line on the close button's centre.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: BalancedText(
                dashHeldToWord(text),
                style: SeferType.of(context).marginalia,
                textAlign: TextAlign.start,
              ),
            ),
          ),
          IconButton(
            tooltip: l.actionDismiss,
            icon: Icon(Icons.close, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
            onPressed: () => ref.read(settingsProvider.notifier).update((s) => s.copyWith(lastStripAck: today)),
          ),
        ],
      ),
    );
  }
}
