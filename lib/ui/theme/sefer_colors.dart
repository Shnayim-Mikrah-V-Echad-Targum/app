import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// The book-specific colour tokens that ColorScheme has no role for
/// (docs/DESIGN_SYSTEM.md §3.3). Values per theme are in palette.dart, and
/// AppTheme.build registers the right one, so read them with
/// `SeferColors.of(context)`.
@immutable
class SeferColors extends ThemeExtension<SeferColors> {
  const SeferColors({
    required this.paper,
    required this.hairline,
    required this.hairlineWidth,
    required this.goldLeaf,
    required this.ringMikrah1,
    required this.ringMikrah2,
    required this.ringTargum,
    required this.ringTrack,
    required this.yearTrack,
    required this.restWash,
    required this.focus,
    required this.focusGap,
    required this.dimInk,
    required this.verseHighlight,
    required this.isHighContrast,
  });

  /// Cards, sheets and dialogs: a page lifted slightly off the surface.
  final Color paper;

  /// Decorative rules between rows and around cards. In high contrast it is
  /// the outline colour, drawn [hairlineWidth] wide.
  final Color hairline;
  final double hairlineWidth;

  /// Frame rules and lozenges. Decorative only: it never carries meaning.
  final Color goldLeaf;

  /// The parsha rings: first reading, second reading, Targum, and the track.
  final Color ringMikrah1;
  final Color ringMikrah2;
  final Color ringTargum;
  final Color ringTrack;

  /// The year bar's open segments (§6.15), a few pixels wide, which the
  /// rings' track would leave all but invisible: outlineVariant, and in high
  /// contrast, where outlineVariant is as dark as a finished segment, a grey
  /// midway, at least 3:1 from the page and 4:1 from a finished segment.
  final Color yearTrack;

  /// The fill behind Shabbat and Yom Tov days.
  final Color restWash;

  /// The keyboard focus ring, and the gap painted between it and the control.
  final Color focus;
  final Color focusGap;

  /// Focus mode's de-emphasized verses. Still meets 4.5:1 on the surface; in
  /// high contrast it does not dim at all.
  final Color dimInk;

  /// Focus mode's current-verse fill (transparent in high contrast).
  final Color verseHighlight;

  /// Whether this is one of the two high-contrast themes.
  final bool isHighContrast;

  static SeferColors of(BuildContext context) => Theme.of(context).extension<SeferColors>()!;

  @override
  SeferColors copyWith({
    Color? paper,
    Color? hairline,
    double? hairlineWidth,
    Color? goldLeaf,
    Color? ringMikrah1,
    Color? ringMikrah2,
    Color? ringTargum,
    Color? ringTrack,
    Color? yearTrack,
    Color? restWash,
    Color? focus,
    Color? focusGap,
    Color? dimInk,
    Color? verseHighlight,
    bool? isHighContrast,
  }) =>
      SeferColors(
        paper: paper ?? this.paper,
        hairline: hairline ?? this.hairline,
        hairlineWidth: hairlineWidth ?? this.hairlineWidth,
        goldLeaf: goldLeaf ?? this.goldLeaf,
        ringMikrah1: ringMikrah1 ?? this.ringMikrah1,
        ringMikrah2: ringMikrah2 ?? this.ringMikrah2,
        ringTargum: ringTargum ?? this.ringTargum,
        ringTrack: ringTrack ?? this.ringTrack,
        yearTrack: yearTrack ?? this.yearTrack,
        restWash: restWash ?? this.restWash,
        focus: focus ?? this.focus,
        focusGap: focusGap ?? this.focusGap,
        dimInk: dimInk ?? this.dimInk,
        verseHighlight: verseHighlight ?? this.verseHighlight,
        isHighContrast: isHighContrast ?? this.isHighContrast,
      );

  @override
  SeferColors lerp(SeferColors? other, double t) {
    if (other == null) return this;
    return SeferColors(
      paper: Color.lerp(paper, other.paper, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      hairlineWidth: lerpDouble(hairlineWidth, other.hairlineWidth, t)!,
      goldLeaf: Color.lerp(goldLeaf, other.goldLeaf, t)!,
      ringMikrah1: Color.lerp(ringMikrah1, other.ringMikrah1, t)!,
      ringMikrah2: Color.lerp(ringMikrah2, other.ringMikrah2, t)!,
      ringTargum: Color.lerp(ringTargum, other.ringTargum, t)!,
      ringTrack: Color.lerp(ringTrack, other.ringTrack, t)!,
      yearTrack: Color.lerp(yearTrack, other.yearTrack, t)!,
      restWash: Color.lerp(restWash, other.restWash, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      focusGap: Color.lerp(focusGap, other.focusGap, t)!,
      dimInk: Color.lerp(dimInk, other.dimInk, t)!,
      verseHighlight: Color.lerp(verseHighlight, other.verseHighlight, t)!,
      // A flag can't be blended: switch halfway, as ThemeData does for
      // its own booleans.
      isHighContrast: t < 0.5 ? isHighContrast : other.isHighContrast,
    );
  }
}
