import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

void main() {
  test('settings round-trip through JSON', () {
    final s = const AppSettings().copyWith(
      israel: true,
      theme: AppThemeMode.highContrastDark,
      readingScale: 2.5,
      secondReading: SecondReading.onkelosAndRashi,
      joinDate: LocalDate(2026, 10, 9),
      habitAnchor: 'finish Shacharit',
    );
    final back = AppSettings.fromJson(s.toJson());
    expect(back.toJson(), s.toJson());
  });

  test('unknown or out-of-range values fall back safely', () {
    final s = AppSettings.fromJson({
      'theme': 'neon',
      'readingScale': 99,
      'israel': 'yes',
      'method': null,
    });
    expect(s.theme, AppThemeMode.system);
    expect(s.readingScale, kMaxReadingScale);
    expect(s.israel, isFalse);
    expect(s.method, ReadingMethod.verseByVerse);
  });

  test('copyWith can clear nullable fields', () {
    final s = const AppSettings(habitAnchor: 'x').copyWith(habitAnchor: null);
    expect(s.habitAnchor, isNull);
  });

  test('interface fonts keep their persisted names, and the device font round-trips', () {
    expect(UiFont.values.map((f) => f.name), ['standard', 'atkinson', 'lexend', 'openDyslexic', 'system']);
    expect(AppSettings.fromJson({'uiFont': 'standard'}).uiFont, UiFont.standard);
    expect(AppSettings.fromJson({'uiFont': 'lexend'}).uiFont, UiFont.lexend);
    final device = const AppSettings(uiFont: UiFont.system);
    expect(AppSettings.fromJson(device.toJson()).uiFont, UiFont.system);
  });
}
