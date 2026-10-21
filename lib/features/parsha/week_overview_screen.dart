import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/config.dart';
import '../../app/providers.dart';
import '../../core/calendar/local_date.dart';
import '../../core/text/hebrew_text.dart';
import '../../data/models/verse_ref.dart' show VerseRange;
import '../../services/feedback.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/fallbacks.dart';
import '../../ui/widgets/heading_reveal.dart';
import '../../ui/widgets/lang.dart';
import '../../ui/widgets/lines.dart';
import '../../ui/widgets/ornaments.dart';
import '../../ui/widgets/page_columns.dart';
import '../../ui/widgets/paper_group.dart';
import '../../ui/widgets/progress_widgets.dart';
import '../../ui/widgets/read_date_sheet.dart';
import '../notes/notes_screen.dart';
import '../notes/week_notes_row.dart';
import '../progress/domain/progress_models.dart';
import '../progress/domain/reading_plan.dart' show kSecondsPerVerse;
import '../progress/domain/streak_engine.dart' show WeekStatus;
import 'week_context.dart';
import 'week_rows.dart';

/// One week's portion: its aliyot, the plan, and progress. Used for any
/// week (current, past or future).
class WeekOverviewScreen extends ConsumerWidget {
  const WeekOverviewScreen({super.key, required this.weekId});

  final String weekId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(weekContextProvider(weekId));
    // A link to a week that doesn't exist.
    if (ctx == null) return const NotFoundPage();
    return WeekOverview(ctx: ctx, leading: homeLeading(context));
  }
}

/// A week's page (docs/DESIGN_SYSTEM.md §9 Parsha): the parsha's name at its
/// head with when it is read and its rings, then its seven aliyot on one
/// sheet of paper, each with its plan and its three readings, then the
/// haftarah and the discussion.
///
/// The name at the head is the page's heading. The app bar shows it too once
/// it has scrolled out of sight.
class WeekOverview extends ConsumerStatefulWidget {
  const WeekOverview({super.key, required this.ctx, this.leading, this.actions = const [], this.bareTitle = false});

  final WeekContext ctx;

  /// The app bar's leading button, if not the usual one.
  final Widget? leading;
  final List<Widget> actions;

  /// Whether the title revealed as the parsha's name scrolls away is the
  /// name alone ("Bereshit"), where the page's place already says it is a
  /// parsha (the Parsha tab), leaving room for the tab's actions on a
  /// phone; otherwise "Parshat Bereshit".
  final bool bareTitle;

  @override
  ConsumerState<WeekOverview> createState() => _WeekOverviewState();
}

// The parsha's names head the page; once they have scrolled under the app
// bar, it names the parsha itself.
class _WeekOverviewState extends ConsumerState<WeekOverview> with HeadingReveal<WeekOverview> {
  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final l = context.l10n;
    final names = Names(context);
    final settings = ref.watch(settingsProvider);
    final name = names.portion(ctx.portion, ashkenazi: settings.ashkenaziNames);
    final open = ctx.isOpen && !ctx.progress.isComplete;
    final clearable = ctx.progress.completedUnits > 0;
    // The week's haftarah, the notes on its verses and its discussion.
    final weekRows = [
      if (settings.haftarahEnabled || ctx.haftarahRequired) HaftarahRow(ctx: ctx),
      // Once the reader has marked a verse of the parsha.
      if (WeekNotesRow.shows(ref, ctx)) WeekNotesRow(ctx: ctx),
      if (AppConfig.communityEnabled) DiscussRow(ctx: ctx),
    ];

    Future<void> markWeek() async {
      final date = await pickReadDate(context, week: ctx.week, today: ctx.today, oneDayYomTov: settings.oneDayYomTov);
      if (date == null || !context.mounted) return;
      final wasComplete = ref.read(progressProvider).week(ctx.id).isComplete;
      ref.read(progressProvider.notifier).markWeek(ctx.id, date);
      hapticRecorded(ref, completedParsha: !wasComplete && ref.read(progressProvider).week(ctx.id).isComplete);
      showStatus(context, l.parshaComplete(name));
    }

