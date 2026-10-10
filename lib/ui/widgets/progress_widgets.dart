import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/calendar/jewish_holidays.dart';
import '../../core/calendar/local_date.dart';
import '../../core/text/hebrew_text.dart';
import '../../features/progress/domain/progress_models.dart';
import '../../features/progress/domain/reading_plan.dart';
import '../../features/progress/domain/streak_engine.dart';
import '../l10n.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// The geometry of the parsha rings at one size (docs/DESIGN_SYSTEM.md
/// §6.11): three strokes of `size × 0.055`, 1.6 strokes apart.
@immutable
class RingGeometry {
  factory RingGeometry(double size) {
    final stroke = size * 0.055;
    final r0 = size / 2 - stroke / 2;
    return RingGeometry._(stroke, [r0, r0 - 1.6 * stroke, r0 - 3.2 * stroke]);
  }

  const RingGeometry._(this.stroke, this.radii);

  final double stroke;

  /// The radius of each ring's centre line: first reading (outermost),
  /// second reading, Targum.
  final List<double> radii;

  /// The diameter of the hole inside the Targum ring: 56 at size 104.
  double get hole => 2 * (radii.last - stroke / 2);
}

/// The angle the rings start from: 12 o'clock.
const double kRingStart = -math.pi / 2;

/// The gap between two aliyot's arcs, in radians.
const double kRingGap = 0.042;

/// One done stretch of a ring, in radians clockwise from 3 o'clock, as
/// [Canvas.drawArc] takes it.
@immutable
class RingArc {
  const RingArc(this.ring, this.start, this.sweep);

  /// 0 for the first reading, 1 for the second, 2 for the Targum.
  final int ring;
  final double start;
  final double sweep;

  @override
  bool operator ==(Object other) => other is RingArc && other.ring == ring && other.start == start && other.sweep == sweep;

  @override
  int get hashCode => Object.hash(ring, start, sweep);

  @override
  String toString() => 'RingArc($ring, ${start.toStringAsFixed(3)}, ${sweep.toStringAsFixed(3)})';
}

/// The bit of one unit (reading [ring] of [aliyah]) in a [ringMask].
int _unit(int ring, int aliyah) => 1 << (ring * kAliyot + aliyah);

/// The done units of [progress] as bits, one per unit: bit
/// `pass.index * kAliyot + aliyah`.
int ringMask(WeekProgress progress) {
  var mask = 0;
  for (final pass in ReadingPass.values) {
    for (var a = 0; a < kAliyot; a++) {
      if (progress.isUnitDone(a, pass)) mask |= _unit(pass.index, a);
    }
  }
  return mask;
}

/// The aliyot whose three readings are all done in [mask].
int _aliyotDone(int mask) {
  var n = 0;
  for (var a = 0; a < kAliyot; a++) {
    if (ReadingPass.values.every((p) => mask & _unit(p.index, a) != 0)) n++;
  }
  return n;
}

/// The arcs to draw in each ring's colour, for done units [from] sweeping
/// to done units [to] (masks as [ringMask] makes them), [t] of the way.
///
/// Each aliyah's arc is sized by its share of [weights] (verse counts).
/// In each ring, a head travels clockwise from the start of the first arc
/// that changes to the end of the last one: arcs being finished fill in
/// behind it, and arcs being cleared empty behind it. Arcs that don't
/// change are drawn as they are. Clockwise in both directions of text: a
/// ring is not text, and the same progress looks the same in every language.
List<RingArc> ringArcs({required List<int> weights, required int from, required int to, double t = 1}) {
  final total = weights.fold<int>(0, (a, b) => a + b);
  // Each aliyah's arc, less half the gap at each end.
  final spans = <(double, double)>[];
  var at = kRingStart;
  for (final w in weights) {
    final share = 2 * math.pi * (total > 0 ? w / total : 1 / weights.length);
    spans.add((at + kRingGap / 2, at + kRingGap / 2 + math.max(0.001, share - kRingGap)));
    at += share;
  }
  bool done(int mask, int ring, int a) => mask & _unit(ring, a) != 0;

  final arcs = <RingArc>[];
  for (var ring = 0; ring < 3; ring++) {
    final changed = [
      for (var a = 0; a < spans.length; a++)
        if (done(from, ring, a) != done(to, ring, a)) a,
    ];
    final head = changed.isEmpty || t >= 1 ? null : lerpDouble(spans[changed.first].$1, spans[changed.last].$2, t)!;
    for (var a = 0; a < spans.length; a++) {
      final (start, end) = spans[a];
      final was = done(from, ring, a);
      final now = done(to, ring, a);
      var (s, e) = (start, end);
      if (head != null && was != now) {
        // Finishing: done up to the head. Clearing: done only past it.
        (s, e) = now ? (start, math.min(head, end)) : (math.max(head, start), end);
      } else if (!now) {
        continue;
      }
      if (e > s) arcs.add(RingArc(ring, s, e - s));
    }
  }
  return arcs;
}

