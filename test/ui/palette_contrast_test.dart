// Locks in the contrast of the Klaf & Techelet palette (docs/DESIGN_SYSTEM.md
// §3.5) with the WCAG 2.x formula, so no colour can drift below its target
// unnoticed. Pure Dart: it reads the palette constants, not a rendered app.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/ui/theme/palette.dart';

/// WCAG 2.x relative luminance of an opaque sRGB colour.
double luminance(Color c) {
  double linear(double v) => v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b);
}

/// WCAG contrast ratio, from 1 to 21.
double contrast(Color a, Color b) {
  final la = luminance(a);
  final lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

class _Theme {
  const _Theme(this.name, this.scheme, this.sefer, this.status, {this.highContrast = false});
  final String name;
  final ColorScheme scheme;
  final SeferColors sefer;
  final StatusColors status;
  final bool highContrast;
}

const _themes = [
  _Theme('light', Palettes.light, Palettes.seferLight, Palettes.statusLight),
  _Theme('dark', Palettes.dark, Palettes.seferDark, Palettes.statusDark),
  _Theme('sepia', Palettes.sepia, Palettes.seferSepia, Palettes.statusSepia),
  _Theme('hcLight', Palettes.hcLight, Palettes.seferHcLight, Palettes.statusHcLight, highContrast: true),
  _Theme('hcDark', Palettes.hcDark, Palettes.seferHcDark, Palettes.statusHcDark, highContrast: true),
];

typedef _Pair = (Color, Color) Function(_Theme t);

/// Text on its background: 4.5:1, or 7:1 in high contrast.
final _textPairs = <String, _Pair>{
  'onSurface / surface': (t) => (t.scheme.onSurface, t.scheme.surface),
  'onSurface / paper': (t) => (t.scheme.onSurface, t.sefer.paper),
  'onSurfaceVariant / surface': (t) => (t.scheme.onSurfaceVariant, t.scheme.surface),
  'onSurfaceVariant / paper': (t) => (t.scheme.onSurfaceVariant, t.sefer.paper),
  'onSurfaceVariant / surfaceContainer': (t) => (t.scheme.onSurfaceVariant, t.scheme.surfaceContainer),
  'dimInk / surface': (t) => (t.sefer.dimInk, t.scheme.surface),
  'primary / surface': (t) => (t.scheme.primary, t.scheme.surface),
  'primary / paper': (t) => (t.scheme.primary, t.sefer.paper),
  'onPrimary / primary': (t) => (t.scheme.onPrimary, t.scheme.primary),
  'onPrimaryContainer / primaryContainer': (t) => (t.scheme.onPrimaryContainer, t.scheme.primaryContainer),
  'onSurface / primaryContainer': (t) => (t.scheme.onSurface, t.scheme.primaryContainer),
  'secondary / surface': (t) => (t.scheme.secondary, t.scheme.surface),
  'secondary / paper': (t) => (t.scheme.secondary, t.sefer.paper),
  'secondary / restWash': (t) => (t.scheme.secondary, t.sefer.restWash),
  'onSecondaryContainer / secondaryContainer': (t) => (t.scheme.onSecondaryContainer, t.scheme.secondaryContainer),
  'tertiary / paper': (t) => (t.scheme.tertiary, t.sefer.paper),
  'onLate / late': (t) => (t.status.onLate, t.status.late),
  'late / paper': (t) => (t.status.late, t.sefer.paper),
  'error / surface': (t) => (t.scheme.error, t.scheme.surface),
  'onInverseSurface / inverseSurface': (t) => (t.scheme.onInverseSurface, t.scheme.inverseSurface),
  'inversePrimary / inverseSurface': (t) => (t.scheme.inversePrimary, t.scheme.inverseSurface),
};

/// Boundaries, icons and graphics: 3:1, or 4.5:1 in high contrast. goldLeaf
/// and hairline are decorative and exempt.
final _uiPairs = <String, _Pair>{
  'outline / surface': (t) => (t.scheme.outline, t.scheme.surface),
  'outline / paper': (t) => (t.scheme.outline, t.sefer.paper),
  'outline / surfaceContainer': (t) => (t.scheme.outline, t.scheme.surfaceContainer),
  'focus / surface': (t) => (t.sefer.focus, t.scheme.surface),
  'neutral / paper': (t) => (t.status.neutral, t.sefer.paper),
  'ringMikra1 / paper': (t) => (t.sefer.ringMikra1, t.sefer.paper),
  'ringMikra2 / paper': (t) => (t.sefer.ringMikra2, t.sefer.paper),
  'ringTargum / paper': (t) => (t.sefer.ringTargum, t.sefer.paper),
  'ringMikra2 / ringTrack': (t) => (t.sefer.ringMikra2, t.sefer.ringTrack),
  'ringTargum / ringTrack': (t) => (t.sefer.ringTargum, t.sefer.ringTrack),
};

/// Each pair in [pairs] that falls short of [minimum] in theme [t], described
/// for the failure message.
List<String> _shortfalls(_Theme t, Map<String, _Pair> pairs, double minimum) {
  final out = <String>[];
  for (final MapEntry(key: name, value: pair) in pairs.entries) {
    final (fg, bg) = pair(t);
    if (fg.a != 1 || bg.a != 1) {
      out.add('$name: translucent, so its contrast depends on what is behind it');
    } else if (contrast(fg, bg) < minimum) {
      out.add('$name: ${contrast(fg, bg).toStringAsFixed(2)}');
    }
  }
  return out;
}

/// The ColorScheme roles by name, for comparing two schemes role by role.
final _roles = <String, Color Function(ColorScheme)>{
  'primary': (s) => s.primary,
  'onPrimary': (s) => s.onPrimary,
  'primaryContainer': (s) => s.primaryContainer,
  'onPrimaryContainer': (s) => s.onPrimaryContainer,
  'primaryFixed': (s) => s.primaryFixed,
  'primaryFixedDim': (s) => s.primaryFixedDim,
  'onPrimaryFixed': (s) => s.onPrimaryFixed,
  'onPrimaryFixedVariant': (s) => s.onPrimaryFixedVariant,
  'secondary': (s) => s.secondary,
  'onSecondary': (s) => s.onSecondary,
  'secondaryContainer': (s) => s.secondaryContainer,
  'onSecondaryContainer': (s) => s.onSecondaryContainer,
  'secondaryFixed': (s) => s.secondaryFixed,
  'secondaryFixedDim': (s) => s.secondaryFixedDim,
  'onSecondaryFixed': (s) => s.onSecondaryFixed,
  'onSecondaryFixedVariant': (s) => s.onSecondaryFixedVariant,
  'tertiary': (s) => s.tertiary,
  'onTertiary': (s) => s.onTertiary,
  'tertiaryContainer': (s) => s.tertiaryContainer,
  'onTertiaryContainer': (s) => s.onTertiaryContainer,
  'tertiaryFixed': (s) => s.tertiaryFixed,
  'tertiaryFixedDim': (s) => s.tertiaryFixedDim,
  'onTertiaryFixed': (s) => s.onTertiaryFixed,
  'onTertiaryFixedVariant': (s) => s.onTertiaryFixedVariant,
  'error': (s) => s.error,
  'onError': (s) => s.onError,
  'errorContainer': (s) => s.errorContainer,
  'onErrorContainer': (s) => s.onErrorContainer,
  'surface': (s) => s.surface,
  'onSurface': (s) => s.onSurface,
  'surfaceDim': (s) => s.surfaceDim,
  'surfaceBright': (s) => s.surfaceBright,
  'surfaceContainerLowest': (s) => s.surfaceContainerLowest,
  'surfaceContainerLow': (s) => s.surfaceContainerLow,
  'surfaceContainer': (s) => s.surfaceContainer,
  'surfaceContainerHigh': (s) => s.surfaceContainerHigh,
  'surfaceContainerHighest': (s) => s.surfaceContainerHighest,
  'onSurfaceVariant': (s) => s.onSurfaceVariant,
  'outline': (s) => s.outline,
  'outlineVariant': (s) => s.outlineVariant,
  'shadow': (s) => s.shadow,
  'scrim': (s) => s.scrim,
  'inverseSurface': (s) => s.inverseSurface,
  'onInverseSurface': (s) => s.onInverseSurface,
  'inversePrimary': (s) => s.inversePrimary,
  'surfaceTint': (s) => s.surfaceTint,
};

void main() {
  test('the contrast formula matches WCAG', () {
    expect(contrast(Colors.black, Colors.white), closeTo(21, 1e-9));
    expect(contrast(Colors.white, Colors.white), 1);
    // #767676 is the classic lightest grey that passes 4.5:1 on white.
    expect(contrast(const Color(0xFF767676), Colors.white), closeTo(4.54, 0.01));
  });

  for (final t in _themes) {
    group(t.name, () {
      final text = t.highContrast ? 7.0 : 4.5;
      final ui = t.highContrast ? 4.5 : 3.0;

      test('text pairs reach $text:1', () {
        expect(_shortfalls(t, _textPairs, text), isEmpty);
      });

      test('scripture (onSurface / surface) reaches 7:1', () {
        expect(contrast(t.scheme.onSurface, t.scheme.surface), greaterThanOrEqualTo(7));
      });

      test('UI pairs reach $ui:1', () {
        expect(_shortfalls(t, _uiPairs, ui), isEmpty);
      });

      test('fixed roles repeat the containers, and nothing is tinted', () {
        final s = t.scheme;
        expect(s.surfaceTint, Colors.transparent);
        for (final (fixed, container) in [
          (s.primaryFixed, s.primaryContainer),
          (s.primaryFixedDim, s.primaryContainer),
          (s.onPrimaryFixed, s.onPrimaryContainer),
          (s.onPrimaryFixedVariant, s.onPrimaryContainer),
          (s.secondaryFixed, s.secondaryContainer),
          (s.secondaryFixedDim, s.secondaryContainer),
          (s.onSecondaryFixed, s.onSecondaryContainer),
          (s.onSecondaryFixedVariant, s.onSecondaryContainer),
          (s.tertiaryFixed, s.tertiaryContainer),
          (s.tertiaryFixedDim, s.tertiaryContainer),
          (s.onTertiaryFixed, s.onTertiaryContainer),
          (s.onTertiaryFixedVariant, s.onTertiaryContainer),
        ]) {
          expect(fixed, container);
        }
      });

      test('focus, highlight and high-contrast rules', () {
        final s = t.scheme;
        final sefer = t.sefer;
        expect(sefer.isHighContrast, t.highContrast);
        if (t.highContrast) {
          // §3.1 rule 7: no dimming, a 2 px outline for every hairline, and
          // a focus ring in the ink colour.
          expect(sefer.dimInk, s.onSurfaceVariant);
          expect(sefer.hairline, s.outline);
          expect(sefer.hairlineWidth, 2);
          expect(sefer.focus, s.onSurface);
          expect(sefer.verseHighlight, Colors.transparent);
        } else {
          expect(sefer.hairlineWidth, 1);
          expect(sefer.focus, s.primary);
          expect(sefer.verseHighlight, sefer.paper);
        }
        expect(sefer.focusGap, s.surface);
        // Techelet means Mikra progress, so "done" and the first ring share it.
        expect(sefer.ringMikra1, s.primary);
        expect(t.status.done, s.primary);
      });
    });
  }

  // Every role is chosen by hand, so none may equal the tone Material would
  // seed from techelet. Pure black and white are absolutes rather than seeded
  // tones (text on a filled button, the scrim), so matching there is a choice.
  const seed = Color(0xFF1D3F75);
  for (final (name, scheme, seeded) in [
    ('light', Palettes.light, ColorScheme.fromSeed(seedColor: seed)),
    ('dark', Palettes.dark, ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark)),
  ]) {
    test('no $name role is a seeded default', () {
      bool absolute(Color c) => c == const Color(0xFF000000) || c == const Color(0xFFFFFFFF);
      final matches = [
        for (final MapEntry(key: role, value: of) in _roles.entries)
          if (of(scheme) == of(seeded) && !absolute(of(scheme))) role,
      ];
      expect(matches, isEmpty);
    });
  }
}