    Future<void> clearWeek() async {
      final ok = await showAppDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.clearWeekConfirm(name)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.actionCancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.actionClear)),
          ],
        ),
      );
      if (ok == true && context.mounted) {
        final before = ref.read(progressProvider).week(ctx.id);
        ref.read(progressProvider.notifier).clearWeek(ctx.id);
        // The snackbar outlives this page, and its ref with it.
        final container = ProviderScope.containerOf(context, listen: false);
        showStatus(
          context,
          l.weekCleared(name),
          action: SnackBarAction(
            label: l.actionUndo,
            onPressed: () => container.read(progressProvider.notifier).restoreWeek(ctx.id, before),
          ),
        );
      }
    }

    // A desktop sets the parsha's head beside its aliyot, rather than over
    // them in a narrow column.
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.expanded;
    final width = wide ? ContentWidth.todayWide : ContentWidth.list;

    return PageScaffold(
      leading: widget.leading,
      titleText: l.parshaLabel(name),
      // Whole or not at all: it repeats the page's heading.
      title: AppBarTitle(widget.bareTitle ? name : l.parshaLabel(name), wholeOnly: true),
      titleRevealed: headingHidden,
      contentMaxWidth: width,
      actions: [
        ...widget.actions,
        PopupMenuButton<String>(
          tooltip: l.actionMore,
          popUpAnimationStyle: Motion.of(context).style,
          onSelected: (v) => switch (v) {
            'all' => markWeek(),
            'clear' => clearWeek(),
            'full' => context.push('/read/${ctx.id}/0?mode=full&from=week'),
            'notes' => context.push(notesPath()),
            _ => null,
          },
          // Ways to read first; then, under a hairline, what changes the
          // week's progress, the clearing last.
          itemBuilder: (context) => [
            SeferMenuItem(value: 'full', child: Text(l.fullTextMode)),
            SeferMenuItem(value: 'notes', child: Text(l.notesTitle)),
            if (open || clearable)
              PopupMenuDivider(
                thickness: SeferColors.of(context).hairlineWidth,
                color: SeferColors.of(context).hairline,
              ),
            if (open) SeferMenuItem(value: 'all', child: Text(l.markWholeWeek)),
            if (clearable) SeferMenuItem(value: 'clear', child: Text(l.clearWeek)),
          ],
        ),
      ],
      body: watchHeading(
        PageBody(
          maxWidth: width,
          children: [
            // From 1200, the parsha's head beside its aliyot and the rest of
            // the week (§9 Parsha tab, 6); below, one above the other.
            PageColumns(
              wide: wide,
              startFlex: 5,
              endFlex: 7,
              stackedGap: Rhythm.sectionGap,
              start: [
                _WeekHeader(ctx: ctx, namesKey: headingKey),
                if (!ctx.isOpen) ...[
                  const Gap(Space.xl),
                  NoticeBanner(
                    icon: Icons.visibility_outlined,
                    text: l.previewNotOpen(names.practiceDate(ctx.week.start)),
                  ),
                ],
              ],
              end: [
                // Digits, which an eyebrow never holds; inset as a group's
                // header. Nothing above it: side by side it starts level with
                // the parsha's name, and as one column it stands a section's
                // gap below the head.
                SectionHeader.plain(
                  l.aliyotProgress(ctx.progress.completedAliyot, kAliyot),
                  padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, 0, 0, Space.sm),
                ),
                PaperGroup(
                  ruleInset: _AliyahRow.textStart,
                  children: [for (var a = 0; a < kAliyot; a++) _AliyahRow(ctx: ctx, aliyah: a)],
                ),
                // With the haftarah off, no notes and no community, none.
                if (weekRows.isNotEmpty) ...[
                  const Gap(Rhythm.sectionGap),
                  PaperGroup(ruleInset: PaperGroup.iconInset, children: weekRows),
                ],
                if (open) ...[
                  const Gap(Space.xl),
                  // Read without the app, from a printed Chumash perhaps: taken
                  // at the reader's word.
                  Center(
                    child: TextButton.icon(
                      style: AppButtons.roomy(context, (12, 8, 4), vertical: 8),
                      icon: const Icon(Icons.import_contacts),
                      label: Text(l.markWholeWeek, textAlign: TextAlign.center),
                      onPressed: markWeek,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The head of the page, with no card: the parsha's pointed name in Hebrew,
/// its name in the UI's language, its verses, when it is read, how the week
/// stands, and the rings.
class _WeekHeader extends ConsumerWidget {
  const _WeekHeader({required this.ctx, required this.namesKey});

  final WeekContext ctx;

  /// For the names, which the page watches scroll out of sight.
  final Key namesKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final names = Names(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = ref.watch(settingsProvider);
    final repo = ref.watch(parshaRepositoryProvider);
    final portion = ctx.portion;
    final range = portion.range;
    final name = names.portion(portion, ashkenazi: settings.ashkenaziNames);
    final hebrewUi = context.isHebrewUi;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    // A name that wraps keeps to the page's start, whatever its own script.
    final start = Directionality.of(context) == TextDirection.rtl ? TextAlign.right : TextAlign.left;
    final occasion = ctx.week.occasion;
    final status = ctx.status;
    final thirdLabel = settings.usesRashi && !settings.usesOnkelos ? l.passRashi : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          key: namesKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The page's heading, named as the UI names the parsha.
            Semantics(
              header: true,
              headingLevel: 1,
              namesRoute: true,
              label: l.parshaLabel(name),
              child: ExcludeSemantics(
                child: WholeWords(
                  names.portionPointed(portion),
                  style: SeferType.of(context).hebrewDisplay.copyWith(fontSize: 36, height: 48 / 36),
                  textAlign: start,
                  textDirection: TextDirection.rtl,
                  locale: const Locale('he'),
                ),
              ),
            ),
            if (hebrewUi)
              Lang(
                const Locale('en'),
                // Whole, as the name above it is.
                child: WholeWords(
                  names.portionAlt(portion, ashkenazi: settings.ashkenaziNames),
                  style: muted,
                  textAlign: start,
                  textDirection: TextDirection.ltr,
                ),
              )
            else
              // The heading already says it.
              ExcludeSemantics(
                child: WholeWords(
                  name,
                  style: theme.textTheme.headlineMedium?.copyWith(color: scheme.onSurface),
                  textAlign: start,
                ),
              ),
          ],
        ),
        const Gap(Space.xs),
        DotLine(
          [
            names.range(portion.book, range.start.chapter, range.start.verse, range.end.chapter, range.end.verse),
            l.versesCount(repo.verseCount(portion)),
          ],
          style: muted,
        ),
        // When it is read, in the UI's own calendar (the Hebrew one in the
        // Hebrew UI), and then in the other.
        DotLine(
          [names.readOnLabel(ctx.week), hebrewUi ? names.dateWithYear(occasion) : names.hebrewDate(occasion)],
          style: muted,
        ),
        if (status != null) ...[
          const Gap(Space.xs),
          _StatusLine(status),
        ],
        const Gap(Space.xl),
        RingsWithLegend(
          progress: ctx.progress,
          aliyahWeights: ctx.aliyahVerses,
          size: ParshaRings.header,
          thirdLabel: thirdLabel,
        ),
      ],
    );
  }
}

/// How the week stands: an icon in its status colour, and its label.
class _StatusLine extends StatelessWidget {
  const _StatusLine(this.status);

  final WeekStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: Icon(
              WeekStatusBadge.icon(status),
              size: _iconScaler(context).scale(16),
              color: WeekStatusBadge.color(context, status),
            ),
          ),
        ),
        TextSpan(text: WeekStatusBadge.label(context, status)),
      ]),
      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
  }
}

