import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/text/hebrew_text.dart';
import '../../features/settings/app_settings.dart';

/// A family and the families that draw the characters it lacks.
typedef _Face = ({String? family, List<String>? fallback});

// The families of docs/DESIGN_SYSTEM.md §4.2. A Hebrew word in an English
// heading falls back to Frank Ruhl Libre, and a Latin word in a Hebrew one to
// EB Garamond, so headings never mix a serif with a sans.
const _Face _ebg = (family: 'EBGaramond', fallback: ['FrankRuhlLibre', 'NotoSerifHebrew']);
const _Face _frl = (family: 'FrankRuhlLibre', fallback: ['EBGaramond', 'NotoSerifHebrew']);
const _Face _ns = (family: 'NotoSans', fallback: ['NotoSansHebrew', 'NotoSerifHebrew']);
const _Face _nsh = (family: 'NotoSansHebrew', fallback: ['NotoSans', 'NotoSerifHebrew']);

/// For a face with little or no Hebrew of its own (§4.2).
const _hebrewFallback = ['NotoSansHebrew', 'NotoSerifHebrew'];

/// The platform's own font ("Device font"): no family, so ThemeData fills in
/// the platform's. It changes the Latin text only. Hebrew falls back to the
/// bundled Noto Sans Hebrew, with Noto Serif Hebrew for any mark it lacks, as
/// in every other face (§13.1), so nikud never depends on the system's fonts.
/// (In both UIs: Noto Sans Hebrew's own list starts with Noto Sans, which
/// would set the Latin text in Noto Sans again.) Segoe UI, which has Hebrew
/// of its own, draws the Hebrew on Windows.
const _Face _device = (family: null, fallback: _hebrewFallback);

/// Serif numbers line up in columns and sit on the baseline (§4.5): EB
/// Garamond's default old-style figures make "1" read as "I".
const _figures = [FontFeature.liningFigures(), FontFeature.tabularFigures()];

/// The app's type (docs/DESIGN_SYSTEM.md §4.2–4.5): a serif for display roles
/// (EB Garamond in the English UI, Frank Ruhl Libre in the Hebrew UI) and a
/// bundled sans for everything else, so the brand looks the same on every
/// platform.
///
/// Only bundled weights are ever requested: 500, 600 and 700 for the serifs;
/// 400, 500 and 700 for Noto Sans and Noto Sans Hebrew; 400 and 700 for the
/// accessibility fonts, except their Medium roles in the Hebrew UI (see
/// [_Typesetter.sans]). Bold text needs nothing here: [Text] itself switches
/// to w700 when `MediaQuery.boldTextOf` is true, and every family bundles it.
abstract final class AppTypography {
  static TextTheme textTheme({
    required ColorScheme scheme,
    required UiFont uiFont,
    required bool hebrewUi,
    required bool highContrast,
  }) {
    final t = _Typesetter(uiFont: uiFont, hebrewUi: hebrewUi, highContrast: highContrast);
    final ink = scheme.onSurface;
    if (hebrewUi) {
      // Hebrew has no case and no tracking: letter spacing is 0 everywhere.
      return TextTheme(
        displayLarge: t.display(40, 56, FontWeight.w500, color: ink),
        displayMedium: t.display(34, 48, FontWeight.w500, color: ink),
        displaySmall: t.display(30, 42, FontWeight.w500, color: ink),
        headlineLarge: t.display(28, 38, FontWeight.w500, color: ink),
        headlineMedium: t.display(26, 36, FontWeight.w500, color: ink),
        headlineSmall: t.display(22, 30, FontWeight.w600, color: ink),
        titleLarge: t.display(21, 28, FontWeight.w600, color: ink),
        titleMedium: t.sans(16, 24, FontWeight.w500, color: ink),
        titleSmall: t.sans(14, 22, FontWeight.w500, color: ink),
        bodyLarge: t.sans(16, 26, FontWeight.w400, color: ink),
        bodyMedium: t.sans(15, 24, FontWeight.w400, color: ink),
        bodySmall: t.sans(13, 20, FontWeight.w400, color: ink),
        labelLarge: t.sans(15, 20, FontWeight.w500, color: ink),
        labelMedium: t.sans(13, 18, FontWeight.w500, color: ink),
        labelSmall: t.sans(12, 16, FontWeight.w500, color: ink),
      );
    }
    return TextTheme(
      displayLarge: t.display(44, 52, FontWeight.w500, letterSpacing: -0.25, color: ink),
      displayMedium: t.display(38, 46, FontWeight.w500, letterSpacing: -0.2, color: ink),
      displaySmall: t.display(32, 40, FontWeight.w500, color: ink),
      headlineLarge: t.display(30, 38, FontWeight.w500, color: ink),
      headlineMedium: t.display(28, 36, FontWeight.w500, color: ink),
      headlineSmall: t.display(24, 30, FontWeight.w500, color: ink),
      titleLarge: t.display(22, 28, FontWeight.w500, color: ink),
      titleMedium: t.sans(16, 24, FontWeight.w500, letterSpacing: 0.1, color: ink),
      titleSmall: t.sans(14, 20, FontWeight.w500, letterSpacing: 0.1, color: ink),
      bodyLarge: t.sans(16, 24, FontWeight.w400, letterSpacing: 0.15, color: ink),
      bodyMedium: t.sans(15, 22, FontWeight.w400, letterSpacing: 0.15, color: ink),
      bodySmall: t.sans(13, 18, FontWeight.w400, letterSpacing: 0.2, color: ink),
      labelLarge: t.sans(15, 20, FontWeight.w500, letterSpacing: 0.1, color: ink),
      labelMedium: t.sans(13, 16, FontWeight.w500, letterSpacing: 0.3, color: ink),
      labelSmall: t.sans(12, 16, FontWeight.w500, letterSpacing: 0.4, color: ink),
    );
  }

