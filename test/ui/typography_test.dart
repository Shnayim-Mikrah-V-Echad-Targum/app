import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/app_theme.dart';
import 'package:shnayim_mikra/ui/theme/palette.dart';

import '../helpers.dart';

const _scheme = Palettes.light;

const _short = {
  'EBGaramond': 'EBG',
  'FrankRuhlLibre': 'FRL',
  'NotoSans': 'NS',
  'NotoSansHebrew': 'NSH',
  'Lexend': 'Lexend',
};

String _n(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';

/// "EBG 22/28 500 0", in the shape of the tables in docs/DESIGN_SYSTEM.md §4.
String _describe(TextStyle s) {
  final size = s.fontSize!;
  return [
    _short[s.fontFamily] ?? '${s.fontFamily}',
    '${_n(size)}/${(size * s.height!).round()}',
    '${s.fontWeight!.value}',
    _n(s.letterSpacing!),
    if (s.fontStyle == FontStyle.italic) 'italic',
  ].join(' ');
}

Map<String, TextStyle> _roles(TextTheme t) => {
      'displayLarge': t.displayLarge!,
      'displayMedium': t.displayMedium!,
      'displaySmall': t.displaySmall!,
      'headlineLarge': t.headlineLarge!,
      'headlineMedium': t.headlineMedium!,
      'headlineSmall': t.headlineSmall!,
      'titleLarge': t.titleLarge!,
      'titleMedium': t.titleMedium!,
      'titleSmall': t.titleSmall!,
      'bodyLarge': t.bodyLarge!,
      'bodyMedium': t.bodyMedium!,
      'bodySmall': t.bodySmall!,
      'labelLarge': t.labelLarge!,
      'labelMedium': t.labelMedium!,
      'labelSmall': t.labelSmall!,
    };

const _serifRoles = {
  'displayLarge',
  'displayMedium',
  'displaySmall',
  'headlineLarge',
  'headlineMedium',
  'headlineSmall',
  'titleLarge',
};

Map<String, TextStyle> _tokens(SeferType t) => {
      'eyebrow': t.eyebrow,
      'marginalia': t.marginalia,
      'ledgerNumeral': t.ledgerNumeral,
      'ringNumeral': t.ringNumeral,
      'longformBody': t.longformBody,
      'longformHeading': t.longformHeading,
      'hebrewDisplay': t.hebrewDisplay,
      'ordinal': t.ordinal,
      'wordmark': t.wordmark,
    };

// docs/DESIGN_SYSTEM.md §4.3 and §4.4.
const _english = {
  'displayLarge': 'EBG 44/52 500 -0.25',
  'displayMedium': 'EBG 38/46 500 -0.2',
  'displaySmall': 'EBG 32/40 500 0',
  'headlineLarge': 'EBG 30/38 500 0',
  'headlineMedium': 'EBG 28/36 500 0',
  'headlineSmall': 'EBG 24/30 500 0',
  'titleLarge': 'EBG 22/28 500 0',
  'titleMedium': 'NS 16/24 500 0.1',
  'titleSmall': 'NS 14/20 500 0.1',
  'bodyLarge': 'NS 16/24 400 0.15',
  'bodyMedium': 'NS 15/22 400 0.15',
  'bodySmall': 'NS 13/18 400 0.2',
  'labelLarge': 'NS 15/20 500 0.1',
  'labelMedium': 'NS 13/16 500 0.3',
  'labelSmall': 'NS 12/16 500 0.4',
};

const _hebrew = {
  'displayLarge': 'FRL 40/56 500 0',
  'displayMedium': 'FRL 34/48 500 0',
  'displaySmall': 'FRL 30/42 500 0',
  'headlineLarge': 'FRL 28/38 500 0',
  'headlineMedium': 'FRL 26/36 500 0',
  'headlineSmall': 'FRL 22/30 600 0',
  'titleLarge': 'FRL 21/28 600 0',
  'titleMedium': 'NSH 16/24 500 0',
  'titleSmall': 'NSH 14/22 500 0',
  'bodyLarge': 'NSH 16/26 400 0',
  'bodyMedium': 'NSH 15/24 400 0',
  'bodySmall': 'NSH 13/20 400 0',
  'labelLarge': 'NSH 15/20 500 0',
  'labelMedium': 'NSH 13/18 500 0',
  'labelSmall': 'NSH 12/16 500 0',
};

// §4.5 and the rail's wordmark (§6.10), without hebrewDisplay (it has no size;
// checked on its own).
const _seferEnglish = {
  'eyebrow': 'EBG 18/22 600 0.8',
  'marginalia': 'EBG 19/28 500 0 italic',
  'ledgerNumeral': 'EBG 34/40 600 0',
  'ringNumeral': 'EBG 22/24 600 0',
  'longformBody': 'EBG 20/32 500 0.1',
  'longformHeading': 'EBG 24/30 500 0',
  'ordinal': 'FRL 20/24 600 0',
  'wordmark': 'EBG 20/24 500 0',
};
const _seferHebrew = {
  'eyebrow': 'FRL 16/20 600 0',
  'marginalia': 'FRL 17/26 500 0',
  'ledgerNumeral': 'EBG 34/40 600 0',
  'ringNumeral': 'EBG 22/24 600 0',
  'longformBody': 'FRL 18/30 500 0',
  'longformHeading': 'FRL 22/30 600 0',
  'ordinal': 'FRL 20/24 600 0',
  'wordmark': 'FRL 20/24 500 0',
};
const _seferEnglishHc = {
  'eyebrow': 'EBG 18/22 700 0.8',
  'marginalia': 'EBG 19/28 600 0',
  'ledgerNumeral': 'EBG 34/40 600 0',
  'ringNumeral': 'EBG 22/24 600 0',
  'longformBody': 'EBG 20/32 600 0.1',
  'longformHeading': 'EBG 24/30 600 0',
  'ordinal': 'FRL 20/24 700 0',
  'wordmark': 'EBG 20/24 600 0',
};
const _seferHebrewHc = {
  'eyebrow': 'FRL 16/20 700 0',
  'marginalia': 'FRL 17/26 700 0',
  'ledgerNumeral': 'EBG 34/40 600 0',
  'ringNumeral': 'EBG 22/24 600 0',
  'longformBody': 'FRL 18/30 700 0',
  'longformHeading': 'FRL 22/30 700 0',
  'ordinal': 'FRL 20/24 700 0',
  'wordmark': 'FRL 20/24 700 0',
};
const _seferLexendEnglish = {
  'eyebrow': 'Lexend 13/16 700 0.8',
  'marginalia': 'Lexend 16/24 400 0',
  'ledgerNumeral': 'Lexend 34/40 700 0',
  'ringNumeral': 'Lexend 22/24 700 0',
  'longformBody': 'Lexend 18/30 400 0',
  'longformHeading': 'Lexend 24/30 700 0',
  'ordinal': 'Lexend 20/24 700 0',
  'wordmark': 'Lexend 20/24 700 0',
};
const _seferLexendHebrew = {
  'eyebrow': 'Lexend 13/16 700 0',
  'marginalia': 'Lexend 16/24 400 0',
  'ledgerNumeral': 'Lexend 34/40 700 0',
  'ringNumeral': 'Lexend 22/24 700 0',
  'longformBody': 'Lexend 18/30 400 0',
  'longformHeading': 'Lexend 22/30 700 0',
  'ordinal': 'Lexend 20/24 700 0',
  'wordmark': 'Lexend 20/24 700 0',
};

/// The weights each family bundles (pubspec.yaml). The device font is
/// asked for the sans weights only.
const _bundled = {
  'EBGaramond': {500, 600, 700},
  'FrankRuhlLibre': {500, 600, 700},
  'NotoSans': {400, 500, 700},
  'NotoSansHebrew': {400, 500, 700},
  'AtkinsonHyperlegibleNext': {400, 700},
  'Lexend': {400, 700},
  'OpenDyslexic': {400, 700},
  null: {400, 500, 700},
};

/// The accessibility fonts, which have no Hebrew: in the Hebrew UI their
/// Medium roles ask for 500, which the fallback that draws the Hebrew, Noto
/// Sans Hebrew, bundles. Their Latin falls to the nearest weight, 400.
const _accessibilityFonts = {'AtkinsonHyperlegibleNext', 'Lexend', 'OpenDyslexic'};

Set<int> _weightsFor(String? family, {required bool hebrewUi}) => hebrewUi && _accessibilityFonts.contains(family)
    ? {..._bundled[family]!, ..._bundled['NotoSansHebrew']!}
    : _bundled[family]!;

const _fallbacks = {
  'EBGaramond': ['FrankRuhlLibre', 'NotoSerifHebrew'],
  'FrankRuhlLibre': ['EBGaramond', 'NotoSerifHebrew'],
  'NotoSans': ['NotoSansHebrew', 'NotoSerifHebrew'],
  'NotoSansHebrew': ['NotoSans', 'NotoSerifHebrew'],
  'AtkinsonHyperlegibleNext': ['NotoSansHebrew', 'NotoSerifHebrew'],
  'Lexend': ['NotoSansHebrew', 'NotoSerifHebrew'],
  'OpenDyslexic': ['NotoSansHebrew', 'NotoSerifHebrew'],
  null: ['NotoSansHebrew', 'NotoSerifHebrew'],
};

TextTheme _theme({UiFont uiFont = UiFont.standard, bool hebrewUi = false, bool highContrast = false}) =>
    AppTypography.textTheme(scheme: _scheme, uiFont: uiFont, hebrewUi: hebrewUi, highContrast: highContrast);

SeferType _sefer({UiFont uiFont = UiFont.standard, bool hebrewUi = false, bool highContrast = false}) =>
    AppTypography.sefer(scheme: _scheme, uiFont: uiFont, hebrewUi: hebrewUi, highContrast: highContrast);

Map<String, String> _described(Map<String, TextStyle> styles, Iterable<String> keys) =>
    {for (final k in keys) k: _describe(styles[k]!)};

void main() {
  group('the text theme snapshot', () {
    test('serif display roles: EB Garamond in English, Frank Ruhl Libre in Hebrew', () {
      ThemeData build(bool hebrewUi) =>
          AppTheme.build(mode: AppThemeMode.light, uiFont: UiFont.standard, hebrewUi: hebrewUi, reduceMotion: false);
      expect(build(false).textTheme.titleLarge!.fontFamily, 'EBGaramond');
      expect(build(true).textTheme.titleLarge!.fontFamily, 'FrankRuhlLibre');
      expect(build(false).textTheme.bodyMedium!.fontFamily, 'NotoSans');
      expect(build(true).textTheme.bodyMedium!.fontFamily, 'NotoSansHebrew');
    });

    test('no Noto Sans role in any theme asks for w600, which is not bundled', () {
      for (final mode in AppThemeMode.values.where((m) => m != AppThemeMode.system)) {
        for (final hebrewUi in [false, true]) {
          final theme = AppTheme.build(mode: mode, uiFont: UiFont.standard, hebrewUi: hebrewUi, reduceMotion: false);
          for (final MapEntry(key: role, value: style) in _roles(theme.textTheme).entries) {
            if (_serifRoles.contains(role)) continue;
            expect(style.fontFamily, hebrewUi ? 'NotoSansHebrew' : 'NotoSans');
            expect(style.fontWeight, isNot(FontWeight.w600), reason: '${mode.name} $role');
          }
          // Buttons take labelLarge as it is: Medium, not Bold.
          expect(theme.filledButtonTheme.style?.textStyle, isNull);
        }
      }
    });

    test('the English UI matches §4.3', () {
      expect(_described(_roles(_theme()), _english.keys), _english);
    });

    test('the Hebrew UI matches §4.4: letter spacing 0 everywhere', () {
      expect(_described(_roles(_theme(hebrewUi: true)), _hebrew.keys), _hebrew);
    });

    test('high contrast: EB Garamond roles at w600, Frank Ruhl Libre roles at w700', () {
      for (final MapEntry(key: role, value: style) in _roles(_theme(highContrast: true)).entries) {
        expect(style.fontWeight, _serifRoles.contains(role) ? FontWeight.w600 : _roles(_theme())[role]!.fontWeight,
            reason: role);
      }
      for (final MapEntry(key: role, value: style) in _roles(_theme(hebrewUi: true, highContrast: true)).entries) {
        expect(style.fontWeight,
            _serifRoles.contains(role) ? FontWeight.w700 : _roles(_theme(hebrewUi: true))[role]!.fontWeight,
            reason: role);
      }
    });

    test('an accessibility font replaces every role, in bold for display, headline and title', () {
      for (final hebrewUi in [false, true]) {
        final plain = _roles(_theme(hebrewUi: hebrewUi));
        final atkinson = _roles(_theme(uiFont: UiFont.atkinson, hebrewUi: hebrewUi));
        for (final MapEntry(key: role, value: style) in atkinson.entries) {
          expect(style.fontFamily, 'AtkinsonHyperlegibleNext', reason: role);
          expect(style.fontFamilyFallback, ['NotoSansHebrew', 'NotoSerifHebrew'], reason: role);
          expect(style.fontSize, plain[role]!.fontSize, reason: role);
          expect(style.height, plain[role]!.height, reason: role);
          final plainWeight = plain[role]!.fontWeight;
          expect(
            style.fontWeight,
            _serifRoles.contains(role)
                ? FontWeight.w700
                // Only 400 and 700 are bundled: in English, Medium roles ask
                // for Regular. In Hebrew they keep 500 for the Hebrew, which
                // Noto Sans Hebrew draws in its Medium.
                : plainWeight == FontWeight.w500 && !hebrewUi
                    ? FontWeight.w400
                    : plainWeight,
            reason: '$role he=$hebrewUi',
          );
        }
      }
    });

    test('the device font changes only the sans roles', () {
      for (final hebrewUi in [false, true]) {
        final plain = _roles(_theme(hebrewUi: hebrewUi));
        final device = _roles(_theme(uiFont: UiFont.system, hebrewUi: hebrewUi));
        for (final MapEntry(key: role, value: style) in device.entries) {
          if (_serifRoles.contains(role)) {
            expect(style, plain[role], reason: role);
          } else {
            // The platform's font for the Latin; Hebrew still falls back to
            // the bundled fonts, in either UI.
            expect(style.fontFamily, isNull, reason: role);
            expect(style.fontFamilyFallback, ['NotoSansHebrew', 'NotoSerifHebrew'], reason: role);
            final bundled = plain[role]!;
            expect(style.copyWith(fontFamily: bundled.fontFamily, fontFamilyFallback: bundled.fontFamilyFallback),
                bundled,
                reason: role);
          }
        }
      }
      // ThemeData fills the family in from the platform's typography, and
      // keeps the fallbacks.
      for (final hebrewUi in [false, true]) {
        final theme =
            AppTheme.build(mode: AppThemeMode.light, uiFont: UiFont.system, hebrewUi: hebrewUi, reduceMotion: false);
        expect(theme.textTheme.bodyMedium!.fontFamily, 'Roboto');
        expect(theme.textTheme.bodyMedium!.fontFamilyFallback, ['NotoSansHebrew', 'NotoSerifHebrew']);
        expect(theme.textTheme.titleLarge!.fontFamily, hebrewUi ? 'FrankRuhlLibre' : 'EBGaramond');
      }
    });

    test('serif roles use lining, tabular figures', () {
      for (final hebrewUi in [false, true]) {
        for (final role in _serifRoles) {
          expect(_roles(_theme(hebrewUi: hebrewUi))[role]!.fontFeatures,
              containsAll(const [FontFeature.liningFigures(), FontFeature.tabularFigures()]));
        }
      }
    });
  });

  group('SeferType', () {
    test('English and Hebrew tokens match §4.5', () {
      expect(_described(_tokens(_sefer()), _seferEnglish.keys), _seferEnglish);
      expect(_described(_tokens(_sefer(hebrewUi: true)), _seferHebrew.keys), _seferHebrew);
    });

    test('high contrast: bold eyebrows, upright marginalia, heavier serifs', () {
      expect(_described(_tokens(_sefer(highContrast: true)), _seferEnglishHc.keys), _seferEnglishHc);
      expect(_described(_tokens(_sefer(hebrewUi: true, highContrast: true)), _seferHebrewHc.keys), _seferHebrewHc);
    });

    test('an accessibility font replaces every token but the Hebrew display', () {
      expect(_described(_tokens(_sefer(uiFont: UiFont.lexend)), _seferLexendEnglish.keys), _seferLexendEnglish);
      expect(_described(_tokens(_sefer(uiFont: UiFont.lexend, hebrewUi: true)), _seferLexendHebrew.keys),
          _seferLexendHebrew);
      for (final hebrewUi in [false, true]) {
        expect(_sefer(uiFont: UiFont.openDyslexic, hebrewUi: hebrewUi).hebrewDisplay,
            _sefer(hebrewUi: hebrewUi).hebrewDisplay);
      }
      // No small caps in these fonts.
      expect(_sefer(uiFont: UiFont.lexend).eyebrow.fontFeatures, isNull);
      expect(_sefer(uiFont: UiFont.lexend).ledgerNumeral.fontFeatures, [const FontFeature.tabularFigures()]);
    });

    test('the device font leaves every token alone', () {
      for (final hebrewUi in [false, true]) {
        for (final highContrast in [false, true]) {
          expect(_tokens(_sefer(uiFont: UiFont.system, hebrewUi: hebrewUi, highContrast: highContrast)),
              _tokens(_sefer(hebrewUi: hebrewUi, highContrast: highContrast)));
        }
      }
    });

    test('colours come from the scheme', () {
      final t = _sefer();
      expect(t.eyebrow.color, _scheme.secondary);
      expect(t.marginalia.color, _scheme.onSurfaceVariant);
      expect(t.ledgerNumeral.color, _scheme.onSurface);
      expect(t.ringNumeral.color, _scheme.onSurface);
      expect(t.longformHeading.color, _scheme.onSurface);
      expect(t.hebrewDisplay.color, _scheme.primary);
      expect(t.wordmark.color, _scheme.onSurface);
      expect(_sefer(hebrewUi: true).eyebrow.color, _scheme.secondary);
    });

    test('the English eyebrow is in small caps; serif numerals are lining and tabular', () {
      expect(_sefer().eyebrow.fontFeatures,
          const [FontFeature.enable('smcp'), FontFeature.enable('c2sc')]);
      expect(_sefer(hebrewUi: true).eyebrow.fontFeatures, isNull);
      for (final hebrewUi in [false, true]) {
        for (final numeral in [_sefer(hebrewUi: hebrewUi).ledgerNumeral, _sefer(hebrewUi: hebrewUi).ringNumeral]) {
          expect(numeral.fontFamily, 'EBGaramond');
          expect(numeral.fontFeatures, containsAll(const [FontFeature.liningFigures(), FontFeature.tabularFigures()]));
        }
      }
    });

    test('the Hebrew display is Frank Ruhl Libre at a per-use size', () {
      for (final hebrewUi in [false, true]) {
        final d = _sefer(hebrewUi: hebrewUi).hebrewDisplay;
        expect(d.fontFamily, 'FrankRuhlLibre');
        expect(d.fontFamilyFallback, ['NotoSerifHebrew']);
        expect(d.fontSize, isNull);
        expect(d.height, 1.3);
        expect(d.fontWeight, FontWeight.w500);
        expect(_sefer(hebrewUi: hebrewUi, highContrast: true).hebrewDisplay.fontWeight, FontWeight.w700);
      }
    });

    test('EB Garamond never goes below 18 for eyebrows or 19 for running text', () {
      for (final highContrast in [false, true]) {
        final t = _sefer(highContrast: highContrast);
        for (final MapEntry(key: name, value: style) in _tokens(t).entries) {
          if (style.fontFamily != 'EBGaramond') continue;
          expect(style.fontSize, greaterThanOrEqualTo(name == 'eyebrow' ? 18 : 19), reason: name);
        }
      }
    });

    test('eyebrows are uppercased only for an accessibility font in the English UI, and never with Hebrew', () {
      expect(_sefer().eyebrowText('Parshat Hashavua'), 'Parshat Hashavua');
      expect(_sefer(uiFont: UiFont.system).eyebrowText('Parshat Hashavua'), 'Parshat Hashavua');
      expect(_sefer(uiFont: UiFont.atkinson).eyebrowText('Parshat Hashavua'), 'PARSHAT HASHAVUA');
      expect(_sefer(uiFont: UiFont.atkinson).eyebrowText('Revi’i · רביעי'), 'Revi’i · רביעי');
      expect(_sefer(uiFont: UiFont.atkinson, hebrewUi: true).eyebrowText('This week'), 'This week');
    });

    test('copyWith and lerp', () {
      final a = _sefer();
      final b = _sefer(uiFont: UiFont.lexend, highContrast: true);
      expect(a.lerp(b, 0).eyebrow, a.eyebrow);
      expect(a.lerp(b, 1).ordinal, b.ordinal);
      expect(a.lerp(b, 0.5).ledgerNumeral.fontSize, 34);
      expect(a.lerp(b, 0.4).uppercaseEyebrows, isFalse);
      expect(a.lerp(b, 0.6).uppercaseEyebrows, isTrue);
      expect(a.lerp(null, 0.5), same(a));
      expect(a.copyWith(ordinal: b.ordinal).ordinal, b.ordinal);
      expect(a.copyWith(ordinal: b.ordinal).eyebrow, a.eyebrow);
      expect(a.lerp(b, 1).wordmark, b.wordmark);
      expect(a.copyWith(wordmark: b.wordmark).wordmark, b.wordmark);
    });
  });

  test('every style in every combination sets its line height, splits it evenly, and asks only for bundled faces', () {
    for (final uiFont in UiFont.values) {
      for (final hebrewUi in [false, true]) {
        for (final highContrast in [false, true]) {
          final combo = '${uiFont.name} ${hebrewUi ? 'he' : 'en'}${highContrast ? ' hc' : ''}';
          final styles = {
            ..._roles(_theme(uiFont: uiFont, hebrewUi: hebrewUi, highContrast: highContrast)),
            ..._tokens(_sefer(uiFont: uiFont, hebrewUi: hebrewUi, highContrast: highContrast)),
          };
          for (final MapEntry(key: name, value: s) in styles.entries) {
            final where = '$combo $name';
            expect(s.height, isNotNull, reason: where);
            expect(s.leadingDistribution, TextLeadingDistribution.even, reason: where);
            expect(_weightsFor(s.fontFamily, hebrewUi: hebrewUi), contains(s.fontWeight!.value), reason: where);
            if (name != 'hebrewDisplay') expect(s.fontFamilyFallback, _fallbacks[s.fontFamily], reason: where);
            if (s.fontStyle == FontStyle.italic) {
              // The one italic face: EB Garamond Medium Italic.
              expect((s.fontFamily, s.fontWeight), ('EBGaramond', FontWeight.w500), reason: where);
            }
            if (hebrewUi) expect(s.letterSpacing, 0, reason: where);
          }
        }
      }
    }
  });

  group('in the app', () {
    /// Friday morning in the week of Bereshit: the hero shows its button.
    final friday = DateTime(2026, 10, 9, 11);

    BuildContext page(WidgetTester tester) => tester.element(find.byType(Scaffold).first);

    testWidgets('SeferType.of(context) returns the tokens for every theme, language and interface font',
        (tester) async {
      for (final mode in AppThemeMode.values.where((m) => m != AppThemeMode.system)) {
        for (final hebrewUi in [false, true]) {
          for (final uiFont in UiFont.values) {
            late SeferType found;
            await tester.pumpWidget(MaterialApp(
              // A fresh app each time, so the theme isn't animating from the last one.
              key: UniqueKey(),
              theme: AppTheme.build(mode: mode, uiFont: uiFont, hebrewUi: hebrewUi, reduceMotion: false),
              home: Builder(builder: (context) {
                found = SeferType.of(context);
                return const SizedBox();
              }),
            ));
            final expected = AppTypography.sefer(
              scheme: AppTheme.scheme(mode, Brightness.light),
              uiFont: uiFont,
              hebrewUi: hebrewUi,
              highContrast: AppTheme.isHighContrast(mode),
            );
            expect(_tokens(found), _tokens(expected), reason: '${mode.name} ${uiFont.name} he=$hebrewUi');
            expect(found.uppercaseEyebrows, expected.uppercaseEyebrows);
          }
        }
      }
    });

    testWidgets('following the device language, the text theme follows the locale MaterialApp resolves',
        (tester) async {
      // French isn't supported, so the app falls through to the next choice.
      tester.platformDispatcher.localesTestValue = const [Locale('fr', 'FR'), Locale('he', 'IL')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await pumpApp(tester, now: friday);
      expect(Localizations.localeOf(page(tester)).languageCode, 'he');
      expect(Theme.of(page(tester)).textTheme.titleLarge!.fontFamily, 'FrankRuhlLibre');
      expect(Theme.of(page(tester)).textTheme.bodyMedium!.fontFamily, 'NotoSansHebrew');
      expect(SeferType.of(page(tester)).eyebrow.fontFamily, 'FrankRuhlLibre');

      // Changing the device language switches the theme with the locale.
      tester.platformDispatcher.localesTestValue = const [Locale('en', 'GB')];
      await tester.pumpAndSettle();
      expect(Localizations.localeOf(page(tester)).languageCode, 'en');
      expect(Theme.of(page(tester)).textTheme.titleLarge!.fontFamily, 'EBGaramond');
      expect(Theme.of(page(tester)).textTheme.bodyMedium!.fontFamily, 'NotoSans');
    });

    testWidgets('a chosen language wins over the device language', (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('he', 'IL')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await pumpApp(tester,
          now: friday, settings: const AppSettings(onboardingComplete: true, language: AppLanguage.english));
      expect(Localizations.localeOf(page(tester)).languageCode, 'en');
      expect(Theme.of(page(tester)).textTheme.titleLarge!.fontFamily, 'EBGaramond');
    });

    TextStyle buttonLabel(WidgetTester tester) => tester
        .renderObject<RenderParagraph>(
            find.descendant(of: find.byType(FilledButton).first, matching: find.byType(Text)))
        .text
        .style!;

    testWidgets('the interface is drawn in the bundled Noto Sans, and buttons in its Medium', (tester) async {
      await pumpApp(tester, now: friday);
      expect(buttonLabel(tester).fontFamily, 'NotoSans');
      expect(buttonLabel(tester).fontWeight, FontWeight.w500);
      expect(Theme.of(page(tester)).textTheme.bodyMedium!.fontFamily, 'NotoSans');
    }, variant: const TargetPlatformVariant({TargetPlatform.android, TargetPlatform.windows, TargetPlatform.iOS}));

    testWidgets('the device font is the platform\'s own', (tester) async {
      await pumpApp(tester, now: friday, settings: const AppSettings(onboardingComplete: true, uiFont: UiFont.system));
      final platformFamily = switch (defaultTargetPlatform) {
        TargetPlatform.windows => 'Segoe UI',
        TargetPlatform.android => 'Roboto',
        _ => throw UnimplementedError(),
      };
      expect(buttonLabel(tester).fontFamily, platformFamily);
      expect(Theme.of(page(tester)).textTheme.titleLarge!.fontFamily, 'EBGaramond');
    }, variant: const TargetPlatformVariant({TargetPlatform.android, TargetPlatform.windows}));

    testWidgets('Display settings offers the device font', (tester) async {
      final container = await openRoute(tester, '/settings/display', now: friday);
      final option = find.text('Device font');
      await tester.ensureVisible(option);
      await tester.pumpAndSettle();
      await tester.tap(option);
      await tester.pumpAndSettle();
      expect(container.read(settingsProvider).uiFont, UiFont.system);
      expect(Theme.of(page(tester)).textTheme.bodyMedium!.fontFamily, 'Roboto');
      expect(Theme.of(page(tester)).textTheme.titleLarge!.fontFamily, 'EBGaramond');
    });
  });
}