/// Three concentric rings: first reading (outermost), second reading,
/// Targum (docs/DESIGN_SYSTEM.md §6.11). Each is made of seven arcs, one
/// per aliyah, sized by verse count, and drawn over a full track. At
/// [header] size and up, the centre counts the finished aliyot ("2/7").
///
/// Put a [RingLegend] beside or under rings of [header] size or more
/// ([RingsWithLegend] does both): only the legend says which ring is which.
///
/// The rings remember, for this run of the app, what they last showed for
/// each week. When a unit has been finished since, the next time they are
/// shown the arcs sweep from the old progress to the new over [Motion.ring]
/// and the centre count cross-fades. Once; nothing loops.
class ParshaRings extends StatefulWidget {
  const ParshaRings({
    super.key,
    required this.progress,
    required this.aliyahWeights,
    this.size = hero,
    this.thirdLabel,
  });

  /// The three sizes: the Today hero, the Parsha header and compact rows.
  static const double hero = 104;
  static const double header = 88;
  static const double compact = 40;

  final WeekProgress progress;

  /// Relative length of each aliyah (verse counts).
  final List<int> aliyahWeights;
  final double size;

  /// Name of the third reading, if not "Targum" (e.g. "Rashi").
  final String? thirdLabel;

  /// Forgets what the rings last showed, as if the app had restarted.
  @visibleForTesting
  static void forgetShown() => _ParshaRingsState._shown.clear();

  @override
  State<ParshaRings> createState() => _ParshaRingsState();
}

class _ParshaRingsState extends State<ParshaRings> with SingleTickerProviderStateMixin {
  /// What the rings of each week last showed, by week id. In memory only:
  /// a restarted app shows progress as it is, without a sweep.
  static final _shown = <String, int>{};

  late final AnimationController _controller = AnimationController(vsync: this, value: 1);
  late final Animation<double> _sweep = CurvedAnimation(parent: _controller, curve: Motion.decelerate);

  /// The sweep runs from [_from] to [_to] (masks, as [ringMask] makes them).
  late int _from;
  late int _to;

  /// Whether [_to] has yet to be shown: set while the rings are hidden (a
  /// route covers them, or their tab is in the background), so the sweep
  /// waits until they can be seen.
  bool _pending = true;

  String get _week => widget.progress.weekId;

  @override
  void initState() {
    super.initState();
    _to = ringMask(widget.progress);
    _from = _shown[_week] ?? _to;
    if (_from != _to) _controller.value = 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _showIfVisible();
  }

  @override
  void didUpdateWidget(ParshaRings old) {
    super.didUpdateWidget(old);
    final to = ringMask(widget.progress);
    if (old.progress.weekId != _week) {
      // Another week in the same place sweeps from what it last showed.
      _from = _shown[_week] ?? to;
    } else if (to != _to) {
      // A sweep still running ends where it was going, and the next starts
      // from there. One not yet shown still starts from what was last seen.
      if (!_pending) _from = _to;
    } else {
      return;
    }
    _to = to;
    _pending = true;
    _controller.value = _from == _to ? 1 : 0;
    _showIfVisible();
  }