  static SeferType sefer({
    required ColorScheme scheme,
    required UiFont uiFont,
    required bool hebrewUi,
    required bool highContrast,
  }) {
    final t = _Typesetter(uiFont: uiFont, hebrewUi: hebrewUi, highContrast: highContrast);
    final accessible = t.accessible;
    final he = hebrewUi;

    final TextStyle eyebrow;
    if (accessible) {
      // No small caps in these fonts: the English UI uppercases instead (see
      // SeferType.eyebrowText).
      eyebrow = t.style(t.accessibleFace, 13, 16, FontWeight.w700,
          letterSpacing: he ? 0 : 0.8, color: scheme.secondary);
    } else {
      // Small caps are thin: high contrast sets them in bold.
      eyebrow = he
          ? t.serif(_frl, 16, 20, FontWeight.w600, color: scheme.secondary)
          : t.serif(_ebg, 18, 22, highContrast ? FontWeight.w700 : FontWeight.w600,
              letterSpacing: 0.8,
              color: scheme.secondary,
              features: const [FontFeature.enable('smcp'), FontFeature.enable('c2sc')]);
    }

    final TextStyle marginalia;
    if (accessible) {
      marginalia = t.style(t.accessibleFace, 16, 24, FontWeight.w400, color: scheme.onSurfaceVariant);
    } else if (he) {
      // No italics in Hebrew.
      marginalia = t.serif(_frl, 17, 26, FontWeight.w500, color: scheme.onSurfaceVariant);
    } else {
      // High contrast sets it upright: thin italic strokes are the first to go.
      marginalia = t.serif(_ebg, 19, 28, FontWeight.w500,
          italic: !highContrast, color: scheme.onSurfaceVariant);
    }

    // Counts are Latin digits in both UIs, so numerals are always EB Garamond.
    TextStyle numeral(double size, double lineHeight) => accessible
        ? t.style(t.accessibleFace, size, lineHeight, FontWeight.w700,
            color: scheme.onSurface, features: const [FontFeature.tabularFigures()])
        : t.serif(_ebg, size, lineHeight, FontWeight.w600, color: scheme.onSurface, features: _figures);

    return SeferType(
      eyebrow: eyebrow,
      marginalia: marginalia,
      ledgerNumeral: numeral(34, 40),
      ringNumeral: numeral(22, 24),
      longformBody: accessible
          ? t.style(t.accessibleFace, 18, 30, FontWeight.w400, color: scheme.onSurface)
          : he
              ? t.serif(_frl, 18, 30, FontWeight.w500, color: scheme.onSurface)
              : t.serif(_ebg, 20, 32, FontWeight.w500, letterSpacing: 0.1, color: scheme.onSurface),
      longformHeading: he
          ? t.display(22, 30, FontWeight.w600, color: scheme.onSurface)
          : t.display(24, 30, FontWeight.w500, color: scheme.onSurface),
      // Never an accessibility font: they have no Hebrew. The size is set per
      // use; the fallback keeps every point and cantillation mark drawable.
      hebrewDisplay: t.serif((family: 'FrankRuhlLibre', fallback: const ['NotoSerifHebrew']), null, null,
          FontWeight.w500, height: 1.3, color: scheme.primary),
      ordinal: accessible
          ? t.style(t.accessibleFace, 20, 24, FontWeight.w700, color: scheme.onSurface)
          : t.serif(_frl, 20, 24, FontWeight.w600, color: scheme.onSurface),
      wordmark: t.display(20, 24, FontWeight.w500, color: scheme.onSurface),
      uppercaseEyebrows: accessible && !he,
    );
  }
}