/// One aliyah on the week's sheet (§9 Parsha, 3): a disc with its Hebrew
/// ordinal, or a check once its three readings are done; its name, verses
/// and the time they take; the day it is planned for; in a week of two
/// parshiyot, where the second begins, in the aliyah it begins in; and at
/// the end, pips for its three readings over a menu.
///
/// Today's aliyot say so in bold, and those planned for a day gone by that
/// are still to read give their day in the overdue colour, after a mark,
/// and say so to a screen reader too; never for a day that doesn't count
/// (before joining, or paused). A tap opens the reader.
///
/// Where text so large would leave the lines a word or two each between the
/// disc and the pips ([PaperRow.squeezes]), the row stacks, as a paper row
/// does: the disc and the name, then the lines the row's full width, then
/// the pips and the menu at either end of a line of their own.
class _AliyahRow extends ConsumerWidget {
  const _AliyahRow({required this.ctx, required this.aliyah});

  final WeekContext ctx;
  final int aliyah;

  static const double _start = PaperGroup.plainInset;
  static const double _disc = 40;
  static const double _discGap = 16;

  /// Where the row's text starts, and the hairline under it.
  static const double textStart = _start + _disc + _discGap;

  /// The column of the pips and, under them, the menu: as wide as the pips.
  /// The ring around the current one reaches a little past it, into the
  /// space either side.
  static const double _trailing = 52;

