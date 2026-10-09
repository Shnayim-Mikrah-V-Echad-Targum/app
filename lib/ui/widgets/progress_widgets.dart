import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/calendar/jewish_holidays.dart';
import '../../core/calendar/local_date.dart';
import '../../features/progress/domain/progress_models.dart';
import '../../features/progress/domain/reading_plan.dart';
import '../../features/progress/domain/streak_engine.dart';
import '../l10n.dart';
import '../theme/app_theme.dart';

/// Three concentric rings — first reading, second reading, Targum — each
/// made of seven arcs (one per aliyah) sized by verse count.
class ParshaRings extends StatelessWidget {
  const ParshaRings({
    super.key,
    required this.progress,
    required this.aliyahWeights,
    this.size = 120,
    this.center,
    this.secondLabel,
  });

  final WeekProgress progress;

  /// Relative length of each aliyah (verse counts).
  final List<int> aliyahWeights;
  final double size;
  final Widget? center;

  /// Name of the third reading ("Targum" or "Rashi").
  final String? secondLabel;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final sefer = SeferColors.of(context);
    int count(ReadingPass p) => [for (var a = 0; a < kAliyot; a++) a].where((a) => progress.isUnitDone(a, p)).length;
    final label = [
      l.aliyotProgress(progress.completedAliyot, kAliyot),
      '${l.passMikra1}: ${count(ReadingPass.mikra1)}/7',
      '${l.passMikra2}: ${count(ReadingPass.mikra2)}/7',
      '${secondLabel ?? l.passTargum}: ${count(ReadingPass.targum)}/7',
    ].join('. ');
    return Semantics(
      label: label,
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingsPainter(
            progress: progress,
            weights: aliyahWeights,
            done: [sefer.ringMikra1, sefer.ringMikra2, sefer.ringTargum],
            track: sefer.ringTrack,
            gapColor: scheme.surface,
          ),
          child: center == null ? null : Center(child: ExcludeSemantics(child: center!)),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({required this.progress, required this.weights, required this.done, required this.track, required this.gapColor});

  final WeekProgress progress;
  final List<int> weights;
  final List<Color> done;
  final Color track;
  final Color gapColor;

  @override
  void paint(Canvas canvas, Size size) {
    final total = weights.fold<int>(0, (a, b) => a + b).toDouble();
    final stroke = size.width * 0.075;
    const gap = 0.025; // radians between aliyot
    for (var ring = 0; ring < 3; ring++) {
      final radius = size.width / 2 - stroke / 2 - ring * (stroke + stroke * 0.35);
      final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: radius);
      var start = -math.pi / 2;
      for (var a = 0; a < weights.length; a++) {
        final sweep = 2 * math.pi * weights[a] / total;
        final isDone = progress.isUnitDone(a, ReadingPass.values[ring]);
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt
          ..color = isDone ? done[ring] : track;
        canvas.drawArc(rect, start + gap / 2, math.max(0.001, sweep - gap), false, paint);
        start += sweep;
      }
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.progress != progress || old.done != done || old.track != track || old.weights != weights;
}

/// Two Shabbat candles, drawn so there's an unmistakable rest-day symbol.
class ShabbatCandlesIcon extends StatelessWidget {
  const ShabbatCandlesIcon({super.key, this.size = 24, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _CandlesPainter(color ?? IconTheme.of(context).color ?? Colors.black)),
      );
}

class _CandlesPainter extends CustomPainter {
  _CandlesPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color;
    final w = s.width;
    for (final cx in [w * 0.32, w * 0.68]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(cx - w * 0.08, s.height * 0.42, w * 0.16, s.height * 0.5), Radius.circular(w * 0.03)),
        p,
      );
      final flame = Path()
        ..moveTo(cx, s.height * 0.08)
        ..quadraticBezierTo(cx + w * 0.11, s.height * 0.24, cx, s.height * 0.36)
        ..quadraticBezierTo(cx - w * 0.11, s.height * 0.24, cx, s.height * 0.08)
        ..close();
      canvas.drawPath(flame, p);
    }
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