  void _showIfVisible() {
    if (!_pending || !TickerMode.valuesOf(context).enabled) return;
    _pending = false;
    _shown[_week] = _to;
    if (_controller.value < 1) {
      _controller
        ..duration = Motion.of(context).d(Motion.ring)
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sefer = SeferColors.of(context);
    // "2 of 7 aliyot. First reading: 3 of 7. …", the legend in words.
    final label = [
      l.aliyotProgress(widget.progress.completedAliyot, kAliyot),
      for (final e in _legendEntries(context, widget.progress, widget.thirdLabel))
        '${e.label}: ${l.countOfTotal(e.done, kAliyot)}',
    ].join('. ');
    return Semantics(
      // An item of its own, never merged into a card, a row, or a heading or
      // text beside it.
      container: true,
      label: label,
      image: true,
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: CustomPaint(
            painter: _RingsPainter(
              weights: widget.aliyahWeights,
              from: _from,
              to: _to,
              sweep: _sweep,
              colors: [sefer.ringMikra1, sefer.ringMikra2, sefer.ringTargum],
              track: sefer.ringTrack,
            ),
            child: widget.size >= ParshaRings.header ? ExcludeSemantics(child: _centre(context)) : null,
          ),
        ),
      ),
    );
  }

  /// "2/7" over "aliyot", scaled down to fit inside the Targum ring. The
  /// legend beside the rings carries the counts at full size.
  Widget _centre(BuildContext context) {
    final theme = Theme.of(context);
    final duration = Motion.of(context).d(Motion.short);
    // The square inscribed in the round hole, with a little clearance: any
    // larger, and its corners (where "aliyot" sits) would cross the ring.
    final box = RingGeometry(widget.size).hole / math.sqrt2 * 0.95;
    return Center(
      child: SizedBox.square(
        dimension: box,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  // The old count until the sweep sets off.
                  final n = _aliyotDone(_controller.value > 0 ? _to : _from);
                  return AnimatedSwitcher(
                    // Another week in the same place is not a change to fade.
                    key: ValueKey(_week),
                    duration: duration,
                    child: Text(
                      '$n/$kAliyot',
                      key: ValueKey(n),
                      style: SeferType.of(context).ringNumeral,
                      textDirection: TextDirection.ltr,
                    ),
                  );
                },
              ),
              Text(
                context.l10n.aliyotWord,
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({
    required this.weights,
    required this.from,
    required this.to,
    required this.sweep,
    required this.colors,
    required this.track,
  }) : super(repaint: sweep);

  final List<int> weights;
  final int from;
  final int to;
  final Animation<double> sweep;
  final List<Color> colors;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = RingGeometry(size.shortestSide);
    final centre = size.center(Offset.zero);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = geometry.stroke
      ..strokeCap = StrokeCap.butt;
    // Each track is one full circle, under its done arcs.
    paint.color = track;
    for (final r in geometry.radii) {
      canvas.drawCircle(centre, r, paint);
    }
    for (final arc in ringArcs(weights: weights, from: from, to: to, t: sweep.value)) {
      paint.color = colors[arc.ring];
      canvas.drawArc(Rect.fromCircle(center: centre, radius: geometry.radii[arc.ring]), arc.start, arc.sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.from != from ||
      old.to != to ||
      old.sweep != sweep ||
      old.track != track ||
      !listEquals(old.colors, colors) ||
      !listEquals(old.weights, weights);
}

/// One reading in the legend: its ring's colour, its name, and how many
/// aliyot it has covered.
typedef _LegendEntry = ({Color color, String label, int done});

List<_LegendEntry> _legendEntries(BuildContext context, WeekProgress progress, String? thirdLabel) {
  final l = context.l10n;
  final sefer = SeferColors.of(context);
  int count(ReadingPass p) => [for (var a = 0; a < kAliyot; a++) a].where((a) => progress.isUnitDone(a, p)).length;
  return [
    (color: sefer.ringMikra1, label: l.passMikra1, done: count(ReadingPass.mikra1)),
    (color: sefer.ringMikra2, label: l.passMikra2, done: count(ReadingPass.mikra2)),
    (color: sefer.ringTargum, label: thirdLabel ?? l.passTargum, done: count(ReadingPass.targum)),
  ];
}

/// Which ring is which (docs/DESIGN_SYSTEM.md §6.11): for each reading, a
/// dot in its ring's colour, its name, and how many of the seven aliyot it
/// has covered ("3 of 7"). Hidden from screen readers, since the rings'
/// own label says all of it.
class RingLegend extends StatelessWidget {
  const RingLegend({super.key, required this.progress, this.thirdLabel});

  final WeekProgress progress;

  /// Name of the third reading, if not "Targum" (e.g. "Rashi").
  final String? thirdLabel;

  static const double _dot = 9;
  static const double _dotGap = 10;
  static const double _countGap = 12;

  static TextStyle? _labelStyle(BuildContext context) => Theme.of(context).textTheme.bodyMedium;

  static TextStyle? _countStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// The width the legend needs to set each row on one line, at the
  /// current text size.
  static double naturalWidth(BuildContext context, WeekProgress progress, {String? thirdLabel}) =>
      _width(context, progress, thirdLabel: thirdLabel, split: false);

  /// The width the legend needs with each count under its name.
  static double splitWidth(BuildContext context, WeekProgress progress, {String? thirdLabel}) =>
      _width(context, progress, thirdLabel: thirdLabel, split: true);

  static double _width(BuildContext context, WeekProgress progress, {String? thirdLabel, required bool split}) {
    final l = context.l10n;
    final bold = MediaQuery.boldTextOf(context) ? const TextStyle(fontWeight: FontWeight.bold) : null;
    double measure(String text, TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style?.merge(bold) ?? bold),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final entries = _legendEntries(context, progress, thirdLabel);
    final label = entries.map((e) => measure(e.label, _labelStyle(context))).reduce(math.max);
    final count = entries.map((e) => measure(l.countOfTotal(e.done, kAliyot), _countStyle(context))).reduce(math.max);
    final text = split ? math.max(label, count) : label + _countGap + count;
    return (_dot + _dotGap + text).ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final labelStyle = _labelStyle(context);
    final countStyle = _countStyle(context);
    // One line of a name, for the dot to sit beside the first.
    final line = MediaQuery.textScalerOf(context).scale(labelStyle?.fontSize ?? 15) * (labelStyle?.height ?? 1.5);
    final natural = naturalWidth(context, progress, thirdLabel: thirdLabel);
    final entries = _legendEntries(context, progress, thirdLabel);
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // With large text in a small space, each count goes under its
          // name rather than squeezing it.
          final split = constraints.maxWidth < natural;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final e in entries)
                Container(
                  constraints: const BoxConstraints(minHeight: 24),
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: line,
                        child: Center(
                          child: SizedBox.square(
                            dimension: _dot,
                            child: DecoratedBox(decoration: BoxDecoration(color: e.color, shape: BoxShape.circle)),
                          ),
                        ),
                      ),
                      const SizedBox(width: _dotGap),
                      if (split)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.label, style: labelStyle),
                              Text(l.countOfTotal(e.done, kAliyot), style: countStyle),
                            ],
                          ),
                        )
                      else ...[
                        Expanded(child: Text(e.label, style: labelStyle)),
                        const SizedBox(width: _countGap),
                        Text(l.countOfTotal(e.done, kAliyot), style: countStyle),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// [ParshaRings] with their [RingLegend] (docs/DESIGN_SYSTEM.md §6.11): side
/// by side wherever the legend fits beside the rings, each count under its
/// name if the two can't share a line (as on a 360 dp phone); otherwise the
/// rings centred above the legend (on a narrower phone, or with large text).
class RingsWithLegend extends StatelessWidget {
  const RingsWithLegend({
    super.key,
    required this.progress,
    required this.aliyahWeights,
    this.size = ParshaRings.hero,
    this.thirdLabel,
  }) : assert(size >= ParshaRings.header, 'Compact rings have no legend.');

  final WeekProgress progress;
  final List<int> aliyahWeights;
  final double size;
  final String? thirdLabel;

  /// Between the rings and the legend beside them.
  static const double gap = 20;

  /// Between the rings and the legend under them.
  static const double stackedGap = 16;

  /// The most the legend beside the rings grows past its natural width.
  static const double maxSlack = 40;

  @override
  Widget build(BuildContext context) {
    final rings = ParshaRings(progress: progress, aliyahWeights: aliyahWeights, size: size, thirdLabel: thirdLabel);
    final legend = RingLegend(progress: progress, thirdLabel: thirdLabel);
    final natural = RingLegend.naturalWidth(context, progress, thirdLabel: thirdLabel);
    final split = RingLegend.splitWidth(context, progress, thirdLabel: thirdLabel);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= size + gap + split) {
          return Row(
            children: [
              rings,
              const SizedBox(width: gap),
              // On a wide card the counts stay near their names.
              Flexible(
                child: ConstrainedBox(constraints: BoxConstraints(maxWidth: natural + maxSlack), child: legend),
              ),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            rings,
            const SizedBox(height: stackedGap),
            ConstrainedBox(constraints: BoxConstraints(maxWidth: natural), child: legend),
          ],
        );
      },
    );
  }
}

