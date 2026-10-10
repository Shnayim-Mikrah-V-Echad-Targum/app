import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/shell.dart' show Breakpoints;
import '../../core/calendar/parsha_schedule.dart';
import '../../data/models/parsha.dart';
import '../../services/feedback.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/progress_widgets.dart';
import '../../ui/widgets/sefer_choice_chip.dart';
import '../parsha/week_context.dart';
import 'domain/milestones.dart';
import 'domain/parsha_standing.dart';
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
          SectionHeader(l.torahMap, trailing: const _TorahMapHelpButton()),
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
  const _TorahMap({required this.cycle, required this.summary, required this.done, required this.current});

  final int cycle;
  final StreakSummary summary;
  final Set<int> done;
  final WeekContext current;

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
  /// have to shrink the book's longest word below [_minNameScale] to fit a
  /// tile. A name wraps between words, never inside one: a word a little too
  /// long for its tile is set just small enough instead (see [_tile]).
  static int _columns(BuildContext context, double width, double longestWord) {
    final window = MediaQuery.sizeOf(context).width;
    final most = window >= Breakpoints.expanded ? 6 : (window >= Breakpoints.medium ? 4 : 3);
    for (var c = most; c > 1; c--) {
      if (_room(width, c) >= longestWord * _minNameScale) return c;
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
      current: widget.current.week.portion,
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
              _columns(context, width, book.map((p) => words.longest(name(p), bold: true)).reduce(math.max)),
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
          onTap: () => context.push('/week/${widget.cycle}:${p.id.number}'),
          name: name,
          stacked: look.icon != null && word > room - _tileIcon - _tileIconGap,
          // A hair under, so rounding never wraps the word after all.
          nameScale: word > room ? (room - 0.5) / word : 1,
        ),
      ),
    );
  }
}

/// The widths of the words of parsha names in the map's tile style, at the
/// current text size.
class _WordWidths {
  _WordWidths(this.context);

  final BuildContext context;
  final _widths = <(String, bool), double>{};

  /// Where a name may wrap: at a space, or after a hyphen ("Lech-Lecha").
  static final _breaks = RegExp(r'(?<=-)|\s+');

  /// The width of the longest word in [name].
  double longest(String name, {required bool bold}) =>
      name.split(_breaks).map((word) => _widths[(word, bold)] ??= _measure(word, bold)).reduce(math.max);

  double _measure(String word, bool bold) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: bold ? FontWeight.w700 : null);
    final painter = TextPainter(
      text: TextSpan(text: word, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
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