/// Builds styles for one combination of interface font, UI language and
/// contrast.
class _Typesetter {
  _Typesetter({required this.uiFont, required this.hebrewUi, required this.highContrast});

  final UiFont uiFont;
  final bool hebrewUi;
  final bool highContrast;

  /// Whether an accessibility font replaces the serifs and the sans.
  bool get accessible => uiFont.family != null;

  /// Atkinson, Lexend and OpenDyslexic have no Hebrew.
  _Face get accessibleFace => (family: uiFont.family, fallback: _hebrewFallback);

  /// A display, headline or title role: the UI language's serif, or the
  /// accessibility font in bold.
  TextStyle display(double size, double lineHeight, FontWeight weight, {double letterSpacing = 0, Color? color}) =>
      accessible
          ? style(accessibleFace, size, lineHeight, FontWeight.w700, letterSpacing: letterSpacing, color: color)
          : serif(hebrewUi ? _frl : _ebg, size, lineHeight, weight,
              letterSpacing: letterSpacing, color: color, features: _figures);

  /// An EB Garamond or Frank Ruhl Libre style, heavier in high contrast so
  /// the hairline strokes hold up.
  TextStyle serif(
    _Face face,
    double? size,
    double? lineHeight,
    FontWeight weight, {
    double? height,
    double letterSpacing = 0,
    bool italic = false,
    Color? color,
    List<FontFeature>? features,
  }) {
    if (highContrast) {
      weight = face.family == _ebg.family
          ? (weight.value < 600 ? FontWeight.w600 : weight)
          : FontWeight.w700;
    }
    return style(face, size, lineHeight, weight,
        height: height, letterSpacing: letterSpacing, italic: italic, color: color, features: features);
  }

  /// A Noto Sans (English UI) or Noto Sans Hebrew (Hebrew UI) role, or the
  /// chosen interface font.
  TextStyle sans(double size, double lineHeight, FontWeight weight, {double letterSpacing = 0, Color? color}) {
    final _Face face;
    if (accessible) {
      face = accessibleFace;
      // These fonts bundle 400 and 700 only. In the English UI a Medium role
      // asks for their Regular, which is what 500 would quietly render as.
      // The Hebrew UI keeps 500: its Hebrew is drawn by the fallback, Noto
      // Sans Hebrew, which has a Medium, so row titles and buttons keep their
      // weight; a Latin word among it still falls to the Regular, the nearest
      // weight its font has.
      if (weight == FontWeight.w500 && !hebrewUi) weight = FontWeight.w400;
    } else if (uiFont == UiFont.system && !kIsWeb) {
      face = _device;
    } else {
      // The web can't reach the device's fonts, so it always gets the bundled
      // ones.
      face = hebrewUi ? _nsh : _ns;
    }
    return style(face, size, lineHeight, weight, letterSpacing: letterSpacing, color: color);
  }

  /// Every style sets its line height, split evenly above and below the
  /// glyphs so that nikud and descenders are never clipped.
  TextStyle style(
    _Face face,
    double? size,
    double? lineHeight,
    FontWeight weight, {
    double? height,
    double letterSpacing = 0,
    bool italic = false,
    Color? color,
    List<FontFeature>? features,
  }) =>
      TextStyle(
        fontFamily: face.family,
        fontFamilyFallback: face.fallback,
        fontSize: size,
        height: height ?? lineHeight! / size!,
        leadingDistribution: TextLeadingDistribution.even,
        fontWeight: weight,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        letterSpacing: letterSpacing,
        color: color,
        fontFeatures: features,
      );
}

