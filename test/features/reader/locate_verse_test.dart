import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/data/models/verse_ref.dart';
import 'package:shnayim_mikra/data/parsha_repository.dart';
import 'package:shnayim_mikra/features/parsha/week_context.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

class _FixedToday extends TodayController {
  _FixedToday(this.day);
  final LocalDate day;

  @override
  LocalDate build() => day;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ParshaRepository repo;
  setUpAll(() async => repo = await ParshaRepository.load());

  const diaspora = ParshaSchedule(israel: false);
  const israel = ParshaSchedule(israel: true);

  test('finds the week and aliyah of a verse', () {
    expect(locateVerse(repo, diaspora, 5787, 'Genesis', const VerseRef(1, 1)), (weekId: '5787:1', aliyah: 0));
    expect(locateVerse(repo, diaspora, 5787, 'Genesis', const VerseRef(28, 10)), (weekId: '5787:7', aliyah: 0));
    expect(locateVerse(repo, diaspora, 5787, 'Genesis', const VerseRef(28, 12)), (weekId: '5787:7', aliyah: 0));
    expect(locateVerse(repo, diaspora, 5787, 'Genesis', const VerseRef(50, 26)), (weekId: '5787:12', aliyah: 6));
  });

  test('counts the aliyah in the week’s portion when two parshiyot are read together', () {
    // Pekudei begins at Exodus 38:21, its own first aliyah. In 5788 it is
    // read with Vayakhel, whose fourth aliyah runs from 38:1 to 39:1.
    expect(locateVerse(repo, diaspora, 5787, 'Exodus', const VerseRef(38, 21)), (weekId: '5787:23', aliyah: 0));
    expect(locateVerse(repo, diaspora, 5788, 'Exodus', const VerseRef(38, 21)), (weekId: '5788:22-23', aliyah: 3));
    expect(locateVerse(repo, diaspora, 5788, 'Exodus', const VerseRef(40, 38)), (weekId: '5788:22-23', aliyah: 6));
  });

  test('follows the reader’s schedule, where Israel and the Diaspora differ', () {
    // In 5787 the Diaspora reads Chukat and Balak together, after the second
    // day of Shavuot; Israel reads them apart.
    expect(locateVerse(repo, diaspora, 5787, 'Numbers', const VerseRef(22, 2)), (weekId: '5787:39-40', aliyah: 3));
    expect(locateVerse(repo, israel, 5787, 'Numbers', const VerseRef(22, 2)), (weekId: '5787:40', aliyah: 0));
  });

  test('finds Vezot HaBerakhah, read on Simchat Torah of the next year', () {
    expect(locateVerse(repo, diaspora, 5787, 'Deuteronomy', const VerseRef(34, 12)), (weekId: '5787:54', aliyah: 6));
  });

  test('finds nothing outside the Torah', () {
    expect(locateVerse(repo, diaspora, 5787, 'Genesis', const VerseRef(51, 1)), isNull);
    expect(locateVerse(repo, diaspora, 5787, 'Joshua', const VerseRef(1, 1)), isNull);
  });

  test('the locator reads the cycle of the current week', () async {
    SharedPreferences.setMockInitialValues({
      SettingsController.storageKey: jsonEncode(const AppSettings(onboardingComplete: true).toJson()),
    });
    final prefs = await SharedPreferences.getInstance();
    ProviderContainer containerOn(LocalDate today) {
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        parshaRepositoryProvider.overrideWithValue(repo),
        todayProvider.overrideWith(() => _FixedToday(today)),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    // Noach 5787, and Ha'azinu at the end of that cycle, after Rosh Hashana.
    for (final today in [LocalDate(2026, 10, 12), LocalDate(2027, 10, 6)]) {
      final locate = containerOn(today).read(verseLocatorProvider);
      expect(locate('Exodus', const VerseRef(38, 21)), (weekId: '5787:23', aliyah: 0), reason: '$today');
    }
    // Bereshit 5788 begins the next cycle, which reads them together.
    final locate = containerOn(LocalDate(2027, 10, 25)).read(verseLocatorProvider);
    expect(locate('Exodus', const VerseRef(38, 21)), (weekId: '5788:22-23', aliyah: 3));
  });
}