/// Two Shabbat candles, the rest-day symbol (docs/DESIGN_SYSTEM.md §7.6),
/// drawn on a 24 grid and scaled to [size]. In the rest colour unless given
/// another.
class ShabbatCandlesIcon extends StatelessWidget {
  const ShabbatCandlesIcon({super.key, this.size = 24, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _CandlesPainter(
            color ??
                Theme.of(context).extension<StatusColors>()?.rest ??
                IconTheme.of(context).color ??
                Theme.of(context).colorScheme.onSurface,
          ),
        ),
      );
}

class _CandlesPainter extends CustomPainter {
  _CandlesPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color;
    canvas
      ..save()
      ..scale(s.width / 24, s.height / 24);
    // Each body is 3.5 wide, with its flame centred over it.
    for (final x in [6.5, 14.0]) {
      final cx = x + 1.75;
      canvas
        ..drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 11, 3.5, 10), const Radius.circular(0.8)), p)
        ..drawPath(
          Path()
            ..moveTo(cx, 3)
            ..cubicTo(cx + 2.6, 5.6, cx + 2.2, 9.5, cx, 9.5)
            ..cubicTo(cx - 2.2, 9.5, cx - 2.6, 5.6, cx, 3)
            ..close(),
          p,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CandlesPainter old) => old.color != color;
}

