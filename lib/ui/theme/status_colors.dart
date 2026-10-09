import 'package:flutter/material.dart';

/// Semantic colors for progress states. Never red: missed days are shown in
/// neutral grey, and every state also has its own icon and label so color is
/// never the only signal (WCAG 1.4.1). Values per theme are in palette.dart.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.done,
    required this.onDone,
    required this.late,
    required this.onLate,
    required this.overdue,
    required this.grace,
    required this.neutral,
    required this.rest,
  });

  /// Read on time (techelet).
  final Color done;
  final Color onDone;

  /// Finished late or restored: a quieter slate blue.
  final Color late;
  final Color onLate;

  /// Still open after its Shabbat (gold ink, the rubric colour).
  final Color overdue;

  /// Covered by a grace day (hyssop green, used for nothing else).
  final Color grace;

  /// Missed: always paired with a dash glyph, never red.
  final Color neutral;

  /// Shabbat and Yom Tov candles.
  final Color rest;

  static StatusColors of(BuildContext context) => Theme.of(context).extension<StatusColors>()!;

  @override
  StatusColors copyWith({
    Color? done,
    Color? onDone,
    Color? late,
    Color? onLate,
    Color? overdue,
    Color? grace,
    Color? neutral,
    Color? rest,
  }) =>
      StatusColors(
        done: done ?? this.done,
        onDone: onDone ?? this.onDone,
        late: late ?? this.late,
        onLate: onLate ?? this.onLate,
        overdue: overdue ?? this.overdue,
        grace: grace ?? this.grace,
        neutral: neutral ?? this.neutral,
        rest: rest ?? this.rest,
      );

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    return StatusColors(
      done: Color.lerp(done, other.done, t)!,
      onDone: Color.lerp(onDone, other.onDone, t)!,
      late: Color.lerp(late, other.late, t)!,
      onLate: Color.lerp(onLate, other.onLate, t)!,
      overdue: Color.lerp(overdue, other.overdue, t)!,
      grace: Color.lerp(grace, other.grace, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      rest: Color.lerp(rest, other.rest, t)!,
    );
  }
}