/// The book-specific type tokens that TextTheme has no role for
/// (docs/DESIGN_SYSTEM.md §4.5). AppTheme.build registers the set for the
/// interface font, UI language and contrast, so read them with
/// `SeferType.of(context)`.
@immutable
class SeferType extends ThemeExtension<SeferType> {
  const SeferType({
    required this.eyebrow,
    required this.marginalia,
    required this.ledgerNumeral,
    required this.ringNumeral,
    required this.longformBody,
    required this.longformHeading,
    required this.hebrewDisplay,
    required this.ordinal,
    required this.wordmark,
    required this.uppercaseEyebrows,
  });

  /// The small line above a title, in gold ink: small caps in English. Never
  /// put digits in it (old-style small-cap figures make "1" read as "I");
  /// pass the text through [eyebrowText].
  final TextStyle eyebrow;

  /// One gentle sentence beside the main content, never instructions.
  final TextStyle marginalia;

  /// The large counts on the ledger card.
  final TextStyle ledgerNumeral;

  /// The count in the middle of the parsha rings.
  final TextStyle ringNumeral;

  /// Running text and headings on the Guide, About, Sources and Privacy pages.
  final TextStyle longformBody;
  final TextStyle longformHeading;

  /// Pointed Hebrew titles, such as the parsha name. It has no size: set one
  /// per use. Never replaced by an accessibility font, which has no Hebrew.
  final TextStyle hebrewDisplay;

  /// The Hebrew aliyah letter, א to ז.
  final TextStyle ordinal;

  /// The app's name beside its mark, at the head of the extended navigation
  /// rail (§6.10).
  final TextStyle wordmark;

  /// Whether [eyebrowText] uppercases: an accessibility font has no small
  /// caps, so the English UI sets eyebrows in capitals instead.
  final bool uppercaseEyebrows;

  static SeferType of(BuildContext context) => Theme.of(context).extension<SeferType>()!;

  /// [text] as an eyebrow shows it. A string with any Hebrew in it is never
  /// uppercased, so a transliteration beside it isn't either.
  String eyebrowText(String text) =>
      uppercaseEyebrows && !HebrewText.containsHebrew(text) ? text.toUpperCase() : text;

  @override
  SeferType copyWith({
    TextStyle? eyebrow,
    TextStyle? marginalia,
    TextStyle? ledgerNumeral,
    TextStyle? ringNumeral,
    TextStyle? longformBody,
    TextStyle? longformHeading,
    TextStyle? hebrewDisplay,
    TextStyle? ordinal,
    TextStyle? wordmark,
    bool? uppercaseEyebrows,
  }) =>
      SeferType(
        eyebrow: eyebrow ?? this.eyebrow,
        marginalia: marginalia ?? this.marginalia,
        ledgerNumeral: ledgerNumeral ?? this.ledgerNumeral,
        ringNumeral: ringNumeral ?? this.ringNumeral,
        longformBody: longformBody ?? this.longformBody,
        longformHeading: longformHeading ?? this.longformHeading,
        hebrewDisplay: hebrewDisplay ?? this.hebrewDisplay,
        ordinal: ordinal ?? this.ordinal,
        wordmark: wordmark ?? this.wordmark,
        uppercaseEyebrows: uppercaseEyebrows ?? this.uppercaseEyebrows,
      );

  @override
  SeferType lerp(SeferType? other, double t) {
    if (other == null) return this;
    return SeferType(
      eyebrow: TextStyle.lerp(eyebrow, other.eyebrow, t)!,
      marginalia: TextStyle.lerp(marginalia, other.marginalia, t)!,
      ledgerNumeral: TextStyle.lerp(ledgerNumeral, other.ledgerNumeral, t)!,
      ringNumeral: TextStyle.lerp(ringNumeral, other.ringNumeral, t)!,
      longformBody: TextStyle.lerp(longformBody, other.longformBody, t)!,
      longformHeading: TextStyle.lerp(longformHeading, other.longformHeading, t)!,
      hebrewDisplay: TextStyle.lerp(hebrewDisplay, other.hebrewDisplay, t)!,
      ordinal: TextStyle.lerp(ordinal, other.ordinal, t)!,
      wordmark: TextStyle.lerp(wordmark, other.wordmark, t)!,
      // A flag can't be blended: switch halfway, as ThemeData does.
      uppercaseEyebrows: t < 0.5 ? uppercaseEyebrows : other.uppercaseEyebrows,
    );
  }
}