/// Visual and textual description of a day in the week strip.
enum DayDisplay { kept, ahead, caughtUp, grace, paused, open, missed, rest, upcoming, noReading, today }

DayDisplay dayDisplayFor({
  required LocalDate date,
  required LocalDate today,
  required DayStatus? status,
  required bool rest,
  required bool planned,
  LocalDate? joinDate,
}) {
  if (rest) return DayDisplay.rest;
  if (joinDate != null && date < joinDate) return DayDisplay.noReading;
  if (status != null) {
    return switch (status) {
      DayStatus.kept => DayDisplay.kept,
      DayStatus.ahead => DayDisplay.ahead,
      DayStatus.caughtUp => DayDisplay.caughtUp,
      DayStatus.grace => DayDisplay.grace,
      DayStatus.paused => DayDisplay.paused,
      DayStatus.open => date == today ? DayDisplay.today : DayDisplay.open,
      DayStatus.missed => DayDisplay.missed,
    };
  }
  if (!planned) return DayDisplay.noReading;
  if (date > today) return DayDisplay.upcoming;
  return date == today ? DayDisplay.today : DayDisplay.open;
}

extension DayDisplayX on DayDisplay {
  String label(BuildContext context) {
    final l = context.l10n;
    return switch (this) {
      DayDisplay.kept => l.dayKept,
      DayDisplay.ahead => l.dayAhead,
      DayDisplay.caughtUp => l.dayCaughtUp,
      DayDisplay.grace => l.dayGrace,
      DayDisplay.paused => l.dayPaused,
      DayDisplay.open || DayDisplay.today => l.dayOpen,
      DayDisplay.missed => l.dayMissed,
      DayDisplay.rest => l.dayRest,
      DayDisplay.upcoming => l.dayUpcoming,
      DayDisplay.noReading => l.dayNoReading,
    };
  }

  /// The day's glyph in the week strip (docs/DESIGN_SYSTEM.md §6.13), [size]
  /// square: a filled disc for a day that counts, a ring and dot for today,
  /// outlines for days still open or to come, the candles for a rest day.
  Widget icon(BuildContext context, {double size = 22}) {
    final scheme = Theme.of(context).colorScheme;
    final status = StatusColors.of(context);
    return switch (this) {
      DayDisplay.kept => _DayDisc(Icons.check, size: size),
      DayDisplay.ahead => _DayDisc(Icons.fast_forward_rounded, size: size),
      DayDisplay.caughtUp => _DayDisc(Icons.published_with_changes, size: size),
      DayDisplay.grace => Icon(Icons.shield_outlined, size: size, color: status.grace),
      DayDisplay.paused => Icon(Icons.pause_circle_outline, size: size, color: scheme.onSurfaceVariant),
      DayDisplay.open => Icon(Icons.radio_button_unchecked, size: size, color: scheme.onSurfaceVariant),
      DayDisplay.today => TodayMark(size: size),
      DayDisplay.missed => Icon(Icons.remove_circle_outline, size: size, color: status.neutral),
      DayDisplay.rest => ShabbatCandlesIcon(size: size, color: status.rest),
      DayDisplay.upcoming => Icon(Icons.circle_outlined, size: size, color: scheme.outline),
      DayDisplay.noReading => Icon(Icons.horizontal_rule, size: size, color: scheme.outline),
    };
  }
}

