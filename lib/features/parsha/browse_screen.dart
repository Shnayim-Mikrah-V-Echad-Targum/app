import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/calendar/parsha_schedule.dart';
import '../../data/models/parsha.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/fonts_change_scope.dart';
import '../../ui/widgets/lang.dart';
import '../../ui/widgets/lines.dart';
import '../../ui/widgets/ornaments.dart';
import '../../ui/widgets/paper_group.dart';
import '../progress/domain/milestones.dart' show parshiyotDoneInCycle;
import '../progress/domain/progress_models.dart';
import 'week_context.dart';

/// Every parsha of the Torah (docs/DESIGN_SYSTEM.md §9 Browse), on a sheet
/// of paper for each book: each with its number, or how far it is read this
/// year, its names, its verses and the day it is read in this year's cycle.
///
/// This week's parsha is marked at its start and named so, and the page
/// opens with it in view.
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  /// This week's row (the first, for two parshiyot read together).
  final _currentRow = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealCurrent());
  }

  /// Brings this week's row into view, three tenths of the way down the
  /// page, unless it already shows whole, as near the start of the Torah.
  void _revealCurrent() {
    final row = _currentRow.currentContext;
    if (!mounted || row == null || !row.mounted) return;
    final box = row.findRenderObject();
    final view = Scrollable.maybeOf(row)?.context.findRenderObject();
    if (box is! RenderBox || view is! RenderBox || !box.attached || !view.attached) return;
    final top = box.localToGlobal(Offset.zero, ancestor: view).dy;
    if (top >= 0 && top + box.size.height <= view.size.height) return;
    Scrollable.ensureVisible(
      row,
      alignment: 0.3,
      duration: Motion.of(context).d(Motion.medium),
      curve: Motion.standard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final repo = ref.watch(parshaRepositoryProvider);
    final ashkenazi = ref.watch(settingsProvider.select((s) => s.ashkenaziNames));
    final current = ref.watch(currentWeekProvider);
    final cycle = cycleYearOf(current.portion, current.occasion);
    final weeks = ref.watch(currentCycleWeeksProvider);
    final standing = _standing(ref.watch(progressProvider.select((p) => p.weeks)), cycle);
    final byNumber = {for (final p in repo.all) p.id.number: p};
    // A larger screen's rows end in a chevron; a phone's are tapped as they
    // are.
    final chevron = MediaQuery.sizeOf(context).width >= Breakpoints.medium;

    Widget row(PortionInfo p) {
      final n = p.id.number;
      final week = weeks[n];
      final other = week?.portion.parshiyot.where((o) => o != n).firstOrNull;
      final thisWeeks = current.portion.parshiyot;
      final thisWeek = !thisWeeks.contains(n)
          ? _ThisWeek.no
          : thisWeeks.length == 1
              ? _ThisWeek.only
              : n == thisWeeks.first
                  ? _ThisWeek.first
                  : _ThisWeek.second;
      return _ParshaRow(
        // The first of this week's rows, for two read together.
        key: thisWeek == _ThisWeek.only || thisWeek == _ThisWeek.first ? _currentRow : null,
        portion: p,
        week: week,
        readWith: other == null ? null : byNumber[other],
        ashkenazi: ashkenazi,
        standing: standing.done.contains(n)
            ? _Standing.done
            : standing.begun.contains(n)
                ? _Standing.begun
                : _Standing.none,
        thisWeek: thisWeek,
        chevron: chevron,
        // By the week's own id, which names both of two parshiyot read
        // together, as every other link to the week does.
        onTap: () => context.push('/parsha/week/${week == null ? '$cycle:$n' : weekIdFor(week.portion, week.occasion)}'),
      );
    }

    return PageScaffold(
      titleText: l.browseTitle,
      body: PageBody(
        children: [
          for (var b = 0; b < kTorahBooks.length; b++) ...[
            _BookHeader(
              book: b,
              count: repo.all.where((p) => p.bookIndex == b).length,
              top: b == 0 ? Space.md : Rhythm.sectionGap,
            ),
            PaperGroup(
              ruleInset: _ParshaRow.textStart,
              children: [for (final p in repo.all.where((p) => p.bookIndex == b)) row(p)],
            ),
          ],
        ],
      ),
    );
  }
}

/// How far a parsha is read in this year's cycle.
enum _Standing { none, begun, done }

/// Whether a parsha is this week's: [only] it, or the [first] or [second] of
/// two read together, whose rows share one rule and one eyebrow.
enum _ThisWeek { no, only, first, second }

