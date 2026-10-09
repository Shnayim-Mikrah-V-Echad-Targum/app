import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/app_theme.dart';
import 'package:shnayim_mikra/ui/theme/palette.dart';

import '../helpers.dart';

const _modes = [
  AppThemeMode.light,
  AppThemeMode.dark,
  AppThemeMode.sepia,
  AppThemeMode.highContrastLight,
  AppThemeMode.highContrastDark,
];

// The tables of docs/DESIGN_SYSTEM.md §3.2–3.4, as Light / Dark / Sepia /
// HC Light / HC Dark. "-" is transparent.
const _scheme = {
  'surface': 'FAF7F0/14120F/F3E9D2/FFFFFF/000000',
  'surfaceDim': 'E6DFD1/14120F/E1D4B6/E0E0E0/000000',
  'surfaceBright': 'FFFDF8/3A352E/FAF3E3/FFFFFF/262626',
  'surfaceContainerLowest': 'FFFDF8/0F0D0B/FAF3E3/FFFFFF/000000',
  'surfaceContainerLow': 'F4EFE4/1C1915/EDE2C8/FFFFFF/000000',
  'surfaceContainer': 'EEE8DB/221F1A/E7DBBF/F2F2F2/0F0F0F',
  'surfaceContainerHigh': 'E8E1D2/2B2721/E1D4B6/EBEBEB/1A1A1A',
  'surfaceContainerHighest': 'E0D8C7/36312A/D8CAA9/E0E0E0/262626',
  'onSurface': '1E1A16/EDE6D6/2B2115/000000/FFFFFF',
  'onSurfaceVariant': '575046/C4BAA8/54452F/1F1F1F/EBEBEB',
  'outline': '857B6D/928878/83704F/000000/FFFFFF',
  'outlineVariant': 'D8CFBF/4A443A/CBB994/4D4D4D/B3B3B3',
  'primary': '1D3F75/AFC6EE/25406C/0A2A5E/B5CEFF',
  'onPrimary': 'FFFFFF/0E2547/FFFFFF/FFFFFF/000000',
  'primaryContainer': 'DDE5F2/27416B/D7DBE1/DCE6FA/1B2A45',
  'onPrimaryContainer': '0E2547/DDE7F8/142A4D/000000/FFFFFF',
  'secondary': '7A5712/DDB96B/6C4B0E/4F3500/FFD970',
  'onSecondary': 'FFFFFF/2E2205/FFFFFF/FFFFFF/000000',
  'secondaryContainer': 'F2E7CD/4A3A16/EADBB4/FFF0C2/3D2E00',
  'onSecondaryContainer': '3B2A06/F4E5BC/3A2905/000000/FFFFFF',
  'tertiary': '2E6A56/8FD0B6/2B6350/00463A/7FE3C2',
  'onTertiary': 'FFFFFF/003829/FFFFFF/FFFFFF/000000',
  'tertiaryContainer': 'D5EADF/1F4A3C/D3E3D3/D6F5EA/003D2E',
  'onTertiaryContainer': '0B3B2C/C9EEDD/0E3528/000000/FFFFFF',
  'error': '9A2B2B/F2B8B5/8E2A22/8C0000/FFB4AB',
  'onError': 'FFFFFF/601410/FFFFFF/FFFFFF/000000',
  'errorContainer': 'F6DEDA/5C1A17/F1D5C9/FFE0DC/4A0000',
  'onErrorContainer': '5C1414/FFDAD5/4F120C/000000/FFFFFF',
  'inverseSurface': '2E2924/EDE6D6/3A2F20/000000/FFFFFF',
  'onInverseSurface': 'F4EFE4/1E1A16/F3E9D2/FFFFFF/000000',
  'inversePrimary': 'AFC6EE/1D3F75/B4C6E6/B5CEFF/0A2A5E',
  'shadow': '1E1A16/000000/2B2115/000000/000000',
  'scrim': '000000/000000/000000/000000/000000',
  'surfaceTint': '-/-/-/-/-',
};