/// A day that counts: at the default size, a 20 px disc in the done colour
/// with a 14 px [glyph] in onDone.
class _DayDisc extends StatelessWidget {
  const _DayDisc(this.glyph, {required this.size});

  final IconData glyph;
  final double size;

  @override
  Widget build(BuildContext context) {
    final status = StatusColors.of(context);
    final disc = size * 20 / 22;
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: Container(
          width: disc,
          height: disc,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: status.done, shape: BoxShape.circle),
          child: Icon(glyph, size: size * 14 / 22, color: status.onDone),
        ),
      ),
    );
  }
}

/// Today, not yet read: a 2 px ring in primary around an 8 px dot, on a 22
/// grid scaled to [size].
class TodayMark extends StatelessWidget {
  const TodayMark({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _TodayMarkPainter(Theme.of(context).colorScheme.primary)),
      );
}

class _TodayMarkPainter extends CustomPainter {
  _TodayMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / 22;
    final centre = size.center(Offset.zero);
    // The ring is 20 across, as wide as a kept day's disc.
    canvas
      ..drawCircle(
        centre,
        9 * unit,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * unit
          ..color = color,
      )
      ..drawCircle(centre, 4 * unit, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TodayMarkPainter old) => old.color != color;
}

/// The aliyot planned for a day as the week strip prints them, in Hebrew
/// ordinals: "א", "ד·ה" for two, "א–ז" for a run of three or more.
String aliyahOrdinals(List<int> aliyot) {
  final sorted = [...aliyot]..sort();
  final letters = [for (final a in sorted) HebrewText.gematria(a + 1, punctuate: false)];
  if (sorted.length > 2 && sorted.last - sorted.first == sorted.length - 1) return '${letters.first}–${letters.last}';
  return letters.join('·');
}

const _dayRadius = BorderRadius.all(Radius.circular(10));