/// The parshiyot of [cycle] finished, and those begun but not finished, by
/// number, from the weeks read in [weeks].
({Set<int> done, Set<int> begun}) _standing(Map<String, WeekProgress> weeks, int cycle) {
  final done = parshiyotDoneInCycle(weeks, cycle);
  final begun = <int>{};
  for (final MapEntry(:key, :value) in weeks.entries) {
    final colon = key.indexOf(':');
    if (colon < 0 || key.substring(0, colon) != '$cycle' || value.completedUnits == 0) continue;
    for (final part in key.substring(colon + 1).split('-')) {
      final n = int.tryParse(part);
      if (n != null && !done.contains(n)) begun.add(n);
    }
  }
  return (done: done, begun: begun);
}

/// The heading over a book's sheet: its Hebrew name in gold, beside it the
/// English one in the English UI, and at the end how many parshiyot it has.
/// A level-2 heading, named in the UI's language.
class _BookHeader extends StatelessWidget {
  const _BookHeader({required this.book, required this.count, required this.top});

  final int book;
  final int count;

  /// The space above it.
  final double top;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    // Frank Ruhl Libre 600, set heavier in high contrast as every Frank Ruhl
    // role is; never an interface font, which has no Hebrew.
    final hebrew = SeferType.of(context).hebrewDisplay.copyWith(
          fontSize: 20,
          height: 28 / 20,
          fontWeight: SeferColors.of(context).isHighContrast ? FontWeight.w700 : FontWeight.w600,
          color: scheme.secondary,
        );
    return Padding(
      // Inset as a group's header is.
      padding: EdgeInsetsDirectional.fromSTEB(Space.xs, top, Space.xs, Space.sm),
      child: MergeSemantics(
        child: Semantics(
          header: true,
          headingLevel: 2,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                // One paragraph, so that with large text the English name
                // wraps under the Hebrew one.
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: kTorahBooksHe[book], style: hebrew, locale: const Locale('he')),
                    if (!context.isHebrewUi) ...[
                      const WidgetSpan(child: SizedBox(width: Space.sm)),
                      TextSpan(text: kTorahBooks[book], style: theme.textTheme.titleSmall?.copyWith(color: muted)),
                    ],
                  ]),
                  semanticsLabel: Names(context).book(kTorahBooks[book]),
                ),
              ),
              const SizedBox(width: Space.md),
              Text(
                context.l10n.browseBookParshiyot(count),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: muted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One parsha on its book's sheet: its number in the Torah (a check instead
/// once it is read this year, or a half-filled clock while it is under way),
/// its name in the UI's language with the other at the end of the line, and
/// its verses and the day it is read this year, with the parsha read together
/// with it, if any.
///
/// This week's parsha has a 3 px techelet rule at its start and is named so
/// over its title; two read together share the rule, and the name over the
/// first. The row is one button, how far it is read its value; the number,
/// and in the English UI the Hebrew name, are for the eye.
class _ParshaRow extends StatelessWidget {
  const _ParshaRow({
    super.key,
    required this.portion,
    required this.week,
    required this.readWith,
    required this.ashkenazi,
    required this.standing,
    required this.thisWeek,
    required this.chevron,
    required this.onTap,
  });

  final PortionInfo portion;

  /// The week it is read in this year; null only if the schedule has none.
  final ReadingWeek? week;

  /// The parsha read together with it this year, if any.
  final PortionInfo? readWith;
  final bool ashkenazi;
  final _Standing standing;
  final _ThisWeek thisWeek;
  final bool chevron;
  final VoidCallback onTap;

  static const double _start = PaperGroup.plainInset;

  /// The column of the number or the mark, then the space after it, as wide
  /// together as a paper row's icon slot: the text starts where the text of
  /// the app's other sheets does.
  static const double _lead = 28;
  static const double _leadGap = PaperGroup.iconInset - _start - _lead;

  /// Where the row's text starts, and the hairline under it.
  static const double textStart = PaperGroup.iconInset;

  static const double _rule = 3;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final names = Names(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final sefer = SeferType.of(context);
    final hebrewUi = context.isHebrewUi;
    final muted = text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final latin = portion.displayName(ashkenazi: ashkenazi);
    // The number or the mark grows with the text only as far as its column
    // holds it.
    final markScaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5);

    final hebrewName = Text(
      hebrewUi ? names.portion(portion, ashkenazi: ashkenazi) : names.portionAlt(portion, ashkenazi: ashkenazi),
      style: sefer.hebrewDisplay.copyWith(
        fontSize: hebrewUi ? 20 : 18,
        height: hebrewUi ? 28 / 20 : 26 / 18,
        color: hebrewUi ? scheme.onSurface : scheme.onSurfaceVariant,
      ),
      textDirection: TextDirection.rtl,
      locale: const Locale('he'),
    );
    final latinName = Text(
      latin,
      style: hebrewUi ? muted : text.titleLarge?.copyWith(fontSize: 20, height: 26 / 20, color: scheme.onSurface),
      textDirection: TextDirection.ltr,
    );
    // The title in the UI's language, and the name in the other at its end.
    final title = hebrewUi
        ? _NameLine(title: hebrewName, name: latinName, nameInEnglish: true)
        : _NameLine(title: latinName, name: hebrewName, nameInEnglish: false);

    final range = portion.range;
    final week = this.week;
    final other = readWith;
    final subtitle = [
      names.range(portion.book, range.start.chapter, range.start.verse, range.end.chapter, range.end.verse),
      if (week != null)
        [
          if (other != null) l.browseReadWith(names.portion(other, ashkenazi: ashkenazi)),
          // In the UI's own calendar, as the week's page dates it.
          hebrewUi ? names.hebrewDayMonth(week.occasion) : names.dateMonthDay(week.occasion),
        ].join(DotLine.separator),
    ];

    final mark = switch (standing) {
      _Standing.done => Icons.check_circle,
      _Standing.begun => Icons.timelapse,
      _Standing.none => null,
    };
    final lead = ExcludeSemantics(
      child: SizedBox(
        width: _lead,
        child: mark == null
            ? Text(
                '${portion.id.number}',
                style: text.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                textAlign: TextAlign.center,
                textScaler: markScaler,
              )
            // A line of its own, for a baseline to set it on.
            : Text.rich(
                TextSpan(children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Icon(mark, size: markScaler.scale(18), color: scheme.primary),
                  ),
                ]),
                style: text.labelMedium,
                textAlign: TextAlign.center,
                textScaler: markScaler,
              ),
      ),
    );

    final content = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(_start, Space.md, chevron ? Space.md : Space.lg, Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (thisWeek == _ThisWeek.only || thisWeek == _ThisWeek.first)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: _lead + _leadGap, bottom: 2),
              child: Eyebrow(l.browseThisWeek),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              lead,
              const SizedBox(width: _leadGap),
              Expanded(
                // The chevron in the middle of the names and the verses,
                // below any eyebrow, as in every other row.
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [title, DotLine(subtitle, style: muted)],
                      ),
                    ),
                    if (chevron)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: Space.md),
                        child: Icon(Icons.chevron_right, size: 20, color: scheme.outline),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final corners = PaperGroup.rowCorners(context);
    return Semantics(
      container: true,
      button: true,
      // The second of this week's two, named so only over the first.
      label: thisWeek == _ThisWeek.second ? l.browseThisWeek : null,
      value: switch (standing) {
        _Standing.done => l.stateDone,
        _Standing.begun => l.weekInProgress,
        _Standing.none => null,
      },
      child: SeferInkWell(
        onTap: onTap,
        borderRadius: corners,
        child: thisWeek == _ThisWeek.no
            ? content
            : Stack(
                clipBehavior: Clip.none,
                children: [
                  content,
                  // This week's rule, inside the sheet's edge, and rounded
                  // with its corners at the head or foot of a book. Over two
                  // rows, the first's reaches into the second's, so that no
                  // seam shows where they meet.
                  Positioned.fill(
                    bottom: thisWeek == _ThisWeek.first ? -1 : 0,
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: corners,
                        child: Padding(
                          padding: EdgeInsetsDirectional.only(start: SeferColors.of(context).hairlineWidth),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: SizedBox(
                              width: _rule,
                              height: double.infinity,
                              child: ColoredBox(color: scheme.primary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// A parsha's [title] with its [name] in the other language at the end of
/// the title's line, on its baseline; or under the title once the two no
/// longer fit side by side, as with large text.
///
/// The English name in the Hebrew UI is read in an English voice
/// ([nameInEnglish]); the Hebrew name in the English UI only repeats the
/// title for the eye, and is not read.
class _NameLine extends StatelessWidget {
  const _NameLine({required this.title, required this.name, required this.nameInEnglish});

  final Text title;
  final Text name;
  final bool nameInEnglish;

  static const double _gap = Space.md;

  @override
  Widget build(BuildContext context) {
    // Measured again when a font arrives.
    FontsChangeScope.watch(context);
    final shownName = nameInEnglish ? Lang(const Locale('en'), child: name) : ExcludeSemantics(child: name);
    return LayoutBuilder(builder: (context, constraints) {
      if (_width(context, title) + _gap + _width(context, name) <= constraints.maxWidth) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [Expanded(child: title), const SizedBox(width: _gap), shownName],
        );
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, shownName]);
    });
  }

  /// How wide [text] is set on one line.
  static double _width(BuildContext context, Text text) {
    final bold = MediaQuery.boldTextOf(context) ? const TextStyle(fontWeight: FontWeight.bold) : null;
    final painter = TextPainter(
      text: TextSpan(text: text.data, style: DefaultTextStyle.of(context).style.merge(text.style).merge(bold)),
      textDirection: text.textDirection ?? Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: text.locale,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}