  Widget icon(BuildContext context, {double size = 22}) {
    final scheme = Theme.of(context).colorScheme;
    final status = StatusColors.of(context);
    return switch (this) {
      DayDisplay.kept => Icon(Icons.check_circle, size: size, color: status.done),
      DayDisplay.ahead => Icon(Icons.fast_forward_rounded, size: size, color: status.done),
      DayDisplay.caughtUp => Icon(Icons.published_with_changes, size: size, color: status.done),
      DayDisplay.grace => Icon(Icons.shield_outlined, size: size, color: status.grace),
      DayDisplay.paused => Icon(Icons.pause_circle_outline, size: size, color: scheme.onSurfaceVariant),
      DayDisplay.open => Icon(Icons.radio_button_unchecked, size: size, color: scheme.onSurfaceVariant),
      DayDisplay.today => Icon(Icons.adjust, size: size, color: scheme.primary),
      DayDisplay.missed => Icon(Icons.remove_circle_outline, size: size, color: status.neutral),
      DayDisplay.rest => ShabbatCandlesIcon(size: size, color: status.rest),
      DayDisplay.upcoming => Icon(Icons.circle_outlined, size: size, color: scheme.outline),
      DayDisplay.noReading => Icon(Icons.horizontal_rule, size: size, color: scheme.outline),
    };
  }
}

/// Sunday through Shabbat of a week, with the day's plan and status.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.plan,
    required this.today,
    required this.statuses,
    required this.israel,
    this.onDayTap,
    this.joinDate,
  });

  final WeekPlan plan;
  final LocalDate today;
  final Map<LocalDate, DayStatus> statuses;
  final bool israel;
  final LocalDate? joinDate;
  final void Function(PlanDay day)? onDayTap;

  @override
  Widget build(BuildContext context) {
    final names = Names(context);
    final end = plan.week.occasion.isShabbat ? plan.week.occasion : plan.week.occasion.onOrAfter(6);
    final days = [for (var i = 6; i >= 0; i--) end.addDays(-i)];
    final theme = Theme.of(context);
    return Semantics(
      label: context.l10n.weekStripLabel,
      container: true,
      explicitChildNodes: true,
      child: Row(
        children: [
          for (final d in days)
            Expanded(
              child: Builder(builder: (context) {
                final planned = plan.dayFor(d);
                final rest = JewishHolidays.isRestDay(d, israel: israel);
                final display = dayDisplayFor(
                  date: d,
                  today: today,
                  status: statuses[d],
                  rest: rest,
                  planned: planned != null,
                  joinDate: joinDate,
                );
                final aliyot = planned == null ? '' : names.aliyot(planned.aliyot);
                final isToday = d == today;
                final semantic = [
                  context.l10n.dayChipLabel(names.weekday(d), display.label(context)),
                  if (aliyot.isNotEmpty) aliyot,
                ].join('. ');
                final chip = Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: isToday ? Border.all(color: theme.colorScheme.primary, width: 2) : null,
                    color: isToday ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35) : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        names.weekdayShort(d),
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      display.icon(context),
                    ],
                  ),
                );
                return Semantics(
                  label: semantic,
                  button: planned != null && onDayTap != null,
                  excludeSemantics: true,
                  child: Tooltip(
                    message: semantic,
                    child: planned != null && onDayTap != null
                        ? InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => onDayTap!(planned),
                            child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 48), child: chip),
                          )
                        : ConstrainedBox(constraints: const BoxConstraints(minHeight: 48), child: chip),
                  ),
                );
              }),
            ),
        ],
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
    return switch (s) {
      WeekStatus.onTime || WeekStatus.restored => c.done,
      WeekStatus.late || WeekStatus.madeUp => c.late,
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