  /// Between the text and that column: little, since the menu's icon sits
  /// in the middle of its 48 dp target, and the pips beside a short title.
  static const double _trailingGap = Space.xs;

  /// At the end, room for the ring of a current reading at the end.
  static const double _end = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final names = Names(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final settings = ref.watch(settingsProvider);
    // Nothing is behind while paused, or on a day a pause covered.
    final paused = ref.watch(isPausedProvider);
    final pauses = ref.watch(progressProvider.select((p) => p.pauses));
    final r = ctx.portion.aliyot[aliyah];
    final verses = ctx.aliyahVerses[aliyah];
    final progress = ctx.progress;
    final done = progress.isAliyahDone(aliyah);
    final passes = [for (final p in ReadingPass.values) progress.isUnitDone(aliyah, p)];
    final secondName = settings.usesRashi && !settings.usesOnkelos ? l.passRashi : l.passTargum;
    final passNames = [l.passMikrah1, l.passMikrah2, secondName];
    final passStates = [
      for (final p in ReadingPass.values)
        l.passSemantics(passNames[p.index], passes[p.index] ? l.stateDone : l.stateNotDone),
    ];
    // The reading under way: the next of the aliyah to read next.
    final current = ctx.isOpen && ctx.nextAliyah == aliyah ? passes.indexOf(false) : -1;
    final other = ctx.portion.alternativeAliyah(aliyah);
    // In a week of two parshiyot, the aliyah the second begins in says
    // where it does.
    String? secondBegins;
    if (ref.watch(parshaRepositoryProvider).secondParsha(ctx.portion) case final second?) {
      final start = second.aliyot.first.start;
      if (r.contains(start)) {
        secondBegins = l.secondParshaBegins(
          names.portion(second, ashkenazi: settings.ashkenaziNames),
          names.verseRange(start.chapter, start.verse, start.chapter, start.verse),
        );
      }
    }
    final scaler = MediaQuery.textScalerOf(context);
    final titleStyle = text.titleMedium!.copyWith(color: scheme.onSurface);
    final titleLine = scaler.scale(titleStyle.fontSize!) * titleStyle.height!;

    Future<void> markRead() async {
      final date = await pickReadDate(context, week: ctx.week, today: ctx.today, oneDayYomTov: settings.oneDayYomTov);
      if (date == null || !context.mounted) return;
      final wasComplete = ref.read(progressProvider).week(ctx.id).isComplete;
      ref.read(progressProvider.notifier).markAliyah(ctx.id, aliyah, date);
      hapticRecorded(ref, completedParsha: !wasComplete && ref.read(progressProvider).week(ctx.id).isComplete);
      showStatus(context, l.markedRead);
    }

    final disc = ExcludeSemantics(
      child: Container(
        width: _disc,
        height: _disc,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? scheme.primary : SeferColors.of(context).ringTrack,
        ),
        child: done
            ? Icon(Icons.check, size: 20, color: scheme.onPrimary)
            : Text(
                HebrewText.gematria(aliyah + 1, punctuate: false),
                style: SeferType.of(context).ordinal.copyWith(fontSize: 18, height: 24 / 18, color: scheme.onSurface),
                textDirection: TextDirection.rtl,
                locale: const Locale('he'),
                // A letter, which grows with the text only as far as the
                // disc holds it.
                textScaler: scaler.clamp(maxScaleFactor: 1.3),
              ),
      ),
    );