/// Sunday through Shabbat of a week, with each day's plan and status
/// (docs/DESIGN_SYSTEM.md §6.13): the weekday, a glyph for how the day went,
/// and the aliyot planned for it in Hebrew ordinals. Today is filled in the
/// primary container colour and edged in primary; Shabbat and Yom Tov are
/// washed in the rest colour.
///
/// Where seven days would each be narrower than [minDayWidth] (or than the
/// weekday names at the current text size), the week takes two rows: Sunday
/// to Wednesday, then Thursday to Shabbat.
///
/// [WeekStripLegendButton] explains the glyphs.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.plan,
    required this.today,
    required this.statuses,
    required this.oneDayYomTov,
    this.onDayTap,
    this.joinDate,
  });

  final WeekPlan plan;
  final LocalDate today;
  final Map<LocalDate, DayStatus> statuses;

  /// The reader's custom for Yom Tov, which decides the rest days shown.
  final bool oneDayYomTov;
  final LocalDate? joinDate;
  final void Function(PlanDay day)? onDayTap;

  /// The narrowest a day may be, margins included: a 48 dp target.
  static const double minDayWidth = 48;

  /// The padding of a card around the strip: tighter than a card's usual
  /// 20, so the days stay in one row on more phones.
  static const cardPadding = EdgeInsets.all(8);

  static const double _margin = 2;
  static const double _inset = 2;

  @override
  Widget build(BuildContext context) {
    final end = plan.week.occasion.isShabbat ? plan.week.occasion : plan.week.occasion.onOrAfter(6);
    final days = [for (var i = 6; i >= 0; i--) end.addDays(-i)];
    final cells = [for (final d in days) _day(context, d)];
    return Semantics(
      label: context.l10n.weekStripLabel,
      container: true,
      explicitChildNodes: true,
      // The filled days are ink, so their ripples show; this keeps it moving
      // with them wherever the strip scrolls.
      child: Material(
        type: MaterialType.transparency,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth / 7 >= _dayWidthNeeded(context, days)) return _row(cells);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _row(cells.sublist(0, 4)),
                const SizedBox(height: 2 * _margin),
                // Thursday under Sunday, and Shabbat under Tuesday.
                _row([...cells.sublist(4), const SizedBox.shrink()]),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The width each day needs to set its weekday on one line, margins
  /// included, and never less than [minDayWidth].
  double _dayWidthNeeded(BuildContext context, List<LocalDate> days) {
    final names = Names(context);
    // Today's is bold; measure every name as if it were.
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700);
    var widest = 0.0;
    for (final d in days) {
      final painter = TextPainter(
        text: TextSpan(text: names.weekdayShort(d), style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    return math.max(minDayWidth, widest.ceilToDouble() + 2 * (_inset + _margin));
  }

  /// Days side by side, all as tall as the tallest.
  static Widget _row(List<Widget> cells) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final c in cells) Expanded(child: c)],
        ),
      );

  Widget _day(BuildContext context, LocalDate d) {
    final l = context.l10n;
    final names = Names(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final planned = plan.dayFor(d);
    final rest = JewishHolidays.isRestDay(d, israel: oneDayYomTov);
    final display = dayDisplayFor(
      date: d,
      today: today,
      status: statuses[d],
      rest: rest,
      planned: planned != null,
      joinDate: joinDate,
    );
    // The aliyot planned for the day, Shabbat morning's included; none on a
    // day before the reader joined.
    final dayAliyot = display == DayDisplay.noReading
        ? const <int>[]
        : planned?.aliyot ?? (d == plan.week.occasion ? plan.shabbatAliyot : const <int>[]);
    final isToday = d == today;
    final semantic = [
      l.dayChipLabel(names.weekday(d), display.label(context)),
      if (dayAliyot.isNotEmpty) names.aliyot(dayAliyot),
    ].join('. ');
    // Under the glyph, those aliyot as ordinals; on a Yom Tov that is not
    // Shabbat, that it is one, so Simchat Torah is not taken for Shabbat.
    final yomTov = rest && !d.isShabbat;
    final note = yomTov ? l.yomTovShort : (dayAliyot.isEmpty ? null : aliyahOrdinals(dayAliyot));
    final noteStyle = theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);
    final content = Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(vertical: 8),
      // A foreground border, so today's content sits exactly where the
      // other days' does.
      foregroundDecoration: isToday
          ? BoxDecoration(borderRadius: _dayRadius, border: Border.all(color: scheme.primary, width: 1.5))
          : null,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _inset),
            child: Text(
              names.weekdayShort(d),
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isToday ? scheme.onSurface : scheme.onSurfaceVariant,
                fontWeight: isToday ? FontWeight.w700 : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // A day that changes state cross-fades to its new glyph; nothing
          // grows or bounces.
          AnimatedSwitcher(
            duration: Motion.of(context).d(Motion.medium),
            child: KeyedSubtree(key: ValueKey(display), child: display.icon(context)),
          ),
          if (note != null) ...[
            const SizedBox(height: 4),
            if (yomTov)
              // One line across the day, untracked and shrunk a little if
              // need be ("Yom Tov" is about 50 px; a day on a 412 dp phone
              // has 48), so a Yom Tov week is no taller than any other. The
              // inset keeps it off the edges of the wash.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _inset),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(note, maxLines: 1, softWrap: false, style: noteStyle?.copyWith(letterSpacing: 0)),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _inset),
                child: Text(
                  note,
                  textAlign: TextAlign.center,
                  // Ordinals read right to left in either UI.
                  textDirection: TextDirection.rtl,
                  style: noteStyle,
                ),
              ),
          ],
        ],
      ),
    );
    final fill = rest ? SeferColors.of(context).restWash : (isToday ? scheme.primaryContainer : null);
    final interactive = planned != null && onDayTap != null;
    void tap() => onDayTap!(planned!);
    final body = interactive
        ? SeferInkWell(borderRadius: _dayRadius, onTap: tap, child: ExcludeSemantics(child: content))
        : ExcludeSemantics(child: content);
    Widget day = Padding(
      // Outside the ink well, so its focus ring hugs the day.
      padding: const EdgeInsets.symmetric(horizontal: _margin),
      child: Tooltip(
        message: semantic,
        excludeFromSemantics: true,
        child: fill == null ? body : Ink(decoration: BoxDecoration(color: fill, borderRadius: _dayRadius), child: body),
      ),
    );
    // The margins answer a tap too, so the whole slot, at least 48 dp, is
    // the target a finger has (the ink well's own taps win inside it).
    if (interactive) {
      day = GestureDetector(behavior: HitTestBehavior.opaque, excludeFromSemantics: true, onTap: tap, child: day);
    }
    // One node per day, the size of its slot (margins and all), carrying the
    // ink well's tap and focus.
    return Semantics(container: true, button: interactive, label: semantic, child: day);
  }
}