const _sefer = {
  'paper': 'FFFDF8/1C1915/FAF3E3/FFFFFF/000000',
  'hairline': 'D8CFBF/4A443A/CBB994/000000/FFFFFF',
  'goldLeaf': 'B38D3F/B8954B/A9853A/4F3500/FFD970',
  'ringMikra1': '1D3F75/AFC6EE/25406C/0A2A5E/B5CEFF',
  'ringMikra2': '55779F/7E9BC8/4F6B92/2F4F82/8FB0F0',
  'ringTargum': '946C1E/C9A458/8A651C/4F3500/FFD970',
  'ringTrack': 'E8E1D3/36312A/E0D3B4/E0E0E0/333333',
  'restWash': 'F2E7CD/4A3A16/EADBB4/FFF0C2/3D2E00',
  'focus': '1D3F75/AFC6EE/25406C/000000/FFFFFF',
  'focusGap': 'FAF7F0/14120F/F3E9D2/FFFFFF/000000',
  'dimInk': '716859/9C9384/6E5F49/1F1F1F/EBEBEB',
  'verseHighlight': 'FFFDF8/1C1915/FAF3E3/-/-',
};

const _status = {
  'done': '1D3F75/AFC6EE/25406C/0A2A5E/B5CEFF',
  'onDone': 'FFFFFF/0E2547/FFFFFF/FFFFFF/000000',
  'late': '4A6A9B/8199C6/46628C/2F4F82/8FB0F0',
  'onLate': 'FFFFFF/0E2547/FFFFFF/FFFFFF/000000',
  'overdue': '7A5712/DDB96B/6C4B0E/4F3500/FFD970',
  'grace': '2E6A56/8FD0B6/2B6350/00463A/7FE3C2',
  'neutral': '7D7466/958C7D/7C6C55/4D4D4D/BDBDBD',
  'rest': '7A5712/DDB96B/6C4B0E/4F3500/FFD970',
};

Color _cell(String row, int column) {
  final hex = row.split('/')[column];
  return hex == '-' ? Colors.transparent : Color(0xFF000000 | int.parse(hex, radix: 16));
}

Map<String, Color> _schemeRoles(ColorScheme s) => {
      'surface': s.surface,
      'surfaceDim': s.surfaceDim,
      'surfaceBright': s.surfaceBright,
      'surfaceContainerLowest': s.surfaceContainerLowest,
      'surfaceContainerLow': s.surfaceContainerLow,
      'surfaceContainer': s.surfaceContainer,
      'surfaceContainerHigh': s.surfaceContainerHigh,
      'surfaceContainerHighest': s.surfaceContainerHighest,
      'onSurface': s.onSurface,
      'onSurfaceVariant': s.onSurfaceVariant,
      'outline': s.outline,
      'outlineVariant': s.outlineVariant,
      'primary': s.primary,
      'onPrimary': s.onPrimary,
      'primaryContainer': s.primaryContainer,
      'onPrimaryContainer': s.onPrimaryContainer,
      'secondary': s.secondary,
      'onSecondary': s.onSecondary,
      'secondaryContainer': s.secondaryContainer,
      'onSecondaryContainer': s.onSecondaryContainer,
      'tertiary': s.tertiary,
      'onTertiary': s.onTertiary,
      'tertiaryContainer': s.tertiaryContainer,
      'onTertiaryContainer': s.onTertiaryContainer,
      'error': s.error,
      'onError': s.onError,
      'errorContainer': s.errorContainer,
      'onErrorContainer': s.onErrorContainer,
      'inverseSurface': s.inverseSurface,
      'onInverseSurface': s.onInverseSurface,
      'inversePrimary': s.inversePrimary,
      'shadow': s.shadow,
      'scrim': s.scrim,
      'surfaceTint': s.surfaceTint,
    };

Map<String, Color> _seferTokens(SeferColors c) => {
      'paper': c.paper,
      'hairline': c.hairline,
      'goldLeaf': c.goldLeaf,
      'ringMikra1': c.ringMikra1,
      'ringMikra2': c.ringMikra2,
      'ringTargum': c.ringTargum,
      'ringTrack': c.ringTrack,
      'restWash': c.restWash,
      'focus': c.focus,
      'focusGap': c.focusGap,
      'dimInk': c.dimInk,
      'verseHighlight': c.verseHighlight,
    };