    // Each word of the row whole, as very large text between the disc and
    // the pips would not keep it.
    final name = WholeWords(
      names.aliyah(aliyah),
      style: titleStyle,
      textAlign: TextAlign.start,
      // With its number, for a screen reader.
      semanticsLabel: l.aliyahWithName(names.aliyah(aliyah), aliyah + 1),
    );
    final lines = [
      DotLine(
        [
          // The book is the page's, named at its head.
          _unbroken(names.verseRange(r.start.chapter, r.start.verse, r.end.chapter, r.end.verse)),
          l.versesCount(verses),
          l.minutesEstimate((verses * kSecondsPerVerse / 60).ceil()),
        ],
        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
      ?_plan(context, counts: (date) => !paused && !pauses.any((p) => p.contains(date))),
      if (secondBegins != null)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: WholeWords(secondBegins, style: SeferType.of(context).marginalia, textAlign: TextAlign.start),
        ),
      if (other != null) _otherDivision(context, other),
    ];
    final pips = PassPips(
      states: [for (final d in passes) d ? PipState.done : PipState.pending],
      current: current < 0 ? null : current,
    );
    final menu = PopupMenuButton<String>(
      tooltip: l.moreOptionsFor(names.aliyah(aliyah)),
      popUpAnimationStyle: Motion.of(context).style,
      onSelected: (v) {
        if (v == 'read') markRead();
        if (v == 'unread') {
          ref.read(progressProvider.notifier).markAliyah(ctx.id, aliyah, null);
          showStatus(context, l.markedUnread);
        }
        if (v == 'full') context.push('/read/${ctx.id}/$aliyah?mode=full&from=week');
      },
      itemBuilder: (context) => [
        SeferMenuItem(value: 'full', child: Text(l.fullTextMode)),
        if (!done && ctx.isOpen) SeferMenuItem(value: 'read', child: Text(l.actionMarkRead)),
        if (progress.units[aliyah].any((d) => d != null))
          SeferMenuItem(value: 'unread', child: Text(l.actionMarkUnread)),
      ],
    );

