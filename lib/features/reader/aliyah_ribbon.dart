import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/text/hebrew_text.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/fonts_change_scope.dart';
import '../../ui/widgets/ornaments.dart';
import '../progress/domain/progress_models.dart';

/// The week's seven aliyot as a ribbon of tabs across the top of the reader
/// (docs/DESIGN_SYSTEM.md §6.16). Each tab shows the aliyah's Hebrew
/// ordinal, its name, and a pip for each of its three readings, filled once
/// that reading is done. The open aliyah has a bar beneath it and its letter
/// and name in full ink: being open says nothing about being read.
///
/// The tabs share the width when all seven fit, names and all; otherwise
/// (a narrow phone, large text) they scroll, and the open one is kept in
/// view.
class AliyahRibbon extends StatefulWidget {
  const AliyahRibbon({
    super.key,
    required this.week,
    required this.aliyahVerses,
    required this.selected,
    required this.onSelected,
    required this.maxWidth,
  });

  /// What has been read of the week.
  final WeekProgress week;

  /// The number of verses in each aliyah, which tells a reading under way
  /// from a stale saved place (see [WeekProgress.isAliyahStarted]).
  final List<int> aliyahVerses;

  final int selected;
  final ValueChanged<int> onSelected;

  /// The reading column's width, which the tabs keep within on a wide screen.
  final double maxWidth;

  /// The ribbon's height at the normal text size; it grows with the text.
  static const double minHeight = 76;

  /// The narrowest a tab may be when the seven share the width.
  static const double minTabWidth = 56;

  /// The narrowest a tab is when the ribbon scrolls.
  static const double scrollingTabWidth = 64;

  static const double _padding = 8;

  @override
  State<AliyahRibbon> createState() => _AliyahRibbonState();
}

class _AliyahRibbonState extends State<AliyahRibbon> {
  // One key per tab, never moved, so that a tab keeps its focus when it is
  // selected, and when the ribbon changes between sharing the width and
  // scrolling.
  final _tabKeys = List.generate(kAliyot, (_) => GlobalKey());

  // Whether the tabs scroll, as last laid out.
  bool _scrolls = false;

  @override
  void didUpdateWidget(AliyahRibbon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _revealSelected(animate: true);
  }

  /// Centres the open aliyah's tab unless it is already in full view: on a
  /// narrow phone, Shevi'i's starts off screen. Nothing moves while the tabs
  /// share the width.
  void _revealSelected({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tab = _tabKeys[widget.selected].currentContext;
      if (!mounted || tab == null) return;
      final box = tab.findRenderObject();
      final viewport = box == null ? null : RenderAbstractViewport.maybeOf(box);
      final position = Scrollable.maybeOf(tab, axis: Axis.horizontal)?.position;
      if (box == null || viewport == null || position == null) return;
      final startAligned = viewport.getOffsetToReveal(box, 0).offset;
      final endAligned = viewport.getOffsetToReveal(box, 1).offset;
      if (position.pixels >= endAligned && position.pixels <= startAligned) return;
      Scrollable.ensureVisible(
        tab,
        alignment: 0.5,
        duration: animate ? Motion.of(context).d(Motion.medium) : Duration.zero,
        curve: Motion.standard,
      );
    });
  }

  /// The name's style: labelSmall without tracking, so that "Chamishi" fits a
  /// seventh of a 412 dp phone in bold (as the navigation bar's labels do),
  /// and in bold and full ink on the open tab.
  TextStyle? _nameStyle(BuildContext context, {required bool selected}) {
    final theme = Theme.of(context);
    return theme.textTheme.labelSmall?.copyWith(
      letterSpacing: 0,
      color: selected ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
      fontWeight: selected ? FontWeight.w700 : null,
    );
  }

  /// The width of the widest name on one line, as if it were the open one,
  /// in bold.
  double _widestName(BuildContext context) {
    FontsChangeScope.watch(context);
    final names = Names(context);
    final style = _nameStyle(context, selected: true);
    var widest = 0.0;
    for (var a = 0; a < kAliyot; a++) {
      final painter = TextPainter(
        text: TextSpan(text: names.aliyah(a), style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    return widest;
  }

  @override
  Widget build(BuildContext context) {
    final sefer = SeferColors.of(context);
    final widest = _widestName(context);
    // Tabs as tall as the tallest, and the ribbon never shorter than its
    // normal height.
    Widget row(List<Widget> tabs) => ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AliyahRibbon.minHeight),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: tabs),
          ),
        );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: sefer.hairline, width: sefer.hairlineWidth),
        ),
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.maxWidth + 2 * AliyahRibbon._padding),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabs = [for (var a = 0; a < kAliyot; a++) _tab(context, a)];
              // A name may overhang its tab by a fraction of a pixel, which
              // its letters' side bearings hide.
              final shared = (constraints.maxWidth - 2 * AliyahRibbon._padding) / kAliyot;
              if (shared >= math.max(AliyahRibbon.minTabWidth, widest.floorToDouble())) {
                _scrolls = false;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AliyahRibbon._padding),
                  child: row([for (final t in tabs) Expanded(child: t)]),
                );
              }
              // Come to scroll (as the text grows), the open tab is shown.
              if (!_scrolls) _revealSelected(animate: false);
              _scrolls = true;
              final width = math.max(AliyahRibbon.scrollingTabWidth, widest.ceilToDouble() + 8);
              // Every tab is built, so that any of them can be revealed.
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AliyahRibbon._padding),
                child: row([for (final t in tabs) SizedBox(width: width, child: t)]),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, int a) {
    final l = context.l10n;
    final names = Names(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final week = widget.week;
    final selected = widget.selected == a;
    final name = names.aliyah(a);
    final passes = [for (final pass in ReadingPass.values) week.isUnitDone(a, pass)];
    final done = passes.where((d) => d).length;
    // A reading under way but none done is said as none done, as the pips
    // show it: "0 of 3 readings done".
    final state = done == passes.length
        ? l.tabRead
        : (week.isAliyahStarted(a, widget.aliyahVerses[a]) ? l.tabPartial(done) : l.tabNotStarted);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          HebrewText.gematria(a + 1, punctuate: false),
          style: SeferType.of(context).ordinal.copyWith(color: selected ? scheme.onSurface : scheme.onSurfaceVariant),
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 2),
        Text(
          name,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: _nameStyle(context, selected: selected),
        ),
        const SizedBox(height: 6),
        // Sized, so the ribbon's intrinsic height counts the pips.
        SizedBox(
          height: PassPips.mini,
          child: PassPips(size: PassPips.mini, states: [for (final d in passes) d ? PipState.done : PipState.pending]),
        ),
      ],
    );
    return Semantics(
      key: _tabKeys[a],
      container: true,
      button: true,
      selected: selected,
      label: '${l.aliyahTabLabel(name, a + 1)}, $state',
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Inset from the ribbon's edges, so that the focus ring, drawn
          // outside the ink well, is never clipped where the ribbon scrolls.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SeferInkWell(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              onTap: () => widget.onSelected(a),
              child: ExcludeSemantics(child: Center(child: content)),
            ),
          ),
          PositionedDirectional(
            start: 8,
            end: 8,
            bottom: 0,
            height: 3,
            child: AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: Motion.of(context).d(Motion.short),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: const BorderRadius.all(Radius.circular(1.5)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