/// An info button for the header of a card that holds a [WeekStrip]. It
/// opens a sheet naming each of the strip's glyphs.
class WeekStripLegendButton extends StatelessWidget {
  const WeekStripLegendButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        icon: const Icon(Icons.info_outline),
        tooltip: context.l10n.statusLegend,
        onPressed: () => showWeekStripLegend(context),
      );
}

/// Shows what each glyph in a [WeekStrip] means.
Future<void> showWeekStripLegend(BuildContext context) => showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _WeekStripLegend(),
    );

class _WeekStripLegend extends StatelessWidget {
  const _WeekStripLegend();

  /// Roughly in the order a week fills in.
  static const _order = [
    DayDisplay.today,
    DayDisplay.kept,
    DayDisplay.ahead,
    DayDisplay.caughtUp,
    DayDisplay.grace,
    DayDisplay.open,
    DayDisplay.missed,
    DayDisplay.paused,
    DayDisplay.upcoming,
    DayDisplay.noReading,
    DayDisplay.rest,
  ];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final padding = sheetPadding(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle(l.statusLegend),
            for (final d in _order)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: padding, vertical: 6),
                child: Row(
                  children: [
                    // Today and rest days with their fills, as the strip
                    // shows them.
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: switch (d) {
                        DayDisplay.today => BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: _dayRadius,
                            border: Border.all(color: scheme.primary, width: 1.5),
                          ),
                        DayDisplay.rest =>
                          BoxDecoration(color: SeferColors.of(context).restWash, borderRadius: _dayRadius),
                        _ => null,
                      },
                      child: d.icon(context),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        d == DayDisplay.today ? l.dayToday : d.label(context),
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Icon + label for a week's status. Never uses red; always has a label.
class WeekStatusBadge extends StatelessWidget {
  const WeekStatusBadge(this.status, {super.key, this.dense = false});

  final WeekStatus status;
  final bool dense;

  static String label(BuildContext context, WeekStatus s) {
    final l = context.l10n;
    return switch (s) {
      WeekStatus.onTime => l.weekOnTime,
      WeekStatus.late => l.weekLate,
      WeekStatus.restored => l.weekRestored,
      WeekStatus.madeUp => l.weekMadeUp,
      WeekStatus.missed => l.weekMissed,
      WeekStatus.transparent => l.weekTransparent,
      WeekStatus.overdue => l.weekOverdue,
      WeekStatus.inProgress => l.weekInProgress,
    };
  }

  static IconData icon(WeekStatus s) => switch (s) {
        WeekStatus.onTime => Icons.check_circle,
        WeekStatus.late => Icons.check_circle_outline,
        WeekStatus.restored => Icons.done_all,
        WeekStatus.madeUp => Icons.history,
        WeekStatus.missed => Icons.radio_button_unchecked,
        WeekStatus.transparent => Icons.pause_circle_outline,
        WeekStatus.overdue => Icons.schedule,
        WeekStatus.inProgress => Icons.timelapse,
      };

  static Color color(BuildContext context, WeekStatus s) {
    final c = StatusColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    // §3.4 and §6.14: restored is finished late too, so it takes the late
    // colour; only a week finished on time is in the done colour.
    return switch (s) {
      WeekStatus.onTime => c.done,
      WeekStatus.late || WeekStatus.restored || WeekStatus.madeUp => c.late,
      WeekStatus.overdue => c.overdue,
      WeekStatus.missed || WeekStatus.transparent => c.neutral,
      WeekStatus.inProgress => scheme.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final text = label(context, status);
    final color = WeekStatusBadge.color(context, status);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon(status), size: dense ? 16 : 20, color: color),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: Theme.of(context).textTheme.labelMedium)),
      ],
    );
  }
}