    // The disc, the name and its lines, and the pips over the menu, side by
    // side.
    Widget sideBySide() => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.symmetric(vertical: Space.md), child: disc),
            const SizedBox(width: _discGap),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.md),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [name, ...lines]),
              ),
            ),
            const SizedBox(width: _trailingGap),
            SizedBox(
              width: _trailing,
              child: Column(
                children: [
                  // On the title's line.
                  Padding(
                    padding: const EdgeInsets.only(top: Space.md),
                    child: SizedBox(height: titleLine, child: Center(child: pips)),
                  ),
                  menu,
                ],
              ),
            ),
          ],
        );

    // The disc and the name, the lines the row's full width under them, and
    // the pips and the menu at either end of a line of their own.
    Widget stacked() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: Space.md),
              child: Row(children: [disc, const SizedBox(width: _discGap), Expanded(child: name)]),
            ),
            ...lines,
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [pips, menu]),
          ],
        );

    final content = Padding(
      padding: const EdgeInsetsDirectional.only(start: _start, end: _end),
      child: LayoutBuilder(
        builder: (context, constraints) =>
            PaperRow.squeezes(scaler, constraints.maxWidth - _disc - _discGap - _trailingGap - _trailing)
                ? stacked()
                : sideBySide(),
      ),
    );

    return Semantics(
      // Its own item, with the state of its three readings; the menu keeps
      // one of its own beside it.
      container: true,
      button: true,
      value: passStates.join(', '),
      child: SeferInkWell(
        onTap: () => context.push('/read/${ctx.id}/$aliyah?from=week'),
        borderRadius: PaperGroup.rowCorners(context),
        child: content,
      ),
    );
  }

  /// The day the aliyah is planned for: today in bold, and a day gone by
  /// with the aliyah still to read, on a day that [counts], in the overdue
  /// colour, after a mark.
  Widget? _plan(BuildContext context, {required bool Function(LocalDate date) counts}) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall;
    final day = ctx.plan.days.firstWhereOrNull((d) => d.aliyot.contains(aliyah))?.date;
    if (day == null && !ctx.plan.shabbatAliyot.contains(aliyah)) return null;
    // A sentence, which a line may end in after a dash.
    Widget line(String text, TextStyle? style) =>
        WholeWords(text, style: style, textAlign: TextAlign.start, breakAtHyphens: true);
    if (day == ctx.today) {
      return line(l.plannedForToday, style?.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w700));
    }
    final weekday = day == null ? null : Names(context).weekday(day);
    final label = weekday == null ? l.plannedForShabbat : l.plannedFor(weekday);
    if (!_overdue(day ?? ctx.week.occasion, counts: counts)) {
      return line(label, style?.copyWith(color: theme.colorScheme.onSurfaceVariant));
    }
    final color = StatusColors.of(context).overdue;
    return WholeWords.rich(
      // In words what the colour and the mark say.
      semanticsLabel: weekday == null ? l.plannedForShabbatOverdue : l.plannedForOverdue(weekday),
      TextSpan(children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 4),
            child: Icon(stillToReadIcon, size: _iconScaler(context).scale(14), color: color),
          ),
        ),
        TextSpan(text: label),
      ]),
      style: style?.copyWith(color: color),
      textAlign: TextAlign.start,
    );
  }

  /// Whether the aliyah, planned for [date], is still to read after that
  /// day; never for a day that doesn't count: before the reader joined, one
  /// a pause covered or any while paused (as [counts] says), or in a week
  /// that doesn't count at all.
  bool _overdue(LocalDate date, {required bool Function(LocalDate date) counts}) {
    if (ctx.progress.isAliyahDone(aliyah) || date >= ctx.today) return false;
    if (ctx.status == WeekStatus.transparent || !counts(date)) return false;
    final join = ctx.joinDate;
    return join == null || date >= join;
  }

  /// Where some sources divide the aliyah otherwise, as [other]: a line of
  /// meta, after a small mark, that steps back behind the aliyah's own lines
  /// rather than speak over them. The mark leads it as the overdue mark
  /// leads the plan's line, so that the two wrap alike.
  Widget _otherDivision(BuildContext context, VerseRange other) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    final range = Names(context).verseRange(other.start.chapter, other.start.verse, other.end.chapter, other.end.verse);
    final note = context.l10n.aliyahOtherDivision(_unbroken(range));
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: WholeWords.rich(
        semanticsLabel: note,
        TextSpan(children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: Space.xs),
              child: Icon(Icons.info_outline, size: _iconScaler(context).scale(14), color: color),
            ),
          ),
          TextSpan(text: note),
        ]),
        style: theme.textTheme.bodySmall?.copyWith(color: color),
        textAlign: TextAlign.start,
      ),
    );
  }
}

/// [range] kept on one line, so that a line never breaks inside a
/// reference ("4:19– / 26").
String _unbroken(String range) => range.replaceAll(' ', '\u00A0').replaceAll('–', '\u2060–\u2060');

/// How an icon in a line of text grows with it: a little, so that it stays
/// a mark beside the words rather than outgrowing them.
TextScaler _iconScaler(BuildContext context) => MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