Map<String, Color> _statusTokens(StatusColors c) => {
      'done': c.done,
      'onDone': c.onDone,
      'late': c.late,
      'onLate': c.onLate,
      'overdue': c.overdue,
      'grace': c.grace,
      'neutral': c.neutral,
      'rest': c.rest,
    };

/// The rows of [table] whose value in [column] differs from [actual].
List<String> _mismatches(Map<String, String> table, Map<String, Color> actual, int column) => [
      for (final MapEntry(key: name, value: row) in table.entries)
        if (actual[name] != _cell(row, column)) '$name: ${actual[name]}, expected ${row.split('/')[column]}',
    ];

void main() {
  for (final (column, mode) in _modes.indexed) {
    test('${mode.name}: the theme carries the palette and both extensions', () {
      final theme = AppTheme.build(mode: mode, uiFont: UiFont.standard, reduceMotion: false);
      final sefer = theme.extension<SeferColors>()!;
      final status = theme.extension<StatusColors>()!;

      expect(_mismatches(_scheme, _schemeRoles(theme.colorScheme), column), isEmpty);
      expect(_mismatches(_sefer, _seferTokens(sefer), column), isEmpty);
      expect(_mismatches(_status, _statusTokens(status), column), isEmpty);
      expect(sefer.hairlineWidth, AppTheme.isHighContrast(mode) ? 2 : 1);
      expect(sefer.isHighContrast, AppTheme.isHighContrast(mode));
      expect(theme.brightness, mode == AppThemeMode.dark || mode == AppThemeMode.highContrastDark ? Brightness.dark : Brightness.light);
      expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);
    });
  }

  test('the system theme follows the platform brightness', () {
    expect(AppTheme.resolve(AppThemeMode.system, Brightness.light), AppThemeMode.light);
    expect(AppTheme.resolve(AppThemeMode.system, Brightness.dark), AppThemeMode.dark);
    expect(AppTheme.resolve(AppThemeMode.sepia, Brightness.dark), AppThemeMode.sepia);
    expect(AppTheme.scheme(AppThemeMode.system, Brightness.dark), Palettes.dark);
    expect(AppTheme.scheme(AppThemeMode.highContrastLight, Brightness.dark), Palettes.hcLight);
  });

  test('SeferColors interpolates between themes', () {
    const a = Palettes.seferLight;
    const b = Palettes.seferHcDark;
    expect(a.lerp(b, 0).paper, a.paper);
    expect(a.lerp(b, 1).dimInk, b.dimInk);
    expect(a.lerp(b, 0.5).hairlineWidth, 1.5);
    expect(a.lerp(b, 0.4).isHighContrast, isFalse);
    expect(a.lerp(b, 0.6).isHighContrast, isTrue);
    expect(a.lerp(null, 0.5), same(a));
    expect(a.copyWith(dimInk: Colors.red).dimInk, Colors.red);
    expect(a.copyWith(dimInk: Colors.red).paper, a.paper);
  });

  test('StatusColors interpolates between themes', () {
    const a = Palettes.statusLight;
    const b = Palettes.statusDark;
    expect(a.lerp(b, 0).overdue, a.overdue);
    expect(a.lerp(b, 1).overdue, b.overdue);
    expect(a.copyWith(overdue: Colors.red).overdue, Colors.red);
    expect(a.copyWith(overdue: Colors.red).late, a.late);
  });

  for (final (theme, platform) in [
    (AppThemeMode.system, Brightness.dark),
    for (final m in _modes) (m, Brightness.light),
  ]) {
    testWidgets('the app paints the ${theme.name} tokens on a ${platform.name} platform', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = platform;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await pumpApp(tester, settings: AppSettings(onboardingComplete: true, theme: theme));
      final context = tester.element(find.byType(Scaffold).first);
      final column = _modes.indexOf(AppTheme.resolve(theme, platform));
      expect(_mismatches(_scheme, _schemeRoles(Theme.of(context).colorScheme), column), isEmpty);
      expect(_mismatches(_sefer, _seferTokens(SeferColors.of(context)), column), isEmpty);
      expect(_mismatches(_status, _statusTokens(StatusColors.of(context)), column), isEmpty);
    });
  }
}
