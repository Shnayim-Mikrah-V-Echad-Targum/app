import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/calendar/parsha_schedule.dart';
import '../../features/progress/domain/progress_models.dart';
import '../../features/progress/domain/streak_engine.dart';
import '../l10n.dart';
import '../theme/app_theme.dart';

/// Where one parsha of the year stands, as its segment of the [YearBar]
/// shows it.
enum YearSegment {
  /// Finished by its Shabbat.
  onTime,

  /// Finished late, or restored by doubling up.
  late,

  /// Made up later in the year.
  madeUp,

  /// This week's parsha, still being read.
  current,

  /// Anything else: still to come, missed, or before the reader joined.
  open,
}

/// The year at a glance (docs/DESIGN_SYSTEM.md §6.15): one segment for each
/// of the 54 parshiyot in Torah order, a wider gap between the books, and
/// each book's short name under its first segment.
///
/// It follows the reading direction, so in Hebrew Bereshit is on the right.
/// Screen readers hear one sentence: how many parshiyot are complete, and
/// which is being read now.
class YearBar extends StatelessWidget {
  const YearBar({super.key, required this.segments, this.currentName});

  /// The state of each parsha, from Bereshit to Vezot HaBerakhah.
  final List<YearSegment> segments;

  /// This week's parsha in the UI language, named to screen readers while
  /// it is [YearSegment.current].
  final String? currentName;

  static const double height = 8;
  static const double radius = 1.5;

  /// Between two segments.
  static const double gap = 2;

  /// Added to [gap] between two books.
  static const double bookGap = 4;

  /// The least space between two books' names.
  static const double labelGap = 4;

  /// The segments for [cycle]: how each week of it ended in [weeks], the
  /// parshiyot finished at any time ([done], as `parshiyotDoneInCycle` gives
  /// them), and the [current] portion.
  static List<YearSegment> segmentsFor({
    required Iterable<WeekEvaluation> weeks,
    required int cycle,
    required Set<int> done,
    required PortionId current,
  }) {
    final status = <int, WeekStatus>{};
    for (final e in weeks) {
      if (cycleYearOf(e.plan.portion, e.plan.week.occasion) != cycle) continue;
      for (final n in e.plan.portion.parshiyot) {
        status[n] = e.status;
      }
    }
    return [
      for (var n = 1; n <= kParshaCount; n++)
        switch (status[n]) {
          WeekStatus.onTime => YearSegment.onTime,
          WeekStatus.late || WeekStatus.restored => YearSegment.late,
          WeekStatus.madeUp => YearSegment.madeUp,
          _ when current.parshiyot.contains(n) => done.contains(n) ? YearSegment.onTime : YearSegment.current,
          _ when done.contains(n) => YearSegment.madeUp,
          _ => YearSegment.open,
        },
    ];
  }

