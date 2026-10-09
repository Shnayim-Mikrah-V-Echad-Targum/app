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
      starterCatchUp: false,
      habitAnchor: 'finish Shacharit',
    );
    final back = AppSettings.fromJson(s.toJson());
    expect(back.toJson(), s.toJson());
    expect(back.starterCatchUp, isFalse);
  });

  test('settings saved before the starter plan existed turn it on', () {
    final s = AppSettings.fromJson({'joinDate': LocalDate(2026, 10, 9).rd});
    expect(s.starterCatchUp, isTrue);
    expect(s.joinDate, LocalDate(2026, 10, 9));
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
}
