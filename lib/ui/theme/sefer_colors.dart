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
    required this.ringMikra1,
    required this.ringMikra2,
    required this.ringTargum,
    required this.ringTrack,
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
  final Color ringMikra1;
  final Color ringMikra2;
  final Color ringTargum;
  final Color ringTrack;

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
    Color? ringMikra1,
    Color? ringMikra2,
    Color? ringTargum,
    Color? ringTrack,
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
        ringMikra1: ringMikra1 ?? this.ringMikra1,
        ringMikra2: ringMikra2 ?? this.ringMikra2,
        ringTargum: ringTargum ?? this.ringTargum,
        ringTrack: ringTrack ?? this.ringTrack,
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
      ringMikra1: Color.lerp(ringMikra1, other.ringMikra1, t)!,
      ringMikra2: Color.lerp(ringMikra2, other.ringMikra2, t)!,
      ringTargum: Color.lerp(ringTargum, other.ringTargum, t)!,
      ringTrack: Color.lerp(ringTrack, other.ringTrack, t)!,
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