  @override
  Widget build(BuildContext context) {
    assert(segments.length == kParshaCount, 'One segment for each parsha.');
    final l = context.l10n;
    final theme = Theme.of(context);
    final complete = segments.where((s) => s != YearSegment.current && s != YearSegment.open).length;
    final name = currentName;
    final books = [l.bookAbbrGenesis, l.bookAbbrExodus, l.bookAbbrLeviticus, l.bookAbbrNumbers, l.bookAbbrDeuteronomy];
    final abbreviation = theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: name != null && segments.contains(YearSegment.current)
          ? l.yearBarSemanticsCurrent(complete, kParshaCount, name)
          : l.yearBarSemantics(complete, kParshaCount),
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Segments of 6 where nothing sets the width.
            final width = constraints.hasBoundedWidth ? constraints.maxWidth : 446.0;
            final layout = _YearBarLayout(width);
            return SizedBox(
              width: width,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CustomPaint(
                    size: Size(width, height),
                    painter: _YearBarPainter(
                      segments: segments,
                      layout: layout,
                      direction: Directionality.of(context),
                      colors: _YearBarColors.of(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Each name starts at its book's first segment. If the text is
                  // very large, it shrinks rather than run into the next one.
                  Row(
                    children: [
                      for (var b = 0; b < books.length; b++)
                        SizedBox(
                          width: layout.bookWidth(b),
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(end: labelGap),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(books[b], style: abbreviation, maxLines: 1),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Where each segment falls, measured from the start edge.
class _YearBarLayout {
  factory _YearBarLayout(double width) {
    final books = bookIndexOfParsha(kParshaCount) + 1;
    final gaps = (kParshaCount - 1) * YearBar.gap + (books - 1) * YearBar.bookGap;
    var segment = (width - gaps) / kParshaCount;
    var scale = 1.0;
    if (segment < 1) {
      // Too narrow for the gaps: shrink them along with the segments.
      scale = width / (kParshaCount + gaps);
      segment = scale;
    }
    final starts = <double>[];
    final bookStarts = <double>[];
    var x = 0.0;
    for (var i = 0; i < kParshaCount; i++) {
      final book = bookIndexOfParsha(i + 1);
      if (i > 0) x += YearBar.gap * scale;
      if (i == 0 || book != bookIndexOfParsha(i)) {
        if (i > 0) x += YearBar.bookGap * scale;
        bookStarts.add(x);
      }
      starts.add(x);
      x += segment;
    }
    return _YearBarLayout._(width, segment, starts, bookStarts);
  }

  const _YearBarLayout._(this.width, this.segment, this.starts, this.bookStarts);

  final double width;
  final double segment;
  final List<double> starts;
  final List<double> bookStarts;

  /// From the start of book [b] to the start of the next (or the end).
  double bookWidth(int b) => (b + 1 < bookStarts.length ? bookStarts[b + 1] : width) - bookStarts[b];
}

class _YearBarColors {
  const _YearBarColors({
    required this.onTime,
    required this.late,
    required this.paper,
    required this.current,
    required this.currentBorder,
    required this.track,
  });

  factory _YearBarColors.of(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = StatusColors.of(context);
    final sefer = SeferColors.of(context);
    return _YearBarColors(
      onTime: status.done,
      late: status.late,
      paper: sefer.paper,
      current: scheme.primaryContainer,
      currentBorder: scheme.primary,
      track: sefer.ringTrack,
    );
  }

  final Color onTime;
  final Color late;
  final Color paper;
  final Color current;
  final Color currentBorder;
  final Color track;

  @override
  bool operator ==(Object other) =>
      other is _YearBarColors &&
      other.onTime == onTime &&
      other.late == late &&
      other.paper == paper &&
      other.current == current &&
      other.currentBorder == currentBorder &&
      other.track == track;

  @override
  int get hashCode => Object.hash(onTime, late, paper, current, currentBorder, track);
}

class _YearBarPainter extends CustomPainter {
  const _YearBarPainter({required this.segments, required this.layout, required this.direction, required this.colors});

  final List<YearSegment> segments;
  final _YearBarLayout layout;
  final TextDirection direction;
  final _YearBarColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint();
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < segments.length; i++) {
      final start = layout.starts[i];
      final left = direction == TextDirection.rtl ? size.width - start - layout.segment : start;
      final box = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 0, layout.segment, size.height),
        const Radius.circular(YearBar.radius),
      );
      final (Color body, Color? edge) = switch (segments[i]) {
        YearSegment.onTime => (colors.onTime, null),
        YearSegment.late => (colors.late, null),
        YearSegment.madeUp => (colors.paper, colors.late),
        YearSegment.current => (colors.current, colors.currentBorder),
        YearSegment.open => (colors.track, null),
      };
      canvas.drawRRect(box, fill..color = body);
      // A 1 px border inside the segment.
      if (edge != null) canvas.drawRRect(box.deflate(0.5), border..color = edge);
    }
  }

  @override
  bool shouldRepaint(_YearBarPainter old) =>
      old.layout.width != layout.width ||
      old.direction != direction ||
      old.colors != colors ||
      !listEquals(old.segments, segments);
}
